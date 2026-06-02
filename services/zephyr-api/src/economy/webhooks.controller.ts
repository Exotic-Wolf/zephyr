import {
  BadRequestException,
  Body,
  Controller,
  Headers,
  HttpCode,
  Logger,
  Post,
} from '@nestjs/common';
import { IapService } from '../core/iap.service';

/**
 * Webhook endpoints for Apple App Store Server Notifications V2
 * and Google Play Real-Time Developer Notifications.
 *
 * These are called by Apple/Google servers when purchases are refunded,
 * revoked, or otherwise modified. No user auth — validated by signature/secret.
 */
@Controller('v1/webhooks')
export class WebhooksController {
  private readonly logger = new Logger(WebhooksController.name);

  constructor(private readonly iapService: IapService) {}

  /**
   * Apple App Store Server Notifications V2.
   * Apple sends a signed JWS payload — we verify with their root cert.
   * URL to configure in App Store Connect: https://your-api.com/v1/webhooks/apple
   */
  @Post('apple')
  @HttpCode(200)
  async handleAppleWebhook(
    @Body() body: { signedPayload?: string },
  ): Promise<{ success: boolean }> {
    if (!body.signedPayload) {
      throw new BadRequestException('Missing signedPayload');
    }

    try {
      await this.iapService.handleAppleNotification(body.signedPayload);
      return { success: true };
    } catch (err) {
      this.logger.error('Apple webhook processing failed', err);
      // Still return 200 to Apple — they'll retry otherwise and flood us.
      // We log the error for investigation.
      return { success: false };
    }
  }

  /**
   * Google Play Real-Time Developer Notifications (RTDN).
   * Google sends via Cloud Pub/Sub push subscription.
   * URL to configure: https://your-api.com/v1/webhooks/google
   *
   * Validates the shared secret in the query param or header.
   */
  @Post('google')
  @HttpCode(200)
  async handleGoogleWebhook(
    @Body() body: { message?: { data?: string }; subscription?: string },
    @Headers('authorization') authorization?: string,
  ): Promise<{ success: boolean }> {
    // Google Cloud Pub/Sub wraps the data in base64
    const webhookSecret = process.env.GOOGLE_RTDN_WEBHOOK_SECRET;
    if (webhookSecret && authorization !== `Bearer ${webhookSecret}`) {
      this.logger.warn('Google webhook: invalid authorization');
      throw new BadRequestException('Invalid authorization');
    }

    if (!body.message?.data) {
      throw new BadRequestException('Missing message.data');
    }

    try {
      const decoded = Buffer.from(body.message.data, 'base64').toString('utf8');
      const notification = JSON.parse(decoded);

      await this.iapService.handleGoogleNotification(notification);
      return { success: true };
    } catch (err) {
      this.logger.error('Google webhook processing failed', err);
      return { success: false };
    }
  }
}
