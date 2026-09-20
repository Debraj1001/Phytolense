// lib/data/chat_database.dart
//
// Local SQLite database for Chat History persistence and offline AI usage tracking.
// Stores sessions and messages permanently on-device.

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class ChatDatabase {
  static final ChatDatabase _instance = ChatDatabase._internal();
  factory ChatDatabase() => _instance;
  ChatDatabase._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final appDir = await getApplicationDocumentsDirectory();
    final path = join(appDir.path, 'phytolens_chats.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE chat_sessions (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            title TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE chat_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            source TEXT NOT NULL DEFAULT 'online',
            synced INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('CREATE INDEX idx_chat_msg_session ON chat_messages(session_id)');
        await db.execute('CREATE INDEX idx_chat_msg_user ON chat_messages(user_id)');
        await db.execute('CREATE INDEX idx_chat_msg_synced ON chat_messages(synced)');
        await db.execute('CREATE INDEX idx_chat_sessions_user ON chat_sessions(user_id, updated_at DESC)');
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SESSIONS
  // ═══════════════════════════════════════════════════════════════════════

  Future<String> getOrCreateActiveSession(String userId) async {
    final db = await database;
    final sessions = await db.query(
      'chat_sessions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'updated_at DESC',
      limit: 1,
    );

    if (sessions.isNotEmpty) {
      return sessions.first['id'] as String;
    }

    return createNewSession(userId);
  }

  Future<String> createNewSession(String userId, {String? title}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final sessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}';

    await db.insert(
      'chat_sessions',
      {
        'id': sessionId,
        'user_id': userId,
        'title': title ?? 'New Conversation',
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return sessionId;
  }

  Future<List<Map<String, dynamic>>> getRecentSessions(String userId, {int limit = 20}) async {
    final db = await database;
    return await db.query(
      'chat_sessions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'updated_at DESC',
      limit: limit,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MESSAGES
  // ═══════════════════════════════════════════════════════════════════════

  Future<int> saveMessage({
    required String sessionId,
    required String userId,
    required String role,
    required String content,
    String source = 'online',
    int synced = 0,
    DateTime? createdAt,
  }) async {
    final db = await database;
    final now = (createdAt ?? DateTime.now()).toIso8601String();

    final id = await db.insert('chat_messages', {
      'session_id': sessionId,
      'user_id': userId,
      'role': role,
      'content': content,
      'source': source,
      'synced': synced,
      'created_at': now,
    });

    // Update session timestamp & auto-title if needed
    final session = await db.query('chat_sessions', where: 'id = ?', whereArgs: [sessionId], limit: 1);
    if (session.isNotEmpty) {
      String? currentTitle = session.first['title'] as String?;
      Map<String, dynamic> updateValues = {'updated_at': now};
      if ((currentTitle == null || currentTitle == 'New Conversation') && role == 'user') {
        final titleSnippet = content.trim().replaceAll('\n', ' ');
        updateValues['title'] = titleSnippet.length > 35 ? '${titleSnippet.substring(0, 32)}...' : titleSnippet;
      }
      await db.update('chat_sessions', updateValues, where: 'id = ?', whereArgs: [sessionId]);
    }

    return id;
  }

  Future<List<Map<String, dynamic>>> getSessionMessages(String sessionId) async {
    final db = await database;
    return await db.query(
      'chat_messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC, id ASC',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // OFFLINE USAGE TRACKING & SYNC
  // ═══════════════════════════════════════════════════════════════════════

  Future<int> getUnsyncedOfflineCount(String userId) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM chat_messages WHERE user_id = ? AND source = ? AND synced = 0 AND role = ?',
      [userId, 'offline', 'user'],
    );
    if (res.isNotEmpty && res.first['cnt'] != null) {
      return (res.first['cnt'] as num).toInt();
    }
    return 0;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedOfflineMessages(String userId) async {
    final db = await database;
    return await db.query(
      'chat_messages',
      where: 'user_id = ? AND source = ? AND synced = 0 AND role = ?',
      whereArgs: [userId, 'offline', 'user'],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> markMessagesSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE chat_messages SET synced = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DELETION & RESET
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> clearSession(String sessionId) async {
    final db = await database;
    await db.delete('chat_messages', where: 'session_id = ?', whereArgs: [sessionId]);
    await db.delete('chat_sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  Future<void> clearAllUserData(String userId) async {
    final db = await database;
    await db.delete('chat_messages', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('chat_sessions', where: 'user_id = ?', whereArgs: [userId]);
    debugPrint('🗑️ Cleared all chat history for user: $userId');
  }
}
