import 'dart:math' show cos, pi, sin;
import 'package:flutter/material.dart';

// ── Shared live helpers ───────────────────────────────────────────────────────

class LiveComment {
  LiveComment({required this.name, required this.text});
  final String name;
  final String text;
}

class FloatingGift {
  FloatingGift({required this.id, required this.emoji});
  final String id;
  final String emoji;
}

class FloatingGiftWidget extends StatefulWidget {
  const FloatingGiftWidget({required this.gift});
  final FloatingGift gift;
  @override
  State<FloatingGiftWidget> createState() => FloatingGiftWidgetState();
}

class FloatingGiftWidgetState extends State<FloatingGiftWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..forward();
    _opacity = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.6, 1.0)));
    _offset = Tween<double>(begin: 0, end: -120).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 60,
      bottom: 200,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, _offset.value),
          child: Opacity(
            opacity: _opacity.value,
            child: Text(widget.gift.emoji, style: const TextStyle(fontSize: 40)),
          ),
        ),
      ),
    );
  }
}

class LiveCtrlBtn extends StatelessWidget {
  const LiveCtrlBtn({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: active ? Colors.white24 : Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: active ? Colors.white : Colors.white38, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }
}

