// lib/services/scan_limiter.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/app_user.dart';
import '../providers/app_config_provider.dart';
import 'supabase_service.dart';
import 'sync_service.dart';
import 'trial_service.dart';
import 'secure_tier_service.dart';

class ScanLimiter {
  final SupabaseService _supabase = SupabaseService();
  final SyncService _syncService = SyncService();

  // ─── Fast Synchronous / Reactive Computation ──────────────────────────────

  static ScanLimitResult computeScanLimit(AppUser? appUser, AppConfig config) {
    if (appUser == null) {
      return const ScanLimitResult(canScan: false, reason: 'Not logged in');
    }

    String tier = appUser.subscriptionTier;
    if (tier != 'free' && appUser.subscriptionExpiry != null && appUser.subscriptionExpiry!.isBefore(DateTime.now())) {
      tier = 'free';
    }

    final trialInfo = TrialService.getTrialInfo(appUser, trialDays: config.trialDays);

    if (tier == 'free' && config.trialEnabled) {
      if (trialInfo.isNotStarted) {
        return ScanLimitResult(
          canScan: false,
          remaining: 0,
          limit: 0,
          tier: tier,
          reason: 'Activate your ${config.trialDays}-Day Trial to start scanning.',
          isExpired: false,
          isNotStarted: true,
        );
      }
      if (trialInfo.isExpired) {
        return ScanLimitResult(
          canScan: false,
          remaining: 0,
          limit: 0,
          tier: tier,
          reason: 'Your trial has ended. Please upgrade to Tier 1 (Pro) or Farm Pack to continue scanning.',
          isExpired: true,
          isNotStarted: false,
        );
      }
    }

    int limit;
    String effectiveTier = tier;
    if (tier == 'farm') {
      limit = config.farmScanLimit;
    } else if (tier == 'pro') {
      limit = config.proScanLimit;
    } else if (trialInfo.isActive) {
      // Trial benefits are identical to Tier 1 (Pro)
      limit = config.proScanLimit;
      effectiveTier = 'pro';
    } else {
      limit = config.freeScanLimit;
    }

    // -1 or <= 0 indicates unlimited
    if (limit < 0 || (tier == 'farm' && limit <= 0)) {
      return ScanLimitResult(
        canScan: true,
        remaining: -1,
        limit: -1,
        tier: effectiveTier,
        isExpired: false,
      );
    }

    final todayCount = appUser.todayScans;
    final remaining = limit - todayCount;

    return ScanLimitResult(
      canScan: remaining > 0,
      remaining: remaining < 0 ? 0 : remaining,
      limit: limit,
      tier: effectiveTier,
      reason: remaining <= 0 ? 'Daily limit reached ($limit scans/day on ${trialInfo.isActive ? "Pro Trial" : effectiveTier} plan)' : null,
      isExpired: false,
      isNotStarted: false,
    );
  }

  static AiLimitResult computeAiLimit(AppUser? appUser, AppConfig config) {
    if (appUser == null) {
      return const AiLimitResult(canUse: false, reason: 'Not logged in');
    }

    String tier = appUser.subscriptionTier;
    if (tier != 'free' && appUser.subscriptionExpiry != null && appUser.subscriptionExpiry!.isBefore(DateTime.now())) {
      tier = 'free';
    }

    final trialInfo = TrialService.getTrialInfo(appUser, trialDays: config.trialDays);

    if (tier == 'free' && config.trialEnabled) {
      if (trialInfo.isNotStarted) {
        return AiLimitResult(
          canUse: false,
          remaining: 0,
          limit: 0,
          tier: tier,
          reason: 'Activate your ${config.trialDays}-Day Trial to start chatting.',
          isExpired: false,
          isNotStarted: true,
        );
      }
      if (trialInfo.isExpired) {
        return AiLimitResult(
          canUse: false,
          remaining: 0,
          limit: 0,
          tier: tier,
          reason: 'Your trial has ended. Please upgrade to Tier 1 (Pro) or Farm Pack to continue chatting.',
          isExpired: true,
          isNotStarted: false,
        );
      }
    }

    int limit;
    String effectiveTier = tier;
    if (tier == 'farm') {
      limit = config.farmAiLimit;
    } else if (tier == 'pro') {
      limit = config.proAiLimit;
    } else if (trialInfo.isActive) {
      // Trial AI benefits are identical to Tier 1 (Pro)
      limit = config.proAiLimit;
      effectiveTier = 'pro';
    } else {
      limit = config.freeAiLimit;
    }

    if (limit < 0 || (tier == 'farm' && limit <= 0)) {
      return AiLimitResult(
        canUse: true,
        remaining: -1,
        limit: -1,
        tier: effectiveTier,
        isExpired: false,
      );
    }

    final todayAi = appUser.todayAi;
    final remaining = limit - todayAi;

    return AiLimitResult(
      canUse: remaining > 0,
      remaining: remaining < 0 ? 0 : remaining,
      limit: limit,
      tier: effectiveTier,
      reason: remaining <= 0 ? 'Daily AI limit reached ($limit queries/day on ${trialInfo.isActive ? "Pro Trial" : effectiveTier} plan)' : null,
      isExpired: false,
      isNotStarted: false,
    );
  }

  // ─── Scan limit ────────────────────────────────────────────────────────────

  Future<ScanLimitResult> checkScanLimit() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const ScanLimitResult(canScan: false, reason: 'Not logged in');

    final isOnline = await _syncService.isOnline();
    if (isOnline) {
      final appUser = await _supabase.getUser(user.id);
      final config = await _supabase.fetchAppConfig();
      return computeScanLimit(appUser, config);
    }

    // ── SECURE OFFLINE TIER CHECK ──
    // Uses HMAC-signed cached tier instead of plain SharedPreferences
    final secureTier = SecureTierService();
    final tierString = await secureTier.getCachedTierString();
    final limit = await secureTier.getDailyScanLimit();

    final prefs = await SharedPreferences.getInstance();
    final todayCount = _getLocalScanCount(prefs);

    if (limit < 0) {
      return ScanLimitResult(canScan: true, remaining: -1, limit: -1, tier: tierString, isExpired: false, isNotStarted: false);
    }

    final remaining = limit - todayCount;
    return ScanLimitResult(
      canScan: remaining > 0,
      remaining: remaining < 0 ? 0 : remaining,
      limit: limit,
      tier: tierString,
      reason: remaining <= 0 ? 'Offline limit reached ($limit scans/day)' : null,
      isExpired: false,
      isNotStarted: false,
    );
  }

  // ─── AI limit (NOW WORKS OFFLINE with same limits as online) ────────────────

  Future<AiLimitResult> checkAiLimit() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const AiLimitResult(canUse: false, reason: 'Not logged in');

    final isOnline = await _syncService.isOnline();
    if (isOnline) {
      final appUser = await _supabase.getUser(user.id);
      final config = await _supabase.fetchAppConfig();
      return computeAiLimit(appUser, config);
    }

    // ── OFFLINE AI LIMIT — same daily limits as online ──
    // Uses local LLM instead of Groq, with the same tier-based daily limits.
    final secureTier = SecureTierService();
    final tierString = await secureTier.getCachedTierString();
    final limit = await secureTier.getDailyAiLimit();

    final prefs = await SharedPreferences.getInstance();
    final todayAiCount = _getLocalAiCount(prefs);

    if (limit < 0) {
      return AiLimitResult(
        canUse: true, remaining: -1, limit: -1, tier: tierString,
        isExpired: false, isNotStarted: false,
      );
    }

    final remaining = limit - todayAiCount;
    return AiLimitResult(
      canUse: remaining > 0,
      remaining: remaining < 0 ? 0 : remaining,
      limit: limit,
      tier: tierString,
      reason: remaining <= 0
          ? 'Offline AI limit reached ($limit chats/day on $tierString plan)'
          : null,
      isExpired: false,
      isNotStarted: false,
    );
  }

  // ─── Local Count Helpers ───────────────────────────────────────────────────

  int _getLocalScanCount(SharedPreferences prefs) {
    final lastDate = prefs.getString('offline_scan_date');
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    if (lastDate != today) {
      return 0;
    }
    return prefs.getInt('offline_scan_count') ?? 0;
  }

  int _getLocalAiCount(SharedPreferences prefs) {
    final lastDate = prefs.getString('offline_ai_date');
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (lastDate != today) {
      return 0;
    }
    return prefs.getInt('offline_ai_count') ?? 0;
  }

  Future<void> _updateLocalScanCount(SharedPreferences prefs, int count) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    await prefs.setString('offline_scan_date', today);
    await prefs.setInt('offline_scan_count', count);
  }

  Future<void> incrementLocalScanCount() async {
    final prefs = await SharedPreferences.getInstance();
    int current = _getLocalScanCount(prefs);
    await _updateLocalScanCount(prefs, current + 1);
  }

  Future<void> incrementLocalAiCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastDate = prefs.getString('offline_ai_date');
    int current = (lastDate == today) ? (prefs.getInt('offline_ai_count') ?? 0) : 0;
    await prefs.setString('offline_ai_date', today);
    await prefs.setInt('offline_ai_count', current + 1);
  }
}

class ScanLimitResult {
  final bool canScan;
  final int remaining;
  final int limit;
  final String tier;
  final String? reason;
  final bool isExpired;
  final bool isNotStarted;

  const ScanLimitResult({
    required this.canScan,
    this.remaining = 0,
    this.limit = AppConstants.freeDailyScanLimit,
    this.tier = 'free',
    this.reason,
    this.isExpired = false,
    this.isNotStarted = false,
  });

  bool get isUnlimited => (limit < 0 || remaining == -1) && !isNotStarted && !isExpired;

  String get displayText {
    if (isNotStarted) return 'Trial Needed';
    if (isExpired) return 'Trial Ended';
    if (isUnlimited) return 'Unlimited';
    return '$remaining / $limit left';
  }
}

class AiLimitResult {
  final bool canUse;
  final int remaining;
  final int limit;
  final String tier;
  final String? reason;
  final bool isExpired;
  final bool isNotStarted;

  const AiLimitResult({
    required this.canUse,
    this.remaining = 0,
    this.limit = AppConstants.freeDailyAiLimit,
    this.tier = 'free',
    this.reason,
    this.isExpired = false,
    this.isNotStarted = false,
  });

  bool get isUnlimited => (limit < 0 || remaining == -1) && !isNotStarted && !isExpired;

  String get displayText {
    if (isNotStarted) return 'Trial Needed';
    if (isExpired) return 'Trial Ended';
    if (isUnlimited) return 'Unlimited';
    return '$remaining / $limit left';
  }
}
