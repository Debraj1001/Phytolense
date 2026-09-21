// lib/data/local_database.dart
//
// Local SQLite database for offline scan history.
// All scans are saved locally first, then synced to Supabase when online.
// This is the single source of truth for scan history on the device.

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/scan_result.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final appDir = await getApplicationDocumentsDirectory();
    final path = join(appDir.path, 'phytolens_scans.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE scans (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            plant_id TEXT,
            image_url TEXT,
            disease_name TEXT NOT NULL,
            disease_confidence REAL NOT NULL DEFAULT 0.0,
            plant_name TEXT NOT NULL DEFAULT 'Unknown Plant',
            health_score INTEGER NOT NULL DEFAULT 0,
            remedy TEXT,
            flagged INTEGER NOT NULL DEFAULT 0,
            scanned_at TEXT NOT NULL,
            severity_percent INTEGER NOT NULL DEFAULT 0,
            infection_area REAL NOT NULL DEFAULT 0.0,
            ai_source TEXT NOT NULL DEFAULT 'cloud',
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');

        // Pending deletions queue — survives offline/restart, synced when online
        await db.execute('''
          CREATE TABLE pending_deletions (
            scan_id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            queued_at TEXT NOT NULL
          )
        ''');

        // Index for fast offline-first queries
        await db.execute(
          'CREATE INDEX idx_scans_user ON scans(user_id)',
        );
        await db.execute(
          'CREATE INDEX idx_scans_synced ON scans(synced)',
        );
        await db.execute(
          'CREATE INDEX idx_scans_date ON scans(scanned_at DESC)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS pending_deletions (
              scan_id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              queued_at TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CRUD OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════

  /// Insert or update a scan result
  Future<void> upsertScan(ScanResult scan, {bool synced = false}) async {
    final db = await database;
    final map = scan.toMap(includeId: true);
    map['synced'] = synced ? 1 : 0;
    map['flagged'] = scan.flagged ? 1 : 0;

    await db.insert(
      'scans',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Batch insert or update multiple scan results in a single transaction
  Future<void> batchUpsertScans(List<ScanResult> scans, {bool synced = false}) async {
    if (scans.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final scan in scans) {
      final map = scan.toMap(includeId: true);
      map['synced'] = synced ? 1 : 0;
      map['flagged'] = scan.flagged ? 1 : 0;
      batch.insert(
        'scans',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }


  /// Get all scans for a user, ordered by date (newest first)
  Future<List<ScanResult>> getUserScans(String userId, {int limit = 50}) async {
    final db = await database;
    final results = await db.query(
      'scans',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'scanned_at DESC',
      limit: limit,
    );

    return results.map((row) {
      final map = Map<String, dynamic>.from(row);
      map['flagged'] = (map['flagged'] as int?) == 1;
      return ScanResult.fromMap(map);
    }).toList();
  }

  /// Get recent scans (for dashboard preview)
  Future<List<ScanResult>> getRecentScans(String userId, {int limit = 5}) async {
    return getUserScans(userId, limit: limit);
  }

  /// Get a single scan by ID
  Future<ScanResult?> getScan(String id) async {
    final db = await database;
    final results = await db.query(
      'scans',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    final map = Map<String, dynamic>.from(results.first);
    map['flagged'] = (map['flagged'] as int?) == 1;
    return ScanResult.fromMap(map);
  }

  /// Get all unsynced scans (for background sync)
  Future<List<ScanResult>> getUnsyncedScans() async {
    final db = await database;
    final results = await db.query(
      'scans',
      where: 'synced = 0',
      orderBy: 'scanned_at ASC',
    );

    return results.map((row) {
      final map = Map<String, dynamic>.from(row);
      map['flagged'] = (map['flagged'] as int?) == 1;
      return ScanResult.fromMap(map);
    }).toList();
  }

  /// Mark a scan as synced
  Future<void> markSynced(String id) async {
    final db = await database;
    await db.update(
      'scans',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update a scan's remedy (after cloud sync upgrades it)
  Future<void> updateRemedy(String id, String remedy, String aiSource) async {
    final db = await database;
    await db.update(
      'scans',
      {'remedy': remedy, 'ai_source': aiSource, 'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update a scan's image URL (after cloud upload)
  Future<void> updateImageUrl(String id, String imageUrl) async {
    final db = await database;
    await db.update(
      'scans',
      {'image_url': imageUrl},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get aggregate stats for dashboard
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    final db = await database;

    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as total FROM scans WHERE user_id = ?',
      [userId],
    );
    final total = Sqflite.firstIntValue(countResult) ?? 0;

    final avgResult = await db.rawQuery(
      'SELECT AVG(health_score) as avg_health FROM scans WHERE user_id = ?',
      [userId],
    );
    final avgHealth = (avgResult.first['avg_health'] as num?)?.toInt() ?? 0;

    final diseaseResult = await db.rawQuery(
      '''SELECT COUNT(*) as diseases FROM scans 
         WHERE user_id = ? AND disease_name != 'Healthy' 
         AND disease_name != 'Identified Species'
         AND disease_name != 'Object (Non-Plant)'
         AND disease_name != 'Identified Plant' ''',
      [userId],
    );
    final diseases = Sqflite.firstIntValue(diseaseResult) ?? 0;

    return {
      'total_scans': total,
      'avg_health': avgHealth,
      'diseases_found': diseases,
    };
  }

  /// Get scan count for today (for daily limit checking)
  Future<int> getTodayScanCount(String userId) async {
    final db = await database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day).toUtc().toIso8601String();

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM scans WHERE user_id = ? AND scanned_at >= ?',
      [userId, startOfDay],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Delete a scan
  Future<void> deleteScan(String id) async {
    final db = await database;
    await db.delete('scans', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete all scans for a user (used during account reset/deletion)
  Future<void> clearAllUserData(String userId) async {
    final db = await database;
    await db.delete('scans', where: 'user_id = ?', whereArgs: [userId]);
    debugPrint('🗑️ Cleared all scans for user: $userId');
  }

  /// Import scans from Supabase (bulk insert for initial sync)
  Future<void> importScans(List<ScanResult> scans) async {
    final db = await database;
    final batch = db.batch();

    for (final scan in scans) {
      final map = scan.toMap(includeId: true);
      map['synced'] = 1;
      map['flagged'] = scan.flagged ? 1 : 0;
      batch.insert('scans', map, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    await batch.commit(noResult: true);
    debugPrint('📦 Imported ${scans.length} scans to local DB');
  }

  /// Close the database
  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PENDING DELETIONS QUEUE
  // ═══════════════════════════════════════════════════════════════════════

  /// Queue a scan for deferred Supabase deletion (used when offline)
  Future<void> queuePendingDeletion(String scanId, String userId) async {
    final db = await database;
    await db.insert(
      'pending_deletions',
      {
        'scan_id': scanId,
        'user_id': userId,
        'queued_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('🗑️ Queued pending deletion for scan: $scanId');
  }

  /// Get all pending deletions that need to be synced to Supabase
  Future<List<Map<String, dynamic>>> getPendingDeletions() async {
    final db = await database;
    return db.query('pending_deletions', orderBy: 'queued_at ASC');
  }

  /// Remove a scan from the pending deletions queue (after successful cloud delete)
  Future<void> clearPendingDeletion(String scanId) async {
    final db = await database;
    await db.delete('pending_deletions', where: 'scan_id = ?', whereArgs: [scanId]);
  }
}
