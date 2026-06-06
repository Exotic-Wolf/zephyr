import 'package:flutter/material.dart';

import '../../../flags.dart';
import '../../../models/models.dart';
import '../../../services/firebase_chat_service.dart';
import 'shake_call_button.dart';

/// A card displaying a user's live/online status, used in all feed tabs.
class LiveFeedCardWidget extends StatelessWidget {
  const LiveFeedCardWidget({
    super.key,
    required this.feedCard,
    required this.isTablet,
    this.showPreview = true,
    this.isJoining = false,
    this.onTap,
    this.onCallTap,
    this.livePreviewWidget,
  });

  final LiveFeedCard feedCard;
  final bool isTablet;
  final bool showPreview;
  final bool isJoining;
  final VoidCallback? onTap;
  final VoidCallback? onCallTap;
  final Widget? livePreviewWidget;

  @override
  Widget build(BuildContext context) {
    final double borderRadius = isTablet ? 44 : 34;

    return ValueListenableBuilder<int>(
      valueListenable: FirebaseChatService.instance.presenceVersion,
      builder: (context, _, __) => ValueListenableBuilder<int>(
        valueListenable: FirebaseChatService.instance.profileVersion,
        builder: (context, _, __) {
          final profile = FirebaseChatService.instance.profileCached(
            feedCard.hostUserId,
          );
          final String displayName =
              profile?.displayName ?? feedCard.hostDisplayName;
          final String countryCode = profile?.countryCode.isNotEmpty == true
              ? profile!.countryCode
              : feedCard.hostCountryCode;
          final String language = profile?.language.isNotEmpty == true
              ? profile!.language
              : feedCard.hostLanguage;
          final String localeLine = showPreview
              ? '${CountryFlags.flagEmoji(countryCode)} $countryCode $language'
              : '${CountryFlags.flagEmoji(countryCode)} $countryCode';
          final String status =
              FirebaseChatService.instance.presenceStateCached(
                feedCard.hostUserId,
              ) ??
              feedCard.hostStatus;
          final bool isLive = status == 'live' || status == 'premium_live';

          final Color statusDot = switch (status) {
            'premium_live' => const Color(0xFFFF2D55),
            'live' => const Color(0xFFFF3B30),
            'busy' => const Color(0xFFFF9500),
            'away' => const Color(0xFFFFCC00),
            'offline' => const Color(0xFF8E8E93),
            _ => const Color(0xFF34C759),
          };
          final String statusLabel = switch (status) {
            'premium_live' => 'Premium',
            'live' => 'Live',
            'busy' => 'Busy',
            'away' => 'Away',
            'offline' => 'Offline',
            _ => 'Online',
          };
          final bool isAway = status == 'away';

          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(borderRadius),
              child: InkWell(
                borderRadius: BorderRadius.circular(borderRadius),
                onTap: isJoining ? null : onTap,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[Color(0xFF1C1C2E), Color(0xFF2D2D44)],
                    ),
                  ),
                  child: Stack(
                    children: <Widget>[
                      // ── top-left status badge
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (showPreview) ...[
                                const Icon(
                                  Icons.videocam_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                              ],
                              if (isAway)
                                Icon(
                                  Icons.nightlight_round,
                                  color: statusDot,
                                  size: 10,
                                )
                              else
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: statusDot,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              const SizedBox(width: 4),
                              Text(
                                statusLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // ── joining overlay
                      Positioned(
                        top: 20,
                        left: 20,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: isJoining ? 1 : 0,
                          child: const Text(
                            'Opening live...',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      // ── preview box — only shown when Live
                      if (isLive && showPreview)
                        Positioned(
                          top: 20,
                          right: 20,
                          child:
                              livePreviewWidget ??
                              Container(
                                width: isTablet ? 150 : 100,
                                height: isTablet ? 180 : 130,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                        ),
                      Positioned(
                        bottom: 12,
                        left: 16,
                        right: 4,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    localeLine,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (onCallTap != null)
                              ShakeCallButton(onTap: onCallTap!),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
