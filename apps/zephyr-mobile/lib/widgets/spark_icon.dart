import 'dart:math' show pi, sin, cos;
import 'package:flutter/material.dart';

// ── SparkIcon ────────────────────────────────────────────────────────────────
class SparkIcon extends StatelessWidget {
  const SparkIcon({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 0.78,
      height: size,
      child: CustomPaint(painter: ClassicFlamePainter()),
    );
  }
}

class ClassicFlamePainter extends CustomPainter {  // v4 saved — 3-tongue Olympic, good gradient
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Rect bounds = Rect.fromLTWH(0, 0, w, h);

    // ── Olympic flame: 3 tongues (left short, center tallest, right medium) ──
    final Path flame = Path()
      ..moveTo(w * 0.50, h * 1.00)
      // base left curve
      ..cubicTo(w * 0.18, h * 1.00, w * 0.06, h * 0.80, w * 0.12, h * 0.58)
      // left wall rising
      ..cubicTo(w * 0.16, h * 0.44, w * 0.20, h * 0.36, w * 0.22, h * 0.26)
      // left tongue — short, curled tip
      ..cubicTo(w * 0.22, h * 0.14, w * 0.27, h * 0.06, w * 0.30, h * 0.10)
      ..cubicTo(w * 0.33, h * 0.14, w * 0.34, h * 0.24, w * 0.37, h * 0.30)
      // valley between left and center
      ..cubicTo(w * 0.40, h * 0.36, w * 0.44, h * 0.30, w * 0.46, h * 0.20)
      // center tongue — tallest, sharp tip
      ..cubicTo(w * 0.48, h * 0.08, w * 0.50, h * 0.00, w * 0.52, h * 0.08)
      ..cubicTo(w * 0.54, h * 0.18, w * 0.58, h * 0.28, w * 0.60, h * 0.32)
      // valley between center and right
      ..cubicTo(w * 0.63, h * 0.26, w * 0.66, h * 0.18, w * 0.70, h * 0.12)
      // right tongue — medium height
      ..cubicTo(w * 0.74, h * 0.06, w * 0.78, h * 0.12, w * 0.76, h * 0.24)
      ..cubicTo(w * 0.74, h * 0.34, w * 0.78, h * 0.46, w * 0.84, h * 0.58)
      // base right curve
      ..cubicTo(w * 0.92, h * 0.80, w * 0.82, h * 1.00, w * 0.50, h * 1.00)
      ..close();

    // Main gradient: bright gold tip → vivid orange → deep red base
    canvas.drawPath(
      flame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const <Color>[
            Color(0xFFFFF176), // pale gold tip
            Color(0xFFFF8F00), // amber
            Color(0xFFE53935), // deep red base
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ).createShader(bounds),
    );

    // Inner bright core teardrop — gives depth & realism
    final Path core = Path()
      ..moveTo(w * 0.50, h * 0.28)
      ..cubicTo(w * 0.60, h * 0.42, w * 0.63, h * 0.62, w * 0.57, h * 0.74)
      ..cubicTo(w * 0.54, h * 0.82, w * 0.46, h * 0.82, w * 0.43, h * 0.74)
      ..cubicTo(w * 0.37, h * 0.62, w * 0.40, h * 0.42, w * 0.50, h * 0.28)
      ..close();

    canvas.drawPath(
      core,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.88),
            const Color(0xFFFFCC02).withValues(alpha: 0.55),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Flame glory painter — light rays + 4-point sparkles ─────────────────────
class FlameGloryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.5;
    final double cy = size.height * 0.52;

    // ── Light rays radiating from flame center ────────────────
    final Paint rayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 8 rays at different angles, skip bottom zone (flame is there)
    const List<double> angles = <double>[-80, -55, -35, -15, 15, 35, 55, 80, 105, 130, 150, 170, 200, 220, 240, 255];
    const List<double> lengths = <double>[38, 28, 42, 30, 30, 42, 28, 38, 22, 30, 38, 26, 30, 38, 26, 22];
    const List<double> starts  = <double>[46, 40, 50, 38, 38, 50, 40, 46, 36, 40, 46, 38, 40, 46, 38, 36];

    for (int i = 0; i < angles.length; i++) {
      final double a = angles[i] * pi / 180;
      final double r0 = starts[i];
      final double r1 = r0 + lengths[i];
      final double opacity = 0.18 + (i % 3) * 0.08;
      rayPaint
        ..color = const Color(0xFFFF8F00).withValues(alpha: opacity)
        ..strokeWidth = 2.5 + (i % 2) * 1.5;
      canvas.drawLine(
        Offset(cx + r0 * cos(a), cy + r0 * sin(a)),
        Offset(cx + r1 * cos(a), cy + r1 * sin(a)),
        rayPaint,
      );
    }

    // ── 4-point diamond sparkles ──────────────────────────────
    void drawSparkle(double x, double y, double r, Color color) {
      final Path p = Path()
        ..moveTo(x,     y - r)
        ..cubicTo(x + r*0.18, y - r*0.18, x + r*0.18, y - r*0.18, x + r, y)
        ..cubicTo(x + r*0.18, y + r*0.18, x + r*0.18, y + r*0.18, x,     y + r)
        ..cubicTo(x - r*0.18, y + r*0.18, x - r*0.18, y + r*0.18, x - r, y)
        ..cubicTo(x - r*0.18, y - r*0.18, x - r*0.18, y - r*0.18, x,     y - r)
        ..close();
      canvas.drawPath(p, Paint()..color = color);
    }

    // Large sparkle — upper left
    drawSparkle(cx - 72, cy - 28, 10, const Color(0xFFFFD21F).withValues(alpha: 0.95));
    // Small sparkle — upper left (nested)
    drawSparkle(cx - 58, cy - 44, 5, const Color(0xFFFFE76A).withValues(alpha: 0.90));
    // Medium sparkle — upper right
    drawSparkle(cx + 68, cy - 22, 8, const Color(0xFFFF8F00).withValues(alpha: 0.88));
    // Tiny sparkle — right mid
    drawSparkle(cx + 82, cy + 8, 4, const Color(0xFFFFD21F).withValues(alpha: 0.80));
    // Tiny sparkle — upper center-right
    drawSparkle(cx + 30, cy - 52, 5, const Color(0xFFFFE76A).withValues(alpha: 0.75));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

