const Set<String> rtdbPresenceDisplayStatuses = <String>{
  'online',
  'away',
  'live',
  'premium_live',
  'busy',
  'offline',
};

const Set<String> rtdbCallSignalStatuses = <String>{
  'ringing',
  'accepted',
  'declined',
  'matched',
};

Map<String, dynamic>? _asMap(Object? value) {
  if (value is! Map) return null;
  return <String, dynamic>{
    for (final MapEntry<dynamic, dynamic> entry in value.entries)
      if (entry.key != null) entry.key.toString(): entry.value,
  };
}

String? _string(Object? value) {
  if (value is! String) return null;
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool _isNumber(Object? value) => value is num;

int? _int(Object? value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

class RtdbPresenceContract {
  const RtdbPresenceContract._();

  static Map<String, dynamic> offlineFallback() {
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

  static Map<String, dynamic> normalize(Object? value) {
    final Map<String, dynamic>? map = _asMap(value);
    if (map == null) return offlineFallback();

    final String? displayStatus =
        _string(map['displayStatus']) ?? _string(map['state']);
    final String? state = _string(map['state']);
    final Map<String, dynamic>? routing = _asMap(map['routing']);

    if (map['schemaVersion'] != 1 ||
        displayStatus == null ||
        !rtdbPresenceDisplayStatuses.contains(displayStatus) ||
        (state != null && state != displayStatus) ||
        _string(map['connection']) == null ||
        _string(map['activity']) == null ||
        _string(map['availability']) == null ||
        routing == null ||
        routing['directCall'] is! bool ||
        routing['randomCall'] is! bool ||
        map['interruptible'] is! bool ||
        !_isNumber(map['lastSeen']) ||
        !_isNumber(map['updatedAt'])) {
      return offlineFallback();
    }

    return <String, dynamic>{
      ...map,
      'routing': routing,
      'displayStatus': displayStatus,
      'state': displayStatus,
    };
  }

  static String displayStatus(Object? value) {
    return normalize(value)['displayStatus'] as String;
  }

  static String? liveRoomId(Object? value) {
    final Map<String, dynamic> map = normalize(value);
    final String status = map['displayStatus'] as String;
    final String? roomId = _string(map['roomId']);
    if (roomId == null) return null;
    return (status == 'live' || status == 'premium_live') ? roomId : null;
  }

  static DateTime? demoNextRotationAt(Object? value) {
    final Map<String, dynamic>? map = _asMap(value);
    final Map<String, dynamic>? demo = _asMap(map?['demo']);
    if (demo?['simulator'] != 'for_you') return null;
    final int? milliseconds = _int(demo?['nextRotationAt']);
    if (milliseconds == null || milliseconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
}

class RtdbProfileContract {
  const RtdbProfileContract._();

  static RtdbProfileData? parse(Object? value) {
    final Map<String, dynamic>? map = _asMap(value);
    if (map == null) return null;

    final String? displayName = _string(map['displayName']);
    final String? countryCode = _string(map['countryCode']);
    final String? language = _string(map['language']);
    if (displayName == null || countryCode == null || language == null) {
      return null;
    }

    return RtdbProfileData(
      displayName: displayName,
      avatarUrl: _string(map['avatarUrl']),
      countryCode: countryCode,
      language: language,
      birthday: _string(map['birthday']),
    );
  }
}

class RtdbProfileData {
  const RtdbProfileData({
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
}

class RtdbDirectCallSignalContract {
  const RtdbDirectCallSignalContract._();

  static Map<String, dynamic>? ringingPayload({
    required String callerId,
    required String callerName,
    String? callerAvatarUrl,
    required String sessionId,
    required Object timestamp,
  }) {
    final String? safeCallerId = _string(callerId);
    final String? safeCallerName = _string(callerName);
    final String? safeSessionId = _string(sessionId);
    if (safeCallerId == null ||
        safeCallerName == null ||
        safeSessionId == null) {
      return null;
    }

    return <String, dynamic>{
      'callerId': safeCallerId,
      'callerName': safeCallerName,
      'callerAvatarUrl': _string(callerAvatarUrl),
      'sessionId': safeSessionId,
      'status': 'ringing',
      'ts': timestamp,
    };
  }

  static Map<String, dynamic>? parse(Object? value) {
    final Map<String, dynamic>? map = _asMap(value);
    if (map == null) return null;

    final String? event = _string(map['event']);
    if (event == 'partner_left') {
      return _string(map['sessionId']) != null &&
              _string(map['partnerId']) != null &&
              _isNumber(map['ts'])
          ? map
          : null;
    }

    final String? status = _string(map['status']);
    final String? sessionId = _string(map['sessionId']);
    final String? callerId = _string(map['callerId']);
    if (status == null ||
        !rtdbCallSignalStatuses.contains(status) ||
        sessionId == null ||
        callerId == null ||
        !_isNumber(map['ts'])) {
      return null;
    }

    if (event == 'matched') {
      final bool hasRandomInvite =
          status == 'matched' &&
          _string(map['appId']) != null &&
          _string(map['channelName']) != null &&
          _string(map['token']) != null &&
          _string(map['partnerId']) != null &&
          _int(map['uid']) != null;
      return hasRandomInvite ? map : null;
    }

    return map;
  }
}

class RtdbLiveRoomContract {
  const RtdbLiveRoomContract._();

  static int audienceCount(Object? value) {
    final Map<String, dynamic>? map = _asMap(value);
    return map?.length ?? 0;
  }

  static RtdbLiveComment? comment(Object? value) {
    final Map<String, dynamic>? map = _asMap(value);
    if (map == null ||
        _string(map['userId']) == null ||
        _string(map['name']) == null ||
        _string(map['text']) == null ||
        !_isNumber(map['ts'])) {
      return null;
    }
    return RtdbLiveComment(
      name: _string(map['name'])!,
      text: _string(map['text'])!,
    );
  }

  static String? reactionEmoji(Object? value, String myUserId) {
    final Map<String, dynamic>? map = _asMap(value);
    if (map == null ||
        _string(map['userId']) == null ||
        _string(map['userId']) == myUserId ||
        _string(map['emoji']) == null ||
        !_isNumber(map['ts'])) {
      return null;
    }
    return _string(map['emoji']);
  }

  static RtdbLiveGift? gift(Object? value) {
    final Map<String, dynamic>? map = _asMap(value);
    if (map == null ||
        map['trusted'] != true ||
        _string(map['senderName']) == null ||
        _string(map['giftName']) == null ||
        !_isNumber(map['quantity']) ||
        !_isNumber(map['ts'])) {
      return null;
    }
    return RtdbLiveGift(
      senderName: _string(map['senderName'])!,
      giftName: _string(map['giftName'])!,
      quantity: (map['quantity'] as num).toInt(),
    );
  }

  static bool isEnded(Object? value) => value == 'ended';
}

class RtdbLiveComment {
  const RtdbLiveComment({required this.name, required this.text});

  final String name;
  final String text;
}

class RtdbLiveGift {
  const RtdbLiveGift({
    required this.senderName,
    required this.giftName,
    required this.quantity,
  });

  final String senderName;
  final String giftName;
  final int quantity;
}
