import {
  BadRequestException,
  Body,
  Controller,
  DefaultValuePipe,
  Get,
  Headers,
  Param,
  ParseIntPipe,
  Post,
  Query,
} from '@nestjs/common';
import {
  StoreService,
} from '../core/store.service';
import {
  RtcJoinTokenResult,
  RtcService,
} from '../core/rtc.service';
import type {
  CoinPack,
  EconomyConfig,
  GiftCatalogItem,
  GiftSendResult,
  CallSession,
  CallSessionTickResult,
  WalletSummary,
} from '../core/store.service';
import { EndCallSessionDto } from './dto/end-call-session.dto';
import { PurchaseCoinsDto } from './dto/purchase-coins.dto';
import { SendGiftDto } from './dto/send-gift.dto';
import { StartCallSessionDto } from './dto/start-call-session.dto';
import { TickCallSessionDto } from './dto/tick-call-session.dto';

@Controller('v1/economy')
export class EconomyController {
  constructor(
    private readonly storeService: StoreService,
    private readonly rtcService: RtcService,
  ) {}

  @Get('config')
  getEconomyConfig(): EconomyConfig {
    return this.storeService.getEconomyConfig();
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
  async purchaseCoins(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: PurchaseCoinsDto,
  ): Promise<WalletSummary> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    return this.storeService.purchaseCoins(user.id, body.packId);
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
  async sendGift(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: SendGiftDto,
  ): Promise<GiftSendResult> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    return this.storeService.sendGiftInCall(user.id, {
      sessionId: body.sessionId,
      giftId: body.giftId,
      quantity: body.quantity,
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
    @Param('sessionId') sessionId: string,
    @Body() body: TickCallSessionDto,
  ): Promise<CallSessionTickResult> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    return this.storeService.tickCallSession(
      user.id,
      sessionId,
      body.elapsedSeconds,
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
}
