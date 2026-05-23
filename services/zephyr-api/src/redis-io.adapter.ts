import { IoAdapter } from '@nestjs/platform-socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import Redis from 'ioredis';
import type { ServerOptions, Server } from 'socket.io';

/**
 * Swaps in the Redis Socket.IO adapter when REDIS_URL is set.
 * Falls back to the default in-memory adapter for local dev.
 */
export class RedisIoAdapter extends IoAdapter {
  private adapterConstructor: ReturnType<typeof createAdapter> | null = null;

  async connectToRedis(): Promise<void> {
    const redisUrl = process.env.REDIS_URL;
    if (!redisUrl) {
      return; // no Redis configured — use in-memory adapter (local dev)
    }

    const pubClient = new Redis(redisUrl);
    const subClient = pubClient.duplicate();

    this.adapterConstructor = createAdapter(pubClient, subClient);
  }

  createIOServer(port: number, options?: Partial<ServerOptions>): Server {
    const server = super.createIOServer(port, {
      ...options,
      pingInterval: 10000, // ping every 10s
      pingTimeout: 5000, // 5s to respond → disconnect after 15s max
    }) as Server;
    if (this.adapterConstructor) {
      server.adapter(this.adapterConstructor);
    }
    return server;
  }
}
