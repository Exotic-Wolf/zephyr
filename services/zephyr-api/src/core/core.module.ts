import { Global, Module } from '@nestjs/common';
import { AgoraChatService } from './agora-chat.service';
import { DatabaseService } from './database.service';
import { FcmService } from './fcm.service';
import { RtcService } from './rtc.service';
import { StoreService } from './store.service';

@Global()
@Module({
  providers: [DatabaseService, StoreService, RtcService, FcmService, AgoraChatService],
  exports: [DatabaseService, StoreService, RtcService, FcmService, AgoraChatService],
})
export class CoreModule {}