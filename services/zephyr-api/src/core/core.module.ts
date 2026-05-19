import { Global, Module } from '@nestjs/common';
import { DatabaseService } from './database.service';
import { FcmService } from './fcm.service';
import { RtcService } from './rtc.service';
import { StoreService } from './store.service';

@Global()
@Module({
  providers: [DatabaseService, StoreService, RtcService, FcmService],
  exports: [DatabaseService, StoreService, RtcService, FcmService],
})
export class CoreModule {}