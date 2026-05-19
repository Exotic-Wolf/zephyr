import * as Sentry from '@sentry/nestjs';
import { Controller, Get } from '@nestjs/common';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getHello(): string {
    return this.appService.getHello();
  }

  @Get('sentry-test')
  sentryTest(): { ok: boolean } {
    Sentry.captureMessage('Sentry test from zephyr-api', 'info');
    return { ok: true };
  }
}
