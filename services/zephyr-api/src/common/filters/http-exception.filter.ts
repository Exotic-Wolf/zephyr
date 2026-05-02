import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { type Request, type Response } from 'express';

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const context = host.switchToHttp();
    const response = context.getResponse<Response>();
    const request = context.getRequest<Request>();

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    const payload =
      exception instanceof HttpException
        ? exception.getResponse()
        : { message: 'Internal server error' };

    const message = this.resolveMessage(payload);
    const details = this.resolveDetails(payload);

    response.status(status).json({
      success: false,
      error: {
        code: this.codeFromStatus(status),
        message,
        details,
        timestamp: new Date().toISOString(),
        path: request.url,
      },
    });
  }

  private resolveMessage(payload: unknown): string {
    if (typeof payload === 'string') {
      return payload;
    }

    if (this.hasMessage(payload)) {
      const { message } = payload;
      if (Array.isArray(message)) {
        return message.join(', ');
      }
      if (typeof message === 'string') {
        return message;
      }
    }

    return 'Request failed';
  }

  private resolveDetails(payload: unknown): unknown {
    if (typeof payload === 'object' && payload !== null) {
      return payload;
    }
    return null;
  }

  private codeFromStatus(status: number): string {
    if (status >= 500) {
      return 'INTERNAL_ERROR';
    }
    if (status === 429) {
      return 'RATE_LIMITED';
    }
    if (status === 401) {
      return 'UNAUTHORIZED';
    }
    if (status === 404) {
      return 'NOT_FOUND';
    }
    if (status >= 400) {
      return 'BAD_REQUEST';
    }
    return 'UNKNOWN_ERROR';
  }

  private hasMessage(payload: unknown): payload is { message?: string | string[] } {
    return typeof payload === 'object' && payload !== null && 'message' in payload;
  }
}