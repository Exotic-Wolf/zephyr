import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/api_client.dart';

/// Billing tick interval in seconds.
const int _kTickSeconds = 15;

class DirectCallScreen extends StatefulWidget {
  const DirectCallScreen({
    super.key,
    required this.apiClient,
    required this.accessToken,
    required this.sessionId,
    required this.appId,
    required this.channelName,
    required this.uid,
    required this.token,
    required this.partnerName,
    this.partnerAvatarUrl,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final String sessionId;
  final String appId;
  final String channelName;
  final int uid;
  final String token;
  final String partnerName;
  final String? partnerAvatarUrl;

  @override
  State<DirectCallScreen> createState() => _DirectCallScreenState();
}

class _DirectCallScreenState extends State<DirectCallScreen> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _localVideoReady = false;
  bool _micMuted = false;
  bool _cameraMuted = false;
  int _elapsed = 0;
  Timer? _elapsedTimer;
  Timer? _tickTimer;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await [Permission.camera, Permission.microphone].request();
    await _initAgora();
    _startTimers();
  }

  Future<void> _initAgora() async {
    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(
      appId: widget.appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        debugPrint('[DirectCall] joined channel: ${connection.channelId}');
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        if (!_disposed) setState(() => _remoteUid = remoteUid);
      },
      onUserOffline: (connection, remoteUid, reason) {
        if (!_disposed) {
          setState(() => _remoteUid = null);
          // Partner left — end call
          _endCall();
        }
      },
      onLocalVideoStateChanged: (source, state, error) {
        if (state == LocalVideoStreamState.localVideoStreamStateCapturing ||
            state == LocalVideoStreamState.localVideoStreamStateEncoding) {
          if (!_disposed) setState(() => _localVideoReady = true);
        }
      },
      onError: (err, msg) {
        debugPrint('[DirectCall] Agora error: $err $msg');
      },
    ));

    await engine.enableVideo();
    await engine.enableAudio();
    await engine.startPreview();

    await engine.joinChannel(
      token: widget.token,
      channelId: widget.channelName,
      uid: widget.uid,
      options: const ChannelMediaOptions(
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
      ),
    );

    _engine = engine;
    if (!_disposed) setState(() {});
  }

  void _startTimers() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_disposed) setState(() => _elapsed++);
    });
    _tickTimer = Timer.periodic(Duration(seconds: _kTickSeconds), (_) {
      widget.apiClient.tickCallSession(
        accessToken: widget.accessToken,
        sessionId: widget.sessionId,
        elapsedSeconds: _kTickSeconds,
      ).ignore();
    });
  }

  void _toggleMic() {
    setState(() => _micMuted = !_micMuted);
    _engine?.muteLocalAudioStream(_micMuted);
  }

  void _toggleCamera() {
    setState(() => _cameraMuted = !_cameraMuted);
    _engine?.muteLocalVideoStream(_cameraMuted);
  }

  void _flipCamera() {
    _engine?.switchCamera();
  }

  void _endCall() {
    if (_disposed) return;
    widget.apiClient.endCallSession(
      accessToken: widget.accessToken,
      sessionId: widget.sessionId,
      reason: 'user_ended',
    ).ignore();
    _leave();
  }

  void _leave() {
    if (_disposed) return;
    _disposed = true;
    _elapsedTimer?.cancel();
    _tickTimer?.cancel();
    _engine?.leaveChannel();
    _engine?.release();
    _engine = null;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _disposed = true;
    _elapsedTimer?.cancel();
    _tickTimer?.cancel();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  String get _timerText {
    final m = _elapsed ~/ 60;
    final s = _elapsed % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          // Remote video (full screen)
          _buildRemoteVideo(),

          // Local preview (PIP top-right)
          _buildLocalPreview(),

          // Top bar: timer + partner name
          _buildTopBar(),

          // Bottom controls
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildRemoteVideo() {
    if (_engine != null && _remoteUid != null) {
      return Positioned.fill(
        child: AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: _engine!,
            canvas: VideoCanvas(uid: _remoteUid!),
            connection: RtcConnection(channelId: widget.channelName),
          ),
        ),
      );
    }

    // Waiting for partner to connect
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF1A1A2E),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            CircleAvatar(
              radius: 48,
              backgroundColor: Colors.white12,
              backgroundImage: widget.partnerAvatarUrl != null
                  ? NetworkImage(widget.partnerAvatarUrl!)
                  : null,
              child: widget.partnerAvatarUrl == null
                  ? Text(
                      widget.partnerName.isNotEmpty
                          ? widget.partnerName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 36, color: Colors.white70),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              widget.partnerName,
              style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connecting video…',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalPreview() {
    if (_engine == null) return const SizedBox.shrink();
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      right: 12,
      width: 100,
      height: 140,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.white24, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _cameraMuted
              ? const Center(
                  child: Icon(Icons.videocam_off_rounded,
                      color: Colors.white38, size: 32),
                )
              : _localVideoReady
                  ? AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: _engine!,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white24)),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.circle, color: Colors.redAccent, size: 8),
                    const SizedBox(width: 6),
                    Text(
                      _timerText,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_remoteUid == null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Waiting…',
                      style: TextStyle(color: Colors.orange, fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
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
            24, 40, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            _ControlButton(
              icon: _micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: _micMuted ? 'Unmute' : 'Mute',
              onTap: _toggleMic,
            ),
            _ControlButton(
              icon: _cameraMuted
                  ? Icons.videocam_off_rounded
                  : Icons.videocam_rounded,
              label: _cameraMuted ? 'Camera On' : 'Camera Off',
              onTap: _toggleCamera,
            ),
            _ControlButton(
              icon: Icons.flip_camera_ios_rounded,
              label: 'Flip',
              onTap: _flipCamera,
            ),
            _ControlButton(
              icon: Icons.call_end_rounded,
              label: 'End',
              color: Colors.red,
              onTap: _endCall,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Control button widget ─────────────────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  const _ControlButton({
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
    final c = color ?? Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (color ?? Colors.white).withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: c, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(color: c.withValues(alpha: 0.8), fontSize: 11)),
        ],
      ),
    );
  }
}
