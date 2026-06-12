import { GiftDeliveryService } from './gift-delivery.service';
import type { GiftDeliveryOutboxItem, GiftSendResult } from './store.service';

describe('GiftDeliveryService', () => {
  const sender = {
    id: '11111111-1111-4111-8111-111111111111',
    displayName: 'Sender',
    avatarUrl: 'https://cdn.example.test/sender.webp',
  };
  const receiver = {
    id: '22222222-2222-4222-8222-222222222222',
    displayName: 'Receiver',
    avatarUrl: 'https://cdn.example.test/receiver.webp',
  };
  const inboxGift: GiftSendResult = {
    giftEventId: '33333333-3333-4333-8333-333333333333',
    surface: 'inbox',
    contextId: [sender.id, receiver.id].sort().join('_'),
    senderUserId: sender.id,
    receiverUserId: receiver.id,
    sessionId: [sender.id, receiver.id].sort().join('_'),
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
    createdAt: new Date('2026-06-13T00:00:00.000Z').toISOString(),
  };
  const liveGift: GiftSendResult = {
    ...inboxGift,
    giftEventId: '44444444-4444-4444-8444-444444444444',
    surface: 'live_room',
    contextId: '55555555-5555-4555-8555-555555555555',
    receiverUserId: receiver.id,
    sessionId: '55555555-5555-4555-8555-555555555555',
  };

  function makeService(
    overrides: {
      store?: Record<string, unknown>;
      fcm?: Record<string, unknown>;
    } = {},
  ): {
    service: GiftDeliveryService;
    storeService: Record<string, jest.Mock>;
    fcmService: Record<string, jest.Mock>;
  } {
    const storeService = {
      isGiftDeliveryDelivered: jest.fn().mockResolvedValue(false),
      getUserById: jest.fn(async (userId: string) => {
        if (userId === sender.id) return sender;
        if (userId === receiver.id) return receiver;
        throw new Error('User not found');
      }),
      getDeviceTokens: jest.fn().mockResolvedValue(['token-a']),
      deleteDeviceTokensByToken: jest.fn().mockResolvedValue(undefined),
      markGiftDeliveryDelivered: jest.fn().mockResolvedValue(undefined),
      markGiftDeliveryFailed: jest.fn().mockResolvedValue(undefined),
      claimPendingGiftDeliveries: jest.fn().mockResolvedValue([]),
      ...overrides.store,
    } as Record<string, jest.Mock>;
    const fcmService = {
      writeInboxGiftMessage: jest
        .fn()
        .mockResolvedValue({ delivered: true, created: true }),
      writeLiveGiftEvent: jest.fn().mockResolvedValue(true),
      sendCommittedChatMessagePush: jest
        .fn()
        .mockResolvedValue({ sent: true, invalidTokens: ['bad-token'] }),
      ...overrides.fcm,
    } as Record<string, jest.Mock>;

    return {
      service: new GiftDeliveryService(
        storeService as never,
        fcmService as never,
      ),
      storeService,
      fcmService,
    };
  }

  it('writes inbox gift projection and marks delivery as delivered', async () => {
    const { service, storeService, fcmService } = makeService();

    await service.deliverCommittedGift(inboxGift, 'idem-inbox');
    await new Promise<void>((resolve) => setImmediate(resolve));

    expect(fcmService.writeInboxGiftMessage).toHaveBeenCalledWith(
      expect.objectContaining({
        chatId: inboxGift.contextId,
        giftEventId: inboxGift.giftEventId,
        senderUserId: sender.id,
        receiverUserId: receiver.id,
        giftId: 'rose',
        totalGiftCoins: 10,
        idempotencyKey: 'idem-inbox',
      }),
    );
    expect(storeService.markGiftDeliveryDelivered).toHaveBeenCalledWith(
      inboxGift.giftEventId,
    );
    expect(storeService.markGiftDeliveryFailed).not.toHaveBeenCalled();
    expect(fcmService.sendCommittedChatMessagePush).toHaveBeenCalledWith(
      expect.objectContaining({
        senderId: sender.id,
        recipientId: receiver.id,
        chatId: inboxGift.contextId,
        messageId: inboxGift.giftEventId,
      }),
    );
    expect(storeService.deleteDeviceTokensByToken).toHaveBeenCalledWith([
      'bad-token',
    ]);
  });

  it('does not re-deliver a gift already marked delivered', async () => {
    const { service, storeService, fcmService } = makeService({
      store: {
        isGiftDeliveryDelivered: jest.fn().mockResolvedValue(true),
      },
    });

    await service.deliverCommittedGift(liveGift, 'idem-live');

    expect(storeService.isGiftDeliveryDelivered).toHaveBeenCalledWith(
      liveGift.giftEventId,
    );
    expect(fcmService.writeLiveGiftEvent).not.toHaveBeenCalled();
    expect(storeService.markGiftDeliveryDelivered).not.toHaveBeenCalled();
  });

  it('marks live gift delivery pending when RTDB fan-out fails', async () => {
    const { service, storeService } = makeService({
      fcm: {
        writeLiveGiftEvent: jest.fn().mockResolvedValue(false),
      },
    });

    await service.deliverCommittedGift(liveGift, 'idem-live');

    expect(storeService.markGiftDeliveryFailed).toHaveBeenCalledWith(
      liveGift.giftEventId,
      'Live room gift event projection was not delivered',
    );
    expect(storeService.markGiftDeliveryDelivered).not.toHaveBeenCalled();
  });

  it('retries claimed pending gift deliveries without rerunning the ledger', async () => {
    const pending: GiftDeliveryOutboxItem = {
      giftEventId: liveGift.giftEventId,
      surface: 'live_room',
      contextId: liveGift.contextId,
      gift: liveGift,
      idempotencyKey: 'idem-live',
      status: 'failed',
      attemptCount: 1,
      lastError: 'temporary RTDB failure',
      createdAt: liveGift.createdAt,
    };
    const { service, storeService, fcmService } = makeService({
      store: {
        claimPendingGiftDeliveries: jest.fn().mockResolvedValue([pending]),
      },
    });

    const result = await service.retryPendingGiftDeliveries(10);

    expect(result).toEqual({ claimed: 1, delivered: 1, failed: 0 });
    expect(storeService.claimPendingGiftDeliveries).toHaveBeenCalledWith(10);
    expect(fcmService.writeLiveGiftEvent).toHaveBeenCalledWith(
      liveGift.contextId,
      expect.objectContaining({
        giftEventId: liveGift.giftEventId,
        senderUserId: sender.id,
        idempotencyKey: 'idem-live',
      }),
    );
    expect(storeService.markGiftDeliveryDelivered).toHaveBeenCalledWith(
      liveGift.giftEventId,
    );
  });
});
