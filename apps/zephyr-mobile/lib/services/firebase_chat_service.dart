import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'direct_call_signals.dart';
import 'live_room_realtime.dart';
import 'presence_realtime.dart';
import 'realtime_profiles.dart';

/// Isolated Firebase chat service — completely separate from existing messaging.
/// Uses Firestore for messages and RTDB for presence (onDisconnect).
class FirebaseChatService {
  FirebaseChatService._();
  static final FirebaseChatService instance = FirebaseChatService._();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final PresenceRealtime presence = PresenceRealtime();
  final ProfilesRealtime profiles = ProfilesRealtime();
  final DirectCallSignals directSignals = DirectCallSignals();
  final LiveRoomRealtime liveRooms = LiveRoomRealtime();

  String? _myUserId;
  String get myUserId => _myUserId!;

  /// Callback to send push notifications via the backend API.
  Future<void> Function(String recipientId, String title, String body)?
  onSendPush;

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
      profiles.bindUser(zephyrUserId);
      await presence.bindUser(zephyrUserId);
    } else {
      profiles.bindUser(zephyrUserId);
      await presence.writeCurrent();
    }
  }

  // ── Realtime module facade ─────────────────────────────────────────────────

  ValueNotifier<int> get presenceVersion => presence.version;
  ValueNotifier<int> get profileVersion => profiles.version;

  bool? isOnlineCached(String userId) => presence.isOnlineCached(userId);
  String? presenceStateCached(String userId) => presence.stateCached(userId);
  String? presenceRoomIdCached(String userId) => presence.roomIdCached(userId);
  void warmPresence(List<String> userIds) => presence.warm(userIds);

  RtdbProfile? profileCached(String userId) => profiles.cached(userId);
  void warmProfiles(List<String> userIds) => profiles.warm(userIds);

  Future<void> writeMyProfile({
    required String displayName,
    String? avatarUrl,
    required String countryCode,
    required String language,
    String? birthday,
  }) {
    return profiles.writeMine(
      displayName: displayName,
      avatarUrl: avatarUrl,
      countryCode: countryCode,
      language: language,
      birthday: birthday,
    );
  }

  /// Listen to a user's presence state.
  Stream<Map<String, dynamic>> watchPresence(String userId) =>
      presence.watch(userId);

  /// Mark current user as "live" in Firebase RTDB presence.
  void setLiveStatus({String? roomId}) => presence.setLive(roomId: roomId);

  /// Restore current user to "online" (call when ending a live stream).
  void clearLiveStatus() => presence.clearLive();

  /// Mark current user as "away" (idle in foreground for 60s, no touches).
  void setAwayStatus() => presence.setAway();

  /// Mark current user as offline (app backgrounded / screen locked).
  void setBackgroundOffline() => presence.setBackgroundOffline();

  /// Restore current user to "online" (app foregrounded / user active).
  void restoreOnlineStatus() => presence.restoreOnline();

  /// Mark current user as "busy" in Firebase RTDB presence.
  void setBusyStatus({String? sessionId, String activity = 'direct_call'}) {
    presence.setBusy(sessionId: sessionId, activity: activity);
  }

  /// Clear busy and restore to "online".
  void clearBusyStatus() => presence.clearBusy();

  /// Explicitly go offline (logout). Cancels onDisconnect and clears presence.
  Future<void> setOfflineStatus() => presence.setOffline();

  /// Clears all local listeners/caches and signs out Firebase Auth.
  Future<void> clearSession() async {
    await presence.clearSession();
    await profiles.clearSession();
    _myUserId = null;

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Ignore sign-out errors.
    }
  }

  // ── Direct Call Signaling (RTDB) ─────────────────────────────────────────────

  /// Reference to a user's call signaling node.
  DatabaseReference callSignalRef(String userId) =>
      directSignals.refForUser(userId);

  /// Write a "ringing" signal to the target user's node.
  /// Also sets onDisconnect to auto-remove the node if the caller crashes.
  Future<void> writeRinging({
    required String targetUserId,
    required String callerId,
    required String callerName,
    String? callerAvatarUrl,
    required String sessionId,
  }) {
    return directSignals.writeRinging(
      targetUserId: targetUserId,
      callerId: callerId,
      callerName: callerName,
      callerAvatarUrl: callerAvatarUrl,
      sessionId: sessionId,
    );
  }

  /// Cancel the onDisconnect handler (call this when the call connects to Agora,
  /// so a brief RTDB disconnect doesn't kill the active call).
  Future<void> cancelOnDisconnect(String targetUserId) {
    return directSignals.cancelOnDisconnect(targetUserId);
  }

  /// Update the status field on my own signal node (e.g. 'accepted', 'declined').
  Future<void> writeCallStatus(String userId, String status) {
    return directSignals.writeStatus(userId, status);
  }

  /// Remove the call signaling node (cleanup).
  Future<void> removeCallSignal(String userId) {
    return directSignals.remove(userId);
  }

  /// Listen for changes on a user's call signal node.
  /// Returns the subscription so the caller can cancel it.
  StreamSubscription<DatabaseEvent> listenCallSignal(
    String userId,
    void Function(Map<String, dynamic>? data) onData,
  ) {
    return directSignals.listen(userId, onData);
  }

  // ── Chat ID ─────────────────────────────────────────────────────────────────

  /// Deterministic chat ID from two user IDs (sorted).
  String chatId(String userId1, String userId2) {
    final List<String> sorted = [userId1, userId2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  // ── Conversations (Inbox) ───────────────────────────────────────────────────

  /// Ensure the chat doc exists with participants. Call before listening to messages.
  /// Needed because Firestore security rules require the parent doc's participants array.
  /// Optionally writes display names/avatars as fallback for inbox display
  /// (RTDB profiles remain the source of truth via profileCached).
  Future<void> ensureChatDoc(
    String otherUserId, {
    String? myDisplayName,
    String? myAvatarUrl,
    String? otherDisplayName,
    String? otherAvatarUrl,
  }) async {
    final String cId = chatId(_myUserId!, otherUserId);
    await _fs.collection('chats').doc(cId).set({
      'participants': [_myUserId, otherUserId],
      if (myDisplayName != null) 'name_$_myUserId': myDisplayName,
      if (myAvatarUrl != null) 'avatar_$_myUserId': myAvatarUrl,
      if (otherDisplayName != null) 'name_$otherUserId': otherDisplayName,
      if (otherAvatarUrl != null) 'avatar_$otherUserId': otherAvatarUrl,
    }, SetOptions(merge: true));
  }

  /// Stream of conversations for the current user, ordered by last message time.
  Stream<List<FirebaseConversation>> watchConversations() {
    return _fs
        .collection('chats')
        .where('participants', arrayContains: _myUserId)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
          final list = snap.docs
              .map((doc) {
                final data = doc.data();
                final List<String> participants = List<String>.from(
                  data['participants'] as List,
                );
                final String? otherUserId = participants
                    .cast<String?>()
                    .firstWhere((id) => id != _myUserId, orElse: () => null);
                if (otherUserId == null) return null; // self-chat, skip
                final int unread = (data['unread_$_myUserId'] as int?) ?? 0;
                return FirebaseConversation(
                  chatId: doc.id,
                  otherUserId: otherUserId,
                  otherDisplayName:
                      (data['name_$otherUserId'] as String?) ?? 'User',
                  otherAvatarUrl: data['avatar_$otherUserId'] as String?,
                  lastMessage: (data['lastMessage'] as String?) ?? '',
                  lastMessageAt:
                      (data['lastMessageAt'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                  unreadCount: unread,
                );
              })
              .whereType<FirebaseConversation>()
              .toList();
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
          return snap.docs
              .map((doc) {
                final data = doc.data();
                return FirebaseMessage(
                  id: doc.id,
                  senderId: data['senderId'] as String,
                  body: (data['body'] as String?) ?? '',
                  createdAt:
                      (data['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                  deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
                  readAt: (data['readAt'] as Timestamp?)?.toDate(),
                  type: (data['type'] as String?) ?? 'text',
                  imageUrl: data['imageUrl'] as String?,
                  deletedFor: data['deletedFor'],
                );
              })
              .where((msg) {
                // Filter deleted messages
                if (msg.deletedFor == 'all') {
                  return true; // Show "deleted" placeholder
                }
                if (msg.deletedFor is List &&
                    (msg.deletedFor as List).contains(_myUserId)) {
                  return false; // Hidden for me
                }
                return true;
              })
              .toList();
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
    final doc = await _fs
        .collection('blocks')
        .doc('${_myUserId}_$otherUserId')
        .get();
    return doc.exists;
  }

  /// Check if the other user blocked me.
  Future<bool> isBlockedBy(String otherUserId) async {
    final doc = await _fs
        .collection('blocks')
        .doc('${otherUserId}_$_myUserId')
        .get();
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
  Future<void> deleteMessageForEveryone(
    String otherUserId,
    String messageId,
  ) async {
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
    String type = 'text',
    String? imageUrl,
    String? idempotencyKey,
  }) async {
    final String cId = chatId(_myUserId!, otherUserId);
    final DocumentReference chatDoc = _fs.collection('chats').doc(cId);
    final CollectionReference messagesCol = chatDoc.collection('messages');

    // Ensure chat doc exists with participants BEFORE any subcollection ops.
    // Security rules on /messages require the parent doc's participants array.
    await chatDoc.set({
      'participants': [_myUserId, otherUserId],
    }, SetOptions(merge: true));

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

    // Update chat metadata — keep sender name/avatar as inbox fallback
    // (RTDB profiles remain the primary source via profileCached)
    await chatDoc.set({
      'lastMessage': preview,
      'lastMessageAt': now,
      'lastSenderId': _myUserId,
      'unread_$otherUserId': FieldValue.increment(1),
      'name_$_myUserId': myDisplayName,
      if (myAvatarUrl != null) 'avatar_$_myUserId': myAvatarUrl,
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
    final Reference ref = FirebaseStorage.instance.ref('chats/$cId/$fileName');

    await ref.putFile(imageFile, SettableMetadata(contentType: 'image/$ext'));
    final String downloadUrl = await ref.getDownloadURL();

    await sendMessage(
      otherUserId: otherUserId,
      body: '',
      myDisplayName: myDisplayName,
      myAvatarUrl: myAvatarUrl,
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
      batch.update(doc.reference, {
        'deliveredAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Mark all messages from the other user as read.
  Future<void> markRead(String otherUserId) async {
    final String cId = chatId(_myUserId!, otherUserId);
    final DocumentReference chatDoc = _fs.collection('chats').doc(cId);

    // Reset my unread counter
    await chatDoc.set({'unread_$_myUserId': 0}, SetOptions(merge: true));

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
    String otherUserId,
    DateTime before,
  ) async {
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
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
        readAt: (data['readAt'] as Timestamp?)?.toDate(),
        type: (data['type'] as String?) ?? 'text',
        imageUrl: data['imageUrl'] as String?,
      );
    }).toList();
  }

  // ── Live Room (RTDB) ────────────────────────────────────────────────────────

  /// Write audience_count and set onDisconnect to decrement.
  Future<void> joinLiveRoom(String roomId) =>
      liveRooms.joinAudience(roomId, _myUserId ?? '');

  /// Decrement audience_count and cancel onDisconnect.
  Future<void> leaveLiveRoom(String roomId) =>
      liveRooms.leaveAudience(roomId, _myUserId ?? '');

  /// Listen to audience_count changes.
  StreamSubscription<DatabaseEvent> listenAudienceCount(
    String roomId,
    void Function(int count) onCount,
  ) => liveRooms.listenAudienceCount(roomId, onCount);

  /// Push a comment to the room.
  void writeLiveComment(String roomId, String displayName, String text) {
    liveRooms.writeComment(roomId, displayName, text);
  }

  /// Listen for new comments (child_added).
  StreamSubscription<DatabaseEvent> listenLiveComments(
    String roomId,
    void Function(String name, String text) onComment,
  ) => liveRooms.listenComments(roomId, onComment);

  /// Push a reaction (ephemeral).
  void writeLiveReaction(String roomId, String userId, String emoji) {
    liveRooms.writeReaction(roomId, userId, emoji);
  }

  /// Listen for new reactions.
  StreamSubscription<DatabaseEvent> listenLiveReactions(
    String roomId,
    String myUserId,
    void Function(String emoji) onReaction,
  ) => liveRooms.listenReactions(roomId, myUserId, onReaction);

  /// Push a gift event (called after backend confirms economy).
  void writeLiveGift(
    String roomId,
    String senderName,
    String giftId,
    String giftName,
    int quantity,
  ) {
    liveRooms.writeGift(roomId, senderName, giftId, giftName, quantity);
  }

  /// Listen for new gifts.
  StreamSubscription<DatabaseEvent> listenLiveGifts(
    String roomId,
    void Function(String senderName, String giftName, int quantity) onGift,
  ) => liveRooms.listenGifts(roomId, onGift);

  /// Mark room as ended in RTDB (host calls this).
  void endLiveRoom(String roomId) {
    liveRooms.endRoom(roomId);
  }

  /// Listen for room ended.
  StreamSubscription<DatabaseEvent> listenRoomEnded(
    String roomId,
    void Function() onEnded,
  ) => liveRooms.listenEnded(roomId, onEnded);

  /// Initialize a room node when going live.
  void initLiveRoom(String roomId, {required String hostUserId}) {
    liveRooms.initRoom(roomId, hostUserId: hostUserId);
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
