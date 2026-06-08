import 'package:flutter/material.dart';

import '../../../models/models.dart';
import 'host_card_grid.dart';

class ForYouFeed extends StatelessWidget {
  const ForYouFeed({
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
    return HostCardGrid(cards: cards, isTablet: isTablet, onCardTap: onCardTap);
  }
}
