import {
  Body,
  Controller,
  Get,
  Headers,
  Post,
  UnauthorizedException,
} from '@nestjs/common';
import { DatabaseService } from '../core/database.service';
import { StoreService } from '../core/store.service';

@Controller('v1')
export class HealthController {
  constructor(
    private readonly databaseService: DatabaseService,
    private readonly storeService: StoreService,
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
}