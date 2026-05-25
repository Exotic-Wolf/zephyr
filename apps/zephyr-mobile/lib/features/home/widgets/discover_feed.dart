import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../chat/live_preview_widget.dart';
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
    required this.onLivePreviewTap,
    required this.onCallTap,
    required this.onRandomMatch,
    this.joiningRoomId,
    this.activeIndex = 0,
  });

  final List<LiveFeedCard> cards;
  final bool allCardsEmpty;
  final String searchQuery;
  final String? filterCountryName;
  final bool isTablet;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final void Function(LiveFeedCard, RtcEngine, int hostUid, String channelName) onLivePreviewTap;
  final void Function(LiveFeedCard) onCallTap;
  final VoidCallback onRandomMatch;
  final String? joiningRoomId;
  final int activeIndex;

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
            final bool isActive = index == activeIndex;
            return Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 18),
              child: LiveFeedCardWidget(
                feedCard: card,
                isTablet: isTablet,
                showPreview: true,
                isJoining: card.roomId != null && joiningRoomId == card.roomId,
                onCallTap: () => onCallTap(card),
                livePreviewWidget: isActive && card.roomId != null
                    ? LivePreviewWidget(
                        key: ValueKey(card.roomId),
                        roomId: card.roomId!,
                        width: isTablet ? 150 : 100,
                        height: isTablet ? 180 : 130,
                        borderRadius: 20,
                        onTap: (engine, hostUid, channelName) =>
                            onLivePreviewTap(card, engine, hostUid, channelName),
                      )
                    : null,
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
