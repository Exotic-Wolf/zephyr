import 'dart:math' show pi, sin;
import 'package:flutter/material.dart';

class ShakeCallButton extends StatefulWidget {
  const ShakeCallButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<ShakeCallButton> createState() => _ShakeCallButtonState();
}

class _ShakeCallButtonState extends State<ShakeCallButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const Color _baseGreen = Color(0xFF00A651);
  static const Color _lightGreen = Color(0xFF7BEA3B);
  static const double _btnSize = 52;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3800),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _shakeAngle(double t) {
    if (t > 0.15) return 0;
    return sin(t * 10 * 2 * pi) * (6 * pi / 180);
  }

  double? _ringProgress(double t, double phase) {
    final double shifted = (t + phase) % 1.0;
    if (shifted > 0.40) return null;
    return shifted / 0.40;
  }

  Widget _buildRing(double progress) {
    final double size = _btnSize + progress * 48;
    final double opacity = (1 - progress) * 0.35;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _baseGreen.withValues(alpha: opacity),
          width: 2.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = _controller.value;
        final double? r1 = _ringProgress(t, 0.0);
        final double? r2 = _ringProgress(t, 0.15);

        return SizedBox(
          width: _btnSize + 40,
          height: _btnSize + 40,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              if (r1 != null) _buildRing(r1),
              if (r2 != null) _buildRing(r2),
              Transform.rotate(
                angle: _shakeAngle(t),
                child: child,
              ),
            ],
          ),
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: _btnSize,
          height: _btnSize,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: <Color>[_baseGreen, _lightGreen],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.call_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
