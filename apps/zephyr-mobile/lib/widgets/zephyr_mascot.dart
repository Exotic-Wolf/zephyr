import 'dart:math';
import 'package:flutter/material.dart';

/// The Zephyr mascot — a chubby flame creature based on the original
/// stuffed toy, with amber→red gradient body, flame on head, dot eyes,
/// little teeth, swirl wisps and sparkles.
class ZephyrMascot extends StatelessWidget {
  const ZephyrMascot({super.key, this.size = 200});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.35,
      child: CustomPaint(painter: _ZephyrMascotPainter()),
    );
  }
}

class _ZephyrMascotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w * 0.5;

    // Layout constants
    final double bodyTop    = h * 0.22;
    final double bodyBottom = h * 0.80;
    final double bodyW      = w * 0.70;

    _drawGlow(canvas, size, cx, h);
    _drawSwirls(canvas, size, cx, h);
    _drawBody(canvas, size, cx, bodyTop, bodyBottom, bodyW);
    _drawFeet(canvas, size, cx, bodyBottom);
    _drawFlame(canvas, size, cx, bodyTop);
    _drawEyes(canvas, size, cx, h);
    _drawMouth(canvas, size, cx, h);
    _drawSparkles(canvas, size);
  }

  // ── Radial ambient glow ────────────────────────────────────────────────────
  void _drawGlow(Canvas canvas, Size size, double cx, double h) {
    final Paint p = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF8F00).withValues(alpha: 0.30),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCenter(
        center: Offset(cx, h * 0.55),
        width: size.width * 1.4,
        height: h * 1.0,
      ));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h * 0.55), width: size.width * 1.3, height: h * 0.9),
      p,
    );
  }

  // ── Swirling wind wisps ────────────────────────────────────────────────────
  void _drawSwirls(Canvas canvas, Size size, double cx, double h) {
    final double w = size.width;
    final Paint p = Paint()
      ..color = const Color(0xFFFF5722).withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.020
      ..strokeCap = StrokeCap.round;

    // Left swirl
    final Path left = Path()
      ..moveTo(cx - w * 0.48, h * 0.60)
      ..cubicTo(cx - w * 0.52, h * 0.44, cx - w * 0.34, h * 0.33, cx - w * 0.06, h * 0.44);
    canvas.drawPath(left, p);

    // Right swirl
    final Path right = Path()
      ..moveTo(cx + w * 0.48, h * 0.60)
      ..cubicTo(cx + w * 0.52, h * 0.44, cx + w * 0.34, h * 0.33, cx + w * 0.06, h * 0.44);
    canvas.drawPath(right, p);

    // Bottom fade-out wisp left
    final Paint p2 = Paint()
      ..color = const Color(0xFFE53935).withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.014
      ..strokeCap = StrokeCap.round;
    final Path botLeft = Path()
      ..moveTo(cx - w * 0.38, h * 0.75)
      ..cubicTo(cx - w * 0.42, h * 0.68, cx - w * 0.30, h * 0.64, cx - w * 0.18, h * 0.68);
    canvas.drawPath(botLeft, p2);

    final Path botRight = Path()
      ..moveTo(cx + w * 0.38, h * 0.75)
      ..cubicTo(cx + w * 0.42, h * 0.68, cx + w * 0.30, h * 0.64, cx + w * 0.18, h * 0.68);
    canvas.drawPath(botRight, p2);
  }

  // ── Body blob ──────────────────────────────────────────────────────────────
  void _drawBody(Canvas canvas, Size size, double cx,
      double top, double bottom, double bodyW) {
    final Path body = Path()
      ..moveTo(cx, top + size.height * 0.015)
      ..cubicTo(cx + bodyW * 0.62, top, cx + bodyW * 0.58, bottom - size.height * 0.08, cx, bottom)
      ..cubicTo(cx - bodyW * 0.58, bottom - size.height * 0.08, cx - bodyW * 0.62, top, cx, top + size.height * 0.015)
      ..close();

    final Paint fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFFFFF176), Color(0xFFFF8F00), Color(0xFFE53935)],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(Rect.fromLTWH(cx - bodyW * 0.62, top, bodyW * 1.24, bottom - top));
    canvas.drawPath(body, fill);

    // Subtle highlight on upper-left
    final Paint highlight = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.5),
        radius: 0.7,
        colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(cx - bodyW * 0.62, top, bodyW * 1.24, bottom - top));
    canvas.drawPath(body, highlight);

    // Outline
    final Paint outline = Paint()
      ..color = const Color(0xFFBB3300).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.013;
    canvas.drawPath(body, outline);
  }

  // ── Feet ───────────────────────────────────────────────────────────────────
  void _drawFeet(Canvas canvas, Size size, double cx, double bodyBottom) {
    final double w = size.width;
    final Paint fill = Paint()..color = const Color(0xFFCC3300);
    final Paint outline = Paint()
      ..color = const Color(0xFF991100).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.010;

    for (final double side in <double>[-1, 1]) {
      final Rect r = Rect.fromCenter(
        center: Offset(cx + side * w * 0.17, bodyBottom + w * 0.045),
        width: w * 0.19,
        height: w * 0.095,
      );
      final RRect rr = RRect.fromRectAndRadius(r, const Radius.circular(20));
      canvas.drawRRect(rr, fill);
      canvas.drawRRect(rr, outline);
    }
  }

  // ── Flame on head ──────────────────────────────────────────────────────────
  void _drawFlame(Canvas canvas, Size size, double cx, double bodyTop) {
    final double w = size.width;
    final double h = size.height;
    final double base   = bodyTop + h * 0.022;
    final double tip    = bodyTop - h * 0.16;
    final double tipMid = bodyTop - h * 0.10;

    // Outer flame
    final Path flame = Path()
      ..moveTo(cx - w * 0.075, base)
      ..cubicTo(cx - w * 0.13, tipMid, cx - w * 0.035, tip + h * 0.03, cx, tip)
      ..cubicTo(cx + w * 0.035, tip + h * 0.03, cx + w * 0.13, tipMid, cx + w * 0.075, base)
      ..close();

    final Paint flameFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: const [Color(0xFFFF8F00), Color(0xFFFFF176)],
      ).createShader(Rect.fromLTWH(cx - w * 0.13, tip, w * 0.26, base - tip));
    canvas.drawPath(flame, flameFill);

    // Inner glow core
    final Path inner = Path()
      ..moveTo(cx - w * 0.030, base - h * 0.005)
      ..cubicTo(cx - w * 0.038, tipMid + h * 0.03, cx - w * 0.005, tip + h * 0.04, cx + w * 0.010, tipMid)
      ..cubicTo(cx + w * 0.030, tipMid + h * 0.02, cx + w * 0.030, base - h * 0.005, cx - w * 0.030, base - h * 0.005)
      ..close();
    canvas.drawPath(inner, Paint()..color = Colors.white.withValues(alpha: 0.35));
  }

  // ── Eyes ───────────────────────────────────────────────────────────────────
  void _drawEyes(Canvas canvas, Size size, double cx, double h) {
    final double w = size.width;
    final double eyeY = h * 0.455;
    final double r    = w * 0.042;

    final Paint dark  = Paint()..color = const Color(0xFF180800);
    final Paint shine = Paint()..color = Colors.white.withValues(alpha: 0.75);

    for (final double side in <double>[-1, 1]) {
      final Offset center = Offset(cx + side * w * 0.105, eyeY);
      canvas.drawCircle(center, r, dark);
      canvas.drawCircle(Offset(center.dx + w * 0.015 * side.sign, eyeY - r * 0.32), r * 0.34, shine);
    }
  }

  // ── Mouth + teeth ──────────────────────────────────────────────────────────
  void _drawMouth(Canvas canvas, Size size, double cx, double h) {
    final double w = size.width;
    final double mY = h * 0.535;

    // Smile arc
    final Paint mPaint = Paint()
      ..color = const Color(0xFF180800)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.024
      ..strokeCap = StrokeCap.round;
    final Path mouth = Path()
      ..moveTo(cx - w * 0.115, mY)
      ..quadraticBezierTo(cx, mY + h * 0.038, cx + w * 0.115, mY);
    canvas.drawPath(mouth, mPaint);

    // 3 small downward teeth
    final Paint teeth = Paint()..color = Colors.white;
    final double tW = w * 0.036;
    final double tH = h * 0.032;
    for (int i = -1; i <= 1; i++) {
      final double tx = cx + i * w * 0.052;
      final Path tooth = Path()
        ..moveTo(tx - tW / 2, mY + h * 0.004)
        ..lineTo(tx + tW / 2, mY + h * 0.004)
        ..lineTo(tx, mY + tH)
        ..close();
      canvas.drawPath(tooth, teeth);
    }
  }

  // ── 4-point sparkles ───────────────────────────────────────────────────────
  void _drawSparkles(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final List<_Sparkle> sparkles = <_Sparkle>[
      _Sparkle(Offset(w * 0.84, h * 0.18), w * 0.040, 0.90),
      _Sparkle(Offset(w * 0.13, h * 0.23), w * 0.026, 0.70),
      _Sparkle(Offset(w * 0.90, h * 0.50), w * 0.022, 0.55),
      _Sparkle(Offset(w * 0.06, h * 0.62), w * 0.028, 0.65),
    ];
    for (final _Sparkle s in sparkles) {
      _drawSparkle(canvas, s.offset, s.size, s.alpha);
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double sz, double alpha) {
    final Paint paint = Paint()
      ..color = const Color(0xFFFFF176).withValues(alpha: alpha);
    final Path path = Path();
    for (int i = 0; i < 4; i++) {
      final double a     = i * pi / 2 - pi / 4;
      final double aNext = a + pi / 2;
      final double inner = sz * 0.22;
      final Offset tip   = Offset(center.dx + cos(a + pi / 4) * sz, center.dy + sin(a + pi / 4) * sz);
      final Offset p1    = Offset(center.dx + cos(a) * inner, center.dy + sin(a) * inner);
      final Offset p2    = Offset(center.dx + cos(aNext) * inner, center.dy + sin(aNext) * inner);
      if (i == 0) path.moveTo(p1.dx, p1.dy);
      path.lineTo(tip.dx, tip.dy);
      path.lineTo(p2.dx, p2.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Sparkle {
  const _Sparkle(this.offset, this.size, this.alpha);
  final Offset offset;
  final double size;
  final double alpha;
}
