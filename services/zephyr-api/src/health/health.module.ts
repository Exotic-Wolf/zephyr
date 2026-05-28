import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';
import { RoomsModule } from '../rooms/rooms.module';

@Module({
  imports: [RoomsModule],
  controllers: [HealthController],
})
export class HealthModule {}