import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_mobile/services/presence_realtime.dart';

void main() {
  group('PresenceRealtime', () {
    test(
      'presence listener errors invalidate stale state and allow rewarm',
      () async {
        final store = _FakePresenceRealtimeStore();
        final presence = PresenceRealtime(
          store: store,
          listenerRetryDelay: Duration.zero,
        );
        addTearDown(presence.clearSession);

        presence.warm(<String>['akshay']);
        store.emit(
          'presence/akshay',
          _presencePayload('live', roomId: 'room-akshay'),
        );
        await pumpEventQueue();

        expect(presence.stateCached('akshay'), 'live');
        expect(presence.roomIdCached('akshay'), 'room-akshay');
        expect(store.watchCount('presence/akshay'), 1);

        store.emitError(
          'presence/akshay',
          Exception(
            '[firebase_database/permission-denied] Client does not have permission.',
          ),
        );
        await pumpEventQueue();

        expect(presence.stateCached('akshay'), isNull);
        expect(presence.roomIdCached('akshay'), isNull);

        await pumpEventQueue();
        expect(store.watchCount('presence/akshay'), 2);

        store.emit('presence/akshay', _presencePayload('online'));
        await pumpEventQueue();

        expect(presence.stateCached('akshay'), 'online');
      },
    );
  });
}

Map<String, dynamic> _presencePayload(String status, {String? roomId}) {
  final bool online = status != 'offline';
  return <String, dynamic>{
    'schemaVersion': 1,
    'connection': online ? 'online' : 'offline',
    'activity': 'idle',
    'availability': online ? 'available' : 'unavailable',
    'routing': <String, bool>{'directCall': online, 'randomCall': online},
    'displayStatus': status,
    'interruptible': online,
    'state': status,
    'lastSeen': 1760000000000,
    'updatedAt': 1760000000000,
    if (roomId != null) 'roomId': roomId,
  };
}

class _FakePresenceRealtimeStore implements PresenceRealtimeStore {
  final Map<String, StreamController<Object?>> _controllers =
      <String, StreamController<Object?>>{};
  final Map<String, int> _watchCounts = <String, int>{};
  final Map<String, Object?> writes = <String, Object?>{};
  final Map<String, Object?> disconnectWrites = <String, Object?>{};

  @override
  Stream<Object?> watchValue(String path) {
    _watchCounts[path] = (_watchCounts[path] ?? 0) + 1;
    return _controller(path).stream;
  }

  int watchCount(String path) => _watchCounts[path] ?? 0;

  void emit(String path, Object? value) {
    _controller(path).add(value);
  }

  void emitError(String path, Object error) {
    _controller(path).addError(error);
  }

  StreamController<Object?> _controller(String path) {
    return _controllers.putIfAbsent(
      path,
      () => StreamController<Object?>.broadcast(),
    );
  }

  @override
  Future<void> set(String path, Object? value) async {
    writes[path] = value;
  }

  @override
  Future<void> onDisconnectSet(String path, Object? value) async {
    disconnectWrites[path] = value;
  }

  @override
  Future<void> onDisconnectCancel(String path) async {
    disconnectWrites.remove(path);
  }
}
