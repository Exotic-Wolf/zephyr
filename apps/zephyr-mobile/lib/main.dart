import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://zephyr-api-wr1s.onrender.com',
);

const String googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue: '',
);

const double tabletBreakpoint = 700;
const double maxContentWidth = 820;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ZephyrApiClient _apiClient = ZephyrApiClient(baseUrl: apiBaseUrl);
  String? _accessToken;

  void _onLoginSuccess(String accessToken) {
    setState(() {
      _accessToken = accessToken;
    });
  }

  void _onLogout() {
    setState(() {
      _accessToken = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zephyr',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
      ),
      home: _accessToken == null
          ? OnboardingScreen(
              apiClient: _apiClient,
              onLoginSuccess: _onLoginSuccess,
            )
          : HomeScreen(
              apiClient: _apiClient,
              accessToken: _accessToken!,
              onLogout: _onLogout,
            ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.apiClient,
    required this.onLoginSuccess,
    super.key,
  });

  final ZephyrApiClient apiClient;
  final ValueChanged<String> onLoginSuccess;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _nameController = TextEditingController();
  late final GoogleSignIn _googleSignIn;
  bool _loading = false;
  bool _googleLoading = false;
  bool _appleLoading = false;
  bool _checkingApiStatus = true;
  bool? _apiReachable;
  String? _error;

  @override
  void initState() {
    super.initState();
    _googleSignIn = GoogleSignIn(
      scopes: <String>['email'],
      serverClientId: googleServerClientId.isEmpty
          ? null
          : googleServerClientId,
    );
    _refreshApiStatus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _refreshApiStatus() async {
    setState(() {
      _checkingApiStatus = true;
    });

    final bool isReachable = await widget.apiClient.ping();
    if (!mounted) {
      return;
    }

    setState(() {
      _apiReachable = isReachable;
      _checkingApiStatus = false;
    });
  }

  Future<void> _continue() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = 'Please enter your display name.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final AuthSession session = await widget.apiClient.guestLogin(name);
      if (!mounted) {
        return;
      }
      widget.onLoginSuccess(session.accessToken);
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _continueWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });

    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _error = 'Google sign-in canceled.';
        });
        return;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception(
          'Google ID token not available. Set GOOGLE_SERVER_CLIENT_ID '
          '(Web OAuth client ID) via --dart-define and retry.',
        );
      }

      final AuthSession session = await widget.apiClient.googleLogin(idToken);
      if (!mounted) {
        return;
      }
      widget.onLoginSuccess(session.accessToken);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _googleLoading = false;
        });
      }
    }
  }

  Future<void> _continueWithApple() async {
    setState(() {
      _appleLoading = true;
      _error = null;
    });

    try {
      final AuthorizationCredentialAppleID credential =
          await SignInWithApple.getAppleIDCredential(
            scopes: <AppleIDAuthorizationScopes>[
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
          );

      final String? idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception(
          'Apple ID token not available from Sign in with Apple.',
        );
      }

      final AuthSession session = await widget.apiClient.appleLogin(
        idToken: idToken,
        email: credential.email,
        givenName: credential.givenName,
        familyName: credential.familyName,
      );

      if (!mounted) {
        return;
      }
      widget.onLoginSuccess(session.accessToken);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _appleLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.sizeOf(context).width >= tabletBreakpoint;

    return Scaffold(
      appBar: AppBar(title: const Text('Zephyr Onboarding')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isTablet ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Go live in seconds',
                  style: TextStyle(
                    fontSize: isTablet ? 24 : 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(child: Text('API: ${widget.apiClient.baseUrl}')),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _checkingApiStatus
                            ? Colors.orange.shade50
                            : (_apiReachable == true
                                  ? Colors.green.shade50
                                  : Colors.red.shade50),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _checkingApiStatus
                            ? 'Checking API...'
                            : (_apiReachable == true
                                  ? 'API Connected'
                                  : 'API Offline'),
                        style: TextStyle(
                          color: _checkingApiStatus
                              ? Colors.orange.shade700
                              : (_apiReachable == true
                                    ? Colors.green.shade700
                                    : Colors.red.shade700),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh API status',
                      onPressed: _checkingApiStatus ? null : _refreshApiStatus,
                      icon: const Icon(Icons.refresh, size: 20),
                    ),
                  ],
                ),
                SizedBox(height: isTablet ? 20 : 16),
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    hintText: 'Enter your name',
                  ),
                  onSubmitted: (_) => _continue(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: isTablet ? 320 : double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _continue,
                    child: Text(
                      _loading ? 'Connecting...' : 'Continue as Guest',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: isTablet ? 320 : double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _googleLoading ? null : _continueWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4285F4),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Text(
                      'G',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    label: Text(
                      _googleLoading ? 'Signing in...' : 'Continue with Google',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: isTablet ? 320 : double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _appleLoading ? null : _continueWithApple,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.apple),
                    label: Text(
                      _appleLoading ? 'Signing in...' : 'Continue with Apple',
                    ),
                  ),
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.apiClient,
    required this.accessToken,
    required this.onLogout,
    super.key,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final VoidCallback onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _roomTitleController = TextEditingController();
  final PageController _feedController = PageController(viewportFraction: 0.92);
  UserProfile? _me;
  List<LiveFeedCard> _feedCards = <LiveFeedCard>[];
  int _activeFeedIndex = 0;
  bool _checkingApiStatus = true;
  bool? _apiReachable;
  bool _loading = true;
  bool _creating = false;
  String? _joiningRoomId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshApiStatus();
  }

  @override
  void dispose() {
    _roomTitleController.dispose();
    _feedController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final UserProfile me = await widget.apiClient.getMe(widget.accessToken);
      final List<LiveFeedCard> feedCards = await widget.apiClient.listLiveFeed(
        widget.accessToken,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _me = me;
        _feedCards = feedCards;
        _activeFeedIndex = feedCards.isEmpty
            ? 0
            : _activeFeedIndex.clamp(0, feedCards.length - 1);
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _refreshApiStatus() async {
    setState(() {
      _checkingApiStatus = true;
    });

    final bool isReachable = await widget.apiClient.ping();
    if (!mounted) {
      return;
    }

    setState(() {
      _apiReachable = isReachable;
      _checkingApiStatus = false;
    });
  }

  Future<void> _refreshHome() async {
    await Future.wait(<Future<void>>[_loadData(), _refreshApiStatus()]);
  }

  Future<void> _createRoom() async {
    final String title = _roomTitleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _error = 'Please add a room title.';
      });
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      await widget.apiClient.createRoom(widget.accessToken, title);
      _roomTitleController.clear();
      await _loadData();
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  Future<void> _enterRoom(LiveFeedCard feedCard) async {
    setState(() {
      _joiningRoomId = feedCard.roomId;
    });

    try {
      await widget.apiClient.joinRoom(widget.accessToken, feedCard.roomId);
      await _loadData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Joined ${feedCard.title}')));
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _joiningRoomId = null;
        });
      }
    }
  }

  Widget _buildFeedCard(LiveFeedCard feedCard) {
    final bool joiningCurrentRoom = _joiningRoomId == feedCard.roomId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              feedCard.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text('Host: ${feedCard.hostDisplayName}'),
            const SizedBox(height: 8),
            Text('Audience: ${feedCard.audienceCount}'),
            const SizedBox(height: 8),
            Text(
              'Started: ${feedCard.startedAt.toLocal().toIso8601String().substring(0, 16).replaceFirst('T', ' ')}',
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: joiningCurrentRoom
                    ? null
                    : () => _enterRoom(feedCard),
                child: Text(joiningCurrentRoom ? 'Entering...' : 'Enter Room'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.sizeOf(context).width >= tabletBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: Text('Zephyr ${_me?.displayName ?? ''}'),
        actions: <Widget>[
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _checkingApiStatus
                    ? Colors.orange.shade50
                    : (_apiReachable == true
                          ? Colors.green.shade50
                          : Colors.red.shade50),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _checkingApiStatus
                    ? 'API...'
                    : (_apiReachable == true ? 'API ✓' : 'API ✕'),
                style: TextStyle(
                  color: _checkingApiStatus
                      ? Colors.orange.shade700
                      : (_apiReachable == true
                            ? Colors.green.shade700
                            : Colors.red.shade700),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refreshHome,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxContentWidth),
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 24 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Live Now',
                        style: TextStyle(
                          fontSize: isTablet ? 24 : 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _roomTitleController,
                              decoration: const InputDecoration(
                                labelText: 'Room Title',
                                hintText: 'Night Talk, Music Chill, etc.',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _creating ? null : _createRoom,
                            child: Text(_creating ? 'Creating...' : 'Create'),
                          ),
                        ],
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_feedCards.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            isTablet
                                ? 'Live Rooms: ${_feedCards.length}'
                                : 'Swipe ${_activeFeedIndex + 1}/${_feedCards.length}',
                          ),
                        ),
                      Expanded(
                        child: _feedCards.isEmpty
                            ? const Center(
                                child: Text(
                                  'No live rooms yet. Create one to start.',
                                ),
                              )
                            : (isTablet
                                  ? GridView.builder(
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 2,
                                            crossAxisSpacing: 12,
                                            mainAxisSpacing: 12,
                                            childAspectRatio: 1.18,
                                          ),
                                      itemCount: _feedCards.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                            return _buildFeedCard(
                                              _feedCards[index],
                                            );
                                          },
                                    )
                                  : PageView.builder(
                                      controller: _feedController,
                                      itemCount: _feedCards.length,
                                      onPageChanged: (int index) {
                                        setState(() {
                                          _activeFeedIndex = index;
                                        });
                                      },
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                            return _buildFeedCard(
                                              _feedCards[index],
                                            );
                                          },
                                    )),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

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

class AuthSession {
  AuthSession({required this.accessToken, required this.user});

  final String accessToken;
  final UserProfile user;
}

class UserProfile {
  UserProfile({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
    required this.createdAt,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final DateTime createdAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
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
    required this.startedAt,
  });

  final String roomId;
  final String title;
  final int audienceCount;
  final String hostUserId;
  final String hostDisplayName;
  final String? hostAvatarUrl;
  final DateTime startedAt;

  factory LiveFeedCard.fromJson(Map<String, dynamic> json) {
    return LiveFeedCard(
      roomId: json['roomId'] as String,
      title: json['title'] as String,
      audienceCount: json['audienceCount'] as int,
      hostUserId: json['hostUserId'] as String,
      hostDisplayName: json['hostDisplayName'] as String,
      hostAvatarUrl: json['hostAvatarUrl'] as String?,
      startedAt: DateTime.parse(json['startedAt'] as String),
    );
  }
}
