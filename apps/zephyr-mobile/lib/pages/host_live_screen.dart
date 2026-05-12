import 'dart:async';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../models/models.dart';
import '../services/api_client.dart';
import '../widgets/shared_live_widgets.dart';
import '../app_constants.dart';

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
  Timer? _heartbeatTimer;
  sio.Socket? _socket;
  final List<LiveComment> _comments = <LiveComment>[];
  final List<FloatingGift> _gifts = <FloatingGift>[];
  late final AnimationController _pulseCtrl;

  // LiveKit
  lk.Room? _livekitRoom;
  lk.VideoTrack? _localVideoTrack;

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
    // Heartbeat: tell server host is still live every 15s
    widget.apiClient
        .heartbeatRoom(widget.accessToken, widget.room.id)
        .ignore();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => widget.apiClient
          .heartbeatRoom(widget.accessToken, widget.room.id)
          .ignore(),
    );
    // Real-time viewer count via socket
    _connectSocket();
    // LiveKit RTC
    _connectLiveKit();
  }

  Future<void> _connectLiveKit() async {
    try {
      final info = await widget.apiClient.getRoomRtcToken(
          widget.accessToken, widget.room.id);
      _livekitRoom = lk.Room();
      await _livekitRoom!.connect(
        info.wsUrl,
        info.token,
        roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true),
      );
      await _livekitRoom!.localParticipant?.setCameraEnabled(true);
      await _livekitRoom!.localParticipant?.setMicrophoneEnabled(true);
      if (mounted) {
        setState(() {
          _localVideoTrack = _livekitRoom!
              .localParticipant
              ?.videoTrackPublications
              .firstOrNull
              ?.track as lk.VideoTrack?;;
        });
      }
    } catch (e) {
      debugPrint('[LiveKit host] error: $e');
    }
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
          if (payload['roomId'] == widget.room.id) {
            setState(() => _viewerCount = payload['audienceCount'] as int);
          }
        } catch (_) {}
      })
      ..connect();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _heartbeatTimer?.cancel();
    _socket?.dispose();
    _pulseCtrl.dispose();
    _livekitRoom?.disconnect();
    _livekitRoom?.dispose();
    // End the room automatically if host navigates away or closes the app
    widget.apiClient.endRoom(widget.accessToken, widget.room.id)
        .then((_) => debugPrint('[endRoom dispose] success'))
        .catchError((Object e) { debugPrint('[endRoom dispose] error: $e'); });
    super.dispose();
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
      debugPrint('[endRoom] success');
    } catch (e) {
      debugPrint('[endRoom] error: $e');
      // ignore API error — pop anyway so user isn't stuck
    }
    if (mounted) Navigator.of(context).pop();
    widget.onEnd();
  }

  void _flipCamera() async {
    final devices = await lk.Hardware.instance.enumerateDevices();
    final cameras = devices.where((d) => d.kind == 'videoinput').toList();
    if (cameras.length < 2) return;
    final currentId = lk.Hardware.instance.selectedVideoInput?.deviceId;
    final next = cameras.firstWhere(
      (d) => d.deviceId != currentId,
      orElse: () => cameras.first,
    );
    await _livekitRoom?.setVideoInputDevice(next);
  }

  void _addComment(String name, String text) {
    setState(() {
      _comments.add(LiveComment(name: name, text: text));
      if (_comments.length > 30) _comments.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          // ── Background (live camera or placeholder) ──────────────────────
          if (_localVideoTrack != null)
            Positioned.fill(
              child: lk.VideoTrackRenderer(
                _localVideoTrack!,
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
          ..._gifts.map((g) => FloatingGiftWidget(gift: g)),

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
                  LiveCtrlBtn(
                    icon: _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                    label: _micOn ? 'Mic On' : 'Mic Off',
                    active: _micOn,
                    onTap: () {
                      setState(() => _micOn = !_micOn);
                      _livekitRoom?.localParticipant
                          ?.setMicrophoneEnabled(_micOn);
                    },
                  ),
                  LiveCtrlBtn(
                    icon: _cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                    label: _cameraOn ? 'Camera' : 'Off',
                    active: _cameraOn,
                    onTap: () {
                      setState(() => _cameraOn = !_cameraOn);
                      _livekitRoom?.localParticipant
                          ?.setCameraEnabled(_cameraOn);
                    },
                  ),
                  LiveCtrlBtn(
                    icon: Icons.flip_camera_ios_rounded,
                    label: 'Flip',
                    active: true,
                    onTap: _flipCamera,
                  ),
                  LiveCtrlBtn(
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

