import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class ZephyrApiClient {
  ZephyrApiClient({required this.baseUrl});

  final String baseUrl;

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

  Future<AuthSession> guestLogin(String displayName) async {
    final Map<String, dynamic> data = await _request(
      method: 'POST',
      path: '/v1/auth/guest-login',
      body: <String, dynamic>{'displayName': displayName},
    );

    return AuthSession(
      accessToken: data['accessToken'] as String,
      user: UserProfile.fromJson(data['user'] as Map<String, dynamic>),
    );
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
    if (callRateCoinsPerMinute != null) body['callRateCoinsPerMinute'] = callRateCoinsPerMinute;
    if (publicId != null && publicId.isNotEmpty) body['publicId'] = publicId;

    final Map<String, dynamic> data = await _request(
      method: 'PATCH',
      path: '/v1/users/me',
      accessToken: accessToken,
      body: body,
    );

    return UserProfile.fromJson(data);
  }

  Future<String> uploadAvatar(String accessToken, File imageFile) async {
    final Uri uri = Uri.parse('$baseUrl/v1/users/me/avatar');
    final http.MultipartRequest request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    final http.StreamedResponse streamed = await request.send();
    final String body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('Upload failed: ${streamed.statusCode} $body');
    }
    final Map<String, dynamic> json = jsonDecode(body) as Map<String, dynamic>;
    return json['avatarUrl'] as String;
  }

  Future<UserProfile> getUserByPublicId(String publicId) async {
    final dynamic data = await _request(
      method: 'GET',
      path: '/v1/users/by-public-id/$publicId',
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
    if (data is! List<dynamic>) throw Exception('Invalid conversations response');
    return data
        .map((dynamic e) => ZephyrConversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ZephyrMessage>> getThread(
      String accessToken, String userId) async {
    final dynamic data = await _request(
      method: 'GET',
      path: '/v1/messages/conversations/$userId',
      accessToken: accessToken,
    );
    if (data is! List<dynamic>) throw Exception('Invalid thread response');
    return data
        .map((dynamic e) => ZephyrMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ZephyrMessage> sendMessage(
      String accessToken, String receiverId, String body) async {
    final dynamic data = await _request(
      method: 'POST',
      path: '/v1/messages',
      accessToken: accessToken,
      body: <String, dynamic>{'receiverId': receiverId, 'body': body},
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
          .map((dynamic item) =>
              (item as Map<String, dynamic>)['userId'] as String)
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
  }) async {
    final Map<String, dynamic> data = await _request(
      method: 'POST',
      path: '/v1/economy/calls/$sessionId/tick',
      accessToken: accessToken,
      body: <String, dynamic>{'elapsedSeconds': elapsedSeconds},
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

  Future<RtcJoinInfo> getRoomRtcToken(String accessToken, String roomId) async {
    final Map<String, dynamic> data = await _request(
      method: 'POST',
      path: '/v1/rooms/$roomId/rtc-token',
      accessToken: accessToken,
    );
    return RtcJoinInfo.fromJson(data);
  }

  Future<RoomViewersResult> getRoomViewers(String accessToken, String roomId) async {
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
  }) async {
    final Uri uri = Uri.parse('$baseUrl$path');
    final HttpClient client = HttpClient();

    try {
      final HttpClientRequest request = switch (method) {
        'POST' => await client.postUrl(uri),
        'PATCH' => await client.patchUrl(uri),
        'DELETE' => await client.deleteUrl(uri),
        _ => await client.getUrl(uri),
      };

      request.headers.contentType = ContentType.json;
      if (accessToken != null) {
        request.headers.set('authorization', 'Bearer $accessToken');
      }

      if (body != null) {
        request.write(jsonEncode(body));
      }

      final HttpClientResponse response = await request.close();
      final String responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode > 299) {
        throw Exception('API ${response.statusCode}: $responseBody');
      }

      if (responseBody.isEmpty) {
        return <String, dynamic>{};
      }

      return jsonDecode(responseBody);
    } finally {
      client.close();
    }
  }
}

