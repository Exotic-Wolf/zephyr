"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var DatabaseService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.DatabaseService = void 0;
const common_1 = require("@nestjs/common");
const pg_1 = require("pg");
let DatabaseService = DatabaseService_1 = class DatabaseService {
    logger = new common_1.Logger(DatabaseService_1.name);
    pool = null;
    onModuleInit() {
        const databaseUrl = process.env.DATABASE_URL;
        if (!databaseUrl) {
            this.logger.warn('DATABASE_URL not set. Falling back to in-memory store.');
            return;
        }
        this.pool = new pg_1.Pool({
            connectionString: databaseUrl,
            ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
        });
        void this.ensureSchema();
    }
    async onModuleDestroy() {
        if (this.pool) {
            await this.pool.end();
            this.pool = null;
        }
    }
    isEnabled() {
        return this.pool !== null;
    }
    async query(sql, params = []) {
        if (!this.pool) {
            throw new Error('Database pool is not initialized');
        }
        return this.pool.query(sql, params);
    }
    async ping() {
        await this.query('SELECT 1');
    }
    async ensureSchema() {
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
};
exports.DatabaseService = DatabaseService;
exports.DatabaseService = DatabaseService = DatabaseService_1 = __decorate([
    (0, common_1.Injectable)()
], DatabaseService);
//# sourceMappingURL=database.service.js.map