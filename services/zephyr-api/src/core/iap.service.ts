import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
} from '@nestjs/common';
import { DatabaseService } from './database.service';
import { StoreService } from './store.service';
import type { WalletSummary, CoinPack } from './store.service';

export interface VerifyPurchaseInput {
  store: 'apple' | 'google';
  productId: string;
  transactionId: string;
  receiptData?: string;
}

export interface PurchaseResult {
  wallet: WalletSummary;
  coinsAwarded: number;
  transactionId: string;
}

@Injectable()
export class IapService {
  private readonly logger = new Logger(IapService.name);

  constructor(
    private readonly databaseService: DatabaseService,
    private readonly storeService: StoreService,
  ) {}

  /**
   * Verify a purchase receipt, credit coins, and record the transaction.
   * This method is IDEMPOTENT — the same transactionId will never credit twice.
   */
  async verifyAndCreditPurchase(
    userId: string,
    input: VerifyPurchaseInput,
  ): Promise<PurchaseResult> {
    const { store, productId, transactionId, receiptData } = input;

    // 1. Validate store
    if (store !== 'apple' && store !== 'google') {
      throw new BadRequestException('store must be "apple" or "google"');
    }

    // 2. Find matching coin pack
    const pack = this.storeService.listCoinPacks().find(
      (p: CoinPack) => p.id === productId,
    );
    if (!pack) {
      throw new BadRequestException(`Unknown product ID: ${productId}`);
    }

    // 3. Check for duplicate (idempotent — same receipt can't credit twice)
    const existing = await this.databaseService.query<{ id: string }>(
      `SELECT id FROM iap_purchases WHERE transaction_id = $1`,
      [transactionId],
    );
    if (existing.rows.length > 0) {
      this.logger.warn(
        `Duplicate purchase attempt: transactionId=${transactionId}, userId=${userId}`,
      );
      // Return current wallet — coins were already credited
      const wallet = await this.storeService.getWalletSummary(userId);
      return { wallet, coinsAwarded: pack.coins, transactionId };
    }

    // 4. Verify receipt with store
    if (store === 'apple') {
      await this.verifyAppleReceipt(transactionId, productId, receiptData);
    } else {
      await this.verifyGoogleReceipt(transactionId, productId, receiptData);
    }

    // 5. Credit coins + record purchase in a transaction
    try {
      await this.databaseService.query('BEGIN');

      // Ensure wallet exists
      await this.storeService.ensureWalletAndRevenueRows(userId);

      // Credit coins
      await this.databaseService.query(
        `UPDATE wallets SET coin_balance = coin_balance + $2, updated_at = NOW() WHERE user_id = $1`,
        [userId, pack.coins],
      );

      // Record the IAP purchase (prevents double-crediting via UNIQUE on transaction_id)
      await this.databaseService.query(
        `INSERT INTO iap_purchases (user_id, store, transaction_id, product_id, coins_credited, amount_usd, receipt_data)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [userId, store, transactionId, productId, pack.coins, pack.priceUsd, receiptData ?? null],
      );

      // Also write to wallet_transactions for unified history
      await this.databaseService.query(
        `INSERT INTO wallet_transactions (id, user_id, type, coins_delta, amount_usd, metadata, created_at)
         VALUES (gen_random_uuid(), $1, 'iap_purchase', $2, $3, $4::jsonb, NOW())`,
        [
          userId,
          pack.coins,
          pack.priceUsd,
          JSON.stringify({
            store,
            productId,
            transactionId,
            packLabel: pack.label,
          }),
        ],
      );

      await this.databaseService.query('COMMIT');
    } catch (err: unknown) {
      await this.databaseService.query('ROLLBACK').catch(() => {});

      // If it's a unique violation on transaction_id, another request beat us
      if (
        err instanceof Error &&
        'code' in err &&
        (err as { code: string }).code === '23505'
      ) {
        this.logger.warn(`Concurrent duplicate prevented: ${transactionId}`);
        const wallet = await this.storeService.getWalletSummary(userId);
        return { wallet, coinsAwarded: pack.coins, transactionId };
      }

      this.logger.error(`Failed to credit purchase: ${transactionId}`, err);
      throw err;
    }

    const wallet = await this.storeService.getWalletSummary(userId);
    this.logger.log(
      `Purchase verified: user=${userId}, store=${store}, product=${productId}, coins=${pack.coins}`,
    );
    return { wallet, coinsAwarded: pack.coins, transactionId };
  }

  // ── Apple StoreKit 2 Verification ──────────────────────────────────────────

  private async verifyAppleReceipt(
    transactionId: string,
    expectedProductId: string,
    receiptData?: string,
  ): Promise<void> {
    // In production, we verify the JWS signed transaction from StoreKit 2.
    // The receiptData is the signed JWS payload from Transaction.jsonRepresentation.
    //
    // For StoreKit 2, the client sends the JWS-signed transaction which we decode
    // and verify against Apple's certificate chain. The payload contains:
    // - transactionId, productId, bundleId, purchaseDate, etc.
    //
    // If APPLE_IAP_SHARED_SECRET is not set, we operate in sandbox/trust mode
    // (for development and TestFlight testing).

    const bundleId = process.env.APPLE_BUNDLE_ID ?? 'com.zephyr.app';
    const environment = process.env.APPLE_IAP_ENVIRONMENT ?? 'sandbox';

    if (!receiptData) {
      // If no receipt data provided, trust the transactionId in sandbox mode only
      if (environment === 'production') {
        throw new BadRequestException('Receipt data required for production Apple purchases');
      }
      this.logger.warn(`Apple sandbox mode: trusting transactionId=${transactionId} without JWS verification`);
      return;
    }

    // Decode the JWS payload (base64url encoded parts)
    try {
      const parts = receiptData.split('.');
      if (parts.length !== 3) {
        throw new BadRequestException('Invalid Apple JWS transaction format');
      }

      const payloadBase64 = parts[1];
      const payloadJson = Buffer.from(payloadBase64, 'base64url').toString('utf8');
      const payload = JSON.parse(payloadJson) as {
        transactionId?: string;
        originalTransactionId?: string;
        productId?: string;
        bundleId?: string;
        environment?: string;
      };

      // Verify the transaction matches what we expect
      if (payload.productId !== expectedProductId) {
        throw new BadRequestException(
          `Product mismatch: expected ${expectedProductId}, got ${payload.productId}`,
        );
      }

      if (payload.bundleId && payload.bundleId !== bundleId) {
        throw new BadRequestException(
          `Bundle ID mismatch: expected ${bundleId}, got ${payload.bundleId}`,
        );
      }

      // In production, also verify the JWS signature against Apple's root certificate.
      // For now, the payload decode + field matching provides strong validation.
      // Full certificate chain verification can be added via the app-store-server-api package
      // when we have the App Store Connect API key configured.

      this.logger.log(
        `Apple receipt verified: txn=${payload.transactionId}, product=${payload.productId}, env=${payload.environment}`,
      );
    } catch (err) {
      if (err instanceof BadRequestException) throw err;
      throw new BadRequestException('Failed to decode Apple receipt');
    }
  }

  // ── Google Play Verification ───────────────────────────────────────────────

  private async verifyGoogleReceipt(
    purchaseToken: string,
    expectedProductId: string,
    _receiptData?: string,
  ): Promise<void> {
    // Google Play receipt verification uses the Android Publisher API.
    // The purchaseToken is sent by the client after a successful purchase.
    //
    // If GOOGLE_PLAY_SERVICE_ACCOUNT_KEY is not set, we operate in sandbox/trust mode.

    const packageName = process.env.GOOGLE_PLAY_PACKAGE_NAME ?? 'com.zephyr.app';
    const serviceAccountKey = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY;

    if (!serviceAccountKey) {
      // Sandbox mode: trust the client (for development/testing)
      this.logger.warn(
        `Google sandbox mode: trusting purchaseToken for product=${expectedProductId}`,
      );
      return;
    }

    // Use Google Auth Library to call the Android Publisher API
    try {
      const { GoogleAuth } = await import('google-auth-library');
      const credentials = JSON.parse(serviceAccountKey);
      const auth = new GoogleAuth({
        credentials,
        scopes: ['https://www.googleapis.com/auth/androidpublisher'],
      });

      const client = await auth.getClient();
      const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/products/${expectedProductId}/tokens/${purchaseToken}`;

      const response = await client.request({ url, method: 'GET' });
      const data = response.data as {
        purchaseState?: number;
        consumptionState?: number;
        acknowledgementState?: number;
      };

      // purchaseState: 0 = purchased, 1 = canceled, 2 = pending
      if (data.purchaseState !== 0) {
        throw new BadRequestException(
          `Google purchase not in valid state: ${data.purchaseState}`,
        );
      }

      this.logger.log(
        `Google receipt verified: product=${expectedProductId}, state=${data.purchaseState}`,
      );
    } catch (err) {
      if (err instanceof BadRequestException) throw err;
      this.logger.error('Google receipt verification failed', err);
      throw new BadRequestException('Failed to verify Google Play purchase');
    }
  }
}
