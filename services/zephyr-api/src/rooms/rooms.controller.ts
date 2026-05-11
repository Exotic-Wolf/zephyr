import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import { StoreService } from '../core/store.service';
import type { Room } from '../core/store.service';
import { CreateRoomDto } from './dto/create-room.dto';
import { RoomsGateway } from './rooms.gateway';

@Controller('v1/rooms')
export class RoomsController {
  constructor(
    private readonly storeService: StoreService,
    private readonly roomsGateway: RoomsGateway,
  ) {}

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
    const room = await this.storeService.createRoom(user.id, body?.title);
    // Push real-time event to all connected clients
    this.roomsGateway.emitRoomCreated({
      roomId: room.id,
      title: room.title,
      audienceCount: room.audienceCount,
      hostUserId: room.hostUserId,
      hostDisplayName: user.displayName,
      hostAvatarUrl: user.avatarUrl,
      hostCountryCode: user.countryCode ?? 'PH',
      hostLanguage: user.language ?? 'English',
      hostStatus: 'live',
      startedAt: room.createdAt,
    });
    return room;
  }

  @Post(':roomId/join')
  async joinRoom(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId', new ParseUUIDPipe()) roomId: string,
  ): Promise<Room> {
    await this.storeService.getUserFromAuthHeader(authorization);
    const room = await this.storeService.joinRoom(roomId);
    this.roomsGateway.emitRoomUpdated(room.id, room.audienceCount);
    return room;
  }

  @Post(':roomId/leave')
  @HttpCode(HttpStatus.NO_CONTENT)
  async leaveRoom(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId', new ParseUUIDPipe()) roomId: string,
  ): Promise<void> {
    await this.storeService.getUserFromAuthHeader(authorization);
    await this.storeService.leaveRoom(roomId);
    // Fetch updated count and broadcast
    try {
      const rooms = await this.storeService.listRooms();
      const room = rooms.find((r) => r.id === roomId);
      if (room) this.roomsGateway.emitRoomUpdated(roomId, room.audienceCount);
    } catch {
      // best-effort
    }
  }

  @Post(':roomId/heartbeat')
  @HttpCode(HttpStatus.NO_CONTENT)
  async heartbeatRoom(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId', new ParseUUIDPipe()) roomId: string,
  ): Promise<void> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    await this.storeService.heartbeatRoom(user.id, roomId);
  }

  @Delete(':roomId')
  async endRoom(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId', new ParseUUIDPipe()) roomId: string,
  ): Promise<{ ok: true }> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    await this.storeService.endRoom(user.id, roomId);
    // Card stays in feed — just update status back to online
    this.roomsGateway.emitRoomEnded(roomId, user.id);
    return { ok: true };
  }
}