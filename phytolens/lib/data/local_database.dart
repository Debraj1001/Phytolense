import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/scan_result.dart';
import '../models/app_user.dart';
import '../models/app_config.dart';

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
      version: 3,
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

        // Cached user profiles for instant offline startup
        await db.execute('''
          CREATE TABLE cached_users (
            uid TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        // Cached global app configuration
        await db.execute('''
          CREATE TABLE cached_config (
            key TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        // Indexes for fast offline-first queries
        await db.execute('CREATE INDEX idx_scans_user ON scans(user_id)');
        await db.execute('CREATE INDEX idx_scans_synced ON scans(synced)');
        await db.execute('CREATE INDEX idx_scans_date ON scans(scanned_at DESC)');
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
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_users (
              uid TEXT PRIMARY KEY,
              data TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_config (
              key TEXT PRIMARY KEY,
              data TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // USER PROFILE & CONFIG CACHING (Instant Offline Cold-Start)
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> saveCachedUser(AppUser user) async {
    try {
      final db = await database;
      await db.insert(
        'cached_users',
        {
          'uid': user.uid,
          'data': jsonEncode(user.toMap()),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('💾 Cached user profile offline: ${user.displayName} (${user.uid})');
    } catch (e) {
      debugPrint('Error saving cached user: $e');
    }
  }

  Future<AppUser?> getCachedUser(String uid) async {
    try {
      final db = await database;
      final results = await db.query(
        'cached_users',
        where: 'uid = ?',
        whereArgs: [uid],
        limit: 1,
      );
      if (results.isNotEmpty) {
        final data = jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
        return AppUser.fromMap(data);
      }
    } catch (e) {
      debugPrint('Error reading cached user: $e');
    }
    return null;
  }

  Future<AppUser?> getLastLoggedInUser() async {
    try {
      final db = await database;
      final results = await db.query(
        'cached_users',
        orderBy: 'updated_at DESC',
        limit: 1,
      );
      if (results.isNotEmpty) {
        final data = jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
        return AppUser.fromMap(data);
      }
    } catch (e) {
      debugPrint('Error reading last logged in user: $e');
    }
    return null;
  }

  Future<void> saveCachedAppConfig(AppConfig config) async {
    try {
      final db = await database;
      await db.insert(
        'cached_config',
        {
          'key': 'app_config',
          'data': jsonEncode(config.toMap()),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error caching app config: $e');
    }
  }

  Future<AppConfig?> getCachedAppConfig() async {
    try {
      final db = await database;
      final results = await db.query(
        'cached_config',
        where: 'key = ?',
        whereArgs: ['app_config'],
        limit: 1,
      );
      if (results.isNotEmpty) {
        final data = jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
        return AppConfig.fromMap(data);
      }
    } catch (_) {}
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CRUD OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════

  /// Insert or update a scan result
  Future<void> upsertScan(ScanResult scan, {bool synced = false}) async {
    final db = await database;
    final map = scan.toMap(includeId: true);
    // Ensure id is always present
    if (scan.id.isNotEmpty) {
      map['id'] = scan.id;
    } else {
      map['id'] = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    }
    map['synced'] = synced ? 1 : 0;
    map['flagged'] = scan.flagged ? 1 : 0;

    await db.insert(
      'scans',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Atomically replace a local temporary scan with the confirmed cloud scan UUID
  Future<void> replaceTempScanWithCloud(String tempId, ScanResult cloudScan) async {
    final db = await database;
    await db.transaction((txn) async {
      if (tempId.isNotEmpty) {
        await txn.delete('scans', where: 'id = ?', whereArgs: [tempId]);
      }
      final map = cloudScan.toMap(includeId: true);
      if (cloudScan.id.isNotEmpty) {
        map['id'] = cloudScan.id;
      }
      map['synced'] = 1;
      map['flagged'] = cloudScan.flagged ? 1 : 0;
      await txn.insert('scans', map, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    debugPrint('🔄 Replaced temp scan $tempId with cloud UUID ${cloudScan.id}');
  }

  /// Batch insert or update multiple scan results in a single transaction.
  /// Ignores any scans that are in the pending deletions queue to prevent resurrection.
  Future<void> batchUpsertScans(List<ScanResult> scans, {bool synced = false}) async {
    if (scans.isEmpty) return;
    final db = await database;

    final pending = await getPendingDeletions();
    final pendingIds = pending.map((r) => r['scan_id'] as String).toSet();

    final batch = db.batch();
    for (final scan in scans) {
      if (scan.id.isEmpty || pendingIds.contains(scan.id)) continue;
      final map = scan.toMap(includeId: true);
      map['id'] = scan.id;
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

  /// Get all scans for a user, ordered by date (newest first).
  /// Excludes any scans currently queued for deletion.
  Future<List<ScanResult>> getUserScans(String userId, {int limit = 50}) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT s.* FROM scans s
      LEFT JOIN pending_deletions p ON s.id = p.scan_id
      WHERE (s.user_id = ? OR ? = '') AND p.scan_id IS NULL AND s.id != ''
      ORDER BY s.scanned_at DESC
      LIMIT ?
    ''', [userId, userId, limit]);

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
    final results = await db.rawQuery('''
      SELECT s.* FROM scans s
      LEFT JOIN pending_deletions p ON s.id = p.scan_id
      WHERE s.synced = 0 AND p.scan_id IS NULL AND s.id != ''
      ORDER BY s.scanned_at ASC
    ''');

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
      'SELECT COUNT(*) as total FROM scans WHERE (user_id = ? OR ? = "") AND id != ""',
      [userId, userId],
    );
    final total = Sqflite.firstIntValue(countResult) ?? 0;

    final avgResult = await db.rawQuery(
      'SELECT AVG(health_score) as avg_health FROM scans WHERE (user_id = ? OR ? = "") AND id != ""',
      [userId, userId],
    );
    final avgHealth = (avgResult.first['avg_health'] as num?)?.toInt() ?? 0;

    final diseaseResult = await db.rawQuery(
      '''SELECT COUNT(*) as diseases FROM scans 
         WHERE (user_id = ? OR ? = "") AND id != "" AND disease_name != 'Healthy' 
         AND disease_name != 'Identified Species'
         AND disease_name != 'Object (Non-Plant)'
         AND disease_name != 'Identified Plant' ''',
      [userId, userId],
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
    await db.delete('scans', where: 'id = ?', whereArgs: ['']);
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
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (!uuidRegex.hasMatch(scanId)) {
      debugPrint('Skipping pending deletion queue for local-only scan: $scanId');
      return;
    }

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
