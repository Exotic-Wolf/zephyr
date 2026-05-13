import { Module } from '@nestjs/common';
import { MulterModule } from '@nestjs/platform-express';
import { UsersController } from './users.controller';

@Module({
  imports: [MulterModule.register()],
  controllers: [UsersController],
})
export class UsersModule {}