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

interface QueueEntry {
  userId: string;
  /** IDs this user has blocked OR that have blocked them — excluded from matching */
  blockedIds: Set<string>;
}

@WebSocketGateway({ cors: { origin: '*' }, namespace: '/call' })
export class MatchmakingGateway implements OnGatewayInit, OnGatewayConnection {
  @WebSocketServer()
  server!: Server;

  /** userId → socket.id */
  private readonly socketByUser = new Map<string, string>();

  /** Ordered queue of entries waiting to be matched */
  private readonly queue: QueueEntry[] = [];

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

    this.socketByUser.set(userId, client.id);

    // Don't add duplicates
    if (this.queue.some((e) => e.userId === userId)) return;

    void this.storeService.getBlockedIds(userId).then((blockedIds) => {
      const entry: QueueEntry = { userId, blockedIds };
      const partnerIdx = this.queue.findIndex(
        (e) => e.userId !== userId && !e.blockedIds.has(userId) && !blockedIds.has(e.userId),
      );
      if (partnerIdx !== -1) {
        const partner = this.queue[partnerIdx];
        this.queue.splice(partnerIdx, 1);
        void this.matchPair(entry, partner);
      } else {
        this.queue.push(entry);
      }
    });
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

    void this.storeService.endCallSession(userId, sessionId, 'caller_ended').catch(() => null);
    this.notifyPartnerLeft(userId, sessionId);

    this.socketByUser.set(userId, client.id);
    this.removeFromQueue(userId);
    this.activeSession.delete(userId);

    void this.storeService.getBlockedIds(userId).then((blockedIds) => {
      const entry: QueueEntry = { userId, blockedIds };
      const partnerIdx = this.queue.findIndex(
        (e) => e.userId !== userId && !e.blockedIds.has(userId) && !blockedIds.has(e.userId),
      );
      if (partnerIdx !== -1) {
        const partner = this.queue[partnerIdx];
        this.queue.splice(partnerIdx, 1);
        void this.matchPair(entry, partner);
      } else {
        this.queue.push(entry);
      }
    });
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

  private async matchPair(entryA: QueueEntry, entryB: QueueEntry): Promise<void> {
    const { userId: userA } = entryA;
    const { userId: userB } = entryB;
    try {
      const session = await this.storeService.startCallSession(userA, {
        mode: 'random',
        receiverUserId: userB,
      });

      const tokenA = this.rtcService.createJoinToken({ sessionId: session.id, userId: userA, role: 'caller' });
      const tokenB = this.rtcService.createJoinToken({ sessionId: session.id, userId: userB, role: 'receiver' });

      this.activeSession.set(userA, session.id);
      this.activeSession.set(userB, session.id);

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
      this.queue.push(entryA, entryB);
    }
  }

  private notifyPartnerLeft(userId: string, sessionId: string): void {
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
    const idx = this.queue.findIndex((e) => e.userId === userId);
    if (idx !== -1) this.queue.splice(idx, 1);
  }
}
