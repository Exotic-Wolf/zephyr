import { Global, Module } from '@nestjs/common';
import { DatabaseService } from './database.service';
import { DemoForYouSimulatorService } from './demo-for-you-simulator.service';
import { FcmService } from './fcm.service';
import { GiftDeliveryService } from './gift-delivery.service';
import { IapService } from './iap.service';
import { RtcService } from './rtc.service';
import { StoreService } from './store.service';

@Global()
@Module({
  providers: [
    DatabaseService,
    StoreService,
    RtcService,
    FcmService,
    GiftDeliveryService,
    IapService,
    DemoForYouSimulatorService,
  ],
  exports: [
    DatabaseService,
    StoreService,
    RtcService,
    FcmService,
    GiftDeliveryService,
    IapService,
    DemoForYouSimulatorService,
  ],
})
export class CoreModule {}
