import 'dart:async';

import 'package:flutter/material.dart';

import '../services/presence_bus.dart';

/// A small status indicator dot that updates in real-time via [PresenceBus].
///
/// Usage:
///   StatusDot(userId: 'abc123', size: 12)
///
/// Place inside a Stack with Positioned to overlap an avatar.
class StatusDot extends StatefulWidget {
  const StatusDot({super.key, required this.userId, this.size = 12});

  final String userId;
  final double size;

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot> {
  late String _status;
  StreamSubscription<PresenceEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _status = PresenceBus.instance.statusOf(widget.userId);
    _sub = PresenceBus.instance.stream.listen(_onEvent);
  }

  @override
  void didUpdateWidget(StatusDot old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId) {
      _status = PresenceBus.instance.statusOf(widget.userId);
    }
  }

  void _onEvent(PresenceEvent e) {
    if (e.userId != widget.userId || !mounted) return;
    setState(() => _status = e.status);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: _colorFor(_status),
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 2,
        ),
      ),
    );
  }

  static Color _colorFor(String status) => switch (status) {
        'live' => const Color(0xFFFF3B30),
        'busy' => const Color(0xFFFF9500),
        'online' => const Color(0xFF34C759),
        _ => const Color(0xFF8E8E93),
      };
}
