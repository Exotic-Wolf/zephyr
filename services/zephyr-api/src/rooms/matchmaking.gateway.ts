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
 *   call:direct       { userId: string, receiverId: string }  – ring a specific user (paid)
 *   call:next         { userId: string, sessionId: string }  – end current call, re-search
 *   call:end          { userId: string, sessionId: string }  – end call, do NOT re-search
 *   call:accept       { userId: string }  – receiver accepts incoming call
 *   call:reject       { userId: string }  – receiver rejects incoming call
 *
 * Server → client events:
 *   call:matched       { sessionId, appId, channelName, uid, token, partnerId }
 *   call:incoming      { callerId, mode? }  – ring: accept or reject
 *   call:partner_left  {}  – partner pressed Next or disconnected
 *   call:cancelled     {}  – caller left while ringing
 *   call:rejected      { userId }  – direct call was rejected
 *   call:busy          { userId }  – target is in a call
 *   call:unavailable   { userId }  – target not connected
 *   call:no_answer     { userId }  – 30s timeout, no response
 *   call:error         { reason }  – e.g. blocked
 */

interface QueueEntry {
  userId: string;
  /** IDs this user has blocked OR that have blocked them — excluded from matching */
  blockedIds: Set<string>;
}

/** Tracks a pending incoming call to an online user. */
interface PendingCall {
  callerId: string;
  receiverId: string;
  callerSocket: string;
  mode: 'random' | 'direct';
  timeout: ReturnType<typeof setTimeout>;
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

  /** receiverId → pending call info (waiting for accept/reject) */
  private readonly pendingCalls = new Map<string, PendingCall>();

  /** callerId → set of userIds already tried this search (to avoid re-ringing) */
  private readonly triedOnline = new Map<string, Set<string>>();

  private static readonly RING_TIMEOUT_MS = 30_000;

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

    void this.matchWithLiveHost(userId, client);
  }

  @SubscribeMessage('call:leave_queue')
  handleLeaveQueue(@MessageBody() data: { userId: string }): void {
    this.removeFromQueue(data.userId);
  }

  @SubscribeMessage('call:direct')
  handleDirectCall(
    @MessageBody() data: { userId: string; receiverId: string },
    @ConnectedSocket() client: Socket,
  ): void {
    const { userId, receiverId } = data;
    if (!userId || !receiverId || userId === receiverId) return;

    this.socketByUser.set(userId, client.id);
    void this.initiateDirectCall(userId, receiverId, client.id);
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

    void this.matchWithLiveHost(userId, client);
  }

  @SubscribeMessage('call:end')
  handleEnd(@MessageBody() data: { userId: string; sessionId: string }): void {
    const { userId, sessionId } = data;
    void this.storeService.endCallSession(userId, sessionId, 'caller_ended').catch(() => null);
    this.notifyPartnerLeft(userId, sessionId);
    this.removeFromQueue(userId);
    this.activeSession.delete(userId);
    this.triedOnline.delete(userId);
    this.cancelPendingCallFrom(userId);
  }

  @SubscribeMessage('call:accept')
  handleAccept(
    @MessageBody() data: { userId: string },
    @ConnectedSocket() client: Socket,
  ): void {
    const { userId } = data;
    const pending = this.pendingCalls.get(userId);
    if (!pending) return;

    clearTimeout(pending.timeout);
    this.pendingCalls.delete(userId);
    this.socketByUser.set(userId, client.id);

    void this.connectPair(pending.callerId, userId, pending.callerSocket, client.id, pending.mode);
  }

  @SubscribeMessage('call:reject')
  handleReject(@MessageBody() data: { userId: string }): void {
    const { userId } = data;
    const pending = this.pendingCalls.get(userId);
    if (!pending) return;

    clearTimeout(pending.timeout);
    this.pendingCalls.delete(userId);

    if (pending.mode === 'direct') {
      // Direct call rejected — notify caller
      this.server.to(pending.callerSocket).emit('call:rejected', { userId });
    } else {
      // Random call rejected — try next online user
      void this.tryNextOnlineUser(pending.callerId, pending.callerSocket);
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  /**
   * Longest-live-first matching: query DB for best live host,
   * respecting 4h cooldown. Falls back to ignoring cooldown if exhausted.
   * If no live host → try online users (ring them with accept/reject).
   * If no one at all → queue the caller for peer-to-peer fallback.
   */
  private async matchWithLiveHost(userId: string, client: Socket): Promise<void> {
    // Reject banned users
    const user = await this.storeService.getUserById(userId).catch(() => null) as any;
    if (user?.is_banned) return;

    const hostId = await this.storeService.findBestRandomMatch(userId);

    if (hostId) {
      // Found a live host → auto-connect (no acceptance needed)
      await this.connectPair(userId, hostId, client.id, this.socketByUser.get(hostId));
      // Record match for cooldown tracking
      await this.storeService.recordRandomMatch(userId, hostId);
    } else {
      // No live host → try online users
      this.triedOnline.set(userId, new Set());
      await this.tryNextOnlineUser(userId, client.id);
    }
  }

  /** Direct call: ring a specific user (paid call from profile). */
  private async initiateDirectCall(callerId: string, receiverId: string, callerSocketId: string): Promise<void> {
    // Reject banned users
    const user = await this.storeService.getUserById(callerId).catch(() => null) as any;
    if (user?.is_banned) return;

    // Check if receiver is blocked
    const blocked = await this.storeService.getBlockedIds(callerId);
    if (blocked.has(receiverId)) {
      this.server.to(callerSocketId).emit('call:error', { reason: 'blocked' });
      return;
    }

    // Check if receiver is already in a call
    if (this.activeSession.has(receiverId) || this.pendingCalls.has(receiverId)) {
      this.server.to(callerSocketId).emit('call:busy', { userId: receiverId });
      return;
    }

    const receiverSocketId = this.socketByUser.get(receiverId);
    if (!receiverSocketId) {
      // Receiver not connected to /call namespace — they're offline or not on the app
      this.server.to(callerSocketId).emit('call:unavailable', { userId: receiverId });
      return;
    }

    // Ring the receiver
    const timeout = setTimeout(() => {
      this.pendingCalls.delete(receiverId);
      this.server.to(callerSocketId).emit('call:no_answer', { userId: receiverId });
    }, MatchmakingGateway.RING_TIMEOUT_MS);

    this.pendingCalls.set(receiverId, {
      callerId,
      receiverId,
      callerSocket: callerSocketId,
      mode: 'direct',
      timeout,
    });

    this.server.to(receiverSocketId).emit('call:incoming', {
      callerId,
      mode: 'direct',
    });
  }

  /** Try to ring the next online user for this caller. */
  private async tryNextOnlineUser(callerId: string, callerSocketId: string): Promise<void> {
    const tried = this.triedOnline.get(callerId) ?? new Set();
    const onlineId = await this.storeService.findBestOnlineMatch(callerId);

    if (!onlineId || tried.has(onlineId)) {
      // No more online users — fall back to peer-to-peer queue
      this.triedOnline.delete(callerId);
      this.addToQueue(callerId);
      return;
    }

    tried.add(onlineId);
    this.triedOnline.set(callerId, tried);

    const receiverSocket = this.socketByUser.get(onlineId);
    if (!receiverSocket) {
      // Online user not connected to /call — try next
      await this.tryNextOnlineUser(callerId, callerSocketId);
      return;
    }

    // Ring the online user
    const timeout = setTimeout(() => {
      // Timeout — no response in 30s
      this.pendingCalls.delete(onlineId);
      void this.tryNextOnlineUser(callerId, callerSocketId);
    }, MatchmakingGateway.RING_TIMEOUT_MS);

    this.pendingCalls.set(onlineId, {
      callerId,
      receiverId: onlineId,
      callerSocket: callerSocketId,
      mode: 'random',
      timeout,
    });

    this.server.to(receiverSocket).emit('call:incoming', {
      callerId,
    });
  }

  /** Connect a matched pair — creates session and emits call:matched to both. */
  private async connectPair(
    callerId: string,
    receiverId: string,
    callerSocketId: string,
    receiverSocketId: string | undefined,
    mode: 'random' | 'direct' = 'random',
  ): Promise<void> {
    try {
      const session = await this.storeService.startCallSession(callerId, {
        mode,
        receiverUserId: receiverId,
      });

      if (mode === 'random') {
        await this.storeService.recordRandomMatch(callerId, receiverId);
      }

      const tokenCaller = this.rtcService.createJoinToken({ sessionId: session.id, userId: callerId, role: 'caller' });
      const tokenReceiver = this.rtcService.createJoinToken({ sessionId: session.id, userId: receiverId, role: 'receiver' });

      this.activeSession.set(callerId, session.id);
      this.activeSession.set(receiverId, session.id);
      this.triedOnline.delete(callerId);

      this.server.to(callerSocketId).emit('call:matched', {
        sessionId: session.id,
        appId: tokenCaller.appId,
        channelName: tokenCaller.channelName,
        uid: tokenCaller.uid,
        token: tokenCaller.token,
        partnerId: receiverId,
      });

      if (receiverSocketId) {
        this.server.to(receiverSocketId).emit('call:matched', {
          sessionId: session.id,
          appId: tokenReceiver.appId,
          channelName: tokenReceiver.channelName,
          uid: tokenReceiver.uid,
          token: tokenReceiver.token,
          partnerId: callerId,
        });
      }
    } catch (err) {
      console.error('[MatchmakingGateway] connectPair failed:', err);
      this.addToQueue(callerId);
    }
  }

  /** Cancel any pending incoming call initiated by this caller. */
  private cancelPendingCallFrom(callerId: string): void {
    for (const [receiverId, pending] of this.pendingCalls.entries()) {
      if (pending.callerId === callerId) {
        clearTimeout(pending.timeout);
        this.pendingCalls.delete(receiverId);
        // Notify the receiver that the call was cancelled
        const receiverSocket = this.socketByUser.get(receiverId);
        if (receiverSocket) {
          this.server.to(receiverSocket).emit('call:cancelled', {});
        }
        break;
      }
    }
  }

  /** Add user to queue and attempt peer-to-peer match with waiting users. */
  private addToQueue(userId: string): void {
    void this.storeService.getBlockedIds(userId).then((blockedIds) => {
      const entry: QueueEntry = { userId, blockedIds };
      const partnerIdx = this.queue.findIndex(
        (e) => e.userId !== userId && !e.blockedIds.has(userId) && !blockedIds.has(e.userId),
      );
      if (partnerIdx !== -1) {
        const partner = this.queue[partnerIdx];
        this.queue.splice(partnerIdx, 1);
        const socketA = this.socketByUser.get(entry.userId);
        const socketB = this.socketByUser.get(partner.userId);
        void this.connectPair(entry.userId, partner.userId, socketA ?? '', socketB);
      } else {
        this.queue.push(entry);
      }
    });
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
