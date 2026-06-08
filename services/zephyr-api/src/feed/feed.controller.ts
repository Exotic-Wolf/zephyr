import {
  Controller,
  DefaultValuePipe,
  Get,
  Headers,
  ParseIntPipe,
  Query,
} from '@nestjs/common';
import { StoreService } from '../core/store.service';
import type { LiveFeedCard } from '../core/store.service';

@Controller('v1/feed')
export class FeedController {
  constructor(private readonly storeService: StoreService) {}

  @Get('live')
  async listLiveFeed(
    @Headers('authorization') authorization: string | undefined,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
    @Query('offset', new DefaultValuePipe(0), ParseIntPipe) offset: number,
    @Query('liveOnly') liveOnly?: string,
  ): Promise<LiveFeedCard[]> {
    await this.storeService.getUserFromAuthHeader(authorization);
    return this.storeService.listLiveFeed(limit, {
      offset,
      liveOnly: liveOnly === 'true' || liveOnly === '1',
    });
  }
}
