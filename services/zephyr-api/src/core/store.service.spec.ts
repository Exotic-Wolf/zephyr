import {
  BadRequestException,
  ConflictException,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { StoreService } from './store.service';

describe('StoreService', () => {
  let storeService: StoreService;

  beforeEach(() => {
    storeService = new StoreService();
  });

  it('creates internal test session and resolves user from bearer token', async () => {
    const session = await storeService.issueTestSession('wolf');
    const user = await storeService.getUserFromAuthHeader(
      `Bearer ${session.accessToken}`,
    );

    expect(user.id).toBe(session.user.id);
    expect(user.displayName).toBe('wolf');
  });

  it('rejects an older token after a newer mobile session becomes active', async () => {
    const first = await storeService.issueTestSession('wolf', {
      deviceId: 'mobile-test-device-a',
    });
    const replacement = (storeService as any).createAuthSession(first.user.id, {
      deviceId: 'mobile-test-device-b',
    });

    (storeService as any).rememberInMemorySession(first.user.id, replacement);

    await expect(
      storeService.getUserFromAuthHeader(`Bearer ${first.accessToken}`),
    ).rejects.toThrow(UnauthorizedException);

    const current = await storeService.getUserFromAuthHeader(
      `Bearer ${replacement.token}`,
    );
    expect(current.id).toBe(first.user.id);
  });

  it('revokes the current session on logout', async () => {
    const session = await storeService.issueTestSession('wolf', {
      deviceId: 'mobile-test-device-a',
    });

    const revoked = await storeService.revokeAuthSessionFromAuthHeader(
      `Bearer ${session.accessToken}`,
    );

    expect(revoked.user.id).toBe(session.user.id);
    await expect(
      storeService.getUserFromAuthHeader(`Bearer ${session.accessToken}`),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('returns push tokens only for the active session', async () => {
    const session = await storeService.issueTestSession('push_active', {
      deviceId: 'mobile-test-device-a',
    });

    await storeService.upsertDeviceToken(
      {
        user: session.user,
        sessionId: session.sessionId,
        deviceId: session.deviceId,
      },
      'fcm-token-active',
    );

    expect(await storeService.getDeviceTokens(session.user.id)).toEqual([
      'fcm-token-active',
    ]);

    const replacement = (storeService as any).createAuthSession(
      session.user.id,
      {
        deviceId: 'mobile-test-device-b',
      },
    );
    (storeService as any).rememberInMemorySession(session.user.id, replacement);

    expect(await storeService.getDeviceTokens(session.user.id)).toEqual([]);
  });

  it('removes active-session push tokens on logout', async () => {
    const session = await storeService.issueTestSession('push_logout', {
      deviceId: 'mobile-test-device-a',
    });

    await storeService.upsertDeviceToken(
      {
        user: session.user,
        sessionId: session.sessionId,
        deviceId: session.deviceId,
      },
      'fcm-token-logout',
    );

    await storeService.revokeAuthSessionFromAuthHeader(
      `Bearer ${session.accessToken}`,
    );

    expect(await storeService.getDeviceTokens(session.user.id)).toEqual([]);
  });

  it('moves a reused app token to the latest signed-in account', async () => {
    const first = await storeService.issueTestSession('push_account_a', {
      deviceId: 'mobile-test-device-a',
    });
    const second = await storeService.issueTestSession('push_account_b', {
      deviceId: 'mobile-test-device-b',
    });

    await storeService.upsertDeviceToken(
      {
        user: first.user,
        sessionId: first.sessionId,
        deviceId: first.deviceId,
      },
      'fcm-token-shared-install',
    );
    await storeService.upsertDeviceToken(
      {
        user: second.user,
        sessionId: second.sessionId,
        deviceId: second.deviceId,
      },
      'fcm-token-shared-install',
    );

    expect(await storeService.getDeviceTokens(first.user.id)).toEqual([]);
    expect(await storeService.getDeviceTokens(second.user.id)).toEqual([
      'fcm-token-shared-install',
    ]);
  });

  it('prunes invalid push tokens globally', async () => {
    const first = await storeService.issueTestSession('push_prune_a', {
      deviceId: 'mobile-test-device-a',
    });
    const second = await storeService.issueTestSession('push_prune_b', {
      deviceId: 'mobile-test-device-b',
    });

    await storeService.upsertDeviceToken(
      {
        user: first.user,
        sessionId: first.sessionId,
        deviceId: first.deviceId,
      },
      'fcm-token-prune-a',
    );
    await storeService.upsertDeviceToken(
      {
        user: second.user,
        sessionId: second.sessionId,
        deviceId: second.deviceId,
      },
      'fcm-token-prune-b',
    );

    await storeService.deleteDeviceTokensByToken(['fcm-token-prune-a']);

    expect(await storeService.getDeviceTokens(first.user.id)).toEqual([]);
    expect(await storeService.getDeviceTokens(second.user.id)).toEqual([
      'fcm-token-prune-b',
    ]);
  });

  it('rejects invalid profile displayName update', async () => {
    const session = await storeService.issueTestSession('wolf');

    await expect(
      storeService.updateUser(session.user.id, { displayName: 'x' }),
    ).rejects.toThrow(BadRequestException);
  });

  it('creates and joins room', async () => {
    const session = await storeService.issueTestSession('wolf');
    const room = await storeService.createRoom(
      session.user.id,
      'Late Night Talk',
    );
    const joinedRoom = await storeService.joinRoom(room.id, session.user.id);

    expect(joinedRoom.audienceCount).toBe(1);
    const rooms = await storeService.listRooms();
    expect(rooms[0].id).toBe(room.id);
  });

  it('keeps only one active live room per host', async () => {
    const session = await storeService.issueTestSession('host_one_live');
    const firstRoom = await storeService.createRoom(
      session.user.id,
      'First Live',
    );
    const secondRoom = await storeService.createRoom(
      session.user.id,
      'Second Live',
    );

    await expect(
      storeService.joinRoom(firstRoom.id, session.user.id),
    ).rejects.toThrow(NotFoundException);

    const rooms = await storeService.listRooms();
    expect(rooms).toHaveLength(1);
    expect(rooms[0].id).toBe(secondRoom.id);
  });

  it('keeps host feed limited to host accounts after a room ends', async () => {
    const session = await storeService.issueTestSession('host_end_live');
    const host = await storeService.updateUser(session.user.id, {
      gender: 'Female',
    });
    const customer = await storeService.issueTestSession('customer_not_feed');
    const room = await storeService.createRoom(
      session.user.id,
      'Temporary Live',
    );
    await storeService.createRoom(customer.user.id, 'Customer Live');

    await storeService.endRoom(session.user.id, room.id);

    const feed = await storeService.listLiveFeed();
    const liveOnlyFeed = await storeService.listLiveFeed(20, {
      liveOnly: true,
    });
    const rooms = await storeService.listRooms();

    expect(feed).toHaveLength(1);
    expect(liveOnlyFeed).toHaveLength(0);
    expect(feed[0].hostUserId).toBe(session.user.id);
    expect(feed[0].hostCoverUrl).toBe(host.coverUrl);
    expect(feed[0].hostCoverUrl).toMatch(/^assets\/images\/host_covers\//);
    expect(feed[0].roomId).toBeNull();
    expect(feed[0].hostStatus).toBe('offline');
    expect(rooms).toHaveLength(1);
    expect(rooms[0].hostUserId).toBe(customer.user.id);
    await expect(
      storeService.joinRoom(room.id, session.user.id),
    ).rejects.toThrow(NotFoundException);
  });

  it('rejects missing auth header', async () => {
    await expect(storeService.getUserFromAuthHeader(undefined)).rejects.toThrow(
      UnauthorizedException,
    );
  });

  it('allows one user to be both caller and receiver', async () => {
    const session = await storeService.issueTestSession('wolf_dual');

    const startedSession = await storeService.startCallSession(
      session.user.id,
      {
        mode: 'direct',
        receiverUserId: session.user.id,
        directRateCoinsPerMinute: 2100,
      },
    );

    expect(startedSession.callerUserId).toBe(session.user.id);
    expect(startedSession.receiverUserId).toBe(session.user.id);

    const walletBeforeTick = await storeService.getWalletSummary(
      session.user.id,
    );
    const tickResult = await storeService.tickCallSession(
      session.user.id,
      startedSession.id,
      10,
    );
    const walletAfterTick = await storeService.getWalletSummary(
      session.user.id,
    );

    expect(tickResult.chargedCoins).toBeGreaterThan(0);
    expect(tickResult.receiverSpark).toBeGreaterThan(0);
    expect(walletAfterTick.coinBalance).toBe(
      walletBeforeTick.coinBalance - tickResult.chargedCoins,
    );

    const endedSession = await storeService.endCallSession(
      session.user.id,
      startedSession.id,
      'caller_ended',
    );

    expect(endedSession.status).toBe('ended');
  });

  it('charges caller and awards spark to receiver', async () => {
    const callerSession = await storeService.issueTestSession('caller_user');
    const receiverSession =
      await storeService.issueTestSession('receiver_user');

    const callerWalletBefore = await storeService.getWalletSummary(
      callerSession.user.id,
    );
    const receiverWalletBefore = await storeService.getWalletSummary(
      receiverSession.user.id,
    );

    const startedSession = await storeService.startCallSession(
      callerSession.user.id,
      {
        mode: 'direct',
        receiverUserId: receiverSession.user.id,
        directRateCoinsPerMinute: 2100,
      },
    );

    const tickResult = await storeService.tickCallSession(
      callerSession.user.id,
      startedSession.id,
      10,
    );

    const callerWalletAfter = await storeService.getWalletSummary(
      callerSession.user.id,
    );
    const receiverWalletAfter = await storeService.getWalletSummary(
      receiverSession.user.id,
    );

    expect(callerWalletAfter.coinBalance).toBe(
      callerWalletBefore.coinBalance - tickResult.chargedCoins,
    );
    expect(receiverWalletAfter.sparkBalance).toBeGreaterThan(
      receiverWalletBefore.sparkBalance,
    );
    expect(receiverWalletAfter.coinBalance).toBe(
      receiverWalletBefore.coinBalance,
    );
  });

  it('replays duplicate call tick idempotency keys without charging twice', async () => {
    const caller = await storeService.issueTestSession('idem_tick_caller');
    const receiver = await storeService.issueTestSession('idem_tick_receiver');
    const session = await storeService.startCallSession(caller.user.id, {
      mode: 'direct',
      receiverUserId: receiver.user.id,
      directRateCoinsPerMinute: 2100,
    });
    const walletBefore = await storeService.getWalletSummary(caller.user.id);
    const idempotencyKey = `tick:${session.id}:0001`;

    const first = await storeService.tickCallSession(
      caller.user.id,
      session.id,
      10,
      idempotencyKey,
    );
    const second = await storeService.tickCallSession(
      caller.user.id,
      session.id,
      10,
      idempotencyKey,
    );
    const walletAfter = await storeService.getWalletSummary(caller.user.id);

    expect(second).toEqual(first);
    expect(walletAfter.coinBalance).toBe(
      walletBefore.coinBalance - first.chargedCoins,
    );
  });

  it('rejects reusing a call tick idempotency key for different details', async () => {
    const caller = await storeService.issueTestSession('idem_conflict_caller');
    const receiver = await storeService.issueTestSession(
      'idem_conflict_receiver',
    );
    const session = await storeService.startCallSession(caller.user.id, {
      mode: 'direct',
      receiverUserId: receiver.user.id,
      directRateCoinsPerMinute: 2100,
    });
    const idempotencyKey = `tick:${session.id}:conflict`;

    await storeService.tickCallSession(
      caller.user.id,
      session.id,
      10,
      idempotencyKey,
    );

    await expect(
      storeService.tickCallSession(
        caller.user.id,
        session.id,
        15,
        idempotencyKey,
      ),
    ).rejects.toThrow(ConflictException);
  });

  it('exposes paid server gift catalog metadata for reusable gift surfaces', () => {
    const catalog = storeService.listGiftCatalog();
    const rose = catalog.find((gift) => gift.id === 'rose');
    const lion = catalog.find((gift) => gift.id === 'lion');
    const premiumKey = catalog.find((gift) => gift.id === 'premium_room_key');

    expect(catalog.every((gift) => gift.coinCost > 0)).toBe(true);
    expect(rose).toMatchObject({
      sectionId: 'classic',
      animationType: 'lottie',
      tier: 'small',
      enabled: true,
    });
    expect(rose?.surfaces).toContain('inbox');
    expect(rose?.thumbnailUrl).toContain('/classic/rose/thumb.webp');
    expect(lion?.tier).toBe('huge');
    expect(premiumKey?.surfaces).toEqual(['premium_live_entry']);
  });

  it('replays duplicate gift idempotency keys without charging twice', async () => {
    const caller = await storeService.issueTestSession('idem_gift_caller');
    const receiver = await storeService.issueTestSession('idem_gift_receiver');

    await storeService.purchaseCoins(caller.user.id, 'pack_299');
    const session = await storeService.startCallSession(caller.user.id, {
      mode: 'direct',
      receiverUserId: receiver.user.id,
      directRateCoinsPerMinute: 2100,
    });
    const walletBefore = await storeService.getWalletSummary(caller.user.id);
    const idempotencyKey = `gift:${session.id}:lion:1`;

    const first = await storeService.sendGiftInCall(caller.user.id, {
      sessionId: session.id,
      giftId: 'lion',
      quantity: 1,
      idempotencyKey,
    });
    const second = await storeService.sendGiftInCall(caller.user.id, {
      sessionId: session.id,
      giftId: 'lion',
      quantity: 1,
      idempotencyKey,
    });
    const walletAfter = await storeService.getWalletSummary(caller.user.id);

    expect(second).toEqual(first);
    expect(first.giftEventId).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
    );
    expect(first.surface).toBe('direct_call');
    expect(first.contextId).toBe(session.id);
    expect(first.senderUserId).toBe(caller.user.id);
    expect(first.receiverUserId).toBe(receiver.user.id);
    expect(first.deliveryStatus).toBe('committed');
    expect(walletAfter.coinBalance).toBe(
      walletBefore.coinBalance - first.totalGiftCoins,
    );
  });

  it('sends inbox gifts through the reusable gift contract with a canonical context', async () => {
    const sender = await storeService.issueTestSession('inbox_gift_sender');
    const receiver = await storeService.issueTestSession('inbox_gift_receiver');
    const contextId = [sender.user.id, receiver.user.id].sort().join('_');
    const walletBefore = await storeService.getWalletSummary(sender.user.id);
    const idempotencyKey = `gift:inbox:${contextId}:rose:1`;

    const first = await storeService.sendGift(sender.user.id, {
      surface: 'inbox',
      contextId,
      receiverUserId: receiver.user.id,
      giftId: 'rose',
      quantity: 2,
      idempotencyKey,
    });
    const second = await storeService.sendGift(sender.user.id, {
      surface: 'inbox',
      contextId,
      receiverUserId: receiver.user.id,
      giftId: 'rose',
      quantity: 2,
      idempotencyKey,
    });
    const walletAfter = await storeService.getWalletSummary(sender.user.id);

    expect(second).toEqual(first);
    expect(first.surface).toBe('inbox');
    expect(first.contextId).toBe(contextId);
    expect(first.sessionId).toBe(contextId);
    expect(first.senderUserId).toBe(sender.user.id);
    expect(first.receiverUserId).toBe(receiver.user.id);
    expect(first.totalGiftCoins).toBe(20);
    expect(first.receiverSpark).toBe(12);
    expect(first.deliveryStatus).toBe('committed');
    expect(walletAfter.coinBalance).toBe(
      walletBefore.coinBalance - first.totalGiftCoins,
    );
  });

  it('rejects inbox gift context/receiver mismatches before charging', async () => {
    const sender = await storeService.issueTestSession('inbox_wrong_sender');
    const receiver = await storeService.issueTestSession(
      'inbox_wrong_receiver',
    );
    const walletBefore = await storeService.getWalletSummary(sender.user.id);

    await expect(
      storeService.sendGift(sender.user.id, {
        surface: 'inbox',
        contextId:
          '11111111-1111-4111-8111-111111111111_22222222-2222-4222-8222-222222222222',
        receiverUserId: receiver.user.id,
        giftId: 'rose',
      }),
    ).rejects.toThrow(BadRequestException);

    const walletAfter = await storeService.getWalletSummary(sender.user.id);
    expect(walletAfter.coinBalance).toBe(walletBefore.coinBalance);
  });

  it('rejects gifts that are not enabled for the requested surface', async () => {
    const sender = await storeService.issueTestSession('surface_gift_sender');
    const receiver = await storeService.issueTestSession(
      'surface_gift_receiver',
    );

    await expect(
      storeService.sendGift(sender.user.id, {
        surface: 'inbox',
        receiverUserId: receiver.user.id,
        giftId: 'premium_room_key',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('rejects a call gift when requested surface does not match the call mode', async () => {
    const caller = await storeService.issueTestSession(
      'surface_call_mismatch_caller',
    );
    const receiver = await storeService.issueTestSession(
      'surface_call_mismatch_receiver',
    );
    const session = await storeService.startCallSession(caller.user.id, {
      mode: 'direct',
      receiverUserId: receiver.user.id,
      directRateCoinsPerMinute: 2100,
    });
    const walletBefore = await storeService.getWalletSummary(caller.user.id);

    await expect(
      storeService.sendGift(caller.user.id, {
        surface: 'random_call',
        contextId: session.id,
        giftId: 'rose',
      }),
    ).rejects.toThrow(BadRequestException);

    const walletAfter = await storeService.getWalletSummary(caller.user.id);
    expect(walletAfter.coinBalance).toBe(walletBefore.coinBalance);
  });

  it('uses a single database transaction and row locks for call ticks', async () => {
    const callerUserId = '11111111-1111-4111-8111-111111111111';
    const receiverUserId = '22222222-2222-4222-8222-222222222222';
    const sessionId = '33333333-3333-4333-8333-333333333333';
    const baseSessionRow = {
      id: sessionId,
      caller_user_id: callerUserId,
      receiver_user_id: receiverUserId,
      mode: 'random',
      rate_coins_per_minute: 600,
      receiver_share_bps: 6000,
      coins_per_usd_receiver: 10000,
      spark_per_usd: 10000,
      total_billed_coins: 0,
      total_receiver_coins: 0,
      total_receiver_usd: 0,
      total_receiver_spark: 0,
      status: 'live',
      end_reason: null,
      started_at: new Date('2026-06-06T00:00:00.000Z'),
      updated_at: new Date('2026-06-06T00:00:00.000Z'),
      ended_at: null,
    };
    const updatedSessionRow = {
      ...baseSessionRow,
      total_billed_coins: 100,
      total_receiver_coins: 60,
      total_receiver_usd: 0.006,
      total_receiver_spark: 60,
      updated_at: new Date('2026-06-06T00:00:10.000Z'),
    };

    const client = {
      query: jest.fn(async (sql: string) => {
        if (sql.includes('FROM call_sessions')) {
          return { rowCount: 1, rows: [baseSessionRow] };
        }
        if (sql.includes('FROM wallets')) {
          return { rowCount: 1, rows: [{ coin_balance: 1200 }] };
        }
        if (sql.includes('UPDATE wallets')) {
          return { rowCount: 1, rows: [{ coin_balance: 1100 }] };
        }
        if (sql.includes('UPDATE call_sessions')) {
          return { rowCount: 1, rows: [updatedSessionRow] };
        }
        return { rowCount: 1, rows: [] };
      }),
    };
    const databaseService = {
      isEnabled: () => true,
      transaction: jest.fn(async (work) => work(client)),
      query: jest.fn(),
    };
    const dbBackedStore = new StoreService(databaseService as any);

    const result = await dbBackedStore.tickCallSession(
      callerUserId,
      sessionId,
      10,
    );

    expect(databaseService.transaction).toHaveBeenCalledTimes(1);
    expect(result.chargedCoins).toBe(100);
    expect(result.callerCoinBalanceAfter).toBe(1100);
    expect(
      client.query.mock.calls.some(([sql]) =>
        String(sql).includes('FOR UPDATE'),
      ),
    ).toBe(true);
    expect(databaseService.query).not.toHaveBeenCalled();
  });

  it('writes a gift event receipt inside the call gift database transaction', async () => {
    const callerUserId = '11111111-1111-4111-8111-111111111111';
    const receiverUserId = '22222222-2222-4222-8222-222222222222';
    const sessionId = '33333333-3333-4333-8333-333333333333';
    const sessionRow = {
      id: sessionId,
      caller_user_id: callerUserId,
      receiver_user_id: receiverUserId,
      mode: 'random',
      rate_coins_per_minute: 600,
      receiver_share_bps: 6000,
      coins_per_usd_receiver: 10000,
      spark_per_usd: 10000,
      total_billed_coins: 0,
      total_receiver_coins: 0,
      total_receiver_usd: 0,
      total_receiver_spark: 0,
      status: 'live',
      end_reason: null,
      started_at: new Date('2026-06-06T00:00:00.000Z'),
      updated_at: new Date('2026-06-06T00:00:00.000Z'),
      ended_at: null,
    };

    const client = {
      query: jest.fn(async (sql: string) => {
        if (sql.includes('FROM call_sessions')) {
          return { rowCount: 1, rows: [sessionRow] };
        }
        if (sql.includes('FROM wallets')) {
          return { rowCount: 1, rows: [{ coin_balance: 1200 }] };
        }
        if (sql.includes('UPDATE wallets')) {
          return { rowCount: 1, rows: [{ coin_balance: 1190 }] };
        }
        return { rowCount: 1, rows: [] };
      }),
    };
    const databaseService = {
      isEnabled: () => true,
      transaction: jest.fn(async (work) => work(client)),
      query: jest.fn(),
    };
    const dbBackedStore = new StoreService(databaseService as any);

    const result = await dbBackedStore.sendGiftInCall(callerUserId, {
      sessionId,
      giftId: 'rose',
      quantity: 1,
    });

    const giftEventInsert = client.query.mock.calls.find(([sql]) =>
      String(sql).includes('INSERT INTO gift_events'),
    );
    const outboxInsert = client.query.mock.calls.find(([sql]) =>
      String(sql).includes('INSERT INTO gift_delivery_outbox'),
    );
    const giftEventParams = giftEventInsert?.[1] as unknown[] | undefined;

    expect(databaseService.transaction).toHaveBeenCalledTimes(1);
    expect(giftEventInsert).toBeDefined();
    expect(outboxInsert).toBeUndefined();
    expect(result.giftEventId).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
    );
    expect(result.surface).toBe('random_call');
    expect(result.contextId).toBe(sessionId);
    expect(result.senderUserId).toBe(callerUserId);
    expect(result.receiverUserId).toBe(receiverUserId);
    expect(result.senderCoinBalanceAfter).toBe(1190);
    expect(giftEventParams?.[0]).toBe(result.giftEventId);
    expect(giftEventParams?.[2]).toBe('random_call');
    expect(giftEventParams?.[3]).toBe(sessionId);
    expect(giftEventParams?.[4]).toBe(callerUserId);
    expect(giftEventParams?.[5]).toBe(receiverUserId);
    expect(giftEventParams?.[6]).toBe('rose');
    expect(giftEventParams?.[9]).toBe(10);
    expect(giftEventParams?.[10]).toBe(10);
    expect(giftEventParams?.[16]).toBe('committed');
    expect(databaseService.query).not.toHaveBeenCalled();
  });

  it('writes an inbox gift event receipt inside the inbox gift database transaction', async () => {
    const senderUserId = '11111111-1111-4111-8111-111111111111';
    const receiverUserId = '22222222-2222-4222-8222-222222222222';
    const contextId = [senderUserId, receiverUserId].sort().join('_');

    const client = {
      query: jest.fn(async (sql: string) => {
        if (sql.includes('FROM users')) {
          return { rowCount: 1, rows: [{ id: receiverUserId }] };
        }
        if (sql.includes('FROM user_blocks')) {
          return { rowCount: 1, rows: [{ blocked: false }] };
        }
        if (sql.includes('FROM wallets')) {
          return { rowCount: 1, rows: [{ coin_balance: 1200 }] };
        }
        if (sql.includes('UPDATE wallets')) {
          return { rowCount: 1, rows: [{ coin_balance: 1190 }] };
        }
        return { rowCount: 1, rows: [] };
      }),
    };
    const databaseService = {
      isEnabled: () => true,
      transaction: jest.fn(async (work) => work(client)),
      query: jest.fn(),
    };
    const dbBackedStore = new StoreService(databaseService as any);

    const result = await dbBackedStore.sendGift(senderUserId, {
      surface: 'inbox',
      receiverUserId,
      giftId: 'rose',
      quantity: 1,
    });

    const giftEventInsert = client.query.mock.calls.find(([sql]) =>
      String(sql).includes('INSERT INTO gift_events'),
    );
    const outboxInsert = client.query.mock.calls.find(([sql]) =>
      String(sql).includes('INSERT INTO gift_delivery_outbox'),
    );
    const giftEventParams = giftEventInsert?.[1] as unknown[] | undefined;
    const outboxParams = outboxInsert?.[1] as unknown[] | undefined;
    const outboxPayload =
      typeof outboxParams?.[3] === 'string'
        ? JSON.parse(outboxParams[3])
        : undefined;

    expect(databaseService.transaction).toHaveBeenCalledTimes(1);
    expect(result.surface).toBe('inbox');
    expect(result.contextId).toBe(contextId);
    expect(result.receiverUserId).toBe(receiverUserId);
    expect(result.senderCoinBalanceAfter).toBe(1190);
    expect(giftEventInsert).toBeDefined();
    expect(giftEventParams?.[0]).toBe(result.giftEventId);
    expect(giftEventParams?.[2]).toBe('inbox');
    expect(giftEventParams?.[3]).toBe(contextId);
    expect(giftEventParams?.[4]).toBe(senderUserId);
    expect(giftEventParams?.[5]).toBe(receiverUserId);
    expect(giftEventParams?.[6]).toBe('rose');
    expect(giftEventParams?.[9]).toBe(10);
    expect(giftEventParams?.[10]).toBe(10);
    expect(giftEventParams?.[16]).toBe('committed');
    expect(outboxInsert).toBeDefined();
    expect(outboxParams?.[0]).toBe(result.giftEventId);
    expect(outboxParams?.[1]).toBe('inbox');
    expect(outboxParams?.[2]).toBe(contextId);
    expect(outboxPayload?.gift?.giftEventId).toBe(result.giftEventId);
    expect(outboxPayload?.gift?.receiverUserId).toBe(receiverUserId);
    expect(outboxPayload?.idempotencyKey).toBeNull();
    expect(databaseService.query).not.toHaveBeenCalled();
  });

  it('prevents a busy caller from starting another live call', async () => {
    const caller = await storeService.issueTestSession('caller_busy');
    const receiverOne = await storeService.issueTestSession('receiver_one');
    const receiverTwo = await storeService.issueTestSession('receiver_two');

    await storeService.startCallSession(caller.user.id, {
      mode: 'direct',
      receiverUserId: receiverOne.user.id,
      directRateCoinsPerMinute: 2100,
    });

    await expect(
      storeService.startCallSession(caller.user.id, {
        mode: 'direct',
        receiverUserId: receiverTwo.user.id,
        directRateCoinsPerMinute: 2100,
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('prevents calling a receiver who is already in a live call', async () => {
    const callerOne = await storeService.issueTestSession('caller_one');
    const callerTwo = await storeService.issueTestSession('caller_two');
    const busyReceiver = await storeService.issueTestSession('busy_receiver');

    await storeService.startCallSession(callerOne.user.id, {
      mode: 'direct',
      receiverUserId: busyReceiver.user.id,
      directRateCoinsPerMinute: 2100,
    });

    await expect(
      storeService.startCallSession(callerTwo.user.id, {
        mode: 'direct',
        receiverUserId: busyReceiver.user.id,
        directRateCoinsPerMinute: 2100,
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('allows caller to send gift during live call and credits receiver spark', async () => {
    const caller = await storeService.issueTestSession('gift_caller');
    const receiver = await storeService.issueTestSession('gift_receiver');

    await storeService.purchaseCoins(caller.user.id, 'pack_299');
    const callerWalletBefore = await storeService.getWalletSummary(
      caller.user.id,
    );
    const receiverWalletBefore = await storeService.getWalletSummary(
      receiver.user.id,
    );

    const session = await storeService.startCallSession(caller.user.id, {
      mode: 'direct',
      receiverUserId: receiver.user.id,
      directRateCoinsPerMinute: 2100,
    });

    const giftResult = await storeService.sendGiftInCall(caller.user.id, {
      sessionId: session.id,
      giftId: 'lion',
      quantity: 1,
    });

    const callerWalletAfter = await storeService.getWalletSummary(
      caller.user.id,
    );
    const receiverWalletAfter = await storeService.getWalletSummary(
      receiver.user.id,
    );

    expect(giftResult.totalGiftCoins).toBe(5000);
    expect(giftResult.receiverSpark).toBe(3000);
    expect(giftResult.giftEventId).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
    );
    expect(giftResult.surface).toBe('direct_call');
    expect(giftResult.contextId).toBe(session.id);
    expect(giftResult.senderUserId).toBe(caller.user.id);
    expect(giftResult.receiverUserId).toBe(receiver.user.id);
    expect(giftResult.coinCost).toBe(5000);
    expect(giftResult.deliveryStatus).toBe('committed');
    expect(callerWalletAfter.coinBalance).toBe(
      callerWalletBefore.coinBalance - 5000,
    );
    expect(receiverWalletAfter.sparkBalance).toBe(
      receiverWalletBefore.sparkBalance + 3000,
    );
    expect(receiverWalletAfter.coinBalance).toBe(
      receiverWalletBefore.coinBalance,
    );
  });

  it('rejects gift send when sender is not the call caller', async () => {
    const caller = await storeService.issueTestSession('gift_owner');
    const receiver = await storeService.issueTestSession('gift_receiver_only');

    const session = await storeService.startCallSession(caller.user.id, {
      mode: 'direct',
      receiverUserId: receiver.user.id,
      directRateCoinsPerMinute: 2100,
    });

    await expect(
      storeService.sendGiftInCall(receiver.user.id, {
        sessionId: session.id,
        giftId: 'rose',
        quantity: 1,
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('resolves call participant role for caller and receiver', async () => {
    const caller = await storeService.issueTestSession('rtc_caller');
    const receiver = await storeService.issueTestSession('rtc_receiver');

    const session = await storeService.startCallSession(caller.user.id, {
      mode: 'direct',
      receiverUserId: receiver.user.id,
      directRateCoinsPerMinute: 2100,
    });

    const callerParticipant = await storeService.getLiveCallSessionParticipant(
      session.id,
      caller.user.id,
    );
    const receiverParticipant =
      await storeService.getLiveCallSessionParticipant(
        session.id,
        receiver.user.id,
      );

    expect(callerParticipant.role).toBe('caller');
    expect(receiverParticipant.role).toBe('receiver');
  });

  it('rejects non-participant RTC token access', async () => {
    const caller = await storeService.issueTestSession('rtc_owner');
    const receiver = await storeService.issueTestSession('rtc_peer');
    const outsider = await storeService.issueTestSession('rtc_outsider');

    const session = await storeService.startCallSession(caller.user.id, {
      mode: 'direct',
      receiverUserId: receiver.user.id,
      directRateCoinsPerMinute: 2100,
    });

    await expect(
      storeService.getLiveCallSessionParticipant(session.id, outsider.user.id),
    ).rejects.toThrow(BadRequestException);
  });
});
