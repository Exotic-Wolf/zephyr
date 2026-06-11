import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'direct_call_signals.dart';
import 'live_room_realtime.dart';
import 'presence_realtime.dart';
import 'realtime_profiles.dart';

const int chatImageMaxUploadBytes = 4 * 1024 * 1024;
const int chatImageMaxEdge = 1440;
const int _chatImageMinEdge = 720;
const int _chatImageInitialQuality = 82;
const int _chatImageMinQuality = 58;

class PreparedChatImageUpload {
  const PreparedChatImageUpload({
    required this.file,
    required this.fileName,
    required this.contentType,
    required this.byteSize,
    required this.width,
    required this.height,
    required this.quality,
  });

  final File file;
  final String fileName;
  final String contentType;
  final int byteSize;
  final int width;
  final int height;
  final int quality;
}

Future<PreparedChatImageUpload> prepareChatImageForUpload(
  File imageFile, {
  Directory? outputDirectory,
  int maxBytes = chatImageMaxUploadBytes,
  int maxEdge = chatImageMaxEdge,
  int initialQuality = _chatImageInitialQuality,
  int minQuality = _chatImageMinQuality,
}) async {
  final Uint8List sourceBytes = await imageFile.readAsBytes();
  if (sourceBytes.isEmpty) {
    throw Exception('Unsupported image format');
  }

  final Map<String, Object> prepared = await compute(_prepareChatImageBytes, {
    'bytes': sourceBytes,
    'maxBytes': maxBytes,
    'maxEdge': maxEdge,
    'initialQuality': initialQuality,
    'minQuality': minQuality,
  });

  final Uint8List uploadBytes = prepared['bytes']! as Uint8List;
  final Directory tempDir = outputDirectory ?? await getTemporaryDirectory();
  final String fileName =
      'chat_${DateTime.now().microsecondsSinceEpoch}_${uploadBytes.length}.jpg';
  final File uploadFile = File(p.join(tempDir.path, fileName));
  await uploadFile.writeAsBytes(uploadBytes, flush: false);

  return PreparedChatImageUpload(
    file: uploadFile,
    fileName: fileName,
    contentType: 'image/jpeg',
    byteSize: uploadBytes.length,
    width: prepared['width']! as int,
    height: prepared['height']! as int,
    quality: prepared['quality']! as int,
  );
}

Map<String, Object> _prepareChatImageBytes(Map<String, Object> input) {
  final Uint8List bytes = input['bytes']! as Uint8List;
  final int maxBytes = input['maxBytes']! as int;
  final int maxEdge = input['maxEdge']! as int;
  final int initialQuality = input['initialQuality']! as int;
  final int minQuality = input['minQuality']! as int;

  final img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception('Unsupported image format');
  }

  final img.Image source = img.bakeOrientation(decoded);
  final int sourceLongestEdge = math.max(source.width, source.height);
  int targetEdge = math.min(sourceLongestEdge, maxEdge);
  img.Image candidate = _resizeForLongestEdge(source, targetEdge);

  while (true) {
    int quality = initialQuality;
    while (quality >= minQuality) {
      final Uint8List encoded = Uint8List.fromList(
        img.encodeJpg(candidate, quality: quality),
      );
      if (encoded.length <= maxBytes) {
        return {
          'bytes': encoded,
          'width': candidate.width,
          'height': candidate.height,
          'quality': quality,
        };
      }
      quality -= 6;
    }

    if (targetEdge <= _chatImageMinEdge) break;
    targetEdge = math.max(_chatImageMinEdge, (targetEdge * 0.84).round());
    candidate = _resizeForLongestEdge(source, targetEdge);
  }

  throw Exception('Photo is too large after compression');
}

img.Image _resizeForLongestEdge(img.Image source, int longestEdge) {
  final int sourceLongestEdge = math.max(source.width, source.height);
  if (sourceLongestEdge <= longestEdge) return source;
  final double scale = longestEdge / sourceLongestEdge;
  return img.copyResize(
    source,
    width: math.max(1, (source.width * scale).round()),
    height: math.max(1, (source.height * scale).round()),
    interpolation: img.Interpolation.average,
  );
}

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
  List<FirebaseConversation> _conversationCache = const [];
  final Map<String, List<FirebaseMessage>> _messageCacheByChatId = {};

  /// Callback to send a backend-verified push for a committed Firestore message.
  Future<void> Function(String recipientId, String chatId, String messageId)?
  onSendPush;

  /// Initialize: sign in with custom Firebase token and set up presence.
  /// [zephyrUserId] is the app's user ID (UUID). Safe to call multiple times.
  /// [firebaseToken] is a custom token from the backend. It is required on
  /// first init and should be passed again whenever the API session is restored
  /// or refreshed so Firebase Auth carries the active session claims.
  Future<void> init(String zephyrUserId, {String? firebaseToken}) async {
    if (_myUserId != null && _myUserId != zephyrUserId) {
      _conversationCache = const [];
      _messageCacheByChatId.clear();
    }
    final bool firstInit = _myUserId != zephyrUserId;
    _myUserId = zephyrUserId;

    if (firstInit || (firebaseToken != null && firebaseToken.isNotEmpty)) {
      if (firebaseToken == null || firebaseToken.isEmpty) {
        throw StateError('Firebase custom token required for chat init');
      }
      await FirebaseAuth.instance.signInWithCustomToken(firebaseToken);
    }

    if (firstInit) {
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
  DateTime? demoNextRotationAtCached(String userId) {
    return presence.demoNextRotationAtCached(userId);
  }

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

  /// Mark free live as paused while a non-interruptible call/premium flow owns UX.
  void pauseLiveStatus() => presence.pauseLive();

  /// Resume a paused free live state.
  void resumeLiveStatus() => presence.resumeLive();

  /// Mark current user as non-interruptible premium live host.
  void setPremiumLiveHostStatus({required String roomId}) {
    presence.setPremiumLiveHost(roomId: roomId);
  }

  /// Mark current user as non-interruptible premium live viewer.
  void setPremiumLiveViewerStatus({
    required String roomId,
    String? premiumRoomSessionId,
  }) {
    presence.setPremiumLiveViewer(
      roomId: roomId,
      premiumRoomSessionId: premiumRoomSessionId,
    );
  }

  /// Clear premium live state and return to normal availability.
  void clearPremiumLiveStatus() => presence.clearPremiumLive();

  /// Mark current user as "away" (idle in foreground for 2 min, no touches).
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
    _conversationCache = const [];
    _messageCacheByChatId.clear();

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
    void Function(Map<String, dynamic>? data) onData, {
    void Function(Object error)? onError,
  }) {
    return directSignals.listen(userId, onData, onError: onError);
  }

  // ── Chat ID ─────────────────────────────────────────────────────────────────

  /// Deterministic chat ID from two user IDs (sorted).
  String chatId(String userId1, String userId2) {
    final List<String> sorted = [userId1, userId2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  List<String> _participantsFor(String otherUserId) {
    return <String>[_myUserId!, otherUserId]..sort();
  }

  Map<String, bool> _participantIdsFor(String otherUserId) {
    return <String, bool>{
      for (final String userId in _participantsFor(otherUserId)) userId: true,
    };
  }

  bool isInitializedFor(String zephyrUserId) => _myUserId == zephyrUserId;

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
      'participants': _participantsFor(otherUserId),
      'participantIds': _participantIdsFor(otherUserId),
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
        .where(
          FieldPath(<String>['participantIds', _myUserId!]),
          isEqualTo: true,
        )
        .snapshots()
        .map(_conversationsFromSnapshot);
  }

  List<FirebaseConversation> cachedConversations() => _conversationCache;

  Future<List<FirebaseConversation>> loadCachedConversations() async {
    if (_conversationCache.isNotEmpty) return _conversationCache;
    if (_myUserId == null) return const [];
    try {
      final QuerySnapshot<Map<String, dynamic>> snap = await _fs
          .collection('chats')
          .where(
            FieldPath(<String>['participantIds', _myUserId!]),
            isEqualTo: true,
          )
          .get(const GetOptions(source: Source.cache));
      return _conversationsFromSnapshot(snap);
    } catch (error) {
      debugPrint('Firestore cached conversations unavailable: $error');
      return _conversationCache;
    }
  }

  List<FirebaseConversation> _conversationsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    final List<FirebaseConversation> list = snap.docs
        .map(_conversationFromDoc)
        .whereType<FirebaseConversation>()
        .toList();
    list.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    _conversationCache = List<FirebaseConversation>.unmodifiable(list);
    return list;
  }

  FirebaseConversation? _conversationFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    final Object? participantsValue = data['participants'];
    final Object? participantIdsValue = data['participantIds'];
    final List<String> participants = participantsValue is List
        ? participantsValue.whereType<String>().toList()
        : participantIdsValue is Map
        ? participantIdsValue.keys.whereType<String>().toList()
        : const <String>[];
    final String? otherUserId = participants.cast<String?>().firstWhere(
      (String? id) => id != null && id != _myUserId,
      orElse: () => null,
    );
    if (otherUserId == null) return null;
    final int unread = (data['unread_$_myUserId'] as int?) ?? 0;
    return FirebaseConversation(
      chatId: doc.id,
      otherUserId: otherUserId,
      otherDisplayName: (data['name_$otherUserId'] as String?) ?? 'User',
      otherAvatarUrl: data['avatar_$otherUserId'] as String?,
      lastMessage: (data['lastMessage'] as String?) ?? '',
      lastMessageAt:
          (data['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: unread,
    );
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
          return _messagesFromSnapshot(cId, snap);
        });
  }

  List<FirebaseMessage> cachedMessages(String otherUserId) {
    if (_myUserId == null) return const [];
    final String cId = chatId(_myUserId!, otherUserId);
    return _messageCacheByChatId[cId] ?? const [];
  }

  Future<List<FirebaseMessage>> loadCachedMessages(String otherUserId) async {
    final List<FirebaseMessage> memory = cachedMessages(otherUserId);
    if (memory.isNotEmpty) return memory;
    if (_myUserId == null) return const [];
    final String cId = chatId(_myUserId!, otherUserId);
    try {
      final QuerySnapshot<Map<String, dynamic>> snap = await _fs
          .collection('chats')
          .doc(cId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .limitToLast(100)
          .get(const GetOptions(source: Source.cache));
      return _messagesFromSnapshot(cId, snap);
    } catch (error) {
      debugPrint('Firestore cached messages unavailable for $cId: $error');
      return memory;
    }
  }

  List<FirebaseMessage> _messagesFromSnapshot(
    String chatId,
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    final List<FirebaseMessage> list = snap.docs
        .map(_messageFromDoc)
        .whereType<FirebaseMessage>()
        .where(_messageVisibleForMe)
        .toList();
    _messageCacheByChatId[chatId] = List<FirebaseMessage>.unmodifiable(list);
    return list;
  }

  FirebaseMessage? _messageFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    final String? senderId = data['senderId'] as String?;
    if (senderId == null || senderId.isEmpty) return null;
    return FirebaseMessage(
      id: doc.id,
      senderId: senderId,
      body: (data['body'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      type: (data['type'] as String?) ?? 'text',
      imageUrl: data['imageUrl'] as String?,
      deletedFor: data['deletedFor'],
    );
  }

  bool _messageVisibleForMe(FirebaseMessage msg) {
    if (msg.deletedFor == 'all') {
      return true;
    }
    if (msg.deletedFor is List &&
        (msg.deletedFor as List).contains(_myUserId)) {
      return false;
    }
    return true;
  }

  // ── Block / Report ─────────────────────────────────────────────────────────

  /// Block/report are backend-owned. Firestore keeps only backend/Admin block
  /// projections so rules can reject blocked message sends.
  Future<void> blockUser(String otherUserId) async {
    throw UnsupportedError('Use backend block API');
  }

  /// Unblock a user.
  Future<void> unblockUser(String otherUserId) async {
    throw UnsupportedError('Use backend unblock API');
  }

  /// Check if current user blocked the other user.
  Future<bool> isBlocked(String otherUserId) async {
    throw UnsupportedError('Use backend block status API');
  }

  /// Check if the other user blocked me.
  Future<bool> isBlockedBy(String otherUserId) async {
    throw UnsupportedError('Use backend block status API');
  }

  /// Report a user with reason.
  Future<void> reportUser(String otherUserId, String reason) async {
    throw UnsupportedError('Use backend report API');
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
      'participants': _participantsFor(otherUserId),
      'participantIds': _participantIdsFor(otherUserId),
    }, SetOptions(merge: true));

    final now = FieldValue.serverTimestamp();
    final String messageId = idempotencyKey ?? messagesCol.doc().id;
    final DocumentReference messageDoc = messagesCol.doc(messageId);

    final bool created = await _fs.runTransaction<bool>((tx) async {
      if (idempotencyKey != null) {
        final existing = await tx.get(messageDoc);
        if (existing.exists) return false;
      }

      final String preview = type == 'image' ? 'Photo' : body;

      // Keep message body, unread count, and inbox metadata in one commit.
      tx.set(chatDoc, {
        'participants': _participantsFor(otherUserId),
        'participantIds': _participantIdsFor(otherUserId),
        'lastMessage': preview,
        'lastMessageAt': now,
        'lastSenderId': _myUserId,
        'unread_$otherUserId': FieldValue.increment(1),
        'name_$_myUserId': myDisplayName,
        if (myAvatarUrl != null) 'avatar_$_myUserId': myAvatarUrl,
      }, SetOptions(merge: true));

      tx.set(messageDoc, {
        'senderId': _myUserId,
        'body': body,
        'type': type,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
        'createdAt': now,
        'deliveredAt': null,
        'readAt': null,
      });
      return true;
    });

    // Push is backend-verified against the committed Firestore message.
    // It must never make a committed chat message look failed in the UI.
    final push = onSendPush;
    if (created && push != null) {
      unawaited(
        Future<void>.sync(() => push(otherUserId, cId, messageId)).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          debugPrint('Chat push relay failed for $messageId: $error');
        }),
      );
    }
  }

  Future<bool> sentMessageExists({
    required String otherUserId,
    required String messageId,
  }) async {
    final String cId = chatId(_myUserId!, otherUserId);
    final DocumentSnapshot snapshot = await _fs
        .collection('chats')
        .doc(cId)
        .collection('messages')
        .doc(messageId)
        .get();
    if (!snapshot.exists) return false;
    final data = snapshot.data() as Map<String, dynamic>?;
    return data?['senderId'] == _myUserId;
  }

  /// Upload a normalized chat image.
  ///
  /// The binary is stored in Firebase Storage at
  /// chats/{chatId}/{senderId}/{fileName}; Firestore stores only message
  /// metadata and the returned download URL.
  Future<String> uploadChatImage({
    required String otherUserId,
    required File imageFile,
    void Function(double progress)? onProgress,
  }) async {
    final PreparedChatImageUpload prepared = await prepareChatImageForUpload(
      imageFile,
    );
    final Reference ref = await _prepareChatImageUploadRef(
      otherUserId: otherUserId,
      fileName: prepared.fileName,
    );
    await _debugLogChatImageUploadAuth(
      phase: 'start',
      ref: ref,
      prepared: prepared,
    );
    final UploadTask task = ref.putFile(
      prepared.file,
      SettableMetadata(
        contentType: prepared.contentType,
        cacheControl: 'public,max-age=31536000,immutable',
        customMetadata: {
          'byteSize': prepared.byteSize.toString(),
          'width': prepared.width.toString(),
          'height': prepared.height.toString(),
          'quality': prepared.quality.toString(),
        },
      ),
    );

    final StreamSubscription<TaskSnapshot>? sub = onProgress == null
        ? null
        : task.snapshotEvents.listen((TaskSnapshot snapshot) {
            final int total = snapshot.totalBytes;
            if (total <= 0) return;
            onProgress(snapshot.bytesTransferred / total);
          });

    try {
      late final TaskSnapshot snapshot;
      try {
        snapshot = await task;
        onProgress?.call(1.0);
        await _debugLogChatImageUploadAuth(
          phase: 'upload-committed',
          ref: snapshot.ref,
          prepared: prepared,
        );
      } on FirebaseException catch (error) {
        await _debugLogChatImageUploadAuth(
          phase: 'upload-failed:${error.plugin}/${error.code}',
          ref: ref,
          prepared: prepared,
        );
        rethrow;
      }

      try {
        final String downloadUrl = await snapshot.ref.getDownloadURL();
        await _debugLogChatImageUploadAuth(
          phase: 'download-url-ok',
          ref: snapshot.ref,
          prepared: prepared,
        );
        return downloadUrl;
      } on FirebaseException catch (error) {
        await _debugLogChatImageUploadAuth(
          phase: 'download-url-failed:${error.plugin}/${error.code}',
          ref: snapshot.ref,
          prepared: prepared,
        );
        rethrow;
      }
    } finally {
      await sub?.cancel();
    }
  }

  Future<void> _debugLogChatImageUploadAuth({
    required String phase,
    required Reference ref,
    required PreparedChatImageUpload prepared,
  }) async {
    if (!kDebugMode) return;
    try {
      final User? firebaseUser = FirebaseAuth.instance.currentUser;
      final IdTokenResult? token = firebaseUser == null
          ? null
          : await firebaseUser.getIdTokenResult();
      final Object? sessionClaim = token?.claims?['sessionId'];
      final Object? deviceClaim = token?.claims?['deviceId'];
      debugPrint(
        'Chat image upload $phase: '
        'appUser=${_shortDebugId(_myUserId)} '
        'firebaseUid=${_shortDebugId(firebaseUser?.uid)} '
        'hasSessionClaim=${sessionClaim is String && sessionClaim.isNotEmpty} '
        'session=${_shortDebugId(sessionClaim is String ? sessionClaim : null)} '
        'hasDeviceClaim=${deviceClaim is String && deviceClaim.isNotEmpty} '
        'device=${_shortDebugId(deviceClaim is String ? deviceClaim : null)} '
        'size=${prepared.byteSize} '
        'contentType=${prepared.contentType} '
        'path=${ref.fullPath}',
      );
    } catch (error) {
      debugPrint('Chat image upload debug snapshot failed: $error');
    }
  }

  String _shortDebugId(String? value) {
    if (value == null || value.isEmpty) return 'none';
    if (value.length <= 8) return value;
    return '${value.substring(0, 8)}...';
  }

  Future<void> sendImage({
    required String otherUserId,
    required File imageFile,
    required String myDisplayName,
    String? myAvatarUrl,
    String body = '',
    String? idempotencyKey,
  }) async {
    final String downloadUrl = await uploadChatImage(
      otherUserId: otherUserId,
      imageFile: imageFile,
    );

    await sendMessage(
      otherUserId: otherUserId,
      body: body,
      myDisplayName: myDisplayName,
      myAvatarUrl: myAvatarUrl,
      type: 'image',
      imageUrl: downloadUrl,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<Reference> _prepareChatImageUploadRef({
    required String otherUserId,
    required String fileName,
  }) async {
    final String cId = chatId(_myUserId!, otherUserId);
    await _fs.collection('chats').doc(cId).set({
      'participants': _participantsFor(otherUserId),
      'participantIds': _participantIdsFor(otherUserId),
    }, SetOptions(merge: true));

    final Reference ref = FirebaseStorage.instance.ref(
      'chats/$cId/$_myUserId/$fileName',
    );

    return ref;
  }

  /// Mark all messages from the other user as delivered (app received them).
  Future<void> markDelivered(String otherUserId) async {
    try {
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
    } catch (error) {
      debugPrint('Firestore delivery receipt skipped: $error');
    }
  }

  /// Mark all messages from the other user as read.
  Future<void> markRead(String otherUserId) async {
    try {
      final String cId = chatId(_myUserId!, otherUserId);
      final DocumentReference chatDoc = _fs.collection('chats').doc(cId);

      // Reset my unread counter
      await chatDoc.set({
        'participants': _participantsFor(otherUserId),
        'participantIds': _participantIdsFor(otherUserId),
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
    } catch (error) {
      debugPrint('Firestore read receipt skipped: $error');
    }
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

  /// Write this user's audience presence and set onDisconnect cleanup.
  Future<void> joinLiveRoom(String roomId) =>
      liveRooms.joinAudience(roomId, _myUserId ?? '');

  /// Remove this user's audience presence and cancel onDisconnect cleanup.
  Future<void> leaveLiveRoom(String roomId) =>
      liveRooms.leaveAudience(roomId, _myUserId ?? '');

  /// Listen to derived audience count changes.
  StreamSubscription<DatabaseEvent> listenAudienceCount(
    String roomId,
    void Function(int count) onCount,
  ) => liveRooms.listenAudienceCount(roomId, onCount);

  /// Push a comment to the room.
  void writeLiveComment(String roomId, String displayName, String text) {
    liveRooms.writeComment(roomId, _myUserId ?? '', displayName, text);
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
  Future<void> initLiveRoom(String roomId, {required String hostUserId}) =>
      liveRooms.initRoom(roomId, hostUserId: hostUserId);
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
