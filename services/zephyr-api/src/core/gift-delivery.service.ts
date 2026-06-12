import { Injectable, Logger } from '@nestjs/common';
import { FcmService } from './fcm.service';
import { StoreService } from './store.service';
import type { GiftDeliveryOutboxItem, GiftSendResult } from './store.service';

interface GiftDeliveryAttemptResult {
  delivered: boolean;
  error?: string;
}

export interface GiftDeliveryRetryResult {
  claimed: number;
  delivered: number;
  failed: number;
}

@Injectable()
export class GiftDeliveryService {
  private readonly logger = new Logger(GiftDeliveryService.name);

  constructor(
    private readonly storeService: StoreService,
    private readonly fcmService: FcmService,
  ) {}

  async deliverCommittedGift(
    gift: GiftSendResult,
    idempotencyKey?: string | null,
  ): Promise<void> {
    if (!this.canDeliverProjection(gift)) {
      return;
    }

    let alreadyDelivered = false;
    try {
      alreadyDelivered = await this.storeService.isGiftDeliveryDelivered(
        gift.giftEventId,
      );
    } catch (error) {
      this.logger.warn(
        `Could not check gift delivery status for ${gift.giftEventId}`,
      );
    }
    if (alreadyDelivered) {
      return;
    }

    const result = await this.deliverProjection(gift, idempotencyKey ?? null);
    await this.recordDeliveryResult(gift.giftEventId, result);
  }

  async retryPendingGiftDeliveries(
    limit = 25,
  ): Promise<GiftDeliveryRetryResult> {
    const deliveries =
      await this.storeService.claimPendingGiftDeliveries(limit);
    let delivered = 0;
    let failed = 0;

    for (const delivery of deliveries) {
      const result = await this.deliverClaimedProjection(delivery);
      if (result.delivered) {
        delivered += 1;
      } else {
        failed += 1;
      }
      await this.recordDeliveryResult(delivery.giftEventId, result);
    }

    return {
      claimed: deliveries.length,
      delivered,
      failed,
    };
  }

  private canDeliverProjection(gift: GiftSendResult): boolean {
    return gift.surface === 'inbox' || gift.surface === 'live_room';
  }

  private async deliverClaimedProjection(
    delivery: GiftDeliveryOutboxItem,
  ): Promise<GiftDeliveryAttemptResult> {
    if (!this.canDeliverProjection(delivery.gift)) {
      return {
        delivered: false,
        error: `Unsupported gift delivery surface: ${delivery.surface}`,
      };
    }
    return this.deliverProjection(delivery.gift, delivery.idempotencyKey);
  }

  private async deliverProjection(
    gift: GiftSendResult,
    idempotencyKey: string | null,
  ): Promise<GiftDeliveryAttemptResult> {
    switch (gift.surface) {
      case 'inbox':
        return this.deliverInboxGift(gift, idempotencyKey);
      case 'live_room':
        return this.deliverLiveRoomGift(gift, idempotencyKey);
      default:
        return {
          delivered: false,
          error: `Unsupported gift delivery surface: ${gift.surface}`,
        };
    }
  }

  private async deliverInboxGift(
    gift: GiftSendResult,
    idempotencyKey: string | null,
  ): Promise<GiftDeliveryAttemptResult> {
    try {
      const [sender, receiver] = await Promise.all([
        this.storeService.getUserById(gift.senderUserId),
        this.storeService.getUserById(gift.receiverUserId),
      ]);
      const writeResult = await this.fcmService.writeInboxGiftMessage({
        chatId: gift.contextId,
        giftEventId: gift.giftEventId,
        senderUserId: sender.id,
        senderDisplayName: sender.displayName,
        senderAvatarUrl: sender.avatarUrl,
        receiverUserId: receiver.id,
        receiverDisplayName: receiver.displayName,
        receiverAvatarUrl: receiver.avatarUrl,
        giftId: gift.giftId,
        giftName: gift.giftName,
        sectionId: gift.sectionId,
        sectionName: gift.sectionName,
        thumbnailUrl: gift.thumbnailUrl,
        animationUrl: gift.animationUrl,
        animationType: gift.animationType,
        tier: gift.tier,
        coinCost: gift.coinCost,
        quantity: gift.quantity,
        totalGiftCoins: gift.totalGiftCoins,
        idempotencyKey,
      });

      if (!writeResult.delivered) {
        return {
          delivered: false,
          error: 'Inbox gift message projection was not delivered',
        };
      }

      if (writeResult.created) {
        this.sendInboxGiftPush(gift, sender.displayName);
      }

      return { delivered: true };
    } catch (error) {
      this.logger.error('Failed to deliver inbox gift projection', error);
      return {
        delivered: false,
        error: this.errorMessage(error),
      };
    }
  }

  private async deliverLiveRoomGift(
    gift: GiftSendResult,
    idempotencyKey: string | null,
  ): Promise<GiftDeliveryAttemptResult> {
    try {
      const sender = await this.storeService.getUserById(gift.senderUserId);
      const delivered = await this.fcmService.writeLiveGiftEvent(
        gift.contextId,
        {
          giftEventId: gift.giftEventId,
          senderUserId: sender.id,
          senderName: sender.displayName,
          giftId: gift.giftId,
          giftName: gift.giftName,
          quantity: gift.quantity,
          totalGiftCoins: gift.totalGiftCoins,
          idempotencyKey,
        },
      );
      return delivered
        ? { delivered: true }
        : {
            delivered: false,
            error: 'Live room gift event projection was not delivered',
          };
    } catch (error) {
      this.logger.error('Failed to deliver live room gift projection', error);
      return {
        delivered: false,
        error: this.errorMessage(error),
      };
    }
  }

  private sendInboxGiftPush(
    gift: GiftSendResult,
    senderDisplayName: string,
  ): void {
    this.storeService
      .getDeviceTokens(gift.receiverUserId)
      .then((tokens) =>
        this.fcmService.sendCommittedChatMessagePush({
          tokens,
          senderId: gift.senderUserId,
          senderDisplayName,
          recipientId: gift.receiverUserId,
          chatId: gift.contextId,
          messageId: gift.giftEventId,
        }),
      )
      .then((pushResult) =>
        this.storeService.deleteDeviceTokensByToken(pushResult.invalidTokens),
      )
      .catch((error) => {
        this.logger.warn(
          `Gift push failed after projection ${gift.giftEventId}: ${this.errorMessage(
            error,
          )}`,
        );
      });
  }

  private async recordDeliveryResult(
    giftEventId: string,
    result: GiftDeliveryAttemptResult,
  ): Promise<void> {
    try {
      if (result.delivered) {
        await this.storeService.markGiftDeliveryDelivered(giftEventId);
      } else {
        await this.storeService.markGiftDeliveryFailed(
          giftEventId,
          result.error ?? 'Gift delivery projection failed',
        );
      }
    } catch (error) {
      this.logger.error(
        `Failed to record gift delivery result for ${giftEventId}`,
        error,
      );
    }
  }

  private errorMessage(error: unknown): string {
    if (error instanceof Error) {
      return error.message;
    }
    if (typeof error === 'string') {
      return error;
    }
    return 'Gift delivery projection failed';
  }
}
