import {
  BadRequestException,
  Injectable,
  Logger,
} from '@nestjs/common';
import { GoogleAuth } from 'google-auth-library';
import { DatabaseService } from './database.service';
import { StoreService } from './store.service';
import type { WalletSummary, CoinPack } from './store.service';

export interface VerifyPurchaseInput {
  store: 'apple' | 'google';
  productId: string;
  transactionId: string;
  receiptData?: string;
}

interface NormalizedPurchaseInput {
  store: 'apple' | 'google';
  productId: string;
  transactionId: string;
  receiptData?: string;
  googlePurchaseToken?: string;
}

interface VerifiedPurchaseMetadata {
  packageName?: string;
  storeOrderId?: string;
  purchaseToken?: string;
  consumptionState?: number;
  acknowledgementState?: number;
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
    const { store, productId, transactionId, receiptData, googlePurchaseToken } =
      this.normalizePurchaseInput(input);

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
    let metadata: VerifiedPurchaseMetadata = {};
    if (store === 'apple') {
      await this.verifyAppleReceipt(transactionId, productId, receiptData);
    } else {
      metadata = await this.verifyGoogleReceipt(
        googlePurchaseToken ?? transactionId,
        productId,
      );
    }

    // 5. Credit coins + record purchase in a transaction
    try {
      await this.databaseService.transaction(async (client) => {
        // Ensure wallet exists inside the same DB transaction.
        await this.storeService.ensureWalletAndRevenueRows(userId, client);

        // Record first so duplicate transaction IDs fail before wallet credit.
        await client.query(
          `INSERT INTO iap_purchases (
             user_id,
             store,
             transaction_id,
             product_id,
             coins_credited,
             amount_usd,
             receipt_data,
             store_order_id,
             package_name
           )
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
          [
            userId,
            store,
            transactionId,
            productId,
            pack.coins,
            pack.priceUsd,
            receiptData ?? null,
            metadata.storeOrderId ?? null,
            metadata.packageName ?? null,
          ],
        );

        await client.query(
          `UPDATE wallets SET coin_balance = coin_balance + $2, updated_at = NOW() WHERE user_id = $1`,
          [userId, pack.coins],
        );

        await client.query(
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
              storeOrderId: metadata.storeOrderId,
              packageName: metadata.packageName,
              consumptionState: metadata.consumptionState,
              acknowledgementState: metadata.acknowledgementState,
              packLabel: pack.label,
            }),
          ],
        );
      });
    } catch (err: unknown) {
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

  private normalizePurchaseInput(
    input: VerifyPurchaseInput,
  ): NormalizedPurchaseInput {
    const store = input.store;
    const productId = input.productId?.trim();
    const rawTransactionId = input.transactionId?.trim();
    const receiptData = input.receiptData?.trim() || undefined;

    if (!rawTransactionId) {
      throw new BadRequestException('transactionId is required');
    }
    if (!productId) {
      throw new BadRequestException('productId is required');
    }

    if (store === 'google') {
      // Flutter in_app_purchase exposes the Play purchase token as
      // verificationData.serverVerificationData. Prefer it so older builds that
      // sent purchaseID/orderId as transactionId still verify correctly.
      const googlePurchaseToken = receiptData || rawTransactionId;
      if (!googlePurchaseToken) {
        throw new BadRequestException('Google purchase token is required');
      }

      return {
        store,
        productId,
        transactionId: googlePurchaseToken,
        receiptData: googlePurchaseToken,
        googlePurchaseToken,
      };
    }

    return {
      store,
      productId,
      transactionId: rawTransactionId,
      receiptData,
    };
  }

  // ── Apple StoreKit 2 Verification ──────────────────────────────────────────

  private async verifyAppleReceipt(
    transactionId: string,
    expectedProductId: string,
    receiptData?: string,
  ): Promise<void> {
    const bundleId = process.env.APPLE_BUNDLE_ID ?? 'com.zephyr.zephyrMobile';
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
  ): Promise<VerifiedPurchaseMetadata> {
    // Google Play receipt verification uses the Android Publisher API.
    // The purchaseToken is sent by the client after a successful purchase.
    //
    // If GOOGLE_PLAY_SERVICE_ACCOUNT_KEY is not set, we operate in sandbox/trust mode.

    const packageName =
      process.env.GOOGLE_PLAY_PACKAGE_NAME ?? 'com.zephyr.zephyr_mobile';
    const credentials = this.getGooglePlayServiceAccountCredentials();

    if (!credentials) {
      if (process.env.NODE_ENV === 'production') {
        throw new BadRequestException(
          'Google Play service account is required in production',
        );
      }
      this.logger.warn(
        `Google sandbox mode: trusting purchaseToken for product=${expectedProductId}`,
      );
      return { packageName, purchaseToken };
    }

    // Use Google Auth Library to call the Android Publisher API
    try {
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
        orderId?: string;
        productId?: string;
        purchaseToken?: string;
        quantity?: number;
      };

      if (data.productId && data.productId !== expectedProductId) {
        throw new BadRequestException(
          `Google product mismatch: expected ${expectedProductId}, got ${data.productId}`,
        );
      }
      if (data.purchaseToken && data.purchaseToken !== purchaseToken) {
        throw new BadRequestException('Google purchase token mismatch');
      }

      // purchaseState: 0 = purchased, 1 = canceled, 2 = pending
      if (data.purchaseState !== 0) {
        throw new BadRequestException(
          `Google purchase not in valid state: ${data.purchaseState}`,
        );
      }
      // consumptionState: 0 = yet to be consumed, 1 = consumed.
      // We credit before the client consumes. If this is already consumed and
      // not in our DB, do not trust it as a fresh coin purchase.
      if (
        data.consumptionState !== undefined &&
        data.consumptionState !== 0
      ) {
        throw new BadRequestException(
          `Google purchase already consumed: ${data.consumptionState}`,
        );
      }
      if (data.quantity !== undefined && data.quantity !== 1) {
        throw new BadRequestException(
          `Google purchase quantity is not supported: ${data.quantity}`,
        );
      }

      this.logger.log(
        `Google receipt verified: product=${expectedProductId}, state=${data.purchaseState}`,
      );
      return {
        packageName,
        storeOrderId: data.orderId,
        purchaseToken: data.purchaseToken ?? purchaseToken,
        consumptionState: data.consumptionState,
        acknowledgementState: data.acknowledgementState,
      };
    } catch (err) {
      if (err instanceof BadRequestException) throw err;
      this.logger.error('Google receipt verification failed', err);
      throw new BadRequestException('Failed to verify Google Play purchase');
    }
  }

  private getGooglePlayServiceAccountCredentials(): Record<string, unknown> | null {
    const rawJson = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY?.trim();
    const rawBase64 =
      process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY_BASE64?.trim();
    const value = rawJson
      ? rawJson
      : rawBase64
        ? Buffer.from(rawBase64, 'base64').toString('utf8')
        : null;
    if (!value) {
      return null;
    }

    try {
      return JSON.parse(value) as Record<string, unknown>;
    } catch (err) {
      this.logger.error('Invalid Google Play service account JSON', err);
      throw new BadRequestException(
        'Google Play service account configuration is invalid',
      );
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
      const { orderId, purchaseToken } = data.voidedPurchaseNotification;
      this.logger.warn(
        `Google voided purchase: orderId=${orderId}, purchaseToken=${purchaseToken}`,
      );
      await this.processRefund(purchaseToken, 'google');
      return;
    }

    this.logger.log('Google notification ignored (not a voided purchase)');
  }

  /**
   * Core refund processor: finds the original IAP purchase by transaction ID,
   * deducts the credited coins, and records the clawback.
   */
  private async processRefund(transactionId: string, store: string): Promise<void> {
    try {
      const purchase = await this.databaseService.transaction(async (client) => {
        const result = await client.query<{
          id: string;
          user_id: string;
          coins_credited: number;
        }>(
          `
            SELECT id, user_id, coins_credited
            FROM iap_purchases
            WHERE transaction_id = $1
            FOR UPDATE
          `,
          [transactionId],
        );

        if (result.rows.length === 0) {
          return null;
        }

        const purchase = result.rows[0];

        const existingRefund = await client.query<{ id: string }>(
          `SELECT id FROM wallet_transactions WHERE type = 'iap_refund' AND metadata->>'transactionId' = $1`,
          [transactionId],
        );
        if (existingRefund.rows.length > 0) {
          return { ...purchase, alreadyRefunded: true };
        }

        await client.query(
          `UPDATE wallets SET coin_balance = coin_balance - $2, updated_at = NOW() WHERE user_id = $1`,
          [purchase.user_id, purchase.coins_credited],
        );

        await client.query(
          `INSERT INTO wallet_transactions (id, user_id, type, coins_delta, amount_usd, metadata, created_at)
           VALUES (gen_random_uuid(), $1, 'iap_refund', $2, NULL, $3::jsonb, NOW())`,
          [
            purchase.user_id,
            -purchase.coins_credited,
            JSON.stringify({ store, transactionId, originalPurchaseId: purchase.id }),
          ],
        );

        return { ...purchase, alreadyRefunded: false };
      });

      if (!purchase) {
        this.logger.warn(`Refund for unknown transaction: ${transactionId} (${store})`);
        return;
      }

      if (purchase.alreadyRefunded) {
        this.logger.warn(`Refund already processed for: ${transactionId}`);
        return;
      }

      this.logger.warn(
        `REFUND PROCESSED: user=${purchase.user_id}, store=${store}, txn=${transactionId}, coins=-${purchase.coins_credited}`,
      );
    } catch (err: unknown) {
      if (
        err instanceof Error &&
        'code' in err &&
        (err as { code: string }).code === '23505'
      ) {
        this.logger.warn(`Concurrent refund duplicate prevented: ${transactionId}`);
        return;
      }
      throw err;
    }
  }
}
