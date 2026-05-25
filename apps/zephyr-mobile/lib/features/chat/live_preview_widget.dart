import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import '../../services/api_client.dart';

/// Compact live stream preview — drop anywhere with just a [roomId] and [onTap].
///
/// Subscribes to the low-quality video stream for minimal bandwidth.
/// Fades in smoothly once the first frame arrives.
/// Auto-hides if the host disconnects.
/// Silent — no audio.
/// Callback signature when the user taps the preview.
/// Receives the already-connected [engine], [hostUid], and [channelName]
/// so the destination screen can reuse them without re-joining.
typedef LivePreviewTapCallback = void Function(
    RtcEngine engine, int hostUid, String channelName);

class LivePreviewWidget extends StatefulWidget {
  const LivePreviewWidget({
    super.key,
    required this.roomId,
    required this.onTap,
    this.width = 120,
    this.height = 160,
    this.borderRadius = 12,
  });

  final String roomId;
  final LivePreviewTapCallback onTap;
  final double width;
  final double height;
  final double borderRadius;

  @override
  State<LivePreviewWidget> createState() => _LivePreviewWidgetState();
}

class _LivePreviewWidgetState extends State<LivePreviewWidget>
    with SingleTickerProviderStateMixin {
  RtcEngine? _engine;
  int? _hostUid;
  String? _channelName;
  bool _streaming = false;
  bool _failed = false;
  bool _disposed = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _init();
  }

  Future<void> _init() async {
    final api = ZephyrApiClient.instance;
    final token = ZephyrApiClient.accessToken;
    if (api == null || token == null) {
      debugPrint('[LivePreview] no api/token');
      if (mounted) setState(() => _failed = true);
      return;
    }

    try {
      final info = await api.getRoomRtcToken(token, widget.roomId);
      debugPrint('[LivePreview] got token for channel=${info.channelName} uid=${info.uid}');
      if (_disposed) return;

      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: info.appId));
      if (_disposed) {
        engine.release();
        return;
      }

      engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint('[LivePreview] joined channel OK elapsed=$elapsed');
        },
        onError: (err, msg) {
          debugPrint('[LivePreview] agora error: $err $msg');
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          debugPrint('[LivePreview] host joined uid=$remoteUid');
          if (!mounted) return;
          setState(() {
            _hostUid = remoteUid;
            _streaming = true;
          });
          _fadeCtrl.forward();
          // Subscribe low-quality stream for preview
          engine.setRemoteVideoStreamType(
            uid: remoteUid,
            streamType: VideoStreamType.videoStreamLow,
          );
        },
        onUserOffline: (connection, remoteUid, reason) {
          debugPrint('[LivePreview] host offline uid=$remoteUid');
          if (!mounted) return;
          setState(() {
            _hostUid = null;
            _streaming = false;
          });
          _fadeCtrl.reverse();
        },
        onFirstRemoteVideoFrame: (connection, remoteUid, width, height, elapsed) {
          debugPrint('[LivePreview] first frame ${width}x$height');
        },
      ));

      await engine.setChannelProfile(
          ChannelProfileType.channelProfileLiveBroadcasting);
      await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
      await engine.enableVideo();
      await engine.muteAllRemoteAudioStreams(true);

      await engine.joinChannel(
        token: info.token,
        channelId: info.channelName,
        uid: info.uid,
        options: const ChannelMediaOptions(
          autoSubscribeVideo: true,
          autoSubscribeAudio: false,
          clientRoleType: ClientRoleType.clientRoleAudience,
        ),
      );

      if (_disposed) {
        engine.leaveChannel();
        engine.release();
        return;
      }

      _engine = engine;
      if (mounted) setState(() => _channelName = info.channelName);
    } catch (e) {
      debugPrint('[LivePreview] init error: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _fadeCtrl.dispose();
    _releaseEngine();
    super.dispose();
  }

  void _releaseEngine() {
    final engine = _engine;
    _engine = null;
    if (engine != null) {
      engine.leaveChannel();
      engine.release(sync: true);
    }
  }

  void _handleTap() {
    final engine = _engine;
    final hostUid = _hostUid;
    final channelName = _channelName;
    if (engine == null || hostUid == null || channelName == null) return;
    // Transfer ownership — don't release, the receiver owns it now
    _engine = null;
    widget.onTap(engine, hostUid, channelName);
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();

    return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video layer — fades in on first frame
            if (_engine != null && _hostUid != null)
              FadeTransition(
                opacity: _fadeAnim,
                child: AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: _engine!,
                    canvas: VideoCanvas(uid: _hostUid!),
                    connection: RtcConnection(channelId: _channelName ?? ''),
                  ),
                ),
              ),
            // Loading state
            if (!_streaming)
              const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white38,
                  ),
                ),
              ),
            // LIVE badge
            const Positioned(
              top: 6,
              left: 6,
              child: _LiveBadge(),
            ),
            // Tap ripple hint
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: _handleTap),
              ),
            ),
          ],
        ),
      );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 5, color: Colors.white),
          SizedBox(width: 3),
          Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
