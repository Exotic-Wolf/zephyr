import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'firebase_realtime_database.dart';

class PresenceRealtime {
  PresenceRealtime({FirebaseDatabase? database})
    : _rtdb = database ?? createZephyrRealtimeDatabase();

  final FirebaseDatabase _rtdb;
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
  final Map<String, StreamSubscription<DatabaseEvent>> _presenceSubs = {};
  final Map<String, DateTime> _presenceLastAccess = {};
  StreamSubscription<DatabaseEvent>? _connectedSub;

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

      _presenceLastAccess[uid] = DateTime.now();
      _presenceSubs[uid] = _rtdb.ref('presence/$uid').onValue.listen((event) {
        final data = event.snapshot.value;
        final String state = data is Map
            ? ((data['displayStatus'] as String?) ??
                  (data['state'] as String?) ??
                  'offline')
            : 'offline';
        final String? roomId = data is Map ? data['roomId'] as String? : null;

        final bool changed =
            _presenceCache[uid] != state || _presenceRoomCache[uid] != roomId;

        _presenceCache[uid] = state;
        if ((state == 'live' || state == 'premium_live') && roomId != null) {
          _presenceRoomCache[uid] = roomId;
        } else {
          _presenceRoomCache.remove(uid);
        }

        if (changed) {
          version.value++;
        }
      });
    }
  }

  void _setupPresence(String userId) {
    final DatabaseReference presenceRef = _rtdb.ref('presence/$userId');
    final DatabaseReference connectedRef = _rtdb.ref('.info/connected');

    _connectedSub?.cancel();
    _connectedSub = connectedRef.onValue.listen((DatabaseEvent event) {
      final bool connected = event.snapshot.value as bool? ?? false;
      if (!connected) return;

      presenceRef.onDisconnect().set(_offlinePresencePayload());
      presenceRef.set(_currentPresencePayload());
    });
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

  Map<String, dynamic> _offlinePresenceFallback() {
    return <String, dynamic>{
      'schemaVersion': 1,
      'connection': 'offline',
      'activity': 'idle',
      'availability': 'unavailable',
      'routing': <String, bool>{'directCall': false, 'randomCall': false},
      'displayStatus': 'offline',
      'interruptible': false,
      'state': 'offline',
      'lastSeen': 0,
      'updatedAt': 0,
    };
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
    return _rtdb.ref('presence/$uid').set(_currentPresencePayload());
  }

  Stream<Map<String, dynamic>> watch(String userId) {
    return _rtdb.ref('presence/$userId').onValue.map((DatabaseEvent event) {
      final data = event.snapshot.value;
      if (data == null) return _offlinePresenceFallback();
      return Map<String, dynamic>.from(data as Map);
    });
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
    _rtdb.ref('presence/$uid').set(_awayPresencePayload());
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
    final ref = _rtdb.ref('presence/$uid');
    await ref.onDisconnect().cancel();
    await ref.set(_offlinePresencePayload());
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
    _presenceCache.clear();
    _presenceRoomCache.clear();

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
