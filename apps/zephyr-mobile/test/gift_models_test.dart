import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_mobile/models/models.dart';

void main() {
  test('parses server-driven gift catalog metadata', () {
    final GiftCatalogItem gift = GiftCatalogItem.fromJson(<String, dynamic>{
      'id': 'world_cup_trophy',
      'name': 'World Cup Trophy',
      'coinCost': 2500,
      'sectionId': 'world_cup',
      'sectionName': 'World Cup',
      'thumbnailUrl': 'https://cdn.example.test/gifts/trophy.webp',
      'animationUrl': 'https://cdn.example.test/gifts/trophy.riv',
      'animationType': 'rive',
      'tier': 'large',
      'surfaces': <String>['inbox', 'live_room'],
      'enabled': true,
    });

    expect(gift.id, 'world_cup_trophy');
    expect(gift.coinCost, 2500);
    expect(gift.sectionId, 'world_cup');
    expect(gift.animationType, 'rive');
    expect(gift.tier, 'large');
    expect(gift.surfaces, <String>['inbox', 'live_room']);
    expect(gift.enabled, isTrue);
  });

  test('parses committed gift send receipts', () {
    final GiftSendResult result = GiftSendResult.fromJson(<String, dynamic>{
      'giftEventId': 'gift-event-1',
      'surface': 'inbox',
      'contextId': 'sender_receiver',
      'senderUserId': 'sender',
      'receiverUserId': 'receiver',
      'giftId': 'rose',
      'giftName': 'Rose',
      'sectionId': 'classic',
      'sectionName': 'Classic',
      'thumbnailUrl': 'https://cdn.example.test/gifts/rose/thumb.webp',
      'animationUrl': 'https://cdn.example.test/gifts/rose/animation.lottie',
      'animationType': 'lottie',
      'tier': 'small',
      'quantity': 2,
      'coinCost': 10,
      'totalGiftCoins': 20,
      'senderCoinBalanceAfter': 1180,
      'deliveryStatus': 'committed',
      'createdAt': '2026-06-12T10:00:00.000Z',
    });

    expect(result.giftEventId, 'gift-event-1');
    expect(result.surface, 'inbox');
    expect(result.contextId, 'sender_receiver');
    expect(result.thumbnailUrl, contains('rose/thumb.webp'));
    expect(result.animationType, 'lottie');
    expect(result.tier, 'small');
    expect(result.totalGiftCoins, 20);
    expect(result.senderCoinBalanceAfter, 1180);
    expect(result.deliveryStatus, 'committed');
    expect(
      result.createdAt.toUtc().toIso8601String(),
      '2026-06-12T10:00:00.000Z',
    );
  });
}
