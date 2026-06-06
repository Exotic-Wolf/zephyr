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
    const caller = await storeService.issueGuestSession('db_tick_caller');
    const receiver = await storeService.issueGuestSession('db_tick_receiver');
    await makeAvailable(receiver.user.id);
    const session = await storeService.startCallSession(caller.user.id, {
      mode: 'direct',
      receiverUserId: receiver.user.id,
      directRateCoinsPerMinute: 2100,
    });
    const walletBefore = await storeService.getWalletSummary(caller.user.id);
    const idempotencyKey = `tick:${session.id}:race-duplicate`;

    const [first, second] = await Promise.all([
      storeService.tickCallSession(caller.user.id, session.id, 10, idempotencyKey),
      storeService.tickCallSession(caller.user.id, session.id, 10, idempotencyKey),
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
    const caller = await storeService.issueGuestSession('db_tick_low_balance');
    const receiver = await storeService.issueGuestSession('db_tick_host');
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
    const caller = await storeService.issueGuestSession('db_gift_caller');
    const receiver = await storeService.issueGuestSession('db_gift_receiver');
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

    expect(second).toEqual(first);
    expect(walletAfter.coinBalance).toBe(
      walletBefore.coinBalance - first.totalGiftCoins,
    );
    expect(spendCount.rows[0]?.count).toBe('1');
  });
});
