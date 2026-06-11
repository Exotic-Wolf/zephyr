import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'firebase_realtime_database.dart';
import 'rtdb_contracts.dart';

class DirectCallSignals {
  DirectCallSignals({FirebaseDatabase? database})
    : _rtdb = database ?? createZephyrRealtimeDatabase();

  final FirebaseDatabase _rtdb;

  DatabaseReference refForUser(String userId) =>
      _rtdb.ref('direct_calls/$userId');

  void _debugLog(String message) {
    assert(() {
      debugPrint('[DirectCallSignals] $message');
      return true;
    }());
  }

  Future<void> writeRinging({
    required String targetUserId,
    required String callerId,
    required String callerName,
    String? callerAvatarUrl,
    required String sessionId,
  }) async {
    final ref = refForUser(targetUserId);
    _debugLog(
      'writeRinging start target=$targetUserId caller=$callerId session=$sessionId',
    );
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

    await ref.set(payload);
    _debugLog('writeRinging set-ok target=$targetUserId session=$sessionId');
    try {
      await ref.onDisconnect().remove();
      _debugLog(
        'writeRinging onDisconnect-ok target=$targetUserId session=$sessionId',
      );
    } catch (_) {
      _debugLog(
        'writeRinging onDisconnect-failed target=$targetUserId session=$sessionId',
      );
      await ref.remove().catchError((_) {});
      rethrow;
    }
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
    _debugLog('listen attach user=$userId');
    return refForUser(userId).onValue.listen((DatabaseEvent event) {
      final Map<String, dynamic>? data = RtdbDirectCallSignalContract.parse(
        event.snapshot.value,
      );
      _debugLog(
        'listen event user=$userId status=${data?['status']} caller=${data?['callerId']} session=${data?['sessionId']}',
      );
      onData(data);
    }, onError: onError);
  }
}
