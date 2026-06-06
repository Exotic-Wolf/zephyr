import { IapService } from './iap.service';

describe('IapService', () => {
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
});
