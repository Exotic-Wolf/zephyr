import 'package:flutter/material.dart';

import '../services/firebase_chat_service.dart';

/// A small status indicator dot that updates in real-time via [FirebaseChatService.presenceVersion].
///
/// Usage:
///   StatusDot(userId: 'abc123', size: 12)
///
/// Place inside a Stack with Positioned to overlap an avatar.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.userId, this.size = 12});

  final String userId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: FirebaseChatService.instance.presenceVersion,
      builder: (context, _, __) {
        final String status =
            FirebaseChatService.instance.presenceStateCached(userId) ?? 'offline';
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _colorFor(status),
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).scaffoldBackgroundColor,
              width: 2,
            ),
          ),
        );
      },
    );
  }

  static Color _colorFor(String status) => switch (status) {
        'live' => const Color(0xFFFF3B30),
        'busy' => const Color(0xFFFF9500),
        'online' => const Color(0xFF34C759),
        _ => const Color(0xFF8E8E93),
      };
}
