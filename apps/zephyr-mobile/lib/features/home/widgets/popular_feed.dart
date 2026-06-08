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
    required this.onRandomMatch,
    required this.showRandomMatch,
  });

  final List<LiveFeedCard> cards;
  final bool allCardsEmpty;
  final String searchQuery;
  final String? filterCountryName;
  final bool isTablet;
  final void Function(LiveFeedCard) onCardTap;
  final VoidCallback onRandomMatch;
  final bool showRandomMatch;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return Stack(
        children: <Widget>[
          Center(
            child: Text(
              allCardsEmpty
                  ? AppLocalizations.of(context)!.noPopularStreamersRightNow
                  : searchQuery.isNotEmpty
                  ? AppLocalizations.of(context)!.noResultsFor(searchQuery)
                  : AppLocalizations.of(
                      context,
                    )!.noStreamersFrom(filterCountryName ?? 'there'),
              textAlign: TextAlign.center,
            ),
          ),
          if (showRandomMatch) _RandomMatchButton(onPressed: onRandomMatch),
        ],
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
            );
          },
        ),
        if (showRandomMatch) _RandomMatchButton(onPressed: onRandomMatch),
      ],
    );
  }
}

class _RandomMatchButton extends StatelessWidget {
  const _RandomMatchButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Center(
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7BEA3B),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text('Random match'),
        ),
      ),
    );
  }
}
