import { Module } from '@nestjs/common';
import { EconomyController } from './economy.controller';
import { CoreModule } from '../core/core.module';

@Module({
  imports: [CoreModule],
  controllers: [EconomyController],
})
export class EconomyModule {}
