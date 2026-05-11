import 'dart:async';
import 'dart:math' show cos, pi, sin;
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import 'host_live_screen.dart';
import '../app_constants.dart';

// ── GoLiveCountdownPage ───────────────────────────────────────────────────────

class GoLiveCountdownPage extends StatefulWidget {
  const GoLiveCountdownPage({
    super.key,
    required this.displayName,
    required this.avatarUrl,
    required this.apiClient,
    required this.accessToken,
    required this.onEnd,
    required this.onCancel,
  });

  final String displayName;
  final String? avatarUrl;
  final ZephyrApiClient apiClient;
  final String accessToken;
  final VoidCallback onEnd;
  final VoidCallback onCancel;

  @override
  State<GoLiveCountdownPage> createState() => _GoLiveCountdownPageState();
}

class _GoLiveCountdownPageState extends State<GoLiveCountdownPage>
    with SingleTickerProviderStateMixin {
  int _count = 3;
  Timer? _timer;
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scale;

  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _scaleCtrl.forward();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_count == 1) {
        _timer?.cancel();
        setState(() => _count = 0);
        // Show LIVE briefly then create room and pushReplacement
        Future<void>.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _startLive();
        });
      } else {
        setState(() => _count--);
        _scaleCtrl.forward(from: 0);
      }
    });
  }

  Future<void> _startLive() async {
    setState(() => _starting = true);
    try {
      final Room room = await widget.apiClient.createRoom(
          widget.accessToken, widget.displayName);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => HostLiveScreen(
          room: room,
          apiClient: widget.apiClient,
          accessToken: widget.accessToken,
          hostDisplayName: widget.displayName,
          hostAvatarUrl: widget.avatarUrl,
          onEnd: widget.onEnd,
        ),
      ));
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCancel();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLive = _count == 0;

    return Scaffold(
      backgroundColor: Colors.black87,
      body: Stack(
        children: <Widget>[
          // Background blur effect
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF0d0d1a), Color(0xFF1a0a2e)],
              ),
            ),
          ),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Avatar
                CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white12,
                  backgroundImage: widget.avatarUrl != null
                      ? NetworkImage(widget.avatarUrl!)
                      : null,
                  child: widget.avatarUrl == null
                      ? Text(
                          widget.displayName.isNotEmpty
                              ? widget.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.displayName,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 48),

                // Countdown number / LIVE
                ScaleTransition(
                  scale: _scale,
                  child: isLive
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 36, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              const Text('LIVE',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 4)),
                            ],
                          ),
                        )
                      : Text(
                          '$_count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 120,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                ),

                const SizedBox(height: 32),
                Text(
                  isLive
                      ? (_starting ? 'Starting your stream…' : 'Starting your stream…')
                      : 'Get ready!',
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                ),
                const SizedBox(height: 60),

                // Cancel button — hidden once LIVE / starting
                if (!isLive && !_starting)
                  TextButton(
                    onPressed: () {
                      _timer?.cancel();
                      Navigator.of(context).pop();
                      widget.onCancel();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white30),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(
                              color: Colors.white60,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

