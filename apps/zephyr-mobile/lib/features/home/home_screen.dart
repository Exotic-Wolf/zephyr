import 'dart:async';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/firebase_chat_service.dart';
import 'widgets/popular_feed.dart';
import 'widgets/discover_feed.dart';
import 'widgets/follow_feed.dart';
import '../me/me_tab.dart';
import '../explore/explore_page.dart';
import '../live/go_live_countdown_page.dart';
import '../chat/inbox_firebase_page.dart';
import '../profile/profile_page.dart';
import '../live/viewer_live_screen.dart';
import '../../app_constants.dart';
import '../call/random_call_screen.dart';
import '../../l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.apiClient,
    required this.accessToken,
    required this.onLogout,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.locale,
    required this.onLocaleChanged,
    this.tabNotifier,
    super.key,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final VoidCallback onLogout;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final Locale? locale;
  final ValueChanged<Locale?> onLocaleChanged;
  final ValueNotifier<int>? tabNotifier;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _roomTitleController = TextEditingController();
  final PageController _feedController = PageController();
  UserProfile? _me;
  List<LiveFeedCard> _feedCards = <LiveFeedCard>[];
  Set<String> _followingIds = <String>{};
  int _selectedTabIndex = 0;
  int _homeTopTabIndex = 1;
  Timer? _feedPollTimer;
  sio.Socket? _feedSocket;
  Timer? _heartbeatTimer;
  int _activeFeedIndex = 0;
  Country? _filterCountry;
  String _searchQuery = '';
  bool _searchActive = false;
  final TextEditingController _searchCtrl = TextEditingController();
  bool? _apiReachable;
  bool _loading = true;
  final bool _creating = false;

  StreamSubscription<RemoteMessage>? _fcmSub;
  StreamSubscription<List<dynamic>>? _convoDeliverySub;
  String? _joiningRoomId;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _selectedTabIndex = widget.tabNotifier?.value ?? 0;
    widget.tabNotifier?.addListener(_onTabNotify);
    _loadData();
    _refreshApiStatus();
    _connectFeedSocket();
    _fcmSub = FirebaseMessaging.onMessage.listen((_) {});
  }

  void _onTabNotify() {
    final int tab = widget.tabNotifier?.value ?? 0;
    if (mounted) {
      setState(() => _selectedTabIndex = tab);
    }
  }

  void _sendHeartbeat() {
    widget.apiClient.heartbeat(widget.accessToken).catchError((_) {});
  }

  void _connectFeedSocket() {
    _feedSocket = sio.io(
      '$apiBaseUrl/feed',
      sio.OptionBuilder()
          .setTransports(<String>['websocket', 'polling'])
          .enableReconnection()
          .setReconnectionAttempts(100)
          .setReconnectionDelay(2000)
          .disableAutoConnect()
          .build(),
    );

    _feedSocket!
      ..on('connect', (_) {
        // Socket is healthy — kill the fallback poll
        _feedPollTimer?.cancel();
        _feedPollTimer = null;
        _refreshFeed(); // one sync to catch anything missed
      })
      ..on('disconnect', (_) {
        // Socket dropped — start fallback polling until it reconnects
        _feedPollTimer ??= Timer.periodic(
          const Duration(seconds: 30),
          (_) => _refreshFeed(),
        );
      })
      ..on('feed:room-created', (dynamic data) {
        if (!mounted) return;
        try {
          final Map<String, dynamic> payload =
              (data as Map<dynamic, dynamic>).cast<String, dynamic>();
          final LiveFeedCard card = LiveFeedCard.fromJson(
              (payload['card'] as Map<dynamic, dynamic>)
                  .cast<String, dynamic>());
          if (card.hostUserId == _me?.id) return;
          final bool exists = _feedCards.any((LiveFeedCard c) => c.hostUserId == card.hostUserId);
          if (exists) {
            _feedCards = _feedCards.map((LiveFeedCard c) =>
              c.hostUserId == card.hostUserId ? card : c).toList();
          } else {
            _feedCards = <LiveFeedCard>[card, ..._feedCards];
          }
          if (_selectedTabIndex == 0) setState(() {});
        } catch (_) {}
      })
      ..on('feed:room-ended', (dynamic data) {
        if (!mounted) return;
        try {
          final Map<String, dynamic> payload =
              (data as Map<dynamic, dynamic>).cast<String, dynamic>();
          final String hostUserId = payload['hostUserId'] as String;
          _feedCards = _feedCards.map((LiveFeedCard c) =>
            c.hostUserId == hostUserId
                ? c.copyWith(hostStatus: 'online', roomId: null, audienceCount: 0)
                : c,
          ).toList();
          if (_selectedTabIndex == 0) setState(() {});
        } catch (_) {}
      })
      ..on('feed:room-updated', (dynamic data) {
        if (!mounted) return;
        try {
          final Map<String, dynamic> payload =
              (data as Map<dynamic, dynamic>).cast<String, dynamic>();
          final String roomId = payload['roomId'] as String;
          final int count = payload['audienceCount'] as int;
          _feedCards = _feedCards.map((LiveFeedCard c) =>
            c.roomId == roomId ? c.copyWith(audienceCount: count) : c,
          ).toList();
          if (_selectedTabIndex == 0) setState(() {});
        } catch (_) {}
      })
      ..connect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _convoDeliverySub?.cancel();
    _fcmSub?.cancel();
    widget.tabNotifier?.removeListener(_onTabNotify);
    _feedPollTimer?.cancel();
    _heartbeatTimer?.cancel();
    _feedSocket?.dispose();
    _roomTitleController.dispose();
    _feedController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App back to foreground — reconnect socket fresh + sync feed
      if (_feedSocket?.disconnected == true) {
        _feedSocket!.connect();
      }
      _refreshFeed();
    }
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
        widget.apiClient.getFollowingIds(widget.accessToken),
      ]);

      final UserProfile me = data[0] as UserProfile;
      final List<LiveFeedCard> feedCards = data[1] as List<LiveFeedCard>;
      final Set<String> followingIds = data[2] as Set<String>;

      if (!mounted) {
        return;
      }
      setState(() {
        _me = me;
        _followingIds = followingIds;
        _feedCards = <LiveFeedCard>[
          ...feedCards.where((LiveFeedCard c) => c.hostUserId != me.id),
        ]..sort((LiveFeedCard a, LiveFeedCard b) {
          int rank(String s) => switch (s) {
            'live'    => 0,
            'busy'    => 1,
            'online'  => 2,
            _         => 3,
          };
          return rank(a.hostStatus).compareTo(rank(b.hostStatus));
        });
        // Warm Firebase RTDB presence for feed card hosts
        FirebaseChatService.instance.warmPresence(
          _feedCards.map((c) => c.hostUserId).toList(),
        );
        _activeFeedIndex = feedCards.isEmpty
            ? 0
            : _activeFeedIndex.clamp(0, feedCards.length - 1);
      });
      // Start HTTP heartbeat for presence (runs regardless of socket state)
      _heartbeatTimer ??= Timer.periodic(
        const Duration(seconds: 20),
        (_) => _sendHeartbeat(),
      );
      _sendHeartbeat(); // immediate first beat
      // Initialize Firebase with custom token for secure auth
      _initFirebaseChat(me.id);
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

  Future<void> _initFirebaseChat(String userId) async {
    try {
      final String token =
          await widget.apiClient.getFirebaseToken(widget.accessToken);
      await FirebaseChatService.instance.init(userId, firebaseToken: token);
    } catch (_) {
      // Fallback to anonymous if backend doesn't support custom tokens yet
      await FirebaseChatService.instance.init(userId);
    }
    // Wire push notifications for Firebase chat
    FirebaseChatService.instance.onSendPush = (recipientId, title, body) async {
      widget.apiClient
          .sendPushNotification(widget.accessToken, recipientId, title, body)
          .ignore();
    };

    // Global delivery receipts — mark messages delivered as soon as app receives them
    _convoDeliverySub?.cancel();
    _convoDeliverySub = FirebaseChatService.instance.watchConversations().listen((convos) {
      for (final c in convos) {
        if (c.unreadCount > 0) {
          FirebaseChatService.instance.markDelivered(c.otherUserId);
        }
      }
    });
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
      _feedCards = <LiveFeedCard>[
        ...feedCards.where((LiveFeedCard c) => c.hostUserId != _me?.id),
      ]..sort((LiveFeedCard a, LiveFeedCard b) {
        int rank(String s) => switch (s) {
          'live'   => 0,
          'busy'   => 1,
          'online' => 2,
          _        => 3,
        };
        return rank(a.hostStatus).compareTo(rank(b.hostStatus));
      });
      if (_selectedTabIndex == 0) setState(() {});
    } catch (_) {
      // ignore — next poll will retry
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
      _selectedTabIndex = 2;
    });
  }


  Future<void> _startRandomMatchFromHome() async {
    final String? userId = _me?.id;
    if (userId == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => RandomCallScreen(
          apiClient: widget.apiClient,
          accessToken: widget.accessToken,
          userId: userId,
        ),
      ),
    );
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
          myDisplayName: _me?.displayName,
          myAvatarUrl: _me?.avatarUrl,
          onMessage: () {
            Navigator.of(context).pop();
            setState(() => _selectedTabIndex = 3);
          },
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
    return PopularFeed(
      cards: cards,
      allCardsEmpty: _feedCards.isEmpty,
      searchQuery: _searchQuery,
      filterCountryName: _filterCountry?.name,
      isTablet: isTablet,
      onCardTap: _openProfilePage,
      onCallTap: (card) => _openCallTabForHost(card.hostUserId),
      onRandomMatch: _startRandomMatchFromHome,
    );
  }

  Widget _buildFollowTab(bool isTablet) {
    final List<LiveFeedCard> cards = _visibleCards;
    return FollowFeed(
      cards: cards,
      followingIds: _followingIds,
      filterCountryName: _filterCountry?.name,
      isTablet: isTablet,
      onCardTap: _openProfilePage,
      onCallTap: (card) => _openCallTabForHost(card.hostUserId),
      onRandomMatch: _startRandomMatchFromHome,
    );
  }

  Widget _buildDiscoverTab(bool isTablet) {
    final List<LiveFeedCard> cards = _visibleCards;
    return DiscoverFeed(
      cards: cards,
      allCardsEmpty: _feedCards.isEmpty,
      searchQuery: _searchQuery,
      filterCountryName: _filterCountry?.name,
      isTablet: isTablet,
      pageController: _feedController,
      onPageChanged: (int index) {
        setState(() {
          _activeFeedIndex = index;
        });
      },
      onCardTap: _enterRoom,
      onCallTap: (card) => _openCallTabForHost(card.hostUserId),
      onRandomMatch: _startRandomMatchFromHome,
      joiningRoomId: _joiningRoomId,
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
                myDisplayName: _me?.displayName ?? 'User',
                myAvatarUrl: _me?.avatarUrl,
              ),
            3 => InboxFirebasePage(
                myUserId: _me?.id ?? '',
                myDisplayName: _me?.displayName ?? 'User',
                myAvatarUrl: _me?.avatarUrl,
              ),
            4 => MeTab(
                me: _me,
                apiClient: widget.apiClient,
                accessToken: widget.accessToken,
                onLogout: widget.onLogout,
                locale: widget.locale,
                onLocaleChanged: widget.onLocaleChanged,
                themeMode: widget.themeMode,
                onThemeModeChanged: widget.onThemeModeChanged,
                onProfileUpdated: (profile) {
                  setState(() => _me = profile);
                },
              ),
            _ => const SizedBox.shrink(),
          };

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: Scaffold(
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
            : null,
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
          setState(() => _selectedTabIndex = index);
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
            icon: Icon(Icons.chat_bubble_rounded, color: isDark ? const Color(0xFF6B6B6B) : null),
            selectedIcon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFFFF8F00)),
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
    ),
    );
  }
}

