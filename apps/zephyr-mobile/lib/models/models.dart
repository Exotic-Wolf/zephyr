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

class IapVerifyResult {
  IapVerifyResult({
    required this.wallet,
    required this.coinsAwarded,
    required this.transactionId,
  });

  final WalletSummary wallet;
  final int coinsAwarded;
  final String transactionId;

  factory IapVerifyResult.fromJson(Map<String, dynamic> json) {
    return IapVerifyResult(
      wallet: WalletSummary.fromJson(json['wallet'] as Map<String, dynamic>),
      coinsAwarded: (json['coinsAwarded'] as num?)?.toInt() ?? 0,
      transactionId: json['transactionId'] as String? ?? '',
    );
  }
}

class CallRateTier {
  CallRateTier({
    required this.label,
    required this.minLevel,
    required this.coinsPerMinute,
    required this.sparkPerMinute,
  });

  final String label;
  final int minLevel;
  final int coinsPerMinute;
  final int sparkPerMinute;

  factory CallRateTier.fromJson(Map<String, dynamic> json) {
    return CallRateTier(
      label: json['label'] as String,
      minLevel: (json['minLevel'] as num).toInt(),
      coinsPerMinute: (json['coinsPerMinute'] as num).toInt(),
      sparkPerMinute: (json['sparkPerMinute'] as num).toInt(),
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
          ? rawRates.whereType<num>().map((num value) => value.toInt()).toList()
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

class WalletTransaction {
  WalletTransaction({
    required this.id,
    required this.type,
    required this.coinsDelta,
    this.amountUsd,
    required this.createdAt,
  });

  final String id;
  final String type;
  final int coinsDelta;
  final double? amountUsd;
  final String createdAt;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String,
      type: json['type'] as String,
      coinsDelta: (json['coinsDelta'] as num?)?.toInt() ?? 0,
      amountUsd: (json['amountUsd'] as num?)?.toDouble(),
      createdAt: json['createdAt'] as String,
    );
  }
}

class RtcJoinInfo {
  RtcJoinInfo({
    required this.provider,
    required this.appId,
    required this.channelName,
    required this.uid,
    required this.role,
    required this.token,
    required this.expiresInSeconds,
  });

  final String provider;
  final String appId;
  final String channelName;
  final int uid;
  final String role;
  final String token;
  final int expiresInSeconds;

  factory RtcJoinInfo.fromJson(Map<String, dynamic> json) {
    return RtcJoinInfo(
      provider: (json['provider'] as String?) ?? 'agora',
      appId: (json['appId'] as String?) ?? '',
      channelName: (json['channelName'] as String?) ?? '',
      uid: (json['uid'] as num?)?.toInt() ?? 0,
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
    this.deliveredAt,
    this.readAt,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String body;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  factory ZephyrMessage.fromJson(Map<String, dynamic> json) {
    return ZephyrMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.parse(json['deliveredAt'] as String)
          : null,
      readAt: json['readAt'] != null
          ? DateTime.parse(json['readAt'] as String)
          : null,
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
    this.lastSeenAt,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final DateTime? lastSeenAt;

  factory ZephyrConversation.fromJson(Map<String, dynamic> json) {
    return ZephyrConversation(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      lastMessage: json['lastMessage'] as String,
      lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      lastSeenAt: json['lastSeenAt'] != null
          ? DateTime.parse(json['lastSeenAt'] as String)
          : null,
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
    this.isHost = false,
    this.coverUrl,
    this.gender,
    this.birthday,
    this.countryCode,
    this.language,
    this.callRateCoinsPerMinute,
    this.onboardedAt,
  }) : publicId = publicId ?? derivePublicId(id);

  final String id;

  /// Short 8-digit public ID shown to users. Safe to share; does not expose the DB UUID.
  final String publicId;
  final bool isAdmin;
  final bool isHost;
  final String displayName;
  final String? avatarUrl;
  final String? coverUrl;
  final String? bio;
  final String? gender;
  final String? birthday; // ISO date string e.g. "1995-06-15"
  final String? countryCode;
  final String? language;
  final int? callRateCoinsPerMinute;
  final DateTime? onboardedAt;
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
      isHost: (json['isHost'] as bool?) ?? false,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      coverUrl: json['coverUrl'] as String?,
      bio: json['bio'] as String?,
      gender: json['gender'] as String?,
      birthday: json['birthday'] as String?,
      countryCode: json['countryCode'] as String?,
      language: json['language'] as String?,
      callRateCoinsPerMinute: (json['callRateCoinsPerMinute'] as num?)?.toInt(),
      onboardedAt: json['onboardedAt'] != null
          ? DateTime.parse(json['onboardedAt'] as String)
          : null,
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
    this.callRateCoinsPerMinute,
  });

  final String? roomId;
  final String title;
  final int audienceCount;
  final String hostUserId;
  final String hostDisplayName;
  final String? hostAvatarUrl;
  final String hostCountryCode;
  final String hostLanguage;

  /// Display status from canonical presence: online, away, live, premium_live, busy, offline.
  final String hostStatus;
  final DateTime startedAt;
  final int? callRateCoinsPerMinute;

  factory LiveFeedCard.fromJson(Map<String, dynamic> json) {
    return LiveFeedCard(
      roomId: json['roomId'] as String?,
      title: json['title'] as String,
      audienceCount: json['audienceCount'] as int,
      hostUserId: json['hostUserId'] as String,
      hostDisplayName: json['hostDisplayName'] as String,
      hostAvatarUrl: json['hostAvatarUrl'] as String?,
      hostCountryCode: (json['hostCountryCode'] as String? ?? 'PH')
          .trim()
          .toUpperCase(),
      hostLanguage: (json['hostLanguage'] as String? ?? 'English').trim(),
      hostStatus: (json['hostStatus'] as String? ?? 'offline')
          .trim()
          .toLowerCase(),
      startedAt: DateTime.parse(json['startedAt'] as String),
      callRateCoinsPerMinute: (json['hostCallRateCoinsPerMinute'] as num?)
          ?.toInt(),
    );
  }

  LiveFeedCard copyWith({
    String? hostStatus,
    String? roomId,
    int? audienceCount,
  }) {
    return LiveFeedCard(
      roomId: roomId ?? this.roomId,
      title: title,
      audienceCount: audienceCount ?? this.audienceCount,
      hostUserId: hostUserId,
      hostDisplayName: hostDisplayName,
      hostAvatarUrl: hostAvatarUrl,
      hostCountryCode: hostCountryCode,
      hostLanguage: hostLanguage,
      hostStatus: hostStatus ?? this.hostStatus,
      startedAt: startedAt,
      callRateCoinsPerMinute: callRateCoinsPerMinute,
    );
  }
}

class RoomViewer {
  RoomViewer({required this.displayName, this.avatarUrl});

  final String displayName;
  final String? avatarUrl;

  factory RoomViewer.fromJson(Map<String, dynamic> json) {
    return RoomViewer(
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class RoomViewersResult {
  RoomViewersResult({required this.viewers, required this.total});

  final List<RoomViewer> viewers;
  final int total;

  factory RoomViewersResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> list = json['viewers'] as List<dynamic>? ?? [];
    return RoomViewersResult(
      viewers: list
          .map((dynamic e) => RoomViewer.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}
