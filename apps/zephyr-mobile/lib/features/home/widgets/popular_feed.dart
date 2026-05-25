import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../../../l10n/app_localizations.dart';
import 'live_feed_card.dart';

class PopularFeed extends StatelessWidget {
  const PopularFeed({
    super.key,
    required this.cards,
    required this.allCardsEmpty,
    required this.searchQuery,
    required this.filterCountryName,
    required this.isTablet,
    required this.onCardTap,
    required this.onCallTap,
    required this.onRandomMatch,
  });

  final List<LiveFeedCard> cards;
  final bool allCardsEmpty;
  final String searchQuery;
  final String? filterCountryName;
  final bool isTablet;
  final void Function(LiveFeedCard) onCardTap;
  final void Function(LiveFeedCard) onCallTap;
  final VoidCallback onRandomMatch;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return Center(
        child: Text(
          allCardsEmpty
              ? AppLocalizations.of(context)!.noPopularStreamersRightNow
              : searchQuery.isNotEmpty
                  ? AppLocalizations.of(context)!.noResultsFor(searchQuery)
                  : AppLocalizations.of(context)!.noStreamersFrom(filterCountryName ?? 'there'),
        ),
      );
    }

    return Stack(
      children: <Widget>[
        GridView.builder(
          padding: const EdgeInsets.only(bottom: 56),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: isTablet ? 0.72 : 0.62,
          ),
          itemCount: cards.length,
          itemBuilder: (BuildContext context, int index) {
            return LiveFeedCardWidget(
              feedCard: cards[index],
              isTablet: isTablet,
              showPreview: false,
              onTap: () => onCardTap(cards[index]),
              onCallTap: () => onCallTap(cards[index]),
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
