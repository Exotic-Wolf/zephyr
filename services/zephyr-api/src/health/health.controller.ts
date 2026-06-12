import {
  Body,
  Controller,
  Get,
  Headers,
  Post,
  UnauthorizedException,
} from '@nestjs/common';
import { DatabaseService } from '../core/database.service';
import { DemoForYouSimulatorService } from '../core/demo-for-you-simulator.service';
import { GiftDeliveryService } from '../core/gift-delivery.service';
import type { GiftDeliveryRetryResult } from '../core/gift-delivery.service';
import { StoreService } from '../core/store.service';

interface InternalSyncPresenceBody {
  userId: string;
  status: string;
  connection?: string;
  activity?: string;
  availability?: string;
  routing?: {
    directCall?: boolean;
    randomCall?: boolean;
  };
  updatedAt?: number;
}

interface DemoForYouStartBody {
  count?: number;
  intervals?: number[];
  routeable?: boolean;
}

interface InternalGiftDeliveryRetryBody {
  limit?: number;
}

@Controller('v1')
export class HealthController {
  constructor(
    private readonly databaseService: DatabaseService,
    private readonly storeService: StoreService,
    private readonly demoForYouSimulator: DemoForYouSimulatorService,
    private readonly giftDeliveryService: GiftDeliveryService,
  ) {}

  @Get('health/live')
  live(): { status: 'ok'; timestamp: string } {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
    };
  }

  @Get('health/ready')
  async ready(): Promise<{
    status: 'ok';
    storage: 'postgres' | 'in-memory';
    timestamp: string;
  }> {
    const storage = this.databaseService.isEnabled() ? 'postgres' : 'in-memory';

    if (storage === 'postgres') {
      await this.databaseService.ping();
    }

    return {
      status: 'ok',
      storage,
      timestamp: new Date().toISOString(),
    };
  }

  @Post('health/end-stale-calls')
  async endStaleCalls(): Promise<{ ended: number }> {
    if (!this.databaseService.isEnabled()) {
      return { ended: 0 };
    }

    const result = await this.databaseService.query(
      `
        UPDATE call_sessions
        SET status = 'ended',
            end_reason = 'stale_cleanup',
            ended_at = NOW(),
            updated_at = NOW()
        WHERE status = 'live'
          AND updated_at < NOW() - INTERVAL '5 minutes'
      `,
      [],
    );

    return { ended: result.rowCount ?? 0 };
  }

  // ── Internal demo simulator controls ───────────────────────────────────────
  @Get('internal/demo-for-you/status')
  internalDemoForYouStatus(
    @Headers('x-service-key') serviceKey: string | undefined,
  ): ReturnType<DemoForYouSimulatorService['status']> {
    this.assertInternalServiceKey(serviceKey);
    return this.demoForYouSimulator.status();
  }

  @Post('internal/demo-for-you/start')
  async internalDemoForYouStart(
    @Headers('x-service-key') serviceKey: string | undefined,
    @Body() body: DemoForYouStartBody = {},
  ): Promise<ReturnType<DemoForYouSimulatorService['status']>> {
    this.assertInternalServiceKey(serviceKey);
    return this.demoForYouSimulator.start({
      count: body.count,
      intervals: body.intervals,
      routeable: body.routeable,
    });
  }

  @Post('internal/demo-for-you/stop')
  internalDemoForYouStop(
    @Headers('x-service-key') serviceKey: string | undefined,
  ): ReturnType<DemoForYouSimulatorService['status']> {
    this.assertInternalServiceKey(serviceKey);
    return this.demoForYouSimulator.stop();
  }

  @Post('internal/demo-for-you/cleanup')
  async internalDemoForYouCleanup(
    @Headers('x-service-key') serviceKey: string | undefined,
  ): Promise<{ removedHosts: number; removedRooms: number }> {
    this.assertInternalServiceKey(serviceKey);
    return this.demoForYouSimulator.cleanup();
  }

  // ── Internal endpoint for Cloud Functions ──────────────────────────────────
  @Post('internal/end-call-session')
  async internalEndCallSession(
    @Headers('x-service-key') serviceKey: string | undefined,
    @Body() body: { sessionId: string; reason?: string },
  ): Promise<{ status: string; sessionId: string }> {
    const expectedKey = process.env.SERVICE_KEY;
    if (!expectedKey || serviceKey !== expectedKey) {
      throw new UnauthorizedException('Invalid service key');
    }

    if (!body.sessionId) {
      return { status: 'no_session_id', sessionId: '' };
    }

    try {
      await this.storeService.endCallSessionInternal(
        body.sessionId,
        body.reason ?? 'signal_deleted',
      );
      return { status: 'ended', sessionId: body.sessionId };
    } catch (e: any) {
      // Session already ended or not found — that's fine (idempotent)
      return { status: 'already_ended', sessionId: body.sessionId };
    }
  }

  // ── Internal endpoint for Cloud Functions: end live room ────────────────────
  @Post('internal/end-room')
  async internalEndRoom(
    @Headers('x-service-key') serviceKey: string | undefined,
    @Body() body: { roomId: string; hostUserId: string },
  ): Promise<{ status: string; roomId: string }> {
    const expectedKey = process.env.SERVICE_KEY;
    if (!expectedKey || serviceKey !== expectedKey) {
      throw new UnauthorizedException('Invalid service key');
    }

    if (!body.roomId || !body.hostUserId) {
      return { status: 'missing_params', roomId: '' };
    }

    await this.storeService.endRoom(body.hostUserId, body.roomId);
    return { status: 'ended', roomId: body.roomId };
  }

  // ── Internal endpoint for Cloud Functions: sync presence to PG ─────────────
  @Post('internal/sync-presence')
  async internalSyncPresence(
    @Headers('x-service-key') serviceKey: string | undefined,
    @Body() body: InternalSyncPresenceBody,
  ): Promise<{ status: string }> {
    const expectedKey = process.env.SERVICE_KEY;
    if (!expectedKey || serviceKey !== expectedKey) {
      throw new UnauthorizedException('Invalid service key');
    }

    if (!body.userId || !body.status) {
      return { status: 'missing_params' };
    }

    await this.storeService.syncPresence(body.userId, body.status, {
      connection: body.connection,
      activity: body.activity,
      availability: body.availability,
      directCall: body.routing?.directCall,
      randomCall: body.routing?.randomCall,
      updatedAt: body.updatedAt,
    });
    return { status: 'synced' };
  }

  @Post('internal/gifts/retry-delivery')
  async internalRetryGiftDelivery(
    @Headers('x-service-key') serviceKey: string | undefined,
    @Body() body: InternalGiftDeliveryRetryBody = {},
  ): Promise<GiftDeliveryRetryResult> {
    this.assertInternalServiceKey(serviceKey);
    return this.giftDeliveryService.retryPendingGiftDeliveries(body.limit);
  }

  private assertInternalServiceKey(serviceKey: string | undefined): void {
    const expectedKey = process.env.SERVICE_KEY;
    if (!expectedKey || serviceKey !== expectedKey) {
      throw new UnauthorizedException('Invalid service key');
    }
  }
}
