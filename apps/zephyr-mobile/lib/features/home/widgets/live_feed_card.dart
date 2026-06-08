import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../flags.dart';
import '../../../models/models.dart';
import '../../../services/firebase_chat_service.dart';
import '../host_card_cover_assets.dart';

/// A card displaying a user's live/online status, used in all feed tabs.
class LiveFeedCardWidget extends StatelessWidget {
  const LiveFeedCardWidget({
    super.key,
    required this.feedCard,
    required this.isTablet,
    this.showPreview = true,
    this.isJoining = false,
    this.borderRadius,
    this.coverAsset,
    this.onTap,
    this.onProfileTap,
    this.livePreviewWidget,
  });

  final LiveFeedCard feedCard;
  final bool isTablet;
  final bool showPreview;
  final bool isJoining;
  final double? borderRadius;
  final String? coverAsset;
  final VoidCallback? onTap;
  final VoidCallback? onProfileTap;
  final Widget? livePreviewWidget;

  @override
  Widget build(BuildContext context) {
    final double cardRadius = borderRadius ?? (isTablet ? 44 : 34);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final double cardTopShade = isDarkMode ? 0.30 : 0.42;
    final double cardMiddleShade = isDarkMode ? 0.10 : 0.20;
    final double cardBottomShade = isDarkMode ? 0.60 : 0.82;
    final double cardTint = isDarkMode ? 0.08 : 0.18;
    final Color? cardContour = isDarkMode
        ? const Color(0xFFFFA726).withValues(alpha: 0.20)
        : null;

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
          final String avatarUrl =
              (profile?.avatarUrl ?? feedCard.hostAvatarUrl ?? '').trim();
          final String avatarInitial = displayName.trim().isEmpty
              ? '?'
              : displayName.trim().substring(0, 1).toUpperCase();
          final String countryCode = profile?.countryCode.isNotEmpty == true
              ? profile!.countryCode
              : feedCard.hostCountryCode;
          final String language = profile?.language.isNotEmpty == true
              ? profile!.language
              : feedCard.hostLanguage;
          final String localeLine = showPreview
              ? '${CountryFlags.flagEmoji(countryCode)} $countryCode $language'
              : '${CountryFlags.flagEmoji(countryCode)} $countryCode';
          final String fallbackCoverAsset = HostCardCoverAssets.forUser(
            userId: feedCard.hostUserId,
            displayName: feedCard.hostDisplayName,
            countryCode: feedCard.hostCountryCode,
          );
          final String coverSource =
              (coverAsset ?? feedCard.hostCoverUrl ?? fallbackCoverAsset)
                  .trim();
          final String? cachedPresence = FirebaseChatService.instance
              .presenceStateCached(feedCard.hostUserId)
              ?.trim()
              .toLowerCase();
          final String feedStatus = feedCard.hostStatus.trim().toLowerCase();
          final bool hasLiveRoom =
              (feedCard.roomId?.trim().isNotEmpty ?? false);
          String status = cachedPresence ?? feedStatus;
          if (hasLiveRoom &&
              (feedStatus == 'live' || feedStatus == 'premium_live')) {
            status = feedStatus;
          } else if (hasLiveRoom &&
              (status.isEmpty ||
                  status == 'offline' ||
                  status == 'online' ||
                  status == 'away')) {
            status = 'live';
          }
          final bool isLive = status == 'live' || status == 'premium_live';
          final String viewerCountLabel = _formatViewerCount(
            feedCard.audienceCount,
          );
          final DateTime? demoNextRotationAt = FirebaseChatService.instance
              .demoNextRotationAtCached(feedCard.hostUserId);

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
            borderRadius: BorderRadius.circular(cardRadius),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(cardRadius),
              child: InkWell(
                borderRadius: BorderRadius.circular(cardRadius),
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
                      Positioned.fill(
                        child: _HostCoverImage(
                          source: coverSource,
                          fallbackAsset: fallbackCoverAsset,
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Colors.black.withValues(alpha: cardTopShade),
                                const Color(
                                  0xFF171328,
                                ).withValues(alpha: cardMiddleShade),
                                Colors.black.withValues(alpha: cardBottomShade),
                              ],
                              stops: const <double>[0.0, 0.48, 1.0],
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF120E22,
                            ).withValues(alpha: cardTint),
                          ),
                        ),
                      ),
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
                      if (!showPreview && isLive)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: _ViewerCountBadge(label: viewerCountLabel),
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
                      if (demoNextRotationAt != null)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Center(
                              child: Transform.translate(
                                offset: const Offset(0, -8),
                                child: _DemoRotationCountdown(
                                  nextRotationAt: demoNextRotationAt,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 12,
                        left: 16,
                        right: 16,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onProfileTap,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              _HostCardAvatar(
                                avatarUrl: avatarUrl,
                                fallbackText: avatarInitial,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: SizedBox(
                                  height: 28,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                          height: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        localeLine,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 11.5,
                                          height: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (cardContour != null)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(cardRadius),
                                border: Border.all(
                                  color: cardContour,
                                  width: 1,
                                ),
                              ),
                            ),
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

class _DemoRotationCountdown extends StatefulWidget {
  const _DemoRotationCountdown({required this.nextRotationAt});

  final DateTime nextRotationAt;

  @override
  State<_DemoRotationCountdown> createState() => _DemoRotationCountdownState();
}

class _DemoRotationCountdownState extends State<_DemoRotationCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Duration remaining = widget.nextRotationAt.difference(DateTime.now());
    final int seconds = remaining.inSeconds.clamp(0, 999);
    final String label = seconds == 0
        ? 'Switching'
        : 'Next ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFFFA726).withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.timer_rounded, color: Color(0xFFFFB74D), size: 13),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatViewerCount(int value) {
  if (value >= 1000000) {
    final double compact = value / 1000000;
    return '${compact.toStringAsFixed(compact >= 10 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    final double compact = value / 1000;
    return '${compact.toStringAsFixed(compact >= 10 ? 0 : 1)}K';
  }
  return value.toString();
}

class _ViewerCountBadge extends StatelessWidget {
  const _ViewerCountBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.visibility_rounded, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HostCoverImage extends StatelessWidget {
  const _HostCoverImage({required this.source, required this.fallbackAsset});

  final String source;
  final String fallbackAsset;

  @override
  Widget build(BuildContext context) {
    if (HostCardCoverAssets.isBundledAsset(source)) {
      return Image.asset(
        source,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      );
    }

    return CachedNetworkImage(
      imageUrl: source,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      fadeInDuration: const Duration(milliseconds: 120),
      errorWidget: (context, _, __) => Image.asset(
        fallbackAsset,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

class _HostCardAvatar extends StatelessWidget {
  const _HostCardAvatar({required this.avatarUrl, required this.fallbackText});

  final String avatarUrl;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final bool hasAvatar = avatarUrl.isNotEmpty;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.34),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 14,
        backgroundColor: const Color(0xFF3A3147),
        backgroundImage: hasAvatar
            ? CachedNetworkImageProvider(avatarUrl)
            : null,
        child: hasAvatar
            ? null
            : Text(
                fallbackText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}
