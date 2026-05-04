import { Global, Module } from '@nestjs/common';
import { DatabaseService } from './database.service';
import { RtcService } from './rtc.service';
import { StoreService } from './store.service';

@Global()
@Module({
  providers: [DatabaseService, StoreService, RtcService],
  exports: [DatabaseService, StoreService, RtcService],
})
export class CoreModule {}