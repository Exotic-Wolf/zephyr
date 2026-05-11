import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show cos, pi, sin;
import 'package:country_picker/country_picker.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Country? _filterCountry;
  String _searchQuery = '';
  bool _searchActive = false;
  final TextEditingController _searchCtrl = TextEditingController();
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
    _searchCtrl.dispose();
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
            hostDisplayName: '[Mock] SarahBusy',
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
            hostDisplayName: '[Mock] TaniaOnline',
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
            hostDisplayName: '[Mock] MikeOffline',
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
        _myLiveRoom = null; // always reset; only set if backend confirms a live room
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

  Future<void> _showGoLiveSheet() async {
    _roomTitleController.clear();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Start a Live Room',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Give your stream a title',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                const SizedBox(height: 16),
                TextField(
                  controller: _roomTitleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Night Talk, Music Chill, Q&A…',
                    filled: true,
                    fillColor: const Color(0xFFF2F2F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1FA4EA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _createRoom();
                    },
                    child: const Text('Go Live 🔴', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
      if (!mounted) return;
      // Open fullscreen host screen
      await Navigator.of(context).push(MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => HostLiveScreen(
          room: room,
          apiClient: widget.apiClient,
          accessToken: widget.accessToken,
          hostDisplayName: _me?.displayName ?? 'Me',
          hostAvatarUrl: _me?.avatarUrl,
          onEnd: () {
            _loadData();
          },
        ),
      ));
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
    // Open fullscreen viewer screen immediately
    await Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ViewerLiveScreen(
        feedCard: feedCard,
        apiClient: widget.apiClient,
        accessToken: widget.accessToken,
        myUserId: _me?.id ?? '',
        myDisplayName: _me?.displayName ?? 'Guest',
        onLeave: () => _loadData(),
      ),
    ));
    // Notify backend of join in background
    widget.apiClient.joinRoom(widget.accessToken, feedCard.roomId).ignore();
    await _loadData();
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
      2 => 'Explore',
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

  Future<void> _searchByPublicId(String query) async {
    if (query.length != 8 || int.tryParse(query) == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter an exact 8-digit ID'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    try {
      final UserProfile profile =
          await widget.apiClient.getUserByPublicId(query);
      if (!mounted) return;
      // Close search bar
      setState(() { _searchActive = false; _searchCtrl.clear(); _searchQuery = ''; });
      // Build a minimal LiveFeedCard to reuse ProfilePage
      final LiveFeedCard card = LiveFeedCard(
        roomId: '',
        title: profile.displayName,
        hostUserId: profile.id,
        hostDisplayName: profile.displayName,
        hostAvatarUrl: profile.avatarUrl,
        hostCountryCode: profile.countryCode ?? 'XX',
        hostLanguage: profile.language ?? '',
        hostStatus: 'online',
        audienceCount: 0,
        startedAt: DateTime.now(),
      );
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ProfilePage(
          feedCard: card,
          apiClient: widget.apiClient,
          accessToken: widget.accessToken,
          myUserId: _me?.id,
          onMessage: () {
            Navigator.of(context).pop();
            setState(() => _selectedTabIndex = 3);
          },
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No user found with that ID'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _openProfilePage(LiveFeedCard feedCard) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfilePage(
          feedCard: feedCard,
          apiClient: widget.apiClient,
          accessToken: widget.accessToken,
          myUserId: _me?.id,
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

  List<LiveFeedCard> get _visibleCards {
    List<LiveFeedCard> cards = _filterCountry == null
        ? _feedCards
        : _feedCards.where((LiveFeedCard c) =>
            c.hostCountryCode.toUpperCase() == _filterCountry!.countryCode.toUpperCase()).toList();
    if (_searchQuery.isNotEmpty) {
      final String q = _searchQuery.toLowerCase();
      cards = cards.where((LiveFeedCard c) {
        if (c.hostDisplayName.toLowerCase().contains(q)) return true;
        final String pid = _derivePublicId(c.hostUserId);
        return pid.contains(q);
      }).toList();
    }
    return cards;
  }

  Widget _buildPopularTab(bool isTablet) {
    final List<LiveFeedCard> cards = _visibleCards;
    if (cards.isEmpty) {
      return Center(
        child: Text(
          _feedCards.isEmpty
              ? 'No popular streamers right now. Check again in a moment.'
              : _searchQuery.isNotEmpty
                  ? 'No results for "$_searchQuery".'
                  : 'No streamers from ${_filterCountry?.name ?? 'there'} right now.',
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
          itemCount: cards.length,
          itemBuilder: (BuildContext context, int index) {
            return _buildDiscoverLiveCard(cards[index], isTablet,
                showPreview: false,
                onTap: () => _openProfilePage(cards[index]));
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
    final List<LiveFeedCard> followed = _visibleCards
        .where((LiveFeedCard c) => _followingIds.contains(c.hostUserId))
        .toList();

    if (_followingIds.isEmpty || followed.isEmpty) {
      return Center(
        child: Text(
          _followingIds.isEmpty
              ? 'Follow someone to see them here.'
              : 'None of the people you follow are live from ${_filterCountry?.name ?? 'there'} right now.',
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
    final List<LiveFeedCard> cards = _visibleCards;
    if (cards.isEmpty) {
      return Center(
        child: Text(
          _feedCards.isEmpty
              ? 'No one is live right now. Check again in a moment.'
              : _searchQuery.isNotEmpty
                  ? 'No results for "$_searchQuery".'
                  : 'No one is live from ${_filterCountry?.name ?? 'there'} right now.',
        ),
      );
    }

    return Stack(
      children: <Widget>[
        PageView.builder(
          controller: _feedController,
          scrollDirection: Axis.vertical,
          itemCount: cards.length,
          onPageChanged: (int index) {
            setState(() {
              _activeFeedIndex = index;
            });
          },
          itemBuilder: (BuildContext context, int index) {
            return Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 18),
              child: _buildDiscoverLiveCard(cards[index], isTablet),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF1FA4EA), Color(0xFF7B5EA7)],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF1FA4EA).withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.live_tv_rounded, color: Colors.white, size: 42),
            ),
            const SizedBox(height: 24),
            const Text(
              'Go Live',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a live stream and connect\nwith your audience in real time',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade500, height: 1.5),
            ),
            const SizedBox(height: 36),
            GestureDetector(
              onTap: _creating ? null : _showGoLiveSheet,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF1FA4EA), Color(0xFF7B5EA7)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFF1FA4EA).withValues(alpha: 0.30),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(Icons.live_tv_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      _creating ? 'Starting…' : 'Start Live Stream',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
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

  Future<void> _openMyProfilePage() async {
    final UserProfile? updated = await Navigator.of(context).push(
      MaterialPageRoute<UserProfile>(
        builder: (_) => MyProfilePage(
          me: _me,
          apiClient: widget.apiClient,
          accessToken: widget.accessToken,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _me = updated);
    }
  }

  Future<void> _openCallPricePage() async {
    final UserProfile? updated = await Navigator.of(context).push(
      MaterialPageRoute<UserProfile>(
        builder: (_) => CallPricePage(
          userLevel: _userLevel,
          apiClient: widget.apiClient,
          accessToken: widget.accessToken,
          me: _me,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _me = updated);
    }
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
            title: Row(
              children: <Widget>[
                Text(_me?.displayName ?? 'Me'),
                if (_me?.isAdmin == true) ...<Widget>[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFFFFD700), Color(0xFFFF8C00)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'OWNER',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _openMyProfilePage,
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
                leading: const Icon(Icons.call_rounded),
                title: const Text('My Call Price'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _openCallPricePage,
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
            2 => ExplorePage(
                apiClient: widget.apiClient,
                accessToken: widget.accessToken,
                myUserId: _me?.id ?? '',
              ),
            3 => InboxPage(
                apiClient: widget.apiClient,
                accessToken: widget.accessToken,
                myUserId: _me?.id ?? '',
              ),
            4 => _buildMeTab(),
            _ => const SizedBox.shrink(),
          };

    return Scaffold(
      appBar: AppBar(
        centerTitle: _selectedTabIndex == 0 ? false : null,
        title: _selectedTabIndex == 0
            ? (_searchActive
                ? TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Name or ID…',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  )
                : SingleChildScrollView(
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
                  ))
            : Text(_titleForTab()),
        actions: <Widget>[
          if (_selectedTabIndex == 0) ...<Widget>[
            IconButton(
              tooltip: _searchActive ? 'Close search' : 'Search',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              iconSize: 20,
              onPressed: () => setState(() {
                _searchActive = !_searchActive;
                if (!_searchActive) {
                  _searchCtrl.clear();
                  _searchQuery = '';
                }
              }),
              icon: Icon(_searchActive ? Icons.close_rounded : Icons.search_rounded),
            ),
            if (_filterCountry != null) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 4),
                child: SizedBox(
                  width: 34, height: 34,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      GestureDetector(
                        onTap: () => showCountryPicker(
                          context: context,
                          showPhoneCode: false,
                          onSelect: (Country c) => setState(() => _filterCountry = c),
                        ),
                        child: Center(
                          child: Text(_filterCountry!.flagEmoji,
                              style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                      Positioned(
                        top: 0, right: 0,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _filterCountry = null),
                          child: Container(
                            width: 14, height: 14,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF1FA4EA),
                            ),
                            child: const Icon(Icons.close_rounded,
                                size: 10, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else
              GestureDetector(
                onTap: () => showCountryPicker(
                  context: context,
                  showPhoneCode: false,
                  onSelect: (Country c) => setState(() => _filterCountry = c),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.language_rounded, size: 22),
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
            icon: Icon(Icons.explore_rounded),
            label: 'Explore',
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
  const ProfilePage({
    super.key,
    required this.feedCard,
    required this.onMessage,
    this.isPreview = false,
    this.apiClient,
    this.accessToken,
    this.myUserId,
  });

  final LiveFeedCard feedCard;
  final VoidCallback onMessage;
  final bool isPreview;
  final ZephyrApiClient? apiClient;
  final String? accessToken;
  final String? myUserId;

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
      bottomNavigationBar: widget.isPreview ? null : Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                onPressed: () {
                  final api = widget.apiClient;
                  final token = widget.accessToken;
                  final me = widget.myUserId;
                  if (api != null && token != null && me != null) {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => ThreadPage(
                        apiClient: api,
                        accessToken: token,
                        myUserId: me,
                        otherUserId: _card.hostUserId,
                        otherDisplayName: _card.hostDisplayName,
                        otherAvatarUrl: _card.hostAvatarUrl,
                      ),
                    ));
                  } else {
                    widget.onMessage();
                  }
                },
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
                  if (_card.hostStatus == 'live' && !widget.isPreview)
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
                  if (!widget.isPreview)
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
                          label: 'Followers', value: '2.4K'),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── follow button ─────────────────────────────────
                  if (!widget.isPreview)
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

                  const SizedBox(height: 28),

                  // ── gifts section ─────────────────────────────────
                  const Text(
                    'Gifts',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'No gifts yet.',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade500),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── MyProfilePage ─────────────────────────────────────────────────────────────

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({
    super.key,
    required this.me,
    required this.apiClient,
    required this.accessToken,
  });
  final UserProfile? me;
  final ZephyrApiClient apiClient;
  final String accessToken;

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  late final TextEditingController _nicknameCtrl;
  bool _editing = false;
  bool _saving = false;

  String _gender = 'Prefer not to say';
  DateTime? _birthday;
  Country? _country;
  String _language = '';

  Future<void> _pickLanguage() async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LanguagePickerSheet(),
    );
    if (picked != null) setState(() => _language = picked);
  }

  static const List<String> _genders = <String>[
    'Male', 'Female', 'Non-binary', 'Prefer not to say',
  ];

  @override
  void initState() {
    super.initState();
    final UserProfile? me = widget.me;
    _nicknameCtrl = TextEditingController(text: me?.displayName ?? '');
    if (me?.gender != null) _gender = me!.gender!;
    if (me?.birthday != null) {
      _birthday = DateTime.tryParse(me!.birthday!);
    }
    if (me?.countryCode != null) {
      _country = CountryService().findByCode(me!.countryCode!);
    }
    if (me?.language != null && me!.language!.isNotEmpty) {
      _language = me.language!;
    }
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  String get _userId => widget.me?.publicId ?? '—';

  Future<void> _pickBirthday() async {
    if (!_editing) return;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  String _formatBirthday() {
    if (_birthday == null) return 'Not set';
    return '${_birthday!.day}/${_birthday!.month}/${_birthday!.year}';
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final String? birthdayStr = _birthday != null
          ? '${_birthday!.year.toString().padLeft(4, '0')}-'
            '${_birthday!.month.toString().padLeft(2, '0')}-'
            '${_birthday!.day.toString().padLeft(2, '0')}'
          : null;

      final UserProfile updated = await widget.apiClient.updateMe(
        widget.accessToken,
        displayName: _nicknameCtrl.text.trim().isEmpty
            ? null
            : _nicknameCtrl.text.trim(),
        gender: _gender,
        birthday: birthdayStr,
        countryCode: _country?.countryCode,
        language: _language.isEmpty ? null : _language,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Profile saved'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color valueColor = Colors.grey.shade600;
    const TextStyle valueStyle = TextStyle(fontSize: 14);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: <Widget>[
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_editing)
            TextButton(
              onPressed: _save,
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          else
            TextButton(
              onPressed: () => setState(() => _editing = true),
              child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[

          // ── Avatar ───────────────────────────────────────────
          Center(
            child: Column(
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: widget.me?.isAdmin == true
                          ? const Color(0xFFFFD700).withValues(alpha: 0.18)
                          : const Color(0xFF1FA4EA).withValues(alpha: 0.15),
                      child: Text(
                        (widget.me?.displayName ?? 'M').substring(0, 1).toUpperCase(),
                        style: TextStyle(
                            fontSize: 40, fontWeight: FontWeight.w700,
                            color: widget.me?.isAdmin == true
                                ? const Color(0xFFB8860B)
                                : const Color(0xFF1FA4EA)),
                      ),
                    ),
                    if (_editing)
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 30, height: 30,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF1FA4EA),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 16, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                if (widget.me?.isAdmin == true) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFFFFD700), Color(0xFFFF8C00)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '👑  OWNER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Fields ───────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: <Widget>[

                // ID — always read-only
                ListTile(
                  title: const Text('ID'),
                  trailing: GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _userId));
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(const SnackBar(
                          content: Text('ID copied to clipboard'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ));
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(_userId,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                        const SizedBox(width: 6),
                        Icon(Icons.copy_rounded, size: 15, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),

                // Nickname
                ListTile(
                  title: const Text('Nickname'),
                  trailing: _editing
                      ? SizedBox(
                          width: 160,
                          child: TextField(
                            controller: _nicknameCtrl,
                            textAlign: TextAlign.end,
                            style: valueStyle,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Enter nickname',
                              hintStyle: TextStyle(color: Colors.grey),
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        )
                      : Text(_nicknameCtrl.text.isEmpty ? '—' : _nicknameCtrl.text,
                          style: TextStyle(fontSize: 14, color: valueColor)),
                ),
                const Divider(height: 1),

                // Gender
                ListTile(
                  title: const Text('Gender'),
                  trailing: _editing
                      ? DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _gender,
                            isDense: true,
                            isExpanded: false,
                            alignment: AlignmentDirectional.centerEnd,
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                            selectedItemBuilder: (_) => _genders.map((String g) =>
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(g, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                              ),
                            ).toList(),
                            items: _genders.map((String g) => DropdownMenuItem<String>(
                              value: g, child: Text(g),
                            )).toList(),
                            onChanged: (String? v) {
                              if (v != null) setState(() => _gender = v);
                            },
                          ),
                        )
                      : Text(_gender, style: TextStyle(fontSize: 14, color: valueColor)),
                ),
                const Divider(height: 1),

                // Birthday
                ListTile(
                  title: const Text('Birthday'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(_formatBirthday(),
                          style: TextStyle(fontSize: 14, color: valueColor)),
                      if (_editing) ...<Widget>[
                        const SizedBox(width: 4),
                        Icon(Icons.edit_calendar_rounded,
                            size: 16, color: Colors.grey.shade400),
                      ],
                    ],
                  ),
                  onTap: _pickBirthday,
                ),
                const Divider(height: 1),

                // Country
                ListTile(
                  title: const Text('Country'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _country == null
                          ? Text('Not set', style: TextStyle(fontSize: 14, color: Colors.grey.shade400))
                          : Text('${_country!.flagEmoji} ${_country!.name}',
                              style: TextStyle(fontSize: 14, color: valueColor)),
                      if (_editing) ...<Widget>[
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: Colors.grey.shade400),
                      ],
                    ],
                  ),
                  onTap: _editing
                      ? () => showCountryPicker(
                            context: context,
                            showPhoneCode: false,
                            onSelect: (Country c) => setState(() => _country = c),
                          )
                      : null,
                ),
                const Divider(height: 1),

                // Language
                ListTile(
                  title: const Text('Language'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(_language.isEmpty ? 'Not set' : _language,
                          style: TextStyle(
                              fontSize: 14,
                              color: _language.isEmpty
                                  ? Colors.grey.shade400
                                  : valueColor)),
                      if (_editing) ...<Widget>[
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: Colors.grey.shade400),
                      ],
                    ],
                  ),
                  onTap: _editing ? _pickLanguage : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your ID is permanent and cannot be changed.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              final UserProfile? me = widget.me;
              final LiveFeedCard card = LiveFeedCard(
                roomId: '',
                title: '',
                audienceCount: 0,
                hostUserId: me?.id ?? '',
                hostDisplayName: me?.displayName ?? '',
                hostAvatarUrl: me?.avatarUrl,
                hostCountryCode: me?.countryCode ?? '',
                hostLanguage: me?.language ?? '',
                hostStatus: 'online',
                startedAt: DateTime.now(),
              );
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProfilePage(
                    feedCard: card,
                    onMessage: () {},
                    isPreview: true,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.person_search_rounded, size: 18),
            label: const Text('View Public Profile'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── CallPricePage ────────────────────────────────────────────────────────────

class _CallTier {
  const _CallTier({
    required this.label,
    required this.sparkPerMin,
    required this.coinsPerMin,
    required this.minLevel,
  });
  final String label;
  final int sparkPerMin;
  final int coinsPerMin;
  final int minLevel;
}

const List<_CallTier> _kCallTiers = <_CallTier>[
  _CallTier(label: '≤Lv3',  sparkPerMin:  1260,  coinsPerMin:  2100,  minLevel: 1),
  _CallTier(label: 'Lv4',   sparkPerMin:  1920,  coinsPerMin:  3200,  minLevel: 4),
  _CallTier(label: 'Lv5',   sparkPerMin:  2520,  coinsPerMin:  4200,  minLevel: 5),
  _CallTier(label: 'Lv6',   sparkPerMin:  3240,  coinsPerMin:  5400,  minLevel: 6),
  _CallTier(label: 'Lv7',   sparkPerMin:  3840,  coinsPerMin:  6400,  minLevel: 7),
  _CallTier(label: 'Lv8',   sparkPerMin:  4800,  coinsPerMin:  8000,  minLevel: 8),
  _CallTier(label: 'Lv9+',  sparkPerMin: 16200,  coinsPerMin: 27000,  minLevel: 9),
];

class CallPricePage extends StatefulWidget {
  const CallPricePage({
    super.key,
    required this.userLevel,
    required this.apiClient,
    required this.accessToken,
    this.me,
  });

  final int userLevel;
  final ZephyrApiClient apiClient;
  final String accessToken;
  final UserProfile? me;

  @override
  State<CallPricePage> createState() => _CallPricePageState();
}

class _CallPricePageState extends State<CallPricePage> {
  // default to highest tier the user qualifies for
  late int _selectedCoins = _kCallTiers
      .lastWhere(
        (t) => t.minLevel <= widget.userLevel,
        orElse: () => _kCallTiers.first,
      )
      .coinsPerMin;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate from saved rate if it matches a valid tier
    final int? saved = widget.me?.callRateCoinsPerMinute;
    if (saved != null &&
        _kCallTiers.any((t) => t.coinsPerMin == saved && t.minLevel <= widget.userLevel)) {
      _selectedCoins = saved;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final UserProfile updated = await widget.apiClient.updateMe(
        widget.accessToken,
        callRateCoinsPerMinute: _selectedCoins,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Call rate saved'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Call Price'),
        actions: <Widget>[
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: <Widget>[
          // ── Spark hero — 1/4 screen ───────────────────────────
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.32,
            child: Container(
              width: double.infinity,
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 200,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        // rays + sparkles layer behind flame
                        Positioned.fill(
                          child: CustomPaint(painter: _FlameGloryPainter()),
                        ),
                        // flame centered
                        SizedBox(
                          width: 70,
                          height: 90,
                          child: CustomPaint(painter: _ClassicFlamePainter()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Spark',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE53935),
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: <Widget>[
                        _HeroBullet(
                          iconWidget: const _SparkIcon(size: 16),
                          text: 'You earn Sparks every second you\'re on a call',
                        ),
                        const SizedBox(height: 6),
                        _HeroBullet(
                          iconWidget: const Icon(Icons.trending_up_rounded, size: 16, color: Color(0xFFE53935)),
                          text: 'Fair pricing gets you more calls, faster',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── rest of the page ──────────────────────────────────
          Expanded(
            child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // ── caller preview banner ─────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1FA4EA).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF1FA4EA).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFF1FA4EA), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 3,
                    children: <Widget>[
                      const Text('Callers will see:',
                          style: TextStyle(fontSize: 13, color: Colors.black87)),
                      Text('Video call  $_selectedCoins',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87)),
                      const _CoinIcon(size: 14),
                      const Text('/min',
                          style: TextStyle(fontSize: 13, color: Colors.black87)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Text('Choose your rate',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Your level is ${widget.userLevel}. Higher tiers unlock at higher levels.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),

          // ── tier table ────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: <Widget>[
                // header row
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: <Widget>[
                      const Expanded(
                          flex: 3,
                          child: Text('Tier',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey))),
                      const Expanded(
                          flex: 3,
                          child: Text('You earn',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey))),
                      const Expanded(
                          flex: 3,
                          child: Text('Caller pays',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey))),
                      const SizedBox(width: 32),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ..._kCallTiers.map((_CallTier tier) {
                  final bool unlocked =
                      widget.userLevel >= tier.minLevel;
                  final bool selected =
                      _selectedCoins == tier.coinsPerMin;
                  return Column(
                    children: <Widget>[
                      InkWell(
                        onTap: unlocked
                            ? () {
                                setState(() => _selectedCoins = tier.coinsPerMin);
                              }
                            : null,
                        child: Container(
                          color: selected
                              ? const Color(0xFF1FA4EA)
                                  .withValues(alpha: 0.08)
                              : null,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                flex: 3,
                                child: Text(
                                  tier.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: unlocked
                                        ? Colors.black87
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: <Widget>[
                                    Text(
                                      '${tier.sparkPerMin}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: unlocked
                                            ? const Color(0xFF00A651)
                                            : Colors.grey.shade400,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    unlocked
                                        ? Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: const _SparkIcon(size: 18),
                                          )
                                        : const SizedBox.shrink(),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: <Widget>[
                                    Text(
                                      '${tier.coinsPerMin}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: unlocked
                                            ? Colors.black87
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    unlocked
                                        ? const _CoinIcon(size: 13)
                                        : const SizedBox.shrink(),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 32,
                                child: unlocked
                                    ? (selected
                                        ? const Icon(
                                            Icons.check_circle_rounded,
                                            color: Color(0xFF1FA4EA),
                                            size: 20)
                                        : null)
                                    : Icon(Icons.lock_outline_rounded,
                                        size: 16,
                                        color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (tier != _kCallTiers.last)
                        const Divider(height: 1),
                    ],
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── level unlock note ─────────────────────────────────
          Text(
            '🔒 Locked tiers unlock as you level up by being active on Zephyr.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),

          const SizedBox(height: 8),
        ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Flame glory painter — light rays + 4-point sparkles ─────────────────────
class _FlameGloryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.5;
    final double cy = size.height * 0.52;

    // ── Light rays radiating from flame center ────────────────
    final Paint rayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 8 rays at different angles, skip bottom zone (flame is there)
    const List<double> angles = <double>[-80, -55, -35, -15, 15, 35, 55, 80, 105, 130, 150, 170, 200, 220, 240, 255];
    const List<double> lengths = <double>[38, 28, 42, 30, 30, 42, 28, 38, 22, 30, 38, 26, 30, 38, 26, 22];
    const List<double> starts  = <double>[46, 40, 50, 38, 38, 50, 40, 46, 36, 40, 46, 38, 40, 46, 38, 36];

    for (int i = 0; i < angles.length; i++) {
      final double a = angles[i] * pi / 180;
      final double r0 = starts[i];
      final double r1 = r0 + lengths[i];
      final double opacity = 0.18 + (i % 3) * 0.08;
      rayPaint
        ..color = const Color(0xFFFF8F00).withValues(alpha: opacity)
        ..strokeWidth = 2.5 + (i % 2) * 1.5;
      canvas.drawLine(
        Offset(cx + r0 * cos(a), cy + r0 * sin(a)),
        Offset(cx + r1 * cos(a), cy + r1 * sin(a)),
        rayPaint,
      );
    }

    // ── 4-point diamond sparkles ──────────────────────────────
    void drawSparkle(double x, double y, double r, Color color) {
      final Path p = Path()
        ..moveTo(x,     y - r)
        ..cubicTo(x + r*0.18, y - r*0.18, x + r*0.18, y - r*0.18, x + r, y)
        ..cubicTo(x + r*0.18, y + r*0.18, x + r*0.18, y + r*0.18, x,     y + r)
        ..cubicTo(x - r*0.18, y + r*0.18, x - r*0.18, y + r*0.18, x - r, y)
        ..cubicTo(x - r*0.18, y - r*0.18, x - r*0.18, y - r*0.18, x,     y - r)
        ..close();
      canvas.drawPath(p, Paint()..color = color);
    }

    // Large sparkle — upper left
    drawSparkle(cx - 72, cy - 28, 10, const Color(0xFFFFD21F).withValues(alpha: 0.95));
    // Small sparkle — upper left (nested)
    drawSparkle(cx - 58, cy - 44, 5, const Color(0xFFFFE76A).withValues(alpha: 0.90));
    // Medium sparkle — upper right
    drawSparkle(cx + 68, cy - 22, 8, const Color(0xFFFF8F00).withValues(alpha: 0.88));
    // Tiny sparkle — right mid
    drawSparkle(cx + 82, cy + 8, 4, const Color(0xFFFFD21F).withValues(alpha: 0.80));
    // Tiny sparkle — upper center-right
    drawSparkle(cx + 30, cy - 52, 5, const Color(0xFFFFE76A).withValues(alpha: 0.75));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── HostLiveScreen ────────────────────────────────────────────────────────────

class HostLiveScreen extends StatefulWidget {
  const HostLiveScreen({
    super.key,
    required this.room,
    required this.apiClient,
    required this.accessToken,
    required this.hostDisplayName,
    required this.hostAvatarUrl,
    required this.onEnd,
  });

  final Room room;
  final ZephyrApiClient apiClient;
  final String accessToken;
  final String hostDisplayName;
  final String? hostAvatarUrl;
  final VoidCallback onEnd;

  @override
  State<HostLiveScreen> createState() => _HostLiveScreenState();
}

class _HostLiveScreenState extends State<HostLiveScreen>
    with TickerProviderStateMixin {
  bool _micOn = true;
  bool _cameraOn = true;
  bool _ending = false;
  int _viewerCount = 0;
  int _elapsedSeconds = 0;
  Timer? _ticker;
  Timer? _viewerPoll;
  final List<_LiveComment> _comments = <_LiveComment>[];
  final List<_FloatingGift> _gifts = <_FloatingGift>[];
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _viewerCount = widget.room.audienceCount;
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
    _viewerPoll = Timer.periodic(const Duration(seconds: 5), (_) => _pollRoom());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _viewerPoll?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _pollRoom() async {
    // In future: fetch room from API to get live viewer count
  }

  String get _elapsed {
    final int m = _elapsedSeconds ~/ 60;
    final int s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _end() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End Live?'),
        content: const Text('Your stream will end and viewers will be disconnected.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Live', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _ending = true);
    try {
      await widget.apiClient.endRoom(widget.accessToken, widget.room.id);
    } catch (_) {
      // ignore API error — pop anyway so user isn't stuck
    }
    if (mounted) Navigator.of(context).pop();
    widget.onEnd();
  }

  void _addComment(String name, String text) {
    setState(() {
      _comments.add(_LiveComment(name: name, text: text));
      if (_comments.length > 30) _comments.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          // ── Background (camera placeholder) ──────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
              ),
            ),
          ),
          // Camera-off overlay
          if (!_cameraOn)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CircleAvatar(
                    radius: 56,
                    backgroundColor: Colors.white12,
                    backgroundImage: widget.hostAvatarUrl != null
                        ? NetworkImage(widget.hostAvatarUrl!)
                        : null,
                    child: widget.hostAvatarUrl == null
                        ? Text(widget.hostDisplayName[0].toUpperCase(),
                            style: const TextStyle(fontSize: 40, color: Colors.white))
                        : null,
                  ),
                  const SizedBox(height: 12),
                  const Text('Camera is off',
                      style: TextStyle(color: Colors.white54, fontSize: 14)),
                ],
              ),
            ),

          // ── Floating gift animations ──────────────────────────────────────
          ..._gifts.map((g) => _FloatingGiftWidget(gift: g)),

          // ── Top bar ──────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: <Widget>[
                  // Host info pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: widget.hostAvatarUrl != null
                              ? NetworkImage(widget.hostAvatarUrl!)
                              : null,
                          child: widget.hostAvatarUrl == null
                              ? Text(widget.hostDisplayName[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 12, color: Colors.white))
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(widget.hostDisplayName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // LIVE badge
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Color.lerp(Colors.red, Colors.red.shade300, _pulseCtrl.value),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(width: 6, height: 6,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Viewer count
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.remove_red_eye_rounded, color: Colors.white70, size: 13),
                        const SizedBox(width: 4),
                        Text('$_viewerCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Timer
                  Text(_elapsed, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(width: 8),
                  // Close
                  GestureDetector(
                    onTap: _ending ? null : _end,
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                      child: _ending
                          ? const Padding(padding: EdgeInsets.all(6), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Comments feed ────────────────────────────────────────────────
          Positioned(
            left: 12,
            right: 120,
            bottom: 110,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _comments.reversed.take(6).toList().reversed.map((c) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: <TextSpan>[
                          TextSpan(text: '${c.name}  ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                          TextSpan(text: c.text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ).toList(),
            ),
          ),

          // ── Bottom controls ──────────────────────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Colors.transparent, Colors.black87],
                ),
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _LiveCtrlBtn(
                    icon: _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                    label: _micOn ? 'Mic On' : 'Mic Off',
                    active: _micOn,
                    onTap: () => setState(() => _micOn = !_micOn),
                  ),
                  _LiveCtrlBtn(
                    icon: _cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                    label: _cameraOn ? 'Camera' : 'Off',
                    active: _cameraOn,
                    onTap: () => setState(() => _cameraOn = !_cameraOn),
                  ),
                  _LiveCtrlBtn(
                    icon: Icons.flip_camera_ios_rounded,
                    label: 'Flip',
                    active: true,
                    onTap: () {},
                  ),
                  _LiveCtrlBtn(
                    icon: Icons.people_rounded,
                    label: '$_viewerCount',
                    active: true,
                    onTap: () {},
                  ),
                  GestureDetector(
                    onTap: _ending ? null : _end,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text('End Live',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
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

// ── ViewerLiveScreen ──────────────────────────────────────────────────────────

class ViewerLiveScreen extends StatefulWidget {
  const ViewerLiveScreen({
    super.key,
    required this.feedCard,
    required this.apiClient,
    required this.accessToken,
    required this.myUserId,
    required this.myDisplayName,
    required this.onLeave,
  });

  final LiveFeedCard feedCard;
  final ZephyrApiClient apiClient;
  final String accessToken;
  final String myUserId;
  final String myDisplayName;
  final VoidCallback onLeave;

  @override
  State<ViewerLiveScreen> createState() => _ViewerLiveScreenState();
}

class _ViewerLiveScreenState extends State<ViewerLiveScreen>
    with TickerProviderStateMixin {
  int _viewerCount = 0;
  final List<_LiveComment> _comments = <_LiveComment>[];
  final List<_FloatingGift> _floatingGifts = <_FloatingGift>[];
  final TextEditingController _commentCtrl = TextEditingController();
  Timer? _viewerPoll;
  late final AnimationController _pulseCtrl;
  int _elapsedSeconds = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _viewerCount = widget.feedCard.audienceCount;
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
    _viewerPoll = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
    _comments.add(_LiveComment(name: widget.feedCard.hostDisplayName, text: 'Welcome to my live! 👋'));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _viewerPoll?.cancel();
    _pulseCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    // Future: fetch room viewer count from API
  }

  void _sendComment() {
    final String text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    _commentCtrl.clear();
    setState(() {
      _comments.add(_LiveComment(name: widget.myDisplayName, text: text));
      if (_comments.length > 30) _comments.removeAt(0);
    });
  }

  void _sendReaction(String emoji) {
    final String id = DateTime.now().millisecondsSinceEpoch.toString();
    final _FloatingGift gift = _FloatingGift(id: id, emoji: emoji);
    setState(() => _floatingGifts.add(gift));
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _floatingGifts.removeWhere((g) => g.id == id));
    });
  }

  String get _elapsed {
    final int m = _elapsedSeconds ~/ 60;
    final int s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: <Widget>[
          // ── Background ───────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
              ),
            ),
          ),
          // Host avatar center
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CircleAvatar(
                  radius: 64,
                  backgroundColor: Colors.white12,
                  backgroundImage: widget.feedCard.hostAvatarUrl != null
                      ? NetworkImage(widget.feedCard.hostAvatarUrl!)
                      : null,
                  child: widget.feedCard.hostAvatarUrl == null
                      ? Text(widget.feedCard.hostDisplayName[0].toUpperCase(),
                          style: const TextStyle(fontSize: 48, color: Colors.white))
                      : null,
                ),
                const SizedBox(height: 12),
                Text(widget.feedCard.hostDisplayName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(widget.feedCard.title,
                    style: const TextStyle(color: Colors.white60, fontSize: 14)),
              ],
            ),
          ),

          // ── Floating gifts ───────────────────────────────────────────────
          ..._floatingGifts.map((g) => _FloatingGiftWidget(gift: g)),

          // ── Top bar ──────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: widget.feedCard.hostAvatarUrl != null
                              ? NetworkImage(widget.feedCard.hostAvatarUrl!)
                              : null,
                          child: widget.feedCard.hostAvatarUrl == null
                              ? Text(widget.feedCard.hostDisplayName[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 12, color: Colors.white))
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(widget.feedCard.hostDisplayName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Color.lerp(Colors.red, Colors.red.shade300, _pulseCtrl.value),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(width: 6, height: 6,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.remove_red_eye_rounded, color: Colors.white70, size: 13),
                        const SizedBox(width: 4),
                        Text('$_viewerCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(_elapsed, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () { Navigator.of(context).pop(); widget.onLeave(); },
                    child: Container(
                      width: 32, height: 32,
                      decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Comment feed ─────────────────────────────────────────────────
          Positioned(
            left: 12,
            right: 120,
            bottom: 80,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _comments.reversed.take(6).toList().reversed.map((c) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
                    child: RichText(
                      text: TextSpan(children: <TextSpan>[
                        TextSpan(text: '${c.name}  ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                        TextSpan(text: c.text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ]),
                    ),
                  ),
                ),
              ).toList(),
            ),
          ),

          // ── Reaction buttons (right side) ────────────────────────────────
          Positioned(
            right: 12,
            bottom: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final String e in <String>['❤️', '😂', '🔥', '👏', '😍'])
                  GestureDetector(
                    onTap: () => _sendReaction(e),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                      child: Center(child: Text(e, style: const TextStyle(fontSize: 20))),
                    ),
                  ),
              ],
            ),
          ),

          // ── Bottom comment bar ───────────────────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Colors.transparent, Colors.black87],
                ),
              ),
              padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _commentCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Say something…',
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _sendComment(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendComment,
                    child: Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(color: Color(0xFF1FA4EA), shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
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

// ── Shared live helpers ───────────────────────────────────────────────────────

class _LiveComment {
  _LiveComment({required this.name, required this.text});
  final String name;
  final String text;
}

class _FloatingGift {
  _FloatingGift({required this.id, required this.emoji});
  final String id;
  final String emoji;
}

class _FloatingGiftWidget extends StatefulWidget {
  const _FloatingGiftWidget({required this.gift});
  final _FloatingGift gift;
  @override
  State<_FloatingGiftWidget> createState() => _FloatingGiftWidgetState();
}

class _FloatingGiftWidgetState extends State<_FloatingGiftWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..forward();
    _opacity = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.6, 1.0)));
    _offset = Tween<double>(begin: 0, end: -120).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 60,
      bottom: 200,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, _offset.value),
          child: Opacity(
            opacity: _opacity.value,
            child: Text(widget.gift.emoji, style: const TextStyle(fontSize: 40)),
          ),
        ),
      ),
    );
  }
}

class _LiveCtrlBtn extends StatelessWidget {
  const _LiveCtrlBtn({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: active ? Colors.white24 : Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: active ? Colors.white : Colors.white38, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── ExplorePage ───────────────────────────────────────────────────────────────

class ExplorePage extends StatefulWidget {
  const ExplorePage({
    super.key,
    required this.apiClient,
    required this.accessToken,
    required this.myUserId,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final String myUserId;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final TextEditingController _ctrl = TextEditingController();
  List<UserProfile> _results = <UserProfile>[];
  bool _searching = false;
  bool _hasSearched = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    q = q.trim();
    if (q == _lastQuery) return;
    _lastQuery = q;
    if (q.length < 2) {
      setState(() { _results = <UserProfile>[]; _hasSearched = false; });
      return;
    }
    setState(() => _searching = true);
    try {
      final List<UserProfile> res = await widget.apiClient.searchUsers(q);
      if (mounted && q == _lastQuery) {
        setState(() { _results = res; _hasSearched = true; _searching = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _searching = false; _hasSearched = true; });
    }
  }

  void _openProfile(UserProfile profile) {
    final LiveFeedCard card = LiveFeedCard(
      roomId: '',
      title: profile.displayName,
      hostUserId: profile.id,
      hostDisplayName: profile.displayName,
      hostAvatarUrl: profile.avatarUrl,
      hostCountryCode: profile.countryCode ?? 'XX',
      hostLanguage: profile.language ?? '',
      hostStatus: 'online',
      audienceCount: 0,
      startedAt: DateTime.now(),
    );
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ProfilePage(
        feedCard: card,
        apiClient: widget.apiClient,
        accessToken: widget.accessToken,
        myUserId: widget.myUserId,
        onMessage: () => Navigator.of(context).pop(),
      ),
    ));
  }

  void _openThread(UserProfile profile) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ThreadPage(
        apiClient: widget.apiClient,
        accessToken: widget.accessToken,
        myUserId: widget.myUserId,
        otherUserId: profile.id,
        otherDisplayName: profile.displayName,
        otherAvatarUrl: profile.avatarUrl,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: <Widget>[
          // ── Hero header ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF1FA4EA), Color(0xFF7B5EA7)],
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Explore',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Find anyone by name or 8-digit ID',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Icon(Icons.search_rounded,
                              color: Color(0xFF1FA4EA), size: 22),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            onChanged: _search,
                            textInputAction: TextInputAction.search,
                            onSubmitted: _search,
                            decoration: const InputDecoration(
                              hintText: 'Name or 8-digit ID…',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        if (_ctrl.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 18, color: Colors.grey),
                            onPressed: () {
                              _ctrl.clear();
                              _search('');
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Results / states ─────────────────────────────────────────────
          if (_searching)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!_hasSearched)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: <Color>[Color(0xFF1FA4EA), Color(0xFF7B5EA7)],
                        ),
                      ),
                      child: const Icon(Icons.explore_rounded,
                          color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Discover people',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Search by name or enter an\nexact 8-digit public ID',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            )
          else if (_results.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.person_search_rounded,
                        size: 56, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('No users found',
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey.shade500)),
                    const SizedBox(height: 4),
                    Text('Try a different name or ID',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade400)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext ctx, int i) {
                    final UserProfile p = _results[i];
                    return _ExploreUserCard(
                      profile: p,
                      onProfile: () => _openProfile(p),
                      onMessage: () => _openThread(p),
                    );
                  },
                  childCount: _results.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExploreUserCard extends StatelessWidget {
  const _ExploreUserCard({
    required this.profile,
    required this.onProfile,
    required this.onMessage,
  });

  final UserProfile profile;
  final VoidCallback onProfile;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onProfile,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                // Avatar
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      const Color(0xFF1FA4EA).withValues(alpha: 0.15),
                  backgroundImage: profile.avatarUrl != null
                      ? NetworkImage(profile.avatarUrl!)
                      : null,
                  child: profile.avatarUrl == null
                      ? Text(
                          profile.displayName.isNotEmpty
                              ? profile.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Color(0xFF1FA4EA),
                              fontWeight: FontWeight.w700,
                              fontSize: 18),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              profile.displayName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (profile.isAdmin) ...<Widget>[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: <Color>[
                                  Color(0xFFFFD700),
                                  Color(0xFFFFA500)
                                ]),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('OWNER',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          // ID pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1FA4EA)
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'ID: ${profile.publicId}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF1FA4EA),
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (profile.countryCode != null) ...<Widget>[
                            const SizedBox(width: 8),
                            Text(
                              profile.countryCode!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action buttons
                Column(
                  children: <Widget>[
                    _ActionBtn(
                      icon: Icons.chat_bubble_rounded,
                      color: const Color(0xFF1FA4EA),
                      onTap: onMessage,
                    ),
                    const SizedBox(height: 8),
                    _ActionBtn(
                      icon: Icons.person_rounded,
                      color: const Color(0xFF7B5EA7),
                      onTap: onProfile,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ── Message cache (in-memory, survives navigation within session) ─────────────

class _MessageCache {
  _MessageCache._();
  static final _MessageCache instance = _MessageCache._();

  List<ZephyrConversation>? conversations;
  final Map<String, List<ZephyrMessage>> threads = <String, List<ZephyrMessage>>{};
}

// ── InboxPage ─────────────────────────────────────────────────────────────────

class InboxPage extends StatefulWidget {
  const InboxPage({
    super.key,
    required this.apiClient,
    required this.accessToken,
    required this.myUserId,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final String myUserId;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  List<ZephyrConversation> _conversations = <ZephyrConversation>[];
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Show cache immediately — no spinner if we have data
    final cached = _MessageCache.instance.conversations;
    if (cached != null) {
      _conversations = cached;
      _loading = false;
    }
    _refresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // Called by pull-to-refresh button — shows spinner only if no cache
  Future<void> _load() async {
    if (_conversations.isEmpty) setState(() { _loading = true; _error = null; });
    await _refresh();
  }

  Future<void> _refresh() async {
    try {
      final List<ZephyrConversation> convos =
          await widget.apiClient.getConversations(widget.accessToken);
      _MessageCache.instance.conversations = convos;
      if (mounted) setState(() { _conversations = convos; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = _conversations.isEmpty ? e.toString() : null; _loading = false; });
    }
  }

  String _timeAgo(DateTime dt) {
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _conversations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No messages yet',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _conversations.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (BuildContext ctx, int i) {
                        final ZephyrConversation c = _conversations[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 26,
                            backgroundColor:
                                const Color(0xFF1FA4EA).withValues(alpha: 0.15),
                            backgroundImage: c.avatarUrl != null
                                ? NetworkImage(c.avatarUrl!)
                                : null,
                            child: c.avatarUrl == null
                                ? Text(
                                    c.displayName.isNotEmpty
                                        ? c.displayName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: Color(0xFF1FA4EA),
                                        fontWeight: FontWeight.w700),
                                  )
                                : null,
                          ),
                          title: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(c.displayName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ),
                              Text(_timeAgo(c.lastMessageAt),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade400)),
                            ],
                          ),
                          subtitle: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  c.lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: c.unreadCount > 0
                                          ? Colors.black87
                                          : Colors.grey.shade500,
                                      fontWeight: c.unreadCount > 0
                                          ? FontWeight.w500
                                          : FontWeight.normal),
                                ),
                              ),
                              if (c.unreadCount > 0)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1FA4EA),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${c.unreadCount}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ThreadPage(
                                  apiClient: widget.apiClient,
                                  accessToken: widget.accessToken,
                                  myUserId: widget.myUserId,
                                  otherUserId: c.userId,
                                  otherDisplayName: c.displayName,
                                  otherAvatarUrl: c.avatarUrl,
                                ),
                              ),
                            );
                            _load(); // refresh unread counts on return
                          },
                        );
                      },
                    ),
    );
  }
}

// ── ThreadPage ────────────────────────────────────────────────────────────────

class ThreadPage extends StatefulWidget {
  const ThreadPage({
    super.key,
    required this.apiClient,
    required this.accessToken,
    required this.myUserId,
    required this.otherUserId,
    required this.otherDisplayName,
    this.otherAvatarUrl,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final String myUserId;
  final String otherUserId;
  final String otherDisplayName;
  final String? otherAvatarUrl;

  @override
  State<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> {
  List<ZephyrMessage> _messages = <ZephyrMessage>[];
  bool _loading = true;
  bool _sending = false;
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Show cached thread instantly if available
    final cached = _MessageCache.instance.threads[widget.otherUserId];
    if (cached != null) {
      _messages = cached;
      _loading = false;
      _scrollToBottom();
    }
    _load();
    // Poll for new messages every 4 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<ZephyrMessage> msgs = await widget.apiClient
          .getThread(widget.accessToken, widget.otherUserId);
      _MessageCache.instance.threads[widget.otherUserId] = msgs;
      if (!mounted) return;
      setState(() { _messages = msgs; _loading = false; });
      // Mark unread incoming messages as read
      for (final ZephyrMessage m in msgs) {
        if (m.receiverId == widget.myUserId && m.readAt == null) {
          widget.apiClient.markMessageRead(widget.accessToken, m.id);
        }
      }
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _poll() async {
    if (!mounted || _sending) return;
    try {
      final List<ZephyrMessage> msgs = await widget.apiClient
          .getThread(widget.accessToken, widget.otherUserId);
      if (!mounted) return;
      final bool hasNew = msgs.length != _messages.length ||
          (msgs.isNotEmpty && _messages.isNotEmpty &&
           msgs.last.id != _messages.last.id);
      _MessageCache.instance.threads[widget.otherUserId] = msgs;
      setState(() => _messages = msgs);
      if (hasNew) {
        // Mark newly received messages as read
        for (final ZephyrMessage m in msgs) {
          if (m.receiverId == widget.myUserId && m.readAt == null) {
            widget.apiClient.markMessageRead(widget.accessToken, m.id);
          }
        }
        _scrollToBottom();
      }
    } catch (_) {
      // silently ignore poll errors
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final String text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _inputCtrl.clear();
    try {
      final ZephyrMessage msg = await widget.apiClient.sendMessage(
          widget.accessToken, widget.otherUserId, text);
      if (!mounted) return;
      final updated = <ZephyrMessage>[..._messages, msg];
      _MessageCache.instance.threads[widget.otherUserId] = updated;
      setState(() => _messages = updated);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatTime(DateTime dt) {
    final String h = dt.hour.toString().padLeft(2, '0');
    final String m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        leadingWidth: 40,
        title: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  const Color(0xFF1FA4EA).withValues(alpha: 0.15),
              backgroundImage: widget.otherAvatarUrl != null
                  ? NetworkImage(widget.otherAvatarUrl!)
                  : null,
              child: widget.otherAvatarUrl == null
                  ? Text(
                      widget.otherDisplayName.isNotEmpty
                          ? widget.otherDisplayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Color(0xFF1FA4EA),
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(widget.otherDisplayName),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text('No messages yet. Say hello!',
                            style: TextStyle(color: Colors.grey.shade500)),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        itemCount: _messages.length,
                        itemBuilder: (BuildContext ctx, int i) {
                          final ZephyrMessage msg = _messages[i];
                          final bool isMe =
                              msg.senderId == widget.myUserId;
                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(vertical: 3),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.sizeOf(ctx).width * 0.72),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xFF1FA4EA)
                                    : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 18),
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(msg.body,
                                      style: TextStyle(
                                          fontSize: 15,
                                          color: isMe
                                              ? Colors.white
                                              : Colors.black87)),
                                  const SizedBox(height: 3),
                                  Text(_formatTime(msg.createdAt),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: isMe
                                              ? Colors.white70
                                              : Colors.grey.shade400)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          // ── Input bar ──────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomPad),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _inputCtrl,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Message…',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _sending
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : GestureDetector(
                        onTap: _send,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF1FA4EA),
                          ),
                          child: const Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Spark icon — classic flame, Pantone Green 347C ──────────────────────────
// ── _LanguagePickerSheet ──────────────────────────────────────────────────────

class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet();

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  static const List<String> _all = <String>[
    'Afrikaans', 'Arabic', 'Bengali', 'Bulgarian', 'Catalan', 'Chinese (Simplified)',
    'Chinese (Traditional)', 'Croatian', 'Czech', 'Danish', 'Dutch', 'English',
    'Estonian', 'Finnish', 'French', 'German', 'Greek', 'Gujarati', 'Hebrew',
    'Hindi', 'Hungarian', 'Indonesian', 'Italian', 'Japanese', 'Kannada', 'Korean',
    'Latvian', 'Lithuanian', 'Malay', 'Malayalam', 'Marathi', 'Norwegian', 'Persian',
    'Polish', 'Portuguese', 'Punjabi', 'Romanian', 'Russian', 'Serbian', 'Slovak',
    'Slovenian', 'Spanish', 'Swahili', 'Swedish', 'Tamil', 'Telugu', 'Thai',
    'Turkish', 'Ukrainian', 'Urdu', 'Vietnamese',
  ];

  String _query = '';

  List<String> get _filtered => _query.isEmpty
      ? _all
      : _all.where((l) => l.toLowerCase().contains(_query.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Select Language',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search language…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF2F2F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final String lang = _filtered[i];
                  return ListTile(
                    title: Text(lang),
                    onTap: () => Navigator.of(context).pop(lang),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _SparkIcon ────────────────────────────────────────────────────────────────
class _SparkIcon extends StatelessWidget {
  const _SparkIcon({this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 0.78,
      height: size,
      child: CustomPaint(painter: _ClassicFlamePainter()),
    );
  }
}

class _ClassicFlamePainter extends CustomPainter {  // v4 saved — 3-tongue Olympic, good gradient
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Rect bounds = Rect.fromLTWH(0, 0, w, h);

    // ── Olympic flame: 3 tongues (left short, center tallest, right medium) ──
    final Path flame = Path()
      ..moveTo(w * 0.50, h * 1.00)
      // base left curve
      ..cubicTo(w * 0.18, h * 1.00, w * 0.06, h * 0.80, w * 0.12, h * 0.58)
      // left wall rising
      ..cubicTo(w * 0.16, h * 0.44, w * 0.20, h * 0.36, w * 0.22, h * 0.26)
      // left tongue — short, curled tip
      ..cubicTo(w * 0.22, h * 0.14, w * 0.27, h * 0.06, w * 0.30, h * 0.10)
      ..cubicTo(w * 0.33, h * 0.14, w * 0.34, h * 0.24, w * 0.37, h * 0.30)
      // valley between left and center
      ..cubicTo(w * 0.40, h * 0.36, w * 0.44, h * 0.30, w * 0.46, h * 0.20)
      // center tongue — tallest, sharp tip
      ..cubicTo(w * 0.48, h * 0.08, w * 0.50, h * 0.00, w * 0.52, h * 0.08)
      ..cubicTo(w * 0.54, h * 0.18, w * 0.58, h * 0.28, w * 0.60, h * 0.32)
      // valley between center and right
      ..cubicTo(w * 0.63, h * 0.26, w * 0.66, h * 0.18, w * 0.70, h * 0.12)
      // right tongue — medium height
      ..cubicTo(w * 0.74, h * 0.06, w * 0.78, h * 0.12, w * 0.76, h * 0.24)
      ..cubicTo(w * 0.74, h * 0.34, w * 0.78, h * 0.46, w * 0.84, h * 0.58)
      // base right curve
      ..cubicTo(w * 0.92, h * 0.80, w * 0.82, h * 1.00, w * 0.50, h * 1.00)
      ..close();

    // Main gradient: bright gold tip → vivid orange → deep red base
    canvas.drawPath(
      flame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const <Color>[
            Color(0xFFFFF176), // pale gold tip
            Color(0xFFFF8F00), // amber
            Color(0xFFE53935), // deep red base
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ).createShader(bounds),
    );

    // Inner bright core teardrop — gives depth & realism
    final Path core = Path()
      ..moveTo(w * 0.50, h * 0.28)
      ..cubicTo(w * 0.60, h * 0.42, w * 0.63, h * 0.62, w * 0.57, h * 0.74)
      ..cubicTo(w * 0.54, h * 0.82, w * 0.46, h * 0.82, w * 0.43, h * 0.74)
      ..cubicTo(w * 0.37, h * 0.62, w * 0.40, h * 0.42, w * 0.50, h * 0.28)
      ..close();

    canvas.drawPath(
      core,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.88),
            const Color(0xFFFFCC02).withValues(alpha: 0.55),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Spark hero painter — S-shaped flame silhouette ───────────────────────────
class _SparkHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // S-flame: two lobes — the silhouette reads as an S
    // Upper lobe curves right, lower lobe curves left, split tip at top
    final Path flame = Path()
      ..moveTo(w * 0.50, h * 0.98)          // base center
      // ── left side of base ──
      ..cubicTo(w * 0.14, h * 0.98, w * 0.04, h * 0.78, w * 0.10, h * 0.58)
      // ── lower-left up (bottom of S, left wall) ──
      ..cubicTo(w * 0.16, h * 0.42, w * 0.36, h * 0.40, w * 0.42, h * 0.36)
      // ── waist crossing left→right ──
      ..cubicTo(w * 0.54, h * 0.30, w * 0.28, h * 0.20, w * 0.28, h * 0.12)
      // ── left flame tip ──
      ..cubicTo(w * 0.28, h * 0.03, w * 0.38, h * 0.00, w * 0.44, h * 0.05)
      // ── notch between tips ──
      ..cubicTo(w * 0.47, h * 0.10, w * 0.53, h * 0.10, w * 0.56, h * 0.05)
      // ── right flame tip ──
      ..cubicTo(w * 0.62, h * 0.00, w * 0.72, h * 0.03, w * 0.72, h * 0.12)
      // ── upper-right down (top of S, right wall) ──
      ..cubicTo(w * 0.72, h * 0.20, w * 0.46, h * 0.30, w * 0.58, h * 0.36)
      // ── waist crossing right→left ──
      ..cubicTo(w * 0.64, h * 0.40, w * 0.84, h * 0.42, w * 0.90, h * 0.58)
      // ── right side of base ──
      ..cubicTo(w * 0.96, h * 0.78, w * 0.86, h * 0.98, w * 0.50, h * 0.98)
      ..close();

    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFF52E87A),
          const Color(0xFF00A651),
          const Color(0xFF006B32),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    // Subtle drop shadow
    canvas.drawPath(
      flame,
      Paint()
        ..color = const Color(0xFF00843F).withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.drawPath(flame, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// v5 — Realistic flame: asymmetric, tapered, flowing curves ──────────────────
class _RealFlamePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Rect bounds = Rect.fromLTWH(0, 0, w, h);

    final Paint gradPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFFFFF176),
          Color(0xFFFF8F00),
          Color(0xFFE53935),
        ],
        stops: <double>[0.0, 0.42, 1.0],
      ).createShader(bounds);

    // Outer silhouette — one dominant center tip, right lean, organic asymmetry
    final Path outer = Path()
      ..moveTo(w * 0.50, h * 1.00)
      // left base → up left side
      ..cubicTo(w * 0.16, h * 1.00, w * 0.04, h * 0.76, w * 0.12, h * 0.54)
      ..cubicTo(w * 0.18, h * 0.38, w * 0.26, h * 0.30, w * 0.28, h * 0.20)
      // left wisp — short curl, like a secondary tongue
      ..cubicTo(w * 0.28, h * 0.10, w * 0.34, h * 0.04, w * 0.36, h * 0.10)
      ..cubicTo(w * 0.38, h * 0.16, w * 0.38, h * 0.26, w * 0.40, h * 0.32)
      // flow inward to the main tip (tallest, slightly right of center)
      ..cubicTo(w * 0.43, h * 0.20, w * 0.47, h * 0.06, w * 0.52, h * 0.00)
      // down the right side of main tip
      ..cubicTo(w * 0.57, h * 0.06, w * 0.60, h * 0.16, w * 0.63, h * 0.24)
      // right shoulder — broader, softer
      ..cubicTo(w * 0.68, h * 0.16, w * 0.72, h * 0.10, w * 0.74, h * 0.16)
      ..cubicTo(w * 0.76, h * 0.22, w * 0.74, h * 0.34, w * 0.78, h * 0.44)
      ..cubicTo(w * 0.84, h * 0.56, w * 0.92, h * 0.72, w * 0.88, h * 0.86)
      ..cubicTo(w * 0.84, h * 1.00, w * 0.72, h * 1.00, w * 0.50, h * 1.00)
      ..close();

    // Soft shadow for depth
    canvas.drawPath(
      outer,
      Paint()
        ..color = const Color(0xFFBF360C).withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    canvas.drawPath(outer, gradPaint);

    // Bright inner core — tear shape, offset slightly up-left
    final Path core = Path()
      ..moveTo(w * 0.49, h * 0.26)
      ..cubicTo(w * 0.60, h * 0.38, w * 0.62, h * 0.60, w * 0.56, h * 0.74)
      ..cubicTo(w * 0.52, h * 0.83, w * 0.44, h * 0.83, w * 0.42, h * 0.74)
      ..cubicTo(w * 0.36, h * 0.60, w * 0.38, h * 0.38, w * 0.49, h * 0.26)
      ..close();

    canvas.drawPath(
      core,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.90),
            const Color(0xFFFFCC02).withValues(alpha: 0.60),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.50, 1.0],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _SparkBurstPainter extends CustomPainter {  // v1 — starburst + embers (saved)
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.5;
    final double cy = size.height * 0.5;
    final double outerR = size.width * 0.38;
    final double innerR = size.width * 0.15;

    final Paint p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Campfire spark — 8-point irregular starburst
    // Outer radii vary for organic feel
    const List<double> outerMult = <double>[1.00, 0.82, 1.00, 0.78, 1.00, 0.80, 1.00, 0.76];
    const int pts = 8;
    final Path star = Path();
    for (int i = 0; i < pts; i++) {
      final double outerAngle = (2 * pi * i / pts) - pi / 2;
      final double innerAngle = outerAngle + pi / pts;
      final double or_ = outerR * outerMult[i];
      final double ox = cx + or_ * cos(outerAngle);
      final double oy = cy + or_ * sin(outerAngle);
      final double ix = cx + innerR * cos(innerAngle);
      final double iy = cy + innerR * sin(innerAngle);
      if (i == 0) {
        star.moveTo(ox, oy);
      } else {
        star.lineTo(ox, oy);
      }
      star.lineTo(ix, iy);
    }
    star.close();
    canvas.drawPath(star, p);

    // Flying embers
    final Paint ember = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx + size.width * 0.34, cy - size.height * 0.30), size.width * 0.055, ember);
    canvas.drawCircle(Offset(cx - size.width * 0.30, cy - size.height * 0.28), size.width * 0.040, ember);
    canvas.drawCircle(Offset(cx + size.width * 0.12, cy + size.height * 0.36), size.width * 0.038, ember);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// v2 — Spark NZ style: bundle of crossing strokes through a center point
class _SparkCrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.5;
    final double cy = size.height * 0.5;

    // 10 lines at staggered angles — all cross the center, varying lengths
    const List<double> angleDeg = <double>[0, 18, 36, 54, 72, 90, 108, 126, 144, 162];
    const List<double> radMult  = <double>[0.45, 0.36, 0.43, 0.34, 0.46, 0.38, 0.44, 0.33, 0.45, 0.37];

    final Paint stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.10;

    for (int i = 0; i < angleDeg.length; i++) {
      final double a = angleDeg[i] * pi / 180;
      final double r = size.width * radMult[i];
      canvas.drawLine(
        Offset(cx - r * cos(a), cy - r * sin(a)),
        Offset(cx + r * cos(a), cy + r * sin(a)),
        stroke,
      );
    }

    // Small bright dot at center to anchor the burst
    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.08,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// v3 — Pearl: iridescent circle with highlight lustre
class _PearlPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.5;
    final double cy = size.height * 0.5;
    final double r  = size.width * 0.37;

    // Pearl body — soft blue-white iridescent gradient
    final Rect bodyRect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final Paint body = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.25, -0.35),
        radius: 1.0,
        colors: <Color>[
          Color(0xFFFFFFFF),
          Color(0xFFE4EEF7),
          Color(0xFFC3D8EC),
          Color(0xFFABC4DC),
        ],
        stops: <double>[0.0, 0.30, 0.65, 1.0],
      ).createShader(bodyRect);
    canvas.drawCircle(Offset(cx, cy), r, body);

    // Primary highlight — crisp white spot upper-left
    final Offset h1 = Offset(cx - r * 0.30, cy - r * 0.32);
    final Paint hi1 = Paint()
      ..shader = RadialGradient(
        colors: <Color>[Colors.white, Colors.white.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: h1, radius: r * 0.38));
    canvas.drawCircle(h1, r * 0.38, hi1);

    // Secondary soft glow — bottom right
    final Offset h2 = Offset(cx + r * 0.22, cy + r * 0.28);
    canvas.drawCircle(
      h2,
      r * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
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

class _HeroBullet extends StatelessWidget {
  const _HeroBullet({required this.iconWidget, required this.text});
  final Widget iconWidget;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        iconWidget,
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
          ),
        ),
      ],
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

/// Derives a stable 8-digit numeric public ID from a UUID using a djb2 hash.
String _derivePublicId(String uuid) {
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
  }) : publicId = publicId ?? _derivePublicId(id);

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
  static String derivePublicId(String uuid) => _derivePublicId(uuid);

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
