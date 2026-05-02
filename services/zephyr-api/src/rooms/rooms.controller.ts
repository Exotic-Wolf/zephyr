import {
  Body,
  Controller,
  Get,
  Headers,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import { StoreService } from '../core/store.service';
import type { Room } from '../core/store.service';
import { CreateRoomDto } from './dto/create-room.dto';

@Controller('v1/rooms')
export class RoomsController {
  constructor(private readonly storeService: StoreService) {}

  @Get()
  async listRooms(): Promise<Room[]> {
    return this.storeService.listRooms();
  }

  @Post()
  async createRoom(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: CreateRoomDto,
  ): Promise<Room> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    return this.storeService.createRoom(user.id, body?.title);
  }

  @Post(':roomId/join')
  async joinRoom(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId', new ParseUUIDPipe()) roomId: string,
  ): Promise<Room> {
    await this.storeService.getUserFromAuthHeader(authorization);
    return this.storeService.joinRoom(roomId);
  }
}