import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { admin, ensureFirebaseAdminInitialized } from './firebase-admin';

export interface FcmSendResult {
  invalidTokens: string[];
}

export interface CommittedChatPushResult extends FcmSendResult {
  sent: boolean;
}

function isInvalidFcmTokenError(error: unknown): boolean {
  const code =
    typeof error === 'object' && error !== null && 'code' in error
      ? String((error as { code?: unknown }).code ?? '')
      : '';
  return (
    code === 'messaging/registration-token-not-registered' ||
    code === 'messaging/invalid-registration-token'
  );
}

@Injectable()
export class FcmService implements OnModuleInit {
  private readonly logger = new Logger(FcmService.name);
  private initialized = false;

  onModuleInit() {
    this.initialized = ensureFirebaseAdminInitialized(this.logger);
    if (!this.initialized) {
      this.logger.warn(
        'FIREBASE_SERVICE_ACCOUNT_JSON not set — push notifications disabled',
      );
    }
  }

  async sendPush(
    tokens: string[],
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<FcmSendResult> {
    if (!this.initialized || tokens.length === 0) {
      return { invalidTokens: [] };
    }
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
      const invalidTokens = response.responses.flatMap((r, index) =>
        !r.success && isInvalidFcmTokenError(r.error) ? [tokens[index]] : [],
      );
      return { invalidTokens };
    } catch (err) {
      this.logger.error('FCM sendPush error', err);
      return { invalidTokens: [] };
    }
  }

  async sendReadReceiptPush(
    tokens: string[],
    messageId: string,
    readAt: string,
  ): Promise<FcmSendResult> {
    if (!this.initialized || tokens.length === 0) {
      return { invalidTokens: [] };
    }
    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        data: { type: 'read_receipt', messageId, readAt },
        android: { priority: 'high' },
        apns: {
          headers: { 'apns-push-type': 'background', 'apns-priority': '5' },
          payload: { aps: { 'content-available': 1 } },
        },
      });
      const invalidTokens = response.responses.flatMap((r, index) =>
        !r.success && isInvalidFcmTokenError(r.error) ? [tokens[index]] : [],
      );
      return { invalidTokens };
    } catch (err) {
      this.logger.error('FCM sendReadReceiptPush error', err);
      return { invalidTokens: [] };
    }
  }

  async sendCommittedChatMessagePush(input: {
    tokens: string[];
    senderId: string;
    senderDisplayName: string;
    recipientId: string;
    chatId: string;
    messageId: string;
  }): Promise<CommittedChatPushResult> {
    if (!this.initialized || input.tokens.length === 0) {
      return { sent: false, invalidTokens: [] };
    }

    try {
      const chatRef = admin.firestore().collection('chats').doc(input.chatId);
      const [chatSnap, messageSnap] = await Promise.all([
        chatRef.get(),
        chatRef.collection('messages').doc(input.messageId).get(),
      ]);

      const participants = chatSnap.data()?.participants;
      if (
        !Array.isArray(participants) ||
        !participants.includes(input.senderId) ||
        !participants.includes(input.recipientId)
      ) {
        return { sent: false, invalidTokens: [] };
      }

      const message = messageSnap.data();
      if (!message || message.senderId !== input.senderId) {
        return { sent: false, invalidTokens: [] };
      }

      const type = typeof message.type === 'string' ? message.type : 'text';
      const body =
        type === 'image'
          ? 'Photo'
          : String(message.body ?? '')
              .trim()
              .slice(0, 200);
      if (!body) return { sent: false, invalidTokens: [] };

      const result = await this.sendPush(
        input.tokens,
        input.senderDisplayName,
        body,
        {
          type: 'chat_message',
          source: 'firestore',
          senderId: input.senderId,
          chatId: input.chatId,
          messageId: input.messageId,
        },
      );
      return { sent: true, invalidTokens: result.invalidTokens };
    } catch (err) {
      this.logger.error('Failed to verify/send Firestore chat push', err);
      return { sent: false, invalidTokens: [] };
    }
  }

  async setActiveFirebaseSession(input: {
    userId: string;
    sessionId: string;
    deviceId: string;
  }): Promise<void> {
    if (!this.initialized) return;

    await Promise.all([
      admin.firestore().collection('session_controls').doc(input.userId).set({
        activeSessionId: input.sessionId,
        activeDeviceId: input.deviceId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
      admin.database().ref(`session_controls/${input.userId}`).set({
        activeSessionId: input.sessionId,
        activeDeviceId: input.deviceId,
        updatedAt: admin.database.ServerValue.TIMESTAMP,
      }),
    ]);
  }

  async clearActiveFirebaseSession(input: {
    userId: string;
    sessionId: string;
  }): Promise<void> {
    if (!this.initialized) return;

    await Promise.all([
      admin.firestore().runTransaction(async (transaction) => {
        const ref = admin
          .firestore()
          .collection('session_controls')
          .doc(input.userId);
        const snapshot = await transaction.get(ref);
        if (
          !snapshot.exists ||
          snapshot.get('activeSessionId') === input.sessionId
        ) {
          transaction.delete(ref);
        }
      }),
      admin
        .database()
        .ref(`session_controls/${input.userId}`)
        .transaction((current) => {
          if (!current || current.activeSessionId === input.sessionId) {
            return null;
          }
          return current;
        }),
    ]);
  }

  async createCustomToken(
    userId: string,
    claims?: {
      sessionId?: string | null;
      deviceId?: string | null;
    },
  ): Promise<string | null> {
    if (!this.initialized) return null;
    return admin.auth().createCustomToken(userId, {
      ...(claims?.sessionId ? { sessionId: claims.sessionId } : {}),
      ...(claims?.deviceId ? { deviceId: claims.deviceId } : {}),
    });
  }

  async writeBlockProjection(
    blockerId: string,
    blockedId: string,
  ): Promise<void> {
    if (!this.initialized) return;
    await admin
      .firestore()
      .collection('blocks')
      .doc(`${blockerId}_${blockedId}`)
      .set({
        blockedBy: blockerId,
        blockedUser: blockedId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
  }

  async removeBlockProjection(
    blockerId: string,
    blockedId: string,
  ): Promise<void> {
    if (!this.initialized) return;
    await admin
      .firestore()
      .collection('blocks')
      .doc(`${blockerId}_${blockedId}`)
      .delete();
  }

  /** Write a call signal to RTDB at direct_calls/{userId}. */
  async writeCallSignal(
    userId: string,
    data: Record<string, unknown>,
  ): Promise<void> {
    if (!this.initialized) return;
    await admin.database().ref(`direct_calls/${userId}`).set(data);
  }

  /** Remove a user's call signal node from RTDB. */
  async removeCallSignal(userId: string): Promise<void> {
    if (!this.initialized) return;
    await admin.database().ref(`direct_calls/${userId}`).remove();
  }

  /**
   * Publish a trusted live-room gift event after the backend economy ledger
   * has already succeeded. Firebase Admin bypasses client RTDB rules; clients
   * can read this fan-out but cannot forge it.
   */
  async writeLiveGiftEvent(
    roomId: string,
    data: {
      senderUserId: string;
      senderName: string;
      giftId: string;
      giftName: string;
      quantity: number;
      totalGiftCoins: number;
      idempotencyKey?: string | null;
    },
  ): Promise<void> {
    if (!this.initialized) return;

    try {
      const giftsRef = admin.database().ref(`live_rooms/${roomId}/gifts`);
      const eventKey = this.toRealtimeKey(data.idempotencyKey);
      const eventRef = eventKey ? giftsRef.child(eventKey) : giftsRef.push();
      await eventRef.set({
        senderUserId: data.senderUserId,
        senderName: data.senderName,
        giftId: data.giftId,
        giftName: data.giftName,
        quantity: data.quantity,
        totalGiftCoins: data.totalGiftCoins,
        trusted: true,
        eventId: eventRef.key,
        ts: admin.database.ServerValue.TIMESTAMP,
      });
    } catch (err) {
      this.logger.error('Failed to write live gift event', err);
    }
  }

  private toRealtimeKey(value?: string | null): string | null {
    if (!value) return null;
    const normalized = value.replace(/[.#$\/\[\]]/g, '_').slice(0, 180);
    return normalized.length > 0 ? normalized : null;
  }

  /**
   * Delete user-owned Firebase data so account deletion leaves no runtime traces.
   * Best-effort: ignores missing resources and continues cleanup.
   */
  async deleteUserRealtimeData(userId: string): Promise<void> {
    if (!this.initialized) return;

    // RTDB: remove direct user-owned nodes
    let roomIdFromPresence: string | null = null;
    try {
      const presenceSnap = await admin
        .database()
        .ref(`presence/${userId}`)
        .get();
      const presence = presenceSnap.val() as { roomId?: string } | null;
      roomIdFromPresence = presence?.roomId ?? null;
    } catch {
      roomIdFromPresence = null;
    }

    await admin
      .database()
      .ref()
      .update({
        [`session_controls/${userId}`]: null,
        [`presence/${userId}`]: null,
        [`profiles/${userId}`]: null,
        [`direct_calls/${userId}`]: null,
      });

    // RTDB: remove incoming call nodes where this user is caller
    try {
      const callsByCaller = await admin
        .database()
        .ref('direct_calls')
        .orderByChild('callerId')
        .equalTo(userId)
        .get();
      const updates: Record<string, null> = {};
      callsByCaller.forEach((child) => {
        updates[`direct_calls/${child.key}`] = null;
      });
      if (Object.keys(updates).length > 0) {
        await admin.database().ref().update(updates);
      }
    } catch {
      // Ignore query failures in best-effort cleanup.
    }

    // RTDB: if user was live, remove that room node too.
    if (roomIdFromPresence) {
      try {
        await admin.database().ref(`live_rooms/${roomIdFromPresence}`).remove();
      } catch {
        // Ignore if room already removed.
      }
    }

    // Firestore: delete all chats this user participated in (including subcollections).
    try {
      const firestore = admin.firestore();
      await firestore.collection('session_controls').doc(userId).delete();
      const chatSnap = await firestore
        .collection('chats')
        .where('participants', 'array-contains', userId)
        .get();
      for (const doc of chatSnap.docs) {
        await firestore.recursiveDelete(doc.ref);
      }
    } catch {
      // Ignore if Firestore is unavailable.
    }

    // Firebase Auth account (custom token identity)
    try {
      await admin.auth().deleteUser(userId);
    } catch {
      // Ignore if user does not exist.
    }
  }
}
