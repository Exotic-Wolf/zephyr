import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'presence_bus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Isolated Firebase chat service — completely separate from existing messaging.
/// Uses Firestore for messages and RTDB for presence (onDisconnect).
class FirebaseChatService {
  FirebaseChatService._();
  static final FirebaseChatService instance = FirebaseChatService._();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://zephyr-495115-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  String? _myUserId;
  String get myUserId => _myUserId!;

  /// Callback to send push notifications via the backend API.
  Future<void> Function(String recipientId, String title, String body)?
      onSendPush;

  // ── Presence cache ──────────────────────────────────────────────────────────
  /// Whether THIS user is currently live-streaming.
  bool _isLive = false;

  /// Cached state per user: 'online', 'offline', or 'live'.
  final Map<String, String> _presenceCache = {};
  /// Cached roomId per user (only set when state == 'live').
  final Map<String, String> _presenceRoomCache = {};
  final Map<String, StreamSubscription<DatabaseEvent>> _presenceSubs = {};
  StreamSubscription<DatabaseEvent>? _connectedSub;

  /// Notifies listeners whenever any user's presence changes.
  final ValueNotifier<int> presenceVersion = ValueNotifier<int>(0);

  /// Whether a user is known to be online (from cache). Returns null if unknown.
  bool? isOnlineCached(String userId) {
    final s = _presenceCache[userId];
    if (s == null) return null;
    return s == 'online' || s == 'live';
  }

  /// Returns the raw presence state: 'online', 'offline', or 'live'. Null if unknown.
  String? presenceStateCached(String userId) => _presenceCache[userId];

  /// Returns the roomId for a user who is currently live. Null otherwise.
  String? presenceRoomIdCached(String userId) => _presenceRoomCache[userId];

  /// Pre-warm presence for a list of user IDs. Subscribes once per user.
  /// Caps at 50 subscriptions to avoid unbounded RTDB listeners.
  static const int _maxPresenceSubs = 50;

  void warmPresence(List<String> userIds) {
    for (final String uid in userIds) {
      if (_presenceSubs.containsKey(uid)) continue;

      // Evict oldest subscriptions if at capacity
      while (_presenceSubs.length >= _maxPresenceSubs) {
        final String oldest = _presenceSubs.keys.first;
        _presenceSubs.remove(oldest)?.cancel();
      }

      _presenceSubs[uid] = _rtdb.ref('presence/$uid').onValue.listen((event) {
        final data = event.snapshot.value;
        final String state =
            (data is Map ? data['state'] as String? : null) ?? 'offline';
        final String? roomId =
            data is Map ? data['roomId'] as String? : null;

        final bool changed = _presenceCache[uid] != state ||
            _presenceRoomCache[uid] != roomId;

        _presenceCache[uid] = state;
        if (state == 'live' && roomId != null) {
          _presenceRoomCache[uid] = roomId;
        } else {
          _presenceRoomCache.remove(uid);
        }

        if (changed) {
          presenceVersion.value++;
          // Keep PresenceBus in sync so StatusDot (inbox) reflects the same state.
          PresenceBus.instance.update(uid, state);
        }
      });
    }
  }

  /// Initialize: sign in with custom Firebase token and set up presence.
  /// [zephyrUserId] is the app's user ID (UUID). Safe to call multiple times.
  /// [firebaseToken] is a custom token from the backend (optional — falls back to anonymous).
  Future<void> init(String zephyrUserId, {String? firebaseToken}) async {
    final bool firstInit = _myUserId != zephyrUserId;
    _myUserId = zephyrUserId;

    if (firstInit) {
      if (firebaseToken != null) {
        await FirebaseAuth.instance.signInWithCustomToken(firebaseToken);
      } else {
        await FirebaseAuth.instance.signInAnonymously();
      }
      _setupPresence(zephyrUserId);
    }

    // Always write presence directly (handles cold start + reconnection)
    _rtdb.ref('presence/$zephyrUserId').set({
      'state': _isLive ? 'live' : 'online',
      'lastSeen': ServerValue.timestamp,
    });
  }

  // ── Presence (RTDB + onDisconnect) ──────────────────────────────────────────

  void _setupPresence(String userId) {
    final DatabaseReference presenceRef = _rtdb.ref('presence/$userId');
    final DatabaseReference connectedRef = _rtdb.ref('.info/connected');

    _connectedSub?.cancel();
    _connectedSub = connectedRef.onValue.listen((DatabaseEvent event) {
      final bool connected = event.snapshot.value as bool? ?? false;
      if (!connected) return;

      // When we disconnect, mark offline with server timestamp
      presenceRef.onDisconnect().set({
        'state': 'offline',
        'lastSeen': ServerValue.timestamp,
      });

      // Write current state now
      presenceRef.set({
        'state': _isLive ? 'live' : 'online',
        'lastSeen': ServerValue.timestamp,
      });
    });
  }

  /// Listen to a user's presence state.
  Stream<Map<String, dynamic>> watchPresence(String userId) {
    return _rtdb.ref('presence/$userId').onValue.map((DatabaseEvent event) {
      final data = event.snapshot.value;
      if (data == null) return {'state': 'offline', 'lastSeen': 0};
      return Map<String, dynamic>.from(data as Map);
    });
  }

  /// Mark current user as "live" in Firebase RTDB presence.
  void setLiveStatus({String? roomId}) {
    if (_myUserId == null) return;
    _isLive = true;
    _rtdb.ref('presence/$_myUserId').set({
      'state': 'live',
      'lastSeen': ServerValue.timestamp,
      if (roomId != null) 'roomId': roomId,
    });
  }

  /// Restore current user to "online" (call when ending a live stream).
  void clearLiveStatus() {
    if (_myUserId == null) return;
    _isLive = false;
    _rtdb.ref('presence/$_myUserId').set({
      'state': 'online',
      'lastSeen': ServerValue.timestamp,
    });
  }

  /// Mark current user as "busy" in Firebase RTDB presence.
  void setBusyStatus() {
    if (_myUserId == null) return;
    _rtdb.ref('presence/$_myUserId').set({
      'state': 'busy',
      'lastSeen': ServerValue.timestamp,
    });
  }

  /// Clear busy and restore to "online".
  void clearBusyStatus() {
    if (_myUserId == null) return;
    _rtdb.ref('presence/$_myUserId').set({
      'state': _isLive ? 'live' : 'online',
      'lastSeen': ServerValue.timestamp,
    });
  }

  // ── Direct Call Signaling (RTDB) ─────────────────────────────────────────────

  /// Reference to a user's call signaling node.
  DatabaseReference callSignalRef(String userId) =>
      _rtdb.ref('direct_calls/$userId');

  /// Write a "ringing" signal to the target user's node.
  /// Also sets onDisconnect to auto-remove the node if the caller crashes.
  Future<void> writeRinging({
    required String targetUserId,
    required String callerId,
    required String callerName,
    String? callerAvatarUrl,
    required String sessionId,
  }) async {
    final ref = callSignalRef(targetUserId);
    await ref.onDisconnect().remove();
    await ref.set(<String, dynamic>{
      'callerId': callerId,
      'callerName': callerName,
      'callerAvatarUrl': callerAvatarUrl,
      'sessionId': sessionId,
      'status': 'ringing',
      'ts': ServerValue.timestamp,
    });
  }

  /// Cancel the onDisconnect handler (call this when the call connects to Agora,
  /// so a brief RTDB disconnect doesn't kill the active call).
  Future<void> cancelOnDisconnect(String targetUserId) {
    return callSignalRef(targetUserId).onDisconnect().cancel();
  }

  /// Update the status field on my own signal node (e.g. 'accepted', 'declined').
  Future<void> writeCallStatus(String userId, String status) {
    return callSignalRef(userId).child('status').set(status);
  }

  /// Remove the call signaling node (cleanup).
  Future<void> removeCallSignal(String userId) {
    return callSignalRef(userId).remove();
  }

  /// Listen for changes on a user's call signal node.
  /// Returns the subscription so the caller can cancel it.
  StreamSubscription<DatabaseEvent> listenCallSignal(
    String userId,
    void Function(Map<String, dynamic>? data) onData,
  ) {
    return callSignalRef(userId).onValue.listen((DatabaseEvent event) {
      final raw = event.snapshot.value;
      if (raw == null) {
        onData(null);
      } else {
        onData(Map<String, dynamic>.from(raw as Map));
      }
    });
  }

  // ── Chat ID ─────────────────────────────────────────────────────────────────

  /// Deterministic chat ID from two user IDs (sorted).
  String chatId(String userId1, String userId2) {
    final List<String> sorted = [userId1, userId2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  // ── Conversations (Inbox) ───────────────────────────────────────────────────

  /// Stream of conversations for the current user, ordered by last message time.
  Stream<List<FirebaseConversation>> watchConversations() {
    return _fs
        .collection('chats')
        .where('participants', arrayContains: _myUserId)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
      final list = snap.docs.map((doc) {
        final data = doc.data();
        final List<String> participants =
            List<String>.from(data['participants'] as List);
        final String? otherUserId =
            participants.cast<String?>().firstWhere((id) => id != _myUserId, orElse: () => null);
        if (otherUserId == null) return null; // self-chat, skip
        final int unread = (data['unread_$_myUserId'] as int?) ?? 0;
        return FirebaseConversation(
          chatId: doc.id,
          otherUserId: otherUserId,
          otherDisplayName: (data['name_$otherUserId'] as String?) ?? 'User',
          otherAvatarUrl: data['avatar_$otherUserId'] as String?,
          lastMessage: (data['lastMessage'] as String?) ?? '',
          lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          unreadCount: unread,
        );
      }).whereType<FirebaseConversation>().toList();
      list.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      return list;
    });
  }

  // ── Messages (Thread) ──────────────────────────────────────────────────────

  /// Stream of messages in a chat, ordered by creation time.
  /// Filters out messages deleted for the current user.
  Stream<List<FirebaseMessage>> watchMessages(String otherUserId) {
    final String cId = chatId(_myUserId!, otherUserId);
    return _fs
        .collection('chats')
        .doc(cId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limitToLast(100)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        return FirebaseMessage(
          id: doc.id,
          senderId: data['senderId'] as String,
          body: (data['body'] as String?) ?? '',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
          readAt: (data['readAt'] as Timestamp?)?.toDate(),
          type: (data['type'] as String?) ?? 'text',
          imageUrl: data['imageUrl'] as String?,
          deletedFor: data['deletedFor'],
        );
      }).where((msg) {
        // Filter deleted messages
        if (msg.deletedFor == 'all') return true; // Show "deleted" placeholder
        if (msg.deletedFor is List && (msg.deletedFor as List).contains(_myUserId)) {
          return false; // Hidden for me
        }
        return true;
      }).toList();
    });
  }

  // ── Block / Report ─────────────────────────────────────────────────────────

  /// Block a user. Prevents messaging and hides conversation.
  Future<void> blockUser(String otherUserId) async {
    await _fs.collection('blocks').doc('${_myUserId}_$otherUserId').set({
      'blockedBy': _myUserId,
      'blockedUser': otherUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Unblock a user.
  Future<void> unblockUser(String otherUserId) async {
    await _fs.collection('blocks').doc('${_myUserId}_$otherUserId').delete();
  }

  /// Check if current user blocked the other user.
  Future<bool> isBlocked(String otherUserId) async {
    final doc = await _fs.collection('blocks').doc('${_myUserId}_$otherUserId').get();
    return doc.exists;
  }

  /// Check if the other user blocked me.
  Future<bool> isBlockedBy(String otherUserId) async {
    final doc = await _fs.collection('blocks').doc('${otherUserId}_$_myUserId').get();
    return doc.exists;
  }

  /// Report a user with reason.
  Future<void> reportUser(String otherUserId, String reason) async {
    await _fs.collection('reports').add({
      'reportedBy': _myUserId,
      'reportedUser': otherUserId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Message Deletion ────────────────────────────────────────────────────────

  /// Delete message for me only (hides it locally via a deletedFor field).
  Future<void> deleteMessageForMe(String otherUserId, String messageId) async {
    final String cId = chatId(_myUserId!, otherUserId);
    await _fs
        .collection('chats')
        .doc(cId)
        .collection('messages')
        .doc(messageId)
        .update({
      'deletedFor': FieldValue.arrayUnion([_myUserId]),
    });
  }

  /// Delete message for everyone (only sender can do this).
  Future<void> deleteMessageForEveryone(String otherUserId, String messageId) async {
    final String cId = chatId(_myUserId!, otherUserId);
    await _fs
        .collection('chats')
        .doc(cId)
        .collection('messages')
        .doc(messageId)
        .update({
      'deletedFor': 'all',
      'body': '',
      'imageUrl': null,
      'type': 'deleted',
    });
  }

  /// Send a message to another user.
  Future<void> sendMessage({
    required String otherUserId,
    required String body,
    required String myDisplayName,
    String? myAvatarUrl,
    required String otherDisplayName,
    String? otherAvatarUrl,
    String type = 'text',
    String? imageUrl,
    String? idempotencyKey,
  }) async {
    final String cId = chatId(_myUserId!, otherUserId);
    final DocumentReference chatDoc = _fs.collection('chats').doc(cId);
    final CollectionReference messagesCol = chatDoc.collection('messages');

    // Duplicate send protection via idempotency key
    if (idempotencyKey != null) {
      final existing = await messagesCol
          .where('idempotencyKey', isEqualTo: idempotencyKey)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) return; // Already sent
    }

    final now = FieldValue.serverTimestamp();

    // Add the message
    await messagesCol.add({
      'senderId': _myUserId,
      'body': body,
      'type': type,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      'createdAt': now,
      'deliveredAt': null,
      'readAt': null,
    });

    final String preview = type == 'image' ? '📷 Photo' : body;

    // Update chat metadata (create if doesn't exist)
    await chatDoc.set({
      'participants': [_myUserId, otherUserId],
      'lastMessage': preview,
      'lastMessageAt': now,
      'lastSenderId': _myUserId,
      'name_$_myUserId': myDisplayName,
      'name_$otherUserId': otherDisplayName,
      if (myAvatarUrl != null) 'avatar_$_myUserId': myAvatarUrl,
      if (otherAvatarUrl != null) 'avatar_$otherUserId': otherAvatarUrl,
      'unread_$otherUserId': FieldValue.increment(1),
    }, SetOptions(merge: true));

    // Send push notification to recipient (fire-and-forget)
    onSendPush?.call(otherUserId, myDisplayName, preview);
  }

  /// Upload an image and send it as a message.
  /// Validates file size (max 5MB) and format before uploading.
  Future<void> sendImage({
    required String otherUserId,
    required File imageFile,
    required String myDisplayName,
    String? myAvatarUrl,
    required String otherDisplayName,
    String? otherAvatarUrl,
  }) async {
    // Image validation
    final int fileSize = await imageFile.length();
    if (fileSize > 5 * 1024 * 1024) {
      throw Exception('Image too large (max 5 MB)');
    }
    final String ext = imageFile.path.split('.').last.toLowerCase();
    if (!{'jpg', 'jpeg', 'png', 'webp', 'heic'}.contains(ext)) {
      throw Exception('Unsupported image format');
    }

    final String cId = chatId(_myUserId!, otherUserId);
    final String fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
    final Reference ref =
        FirebaseStorage.instance.ref('chats/$cId/$fileName');

    await ref.putFile(imageFile, SettableMetadata(contentType: 'image/$ext'));
    final String downloadUrl = await ref.getDownloadURL();

    await sendMessage(
      otherUserId: otherUserId,
      body: '',
      myDisplayName: myDisplayName,
      myAvatarUrl: myAvatarUrl,
      otherDisplayName: otherDisplayName,
      otherAvatarUrl: otherAvatarUrl,
      type: 'image',
      imageUrl: downloadUrl,
    );
  }

  /// Mark all messages from the other user as delivered (app received them).
  Future<void> markDelivered(String otherUserId) async {
    final String cId = chatId(_myUserId!, otherUserId);
    final DocumentReference chatDoc = _fs.collection('chats').doc(cId);

    final QuerySnapshot<Map<String, dynamic>> undelivered = await chatDoc
        .collection('messages')
        .where('senderId', isEqualTo: otherUserId)
        .where('deliveredAt', isNull: true)
        .get();

    if (undelivered.docs.isEmpty) return;

    final WriteBatch batch = _fs.batch();
    for (final doc in undelivered.docs) {
      batch.update(doc.reference, {'deliveredAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  /// Mark all messages from the other user as read.
  Future<void> markRead(String otherUserId) async {
    final String cId = chatId(_myUserId!, otherUserId);
    final DocumentReference chatDoc = _fs.collection('chats').doc(cId);

    // Reset my unread counter
    await chatDoc.set({
      'unread_$_myUserId': 0,
    }, SetOptions(merge: true));

    // Mark individual unread messages from the other user
    final QuerySnapshot<Map<String, dynamic>> unread = await chatDoc
        .collection('messages')
        .where('senderId', isEqualTo: otherUserId)
        .where('readAt', isNull: true)
        .get();

    final WriteBatch batch = _fs.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {
        'readAt': FieldValue.serverTimestamp(),
        'deliveredAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Load older messages (pagination).
  Future<List<FirebaseMessage>> loadMoreMessages(
      String otherUserId, DateTime before) async {
    final String cId = chatId(_myUserId!, otherUserId);
    final QuerySnapshot<Map<String, dynamic>> snap = await _fs
        .collection('chats')
        .doc(cId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .startAfter([Timestamp.fromDate(before)])
        .limit(50)
        .get();

    return snap.docs.reversed.map((doc) {
      final data = doc.data();
      return FirebaseMessage(
        id: doc.id,
        senderId: data['senderId'] as String,
        body: (data['body'] as String?) ?? '',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
        readAt: (data['readAt'] as Timestamp?)?.toDate(),
        type: (data['type'] as String?) ?? 'text',
        imageUrl: data['imageUrl'] as String?,
      );
    }).toList();
  }

  // ── Live Room (RTDB) ────────────────────────────────────────────────────────

  /// RTDB ref for a live room's real-time data.
  DatabaseReference _liveRef(String roomId) => _rtdb.ref('live_rooms/$roomId');

  /// Write audience_count and set onDisconnect to decrement.
  Future<void> joinLiveRoom(String roomId) async {
    final DatabaseReference countRef = _liveRef(roomId).child('audience_count');
    await countRef.set(ServerValue.increment(1));
    await countRef.onDisconnect().set(ServerValue.increment(-1));
  }

  /// Decrement audience_count and cancel onDisconnect.
  Future<void> leaveLiveRoom(String roomId) async {
    final DatabaseReference countRef = _liveRef(roomId).child('audience_count');
    await countRef.onDisconnect().cancel();
    await countRef.set(ServerValue.increment(-1));
  }

  /// Listen to audience_count changes.
  StreamSubscription<DatabaseEvent> listenAudienceCount(
    String roomId,
    void Function(int count) onCount,
  ) {
    return _liveRef(roomId).child('audience_count').onValue.listen((event) {
      final int count = (event.snapshot.value as num?)?.toInt() ?? 0;
      onCount(count < 0 ? 0 : count);
    });
  }

  /// Push a comment to the room.
  void writeLiveComment(String roomId, String displayName, String text) {
    _liveRef(roomId).child('comments').push().set(<String, dynamic>{
      'name': displayName,
      'text': text,
      'ts': ServerValue.timestamp,
    });
  }

  /// Listen for new comments (child_added).
  StreamSubscription<DatabaseEvent> listenLiveComments(
    String roomId,
    void Function(String name, String text) onComment,
  ) {
    return _liveRef(roomId)
        .child('comments')
        .orderByChild('ts')
        .startAt(DateTime.now().millisecondsSinceEpoch)
        .onChildAdded
        .listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        onComment(
          (data['name'] as String?) ?? '',
          (data['text'] as String?) ?? '',
        );
      }
    });
  }

  /// Push a reaction (ephemeral).
  void writeLiveReaction(String roomId, String userId, String emoji) {
    _liveRef(roomId).child('reactions').push().set(<String, dynamic>{
      'userId': userId,
      'emoji': emoji,
      'ts': ServerValue.timestamp,
    });
  }

  /// Listen for new reactions.
  StreamSubscription<DatabaseEvent> listenLiveReactions(
    String roomId,
    String myUserId,
    void Function(String emoji) onReaction,
  ) {
    return _liveRef(roomId)
        .child('reactions')
        .orderByChild('ts')
        .startAt(DateTime.now().millisecondsSinceEpoch)
        .onChildAdded
        .listen((event) {
      final data = event.snapshot.value;
      if (data is Map && data['userId'] != myUserId) {
        onReaction((data['emoji'] as String?) ?? '❤️');
      }
    });
  }

  /// Push a gift event (called after backend confirms economy).
  void writeLiveGift(String roomId, String senderName, String giftId, String giftName, int quantity) {
    _liveRef(roomId).child('gifts').push().set(<String, dynamic>{
      'senderName': senderName,
      'giftId': giftId,
      'giftName': giftName,
      'quantity': quantity,
      'ts': ServerValue.timestamp,
    });
  }

  /// Listen for new gifts.
  StreamSubscription<DatabaseEvent> listenLiveGifts(
    String roomId,
    void Function(String senderName, String giftName, int quantity) onGift,
  ) {
    return _liveRef(roomId)
        .child('gifts')
        .orderByChild('ts')
        .startAt(DateTime.now().millisecondsSinceEpoch)
        .onChildAdded
        .listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        onGift(
          (data['senderName'] as String?) ?? '',
          (data['giftName'] as String?) ?? '',
          (data['quantity'] as num?)?.toInt() ?? 1,
        );
      }
    });
  }

  /// Mark room as ended in RTDB (host calls this).
  void endLiveRoom(String roomId) {
    _liveRef(roomId).child('status').set('ended');
    // Clean up after 10 seconds
    Future<void>.delayed(const Duration(seconds: 10), () {
      _liveRef(roomId).remove();
    });
  }

  /// Listen for room ended.
  StreamSubscription<DatabaseEvent> listenRoomEnded(
    String roomId,
    void Function() onEnded,
  ) {
    return _liveRef(roomId).child('status').onValue.listen((event) {
      if (event.snapshot.value == 'ended') {
        onEnded();
      }
    });
  }

  /// Initialize a room node when going live.
  void initLiveRoom(String roomId) {
    _liveRef(roomId).set(<String, dynamic>{
      'status': 'live',
      'audience_count': 0,
      'started_at': ServerValue.timestamp,
    });
    // If host disconnects, mark room ended
    _liveRef(roomId).child('status').onDisconnect().set('ended');
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

class FirebaseConversation {
  FirebaseConversation({
    required this.chatId,
    required this.otherUserId,
    required this.otherDisplayName,
    this.otherAvatarUrl,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  final String chatId;
  final String otherUserId;
  final String otherDisplayName;
  final String? otherAvatarUrl;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
}

class FirebaseMessage {
  FirebaseMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.deliveredAt,
    this.readAt,
    this.type = 'text',
    this.imageUrl,
    this.deletedFor,
  });

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String type;
  final String? imageUrl;
  final dynamic deletedFor; // 'all' or List<String> of user IDs
}
