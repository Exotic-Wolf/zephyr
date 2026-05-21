import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../app_constants.dart';
import '../services/api_client.dart';

// How often the client reports elapsed seconds for billing
const int _tickIntervalSeconds = 15;

enum _Phase { searching, connected, transitioning }

class RandomCallScreen extends StatefulWidget {
  const RandomCallScreen({
    super.key,
    required this.apiClient,
    required this.accessToken,
    required this.userId,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final String userId;

  @override
  State<RandomCallScreen> createState() => _RandomCallScreenState();
}

class _RandomCallScreenState extends State<RandomCallScreen>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.searching;

  // Matchmaking socket
  sio.Socket? _socket;

  // Current call state
  String? _sessionId;
  // ignore: unused_field
  String? _partnerId;
  String _channelName = '';
  int _elapsedSeconds = 0;
  Timer? _tickTimer;
  Timer? _elapsedTimer;

  // Agora
  RtcEngine? _engine;
  int? _remoteUid;
  bool _micMuted = false;
  bool _cameraOff = false;

  // Search dot animation
  late final AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _requestPermissionsAndConnect();
  }

  Future<void> _requestPermissionsAndConnect() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    _connectSocket();
  }

  // ── Socket ──────────────────────────────────────────────────────────────────

  void _connectSocket() {
    _socket = sio.io(
      '$apiBaseUrl/call',
      sio.OptionBuilder()
          .setTransports(<String>['websocket', 'polling'])
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(2000)
          .setQuery(<String, dynamic>{'userId': widget.userId})
          .disableAutoConnect()
          .build(),
    );

    _socket!
      ..on('connect', (_) => _joinQueue())
      ..on('call:matched', (dynamic data) {
        final Map<String, dynamic> payload =
            (data as Map<dynamic, dynamic>).cast<String, dynamic>();
        _onMatched(payload);
      })
      ..on('call:partner_left', (_) => _onPartnerLeft())
      ..connect();
  }

  void _joinQueue() {
    _socket?.emit('call:join_queue', <String, dynamic>{'userId': widget.userId});
  }

  void _onMatched(Map<String, dynamic> payload) async {
    if (!mounted) return;

    final String sessionId = payload['sessionId'] as String;
    final String appId = payload['appId'] as String;
    final String channelName = payload['channelName'] as String;
    final int uid = payload['uid'] as int;
    final String token = payload['token'] as String;
    final String partnerId = payload['partnerId'] as String;

    setState(() {
      _sessionId = sessionId;
      _partnerId = partnerId;
      _channelName = channelName;
      _phase = _Phase.connected;
      _elapsedSeconds = 0;
    });

    // Start billing ticker
    _elapsedTimer = Timer.periodic(
        const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
    _tickTimer = Timer.periodic(
        const Duration(seconds: _tickIntervalSeconds), (_) => _runTick());

    // Init Agora
    await _initAgora(appId: appId, channelName: channelName, uid: uid, token: token);
  }

  void _onPartnerLeft() {
    if (!mounted || _phase != _Phase.connected) return;
    // Partner pressed Next or disconnected → show searching again
    _cleanupCall();
    if (mounted) {
      setState(() => _phase = _Phase.searching);
      _joinQueue();
    }
  }

  // ── Agora ───────────────────────────────────────────────────────────────────

  Future<void> _initAgora({
    required String appId,
    required String channelName,
    required int uid,
    required String token,
  }) async {
    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: appId));

      engine.registerEventHandler(RtcEngineEventHandler(
        onUserJoined: (connection, remoteUid, elapsed) {
          if (mounted) setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (mounted) setState(() => _remoteUid = null);
        },
      ));

      await engine.setChannelProfile(
          ChannelProfileType.channelProfileCommunication);
      await engine.enableVideo();
      await engine.enableAudio();
      await engine.startPreview();

      await engine.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );

      _engine = engine;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[Agora random call] init error: $e');
    }
  }

  // ── Billing ─────────────────────────────────────────────────────────────────

  void _runTick() {
    final sid = _sessionId;
    if (sid == null) return;
    widget.apiClient.tickCallSession(
      accessToken: widget.accessToken,
      sessionId: sid,
      elapsedSeconds: _tickIntervalSeconds,
    ).ignore();
  }

  // ── Controls ─────────────────────────────────────────────────────────────────

  void _next() {
    if (_phase != _Phase.connected) return;

    // Stop billing immediately
    _elapsedTimer?.cancel();
    _tickTimer?.cancel();
    _elapsedTimer = null;
    _tickTimer = null;

    final sid = _sessionId;
    // Notify server — will also trigger partner_left on their end
    _socket?.emit('call:next', <String, dynamic>{
      'userId': widget.userId,
      'sessionId': sid ?? '',
    });

    // Cleanup Agora but keep engine alive for next call
    _engine?.leaveChannel();
    _engine?.release();
    _engine = null;

    setState(() {
      _phase = _Phase.transitioning;
      _sessionId = null;
      _partnerId = null;
      _remoteUid = null;
      _elapsedSeconds = 0;
    });

    // Small delay to show transition, then re-search
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _phase = _Phase.searching);
      _joinQueue();
    });
  }

  void _end() {
    final sid = _sessionId;
    _socket?.emit('call:end', <String, dynamic>{
      'userId': widget.userId,
      'sessionId': sid ?? '',
    });
    _cleanupCall();
    if (mounted) Navigator.of(context).pop();
  }

  void _cancelSearch() {
    _socket?.emit('call:leave_queue', <String, dynamic>{'userId': widget.userId});
    if (mounted) Navigator.of(context).pop();
  }

  void _cleanupCall() {
    _elapsedTimer?.cancel();
    _tickTimer?.cancel();
    _elapsedTimer = null;
    _tickTimer = null;
    _engine?.leaveChannel();
    _engine?.release();
    _engine = null;
  }

  // ── UI helpers ───────────────────────────────────────────────────────────────

  String get _elapsed {
    final int m = _elapsedSeconds ~/ 60;
    final int s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    _elapsedTimer?.cancel();
    _tickTimer?.cancel();
    _engine?.leaveChannel();
    _engine?.release();
    _socket?.emit('call:leave_queue', <String, dynamic>{'userId': widget.userId});
    _socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: switch (_phase) {
        _Phase.searching => _buildSearching(),
        _Phase.connected => _buildInCall(),
        _Phase.transitioning => _buildTransitioning(),
      },
    );
  }

  // ── Searching screen ──────────────────────────────────────────────────────────

  Widget _buildSearching() {
    return SafeArea(
      child: Column(
        children: <Widget>[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: _cancelSearch,
            ),
          ),
          const Spacer(),
          // Pulsing ring animation
          AnimatedBuilder(
            animation: _dotCtrl,
            builder: (_, __) {
              final double scale = 1.0 + _dotCtrl.value * 0.15;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: const Color(0xFF1FA4EA).withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.videocam_rounded, color: Color(0xFF1FA4EA), size: 48),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          const Text(
            'Finding someone to chat with…',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            '600 coins / min when connected',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _cancelSearch,
                child: const Text('Cancel'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── In-call screen ────────────────────────────────────────────────────────────

  Widget _buildInCall() {
    return Stack(
      children: <Widget>[
        // Remote video (full screen)
        if (_engine != null && _remoteUid != null)
          Positioned.fill(
            child: AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine!,
                canvas: VideoCanvas(uid: _remoteUid!),
                connection: RtcConnection(channelId: _channelName),
              ),
            ),
          )
        else
          Positioned.fill(
            child: Container(
              color: const Color(0xFF111118),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CircularProgressIndicator(color: Color(0xFF1FA4EA), strokeWidth: 2),
                    SizedBox(height: 16),
                    Text('Connecting…', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),

        // Local video preview (top-right corner)
        if (_engine != null && !_cameraOff)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            width: 90,
            height: 130,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: _engine!,
                  canvas: const VideoCanvas(uid: 0),
                ),
              ),
            ),
          ),

        // Top bar — timer + report
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_elapsed,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.flag_outlined, color: Colors.white54, size: 22),
                  onPressed: () {/* TODO: report */},
                  tooltip: 'Report',
                ),
              ],
            ),
          ),
        ),

        // Bottom controls
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
            padding: EdgeInsets.fromLTRB(
                24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                // Mute
                _CtrlBtn(
                  icon: _micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  label: _micMuted ? 'Unmute' : 'Mute',
                  onTap: () {
                    setState(() => _micMuted = !_micMuted);
                    _engine?.muteLocalAudioStream(_micMuted);
                  },
                ),
                // Flip camera
                _CtrlBtn(
                  icon: Icons.flip_camera_ios_rounded,
                  label: 'Flip',
                  onTap: () => _engine?.switchCamera(),
                ),
                // Next
                _CtrlBtn(
                  icon: Icons.skip_next_rounded,
                  label: 'Next',
                  color: const Color(0xFF1FA4EA),
                  onTap: _next,
                ),
                // End
                _CtrlBtn(
                  icon: Icons.call_end_rounded,
                  label: 'End',
                  color: Colors.red,
                  onTap: _end,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Transitioning screen ──────────────────────────────────────────────────────

  Widget _buildTransitioning() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(color: Color(0xFF1FA4EA), strokeWidth: 2),
          const SizedBox(height: 20),
          const Text('Finding next person…',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }
}

// ── Small control button ──────────────────────────────────────────────────────

class _CtrlBtn extends StatelessWidget {
  const _CtrlBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? Colors.white70;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: c.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Icon(icon, color: c, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: c, fontSize: 11)),
        ],
      ),
    );
  }
}
