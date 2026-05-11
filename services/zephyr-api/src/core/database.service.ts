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
      ALTER TABLE users
      ADD COLUMN IF NOT EXISTS gender TEXT,
      ADD COLUMN IF NOT EXISTS birthday DATE,
      ADD COLUMN IF NOT EXISTS country_code TEXT,
      ADD COLUMN IF NOT EXISTS language TEXT,
      ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE,
      ADD COLUMN IF NOT EXISTS call_rate_coins_per_minute INT,
      ADD COLUMN IF NOT EXISTS public_id TEXT;
    `);

    await this.pool.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS users_public_id_idx
      ON users(public_id)
      WHERE public_id IS NOT NULL;
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
        created_at TIMESTAMPTZ NOT NULL,
        last_heartbeat TIMESTAMPTZ
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
        spark_balance INTEGER NOT NULL DEFAULT 0,
        updated_at TIMESTAMPTZ NOT NULL
      );
    `);

    await this.pool.query(`
      ALTER TABLE user_revenue
      ADD COLUMN IF NOT EXISTS spark_balance INTEGER NOT NULL DEFAULT 0;
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

    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS user_following (
        follower_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        following_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        PRIMARY KEY (follower_id, following_id)
      );
    `);

    await this.pool.query(`
      CREATE INDEX IF NOT EXISTS user_following_follower_idx
      ON user_following(follower_id, created_at DESC);
    `);

    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS messages (
        id UUID PRIMARY KEY,
        sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        body TEXT NOT NULL,
        read_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);

    await this.pool.query(`
      CREATE INDEX IF NOT EXISTS messages_receiver_created_idx
      ON messages(receiver_id, created_at DESC);
    `);

    await this.pool.query(`
      CREATE INDEX IF NOT EXISTS messages_thread_idx
      ON messages(
        LEAST(sender_id, receiver_id),
        GREATEST(sender_id, receiver_id),
        created_at DESC
      );
    `);

    // Seed: promote the owner account to admin based on env var.
    // Safe to re-run — only updates if the email matches.
    const ownerEmail = process.env.OWNER_GOOGLE_EMAIL?.trim();
    if (ownerEmail) {
      await this.pool.query(
        `UPDATE users SET is_admin = TRUE WHERE email = $1 AND provider = 'google'`,
        [ownerEmail],
      );

      // Seed: set owner wallet to level 10 so all call price tiers are unlocked.
      await this.pool.query(
        `
          UPDATE wallets
          SET level = 10
          WHERE user_id = (
            SELECT id FROM users WHERE email = $1 AND provider = 'google' LIMIT 1
          )
          AND level < 10
        `,
        [ownerEmail],
      );
    }

    // Backfill public_id for users where it is NULL (derived deterministically from UUID)
    const nullIdRows = await this.pool.query<{ id: string }>(
      `SELECT id FROM users WHERE public_id IS NULL`,
    );
    for (const row of nullIdRows.rows) {
      const derived = derivePublicId(row.id);
      try {
        await this.pool.query(
          `UPDATE users SET public_id = $1 WHERE id = $2 AND public_id IS NULL`,
          [derived, row.id],
        );
      } catch {
        // UNIQUE violation: skip (extremely rare hash collision)
      }
    }

    // Add last_heartbeat column if it doesn't exist (migration for existing DBs)
    await this.pool.query(`
      ALTER TABLE rooms ADD COLUMN IF NOT EXISTS last_heartbeat TIMESTAMPTZ
    `);

    // Startup cleanup: delete any room older than 30 minutes (catches all stale rooms)
    const startupClean = await this.pool.query(`
      DELETE FROM rooms
      WHERE status = 'live' AND created_at < NOW() - INTERVAL '30 minutes'
    `);
    if (startupClean.rowCount && startupClean.rowCount > 0) {
      this.logger.log(`Startup cleanup: removed ${startupClean.rowCount} stale room(s).`);
    }

    // Periodic cleanup every 30s:
    //  - no heartbeat for 90s → dead
    //  - any room older than 30 min → dead (host gone / crashed / forgot to end)
    setInterval(() => {
      void this.pool!.query(`
        DELETE FROM rooms
        WHERE status = 'live'
          AND (
            created_at < NOW() - INTERVAL '30 minutes'
            OR (last_heartbeat IS NOT NULL AND last_heartbeat < NOW() - INTERVAL '90 seconds')
            OR (last_heartbeat IS NULL AND created_at < NOW() - INTERVAL '5 minutes')
          )
      `).catch(() => {});
    }, 30 * 1000);

    this.logger.log('Database schema is ready.');
  }
}

function derivePublicId(uuid: string): string {
  let h = 5381;
  for (let i = 0; i < uuid.length; i++) {
    h = ((h << 5) + h + uuid.charCodeAt(i)) & 0x7fffffff;
  }
  return Math.abs(h).toString().padStart(8, '0').substring(0, 8);
}