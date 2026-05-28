import {
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  ConnectedSocket,
  MessageBody,
} from '@nestjs/websockets';
import type { Server, Socket } from 'socket.io';
import type { LiveFeedCard } from '../core/store.service';

/**
 * Real-time gateway for live room events.
 *
 * Clients can join/leave a Socket.IO room for scoped events:
 *   emit('join-room', { roomId })  → joins socket room `room:<roomId>`
 *   emit('leave-room', { roomId }) → leaves socket room
 *
 * Events broadcast globally (feed screens):
 *   feed:room-created  { card: LiveFeedCard }
 *   feed:room-ended    { roomId: string; hostUserId: string }
 *   feed:room-updated  { roomId: string; audienceCount: number }
 *   feed:user-status   { hostUserId: string; status: string }
 *
 * Events scoped to socket room (viewers/host in that room):
 *   room:comment       { roomId; userId; displayName; text }
 *   room:reaction      { roomId; userId; emoji }
 *   room:gift          { roomId; senderDisplayName; giftId; giftName; quantity; coinCost }
 */
@WebSocketGateway({
  cors: { origin: '*' },
  namespace: '/feed',
})
export class RoomsGateway implements OnGatewayInit {
  @WebSocketServer()
  server!: Server;

  afterInit() {
    console.log('[RoomsGateway] WebSocket gateway initialised on /feed');
  }

  @SubscribeMessage('join-room')
  handleJoinRoom(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { roomId: string },
  ) {
    if (data?.roomId) {
      client.join(`room:${data.roomId}`);
    }
  }

  @SubscribeMessage('leave-room')
  handleLeaveRoom(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { roomId: string },
  ) {
    if (data?.roomId) {
      client.leave(`room:${data.roomId}`);
    }
  }

  // ── Global events (feed screens) ─────────────────────────────────────────

  emitRoomCreated(card: LiveFeedCard): void {
    this.server.emit('feed:room-created', { card });
  }

  emitRoomEnded(roomId: string, hostUserId: string): void {
    this.server.emit('feed:room-ended', { roomId, hostUserId });
  }

  emitUserStatus(hostUserId: string, status: string): void {
    this.server.emit('feed:user-status', { hostUserId, status });
  }

  emitRoomUpdated(roomId: string, audienceCount: number): void {
    this.server.emit('feed:room-updated', { roomId, audienceCount });
  }

  // ── Room-scoped events (only participants of that room) ───────────────────

  emitRoomComment(roomId: string, userId: string, displayName: string, text: string): void {
    this.server.to(`room:${roomId}`).emit('room:comment', { roomId, userId, displayName, text });
  }

  emitRoomReaction(roomId: string, userId: string, emoji: string): void {
    this.server.to(`room:${roomId}`).emit('room:reaction', { roomId, userId, emoji });
  }

  emitRoomGift(roomId: string, senderDisplayName: string, giftId: string, giftName: string, quantity: number, coinCost: number): void {
    this.server.to(`room:${roomId}`).emit('room:gift', { roomId, senderDisplayName, giftId, giftName, quantity, coinCost });
  }
}
