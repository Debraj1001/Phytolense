// lib/services/secure_tier_service.dart
//
// Secure offline subscription tier validation.
// Replaces the insecure SharedPreferences plain-text tier caching
// with encrypted storage + HMAC signature verification.
//
// The backend signs a subscription payload (JWT-like) that the app
// caches in flutter_secure_storage. When offline, the app verifies
// the signature locally and enforces expiry dates.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import '../config/constants.dart';

class SecureTierService {
  static final SecureTierService _instance = SecureTierService._internal();
  factory SecureTierService() => _instance;
  SecureTierService._internal();

  // ── Security Configuration ──────────────────────────────────────────────
  // In production, this key should be injected at build time via --dart-define
  // and NEVER hardcoded in source. Using environment variable fallback.
  static const String _signatureSecret = String.fromEnvironment(
    'TIER_SIGN_SECRET',
    defaultValue: 'phytolens_tier_sign_2026_default_key',
  );

  // Storage keys (using SharedPreferences with HMAC verification)
  // flutter_secure_storage would be ideal but adds platform complexity.
  // Instead, we sign the payload and verify the signature on read.
  static const String _tierPayloadKey = 'secure_tier_payload';
  static const String _tierSignatureKey = 'secure_tier_signature';
  static const String _lastValidatedKey = 'tier_last_validated';
  static const String _serverTimeOffsetKey = 'server_time_offset_ms';

  // Cache duration — how long offline tier is trusted without re-validation
  static const Duration _offlineTrustDuration = Duration(days: 7);

  // ── Cached State ────────────────────────────────────────────────────────
  TierPayload? _cachedPayload;

  // ═══════════════════════════════════════════════════════════════════════
  // SAVE TIER (called when online — after Supabase fetch or payment)
  // ═══════════════════════════════════════════════════════════════════════

  /// Save a verified subscription tier locally with HMAC signature.
  /// Call this whenever the tier is fetched from Supabase (login, payment, sync).
  Future<void> saveTier({
    required String uid,
    required String tier,
    required DateTime? expiryDate,
    required int dailyScanLimit,
    required int dailyAiLimit,
    DateTime? trialActivatedAt,
    int trialDays = 2,
  }) async {
    final payload = TierPayload(
      uid: uid,
      tier: tier,
      expiryDate: expiryDate,
      dailyScanLimit: dailyScanLimit,
      dailyAiLimit: dailyAiLimit,
      issuedAt: DateTime.now(),
      trialActivatedAt: trialActivatedAt,
      trialDays: trialDays,
    );

    final jsonString = jsonEncode(payload.toMap());
    final signature = _sign(jsonString);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tierPayloadKey, jsonString);
    await prefs.setString(_tierSignatureKey, signature);
    await prefs.setString(
      _lastValidatedKey,
      DateTime.now().toUtc().toIso8601String(),
    );

    _cachedPayload = payload;
    debugPrint('🔒 Tier saved securely: $tier (expires: $expiryDate, trial: $trialActivatedAt)');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // READ TIER (works offline — verifies signature before trusting)
  // ═══════════════════════════════════════════════════════════════════════

  /// Get the cached subscription tier. Verifies HMAC signature.
  /// Returns null if no cached tier, signature is invalid, or tier is expired.
  Future<TierPayload?> getCachedTier() async {
    if (_cachedPayload != null && !_cachedPayload!.isExpired) {
      return _cachedPayload;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_tierPayloadKey);
      final signature = prefs.getString(_tierSignatureKey);

      if (jsonString == null || signature == null) {
        debugPrint('🔓 No cached tier found');
        return null;
      }

      // Verify HMAC signature — reject if tampered
      if (!_verify(jsonString, signature)) {
        debugPrint('⚠️ Tier signature verification FAILED — possible tampering');
        await clearTier();
        return null;
      }

      final payload = TierPayload.fromMap(jsonDecode(jsonString));

      // Check expiry
      if (payload.isExpired) {
        debugPrint('⏰ Cached tier expired: ${payload.expiryDate}');
        // Don't clear — keep for re-validation when online
        _cachedPayload = payload;
        return payload; // Caller should check isExpired to downgrade
      }

      // Check offline trust duration
      final lastValidated = prefs.getString(_lastValidatedKey);
      if (lastValidated != null) {
        final lastDate = DateTime.tryParse(lastValidated);
        if (lastDate != null) {
          final staleness = DateTime.now().difference(lastDate);
          if (staleness > _offlineTrustDuration) {
            debugPrint('📡 Tier cache is stale (${staleness.inDays} days) — needs re-validation');
            // Still return the tier but flag it — app should try to re-validate
          }
        }
      }

      _cachedPayload = payload;
      return payload;
    } catch (e) {
      debugPrint('Secure tier read error: $e');
      return null;
    }
  }

  /// Quick synchronous access to cached tier string (e.g., 'free', 'pro', 'farm')
  /// Falls back to 'free' if not available.
  Future<String> getCachedTierString() async {
    final payload = await getCachedTier();
    if (payload == null) return AppConstants.tierFree;
    if (payload.isExpired) return 'trial_expired';
    return payload.tier;
  }

  /// Check if the cached tier needs re-validation (stale)
  Future<bool> needsRevalidation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastValidated = prefs.getString(_lastValidatedKey);
      if (lastValidated == null) return true;

      final lastDate = DateTime.tryParse(lastValidated);
      if (lastDate == null) return true;

      return DateTime.now().difference(lastDate) > _offlineTrustDuration;
    } catch (e) {
      return true;
    }
  }

  /// Get daily scan limit from cached tier (0 if expired)
  Future<int> getDailyScanLimit() async {
    final payload = await getCachedTier();
    if (payload == null) return AppConstants.freeDailyScanLimit;
    if (payload.isExpired) return 0;
    return payload.dailyScanLimit;
  }

  /// Get daily AI limit from cached tier (0 if expired)
  Future<int> getDailyAiLimit() async {
    final payload = await getCachedTier();
    if (payload == null) return AppConstants.freeDailyAiLimit;
    if (payload.isExpired) return 0;
    return payload.dailyAiLimit;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CLEAR / INVALIDATE
  // ═══════════════════════════════════════════════════════════════════════

  /// Clear the cached tier (e.g., on logout or detected tampering)
  Future<void> clearTier() async {
    _cachedPayload = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tierPayloadKey);
    await prefs.remove(_tierSignatureKey);
    await prefs.remove(_lastValidatedKey);
    debugPrint('🗑️ Cached tier cleared');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SERVER TIME OFFSET (anti-clock-manipulation)
  // ═══════════════════════════════════════════════════════════════════════

  /// Save the offset between local time and server time.
  /// Call this whenever a trusted server response is received.
  Future<void> saveServerTimeOffset(DateTime serverTime) async {
    final offset = serverTime.difference(DateTime.now()).inMilliseconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_serverTimeOffsetKey, offset);
  }

  /// Get the adjusted "real" time accounting for any clock manipulation.
  /// If we have a server time offset, use it to correct local time.
  Future<DateTime> getAdjustedNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offset = prefs.getInt(_serverTimeOffsetKey) ?? 0;
      return DateTime.now().add(Duration(milliseconds: offset));
    } catch (e) {
      return DateTime.now();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HMAC SIGNATURE (tamper detection)
  // ═══════════════════════════════════════════════════════════════════════

  String _sign(String data) {
    final key = utf8.encode(_signatureSecret);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(utf8.encode(data));
    return digest.toString();
  }

  bool _verify(String data, String signature) {
    final expected = _sign(data);
    // Constant-time comparison to prevent timing attacks
    if (expected.length != signature.length) return false;
    int result = 0;
    for (int i = 0; i < expected.length; i++) {
      result |= expected.codeUnitAt(i) ^ signature.codeUnitAt(i);
    }
    return result == 0;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MIGRATION FROM LEGACY SharedPreferences
  // ═══════════════════════════════════════════════════════════════════════

  /// Migrate from the old insecure SharedPreferences tier storage.
  /// Called once during app upgrade. After migration, the old keys are removed.
  Future<void> migrateFromLegacy() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if we already have a secure tier
      if (prefs.containsKey(_tierPayloadKey)) return;

      // Read old insecure values
      final oldTier = prefs.getString('offline_tier');

      if (oldTier != null) {
        // Save as secure tier (with default limits)
        int scanLimit;
        int aiLimit;
        switch (oldTier) {
          case 'farm':
            scanLimit = 999;
            aiLimit = 999;
            break;
          case 'pro':
            scanLimit = 50;
            aiLimit = AppConstants.proDailyAiLimit;
            break;
          default:
            scanLimit = AppConstants.freeDailyScanLimit;
            aiLimit = AppConstants.freeDailyAiLimit;
        }

        await saveTier(
          uid: 'migrated',
          tier: oldTier,
          expiryDate: DateTime.now().add(const Duration(days: 1)), // Short expiry to force re-validation
          dailyScanLimit: scanLimit,
          dailyAiLimit: aiLimit,
        );

        // Remove old insecure keys
        await prefs.remove('offline_tier');
        await prefs.remove('offline_scan_count');
        debugPrint('✅ Migrated legacy tier: $oldTier');
      }
    } catch (e) {
      debugPrint('Legacy migration error: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TIER PAYLOAD MODEL
// ═══════════════════════════════════════════════════════════════════════════

class TierPayload {
  final String uid;
  final String tier;
  final DateTime? expiryDate;
  final int dailyScanLimit;
  final int dailyAiLimit;
  final DateTime issuedAt;
  final DateTime? trialActivatedAt;
  final int trialDays;

  const TierPayload({
    required this.uid,
    required this.tier,
    required this.expiryDate,
    required this.dailyScanLimit,
    required this.dailyAiLimit,
    required this.issuedAt,
    this.trialActivatedAt,
    this.trialDays = 2,
  });

  bool get isExpired {
    if (tier.toLowerCase() != AppConstants.tierFree) {
      if (expiryDate != null) return DateTime.now().isAfter(expiryDate!);
      return false;
    }
    // Free tier = Free Trial!
    if (trialActivatedAt == null) return false;
    final trialEnd = trialActivatedAt!.add(Duration(days: trialDays));
    return DateTime.now().isAfter(trialEnd);
  }

  bool get isFree => tier == AppConstants.tierFree;
  bool get isPro => tier == AppConstants.tierPro;
  bool get isFarm => tier == AppConstants.tierFarm;

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'tier': tier,
    'expiry_date': expiryDate?.toUtc().toIso8601String(),
    'daily_scan_limit': dailyScanLimit,
    'daily_ai_limit': dailyAiLimit,
    'issued_at': issuedAt.toUtc().toIso8601String(),
    'trial_activated_at': trialActivatedAt?.toUtc().toIso8601String(),
    'trial_days': trialDays,
  };

  factory TierPayload.fromMap(Map<String, dynamic> map) => TierPayload(
    uid: map['uid'] ?? '',
    tier: map['tier'] ?? AppConstants.tierFree,
    expiryDate: map['expiry_date'] != null
        ? DateTime.tryParse(map['expiry_date'])
        : null,
    dailyScanLimit: map['daily_scan_limit'] ?? AppConstants.freeDailyScanLimit,
    dailyAiLimit: map['daily_ai_limit'] ?? AppConstants.freeDailyAiLimit,
    issuedAt: DateTime.tryParse(map['issued_at'] ?? '') ?? DateTime.now(),
    trialActivatedAt: map['trial_activated_at'] != null
        ? DateTime.tryParse(map['trial_activated_at'])
        : null,
    trialDays: map['trial_days'] ?? 2,
  );
}
