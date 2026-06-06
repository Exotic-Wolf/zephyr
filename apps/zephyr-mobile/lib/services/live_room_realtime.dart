import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import 'firebase_realtime_database.dart';

class LiveRoomRealtime {
  LiveRoomRealtime({FirebaseDatabase? database})
    : _rtdb = database ?? createZephyrRealtimeDatabase();

  final FirebaseDatabase _rtdb;

  DatabaseReference _roomRef(String roomId) => _rtdb.ref('live_rooms/$roomId');

  Future<void> joinAudience(String roomId, String userId) async {
    final countRef = _roomRef(roomId).child('audience_count');
    await countRef.onDisconnect().set(ServerValue.increment(-1));
    await countRef.set(ServerValue.increment(1));
  }

  Future<void> leaveAudience(String roomId, String userId) async {
    final countRef = _roomRef(roomId).child('audience_count');
    await countRef.onDisconnect().cancel();
    await countRef.set(ServerValue.increment(-1));
  }

  StreamSubscription<DatabaseEvent> listenAudienceCount(
    String roomId,
    void Function(int count) onCount,
  ) {
    return _roomRef(roomId).child('audience_count').onValue.listen((event) {
      final int count = (event.snapshot.value as num?)?.toInt() ?? 0;
      onCount(count < 0 ? 0 : count);
    });
  }

  void writeComment(String roomId, String displayName, String text) {
    _roomRef(roomId).child('comments').push().set(<String, dynamic>{
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

  void writeGift(
    String roomId,
    String senderName,
    String giftId,
    String giftName,
    int quantity,
  ) {
    _roomRef(roomId).child('gifts').push().set(<String, dynamic>{
      'senderName': senderName,
      'giftId': giftId,
      'giftName': giftName,
      'quantity': quantity,
      'ts': ServerValue.timestamp,
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

  void initRoom(String roomId, {required String hostUserId}) {
    _roomRef(roomId).set(<String, dynamic>{
      'status': 'live',
      'hostUserId': hostUserId,
      'audience_count': 0,
      'started_at': ServerValue.timestamp,
    });
    _roomRef(roomId).child('status').onDisconnect().set('ended');
  }
}
