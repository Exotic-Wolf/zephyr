import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_mobile/features/gifts/gift_module.dart';
import 'package:zephyr_mobile/models/models.dart';

void main() {
  test('gift visual is built from committed send receipt metadata', () {
    final GiftVisual visual = GiftVisual.fromSendResult(
      GiftSendResult.fromJson(<String, dynamic>{
        'giftEventId': 'gift-event-1',
        'surface': 'inbox',
        'contextId': 'sender_receiver',
        'senderUserId': 'sender',
        'receiverUserId': 'receiver',
        'giftId': 'rocket',
        'giftName': 'Rocket',
        'thumbnailUrl': '',
        'animationUrl': 'https://cdn.example.test/gifts/rocket/animation.riv',
        'animationType': 'rive',
        'tier': 'medium',
        'quantity': 1,
        'coinCost': 120,
        'totalGiftCoins': 120,
        'senderCoinBalanceAfter': 880,
        'deliveryStatus': 'committed',
        'createdAt': '2026-06-12T10:00:00.000Z',
      }),
    );

    expect(visual.giftEventId, 'gift-event-1');
    expect(visual.giftName, 'Rocket');
    expect(visual.animationType, 'rive');
    expect(visual.totalCoins, 120);
  });

  testWidgets(
    'gift receipt card renders thumbnail fallback, gift name, and coins',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: GiftReceiptCard(
                visual: GiftVisual(
                  giftEventId: 'gift-event-1',
                  giftId: 'rose',
                  giftName: 'Rose',
                  thumbnailUrl: '',
                  animationUrl: '',
                  animationType: 'image',
                  tier: 'small',
                  quantity: 2,
                  coinCost: 10,
                  totalCoins: 20,
                ),
                isMine: true,
                timeLabel: '20:31',
                read: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Rose x2'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('20:31'), findsOneWidget);
      expect(find.byIcon(Icons.card_giftcard_rounded), findsOneWidget);
      expect(find.byIcon(Icons.done_all), findsOneWidget);
    },
  );
}
