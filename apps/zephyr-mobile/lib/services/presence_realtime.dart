import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'firebase_realtime_database.dart';
import 'rtdb_contracts.dart';

class PresenceRealtime {
  PresenceRealtime({
    FirebaseDatabase? database,
    PresenceRealtimeStore? store,
    Duration listenerRetryDelay = const Duration(seconds: 2),
  }) : _store =
           store ??
           FirebasePresenceRealtimeStore(
             database ?? createZephyrRealtimeDatabase(),
           ),
       _listenerRetryDelay = listenerRetryDelay;

  final PresenceRealtimeStore _store;
  final Duration _listenerRetryDelay;
  String? _myUserId;

  bool _isLive = false;
  bool _isLivePaused = false;
  String? _liveRoomId;
  bool _isPremiumLiveHost = false;
  bool _isPremiumLiveViewer = false;
  String? _premiumLiveRoomId;
  String? _premiumRoomSessionId;
  bool _isBusy = false;
  String? _busySessionId;
  String _busyActivity = 'direct_call';
  bool _isBackground = false;

  final Map<String, String> _presenceCache = {};
  final Map<String, String> _presenceRoomCache = {};
  final Map<String, DateTime> _demoNextRotationCache = {};
  final Map<String, StreamSubscription<Object?>> _presenceSubs = {};
  final Map<String, DateTime> _presenceLastAccess = {};
  final Map<String, Timer> _presenceRetryTimers = {};
  StreamSubscription<Object?>? _connectedSub;

  static const int _maxPresenceSubs = 50;

  final ValueNotifier<int> version = ValueNotifier<int>(0);

  Future<void> bindUser(String userId) async {
    _myUserId = userId;
    _setupPresence(userId);
    await writeCurrent();
  }

  bool? isOnlineCached(String userId) {
    final s = _presenceCache[userId];
    if (s == null) return null;
    return s == 'online' || s == 'live' || s == 'away';
  }

  String? stateCached(String userId) => _presenceCache[userId];

  String? roomIdCached(String userId) => _presenceRoomCache[userId];

  DateTime? demoNextRotationAtCached(String userId) {
    return _demoNextRotationCache[userId];
  }

  void warm(List<String> userIds) {
    for (final String uid in userIds) {
      if (_presenceSubs.containsKey(uid)) {
        _presenceLastAccess[uid] = DateTime.now();
        continue;
      }

      while (_presenceSubs.length >= _maxPresenceSubs) {
        String? lruKey;
        DateTime? lruTime;
        for (final entry in _presenceLastAccess.entries) {
          if (!_presenceSubs.containsKey(entry.key)) continue;
          if (lruTime == null || entry.value.isBefore(lruTime)) {
            lruKey = entry.key;
            lruTime = entry.value;
          }
        }
        final evict = lruKey ?? _presenceSubs.keys.first;
        _presenceSubs.remove(evict)?.cancel();
        _presenceLastAccess.remove(evict);
      }

      _presenceRetryTimers.remove(uid)?.cancel();
      _presenceLastAccess[uid] = DateTime.now();
      _presenceSubs[uid] = _store
          .watchValue('presence/$uid')
          .listen(
            (data) => _handlePresenceValue(uid, data),
            onError: (Object error) => _handlePresenceError(uid, error),
          );
    }
  }

  void _handlePresenceValue(String uid, Object? data) {
    final String state = RtdbPresenceContract.displayStatus(data);
    final String? roomId = RtdbPresenceContract.liveRoomId(data);
    final DateTime? demoNextRotationAt =
        RtdbPresenceContract.demoNextRotationAt(data);

    final bool changed =
        _presenceCache[uid] != state ||
        _presenceRoomCache[uid] != roomId ||
        _demoNextRotationCache[uid] != demoNextRotationAt;

    _presenceCache[uid] = state;
    if (roomId != null) {
      _presenceRoomCache[uid] = roomId;
    } else {
      _presenceRoomCache.remove(uid);
    }
    if (demoNextRotationAt != null) {
      _demoNextRotationCache[uid] = demoNextRotationAt;
    } else {
      _demoNextRotationCache.remove(uid);
    }

    if (changed) {
      version.value++;
    }
  }

  void _handlePresenceError(String uid, Object error) {
    assert(() {
      debugPrint('[PresenceRealtime] listener error user=$uid error=$error');
      return true;
    }());
    _presenceSubs.remove(uid)?.cancel();
    _presenceLastAccess.remove(uid);

    final bool removedPresence = _presenceCache.remove(uid) != null;
    final bool removedRoom = _presenceRoomCache.remove(uid) != null;
    final bool removedDemoRotation = _demoNextRotationCache.remove(uid) != null;
    final bool removedCachedState =
        removedPresence || removedRoom || removedDemoRotation;
    if (removedCachedState) {
      version.value++;
    }

    _presenceRetryTimers.remove(uid)?.cancel();
    _presenceRetryTimers[uid] = Timer(_listenerRetryDelay, () {
      _presenceRetryTimers.remove(uid);
      warm(<String>[uid]);
    });
  }

  void _setupPresence(String userId) {
    final String presencePath = 'presence/$userId';

    _connectedSub?.cancel();
    _connectedSub = _store.watchValue('.info/connected').listen((value) {
      final bool connected = value as bool? ?? false;
      if (!connected) return;

      unawaited(_writeConnectedPresence(presencePath));
    });
  }

  Future<void> _writeConnectedPresence(String presencePath) async {
    try {
      await _store.onDisconnectSet(presencePath, _offlinePresencePayload());
      await _store.set(presencePath, _currentPresencePayload());
    } catch (error) {
      assert(() {
        debugPrint(
          '[PresenceRealtime] connected presence write failed path=$presencePath error=$error',
        );
        return true;
      }());
    }
  }

  Map<String, dynamic> _presencePayload({
    required String connection,
    required String activity,
    required String availability,
    required bool directCall,
    required bool randomCall,
    required String displayStatus,
    required bool interruptible,
    required String legacyState,
    String? roomId,
    String? roomMode,
    String? callSessionId,
    String? premiumRoomSessionId,
    String? previousActivity,
    String? previousRoomId,
  }) {
    return <String, dynamic>{
      'schemaVersion': 1,
      'connection': connection,
      'activity': activity,
      'availability': availability,
      'routing': <String, bool>{
        'directCall': directCall,
        'randomCall': randomCall,
      },
      'displayStatus': displayStatus,
      'interruptible': interruptible,
      'state': legacyState,
      'lastSeen': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
      if (roomId != null) 'roomId': roomId,
      if (roomMode != null) 'roomMode': roomMode,
      if (callSessionId != null) 'callSessionId': callSessionId,
      if (premiumRoomSessionId != null)
        'premiumRoomSessionId': premiumRoomSessionId,
      if (previousActivity != null) 'previousActivity': previousActivity,
      if (previousRoomId != null) 'previousRoomId': previousRoomId,
    };
  }

  Map<String, dynamic> _offlinePresencePayload() {
    return _presencePayload(
      connection: 'offline',
      activity: 'idle',
      availability: 'unavailable',
      directCall: false,
      randomCall: false,
      displayStatus: 'offline',
      interruptible: false,
      legacyState: 'offline',
    );
  }

  Map<String, dynamic> _idlePresencePayload() {
    return _presencePayload(
      connection: 'online',
      activity: 'idle',
      availability: 'available',
      directCall: true,
      randomCall: true,
      displayStatus: 'online',
      interruptible: true,
      legacyState: 'online',
    );
  }

  Map<String, dynamic> _awayPresencePayload() {
    return _presencePayload(
      connection: 'online',
      activity: 'away',
      availability: 'available',
      directCall: true,
      randomCall: false,
      displayStatus: 'away',
      interruptible: true,
      legacyState: 'away',
    );
  }

  Map<String, dynamic> _freeLiveHostPresencePayload(String? roomId) {
    return _presencePayload(
      connection: 'online',
      activity: 'free_live_host',
      availability: 'available',
      directCall: true,
      randomCall: true,
      displayStatus: 'live',
      interruptible: true,
      legacyState: 'live',
      roomId: roomId,
      roomMode: 'free_live',
    );
  }

  Map<String, dynamic> _livePausedPresencePayload(String? roomId) {
    return _presencePayload(
      connection: 'online',
      activity: 'live_paused',
      availability: 'unavailable',
      directCall: false,
      randomCall: false,
      displayStatus: 'busy',
      interruptible: false,
      legacyState: 'busy',
      roomId: roomId,
      roomMode: 'free_live',
      previousActivity: 'free_live_host',
      previousRoomId: roomId,
    );
  }

  Map<String, dynamic> _premiumLiveHostPresencePayload(String? roomId) {
    return _presencePayload(
      connection: 'online',
      activity: 'premium_live_host',
      availability: 'busy',
      directCall: false,
      randomCall: false,
      displayStatus: 'premium_live',
      interruptible: false,
      legacyState: 'premium_live',
      roomId: roomId,
      roomMode: 'premium_live',
    );
  }

  Map<String, dynamic> _premiumLiveViewerPresencePayload({
    required String? roomId,
    required String? premiumRoomSessionId,
  }) {
    return _presencePayload(
      connection: 'online',
      activity: 'premium_live_viewer',
      availability: 'busy',
      directCall: false,
      randomCall: false,
      displayStatus: 'busy',
      interruptible: false,
      legacyState: 'busy',
      roomId: roomId,
      roomMode: 'premium_live',
      premiumRoomSessionId: premiumRoomSessionId,
    );
  }

  Map<String, dynamic> _callPresencePayload({
    required String activity,
    String? sessionId,
  }) {
    return _presencePayload(
      connection: 'online',
      activity: activity,
      availability: 'busy',
      directCall: false,
      randomCall: false,
      displayStatus: 'busy',
      interruptible: false,
      legacyState: 'busy',
      callSessionId: sessionId,
      previousActivity: (_isLive || _isLivePaused) ? 'free_live_host' : null,
      previousRoomId: (_isLive || _isLivePaused) ? _liveRoomId : null,
    );
  }

  Map<String, dynamic> _currentPresencePayload() {
    if (_isBackground) {
      return _offlinePresencePayload();
    }
    if (_isBusy) {
      return _callPresencePayload(
        activity: _busyActivity,
        sessionId: _busySessionId,
      );
    }
    if (_isPremiumLiveHost) {
      return _premiumLiveHostPresencePayload(_premiumLiveRoomId);
    }
    if (_isPremiumLiveViewer) {
      return _premiumLiveViewerPresencePayload(
        roomId: _premiumLiveRoomId,
        premiumRoomSessionId: _premiumRoomSessionId,
      );
    }
    if (_isLivePaused) {
      return _livePausedPresencePayload(_liveRoomId);
    }
    if (_isLive) {
      return _freeLiveHostPresencePayload(_liveRoomId);
    }
    return _idlePresencePayload();
  }

  Future<void> writeCurrent() {
    final uid = _myUserId;
    if (uid == null) return Future<void>.value();
    return _store.set('presence/$uid', _currentPresencePayload());
  }

  Stream<Map<String, dynamic>> watch(String userId) {
    return _store
        .watchValue('presence/$userId')
        .map(RtdbPresenceContract.normalize);
  }

  void setLive({String? roomId}) {
    if (_myUserId == null) return;
    _isLive = true;
    _isLivePaused = false;
    _liveRoomId = roomId;
    _isPremiumLiveHost = false;
    _isPremiumLiveViewer = false;
    _premiumLiveRoomId = null;
    _premiumRoomSessionId = null;
    writeCurrent();
  }

  void clearLive() {
    if (_myUserId == null) return;
    _isLive = false;
    _isLivePaused = false;
    _liveRoomId = null;
    writeCurrent();
  }

  void pauseLive() {
    if (_myUserId == null || !_isLive) return;
    _isLivePaused = true;
    writeCurrent();
  }

  void resumeLive() {
    if (_myUserId == null || !_isLive) return;
    _isLivePaused = false;
    writeCurrent();
  }

  void setPremiumLiveHost({required String roomId}) {
    if (_myUserId == null) return;
    _isLive = false;
    _isLivePaused = false;
    _liveRoomId = null;
    _isPremiumLiveHost = true;
    _isPremiumLiveViewer = false;
    _premiumLiveRoomId = roomId;
    _premiumRoomSessionId = null;
    writeCurrent();
  }

  void setPremiumLiveViewer({
    required String roomId,
    String? premiumRoomSessionId,
  }) {
    if (_myUserId == null) return;
    _isLive = false;
    _isLivePaused = false;
    _liveRoomId = null;
    _isPremiumLiveHost = false;
    _isPremiumLiveViewer = true;
    _premiumLiveRoomId = roomId;
    _premiumRoomSessionId = premiumRoomSessionId;
    writeCurrent();
  }

  void clearPremiumLive() {
    if (_myUserId == null) return;
    _isPremiumLiveHost = false;
    _isPremiumLiveViewer = false;
    _premiumLiveRoomId = null;
    _premiumRoomSessionId = null;
    writeCurrent();
  }

  void setAway() {
    if (_myUserId == null ||
        _isLive ||
        _isLivePaused ||
        _isPremiumLiveHost ||
        _isPremiumLiveViewer ||
        _isBusy ||
        _isBackground) {
      return;
    }
    final uid = _myUserId;
    if (uid == null) return;
    _store.set('presence/$uid', _awayPresencePayload());
  }

  void setBackgroundOffline() {
    if (_myUserId == null) return;
    _isBackground = true;
    writeCurrent();
  }

  void restoreOnline() {
    if (_myUserId == null) return;
    _isBackground = false;
    if (_isLive ||
        _isLivePaused ||
        _isPremiumLiveHost ||
        _isPremiumLiveViewer ||
        _isBusy) {
      return;
    }
    writeCurrent();
  }

  void setBusy({String? sessionId, String activity = 'direct_call'}) {
    if (_myUserId == null) return;
    _isBusy = true;
    _busySessionId = sessionId;
    _busyActivity = activity == 'random_call' ? 'random_call' : 'direct_call';
    if (_isLive) {
      _isLivePaused = true;
    }
    writeCurrent();
  }

  void clearBusy() {
    if (_myUserId == null) return;
    _isBusy = false;
    _busySessionId = null;
    _busyActivity = 'direct_call';
    writeCurrent();
  }

  Future<void> setOffline() async {
    final uid = _myUserId;
    if (uid == null) return;
    final String path = 'presence/$uid';
    await _store.onDisconnectCancel(path);
    await _store.set(path, _offlinePresencePayload());
    await _connectedSub?.cancel();
    _connectedSub = null;
  }

  Future<void> clearSession() async {
    await _connectedSub?.cancel();
    _connectedSub = null;

    for (final sub in _presenceSubs.values) {
      await sub.cancel();
    }
    _presenceSubs.clear();
    _presenceLastAccess.clear();
    for (final timer in _presenceRetryTimers.values) {
      timer.cancel();
    }
    _presenceRetryTimers.clear();
    _presenceCache.clear();
    _presenceRoomCache.clear();
    _demoNextRotationCache.clear();

    _isLive = false;
    _isLivePaused = false;
    _liveRoomId = null;
    _isPremiumLiveHost = false;
    _isPremiumLiveViewer = false;
    _premiumLiveRoomId = null;
    _premiumRoomSessionId = null;
    _isBusy = false;
    _busySessionId = null;
    _busyActivity = 'direct_call';
    _isBackground = false;
    _myUserId = null;
  }
}

abstract class PresenceRealtimeStore {
  Stream<Object?> watchValue(String path);
  Future<void> set(String path, Object? value);
  Future<void> onDisconnectSet(String path, Object? value);
  Future<void> onDisconnectCancel(String path);
}

class FirebasePresenceRealtimeStore implements PresenceRealtimeStore {
  FirebasePresenceRealtimeStore(this._rtdb);

  final FirebaseDatabase _rtdb;

  @override
  Stream<Object?> watchValue(String path) {
    return _rtdb.ref(path).onValue.map((DatabaseEvent event) {
      return event.snapshot.value;
    });
  }

  @override
  Future<void> set(String path, Object? value) {
    return _rtdb.ref(path).set(value);
  }

  @override
  Future<void> onDisconnectSet(String path, Object? value) {
    return _rtdb.ref(path).onDisconnect().set(value);
  }

  @override
  Future<void> onDisconnectCancel(String path) {
    return _rtdb.ref(path).onDisconnect().cancel();
  }
}
