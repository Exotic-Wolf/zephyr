import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import type { PoolClient } from 'pg';
import { DatabaseService } from './database.service';
import { admin, ensureFirebaseAdminInitialized } from './firebase-admin';

const PROVIDER = 'zephyr-demo';
const SUBJECT_PREFIX = 'for-you-host-';
const DEFAULT_COUNT = 24;
const DEFAULT_INTERVALS = [15, 30, 60, 120];

interface DemoHost {
  id: string;
  display_name: string;
  country_code: string | null;
  language: string | null;
  cover_url: string | null;
}

interface DemoState {
  key: string;
  weight: number;
  status: 'online' | 'away' | 'live' | 'premium_live' | 'busy' | 'offline';
  activity:
    | 'idle'
    | 'away'
    | 'free_live_host'
    | 'premium_live_host'
    | 'direct_call'
    | 'random_call';
  availability: 'available' | 'busy' | 'unavailable';
  connection: 'online' | 'offline';
  directCall: boolean;
  randomCall: boolean;
  interruptible: boolean;
  roomMode: 'free_live' | 'premium_live' | null;
  hasRoom: boolean;
}

interface StartOptions {
  count?: number;
  intervals?: number[];
  routeable?: boolean;
}

interface SimulatorStatus {
  enabled: boolean;
  running: boolean;
  count: number;
  routeable: boolean;
  intervals: number[];
  firebaseReady: boolean;
  lastStartedAt: string | null;
  lastRotationAt: string | null;
}

const covers = [
  'assets/images/host_covers/host_cover_jazz.jpg',
  'assets/images/host_covers/host_cover_beach.jpg',
  'assets/images/host_covers/host_cover_club.jpg',
  'assets/images/host_covers/host_cover_rooftop.jpg',
  'assets/images/host_covers/host_cover_cafe.jpg',
  'assets/images/host_covers/host_cover_music.jpg',
];

const profiles: Array<[string, string, string]> = [
  ['Amina Vale', 'MU', 'English'],
  ['Maya Sol', 'PH', 'English'],
  ['Lina Moreau', 'FR', 'French'],
  ['Nora Hayes', 'US', 'English'],
  ['Sofia Cruz', 'BR', 'Portuguese'],
  ['Elena Park', 'KR', 'English'],
  ['Talia Reed', 'GB', 'English'],
  ['Iris Chen', 'SG', 'English'],
  ['Mila Torres', 'ES', 'Spanish'],
  ['Anika Shah', 'IN', 'English'],
  ['Zara Lane', 'CA', 'English'],
  ['Leah Stone', 'AU', 'English'],
  ['Kiara Bloom', 'ZA', 'English'],
  ['Eva Novak', 'CZ', 'English'],
  ['Nadia Rose', 'IT', 'Italian'],
  ['Rina Cole', 'JP', 'English'],
  ['Amelie Hart', 'DE', 'German'],
  ['Sara Moon', 'AE', 'English'],
  ['Clara Voss', 'NL', 'English'],
  ['Yara Quinn', 'PT', 'Portuguese'],
  ['Mina Kade', 'TH', 'English'],
  ['Bianca Lee', 'MY', 'English'],
  ['Noa Rivers', 'IL', 'English'],
  ['Isla Gray', 'NZ', 'English'],
];

const demoStates: DemoState[] = [
  {
    key: 'free_live',
    weight: 42,
    status: 'live',
    activity: 'free_live_host',
    availability: 'available',
    connection: 'online',
    directCall: true,
    randomCall: true,
    interruptible: true,
    roomMode: 'free_live',
    hasRoom: true,
  },
  {
    key: 'premium_live',
    weight: 12,
    status: 'premium_live',
    activity: 'premium_live_host',
    availability: 'busy',
    connection: 'online',
    directCall: false,
    randomCall: false,
    interruptible: false,
    roomMode: 'premium_live',
    hasRoom: true,
  },
  {
    key: 'online',
    weight: 14,
    status: 'online',
    activity: 'idle',
    availability: 'available',
    connection: 'online',
    directCall: true,
    randomCall: true,
    interruptible: true,
    roomMode: null,
    hasRoom: false,
  },
  {
    key: 'away',
    weight: 8,
    status: 'away',
    activity: 'away',
    availability: 'available',
    connection: 'online',
    directCall: true,
    randomCall: false,
    interruptible: true,
    roomMode: null,
    hasRoom: false,
  },
  {
    key: 'direct_call',
    weight: 8,
    status: 'busy',
    activity: 'direct_call',
    availability: 'busy',
    connection: 'online',
    directCall: false,
    randomCall: false,
    interruptible: false,
    roomMode: null,
    hasRoom: false,
  },
  {
    key: 'random_call',
    weight: 8,
    status: 'busy',
    activity: 'random_call',
    availability: 'busy',
    connection: 'online',
    directCall: false,
    randomCall: false,
    interruptible: false,
    roomMode: null,
    hasRoom: false,
  },
  {
    key: 'offline',
    weight: 8,
    status: 'offline',
    activity: 'idle',
    availability: 'unavailable',
    connection: 'offline',
    directCall: false,
    randomCall: false,
    interruptible: false,
    roomMode: null,
    hasRoom: false,
  },
];

@Injectable()
export class DemoForYouSimulatorService
  implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(DemoForYouSimulatorService.name);
  private readonly timers = new Map<string, ReturnType<typeof setTimeout>>();
  private running = false;
  private count = DEFAULT_COUNT;
  private intervals = DEFAULT_INTERVALS;
  private routeable = false;
  private lastStartedAt: string | null = null;
  private lastRotationAt: string | null = null;

  constructor(private readonly databaseService: DatabaseService) {}

  async onModuleInit(): Promise<void> {
    if (!this.isAutoEnabled()) {
      return;
    }

    try {
      await this.databaseService.waitUntilReady();
      await this.start({
        count: this.envInt('DEMO_FOR_YOU_SIMULATOR_COUNT', DEFAULT_COUNT),
        intervals: this.envIntervals(),
        routeable: process.env.DEMO_FOR_YOU_SIMULATOR_ROUTEABLE === 'true',
      });
    } catch (error) {
      this.logger.error('Failed to start For you demo simulator', error);
    }
  }

  async onModuleDestroy(): Promise<void> {
    this.stop();
  }

  status(): SimulatorStatus {
    return {
      enabled: this.isAutoEnabled(),
      running: this.running,
      count: this.count,
      routeable: this.routeable,
      intervals: this.intervals,
      firebaseReady: admin.apps.length > 0,
      lastStartedAt: this.lastStartedAt,
      lastRotationAt: this.lastRotationAt,
    };
  }

  async start(options: StartOptions = {}): Promise<SimulatorStatus> {
    if (!this.databaseService.isEnabled()) {
      throw new Error('DATABASE_URL is required for the demo simulator');
    }
    if (!ensureFirebaseAdminInitialized(this.logger)) {
      throw new Error(
        'FIREBASE_SERVICE_ACCOUNT_JSON is required for canonical RTDB simulation',
      );
    }

    this.stop();
    this.count = this.normalizeCount(options.count ?? DEFAULT_COUNT);
    this.intervals = this.normalizeIntervals(
      options.intervals ?? DEFAULT_INTERVALS,
    );
    this.routeable = options.routeable ?? false;
    this.lastStartedAt = new Date().toISOString();
    this.lastRotationAt = null;

    const hosts = await this.upsertHosts(this.count);
    const firstDelays = new Map<string, number>();
    for (const host of hosts) {
      const nextDelaySeconds = this.firstDelaySeconds();
      firstDelays.set(host.id, nextDelaySeconds);
      await this.writeProfile(host);
      await this.rotateHost(host, nextDelaySeconds);
    }

    this.running = true;
    for (const host of hosts) {
      this.scheduleHost(host, firstDelays.get(host.id) ?? this.pickDelaySeconds());
    }

    this.logger.log(
      `For you demo simulator running: hosts=${hosts.length}, intervals=${this.intervals.join(
        '/',
      )}s, routeable=${this.routeable}`,
    );
    return this.status();
  }

  stop(): SimulatorStatus {
    for (const timer of this.timers.values()) {
      clearTimeout(timer);
    }
    this.timers.clear();
    this.running = false;
    return this.status();
  }

  async cleanup(): Promise<{ removedHosts: number; removedRooms: number }> {
    this.stop();
    if (!this.databaseService.isEnabled()) {
      return { removedHosts: 0, removedRooms: 0 };
    }
    ensureFirebaseAdminInitialized(this.logger);

    const hosts = await this.listDemoHosts(1000);
    const roomIds = await this.findDemoRoomIds();

    await this.databaseService.query(
      `
        DELETE FROM users
        WHERE provider = $1
          AND provider_subject LIKE $2
      `,
      [PROVIDER, `${SUBJECT_PREFIX}%`],
    );

    if (admin.apps.length > 0) {
      const updates: Record<string, null> = {};
      for (const host of hosts) {
        updates[`presence/${host.id}`] = null;
        updates[`profiles/${host.id}`] = null;
        updates[`direct_calls/${host.id}`] = null;
      }
      for (const roomId of roomIds) {
        updates[`live_rooms/${roomId}`] = null;
      }
      if (Object.keys(updates).length > 0) {
        await admin.database().ref().update(updates);
      }

      try {
        const firestore = admin.firestore();
        for (const host of hosts) {
          const chatSnap = await firestore
            .collection('chats')
            .where('participants', 'array-contains', host.id)
            .get();
          for (const doc of chatSnap.docs) {
            await firestore.recursiveDelete(doc.ref);
          }
        }
      } catch {
        // Firestore cleanup is best-effort; RTDB/DB cleanup is enough for feed tests.
      }
    }

    this.logger.log(
      `For you demo simulator cleanup removed hosts=${hosts.length}, rooms=${roomIds.length}`,
    );
    return { removedHosts: hosts.length, removedRooms: roomIds.length };
  }

  private isAutoEnabled(): boolean {
    return process.env.DEMO_FOR_YOU_SIMULATOR_ENABLED === 'true';
  }

  private envInt(name: string, fallback: number): number {
    const parsed = Number.parseInt(process.env[name] ?? '', 10);
    return Number.isFinite(parsed) ? parsed : fallback;
  }

  private envIntervals(): number[] {
    const raw = process.env.DEMO_FOR_YOU_SIMULATOR_INTERVALS;
    if (!raw) return DEFAULT_INTERVALS;
    return this.normalizeIntervals(
      raw
        .split(',')
        .map((value) => Number.parseInt(value.trim(), 10))
        .filter((value) => Number.isFinite(value)),
    );
  }

  private normalizeCount(value: number): number {
    return Math.min(Math.max(Math.trunc(value), 1), 100);
  }

  private normalizeIntervals(value: number[]): number[] {
    const intervals = value
      .map((item) => Math.trunc(item))
      .filter((item) => Number.isFinite(item) && item >= 5);
    return intervals.length > 0 ? intervals : DEFAULT_INTERVALS;
  }

  private firstDelaySeconds(): number {
    return Math.floor(Math.random() * 4) + 1;
  }

  private pickDelaySeconds(): number {
    return this.intervals[Math.floor(Math.random() * this.intervals.length)];
  }

  private pickState(): DemoState {
    const total = demoStates.reduce((sum, state) => sum + state.weight, 0);
    let cursor = Math.random() * total;
    for (const state of demoStates) {
      cursor -= state.weight;
      if (cursor <= 0) return state;
    }
    return demoStates[demoStates.length - 1];
  }

  private profileSeed(index: number): {
    providerSubject: string;
    displayName: string;
    email: string;
    countryCode: string;
    language: string;
    coverUrl: string;
    publicId: string;
    birthday: string;
  } {
    const [displayName, countryCode, language] =
      profiles[index % profiles.length];
    const ordinal = String(index + 1).padStart(2, '0');
    return {
      providerSubject: `${SUBJECT_PREFIX}${ordinal}`,
      displayName,
      email: `for-you-demo-${ordinal}@zephyr.test`,
      countryCode,
      language,
      coverUrl: covers[index % covers.length],
      publicId: `ZFYDEMO${ordinal}`,
      birthday: `${1996 + (index % 8)}-06-01`,
    };
  }

  private async upsertHosts(count: number): Promise<DemoHost[]> {
    const hosts: DemoHost[] = [];
    for (let index = 0; index < count; index += 1) {
      const seed = this.profileSeed(index);
      const result = await this.databaseService.query<DemoHost>(
        `
          INSERT INTO users (
            id, display_name, email, provider, provider_subject, avatar_url,
            cover_url, bio, gender, birthday, country_code, language,
            is_admin, call_rate_coins_per_minute, public_id, is_host,
            status, presence_connection, presence_activity, presence_availability,
            can_direct_call, can_random_call, presence_updated_at, last_seen_at,
            created_at
          )
          VALUES (
            $1, $2, $3, $4, $5, NULL,
            $6, $7, 'Female', $8::date, $9, $10,
            FALSE, 2100, $11, TRUE,
            'offline', 'offline', 'idle', 'unavailable',
            FALSE, FALSE, NOW(), NOW(),
            $12::timestamptz
          )
          ON CONFLICT (provider, provider_subject)
          WHERE provider IS NOT NULL AND provider_subject IS NOT NULL
          DO UPDATE SET
            display_name = EXCLUDED.display_name,
            email = EXCLUDED.email,
            cover_url = EXCLUDED.cover_url,
            bio = EXCLUDED.bio,
            gender = EXCLUDED.gender,
            birthday = EXCLUDED.birthday,
            country_code = EXCLUDED.country_code,
            language = EXCLUDED.language,
            call_rate_coins_per_minute = EXCLUDED.call_rate_coins_per_minute,
            public_id = EXCLUDED.public_id,
            is_host = TRUE
          RETURNING id, display_name, country_code, language, cover_url
        `,
        [
          randomUUID(),
          seed.displayName,
          seed.email,
          PROVIDER,
          seed.providerSubject,
          seed.coverUrl,
          'Zephyr For you demo host. Safe to remove with the demo cleanup control.',
          seed.birthday,
          seed.countryCode,
          seed.language,
          seed.publicId,
          new Date(Date.now() - index * 20_000).toISOString(),
        ],
      );

      const host = result.rows[0];
      await this.databaseService.query(
        `
          INSERT INTO wallets (user_id, coin_balance, level, updated_at)
          VALUES ($1, 0, 1, NOW())
          ON CONFLICT (user_id) DO NOTHING
        `,
        [host.id],
      );
      await this.databaseService.query(
        `
          INSERT INTO user_revenue (user_id, revenue_usd, spark_balance, updated_at)
          VALUES ($1, 0, 0, NOW())
          ON CONFLICT (user_id) DO NOTHING
        `,
        [host.id],
      );
      hosts.push(host);
    }
    return hosts;
  }

  private async listDemoHosts(limit: number): Promise<DemoHost[]> {
    const result = await this.databaseService.query<DemoHost>(
      `
        SELECT id, display_name, country_code, language, cover_url
        FROM users
        WHERE provider = $1
          AND provider_subject LIKE $2
        ORDER BY provider_subject ASC
        LIMIT $3
      `,
      [PROVIDER, `${SUBJECT_PREFIX}%`, limit],
    );
    return result.rows;
  }

  private async findDemoRoomIds(): Promise<string[]> {
    const result = await this.databaseService.query<{ id: string }>(
      `
        SELECT rooms.id
        FROM rooms
        JOIN users ON users.id = rooms.host_user_id
        WHERE users.provider = $1
          AND users.provider_subject LIKE $2
      `,
      [PROVIDER, `${SUBJECT_PREFIX}%`],
    );
    return result.rows.map((row) => row.id);
  }

  private scheduleHost(host: DemoHost, delaySeconds: number): void {
    if (!this.running) return;
    const timer = setTimeout(async () => {
      this.timers.delete(host.id);
      if (!this.running) return;

      try {
        const nextDelaySeconds = this.pickDelaySeconds();
        await this.rotateHost(host, nextDelaySeconds);
        if (this.running) {
          this.scheduleHost(host, nextDelaySeconds);
        }
      } catch (error) {
        this.logger.warn(
          `Failed to rotate demo host ${host.display_name}: ${String(error)}`,
        );
        if (this.running) {
          this.scheduleHost(host, this.pickDelaySeconds());
        }
      }
    }, delaySeconds * 1000);
    this.timers.set(host.id, timer);
  }

  private async rotateHost(
    host: DemoHost,
    nextDelaySeconds: number,
  ): Promise<void> {
    const state = this.pickState();
    const { roomId, removedRoomId, audienceCount } = await this.projectState(
      host,
      state,
    );
    await this.writePresence(host, state, roomId, nextDelaySeconds);
    if (removedRoomId) {
      await admin.database().ref(`live_rooms/${removedRoomId}`).remove();
    }
    if (state.hasRoom && roomId) {
      await this.writeLiveRoom(host, state, roomId, audienceCount);
    }
    this.lastRotationAt = new Date().toISOString();
  }

  private stateRouting(state: DemoState): {
    directCall: boolean;
    randomCall: boolean;
  } {
    return {
      directCall: this.routeable ? state.directCall : false,
      randomCall: this.routeable ? state.randomCall : false,
    };
  }

  private async projectState(
    host: DemoHost,
    state: DemoState,
  ): Promise<{
    roomId: string | null;
    removedRoomId: string | null;
    audienceCount: number;
  }> {
    const routing = this.stateRouting(state);
    const audienceCount = state.hasRoom
      ? Math.floor(60 + Math.random() * 1800)
      : 0;

    return this.databaseService.transaction(async (client: PoolClient) => {
      const existingRoom = await client.query<{ id: string }>(
        `
          SELECT id
          FROM rooms
          WHERE host_user_id = $1
          ORDER BY created_at DESC
          LIMIT 1
        `,
        [host.id],
      );
      let roomId: string | null = existingRoom.rows[0]?.id ?? null;
      let removedRoomId: string | null = null;

      await client.query(
        `
          UPDATE users
          SET status = $1,
              presence_connection = $2,
              presence_activity = $3,
              presence_availability = $4,
              can_direct_call = $5,
              can_random_call = $6,
              presence_updated_at = NOW(),
              last_seen_at = NOW()
          WHERE id = $7
        `,
        [
          state.status,
          state.connection,
          state.activity,
          state.availability,
          routing.directCall,
          routing.randomCall,
          host.id,
        ],
      );

      if (state.hasRoom) {
        if (!roomId) {
          roomId = randomUUID();
          await client.query(
            `
              INSERT INTO rooms (id, host_user_id, title, audience_count, status, created_at, last_heartbeat)
              VALUES ($1, $2, $3, $4, 'live', NOW(), NOW())
            `,
            [roomId, host.id, `${host.display_name} Live`, audienceCount],
          );
        } else {
          await client.query(
            `
              UPDATE rooms
              SET title = $2,
                  audience_count = $3,
                  status = 'live',
                  last_heartbeat = NOW()
              WHERE id = $1
            `,
            [roomId, `${host.display_name} Live`, audienceCount],
          );
          await client.query(
            `DELETE FROM rooms WHERE host_user_id = $1 AND id <> $2`,
            [host.id, roomId],
          );
        }
      } else {
        removedRoomId = roomId;
        roomId = null;
        await client.query(`DELETE FROM rooms WHERE host_user_id = $1`, [
          host.id,
        ]);
      }

      return { roomId, removedRoomId, audienceCount };
    });
  }

  private async writeProfile(host: DemoHost): Promise<void> {
    await admin
      .database()
      .ref(`profiles/${host.id}`)
      .set({
        displayName: host.display_name,
        avatarUrl: null,
        countryCode: host.country_code ?? 'PH',
        language: host.language ?? 'English',
        updatedAt: admin.database.ServerValue.TIMESTAMP,
      });
  }

  private async writePresence(
    host: DemoHost,
    state: DemoState,
    roomId: string | null,
    nextDelaySeconds: number,
  ): Promise<void> {
    const routing = this.stateRouting(state);
    const callSessionId =
      state.activity === 'direct_call' || state.activity === 'random_call'
        ? randomUUID()
        : null;
    const nextRotationAt = Date.now() + nextDelaySeconds * 1000;
    await admin
      .database()
      .ref(`presence/${host.id}`)
      .set({
        schemaVersion: 1,
        connection: state.connection,
        activity: state.activity,
        availability: state.availability,
        routing,
        displayStatus: state.status,
        interruptible: state.interruptible,
        roomId,
        roomMode: state.roomMode,
        callSessionId,
        premiumRoomSessionId: null,
        previousActivity: null,
        previousRoomId: null,
        state: state.status,
        updatedAt: admin.database.ServerValue.TIMESTAMP,
        demo: {
          simulator: 'for_you',
          routeable: this.routeable,
          nextDelaySeconds,
          nextRotationAt,
          nextRotationAtIso: new Date(nextRotationAt).toISOString(),
        },
      });
  }

  private async writeLiveRoom(
    host: DemoHost,
    state: DemoState,
    roomId: string,
    audienceCount: number,
  ): Promise<void> {
    await admin
      .database()
      .ref(`live_rooms/${roomId}`)
      .update({
        status: 'live',
        roomMode: state.roomMode,
        hostUserId: host.id,
        hostId: host.id,
        hostName: host.display_name,
        audience_count: audienceCount,
        updatedAt: admin.database.ServerValue.TIMESTAMP,
      });
  }
}
