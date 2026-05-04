import { BadRequestException, Injectable } from '@nestjs/common';
import { AccessToken } from 'livekit-server-sdk';

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

  private parseTokenTtlSeconds(): number {
    const parsed = Number.parseInt(process.env.RTC_TOKEN_TTL_SECONDS ?? '3600', 10);
    if (!Number.isFinite(parsed) || parsed <= 0) {
      return 3600;
    }
    return Math.min(parsed, 24 * 60 * 60);
  }
}