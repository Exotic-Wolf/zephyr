import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { Pool, type QueryResult, type QueryResultRow } from 'pg';

@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DatabaseService.name);
  private pool: Pool | null = null;

  onModuleInit(): void {
    const databaseUrl = process.env.DATABASE_URL;
    if (!databaseUrl) {
      this.logger.warn('DATABASE_URL not set. Falling back to in-memory store.');
      return;
    }

    this.pool = new Pool({
      connectionString: databaseUrl,
      ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
    });

    void this.ensureSchema();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.pool) {
      await this.pool.end();
      this.pool = null;
    }
  }

  isEnabled(): boolean {
    return this.pool !== null;
  }

  async query<T extends QueryResultRow = QueryResultRow>(
    sql: string,
    params: unknown[] = [],
  ): Promise<QueryResult<T>> {
    if (!this.pool) {
      throw new Error('Database pool is not initialized');
    }
    return this.pool.query<T>(sql, params);
  }

  async ping(): Promise<void> {
    await this.query('SELECT 1');
  }

  private async ensureSchema(): Promise<void> {
    if (!this.pool) {
      return;
    }

    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY,
        display_name TEXT NOT NULL,
        email TEXT,
        provider TEXT,
        provider_subject TEXT,
        avatar_url TEXT,
        bio TEXT,
        created_at TIMESTAMPTZ NOT NULL
      );
    `);

    await this.pool.query(`
      ALTER TABLE users
      ADD COLUMN IF NOT EXISTS email TEXT,
      ADD COLUMN IF NOT EXISTS provider TEXT,
      ADD COLUMN IF NOT EXISTS provider_subject TEXT;
    `);

    await this.pool.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS users_provider_subject_idx
      ON users(provider, provider_subject)
      WHERE provider IS NOT NULL AND provider_subject IS NOT NULL;
    `);

    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS sessions (
        token TEXT PRIMARY KEY,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        expires_at TIMESTAMPTZ NOT NULL
      );
    `);

    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS rooms (
        id UUID PRIMARY KEY,
        host_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        audience_count INTEGER NOT NULL,
        status TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL
      );
    `);

    this.logger.log('Database schema is ready.');
  }
}