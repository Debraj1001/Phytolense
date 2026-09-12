// lib/services/supabase_admin_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';
import '../models/app_config.dart';
import '../models/app_user.dart';
import '../models/scan_item.dart';

class SupabaseAdminService {
  static final SupabaseAdminService _instance = SupabaseAdminService._internal();
  factory SupabaseAdminService() => _instance;
  SupabaseAdminService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  // ─── APP CONFIG ──────────────────────────────────────────────────────────

  Future<AppConfig> getAppConfig() async {
    try {
      final res = await _client
          .from(AppConstants.tableAppConfig)
          .select()
          .limit(1)
          .maybeSingle();

      if (res != null) {
        return AppConfig.fromMap(res);
      }
    } catch (e) {
      debugPrint('Admin error fetching app config: $e');
    }
    return AppConfig(updatedAt: DateTime.now());
  }

  Stream<AppConfig> streamAppConfig() {
    return _client
        .from(AppConstants.tableAppConfig)
        .stream(primaryKey: ['id'])
        .map((list) {
          if (list.isNotEmpty) {
            return AppConfig.fromMap(list.first);
          }
          return AppConfig(updatedAt: DateTime.now());
        });
  }

  Future<void> updateAppConfig(AppConfig config) async {
    final map = config.toMap();
    // Use upsert to handle both insert and update for id = 1
    await _client.from(AppConstants.tableAppConfig).upsert(map);
  }

  // ─── USERS MANAGEMENT ───────────────────────────────────────────────────

  Future<List<AppUser>> getUsers({String? search, String? tierFilter, int limit = 100}) async {
    var query = _client.from(AppConstants.tableUsers).select();

    if (tierFilter != null && tierFilter.isNotEmpty && tierFilter != 'all') {
      query = query.eq('subscription_tier', tierFilter);
    }

    if (search != null && search.trim().isNotEmpty) {
      query = query.or('display_name.ilike.%$search%,email.ilike.%$search%');
    }

    final res = await query.order('created_at', ascending: false).limit(limit);
    return (res as List).map((m) => AppUser.fromMap(m)).toList();
  }

  Stream<List<AppUser>> streamUsers({int limit = 100}) {
    return _client
        .from(AppConstants.tableUsers)
        .stream(primaryKey: ['uid'])
        .order('created_at', ascending: false)
        .limit(limit)
        .map((list) => list.map((m) => AppUser.fromMap(m)).toList());
  }

  Future<void> updateUserTier(String uid, String tier, {int days = 30}) async {
    final expiry = tier == AppConstants.tierFree 
        ? null 
        : DateTime.now().add(Duration(days: days)).toIso8601String();

    await _client.from(AppConstants.tableUsers).update({
      'subscription_tier': tier,
      'subscription_expiry': expiry,
    }).eq('uid', uid);
  }

  Future<void> toggleUserBan(String uid, bool banned) async {
    await _client.from(AppConstants.tableUsers).update({
      'banned': banned,
    }).eq('uid', uid);
  }

  Future<void> deleteUser(String uid) async {
    await _client.from(AppConstants.tableUsers).delete().eq('uid', uid);
  }

  // ─── SCANS MODERATION ────────────────────────────────────────────────────

  Future<List<ScanItem>> getRecentScans({int limit = 50}) async {
    final res = await _client
        .from(AppConstants.tableScanHistory)
        .select()
        .order('scanned_at', ascending: false)
        .limit(limit);

    return (res as List).map((m) => ScanItem.fromMap(m)).toList();
  }

  Stream<List<ScanItem>> streamRecentScans({int limit = 50}) {
    return _client
        .from(AppConstants.tableScanHistory)
        .stream(primaryKey: ['id'])
        .order('scanned_at', ascending: false)
        .limit(limit)
        .map((list) => list.map((m) => ScanItem.fromMap(m)).toList());
  }

  Future<void> deleteScan(String id) async {
    await _client.from(AppConstants.tableScanHistory).delete().eq('id', id);
  }

  // ─── GLOBAL ANALYTICS ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getGlobalStats() async {
    try {
      final totalUsersRes = await _client.from(AppConstants.tableUsers).select().count(CountOption.exact);
      final totalScansRes = await _client.from(AppConstants.tableScanHistory).select().count(CountOption.exact);
      
      final proUsersRes = await _client.from(AppConstants.tableUsers).select().eq('subscription_tier', 'pro').count(CountOption.exact);
      final farmUsersRes = await _client.from(AppConstants.tableUsers).select().eq('subscription_tier', 'farm').count(CountOption.exact);

      final now = DateTime.now();
      final startOfTodayUtc = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final todayScansRes = await _client
          .from(AppConstants.tableScanHistory)
          .select()
          .gte('scanned_at', startOfTodayUtc)
          .count(CountOption.exact);

      return {
        'totalUsers': totalUsersRes.count,
        'totalScans': totalScansRes.count,
        'activePro': proUsersRes.count,
        'activeFarm': farmUsersRes.count,
        'todayScans': todayScansRes.count,
      };
    } catch (e) {
      debugPrint('Admin error fetching global stats: $e');
      return {
        'totalUsers': 0,
        'totalScans': 0,
        'activePro': 0,
        'activeFarm': 0,
        'todayScans': 0,
      };
    }
  }
}
