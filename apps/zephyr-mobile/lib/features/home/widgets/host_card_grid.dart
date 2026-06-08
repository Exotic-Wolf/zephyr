import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../host_card_cover_assets.dart';
import 'live_feed_card.dart';

class HostCardGrid extends StatelessWidget {
  const HostCardGrid({
    super.key,
    required this.cards,
    required this.isTablet,
    required this.onCardTap,
  });

  final List<LiveFeedCard> cards;
  final bool isTablet;
  final void Function(LiveFeedCard) onCardTap;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SizedBox.expand();
    }
    final List<String> coverAssets = HostCardCoverAssets.forVisibleGrid(
      cards.map((LiveFeedCard card) => card.hostUserId).toList(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const double gap = 4;
        const EdgeInsets padding = EdgeInsets.all(4);
        final double gridHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final double cardHeight = ((gridHeight - padding.vertical - gap) / 2)
            .clamp(220, 520);

        return GridView.builder(
          padding: padding,
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
              borderRadius: isTablet ? 10 : 7,
              coverAsset: coverAssets[index],
              onTap: () => onCardTap(card),
            );
          },
        );
      },
    );
  }
}
