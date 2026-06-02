import { Module } from '@nestjs/common';
import { EconomyController } from './economy.controller';
import { MatchmakingController } from './matchmaking.controller';
import { WebhooksController } from './webhooks.controller';
import { CoreModule } from '../core/core.module';

@Module({
  imports: [CoreModule],
  controllers: [EconomyController, MatchmakingController, WebhooksController],
})
export class EconomyModule {}
