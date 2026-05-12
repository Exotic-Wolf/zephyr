import 'package:flutter/material.dart';

// ── Zephyr coin icon — reusable, no copyright ───────────────────────────────
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFD95A), Color(0xFFE6A817)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFE6A817).withValues(alpha: 0.4),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'Z',
          style: TextStyle(
            fontSize: size * 0.52,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF7A4A00),
            height: 1,
          ),
        ),
      ),
    );
  }
}

