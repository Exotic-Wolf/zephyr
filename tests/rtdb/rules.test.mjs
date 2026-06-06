import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { get, ref, remove, set, update } from 'firebase/database';

const projectId = 'zephyr-rtdb-rules-test';
let env;

const presence = (overrides = {}) => ({
  schemaVersion: 1,
  connection: 'online',
  activity: 'idle',
  availability: 'available',
  routing: {
    directCall: true,
    randomCall: true,
  },
  displayStatus: 'online',
  interruptible: true,
  state: 'online',
  lastSeen: 1760000000000,
  updatedAt: 1760000000000,
  ...overrides,
});

const profile = (overrides = {}) => ({
  displayName: 'Alice',
  countryCode: 'MU',
  language: 'English',
  ...overrides,
});

const callSignal = (overrides = {}) => ({
  callerId: 'alice',
  callerName: 'Alice',
  callerAvatarUrl: 'https://example.com/alice.png',
  sessionId: 'session-1',
  status: 'ringing',
  ts: 1760000000000,
  ...overrides,
});

const liveRoom = (overrides = {}) => ({
  status: 'live',
  hostUserId: 'host',
  audience_count: 0,
  started_at: 1760000000000,
  ...overrides,
});

const db = (uid) => env.authenticatedContext(uid).database();
const anonDb = () => env.unauthenticatedContext().database();

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    database: {
      host: '127.0.0.1',
      port: 9000,
      rules: readFileSync('database.rules.json', 'utf8'),
    },
  });
});

beforeEach(async () => {
  await env.clearDatabase();
});

after(async () => {
  await env.cleanup();
});

describe('presence rules', () => {
  test('enforce owner writes and canonical schema', async () => {
    await assertFails(set(ref(anonDb(), 'presence/alice'), presence()));
    await assertSucceeds(set(ref(db('alice'), 'presence/alice'), presence()));
    await assertFails(set(ref(db('alice'), 'presence/bob'), presence()));
    await assertFails(
      set(ref(db('alice'), 'presence/alice'), presence({ state: 'busy' })),
    );
  });
});

describe('profile rules', () => {
  test('enforce profile ownership and visible identity shape', async () => {
    await assertSucceeds(set(ref(db('alice'), 'profiles/alice'), profile()));
    await assertFails(set(ref(db('alice'), 'profiles/bob'), profile()));
    await assertFails(
      set(ref(db('alice'), 'profiles/alice'), profile({ displayName: '' })),
    );
  });
});

describe('direct call rules', () => {
  test('allow caller create, participant read/status/delete, and immutable metadata', async () => {
    await assertSucceeds(
      set(ref(db('alice'), 'direct_calls/bob'), callSignal()),
    );

    await assertSucceeds(get(ref(db('alice'), 'direct_calls/bob')));
    await assertSucceeds(get(ref(db('bob'), 'direct_calls/bob')));
    await assertFails(get(ref(db('charlie'), 'direct_calls/bob')));

    await assertFails(
      update(ref(db('charlie'), 'direct_calls/bob'), { status: 'accepted' }),
    );
    await assertSucceeds(
      update(ref(db('bob'), 'direct_calls/bob'), { status: 'accepted' }),
    );
    await assertFails(
      update(ref(db('bob'), 'direct_calls/bob'), { callerId: 'charlie' }),
    );
    await assertSucceeds(remove(ref(db('alice'), 'direct_calls/bob')));
  });
});

describe('live room rules', () => {
  test('protect host ownership while allowing validated viewer events', async () => {
    await assertSucceeds(set(ref(db('host'), 'live_rooms/room-1'), liveRoom()));

    await assertFails(
      set(ref(db('viewer'), 'live_rooms/room-1/status'), 'ended'),
    );
    await assertSucceeds(
      set(ref(db('viewer'), 'live_rooms/room-1/comments/comment-1'), {
        name: 'Viewer',
        text: 'Hi',
        ts: 1760000000000,
      }),
    );
    await assertSucceeds(
      set(ref(db('viewer'), 'live_rooms/room-1/reactions/reaction-1'), {
        userId: 'viewer',
        emoji: 'heart',
        ts: 1760000000000,
      }),
    );
    await assertFails(
      set(ref(db('viewer'), 'live_rooms/room-1/reactions/reaction-2'), {
        userId: 'host',
        emoji: 'heart',
        ts: 1760000000000,
      }),
    );
    await assertSucceeds(
      set(ref(db('viewer'), 'live_rooms/room-1/audience_count'), 1),
    );
    await assertFails(remove(ref(db('viewer'), 'live_rooms/room-1')));
    await assertSucceeds(
      set(ref(db('host'), 'live_rooms/room-1/status'), 'ended'),
    );
  });

  test('validate gift event shape until backend fan-out owns trusted gifts', async () => {
    await assertSucceeds(set(ref(db('host'), 'live_rooms/room-1'), liveRoom()));
    await assertSucceeds(
      set(ref(db('viewer'), 'live_rooms/room-1/gifts/gift-1'), {
        senderName: 'Viewer',
        giftId: 'rose',
        giftName: 'Rose',
        quantity: 1,
        ts: 1760000000000,
      }),
    );
    await assertFails(
      set(ref(db('viewer'), 'live_rooms/room-1/gifts/gift-2'), {
        senderName: 'Viewer',
        giftId: 'rose',
        giftName: 'Rose',
        quantity: 100,
        ts: 1760000000000,
      }),
    );
  });
});
