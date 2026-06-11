import { createRequire } from 'node:module';
import { randomUUID } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Pool } from 'pg';

const require = createRequire(import.meta.url);
const scriptDir = dirname(fileURLToPath(import.meta.url));

const PROVIDER = 'zephyr-demo';
const SUBJECT_PREFIX = 'for-you-host-';
const DEFAULT_COUNT = 24;
const DEFAULT_INTERVALS = [15, 30, 60, 120];

const covers = [
  'assets/images/host_covers/host_cover_jazz.jpg',
  'assets/images/host_covers/host_cover_beach.jpg',
  'assets/images/host_covers/host_cover_club.jpg',
  'assets/images/host_covers/host_cover_rooftop.jpg',
  'assets/images/host_covers/host_cover_cafe.jpg',
  'assets/images/host_covers/host_cover_music.jpg',
];

const profiles = [
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

const demoStates = [
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

function loadDotEnv() {
  const candidates = [resolve(process.cwd(), '.env'), resolve(scriptDir, '..', '.env')];
  for (const filePath of candidates) {
    if (!existsSync(filePath)) continue;
    const body = readFileSync(filePath, 'utf8');
    for (const line of body.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const separator = trimmed.indexOf('=');
      if (separator <= 0) continue;
      const key = trimmed.slice(0, separator).trim();
      let value = trimmed.slice(separator + 1).trim();
      if (
        (value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))
      ) {
        value = value.slice(1, -1);
      }
      if (!(key in process.env)) {
        process.env[key] = value;
      }
    }
  }
}

function argValue(args, name, fallback = null) {
  const direct = args.find((arg) => arg.startsWith(`${name}=`));
  if (direct) return direct.slice(name.length + 1);
  const index = args.indexOf(name);
  if (index >= 0 && args[index + 1]) return args[index + 1];
  return fallback;
}

function hasArg(args, name) {
  return args.includes(name);
}

function parseCount(args) {
  const raw = argValue(args, '--count', String(DEFAULT_COUNT));
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed) || parsed < 1 || parsed > 100) {
    throw new Error('--count must be between 1 and 100');
  }
  return parsed;
}

function parseIntervals(args) {
  const raw = argValue(args, '--intervals', DEFAULT_INTERVALS.join(','));
  const intervals = raw
    .split(',')
    .map((value) => Number.parseInt(value.trim(), 10))
    .filter((value) => Number.isFinite(value) && value >= 5);
  if (intervals.length === 0) {
    throw new Error('--intervals must contain at least one value of 5 seconds or more');
  }
  return intervals;
}

function buildPool() {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    throw new Error('DATABASE_URL is required');
  }

  return new Pool({
    connectionString: databaseUrl,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
  });
}

function pick(items) {
  return items[Math.floor(Math.random() * items.length)];
}

function pickWeighted(items) {
  const total = items.reduce((sum, item) => sum + item.weight, 0);
  let cursor = Math.random() * total;
  for (const item of items) {
    cursor -= item.weight;
    if (cursor <= 0) return item;
  }
  return items[items.length - 1];
}

function buildHostSeed(index) {
  const [name, countryCode, language] = profiles[index % profiles.length];
  const ordinal = String(index + 1).padStart(2, '0');
  return {
    providerSubject: `${SUBJECT_PREFIX}${ordinal}`,
    displayName: name,
    email: `for-you-demo-${ordinal}@zephyr.test`,
    countryCode,
    language,
    coverUrl: covers[index % covers.length],
    publicId: `ZFYDEMO${ordinal}`,
    birthday: `${1996 + (index % 8)}-06-01`,
  };
}

async function initializeFirebaseAdmin() {
  if (!process.env.FIREBASE_SERVICE_ACCOUNT_JSON) return null;

  const admin = require('firebase-admin');
  if (admin.apps.length === 0) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
    const databaseURL =
      process.env.FIREBASE_DATABASE_URL ||
      `https://${serviceAccount.project_id}-default-rtdb.asia-southeast1.firebasedatabase.app`;
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      databaseURL,
    });
  }
  return admin;
}

async function upsertHosts(pool, count) {
  const hosts = [];
  for (let index = 0; index < count; index += 1) {
    const seed = buildHostSeed(index);
    const result = await pool.query(
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
        'Zephyr For you demo host. Safe to remove with the demo cleanup script.',
        seed.birthday,
        seed.countryCode,
        seed.language,
        seed.publicId,
        new Date(Date.now() - index * 20_000).toISOString(),
      ],
    );

    const host = result.rows[0];
    await pool.query(
      `
        INSERT INTO wallets (user_id, coin_balance, level, updated_at)
        VALUES ($1, 0, 1, NOW())
        ON CONFLICT (user_id) DO NOTHING
      `,
      [host.id],
    );
    await pool.query(
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

async function findDemoRooms(pool) {
  const result = await pool.query(
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

async function listDemoHosts(pool, count = 100) {
  const result = await pool.query(
    `
      SELECT id, display_name, country_code, language, cover_url
      FROM users
      WHERE provider = $1
        AND provider_subject LIKE $2
      ORDER BY provider_subject ASC
      LIMIT $3
    `,
    [PROVIDER, `${SUBJECT_PREFIX}%`, count],
  );
  return result.rows;
}

function stateForProjection(state, routeable) {
  return {
    ...state,
    directCall: routeable ? state.directCall : false,
    randomCall: routeable ? state.randomCall : false,
  };
}

async function setHostState(pool, admin, host, state, routeable) {
  const projection = stateForProjection(state, routeable);
  const client = await pool.connect();
  let removedRoomId = null;
  let roomId = null;
  const audienceCount = projection.hasRoom
    ? Math.floor(60 + Math.random() * 1800)
    : 0;

  try {
    await client.query('BEGIN');
    const existingRoom = await client.query(
      `
        SELECT id
        FROM rooms
        WHERE host_user_id = $1
        ORDER BY created_at DESC
        LIMIT 1
      `,
      [host.id],
    );
    roomId = existingRoom.rows[0]?.id ?? null;

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
        projection.status,
        projection.connection,
        projection.activity,
        projection.availability,
        projection.directCall,
        projection.randomCall,
        host.id,
      ],
    );

    if (projection.hasRoom) {
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
      await client.query(`DELETE FROM rooms WHERE host_user_id = $1`, [host.id]);
    }

    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }

  if (admin) {
    await mirrorRtdbState(admin, host, projection, roomId);
    if (!projection.hasRoom && removedRoomId) {
      await admin.database().ref(`live_rooms/${removedRoomId}`).remove();
    }
  }

  return { roomId: projection.hasRoom ? roomId : null, audienceCount };
}

async function mirrorRtdbState(admin, host, state, roomId) {
  const now = Date.now();
  const callSessionId =
    state.activity === 'direct_call' || state.activity === 'random_call'
      ? randomUUID()
      : null;
  const presence = {
    schemaVersion: 1,
    connection: state.connection,
    activity: state.activity,
    availability: state.availability,
    routing: {
      directCall: state.directCall,
      randomCall: state.randomCall,
    },
    displayStatus: state.status,
    interruptible: state.interruptible,
    roomId: state.hasRoom ? roomId : null,
    roomMode: state.roomMode,
    callSessionId,
    premiumRoomSessionId: null,
    previousActivity: null,
    previousRoomId: null,
    state: state.status,
    lastSeen: now,
    updatedAt: now,
  };

  const updates = {
    [`presence/${host.id}`]: presence,
  };
  if (state.hasRoom && roomId) {
    updates[`live_rooms/${roomId}/status`] = 'live';
    updates[`live_rooms/${roomId}/roomMode`] = state.roomMode;
    updates[`live_rooms/${roomId}/hostId`] = host.id;
    updates[`live_rooms/${roomId}/hostName`] = host.display_name;
    updates[`live_rooms/${roomId}/updatedAt`] = now;
  }
  await admin.database().ref().update(updates);
}

async function cleanup(pool, admin) {
  const roomIds = await findDemoRooms(pool);
  const hosts = await listDemoHosts(pool);

  await pool.query(
    `
      DELETE FROM users
      WHERE provider = $1
        AND provider_subject LIKE $2
    `,
    [PROVIDER, `${SUBJECT_PREFIX}%`],
  );

  if (admin) {
    const updates = {};
    for (const host of hosts) updates[`presence/${host.id}`] = null;
    for (const roomId of roomIds) updates[`live_rooms/${roomId}`] = null;
    if (Object.keys(updates).length > 0) {
      await admin.database().ref().update(updates);
    }
  }

  console.log(
    `[for-you-demo] removed ${hosts.length} host(s) and ${roomIds.length} room node(s)`,
  );
}

async function seedOnce(pool, admin, options) {
  const hosts = await upsertHosts(pool, options.count);
  const counts = new Map();
  for (const host of hosts) {
    const state = pickWeighted(demoStates);
    const result = await setHostState(pool, admin, host, state, options.routeable);
    counts.set(state.key, (counts.get(state.key) ?? 0) + 1);
    const roomSuffix = result.roomId
      ? `, room=${result.roomId}, viewers=${result.audienceCount}`
      : '';
    console.log(`[for-you-demo] ${host.display_name} -> ${state.key}${roomSuffix}`);
  }
  console.log(
    `[for-you-demo] seeded ${hosts.length} host(s): ${[...counts.entries()]
      .map(([key, value]) => `${key}=${value}`)
      .join(', ')}`,
  );
}

function startRotation(pool, admin, hosts, options) {
  const timers = new Set();

  const schedule = (host, delaySeconds = pick(options.intervals)) => {
    const timer = setTimeout(async () => {
      timers.delete(timer);
      const state = pickWeighted(demoStates);
      try {
        const result = await setHostState(pool, admin, host, state, options.routeable);
        const roomSuffix = result.roomId ? `, viewers=${result.audienceCount}` : '';
        const nextDelay = pick(options.intervals);
        console.log(
          `[for-you-demo] ${host.display_name} -> ${state.key}${roomSuffix}; next ~${nextDelay}s`,
        );
        schedule(host, nextDelay);
      } catch (error) {
        console.error(`[for-you-demo] failed to rotate ${host.display_name}`, error);
        schedule(host);
      }
    }, delaySeconds * 1000);
    timers.add(timer);
  };

  for (const host of hosts) schedule(host, Math.floor(Math.random() * 4) + 1);

  const stop = async () => {
    for (const timer of timers) clearTimeout(timer);
    await pool.end();
    console.log('[for-you-demo] stopped. Run cleanup when you want to remove demo hosts.');
    process.exit(0);
  };
  process.once('SIGINT', stop);
  process.once('SIGTERM', stop);
}

async function main() {
  loadDotEnv();

  const args = process.argv.slice(2);
  const command = args.find((arg) => ['run', 'seed', 'cleanup'].includes(arg)) ?? 'run';
  const needsConfirmation = command === 'run' || command === 'seed' || command === 'cleanup';
  if (needsConfirmation && !hasArg(args, '--yes')) {
    throw new Error(
      'Add --yes to confirm demo data writes. Use cleanup --yes to remove these hosts later.',
    );
  }

  if (!['run', 'seed', 'cleanup'].includes(command)) {
    throw new Error(
      'Usage: demo-for-you-hosts.mjs run|seed|cleanup [--count=24] [--yes] [--db-only]',
    );
  }

  const pool = buildPool();
  const dbOnly = hasArg(args, '--db-only') || hasArg(args, '--no-rtdb');
  const admin = dbOnly ? null : await initializeFirebaseAdmin();
  if (!admin && !dbOnly && command !== 'cleanup') {
    throw new Error(
      'FIREBASE_SERVICE_ACCOUNT_JSON is required for real simulation. Add --db-only only for projection-only cleanup/local debugging.',
    );
  }
  if (!admin && dbOnly) {
    console.log('[for-you-demo] RTDB mirror disabled; using Postgres projection only');
  } else if (!admin && command === 'cleanup') {
    console.log('[for-you-demo] RTDB cleanup skipped; FIREBASE_SERVICE_ACCOUNT_JSON is missing');
  }

  const options = {
    count: parseCount(args),
    intervals: parseIntervals(args),
    routeable: hasArg(args, '--routeable'),
  };

  if (command === 'cleanup') {
    await cleanup(pool, admin);
    await pool.end();
    return;
  }

  await seedOnce(pool, admin, options);

  if (command === 'seed') {
    await pool.end();
    return;
  }

  const hosts = await listDemoHosts(pool, options.count);
  console.log(
    `[for-you-demo] rotating ${hosts.length} host(s) every ${options.intervals.join(
      '/',
    )}s. Routeable=${options.routeable ? 'yes' : 'no'}. Press Ctrl+C to stop.`,
  );
  startRotation(pool, admin, hosts, options);
}

main().catch((error) => {
  console.error(`[for-you-demo] ${error.message}`);
  process.exit(1);
});
