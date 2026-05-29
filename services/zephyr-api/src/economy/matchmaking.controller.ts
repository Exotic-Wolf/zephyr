import {
  Controller,
  Delete,
  Headers,
  HttpCode,
  HttpStatus,
  Post,
  Body,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { StoreService } from '../core/store.service';
import { RtcService } from '../core/rtc.service';
import { FcmService } from '../core/fcm.service';

interface QueueEntry {
  userId: string;
  blockedIds: Set<string>;
  enqueuedAt: number;
}

/** In-memory seeker queue for random matchmaking. */
const seekerQueue: Map<string, QueueEntry> = new Map();

/** Tried-online tracking per seeker to avoid ringing the same user twice. */
const triedOnline: Map<string, Set<string>> = new Map();

@Controller('v1/calls/random')
export class MatchmakingController {
  constructor(
    private readonly storeService: StoreService,
    private readonly rtcService: RtcService,
    private readonly fcmService: FcmService,
  ) {}

  /**
   * POST /v1/calls/random/seek
   * Client calls this to start searching for a random match.
   * Returns immediately with { matched: true, ... } or { matched: false }.
   */
  @Post('seek')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { ttl: 10_000, limit: 5 } })
  async seek(
    @Headers('authorization') authorization: string | undefined,
  ): Promise<
    | { matched: true; sessionId: string; appId: string; channelName: string; uid: number; token: string; partnerId: string; partnerName: string }
    | { matched: false }
  > {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    const userId = user.id;

    // Remove from queue if already there (re-seek)
    seekerQueue.delete(userId);
    triedOnline.delete(userId);

    // Check if banned
    if ((user as any).is_banned) {
      return { matched: false };
    }

    // Step 1: Try to match with a live host
    const hostId = await this.storeService.findBestRandomMatch(userId);
    if (hostId) {
      return this.connectPair(userId, hostId);
    }

    // Step 2: Try to match with an online user
    const onlineId = await this.storeService.findBestOnlineMatch(userId);
    if (onlineId) {
      return this.connectPair(userId, onlineId);
    }

    // Step 3: Check if there's a compatible seeker already waiting
    const blockedIds = await this.storeService.getBlockedIds(userId);
    for (const [waitingId, entry] of seekerQueue) {
      if (waitingId === userId) continue;
      if (entry.blockedIds.has(userId)) continue;
      if (blockedIds.has(waitingId)) continue;

      // Found a peer match!
      seekerQueue.delete(waitingId);
      return this.connectPair(userId, waitingId);
    }

    // Step 4: No match — add to queue
    seekerQueue.set(userId, { userId, blockedIds, enqueuedAt: Date.now() });

    // Auto-expire after 60s
    setTimeout(() => {
      if (seekerQueue.has(userId)) {
        seekerQueue.delete(userId);
      }
    }, 60_000);

    return { matched: false };
  }

  /**
   * DELETE /v1/calls/random/seek
   * Cancel the search.
   */
  @Delete('seek')
  @HttpCode(HttpStatus.NO_CONTENT)
  async cancelSeek(
    @Headers('authorization') authorization: string | undefined,
  ): Promise<void> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    seekerQueue.delete(user.id);
    triedOnline.delete(user.id);
  }

  /**
   * POST /v1/calls/random/next
   * End current call and immediately seek again.
   */
  @Post('next')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { ttl: 5_000, limit: 3 } })
  async next(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: { sessionId: string; partnerId?: string },
  ): Promise<
    | { matched: true; sessionId: string; appId: string; channelName: string; uid: number; token: string; partnerId: string; partnerName: string }
    | { matched: false }
  > {
    const user = await this.storeService.getUserFromAuthHeader(authorization);

    // End the current session and notify partner
    if (body?.sessionId) {
      await this.storeService.endCallSession(user.id, body.sessionId, 'caller_ended').catch(() => null);
      if (body.partnerId) {
        await this.fcmService.writeCallSignal(body.partnerId, { event: 'partner_left', ts: Date.now() });
      }
    }

    // Now seek again
    return this.seek(authorization);
  }

  /**
   * POST /v1/calls/random/end
   * End current call without seeking again.
   */
  @Post('end')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Throttle({ default: { ttl: 5_000, limit: 3 } })
  async end(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: { sessionId: string; partnerId?: string },
  ): Promise<void> {
    const user = await this.storeService.getUserFromAuthHeader(authorization);
    seekerQueue.delete(user.id);
    triedOnline.delete(user.id);

    if (body?.sessionId) {
      await this.storeService.endCallSession(user.id, body.sessionId, 'caller_ended').catch(() => null);
      if (body.partnerId) {
        await this.fcmService.writeCallSignal(body.partnerId, { event: 'partner_left', ts: Date.now() });
      }
    }
  }

  // ─── Private ──────────────────────────────────────────────────────────────

  private async connectPair(
    callerId: string,
    receiverId: string,
  ): Promise<{ matched: true; sessionId: string; appId: string; channelName: string; uid: number; token: string; partnerId: string; partnerName: string }> {
    // Create call session
    const session = await this.storeService.startCallSession(callerId, {
      mode: 'random',
      receiverUserId: receiverId,
    });

    // Record match for cooldown
    await this.storeService.recordRandomMatch(callerId, receiverId);

    // Generate tokens
    const callerToken = this.rtcService.createJoinToken({ sessionId: session.id, userId: callerId, role: 'caller' });
    const receiverToken = this.rtcService.createJoinToken({ sessionId: session.id, userId: receiverId, role: 'receiver' });

    // Get names
    const callerUser = await this.storeService.getUserById(callerId).catch(() => null) as any;
    const receiverUser = await this.storeService.getUserById(receiverId).catch(() => null) as any;

    // Write RTDB signal to receiver
    await this.fcmService.writeCallSignal(receiverId, {
      event: 'matched',
      sessionId: session.id,
      appId: receiverToken.appId,
      channelName: receiverToken.channelName,
      uid: receiverToken.uid,
      token: receiverToken.token,
      partnerId: callerId,
      partnerName: callerUser?.display_name ?? 'User',
      ts: Date.now(),
    });

    // Remove receiver from seeker queue if they were there
    seekerQueue.delete(receiverId);
    triedOnline.delete(receiverId);

    return {
      matched: true,
      sessionId: session.id,
      appId: callerToken.appId,
      channelName: callerToken.channelName,
      uid: callerToken.uid,
      token: callerToken.token,
      partnerId: receiverId,
      partnerName: receiverUser?.display_name ?? 'User',
    };
  }
}
