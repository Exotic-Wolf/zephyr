import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/firebase_chat_service.dart';
import '../../widgets/shared_live_widgets.dart';
import '../../l10n/app_localizations.dart';

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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _micOn = true;
  bool _cameraOn = true;
  bool _ending = false;
  bool _cameraLoading = true;
  int _viewerCount = 0;
  int _elapsedSeconds = 0;
  Timer? _ticker;
  Timer? _heartbeatTimer;
  Timer? _tokenRenewalTimer;
  final List<StreamSubscription<dynamic>> _rtdbSubs =
      <StreamSubscription<dynamic>>[];
  final ValueNotifier<int> _viewerCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<List<LiveComment>> _commentsNotifier =
      ValueNotifier<List<LiveComment>>(<LiveComment>[]);
  final List<FloatingGift> _gifts = <FloatingGift>[];
  late final AnimationController _pulseCtrl;
  bool _reconnecting = false;

  // Agora
  RtcEngine? _engine;
  bool _engineReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _viewerCount = widget.room.audienceCount;
    _viewerCountNotifier.value = widget.room.audienceCount;
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    widget.apiClient.heartbeatRoom(widget.accessToken, widget.room.id).ignore();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => widget.apiClient
          .heartbeatRoom(widget.accessToken, widget.room.id)
          .ignore(),
    );
    _listenFirebase();
    _initAgora();
  }

  Future<void> _initAgora() async {
    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (!camera.isGranted || !mic.isGranted) {
      debugPrint('[Agora host] permissions denied');
      if (mounted) setState(() => _cameraLoading = false);
      return;
    }

    try {
      final info = await widget.apiClient.getRoomRtcToken(
        widget.accessToken,
        widget.room.id,
      );

      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: info.appId));

      await engine.setChannelProfile(
        ChannelProfileType.channelProfileLiveBroadcasting,
      );
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await engine.enableVideo();
      await engine.enableAudio();
      await engine.startPreview();

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onTokenPrivilegeWillExpire: (connection, token) => _renewToken(),
          onConnectionStateChanged: (connection, state, reason) {
            if (!mounted) return;
            final bool lost =
                state == ConnectionStateType.connectionStateReconnecting;
            if (lost != _reconnecting) setState(() => _reconnecting = lost);
          },
        ),
      );

      await engine.joinChannel(
        token: info.token,
        channelId: info.channelName,
        uid: info.uid,
        options: const ChannelMediaOptions(
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );

      _engine = engine;
      if (mounted) {
        setState(() {
          _engineReady = true;
          _cameraLoading = false;
        });
        FirebaseChatService.instance.setLiveStatus(roomId: widget.room.id);
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _elapsedSeconds++);
        });
        // Renew token at 50 minutes (token expires at 60 min)
        final int renewInSeconds = (info.expiresInSeconds - 600).clamp(
          60,
          info.expiresInSeconds,
        );
        _tokenRenewalTimer = Timer(
          Duration(seconds: renewInSeconds),
          _renewToken,
        );
      }
    } catch (e) {
      debugPrint('[Agora host] init error: $e');
      if (mounted) setState(() => _cameraLoading = false);
    }
  }

  Future<void> _renewToken() async {
    try {
      final info = await widget.apiClient.getRoomRtcToken(
        widget.accessToken,
        widget.room.id,
      );
      await _engine?.renewToken(info.token);
      // Schedule next renewal
      final int renewInSeconds = (info.expiresInSeconds - 600).clamp(
        60,
        info.expiresInSeconds,
      );
      _tokenRenewalTimer = Timer(
        Duration(seconds: renewInSeconds),
        _renewToken,
      );
    } catch (e) {
      debugPrint('[Agora host] token renewal error: $e');
    }
  }

  void _listenFirebase() {
    final String roomId = widget.room.id;
    final fcs = FirebaseChatService.instance;

    // Initialize the live room node in RTDB
    unawaited(fcs.initLiveRoom(roomId, hostUserId: widget.room.hostUserId));

    // Audience count
    _rtdbSubs.add(
      fcs.listenAudienceCount(roomId, (int count) {
        if (!mounted) return;
        setState(() => _viewerCount = count);
        _viewerCountNotifier.value = count;
      }),
    );

    // Comments
    _rtdbSubs.add(
      fcs.listenLiveComments(roomId, (String name, String text) {
        if (!mounted) return;
        _addComment(LiveComment(name: name, text: text));
      }),
    );

    // Reactions
    _rtdbSubs.add(
      fcs.listenLiveReactions(roomId, '', (String emoji) {
        if (!mounted) return;
        final String id = DateTime.now().millisecondsSinceEpoch.toString();
        final FloatingGift gift = FloatingGift(id: id, emoji: emoji);
        setState(() => _gifts.add(gift));
        Future<void>.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _gifts.removeWhere((g) => g.id == id));
        });
      }),
    );

    // Gifts
    _rtdbSubs.add(
      fcs.listenLiveGifts(roomId, (
        String senderName,
        String giftName,
        int quantity,
      ) {
        if (!mounted) return;
        _addComment(LiveComment(name: senderName, text: '🎁 sent $giftName'));
      }),
    );
  }

  void _addComment(LiveComment comment) {
    final list = List<LiveComment>.from(_commentsNotifier.value)..add(comment);
    if (list.length > 50) list.removeAt(0);
    _commentsNotifier.value = list;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_ending) {
      // End live immediately — timers don't fire reliably in background
      _forceEnd();
    }
  }

  Future<void> _forceEnd() async {
    _ending = true;
    // Release engine immediately so Agora fires onUserOffline on viewers fast
    _engine?.leaveChannel();
    _engine?.release();
    _engine = null;
    FirebaseChatService.instance.clearLiveStatus();
    try {
      await widget.apiClient.endRoom(widget.accessToken, widget.room.id);
    } catch (e) {
      debugPrint('[endRoom background] error: $e');
    }
    if (mounted) Navigator.of(context).pop();
    widget.onEnd();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _ticker?.cancel();
    _heartbeatTimer?.cancel();
    _tokenRenewalTimer?.cancel();
    for (final sub in _rtdbSubs) {
      sub.cancel();
    }
    _viewerCountNotifier.dispose();
    _commentsNotifier.dispose();
    _pulseCtrl.dispose();
    _engine?.leaveChannel();
    _engine?.release();
    FirebaseChatService.instance.endLiveRoom(widget.room.id);
    FirebaseChatService.instance.clearLiveStatus();
    // Only call endRoom if not already ended by _end() or _forceEnd()
    if (!_ending) {
      widget.apiClient
          .endRoom(widget.accessToken, widget.room.id)
          .then((_) => debugPrint('[endRoom dispose] success'))
          .catchError((Object e) {
            debugPrint('[endRoom dispose] error: $e');
          });
    }
    super.dispose();
  }

  String get _elapsed {
    final int m = _elapsedSeconds ~/ 60;
    final int s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _showViewerList() async {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return _ViewerListSheet(
          apiClient: widget.apiClient,
          accessToken: widget.accessToken,
          roomId: widget.room.id,
          viewerCountNotifier: _viewerCountNotifier,
        );
      },
    );
  }

  Future<void> _end() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocalizations.of(context)!.endLive),
        content: Text(AppLocalizations.of(context)!.streamWillEndMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.of(context)!.endLiveButton,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _ending = true);
    try {
      await widget.apiClient.endRoom(widget.accessToken, widget.room.id);
    } catch (e) {
      debugPrint('[endRoom] error: $e');
    }
    if (mounted) Navigator.of(context).pop();
    widget.onEnd();
  }

  void _flipCamera() {
    _engine?.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Stack(
          children: <Widget>[
            // ── Background (live camera preview or placeholder) ───────────────
            if (_engineReady && _engine != null)
              Positioned.fill(
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0xFF1a1a2e),
                      Color(0xFF16213e),
                      Color(0xFF0f3460),
                    ],
                  ),
                ),
              ),
            // Camera loading spinner
            if (_cameraLoading)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.startingCamera,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            // Camera-off overlay
            if (!_cameraOn)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.75),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(
                        Icons.videocam_off_rounded,
                        color: Colors.white54,
                        size: 56,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context)!.cameraIsOff,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Floating gift animations ────────────────────────────────────────
            ..._gifts.map((g) => FloatingGiftWidget(gift: g)),

            // ── Reconnecting overlay ────────────────────────────────────────
            if (_reconnecting)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Reconnecting...',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Top bar ────────────────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
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
                                ? CachedNetworkImageProvider(
                                    widget.hostAvatarUrl!,
                                  )
                                : null,
                            child: widget.hostAvatarUrl == null
                                ? Text(
                                    widget.hostDisplayName[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.hostDisplayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            Colors.red,
                            Colors.red.shade300,
                            _pulseCtrl.value,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context)!.liveIndicator,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showViewerList,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.remove_red_eye_rounded,
                              color: Colors.white70,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$_viewerCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _elapsed,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _ending ? null : _end,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: _ending
                            ? const Padding(
                                padding: EdgeInsets.all(6),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Comments feed ──────────────────────────────────────────────────
            Positioned(
              left: 12,
              right: 120,
              bottom: 110,
              child: ValueListenableBuilder<List<LiveComment>>(
                valueListenable: _commentsNotifier,
                builder: (_, comments, __) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: comments.reversed
                      .take(6)
                      .toList()
                      .reversed
                      .map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: RichText(
                              text: TextSpan(
                                children: <TextSpan>[
                                  TextSpan(
                                    text: '${c.name}  ',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextSpan(
                                    text: c.text,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),

            // ── Bottom controls ────────────────────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Colors.transparent, Colors.black87],
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery.of(context).padding.bottom + 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    LiveCtrlBtn(
                      icon: _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                      label: _micOn
                          ? AppLocalizations.of(context)!.micOn
                          : AppLocalizations.of(context)!.micOff,
                      active: _micOn,
                      onTap: () {
                        setState(() => _micOn = !_micOn);
                        _engine?.muteLocalAudioStream(!_micOn);
                      },
                    ),
                    LiveCtrlBtn(
                      icon: _cameraOn
                          ? Icons.videocam_rounded
                          : Icons.videocam_off_rounded,
                      label: _cameraOn
                          ? AppLocalizations.of(context)!.camera
                          : AppLocalizations.of(context)!.off,
                      active: _cameraOn,
                      onTap: () {
                        setState(() => _cameraOn = !_cameraOn);
                        _engine?.muteLocalVideoStream(!_cameraOn);
                      },
                    ),
                    LiveCtrlBtn(
                      icon: Icons.flip_camera_ios_rounded,
                      label: AppLocalizations.of(context)!.flip,
                      active: true,
                      onTap: _flipCamera,
                    ),
                    GestureDetector(
                      onTap: _ending ? null : _end,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.endLive,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
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
}

// ── Viewer list bottom sheet ──────────────────────────────────────────────────

class _ViewerListSheet extends StatefulWidget {
  const _ViewerListSheet({
    required this.apiClient,
    required this.accessToken,
    required this.roomId,
    required this.viewerCountNotifier,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final String roomId;
  final ValueNotifier<int> viewerCountNotifier;

  @override
  State<_ViewerListSheet> createState() => _ViewerListSheetState();
}

class _ViewerListSheetState extends State<_ViewerListSheet> {
  bool _loading = true;
  List<dynamic> _viewers = <dynamic>[];
  int _total = 0;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _total = widget.viewerCountNotifier.value;
    widget.viewerCountNotifier.addListener(_onCountChanged);
    _load();
  }

  @override
  void dispose() {
    widget.viewerCountNotifier.removeListener(_onCountChanged);
    super.dispose();
  }

  void _onCountChanged() {
    _load();
  }

  Future<void> _load() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final result = await widget.apiClient.getRoomViewers(
        widget.accessToken,
        widget.roomId,
      );
      if (mounted) {
        setState(() {
          _viewers = result.viewers;
          _total = result.total;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[ViewerList] load error: $e');
      if (mounted) setState(() => _loading = false);
    } finally {
      _fetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.remove_red_eye_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.totalWatching(_total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(
                color: Colors.white54,
                strokeWidth: 2,
              ),
            )
          else if (_viewers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                AppLocalizations.of(context)!.noViewersYet,
                style: const TextStyle(color: Colors.white54),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _viewers.length,
                itemBuilder: (BuildContext ctx, int i) {
                  final viewer = _viewers[i];
                  final String name = viewer.displayName as String;
                  final String? avatar = viewer.avatarUrl as String?;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white12,
                      backgroundImage: avatar != null
                          ? CachedNetworkImageProvider(avatar)
                          : null,
                      child: avatar == null
                          ? Text(
                              name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  );
                },
              ),
            ),
          if (_total > 50)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Text(
                AppLocalizations.of(
                  context,
                )!.andMoreWatching(_total - _viewers.length),
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}
