import { Module } from '@nestjs/common';
import { CoreModule } from '../core/core.module';
import { RoomsModule } from '../rooms/rooms.module';
import { MessagesController } from './messages.controller';
import { MessagesGateway } from './messages.gateway';

@Module({
  imports: [CoreModule, RoomsModule],
  controllers: [MessagesController],
  providers: [MessagesGateway],
  exports: [MessagesGateway],
})
export class MessagesModule {}
