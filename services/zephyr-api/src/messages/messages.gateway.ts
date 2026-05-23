import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import type { Server, Socket } from 'socket.io';
import type { Message } from '../core/store.service';
import { StoreService } from '../core/store.service';
import { RoomsGateway } from '../rooms/rooms.gateway';

const OFFLINE_GRACE_MS = 10_000;

/**
 * Real-time gateway for direct messages + presence.
 *
 * Presence lifecycle:
 *   connect (with userId query)  → online
 *   disconnect                   → 10s grace → offline
 *   reconnect within grace       → stays online (timer cancelled)
 *
 * Events emitted:
 *   chat:message    { message }  → to sender + receiver rooms
 *   chat:delivered  { message }  → to sender room
 *   chat:read       { message }  → to sender room
 */
@WebSocketGateway({ cors: { origin: '*' }, namespace: '/chat' })
export class MessagesGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  constructor(
    private readonly storeService: StoreService,
    private readonly roomsGateway: RoomsGateway,
  ) {}

  @WebSocketServer()
  server!: Server;

  /** userId → Set of socket IDs (supports multiple tabs/devices) */
  private readonly connections = new Map<string, Set<string>>();

  /** userId → grace timer (fires offline after OFFLINE_GRACE_MS) */
  private readonly graceTimers = new Map<string, ReturnType<typeof setTimeout>>();

  afterInit() {
    console.log('[MessagesGateway] WebSocket gateway initialised on /chat');
  }

  handleConnection(client: Socket) {
    const userId = client.handshake.query['userId'] as string | undefined;
    if (!userId) return;

    void client.join(userId);

    // Track this socket for the user
    let sockets = this.connections.get(userId);
    if (!sockets) {
      sockets = new Set();
      this.connections.set(userId, sockets);
    }
    sockets.add(client.id);

    // Cancel any pending offline timer — user reconnected in time
    const timer = this.graceTimers.get(userId);
    if (timer) {
      clearTimeout(timer);
      this.graceTimers.delete(userId);
    }

    // First socket for this user → set online
    if (sockets.size === 1) {
      this.setOnline(userId);
    }
  }

  handleDisconnect(client: Socket) {
    const userId = client.handshake.query['userId'] as string | undefined;
    if (!userId) return;

    // Remove this socket from tracking
    const sockets = this.connections.get(userId);
    if (sockets) {
      sockets.delete(client.id);
      if (sockets.size === 0) {
        this.connections.delete(userId);
        // Last socket gone — start grace timer
        this.startGraceTimer(userId);
      }
    }
  }

  @SubscribeMessage('chat:join')
  handleJoin(
    @MessageBody() userId: string,
    @ConnectedSocket() client: Socket,
  ): void {
    void client.join(userId);
  }

  // ── Presence internals ────────────────────────────────────────────────────

  private setOnline(userId: string): void {
    void this.storeService.setUserStatus(userId, 'online');
    this.roomsGateway.emitUserStatus(userId, 'online');
  }

  private setOffline(userId: string): void {
    void this.storeService.setUserStatus(userId, 'offline');
    this.roomsGateway.emitUserStatus(userId, 'offline');
  }

  private startGraceTimer(userId: string): void {
    // Don't overwrite an existing timer
    if (this.graceTimers.has(userId)) return;
    const timer = setTimeout(() => {
      this.graceTimers.delete(userId);
      // Double-check: user didn't reconnect while timer was pending
      if (!this.connections.has(userId)) {
        this.setOffline(userId);
      }
    }, OFFLINE_GRACE_MS);
    this.graceTimers.set(userId, timer);
  }

  // ── Message events ────────────────────────────────────────────────────────

  emitNewMessage(message: Message): void {
    this.server.to(message.receiverId).emit('chat:message', { message });
    this.server.to(message.senderId).emit('chat:message', { message });
  }

  emitReadReceipt(message: Message): void {
    this.server.to(message.senderId).emit('chat:read', { message });
  }

  emitDeliveryReceipt(message: Message): void {
    this.server.to(message.senderId).emit('chat:delivered', { message });
  }
}
