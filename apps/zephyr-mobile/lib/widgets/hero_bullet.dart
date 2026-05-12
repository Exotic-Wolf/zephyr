import 'package:flutter/material.dart';

class HeroBullet extends StatelessWidget {
  const HeroBullet({super.key, required this.iconWidget, required this.text});
  final Widget iconWidget;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        iconWidget,
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
          ),
        ),
      ],
    );
  }
}

class StatCell extends StatelessWidget {
  const StatCell({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}

