import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'firebase_realtime_database.dart';

class ProfilesRealtime {
  ProfilesRealtime({FirebaseDatabase? database})
    : _rtdb = database ?? createZephyrRealtimeDatabase();

  final FirebaseDatabase _rtdb;
  String? _myUserId;

  final Map<String, RtdbProfile> _profileCache = {};
  final Map<String, StreamSubscription<DatabaseEvent>> _profileSubs = {};
  final Map<String, DateTime> _profileLastAccess = {};
  static const int _maxProfileSubs = 50;

  final ValueNotifier<int> version = ValueNotifier<int>(0);

  void bindUser(String userId) {
    _myUserId = userId;
  }

  RtdbProfile? cached(String userId) => _profileCache[userId];

  void warm(List<String> userIds) {
    for (final String uid in userIds) {
      if (_profileSubs.containsKey(uid)) {
        _profileLastAccess[uid] = DateTime.now();
        continue;
      }

      while (_profileSubs.length >= _maxProfileSubs) {
        String? lruKey;
        DateTime? lruTime;
        for (final entry in _profileLastAccess.entries) {
          if (!_profileSubs.containsKey(entry.key)) continue;
          if (lruTime == null || entry.value.isBefore(lruTime)) {
            lruKey = entry.key;
            lruTime = entry.value;
          }
        }
        final evict = lruKey ?? _profileSubs.keys.first;
        _profileSubs.remove(evict)?.cancel();
        _profileLastAccess.remove(evict);
      }

      _profileLastAccess[uid] = DateTime.now();
      _profileSubs[uid] = _rtdb.ref('profiles/$uid').onValue.listen((event) {
        final data = event.snapshot.value;
        if (data is Map) {
          final profile = RtdbProfile(
            displayName: (data['displayName'] as String?) ?? 'User',
            avatarUrl: data['avatarUrl'] as String?,
            countryCode: (data['countryCode'] as String?) ?? '',
            language: (data['language'] as String?) ?? '',
            birthday: data['birthday'] as String?,
          );
          final old = _profileCache[uid];
          _profileCache[uid] = profile;
          if (old != profile) {
            version.value++;
          }
        }
      });
    }
  }

  Future<void> writeMine({
    required String displayName,
    String? avatarUrl,
    required String countryCode,
    required String language,
    String? birthday,
  }) async {
    final uid = _myUserId;
    if (uid == null) return;
    await _rtdb.ref('profiles/$uid').set({
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'countryCode': countryCode,
      'language': language,
      if (birthday != null) 'birthday': birthday,
    });
  }

  Future<void> clearSession() async {
    for (final sub in _profileSubs.values) {
      await sub.cancel();
    }
    _profileSubs.clear();
    _profileLastAccess.clear();
    _profileCache.clear();
    _myUserId = null;
  }
}

class RtdbProfile {
  const RtdbProfile({
    required this.displayName,
    this.avatarUrl,
    required this.countryCode,
    required this.language,
    this.birthday,
  });

  final String displayName;
  final String? avatarUrl;
  final String countryCode;
  final String language;
  final String? birthday;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RtdbProfile &&
          displayName == other.displayName &&
          avatarUrl == other.avatarUrl &&
          countryCode == other.countryCode &&
          language == other.language &&
          birthday == other.birthday;

  @override
  int get hashCode =>
      Object.hash(displayName, avatarUrl, countryCode, language, birthday);
}
