import { BadRequestException, Injectable } from '@nestjs/common';
import { RtcTokenBuilder, RtcRole } from 'agora-token';

export interface RtcJoinTokenResult {
  provider: 'agora';
  appId: string;
  channelName: string;
  uid: number;
  role: 'caller' | 'receiver' | 'host' | 'viewer';
  token: string;
  expiresInSeconds: number;
}

@Injectable()
export class RtcService {
  createJoinToken(input: {
    sessionId: string;
    userId: string;
    role: 'caller' | 'receiver';
  }): RtcJoinTokenResult {
    const { appId, appCertificate } = this.getCredentials();
    const expiresInSeconds = this.parseTokenTtlSeconds();
    const channelName = `call_${input.sessionId}`;
    const uid = this.userIdToUid(input.userId);
    const expireTs = Math.floor(Date.now() / 1000) + expiresInSeconds;

    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelName,
      uid,
      RtcRole.PUBLISHER,
      expireTs,
      expireTs,
    );

    return { provider: 'agora', appId, channelName, uid, role: input.role, token, expiresInSeconds };
  }

  createLiveRoomToken(input: {
    roomId: string;
    userId: string;
    role: 'host' | 'viewer';
  }): RtcJoinTokenResult {
    const { appId, appCertificate } = this.getCredentials();
    const expiresInSeconds = this.parseTokenTtlSeconds();
    const channelName = `live_${input.roomId}`;
    const uid = this.userIdToUid(input.userId);
    const expireTs = Math.floor(Date.now() / 1000) + expiresInSeconds;
    const agoraRole = input.role === 'host' ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER;

    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelName,
      uid,
      agoraRole,
      expireTs,
      expireTs,
    );

    return { provider: 'agora', appId, channelName, uid, role: input.role, token, expiresInSeconds };
  }

  private getCredentials(): { appId: string; appCertificate: string } {
    const appId = process.env.AGORA_APP_ID?.trim();
    const appCertificate = process.env.AGORA_APP_CERTIFICATE?.trim();
    if (!appId || !appCertificate) {
      throw new BadRequestException(
        'RTC is not configured. Set AGORA_APP_ID and AGORA_APP_CERTIFICATE.',
      );
    }
    return { appId, appCertificate };
  }

  /** Derive a stable uint32 UID from a UUID user ID */
  private userIdToUid(userId: string): number {
    const hex = userId.replace(/-/g, '').slice(0, 8);
    return (parseInt(hex, 16) >>> 0) || 1;
  }

  private parseTokenTtlSeconds(): number {
    const parsed = Number.parseInt(process.env.RTC_TOKEN_TTL_SECONDS ?? '3600', 10);
    if (!Number.isFinite(parsed) || parsed <= 0) return 3600;
    return Math.min(parsed, 24 * 60 * 60);
  }
}


export interface RtcJoinTokenResult {
  provider: 'livekit';
  wsUrl: string;
  roomName: string;
  identity: string;
  role: 'caller' | 'receiver';
  token: string;
  expiresInSeconds: number;
}

@Injectable()
export class RtcService {
  async createJoinToken(input: {
    sessionId: string;
    userId: string;
    role: 'caller' | 'receiver';
  }): Promise<RtcJoinTokenResult> {
    const apiKey = process.env.LIVEKIT_API_KEY?.trim();
    const apiSecret = process.env.LIVEKIT_API_SECRET?.trim();
    const wsUrl = process.env.LIVEKIT_WS_URL?.trim();

    if (!apiKey || !apiSecret || !wsUrl) {
      throw new BadRequestException(
        'RTC is not configured. Set LIVEKIT_API_KEY, LIVEKIT_API_SECRET, and LIVEKIT_WS_URL.',
      );
    }

    const expiresInSeconds = this.parseTokenTtlSeconds();
    const roomName = `call_${input.sessionId}`;
    const identity = `zephyr_${input.role}_${input.userId}`;

    const accessToken = new AccessToken(apiKey, apiSecret, {
      identity,
      ttl: `${expiresInSeconds}s`,
    });

    accessToken.addGrant({
      room: roomName,
      roomJoin: true,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    });

    const token = await accessToken.toJwt();

    return {
      provider: 'livekit',
      wsUrl,
      roomName,
      identity,
      role: input.role,
      token,
      expiresInSeconds,
    };
  }

  async createLiveRoomToken(input: {
    roomId: string;
    userId: string;
    role: 'host' | 'viewer';
  }): Promise<RtcJoinTokenResult> {
    const apiKey = process.env.LIVEKIT_API_KEY?.trim();
    const apiSecret = process.env.LIVEKIT_API_SECRET?.trim();
    const wsUrl = process.env.LIVEKIT_WS_URL?.trim();

    if (!apiKey || !apiSecret || !wsUrl) {
      throw new BadRequestException(
        'RTC is not configured. Set LIVEKIT_API_KEY, LIVEKIT_API_SECRET, and LIVEKIT_WS_URL.',
      );
    }

    const expiresInSeconds = this.parseTokenTtlSeconds();
    const roomName = `live_${input.roomId}`;
    const identity = `${input.role}_${input.userId}`;

    const accessToken = new AccessToken(apiKey, apiSecret, {
      identity,
      ttl: `${expiresInSeconds}s`,
    });

    accessToken.addGrant({
      room: roomName,
      roomJoin: true,
      canPublish: input.role === 'host',
      canSubscribe: true,
      canPublishData: true,
    });

    const token = await accessToken.toJwt();

    return {
      provider: 'livekit',
      wsUrl,
      roomName,
      identity,
      role: input.role === 'host' ? 'caller' : 'receiver',
      token,
      expiresInSeconds,
    };
  }

  private parseTokenTtlSeconds(): number {
    const parsed = Number.parseInt(process.env.RTC_TOKEN_TTL_SECONDS ?? '3600', 10);
    if (!Number.isFinite(parsed) || parsed <= 0) {
      return 3600;
    }
    return Math.min(parsed, 24 * 60 * 60);
  }
}