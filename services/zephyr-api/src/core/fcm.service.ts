import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import * as admin from 'firebase-admin';

@Injectable()
export class FcmService implements OnModuleInit {
  private readonly logger = new Logger(FcmService.name);
  private initialized = false;

  onModuleInit() {
    const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    if (!serviceAccountJson) {
      this.logger.warn('FIREBASE_SERVICE_ACCOUNT_JSON not set — push notifications disabled');
      return;
    }
    try {
      const serviceAccount = JSON.parse(serviceAccountJson);
      admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
      this.initialized = true;
      this.logger.log('Firebase Admin SDK initialized');
    } catch (err) {
      this.logger.error('Failed to initialize Firebase Admin SDK', err);
    }
  }

  async sendPush(tokens: string[], title: string, body: string, data?: Record<string, string>): Promise<void> {
    if (!this.initialized || tokens.length === 0) return;
    try {
      // tag = senderId so messages from the same person replace each other (no spam)
      const tag = data?.senderId ?? 'default';
      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title, body },
        data: data ?? {},
        android: {
          priority: 'high',
          notification: { sound: 'default', tag },
        },
        apns: {
          headers: { 'apns-collapse-id': tag },
          payload: { aps: { sound: 'default' } },
        },
      });
      const failed = response.responses.filter((r) => !r.success).length;
      if (failed > 0) {
        this.logger.warn(`FCM: ${failed}/${tokens.length} tokens failed`);
      }
    } catch (err) {
      this.logger.error('FCM sendPush error', err);
    }
  }

  async sendReadReceiptPush(tokens: string[], messageId: string, readAt: string): Promise<void> {
    if (!this.initialized || tokens.length === 0) return;
    try {
      await admin.messaging().sendEachForMulticast({
        tokens,
        data: { type: 'read_receipt', messageId, readAt },
        android: { priority: 'high' },
        apns: {
          headers: { 'apns-push-type': 'background', 'apns-priority': '5' },
          payload: { aps: { 'content-available': 1 } },
        },
      });
    } catch (err) {
      this.logger.error('FCM sendReadReceiptPush error', err);
    }
  }
}
