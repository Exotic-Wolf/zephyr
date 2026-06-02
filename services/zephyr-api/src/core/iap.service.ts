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
    const bundleId = process.env.APPLE_BUNDLE_ID ?? 'com.zephyr.app';
    const environment = process.env.APPLE_IAP_ENVIRONMENT ?? 'sandbox';

    if (!receiptData) {
      if (environment === 'production') {
        throw new BadRequestException('Receipt data required for production Apple purchases');
      }
      this.logger.warn(`Apple sandbox mode: trusting transactionId=${transactionId} without JWS verification`);
      return;
    }

    // Full cryptographic verification using Apple's certificate chain.
    // `decodeTransaction` verifies the JWS signature against Apple's G3 root cert,
    // validates the entire x5c certificate chain, and decodes the payload.
    // If the signature is forged or tampered, it throws CertificateValidationError.
    try {
      const { decodeTransaction, APPLE_ROOT_CA_G3_FINGERPRINT } = await import('app-store-server-api');

      const decoded = await decodeTransaction(receiptData, APPLE_ROOT_CA_G3_FINGERPRINT);

      // Verify product ID matches
      if (decoded.productId !== expectedProductId) {
        throw new BadRequestException(
          `Product mismatch: expected ${expectedProductId}, got ${decoded.productId}`,
        );
      }

      // Verify bundle ID matches
      if (decoded.bundleId !== bundleId) {
        throw new BadRequestException(
          `Bundle ID mismatch: expected ${bundleId}, got ${decoded.bundleId}`,
        );
      }

      // Reject if the transaction was already revoked (refunded)
      if (decoded.revocationDate) {
        throw new BadRequestException(
          `Transaction ${decoded.transactionId} was revoked/refunded`,
        );
      }

      this.logger.log(
        `Apple receipt CRYPTO-VERIFIED: txn=${decoded.transactionId}, product=${decoded.productId}, env=${decoded.environment}`,
      );
    } catch (err) {
      if (err instanceof BadRequestException) throw err;

      // CertificateValidationError means forged/invalid signature
      const errName = (err as { name?: string })?.name;
      if (errName === 'CertificateValidationError') {
        this.logger.error(`Apple JWS signature INVALID for txn=${transactionId}`);
        throw new BadRequestException('Invalid Apple receipt signature — possible fraud');
      }

      this.logger.error('Apple receipt verification failed', err);
      throw new BadRequestException('Failed to verify Apple receipt');
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

  // ── Refund / Chargeback Handling ───────────────────────────────────────────

  /**
   * Handle an Apple App Store Server Notification (V2).
   * Called from the webhook endpoint when Apple notifies us of a refund.
   */
  async handleAppleNotification(signedPayload: string): Promise<void> {
    try {
      const { decodeNotificationPayload, isDecodedNotificationDataPayload, APPLE_ROOT_CA_G3_FINGERPRINT } =
        await import('app-store-server-api');

      const notification = await decodeNotificationPayload(signedPayload, APPLE_ROOT_CA_G3_FINGERPRINT);

      if (!isDecodedNotificationDataPayload(notification)) {
        this.logger.log(`Apple notification (summary type): ${notification.notificationType}`);
        return;
      }

      const { notificationType, data } = notification;

      if (notificationType === 'REFUND') {
        // Apple refunded this transaction — claw back coins
        const { decodeTransaction } = await import('app-store-server-api');
        const txn = await decodeTransaction(data.signedTransactionInfo!, APPLE_ROOT_CA_G3_FINGERPRINT);
        await this.processRefund(txn.transactionId, 'apple');
      } else {
        this.logger.log(`Apple notification ignored: ${notificationType}`);
      }
    } catch (err) {
      this.logger.error('Failed to process Apple notification', err);
      throw err;
    }
  }

  /**
   * Handle a Google Play Real-Time Developer Notification (RTDN).
   * Called from the webhook endpoint when Google notifies of a voided purchase.
   */
  async handleGoogleNotification(data: {
    packageName: string;
    eventTimeMillis: string;
    oneTimeProductNotification?: {
      version: string;
      notificationType: number;
      purchaseToken: string;
      sku: string;
    };
    voidedPurchaseNotification?: {
      purchaseToken: string;
      orderId: string;
      productType: number;
      refundType: number;
    };
  }): Promise<void> {
    // Google RTDN voidedPurchaseNotification — user was refunded
    if (data.voidedPurchaseNotification) {
      const { orderId } = data.voidedPurchaseNotification;
      this.logger.warn(`Google voided purchase: orderId=${orderId}`);
      await this.processRefund(orderId, 'google');
      return;
    }

    this.logger.log('Google notification ignored (not a voided purchase)');
  }

  /**
   * Core refund processor: finds the original IAP purchase by transaction ID,
   * deducts the credited coins, and records the clawback.
   */
  private async processRefund(transactionId: string, store: string): Promise<void> {
    // Find the original purchase
    const result = await this.databaseService.query<{
      id: string;
      user_id: string;
      coins_credited: number;
    }>(
      `SELECT id, user_id, coins_credited FROM iap_purchases WHERE transaction_id = $1`,
      [transactionId],
    );

    if (result.rows.length === 0) {
      this.logger.warn(`Refund for unknown transaction: ${transactionId} (${store})`);
      return;
    }

    const purchase = result.rows[0];

    // Check if already refunded (idempotent)
    const existingRefund = await this.databaseService.query<{ id: string }>(
      `SELECT id FROM wallet_transactions WHERE type = 'iap_refund' AND metadata->>'transactionId' = $1`,
      [transactionId],
    );
    if (existingRefund.rows.length > 0) {
      this.logger.warn(`Refund already processed for: ${transactionId}`);
      return;
    }

    // Deduct coins (can go negative — that's intentional for fraud prevention)
    await this.databaseService.query(
      `UPDATE wallets SET coin_balance = coin_balance - $2, updated_at = NOW() WHERE user_id = $1`,
      [purchase.user_id, purchase.coins_credited],
    );

    // Record the refund transaction
    await this.databaseService.query(
      `INSERT INTO wallet_transactions (id, user_id, type, coins_delta, amount_usd, metadata, created_at)
       VALUES (gen_random_uuid(), $1, 'iap_refund', $2, NULL, $3::jsonb, NOW())`,
      [
        purchase.user_id,
        -purchase.coins_credited,
        JSON.stringify({ store, transactionId, originalPurchaseId: purchase.id }),
      ],
    );

    this.logger.warn(
      `REFUND PROCESSED: user=${purchase.user_id}, store=${store}, txn=${transactionId}, coins=-${purchase.coins_credited}`,
    );
  }
}
