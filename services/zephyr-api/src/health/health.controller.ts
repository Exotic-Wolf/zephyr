import { Controller, Get, Post } from '@nestjs/common';
import { DatabaseService } from '../core/database.service';

@Controller('v1/health')
export class HealthController {
  constructor(private readonly databaseService: DatabaseService) {}

  @Get('live')
  live(): { status: 'ok'; timestamp: string } {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
    };
  }

  @Get('ready')
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

  @Post('end-stale-calls')
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
}