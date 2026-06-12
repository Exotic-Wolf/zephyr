import { DatabaseService } from './database.service';
import { StoreService } from './store.service';

const runDatabaseRaceTests =
  process.env.ZEPHYR_RUN_DB_RACE_TESTS === 'true' &&
  Boolean(process.env.DATABASE_URL);
const describeDatabaseRace = runDatabaseRaceTests ? describe : describe.skip;

describeDatabaseRace('StoreService Postgres ledger race tests', () => {
  let databaseService: DatabaseService;
  let storeService: StoreService;

  beforeAll(async () => {
    databaseService = new DatabaseService();
    databaseService.onModuleInit();
    await databaseService.waitUntilReady();

    storeService = new StoreService(databaseService);
    await storeService.onModuleInit();
  });

  beforeEach(async () => {
    await databaseService.query(`
      TRUNCATE
        ledger_idempotency,
        gift_delivery_outbox,
        gift_events,
        wallet_transactions,
        call_sessions,
        rooms,
        sessions,
        user_revenue,
        wallets,
        users
      RESTART IDENTITY CASCADE
    `);
  });

  afterAll(async () => {
    await databaseService.onModuleDestroy();
  });

  async function makeAvailable(userId: string): Promise<void> {
    await storeService.syncPresence(userId, 'online', {
      availability: 'available',
      directCall: true,
      randomCall: true,
    });
  }

  it('replays concurrent duplicate call ticks without double charging', async () => {
    const caller = await storeService.issueTestSession('db_tick_caller');
    const receiver = await storeService.issueTestSession('db_tick_receiver');
    await makeAvailable(receiver.user.id);
    const session = await storeService.startCallSession(caller.user.id, {
      mode: 'direct',
      receiverUserId: receiver.user.id,
      directRateCoinsPerMinute: 2100,
    });
    const walletBefore = await storeService.getWalletSummary(caller.user.id);
    const idempotencyKey = `tick:${session.id}:race-duplicate`;

    const [first, second] = await Promise.all([
      storeService.tickCallSession(
        caller.user.id,
        session.id,
        10,
        idempotencyKey,
      ),
      storeService.tickCallSession(
        caller.user.id,
        session.id,
        10,
        idempotencyKey,
      ),
    ]);

    const walletAfter = await storeService.getWalletSummary(caller.user.id);
    const spendCount = await databaseService.query<{ count: string }>(
      `
        SELECT COUNT(*)::text AS count
        FROM wallet_transactions
        WHERE user_id = $1
          AND type = 'call_spend'
          AND metadata->>'sessionId' = $2
      `,
      [caller.user.id, session.id],
    );

    expect(second).toEqual(first);
    expect(walletAfter.coinBalance).toBe(
      walletBefore.coinBalance - first.chargedCoins,
    );
    expect(spendCount.rows[0]?.count).toBe('1');
  });

  it('serializes concurrent call ticks so balance never goes negative', async () => {
    const caller = await storeService.issueTestSession('db_tick_low_balance');
    const receiver = await storeService.issueTestSession('db_tick_host');
    await makeAvailable(receiver.user.id);
    const session = await storeService.startCallSession(caller.user.id, {
      mode: 'random',
      receiverUserId: receiver.user.id,
    });
    await databaseService.query(
      'UPDATE wallets SET coin_balance = 700 WHERE user_id = $1',
      [caller.user.id],
    );

    const results = await Promise.all([
      storeService.tickCallSession(
        caller.user.id,
        session.id,
        60,
        `tick:${session.id}:race-a`,
      ),
      storeService.tickCallSession(
        caller.user.id,
        session.id,
        60,
        `tick:${session.id}:race-b`,
      ),
    ]);

    const walletAfter = await storeService.getWalletSummary(caller.user.id);
    const chargedResults = results.filter((result) => result.chargedCoins > 0);
    const stoppedResults = results.filter(
      (result) => result.stoppedForInsufficientBalance,
    );
    const spendCount = await databaseService.query<{ count: string }>(
      `
        SELECT COUNT(*)::text AS count
        FROM wallet_transactions
        WHERE user_id = $1
          AND type = 'call_spend'
          AND metadata->>'sessionId' = $2
      `,
      [caller.user.id, session.id],
    );

    expect(chargedResults).toHaveLength(1);
    expect(stoppedResults).toHaveLength(1);
    expect(walletAfter.coinBalance).toBe(100);
    expect(spendCount.rows[0]?.count).toBe('1');
  });

  it('replays concurrent duplicate gifts without double charging', async () => {
    const caller = await storeService.issueTestSession('db_gift_caller');
    const receiver = await storeService.issueTestSession('db_gift_receiver');
    await makeAvailable(receiver.user.id);

    await storeService.purchaseCoins(caller.user.id, 'pack_299');
    const session = await storeService.startCallSession(caller.user.id, {
      mode: 'direct',
      receiverUserId: receiver.user.id,
      directRateCoinsPerMinute: 2100,
    });
    const walletBefore = await storeService.getWalletSummary(caller.user.id);
    const idempotencyKey = `gift:${session.id}:lion:race`;

    const [first, second] = await Promise.all([
      storeService.sendGiftInCall(caller.user.id, {
        sessionId: session.id,
        giftId: 'lion',
        quantity: 1,
        idempotencyKey,
      }),
      storeService.sendGiftInCall(caller.user.id, {
        sessionId: session.id,
        giftId: 'lion',
        quantity: 1,
        idempotencyKey,
      }),
    ]);

    const walletAfter = await storeService.getWalletSummary(caller.user.id);
    const spendCount = await databaseService.query<{ count: string }>(
      `
        SELECT COUNT(*)::text AS count
        FROM wallet_transactions
        WHERE user_id = $1
          AND type = 'gift_spend'
          AND metadata->>'sessionId' = $2
      `,
      [caller.user.id, session.id],
    );
    const giftEventCount = await databaseService.query<{ count: string }>(
      `
        SELECT COUNT(*)::text AS count
        FROM gift_events
        WHERE sender_user_id = $1
          AND context_id = $2
      `,
      [caller.user.id, session.id],
    );

    expect(second).toEqual(first);
    expect(second.giftEventId).toBe(first.giftEventId);
    expect(first.surface).toBe('direct_call');
    expect(first.contextId).toBe(session.id);
    expect(first.senderUserId).toBe(caller.user.id);
    expect(first.receiverUserId).toBe(receiver.user.id);
    expect(walletAfter.coinBalance).toBe(
      walletBefore.coinBalance - first.totalGiftCoins,
    );
    expect(spendCount.rows[0]?.count).toBe('1');
    expect(giftEventCount.rows[0]?.count).toBe('1');
  });

  it('replays concurrent duplicate inbox gifts without double charging', async () => {
    const sender = await storeService.issueTestSession('db_inbox_gift_sender');
    const receiver = await storeService.issueTestSession(
      'db_inbox_gift_receiver',
    );

    await storeService.purchaseCoins(sender.user.id, 'pack_299');
    const contextId = [sender.user.id, receiver.user.id].sort().join('_');
    const walletBefore = await storeService.getWalletSummary(sender.user.id);
    const idempotencyKey = `gift:inbox:${contextId}:rose:race`;

    const [first, second] = await Promise.all([
      storeService.sendGift(sender.user.id, {
        surface: 'inbox',
        contextId,
        receiverUserId: receiver.user.id,
        giftId: 'rose',
        quantity: 1,
        idempotencyKey,
      }),
      storeService.sendGift(sender.user.id, {
        surface: 'inbox',
        contextId,
        receiverUserId: receiver.user.id,
        giftId: 'rose',
        quantity: 1,
        idempotencyKey,
      }),
    ]);

    const walletAfter = await storeService.getWalletSummary(sender.user.id);
    const spendCount = await databaseService.query<{ count: string }>(
      `
        SELECT COUNT(*)::text AS count
        FROM wallet_transactions
        WHERE user_id = $1
          AND type = 'gift_spend'
          AND metadata->>'contextId' = $2
      `,
      [sender.user.id, contextId],
    );
    const giftEventCount = await databaseService.query<{ count: string }>(
      `
        SELECT COUNT(*)::text AS count
        FROM gift_events
        WHERE sender_user_id = $1
          AND receiver_user_id = $2
          AND surface = 'inbox'
          AND context_id = $3
      `,
      [sender.user.id, receiver.user.id, contextId],
    );
    const deliveryOutboxCount = await databaseService.query<{ count: string }>(
      `
        SELECT COUNT(*)::text AS count
        FROM gift_delivery_outbox
        WHERE gift_event_id = $1
          AND surface = 'inbox'
          AND context_id = $2
      `,
      [first.giftEventId, contextId],
    );

    expect(second).toEqual(first);
    expect(second.giftEventId).toBe(first.giftEventId);
    expect(first.surface).toBe('inbox');
    expect(first.contextId).toBe(contextId);
    expect(first.senderUserId).toBe(sender.user.id);
    expect(first.receiverUserId).toBe(receiver.user.id);
    expect(walletAfter.coinBalance).toBe(
      walletBefore.coinBalance - first.totalGiftCoins,
    );
    expect(spendCount.rows[0]?.count).toBe('1');
    expect(giftEventCount.rows[0]?.count).toBe('1');
    expect(deliveryOutboxCount.rows[0]?.count).toBe('1');
  });

  it('rejects inbox gifts when either participant has blocked the other user', async () => {
    const sender = await storeService.issueTestSession(
      'db_blocked_gift_sender',
    );
    const receiver = await storeService.issueTestSession(
      'db_blocked_gift_receiver',
    );

    await storeService.purchaseCoins(sender.user.id, 'pack_299');
    await storeService.blockUser(receiver.user.id, sender.user.id);
    const walletBefore = await storeService.getWalletSummary(sender.user.id);

    await expect(
      storeService.sendGift(sender.user.id, {
        surface: 'inbox',
        receiverUserId: receiver.user.id,
        giftId: 'rose',
      }),
    ).rejects.toThrow('Cannot send gift to this user');

    const walletAfter = await storeService.getWalletSummary(sender.user.id);
    const giftEventCount = await databaseService.query<{ count: string }>(
      `
        SELECT COUNT(*)::text AS count
        FROM gift_events
        WHERE sender_user_id = $1
          AND receiver_user_id = $2
          AND surface = 'inbox'
      `,
      [sender.user.id, receiver.user.id],
    );

    expect(walletAfter.coinBalance).toBe(walletBefore.coinBalance);
    expect(giftEventCount.rows[0]?.count).toBe('0');
  });
});
