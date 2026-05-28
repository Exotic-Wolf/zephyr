import 'package:flutter/material.dart';

/// Full-screen overlay shown when another user is ringing this user for a
/// random video call. Provides Accept / Reject buttons.
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
        child: Column(
          children: <Widget>[
            const Spacer(flex: 2),
            // Pulsing phone icon
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) {
                final double scale = 1.0 + _pulseCtrl.value * 0.12;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1FA4EA).withValues(alpha: 0.12),
                      border: Border.all(
                        color: const Color(0xFF1FA4EA).withValues(alpha: 0.6),
                        width: 2.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.videocam_rounded,
                      color: Color(0xFF1FA4EA),
                      size: 48,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              widget.callerName ?? 'Incoming Video Call',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Incoming video call',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const Spacer(flex: 3),
            // Accept / Reject buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  // Reject
                  _CircleButton(
                    icon: Icons.call_end_rounded,
                    color: Colors.red,
                    label: 'Decline',
                    onTap: _handleReject,
                  ),
                  // Accept
                  _CircleButton(
                    icon: Icons.videocam_rounded,
                    color: const Color(0xFF4CAF50),
                    label: 'Accept',
                    onTap: _handleAccept,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
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
