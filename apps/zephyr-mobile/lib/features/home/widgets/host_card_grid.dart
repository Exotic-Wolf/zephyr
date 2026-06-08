import 'package:flutter/material.dart';

import '../../../models/models.dart';
import 'live_feed_card.dart';

class HostCardGrid extends StatelessWidget {
  const HostCardGrid({
    super.key,
    required this.cards,
    required this.isTablet,
    required this.onCardTap,
    required this.onProfileTap,
    this.joiningRoomId,
    this.onLoadMore,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final List<LiveFeedCard> cards;
  final bool isTablet;
  final void Function(LiveFeedCard) onCardTap;
  final void Function(LiveFeedCard) onProfileTap;
  final String? joiningRoomId;
  final VoidCallback? onLoadMore;
  final bool hasMore;
  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SizedBox.expand();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const double gap = 4;
        const EdgeInsets padding = EdgeInsets.all(4);
        final double gridHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final double cardHeight = ((gridHeight - padding.vertical - gap) / 2)
            .clamp(220, 520);

        return NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification notification) {
            if (hasMore &&
                !isLoadingMore &&
                notification.metrics.extentAfter < cardHeight * 1.5) {
              onLoadMore?.call();
            }
            return false;
          },
          child: GridView.builder(
            padding: padding,
            physics: const AlwaysScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: gap,
              mainAxisSpacing: gap,
              mainAxisExtent: cardHeight,
            ),
            itemCount: cards.length,
            itemBuilder: (BuildContext context, int index) {
              final LiveFeedCard card = cards[index];
              return LiveFeedCardWidget(
                feedCard: card,
                isTablet: isTablet,
                showPreview: false,
                isJoining: card.roomId != null && card.roomId == joiningRoomId,
                borderRadius: isTablet ? 10 : 7,
                onTap: () => onCardTap(card),
                onProfileTap: () => onProfileTap(card),
              );
            },
          ),
        );
      },
    );
  }
}
