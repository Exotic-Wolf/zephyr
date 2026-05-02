import { Controller, Get } from '@nestjs/common';
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
}