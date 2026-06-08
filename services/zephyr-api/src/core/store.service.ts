import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
  OnModuleInit,
  Optional,
  UnauthorizedException,
} from '@nestjs/common';
import { createHash, randomUUID } from 'crypto';
import { OAuth2Client } from 'google-auth-library';
import { JWTPayload, createRemoteJWKSet, jwtVerify } from 'jose';
import { JwtPayload, sign, verify } from 'jsonwebtoken';
import type { PoolClient } from 'pg';
import { DatabaseService } from './database.service';

function derivePublicId(uuid: string, attempt = 0): string {
  const input = attempt === 0 ? uuid : `${uuid}:${attempt}`;
  let h = 5381;
  for (let i = 0; i < input.length; i++) {
    h = ((h << 5) + h + input.charCodeAt(i)) & 0x7fffffff;
  }
  return Math.abs(h).toString().padStart(8, '0').substring(0, 8);
}

export interface UserProfile {
  id: string;
  publicId: string | null;
  displayName: string;
  avatarUrl: string | null;
  coverUrl: string | null;
  bio: string | null;
  gender: string | null;
  birthday: string | null;
  countryCode: string | null;
  language: string | null;
  isAdmin: boolean;
  isHost: boolean;
  callRateCoinsPerMinute: number | null;
  followerCount?: number;
  followingCount?: number;
  onboardedAt: string | null;
  createdAt: string;
}

export interface Room {
  id: string;
  hostUserId: string;
  title: string;
  audienceCount: number;
  status: 'live';
  createdAt: string;
}

export interface LiveFeedCard {
  roomId: string | null;
  title: string;
  audienceCount: number;
  hostUserId: string;
  hostDisplayName: string;
  hostAvatarUrl: string | null;
  hostGender: string | null;
  hostCountryCode: string;
  hostLanguage: string;
  hostStatus: string;
  hostCallRateCoinsPerMinute: number | null;
  startedAt: string;
}

export interface Message {
  id: string;
  senderId: string;
  receiverId: string;
  body: string;
  deliveredAt: string | null;
  readAt: string | null;
  createdAt: string;
}

export interface Conversation {
  userId: string;
  displayName: string;
  avatarUrl: string | null;
  lastMessage: string;
  lastMessageAt: string;
  unreadCount: number;
  lastSeenAt: string | null;
}

export interface CoinPack {
  id: string;
  label: string;
  coins: number;
  priceUsd: number;
}

export interface EconomyConfig {
  privateCallRateCoinsPerMinute: number;
  randomCallRateCoinsPerMinute: number;
  directCallAllowedRatesCoinsPerMinute: number[];
  defaultDirectCallRateCoinsPerMinute: number;
  coinsPerUsdReceiver: number;
  receiverShareBps: number;
  sparkPerUsd: number;
  giftPlatformFeeBps: number;
  coinPacks: CoinPack[];
}

export interface WalletSummary {
  coinBalance: number;
  level: number;
  revenueUsd: number;
  sparkBalance: number;
}

export interface GiftCatalogItem {
  id: string;
  name: string;
  coinCost: number;
}

export interface CallSession {
  id: string;
  callerUserId: string;
  receiverUserId: string | null;
  mode: 'direct' | 'random';
  rateCoinsPerMinute: number;
  receiverShareBps: number;
  coinsPerUsdReceiver: number;
  sparkPerUsd: number;
  totalBilledCoins: number;
  totalReceiverCoins: number;
  totalReceiverUsd: number;
  totalReceiverSpark: number;
  status: 'live' | 'ended';
  endReason: string | null;
  startedAt: string;
  updatedAt: string;
  endedAt: string | null;
}

interface CallSessionRow {
  id: string;
  caller_user_id: string;
  receiver_user_id: string | null;
  mode: 'direct' | 'random';
  rate_coins_per_minute: number;
  receiver_share_bps: number;
  coins_per_usd_receiver: number;
  spark_per_usd: number;
  total_billed_coins: number;
  total_receiver_coins: number;
  total_receiver_usd: string | number;
  total_receiver_spark: number;
  status: 'live' | 'ended';
  end_reason: string | null;
  started_at: string;
  updated_at: string;
  ended_at: string | null;
}

export interface CallSessionTickResult {
  session: CallSession;
  chargedCoins: number;
  receiverCoins: number;
  receiverUsd: number;
  receiverSpark: number;
  platformCoins: number;
  callerCoinBalanceAfter: number;
  stoppedForInsufficientBalance: boolean;
}

export interface CallSessionParticipant {
  session: CallSession;
  role: 'caller' | 'receiver';
}

export interface GiftSendResult {
  sessionId: string;
  giftId: string;
  giftName: string;
  quantity: number;
  totalGiftCoins: number;
  receiverCoins: number;
  receiverUsd: number;
  receiverSpark: number;
  platformCoins: number;
  senderCoinBalanceAfter: number;
}

export interface WalletTransaction {
  id: string;
  type: string;
  coinsDelta: number;
  amountUsd: number | null;
  metadata: Record<string, unknown>;
  createdAt: string;
}

interface Session {
  token: string;
  userId: string;
  expiresAt: number;
}

export interface CallRateTier {
  label: string;
  minLevel: number;
  coinsPerMinute: number;
  sparkPerMinute: number;
}

export interface PresenceSyncOptions {
  connection?: string;
  activity?: string;
  availability?: string;
  directCall?: boolean;
  randomCall?: boolean;
  updatedAt?: number;
}

interface NormalizedPresenceSync {
  status: string;
  connection: string;
  activity: string;
  availability: string;
  directCall: boolean;
  randomCall: boolean;
  updatedAtIso: string | null;
}

type LedgerOperationType = 'call_tick' | 'call_gift' | 'live_gift';

interface LedgerIdempotencyEntry<T> {
  operationType: LedgerOperationType;
  requestHash: string;
  response: T;
}

interface LedgerIdempotencyRow {
  operation_type: LedgerOperationType;
  request_hash: string;
  response_json: unknown;
}

function stableJson(value: unknown): string {
  if (value === null || typeof value !== 'object') {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return `[${value.map((item) => stableJson(item)).join(',')}]`;
  }

  const record = value as Record<string, unknown>;
  return `{${Object.keys(record)
    .sort()
    .map((key) => `${JSON.stringify(key)}:${stableJson(record[key])}`)
    .join(',')}}`;
}

function normalizePresenceSync(
  status: string,
  options: PresenceSyncOptions = {},
): NormalizedPresenceSync {
  const normalizedStatus = status.trim().toLowerCase() || 'offline';
  const connection =
    options.connection === 'online' || options.connection === 'offline'
      ? options.connection
      : normalizedStatus === 'offline'
        ? 'offline'
        : 'online';
  const activity =
    options.activity?.trim().toLowerCase() ||
    (normalizedStatus === 'away'
      ? 'away'
      : normalizedStatus === 'live'
        ? 'free_live_host'
        : normalizedStatus === 'premium_live'
          ? 'premium_live_host'
          : normalizedStatus === 'busy'
            ? 'direct_call'
            : 'idle');
  const availability =
    options.availability === 'available' ||
    options.availability === 'busy' ||
    options.availability === 'unavailable'
      ? options.availability
      : normalizedStatus === 'offline'
        ? 'unavailable'
        : normalizedStatus === 'busy' || normalizedStatus === 'premium_live'
          ? 'busy'
          : 'available';
  const directCall =
    options.directCall ??
    (normalizedStatus === 'online' ||
      normalizedStatus === 'away' ||
      normalizedStatus === 'live');
  const randomCall =
    options.randomCall ??
    (normalizedStatus === 'online' || normalizedStatus === 'live');
  const updatedAtDate =
    typeof options.updatedAt === 'number' && options.updatedAt > 0
      ? new Date(options.updatedAt)
      : null;

  return {
    status: normalizedStatus,
    connection,
    activity,
    availability,
    directCall,
    randomCall,
    updatedAtIso:
      updatedAtDate && !Number.isNaN(updatedAtDate.getTime())
        ? updatedAtDate.toISOString()
        : null,
  };
}

@Injectable()
export class StoreService implements OnModuleInit {
  constructor(@Optional() private readonly databaseService?: DatabaseService) {}

  private readonly logger = new Logger(StoreService.name);
  private readonly googleClient = new OAuth2Client();
  private cachedCallRateTiers: CallRateTier[] = [];
  private readonly inMemoryLedgerIdempotency = new Map<
    string,
    LedgerIdempotencyEntry<unknown>
  >();

  async onModuleInit(): Promise<void> {
    await this.loadCallRateTiers();
  }

  private async loadCallRateTiers(): Promise<void> {
    if (this.databaseService?.isEnabled()) {
      try {
        const result = await this.databaseService.query<{
          label: string;
          min_level: number;
          coins_per_minute: number;
          spark_per_minute: number;
        }>('SELECT label, min_level, coins_per_minute, spark_per_minute FROM call_rate_tiers ORDER BY sort_order ASC');
        if (result.rows.length > 0) {
          this.cachedCallRateTiers = result.rows.map(r => ({
            label: r.label,
            minLevel: r.min_level,
            coinsPerMinute: r.coins_per_minute,
            sparkPerMinute: r.spark_per_minute,
          }));
          return;
        }
      } catch (e) {
        this.logger.warn('Failed to load call rate tiers from DB, using defaults', e);
      }
    }
    // Fallback defaults matching PRODUCT.md
    this.cachedCallRateTiers = [
      { label: '≤Lv3', minLevel: 1, coinsPerMinute: 2100, sparkPerMinute: 1260 },
      { label: 'Lv4', minLevel: 4, coinsPerMinute: 3200, sparkPerMinute: 1920 },
      { label: 'Lv5', minLevel: 5, coinsPerMinute: 4200, sparkPerMinute: 2520 },
      { label: 'Lv6', minLevel: 6, coinsPerMinute: 5400, sparkPerMinute: 3240 },
      { label: 'Lv7', minLevel: 7, coinsPerMinute: 6400, sparkPerMinute: 3840 },
      { label: 'Lv8', minLevel: 8, coinsPerMinute: 8000, sparkPerMinute: 4800 },
      { label: 'Lv9+', minLevel: 9, coinsPerMinute: 27000, sparkPerMinute: 16200 },
    ];
  }

  getCallRateTiers(): CallRateTier[] {
    return this.cachedCallRateTiers;
  }

  private normalizeIdempotencyKey(value?: string | null): string | null {
    if (value == null) {
      return null;
    }

    const key = value.trim();
    if (key.length === 0) {
      return null;
    }
    if (key.length < 8 || key.length > 160) {
      throw new BadRequestException(
        'idempotencyKey must be between 8 and 160 characters',
      );
    }
    if (!/^[A-Za-z0-9._:-]+$/.test(key)) {
      throw new BadRequestException(
        'idempotencyKey contains unsupported characters',
      );
    }

    return key;
  }

  private ledgerRequestHash(payload: Record<string, unknown>): string {
    return createHash('sha256').update(stableJson(payload)).digest('hex');
  }

  private inMemoryIdempotencyKey(userId: string, idempotencyKey: string): string {
    return `${userId}:${idempotencyKey}`;
  }

  private getInMemoryLedgerReplay<T>(
    userId: string,
    idempotencyKey: string | null,
    operationType: LedgerOperationType,
    requestHash: string,
  ): T | null {
    if (!idempotencyKey) {
      return null;
    }

    const entry = this.inMemoryLedgerIdempotency.get(
      this.inMemoryIdempotencyKey(userId, idempotencyKey),
    );
    if (!entry) {
      return null;
    }
    if (
      entry.operationType !== operationType ||
      entry.requestHash !== requestHash
    ) {
      throw new ConflictException(
        'idempotencyKey was already used for a different ledger request',
      );
    }

    return entry.response as T;
  }

  private saveInMemoryLedgerResponse<T>(
    userId: string,
    idempotencyKey: string | null,
    operationType: LedgerOperationType,
    requestHash: string,
    response: T,
  ): T {
    if (idempotencyKey) {
      this.inMemoryLedgerIdempotency.set(
        this.inMemoryIdempotencyKey(userId, idempotencyKey),
        { operationType, requestHash, response },
      );
    }

    return response;
  }

  private async getDatabaseLedgerReplay<T>(
    client: PoolClient,
    userId: string,
    idempotencyKey: string | null,
    operationType: LedgerOperationType,
    requestHash: string,
  ): Promise<T | null> {
    if (!idempotencyKey) {
      return null;
    }

    await client.query(
      `
        INSERT INTO ledger_idempotency (
          user_id,
          idempotency_key,
          operation_type,
          request_hash,
          created_at
        )
        VALUES ($1, $2, $3, $4, NOW())
        ON CONFLICT (user_id, idempotency_key) DO NOTHING
      `,
      [userId, idempotencyKey, operationType, requestHash],
    );

    const result = await client.query<LedgerIdempotencyRow>(
      `
        SELECT operation_type, request_hash, response_json
        FROM ledger_idempotency
        WHERE user_id = $1 AND idempotency_key = $2
        FOR UPDATE
      `,
      [userId, idempotencyKey],
    );
    const row = result.rows[0];
    if (!row) {
      throw new Error('Ledger idempotency row was not created');
    }
    if (
      row.operation_type !== operationType ||
      row.request_hash !== requestHash
    ) {
      throw new ConflictException(
        'idempotencyKey was already used for a different ledger request',
      );
    }
    if (row.response_json) {
      return row.response_json as T;
    }

    return null;
  }

  private async saveDatabaseLedgerResponse<T>(
    client: PoolClient,
    userId: string,
    idempotencyKey: string | null,
    response: T,
  ): Promise<T> {
    if (idempotencyKey) {
      await client.query(
        `
          UPDATE ledger_idempotency
          SET response_json = $3::jsonb,
              completed_at = NOW()
          WHERE user_id = $1 AND idempotency_key = $2
        `,
        [userId, idempotencyKey, JSON.stringify(response)],
      );
    }

    return response;
  }

  private async uniquePublicId(uuid: string): Promise<string> {
    if (!this.databaseService?.isEnabled()) return derivePublicId(uuid);
    for (let attempt = 0; attempt < 10; attempt++) {
      const candidate = derivePublicId(uuid, attempt);
      const { rows } = await this.databaseService.query(
        `SELECT 1 FROM users WHERE public_id = $1 LIMIT 1`,
        [candidate],
      );
      if (rows.length === 0) return candidate;
    }
    // Fallback: use full UUID prefix (extremely unlikely to reach here)
    return uuid.replace(/-/g, '').substring(0, 8);
  }

  private readonly users = new Map<string, UserProfile>();
  private readonly sessions = new Map<string, Session>();
  private readonly rooms = new Map<string, Room>();
  private readonly googleSubjectToUserId = new Map<string, string>();
  private readonly appleSubjectToUserId = new Map<string, string>();
  private readonly walletBalances = new Map<string, number>();
  private readonly userLevels = new Map<string, number>();
  private readonly userRevenueUsd = new Map<string, number>();
  private readonly userSparkBalances = new Map<string, number>();
  private readonly callSessions = new Map<string, CallSession>();

  async issueGuestSession(displayName?: string): Promise<{ accessToken: string; user: UserProfile }> {
    const userId = randomUUID();
    const token = this.signJwt(userId);
    const expiresAt = Date.now() + 1000 * 60 * 60 * 24 * 7;
    const now = new Date().toISOString();
    const user: UserProfile = {
      id: userId,
      publicId: null,
      displayName: displayName?.trim() || `zephyr_${userId.slice(0, 8)}`,
      avatarUrl: null,
      coverUrl: null,
      bio: null,
      gender: null,
      birthday: null,
      countryCode: null,
      language: null,
      isAdmin: false,
      isHost: false,
      callRateCoinsPerMinute: null,
      onboardedAt: null,
      createdAt: now,
    };

    if (this.databaseService?.isEnabled()) {
      await this.databaseService.query(
        `
          INSERT INTO users (id, display_name, avatar_url, bio, public_id, created_at)
          VALUES ($1, $2, $3, $4, $5, $6)
        `,
        [user.id, user.displayName, user.avatarUrl, user.bio, await this.uniquePublicId(user.id), user.createdAt],
      );
      await this.databaseService.query(
        `
          INSERT INTO sessions (token, user_id, expires_at)
          VALUES ($1, $2, $3)
        `,
        [token, user.id, new Date(expiresAt).toISOString()],
      );

      return { accessToken: token, user };
    }

    this.users.set(userId, user);
    this.sessions.set(token, {
      token,
      userId,
      expiresAt,
    });

    return { accessToken: token, user };
  }

  async issueGoogleSession(idToken: string): Promise<{ accessToken: string; user: UserProfile }> {
    let ticket;
    try {
      ticket = await this.googleClient.verifyIdToken({
        idToken,
        audience: this.getGoogleAudiences(),
      });
    } catch (error) {
      if (error instanceof UnauthorizedException) {
        throw error;
      }

      throw new UnauthorizedException('Invalid Google token');
    }

    const payload = ticket.getPayload();
    if (!payload || !payload.sub) {
      throw new UnauthorizedException('Invalid Google token payload');
    }

    const googleSubject = payload.sub;
    const email = payload.email ?? null;
    const displayName =
      payload.name?.trim() ||
      (email ? email.split('@')[0] : `google_${googleSubject.slice(0, 8)}`);
    const avatarUrl = payload.picture ?? null;

    if (this.databaseService?.isEnabled()) {
      const existingUserResult = await this.databaseService.query<{
        id: string;
      }>(
        `
          SELECT id
          FROM users
          WHERE provider = 'google' AND provider_subject = $1
          LIMIT 1
        `,
        [googleSubject],
      );

      let userId = existingUserResult.rows[0]?.id;
      if (!userId) {
        userId = randomUUID();
        await this.databaseService.query(
          `
            INSERT INTO users (
              id,
              display_name,
              email,
              provider,
              provider_subject,
              avatar_url,
              bio,
              public_id,
              created_at
            )
            VALUES ($1, $2, $3, 'google', $4, $5, $6, $7, $8)
          `,
          [
            userId,
            displayName,
            email,
            googleSubject,
            avatarUrl,
            null,
            await this.uniquePublicId(userId),
            new Date().toISOString(),
          ],
        );
      } else {
        // On re-login, only sync email — leave display_name and avatar_url intact
        // so users can customise them without being reset by Google on every login.
        await this.databaseService.query(
          `
            UPDATE users
            SET email = $2, avatar_url = COALESCE(avatar_url, $3)
            WHERE id = $1
          `,
          [userId, email, avatarUrl],
        );
      }

      const accessToken = this.signJwt(userId);
      const expiresAt = Date.now() + 1000 * 60 * 60 * 24 * 7;

      const userResult = await this.databaseService.query<{
        id: string;
        display_name: string;
        avatar_url: string | null;
        bio: string | null;
        gender: string | null;
        birthday: string | null;
        country_code: string | null;
        language: string | null;
        public_id: string | null;
        is_admin: boolean;
        call_rate_coins_per_minute: number | null;
        onboarded_at: string | null;
        created_at: string;
      }>(
        `
          SELECT id, public_id, display_name, avatar_url, cover_url, bio, gender, birthday,
                 country_code, language, is_admin, is_host, call_rate_coins_per_minute, onboarded_at, created_at
          FROM users
          WHERE id = $1
          LIMIT 1
        `,
        [userId],
      );

      await this.databaseService.query(
        `
          INSERT INTO sessions (token, user_id, expires_at)
          VALUES ($1, $2, $3)
        `,
        [accessToken, userId, new Date(expiresAt).toISOString()],
      );

      return {
        accessToken,
        user: this.toUserProfile(userResult.rows[0]),
      };
    }

    let userId = this.googleSubjectToUserId.get(googleSubject);
    if (!userId) {
      userId = randomUUID();
      this.googleSubjectToUserId.set(googleSubject, userId);
    }

    const accessToken = this.signJwt(userId);
    const expiresAt = Date.now() + 1000 * 60 * 60 * 24 * 7;

    const user: UserProfile = {
      id: userId,
      publicId: null,
      displayName,
      avatarUrl,
      coverUrl: null,
      bio: null,
      gender: null,
      birthday: null,
      countryCode: null,
      language: null,
      isAdmin: false,
      isHost: false,
      callRateCoinsPerMinute: null,
      onboardedAt: null,
      createdAt: this.users.get(userId)?.createdAt ?? new Date().toISOString(),
    };

    this.users.set(userId, user);
    this.sessions.set(accessToken, {
      token: accessToken,
      userId,
      expiresAt,
    });

    return { accessToken, user };
  }

  async issueAppleSession(
    idToken: string,
    profileHints?: { givenName?: string; familyName?: string; email?: string },
  ): Promise<{ accessToken: string; user: UserProfile }> {
    const payload = await this.verifyAppleIdToken(idToken);
    const appleSubject = payload.sub;

    if (!appleSubject) {
      throw new UnauthorizedException('Invalid Apple token payload');
    }

    const email =
      typeof payload.email === 'string'
        ? payload.email
        : (profileHints?.email ?? null);
    const hintFullName =
      [profileHints?.givenName, profileHints?.familyName]
        .filter((value): value is string => Boolean(value && value.trim().length > 0))
        .join(' ')
        .trim();
    const displayName =
      hintFullName.length > 0
        ? hintFullName
        : (email ? email.split('@')[0] : `apple_${appleSubject.slice(0, 8)}`);

    if (this.databaseService?.isEnabled()) {
      const existingUserResult = await this.databaseService.query<{
        id: string;
      }>(
        `
          SELECT id
          FROM users
          WHERE provider = 'apple' AND provider_subject = $1
          LIMIT 1
        `,
        [appleSubject],
      );

      let userId = existingUserResult.rows[0]?.id;
      if (!userId) {
        userId = randomUUID();
        await this.databaseService.query(
          `
            INSERT INTO users (
              id,
              display_name,
              email,
              provider,
              provider_subject,
              avatar_url,
              bio,
              public_id,
              created_at
            )
            VALUES ($1, $2, $3, 'apple', $4, $5, $6, $7, $8)
          `,
          [
            userId,
            displayName,
            email,
            appleSubject,
            null,
            null,
            await this.uniquePublicId(userId),
            new Date().toISOString(),
          ],
        );
      } else {
        // On re-login, only sync email — leave display_name (nickname) intact
        // so users can customise it without Apple resetting it on every login.
        await this.databaseService.query(
          `
            UPDATE users
            SET email = COALESCE($2, email)
            WHERE id = $1
          `,
          [userId, email],
        );
      }

      const accessToken = this.signJwt(userId);
      const expiresAt = Date.now() + 1000 * 60 * 60 * 24 * 7;

      const userResult = await this.databaseService.query<{
        id: string;
        display_name: string;
        avatar_url: string | null;
        bio: string | null;
        gender: string | null;
        birthday: string | null;
        country_code: string | null;
        language: string | null;
        public_id: string | null;
        is_admin: boolean;
        call_rate_coins_per_minute: number | null;
        onboarded_at: string | null;
        created_at: string;
      }>(
        `
          SELECT id, public_id, display_name, avatar_url, cover_url, bio, gender, birthday,
                 country_code, language, is_admin, is_host, call_rate_coins_per_minute, onboarded_at, created_at
          FROM users
          WHERE id = $1
          LIMIT 1
        `,
        [userId],
      );

      await this.databaseService.query(
        `
          INSERT INTO sessions (token, user_id, expires_at)
          VALUES ($1, $2, $3)
        `,
        [accessToken, userId, new Date(expiresAt).toISOString()],
      );

      return {
        accessToken,
        user: this.toUserProfile(userResult.rows[0]),
      };
    }

    let userId = this.appleSubjectToUserId.get(appleSubject);
    if (!userId) {
      userId = randomUUID();
      this.appleSubjectToUserId.set(appleSubject, userId);
    }

    const accessToken = this.signJwt(userId);
    const expiresAt = Date.now() + 1000 * 60 * 60 * 24 * 7;

    const user: UserProfile = {
      id: userId,
      publicId: null,
      displayName,
      avatarUrl: null,
      coverUrl: null,
      bio: null,
      gender: null,
      birthday: null,
      countryCode: null,
      language: null,
      isAdmin: false,
      isHost: false,
      callRateCoinsPerMinute: null,
      onboardedAt: null,
      createdAt: this.users.get(userId)?.createdAt ?? new Date().toISOString(),
    };

    this.users.set(userId, user);
    this.sessions.set(accessToken, {
      token: accessToken,
      userId,
      expiresAt,
    });

    return { accessToken, user };
  }

  async getUserFromAuthHeader(authorization?: string): Promise<UserProfile> {
    if (!authorization || !authorization.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing bearer token');
    }

    const token = authorization.replace('Bearer ', '').trim();
    const tokenPayload = this.verifyJwt(token);

    if (this.databaseService?.isEnabled()) {
      const result = await this.databaseService.query<{
        id: string;
        public_id: string | null;
        display_name: string;
        avatar_url: string | null;
        bio: string | null;
        gender: string | null;
        birthday: string | null;
        country_code: string | null;
        language: string | null;
        is_admin: boolean;
        call_rate_coins_per_minute: number | null;
        onboarded_at: string | null;
        created_at: string;
      }>(
        `
          SELECT u.id, u.public_id, u.display_name, u.avatar_url, u.cover_url, u.bio, u.gender, u.birthday,
                 u.country_code, u.language, u.is_admin, u.is_host, u.call_rate_coins_per_minute, u.onboarded_at, u.created_at
          FROM sessions s
          INNER JOIN users u ON u.id = s.user_id
          WHERE s.token = $1 AND s.user_id = $2 AND s.expires_at > NOW()
          LIMIT 1
        `,
        [token, tokenPayload.sub],
      );

      if (result.rowCount === 0) {
        throw new UnauthorizedException('Invalid or expired token');
      }

      return this.toUserProfile(result.rows[0]);
    }

    const session = this.sessions.get(token);

    if (
      !session ||
      session.expiresAt < Date.now() ||
      session.userId !== tokenPayload.sub
    ) {
      throw new UnauthorizedException('Invalid or expired token');
    }

    const user = this.users.get(session.userId);
    if (!user) {
      throw new UnauthorizedException('Session user not found');
    }

    return user;
  }

  async updateUser(
    userId: string,
    updates: {
      displayName?: string;
      avatarUrl?: string | null;
      coverUrl?: string | null;
      bio?: string | null;
      gender?: string | null;
      birthday?: string | null;
      countryCode?: string | null;
      language?: string | null;
      callRateCoinsPerMinute?: number | null;
      publicId?: string | null;
    },
  ): Promise<UserProfile> {
    if (updates.displayName !== undefined && updates.displayName.trim().length < 2) {
      throw new BadRequestException('displayName must be at least 2 characters');
    }

    if (this.databaseService?.isEnabled()) {
      const currentResult = await this.databaseService.query<{
        id: string;
        display_name: string;
        avatar_url: string | null;
        cover_url: string | null;
        bio: string | null;
        gender: string | null;
        birthday: string | null;
        country_code: string | null;
        language: string | null;
        public_id: string | null;
        is_admin: boolean;
        call_rate_coins_per_minute: number | null;
        onboarded_at: string | null;
        created_at: string;
      }>(
        `
          SELECT id, public_id, display_name, avatar_url, cover_url, bio, gender, birthday,
                 country_code, language, is_admin, is_host, call_rate_coins_per_minute, onboarded_at, created_at
          FROM users
          WHERE id = $1
          LIMIT 1
        `,
        [userId],
      );

      if (currentResult.rowCount === 0) {
        throw new NotFoundException('User not found');
      }

      const currentUser = this.toUserProfile(currentResult.rows[0]);
      const nextDisplayName = updates.displayName?.trim() || currentUser.displayName;
      const nextAvatarUrl = updates.avatarUrl !== undefined ? updates.avatarUrl : currentUser.avatarUrl;
      const nextCoverUrl = updates.coverUrl !== undefined ? updates.coverUrl : currentUser.coverUrl;
      const nextBio = updates.bio !== undefined ? updates.bio : currentUser.bio;
      const nextGender = updates.gender !== undefined ? updates.gender : currentUser.gender;
      const nextBirthday = updates.birthday !== undefined ? updates.birthday : currentUser.birthday;
      const nextCountryCode = updates.countryCode !== undefined ? updates.countryCode : currentUser.countryCode;
      const nextLanguage = updates.language !== undefined ? updates.language : currentUser.language;
      const nextCallRate = updates.callRateCoinsPerMinute !== undefined ? updates.callRateCoinsPerMinute : currentUser.callRateCoinsPerMinute;
      const nextPublicId = updates.publicId !== undefined ? updates.publicId : currentUser.publicId;

      // Auto-set is_host based on gender: Female = host by default
      const shouldSetHost = updates.gender !== undefined ? updates.gender === 'Female' : undefined;

      const updatedResult = await this.databaseService.query<{
        id: string;
        public_id: string | null;
        display_name: string;
        avatar_url: string | null;
        cover_url: string | null;
        bio: string | null;
        gender: string | null;
        birthday: string | null;
        country_code: string | null;
        language: string | null;
        is_admin: boolean;
        is_host: boolean;
        call_rate_coins_per_minute: number | null;
        onboarded_at: string | null;
        created_at: string;
      }>(
        `
          UPDATE users
          SET display_name = $2, avatar_url = $3, cover_url = $4, bio = $5,
              gender = $6, birthday = $7, country_code = $8, language = $9,
              call_rate_coins_per_minute = $10, public_id = $11,
              onboarded_at = COALESCE(onboarded_at, NOW())
              ${shouldSetHost !== undefined ? `, is_host = $12` : ''}
          WHERE id = $1
          RETURNING id, public_id, display_name, avatar_url, cover_url, bio, gender, birthday,
                    country_code, language, is_admin, is_host, call_rate_coins_per_minute, onboarded_at, created_at
        `,
        shouldSetHost !== undefined
          ? [userId, nextDisplayName, nextAvatarUrl, nextCoverUrl, nextBio, nextGender, nextBirthday, nextCountryCode, nextLanguage, nextCallRate, nextPublicId, shouldSetHost]
          : [userId, nextDisplayName, nextAvatarUrl, nextCoverUrl, nextBio, nextGender, nextBirthday, nextCountryCode, nextLanguage, nextCallRate, nextPublicId],
      );

      return this.toUserProfile(updatedResult.rows[0]);
    }

    const user = this.users.get(userId);
    if (!user) {
      throw new NotFoundException('User not found');
    }

    const nextUser: UserProfile = {
      ...user,
      displayName: updates.displayName?.trim() || user.displayName,
      avatarUrl: updates.avatarUrl !== undefined ? updates.avatarUrl : user.avatarUrl,
      coverUrl: updates.coverUrl !== undefined ? updates.coverUrl : user.coverUrl,
      bio: updates.bio !== undefined ? updates.bio : user.bio,
      gender: updates.gender !== undefined ? updates.gender : user.gender,
      isHost: updates.gender !== undefined ? updates.gender === 'Female' : user.isHost,
      birthday: updates.birthday !== undefined ? updates.birthday : user.birthday,
      countryCode: updates.countryCode !== undefined ? updates.countryCode : user.countryCode,
      language: updates.language !== undefined ? updates.language : user.language,
      callRateCoinsPerMinute: updates.callRateCoinsPerMinute !== undefined ? updates.callRateCoinsPerMinute : user.callRateCoinsPerMinute,
      publicId: updates.publicId !== undefined ? updates.publicId : user.publicId,
      onboardedAt: user.onboardedAt ?? new Date().toISOString(),
    };

    this.users.set(userId, nextUser);
    return nextUser;
  }

  async deleteUserAccount(userId: string): Promise<void> {
    if (this.databaseService?.isEnabled()) {
      await this.databaseService.transaction(async (client) => {
        // Hard delete call sessions where user participated so receiver-set-null rows do not remain.
        await client.query(
          `
            DELETE FROM call_sessions
            WHERE caller_user_id = $1 OR receiver_user_id = $1
          `,
          [userId],
        );

        const deleted = await client.query<{ id: string }>(
          `
            DELETE FROM users
            WHERE id = $1
            RETURNING id
          `,
          [userId],
        );

        if ((deleted.rowCount ?? 0) === 0) {
          throw new NotFoundException('User not found');
        }
      });

      return;
    }

    this.users.delete(userId);
    this.walletBalances.delete(userId);
    this.userLevels.delete(userId);
    this.userRevenueUsd.delete(userId);
    this.userSparkBalances.delete(userId);

    for (const [token, session] of this.sessions.entries()) {
      if (session.userId === userId) {
        this.sessions.delete(token);
      }
    }

    for (const [roomId, room] of this.rooms.entries()) {
      if (room.hostUserId === userId) {
        this.rooms.delete(roomId);
      }
    }

    for (const [sessionId, session] of this.callSessions.entries()) {
      if (session.callerUserId === userId || session.receiverUserId === userId) {
        this.callSessions.delete(sessionId);
      }
    }

    for (const [messageId, message] of this.inMemoryMessages.entries()) {
      if (message.senderId === userId || message.receiverId === userId) {
        this.inMemoryMessages.delete(messageId);
      }
    }

    for (const [subject, mappedUserId] of this.googleSubjectToUserId.entries()) {
      if (mappedUserId === userId) {
        this.googleSubjectToUserId.delete(subject);
      }
    }

    for (const [subject, mappedUserId] of this.appleSubjectToUserId.entries()) {
      if (mappedUserId === userId) {
        this.appleSubjectToUserId.delete(subject);
      }
    }
  }

  async listRooms(): Promise<Room[]> {
    if (this.databaseService?.isEnabled()) {
      const result = await this.databaseService.query<{
        id: string;
        host_user_id: string;
        title: string;
        audience_count: number;
        status: 'live';
        created_at: string;
      }>(
        `
          SELECT id, host_user_id, title, audience_count, status, created_at
          FROM rooms
          WHERE status = 'live'
          ORDER BY created_at DESC
        `,
      );

      return result.rows.map((row) => this.toRoom(row));
    }

    return [...this.rooms.values()].sort((firstRoom, secondRoom) => {
      return secondRoom.createdAt.localeCompare(firstRoom.createdAt);
    });
  }

  async listLiveFeed(limit = 50): Promise<LiveFeedCard[]> {
    const normalizedLimit = Number.isFinite(limit)
      ? Math.min(Math.max(Math.trunc(limit), 1), 100)
      : 50;

    if (this.databaseService?.isEnabled()) {
      const result = await this.databaseService.query<{
        host_user_id: string;
        host_display_name: string;
        host_avatar_url: string | null;
        host_gender: string | null;
        host_country_code: string | null;
        host_language: string | null;
        user_status: string;
        call_rate_coins_per_minute: number | null;
        onboarded_at: string | null;
        room_id: string | null;
        audience_count: number | null;
        started_at: string | null;
      }>(
        `
          SELECT
            users.id            AS host_user_id,
            users.display_name  AS host_display_name,
            users.avatar_url    AS host_avatar_url,
            users.gender        AS host_gender,
            users.country_code  AS host_country_code,
            users.language      AS host_language,
            COALESCE(users.status, 'offline') AS user_status,
            users.call_rate_coins_per_minute,
            rooms.id            AS room_id,
            rooms.audience_count,
            rooms.created_at    AS started_at
          FROM users
          LEFT JOIN rooms
            ON rooms.host_user_id = users.id AND rooms.status = 'live'
          WHERE users.provider IS NOT NULL
            AND users.is_host = TRUE
            AND users.gender = 'Female'
          ORDER BY
            (rooms.id IS NOT NULL) DESC,
            rooms.audience_count DESC NULLS LAST,
            users.display_name ASC
          LIMIT $1
        `,
        [normalizedLimit],
      );

      return result.rows.map((row) => ({
        roomId: row.room_id ?? null,
        title: row.host_display_name,
        audienceCount: row.audience_count ?? 0,
        hostUserId: row.host_user_id,
        hostDisplayName: row.host_display_name,
        hostAvatarUrl: row.host_avatar_url,
        hostGender: row.host_gender,
        hostCountryCode: row.host_country_code ?? 'PH',
        hostLanguage: row.host_language ?? 'English',
        hostStatus: row.user_status,
        hostCallRateCoinsPerMinute: row.call_rate_coins_per_minute,
        startedAt: row.started_at
          ? new Date(row.started_at).toISOString()
          : new Date().toISOString(),
      }));
    }

    // In-memory fallback: return only host users with live status derived from rooms
    return [...this.users.values()]
      .filter((u) => u.isHost && u.gender === 'Female')
      .map((u) => {
        const room = [...this.rooms.values()].find(
          (r) => r.hostUserId === u.id && r.status === 'live',
        );
        return {
          roomId: room?.id ?? null,
          title: u.displayName,
          audienceCount: room?.audienceCount ?? 0,
          hostUserId: u.id,
          hostDisplayName: u.displayName,
          hostAvatarUrl: u.avatarUrl ?? null,
          hostGender: u.gender ?? null,
          hostCountryCode: u.countryCode ?? 'PH',
          hostLanguage: u.language ?? 'English',
          hostStatus: room ? 'live' : (u as any).status ?? 'offline',
          hostCallRateCoinsPerMinute: u.callRateCoinsPerMinute ?? null,
          startedAt: room?.createdAt ?? new Date().toISOString(),
        };
      })
      .sort((a, b) => {
        if (a.hostStatus === 'live' && b.hostStatus !== 'live') return -1;
        if (b.hostStatus === 'live' && a.hostStatus !== 'live') return 1;
        return b.audienceCount - a.audienceCount;
      })
      .slice(0, normalizedLimit);
  }

  async getRoomHostUserId(roomId: string): Promise<string | null> {
    const result = await this.databaseService!.query<{ host_user_id: string }>(
      'SELECT host_user_id FROM rooms WHERE id = $1',
      [roomId],
    );
    return result.rows[0]?.host_user_id ?? null;
  }

  async createRoom(hostUserId: string, title: string): Promise<Room> {
    if (!title || title.trim().length < 3) {
      throw new BadRequestException('title must be at least 3 characters');
    }

    const room: Room = {
      id: randomUUID(),
      hostUserId,
      title: title.trim(),
      audienceCount: 0,
      status: 'live',
      createdAt: new Date().toISOString(),
    };

    if (this.databaseService?.isEnabled()) {
      await this.databaseService.query(
        `
          DELETE FROM rooms
          WHERE host_user_id = $1 AND status = 'live'
        `,
        [hostUserId],
      );

      const result = await this.databaseService.query<{
        id: string;
        host_user_id: string;
        title: string;
        audience_count: number;
        status: 'live';
        created_at: string;
      }>(
        `
          INSERT INTO rooms (id, host_user_id, title, audience_count, status, created_at)
          VALUES ($1, $2, $3, $4, $5, $6)
          RETURNING id, host_user_id, title, audience_count, status, created_at
        `,
        [room.id, room.hostUserId, room.title, room.audienceCount, room.status, room.createdAt],
      );

      return this.toRoom(result.rows[0]);
    }

    const existingLiveRoom = [...this.rooms.values()].find(
      (existingRoom) =>
        existingRoom.hostUserId === hostUserId && existingRoom.status === 'live',
    );
    if (existingLiveRoom) {
      this.rooms.delete(existingLiveRoom.id);
    }

    this.rooms.set(room.id, room);
    return room;
  }

  async joinRoom(roomId: string, userId: string): Promise<Room> {
    if (this.databaseService?.isEnabled()) {
      // Only increment audience_count if this viewer is new (not a re-join)
      const inserted = await this.databaseService.query<{ room_id: string }>(
        `INSERT INTO room_viewers (room_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING RETURNING room_id`,
        [roomId, userId],
      );

      if (inserted.rowCount && inserted.rowCount > 0) {
        await this.databaseService.query(
          `UPDATE rooms SET audience_count = audience_count + 1 WHERE id = $1 AND status = 'live'`,
          [roomId],
        );
      }

      const result = await this.databaseService.query<{
        id: string;
        host_user_id: string;
        title: string;
        audience_count: number;
        status: 'live';
        created_at: string;
      }>(
        `SELECT id, host_user_id, title, audience_count, status, created_at FROM rooms WHERE id = $1 AND status = 'live'`,
        [roomId],
      );

      if (result.rowCount === 0) {
        throw new NotFoundException('Room not found');
      }

      return this.toRoom(result.rows[0]);
    }

    const room = this.rooms.get(roomId);
    if (!room) {
      throw new NotFoundException('Room not found');
    }

    const nextRoom: Room = {
      ...room,
      audienceCount: room.audienceCount + 1,
    };

    this.rooms.set(roomId, nextRoom);
    return nextRoom;
  }

  async endRoom(hostUserId: string, roomId: string): Promise<void> {
    if (this.databaseService?.isEnabled()) {
      await this.databaseService.query(
        `
          DELETE FROM rooms
          WHERE id = $1 AND host_user_id = $2 AND status = 'live'
        `,
        [roomId, hostUserId],
      );
      // Idempotent: don't throw if already deleted (e.g. called twice from dispose)
      return;
    }

    const room = this.rooms.get(roomId);
    if (room && room.hostUserId === hostUserId) {
      this.rooms.delete(roomId);
    }

    this.rooms.delete(roomId);
  }

  async heartbeatRoom(hostUserId: string, roomId: string): Promise<void> {
    if (this.databaseService?.isEnabled()) {
      await this.databaseService.query(
        `
          UPDATE rooms
          SET last_heartbeat = NOW()
          WHERE id = $1 AND host_user_id = $2 AND status = 'live'
        `,
        [roomId, hostUserId],
      );
      return;
    }
    // in-memory: no-op (room is live if it exists)
  }

  async leaveRoom(roomId: string, userId: string): Promise<void> {
    if (this.databaseService?.isEnabled()) {
      // Delete viewer row first — only decrement if row actually existed
      const { rowCount } = await this.databaseService.query(
        `DELETE FROM room_viewers WHERE room_id = $1 AND user_id = $2`,
        [roomId, userId],
      );
      if ((rowCount ?? 0) > 0) {
        await this.databaseService.query(
          `
            UPDATE rooms
            SET audience_count = GREATEST(audience_count - 1, 0)
            WHERE id = $1 AND status = 'live'
          `,
          [roomId],
        );
      }
      return;
    }

    const room = this.rooms.get(roomId);
    if (room) {
      this.rooms.set(roomId, {
        ...room,
        audienceCount: Math.max(room.audienceCount - 1, 0),
      });
    }
  }

  async getRoomViewers(
    roomId: string,
    limit = 50,
  ): Promise<{ displayName: string; avatarUrl: string | null }[]> {
    if (this.databaseService?.isEnabled()) {
      const result = await this.databaseService.query<{
        display_name: string;
        avatar_url: string | null;
      }>(
        `
          SELECT u.display_name, u.avatar_url
          FROM room_viewers rv
          JOIN users u ON u.id = rv.user_id
          WHERE rv.room_id = $1
          ORDER BY rv.joined_at DESC
          LIMIT $2
        `,
        [roomId, limit],
      );
      return result.rows.map((r) => ({
        displayName: r.display_name,
        avatarUrl: r.avatar_url,
      }));
    }
    return [];
  }

  async getUserById(userId: string): Promise<UserProfile> {
    if (this.databaseService?.isEnabled()) {
      const result = await this.databaseService.query<{
        id: string;
        display_name: string;
        avatar_url: string | null;
        bio: string | null;
        gender: string | null;
        birthday: string | null;
        country_code: string | null;
        language: string | null;
        public_id: string | null;
        is_admin: boolean;
        call_rate_coins_per_minute: number | null;
        onboarded_at: string | null;
        created_at: string;
      }>(
        `
          SELECT u.id, u.public_id, u.display_name, u.avatar_url, u.cover_url, u.bio, u.gender, u.birthday,
                 u.country_code, u.language, u.is_admin, u.is_host, u.call_rate_coins_per_minute, u.onboarded_at, u.created_at,
                 (SELECT COUNT(*)::int FROM user_following f WHERE f.following_id = u.id) AS follower_count,
                 (SELECT COUNT(*)::int FROM user_following f WHERE f.follower_id = u.id) AS following_count
          FROM users u WHERE u.id = $1 LIMIT 1
        `,
        [userId],
      );

      if (result.rowCount === 0) {
        throw new NotFoundException('User not found');
      }

      return this.toUserProfile(result.rows[0]);
    }

    const user = this.users.get(userId);
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async getUsersByIds(userIds: string[]): Promise<UserProfile[]> {
    if (!userIds.length) return [];
    if (this.databaseService?.isEnabled()) {
      const placeholders = userIds.map((_, i) => `$${i + 1}`).join(',');
      const result = await this.databaseService.query<{
        id: string;
        display_name: string;
        avatar_url: string | null;
        bio: string | null;
        gender: string | null;
        birthday: string | null;
        country_code: string | null;
        language: string | null;
        public_id: string | null;
        is_admin: boolean;
        call_rate_coins_per_minute: number | null;
        onboarded_at: string | null;
        created_at: string;
      }>(
        `SELECT id, public_id, display_name, avatar_url, cover_url, bio, gender, birthday,
                country_code, language, is_admin, is_host, call_rate_coins_per_minute, onboarded_at, created_at
         FROM users WHERE id IN (${placeholders})`,
        userIds,
      );
      return result.rows.map((row) => this.toUserProfile(row));
    }
    return userIds
      .map((id) => this.users.get(id))
      .filter((u): u is UserProfile => u !== undefined);
  }

  async getUserByPublicId(publicId: string): Promise<UserProfile> {
    if (this.databaseService?.isEnabled()) {
      const result = await this.databaseService.query<{
        id: string;
        display_name: string;
        avatar_url: string | null;
        bio: string | null;
        gender: string | null;
        birthday: string | null;
        country_code: string | null;
        language: string | null;
        public_id: string | null;
        is_admin: boolean;
        call_rate_coins_per_minute: number | null;
        onboarded_at: string | null;
        created_at: string;
      }>(
        `
          SELECT u.id, u.public_id, u.display_name, u.avatar_url, u.cover_url, u.bio, u.gender, u.birthday,
                 u.country_code, u.language, u.is_admin, u.is_host, u.call_rate_coins_per_minute, u.onboarded_at, u.created_at,
                 (SELECT COUNT(*)::int FROM user_following f WHERE f.following_id = u.id) AS follower_count,
                 (SELECT COUNT(*)::int FROM user_following f WHERE f.follower_id = u.id) AS following_count
          FROM users u WHERE u.public_id = $1 LIMIT 1
        `,
        [publicId],
      );

      if (result.rowCount === 0) {
        throw new NotFoundException('User not found');
      }

      return this.toUserProfile(result.rows[0]);
    }

    const user = [...this.users.values()].find(u => u.publicId === publicId);
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async searchUsers(q: string): Promise<UserProfile[]> {
    if (!q || q.length < 2) return [];

    if (this.databaseService?.isEnabled()) {
      const result = await this.databaseService.query<{
        id: string;
        display_name: string;
        avatar_url: string | null;
        bio: string | null;
        gender: string | null;
        birthday: string | null;
        country_code: string | null;
        language: string | null;
        public_id: string | null;
        is_admin: boolean;
        call_rate_coins_per_minute: number | null;
        onboarded_at: string | null;
        created_at: string;
      }>(
        `
          SELECT u.id, u.public_id, u.display_name, u.avatar_url, u.cover_url, u.bio, u.gender, u.birthday,
                 u.country_code, u.language, u.is_admin, u.is_host, u.call_rate_coins_per_minute, u.onboarded_at, u.created_at,
                 (SELECT COUNT(*)::int FROM user_following f WHERE f.following_id = u.id) AS follower_count,
                 (SELECT COUNT(*)::int FROM user_following f WHERE f.follower_id = u.id) AS following_count
          FROM users u
          WHERE u.display_name ILIKE $1
             OR u.public_id = $2
          ORDER BY display_name
          LIMIT 30
        `,
        [`%${q}%`, q],
      );
      return result.rows.map(row => this.toUserProfile(row));
    }

    const lower = q.toLowerCase();
    return [...this.users.values()]
      .filter(u =>
        u.displayName.toLowerCase().includes(lower) ||
        u.publicId === q,
      )
      .slice(0, 30);
  }

  async followUser(followerId: string, followingId: string): Promise<void> {
    if (followerId === followingId) {
      throw new BadRequestException('Cannot follow yourself');
    }

    if (this.databaseService?.isEnabled()) {
      await this.databaseService.query(
        `
          INSERT INTO user_following (follower_id, following_id)
          VALUES ($1, $2)
          ON CONFLICT DO NOTHING
        `,
        [followerId, followingId],
      );
      return;
    }

    // in-memory: no-op (following is a mock in the client)
  }

  async unfollowUser(followerId: string, followingId: string): Promise<void> {
    if (this.databaseService?.isEnabled()) {
      await this.databaseService.query(
        `
          DELETE FROM user_following
          WHERE follower_id = $1 AND following_id = $2
        `,
        [followerId, followingId],
      );
      return;
    }
    // in-memory: no-op
  }

  async blockUser(blockerId: string, blockedId: string): Promise<void> {
    if (blockerId === blockedId) {
      throw new BadRequestException('Cannot block yourself');
    }
    if (this.databaseService?.isEnabled()) {
      await this.databaseService.query(
        `INSERT INTO user_blocks (blocker_id, blocked_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
        [blockerId, blockedId],
      );
    }
  }

  async unblockUser(blockerId: string, blockedId: string): Promise<void> {
    if (this.databaseService?.isEnabled()) {
      await this.databaseService.query(
        `DELETE FROM user_blocks WHERE blocker_id = $1 AND blocked_id = $2`,
        [blockerId, blockedId],
      );
    }
  }

  async isBlocked(blockerId: string, blockedId: string): Promise<boolean> {
    if (!this.databaseService?.isEnabled()) return false;
    const result = await this.databaseService.query<{ exists: boolean }>(
      `SELECT EXISTS(SELECT 1 FROM user_blocks WHERE blocker_id = $1 AND blocked_id = $2) AS exists`,
      [blockerId, blockedId],
    );
    return result.rows[0]?.exists ?? false;
  }

  async reportUser(
    reporterId: string,
    reportedId: string,
    reason?: string,
  ): Promise<void> {
    if (reporterId === reportedId) {
      throw new BadRequestException('Cannot report yourself');
    }
    if (!this.databaseService?.isEnabled()) return;

    await this.databaseService.query(
      `
        INSERT INTO user_reports (reporter_id, reported_id, reason)
        VALUES ($1, $2, $3)
        ON CONFLICT (reporter_id, reported_id)
        DO UPDATE SET reason = EXCLUDED.reason, created_at = NOW()
      `,
      [reporterId, reportedId, reason?.trim() || null],
    );

    const countResult = await this.databaseService.query<{ cnt: string }>(
      `
        SELECT COUNT(*) AS cnt FROM user_reports
        WHERE reported_id = $1
          AND created_at > NOW() - INTERVAL '7 days'
      `,
      [reportedId],
    );
    const count = Number.parseInt(countResult.rows[0]?.cnt ?? '0', 10);
    await this.databaseService.query(
      `UPDATE users SET report_count = $1 WHERE id = $2`,
      [count, reportedId],
    );
  }

  async reportCall(
    reporterId: string,
    sessionId: string,
    reportedId: string,
    reason?: string,
  ): Promise<void> {
    if (!this.databaseService?.isEnabled()) return;

    // Insert report (ignore duplicate — one report per session per reporter)
    await this.databaseService.query(
      `
        INSERT INTO call_reports (session_id, reporter_id, reported_id, reason)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (session_id, reporter_id) DO NOTHING
      `,
      [sessionId, reporterId, reportedId, reason ?? null],
    );

    // Count reports against this user in the last 7 days
    const result = await this.databaseService.query<{ cnt: string }>(
      `
        SELECT COUNT(*) AS cnt FROM call_reports
        WHERE reported_id = $1
          AND created_at > NOW() - INTERVAL '7 days'
      `,
      [reportedId],
    );

    const count = parseInt(result.rows[0]?.cnt ?? '0', 10);

    // Auto-ban at 5+ reports in 7 days
    if (count >= 5) {
      await this.databaseService.query(
        `UPDATE users SET is_banned = TRUE WHERE id = $1`,
        [reportedId],
      );
    }
  }

  /** Returns all user IDs that are blocked by OR have blocked the given user (bidirectional). */
  async getBlockedIds(userId: string): Promise<Set<string>> {
    if (!this.databaseService?.isEnabled()) return new Set();
    const result = await this.databaseService.query<{ other_id: string }>(
      `
        SELECT blocked_id AS other_id FROM user_blocks WHERE blocker_id = $1
        UNION
        SELECT blocker_id AS other_id FROM user_blocks WHERE blocked_id = $1
      `,
      [userId],
    );
    return new Set(result.rows.map((r) => r.other_id));
  }


  async getFollowing(userId: string): Promise<string[]> {
    if (this.databaseService?.isEnabled()) {
      const result = await this.databaseService.query<{ following_id: string }>(
        `
          SELECT following_id FROM user_following
          WHERE follower_id = $1
          ORDER BY created_at DESC
        `,
        [userId],
      );

      return result.rows.map((r) => r.following_id);
    }

    return [];
  }

  async getCallHistory(userId: string, limit = 20): Promise<CallSession[]> {
    const normalizedLimit = Math.min(Math.max(Math.trunc(limit), 1), 100);

    if (this.databaseService?.isEnabled()) {
      const result = await this.databaseService.query<{
        id: string;
        caller_user_id: string;
        receiver_user_id: string | null;
        mode: 'direct' | 'random';
        rate_coins_per_minute: number;
        receiver_share_bps: number;
        coins_per_usd_receiver: number;
        spark_per_usd: number;
        total_billed_coins: number;
        total_receiver_coins: number;
        total_receiver_usd: string;
        total_receiver_spark: number;
        status: 'live' | 'ended';
        end_reason: string | null;
        started_at: string;
        updated_at: string;
        ended_at: string | null;
      }>(
        `
          SELECT * FROM call_sessions
          WHERE caller_user_id = $1 OR receiver_user_id = $1
          ORDER BY started_at DESC
          LIMIT $2
        `,
        [userId, normalizedLimit],
      );

      return result.rows.map((row) => this.toCallSession(row));
    }

    return [...this.callSessions.values()]
      .filter((s) => s.callerUserId === userId || s.receiverUserId === userId)
      .sort((a, b) => b.startedAt.localeCompare(a.startedAt))
      .slice(0, normalizedLimit);
  }

  async getTransactionHistory(userId: string, limit = 50): Promise<WalletTransaction[]> {
    const normalizedLimit = Math.min(Math.max(Math.trunc(limit), 1), 200);

    if (!this.databaseService?.isEnabled()) {
      return [];
    }

    const result = await this.databaseService.query<{
      id: string;
      type: string;
      coins_delta: number;
      amount_usd: string | null;
      metadata: Record<string, unknown> | null;
      created_at: string;
    }>(
      `
        SELECT id, type, coins_delta, amount_usd, metadata, created_at
        FROM wallet_transactions
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT $2
      `,
      [userId, normalizedLimit],
    );

    return result.rows.map((row) => ({
      id: row.id,
      type: row.type,
      coinsDelta: row.coins_delta,
      amountUsd: row.amount_usd ? Number.parseFloat(row.amount_usd) : null,
      metadata: row.metadata ?? {},
      createdAt: row.created_at,
    }));
  }

  // ── Messaging ────────────────────────────────────────────────────────────────

  private readonly inMemoryMessages = new Map<string, Message>();

  async upsertDeviceToken(userId: string, token: string): Promise<void> {
    if (!this.databaseService?.isEnabled()) return;
    await this.databaseService.query(
      `INSERT INTO device_tokens (user_id, token, updated_at)
       VALUES ($1, $2, NOW())
       ON CONFLICT (user_id, token) DO UPDATE SET updated_at = NOW()`,
      [userId, token],
    );
  }

  async deleteDeviceToken(userId: string, token: string): Promise<void> {
    if (!this.databaseService?.isEnabled()) return;
    await this.databaseService.query(
      `DELETE FROM device_tokens WHERE user_id = $1 AND token = $2`,
      [userId, token],
    );
  }

  async getDeviceTokens(userId: string): Promise<string[]> {
    if (!this.databaseService?.isEnabled()) return [];
    const result = await this.databaseService.query<{ token: string }>(
      `SELECT token FROM device_tokens WHERE user_id = $1`,
      [userId],
    );
    return result.rows.map((r) => r.token);
  }

  async sendMessage(senderId: string, receiverId: string, body: string, idempotencyKey?: string): Promise<{ message: Message; isNew: boolean }> {
    if (!body?.trim()) {
      throw new BadRequestException('Message body cannot be empty');
    }
    if (body.trim().length > 2000) {
      throw new BadRequestException('Message body too long (max 2000 chars)');
    }

    if (idempotencyKey && this.databaseService?.isEnabled()) {
      const existing = await this.databaseService.query<{
        id: string; sender_id: string; receiver_id: string;
        body: string; delivered_at: string | null; read_at: string | null; created_at: string;
      }>(
        `SELECT id, sender_id, receiver_id, body, delivered_at, read_at, created_at
         FROM messages
         WHERE idempotency_key = $1 AND created_at > NOW() - INTERVAL '60 seconds'`,
        [idempotencyKey],
      );
      if (existing.rows.length > 0) {
        const r = existing.rows[0];
        return {
          message: { id: r.id, senderId: r.sender_id, receiverId: r.receiver_id, body: r.body, deliveredAt: r.delivered_at, readAt: r.read_at, createdAt: r.created_at },
          isNew: false,
        };
      }
    }

    const msg: Message = {
      id: randomUUID(),
      senderId,
      receiverId,
      body: body.trim(),
      deliveredAt: null,
      readAt: null,
      createdAt: new Date().toISOString(),
    };

    if (this.databaseService?.isEnabled()) {
      await this.databaseService.query(
        `
          INSERT INTO messages (id, sender_id, receiver_id, body, created_at, idempotency_key)
          VALUES ($1, $2, $3, $4, $5, $6)
        `,
        [msg.id, msg.senderId, msg.receiverId, msg.body, msg.createdAt, idempotencyKey ?? null],
      );
      return { message: msg, isNew: true };
    }

    this.inMemoryMessages.set(msg.id, msg);
    return { message: msg, isNew: true };
  }

  async getConversations(userId: string): Promise<Conversation[]> {
    if (this.databaseService?.isEnabled()) {
      const result = await this.databaseService.query<{
        other_id: string;
        display_name: string;
        avatar_url: string | null;
        last_message: string;
        last_message_at: string;
        unread_count: string;
        last_seen_at: string | null;
      }>(
        `
          SELECT
            other_users.id AS other_id,
            other_users.display_name,
            other_users.avatar_url,
            other_users.last_seen_at,
            last_msg.body AS last_message,
            last_msg.created_at AS last_message_at,
            COALESCE(unread.cnt, 0) AS unread_count
          FROM (
            SELECT DISTINCT
              CASE WHEN sender_id = $1 THEN receiver_id ELSE sender_id END AS partner_id
            FROM messages
            WHERE sender_id = $1 OR receiver_id = $1
          ) AS partners
          INNER JOIN users other_users ON other_users.id = partners.partner_id
          CROSS JOIN LATERAL (
            SELECT body, created_at FROM messages
            WHERE (sender_id = $1 AND receiver_id = partners.partner_id)
               OR (sender_id = partners.partner_id AND receiver_id = $1)
            ORDER BY created_at DESC LIMIT 1
          ) AS last_msg
          LEFT JOIN LATERAL (
            SELECT COUNT(*) AS cnt FROM messages
            WHERE sender_id = partners.partner_id AND receiver_id = $1 AND read_at IS NULL
          ) AS unread ON TRUE
          ORDER BY last_msg.created_at DESC
        `,
        [userId],
      );

      return result.rows.map((row) => ({
        userId: row.other_id,
        displayName: row.display_name,
        avatarUrl: row.avatar_url,
        lastMessage: row.last_message,
        lastMessageAt: new Date(row.last_message_at).toISOString(),
        unreadCount: parseInt(row.unread_count, 10),
        lastSeenAt: row.last_seen_at ? new Date(row.last_seen_at).toISOString() : null,
      }));
    }

    // in-memory fallback
    const partnerIds = new Set<string>();
    for (const m of this.inMemoryMessages.values()) {
      if (m.senderId === userId) partnerIds.add(m.receiverId);
      if (m.receiverId === userId) partnerIds.add(m.senderId);
    }

    const convos: Conversation[] = [];
    for (const partnerId of partnerIds) {
      const thread = [...this.inMemoryMessages.values()]
        .filter(
          (m) =>
            (m.senderId === userId && m.receiverId === partnerId) ||
            (m.senderId === partnerId && m.receiverId === userId),
        )
        .sort((a, b) => b.createdAt.localeCompare(a.createdAt));

      const partner = this.users.get(partnerId);
      const unreadCount = thread.filter(
        (m) => m.receiverId === userId && !m.readAt,
      ).length;

      if (thread[0]) {
        convos.push({
          userId: partnerId,
          displayName: partner?.displayName ?? partnerId,
          avatarUrl: partner?.avatarUrl ?? null,
          lastMessage: thread[0].body,
          lastMessageAt: thread[0].createdAt,
          unreadCount,
          lastSeenAt: null,
        });
      }
    }

    return convos.sort((a, b) => b.lastMessageAt.localeCompare(a.lastMessageAt));
  }

  async getThread(
    userId: string,
    partnerId: string,
    limit = 50,
    before?: Date,
    after?: Date,
  ): Promise<{ messages: Message[]; hasMore: boolean }> {
    const normalizedLimit = Math.min(Math.max(Math.trunc(limit), 1), 200);
    const fetchLimit = normalizedLimit + 1;

    if (this.databaseService?.isEnabled()) {
      const params: (string | number)[] = [userId, partnerId, fetchLimit];
      const beforeClause = before
        ? `AND created_at < $${params.push(before.toISOString())}`
        : '';
      // after-cursor: fetch messages newer than this timestamp (no LIMIT needed, just get all missed)
      const afterClause = after
        ? `AND created_at > $${params.push(after.toISOString())}`
        : '';

      const result = await this.databaseService.query<{
        id: string;
        sender_id: string;
        receiver_id: string;
        body: string;
        delivered_at: string | null;
        read_at: string | null;
        created_at: string;
      }>(
        after
          ? // Cursor sync: fetch everything after a timestamp, no DESC/LIMIT wrapping needed
            `
            SELECT id, sender_id, receiver_id, body, delivered_at, read_at, created_at
            FROM messages
            WHERE ((sender_id = $1 AND receiver_id = $2)
               OR (sender_id = $2 AND receiver_id = $1))
               ${afterClause}
            ORDER BY created_at ASC
          `
          : `
          SELECT id, sender_id, receiver_id, body, delivered_at, read_at, created_at
          FROM (
            SELECT id, sender_id, receiver_id, body, delivered_at, read_at, created_at
            FROM messages
            WHERE ((sender_id = $1 AND receiver_id = $2)
               OR (sender_id = $2 AND receiver_id = $1))
               ${beforeClause}
            ORDER BY created_at DESC
            LIMIT $3
          ) sub
          ORDER BY created_at ASC
        `,
        params,
      );

      // For after-cursor queries there is no pagination — return all missed messages
      const hasMore = after ? false : result.rows.length > normalizedLimit;
      // Rows are ASC-sorted: index 0 = oldest, index N = newest.
      // When hasMore, we fetched limit+1 rows. The extra row is the oldest (index 0) —
      // it proves there are older messages. Slice it off; keep the newest `limit` rows.
      const rows = hasMore ? result.rows.slice(1) : result.rows;
      return {
        messages: rows.map((row) => ({
          id: row.id,
          senderId: row.sender_id,
          receiverId: row.receiver_id,
          body: row.body,
          deliveredAt: row.delivered_at ? new Date(row.delivered_at).toISOString() : null,
          readAt: row.read_at ? new Date(row.read_at).toISOString() : null,
          createdAt: new Date(row.created_at).toISOString(),
        })),
        hasMore,
      };
    }

    const all = [...this.inMemoryMessages.values()]
      .filter(
        (m) =>
          (m.senderId === userId && m.receiverId === partnerId) ||
          (m.senderId === partnerId && m.receiverId === userId),
      )
      .filter((m) => !before || m.createdAt < before.toISOString())
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt));

    const hasMore = all.length > normalizedLimit;
    return {
      messages: all.slice(0, normalizedLimit).reverse(),
      hasMore,
    };
  }

  async markMessageDelivered(messageId: string, userId: string): Promise<Message> {
    if (this.databaseService?.isEnabled()) {
      const result = await this.databaseService.query<{
        id: string;
        sender_id: string;
        receiver_id: string;
        body: string;
        delivered_at: string | null;
        read_at: string | null;
        created_at: string;
      }>(
        `
          UPDATE messages
          SET delivered_at = NOW()
          WHERE id = $1 AND receiver_id = $2 AND delivered_at IS NULL
          RETURNING id, sender_id, receiver_id, body, delivered_at, read_at, created_at
        `,
        [messageId, userId],
      );

      if (result.rowCount === 0) {
        throw new NotFoundException('Message not found');
      }

      const row = result.rows[0];
      return {
        id: row.id,
        senderId: row.sender_id,
        receiverId: row.receiver_id,
        body: row.body,
        deliveredAt: row.delivered_at ? new Date(row.delivered_at).toISOString() : null,
        readAt: row.read_at ? new Date(row.read_at).toISOString() : null,
        createdAt: new Date(row.created_at).toISOString(),
      };
    }

    const msg = this.inMemoryMessages.get(messageId);
    if (!msg || msg.receiverId !== userId) {
      throw new NotFoundException('Message not found');
    }
    const updated = { ...msg, deliveredAt: new Date().toISOString() };
    this.inMemoryMessages.set(messageId, updated);
    return updated;
  }

  async markMessageRead(messageId: string, userId: string): Promise<Message> {
    if (this.databaseService?.isEnabled()) {
      const result = await this.databaseService.query<{
        id: string;
        sender_id: string;
        receiver_id: string;
        body: string;
        delivered_at: string | null;
        read_at: string | null;
        created_at: string;
      }>(
        `
          UPDATE messages
          SET read_at = NOW(), delivered_at = COALESCE(delivered_at, NOW())
          WHERE id = $1 AND receiver_id = $2 AND read_at IS NULL
          RETURNING id, sender_id, receiver_id, body, delivered_at, read_at, created_at
        `,
        [messageId, userId],
      );

      if (result.rowCount === 0) {
        throw new NotFoundException('Message not found');
      }

      const row = result.rows[0];
      return {
        id: row.id,
        senderId: row.sender_id,
        receiverId: row.receiver_id,
        body: row.body,
        deliveredAt: row.delivered_at ? new Date(row.delivered_at).toISOString() : null,
        readAt: row.read_at ? new Date(row.read_at).toISOString() : null,
        createdAt: new Date(row.created_at).toISOString(),
      };
    }

    const msg = this.inMemoryMessages.get(messageId);
    if (!msg || msg.receiverId !== userId) {
      throw new NotFoundException('Message not found');
    }
    const updated = { ...msg, deliveredAt: msg.deliveredAt ?? new Date().toISOString(), readAt: new Date().toISOString() };
    this.inMemoryMessages.set(messageId, updated);
    return updated;
  }

  getEconomyConfig(): EconomyConfig {
    const directCallAllowedRates = this.getDirectCallAllowedRates();
    const legacyPrivateCallRateRaw = Number.parseInt(
      process.env.PRIVATE_CALL_RATE_COINS_PER_MINUTE ??
        String(directCallAllowedRates[0] ?? 2100),
      10,
    );
    const defaultDirectCallRateRaw = Number.parseInt(
      process.env.DEFAULT_DIRECT_CALL_RATE_COINS_PER_MINUTE ??
        String(legacyPrivateCallRateRaw),
      10,
    );
    const randomCallRateRaw = Number.parseInt(
      process.env.RANDOM_CALL_RATE_COINS_PER_MINUTE ?? '600',
      10,
    );
    const coinsPerUsdReceiverRaw = Number.parseInt(
      process.env.COINS_PER_USD_RECEIVER ?? '10000',
      10,
    );
    const receiverShareBpsRaw = Number.parseInt(
      process.env.RECEIVER_SHARE_BPS ?? '6000',
      10,
    );
    const sparkPerUsdRaw = Number.parseInt(
      process.env.SPARK_PER_USD ?? String(coinsPerUsdReceiverRaw),
      10,
    );
    const giftFeeRaw = Number.parseInt(
      process.env.GIFT_PLATFORM_FEE_BPS ?? '3000',
      10,
    );

    const normalizedDefaultDirectRate = directCallAllowedRates.includes(
      defaultDirectCallRateRaw,
    )
      ? defaultDirectCallRateRaw
      : directCallAllowedRates[0];
    const normalizedRandomRate = Number.isFinite(randomCallRateRaw)
      ? Math.max(randomCallRateRaw, 1)
      : 600;
    const normalizedCoinsPerUsdReceiver = Number.isFinite(coinsPerUsdReceiverRaw)
      ? Math.max(coinsPerUsdReceiverRaw, 1)
      : 10000;
    const normalizedReceiverShareBps = Number.isFinite(receiverShareBpsRaw)
      ? Math.min(Math.max(receiverShareBpsRaw, 0), 10000)
      : 6000;
    const normalizedSparkPerUsd = Number.isFinite(sparkPerUsdRaw)
      ? Math.max(sparkPerUsdRaw, 1)
      : normalizedCoinsPerUsdReceiver;

    return {
      privateCallRateCoinsPerMinute: normalizedDefaultDirectRate,
      randomCallRateCoinsPerMinute: normalizedRandomRate,
      directCallAllowedRatesCoinsPerMinute: directCallAllowedRates,
      defaultDirectCallRateCoinsPerMinute: normalizedDefaultDirectRate,
      coinsPerUsdReceiver: normalizedCoinsPerUsdReceiver,
      receiverShareBps: normalizedReceiverShareBps,
      sparkPerUsd: normalizedSparkPerUsd,
      giftPlatformFeeBps: Number.isFinite(giftFeeRaw)
        ? Math.max(giftFeeRaw, 0)
        : 3000,
      coinPacks: this.listCoinPacks(),
    };
  }

  listCoinPacks(): CoinPack[] {
    const rawConfig = process.env.COIN_PACKS_JSON?.trim();
    if (!rawConfig) {
      return [
        { id: 'pack_299', label: '16.5K', coins: 16500, priceUsd: 2.99 },
        { id: 'pack_599', label: '33K', coins: 33000, priceUsd: 5.99 },
        { id: 'pack_999', label: '55K', coins: 55000, priceUsd: 9.99 },
        { id: 'pack_2999', label: '165K', coins: 165000, priceUsd: 29.99 },
        { id: 'pack_5999', label: '330K', coins: 330000, priceUsd: 59.99 },
        { id: 'pack_9999', label: '550K', coins: 550000, priceUsd: 99.99 },
      ];
    }

    try {
      const parsed = JSON.parse(rawConfig) as unknown;
      if (!Array.isArray(parsed)) {
        throw new Error('COIN_PACKS_JSON must be an array');
      }

      const packs = parsed
        .map((item) => {
          const candidate = item as {
            id?: string;
            label?: string;
            coins?: number;
            priceUsd?: number;
          };

          if (
            !candidate.id ||
            !candidate.label ||
            !Number.isFinite(candidate.coins) ||
            !Number.isFinite(candidate.priceUsd)
          ) {
            return null;
          }

          const coins = Number(candidate.coins);
          const priceUsd = Number(candidate.priceUsd);

          return {
            id: candidate.id,
            label: candidate.label,
            coins: Math.max(Math.trunc(coins), 1),
            priceUsd: Math.max(priceUsd, 0),
          } satisfies CoinPack;
        })
        .filter((pack): pack is CoinPack => pack !== null);

      if (packs.length > 0) {
        return packs;
      }
    } catch {
      this.logger.warn(
        'Invalid COIN_PACKS_JSON. Using default coin pack scaffold values.',
      );
    }

    return [
      { id: 'pack_299', label: '16.5K', coins: 16500, priceUsd: 2.99 },
      { id: 'pack_599', label: '33K', coins: 33000, priceUsd: 5.99 },
      { id: 'pack_999', label: '55K', coins: 55000, priceUsd: 9.99 },
      { id: 'pack_2999', label: '165K', coins: 165000, priceUsd: 29.99 },
      { id: 'pack_5999', label: '330K', coins: 330000, priceUsd: 59.99 },
      { id: 'pack_9999', label: '550K', coins: 550000, priceUsd: 99.99 },
    ];
  }

  async getWalletSummary(userId: string): Promise<WalletSummary> {
    if (this.databaseService?.isEnabled()) {
      await this.ensureWalletAndRevenueRows(userId);

      const result = await this.databaseService.query<{
        coin_balance: number;
        level: number;
        revenue_usd: string | number;
        spark_balance: number;
      }>(
        `
          SELECT
            wallets.coin_balance,
            wallets.level,
            COALESCE(user_revenue.revenue_usd, 0) AS revenue_usd,
            COALESCE(user_revenue.spark_balance, 0) AS spark_balance
          FROM wallets
          LEFT JOIN user_revenue ON user_revenue.user_id = wallets.user_id
          WHERE wallets.user_id = $1
          LIMIT 1
        `,
        [userId],
      );

      const row = result.rows[0];
      return {
        coinBalance: row?.coin_balance ?? 0,
        level: row?.level ?? 1,
        revenueUsd: Number.parseFloat(String(row?.revenue_usd ?? 0)) || 0,
        sparkBalance: row?.spark_balance ?? 0,
      };
    }

    return {
      coinBalance: this.walletBalances.get(userId) ?? 1200,
      level: this.userLevels.get(userId) ?? 4,
      revenueUsd: this.userRevenueUsd.get(userId) ?? 86.4,
      sparkBalance: this.userSparkBalances.get(userId) ?? 0,
    };
  }

  async purchaseCoins(userId: string, packId: string): Promise<WalletSummary> {
    const selectedPack = this.listCoinPacks().find((pack) => pack.id === packId);
    if (!selectedPack) {
      throw new BadRequestException('Unknown coin pack id');
    }

    if (this.databaseService?.isEnabled()) {
      await this.databaseService.transaction(async (client) => {
        await this.ensureWalletAndRevenueRows(userId, client);

        await client.query(
          `
            UPDATE wallets
            SET coin_balance = coin_balance + $2,
                updated_at = NOW()
            WHERE user_id = $1
          `,
          [userId, selectedPack.coins],
        );

        await this.writeWalletTransaction({
          userId,
          type: 'purchase',
          coinsDelta: selectedPack.coins,
          amountUsd: selectedPack.priceUsd,
          metadata: { packId: selectedPack.id, label: selectedPack.label },
          createdAt: new Date().toISOString(),
          client,
        });
      });

      return this.getWalletSummary(userId);
    }

    const current = this.walletBalances.get(userId) ?? 1200;
    this.walletBalances.set(userId, current + selectedPack.coins);
    if (!this.userLevels.has(userId)) {
      this.userLevels.set(userId, 4);
    }
    if (!this.userRevenueUsd.has(userId)) {
      this.userRevenueUsd.set(userId, 86.4);
    }
    if (!this.userSparkBalances.has(userId)) {
      this.userSparkBalances.set(userId, 0);
    }

    return this.getWalletSummary(userId);
  }

  getPrivateCallQuote(
    minutes: number,
    options?: {
      mode?: string;
      directRateCoinsPerMinute?: number;
    },
  ): {
    minutes: number;
    mode: 'direct' | 'random';
    requiredCoins: number;
    rateCoinsPerMinute: number;
    directCallAllowedRatesCoinsPerMinute: number[];
  } {
    const normalizedMinutes = Number.isFinite(minutes)
      ? Math.min(Math.max(Math.trunc(minutes), 1), 240)
      : 1;
    const config = this.getEconomyConfig();
    const mode = options?.mode === 'random' ? 'random' : 'direct';

    let rateCoinsPerMinute =
      mode === 'random'
        ? config.randomCallRateCoinsPerMinute
        : config.defaultDirectCallRateCoinsPerMinute;

    if (mode === 'direct' && options?.directRateCoinsPerMinute !== undefined) {
      if (
        !config.directCallAllowedRatesCoinsPerMinute.includes(
          options.directRateCoinsPerMinute,
        )
      ) {
        throw new BadRequestException(
          `Invalid direct call rate. Allowed rates: ${config.directCallAllowedRatesCoinsPerMinute.join(', ')}`,
        );
      }
      rateCoinsPerMinute = options.directRateCoinsPerMinute;
    }

    return {
      minutes: normalizedMinutes,
      mode,
      requiredCoins: normalizedMinutes * rateCoinsPerMinute,
      rateCoinsPerMinute,
      directCallAllowedRatesCoinsPerMinute:
        config.directCallAllowedRatesCoinsPerMinute,
    };
  }

  // ─── Random Call Matching (longest-live-first + 4h cooldown) ──────────────

  /**
   * Find the best live host for a random call.
   * Priority: longest live first (started_at ASC).
   * Excludes: the caller, blocked users, hosts matched within 4h.
   * Fallback: if all live hosts are in cooldown, ignore cooldown.
   */
  async findBestRandomMatch(callerId: string): Promise<string | null> {
    if (!this.databaseService?.isEnabled()) return null;
    const blockedIds = await this.getBlockedIds(callerId);
    const blockedArr = [...blockedIds];

    // Step 1: longest live + respect 4h cooldown
    const withCooldown = await this.databaseService.query<{ host_user_id: string }>(
      `SELECT r.host_user_id FROM rooms r
       JOIN users u ON u.id = r.host_user_id
       WHERE r.status = 'live'
         AND u.presence_availability = 'available'
         AND u.can_random_call = TRUE
         AND u.is_banned = FALSE
         AND r.host_user_id != $1
         ${blockedArr.length > 0 ? `AND r.host_user_id != ALL($2::uuid[])` : ''}
         AND NOT EXISTS (
           SELECT 1 FROM random_call_matches m
           WHERE m.caller_id = $1
             AND m.host_id = r.host_user_id
             AND m.matched_at > NOW() - INTERVAL '4 hours'
         )
         AND NOT EXISTS (
           SELECT 1 FROM call_sessions cs
           WHERE cs.receiver_user_id = r.host_user_id
             AND cs.status = 'live'
         )
       ORDER BY r.created_at ASC
       LIMIT 1`,
      blockedArr.length > 0 ? [callerId, blockedArr] : [callerId],
    );

    if (withCooldown.rows.length > 0) {
      return withCooldown.rows[0].host_user_id;
    }

    // Step 2: fallback — ignore cooldown, still pick longest live
    const fallback = await this.databaseService.query<{ host_user_id: string }>(
      `SELECT r.host_user_id FROM rooms r
       JOIN users u ON u.id = r.host_user_id
       WHERE r.status = 'live'
         AND u.presence_availability = 'available'
         AND u.can_random_call = TRUE
         AND u.is_banned = FALSE
         AND r.host_user_id != $1
         ${blockedArr.length > 0 ? `AND r.host_user_id != ALL($2::uuid[])` : ''}
         AND NOT EXISTS (
           SELECT 1 FROM call_sessions cs
           WHERE cs.receiver_user_id = r.host_user_id
             AND cs.status = 'live'
         )
       ORDER BY r.created_at ASC
       LIMIT 1`,
      blockedArr.length > 0 ? [callerId, blockedArr] : [callerId],
    );

    return fallback.rows.length > 0 ? fallback.rows[0].host_user_id : null;
  }

  /** Record a random call match for cooldown tracking. */
  async recordRandomMatch(callerId: string, hostId: string): Promise<void> {
    if (!this.databaseService?.isEnabled()) return;
    await this.databaseService.query(
      `INSERT INTO random_call_matches (caller_id, host_id) VALUES ($1, $2)`,
      [callerId, hostId],
    );
  }

  /**
   * Find the best online user for a random call (fallback when no live hosts).
   * Priority: longest online (last_seen_at most recent = actively using the app).
   * Excludes: the caller, blocked users, users already in a call, 4h cooldown.
   * Fallback: ignores cooldown if all exhausted.
   * Presence synced by Cloud Function (no client heartbeat).
   */
  async findBestOnlineMatch(callerId: string): Promise<string | null> {
    if (!this.databaseService?.isEnabled()) return null;
    const blockedIds = await this.getBlockedIds(callerId);
    const blockedArr = [...blockedIds];

    // Step 1: canonically routeable host, respect 4h cooldown
    const withCooldown = await this.databaseService.query<{ id: string }>(
      `SELECT u.id FROM users u
       WHERE u.is_host = TRUE
         AND u.presence_availability = 'available'
         AND u.can_random_call = TRUE
         AND u.id != $1
         AND u.is_banned = FALSE
         ${blockedArr.length > 0 ? `AND u.id != ALL($2::uuid[])` : ''}
         AND NOT EXISTS (
           SELECT 1 FROM random_call_matches m
           WHERE m.caller_id = $1
             AND m.host_id = u.id
             AND m.matched_at > NOW() - INTERVAL '4 hours'
         )
         AND NOT EXISTS (
           SELECT 1 FROM call_sessions cs
           WHERE (cs.caller_user_id = u.id OR cs.receiver_user_id = u.id)
             AND cs.status = 'live'
         )
         AND NOT EXISTS (
           SELECT 1 FROM rooms r
           WHERE r.host_user_id = u.id AND r.status = 'live'
         )
       ORDER BY u.last_seen_at DESC
       LIMIT 1`,
      blockedArr.length > 0 ? [callerId, blockedArr] : [callerId],
    );

    if (withCooldown.rows.length > 0) {
      return withCooldown.rows[0].id;
    }

    // Step 2: fallback — ignore cooldown
    const fallback = await this.databaseService.query<{ id: string }>(
      `SELECT u.id FROM users u
       WHERE u.is_host = TRUE
         AND u.presence_availability = 'available'
         AND u.can_random_call = TRUE
         AND u.id != $1
         AND u.is_banned = FALSE
         ${blockedArr.length > 0 ? `AND u.id != ALL($2::uuid[])` : ''}
         AND NOT EXISTS (
           SELECT 1 FROM call_sessions cs
           WHERE (cs.caller_user_id = u.id OR cs.receiver_user_id = u.id)
             AND cs.status = 'live'
         )
         AND NOT EXISTS (
           SELECT 1 FROM rooms r
           WHERE r.host_user_id = u.id AND r.status = 'live'
         )
       ORDER BY u.last_seen_at DESC
       LIMIT 1`,
      blockedArr.length > 0 ? [callerId, blockedArr] : [callerId],
    );

    return fallback.rows.length > 0 ? fallback.rows[0].id : null;
  }

  async startCallSession(
    callerUserId: string,
    options: {
      mode: string;
      receiverUserId?: string;
      directRateCoinsPerMinute?: number;
    },
  ): Promise<CallSession> {
    const mode = options.mode === 'random' ? 'random' : 'direct';
    const receiverUserId = options.receiverUserId?.trim() || undefined;

    if (mode === 'direct' && !receiverUserId) {
      throw new BadRequestException('receiverUserId is required for direct call');
    }

    const callerBusy = await this.hasLiveCallSessionForUser(callerUserId);
    if (callerBusy) {
      throw new BadRequestException('Caller is busy in another live call');
    }

    if (receiverUserId && receiverUserId !== callerUserId) {
      if (this.databaseService?.isEnabled()) {
        const routeability = await this.databaseService.query<{
          status: string;
          presence_availability: string;
          can_direct_call: boolean;
        }>(
          `SELECT status, presence_availability, can_direct_call
           FROM users
           WHERE id = $1`,
          [receiverUserId],
        );
        const receiverPresence = routeability.rows[0];
        if (!receiverPresence) {
          throw new NotFoundException('Receiver not found');
        }
        if (
          receiverPresence.presence_availability !== 'available' ||
          !receiverPresence.can_direct_call
        ) {
          throw new BadRequestException('Receiver is not available');
        }
      }

      const receiverBusy = await this.hasLiveCallSessionForUser(receiverUserId);
      if (receiverBusy) {
        throw new BadRequestException('Receiver is busy in another live call');
      }

      // Block check: either direction
      const callerBlocked = await this.isBlocked(receiverUserId, callerUserId);
      const receiverBlocked = await this.isBlocked(callerUserId, receiverUserId);
      if (callerBlocked || receiverBlocked) {
        throw new BadRequestException('Cannot call this user');
      }
    }

    const quote = this.getPrivateCallQuote(1, {
      mode,
      directRateCoinsPerMinute: options.directRateCoinsPerMinute,
    });
    const config = this.getEconomyConfig();
    const now = new Date().toISOString();

    const session: CallSession = {
      id: randomUUID(),
      callerUserId,
      receiverUserId: receiverUserId ?? null,
      mode,
      rateCoinsPerMinute: quote.rateCoinsPerMinute,
      receiverShareBps: config.receiverShareBps,
      coinsPerUsdReceiver: config.coinsPerUsdReceiver,
      sparkPerUsd: config.sparkPerUsd,
      totalBilledCoins: 0,
      totalReceiverCoins: 0,
      totalReceiverUsd: 0,
      totalReceiverSpark: 0,
      status: 'live',
      endReason: null,
      startedAt: now,
      updatedAt: now,
      endedAt: null,
    };

    if (this.databaseService?.isEnabled()) {
      await this.ensureWalletAndRevenueRows(callerUserId);
      if (session.receiverUserId && session.receiverUserId !== callerUserId) {
        await this.ensureWalletAndRevenueRows(session.receiverUserId);
      }

      await this.databaseService.query(
        `
          INSERT INTO call_sessions (
            id,
            caller_user_id,
            receiver_user_id,
            mode,
            rate_coins_per_minute,
            receiver_share_bps,
            coins_per_usd_receiver,
            spark_per_usd,
            total_billed_coins,
            total_receiver_coins,
            total_receiver_usd,
            total_receiver_spark,
            status,
            end_reason,
            started_at,
            updated_at,
            ended_at
          )
          VALUES (
            $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17
          )
        `,
        [
          session.id,
          session.callerUserId,
          session.receiverUserId,
          session.mode,
          session.rateCoinsPerMinute,
          session.receiverShareBps,
          session.coinsPerUsdReceiver,
          session.sparkPerUsd,
          session.totalBilledCoins,
          session.totalReceiverCoins,
          session.totalReceiverUsd,
          session.totalReceiverSpark,
          session.status,
          session.endReason,
          session.startedAt,
          session.updatedAt,
          session.endedAt,
        ],
      );

      return session;
    }

    this.callSessions.set(session.id, session);
    return session;
  }

  async tickCallSession(
    callerUserId: string,
    sessionId: string,
    elapsedSeconds = 60,
    idempotencyKey?: string | null,
  ): Promise<CallSessionTickResult> {
    const normalizedSeconds = Number.isFinite(elapsedSeconds)
      ? Math.min(Math.max(Math.trunc(elapsedSeconds), 1), 300)
      : 60;
    const normalizedIdempotencyKey =
      this.normalizeIdempotencyKey(idempotencyKey);
    const requestHash = this.ledgerRequestHash({
      operationType: 'call_tick',
      sessionId,
      elapsedSeconds: normalizedSeconds,
    });

    if (this.databaseService?.isEnabled()) {
      return this.tickCallSessionInDatabase(
        callerUserId,
        sessionId,
        normalizedSeconds,
        normalizedIdempotencyKey,
        requestHash,
      );
    }

    const replay = this.getInMemoryLedgerReplay<CallSessionTickResult>(
      callerUserId,
      normalizedIdempotencyKey,
      'call_tick',
      requestHash,
    );
    if (replay) {
      return replay;
    }

    const session = await this.getCallSessionForCaller(sessionId, callerUserId);
    if (session.status === 'ended') {
      const callerWallet = await this.getWalletSummary(callerUserId);
      return this.saveInMemoryLedgerResponse(
        callerUserId,
        normalizedIdempotencyKey,
        'call_tick',
        requestHash,
        {
          session,
          chargedCoins: 0,
          receiverCoins: 0,
          receiverUsd: 0,
          receiverSpark: 0,
          platformCoins: 0,
          callerCoinBalanceAfter: callerWallet.coinBalance,
          stoppedForInsufficientBalance:
            session.endReason === 'insufficient_balance',
        },
      );
    }

    const chargedCoins = Math.max(
      Math.ceil((session.rateCoinsPerMinute * normalizedSeconds) / 60),
      1,
    );

    const callerWalletBefore = await this.getWalletSummary(callerUserId);
    if (callerWalletBefore.coinBalance < chargedCoins) {
      const endedSession = await this.endCallSession(
        callerUserId,
        sessionId,
        'insufficient_balance',
      );
      return this.saveInMemoryLedgerResponse(
        callerUserId,
        normalizedIdempotencyKey,
        'call_tick',
        requestHash,
        {
          session: endedSession,
          chargedCoins: 0,
          receiverCoins: 0,
          receiverUsd: 0,
          receiverSpark: 0,
          platformCoins: 0,
          callerCoinBalanceAfter: callerWalletBefore.coinBalance,
          stoppedForInsufficientBalance: true,
        },
      );
    }

    const receiverCoins = Math.floor(
      (chargedCoins * session.receiverShareBps) / 10000,
    );
    const platformCoins = chargedCoins - receiverCoins;
    const receiverUsd = receiverCoins / session.coinsPerUsdReceiver;
    const receiverSpark = Math.floor(receiverUsd * session.sparkPerUsd);
    const now = new Date().toISOString();

    const callerCurrentBalance = this.walletBalances.get(callerUserId) ?? 1200;
    this.walletBalances.set(callerUserId, callerCurrentBalance - chargedCoins);

    if (session.receiverUserId) {
      const receiverCurrentRevenue =
        this.userRevenueUsd.get(session.receiverUserId) ?? 0;
      const receiverCurrentSpark =
        this.userSparkBalances.get(session.receiverUserId) ?? 0;
      this.userRevenueUsd.set(
        session.receiverUserId,
        receiverCurrentRevenue + receiverUsd,
      );
      this.userSparkBalances.set(
        session.receiverUserId,
        receiverCurrentSpark + receiverSpark,
      );
    }

    await this.writeWalletTransaction({
      userId: callerUserId,
      type: 'call_spend',
      coinsDelta: -chargedCoins,
      amountUsd: null,
      metadata: {
        sessionId,
        mode: session.mode,
        elapsedSeconds: normalizedSeconds,
        receiverUserId: session.receiverUserId,
        receiverCoins,
        platformCoins,
      },
      createdAt: now,
    });

    if (session.receiverUserId && receiverCoins > 0) {
      await this.writeWalletTransaction({
        userId: session.receiverUserId,
        type: 'call_earning_spark',
        coinsDelta: 0,
        amountUsd: receiverUsd,
        metadata: {
          sessionId,
          mode: session.mode,
          elapsedSeconds: normalizedSeconds,
          receiverCoinsEquivalent: receiverCoins,
          sparkEarned: receiverSpark,
        },
        createdAt: now,
      });
    }

    const updatedSession: CallSession = {
      ...session,
      totalBilledCoins: session.totalBilledCoins + chargedCoins,
      totalReceiverCoins: session.totalReceiverCoins + receiverCoins,
      totalReceiverUsd:
        Math.round((session.totalReceiverUsd + receiverUsd) * 10000) / 10000,
      totalReceiverSpark: session.totalReceiverSpark + receiverSpark,
      updatedAt: now,
    };

    await this.persistCallSession(updatedSession);
    const callerWalletAfter = await this.getWalletSummary(callerUserId);

    return this.saveInMemoryLedgerResponse(
      callerUserId,
      normalizedIdempotencyKey,
      'call_tick',
      requestHash,
      {
        session: updatedSession,
        chargedCoins,
        receiverCoins,
        receiverUsd,
        receiverSpark,
        platformCoins,
        callerCoinBalanceAfter: callerWalletAfter.coinBalance,
        stoppedForInsufficientBalance: false,
      },
    );
  }

  private async tickCallSessionInDatabase(
    callerUserId: string,
    sessionId: string,
    elapsedSeconds: number,
    idempotencyKey: string | null,
    requestHash: string,
  ): Promise<CallSessionTickResult> {
    return this.databaseService!.transaction(async (client) => {
      const replay = await this.getDatabaseLedgerReplay<CallSessionTickResult>(
        client,
        callerUserId,
        idempotencyKey,
        'call_tick',
        requestHash,
      );
      if (replay) {
        return replay;
      }

      await this.ensureWalletAndRevenueRows(callerUserId, client);

      const sessionResult = await client.query<CallSessionRow>(
        `
          SELECT *
          FROM call_sessions
          WHERE id = $1 AND caller_user_id = $2
          FOR UPDATE
        `,
        [sessionId, callerUserId],
      );

      if ((sessionResult.rowCount ?? 0) === 0) {
        throw new NotFoundException('Call session not found');
      }

      const session = this.mapCallSessionRow(sessionResult.rows[0]);
      const walletResult = await client.query<{ coin_balance: number }>(
        `
          SELECT coin_balance
          FROM wallets
          WHERE user_id = $1
          FOR UPDATE
        `,
        [callerUserId],
      );
      const callerCoinBalanceBefore =
        walletResult.rows[0]?.coin_balance ?? 0;

      if (session.status === 'ended') {
        return this.saveDatabaseLedgerResponse(
          client,
          callerUserId,
          idempotencyKey,
          {
            session,
            chargedCoins: 0,
            receiverCoins: 0,
            receiverUsd: 0,
            receiverSpark: 0,
            platformCoins: 0,
            callerCoinBalanceAfter: callerCoinBalanceBefore,
            stoppedForInsufficientBalance:
              session.endReason === 'insufficient_balance',
          },
        );
      }

      const chargedCoins = Math.max(
        Math.ceil((session.rateCoinsPerMinute * elapsedSeconds) / 60),
        1,
      );

      if (callerCoinBalanceBefore < chargedCoins) {
        const now = new Date().toISOString();
        const endedResult = await client.query<CallSessionRow>(
          `
            UPDATE call_sessions
            SET status = 'ended',
                end_reason = 'insufficient_balance',
                updated_at = $2,
                ended_at = $2
            WHERE id = $1
            RETURNING *
          `,
          [session.id, now],
        );

        return this.saveDatabaseLedgerResponse(
          client,
          callerUserId,
          idempotencyKey,
          {
            session: this.mapCallSessionRow(endedResult.rows[0]),
            chargedCoins: 0,
            receiverCoins: 0,
            receiverUsd: 0,
            receiverSpark: 0,
            platformCoins: 0,
            callerCoinBalanceAfter: callerCoinBalanceBefore,
            stoppedForInsufficientBalance: true,
          },
        );
      }

      if (session.receiverUserId) {
        await this.ensureWalletAndRevenueRows(session.receiverUserId, client);
      }

      const receiverCoins = Math.floor(
        (chargedCoins * session.receiverShareBps) / 10000,
      );
      const platformCoins = chargedCoins - receiverCoins;
      const receiverUsd = receiverCoins / session.coinsPerUsdReceiver;
      const receiverSpark = Math.floor(receiverUsd * session.sparkPerUsd);
      const now = new Date().toISOString();

      const walletUpdate = await client.query<{ coin_balance: number }>(
        `
          UPDATE wallets
          SET coin_balance = coin_balance - $2,
              updated_at = NOW()
          WHERE user_id = $1
          RETURNING coin_balance
        `,
        [callerUserId, chargedCoins],
      );

      if (session.receiverUserId) {
        await client.query(
          `
            UPDATE user_revenue
            SET revenue_usd = revenue_usd + $2,
                spark_balance = spark_balance + $3,
                updated_at = NOW()
            WHERE user_id = $1
          `,
          [session.receiverUserId, receiverUsd, receiverSpark],
        );
      }

      await this.writeWalletTransaction({
        userId: callerUserId,
        type: 'call_spend',
        coinsDelta: -chargedCoins,
        amountUsd: null,
        metadata: {
          sessionId,
          mode: session.mode,
          elapsedSeconds,
          receiverUserId: session.receiverUserId,
          receiverCoins,
          platformCoins,
        },
        createdAt: now,
        client,
      });

      if (session.receiverUserId && receiverCoins > 0) {
        await this.writeWalletTransaction({
          userId: session.receiverUserId,
          type: 'call_earning_spark',
          coinsDelta: 0,
          amountUsd: receiverUsd,
          metadata: {
            sessionId,
            mode: session.mode,
            elapsedSeconds,
            receiverCoinsEquivalent: receiverCoins,
            sparkEarned: receiverSpark,
          },
          createdAt: now,
          client,
        });
      }

      const updatedSessionResult = await client.query<CallSessionRow>(
        `
          UPDATE call_sessions
          SET total_billed_coins = total_billed_coins + $2,
              total_receiver_coins = total_receiver_coins + $3,
              total_receiver_usd = total_receiver_usd + $4,
              total_receiver_spark = total_receiver_spark + $5,
              updated_at = $6
          WHERE id = $1
          RETURNING *
        `,
        [
          session.id,
          chargedCoins,
          receiverCoins,
          receiverUsd,
          receiverSpark,
          now,
        ],
      );
      const updatedSession = this.mapCallSessionRow(
        updatedSessionResult.rows[0],
      );

      return this.saveDatabaseLedgerResponse(
        client,
        callerUserId,
        idempotencyKey,
        {
          session: updatedSession,
          chargedCoins,
          receiverCoins,
          receiverUsd,
          receiverSpark,
          platformCoins,
          callerCoinBalanceAfter:
            walletUpdate.rows[0]?.coin_balance ?? callerCoinBalanceBefore,
          stoppedForInsufficientBalance: false,
        },
      );
    });
  }

  async endCallSession(
    userId: string,
    sessionId: string,
    reason = 'caller_ended',
  ): Promise<CallSession> {
    const session = await this.getCallSessionForParticipant(sessionId, userId);
    if (session.status === 'ended') {
      return session;
    }

    const now = new Date().toISOString();
    const endedSession: CallSession = {
      ...session,
      status: 'ended',
      endReason: reason,
      endedAt: now,
      updatedAt: now,
    };

    await this.persistCallSession(endedSession);
    return endedSession;
  }

  /** Internal: end a session without user auth (for Cloud Functions). */
  async endCallSessionInternal(
    sessionId: string,
    reason = 'signal_deleted',
  ): Promise<CallSession> {
    const session = await this.getCallSessionById(sessionId);
    if (session.status === 'ended') {
      return session;
    }

    const now = new Date().toISOString();
    const endedSession: CallSession = {
      ...session,
      status: 'ended',
      endReason: reason,
      endedAt: now,
      updatedAt: now,
    };

    await this.persistCallSession(endedSession);
    return endedSession;
  }

  listGiftCatalog(): GiftCatalogItem[] {
    return [
      { id: 'rose', name: 'Rose', coinCost: 10 },
      { id: 'heart', name: 'Heart', coinCost: 50 },
      { id: 'rocket', name: 'Rocket', coinCost: 120 },
      { id: 'crown', name: 'Crown', coinCost: 300 },
      { id: 'lion', name: 'Lion', coinCost: 5000 },
    ];
  }

  async sendGiftInCall(
    senderUserId: string,
    input: {
      sessionId: string;
      giftId: string;
      quantity?: number;
      idempotencyKey?: string | null;
    },
  ): Promise<GiftSendResult> {
    const quantity = Number.isFinite(input.quantity)
      ? Math.min(Math.max(Math.trunc(input.quantity ?? 1), 1), 100)
      : 1;
    const normalizedIdempotencyKey = this.normalizeIdempotencyKey(
      input.idempotencyKey,
    );
    const requestHash = this.ledgerRequestHash({
      operationType: 'call_gift',
      sessionId: input.sessionId,
      giftId: input.giftId,
      quantity,
    });

    if (this.databaseService?.isEnabled()) {
      return this.sendGiftInCallInDatabase(
        senderUserId,
        { ...input, quantity },
        normalizedIdempotencyKey,
        requestHash,
      );
    }

    const replay = this.getInMemoryLedgerReplay<GiftSendResult>(
      senderUserId,
      normalizedIdempotencyKey,
      'call_gift',
      requestHash,
    );
    if (replay) {
      return replay;
    }

    const session = await this.getCallSessionById(input.sessionId);
    if (session.status !== 'live') {
      throw new BadRequestException('Gifts can only be sent during a live call');
    }

    if (session.callerUserId !== senderUserId) {
      throw new BadRequestException('Only the caller can send gifts during a call');
    }

    if (!session.receiverUserId) {
      throw new BadRequestException('Receiver is not available for gift delivery');
    }

    const gift = this.listGiftCatalog().find((item) => item.id === input.giftId);
    if (!gift) {
      throw new BadRequestException('Unknown gift id');
    }

    const totalGiftCoins = gift.coinCost * quantity;

    const senderWalletBefore = await this.getWalletSummary(senderUserId);
    if (senderWalletBefore.coinBalance < totalGiftCoins) {
      throw new BadRequestException('Insufficient coin balance for gift');
    }

    const receiverCoins = Math.floor(
      (totalGiftCoins * session.receiverShareBps) / 10000,
    );
    const platformCoins = totalGiftCoins - receiverCoins;
    const receiverUsd = receiverCoins / session.coinsPerUsdReceiver;
    const receiverSpark = Math.floor(receiverUsd * session.sparkPerUsd);
    const now = new Date().toISOString();

    const senderCurrent = this.walletBalances.get(senderUserId) ?? 1200;
    this.walletBalances.set(senderUserId, senderCurrent - totalGiftCoins);

    const receiverRevenue = this.userRevenueUsd.get(session.receiverUserId) ?? 0;
    const receiverSparkBalance =
      this.userSparkBalances.get(session.receiverUserId) ?? 0;
    this.userRevenueUsd.set(
      session.receiverUserId,
      receiverRevenue + receiverUsd,
    );
    this.userSparkBalances.set(
      session.receiverUserId,
      receiverSparkBalance + receiverSpark,
    );

    await this.writeWalletTransaction({
      userId: senderUserId,
      type: 'gift_spend',
      coinsDelta: -totalGiftCoins,
      amountUsd: null,
      metadata: {
        sessionId: session.id,
        mode: session.mode,
        giftId: gift.id,
        giftName: gift.name,
        quantity,
        receiverUserId: session.receiverUserId,
        receiverCoins,
        platformCoins,
      },
      createdAt: now,
    });

    await this.writeWalletTransaction({
      userId: session.receiverUserId,
      type: 'gift_earning_spark',
      coinsDelta: 0,
      amountUsd: receiverUsd,
      metadata: {
        sessionId: session.id,
        mode: session.mode,
        giftId: gift.id,
        giftName: gift.name,
        quantity,
        senderUserId,
        receiverCoinsEquivalent: receiverCoins,
        sparkEarned: receiverSpark,
      },
      createdAt: now,
    });

    const senderWalletAfter = await this.getWalletSummary(senderUserId);

    return this.saveInMemoryLedgerResponse(
      senderUserId,
      normalizedIdempotencyKey,
      'call_gift',
      requestHash,
      {
        sessionId: session.id,
        giftId: gift.id,
        giftName: gift.name,
        quantity,
        totalGiftCoins,
        receiverCoins,
        receiverUsd,
        receiverSpark,
        platformCoins,
        senderCoinBalanceAfter: senderWalletAfter.coinBalance,
      },
    );
  }

  async sendGiftInRoom(
    senderUserId: string,
    input: {
      roomId: string;
      giftId: string;
      quantity?: number;
      idempotencyKey?: string | null;
    },
  ): Promise<GiftSendResult> {
    const quantity = Number.isFinite(input.quantity)
      ? Math.min(Math.max(Math.trunc(input.quantity ?? 1), 1), 100)
      : 1;
    const normalizedIdempotencyKey = this.normalizeIdempotencyKey(
      input.idempotencyKey,
    );
    const requestHash = this.ledgerRequestHash({
      operationType: 'live_gift',
      roomId: input.roomId,
      giftId: input.giftId,
      quantity,
    });

    if (this.databaseService?.isEnabled()) {
      return this.sendGiftInRoomInDatabase(
        senderUserId,
        { ...input, quantity },
        normalizedIdempotencyKey,
        requestHash,
      );
    }

    const replay = this.getInMemoryLedgerReplay<GiftSendResult>(
      senderUserId,
      normalizedIdempotencyKey,
      'live_gift',
      requestHash,
    );
    if (replay) {
      return replay;
    }

    const hostUserId = await this.getRoomHostUserId(input.roomId);
    if (!hostUserId) {
      throw new NotFoundException('Room not found');
    }
    if (hostUserId === senderUserId) {
      throw new BadRequestException('Host cannot send gifts to themselves');
    }

    const gift = this.listGiftCatalog().find((item) => item.id === input.giftId);
    if (!gift) {
      throw new BadRequestException('Unknown gift id');
    }

    const totalGiftCoins = gift.coinCost * quantity;

    const senderWalletBefore = await this.getWalletSummary(senderUserId);
    if (senderWalletBefore.coinBalance < totalGiftCoins) {
      throw new BadRequestException('Insufficient coin balance for gift');
    }

    const config = this.getEconomyConfig();
    const receiverShareBps = config.receiverShareBps;
    const coinsPerUsdReceiver = config.coinsPerUsdReceiver;
    const sparkPerUsd = config.sparkPerUsd;

    const receiverCoins = Math.floor((totalGiftCoins * receiverShareBps) / 10000);
    const platformCoins = totalGiftCoins - receiverCoins;
    const receiverUsd = receiverCoins / coinsPerUsdReceiver;
    const receiverSpark = Math.floor(receiverUsd * sparkPerUsd);
    const now = new Date().toISOString();

    const senderCurrent = this.walletBalances.get(senderUserId) ?? 1200;
    this.walletBalances.set(senderUserId, senderCurrent - totalGiftCoins);

    const receiverRevenue = this.userRevenueUsd.get(hostUserId) ?? 0;
    const receiverSparkBalance = this.userSparkBalances.get(hostUserId) ?? 0;
    this.userRevenueUsd.set(hostUserId, receiverRevenue + receiverUsd);
    this.userSparkBalances.set(hostUserId, receiverSparkBalance + receiverSpark);

    await this.writeWalletTransaction({
      userId: senderUserId,
      type: 'gift_spend',
      coinsDelta: -totalGiftCoins,
      amountUsd: null,
      metadata: {
        roomId: input.roomId,
        mode: 'live_room',
        giftId: gift.id,
        giftName: gift.name,
        quantity,
        receiverUserId: hostUserId,
        receiverCoins,
        platformCoins,
      },
      createdAt: now,
    });

    await this.writeWalletTransaction({
      userId: hostUserId,
      type: 'gift_earning_spark',
      coinsDelta: 0,
      amountUsd: receiverUsd,
      metadata: {
        roomId: input.roomId,
        mode: 'live_room',
        giftId: gift.id,
        giftName: gift.name,
        quantity,
        senderUserId,
        receiverCoinsEquivalent: receiverCoins,
        sparkEarned: receiverSpark,
      },
      createdAt: now,
    });

    const senderWalletAfter = await this.getWalletSummary(senderUserId);

    return this.saveInMemoryLedgerResponse(
      senderUserId,
      normalizedIdempotencyKey,
      'live_gift',
      requestHash,
      {
        sessionId: input.roomId,
        giftId: gift.id,
        giftName: gift.name,
        quantity,
        totalGiftCoins,
        receiverCoins,
        receiverUsd,
        receiverSpark,
        platformCoins,
        senderCoinBalanceAfter: senderWalletAfter.coinBalance,
      },
    );
  }

  private async sendGiftInCallInDatabase(
    senderUserId: string,
    input: {
      sessionId: string;
      giftId: string;
      quantity?: number;
    },
    idempotencyKey: string | null,
    requestHash: string,
  ): Promise<GiftSendResult> {
    const gift = this.listGiftCatalog().find((item) => item.id === input.giftId);
    if (!gift) {
      throw new BadRequestException('Unknown gift id');
    }

    const quantity = Number.isFinite(input.quantity)
      ? Math.min(Math.max(Math.trunc(input.quantity ?? 1), 1), 100)
      : 1;
    const totalGiftCoins = gift.coinCost * quantity;

    return this.databaseService!.transaction(async (client) => {
      const replay = await this.getDatabaseLedgerReplay<GiftSendResult>(
        client,
        senderUserId,
        idempotencyKey,
        'call_gift',
        requestHash,
      );
      if (replay) {
        return replay;
      }

      const sessionResult = await client.query<CallSessionRow>(
        `
          SELECT *
          FROM call_sessions
          WHERE id = $1
          FOR UPDATE
        `,
        [input.sessionId],
      );
      if ((sessionResult.rowCount ?? 0) === 0) {
        throw new NotFoundException('Call session not found');
      }

      const session = this.mapCallSessionRow(sessionResult.rows[0]);
      if (session.status !== 'live') {
        throw new BadRequestException('Gifts can only be sent during a live call');
      }
      if (session.callerUserId !== senderUserId) {
        throw new BadRequestException('Only the caller can send gifts during a call');
      }
      if (!session.receiverUserId) {
        throw new BadRequestException('Receiver is not available for gift delivery');
      }

      await this.ensureWalletAndRevenueRows(senderUserId, client);
      await this.ensureWalletAndRevenueRows(session.receiverUserId, client);

      const walletResult = await client.query<{ coin_balance: number }>(
        `
          SELECT coin_balance
          FROM wallets
          WHERE user_id = $1
          FOR UPDATE
        `,
        [senderUserId],
      );
      const senderCoinBalanceBefore = walletResult.rows[0]?.coin_balance ?? 0;
      if (senderCoinBalanceBefore < totalGiftCoins) {
        throw new BadRequestException('Insufficient coin balance for gift');
      }

      const receiverCoins = Math.floor(
        (totalGiftCoins * session.receiverShareBps) / 10000,
      );
      const platformCoins = totalGiftCoins - receiverCoins;
      const receiverUsd = receiverCoins / session.coinsPerUsdReceiver;
      const receiverSpark = Math.floor(receiverUsd * session.sparkPerUsd);
      const now = new Date().toISOString();

      const walletUpdate = await client.query<{ coin_balance: number }>(
        `
          UPDATE wallets
          SET coin_balance = coin_balance - $2,
              updated_at = NOW()
          WHERE user_id = $1
          RETURNING coin_balance
        `,
        [senderUserId, totalGiftCoins],
      );

      await client.query(
        `
          UPDATE user_revenue
          SET revenue_usd = revenue_usd + $2,
              spark_balance = spark_balance + $3,
              updated_at = NOW()
          WHERE user_id = $1
        `,
        [session.receiverUserId, receiverUsd, receiverSpark],
      );

      await this.writeWalletTransaction({
        userId: senderUserId,
        type: 'gift_spend',
        coinsDelta: -totalGiftCoins,
        amountUsd: null,
        metadata: {
          sessionId: session.id,
          mode: session.mode,
          giftId: gift.id,
          giftName: gift.name,
          quantity,
          receiverUserId: session.receiverUserId,
          receiverCoins,
          platformCoins,
        },
        createdAt: now,
        client,
      });

      await this.writeWalletTransaction({
        userId: session.receiverUserId,
        type: 'gift_earning_spark',
        coinsDelta: 0,
        amountUsd: receiverUsd,
        metadata: {
          sessionId: session.id,
          mode: session.mode,
          giftId: gift.id,
          giftName: gift.name,
          quantity,
          senderUserId,
          receiverCoinsEquivalent: receiverCoins,
          sparkEarned: receiverSpark,
        },
        createdAt: now,
        client,
      });

      return this.saveDatabaseLedgerResponse(
        client,
        senderUserId,
        idempotencyKey,
        {
          sessionId: session.id,
          giftId: gift.id,
          giftName: gift.name,
          quantity,
          totalGiftCoins,
          receiverCoins,
          receiverUsd,
          receiverSpark,
          platformCoins,
          senderCoinBalanceAfter:
            walletUpdate.rows[0]?.coin_balance ?? senderCoinBalanceBefore,
        },
      );
    });
  }

  private async sendGiftInRoomInDatabase(
    senderUserId: string,
    input: {
      roomId: string;
      giftId: string;
      quantity?: number;
    },
    idempotencyKey: string | null,
    requestHash: string,
  ): Promise<GiftSendResult> {
    const gift = this.listGiftCatalog().find((item) => item.id === input.giftId);
    if (!gift) {
      throw new BadRequestException('Unknown gift id');
    }

    const quantity = Number.isFinite(input.quantity)
      ? Math.min(Math.max(Math.trunc(input.quantity ?? 1), 1), 100)
      : 1;
    const totalGiftCoins = gift.coinCost * quantity;
    const config = this.getEconomyConfig();

    return this.databaseService!.transaction(async (client) => {
      const replay = await this.getDatabaseLedgerReplay<GiftSendResult>(
        client,
        senderUserId,
        idempotencyKey,
        'live_gift',
        requestHash,
      );
      if (replay) {
        return replay;
      }

      const roomResult = await client.query<{ host_user_id: string }>(
        `
          SELECT host_user_id
          FROM rooms
          WHERE id = $1 AND status = 'live'
          FOR UPDATE
        `,
        [input.roomId],
      );
      const hostUserId = roomResult.rows[0]?.host_user_id;
      if (!hostUserId) {
        throw new NotFoundException('Room not found');
      }
      if (hostUserId === senderUserId) {
        throw new BadRequestException('Host cannot send gifts to themselves');
      }

      await this.ensureWalletAndRevenueRows(senderUserId, client);
      await this.ensureWalletAndRevenueRows(hostUserId, client);

      const walletResult = await client.query<{ coin_balance: number }>(
        `
          SELECT coin_balance
          FROM wallets
          WHERE user_id = $1
          FOR UPDATE
        `,
        [senderUserId],
      );
      const senderCoinBalanceBefore = walletResult.rows[0]?.coin_balance ?? 0;
      if (senderCoinBalanceBefore < totalGiftCoins) {
        throw new BadRequestException('Insufficient coin balance for gift');
      }

      const receiverCoins = Math.floor(
        (totalGiftCoins * config.receiverShareBps) / 10000,
      );
      const platformCoins = totalGiftCoins - receiverCoins;
      const receiverUsd = receiverCoins / config.coinsPerUsdReceiver;
      const receiverSpark = Math.floor(receiverUsd * config.sparkPerUsd);
      const now = new Date().toISOString();

      const walletUpdate = await client.query<{ coin_balance: number }>(
        `
          UPDATE wallets
          SET coin_balance = coin_balance - $2,
              updated_at = NOW()
          WHERE user_id = $1
          RETURNING coin_balance
        `,
        [senderUserId, totalGiftCoins],
      );

      await client.query(
        `
          UPDATE user_revenue
          SET revenue_usd = revenue_usd + $2,
              spark_balance = spark_balance + $3,
              updated_at = NOW()
          WHERE user_id = $1
        `,
        [hostUserId, receiverUsd, receiverSpark],
      );

      await this.writeWalletTransaction({
        userId: senderUserId,
        type: 'gift_spend',
        coinsDelta: -totalGiftCoins,
        amountUsd: null,
        metadata: {
          roomId: input.roomId,
          mode: 'live_room',
          giftId: gift.id,
          giftName: gift.name,
          quantity,
          receiverUserId: hostUserId,
          receiverCoins,
          platformCoins,
        },
        createdAt: now,
        client,
      });

      await this.writeWalletTransaction({
        userId: hostUserId,
        type: 'gift_earning_spark',
        coinsDelta: 0,
        amountUsd: receiverUsd,
        metadata: {
          roomId: input.roomId,
          mode: 'live_room',
          giftId: gift.id,
          giftName: gift.name,
          quantity,
          senderUserId,
          receiverCoinsEquivalent: receiverCoins,
          sparkEarned: receiverSpark,
        },
        createdAt: now,
        client,
      });

      return this.saveDatabaseLedgerResponse(
        client,
        senderUserId,
        idempotencyKey,
        {
          sessionId: input.roomId,
          giftId: gift.id,
          giftName: gift.name,
          quantity,
          totalGiftCoins,
          receiverCoins,
          receiverUsd,
          receiverSpark,
          platformCoins,
          senderCoinBalanceAfter:
            walletUpdate.rows[0]?.coin_balance ?? senderCoinBalanceBefore,
        },
      );
    });
  }

  async getLiveCallSessionParticipant(
    sessionId: string,
    userId: string,
  ): Promise<CallSessionParticipant> {
    const session = await this.getCallSessionById(sessionId);
    if (session.status !== 'live') {
      throw new BadRequestException('Call session is not live');
    }

    if (session.callerUserId === userId) {
      return { session, role: 'caller' };
    }

    if (session.receiverUserId === userId) {
      return { session, role: 'receiver' };
    }

    throw new BadRequestException(
      'User is not a participant in this call session',
    );
  }

  async ensureWalletAndRevenueRows(
    userId: string,
    client?: PoolClient,
  ): Promise<void> {
    if (!this.databaseService?.isEnabled()) {
      return;
    }

    const query = client
      ? client.query.bind(client)
      : this.databaseService.query.bind(this.databaseService);

    await query(
      `
        INSERT INTO wallets (user_id, coin_balance, level, updated_at)
        VALUES ($1, 1200, 4, NOW())
        ON CONFLICT (user_id) DO NOTHING
      `,
      [userId],
    );

    await query(
      `
        INSERT INTO user_revenue (user_id, revenue_usd, updated_at)
        VALUES ($1, 0, NOW())
        ON CONFLICT (user_id) DO NOTHING
      `,
      [userId],
    );

    await query(
      `
        UPDATE user_revenue
        SET spark_balance = COALESCE(spark_balance, 0),
            updated_at = NOW()
        WHERE user_id = $1
      `,
      [userId],
    );
  }

  private getDirectCallAllowedRates(): number[] {
    if (this.cachedCallRateTiers.length > 0) {
      return this.cachedCallRateTiers.map(t => t.coinsPerMinute);
    }
    return [2100, 3200, 4200, 5400, 6400, 8000, 27000];
  }

  private async getCallSessionForCaller(
    sessionId: string,
    callerUserId: string,
  ): Promise<CallSession> {
    if (this.databaseService?.isEnabled()) {
      const result = await this.databaseService.query<CallSessionRow>(
        `
          SELECT *
          FROM call_sessions
          WHERE id = $1 AND caller_user_id = $2
          LIMIT 1
        `,
        [sessionId, callerUserId],
      );

      if (result.rowCount === 0) {
        throw new NotFoundException('Call session not found');
      }

      return this.mapCallSessionRow(result.rows[0]);
    }

    const session = this.callSessions.get(sessionId);
    if (!session || session.callerUserId !== callerUserId) {
      throw new NotFoundException('Call session not found');
    }
    return session;
  }

  private async getCallSessionForParticipant(
    sessionId: string,
    userId: string,
  ): Promise<CallSession> {
    if (this.databaseService?.isEnabled()) {
      const result = await this.databaseService.query<CallSessionRow>(
        `
          SELECT *
          FROM call_sessions
          WHERE id = $1 AND (caller_user_id = $2 OR receiver_user_id = $2)
          LIMIT 1
        `,
        [sessionId, userId],
      );

      if (result.rowCount === 0) {
        throw new NotFoundException('Call session not found');
      }

      return this.mapCallSessionRow(result.rows[0]);
    }

    const session = this.callSessions.get(sessionId);
    if (
      !session ||
      (session.callerUserId !== userId && session.receiverUserId !== userId)
    ) {
      throw new NotFoundException('Call session not found');
    }
    return session;
  }

  private mapCallSessionRow(row: CallSessionRow): CallSession {
    return {
      id: row.id,
      callerUserId: row.caller_user_id,
      receiverUserId: row.receiver_user_id,
      mode: row.mode,
      rateCoinsPerMinute: row.rate_coins_per_minute,
      receiverShareBps: row.receiver_share_bps,
      coinsPerUsdReceiver: row.coins_per_usd_receiver,
      sparkPerUsd: row.spark_per_usd,
      totalBilledCoins: row.total_billed_coins,
      totalReceiverCoins: row.total_receiver_coins,
      totalReceiverUsd: Number.parseFloat(String(row.total_receiver_usd)) || 0,
      totalReceiverSpark: row.total_receiver_spark,
      status: row.status,
      endReason: row.end_reason,
      startedAt: new Date(row.started_at).toISOString(),
      updatedAt: new Date(row.updated_at).toISOString(),
      endedAt: row.ended_at ? new Date(row.ended_at).toISOString() : null,
    };
  }

  private async getCallSessionById(sessionId: string): Promise<CallSession> {
    if (this.databaseService?.isEnabled()) {
      const result = await this.databaseService.query<{
        id: string;
        caller_user_id: string;
        receiver_user_id: string | null;
        mode: 'direct' | 'random';
        rate_coins_per_minute: number;
        receiver_share_bps: number;
        coins_per_usd_receiver: number;
        spark_per_usd: number;
        total_billed_coins: number;
        total_receiver_coins: number;
        total_receiver_usd: string | number;
        total_receiver_spark: number;
        status: 'live' | 'ended';
        end_reason: string | null;
        started_at: string;
        updated_at: string;
        ended_at: string | null;
      }>(
        `
          SELECT
            id,
            caller_user_id,
            receiver_user_id,
            mode,
            rate_coins_per_minute,
            receiver_share_bps,
            coins_per_usd_receiver,
            spark_per_usd,
            total_billed_coins,
            total_receiver_coins,
            total_receiver_usd,
            total_receiver_spark,
            status,
            end_reason,
            started_at,
            updated_at,
            ended_at
          FROM call_sessions
          WHERE id = $1
          LIMIT 1
        `,
        [sessionId],
      );

      if (result.rowCount === 0) {
        throw new NotFoundException('Call session not found');
      }

      const row = result.rows[0];
      return {
        id: row.id,
        callerUserId: row.caller_user_id,
        receiverUserId: row.receiver_user_id,
        mode: row.mode,
        rateCoinsPerMinute: row.rate_coins_per_minute,
        receiverShareBps: row.receiver_share_bps,
        coinsPerUsdReceiver: row.coins_per_usd_receiver,
        sparkPerUsd: row.spark_per_usd,
        totalBilledCoins: row.total_billed_coins,
        totalReceiverCoins: row.total_receiver_coins,
        totalReceiverUsd: Number.parseFloat(String(row.total_receiver_usd)) || 0,
        totalReceiverSpark: row.total_receiver_spark,
        status: row.status,
        endReason: row.end_reason,
        startedAt: new Date(row.started_at).toISOString(),
        updatedAt: new Date(row.updated_at).toISOString(),
        endedAt: row.ended_at ? new Date(row.ended_at).toISOString() : null,
      };
    }

    const session = this.callSessions.get(sessionId);
    if (!session) {
      throw new NotFoundException('Call session not found');
    }

    return session;
  }

  private async hasLiveCallSessionForUser(userId: string): Promise<boolean> {
    if (this.databaseService?.isEnabled()) {
      const result = await this.databaseService.query(
        `
          SELECT id
          FROM call_sessions
          WHERE status = 'live'
            AND (caller_user_id = $1 OR receiver_user_id = $1)
            AND updated_at > NOW() - INTERVAL '2 minutes'
          LIMIT 1
        `,
        [userId],
      );

      return (result.rowCount ?? 0) > 0;
    }

    const staleThreshold = Date.now() - 2 * 60 * 1000;
    for (const session of this.callSessions.values()) {
      if (
        session.status === 'live' &&
        (session.callerUserId === userId || session.receiverUserId === userId) &&
        new Date(session.updatedAt).getTime() > staleThreshold
      ) {
        return true;
      }
    }

    return false;
  }

  private async persistCallSession(session: CallSession): Promise<void> {
    if (this.databaseService?.isEnabled()) {
      await this.databaseService.query(
        `
          UPDATE call_sessions
          SET total_billed_coins = $2,
              total_receiver_coins = $3,
              total_receiver_usd = $4,
              total_receiver_spark = $5,
              status = $6,
              end_reason = $7,
              updated_at = $8,
              ended_at = $9
          WHERE id = $1
        `,
        [
          session.id,
          session.totalBilledCoins,
          session.totalReceiverCoins,
          session.totalReceiverUsd,
          session.totalReceiverSpark,
          session.status,
          session.endReason,
          session.updatedAt,
          session.endedAt,
        ],
      );
      return;
    }

    this.callSessions.set(session.id, session);
  }

  private async writeWalletTransaction(input: {
    userId: string;
    type: string;
    coinsDelta: number;
    amountUsd: number | null;
    metadata: Record<string, unknown>;
    createdAt: string;
    client?: PoolClient;
  }): Promise<void> {
    if (!this.databaseService?.isEnabled()) {
      return;
    }

    const query = input.client
      ? input.client.query.bind(input.client)
      : this.databaseService.query.bind(this.databaseService);

    await query(
      `
        INSERT INTO wallet_transactions (
          id,
          user_id,
          type,
          coins_delta,
          amount_usd,
          metadata,
          created_at
        )
        VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7)
      `,
      [
        randomUUID(),
        input.userId,
        input.type,
        input.coinsDelta,
        input.amountUsd,
        JSON.stringify(input.metadata),
        input.createdAt,
      ],
    );
  }

  private toUserProfile(row: {
    id: string;
    public_id?: string | null;
    display_name: string;
    avatar_url: string | null;
    cover_url?: string | null;
    bio: string | null;
    gender?: string | null;
    birthday?: string | Date | null;
    country_code?: string | null;
    language?: string | null;
    is_admin?: boolean | null;
    is_host?: boolean | null;
    call_rate_coins_per_minute?: number | null;
    follower_count?: number | string | null;
    following_count?: number | string | null;
    onboarded_at?: string | Date | null;
    created_at: string;
  }): UserProfile {
    return {
      id: row.id,
      publicId: row.public_id ?? null,
      displayName: row.display_name,
      avatarUrl: row.avatar_url,
      coverUrl: row.cover_url ?? null,
      bio: row.bio,
      gender: row.gender ?? null,
      birthday: row.birthday ? new Date(row.birthday).toISOString().split('T')[0] : null,
      countryCode: row.country_code ?? null,
      language: row.language ?? null,
      isAdmin: row.is_admin ?? false,
      isHost: row.is_host ?? false,
      callRateCoinsPerMinute: row.call_rate_coins_per_minute ?? null,
      followerCount: Number(row.follower_count ?? 0),
      followingCount: Number(row.following_count ?? 0),
      onboardedAt: row.onboarded_at ? new Date(row.onboarded_at).toISOString() : null,
      createdAt: new Date(row.created_at).toISOString(),
    };
  }

  private toRoom(row: {
    id: string;
    host_user_id: string;
    title: string;
    audience_count: number;
    status: 'live';
    created_at: string;
  }): Room {
    return {
      id: row.id,
      hostUserId: row.host_user_id,
      title: row.title,
      audienceCount: row.audience_count,
      status: row.status,
      createdAt: new Date(row.created_at).toISOString(),
    };
  }

  private toCallSession(row: {
    id: string;
    caller_user_id: string;
    receiver_user_id: string | null;
    mode: 'direct' | 'random';
    rate_coins_per_minute: number;
    receiver_share_bps: number;
    coins_per_usd_receiver: number;
    spark_per_usd: number;
    total_billed_coins: number;
    total_receiver_coins: number;
    total_receiver_usd: string | number;
    total_receiver_spark: number;
    status: 'live' | 'ended';
    end_reason: string | null;
    started_at: string;
    updated_at: string;
    ended_at: string | null;
  }): CallSession {
    return {
      id: row.id,
      callerUserId: row.caller_user_id,
      receiverUserId: row.receiver_user_id,
      mode: row.mode,
      rateCoinsPerMinute: row.rate_coins_per_minute,
      receiverShareBps: row.receiver_share_bps,
      coinsPerUsdReceiver: row.coins_per_usd_receiver,
      sparkPerUsd: row.spark_per_usd,
      totalBilledCoins: row.total_billed_coins,
      totalReceiverCoins: row.total_receiver_coins,
      totalReceiverUsd: Number.parseFloat(String(row.total_receiver_usd)) || 0,
      totalReceiverSpark: row.total_receiver_spark,
      status: row.status,
      endReason: row.end_reason,
      startedAt: new Date(row.started_at).toISOString(),
      updatedAt: new Date(row.updated_at).toISOString(),
      endedAt: row.ended_at ? new Date(row.ended_at).toISOString() : null,
    };
  }

  private getGoogleAudiences(): string[] {
    const rawAudiences = process.env.GOOGLE_CLIENT_IDS ?? process.env.GOOGLE_CLIENT_ID ?? '';
    const audiences = rawAudiences
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean);

    if (audiences.length === 0) {
      throw new UnauthorizedException('Google OAuth audience is not configured');
    }

    return audiences;
  }

  private signJwt(userId: string): string {
    const secret = this.getJwtSecret();

    return sign(
      {
        sub: userId,
        jti: randomUUID(),
      },
      secret,
      {
        expiresIn: '7d',
        issuer: 'zephyr-api',
        audience: 'zephyr-mobile',
      },
    );
  }

  private verifyJwt(token: string): JwtPayload {
    try {
      const payload = verify(token, this.getJwtSecret(), {
        issuer: 'zephyr-api',
        audience: 'zephyr-mobile',
      });

      if (typeof payload === 'string' || !payload.sub) {
        throw new UnauthorizedException('Invalid token payload');
      }

      return payload;
    } catch {
      throw new UnauthorizedException('Invalid or expired token');
    }
  }

  private getJwtSecret(): string {
    const secret = process.env.JWT_SECRET;

    if (!secret) {
      if (process.env.NODE_ENV === 'production') {
        throw new UnauthorizedException('JWT secret is not configured');
      }

      this.logger.warn('JWT_SECRET not set. Using development fallback secret.');
      return 'zephyr-dev-secret-change-me';
    }

    return secret;
  }

  private async verifyAppleIdToken(idToken: string): Promise<JWTPayload & { email?: string }> {
    const appleClientId = process.env.APPLE_CLIENT_ID;
    if (!appleClientId) {
      throw new BadRequestException('APPLE_CLIENT_ID is not configured');
    }

    const jwks = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

    try {
      const { payload } = await jwtVerify(idToken, jwks, {
        issuer: 'https://appleid.apple.com',
        audience: appleClientId,
      });

      return payload as JWTPayload & { email?: string };
    } catch {
      throw new UnauthorizedException('Invalid Apple ID token');
    }
  }

  // ── Presence ────────────────────────────────────────────────────────────────

  async setUserStatus(userId: string, status: string): Promise<void> {
    if (this.databaseService?.isEnabled()) {
      await this.databaseService.query(
        `UPDATE users SET status = $1 WHERE id = $2`,
        [status, userId],
      );
    }
  }

  async heartbeat(userId: string): Promise<void> {
    if (this.databaseService?.isEnabled()) {
      await this.databaseService.query(
        `UPDATE users SET last_seen_at = NOW() WHERE id = $1`,
        [userId],
      );
    }
  }

  async syncPresence(
    userId: string,
    status: string,
    options: PresenceSyncOptions = {},
  ): Promise<void> {
    const presence = normalizePresenceSync(status, options);
    if (this.databaseService?.isEnabled()) {
      await this.databaseService.query(
        `UPDATE users
         SET status = $1,
             presence_connection = $2,
             presence_activity = $3,
             presence_availability = $4,
             can_direct_call = $5,
             can_random_call = $6,
             presence_updated_at = COALESCE($7::timestamptz, NOW()),
             last_seen_at = COALESCE($7::timestamptz, NOW())
         WHERE id = $8`,
        [
          presence.status,
          presence.connection,
          presence.activity,
          presence.availability,
          presence.directCall,
          presence.randomCall,
          presence.updatedAtIso,
          userId,
        ],
      );
    }
  }

}
