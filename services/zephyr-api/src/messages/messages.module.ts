import { Module } from '@nestjs/common';
import { CoreModule } from '../core/core.module';
import { MessagesController } from './messages.controller';

@Module({
  imports: [CoreModule],
  controllers: [MessagesController],
})
export class MessagesModule {}
