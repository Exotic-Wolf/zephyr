import { Global, Module } from '@nestjs/common';
import { DatabaseService } from './database.service';
import { FcmService } from './fcm.service';
import { IapService } from './iap.service';
import { RtcService } from './rtc.service';
import { StoreService } from './store.service';

@Global()
@Module({
  providers: [DatabaseService, StoreService, RtcService, FcmService, IapService],
  exports: [DatabaseService, StoreService, RtcService, FcmService, IapService],
})
export class CoreModule {}