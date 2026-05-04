import {
  Body,
  Controller,
  DefaultValuePipe,
  Get,
  Headers,
  ParseIntPipe,
  Post,
  Query,
} from '@nestjs/common';
import {
  StoreService,
} from '../core/store.service';
import type {
  CoinPack,
  EconomyConfig,
  GiftCatalogItem,
  WalletSummary,
} from '../core/store.service';
import { PurchaseCoinsDto } from './dto/purchase-coins.dto';

@Controller('v1/economy')
export class EconomyController {
  constructor(private readonly storeService: StoreService) {}

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
  ): { minutes: number; requiredCoins: number; rateCoinsPerMinute: number } {
    return this.storeService.getPrivateCallQuote(minutes);
  }

  @Get('gifts/catalog')
  getGiftCatalog(): GiftCatalogItem[] {
    return this.storeService.listGiftCatalog();
  }
}
