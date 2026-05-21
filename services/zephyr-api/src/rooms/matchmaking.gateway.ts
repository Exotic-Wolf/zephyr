import {
  OnGatewayConnection,
  OnGatewayInit,
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import type { Server, Socket } from 'socket.io';
import { StoreService } from '../core/store.service';
import { RtcService } from '../core/rtc.service';

/**
 * Matchmaking gateway for random video calls.
 *
 * Namespace: /call
 *
 * Client → server events:
 *   call:join_queue   { userId: string }  – enter the matchmaking queue
 *   call:leave_queue  { userId: string }  – leave queue / cancel search
 *   call:next         { userId: string, sessionId: string }  – end current call, re-search
 *   call:end          { userId: string, sessionId: string }  – end call, do NOT re-search
 *
 * Server → client events:
 *   call:matched  { sessionId, appId, channelName, uid, token, partnerId }
 *   call:partner_left  {}  – partner pressed Next or disconnected
 */
@WebSocketGateway({ cors: { origin: '*' }, namespace: '/call' })
export class MatchmakingGateway implements OnGatewayInit, OnGatewayConnection {
  @WebSocketServer()
  server!: Server;

  /** userId → socket.id for users currently connected to /call namespace */
  private readonly socketByUser = new Map<string, string>();

  /** Ordered queue of userIds waiting to be matched */
  private readonly queue: string[] = [];

  /** userId → sessionId for active matched calls */
  private readonly activeSession = new Map<string, string>();

  constructor(
    private readonly storeService: StoreService,
    private readonly rtcService: RtcService,
  ) {}

  afterInit() {
    console.log('[MatchmakingGateway] WebSocket gateway initialised on /call');
  }

  handleConnection(client: Socket) {
    const userId = client.handshake.query['userId'] as string | undefined;
    if (userId) {
      this.socketByUser.set(userId, client.id);
    }
  }

  @SubscribeMessage('call:join_queue')
  handleJoinQueue(
    @MessageBody() data: { userId: string },
    @ConnectedSocket() client: Socket,
  ): void {
    const { userId } = data;
    if (!userId) return;

    // Register socket
    this.socketByUser.set(userId, client.id);

    // Don't add duplicates
    if (this.queue.includes(userId)) return;

    // Try to match immediately with someone already waiting
    const partnerIdx = this.queue.findIndex((id) => id !== userId);
    if (partnerIdx !== -1) {
      const partnerId = this.queue[partnerIdx];
      this.queue.splice(partnerIdx, 1);
      void this.matchPair(userId, partnerId);
    } else {
      this.queue.push(userId);
    }
  }

  @SubscribeMessage('call:leave_queue')
  handleLeaveQueue(@MessageBody() data: { userId: string }): void {
    this.removeFromQueue(data.userId);
  }

  @SubscribeMessage('call:next')
  handleNext(
    @MessageBody() data: { userId: string; sessionId: string },
    @ConnectedSocket() client: Socket,
  ): void {
    const { userId, sessionId } = data;

    // End the session on server side (fire and forget — billing already stops client-side)
    void this.storeService.endCallSession(userId, sessionId, 'caller_ended').catch(() => null);

    // Notify partner
    this.notifyPartnerLeft(userId, sessionId);

    // Re-join queue
    this.socketByUser.set(userId, client.id);
    this.removeFromQueue(userId);
    this.activeSession.delete(userId);

    const partnerIdx = this.queue.findIndex((id) => id !== userId);
    if (partnerIdx !== -1) {
      const partnerId = this.queue[partnerIdx];
      this.queue.splice(partnerIdx, 1);
      void this.matchPair(userId, partnerId);
    } else {
      this.queue.push(userId);
    }
  }

  @SubscribeMessage('call:end')
  handleEnd(@MessageBody() data: { userId: string; sessionId: string }): void {
    const { userId, sessionId } = data;
    void this.storeService.endCallSession(userId, sessionId, 'caller_ended').catch(() => null);
    this.notifyPartnerLeft(userId, sessionId);
    this.removeFromQueue(userId);
    this.activeSession.delete(userId);
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  private async matchPair(userA: string, userB: string): Promise<void> {
    try {
      // Create a call session in the DB (random mode, no fixed receiver upfront)
      const session = await this.storeService.startCallSession(userA, {
        mode: 'random',
        receiverUserId: userB,
      });

      // Generate Agora tokens for both sides
      const tokenA = this.rtcService.createJoinToken({
        sessionId: session.id,
        userId: userA,
        role: 'caller',
      });
      const tokenB = this.rtcService.createJoinToken({
        sessionId: session.id,
        userId: userB,
        role: 'receiver',
      });

      // Track active sessions
      this.activeSession.set(userA, session.id);
      this.activeSession.set(userB, session.id);

      // Emit call:matched to each user
      const socketA = this.socketByUser.get(userA);
      const socketB = this.socketByUser.get(userB);

      if (socketA) {
        this.server.to(socketA).emit('call:matched', {
          sessionId: session.id,
          appId: tokenA.appId,
          channelName: tokenA.channelName,
          uid: tokenA.uid,
          token: tokenA.token,
          partnerId: userB,
        });
      }

      if (socketB) {
        this.server.to(socketB).emit('call:matched', {
          sessionId: session.id,
          appId: tokenB.appId,
          channelName: tokenB.channelName,
          uid: tokenB.uid,
          token: tokenB.token,
          partnerId: userA,
        });
      }
    } catch (err) {
      console.error('[MatchmakingGateway] matchPair failed:', err);
      // Put both back in queue on error
      this.queue.push(userA, userB);
    }
  }

  private notifyPartnerLeft(userId: string, sessionId: string): void {
    // Find the partner in the active session map
    for (const [uid, sid] of this.activeSession.entries()) {
      if (sid === sessionId && uid !== userId) {
        const partnerSocket = this.socketByUser.get(uid);
        if (partnerSocket) {
          this.server.to(partnerSocket).emit('call:partner_left', {});
        }
        this.activeSession.delete(uid);
        break;
      }
    }
  }

  private removeFromQueue(userId: string): void {
    const idx = this.queue.indexOf(userId);
    if (idx !== -1) this.queue.splice(idx, 1);
  }
}
