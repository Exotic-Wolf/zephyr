import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import 'coin_icon.dart';
import 'spark_icon.dart';

class ZephyrAppHeader extends StatelessWidget {
  const ZephyrAppHeader({
    super.key,
    required this.me,
    required this.wallet,
    required this.onAvatarTap,
    required this.onRechargeTap,
    this.apiReachable,
  });

  final UserProfile? me;
  final WalletSummary? wallet;
  final VoidCallback onAvatarTap;
  final VoidCallback? onRechargeTap;
  final bool? apiReachable;

  @override
  Widget build(BuildContext context) {
    final bool isHost = me?.isHost == true;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color pillColor = isDark
        ? const Color(0xFF211A24)
        : const Color(0xFFF3F1F6);
    final Color borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final int? balance = wallet == null
        ? null
        : isHost
        ? wallet!.sparkBalance
        : wallet!.coinBalance;

    return SizedBox(
      height: 44,
      child: Row(
        children: <Widget>[
          _HeaderAvatar(
            avatarUrl: me?.avatarUrl,
            apiReachable: apiReachable,
            onTap: onAvatarTap,
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: isHost ? null : onRechargeTap,
              child: Semantics(
                button: !isHost && onRechargeTap != null,
                label: isHost ? 'Spark balance' : 'Coin balance',
                child: Container(
                  height: 34,
                  padding: EdgeInsets.only(left: 10, right: isHost ? 12 : 5),
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      isHost
                          ? const SparkIcon(size: 18)
                          : const CoinIcon(size: 18),
                      const SizedBox(width: 7),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 88),
                        child: Text(
                          balance == null ? '--' : _formatAmount(balance),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                      if (!isHost && onRechargeTap != null) ...<Widget>[
                        const SizedBox(width: 7),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Color(0xFF68F23B),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.black,
                            size: 18,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  static String _formatAmount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({
    required this.avatarUrl,
    required this.apiReachable,
    required this.onTap,
  });

  final String? avatarUrl;
  final bool? apiReachable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? url = avatarUrl?.trim();
    return Semantics(
      button: true,
      label: 'Open profile',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: CircleAvatar(
                  backgroundColor: const Color(0xFF2A2534),
                  backgroundImage: url == null || url.isEmpty
                      ? null
                      : CachedNetworkImageProvider(url),
                  child: url == null || url.isEmpty
                      ? const Icon(
                          Icons.person_rounded,
                          color: Colors.white70,
                          size: 22,
                        )
                      : null,
                ),
              ),
              if (apiReachable != null)
                Positioned(
                  right: 0,
                  bottom: 1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: apiReachable!
                          ? const Color(0xFF38D95A)
                          : const Color(0xFFFF453A),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
