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
  startedAt: string;
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
    const ticket = await this.googleClient.verifyIdToken({
      idToken,
      audience: this.getGoogleAudiences(),
    });

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
        display_name: string;
        avatar_url: string | null;
        bio: string | null;
        created_at: string;
      }>(
        `
          SELECT id, display_name, avatar_url, bio, created_at
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
        await this.databaseService.query(
          `
            UPDATE users
            SET display_name = $2, email = $3, avatar_url = $4
            WHERE id = $1
          `,
          [userId, displayName, email, avatarUrl],
        );
      }

      const accessToken = this.signJwt(userId);
      const expiresAt = Date.now() + 1000 * 60 * 60 * 24 * 7;

      const userResult = await this.databaseService.query<{
        id: string;
        display_name: string;
        avatar_url: string | null;
        bio: string | null;
        created_at: string;
      }>(
        `
          SELECT id, display_name, avatar_url, bio, created_at
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
        await this.databaseService.query(
          `
            UPDATE users
            SET display_name = $2, email = COALESCE($3, email)
            WHERE id = $1
          `,
          [userId, displayName, email],
        );
      }

      const accessToken = this.signJwt(userId);
      const expiresAt = Date.now() + 1000 * 60 * 60 * 24 * 7;

      const userResult = await this.databaseService.query<{
        id: string;
        display_name: string;
        avatar_url: string | null;
        bio: string | null;
        created_at: string;
      }>(
        `
          SELECT id, display_name, avatar_url, bio, created_at
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
        created_at: string;
      }>(
        `
          SELECT u.id, u.display_name, u.avatar_url, u.bio, u.created_at
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
    updates: { displayName?: string; avatarUrl?: string | null; bio?: string | null },
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
        created_at: string;
      }>(
        `
          SELECT id, display_name, avatar_url, bio, created_at
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

      const updatedResult = await this.databaseService.query<{
        id: string;
        display_name: string;
        avatar_url: string | null;
        bio: string | null;
        created_at: string;
      }>(
        `
          UPDATE users
          SET display_name = $2, avatar_url = $3, bio = $4
          WHERE id = $1
          RETURNING id, display_name, avatar_url, bio, created_at
        `,
        [userId, nextDisplayName, nextAvatarUrl, nextBio],
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
          WHERE id = $1
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

  private toUserProfile(row: {
    id: string;
    display_name: string;
    avatar_url: string | null;
    bio: string | null;
    created_at: string;
  }): UserProfile {
    return {
      id: row.id,
      displayName: row.display_name,
      avatarUrl: row.avatar_url,
      bio: row.bio,
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