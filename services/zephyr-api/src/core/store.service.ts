import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
  UnauthorizedException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { OAuth2Client } from 'google-auth-library';
import { JWTPayload, createRemoteJWKSet, jwtVerify } from 'jose';
import { JwtPayload, sign, verify } from 'jsonwebtoken';
import { DatabaseService } from './database.service';

export interface UserProfile {
  id: string;
  displayName: string;
  avatarUrl: string | null;
  bio: string | null;
  gender: string | null;
  birthday: string | null;
  countryCode: string | null;
  language: string | null;
  isAdmin: boolean;
  callRateCoinsPerMinute: number | null;
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
  roomId: string;
  title: string;
  audienceCount: number;
  hostUserId: string;
  hostDisplayName: string;
  hostAvatarUrl: string | null;
  hostCountryCode: string;
  hostLanguage: string;
  hostStatus: string;
  startedAt: string;
}

export interface Message {
  id: string;
  senderId: string;
  receiverId: string;
  body: string;
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

interface Session {
  token: string;
  userId: string;
  expiresAt: number;
}

@Injectable()
export class StoreService {
  constructor(@Optional() private readonly databaseService?: DatabaseService) {}

  private readonly logger = new Logger(StoreService.name);
  private readonly googleClient = new OAuth2Client();

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
      displayName: displayName?.trim() || `zephyr_${userId.slice(0, 8)}`,
      avatarUrl: null,
      bio: null,
      gender: null,
      birthday: null,
      countryCode: null,
      language: null,
      isAdmin: false,
      callRateCoinsPerMinute: null,
      createdAt: now,
    };

    if (this.databaseService?.isEnabled()) {
      await this.databaseService.query(
        `
          INSERT INTO users (id, display_name, avatar_url, bio, created_at)
          VALUES ($1, $2, $3, $4, $5)
        `,
        [user.id, user.displayName, user.avatarUrl, user.bio, user.createdAt],
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
              created_at
            )
            VALUES ($1, $2, $3, 'google', $4, $5, $6, $7)
          `,
          [
            userId,
            displayName,
            email,
            googleSubject,
            avatarUrl,
            null,
            new Date().toISOString(),
          ],
        );
      } else {
        // On re-login, only sync email and avatarUrl — leave display_name (nickname) intact
        // so users can customise it without it being reset by Google on every login.
        await this.databaseService.query(
          `
            UPDATE users
            SET email = $2, avatar_url = $3
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
        is_admin: boolean;
        call_rate_coins_per_minute: number | null;
        created_at: string;
      }>(
        `
          SELECT id, display_name, avatar_url, bio, gender, birthday,
                 country_code, language, is_admin, call_rate_coins_per_minute, created_at
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
      displayName,
      avatarUrl,
      bio: null,
      gender: null,
      birthday: null,
      countryCode: null,
      language: null,
      isAdmin: false,
      callRateCoinsPerMinute: null,
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
              created_at
            )
            VALUES ($1, $2, $3, 'apple', $4, $5, $6, $7)
          `,
          [
            userId,
            displayName,
            email,
            appleSubject,
            null,
            null,
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
        is_admin: boolean;
        call_rate_coins_per_minute: number | null;
        created_at: string;
      }>(
        `
          SELECT id, display_name, avatar_url, bio, gender, birthday,
                 country_code, language, is_admin, call_rate_coins_per_minute, created_at
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
      displayName,
      avatarUrl: null,
      bio: null,
      gender: null,
      birthday: null,
      countryCode: null,
      language: null,
      isAdmin: false,
      callRateCoinsPerMinute: null,
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
        display_name: string;
        avatar_url: string | null;
        bio: string | null;
        gender: string | null;
        birthday: string | null;
        country_code: string | null;
        language: string | null;
        is_admin: boolean;
        call_rate_coins_per_minute: number | null;
        created_at: string;
      }>(
        `
          SELECT u.id, u.display_name, u.avatar_url, u.bio, u.gender, u.birthday,
                 u.country_code, u.language, u.is_admin, u.call_rate_coins_per_minute, u.created_at
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
      bio?: string | null;
      gender?: string | null;
      birthday?: string | null;
      countryCode?: string | null;
      language?: string | null;
      callRateCoinsPerMinute?: number | null;
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
        bio: string | null;
        gender: string | null;
        birthday: string | null;
        country_code: string | null;
        language: string | null;
        is_admin: boolean;
        call_rate_coins_per_minute: number | null;
        created_at: string;
      }>(
        `
          SELECT id, display_name, avatar_url, bio, gender, birthday,
                 country_code, language, is_admin, call_rate_coins_per_minute, created_at
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
      const nextBio = updates.bio !== undefined ? updates.bio : currentUser.bio;
      const nextGender = updates.gender !== undefined ? updates.gender : currentUser.gender;
      const nextBirthday = updates.birthday !== undefined ? updates.birthday : currentUser.birthday;
      const nextCountryCode = updates.countryCode !== undefined ? updates.countryCode : currentUser.countryCode;
      const nextLanguage = updates.language !== undefined ? updates.language : currentUser.language;
      const nextCallRate = updates.callRateCoinsPerMinute !== undefined ? updates.callRateCoinsPerMinute : currentUser.callRateCoinsPerMinute;

      const updatedResult = await this.databaseService.query<{
        id: string;
        display_name: string;
        avatar_url: string | null;
        bio: string | null;
        gender: string | null;
        birthday: string | null;
        country_code: string | null;
        language: string | null;
        is_admin: boolean;
        call_rate_coins_per_minute: number | null;
        created_at: string;
      }>(
        `
          UPDATE users
          SET display_name = $2, avatar_url = $3, bio = $4,
              gender = $5, birthday = $6, country_code = $7, language = $8,
              call_rate_coins_per_minute = $9
          WHERE id = $1
          RETURNING id, display_name, avatar_url, bio, gender, birthday,
                    country_code, language, is_admin, call_rate_coins_per_minute, created_at
        `,
        [userId, nextDisplayName, nextAvatarUrl, nextBio, nextGender, nextBirthday, nextCountryCode, nextLanguage, nextCallRate],
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
      bio: updates.bio !== undefined ? updates.bio : user.bio,
      gender: updates.gender !== undefined ? updates.gender : user.gender,
      birthday: updates.birthday !== undefined ? updates.birthday : user.birthday,
      countryCode: updates.countryCode !== undefined ? updates.countryCode : user.countryCode,
      language: updates.language !== undefined ? updates.language : user.language,
      callRateCoinsPerMinute: updates.callRateCoinsPerMinute !== undefined ? updates.callRateCoinsPerMinute : user.callRateCoinsPerMinute,
    };

    this.users.set(userId, nextUser);
    return nextUser;
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

  async listLiveFeed(limit = 20): Promise<LiveFeedCard[]> {
    const normalizedLimit = Number.isFinite(limit)
      ? Math.min(Math.max(Math.trunc(limit), 1), 50)
      : 20;

    if (this.databaseService?.isEnabled()) {
      const result = await this.databaseService.query<{
        room_id: string;
        title: string;
        audience_count: number;
        host_user_id: string;
        host_display_name: string;
        host_avatar_url: string | null;
        host_country_code: string | null;
        host_language: string | null;
        started_at: string;
      }>(
        `
          SELECT
            rooms.id AS room_id,
            rooms.title,
            rooms.audience_count,
            rooms.host_user_id,
            users.display_name AS host_display_name,
            users.avatar_url AS host_avatar_url,
            users.country_code AS host_country_code,
            users.language AS host_language,
            rooms.created_at AS started_at
          FROM rooms
          INNER JOIN users ON users.id = rooms.host_user_id
          WHERE rooms.status = 'live'
          ORDER BY rooms.audience_count DESC, rooms.created_at DESC
          LIMIT $1
        `,
        [normalizedLimit],
      );

      return result.rows.map((row) => ({
        roomId: row.room_id,
        title: row.title,
        audienceCount: row.audience_count,
        hostUserId: row.host_user_id,
        hostDisplayName: row.host_display_name,
        hostAvatarUrl: row.host_avatar_url,
        hostCountryCode: row.host_country_code ?? 'PH',
        hostLanguage: row.host_language ?? 'English',
        hostStatus: 'live',
        startedAt: new Date(row.started_at).toISOString(),
      }));
    }

    const rooms = [...this.rooms.values()]
      .filter((room) => room.status === 'live')
      .sort((firstRoom, secondRoom) => {
        if (secondRoom.audienceCount !== firstRoom.audienceCount) {
          return secondRoom.audienceCount - firstRoom.audienceCount;
        }
        return secondRoom.createdAt.localeCompare(firstRoom.createdAt);
      })
      .slice(0, normalizedLimit);

    return rooms.map((room) => {
      const hostUser = this.users.get(room.hostUserId);
      return {
        roomId: room.id,
        title: room.title,
        audienceCount: room.audienceCount,
        hostUserId: room.hostUserId,
        hostDisplayName: hostUser?.displayName ?? `host_${room.hostUserId.slice(0, 8)}`,
        hostAvatarUrl: hostUser?.avatarUrl ?? null,
        hostCountryCode: hostUser?.countryCode ?? 'PH',
        hostLanguage: hostUser?.language ?? 'English',
        hostStatus: 'live',
        startedAt: room.createdAt,
      };
    });
  }

  async createRoom(hostUserId: string, title: string): Promise<Room> {
    if (!title || title.trim().length < 3) {
      throw new BadRequestException('title must be at least 3 characters');
    }

    const room: Room = {
      id: randomUUID(),
      hostUserId,
      title: title.trim(),
      audienceCount: 1,
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

  async joinRoom(roomId: string): Promise<Room> {
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
          UPDATE rooms
          SET audience_count = audience_count + 1
          WHERE id = $1 AND status = 'live'
          RETURNING id, host_user_id, title, audience_count, status, created_at
        `,
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
      const result = await this.databaseService.query(
        `
          DELETE FROM rooms
          WHERE id = $1 AND host_user_id = $2 AND status = 'live'
        `,
        [roomId, hostUserId],
      );

      if (result.rowCount === 0) {
        throw new NotFoundException('Room not found');
      }

      return;
    }

    const room = this.rooms.get(roomId);
    if (!room || room.hostUserId !== hostUserId || room.status !== 'live') {
      throw new NotFoundException('Room not found');
    }

    this.rooms.delete(roomId);
  }

  async leaveRoom(roomId: string): Promise<void> {
    if (this.databaseService?.isEnabled()) {
      await this.databaseService.query(
        `
          UPDATE rooms
          SET audience_count = GREATEST(audience_count - 1, 0)
          WHERE id = $1 AND status = 'live'
        `,
        [roomId],
      );
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
        is_admin: boolean;
        call_rate_coins_per_minute: number | null;
        created_at: string;
      }>(
        `
          SELECT id, display_name, avatar_url, bio, gender, birthday,
                 country_code, language, is_admin, call_rate_coins_per_minute, created_at
          FROM users WHERE id = $1 LIMIT 1
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

  // ── Messaging ────────────────────────────────────────────────────────────────

  private readonly inMemoryMessages = new Map<string, Message>();

  async sendMessage(senderId: string, receiverId: string, body: string): Promise<Message> {
    if (!body?.trim()) {
      throw new BadRequestException('Message body cannot be empty');
    }
    if (body.trim().length > 2000) {
      throw new BadRequestException('Message body too long (max 2000 chars)');
    }

    const msg: Message = {
      id: randomUUID(),
      senderId,
      receiverId,
      body: body.trim(),
      readAt: null,
      createdAt: new Date().toISOString(),
    };

    if (this.databaseService?.isEnabled()) {
      await this.databaseService.query(
        `
          INSERT INTO messages (id, sender_id, receiver_id, body, created_at)
          VALUES ($1, $2, $3, $4, $5)
        `,
        [msg.id, msg.senderId, msg.receiverId, msg.body, msg.createdAt],
      );
      return msg;
    }

    this.inMemoryMessages.set(msg.id, msg);
    return msg;
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
      }>(
        `
          SELECT
            other_users.id AS other_id,
            other_users.display_name,
            other_users.avatar_url,
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
        });
      }
    }

    return convos.sort((a, b) => b.lastMessageAt.localeCompare(a.lastMessageAt));
  }

  async getThread(userId: string, partnerId: string, limit = 50): Promise<Message[]> {
    const normalizedLimit = Math.min(Math.max(Math.trunc(limit), 1), 200);

    if (this.databaseService?.isEnabled()) {
      const result = await this.databaseService.query<{
        id: string;
        sender_id: string;
        receiver_id: string;
        body: string;
        read_at: string | null;
        created_at: string;
      }>(
        `
          SELECT id, sender_id, receiver_id, body, read_at, created_at
          FROM messages
          WHERE (sender_id = $1 AND receiver_id = $2)
             OR (sender_id = $2 AND receiver_id = $1)
          ORDER BY created_at DESC
          LIMIT $3
        `,
        [userId, partnerId, normalizedLimit],
      );

      return result.rows.map((row) => ({
        id: row.id,
        senderId: row.sender_id,
        receiverId: row.receiver_id,
        body: row.body,
        readAt: row.read_at ? new Date(row.read_at).toISOString() : null,
        createdAt: new Date(row.created_at).toISOString(),
      }));
    }

    return [...this.inMemoryMessages.values()]
      .filter(
        (m) =>
          (m.senderId === userId && m.receiverId === partnerId) ||
          (m.senderId === partnerId && m.receiverId === userId),
      )
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
      .slice(0, normalizedLimit);
  }

  async markMessageRead(messageId: string, userId: string): Promise<Message> {
    if (this.databaseService?.isEnabled()) {
      const result = await this.databaseService.query<{
        id: string;
        sender_id: string;
        receiver_id: string;
        body: string;
        read_at: string | null;
        created_at: string;
      }>(
        `
          UPDATE messages
          SET read_at = NOW()
          WHERE id = $1 AND receiver_id = $2 AND read_at IS NULL
          RETURNING id, sender_id, receiver_id, body, read_at, created_at
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
        readAt: row.read_at ? new Date(row.read_at).toISOString() : null,
        createdAt: new Date(row.created_at).toISOString(),
      };
    }

    const msg = this.inMemoryMessages.get(messageId);
    if (!msg || msg.receiverId !== userId) {
      throw new NotFoundException('Message not found');
    }
    const updated = { ...msg, readAt: new Date().toISOString() };
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
      await this.ensureWalletAndRevenueRows(userId);

      await this.databaseService.query(
        `
          UPDATE wallets
          SET coin_balance = coin_balance + $2,
              updated_at = NOW()
          WHERE user_id = $1
        `,
        [userId, selectedPack.coins],
      );

      await this.databaseService.query(
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
          VALUES ($1, $2, 'purchase', $3, $4, $5::jsonb, NOW())
        `,
        [
          randomUUID(),
          userId,
          selectedPack.coins,
          selectedPack.priceUsd,
          JSON.stringify({ packId: selectedPack.id, label: selectedPack.label }),
        ],
      );

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
      const receiverBusy = await this.hasLiveCallSessionForUser(receiverUserId);
      if (receiverBusy) {
        throw new BadRequestException('Receiver is busy in another live call');
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
  ): Promise<CallSessionTickResult> {
    const session = await this.getCallSessionForCaller(sessionId, callerUserId);
    if (session.status === 'ended') {
      const callerWallet = await this.getWalletSummary(callerUserId);
      return {
        session,
        chargedCoins: 0,
        receiverCoins: 0,
        receiverUsd: 0,
        receiverSpark: 0,
        platformCoins: 0,
        callerCoinBalanceAfter: callerWallet.coinBalance,
        stoppedForInsufficientBalance: session.endReason === 'insufficient_balance',
      };
    }

    const normalizedSeconds = Number.isFinite(elapsedSeconds)
      ? Math.min(Math.max(Math.trunc(elapsedSeconds), 1), 300)
      : 60;
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
      return {
        session: endedSession,
        chargedCoins: 0,
        receiverCoins: 0,
        receiverUsd: 0,
        receiverSpark: 0,
        platformCoins: 0,
        callerCoinBalanceAfter: callerWalletBefore.coinBalance,
        stoppedForInsufficientBalance: true,
      };
    }

    const receiverCoins = Math.floor(
      (chargedCoins * session.receiverShareBps) / 10000,
    );
    const platformCoins = chargedCoins - receiverCoins;
    const receiverUsd = receiverCoins / session.coinsPerUsdReceiver;
    const receiverSpark = Math.floor(receiverUsd * session.sparkPerUsd);
    const now = new Date().toISOString();

    if (this.databaseService?.isEnabled()) {
      await this.databaseService.query(
        `
          UPDATE wallets
          SET coin_balance = coin_balance - $2,
              updated_at = NOW()
          WHERE user_id = $1
        `,
        [callerUserId, chargedCoins],
      );

      if (session.receiverUserId) {
        await this.databaseService.query(
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
    } else {
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

    return {
      session: updatedSession,
      chargedCoins,
      receiverCoins,
      receiverUsd,
      receiverSpark,
      platformCoins,
      callerCoinBalanceAfter: callerWalletAfter.coinBalance,
      stoppedForInsufficientBalance: false,
    };
  }

  async endCallSession(
    callerUserId: string,
    sessionId: string,
    reason = 'caller_ended',
  ): Promise<CallSession> {
    const session = await this.getCallSessionForCaller(sessionId, callerUserId);
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
    },
  ): Promise<GiftSendResult> {
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

    const quantity = Number.isFinite(input.quantity)
      ? Math.min(Math.max(Math.trunc(input.quantity ?? 1), 1), 100)
      : 1;
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

    if (this.databaseService?.isEnabled()) {
      await this.ensureWalletAndRevenueRows(senderUserId);
      await this.ensureWalletAndRevenueRows(session.receiverUserId);

      await this.databaseService.query(
        `
          UPDATE wallets
          SET coin_balance = coin_balance - $2,
              updated_at = NOW()
          WHERE user_id = $1
        `,
        [senderUserId, totalGiftCoins],
      );

      await this.databaseService.query(
        `
          UPDATE user_revenue
          SET revenue_usd = revenue_usd + $2,
              spark_balance = spark_balance + $3,
              updated_at = NOW()
          WHERE user_id = $1
        `,
        [session.receiverUserId, receiverUsd, receiverSpark],
      );
    } else {
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
    }

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

    return {
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
    };
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

  private async ensureWalletAndRevenueRows(userId: string): Promise<void> {
    if (!this.databaseService?.isEnabled()) {
      return;
    }

    await this.databaseService.query(
      `
        INSERT INTO wallets (user_id, coin_balance, level, updated_at)
        VALUES ($1, 1200, 4, NOW())
        ON CONFLICT (user_id) DO NOTHING
      `,
      [userId],
    );

    await this.databaseService.query(
      `
        INSERT INTO user_revenue (user_id, revenue_usd, updated_at)
        VALUES ($1, 0, NOW())
        ON CONFLICT (user_id) DO NOTHING
      `,
      [userId],
    );

    await this.databaseService.query(
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
    const rawRates =
      process.env.DIRECT_CALL_ALLOWED_RATES_COINS_PER_MINUTE ??
      '2100,3200,4200,5400,6400,8000,27000';

    const parsed = rawRates
      .split(',')
      .map((value) => Number.parseInt(value.trim(), 10))
      .filter((value) => Number.isFinite(value) && value > 0);

    const uniqueRates = [...new Set(parsed)];
    if (uniqueRates.length > 0) {
      return uniqueRates;
    }

    this.logger.warn(
      'Invalid DIRECT_CALL_ALLOWED_RATES_COINS_PER_MINUTE. Using default rates 2100,3200,4200,5400,6400,8000,27000.',
    );
    return [2100, 3200, 4200, 5400, 6400, 8000, 27000];
  }

  private async getCallSessionForCaller(
    sessionId: string,
    callerUserId: string,
  ): Promise<CallSession> {
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
          WHERE id = $1 AND caller_user_id = $2
          LIMIT 1
        `,
        [sessionId, callerUserId],
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
    if (!session || session.callerUserId !== callerUserId) {
      throw new NotFoundException('Call session not found');
    }
    return session;
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
          LIMIT 1
        `,
        [userId],
      );

      return (result.rowCount ?? 0) > 0;
    }

    for (const session of this.callSessions.values()) {
      if (
        session.status === 'live' &&
        (session.callerUserId === userId || session.receiverUserId === userId)
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
  }): Promise<void> {
    if (!this.databaseService?.isEnabled()) {
      return;
    }

    await this.databaseService.query(
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
    display_name: string;
    avatar_url: string | null;
    bio: string | null;
    gender?: string | null;
    birthday?: string | Date | null;
    country_code?: string | null;
    language?: string | null;
    is_admin?: boolean | null;
    call_rate_coins_per_minute?: number | null;
    created_at: string;
  }): UserProfile {
    return {
      id: row.id,
      displayName: row.display_name,
      avatarUrl: row.avatar_url,
      bio: row.bio,
      gender: row.gender ?? null,
      birthday: row.birthday ? new Date(row.birthday).toISOString().split('T')[0] : null,
      countryCode: row.country_code ?? null,
      language: row.language ?? null,
      isAdmin: row.is_admin ?? false,
      callRateCoinsPerMinute: row.call_rate_coins_per_minute ?? null,
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

}