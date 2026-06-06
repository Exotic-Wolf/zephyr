import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/models.dart';

class ZephyrApiException implements Exception {
  const ZephyrApiException({
    required this.statusCode,
    required this.message,
    required this.responseBody,
  });

  final int statusCode;
  final String message;
  final String responseBody;

  @override
  String toString() => message;
}

class ZephyrApiClient {
  ZephyrApiClient({required this.baseUrl});

  static ZephyrApiClient? instance;
  static String? accessToken;

  final String baseUrl;
  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30)
    ..idleTimeout = const Duration(seconds: 30);

  Future<bool> ping() async {
    try {
      final dynamic data = await _request(
        method: 'GET',
        path: '/v1/health/live',
      );
      return data is Map<String, dynamic> && data['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  Future<AuthSession> googleLogin(String idToken) async {
    final Map<String, dynamic> data = await _request(
      method: 'POST',
      path: '/v1/auth/google-login',
      body: <String, dynamic>{'idToken': idToken},
    );

    return AuthSession(
      accessToken: data['accessToken'] as String,
      user: UserProfile.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  Future<AuthSession> appleLogin({
    required String idToken,
    String? givenName,
    String? familyName,
    String? email,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{'idToken': idToken};
    if (givenName != null) {
      body['givenName'] = givenName;
    }
    if (familyName != null) {
      body['familyName'] = familyName;
    }
    if (email != null) {
      body['email'] = email;
    }

    final Map<String, dynamic> data = await _request(
      method: 'POST',
      path: '/v1/auth/apple-login',
      body: body,
    );

    return AuthSession(
      accessToken: data['accessToken'] as String,
      user: UserProfile.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  Future<UserProfile> getMe(String accessToken) async {
    final Map<String, dynamic> data = await _request(
      method: 'GET',
      path: '/v1/users/me',
      accessToken: accessToken,
    );

    return UserProfile.fromJson(data);
  }

  Future<void> deleteMyAccount(String accessToken) async {
    await _request(
      method: 'DELETE',
      path: '/v1/users/me',
      accessToken: accessToken,
    ).timeout(const Duration(seconds: 15));
  }

  Future<UserProfile> updateMe(
    String accessToken, {
    String? displayName,
    String? gender,
    String? birthday,
    String? countryCode,
    String? language,
    int? callRateCoinsPerMinute,
    String? publicId,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};
    if (displayName != null) body['displayName'] = displayName;
    if (gender != null) body['gender'] = gender;
    if (birthday != null) body['birthday'] = birthday;
    if (countryCode != null) body['countryCode'] = countryCode;
    if (language != null) body['language'] = language;
    if (callRateCoinsPerMinute != null) {
      body['callRateCoinsPerMinute'] = callRateCoinsPerMinute;
    }
    if (publicId != null && publicId.isNotEmpty) body['publicId'] = publicId;

    final Map<String, dynamic> data = await _request(
      method: 'PATCH',
      path: '/v1/users/me',
      accessToken: accessToken,
      body: body,
    );

    return UserProfile.fromJson(data);
  }

  Future<String> uploadAvatar(
    String accessToken,
    File imageFile, {
    String? mimeType,
  }) async {
    final Uri uri = Uri.parse('$baseUrl/v1/users/me/avatar');
    final http.MultipartRequest request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          contentType: mimeType != null
              ? MediaType.parse(mimeType)
              : MediaType('image', 'jpeg'),
        ),
      );
    final http.StreamedResponse streamed = await request.send();
    final String body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('Upload failed: ${streamed.statusCode} $body');
    }
    final Map<String, dynamic> json = jsonDecode(body) as Map<String, dynamic>;
    return json['avatarUrl'] as String;
  }

  Future<String> uploadCover(
    String accessToken,
    File imageFile, {
    String? mimeType,
  }) async {
    final Uri uri = Uri.parse('$baseUrl/v1/users/me/cover');
    final http.MultipartRequest request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          contentType: mimeType != null
              ? MediaType.parse(mimeType)
              : MediaType('image', 'jpeg'),
        ),
      );
    final http.StreamedResponse streamed = await request.send();
    final String body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('Upload failed: ${streamed.statusCode} $body');
    }
    final Map<String, dynamic> json = jsonDecode(body) as Map<String, dynamic>;
    return json['coverUrl'] as String;
  }

  Future<UserProfile> getUserByPublicId(String publicId) async {
    final dynamic data = await _request(
      method: 'GET',
      path: '/v1/users/by-public-id/$publicId',
    );
    return UserProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<UserProfile> getUserById(String userId) async {
    final dynamic data = await _request(
      method: 'GET',
      path: '/v1/users/$userId',
    );
    return UserProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<List<UserProfile>> searchUsers(String q) async {
    final dynamic data = await _request(
      method: 'GET',
      path: '/v1/users/search?q=${Uri.encodeQueryComponent(q)}',
    );
    if (data is! List<dynamic>) return <UserProfile>[];
    return data
        .map((dynamic e) => UserProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ZephyrConversation>> getConversations(String accessToken) async {
    final dynamic data = await _request(
      method: 'GET',
      path: '/v1/messages/conversations',
      accessToken: accessToken,
    );
    if (data is! List<dynamic>) {
      throw Exception('Invalid conversations response');
    }
    return data
        .map(
          (dynamic e) => ZephyrConversation.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  Future<({List<ZephyrMessage> messages, bool hasMore})> getThread(
    String accessToken,
    String userId, {
    DateTime? before,
    DateTime? after,
  }) async {
    final StringBuffer query = StringBuffer();
    if (before != null) {
      query.write(
        '?before=${Uri.encodeComponent(before.toUtc().toIso8601String())}',
      );
    } else if (after != null) {
      query.write(
        '?after=${Uri.encodeComponent(after.toUtc().toIso8601String())}',
      );
    }
    final String path = '/v1/messages/conversations/$userId${query.toString()}';
    final dynamic data = await _request(
      method: 'GET',
      path: path,
      accessToken: accessToken,
    );
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid thread response');
    }
    final List<dynamic> msgs = data['messages'] as List<dynamic>;
    final bool hasMore = data['hasMore'] as bool;
    return (
      messages: msgs
          .map((dynamic e) => ZephyrMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: hasMore,
    );
  }

  Future<void> registerDeviceToken(String accessToken, String token) async {
    await _request(
      method: 'POST',
      path: '/v1/messages/device-token',
      accessToken: accessToken,
      body: <String, dynamic>{'token': token},
    );
  }

  Future<String> getFirebaseToken(String accessToken) async {
    final Map<String, dynamic> res =
        await _request(
              method: 'POST',
              path: '/v1/auth/firebase-token',
              accessToken: accessToken,
            )
            as Map<String, dynamic>;
    return res['firebaseToken'] as String;
  }

  Future<void> unregisterDeviceToken(String accessToken, String token) async {
    await _request(
      method: 'DELETE',
      path: '/v1/messages/device-token',
      accessToken: accessToken,
      body: <String, dynamic>{'token': token},
    );
  }

  Future<void> sendPushNotification(
    String accessToken,
    String recipientId,
    String chatId,
    String messageId,
  ) async {
    await _request(
      method: 'POST',
      path: '/v1/messages/push',
      accessToken: accessToken,
      body: <String, dynamic>{
        'recipientId': recipientId,
        'chatId': chatId,
        'messageId': messageId,
      },
    );
  }

  Future<ZephyrMessage> sendMessage(
    String accessToken,
    String receiverId,
    String body, {
    String? idempotencyKey,
  }) async {
    final dynamic data = await _request(
      method: 'POST',
      path: '/v1/messages',
      accessToken: accessToken,
      body: <String, dynamic>{'receiverId': receiverId, 'body': body},
      extraHeaders: idempotencyKey != null
          ? <String, String>{'X-Idempotency-Key': idempotencyKey}
          : null,
    );
    return ZephyrMessage.fromJson(data as Map<String, dynamic>);
  }

  Future<void> markMessageRead(String accessToken, String messageId) async {
    await _request(
      method: 'PATCH',
      path: '/v1/messages/$messageId/read',
      accessToken: accessToken,
    );
  }

  Future<void> markMessageDelivered(
    String accessToken,
    String messageId,
  ) async {
    await _request(
      method: 'PATCH',
      path: '/v1/messages/$messageId/delivered',
      accessToken: accessToken,
    );
  }

  Future<List<Room>> listRooms() async {
    final dynamic data = await _request(method: 'GET', path: '/v1/rooms');

    if (data is! List<dynamic>) {
      throw Exception('Invalid rooms response');
    }

    return data
        .map((dynamic item) => Room.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<LiveFeedCard>> listLiveFeed(
    String accessToken, {
    int limit = 20,
  }) async {
    final dynamic data = await _request(
      method: 'GET',
      path: '/v1/feed/live?limit=$limit',
      accessToken: accessToken,
    );

    if (data is! List<dynamic>) {
      throw Exception('Invalid live feed response');
    }

    return data
        .map(
          (dynamic item) => LiveFeedCard.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  /// Returns the set of user IDs that the current user follows.
  /// Falls back to an empty set if the endpoint is not yet available.
  Future<Set<String>> getFollowingIds(String accessToken) async {
    try {
      final dynamic data = await _request(
        method: 'GET',
        path: '/v1/users/me/following',
        accessToken: accessToken,
      );

      if (data is! List<dynamic>) {
        return <String>{};
      }

      return data
          .map(
            (dynamic item) =>
                (item as Map<String, dynamic>)['userId'] as String,
          )
          .toSet();
    } catch (_) {
      // Endpoint not yet deployed — return empty set gracefully.
      return <String>{};
    }
  }

  Future<Room> createRoom(String accessToken, String title) async {
    final Map<String, dynamic> data = await _request(
      method: 'POST',
      path: '/v1/rooms',
      accessToken: accessToken,
      body: <String, dynamic>{'title': title},
    );

    return Room.fromJson(data);
  }

  Future<Room> joinRoom(String accessToken, String roomId) async {
    final Map<String, dynamic> data = await _request(
      method: 'POST',
      path: '/v1/rooms/$roomId/join',
      accessToken: accessToken,
    );

    return Room.fromJson(data);
  }

  Future<void> leaveRoom(String accessToken, String roomId) async {
    await _request(
      method: 'POST',
      path: '/v1/rooms/$roomId/leave',
      accessToken: accessToken,
    );
  }

  Future<void> endRoom(String accessToken, String roomId) async {
    await _request(
      method: 'DELETE',
      path: '/v1/rooms/$roomId',
      accessToken: accessToken,
    );
  }

  Future<void> heartbeatRoom(String accessToken, String roomId) async {
    await _request(
      method: 'POST',
      path: '/v1/rooms/$roomId/heartbeat',
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> sendGiftInRoom(
    String accessToken,
    String roomId,
    String giftId, {
    int quantity = 1,
    String? idempotencyKey,
  }) async {
    final Map<String, dynamic> data = await _request(
      method: 'POST',
      path: '/v1/rooms/$roomId/gift',
      accessToken: accessToken,
      body: <String, dynamic>{'giftId': giftId, 'quantity': quantity},
      extraHeaders: idempotencyKey != null
          ? <String, String>{'X-Idempotency-Key': idempotencyKey}
          : null,
    );
    return data;
  }

  Future<void> blockUser(String accessToken, String userId) async {
    await _request(
      method: 'POST',
      path: '/v1/users/$userId/block',
      accessToken: accessToken,
    );
  }

  Future<void> unblockUser(String accessToken, String userId) async {
    await _request(
      method: 'DELETE',
      path: '/v1/users/$userId/block',
      accessToken: accessToken,
    );
  }

  Future<void> reportUser(
    String accessToken,
    String userId, {
    String? reason,
  }) async {
    await _request(
      method: 'POST',
      path: '/v1/users/$userId/report',
      accessToken: accessToken,
      body: <String, dynamic>{
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  Future<bool> isUserBlocked(String accessToken, String userId) async {
    final Map<String, dynamic> data = await _request(
      method: 'GET',
      path: '/v1/users/$userId/block',
      accessToken: accessToken,
    );
    return (data['blocked'] as bool?) ?? false;
  }

  Future<WalletSummary> getWalletSummary(String accessToken) async {
    final Map<String, dynamic> data = await _request(
      method: 'GET',
      path: '/v1/economy/wallet',
      accessToken: accessToken,
    );

    return WalletSummary.fromJson(data);
  }

  Future<List<CoinPack>> listCoinPacks() async {
    final dynamic data = await _request(
      method: 'GET',
      path: '/v1/economy/coin-packs',
    );

    if (data is! List<dynamic>) {
      throw Exception('Invalid coin packs response');
    }

    return data
        .map((dynamic item) => CoinPack.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<WalletSummary> purchaseCoins(String accessToken, String packId) async {
    final Map<String, dynamic> data = await _request(
      method: 'POST',
      path: '/v1/economy/purchase-coins',
      accessToken: accessToken,
      body: <String, dynamic>{'packId': packId},
    );

    return WalletSummary.fromJson(data);
  }

  Future<IapVerifyResult> verifyPurchase(
    String accessToken, {
    required String store,
    required String productId,
    required String transactionId,
    String? receiptData,
  }) async {
    final Map<String, dynamic> data = await _request(
      method: 'POST',
      path: '/v1/economy/verify-purchase',
      accessToken: accessToken,
      body: <String, dynamic>{
        'store': store,
        'productId': productId,
        'transactionId': transactionId,
        if (receiptData != null) 'receiptData': receiptData,
      },
    );

    return IapVerifyResult.fromJson(data);
  }

  Future<List<CallRateTier>> getCallRateTiers() async {
    final dynamic data = await _request(
      method: 'GET',
      path: '/v1/economy/call-rate-tiers',
    );
    if (data is! List<dynamic>) return <CallRateTier>[];
    return data
        .map((dynamic e) => CallRateTier.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CallQuote> getPrivateCallQuote({
    required int minutes,
    required String mode,
    int? directRateCoinsPerMinute,
  }) async {
    final Map<String, String> queryParams = <String, String>{
      'minutes': '$minutes',
      'mode': mode,
    };

    if (directRateCoinsPerMinute != null) {
      queryParams['rateCoinsPerMinute'] = '$directRateCoinsPerMinute';
    }

    final String query = Uri(queryParameters: queryParams).query;

    final Map<String, dynamic> data = await _request(
      method: 'GET',
      path: '/v1/economy/private-call/quote?$query',
    );

    return CallQuote.fromJson(data);
  }

  Future<CallSession> startCallSession({
    required String accessToken,
    required String mode,
    String? receiverUserId,
    int? directRateCoinsPerMinute,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{'mode': mode};
    if (receiverUserId != null) {
      body['receiverUserId'] = receiverUserId;
    }
    if (directRateCoinsPerMinute != null) {
      body['directRateCoinsPerMinute'] = directRateCoinsPerMinute;
    }

    final Map<String, dynamic> data = await _request(
      method: 'POST',
      path: '/v1/economy/calls/start',
      accessToken: accessToken,
      body: body,
    );

    return CallSession.fromJson(data);
  }

  Future<CallSessionTickResult> tickCallSession({
    required String accessToken,
    required String sessionId,
    int elapsedSeconds = 10,
    String? idempotencyKey,
  }) async {
    final Map<String, dynamic> data = await _request(
      method: 'POST',
      path: '/v1/economy/calls/$sessionId/tick',
      accessToken: accessToken,
      body: <String, dynamic>{'elapsedSeconds': elapsedSeconds},
      extraHeaders: idempotencyKey != null
          ? <String, String>{'X-Idempotency-Key': idempotencyKey}
          : null,
    );

    return CallSessionTickResult.fromJson(data);
  }

  Future<CallSession> endCallSession({
    required String accessToken,
    required String sessionId,
    String reason = 'caller_ended',
  }) async {
    final Map<String, dynamic> data = await _request(
      method: 'POST',
      path: '/v1/economy/calls/$sessionId/end',
      accessToken: accessToken,
      body: <String, dynamic>{'reason': reason},
    );

    return CallSession.fromJson(data);
  }

  Future<void> reportCall({
    required String accessToken,
    required String sessionId,
    required String reportedUserId,
    String? reason,
  }) async {
    await _request(
      method: 'POST',
      path: '/v1/economy/calls/$sessionId/report',
      accessToken: accessToken,
      body: <String, dynamic>{
        'reportedUserId': reportedUserId,
        if (reason != null) 'reason': reason,
      },
    );
  }

  // ── Random call matchmaking (REST) ──────────────────────────────────────────

  /// Seek a random call match. Returns match data or { matched: false }.
  Future<Map<String, dynamic>> seekRandomCall(String accessToken) async {
    final dynamic data = await _request(
      method: 'POST',
      path: '/v1/calls/random/seek',
      accessToken: accessToken,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Cancel seeking a random call.
  Future<void> cancelSeekRandomCall(String accessToken) async {
    await _request(
      method: 'DELETE',
      path: '/v1/calls/random/seek',
      accessToken: accessToken,
    );
  }

  /// End current random call and seek next match.
  Future<Map<String, dynamic>> nextRandomCall(
    String accessToken, {
    required String sessionId,
    required String partnerId,
  }) async {
    final dynamic data = await _request(
      method: 'POST',
      path: '/v1/calls/random/next',
      accessToken: accessToken,
      body: <String, dynamic>{'sessionId': sessionId, 'partnerId': partnerId},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// End current random call without seeking again.
  Future<void> endRandomCall(
    String accessToken, {
    required String sessionId,
    required String partnerId,
  }) async {
    await _request(
      method: 'POST',
      path: '/v1/calls/random/end',
      accessToken: accessToken,
      body: <String, dynamic>{'sessionId': sessionId, 'partnerId': partnerId},
    );
  }

  Future<List<WalletTransaction>> getTransactionHistory(
    String accessToken, {
    int limit = 50,
  }) async {
    final dynamic data = await _request(
      method: 'GET',
      path: '/v1/economy/transactions?limit=$limit',
      accessToken: accessToken,
    );
    if (data is! List<dynamic>) return <WalletTransaction>[];
    return data
        .map(
          (dynamic item) =>
              WalletTransaction.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<RtcJoinInfo> getRoomRtcToken(String accessToken, String roomId) async {
    final Map<String, dynamic> data = await _request(
      method: 'POST',
      path: '/v1/rooms/$roomId/rtc-token',
      accessToken: accessToken,
    );
    return RtcJoinInfo.fromJson(data);
  }

  Future<RoomViewersResult> getRoomViewers(
    String accessToken,
    String roomId,
  ) async {
    final Map<String, dynamic> data = await _request(
      method: 'GET',
      path: '/v1/rooms/$roomId/viewers',
      accessToken: accessToken,
    );
    return RoomViewersResult.fromJson(data);
  }

  Future<RtcJoinInfo> requestCallRtcToken({
    required String accessToken,
    required String sessionId,
  }) async {
    final Map<String, dynamic> data = await _request(
      method: 'POST',
      path: '/v1/economy/calls/$sessionId/rtc-token',
      accessToken: accessToken,
    );

    return RtcJoinInfo.fromJson(data);
  }

  Future<dynamic> _request({
    required String method,
    required String path,
    String? accessToken,
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
  }) async {
    final Uri uri = Uri.parse('$baseUrl$path');

    final HttpClientRequest request = switch (method) {
      'POST' => await _httpClient.postUrl(uri),
      'PATCH' => await _httpClient.patchUrl(uri),
      'DELETE' => await _httpClient.deleteUrl(uri),
      _ => await _httpClient.getUrl(uri),
    };

    request.headers.contentType = ContentType.json;
    if (accessToken != null) {
      request.headers.set('authorization', 'Bearer $accessToken');
    }
    extraHeaders?.forEach(request.headers.set);

    if (body != null) {
      request.write(jsonEncode(body));
    }

    final HttpClientResponse response = await request.close();
    final String responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode < 200 || response.statusCode > 299) {
      throw ZephyrApiException(
        statusCode: response.statusCode,
        message: _resolveErrorMessage(response.statusCode, responseBody),
        responseBody: responseBody,
      );
    }

    if (responseBody.isEmpty) {
      return <String, dynamic>{};
    }

    return jsonDecode(responseBody);
  }

  String _resolveErrorMessage(int statusCode, String responseBody) {
    if (responseBody.trim().isEmpty) {
      return 'Request failed with status $statusCode';
    }

    try {
      final dynamic decoded = jsonDecode(responseBody);
      final String? message = _messageFromDecodedError(decoded);
      if (message != null && message.trim().isNotEmpty) {
        return message.trim();
      }
    } catch (_) {
      // Fall through to the raw body fallback below.
    }

    return responseBody.trim();
  }

  String? _messageFromDecodedError(dynamic decoded) {
    if (decoded is String) return decoded;
    if (decoded is List<dynamic>) {
      return decoded.whereType<String>().join(', ');
    }
    if (decoded is! Map<String, dynamic>) return null;

    final dynamic error = decoded['error'];
    if (error is Map<String, dynamic>) {
      final String? nestedMessage = _messageFromDecodedError(error['message']);
      if (nestedMessage != null && nestedMessage.isNotEmpty) {
        return nestedMessage;
      }
      final String? detailMessage = _messageFromDecodedError(error['details']);
      if (detailMessage != null && detailMessage.isNotEmpty) {
        return detailMessage;
      }
    }

    final String? message = _messageFromDecodedError(decoded['message']);
    if (message != null && message.isNotEmpty) {
      return message;
    }

    if (error is String) {
      return error;
    }

    return null;
  }
}
