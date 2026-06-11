import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Full-screen overlay shown when another user is ringing this user for a video
/// call. Provides Accept / Reject buttons.
class IncomingCallOverlay extends StatefulWidget {
  const IncomingCallOverlay({
    super.key,
    required this.callerId,
    required this.onAccept,
    required this.onReject,
    this.callerName,
  });

  final String callerId;
  final String? callerName;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  State<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<IncomingCallOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _tapped = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _handleAccept() {
    if (_tapped) return;
    _tapped = true;
    widget.onAccept();
  }

  void _handleReject() {
    if (_tapped) return;
    _tapped = true;
    widget.onReject();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF0111118),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double height = constraints.maxHeight;
            final bool compact = height < 620;
            final double topInset = (height * (compact ? 0.14 : 0.22))
                .clamp(24.0, 170.0)
                .toDouble();
            final double bottomInset = (height * 0.07)
                .clamp(18.0, 56.0)
                .toDouble();
            final double iconDiameter = compact ? 90 : 110;
            final double iconSize = compact ? 42 : 48;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, topInset, 24, bottomInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0, height - topInset - bottomInset),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _IncomingCallerBlock(
                      pulseCtrl: _pulseCtrl,
                      callerName: widget.callerName,
                      iconDiameter: iconDiameter,
                      iconSize: iconSize,
                      compact: compact,
                    ),
                    const SizedBox(height: 36),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          _CircleButton(
                            icon: Icons.call_end_rounded,
                            color: Colors.red,
                            label: 'Decline',
                            onTap: _handleReject,
                          ),
                          _CircleButton(
                            icon: Icons.videocam_rounded,
                            color: const Color(0xFF4CAF50),
                            label: 'Accept',
                            onTap: _handleAccept,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _IncomingCallerBlock extends StatelessWidget {
  const _IncomingCallerBlock({
    required this.pulseCtrl,
    required this.callerName,
    required this.iconDiameter,
    required this.iconSize,
    required this.compact,
  });

  final AnimationController pulseCtrl;
  final String? callerName;
  final double iconDiameter;
  final double iconSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedBuilder(
          animation: pulseCtrl,
          builder: (_, __) {
            final double scale = 1.0 + pulseCtrl.value * 0.12;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: iconDiameter,
                height: iconDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1FA4EA).withValues(alpha: 0.12),
                  border: Border.all(
                    color: const Color(0xFF1FA4EA).withValues(alpha: 0.6),
                    width: 2.5,
                  ),
                ),
                child: Icon(
                  Icons.videocam_rounded,
                  color: const Color(0xFF1FA4EA),
                  size: iconSize,
                ),
              ),
            );
          },
        ),
        SizedBox(height: compact ? 22 : 32),
        Text(
          callerName ?? 'Incoming Video Call',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 20 : 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Incoming video call',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
