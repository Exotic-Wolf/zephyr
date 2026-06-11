import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import 'firebase_realtime_database.dart';
import 'rtdb_contracts.dart';

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
    final Map<String, dynamic>? payload =
        RtdbDirectCallSignalContract.ringingPayload(
          callerId: callerId,
          callerName: callerName,
          callerAvatarUrl: callerAvatarUrl,
          sessionId: sessionId,
          timestamp: ServerValue.timestamp,
        );
    if (payload == null) {
      throw ArgumentError('Invalid direct-call ringing signal');
    }

    await ref.onDisconnect().remove();
    await ref.set(payload);
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
      onData(RtdbDirectCallSignalContract.parse(event.snapshot.value));
    }, onError: onError);
  }
}
