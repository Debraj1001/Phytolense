// lib/services/sync_service.dart

import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_result.dart';
import 'supabase_service.dart';
import 'gamification_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final _supabase = SupabaseService();
  final _gamification = GamificationService();
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

  Future<void> saveScanOffline(ScanResult scan) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> offlineScans = prefs.getStringList('offline_scans') ?? [];
    
    // Add timestamp to identify when it was scanned offline if needed
    final scanMap = scan.toMap();
    offlineScans.add(jsonEncode(scanMap));
    
    await prefs.setStringList('offline_scans', offlineScans);
  }

  Future<void> syncOfflineData() async {
    if (_isSyncing) return;
    _isSyncing = true;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> offlineScans = prefs.getStringList('offline_scans') ?? [];
      
      if (offlineScans.isEmpty) {
        _isSyncing = false;
        return;
      }

      List<String> failedScans = [];

      for (String scanJson in offlineScans) {
        try {
          final scanMap = jsonDecode(scanJson);
          final scanResult = ScanResult.fromMap(scanMap);
          
          await _supabase.saveScan(scanResult);
          await _gamification.processScanReward(scanResult.userId);
        } catch (e) {
          failedScans.add(scanJson); // Keep it for next sync
        }
      }

      // Update prefs with only the failed scans
      await prefs.setStringList('offline_scans', failedScans);
    } finally {
      _isSyncing = false;
    }
  }
}
