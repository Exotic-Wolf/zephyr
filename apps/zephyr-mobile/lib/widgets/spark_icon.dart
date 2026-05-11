import 'dart:math' show pi, sin, cos;
import 'package:flutter/material.dart';

// ── SparkIcon ────────────────────────────────────────────────────────────────
class SparkIcon extends StatelessWidget {
  const SparkIcon({this.size = 16});

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

// ── Spark hero painter — S-shaped flame silhouette ───────────────────────────
class _SparkHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // S-flame: two lobes — the silhouette reads as an S
    // Upper lobe curves right, lower lobe curves left, split tip at top
    final Path flame = Path()
      ..moveTo(w * 0.50, h * 0.98)          // base center
      // ── left side of base ──
      ..cubicTo(w * 0.14, h * 0.98, w * 0.04, h * 0.78, w * 0.10, h * 0.58)
      // ── lower-left up (bottom of S, left wall) ──
      ..cubicTo(w * 0.16, h * 0.42, w * 0.36, h * 0.40, w * 0.42, h * 0.36)
      // ── waist crossing left→right ──
      ..cubicTo(w * 0.54, h * 0.30, w * 0.28, h * 0.20, w * 0.28, h * 0.12)
      // ── left flame tip ──
      ..cubicTo(w * 0.28, h * 0.03, w * 0.38, h * 0.00, w * 0.44, h * 0.05)
      // ── notch between tips ──
      ..cubicTo(w * 0.47, h * 0.10, w * 0.53, h * 0.10, w * 0.56, h * 0.05)
      // ── right flame tip ──
      ..cubicTo(w * 0.62, h * 0.00, w * 0.72, h * 0.03, w * 0.72, h * 0.12)
      // ── upper-right down (top of S, right wall) ──
      ..cubicTo(w * 0.72, h * 0.20, w * 0.46, h * 0.30, w * 0.58, h * 0.36)
      // ── waist crossing right→left ──
      ..cubicTo(w * 0.64, h * 0.40, w * 0.84, h * 0.42, w * 0.90, h * 0.58)
      // ── right side of base ──
      ..cubicTo(w * 0.96, h * 0.78, w * 0.86, h * 0.98, w * 0.50, h * 0.98)
      ..close();

    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFF52E87A),
          const Color(0xFF00A651),
          const Color(0xFF006B32),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    // Subtle drop shadow
    canvas.drawPath(
      flame,
      Paint()
        ..color = const Color(0xFF00843F).withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.drawPath(flame, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// v5 — Realistic flame: asymmetric, tapered, flowing curves ──────────────────
class _RealFlamePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Rect bounds = Rect.fromLTWH(0, 0, w, h);

    final Paint gradPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFFFFF176),
          Color(0xFFFF8F00),
          Color(0xFFE53935),
        ],
        stops: <double>[0.0, 0.42, 1.0],
      ).createShader(bounds);

    // Outer silhouette — one dominant center tip, right lean, organic asymmetry
    final Path outer = Path()
      ..moveTo(w * 0.50, h * 1.00)
      // left base → up left side
      ..cubicTo(w * 0.16, h * 1.00, w * 0.04, h * 0.76, w * 0.12, h * 0.54)
      ..cubicTo(w * 0.18, h * 0.38, w * 0.26, h * 0.30, w * 0.28, h * 0.20)
      // left wisp — short curl, like a secondary tongue
      ..cubicTo(w * 0.28, h * 0.10, w * 0.34, h * 0.04, w * 0.36, h * 0.10)
      ..cubicTo(w * 0.38, h * 0.16, w * 0.38, h * 0.26, w * 0.40, h * 0.32)
      // flow inward to the main tip (tallest, slightly right of center)
      ..cubicTo(w * 0.43, h * 0.20, w * 0.47, h * 0.06, w * 0.52, h * 0.00)
      // down the right side of main tip
      ..cubicTo(w * 0.57, h * 0.06, w * 0.60, h * 0.16, w * 0.63, h * 0.24)
      // right shoulder — broader, softer
      ..cubicTo(w * 0.68, h * 0.16, w * 0.72, h * 0.10, w * 0.74, h * 0.16)
      ..cubicTo(w * 0.76, h * 0.22, w * 0.74, h * 0.34, w * 0.78, h * 0.44)
      ..cubicTo(w * 0.84, h * 0.56, w * 0.92, h * 0.72, w * 0.88, h * 0.86)
      ..cubicTo(w * 0.84, h * 1.00, w * 0.72, h * 1.00, w * 0.50, h * 1.00)
      ..close();

    // Soft shadow for depth
    canvas.drawPath(
      outer,
      Paint()
        ..color = const Color(0xFFBF360C).withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    canvas.drawPath(outer, gradPaint);

    // Bright inner core — tear shape, offset slightly up-left
    final Path core = Path()
      ..moveTo(w * 0.49, h * 0.26)
      ..cubicTo(w * 0.60, h * 0.38, w * 0.62, h * 0.60, w * 0.56, h * 0.74)
      ..cubicTo(w * 0.52, h * 0.83, w * 0.44, h * 0.83, w * 0.42, h * 0.74)
      ..cubicTo(w * 0.36, h * 0.60, w * 0.38, h * 0.38, w * 0.49, h * 0.26)
      ..close();

    canvas.drawPath(
      core,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.90),
            const Color(0xFFFFCC02).withValues(alpha: 0.60),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.50, 1.0],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _SparkBurstPainter extends CustomPainter {  // v1 — starburst + embers (saved)
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.5;
    final double cy = size.height * 0.5;
    final double outerR = size.width * 0.38;
    final double innerR = size.width * 0.15;

    final Paint p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Campfire spark — 8-point irregular starburst
    // Outer radii vary for organic feel
    const List<double> outerMult = <double>[1.00, 0.82, 1.00, 0.78, 1.00, 0.80, 1.00, 0.76];
    const int pts = 8;
    final Path star = Path();
    for (int i = 0; i < pts; i++) {
      final double outerAngle = (2 * pi * i / pts) - pi / 2;
      final double innerAngle = outerAngle + pi / pts;
      final double or_ = outerR * outerMult[i];
      final double ox = cx + or_ * cos(outerAngle);
      final double oy = cy + or_ * sin(outerAngle);
      final double ix = cx + innerR * cos(innerAngle);
      final double iy = cy + innerR * sin(innerAngle);
      if (i == 0) {
        star.moveTo(ox, oy);
      } else {
        star.lineTo(ox, oy);
      }
      star.lineTo(ix, iy);
    }
    star.close();
    canvas.drawPath(star, p);

    // Flying embers
    final Paint ember = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx + size.width * 0.34, cy - size.height * 0.30), size.width * 0.055, ember);
    canvas.drawCircle(Offset(cx - size.width * 0.30, cy - size.height * 0.28), size.width * 0.040, ember);
    canvas.drawCircle(Offset(cx + size.width * 0.12, cy + size.height * 0.36), size.width * 0.038, ember);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// v2 — Spark NZ style: bundle of crossing strokes through a center point
class _SparkCrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.5;
    final double cy = size.height * 0.5;

    // 10 lines at staggered angles — all cross the center, varying lengths
    const List<double> angleDeg = <double>[0, 18, 36, 54, 72, 90, 108, 126, 144, 162];
    const List<double> radMult  = <double>[0.45, 0.36, 0.43, 0.34, 0.46, 0.38, 0.44, 0.33, 0.45, 0.37];

    final Paint stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.10;

    for (int i = 0; i < angleDeg.length; i++) {
      final double a = angleDeg[i] * pi / 180;
      final double r = size.width * radMult[i];
      canvas.drawLine(
        Offset(cx - r * cos(a), cy - r * sin(a)),
        Offset(cx + r * cos(a), cy + r * sin(a)),
        stroke,
      );
    }

    // Small bright dot at center to anchor the burst
    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.08,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// v3 — Pearl: iridescent circle with highlight lustre
class _PearlPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.5;
    final double cy = size.height * 0.5;
    final double r  = size.width * 0.37;

    // Pearl body — soft blue-white iridescent gradient
    final Rect bodyRect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final Paint body = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.25, -0.35),
        radius: 1.0,
        colors: <Color>[
          Color(0xFFFFFFFF),
          Color(0xFFE4EEF7),
          Color(0xFFC3D8EC),
          Color(0xFFABC4DC),
        ],
        stops: <double>[0.0, 0.30, 0.65, 1.0],
      ).createShader(bodyRect);
    canvas.drawCircle(Offset(cx, cy), r, body);

    // Primary highlight — crisp white spot upper-left
    final Offset h1 = Offset(cx - r * 0.30, cy - r * 0.32);
    final Paint hi1 = Paint()
      ..shader = RadialGradient(
        colors: <Color>[Colors.white, Colors.white.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: h1, radius: r * 0.38));
    canvas.drawCircle(h1, r * 0.38, hi1);

    // Secondary soft glow — bottom right
    final Offset h2 = Offset(cx + r * 0.22, cy + r * 0.28);
    canvas.drawCircle(
      h2,
      r * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
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

