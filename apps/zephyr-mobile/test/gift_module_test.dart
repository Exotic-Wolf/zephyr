import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_mobile/features/gifts/gift_module.dart';
import 'package:zephyr_mobile/models/models.dart';

Finder _receiptRootFor(Key key) {
  return find
      .descendant(of: find.byKey(key), matching: find.byType(DecoratedBox))
      .first;
}

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

  testWidgets('outgoing gift receipt keeps the premium card shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: Center(
            child: GiftReceiptCard(
              visual: GiftVisual(
                giftEventId: 'gift-event-2',
                giftId: 'heart',
                giftName: 'Heart',
                thumbnailUrl: '',
                animationUrl: '',
                animationType: 'image',
                tier: 'small',
                quantity: 1,
                coinCost: 50,
                totalCoins: 50,
              ),
              isMine: true,
              timeLabel: '23:12',
              read: true,
            ),
          ),
        ),
      ),
    );

    final DecoratedBox card = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(GiftReceiptCard),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final BoxDecoration decoration = card.decoration as BoxDecoration;

    expect(decoration.color, const Color(0xFF242126));
    expect(decoration.color, isNot(const Color(0xFFFF8F00)));
    expect(find.byIcon(Icons.card_giftcard_rounded), findsOneWidget);
  });

  testWidgets('gift receipt metadata is pinned to the footer edge', (
    WidgetTester tester,
  ) async {
    const ValueKey<String> sentKey = ValueKey<String>('sent-gift-receipt');
    const ValueKey<String> receivedKey = ValueKey<String>(
      'received-gift-receipt',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GiftReceiptCard(
                  key: sentKey,
                  visual: GiftVisual(
                    giftEventId: 'gift-event-3',
                    giftId: 'rocket',
                    giftName: 'Rocket',
                    thumbnailUrl: '',
                    animationUrl: '',
                    animationType: 'image',
                    tier: 'small',
                    quantity: 1,
                    coinCost: 120,
                    totalCoins: 120,
                  ),
                  isMine: true,
                  timeLabel: '23:21',
                  read: true,
                ),
                SizedBox(height: 16),
                GiftReceiptCard(
                  key: receivedKey,
                  visual: GiftVisual(
                    giftEventId: 'gift-event-4',
                    giftId: 'rose',
                    giftName: 'Rose',
                    thumbnailUrl: '',
                    animationUrl: '',
                    animationType: 'image',
                    tier: 'small',
                    quantity: 1,
                    coinCost: 10,
                    totalCoins: 10,
                  ),
                  isMine: false,
                  timeLabel: '23:22',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final Rect sentCardRect = tester.getRect(_receiptRootFor(sentKey));
    final Rect sentTimeRect = tester.getRect(find.text('23:21'));
    final Rect sentTickRect = tester.getRect(find.byIcon(Icons.done_all));

    expect(sentTimeRect.bottom, greaterThan(sentCardRect.bottom - 18));
    expect(sentTickRect.bottom, greaterThan(sentCardRect.bottom - 18));
    expect(sentTickRect.right, greaterThan(sentCardRect.right - 30));
    expect(sentTimeRect.right, lessThan(sentTickRect.left));
    expect(
      (sentTimeRect.center.dy - sentTickRect.center.dy).abs(),
      lessThan(3),
    );

    final Rect receivedCardRect = tester.getRect(_receiptRootFor(receivedKey));
    final Rect receivedTimeRect = tester.getRect(find.text('23:22'));

    expect(receivedTimeRect.bottom, greaterThan(receivedCardRect.bottom - 18));
    expect(receivedTimeRect.right, greaterThan(receivedCardRect.right - 32));
  });
}
