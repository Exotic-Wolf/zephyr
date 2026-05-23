import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

/// Local SQLite database for offline-first chat.
/// UI reads from here (instant), network syncs into here in the background.
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final String dbPath = join(await getDatabasesPath(), 'zephyr_chat.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            sender_id TEXT NOT NULL,
            receiver_id TEXT NOT NULL,
            body TEXT NOT NULL,
            delivered_at TEXT,
            read_at TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_messages_thread
          ON messages(sender_id, receiver_id, created_at)
        ''');
        await db.execute('''
          CREATE TABLE conversations (
            user_id TEXT PRIMARY KEY,
            display_name TEXT NOT NULL,
            avatar_url TEXT,
            last_message TEXT,
            last_message_at TEXT,
            unread_count INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  /// Upsert a single message (from API or socket).
  Future<void> upsertMessage(ZephyrMessage msg) async {
    final Database d = await db;
    await d.rawInsert('''
      INSERT INTO messages (id, sender_id, receiver_id, body, delivered_at, read_at, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        sender_id = excluded.sender_id,
        receiver_id = excluded.receiver_id,
        body = excluded.body,
        delivered_at = COALESCE(excluded.delivered_at, messages.delivered_at),
        read_at = COALESCE(excluded.read_at, messages.read_at),
        created_at = excluded.created_at
    ''', [
      msg.id,
      msg.senderId,
      msg.receiverId,
      msg.body,
      msg.deliveredAt?.toIso8601String(),
      msg.readAt?.toIso8601String(),
      msg.createdAt.toIso8601String(),
    ]);
  }

  /// Bulk upsert messages (after API fetch).
  Future<void> upsertMessages(List<ZephyrMessage> messages) async {
    if (messages.isEmpty) return;
    final Database d = await db;
    final Batch batch = d.batch();
    for (final ZephyrMessage msg in messages) {
      batch.rawInsert('''
        INSERT INTO messages (id, sender_id, receiver_id, body, delivered_at, read_at, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          sender_id = excluded.sender_id,
          receiver_id = excluded.receiver_id,
          body = excluded.body,
          delivered_at = COALESCE(excluded.delivered_at, messages.delivered_at),
          read_at = COALESCE(excluded.read_at, messages.read_at),
          created_at = excluded.created_at
      ''', [
        msg.id,
        msg.senderId,
        msg.receiverId,
        msg.body,
        msg.deliveredAt?.toIso8601String(),
        msg.readAt?.toIso8601String(),
        msg.createdAt.toIso8601String(),
      ]);
    }
    await batch.commit(noResult: true);
  }

  /// Get a single message by ID (returns null if not found).
  Future<ZephyrMessage?> getMessageById(String id) async {
    final Database d = await db;
    final List<Map<String, Object?>> rows =
        await d.query('messages', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _rowToMessage(rows.first);
  }

  /// Get IDs of incoming messages that haven't been ACKed as delivered yet.
  Future<List<String>> getUndeliveredIncomingIds(String myUserId) async {
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.rawQuery('''
      SELECT id FROM messages
      WHERE receiver_id = ? AND delivered_at IS NULL
    ''', [myUserId]);
    return rows.map((r) => r['id'] as String).toList();
  }

  /// Get thread messages between current user and partner, newest last.
  Future<List<ZephyrMessage>> getThread(String myUserId, String otherUserId, {int limit = 50}) async {
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.rawQuery('''
      SELECT * FROM messages
      WHERE (sender_id = ? AND receiver_id = ?)
         OR (sender_id = ? AND receiver_id = ?)
      ORDER BY created_at ASC
      LIMIT ?
    ''', [myUserId, otherUserId, otherUserId, myUserId, limit]);
    return rows.map(_rowToMessage).toList();
  }

  /// Get the latest N messages for a thread (for display on open).
  Future<List<ZephyrMessage>> getLatestThread(String myUserId, String otherUserId, {int limit = 50}) async {
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.rawQuery('''
      SELECT * FROM (
        SELECT * FROM messages
        WHERE (sender_id = ? AND receiver_id = ?)
           OR (sender_id = ? AND receiver_id = ?)
        ORDER BY created_at DESC
        LIMIT ?
      ) sub ORDER BY created_at ASC
    ''', [myUserId, otherUserId, otherUserId, myUserId, limit]);
    return rows.map(_rowToMessage).toList();
  }

  /// Update delivered_at for a message.
  Future<void> markDelivered(String messageId, DateTime deliveredAt) async {
    final Database d = await db;
    await d.update(
      'messages',
      {'delivered_at': deliveredAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  /// Update read_at for a message.
  Future<void> markRead(String messageId, DateTime readAt) async {
    final Database d = await db;
    await d.update(
      'messages',
      {'read_at': readAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  // ── Conversations ─────────────────────────────────────────────────────────

  /// Replace all conversations (from API refresh).
  Future<void> replaceConversations(List<ZephyrConversation> convos) async {
    final Database d = await db;
    final Batch batch = d.batch();
    batch.delete('conversations');
    for (final ZephyrConversation c in convos) {
      batch.insert('conversations', {
        'user_id': c.userId,
        'display_name': c.displayName,
        'avatar_url': c.avatarUrl,
        'last_message': c.lastMessage,
        'last_message_at': c.lastMessageAt.toIso8601String(),
        'unread_count': c.unreadCount,
      });
    }
    await batch.commit(noResult: true);
  }

  /// Get cached conversations.
  Future<List<ZephyrConversation>> getConversations() async {
    final Database d = await db;
    final List<Map<String, Object?>> rows = await d.query(
      'conversations',
      orderBy: 'last_message_at DESC',
    );
    return rows.map((Map<String, Object?> row) => ZephyrConversation(
      userId: row['user_id'] as String,
      displayName: row['display_name'] as String,
      avatarUrl: row['avatar_url'] as String?,
      lastMessage: row['last_message'] as String? ?? '',
      lastMessageAt: DateTime.parse(row['last_message_at'] as String? ?? DateTime.now().toIso8601String()),
      unreadCount: (row['unread_count'] as int?) ?? 0,
    )).toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  ZephyrMessage _rowToMessage(Map<String, Object?> row) {
    return ZephyrMessage(
      id: row['id'] as String,
      senderId: row['sender_id'] as String,
      receiverId: row['receiver_id'] as String,
      body: row['body'] as String,
      deliveredAt: row['delivered_at'] != null
          ? DateTime.parse(row['delivered_at'] as String)
          : null,
      readAt: row['read_at'] != null
          ? DateTime.parse(row['read_at'] as String)
          : null,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  /// Clear all data (e.g. on logout).
  Future<void> clear() async {
    final Database d = await db;
    await d.delete('messages');
    await d.delete('conversations');
  }
}
