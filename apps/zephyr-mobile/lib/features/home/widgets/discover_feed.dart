import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../../../l10n/app_localizations.dart';
import 'live_feed_card.dart';

class DiscoverFeed extends StatelessWidget {
  const DiscoverFeed({
    super.key,
    required this.cards,
    required this.allCardsEmpty,
    required this.searchQuery,
    required this.filterCountryName,
    required this.isTablet,
    required this.pageController,
    required this.onPageChanged,
    required this.onCardTap,
    required this.onCallTap,
    required this.onRandomMatch,
    this.joiningRoomId,
  });

  final List<LiveFeedCard> cards;
  final bool allCardsEmpty;
  final String searchQuery;
  final String? filterCountryName;
  final bool isTablet;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final void Function(LiveFeedCard) onCardTap;
  final void Function(LiveFeedCard) onCallTap;
  final VoidCallback onRandomMatch;
  final String? joiningRoomId;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return Center(
        child: Text(
          allCardsEmpty
              ? AppLocalizations.of(context)!.noOneIsLiveRightNow
              : searchQuery.isNotEmpty
                  ? AppLocalizations.of(context)!.noResultsFor(searchQuery)
                  : AppLocalizations.of(context)!.noOneIsLiveFrom(filterCountryName ?? 'there'),
        ),
      );
    }

    return Stack(
      children: <Widget>[
        PageView.builder(
          controller: pageController,
          scrollDirection: Axis.vertical,
          itemCount: cards.length,
          onPageChanged: onPageChanged,
          itemBuilder: (BuildContext context, int index) {
            final LiveFeedCard card = cards[index];
            return Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 18),
              child: LiveFeedCardWidget(
                feedCard: card,
                isTablet: isTablet,
                showPreview: true,
                isJoining: card.roomId != null && joiningRoomId == card.roomId,
                onTap: () => onCardTap(card),
                onCallTap: () => onCallTap(card),
              ),
            );
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Center(
            child: FilledButton(
              onPressed: onRandomMatch,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7BEA3B),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Random match'),
            ),
          ),
        ),
      ],
    );
  }
}
