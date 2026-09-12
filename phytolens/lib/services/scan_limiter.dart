// lib/services/scan_limiter.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/app_user.dart';
import '../providers/app_config_provider.dart';
import 'supabase_service.dart';
import 'sync_service.dart';
import 'trial_service.dart';

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

    if (tier == 'free') {
      if (trialInfo.isNotStarted) {
        return ScanLimitResult(
          canScan: false,
          remaining: 0,
          limit: 0,
          tier: tier,
          reason: 'Activate your 2-Day Trial to start scanning.',
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
          reason: 'Your trial has ended. Please upgrade to continue scanning.',
          isExpired: true,
          isNotStarted: false,
        );
      }
    }

    int limit;
    if (tier == 'farm') {
      limit = config.farmScanLimit;
    } else if (tier == 'pro') {
      limit = config.proScanLimit;
    } else {
      limit = config.freeScanLimit;
    }

    // -1 or <= 0 indicates unlimited
    if (limit <= 0) {
      return ScanLimitResult(
        canScan: true,
        remaining: -1,
        limit: -1,
        tier: tier,
        isExpired: false,
      );
    }

    final todayCount = appUser.todayScans;
    final remaining = limit - todayCount;

    return ScanLimitResult(
      canScan: remaining > 0,
      remaining: remaining < 0 ? 0 : remaining,
      limit: limit,
      tier: tier,
      reason: remaining <= 0 ? 'Daily limit reached ($limit scans/day on $tier plan)' : null,
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

    if (tier == 'free') {
      if (trialInfo.isNotStarted) {
        return AiLimitResult(
          canUse: false,
          remaining: 0,
          limit: 0,
          tier: tier,
          reason: 'Activate your 2-Day Trial to start chatting.',
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
          reason: 'Your trial has ended. Please upgrade to continue chatting.',
          isExpired: true,
          isNotStarted: false,
        );
      }
    }

    int limit;
    if (tier == 'farm') {
      limit = config.farmAiLimit;
    } else if (tier == 'pro') {
      limit = config.proAiLimit;
    } else {
      limit = config.freeAiLimit;
    }

    if (limit <= 0) {
      return AiLimitResult(
        canUse: true,
        remaining: -1,
        limit: -1,
        tier: tier,
        isExpired: false,
      );
    }

    final todayAi = appUser.todayAi;
    final remaining = limit - todayAi;

    return AiLimitResult(
      canUse: remaining > 0,
      remaining: remaining < 0 ? 0 : remaining,
      limit: limit,
      tier: tier,
      reason: remaining <= 0 ? 'Daily AI limit reached ($limit queries/day on $tier plan)' : null,
      isExpired: false,
      isNotStarted: false,
    );
  }

  // ─── Scan limit ────────────────────────────────────────────────────────────

  Future<ScanLimitResult> checkScanLimit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const ScanLimitResult(canScan: false, reason: 'Not logged in');

    final isOnline = await _syncService.isOnline();
    if (isOnline) {
      final appUser = await _supabase.getUser(user.uid);
      final config = await _supabase.fetchAppConfig();
      return computeScanLimit(appUser, config);
    }

    final prefs = await SharedPreferences.getInstance();
    final tier = prefs.getString('offline_tier') ?? 'free';
    final todayCount = _getLocalScanCount(prefs);
    final limit = tier == 'farm' ? 100 : (tier == 'pro' ? 50 : AppConstants.freeDailyScanLimit);

    if (limit <= 0) {
      return ScanLimitResult(canScan: true, remaining: -1, limit: -1, tier: tier, isExpired: false, isNotStarted: false);
    }

    final remaining = limit - todayCount;
    return ScanLimitResult(
      canScan: remaining > 0,
      remaining: remaining < 0 ? 0 : remaining,
      limit: limit,
      tier: tier,
      reason: remaining <= 0 ? 'Offline limit reached ($limit scans/day)' : null,
      isExpired: false,
      isNotStarted: false,
    );
  }

  // ─── AI limit ──────────────────────────────────────────────────────────────

  Future<AiLimitResult> checkAiLimit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const AiLimitResult(canUse: false, reason: 'Not logged in');

    final isOnline = await _syncService.isOnline();
    if (!isOnline) {
      return const AiLimitResult(canUse: false, reason: 'Internet connection required for AI Chat');
    }

    final appUser = await _supabase.getUser(user.uid);
    final config = await _supabase.fetchAppConfig();
    return computeAiLimit(appUser, config);
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
}
