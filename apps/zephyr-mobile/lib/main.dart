import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show pi, sin;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'flags.dart';

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
    const String guestName = 'wolf';

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final AuthSession session = await widget.apiClient.guestLogin(guestName);
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
                if (Platform.isIOS) ...<Widget>[
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
                        _appleLoading
                            ? 'Signing in...'
                            : 'Continue with Apple',
                      ),
                    ),
                  ),
                ],
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
  final PageController _feedController = PageController();
  UserProfile? _me;
  List<LiveFeedCard> _feedCards = <LiveFeedCard>[];
  Set<String> _followingIds = <String>{};
  Room? _myLiveRoom;
  String? _selectedDirectReceiverUserId;
  int _selectedTabIndex = 0;
  int _homeTopTabIndex = 1;
  int _coinBalance = 1200;
  int _userLevel = 4;
  double _myRevenue = 86.40;
  List<CoinPack> _coinPacks = <CoinPack>[
    CoinPack(id: 'pack_299',  label: '16.5K',  coins: 16500,  priceUsd: 2.99),
    CoinPack(id: 'pack_999',  label: '55K',    coins: 55000,  priceUsd: 9.99),
    CoinPack(id: 'pack_2999', label: '165K',   coins: 165000, priceUsd: 29.99),
    CoinPack(id: 'pack_9999', label: '550K',   coins: 550000, priceUsd: 99.99),
  ];
  int _callMinutes = 2;
  String _callMode = 'direct';
  int _selectedDirectRate = 2100;
  CallQuote? _callQuote;
  CallSession? _activeCallSession;
  RtcJoinInfo? _rtcJoinInfo;
  Timer? _callTickTimer;
  bool _callActionLoading = false;
  bool _tickInFlight = false;
  bool _rtcLoading = false;
  String? _callActionError;
  String? _rtcError;
  static const int _callTickIntervalSeconds = 10;
  bool _quoteLoading = false;
  String? _quoteError;
  int _activeFeedIndex = 0;
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
    _callTickTimer?.cancel();
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
      final List<dynamic> data = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.apiClient.getMe(widget.accessToken),
        widget.apiClient.listLiveFeed(widget.accessToken),
        widget.apiClient.getWalletSummary(widget.accessToken),
        widget.apiClient.listCoinPacks(),
        widget.apiClient.getFollowingIds(widget.accessToken),
      ]);

      final UserProfile me = data[0] as UserProfile;
      final List<LiveFeedCard> feedCards = data[1] as List<LiveFeedCard>;
      final WalletSummary wallet = data[2] as WalletSummary;
      final Set<String> followingIds = data[4] as Set<String>;
      final List<CoinPack> packs = data[3] as List<CoinPack>;

      if (!mounted) {
        return;
      }
      setState(() {
        _me = me;
        _followingIds = followingIds;
        _feedCards = <LiveFeedCard>[
          ...feedCards,
          // ── mock cards to preview Busy / Online / Offline states ──
          LiveFeedCard(
            roomId: 'mock-busy-1',
            title: 'Busy mock',
            audienceCount: 0,
            hostUserId: 'mock-busy-user',
            hostDisplayName: 'SarahBusy',
            hostAvatarUrl: null,
            hostCountryCode: 'US',
            hostLanguage: 'English',
            hostStatus: 'busy',
            startedAt: DateTime.now(),
          ),
          LiveFeedCard(
            roomId: 'mock-online-1',
            title: 'Online mock',
            audienceCount: 0,
            hostUserId: 'mock-online-user',
            hostDisplayName: 'TaniaOnline',
            hostAvatarUrl: null,
            hostCountryCode: 'PH',
            hostLanguage: 'English',
            hostStatus: 'online',
            startedAt: DateTime.now(),
          ),
          LiveFeedCard(
            roomId: 'mock-offline-1',
            title: 'Offline mock',
            audienceCount: 0,
            hostUserId: 'mock-offline-user',
            hostDisplayName: 'MikeOffline',
            hostAvatarUrl: null,
            hostCountryCode: 'NG',
            hostLanguage: 'English',
            hostStatus: 'offline',
            startedAt: DateTime.now(),
          ),
        ]..sort((LiveFeedCard a, LiveFeedCard b) {
          int _rank(String s) => switch (s) {
            'live'    => 0,
            'busy'    => 1,
            'online'  => 2,
            _         => 3, // offline
          };
          return _rank(a.hostStatus).compareTo(_rank(b.hostStatus));
        });
        // ── mock: pretend we follow two of the mock users ──
        _followingIds = <String>{'mock-busy-user', 'mock-offline-user'};
        _myLiveRoom = feedCards
            .where((LiveFeedCard card) => card.hostUserId == me.id)
            .cast<LiveFeedCard?>()
            .map(
              (LiveFeedCard? card) => card == null
                  ? null
                  : Room(
                      id: card.roomId,
                      hostUserId: card.hostUserId,
                      title: card.title,
                      audienceCount: card.audienceCount,
                      status: 'live',
                      createdAt: card.startedAt,
                    ),
            )
            .firstWhere(
              (Room? room) => room != null,
              orElse: () => null,
            );
        _coinBalance = wallet.coinBalance;
        _userLevel = wallet.level;
        _myRevenue = wallet.revenueUsd;
        _coinPacks = packs;
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
    final bool isReachable = await widget.apiClient.ping();
    if (!mounted) {
      return;
    }

    setState(() {
      _apiReachable = isReachable;
    });
  }

  Future<void> _refreshHome() async {
    await Future.wait(<Future<void>>[_loadData(), _refreshApiStatus()]);
  }

  Future<void> _loadCallQuote() async {
    setState(() {
      _quoteLoading = true;
      _quoteError = null;
    });

    try {
      final CallQuote quote = await widget.apiClient.getPrivateCallQuote(
        minutes: _callMinutes,
        mode: _callMode,
        directRateCoinsPerMinute: _callMode == 'direct'
            ? _selectedDirectRate
            : null,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _callQuote = quote;
        if (
            quote.mode == 'direct' &&
            !quote.directCallAllowedRatesCoinsPerMinute.contains(
              _selectedDirectRate,
            )) {
          _selectedDirectRate = quote.directCallAllowedRatesCoinsPerMinute.first;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _quoteError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _quoteLoading = false;
        });
      }
    }
  }

  String? _resolveDirectReceiverUserId() {
    if (_selectedDirectReceiverUserId != null) {
      return _selectedDirectReceiverUserId;
    }
    if (_feedCards.isNotEmpty) {
      final int safeIndex = _activeFeedIndex.clamp(0, _feedCards.length - 1);
      return _feedCards[safeIndex].hostUserId;
    }
    return null;
  }

  Future<void> _startCallSession() async {
    if (_callQuote == null) {
      return;
    }

    final String? receiverUserId = _callMode == 'direct'
        ? _resolveDirectReceiverUserId()
        : null;
    if (_callMode == 'direct' && receiverUserId == null) {
      setState(() {
        _callActionError =
            'No receiver available for direct call. Try Random mode.';
      });
      return;
    }

    setState(() {
      _callActionLoading = true;
      _callActionError = null;
    });

    try {
      final CallSession session = await widget.apiClient.startCallSession(
        accessToken: widget.accessToken,
        mode: _callMode,
        receiverUserId: receiverUserId,
        directRateCoinsPerMinute: _callMode == 'direct'
            ? _selectedDirectRate
            : null,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _activeCallSession = session;
        _rtcJoinInfo = null;
        _rtcError = null;
      });

      unawaited(_prepareRtcJoin(session.id));

      _callTickTimer?.cancel();
      _callTickTimer = Timer.periodic(
        const Duration(seconds: _callTickIntervalSeconds),
        (_) {
          _runCallTick();
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call session started. Billing is live.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _callActionError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _callActionLoading = false;
        });
      }
    }
  }

  Future<void> _runCallTick() async {
    final CallSession? session = _activeCallSession;
    if (session == null || _tickInFlight) {
      return;
    }

    _tickInFlight = true;
    try {
      final CallSessionTickResult result = await widget.apiClient.tickCallSession(
        accessToken: widget.accessToken,
        sessionId: session.id,
        elapsedSeconds: _callTickIntervalSeconds,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _activeCallSession = result.session;
        _coinBalance = result.callerCoinBalanceAfter;
        if (result.session.status == 'ended') {
          _rtcJoinInfo = null;
        }
      });

      if (result.stoppedForInsufficientBalance || result.session.status == 'ended') {
        _callTickTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.stoppedForInsufficientBalance
                  ? 'Call ended: insufficient balance.'
                  : 'Call ended.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _callActionError = error.toString();
      });
      _callTickTimer?.cancel();
    } finally {
      _tickInFlight = false;
    }
  }

  Future<void> _endCallSession() async {
    final CallSession? session = _activeCallSession;
    if (session == null) {
      return;
    }

    setState(() {
      _callActionLoading = true;
      _callActionError = null;
    });

    try {
      final CallSession ended = await widget.apiClient.endCallSession(
        accessToken: widget.accessToken,
        sessionId: session.id,
        reason: 'caller_ended',
      );

      _callTickTimer?.cancel();

      if (!mounted) {
        return;
      }

      setState(() {
        _activeCallSession = ended;
        _rtcJoinInfo = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Call ended.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _callActionError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _callActionLoading = false;
        });
      }
    }
  }

  Future<void> _prepareRtcJoin(String sessionId) async {
    if (_rtcLoading) {
      return;
    }

    setState(() {
      _rtcLoading = true;
      _rtcError = null;
    });

    try {
      final RtcJoinInfo joinInfo = await widget.apiClient.requestCallRtcToken(
        accessToken: widget.accessToken,
        sessionId: sessionId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _rtcJoinInfo = joinInfo;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _rtcError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _rtcLoading = false;
        });
      }
    }
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
      final Room room = await widget.apiClient.createRoom(widget.accessToken, title);
      _roomTitleController.clear();
      _selectedDirectReceiverUserId = room.hostUserId;
      await _loadData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You are live now: ${room.title}')),
      );
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
      setState(() {
        _selectedDirectReceiverUserId = feedCard.hostUserId;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Watching ${feedCard.title} live')));
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

  Future<void> _endMyLive() async {
    final Room? liveRoom = _myLiveRoom;
    if (liveRoom == null) {
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      await widget.apiClient.endRoom(widget.accessToken, liveRoom.id);
      await _loadData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Live ended.')));
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
          _creating = false;
        });
      }
    }
  }

  void _openCallTabForHost(String hostUserId) {
    setState(() {
      _selectedDirectReceiverUserId = hostUserId;
      _selectedTabIndex = 2;
    });
    if (_callQuote == null && !_quoteLoading) {
      _loadCallQuote();
    }
  }

  Future<void> _openHostProfile(LiveFeedCard feedCard) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  feedCard.hostDisplayName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text('Status: Online · Live now'),
                const SizedBox(height: 4),
                Text('Current live: ${feedCard.title}'),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _enterRoom(feedCard);
                        },
                        child: const Text('Watch Live'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _openCallTabForHost(feedCard.hostUserId);
                        },
                        icon: const Icon(Icons.call_rounded),
                        label: const Text('Call'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
            InkWell(
              onTap: () => _openHostProfile(feedCard),
              child: Text(
                'Host: ${feedCard.hostDisplayName}',
                style: const TextStyle(
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Audience: ${feedCard.audienceCount}'),
            const SizedBox(height: 8),
            Text(
              'Started: ${feedCard.startedAt.toLocal().toIso8601String().substring(0, 16).replaceFirst('T', ' ')}',
            ),
            const Spacer(),
            Row(
              children: <Widget>[
                Expanded(
                  child: ElevatedButton(
                    onPressed: joiningCurrentRoom
                        ? null
                        : () => _enterRoom(feedCard),
                    child: Text(joiningCurrentRoom ? 'Opening...' : 'Watch Live'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openCallTabForHost(feedCard.hostUserId),
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Call Host'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _titleForTab() {
    return switch (_selectedTabIndex) {
      0 => 'Home',
      1 => 'Live',
      2 => 'Calls',
      3 => 'Inbox',
      4 => 'Me',
      _ => 'Zephyr',
    };
  }

  Future<void> _startRandomMatchFromHome() async {
    if (_callActionLoading || _quoteLoading) {
      return;
    }

    setState(() {
      _callMode = 'random';
      _selectedTabIndex = 2;
      _callActionError = null;
    });

    await _loadCallQuote();
    if (!mounted || _callQuote == null) {
      return;
    }

    if (_coinBalance < _callQuote!.requiredCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough coins for random match. Top up first.'),
        ),
      );
      return;
    }

    await _startCallSession();
  }

  Widget _buildHomeTopTab({
    required String label,
    required int index,
  }) {
    final bool selected = _homeTopTabIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _homeTopTabIndex = index;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.black : Colors.black54,
          ),
        ),
      ),
    );
  }

  void _openProfilePage(LiveFeedCard feedCard) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfilePage(
          feedCard: feedCard,
          onMessage: () {
            Navigator.of(context).pop();
            setState(() => _selectedTabIndex = 3);
          },
        ),
      ),
    );
  }

  Widget _buildDiscoverLiveCard(
    LiveFeedCard feedCard,
    bool isTablet, {
    bool showPreview = true,
    VoidCallback? onTap,
  }) {
    final bool joiningCurrentRoom = _joiningRoomId == feedCard.roomId;
    final double borderRadius = isTablet ? 44 : 34;
    final String localeLine = showPreview
        ? '${CountryFlags.flagEmoji(feedCard.hostCountryCode)} ${feedCard.hostCountryCode} ${feedCard.hostLanguage}'
        : '${CountryFlags.flagEmoji(feedCard.hostCountryCode)} ${feedCard.hostCountryCode}';
    final String status = feedCard.hostStatus; // 'live' | 'online' | 'busy' | 'offline'
    final bool isLive = status == 'live';

    // status badge colours
    final Color statusDot = switch (status) {
      'live'    => const Color(0xFFFF3B30),
      'busy'    => const Color(0xFFFF9500),
      'offline' => const Color(0xFF8E8E93),
      _         => const Color(0xFF34C759),
    };
    final String statusLabel = switch (status) {
      'live'    => 'Live',
      'busy'    => 'Busy',
      'offline' => 'Offline',
      _         => 'Online',
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Material(
        color: const Color(0xFF1FA4EA),
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: joiningCurrentRoom
              ? null
              : onTap ?? () => _enterRoom(feedCard),
          child: Stack(
            children: <Widget>[
              // ── top-left status badge ──────────────────────────────
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (showPreview) ...[
                        Icon(
                          Icons.videocam_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusDot,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── joining overlay ────────────────────────────────────
              Positioned(
                top: 20,
                left: 20,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: joiningCurrentRoom ? 1 : 0,
                  child: const Text(
                    'Opening live...',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              // ── preview box — only shown when Live ─────────────────
              if (isLive && showPreview)
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    width: isTablet ? 150 : 100,
                    height: isTablet ? 180 : 130,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    // LiveKit video widget mounts here when wired
                  ),
                ),
              Positioned(
                bottom: 12,
                left: 16,
                right: 4,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            feedCard.hostDisplayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            localeLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _ShakeCallButton(
                      onTap: () => _openCallTabForHost(feedCard.hostUserId),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopularTab(bool isTablet) {
    if (_feedCards.isEmpty) {
      return const Center(
        child: Text('No popular streamers right now. Check again in a moment.'),
      );
    }

    return Stack(
      children: <Widget>[
        GridView.builder(
          padding: const EdgeInsets.only(bottom: 56),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: isTablet ? 0.72 : 0.62,
          ),
          itemCount: _feedCards.length,
          itemBuilder: (BuildContext context, int index) {
            return _buildDiscoverLiveCard(_feedCards[index], isTablet,
                showPreview: false,
                onTap: () => _openProfilePage(_feedCards[index]));
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Center(
            child: FilledButton(
              onPressed: _startRandomMatchFromHome,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7BEA3B),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text('Random match'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFollowTab(bool isTablet) {
    final List<LiveFeedCard> followed = _feedCards
        .where((LiveFeedCard c) => _followingIds.contains(c.hostUserId))
        .toList();

    if (_followingIds.isEmpty || followed.isEmpty) {
      return const Center(
        child: Text(
          'Follow someone to see them here.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Stack(
      children: <Widget>[
        GridView.builder(
          padding: const EdgeInsets.only(bottom: 56),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: isTablet ? 0.72 : 0.62,
          ),
          itemCount: followed.length,
          itemBuilder: (BuildContext context, int index) {
            return _buildDiscoverLiveCard(followed[index], isTablet,
                showPreview: false,
                onTap: () => _openProfilePage(followed[index]));
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Center(
            child: FilledButton(
              onPressed: _startRandomMatchFromHome,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7BEA3B),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text('Random match'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoverTab(bool isTablet) {
    if (_feedCards.isEmpty) {
      return const Center(
        child: Text('No one is live right now. Check again in a moment.'),
      );
    }

    return Stack(
      children: <Widget>[
        PageView.builder(
          controller: _feedController,
          scrollDirection: Axis.vertical,
          itemCount: _feedCards.length,
          onPageChanged: (int index) {
            setState(() {
              _activeFeedIndex = index;
            });
          },
          itemBuilder: (BuildContext context, int index) {
            return Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 18),
              child: _buildDiscoverLiveCard(_feedCards[index], isTablet),
            );
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Center(
            child: FilledButton(
              onPressed: _startRandomMatchFromHome,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7BEA3B),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text('Random match'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeTab(bool isTablet) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isTablet ? 24 : 16,
            isTablet ? 16 : 8,
            isTablet ? 24 : 16,
            isTablet ? 24 : 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 4),
              Expanded(
                child: switch (_homeTopTabIndex) {
                  0 => _buildPopularTab(isTablet),
                  1 => _buildDiscoverTab(isTablet),
                  2 => _buildFollowTab(isTablet),
                  _ => const SizedBox.shrink(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveRoomsTab(bool isTablet) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Live Sessions',
                style: TextStyle(
                  fontSize: isTablet ? 24 : 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (_myLiveRoom != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'You are live: ${_myLiveRoom!.title} · ${_myLiveRoom!.audienceCount} viewers',
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _creating ? null : _endMyLive,
                          child: Text(_creating ? 'Ending...' : 'End Live'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _roomTitleController,
                        decoration: const InputDecoration(
                          labelText: 'Live Title',
                          hintText: 'Night Talk, Music Chill, etc.',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _creating ? null : _createRoom,
                      child: Text(_creating ? 'Starting...' : 'Go Live'),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Expanded(
                child: _feedCards.isEmpty
                    ? const Center(child: Text('No live sessions right now.'))
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
                              itemBuilder: (BuildContext context, int index) {
                                return _buildFeedCard(_feedCards[index]);
                              },
                            )
                          : ListView.builder(
                              itemCount: _feedCards.length,
                              itemBuilder: (BuildContext context, int index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: SizedBox(
                                    height: 240,
                                    child: _buildFeedCard(_feedCards[index]),
                                  ),
                                );
                              },
                            )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderTab({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 52, color: Colors.purple.shade300),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (action != null) ...<Widget>[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }

  Widget _buildCallPricingTab(bool isTablet) {
    final List<int> minuteOptions = <int>[1, 2, 3, 5, 10, 15];
    final List<int> directRateOptions =
        _callQuote?.directCallAllowedRatesCoinsPerMinute ?? <int>[2100, 4200, 8400];
    final String? directReceiverUserId = _resolveDirectReceiverUserId();
    final bool canStartDirectCall =
      _callMode != 'direct' || directReceiverUserId != null;
    final bool hasLiveSession =
      _activeCallSession != null && _activeCallSession!.status == 'live';
    final int quoteRequiredCoins = _callQuote?.requiredCoins ?? 0;
    final bool hasEnoughBalance = _coinBalance >= quoteRequiredCoins;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: ListView(
          padding: EdgeInsets.all(isTablet ? 24 : 16),
          children: <Widget>[
            const Text(
              'Call Pricing',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Preview pricing from backend before starting a call.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Call Type',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const <ButtonSegment<String>>[
                        ButtonSegment<String>(
                          value: 'direct',
                          label: Text('Direct'),
                          icon: Icon(Icons.person_pin_circle_rounded),
                        ),
                        ButtonSegment<String>(
                          value: 'random',
                          label: Text('Random'),
                          icon: Icon(Icons.casino_rounded),
                        ),
                      ],
                      selected: <String>{_callMode},
                      onSelectionChanged: (Set<String> selection) {
                        final String nextMode = selection.first;
                        if (nextMode == _callMode) {
                          return;
                        }
                        setState(() {
                          _callMode = nextMode;
                        });
                        _loadCallQuote();
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Minutes',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: _callMinutes,
                      items: minuteOptions
                          .map(
                            (int minute) => DropdownMenuItem<int>(
                              value: minute,
                              child: Text('$minute min'),
                            ),
                          )
                          .toList(),
                      onChanged: (int? value) {
                        if (value == null || value == _callMinutes) {
                          return;
                        }
                        setState(() {
                          _callMinutes = value;
                        });
                        _loadCallQuote();
                      },
                    ),
                    if (_callMode == 'direct') ...<Widget>[
                      const SizedBox(height: 16),
                      const Text(
                        'Receiver Rate Tier',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: directRateOptions.map((int tier) {
                          return ChoiceChip(
                            label: Text('${_formatCoins(tier)} / min'),
                            selected: _selectedDirectRate == tier,
                            onSelected: (bool selected) {
                              if (!selected || _selectedDirectRate == tier) {
                                return;
                              }
                              setState(() {
                                _selectedDirectRate = tier;
                              });
                              _loadCallQuote();
                            },
                          );
                        }).toList(),
                      ),
                      if (!canStartDirectCall)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'No receiver available from live feed yet. Open a live host card or use Random mode.',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Quote',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (_quoteLoading)
                      const Row(
                        children: <Widget>[
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Fetching live quote...'),
                        ],
                      )
                    else if (_quoteError != null)
                      Text(
                        _quoteError!,
                        style: const TextStyle(color: Colors.red),
                      )
                    else if (_callQuote != null) ...<Widget>[
                      Text(
                        'Mode: ${_callQuote!.mode == 'direct' ? 'Direct' : 'Random'}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rate: ${_formatCoins(_callQuote!.rateCoinsPerMinute)} coins/min',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total for ${_callQuote!.minutes} min: ${_formatCoins(_callQuote!.requiredCoins)} coins',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Your balance: ${_formatCoins(_coinBalance)} coins',
                      style: TextStyle(
                        color: hasEnoughBalance
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!_quoteLoading && _callQuote != null && !hasEnoughBalance)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Not enough coins. Please top up in My Balance before starting this call.',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    if (_callActionError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _callActionError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (_activeCallSession != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'Session ${_activeCallSession!.status == 'live' ? 'Live' : 'Ended'} • billed ${_formatCoins(_activeCallSession!.totalBilledCoins)} coins',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _rtcJoinInfo != null
                            ? 'RTC ready: ${_rtcJoinInfo!.provider} • ${_rtcJoinInfo!.role}'
                            : (_rtcLoading
                                  ? 'Preparing RTC token...'
                                  : 'RTC not prepared yet'),
                        style: TextStyle(
                          color: _rtcJoinInfo != null
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_rtcError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _rtcError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        ElevatedButton.icon(
                          onPressed: _quoteLoading ? null : _loadCallQuote,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Refresh Quote'),
                        ),
                        ElevatedButton(
                          onPressed: (_quoteLoading ||
                                  _callActionLoading ||
                                  _callQuote == null ||
                                  !hasEnoughBalance ||
                                  !canStartDirectCall ||
                                  hasLiveSession)
                              ? null
                              : _startCallSession,
                          child: Text(
                            _callActionLoading ? 'Working...' : 'Start Call',
                          ),
                        ),
                        if (hasLiveSession) ...<Widget>[
                          ElevatedButton.icon(
                            onPressed: (_callActionLoading ||
                                    _rtcLoading ||
                                    _activeCallSession == null)
                                ? null
                                : () => _prepareRtcJoin(_activeCallSession!.id),
                            icon: const Icon(Icons.videocam_rounded),
                            label: Text(
                              _rtcLoading ? 'Preparing RTC...' : 'Prepare RTC',
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _callActionLoading ? null : _endCallSession,
                            child: const Text('End Call'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCoins(int value) {
    return value.toString();
  }

  String _formatRevenue(double value) {
    return value.toStringAsFixed(2);
  }

  String _formatUsd(double value) {
    return '\$${_formatRevenue(value)}';
  }

  Future<void> _openLevelPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(title: const Text('Level')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.military_tech_rounded, size: 56),
                    const SizedBox(height: 12),
                    Text(
                      'Level $_userLevel',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Keep streaming, receiving gifts, and engaging to level up.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openBalancePage() async {
    String? purchasingPackId;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (
              BuildContext context,
              void Function(void Function()) setInnerState,
            ) {
              Future<void> buyCoins(CoinPack pack) async {
                setInnerState(() {
                  purchasingPackId = pack.id;
                });

                try {
                  final WalletSummary wallet = await widget.apiClient
                      .purchaseCoins(widget.accessToken, pack.id);

                  if (!mounted) {
                    return;
                  }

                  setState(() {
                    _coinBalance = wallet.coinBalance;
                    _userLevel = wallet.level;
                    _myRevenue = wallet.revenueUsd;
                  });

                  if (!mounted) {
                    return;
                  }

                  setInnerState(() {
                    purchasingPackId = null;
                  });

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Added ${pack.coins} coins via ${pack.label}.',
                      ),
                    ),
                  );
                } catch (error) {
                  if (!mounted) {
                    return;
                  }

                  setInnerState(() {
                    purchasingPackId = null;
                  });

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Purchase failed: $error')),
                  );
                }
              }

              return Scaffold(
                appBar: AppBar(title: const Text('My Balance')),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Coin Balance',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_formatCoins(_coinBalance)} coins',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Buy Coins',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ..._coinPacks.map((CoinPack pack) {
                      final bool isPurchasing = purchasingPackId == pack.id;

                      return ListTile(
                        leading: const _CoinIcon(size: 28),
                        title: Text('${pack.coins} coins • ${pack.label}'),
                        subtitle: Text(_formatUsd(pack.priceUsd)),
                        trailing: ElevatedButton(
                          onPressed: isPurchasing
                              ? null
                              : () {
                                  buyCoins(pack);
                                },
                          child: Text(isPurchasing ? 'Buying...' : 'Buy'),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openRevenuePage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(title: const Text('My Revenue')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.account_balance_wallet_rounded, size: 56),
                    const SizedBox(height: 12),
                    Text(
                      _formatUsd(_myRevenue),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Revenue from gifts and paid calls appears here.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openSettingsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: ListView(
              children: const <Widget>[
                ListTile(
                  leading: Icon(Icons.person_outline_rounded),
                  title: Text('Account'),
                ),
                ListTile(
                  leading: Icon(Icons.privacy_tip_outlined),
                  title: Text('Privacy'),
                ),
                ListTile(
                  leading: Icon(Icons.notifications_none_rounded),
                  title: Text('Notifications'),
                ),
                ListTile(
                  leading: Icon(Icons.language_rounded),
                  title: Text('Language'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMeTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
            title: Text(_me?.displayName ?? 'Me'),
            subtitle: Text(_me?.bio ?? 'Welcome to Zephyr'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.military_tech_rounded),
                title: const Text('Level'),
                trailing: Text('Lv $_userLevel'),
                onTap: _openLevelPage,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_rounded),
                title: const Text('My Balance'),
                trailing: Text('${_formatCoins(_coinBalance)} coins'),
                onTap: _openBalancePage,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.payments_rounded),
                title: const Text('My Revenue'),
                trailing: Text(_formatUsd(_myRevenue)),
                onTap: _openRevenuePage,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text('Settings'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _openSettingsPage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.sizeOf(context).width >= tabletBreakpoint;

    final Widget bodyContent = _loading
        ? const Center(child: CircularProgressIndicator())
        : switch (_selectedTabIndex) {
            0 => _buildHomeTab(isTablet),
            1 => _buildLiveRoomsTab(isTablet),
            2 => _buildCallPricingTab(isTablet),
            3 => _buildPlaceholderTab(
                icon: Icons.chat_bubble_rounded,
                title: 'Inbox',
                subtitle: 'Messages and notifications will appear here.',
              ),
            4 => _buildMeTab(),
            _ => const SizedBox.shrink(),
          };

    return Scaffold(
      appBar: AppBar(
        centerTitle: _selectedTabIndex == 0 ? false : null,
        title: _selectedTabIndex == 0
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    _buildHomeTopTab(label: 'Popular', index: 0),
                    const SizedBox(width: 12),
                    _buildHomeTopTab(label: 'Discover', index: 1),
                    const SizedBox(width: 12),
                    _buildHomeTopTab(label: 'Follow', index: 2),
                  ],
                ),
              )
            : Text(_titleForTab()),
        actions: <Widget>[
          if (_selectedTabIndex == 0) ...<Widget>[
            IconButton(
              tooltip: 'Search',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              iconSize: 20,
              onPressed: () {},
              icon: const Icon(Icons.search_rounded),
            ),
            IconButton(
              tooltip: 'Country',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              iconSize: 20,
              onPressed: () {},
              icon: SvgPicture.asset(
                'assets/flags/mu.svg',
                width: 20,
                height: 14,
                fit: BoxFit.cover,
              ),
            ),
            IconButton(
              tooltip: 'Trophy',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              iconSize: 20,
              onPressed: () {},
              icon: const Icon(Icons.emoji_events_outlined),
            ),
          ] else ...<Widget>[
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
        ],
      ),
      body: bodyContent,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedTabIndex = index;
          });
          if (index == 2 && _callQuote == null && !_quoteLoading) {
            _loadCallQuote();
          }
        },
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.live_tv_rounded),
            label: 'Live',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_rounded),
            label: 'Calls',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_rounded),
            label: 'Inbox',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person_rounded,
              color: _apiReachable == true ? Colors.green.shade700 : null,
            ),
            selectedIcon: Icon(
              Icons.person_rounded,
              color: _apiReachable == true ? Colors.green.shade700 : null,
            ),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}

class _ShakeCallButton extends StatefulWidget {
  const _ShakeCallButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ShakeCallButton> createState() => _ShakeCallButtonState();
}

class _ShakeCallButtonState extends State<_ShakeCallButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const Color _baseGreen = Color(0xFF00A651);
  static const Color _lightGreen = Color(0xFF7BEA3B);
  static const double _btnSize = 52;

  @override
  void initState() {
    super.initState();
    // 3.8 s cycle: short shake, rings expand slowly, long rest
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3800),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // gentle ring: only first 15% of cycle, slower oscillation (±6°)
  double _shakeAngle(double t) {
    if (t > 0.15) return 0;
    return sin(t * 10 * 2 * pi) * (6 * pi / 180);
  }

  // ring grows slowly — expands over 40% of the cycle, staggered by phase
  double? _ringProgress(double t, double phase) {
    final double shifted = (t + phase) % 1.0;
    if (shifted > 0.40) return null;
    return shifted / 0.40;
  }

  Widget _buildRing(double progress) {
    final double size = _btnSize + progress * 48;
    final double opacity = (1 - progress) * 0.35;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _baseGreen.withValues(alpha: opacity),
          width: 2.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = _controller.value;
        final double? r1 = _ringProgress(t, 0.0);
        final double? r2 = _ringProgress(t, 0.15);

        return SizedBox(
          width: _btnSize + 40,
          height: _btnSize + 40,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              if (r1 != null) _buildRing(r1),
              if (r2 != null) _buildRing(r2),
              Transform.rotate(
                angle: _shakeAngle(t),
                child: child,
              ),
            ],
          ),
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: _btnSize,
          height: _btnSize,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: <Color>[_baseGreen, _lightGreen],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.call_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}

// ── ProfilePage ─────────────────────────────────────────────────────────────

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.feedCard, required this.onMessage});

  final LiveFeedCard feedCard;
  final VoidCallback onMessage;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _following = false;

  LiveFeedCard get _card => widget.feedCard;

  void _showCallSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // drag handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // video call row
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 8),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00A651).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.call_rounded,
                            color: Color(0xFF00A651),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Video call',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            const Text(
                              '4200',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const _CoinIcon(size: 18),
                            const Text(
                              ' /min',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color get _statusColor => switch (_card.hostStatus) {
        'live' => const Color(0xFFFF3B30),
        'busy' => const Color(0xFFFF9500),
        'offline' => const Color(0xFF8E8E93),
        _ => const Color(0xFF34C759),
      };

  String get _statusLabel => switch (_card.hostStatus) {
        'live' => 'Live',
        'busy' => 'Busy',
        'offline' => 'Offline',
        _ => 'Online',
      };

  @override
  Widget build(BuildContext context) {
    final double bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                onPressed: widget.onMessage,
                icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 18),
                label: const Text('Message'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                  side: BorderSide.none,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: FilledButton(
                onPressed: (_card.hostStatus == 'offline' || _card.hostStatus == 'busy')
                    ? null
                    : () => _showCallSheet(context),
                style: FilledButton.styleFrom(
                  backgroundColor: switch (_card.hostStatus) {
                    'offline' => Colors.grey.shade400,
                    'busy'    => Colors.orange.shade300,
                    _         => const Color(0xFF00A651),
                  },
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                ),
                child: switch (_card.hostStatus) {
                  'offline' => const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.phone_disabled_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('Not available'),
                      ],
                    ),
                  'busy' => const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.phone_locked_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('Currently busy'),
                      ],
                    ),
                  _ => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(Icons.call_rounded, size: 18),
                        const SizedBox(width: 6),
                        const Text('Video call',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        const Text('4200',
                            style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 3),
                        const _CoinIcon(size: 13),
                        const Text('/min',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                },
              ),
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: <Widget>[
          // ── hero header ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: const Color(0xFF1FA4EA),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // cover photo placeholder (same blue as card)
                  Container(color: const Color(0xFF1FA4EA)),
                  // avatar centred in lower half
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 48,
                    child: Center(
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white24,
                        backgroundImage: _card.hostAvatarUrl != null
                            ? NetworkImage(_card.hostAvatarUrl!)
                            : null,
                        child: _card.hostAvatarUrl == null
                            ? Text(
                                _card.hostDisplayName.isNotEmpty
                                    ? _card.hostDisplayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  // live preview box — top-right (only when live), tappable
                  if (_card.hostStatus == 'live')
                    Positioned(
                      top: 72,
                      right: 16,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 100,
                          height: 130,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          // LiveKit video widget mounts here when wired
                        ),
                      ),
                    ),
                  // status badge bottom-right of cover
                  Positioned(
                    right: 20,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _statusLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // ── name + flag ──────────────────────────────────
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _card.hostDisplayName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${CountryFlags.flagEmoji(_card.hostCountryCode)} ${_card.hostCountryCode}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _card.hostLanguage,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── stats row ────────────────────────────────────
                  Row(
                    children: <Widget>[
                      _StatCell(
                          label: 'Followers', value: '—'),
                      const SizedBox(width: 32),
                      _StatCell(
                          label: 'Viewers',
                          value: _card.audienceCount > 0
                              ? '${_card.audienceCount}'
                              : '—'),
                      const SizedBox(width: 32),
                      _StatCell(label: 'Gifts', value: '—'),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── follow button ─────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() => _following = !_following);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _following
                            ? Colors.grey.shade300
                            : const Color(0xFF1FA4EA),
                        foregroundColor:
                            _following ? Colors.black87 : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _following ? 'Following' : 'Follow',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── bio placeholder ──────────────────────────────
                  const Text(
                    'About',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No bio yet.',
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Zephyr coin icon — reusable, no copyright ───────────────────────────────
class _CoinIcon extends StatelessWidget {
  const _CoinIcon({this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFD95A), Color(0xFFE6A817)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFE6A817).withValues(alpha: 0.4),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'Z',
          style: TextStyle(
            fontSize: size * 0.52,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF7A4A00),
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
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

  Future<void> endRoom(String accessToken, String roomId) async {
    await _request(
      method: 'DELETE',
      path: '/v1/rooms/$roomId',
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
