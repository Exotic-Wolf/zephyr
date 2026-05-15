import 'dart:async';
import 'dart:math' show pi, sin;
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../flags.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../widgets/coin_icon.dart';
import '../widgets/zephyr_mascot.dart';
import 'explore_page.dart';
import 'go_live_countdown_page.dart';
import 'inbox_page.dart';
import 'my_profile_page.dart';
import 'profile_page.dart';
import 'thread_page.dart';
import 'viewer_live_screen.dart';
import '../app_constants.dart';
import 'call_price_page.dart';
import '../l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.apiClient,
    required this.accessToken,
    required this.onLogout,
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final VoidCallback onLogout;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _roomTitleController = TextEditingController();
  final PageController _feedController = PageController();
  UserProfile? _me;
  List<LiveFeedCard> _feedCards = <LiveFeedCard>[];
  Set<String> _followingIds = <String>{};
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
  final int _callMinutes = 2;
  String _callMode = 'direct';
  int _selectedDirectRate = 2100;
  CallQuote? _callQuote;
  CallSession? _activeCallSession;
  Timer? _callTickTimer;
  Timer? _feedPollTimer;
  sio.Socket? _feedSocket;
  sio.Socket? _chatSocket;
  int _inboxUnread = 0;
  bool _callActionLoading = false;
  bool _tickInFlight = false;
  bool _rtcLoading = false;
  static const int _callTickIntervalSeconds = 10;
  bool _quoteLoading = false;
  int _activeFeedIndex = 0;
  Country? _filterCountry;
  String _searchQuery = '';
  bool _searchActive = false;
  final TextEditingController _searchCtrl = TextEditingController();
  bool? _apiReachable;
  bool _loading = true;
  final bool _creating = false;
  String? _joiningRoomId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshApiStatus();
    _connectFeedSocket();
    // Safety net: poll every 5s in case socket drops or hasn't connected yet
    _feedPollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshFeed());
  }

  void _connectChatSocket() {
    final String? userId = _me?.id;
    if (userId == null) return;
    _chatSocket = sio.io(
      '$apiBaseUrl/chat',
      sio.OptionBuilder()
          .setTransports(<String>['websocket', 'polling'])
          .setQuery(<String, String>{'userId': userId})
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(2000)
          .disableAutoConnect()
          .build(),
    )
      ..on('chat:message', (dynamic data) {
        if (!mounted) return;
        // Refresh conversation cache
        widget.apiClient.getConversations(widget.accessToken).then((convos) {
          MessageCache.instance.conversations = convos;
          if (!mounted) return;
          // Only bump badge if not currently on Inbox tab
          if (_selectedTabIndex != 3) {
            final int unread = convos.fold(0, (int sum, ZephyrConversation c) => sum + c.unreadCount);
            setState(() => _inboxUnread = unread);
          }
        }).catchError((_) {});
      })
      ..connect();
  }

  void _connectFeedSocket() {
    _feedSocket = sio.io(
      '$apiBaseUrl/feed',
      sio.OptionBuilder()
          .setTransports(<String>['websocket', 'polling'])
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(2000)
          .disableAutoConnect()
          .build(),
    );

    _feedSocket!
      ..on('feed:room-created', (dynamic data) {
        if (!mounted) return;
        try {
          final Map<String, dynamic> payload =
              (data as Map<dynamic, dynamic>).cast<String, dynamic>();
          final LiveFeedCard card = LiveFeedCard.fromJson(
              (payload['card'] as Map<dynamic, dynamic>)
                  .cast<String, dynamic>());
          if (card.hostUserId == _me?.id) return;
          setState(() {
            // Update existing card for this user to live, or prepend if new
            final bool exists = _feedCards.any((LiveFeedCard c) => c.hostUserId == card.hostUserId);
            if (exists) {
              _feedCards = _feedCards.map((LiveFeedCard c) =>
                c.hostUserId == card.hostUserId ? card : c).toList();
            } else {
              _feedCards = <LiveFeedCard>[card, ..._feedCards];
            }
          });
        } catch (_) {}
      })
      ..on('feed:room-ended', (dynamic data) {
        if (!mounted) return;
        try {
          final Map<String, dynamic> payload =
              (data as Map<dynamic, dynamic>).cast<String, dynamic>();
          final String hostUserId = payload['hostUserId'] as String;
          setState(() {
            // Card stays — just flip status back to online
            _feedCards = _feedCards.map((LiveFeedCard c) =>
              c.hostUserId == hostUserId
                  ? c.copyWith(hostStatus: 'online', roomId: null, audienceCount: 0)
                  : c,
            ).toList();
          });
        } catch (_) {}
      })
      ..on('feed:user-status', (dynamic data) {
        if (!mounted) return;
        try {
          final Map<String, dynamic> payload =
              (data as Map<dynamic, dynamic>).cast<String, dynamic>();
          final String hostUserId = payload['hostUserId'] as String;
          final String status = payload['status'] as String;
          setState(() {
            _feedCards = _feedCards.map((LiveFeedCard c) =>
              c.hostUserId == hostUserId ? c.copyWith(hostStatus: status) : c,
            ).toList();
          });
        } catch (_) {}
      })
      ..on('connect', (_) => debugPrint('[socket] connected to /feed'))
      ..on('disconnect', (_) => debugPrint('[socket] disconnected from /feed'))
      ..on('connect_error', (dynamic e) => debugPrint('[socket] connect_error: $e'))
      ..on('feed:room-updated', (dynamic data) {
        if (!mounted) return;
        try {
          final Map<String, dynamic> payload =
              (data as Map<dynamic, dynamic>).cast<String, dynamic>();
          final String roomId = payload['roomId'] as String;
          final int count = payload['audienceCount'] as int;
          setState(() {
            _feedCards = _feedCards.map((LiveFeedCard c) =>
              c.roomId == roomId ? c.copyWith(audienceCount: count) : c,
            ).toList();
          });
        } catch (_) {}
      })
      ..connect();
  }

  @override
  void dispose() {
    _callTickTimer?.cancel();
    _feedPollTimer?.cancel();
    _feedSocket?.dispose();
    _chatSocket?.dispose();
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
          // Filter out the logged-in user's own card
          ...feedCards.where((LiveFeedCard c) => c.hostUserId != me.id),
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
          int rank(String s) => switch (s) {
            'live'    => 0,
            'busy'    => 1,
            'online'  => 2,
            _         => 3, // offline
          };
          return rank(a.hostStatus).compareTo(rank(b.hostStatus));
        });
        // ── mock: pretend we follow two of the mock users ──
        _followingIds = <String>{'mock-busy-user', 'mock-offline-user'};
        _coinBalance = wallet.coinBalance;
        _userLevel = wallet.level;
        _myRevenue = wallet.revenueUsd;
        _coinPacks = packs;
        _activeFeedIndex = feedCards.isEmpty
            ? 0
            : _activeFeedIndex.clamp(0, feedCards.length - 1);
        _me = me;
      });
      // Connect chat socket now that we have userId
      if (_chatSocket == null) _connectChatSocket();
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

  /// Silently refreshes just the live feed cards (no loading spinner).
  Future<void> _refreshFeed() async {
    if (!mounted) return;
    try {
      final List<LiveFeedCard> feedCards =
          await widget.apiClient.listLiveFeed(widget.accessToken);
      if (!mounted) return;
      setState(() {
        _feedCards = <LiveFeedCard>[
          ...feedCards.where((LiveFeedCard c) => c.hostUserId != _me?.id),
          // ── mock cards ──
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
          int rank(String s) => switch (s) {
            'live'   => 0,
            'busy'   => 1,
            'online' => 2,
            _        => 3,
          };
          return rank(a.hostStatus).compareTo(rank(b.hostStatus));
        });
      });
    } catch (e) {
      // ignore network errors silently — next poll will retry
      debugPrint('[feed poll] error: $e');
    }
  }

  Future<void> _refreshHome() async {
    await Future.wait(<Future<void>>[_loadData(), _refreshApiStatus()]);
  }

  Future<void> _loadCallQuote() async {
    setState(() {
      _quoteLoading = true;
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
            'No receiver available for direct call. Try Random mode.';
      });
      return;
    }

    setState(() {
      _callActionLoading = true;
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
      });
      _callTickTimer?.cancel();
    } finally {
      _tickInFlight = false;
    }
  }


  Future<void> _prepareRtcJoin(String sessionId) async {
    if (_rtcLoading) {
      return;
    }

    setState(() {
      _rtcLoading = true;
    });

    try {
      await widget.apiClient.requestCallRtcToken(
        accessToken: widget.accessToken,
        sessionId: sessionId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
      });
    } finally {
      if (mounted) {
        setState(() {
          _rtcLoading = false;
        });
      }
    }
  }

  Future<void> _enterRoom(LiveFeedCard feedCard) async {
    final String? roomId = feedCard.roomId;
    if (roomId == null) return;
    // Join before opening — get correct initial count
    int updatedCount = feedCard.audienceCount;
    bool didJoin = false;
    try {
      final Room joined = await widget.apiClient.joinRoom(widget.accessToken, roomId);
      updatedCount = joined.audienceCount;
      didJoin = true;
    } catch (_) {}
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ViewerLiveScreen(
        feedCard: feedCard,
        apiClient: widget.apiClient,
        accessToken: widget.accessToken,
        myUserId: _me?.id ?? '',
        myDisplayName: _me?.displayName ?? 'Guest',
        onLeave: () => _loadData(),
        initialViewerCount: updatedCount,
        didJoin: didJoin,
      ),
    ));
    // leaveRoom is now handled by ViewerLiveScreen.dispose()
    await _loadData();
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


  String _titleForTab(AppLocalizations l10n) {
    return switch (_selectedTabIndex) {
      0 => l10n.home,
      1 => l10n.live,
      2 => l10n.explore,
      3 => l10n.inbox,
      4 => l10n.me,
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
    });

    await _loadCallQuote();
    if (!mounted || _callQuote == null) {
      return;
    }

    if (_coinBalance < _callQuote!.requiredCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.notEnoughCoinsForRandomMatch),
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
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
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
    final bool joiningCurrentRoom = feedCard.roomId != null && _joiningRoomId == feedCard.roomId;
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
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: joiningCurrentRoom
              ? null
              : onTap ?? () => _enterRoom(feedCard),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFF1C1C2E), Color(0xFF2D2D44)],
              ),
            ),
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
        final String pid = UserProfile.derivePublicId(c.hostUserId);
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
              ? AppLocalizations.of(context)!.noPopularStreamersRightNow
              : _searchQuery.isNotEmpty
                  ? AppLocalizations.of(context)!.noResultsFor(_searchQuery)
                  : AppLocalizations.of(context)!.noStreamersFrom(_filterCountry?.name ?? 'there'),
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
              ? AppLocalizations.of(context)!.followSomeoneToSeeThemHere
              : AppLocalizations.of(context)!.noneOfPeopleYouFollowAreLive(_filterCountry?.name ?? 'there'),
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
              ? AppLocalizations.of(context)!.noOneIsLiveRightNow
              : _searchQuery.isNotEmpty
                  ? AppLocalizations.of(context)!.noResultsFor(_searchQuery)
                  : AppLocalizations.of(context)!.noOneIsLiveFrom(_filterCountry?.name ?? 'there'),
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
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Radial ambient glow behind icon
              Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[
                          const Color(0xFFFF8F00).withValues(alpha: 0.28),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0xFFFFF176), Color(0xFFFF8F00), Color(0xFFE53935)],
                        stops: <double>[0.0, 0.5, 1.0],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(0xFFFF8F00).withValues(alpha: 0.55),
                          blurRadius: 32,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.live_tv_rounded, color: Colors.white, size: 42),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context)!.goLive,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: dark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.startLiveStreamAndConnect,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: dark ? const Color(0xFF8A8A8A) : Colors.black45,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),
              GestureDetector(
                onTap: _creating ? null : () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => GoLiveCountdownPage(
                      displayName: _me?.displayName ?? 'Me',
                      avatarUrl: _me?.avatarUrl,
                      apiClient: widget.apiClient,
                      accessToken: widget.accessToken,
                      onEnd: () => _loadData(),
                      onCancel: () {},
                    ),
                  ));
                  await _loadData();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: <Color>[Color(0xFFFF8F00), Color(0xFFE53935)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFFE53935).withValues(alpha: 0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(Icons.live_tv_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        _creating ? AppLocalizations.of(context)!.starting : AppLocalizations.of(context)!.startLiveStream,
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
            appBar: AppBar(title: Text(AppLocalizations.of(context)!.level)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.military_tech_rounded, size: 56),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context)!.levelValue(_userLevel),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.keepStreamingToLevelUp,
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
                appBar: AppBar(title: Text(AppLocalizations.of(context)!.myBalance)),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              AppLocalizations.of(context)!.coinBalance,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context)!.coinsAmount(_coinBalance),
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
                    Text(
                      AppLocalizations.of(context)!.buyCoins,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ..._coinPacks.map((CoinPack pack) {
                      final bool isPurchasing = purchasingPackId == pack.id;

                      return ListTile(
                        leading: const CoinIcon(size: 28),
                        title: Text(AppLocalizations.of(context)!.coinPackLabel(pack.coins, pack.label)),
                        subtitle: Text(_formatUsd(pack.priceUsd)),
                        trailing: ElevatedButton(
                          onPressed: isPurchasing
                              ? null
                              : () {
                                  buyCoins(pack);
                                },
                          child: Text(isPurchasing ? AppLocalizations.of(context)!.buying : AppLocalizations.of(context)!.buy),
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
            appBar: AppBar(title: Text(AppLocalizations.of(context)!.myRevenue)),
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
                    Text(
                      AppLocalizations.of(context)!.revenueFromGiftsAndCalls,
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
            appBar: AppBar(title: Text(AppLocalizations.of(context)!.settings)),
            body: ListView(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(AppLocalizations.of(context)!.account),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(AppLocalizations.of(context)!.privacy),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_none_rounded),
                  title: Text(AppLocalizations.of(context)!.notifications),
                ),
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(AppLocalizations.of(context)!.language),
                ),
                ListTile(
                  leading: const Icon(Icons.brightness_6_rounded),
                  title: Text(AppLocalizations.of(context)!.appearance),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _AppearancePage(
                          current: widget.themeMode,
                          onChanged: widget.onThemeModeChanged,
                        ),
                      ),
                    );
                  },
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
            leading: CircleAvatar(
              backgroundImage: _me?.avatarUrl != null ? NetworkImage(_me!.avatarUrl!) : null,
              child: _me?.avatarUrl == null ? const Icon(Icons.person_rounded) : null,
            ),
            title: Row(
              children: <Widget>[
                Text(_me?.displayName ?? AppLocalizations.of(context)!.me),
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
                    child: Text(
                      AppLocalizations.of(context)!.owner,
                      style: const TextStyle(
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
                title: Text(AppLocalizations.of(context)!.level),
                trailing: Text('Lv $_userLevel'),
                onTap: _openLevelPage,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_rounded),
                title: Text(AppLocalizations.of(context)!.myBalance),
                trailing: Text(AppLocalizations.of(context)!.coinsAmount(_coinBalance)),
                onTap: _openBalancePage,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.payments_rounded),
                title: Text(AppLocalizations.of(context)!.myRevenue),
                trailing: Text(_formatUsd(_myRevenue)),
                onTap: _openRevenuePage,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.call_rounded),
                title: Text(AppLocalizations.of(context)!.myCallPrice),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _openCallPricePage,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: Text(AppLocalizations.of(context)!.settings),
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
    final AppLocalizations l10n = AppLocalizations.of(context)!;

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

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _selectedTabIndex == 1 ? (isDark ? const Color(0xFF0D0A08) : null) : null,
      appBar: AppBar(
        backgroundColor: _selectedTabIndex == 1 ? (isDark ? const Color(0xFF0D0A08) : null) : null,
        foregroundColor: _selectedTabIndex == 1 ? (isDark ? Colors.white : Colors.black87) : null,
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
                        _buildHomeTopTab(label: l10n.popular, index: 0),
                        const SizedBox(width: 12),
                        _buildHomeTopTab(label: l10n.discover, index: 1),
                        const SizedBox(width: 12),
                        _buildHomeTopTab(label: l10n.follow, index: 2),
                      ],
                    ),
                  ))
            : Text(_titleForTab(l10n)),
        actions: <Widget>[
          if (_selectedTabIndex == 0) ...<Widget>[
            IconButton(
              tooltip: _searchActive ? l10n.closeSearch : l10n.search,
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
              tooltip: l10n.refresh,
              onPressed: _loading ? null : _refreshHome,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: l10n.logout,
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ],
      ),
      body: bodyContent,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Divider(height: 1, thickness: 0.5, color: Color(0xFF2A2A2A)),
          NavigationBar(
        selectedIndex: _selectedTabIndex,
        backgroundColor: isDark ? const Color(0xFF111111) : null,
        indicatorColor: const Color(0xFFFF8F00).withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? const Color(0xFFFF8F00) : null,
          );
        }),
        onDestinationSelected: (int index) {
          setState(() {
            _selectedTabIndex = index;
            if (index == 3) _inboxUnread = 0; // clear badge when opening Inbox
          });
        },
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_rounded, color: isDark ? const Color(0xFF6B6B6B) : null),
            selectedIcon: const Icon(Icons.home_rounded, color: Color(0xFFFF8F00)),
            label: l10n.home,
          ),
          NavigationDestination(
            icon: Icon(Icons.live_tv_rounded, color: isDark ? const Color(0xFF6B6B6B) : null),
            selectedIcon: const Icon(Icons.live_tv_rounded, color: Color(0xFFFF8F00)),
            label: l10n.live,
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_rounded, color: isDark ? const Color(0xFF6B6B6B) : null),
            selectedIcon: const Icon(Icons.explore_rounded, color: Color(0xFFFF8F00)),
            label: l10n.explore,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _inboxUnread > 0,
              label: Text(_inboxUnread > 9 ? '9+' : '$_inboxUnread'),
              child: Icon(Icons.chat_bubble_rounded, color: isDark ? const Color(0xFF6B6B6B) : null),
            ),
            selectedIcon: Badge(
              isLabelVisible: _inboxUnread > 0,
              label: Text(_inboxUnread > 9 ? '9+' : '$_inboxUnread'),
              child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFFFF8F00)),
            ),
            label: l10n.inbox,
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person_rounded,
              color: _apiReachable == true ? Colors.green.shade700 : (isDark ? const Color(0xFF6B6B6B) : null),
            ),
            selectedIcon: Icon(
              Icons.person_rounded,
              color: _apiReachable == true ? Colors.green.shade700 : const Color(0xFFFF8F00),
            ),
            label: l10n.me,
          ),
        ],
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

// ── Appearance Settings Page ──────────────────────────────────────────────────
class _AppearancePage extends StatelessWidget {
  const _AppearancePage({required this.current, required this.onChanged});

  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.appearance)),
      body: ListView(
        children: <Widget>[
          _AppearanceTile(
            icon: Icons.brightness_auto_rounded,
            label: AppLocalizations.of(context)!.systemDefault,
            subtitle: AppLocalizations.of(context)!.followDeviceSetting,
            mode: ThemeMode.system,
            current: current,
            onChanged: onChanged,
          ),
          _AppearanceTile(
            icon: Icons.light_mode_rounded,
            label: AppLocalizations.of(context)!.lightMode,
            subtitle: AppLocalizations.of(context)!.alwaysUseLightMode,
            mode: ThemeMode.light,
            current: current,
            onChanged: onChanged,
          ),
          _AppearanceTile(
            icon: Icons.dark_mode_rounded,
            label: AppLocalizations.of(context)!.darkMode,
            subtitle: AppLocalizations.of(context)!.alwaysUseDarkMode,
            mode: ThemeMode.dark,
            current: current,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _AppearanceTile extends StatelessWidget {
  const _AppearanceTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.mode,
    required this.current,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final ThemeMode mode;
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool selected = current == mode;
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(subtitle),
      trailing: selected
          ? Icon(Icons.check_circle_rounded,
              color: Theme.of(context).colorScheme.primary)
          : const Icon(Icons.radio_button_unchecked_rounded),
      onTap: () => onChanged(mode),
    );
  }
}

