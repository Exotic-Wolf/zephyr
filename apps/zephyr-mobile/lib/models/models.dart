// Models — auto-split from main.dart
// ignore_for_file: unnecessary_this

class AuthSession {
  AuthSession({required this.accessToken, required this.user});

  final String accessToken;
  final UserProfile user;
}

class WalletSummary {
  WalletSummary({
    required this.coinBalance,
    required this.level,
    required this.revenueUsd,
  });

  final int coinBalance;
  final int level;
  final double revenueUsd;

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    return WalletSummary(
      coinBalance: (json['coinBalance'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      revenueUsd: (json['revenueUsd'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CoinPack {
  CoinPack({
    required this.id,
    required this.label,
    required this.coins,
    required this.priceUsd,
  });

  final String id;
  final String label;
  final int coins;
  final double priceUsd;

  factory CoinPack.fromJson(Map<String, dynamic> json) {
    return CoinPack(
      id: json['id'] as String,
      label: json['label'] as String,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      priceUsd: (json['priceUsd'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CallQuote {
  CallQuote({
    required this.minutes,
    required this.mode,
    required this.requiredCoins,
    required this.rateCoinsPerMinute,
    required this.directCallAllowedRatesCoinsPerMinute,
  });

  final int minutes;
  final String mode;
  final int requiredCoins;
  final int rateCoinsPerMinute;
  final List<int> directCallAllowedRatesCoinsPerMinute;

  factory CallQuote.fromJson(Map<String, dynamic> json) {
    final dynamic rawRates = json['directCallAllowedRatesCoinsPerMinute'];

    return CallQuote(
      minutes: (json['minutes'] as num?)?.toInt() ?? 1,
      mode: (json['mode'] as String?) ?? 'direct',
      requiredCoins: (json['requiredCoins'] as num?)?.toInt() ?? 0,
      rateCoinsPerMinute: (json['rateCoinsPerMinute'] as num?)?.toInt() ?? 0,
      directCallAllowedRatesCoinsPerMinute: rawRates is List<dynamic>
          ? rawRates
                .whereType<num>()
                .map((num value) => value.toInt())
                .toList()
          : <int>[2100, 4200, 8400],
    );
  }
}

class CallSession {
  CallSession({
    required this.id,
    required this.callerUserId,
    required this.receiverUserId,
    required this.mode,
    required this.rateCoinsPerMinute,
    required this.totalBilledCoins,
    required this.status,
    required this.endReason,
  });

  final String id;
  final String callerUserId;
  final String? receiverUserId;
  final String mode;
  final int rateCoinsPerMinute;
  final int totalBilledCoins;
  final String status;
  final String? endReason;

  factory CallSession.fromJson(Map<String, dynamic> json) {
    return CallSession(
      id: json['id'] as String,
      callerUserId: json['callerUserId'] as String,
      receiverUserId: json['receiverUserId'] as String?,
      mode: json['mode'] as String,
      rateCoinsPerMinute: (json['rateCoinsPerMinute'] as num?)?.toInt() ?? 0,
      totalBilledCoins: (json['totalBilledCoins'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?) ?? 'live',
      endReason: json['endReason'] as String?,
    );
  }
}

class CallSessionTickResult {
  CallSessionTickResult({
    required this.session,
    required this.chargedCoins,
    required this.callerCoinBalanceAfter,
    required this.stoppedForInsufficientBalance,
  });

  final CallSession session;
  final int chargedCoins;
  final int callerCoinBalanceAfter;
  final bool stoppedForInsufficientBalance;

  factory CallSessionTickResult.fromJson(Map<String, dynamic> json) {
    return CallSessionTickResult(
      session: CallSession.fromJson(json['session'] as Map<String, dynamic>),
      chargedCoins: (json['chargedCoins'] as num?)?.toInt() ?? 0,
      callerCoinBalanceAfter:
          (json['callerCoinBalanceAfter'] as num?)?.toInt() ?? 0,
      stoppedForInsufficientBalance:
          (json['stoppedForInsufficientBalance'] as bool?) ?? false,
    );
  }
}

class RtcJoinInfo {
  RtcJoinInfo({
    required this.provider,
    required this.wsUrl,
    required this.roomName,
    required this.identity,
    required this.role,
    required this.token,
    required this.expiresInSeconds,
  });

  final String provider;
  final String wsUrl;
  final String roomName;
  final String identity;
  final String role;
  final String token;
  final int expiresInSeconds;

  factory RtcJoinInfo.fromJson(Map<String, dynamic> json) {
    return RtcJoinInfo(
      provider: (json['provider'] as String?) ?? 'livekit',
      wsUrl: (json['wsUrl'] as String?) ?? '',
      roomName: (json['roomName'] as String?) ?? '',
      identity: (json['identity'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'caller',
      token: (json['token'] as String?) ?? '',
      expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Derives a stable 8-digit numeric public ID from a UUID using a djb2 hash.
String derivePublicId(String uuid) {
  int h = 5381;
  for (final int c in uuid.codeUnits) {
    h = ((h << 5) + h + c) & 0x7FFFFFFF;
  }
  return h.abs().toString().padLeft(8, '0').substring(0, 8);
}

// ── Message models ────────────────────────────────────────────────────────────

class ZephyrMessage {
  ZephyrMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  factory ZephyrMessage.fromJson(Map<String, dynamic> json) {
    return ZephyrMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt'] as String) : null,
    );
  }
}

class ZephyrConversation {
  ZephyrConversation({
    required this.userId,
    required this.displayName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;

  factory ZephyrConversation.fromJson(Map<String, dynamic> json) {
    return ZephyrConversation(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      lastMessage: json['lastMessage'] as String,
      lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class UserProfile {
  UserProfile({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
    required this.createdAt,
    String? publicId,
    this.isAdmin = false,
    this.gender,
    this.birthday,
    this.countryCode,
    this.language,
    this.callRateCoinsPerMinute,
  }) : publicId = publicId ?? derivePublicId(id);

  final String id;
  /// Short 8-digit public ID shown to users. Safe to share; does not expose the DB UUID.
  final String publicId;
  final bool isAdmin;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String? gender;
  final String? birthday;   // ISO date string e.g. "1995-06-15"
  final String? countryCode;
  final String? language;
  final int? callRateCoinsPerMinute;
  final DateTime createdAt;

  /// Derives a stable 8-digit numeric code from the DB UUID using a djb2 hash.
  /// The output looks nothing like the source UUID.
  /// Delegates to the top-level _derivePublicId function.
  static String derivePublicId(String uuid) => derivePublicId(uuid);

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      publicId: json['publicId'] as String?,
      isAdmin: (json['isAdmin'] as bool?) ?? false,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      gender: json['gender'] as String?,
      birthday: json['birthday'] as String?,
      countryCode: json['countryCode'] as String?,
      language: json['language'] as String?,
      callRateCoinsPerMinute: (json['callRateCoinsPerMinute'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class Room {
  Room({
    required this.id,
    required this.hostUserId,
    required this.title,
    required this.audienceCount,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String hostUserId;
  final String title;
  final int audienceCount;
  final String status;
  final DateTime createdAt;

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      hostUserId: json['hostUserId'] as String,
      title: json['title'] as String,
      audienceCount: json['audienceCount'] as int,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class LiveFeedCard {
  LiveFeedCard({
    required this.roomId,
    required this.title,
    required this.audienceCount,
    required this.hostUserId,
    required this.hostDisplayName,
    required this.hostAvatarUrl,
    required this.hostCountryCode,
    required this.hostLanguage,
    required this.hostStatus,
    required this.startedAt,
  });

  final String roomId;
  final String title;
  final int audienceCount;
  final String hostUserId;
  final String hostDisplayName;
  final String? hostAvatarUrl;
  final String hostCountryCode;
  final String hostLanguage;
  /// 'live' | 'online' | 'busy'
  final String hostStatus;
  final DateTime startedAt;

  factory LiveFeedCard.fromJson(Map<String, dynamic> json) {
    return LiveFeedCard(
      roomId: json['roomId'] as String,
      title: json['title'] as String,
      audienceCount: json['audienceCount'] as int,
      hostUserId: json['hostUserId'] as String,
      hostDisplayName: json['hostDisplayName'] as String,
      hostAvatarUrl: json['hostAvatarUrl'] as String?,
      hostCountryCode: (json['hostCountryCode'] as String? ?? 'PH')
          .trim()
          .toUpperCase(),
      hostLanguage: (json['hostLanguage'] as String? ?? 'English').trim(),
      hostStatus: (json['hostStatus'] as String? ?? 'live').trim().toLowerCase(),
      startedAt: DateTime.parse(json['startedAt'] as String),
    );
  }
}
