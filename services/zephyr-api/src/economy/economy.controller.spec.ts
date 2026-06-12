import { EconomyController } from './economy.controller';
import type { GiftSendResult, UserProfile } from '../core/store.service';

describe('EconomyController gift routing', () => {
  const sender: UserProfile = {
    id: '11111111-1111-4111-8111-111111111111',
    publicId: '11111111',
    displayName: 'Sender',
    avatarUrl: 'https://cdn.example.test/sender.webp',
    coverUrl: null,
    bio: null,
    gender: null,
    birthday: null,
    countryCode: 'MU',
    language: 'en',
    isAdmin: false,
    isHost: false,
    callRateCoinsPerMinute: null,
    onboardedAt: new Date().toISOString(),
    createdAt: new Date().toISOString(),
  };
  const receiver: UserProfile = {
    ...sender,
    id: '22222222-2222-4222-8222-222222222222',
    publicId: '22222222',
    displayName: 'Receiver',
    avatarUrl: 'https://cdn.example.test/receiver.webp',
  };
  const contextId = `${sender.id}_${receiver.id}`;
  const giftResult: GiftSendResult = {
    giftEventId: '33333333-3333-4333-8333-333333333333',
    surface: 'inbox',
    contextId,
    senderUserId: sender.id,
    receiverUserId: receiver.id,
    sessionId: contextId,
    giftId: 'rose',
    giftName: 'Rose',
    sectionId: 'classic',
    sectionName: 'Classic',
    thumbnailUrl: 'https://cdn.example.test/gifts/rose/thumb.webp',
    animationUrl: 'https://cdn.example.test/gifts/rose/animation.lottie',
    animationType: 'lottie',
    tier: 'small',
    quantity: 1,
    coinCost: 10,
    totalGiftCoins: 10,
    receiverCoins: 6,
    receiverUsd: 0.001,
    receiverSpark: 6,
    platformCoins: 4,
    senderCoinBalanceAfter: 990,
    deliveryStatus: 'committed',
    createdAt: new Date().toISOString(),
  };

  it('routes committed backend gift receipts through the delivery module', async () => {
    const storeService = {
      getUserFromAuthHeader: jest.fn().mockResolvedValue(sender),
      sendGift: jest.fn().mockResolvedValue(giftResult),
    };
    const giftDeliveryService = {
      deliverCommittedGift: jest.fn().mockResolvedValue(undefined),
    };
    const controller = new EconomyController(
      storeService as never,
      {} as never,
      {} as never,
      giftDeliveryService as never,
    );

    const result = await controller.sendGift('Bearer token', 'idem-inbox-1', {
      surface: 'inbox',
      contextId,
      receiverUserId: receiver.id,
      giftId: 'rose',
      quantity: 1,
    });
    await new Promise<void>((resolve) => setImmediate(resolve));

    expect(result).toBe(giftResult);
    expect(storeService.sendGift).toHaveBeenCalledWith(sender.id, {
      surface: 'inbox',
      contextId,
      receiverUserId: receiver.id,
      giftId: 'rose',
      quantity: 1,
      idempotencyKey: 'idem-inbox-1',
    });
    expect(giftDeliveryService.deliverCommittedGift).toHaveBeenCalledWith(
      giftResult,
      'idem-inbox-1',
    );
  });
});
