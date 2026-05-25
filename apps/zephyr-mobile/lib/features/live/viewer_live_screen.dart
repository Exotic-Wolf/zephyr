import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../widgets/shared_live_widgets.dart';
import '../../app_constants.dart';
import '../../l10n/app_localizations.dart';

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
    this.initialViewerCount,
    this.didJoin = false,
    this.existingEngine,
    this.existingHostUid,
    this.existingChannelName,
  });

  final LiveFeedCard feedCard;
  final ZephyrApiClient apiClient;
  final String accessToken;
  final String myUserId;
  final String myDisplayName;
  final VoidCallback onLeave;
  final int? initialViewerCount;
  /// True when the caller already successfully called joinRoom before pushing this screen.
  final bool didJoin;

  /// Pre-connected Agora engine handed off from a preview widget.
  final RtcEngine? existingEngine;
  final int? existingHostUid;
  final String? existingChannelName;

  @override
  State<ViewerLiveScreen> createState() => _ViewerLiveScreenState();
}

class _ViewerLiveScreenState extends State<ViewerLiveScreen>
    with TickerProviderStateMixin {
  int _viewerCount = 0;
  final List<LiveComment> _comments = <LiveComment>[];
  final List<FloatingGift> _floatingGifts = <FloatingGift>[];
  final TextEditingController _commentCtrl = TextEditingController();
  late final AnimationController _pulseCtrl;
  int _elapsedSeconds = 0;
  Timer? _ticker;
  sio.Socket? _socket;

  // Agora
  RtcEngine? _engine;
  int? _hostUid;
  String? _channelName;
  bool _engineReady = false;
  bool _welcomeAdded = false;
  bool _liveEnded = false;

  @override
  void initState() {
    super.initState();
    _viewerCount = widget.initialViewerCount ?? widget.feedCard.audienceCount;
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _connectSocket();
    if (widget.existingEngine != null) {
      _adoptEngine();
    } else {
      _initAgora();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_welcomeAdded) {
      _welcomeAdded = true;
      _comments.add(LiveComment(
        name: widget.feedCard.hostDisplayName,
        text: AppLocalizations.of(context)!.welcomeToLive,
      ));
    }
  }

  /// Adopt a pre-connected engine from the preview widget (instant video).
  void _adoptEngine() {
    final engine = widget.existingEngine!;
    // Re-register handlers so this screen gets updates
    engine.registerEventHandler(RtcEngineEventHandler(
      onUserJoined: (connection, remoteUid, elapsed) {
        if (mounted) setState(() => _hostUid = remoteUid);
      },
      onUserOffline: (connection, remoteUid, reason) {
        if (mounted && !_liveEnded) _onLiveEnded();
      },
    ));
    // Unmute audio (preview was silent)
    engine.muteAllRemoteAudioStreams(false);
    // Switch to high-quality stream
    if (widget.existingHostUid != null) {
      engine.setRemoteVideoStreamType(
        uid: widget.existingHostUid!,
        streamType: VideoStreamType.videoStreamHigh,
      );
    }
    _engine = engine;
    _hostUid = widget.existingHostUid;
    _channelName = widget.existingChannelName;
    _engineReady = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
    setState(() {});
  }

  Future<void> _initAgora() async {
    if (widget.feedCard.roomId == null) return;
    try {
      final info = await widget.apiClient.getRoomRtcToken(
          widget.accessToken, widget.feedCard.roomId!);

      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: info.appId));

      engine.registerEventHandler(RtcEngineEventHandler(
        onUserJoined: (connection, remoteUid, elapsed) {
          if (mounted) setState(() => _hostUid = remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (mounted && !_liveEnded) _onLiveEnded();
        },
      ));

      await engine.setChannelProfile(
          ChannelProfileType.channelProfileLiveBroadcasting);
      await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
      await engine.enableVideo();

      await engine.joinChannel(
        token: info.token,
        channelId: info.channelName,
        uid: info.uid,
        options: const ChannelMediaOptions(
          autoSubscribeVideo: true,
          autoSubscribeAudio: true,
          clientRoleType: ClientRoleType.clientRoleAudience,
        ),
      );

      _engine = engine;
      if (mounted) {
        setState(() {
          _channelName = info.channelName;
          _engineReady = true;
        });
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _elapsedSeconds++);
        });
      }
    } catch (e) {
      debugPrint('[Agora viewer] init error: $e');
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _socket?.dispose();
    _pulseCtrl.dispose();
    _commentCtrl.dispose();
    _engine?.leaveChannel();
    _engine?.release();
    if (widget.didJoin && widget.feedCard.roomId != null) {
      widget.apiClient
          .leaveRoom(widget.accessToken, widget.feedCard.roomId!)
          .ignore();
    }
    super.dispose();
  }

  void _connectSocket() {
    _socket = sio.io(
      '$apiBaseUrl/feed',
      sio.OptionBuilder()
          .setTransports(<String>['websocket', 'polling'])
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(2000)
          .disableAutoConnect()
          .build(),
    );
    _socket!
      ..on('feed:room-updated', (dynamic data) {
        if (!mounted) return;
        try {
          final Map<String, dynamic> payload =
              (data as Map<dynamic, dynamic>).cast<String, dynamic>();
          if (payload['roomId'] == widget.feedCard.roomId) {
            setState(() => _viewerCount = payload['audienceCount'] as int);
          }
        } catch (_) {}
      })
      ..on('feed:room-ended', (dynamic data) {
        if (!mounted || _liveEnded) return;
        try {
          final Map<String, dynamic> payload =
              (data as Map<dynamic, dynamic>).cast<String, dynamic>();
          if (payload['roomId'] == widget.feedCard.roomId) {
            _onLiveEnded();
          }
        } catch (_) {}
      })
      ..connect();
  }

  void _onLiveEnded() {
    setState(() => _liveEnded = true);
    _ticker?.cancel();
    _engine?.leaveChannel();
    _engine?.release();
    _engine = null;
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onLeave();
      }
    });
  }

  void _sendComment() {
    final String text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    _commentCtrl.clear();
    setState(() {
      _comments.add(LiveComment(name: widget.myDisplayName, text: text));
      if (_comments.length > 30) _comments.removeAt(0);
    });
  }

  void _sendReaction(String emoji) {
    final String id = DateTime.now().millisecondsSinceEpoch.toString();
    final FloatingGift gift = FloatingGift(id: id, emoji: emoji);
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
      body: SizedBox.expand(
        child: Stack(
        children: <Widget>[
          // ── Background ───────────────────────────────────────────────────
          if (_engineReady && _engine != null && _hostUid != null)
            Positioned.fill(
              child: AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: _engine!,
                  canvas: VideoCanvas(uid: _hostUid!),
                  connection: RtcConnection(
                    channelId: _channelName ?? '',
                  ),
                ),
              ),
            )
          else
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
              ),
            ),
          ),
          // Host avatar center (shown only when no remote video yet)
          if (!(_engineReady && _hostUid != null))
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CircleAvatar(
                  radius: 64,
                  backgroundColor: Colors.white12,
                  backgroundImage: widget.feedCard.hostAvatarUrl != null
                      ? CachedNetworkImageProvider(widget.feedCard.hostAvatarUrl!)
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
          ..._floatingGifts.map((g) => FloatingGiftWidget(gift: g)),

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
                              ? CachedNetworkImageProvider(widget.feedCard.hostAvatarUrl!)
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
                          Text(AppLocalizations.of(context)!.liveIndicator, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
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
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)!.saySomething,
                          hintStyle: const TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

          // ── Live ended overlay ───────────────────────────────────────────
          if (_liveEnded)
            Positioned.fill(
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white12,
                        backgroundImage: widget.feedCard.hostAvatarUrl != null
                            ? CachedNetworkImageProvider(widget.feedCard.hostAvatarUrl!)
                            : null,
                        child: widget.feedCard.hostAvatarUrl == null
                            ? Text(widget.feedCard.hostDisplayName[0].toUpperCase(),
                                style: const TextStyle(fontSize: 36, color: Colors.white))
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.liveHasEnded,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.feedCard.hostDisplayName,
                        style: const TextStyle(color: Colors.white60, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}

