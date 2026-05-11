import {
  OnGatewayInit,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import type { Server } from 'socket.io';
import type { LiveFeedCard } from '../core/store.service';

/**
 * Real-time gateway for live room events.
 *
 * Events emitted to all connected clients:
 *   feed:room-created  { card: LiveFeedCard }
 *   feed:room-ended    { roomId: string; hostUserId: string }
 *   feed:room-updated  { roomId: string; audienceCount: number }
 *   feed:user-status   { hostUserId: string; status: string }
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
}
