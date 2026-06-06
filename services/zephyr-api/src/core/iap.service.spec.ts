import { IapService } from './iap.service';

describe('IapService', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = { ...originalEnv };
    delete process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY;
    delete process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY_BASE64;
    delete process.env.GOOGLE_PLAY_PACKAGE_NAME;
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  it('credits a verified purchase through DatabaseService.transaction', async () => {
    const client = {
      query: jest.fn(async () => ({ rowCount: 1, rows: [] })),
    };
    const databaseService = {
      query: jest.fn(async () => ({ rowCount: 0, rows: [] })),
      transaction: jest.fn(async (work) => work(client)),
    };
    const storeService = {
      listCoinPacks: jest.fn(() => [
        { id: 'pack_299', label: '16.5K', coins: 16500, priceUsd: 2.99 },
      ]),
      ensureWalletAndRevenueRows: jest.fn(),
      getWalletSummary: jest.fn(async () => ({
        coinBalance: 17700,
        level: 4,
        revenueUsd: 0,
        sparkBalance: 0,
      })),
    };
    const service = new IapService(databaseService as any, storeService as any);

    const result = await service.verifyAndCreditPurchase('user-1', {
      store: 'google',
      productId: 'pack_299',
      transactionId: 'purchase-token-1',
      receiptData: 'purchase-token-1',
    });

    expect(databaseService.transaction).toHaveBeenCalledTimes(1);
    expect(storeService.ensureWalletAndRevenueRows).toHaveBeenCalledWith(
      'user-1',
      client,
    );
    expect(client.query.mock.calls[0][0]).toContain('INSERT INTO iap_purchases');
    expect(
      client.query.mock.calls.some(([sql]) =>
        String(sql).includes('UPDATE wallets'),
      ),
    ).toBe(true);
    expect(result.coinsAwarded).toBe(16500);
  });

  it('uses the Google purchase token as canonical transaction id for older Android payloads', async () => {
    const client = {
      query: jest.fn(async () => ({ rowCount: 1, rows: [] })),
    };
    const databaseService = {
      query: jest.fn(async () => ({ rowCount: 0, rows: [] })),
      transaction: jest.fn(async (work) => work(client)),
    };
    const storeService = {
      listCoinPacks: jest.fn(() => [
        { id: 'pack_299', label: '16.5K', coins: 16500, priceUsd: 2.99 },
      ]),
      ensureWalletAndRevenueRows: jest.fn(),
      getWalletSummary: jest.fn(async () => ({
        coinBalance: 17700,
        level: 4,
        revenueUsd: 0,
        sparkBalance: 0,
      })),
    };
    const service = new IapService(databaseService as any, storeService as any);

    const result = await service.verifyAndCreditPurchase('user-1', {
      store: 'google',
      productId: 'pack_299',
      transactionId: 'GPA.1234-5678-9012-34567',
      receiptData: 'play-purchase-token-1',
    });

    expect(databaseService.query).toHaveBeenCalledWith(
      expect.stringContaining('FROM iap_purchases'),
      ['play-purchase-token-1'],
    );
    expect(client.query.mock.calls[0][1][2]).toBe('play-purchase-token-1');
    expect(result.transactionId).toBe('play-purchase-token-1');
  });

  it('requires Google Play service account configuration in production', async () => {
    process.env.NODE_ENV = 'production';
    const databaseService = {
      query: jest.fn(async () => ({ rowCount: 0, rows: [] })),
      transaction: jest.fn(),
    };
    const storeService = {
      listCoinPacks: jest.fn(() => [
        { id: 'pack_299', label: '16.5K', coins: 16500, priceUsd: 2.99 },
      ]),
    };
    const service = new IapService(databaseService as any, storeService as any);

    await expect(
      service.verifyAndCreditPurchase('user-1', {
        store: 'google',
        productId: 'pack_299',
        transactionId: 'play-purchase-token-1',
        receiptData: 'play-purchase-token-1',
      }),
    ).rejects.toThrow('Google Play service account is required in production');
  });

  it('refunds Google RTDN voided purchases by purchase token', async () => {
    const service = new IapService({} as any, {} as any);
    const refundSpy = jest
      .spyOn(service as any, 'processRefund')
      .mockResolvedValue(undefined);

    await service.handleGoogleNotification({
      packageName: 'com.zephyr.zephyr_mobile',
      eventTimeMillis: '1770000000000',
      voidedPurchaseNotification: {
        purchaseToken: 'play-purchase-token-1',
        orderId: 'GPA.1234-5678-9012-34567',
        productType: 1,
        refundType: 1,
      },
    });

    expect(refundSpy).toHaveBeenCalledWith('play-purchase-token-1', 'google');
  });
});
