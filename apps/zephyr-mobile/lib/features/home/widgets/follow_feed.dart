import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../../../l10n/app_localizations.dart';
import 'host_card_grid.dart';

class FollowFeed extends StatelessWidget {
  const FollowFeed({
    super.key,
    required this.cards,
    required this.followingIds,
    required this.filterCountryName,
    required this.isTablet,
    required this.onCardTap,
    required this.onRandomMatch,
    required this.showRandomMatch,
  });

  final List<LiveFeedCard> cards;
  final Set<String> followingIds;
  final String? filterCountryName;
  final bool isTablet;
  final void Function(LiveFeedCard) onCardTap;
  final VoidCallback onRandomMatch;
  final bool showRandomMatch;

  @override
  Widget build(BuildContext context) {
    final List<LiveFeedCard> followed = cards
        .where((LiveFeedCard c) => followingIds.contains(c.hostUserId))
        .toList();

    if (followingIds.isEmpty || followed.isEmpty) {
      return Stack(
        children: <Widget>[
          Center(
            child: Text(
              followingIds.isEmpty
                  ? AppLocalizations.of(context)!.followSomeoneToSeeThemHere
                  : AppLocalizations.of(context)!.noneOfPeopleYouFollowAreLive(
                      filterCountryName ?? 'there',
                    ),
              textAlign: TextAlign.center,
            ),
          ),
          if (showRandomMatch) _RandomMatchButton(onPressed: onRandomMatch),
        ],
      );
    }

    return Stack(
      children: <Widget>[
        HostCardGrid(cards: followed, isTablet: isTablet, onCardTap: onCardTap),
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
