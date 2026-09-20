// lib/services/supabase_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';
import '../models/scan_result.dart';
import '../models/plant.dart';
import '../models/app_config.dart';
import '../config/constants.dart';
import '../data/local_database.dart';
import '../data/chat_database.dart';

class SupabaseService {
  SupabaseClient get _client => Supabase.instance.client;

  // ─── Users ───────────────────────────────────────────────────────────────

  Future<void> upsertUser(AppUser user) async {
    await _client.from(AppConstants.tableUsers).upsert(user.toMap());
  }

  Future<AppUser?> getUser(String uid) async {
    final res = await _client
        .from(AppConstants.tableUsers)
        .select()
        .eq('uid', uid)
        .maybeSingle();
        
    if (res != null) {
      final user = AppUser.fromMap(res);
      // Validate subscription window ONLY if an expiry date is set
      if (user.subscriptionTier != AppConstants.tierFree) {
        if (user.subscriptionExpiry != null && DateTime.now().isAfter(user.subscriptionExpiry!)) {
          // Subscription expired, revert to free
          await updateSubscription(uid, AppConstants.tierFree);
          return user.copyWith(
            subscriptionTier: AppConstants.tierFree,
            subscriptionExpiry: null,
          );
        }
      }
      return user;
    }
    return null;
  }

  Stream<AppUser?> streamUser(String uid) {
    return _client
        .from(AppConstants.tableUsers)
        .stream(primaryKey: ['uid'])
        .eq('uid', uid)
        .map((list) => list.isNotEmpty ? AppUser.fromMap(list.first) : null);
  }

  Future<List<AppUser>> getAllUsers({int page = 0, int limit = 20}) async {
    final res = await _client
        .from(AppConstants.tableUsers)
        .select()
        .order('created_at', ascending: false)
        .range(page * limit, (page + 1) * limit - 1);
    return res.map<AppUser>((m) => AppUser.fromMap(m)).toList();
  }

  Stream<List<AppUser>> streamAllUsers({int limit = 100}) {
    return _client
        .from(AppConstants.tableUsers)
        .stream(primaryKey: ['uid'])
        .order('created_at', ascending: false)
        .limit(limit)
        .map((list) => list.map((m) => AppUser.fromMap(m)).toList());
  }

  Future<void> updateUser(String uid, Map<String, dynamic> updates) async {
    await _client.from(AppConstants.tableUsers).update(updates).eq('uid', uid);
  }

  Future<void> deleteUser(String uid) async {
    try {
      await _client.from(AppConstants.tableUsers).delete().eq('uid', uid);
      await _client.from(AppConstants.tableScanHistory).delete().eq('user_id', uid);
      await _client.from(AppConstants.tableAiUsage).delete().eq('user_id', uid);
    } catch (e) {
      debugPrint('Cloud tables delete user error: $e');
    }
    try {
      await LocalDatabase().clearAllUserData(uid);
      await ChatDatabase().clearAllUserData(uid);
    } catch (e) {
      debugPrint('Local SQLite clear user error: $e');
    }
  }

  Future<void> incrementScanCounters(String userId) async {
    try {
      final user = await getUser(userId);
      if (user == null) return;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final newDaily = (user.lastScanDate == today) ? user.dailyScanCount + 1 : 1;
      final updates = <String, dynamic>{
        'scan_count': user.scanCount + 1,
        'daily_scan_count': newDaily,
        'last_scan_date': today,
      };
      if (user.subscriptionTier == 'free' && user.trialActivatedAt == null) {
        updates['trial_activated_at'] = DateTime.now().toIso8601String();
      }
      await _client.from(AppConstants.tableUsers).update(updates).eq('uid', userId);
    } catch (_) {}
  }

  Future<void> decrementScanCounters(String userId) async {
    try {
      final user = await getUser(userId);
      if (user == null) return;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final newDaily = (user.lastScanDate == today && user.dailyScanCount > 0)
          ? user.dailyScanCount - 1
          : 0;
      final newTotal = (user.scanCount > 0) ? user.scanCount - 1 : 0;
      await _client.from(AppConstants.tableUsers).update({
        'scan_count': newTotal,
        'daily_scan_count': newDaily,
      }).eq('uid', userId);
    } catch (_) {}
  }

  Future<void> incrementAiCounters(String userId) async {
    try {
      final user = await getUser(userId);
      if (user == null) return;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final newDaily = (user.lastAiDate == today) ? user.dailyAiCount + 1 : 1;
      final updates = <String, dynamic>{
        'daily_ai_count': newDaily,
        'last_ai_date': today,
      };
      if (user.subscriptionTier == 'free' && user.trialActivatedAt == null) {
        updates['trial_activated_at'] = DateTime.now().toIso8601String();
      }
      await _client.from(AppConstants.tableUsers).update(updates).eq('uid', userId);
    } catch (_) {}
  }

  // ─── Scan History ─────────────────────────────────────────────────────────

  Future<ScanResult> saveScan(ScanResult scan) async {
    final res = await _client
        .from(AppConstants.tableScanHistory)
        .insert(scan.toSupabaseMap())
        .select()
        .single();
    final saved = ScanResult.fromMap(res);

    // 1. Upsert into secondary 'scans' table using exact matching UUID
    try {
      await _client.from('scans').upsert(saved.toSupabaseMap(includeId: true));
    } catch (e) {
      debugPrint('Secondary scans sync notice: $e');
    }

    // 2. If this scan belongs to a specific plant in the garden, update the plant
    if (saved.plantId != null && saved.plantId!.isNotEmpty) {
      try {
        final plantUpdates = <String, dynamic>{
          'latest_health_score': saved.healthScore,
          'latest_disease': saved.diseaseName,
          'last_scanned_at': saved.scannedAt.toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
        if (saved.imageUrl != null && saved.imageUrl!.isNotEmpty) {
          plantUpdates['image_url'] = saved.imageUrl;
        }
        await _client.from('plants').update(plantUpdates).eq('id', saved.plantId!);
      } catch (e) {
        debugPrint('Error updating plant health from scan: $e');
      }
    }

    if (scan.userId.isNotEmpty) {
      await incrementScanCounters(scan.userId);
    }
    return saved;
  }

  Future<List<ScanResult>> getPlantScans(String plantId, {int limit = 30}) async {
    final res = await _client
        .from(AppConstants.tableScanHistory)
        .select()
        .eq('plant_id', plantId)
        .order('scanned_at', ascending: false)
        .limit(limit);
    return res.map<ScanResult>((m) => ScanResult.fromMap(m)).toList();
  }

  Stream<List<ScanResult>> streamPlantScans(String plantId, {int limit = 30}) {
    return _client
        .from(AppConstants.tableScanHistory)
        .stream(primaryKey: ['id'])
        .eq('plant_id', plantId)
        .order('scanned_at', ascending: false)
        .limit(limit)
        .map((list) => list.map((m) => ScanResult.fromMap(m)).toList());
  }

  Future<List<ScanResult>> getUserScans(String userId, {int limit = 50}) async {
    final res = await _client
        .from(AppConstants.tableScanHistory)
        .select()
        .eq('user_id', userId)
        .order('scanned_at', ascending: false)
        .limit(limit);
    return res.map<ScanResult>((m) => ScanResult.fromMap(m)).toList();
  }

  Stream<List<ScanResult>> streamUserScans(String userId, {int limit = 50}) {
    return _client
        .from(AppConstants.tableScanHistory)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('scanned_at', ascending: false)
        .limit(limit)
        .map((list) => list.map((m) => ScanResult.fromMap(m)).toList());
  }

  Future<List<ScanResult>> getAllScans({int limit = 100}) async {
    final res = await _client
        .from(AppConstants.tableScanHistory)
        .select()
        .order('scanned_at', ascending: false)
        .limit(limit);
    return res.map<ScanResult>((m) => ScanResult.fromMap(m)).toList();
  }

  Stream<List<ScanResult>> streamAllScans({int limit = 100}) {
    return _client
        .from(AppConstants.tableScanHistory)
        .stream(primaryKey: ['id'])
        .order('scanned_at', ascending: false)
        .limit(limit)
        .map((list) => list.map((m) => ScanResult.fromMap(m)).toList());
  }

  Future<int> getTotalScanCount(String userId) async {
    final res = await _client
        .from(AppConstants.tableScanHistory)
        .select()
        .eq('user_id', userId)
        .count(CountOption.exact);
    return res.count;
  }

  Future<int> getTodayScanCount(String userId) async {
    final now = DateTime.now();
    final startOfLocalDayUtc = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    final res = await _client
        .from(AppConstants.tableScanHistory)
        .select()
        .eq('user_id', userId)
        .gte('scanned_at', startOfLocalDayUtc)
        .count(CountOption.exact);
    return res.count;
  }

  Future<Map<String, dynamic>> getScanStats(String userId) async {
    final scans = await getUserScans(userId);
    final total = await getTotalScanCount(userId);
    final today = await getTodayScanCount(userId);
    final now = DateTime.now();
    final thisWeek = scans.where((s) => now.difference(s.scannedAt).inDays < 7).length;
    final avgScore = scans.isEmpty ? 0 : scans.map((s) => s.healthScore).reduce((a, b) => a + b) ~/ scans.length;
    final diseaseCount = scans.where((s) => !s.isHealthy).length;
    return {
      'total': total,
      'today': today,
      'thisWeek': thisWeek,
      'avgScore': avgScore,
      'diseaseCount': diseaseCount,
    };
  }


  Future<void> updateScan(String scanId, Map<String, dynamic> updates) async {
    await _client.from(AppConstants.tableScanHistory).update(updates).eq('id', scanId);
    try {
      await _client.from('scans').update(updates).eq('id', scanId);
    } catch (_) {}
  }

  Future<void> deleteScan(String scanId, {String? userId}) async {
    await _client.from(AppConstants.tableScanHistory).delete().eq('id', scanId);
    try {
      await _client.from('scans').delete().eq('id', scanId);
    } catch (_) {}
    if (userId != null && userId.isNotEmpty) {
      await decrementScanCounters(userId);
    }
  }

  Future<void> flagScan(String scanId, bool flagged) async {
    await _client
        .from(AppConstants.tableScanHistory)
        .update({'flagged': flagged})
        .eq('id', scanId);
  }

  // ─── AI Usage ─────────────────────────────────────────────────────────────

  Future<int> getTodayAiUsage(String userId) async {
    final now = DateTime.now();
    final startOfLocalDayUtc = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    final res = await _client
        .from(AppConstants.tableAiUsage)
        .select()
        .eq('user_id', userId)
        .gte('used_at', startOfLocalDayUtc)
        .count(CountOption.exact);
    return res.count;
  }

  Future<void> recordAiUsage(String userId, String feature, {int tokensUsed = 0}) async {
    await _client.from(AppConstants.tableAiUsage).insert({
      'user_id': userId,
      'feature': feature,
      'tokens_used': tokensUsed,
      'used_at': DateTime.now().toUtc().toIso8601String(),
    });
    await incrementAiCounters(userId);
  }

  // ─── Payments ─────────────────────────────────────────────────────────────

  Future<void> savePayment({
    required String userId,
    required int amount,
    required String plan,
    required String razorpayPaymentId,
  }) async {
    await _client.from(AppConstants.tablePayments).insert({
      'user_id': userId,
      'amount': amount,
      'plan': plan,
      'razorpay_payment_id': razorpayPaymentId,
      'status': 'success',
      'paid_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAllPayments() async {
    return await _client
        .from(AppConstants.tablePayments)
        .select()
        .order('paid_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> streamAllPayments({int limit = 100}) {
    return _client
        .from(AppConstants.tablePayments)
        .stream(primaryKey: ['id']) // Ensure 'id' is a primary key on this table
        .order('paid_at', ascending: false)
        .limit(limit);
  }

  Future<int> getMRR() async {
    final subs = await _client
        .from(AppConstants.tableUsers)
        .select('subscription_tier')
        .neq('subscription_tier', 'free');
    int mrr = 0;
    for (final sub in subs) {
      if (sub['subscription_tier'] == 'pro') mrr += 49;
      if (sub['subscription_tier'] == 'farm') mrr += 199;
    }
    return mrr;
  }

  // ─── Subscriptions & Trials ───────────────────────────────────────────────

  Future<void> activateTrial(String userId) async {
    final updates = <String, dynamic>{
      'trial_activated_at': DateTime.now().toIso8601String(),
    };
    await _client
        .from(AppConstants.tableUsers)
        .update(updates)
        .eq('uid', userId);
  }

  Future<void> updateSubscription(String userId, String tier, {int days = 30, String? razorpaySubscriptionId}) async {
    final expiry = tier == 'free'
        ? null
        : DateTime.now().add(Duration(days: days)).toUtc().toIso8601String();
    final updates = <String, dynamic>{
      'subscription_tier': tier,
      'subscription_expiry': expiry,
    };
    await _client
        .from(AppConstants.tableUsers)
        .update(updates)
        .eq('uid', userId);

    // Sync active tier to subscriptions history table
    try {
      await _client.from('subscriptions').insert({
        'user_id': userId,
        'plan_id': tier,
        'status': tier == 'free' ? 'inactive' : 'active',
        'starts_at': DateTime.now().toUtc().toIso8601String(),
        'expires_at': expiry,
        'razorpay_subscription_id': razorpaySubscriptionId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Notice: subscriptions table sync: $e');
    }
  }

  Future<void> updateAvatar(String userId, String avatarUrl) async {
    await _client
        .from(AppConstants.tableUsers)
        .update({'avatar_url': avatarUrl})
        .eq('uid', userId);
  }

  Future<void> updateUserProfile(String userId, {
    String? displayName,
    String? avatarUrl,
    String? phone,
    String? location,
    String? bio,
    String? gardenType,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (phone != null) updates['phone'] = phone;
    if (location != null) updates['location'] = location;
    if (bio != null) updates['bio'] = bio;
    if (gardenType != null) updates['garden_type'] = gardenType;

    if (updates.isNotEmpty) {
      await _client
          .from(AppConstants.tableUsers)
          .update(updates)
          .eq('uid', userId);
    }
  }

  Future<void> grantFreeAccess(String userId, String tier) async {
    await updateSubscription(userId, tier);
  }

  // ─── Storage ──────────────────────────────────────────────────────────────

  Future<String?> uploadImage(File file, String userId) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$userId/$fileName';
      
      await _client.storage.from('scans').upload(
        path,
        file,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );
      return _client.storage.from('scans').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading image to Supabase Storage: $e');
      return null;
    }
  }

  Future<String?> uploadAvatar(File file, String userId) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$userId/$fileName';
      
      await _client.storage.from('avatars').upload(
        path,
        file,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );
      return _client.storage.from('avatars').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading avatar to Supabase Storage: $e');
      return null;
    }
  }

  // ─── App Config ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getAppConfig() async {
    try {
      final res = await _client
          .from(AppConstants.tableAppConfig)
          .select()
          .limit(1)
          .maybeSingle();
      return res ?? {};
    } catch (_) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getPlans() async {
    try {
      final res = await _client.from('plans').select();
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> streamPlans() {
    return _client
        .from('plans')
        .stream(primaryKey: ['id'])
        .map((list) => List<Map<String, dynamic>>.from(list));
  }

  Future<AppConfig> fetchAppConfig() async {
    try {
      final plans = await getPlans();
      final configMap = await getAppConfig();
      return AppConfig.fromPlansAndConfig(plans, configMap);
    } catch (_) {
      return const AppConfig();
    }
  }

  Stream<Map<String, dynamic>> streamAppConfig() {
    return _client
        .from(AppConstants.tableAppConfig)
        .stream(primaryKey: ['id'])
        .map((list) => list.isNotEmpty ? list.first : <String, dynamic>{});
  }

  Future<void> updateAppConfig(Map<String, dynamic> updates) async {
    await _client
        .from(AppConstants.tableAppConfig)
        .update(updates)
        .eq('id', 1);
  }

  // Admin features have been moved to the Phytolens Admin App.

  // ─── Garden ───────────────────────────────────────────────────────────────

  Future<List<Plant>> getGarden(String userId) async {
    try {
      final res = await _client
          .from('plants')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return res.map<Plant>((m) => Plant.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  Stream<List<Plant>> streamGarden(String userId) {
    return _client
        .from('plants')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((list) => list.map((m) => Plant.fromMap(m)).toList());
  }

  Future<Plant> addPlant(
    String userId,
    String name,
    String plantType, {
    String? imageUrl,
    int latestHealthScore = 0,
    String? latestDisease,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final res = await _client.from('plants').insert({
      'user_id': userId,
      'name': name,
      'type': plantType,
      'plant_type': plantType,
      'image_url': imageUrl,
      'latest_health_score': latestHealthScore,
      'latest_disease': latestDisease,
      'added_at': now,
      'created_at': now,
      'updated_at': now,
    }).select().single();
    return Plant.fromMap(res);
  }

  Future<void> updatePlant(String plantId, Map<String, dynamic> updates) async {
    await _client.from('plants').update(updates).eq('id', plantId);
  }

  Future<void> deletePlant(String plantId) async {
    await _client.from('plants').delete().eq('id', plantId);
  }
}
