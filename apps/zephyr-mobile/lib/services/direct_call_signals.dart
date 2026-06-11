import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import 'firebase_realtime_database.dart';

class DirectCallSignals {
  DirectCallSignals({FirebaseDatabase? database})
    : _rtdb = database ?? createZephyrRealtimeDatabase();

  final FirebaseDatabase _rtdb;

  DatabaseReference refForUser(String userId) =>
      _rtdb.ref('direct_calls/$userId');

  Future<void> writeRinging({
    required String targetUserId,
    required String callerId,
    required String callerName,
    String? callerAvatarUrl,
    required String sessionId,
  }) async {
    final ref = refForUser(targetUserId);
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

  Future<void> cancelOnDisconnect(String targetUserId) {
    return refForUser(targetUserId).onDisconnect().cancel();
  }

  Future<void> writeStatus(String userId, String status) {
    return refForUser(userId).child('status').set(status);
  }

  Future<void> remove(String userId) {
    return refForUser(userId).remove();
  }

  StreamSubscription<DatabaseEvent> listen(
    String userId,
    void Function(Map<String, dynamic>? data) onData, {
    void Function(Object error)? onError,
  }) {
    return refForUser(userId).onValue.listen((DatabaseEvent event) {
      final raw = event.snapshot.value;
      if (raw == null) {
        onData(null);
      } else {
        onData(Map<String, dynamic>.from(raw as Map));
      }
    }, onError: onError);
  }
}
