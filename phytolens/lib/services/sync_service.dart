// lib/services/sync_service.dart
//
// Offline-first sync engine.
// Saves scans to local SQLite DB first, then syncs to Supabase when online.
// On reconnect, upgrades offline remedies via Groq cloud AI.

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../data/local_database.dart';
import '../models/scan_result.dart';
import 'supabase_service.dart';
import 'gamification_service.dart';
import 'groq_service.dart';
import 'secure_tier_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final _supabase = SupabaseService();
  final _gamification = GamificationService();
  final _localDb = LocalDatabase();
  bool _isSyncing = false;
  
  // Expose stream for UI
  Stream<List<ConnectivityResult>> get onConnectivityChanged => Connectivity().onConnectivityChanged;

  void initialize() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.mobile) || 
          results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet)) {
        syncOfflineData();
      }
    });
  }

  Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.mobile) || 
           results.contains(ConnectivityResult.wifi) ||
           results.contains(ConnectivityResult.ethernet);
  }

  /// Save a scan locally (always called first, even when online)
  Future<void> saveScanLocally(ScanResult scan, {bool synced = false}) async {
    await _localDb.upsertScan(scan, synced: synced);
  }

  /// Save a scan offline (alias for backward compatibility)
  Future<void> saveScanOffline(ScanResult scan) async {
    await _localDb.upsertScan(scan, synced: false);
  }

  /// Sync all unsynced local scans to Supabase
  Future<void> syncOfflineData() async {
    if (_isSyncing) return;
    _isSyncing = true;
    
    try {
      final unsyncedScans = await _localDb.getUnsyncedScans();
      
      if (unsyncedScans.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint('🔄 Syncing ${unsyncedScans.length} offline scans...');

      for (final scan in unsyncedScans) {
        try {
          var scanToSync = scan;
          
          // Upgrade offline/template remedies with cloud AI
          if (scan.aiSource == 'offline' || scan.aiSource == 'template') {
            try {
              final groq = GroqService();
              final tier = await SecureTierService().getCachedTierString();
              final betterRemedy = await groq.getTieredAdvice(
                tier: tier,
                plantName: scan.plantName,
                diseaseName: scan.diseaseName,
                healthScore: scan.healthScore,
              );
              if (betterRemedy.isNotEmpty) {
                scanToSync = scan.copyWith(
                  remedy: betterRemedy, 
                  aiSource: 'cloud_synced',
                );
                // Update local DB with better remedy
                await _localDb.updateRemedy(scan.id, betterRemedy, 'cloud_synced');
              }
            } catch (_) {
              // Non-fatal, just upload with original offline remedy
            }
          }

          await _supabase.saveScan(scanToSync);
          await _gamification.processScanReward(scanToSync.userId);
          await _localDb.markSynced(scan.id);
          debugPrint('✅ Synced scan: ${scan.id}');
        } catch (e) {
          debugPrint('❌ Failed to sync scan ${scan.id}: $e');
          // Keep it unsynced for next attempt
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Import existing Supabase scans into local DB (initial sync)
  Future<void> importFromCloud(List<ScanResult> cloudScans) async {
    await _localDb.importScans(cloudScans);
  }
}
