import { Module } from '@nestjs/common';
import { RoomsController } from './rooms.controller';
import { RoomsGateway } from './rooms.gateway';
import { MatchmakingGateway } from './matchmaking.gateway';

@Module({
  controllers: [RoomsController],
  providers: [RoomsGateway, MatchmakingGateway],
  exports: [RoomsGateway, MatchmakingGateway],
})
export class RoomsModule {}