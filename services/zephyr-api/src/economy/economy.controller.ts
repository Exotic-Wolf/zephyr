import {
  BadRequestException,
  Body,
  Controller,
  DefaultValuePipe,
  ForbiddenException,
  Get,
  Headers,
  Param,
  ParseIntPipe,
  Post,
  Query,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { StoreService } from '../core/store.service';
import { FcmService } from '../core/fcm.service';
import { IapService, PurchaseResult } from '../core/iap.service';
import { RtcJoinTokenResult, RtcService } from '../core/rtc.service';
import type {
  CoinPack,
  EconomyConfig,
  GiftCatalogItem,
  GiftSendResult,
  CallSession,
  CallSessionTickResult,
  CallRateTier,
  WalletSummary,
} from '../core/store.service';
import { EndCallSessionDto } from './dto/end-call-session.dto';
import { PurchaseCoinsDto } from './dto/purchase-coins.dto';
import { SendGiftDto } from './dto/send-gift.dto';
import { StartCallSessionDto } from './dto/start-call-session.dto';
import { TickCallSessionDto } from './dto/tick-call-session.dto';
import { VerifyPurchaseDto } from './dto/verify-purchase.dto';

@Controller('v1/economy')
export class EconomyController {
  constructor(
    private readonly storeService: StoreService,
    private readonly rtcService: RtcService,
    private readonly iapService: IapService,
    private readonly fcmService: FcmService,
  ) {}

  @Get('config')
  getEconomyConfig(): EconomyConfig {
    return this.storeService.getEconomyConfig();
  }

  @Get('call-rate-tiers')
  getCallRateTiers(): CallRateTier[] {
    return this.storeService.getCallRateTiers();
  }

  @Get('coin-packs')
  listCoinPacks(): CoinPack[] {
    return this.storeService.listCoinPacks();
  }

  @Get('wallet')
  async getWallet(
    @Headers('authorization') authorization: string | undefined,
  ): Promise<WalletSummary> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    return this.storeService.getWalletSummary(user.id);
  }

  @Post('purchase-coins')
  @Throttle({ default: { ttl: 60_000, limit: 5 } })
  async purchaseCoins(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: PurchaseCoinsDto,
  ): Promise<WalletSummary> {
    const allowFakePurchases =
      process.env.ALLOW_FAKE_PURCHASES === 'true' ||
      process.env.NODE_ENV !== 'production';
    if (!allowFakePurchases) {
      throw new ForbiddenException(
        'Direct coin purchase is disabled. Use verify-purchase with a valid store receipt.',
      );
    }

    const user = await this.storeService.getUserFromAuthHeader(authorization);
    return this.storeService.purchaseCoins(user.id, body.packId);
  }

  @Post('verify-purchase')
  @Throttle({ default: { ttl: 60_000, limit: 10 } })
  async verifyPurchase(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: VerifyPurchaseDto,
  ): Promise<PurchaseResult> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    return this.iapService.verifyAndCreditPurchase(user.id, {
      store: body.store as 'apple' | 'google',
      productId: body.productId,
      transactionId: body.transactionId,
      receiptData: body.receiptData,
    });
  }

  @Get('private-call/quote')
  getPrivateCallQuote(
    @Query('minutes', new DefaultValuePipe(1), ParseIntPipe) minutes: number,
    @Query('mode') mode?: string,
    @Query('rateCoinsPerMinute') rateCoinsPerMinuteRaw?: string,
  ): {
    minutes: number;
    mode: 'direct' | 'random';
    requiredCoins: number;
    rateCoinsPerMinute: number;
    directCallAllowedRatesCoinsPerMinute: number[];
  } {
    const normalizedMode =
      mode === undefined || mode === '' ? 'direct' : mode.toLowerCase();
    if (normalizedMode !== 'direct' && normalizedMode !== 'random') {
      throw new BadRequestException('mode must be one of: direct, random');
    }

    let directRateCoinsPerMinute: number | undefined;
    if (rateCoinsPerMinuteRaw !== undefined && rateCoinsPerMinuteRaw !== '') {
      const parsed = Number.parseInt(rateCoinsPerMinuteRaw, 10);
      if (!Number.isFinite(parsed) || parsed <= 0) {
        throw new BadRequestException(
          'rateCoinsPerMinute must be a positive integer',
        );
      }
      directRateCoinsPerMinute = parsed;
    }

    return this.storeService.getPrivateCallQuote(minutes, {
      mode: normalizedMode,
      directRateCoinsPerMinute,
    });
  }

  @Get('gifts/catalog')
  getGiftCatalog(): GiftCatalogItem[] {
    return this.storeService.listGiftCatalog();
  }

  @Post('gifts/send')
  @Throttle({ default: { ttl: 60_000, limit: 30 } })
  async sendGift(
    @Headers('authorization') authorization: string | undefined,
    @Headers('x-idempotency-key') idempotencyKeyHeader: string | undefined,
    @Body() body: SendGiftDto,
  ): Promise<GiftSendResult> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    const idempotencyKey = idempotencyKeyHeader ?? body.idempotencyKey;
    if (body.surface) {
      const result = await this.storeService.sendGift(user.id, {
        surface: body.surface,
        contextId: body.contextId ?? body.sessionId,
        receiverUserId: body.receiverUserId,
        giftId: body.giftId,
        quantity: body.quantity,
        idempotencyKey,
      });

      if (result.surface === 'live_room') {
        await this.fcmService.writeLiveGiftEvent(result.contextId, {
          giftEventId: result.giftEventId,
          senderUserId: user.id,
          senderName: user.displayName,
          giftId: result.giftId,
          giftName: result.giftName,
          quantity: result.quantity,
          totalGiftCoins: result.totalGiftCoins,
          idempotencyKey,
        });
      }

      if (result.surface === 'inbox') {
        const receiver = await this.storeService.getUserById(
          result.receiverUserId,
        );
        const writeResult = await this.fcmService.writeInboxGiftMessage({
          chatId: result.contextId,
          giftEventId: result.giftEventId,
          senderUserId: user.id,
          senderDisplayName: user.displayName,
          senderAvatarUrl: user.avatarUrl,
          receiverUserId: receiver.id,
          receiverDisplayName: receiver.displayName,
          receiverAvatarUrl: receiver.avatarUrl,
          giftId: result.giftId,
          giftName: result.giftName,
          sectionId: result.sectionId,
          sectionName: result.sectionName,
          thumbnailUrl: result.thumbnailUrl,
          animationUrl: result.animationUrl,
          animationType: result.animationType,
          tier: result.tier,
          coinCost: result.coinCost,
          quantity: result.quantity,
          totalGiftCoins: result.totalGiftCoins,
          idempotencyKey,
        });

        if (writeResult.created) {
          this.storeService
            .getDeviceTokens(receiver.id)
            .then((tokens) =>
              this.fcmService.sendCommittedChatMessagePush({
                tokens,
                senderId: user.id,
                senderDisplayName: user.displayName,
                recipientId: receiver.id,
                chatId: result.contextId,
                messageId: result.giftEventId,
              }),
            )
            .then((pushResult) =>
              this.storeService.deleteDeviceTokensByToken(
                pushResult.invalidTokens,
              ),
            )
            .catch(() => {});
        }
      }

      return result;
    }

    if (!body.sessionId) {
      throw new BadRequestException('surface and contextId are required');
    }

    return this.storeService.sendGiftInCall(user.id, {
      sessionId: body.sessionId,
      giftId: body.giftId,
      quantity: body.quantity,
      idempotencyKey,
    });
  }

  @Get('calls')
  async getCallHistory(
    @Headers('authorization') authorization: string | undefined,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
  ): Promise<CallSession[]> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    return this.storeService.getCallHistory(user.id, limit);
  }

  @Get('transactions')
  async getTransactionHistory(
    @Headers('authorization') authorization: string | undefined,
    @Query('limit', new DefaultValuePipe(50), ParseIntPipe) limit: number,
  ) {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    return this.storeService.getTransactionHistory(user.id, limit);
  }

  @Post('calls/start')
  async startCallSession(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: StartCallSessionDto,
  ): Promise<CallSession> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    return this.storeService.startCallSession(user.id, {
      mode: body.mode,
      receiverUserId: body.receiverUserId,
      directRateCoinsPerMinute: body.directRateCoinsPerMinute,
    });
  }

  @Post('calls/:sessionId/tick')
  async tickCallSession(
    @Headers('authorization') authorization: string | undefined,
    @Headers('x-idempotency-key') idempotencyKeyHeader: string | undefined,
    @Param('sessionId') sessionId: string,
    @Body() body: TickCallSessionDto,
  ): Promise<CallSessionTickResult> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    return this.storeService.tickCallSession(
      user.id,
      sessionId,
      body.elapsedSeconds,
      idempotencyKeyHeader ?? body.idempotencyKey,
    );
  }

  @Post('calls/:sessionId/end')
  async endCallSession(
    @Headers('authorization') authorization: string | undefined,
    @Param('sessionId') sessionId: string,
    @Body() body: EndCallSessionDto,
  ): Promise<CallSession> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    return this.storeService.endCallSession(
      user.id,
      sessionId,
      body.reason ?? 'caller_ended',
    );
  }

  @Post('calls/:sessionId/rtc-token')
  async createCallRtcToken(
    @Headers('authorization') authorization: string | undefined,
    @Param('sessionId') sessionId: string,
  ): Promise<RtcJoinTokenResult> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    const participant = await this.storeService.getLiveCallSessionParticipant(
      sessionId,
      user.id,
    );

    return this.rtcService.createJoinToken({
      sessionId,
      userId: user.id,
      role: participant.role,
    });
  }

  @Post('calls/:sessionId/report')
  async reportCall(
    @Headers('authorization') authorization: string | undefined,
    @Param('sessionId') sessionId: string,
    @Body() body: { reportedUserId: string; reason?: string },
  ): Promise<void> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    await this.storeService.reportCall(
      user.id,
      sessionId,
      body.reportedUserId,
      body.reason,
    );
  }
}
