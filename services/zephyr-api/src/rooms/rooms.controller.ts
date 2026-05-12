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
import { RtcService } from '../core/rtc.service';
import type { RtcJoinTokenResult } from '../core/rtc.service';
import { CreateRoomDto } from './dto/create-room.dto';
import { RoomsGateway } from './rooms.gateway';

@Controller('v1/rooms')
export class RoomsController {
  constructor(
    private readonly storeService: StoreService,
    private readonly roomsGateway: RoomsGateway,
    private readonly rtcService: RtcService,
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
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    const room = await this.storeService.joinRoom(roomId, user.id);
    this.roomsGateway.emitRoomUpdated(room.id, room.audienceCount);
    return room;
  }

  @Post(':roomId/leave')
  @HttpCode(HttpStatus.NO_CONTENT)
  async leaveRoom(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId', new ParseUUIDPipe()) roomId: string,
  ): Promise<void> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    await this.storeService.leaveRoom(roomId, user.id);
    // Fetch updated count and broadcast
    try {
      const rooms = await this.storeService.listRooms();
      const room = rooms.find((r) => r.id === roomId);
      if (room) this.roomsGateway.emitRoomUpdated(roomId, room.audienceCount);
    } catch {
      // best-effort
    }
  }

  @Get(':roomId/viewers')
  async getRoomViewers(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId', new ParseUUIDPipe()) roomId: string,
  ): Promise<{ viewers: { displayName: string; avatarUrl: string | null }[]; total: number }> {
    await this.storeService.getUserFromAuthHeader(authorization);
    const viewers = await this.storeService.getRoomViewers(roomId, 50);
    // Get the total from the room's audienceCount
    const rooms = await this.storeService.listRooms();
    const room = rooms.find((r) => r.id === roomId);
    return { viewers, total: room?.audienceCount ?? viewers.length };
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

  @Post(':roomId/rtc-token')
  async getRoomRtcToken(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId', new ParseUUIDPipe()) roomId: string,
  ): Promise<RtcJoinTokenResult> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    const hostUserId = await this.storeService.getRoomHostUserId(roomId);
    const role = hostUserId === user.id ? 'host' : 'viewer';
    return this.rtcService.createLiveRoomToken({ roomId, userId: user.id, role });
  }
}