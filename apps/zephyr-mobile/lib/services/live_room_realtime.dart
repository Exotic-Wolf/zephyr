import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import 'firebase_realtime_database.dart';

class LiveRoomRealtime {
  LiveRoomRealtime({FirebaseDatabase? database})
    : _rtdb = database ?? createZephyrRealtimeDatabase();

  final FirebaseDatabase _rtdb;

  DatabaseReference _roomRef(String roomId) => _rtdb.ref('live_rooms/$roomId');

  Future<void> joinAudience(String roomId, String userId) async {
    if (userId.isEmpty) return;

    final audienceRef = _roomRef(roomId).child('audience/$userId');
    await audienceRef.onDisconnect().remove();
    await audienceRef.set(<String, dynamic>{
      'joinedAt': ServerValue.timestamp,
      'lastSeen': ServerValue.timestamp,
    });
  }

  Future<void> leaveAudience(String roomId, String userId) async {
    if (userId.isEmpty) return;

    final audienceRef = _roomRef(roomId).child('audience/$userId');
    await audienceRef.onDisconnect().cancel();
    await audienceRef.remove();
  }

  StreamSubscription<DatabaseEvent> listenAudienceCount(
    String roomId,
    void Function(int count) onCount,
  ) {
    return _roomRef(roomId).child('audience').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        onCount(data.length);
      } else {
        onCount(0);
      }
    });
  }

  void writeComment(
    String roomId,
    String userId,
    String displayName,
    String text,
  ) {
    _roomRef(roomId).child('comments').push().set(<String, dynamic>{
      'userId': userId,
      'name': displayName,
      'text': text,
      'ts': ServerValue.timestamp,
    });
  }

  StreamSubscription<DatabaseEvent> listenComments(
    String roomId,
    void Function(String name, String text) onComment,
  ) {
    return _roomRef(roomId)
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

  void writeReaction(String roomId, String userId, String emoji) {
    _roomRef(roomId).child('reactions').push().set(<String, dynamic>{
      'userId': userId,
      'emoji': emoji,
      'ts': ServerValue.timestamp,
    });
  }

  StreamSubscription<DatabaseEvent> listenReactions(
    String roomId,
    String myUserId,
    void Function(String emoji) onReaction,
  ) {
    return _roomRef(roomId)
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

  StreamSubscription<DatabaseEvent> listenGifts(
    String roomId,
    void Function(String senderName, String giftName, int quantity) onGift,
  ) {
    return _roomRef(roomId)
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

  void endRoom(String roomId) {
    _roomRef(roomId).child('status').set('ended');
    Future<void>.delayed(const Duration(seconds: 10), () {
      _roomRef(roomId).remove();
    });
  }

  StreamSubscription<DatabaseEvent> listenEnded(
    String roomId,
    void Function() onEnded,
  ) {
    return _roomRef(roomId).child('status').onValue.listen((event) {
      if (event.snapshot.value == 'ended') {
        onEnded();
      }
    });
  }

  Future<void> initRoom(String roomId, {required String hostUserId}) async {
    final roomRef = _roomRef(roomId);
    final snapshot = await roomRef.get();

    if (!snapshot.exists) {
      await roomRef.set(<String, dynamic>{
        'status': 'live',
        'hostUserId': hostUserId,
        'audience_count': 0,
        'started_at': ServerValue.timestamp,
      });
    } else {
      await roomRef.child('status').set('live');
    }

    await roomRef.child('status').onDisconnect().set('ended');
  }
}
