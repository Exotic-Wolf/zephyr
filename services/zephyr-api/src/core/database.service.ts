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

    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS wallets (
        user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        coin_balance INTEGER NOT NULL DEFAULT 0,
        level INTEGER NOT NULL DEFAULT 1,
        updated_at TIMESTAMPTZ NOT NULL
      );
    `);

    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS user_revenue (
        user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        revenue_usd NUMERIC(12, 2) NOT NULL DEFAULT 0,
        updated_at TIMESTAMPTZ NOT NULL
      );
    `);

    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS wallet_transactions (
        id UUID PRIMARY KEY,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        type TEXT NOT NULL,
        coins_delta INTEGER NOT NULL,
        amount_usd NUMERIC(12, 2),
        metadata JSONB,
        created_at TIMESTAMPTZ NOT NULL
      );
    `);

    await this.pool.query(`
      CREATE INDEX IF NOT EXISTS wallet_transactions_user_created_idx
      ON wallet_transactions(user_id, created_at DESC);
    `);

    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS call_sessions (
        id UUID PRIMARY KEY,
        caller_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        receiver_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
        mode TEXT NOT NULL,
        rate_coins_per_minute INTEGER NOT NULL,
        receiver_share_bps INTEGER NOT NULL,
        coins_per_usd_receiver INTEGER NOT NULL,
        spark_per_usd INTEGER NOT NULL,
        total_billed_coins INTEGER NOT NULL DEFAULT 0,
        total_receiver_coins INTEGER NOT NULL DEFAULT 0,
        total_receiver_usd NUMERIC(14, 4) NOT NULL DEFAULT 0,
        total_receiver_spark INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        end_reason TEXT,
        started_at TIMESTAMPTZ NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL,
        ended_at TIMESTAMPTZ
      );
    `);

    await this.pool.query(`
      CREATE INDEX IF NOT EXISTS call_sessions_caller_status_idx
      ON call_sessions(caller_user_id, status, updated_at DESC);
    `);

    this.logger.log('Database schema is ready.');
  }
}