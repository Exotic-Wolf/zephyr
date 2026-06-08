import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/firebase_chat_service.dart';
import '../../widgets/zephyr_app_header.dart';
import 'widgets/for_you_feed.dart';
import 'widgets/follow_feed.dart';
import '../me/me_tab.dart';
import '../me/balance_page.dart';
import '../explore/explore_page.dart';
import '../live/go_live_countdown_page.dart';
import '../live/viewer_live_screen.dart';
import '../chat/inbox_firebase_page.dart';
import '../profile/profile_page.dart';
import '../../app_constants.dart';
import '../call/random_call_screen.dart';
import '../call/direct_call_screen.dart';
import '../call/incoming_call_overlay.dart';
import '../call/random_call_invite_ribbon.dart';
import '../../l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.apiClient,
    required this.accessToken,
    required this.onLogout,
    required this.onDeleteAccount,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.locale,
    required this.onLocaleChanged,
    this.tabNotifier,
    super.key,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final Future<void> Function() onLogout;
  final Future<void> Function() onDeleteAccount;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final Locale? locale;
  final ValueChanged<Locale?> onLocaleChanged;
  final ValueNotifier<int>? tabNotifier;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const int _forYouPageSize = 24;

  UserProfile? _me;
  WalletSummary? _wallet;
  List<LiveFeedCard> _feedCards = <LiveFeedCard>[];
  Set<String> _followingIds = <String>{};
  int _selectedTabIndex = 0;
  bool? _apiReachable;
  bool _loading = true;
  final bool _creating = false;

  StreamSubscription<RemoteMessage>? _fcmSub;
  StreamSubscription<List<dynamic>>? _convoDeliverySub;
  StreamSubscription<List<FirebaseConversation>>? _inboxBadgeSub;
  String? _error;
  int _inboxUnreadTotal = 0;
  String? _joiningRoomId;
  int _feedOffset = 0;
  bool _hasMoreFeedCards = true;
  bool _loadingMoreFeedCards = false;

  // ── Incoming call state ───────────────────────────────────────────────────
  StreamSubscription<DatabaseEvent>? _incomingCallSub;
  String? _incomingCallerId;
  String? _incomingCallerName;
  String? _incomingCallerAvatarUrl;
  String? _incomingSessionId;
  Map<String, dynamic>? _randomCallInvite;
  Timer? _randomCallInviteTimer;
  bool _acceptingRandomCallInvite = false;

  // ── Idle detection (away after 60s no touch) ──────────────────────────────
  Timer? _idleTimer;
  bool _isIdle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _selectedTabIndex = _normalizeRootTab(widget.tabNotifier?.value ?? 0);
    widget.tabNotifier?.addListener(_onTabNotify);
    _loadData();
    _refreshApiStatus();
    _connectFeedSocket();
    _fcmSub = FirebaseMessaging.onMessage.listen((_) {});
    _resetIdleTimer();
  }

  void _onTabNotify() {
    final int tab = _normalizeRootTab(widget.tabNotifier?.value ?? 0);
    if (mounted) {
      setState(() => _selectedTabIndex = tab);
    }
  }

  int _normalizeRootTab(int index) {
    if (index < 0 || index > 4) return 0;
    return index;
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_isIdle) {
      _isIdle = false;
      FirebaseChatService.instance.restoreOnlineStatus();
    }
    _idleTimer = Timer(const Duration(seconds: 60), _onIdleTimeout);
  }

  void _onIdleTimeout() {
    _isIdle = true;
    FirebaseChatService.instance.setAwayStatus();
  }

  void _connectFeedSocket() {
    // Real-time: presence changes trigger feed refresh (someone goes live / offline)
    FirebaseChatService.instance.presenceVersion.addListener(
      _onPresenceChanged,
    );
  }

  void _onPresenceChanged() {
    _refreshFeed();
  }

  // ── Incoming call detection (RTDB-based) ───────────────────────────────────
  void _listenForIncomingCalls() {
    final String? userId = _me?.id;
    if (userId == null) return;

    _incomingCallSub?.cancel();
    final svc = FirebaseChatService.instance;

    _incomingCallSub = svc.listenCallSignal(userId, (
      Map<String, dynamic>? data,
    ) {
      if (!mounted) return;
      if (data == null) {
        // Node deleted — call cancelled or cleaned up
        if (_incomingCallerId != null) {
          setState(() {
            _incomingCallerId = null;
            _incomingSessionId = null;
            _incomingCallerName = null;
            _incomingCallerAvatarUrl = null;
          });
        }
        return;
      }
      final event = data['event'] as String?;
      if (event == 'matched') {
        _showRandomCallInvite(data);
        return;
      }
      if (event == 'partner_left') {
        svc.removeCallSignal(userId).ignore();
        return;
      }

      final status = data['status'] as String?;
      final callerId = data['callerId'] as String?;
      final sessionId = data['sessionId'] as String?;

      if (status == 'ringing' && callerId != null && sessionId != null) {
        setState(() {
          _incomingCallerId = callerId;
          _incomingSessionId = sessionId;
          _incomingCallerName = data['callerName'] as String?;
          _incomingCallerAvatarUrl = data['callerAvatarUrl'] as String?;
        });
      } else if (status == 'cancelled' || status == 'declined') {
        setState(() {
          _incomingCallerId = null;
          _incomingSessionId = null;
          _incomingCallerName = null;
          _incomingCallerAvatarUrl = null;
        });
      }
    });
  }

  String? _stringFromInvite(Map<String, dynamic> invite, String key) {
    final value = invite[key];
    if (value is String && value.trim().isNotEmpty) return value;
    return null;
  }

  int _intFromInvite(
    Map<String, dynamic> invite,
    String key, {
    required int fallback,
  }) {
    final value = invite[key];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  bool _hasUsableRandomInvite(Map<String, dynamic> invite) {
    return _stringFromInvite(invite, 'sessionId') != null &&
        _stringFromInvite(invite, 'appId') != null &&
        _stringFromInvite(invite, 'channelName') != null &&
        _stringFromInvite(invite, 'token') != null &&
        _stringFromInvite(invite, 'partnerId') != null &&
        invite['uid'] is num;
  }

  void _showRandomCallInvite(Map<String, dynamic> invite) {
    if (!_hasUsableRandomInvite(invite)) {
      _endRandomInvite(invite);
      return;
    }

    if (_incomingCallerId != null || _acceptingRandomCallInvite) {
      _endRandomInvite(invite);
      return;
    }

    final currentSessionId = _randomCallInvite?['sessionId'] as String?;
    final nextSessionId = invite['sessionId'] as String?;
    if (currentSessionId == nextSessionId) return;

    _randomCallInviteTimer?.cancel();
    setState(() {
      _randomCallInvite = Map<String, dynamic>.from(invite);
      _acceptingRandomCallInvite = false;
    });

    final int expiresAt = _intFromInvite(
      invite,
      'expiresAt',
      fallback: DateTime.now().millisecondsSinceEpoch + 30000,
    );
    int timeoutMs = expiresAt - DateTime.now().millisecondsSinceEpoch;
    if (timeoutMs < 1000 || timeoutMs > 30000) {
      timeoutMs = 30000;
    }

    _randomCallInviteTimer = Timer(
      Duration(milliseconds: timeoutMs),
      () => _declineRandomCallInvite().ignore(),
    );
  }

  void _clearRandomCallInvite() {
    _randomCallInviteTimer?.cancel();
    _randomCallInviteTimer = null;
    if (!mounted) return;
    setState(() {
      _randomCallInvite = null;
      _acceptingRandomCallInvite = false;
    });
  }

  void _endRandomInvite(Map<String, dynamic> invite) {
    final String? sessionId = _stringFromInvite(invite, 'sessionId');
    final String? partnerId = _stringFromInvite(invite, 'partnerId');
    final String? userId = _me?.id;
    if (sessionId != null && partnerId != null) {
      widget.apiClient
          .endRandomCall(
            widget.accessToken,
            sessionId: sessionId,
            partnerId: partnerId,
          )
          .ignore();
    }
    if (userId != null) {
      FirebaseChatService.instance.removeCallSignal(userId).ignore();
    }
  }

  Future<void> _acceptRandomCallInvite() async {
    final Map<String, dynamic>? invite = _randomCallInvite;
    final String? userId = _me?.id;
    if (invite == null || userId == null) return;

    final String? sessionId = _stringFromInvite(invite, 'sessionId');
    final String? appId = _stringFromInvite(invite, 'appId');
    final String? channelName = _stringFromInvite(invite, 'channelName');
    final String? token = _stringFromInvite(invite, 'token');
    final String? partnerId = _stringFromInvite(invite, 'partnerId');
    final int uid = _intFromInvite(invite, 'uid', fallback: -1);
    if (sessionId == null ||
        appId == null ||
        channelName == null ||
        token == null ||
        partnerId == null ||
        uid < 0) {
      _endRandomInvite(invite);
      _clearRandomCallInvite();
      return;
    }

    setState(() => _acceptingRandomCallInvite = true);
    _randomCallInviteTimer?.cancel();
    _incomingCallSub?.cancel();
    FirebaseChatService.instance.removeCallSignal(userId).ignore();

    try {
      final result = await Navigator.of(context).push<Map<String, String>>(
        MaterialPageRoute<Map<String, String>>(
          fullscreenDialog: true,
          builder: (_) => DirectCallScreen(
            apiClient: widget.apiClient,
            accessToken: widget.accessToken,
            sessionId: sessionId,
            appId: appId,
            channelName: channelName,
            uid: uid,
            token: token,
            partnerId: partnerId,
            partnerName:
                _stringFromInvite(invite, 'partnerName') ??
                _stringFromInvite(invite, 'callerName') ??
                'User',
            partnerAvatarUrl: _stringFromInvite(invite, 'callerAvatarUrl'),
            mode: 'random',
            allowRandomNext: false,
            myUserId: _me?.id,
            myDisplayName: _me?.displayName,
            myAvatarUrl: _me?.avatarUrl,
          ),
        ),
      );

      if (!mounted) return;
      if (result?['action'] == 'partner_left') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Random call ended'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _endRandomInvite(invite);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not join random call'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _clearRandomCallInvite();
      if (mounted) _listenForIncomingCalls();
    }
  }

  Future<void> _declineRandomCallInvite() async {
    final Map<String, dynamic>? invite = _randomCallInvite;
    if (invite == null) return;
    _endRandomInvite(invite);
    _clearRandomCallInvite();
  }

  void _acceptIncomingCall() async {
    final String? userId = _me?.id;
    final String? sessionId = _incomingSessionId;
    final String? callerId = _incomingCallerId;
    if (userId == null || sessionId == null || callerId == null) return;

    // Capture partner info BEFORE clearing state
    final String partnerName = _incomingCallerName ?? 'User';
    final String? partnerAvatarUrl = _incomingCallerAvatarUrl;

    final svc = FirebaseChatService.instance;

    // Update RTDB status to 'accepted' so caller knows
    await svc.writeCallStatus(userId, 'accepted');

    // Get Agora token from server
    try {
      final rtc = await widget.apiClient.requestCallRtcToken(
        accessToken: widget.accessToken,
        sessionId: sessionId,
      );

      if (!mounted) return;
      setState(() {
        _incomingCallerId = null;
        _incomingSessionId = null;
        _incomingCallerName = null;
        _incomingCallerAvatarUrl = null;
      });

      // Pause the RTDB listener while in call
      _incomingCallSub?.cancel();

      Navigator.of(context)
          .push(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => DirectCallScreen(
                apiClient: widget.apiClient,
                accessToken: widget.accessToken,
                sessionId: sessionId,
                appId: rtc.appId,
                channelName: rtc.channelName,
                uid: rtc.uid,
                token: rtc.token,
                partnerId: callerId,
                partnerName: partnerName,
                partnerAvatarUrl: partnerAvatarUrl,
                myUserId: _me?.id,
                myDisplayName: _me?.displayName,
                myAvatarUrl: _me?.avatarUrl,
              ),
            ),
          )
          .then((_) {
            // Clean up the RTDB node and resume listening
            svc.removeCallSignal(userId);
            _listenForIncomingCalls();
          });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _incomingCallerId = null;
        _incomingSessionId = null;
        _incomingCallerName = null;
        _incomingCallerAvatarUrl = null;
      });
    }
  }

  void _rejectIncomingCall() {
    final String? userId = _me?.id;
    if (userId == null) return;

    final svc = FirebaseChatService.instance;

    // Update RTDB status so caller gets notified
    svc.writeCallStatus(userId, 'declined');

    // Then remove the node after a short delay so caller can read it
    Future<void>.delayed(const Duration(seconds: 2), () {
      svc.removeCallSignal(userId);
    });

    setState(() {
      _incomingCallerId = null;
      _incomingSessionId = null;
      _incomingCallerName = null;
      _incomingCallerAvatarUrl = null;
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _convoDeliverySub?.cancel();
    _inboxBadgeSub?.cancel();
    _fcmSub?.cancel();
    widget.tabNotifier?.removeListener(_onTabNotify);
    FirebaseChatService.instance.presenceVersion.removeListener(
      _onPresenceChanged,
    );
    _incomingCallSub?.cancel();
    _randomCallInviteTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      FirebaseChatService.instance.restoreOnlineStatus();
      _resetIdleTimer();
      _listenForIncomingCalls();
      _refreshFeed();
    } else if (state == AppLifecycleState.paused) {
      _idleTimer?.cancel();
      _declineRandomCallInvite().ignore();
      FirebaseChatService.instance.setBackgroundOffline();
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
        widget.apiClient.listLiveFeed(
          widget.accessToken,
          limit: _forYouPageSize,
          liveOnly: true,
        ),
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
        final incoming = <LiveFeedCard>[
          ...feedCards.where(
            (LiveFeedCard c) => _isVisibleHostCard(c, me.id) && _isLiveCard(c),
          ),
        ];
        _rankFeed(incoming);
        _feedOffset = feedCards.length;
        _hasMoreFeedCards = feedCards.length == _forYouPageSize;
        _loadingMoreFeedCards = false;
      });
      _refreshWallet().ignore();
      // Start listening for incoming calls now that we have userId
      _listenForIncomingCalls();
      // Initialize Firebase with custom token for secure auth BEFORE warming presence
      await _initFirebaseChat(me);
      // Warm Firebase RTDB presence and profiles AFTER auth is ready
      final hostIds = _feedCards.map((c) => c.hostUserId).toList();
      FirebaseChatService.instance.warmPresence(hostIds);
      FirebaseChatService.instance.warmProfiles(hostIds);
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

  Future<void> _refreshWallet() async {
    try {
      final WalletSummary wallet = await widget.apiClient.getWalletSummary(
        widget.accessToken,
      );
      if (!mounted) return;
      setState(() => _wallet = wallet);
    } catch (_) {
      // Wallet is an accessory in the root header; do not block app navigation.
    }
  }

  Future<void> _openBalanceFromHeader() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BalancePage(
          apiClient: widget.apiClient,
          accessToken: widget.accessToken,
        ),
      ),
    );
    if (mounted) await _refreshWallet();
  }

  Future<void> _openMeFromHeader() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(AppLocalizations.of(context)!.me)),
          body: MeTab(
            me: _me,
            apiClient: widget.apiClient,
            accessToken: widget.accessToken,
            onLogout: widget.onLogout,
            onDeleteAccount: widget.onDeleteAccount,
            locale: widget.locale,
            onLocaleChanged: widget.onLocaleChanged,
            themeMode: widget.themeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
            onProfileUpdated: (profile) {
              if (mounted) setState(() => _me = profile);
            },
          ),
        ),
      ),
    );
    if (mounted) await _refreshWallet();
  }

  Future<void> _initFirebaseChat(UserProfile me) async {
    try {
      final String token = await widget.apiClient.getFirebaseToken(
        widget.accessToken,
      );
      await FirebaseChatService.instance.init(me.id, firebaseToken: token);
    } catch (e) {
      debugPrint('Firebase custom token failed: $e — skipping RTDB init');
      return; // Don't use anonymous — it can't satisfy RTDB rules
    }

    // Write own profile to RTDB so other users always see fresh identity
    FirebaseChatService.instance.writeMyProfile(
      displayName: me.displayName,
      avatarUrl: me.avatarUrl,
      countryCode: me.countryCode ?? '',
      language: me.language ?? '',
      birthday: me.birthday,
    );

    // Wire push notifications for Firebase chat
    FirebaseChatService.instance.onSendPush =
        (recipientId, chatId, messageId) async {
          widget.apiClient
              .sendPushNotification(
                widget.accessToken,
                recipientId,
                chatId,
                messageId,
              )
              .ignore();
        };

    // Global delivery receipts — mark messages delivered as soon as app receives them
    _convoDeliverySub?.cancel();
    _convoDeliverySub = FirebaseChatService.instance
        .watchConversations()
        .listen((convos) {
          for (final c in convos) {
            if (c.unreadCount > 0) {
              FirebaseChatService.instance.markDelivered(c.otherUserId);
            }
          }
        });

    // Bottom tab badge: keep a real-time aggregate unread count.
    _inboxBadgeSub?.cancel();
    _inboxBadgeSub = FirebaseChatService.instance.watchConversations().listen((
      convos,
    ) {
      final int nextTotal = convos.fold<int>(
        0,
        (sum, c) => sum + c.unreadCount,
      );
      debugPrint('[InboxBadge] convos=${convos.length} unread=$nextTotal');
      if (!mounted || nextTotal == _inboxUnreadTotal) return;
      setState(() => _inboxUnreadTotal = nextTotal);
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
      final List<LiveFeedCard> feedCards = await widget.apiClient.listLiveFeed(
        widget.accessToken,
        limit: _forYouPageSize,
        liveOnly: true,
      );
      if (!mounted) return;
      final incoming = <LiveFeedCard>[
        ...feedCards.where(
          (LiveFeedCard c) => _isVisibleHostCard(c, _me?.id) && _isLiveCard(c),
        ),
      ];
      setState(() {
        _rankFeed(incoming);
        _feedOffset = feedCards.length;
        _hasMoreFeedCards = feedCards.length == _forYouPageSize;
        _loadingMoreFeedCards = false;
      });
    } catch (_) {
      // ignore — next poll will retry
    }
  }

  Future<void> _loadMoreFeedCards() async {
    if (_loadingMoreFeedCards || !_hasMoreFeedCards || !mounted) return;

    setState(() => _loadingMoreFeedCards = true);
    try {
      final List<LiveFeedCard> feedCards = await widget.apiClient.listLiveFeed(
        widget.accessToken,
        limit: _forYouPageSize,
        offset: _feedOffset,
        liveOnly: true,
      );
      if (!mounted) return;
      final List<LiveFeedCard> incoming = feedCards
          .where(
            (LiveFeedCard c) =>
                _isVisibleHostCard(c, _me?.id) && _isLiveCard(c),
          )
          .toList();
      setState(() {
        final Map<String, LiveFeedCard> merged = <String, LiveFeedCard>{
          for (final LiveFeedCard card in _feedCards) _feedCardKey(card): card,
          for (final LiveFeedCard card in incoming) _feedCardKey(card): card,
        };
        _rankFeed(merged.values.toList());
        _feedOffset += feedCards.length;
        _hasMoreFeedCards = feedCards.length == _forYouPageSize;
        _loadingMoreFeedCards = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMoreFeedCards = false);
    }
  }

  String _feedCardKey(LiveFeedCard card) {
    return card.roomId?.isNotEmpty == true ? card.roomId! : card.hostUserId;
  }

  /// Ranks host cards so Following can show the most available hosts first.
  void _rankFeed(List<LiveFeedCard> incoming) {
    final now = DateTime.now();

    double score(LiveFeedCard c) {
      final status =
          FirebaseChatService.instance.presenceStateCached(c.hostUserId) ??
          c.hostStatus;

      // Base tier
      double s = switch (status) {
        'live' => 1000,
        'online' => 500,
        'busy' => 250,
        _ => 0,
      };

      // Freshness boost within live tier — fresh hosts drive random-call revenue
      if (status == 'live') {
        final minutes = now.difference(c.startedAt).inMinutes;
        if (minutes < 5) {
          s += 100; // just went live — prime for random call
        } else if (minutes < 15) {
          s += 50;
        } else if (minutes < 30) {
          s += 20;
        }
        // > 30 min: no boost (still live tier, just lower within it)
      }

      // Deterministic jitter so same-score cards don't always appear in same order
      s += (c.hostUserId.hashCode % 10).abs().toDouble();
      return s;
    }

    _feedCards = incoming..sort((a, b) => score(b).compareTo(score(a)));
  }

  bool _isVisibleHostCard(LiveFeedCard card, String? myUserId) {
    if (card.hostUserId == myUserId) return false;
    final String? gender = card.hostGender?.trim().toLowerCase();
    return gender == null || gender.isEmpty || gender == 'female';
  }

  bool _isLiveCard(LiveFeedCard card) {
    final String status = card.hostStatus.trim().toLowerCase();
    return card.roomId?.isNotEmpty == true ||
        status == 'live' ||
        status == 'premium_live';
  }

  Widget _buildInboxNavIcon({required bool selected, required bool isDark}) {
    final Color baseColor = selected
        ? const Color(0xFFFF8F00)
        : (isDark ? const Color(0xFF6B6B6B) : Colors.black54);

    final Widget bubble = Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: Color(0xFFFF3B30),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _inboxUnreadTotal > 99 ? '99+' : '$_inboxUnreadTotal',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Icon(Icons.chat_bubble_rounded, color: baseColor),
        if (_inboxUnreadTotal > 0)
          Positioned(right: -7, top: -6, child: bubble),
      ],
    );
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

  Future<void> _openLiveRoom(LiveFeedCard feedCard) async {
    final String? roomId = feedCard.roomId;
    final UserProfile? me = _me;
    if (roomId == null || roomId.isEmpty || me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This host is not live right now.')),
      );
      return;
    }

    int viewerCount = feedCard.audienceCount;
    if (mounted) setState(() => _joiningRoomId = roomId);
    try {
      final Room room = await widget.apiClient.joinRoom(
        widget.accessToken,
        roomId,
      );
      viewerCount = room.audienceCount;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not enter this live.')),
      );
      await _loadData();
      return;
    } finally {
      if (mounted) setState(() => _joiningRoomId = null);
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ViewerLiveScreen(
          feedCard: feedCard,
          apiClient: widget.apiClient,
          accessToken: widget.accessToken,
          myUserId: me.id,
          myDisplayName: me.displayName,
          onLeave: () => _loadData().ignore(),
          initialViewerCount: viewerCount,
          didJoin: true,
        ),
      ),
    );
    if (mounted) await _loadData();
  }

  Future<void> _openProfilePage(LiveFeedCard feedCard) async {
    await Navigator.of(context).push(
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
            setState(() => _selectedTabIndex = 4);
          },
        ),
      ),
    );
    if (mounted) await _loadData();
  }

  Widget _buildForYouTab() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }
    return ForYouFeed(
      cards: _feedCards,
      isTablet: MediaQuery.sizeOf(context).width >= tabletBreakpoint,
      onCardTap: _openLiveRoom,
      onProfileTap: _openProfilePage,
      onRefresh: _refreshFeed,
      onLoadMore: () => _loadMoreFeedCards().ignore(),
      onRandomMatch: _startRandomMatchFromHome,
      showRandomMatch: _me?.isHost == false,
      hasMore: _hasMoreFeedCards,
      isLoadingMore: _loadingMoreFeedCards,
      joiningRoomId: _joiningRoomId,
    );
  }

  Widget _buildFollowTab(bool isTablet) {
    return FollowFeed(
      cards: _feedCards,
      followingIds: _followingIds,
      filterCountryName: null,
      isTablet: isTablet,
      onCardTap: _openLiveRoom,
      onProfileTap: _openProfilePage,
      onRandomMatch: _startRandomMatchFromHome,
      showRandomMatch: _me?.isHost == false,
      joiningRoomId: _joiningRoomId,
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
                        colors: <Color>[
                          Color(0xFFFFF176),
                          Color(0xFFFF8F00),
                          Color(0xFFE53935),
                        ],
                        stops: <double>[0.0, 0.5, 1.0],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(
                            0xFFFF8F00,
                          ).withValues(alpha: 0.55),
                          blurRadius: 32,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.live_tv_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
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
                onTap: _creating
                    ? null
                    : () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            fullscreenDialog: true,
                            builder: (_) => GoLiveCountdownPage(
                              displayName: _me?.displayName ?? 'Me',
                              avatarUrl: _me?.avatarUrl,
                              apiClient: widget.apiClient,
                              accessToken: widget.accessToken,
                              onEnd: () => _loadData(),
                              onCancel: () {},
                            ),
                          ),
                        );
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
                      const Icon(
                        Icons.live_tv_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _creating
                            ? AppLocalizations.of(context)!.starting
                            : AppLocalizations.of(context)!.startLiveStream,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
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
    );
  }

  PreferredSizeWidget _buildRootAppBar(BuildContext context, bool isDark) {
    final Color surfaceColor = _selectedTabIndex == 2
        ? (isDark
              ? const Color(0xFF0D0A08)
              : Theme.of(context).colorScheme.surface)
        : (isDark
              ? const Color(0xFF151018)
              : Theme.of(context).colorScheme.surface);

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 58,
      titleSpacing: 16,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: surfaceColor,
      foregroundColor: isDark ? Colors.white : Colors.black87,
      title: ZephyrAppHeader(
        me: _me,
        wallet: _wallet,
        apiReachable: _apiReachable,
        onAvatarTap: _openMeFromHeader,
        onRechargeTap: _me?.isHost == true ? null : _openBalanceFromHeader,
      ),
      actions: const <Widget>[SizedBox(width: 12)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.sizeOf(context).width >= tabletBreakpoint;
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final Widget bodyContent = _loading
        ? const Center(child: CircularProgressIndicator())
        : switch (_selectedTabIndex) {
            0 => _buildForYouTab(),
            1 => _buildFollowTab(isTablet),
            2 => _buildLiveRoomsTab(isTablet),
            3 => ExplorePage(
              apiClient: widget.apiClient,
              accessToken: widget.accessToken,
              myUserId: _me?.id ?? '',
              myDisplayName: _me?.displayName ?? 'User',
              myAvatarUrl: _me?.avatarUrl,
            ),
            4 => InboxFirebasePage(
              myUserId: _me?.id ?? '',
              myDisplayName: _me?.displayName ?? 'User',
              myAvatarUrl: _me?.avatarUrl,
            ),
            _ => const SizedBox.shrink(),
          };

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Map<String, dynamic>? randomInvite = _randomCallInvite;

    return Listener(
      onPointerDown: (_) => _resetIdleTimer(),
      child: PopScope(
        canPop: false,
        child: Stack(
          children: <Widget>[
            Scaffold(
              backgroundColor: _selectedTabIndex == 2
                  ? (isDark ? const Color(0xFF0D0A08) : null)
                  : null,
              appBar: _buildRootAppBar(context, isDark),
              body: bodyContent,
              bottomNavigationBar: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Color(0xFF2A2A2A),
                  ),
                  NavigationBar(
                    selectedIndex: _normalizeRootTab(_selectedTabIndex),
                    backgroundColor: isDark ? const Color(0xFF111111) : null,
                    indicatorColor: const Color(
                      0xFFFF8F00,
                    ).withValues(alpha: 0.18),
                    labelTextStyle: WidgetStateProperty.resolveWith((states) {
                      final bool selected = states.contains(
                        WidgetState.selected,
                      );
                      return TextStyle(
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected ? const Color(0xFFFF8F00) : null,
                      );
                    }),
                    onDestinationSelected: (int index) {
                      setState(
                        () => _selectedTabIndex = _normalizeRootTab(index),
                      );
                    },
                    destinations: <NavigationDestination>[
                      NavigationDestination(
                        icon: Icon(
                          Icons.auto_awesome_rounded,
                          color: isDark ? const Color(0xFF6B6B6B) : null,
                        ),
                        selectedIcon: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFFFF8F00),
                        ),
                        label: l10n.forYou,
                      ),
                      NavigationDestination(
                        icon: Icon(
                          Icons.favorite_border_rounded,
                          color: isDark ? const Color(0xFF6B6B6B) : null,
                        ),
                        selectedIcon: const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFFF8F00),
                        ),
                        label: l10n.followingButton,
                      ),
                      NavigationDestination(
                        icon: Icon(
                          Icons.live_tv_rounded,
                          color: isDark ? const Color(0xFF6B6B6B) : null,
                        ),
                        selectedIcon: const Icon(
                          Icons.live_tv_rounded,
                          color: Color(0xFFFF8F00),
                        ),
                        label: l10n.live,
                      ),
                      NavigationDestination(
                        icon: Icon(
                          Icons.explore_rounded,
                          color: isDark ? const Color(0xFF6B6B6B) : null,
                        ),
                        selectedIcon: const Icon(
                          Icons.explore_rounded,
                          color: Color(0xFFFF8F00),
                        ),
                        label: l10n.explore,
                      ),
                      NavigationDestination(
                        icon: _buildInboxNavIcon(
                          selected: false,
                          isDark: isDark,
                        ),
                        selectedIcon: _buildInboxNavIcon(
                          selected: true,
                          isDark: isDark,
                        ),
                        label: l10n.inbox,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (randomInvite != null && _incomingCallerId == null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 12,
                right: 12,
                child: RandomCallInviteRibbon(
                  partnerName:
                      _stringFromInvite(randomInvite, 'partnerName') ??
                      _stringFromInvite(randomInvite, 'callerName') ??
                      'User',
                  rateCoinsPerMinute: _intFromInvite(
                    randomInvite,
                    'rateCoinsPerMinute',
                    fallback: 600,
                  ),
                  hostEarningCoinsPerMinute: _intFromInvite(
                    randomInvite,
                    'hostEarningCoinsPerMinute',
                    fallback: 360,
                  ),
                  accepting: _acceptingRandomCallInvite,
                  onAccept: _acceptRandomCallInvite,
                  onDecline: () => _declineRandomCallInvite().ignore(),
                ),
              ),
            // Incoming call overlay
            if (_incomingCallerId != null)
              Positioned.fill(
                child: IncomingCallOverlay(
                  callerId: _incomingCallerId!,
                  callerName: _incomingCallerName,
                  onAccept: _acceptIncomingCall,
                  onReject: _rejectIncomingCall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
