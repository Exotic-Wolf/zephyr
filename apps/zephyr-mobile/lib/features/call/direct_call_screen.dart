import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/api_client.dart';
import '../../services/firebase_chat_service.dart';
import 'call_ended_screen.dart';

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
    required this.partnerId,
    this.partnerAvatarUrl,
    this.myUserId,
    this.myDisplayName,
    this.myAvatarUrl,
    this.mode = 'direct',
    this.allowRandomNext = true,
    this.startMedia = true,
    this.managePresence = true,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final String sessionId;
  final String appId;
  final String channelName;
  final int uid;
  final String token;
  final String partnerName;
  final String partnerId;
  final String? partnerAvatarUrl;
  final String? myUserId;
  final String? myDisplayName;
  final String? myAvatarUrl;

  /// 'direct' or 'random'. Random mode adds Next button and pops with result.
  final String mode;
  final bool allowRandomNext;
  final bool startMedia;
  final bool managePresence;

  bool get isRandom => mode == 'random';

  @override
  State<DirectCallScreen> createState() => _DirectCallScreenState();
}

class _DirectCallScreenState extends State<DirectCallScreen> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _localVideoReady = false;
  bool _micMuted = false;
  bool _cameraMuted = false;
  bool _remoteVideoMuted = false;
  bool _reconnecting = false;
  int _elapsed = 0;
  Timer? _elapsedTimer;
  Timer? _tickTimer;
  StreamSubscription<dynamic>? _randomSignalSub;
  bool _disposed = false;
  int _billingTickSequence = 0;
  bool _reporting = false;
  bool _reportedCall = false;

  @override
  void initState() {
    super.initState();
    if (widget.startMedia) {
      _init();
    }
  }

  Future<void> _init() async {
    await [Permission.camera, Permission.microphone].request();
    if (widget.managePresence) {
      FirebaseChatService.instance.setBusyStatus(
        sessionId: widget.sessionId,
        activity: widget.isRandom ? 'random_call' : 'direct_call',
      );
    }
    if (widget.isRandom && widget.managePresence) {
      _listenForRandomPartnerEvents();
    }
    await _initAgora();
    _startTimers();
  }

  void _listenForRandomPartnerEvents() {
    _randomSignalSub?.cancel();
    _randomSignalSub = FirebaseChatService.instance.listenCallSignal(
      FirebaseChatService.instance.myUserId,
      (Map<String, dynamic>? data) {
        if (_disposed || !mounted || data == null) return;
        if (data['event'] != 'partner_left') return;

        final sessionId = data['sessionId'] as String?;
        if (sessionId != null && sessionId != widget.sessionId) return;

        FirebaseChatService.instance
            .removeCallSignal(FirebaseChatService.instance.myUserId)
            .ignore();
        _showSnack('Partner left');
        _leaveWithResult('partner_left');
      },
    );
  }

  Future<void> _initAgora() async {
    final engine = createAgoraRtcEngine();
    await engine.initialize(
      RtcEngineContext(
        appId: widget.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint('[DirectCall] joined channel: ${connection.channelId}');
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          if (!_disposed) {
            setState(() => _remoteUid = remoteUid);
            _startBillingTimer();
          }
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (!_disposed) {
            setState(() => _remoteUid = null);
            if (widget.isRandom) {
              // Random mode: partner left → pop with result so search can continue
              _leaveWithResult('partner_left');
            } else {
              _endCall();
            }
          }
        },
        onLocalVideoStateChanged: (source, state, error) {
          if (state == LocalVideoStreamState.localVideoStreamStateCapturing ||
              state == LocalVideoStreamState.localVideoStreamStateEncoding) {
            if (!_disposed) setState(() => _localVideoReady = true);
          }
        },
        onRemoteVideoStateChanged:
            (connection, remoteUid, state, reason, elapsed) {
              if (!_disposed) {
                if (reason ==
                    RemoteVideoStateReason.remoteVideoStateReasonRemoteMuted) {
                  setState(() => _remoteVideoMuted = true);
                } else if (state == RemoteVideoState.remoteVideoStateDecoding) {
                  setState(() => _remoteVideoMuted = false);
                }
              }
            },
        onTokenPrivilegeWillExpire: (connection, token) => _renewToken(),
        onConnectionStateChanged: (connection, state, reason) {
          if (_disposed) return;
          final bool lost =
              state == ConnectionStateType.connectionStateReconnecting;
          if (lost != _reconnecting) setState(() => _reconnecting = lost);
        },
        onError: (err, msg) {
          debugPrint('[DirectCall] Agora error: $err $msg');
          if (!_disposed && mounted) {
            _showSnack('Call error — please try again');
          }
        },
      ),
    );

    await engine.enableVideo();
    await engine.enableAudio();
    await engine.startPreview();

    // Retry joinChannel once if -17 (previous engine not fully released yet)
    try {
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
    } on AgoraRtcException catch (e) {
      if (e.code == -17 && !_disposed) {
        debugPrint(
          '[DirectCall] joinChannel rejected (-17), retrying in 500ms',
        );
        await Future.delayed(const Duration(milliseconds: 500));
        if (_disposed) return;
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
      } else {
        rethrow;
      }
    }

    _engine = engine;
    if (!_disposed) setState(() {});
  }

  void _startTimers() {
    // Elapsed counter starts immediately (shows user wait time)
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_disposed) setState(() => _elapsed++);
    });
    // Billing timer starts only when partner joins (see onUserJoined)
  }

  void _startBillingTimer() {
    if (_tickTimer != null) return; // already started
    _tickTimer = Timer.periodic(Duration(seconds: _kTickSeconds), (_) {
      _tick();
    });
  }

  Future<void> _tick() async {
    final int tickSequence = ++_billingTickSequence;
    final String idempotencyKey =
        'call-tick:${widget.sessionId}:$tickSequence:$_kTickSeconds';
    try {
      final result = await widget.apiClient.tickCallSession(
        accessToken: widget.accessToken,
        sessionId: widget.sessionId,
        elapsedSeconds: _kTickSeconds,
        idempotencyKey: idempotencyKey,
      );
      if (result.stoppedForInsufficientBalance && !_disposed) {
        _showSnack('Insufficient balance — call ended');
        _leave();
      }
    } catch (_) {
      // Network error during tick — don't kill the call, next tick will retry
    }
  }

  Future<void> _renewToken() async {
    try {
      final rtc = await widget.apiClient.requestCallRtcToken(
        accessToken: widget.accessToken,
        sessionId: widget.sessionId,
      );
      await _engine?.renewToken(rtc.token);
    } catch (e) {
      debugPrint('[DirectCall] token renewal error: $e');
      _showSnack('Connection issue — reconnecting…');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
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
    if (widget.isRandom) {
      widget.apiClient
          .endRandomCall(
            widget.accessToken,
            sessionId: widget.sessionId,
            partnerId: widget.partnerId,
          )
          .ignore();
      _leaveWithResult('ended');
    } else {
      widget.apiClient
          .endCallSession(
            accessToken: widget.accessToken,
            sessionId: widget.sessionId,
            reason: 'user_ended',
          )
          .ignore();
      _leave(showPostCall: true);
    }
  }

  Future<void> _reportCall() async {
    if (_reporting || _reportedCall) return;
    final reason = await showCallReportReasonSheet(context);
    if (reason == null || !mounted) return;

    setState(() => _reporting = true);
    try {
      await widget.apiClient.reportCall(
        accessToken: widget.accessToken,
        sessionId: widget.sessionId,
        reportedUserId: widget.partnerId,
        reason: reason,
      );
      if (!mounted) return;
      setState(() => _reportedCall = true);
      _showSnack('Report sent. Thank you.');
    } catch (_) {
      _showSnack('Could not send report. Try again.');
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  void _nextCall() {
    if (_disposed) return;
    // Don't end session here — RandomCallScreen will call nextRandomCall
    // which ends the old session + seeks a new one atomically.
    _leaveWithResult('next');
  }

  void _leaveWithResult(String action) {
    if (_disposed) return;
    _disposed = true;
    _elapsedTimer?.cancel();
    _tickTimer?.cancel();
    _randomSignalSub?.cancel();
    if (widget.managePresence) FirebaseChatService.instance.clearBusyStatus();
    final engine = _engine;
    _engine = null;
    if (engine != null) {
      engine.leaveChannel().then((_) => engine.release());
    }
    if (mounted) {
      Navigator.of(context).pop(<String, String>{
        'action': action,
        'sessionId': widget.sessionId,
        'partnerId': widget.partnerId,
      });
    }
  }

  void _leave({bool showPostCall = false}) {
    if (_disposed) return;
    _disposed = true;
    _elapsedTimer?.cancel();
    _tickTimer?.cancel();
    _randomSignalSub?.cancel();
    if (widget.managePresence) FirebaseChatService.instance.clearBusyStatus();
    final engine = _engine;
    _engine = null;
    if (engine != null) {
      engine.leaveChannel().then((_) => engine.release());
    }
    if (!mounted) return;
    if (showPostCall) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CallEndedScreen(
            apiClient: widget.apiClient,
            accessToken: widget.accessToken,
            sessionId: widget.sessionId,
            partnerId: widget.partnerId,
            partnerName: widget.partnerName,
            partnerAvatarUrl: widget.partnerAvatarUrl,
            myUserId: widget.myUserId,
            myDisplayName: widget.myDisplayName,
            myAvatarUrl: widget.myAvatarUrl,
          ),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    if (!_disposed) {
      // End session on server if not already ended
      if (widget.isRandom) {
        widget.apiClient
            .endRandomCall(
              widget.accessToken,
              sessionId: widget.sessionId,
              partnerId: widget.partnerId,
            )
            .ignore();
      } else {
        widget.apiClient
            .endCallSession(
              accessToken: widget.accessToken,
              sessionId: widget.sessionId,
              reason: 'disposed',
            )
            .ignore();
      }
      if (widget.managePresence) FirebaseChatService.instance.clearBusyStatus();
    }
    _disposed = true;
    _elapsedTimer?.cancel();
    _tickTimer?.cancel();
    _randomSignalSub?.cancel();
    final engine = _engine;
    _engine = null;
    if (engine != null) {
      engine.leaveChannel().then((_) => engine.release());
    }
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

          // Reconnecting overlay
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
        ],
      ),
    );
  }

  Widget _buildRemoteVideo() {
    if (_engine != null && _remoteUid != null && !_remoteVideoMuted) {
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
                        fontSize: 36,
                        color: Colors.white70,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              widget.partnerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _remoteVideoMuted ? 'Camera off' : 'Connecting video…',
              style: const TextStyle(color: Colors.white38, fontSize: 14),
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
                  child: Icon(
                    Icons.videocam_off_rounded,
                    color: Colors.white38,
                    size: 32,
                  ),
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
                    strokeWidth: 2,
                    color: Colors.white24,
                  ),
                ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                key: const Key('direct-call-report-button'),
                tooltip: _reportedCall ? 'Reported' : 'Report call',
                onPressed: _reporting || _reportedCall ? null : _reportCall,
                icon: _reporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      )
                    : Icon(
                        _reportedCall
                            ? Icons.verified_user_rounded
                            : Icons.report_gmailerrorred_rounded,
                        color: _reportedCall
                            ? Colors.greenAccent
                            : Colors.white,
                      ),
              ),
              if (_remoteUid == null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Waiting…',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
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
          24,
          40,
          24,
          MediaQuery.of(context).padding.bottom + 24,
        ),
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
            if (widget.isRandom && widget.allowRandomNext)
              _ControlButton(
                icon: Icons.skip_next_rounded,
                label: 'Next',
                color: const Color(0xFF1FA4EA),
                onTap: _nextCall,
              ),
            _ControlButton(
              key: const Key('direct-call-end-button'),
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
    super.key,
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
          Text(
            label,
            style: TextStyle(color: c.withValues(alpha: 0.8), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
