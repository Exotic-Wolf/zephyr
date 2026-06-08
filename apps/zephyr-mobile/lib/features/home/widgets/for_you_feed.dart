import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/models.dart';
import 'host_card_grid.dart';

class ForYouFeed extends StatelessWidget {
  const ForYouFeed({
    super.key,
    required this.cards,
    required this.isTablet,
    required this.onCardTap,
    required this.onProfileTap,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onRandomMatch,
    required this.showRandomMatch,
    required this.hasMore,
    required this.isLoadingMore,
    this.joiningRoomId,
  });

  final List<LiveFeedCard> cards;
  final bool isTablet;
  final void Function(LiveFeedCard) onCardTap;
  final void Function(LiveFeedCard) onProfileTap;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final VoidCallback onRandomMatch;
  final bool showRandomMatch;
  final bool hasMore;
  final bool isLoadingMore;
  final String? joiningRoomId;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: _ForYouEmptyState(
                  onRandomMatch: onRandomMatch,
                  showRandomMatch: showRandomMatch,
                ),
              ),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Stack(
        children: <Widget>[
          HostCardGrid(
            cards: cards,
            isTablet: isTablet,
            onCardTap: onCardTap,
            onProfileTap: onProfileTap,
            joiningRoomId: joiningRoomId,
            onLoadMore: onLoadMore,
            hasMore: hasMore,
            isLoadingMore: isLoadingMore,
          ),
          if (isLoadingMore)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Center(child: _LoadingMorePill()),
            ),
        ],
      ),
    );
  }
}

class _ForYouEmptyState extends StatelessWidget {
  const _ForYouEmptyState({
    required this.onRandomMatch,
    required this.showRandomMatch,
  });

  final VoidCallback onRandomMatch;
  final bool showRandomMatch;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF8F00).withValues(alpha: 0.14),
              ),
              child: const Icon(
                Icons.live_tv_rounded,
                color: Color(0xFFFF8F00),
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noOneIsLiveRightNow,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (showRandomMatch) ...<Widget>[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onRandomMatch,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7BEA3B),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                ),
                child: const Text('Random match'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingMorePill extends StatelessWidget {
  const _LoadingMorePill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
