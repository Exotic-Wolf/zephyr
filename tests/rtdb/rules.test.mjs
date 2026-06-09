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
  audience: {},
  started_at: 1760000000000,
  ...overrides,
});

const activeSessionId = (uid) => `active-${uid}`;
const db = (uid) =>
  env.authenticatedContext(uid, { sessionId: activeSessionId(uid) }).database();
const legacyDb = (uid) => env.authenticatedContext(uid).database();
const staleDb = (uid) =>
  env.authenticatedContext(uid, { sessionId: `stale-${uid}` }).database();
const anonDb = () => env.unauthenticatedContext().database();

const seedActiveSessions = async (...uids) => {
  await env.withSecurityRulesDisabled(async (context) => {
    await Promise.all(
      uids.map((uid) =>
        set(ref(context.database(), `session_controls/${uid}`), {
          activeSessionId: activeSessionId(uid),
        }),
      ),
    );
  });
};

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
  await seedActiveSessions('alice', 'bob', 'charlie', 'host', 'viewer');
});

after(async () => {
  await env.cleanup();
});

describe('presence rules', () => {
  test('allow pre-migration Firebase sessions before backend projection exists', async () => {
    await env.clearDatabase();

    await assertSucceeds(set(ref(legacyDb('alice'), 'presence/alice'), presence()));
  });

  test('reject stale Firebase custom-token sessions', async () => {
    await assertFails(set(ref(staleDb('alice'), 'presence/alice'), presence()));
  });

  test('enforce owner writes and canonical schema', async () => {
    await assertFails(set(ref(anonDb(), 'presence/alice'), presence()));
    await assertSucceeds(set(ref(db('alice'), 'presence/alice'), presence()));
    await assertFails(set(ref(db('alice'), 'presence/bob'), presence()));
    await assertFails(
      set(ref(db('alice'), 'presence/alice'), presence({ state: 'busy' })),
    );
    await assertFails(
      set(
        ref(db('alice'), 'presence/alice'),
        presence({
          activity: 'premium_live_host',
          displayStatus: 'premium_live',
          state: 'premium_live',
          roomId: 'room-1',
          roomMode: 'premium_live',
        }),
      ),
    );
  });

  test('enforce coherent canonical availability transitions', async () => {
    await assertSucceeds(
      set(
        ref(db('host'), 'presence/host'),
        presence({
          activity: 'free_live_host',
          displayStatus: 'live',
          state: 'live',
          roomId: 'room-1',
          roomMode: 'free_live',
        }),
      ),
    );
    await assertSucceeds(
      set(
        ref(db('host'), 'presence/host'),
        presence({
          activity: 'live_paused',
          availability: 'unavailable',
          routing: { directCall: false, randomCall: false },
          displayStatus: 'busy',
          interruptible: false,
          state: 'busy',
          roomId: 'room-1',
          roomMode: 'free_live',
        }),
      ),
    );
    await assertSucceeds(
      set(
        ref(db('host'), 'presence/host'),
        presence({
          activity: 'premium_live_host',
          availability: 'busy',
          routing: { directCall: false, randomCall: false },
          displayStatus: 'premium_live',
          interruptible: false,
          state: 'premium_live',
          roomId: 'room-1',
          roomMode: 'premium_live',
        }),
      ),
    );
    await assertSucceeds(
      set(
        ref(db('viewer'), 'presence/viewer'),
        presence({
          activity: 'premium_live_viewer',
          availability: 'busy',
          routing: { directCall: false, randomCall: false },
          displayStatus: 'busy',
          interruptible: false,
          state: 'busy',
          roomId: 'room-1',
          roomMode: 'premium_live',
          premiumRoomSessionId: 'premium-session-1',
        }),
      ),
    );
    await assertFails(
      set(
        ref(db('host'), 'presence/host'),
        presence({
          activity: 'premium_live_host',
          availability: 'busy',
          routing: { directCall: false, randomCall: true },
          displayStatus: 'premium_live',
          interruptible: false,
          state: 'premium_live',
          roomId: 'room-1',
          roomMode: 'premium_live',
        }),
      ),
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

  test('allow random matched signal participants to read and clear backend signal', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await set(
        ref(context.database(), 'direct_calls/bob'),
        callSignal({
          event: 'matched',
          status: 'matched',
          appId: 'agora-app',
          channelName: 'random-session-1',
          uid: 4242,
          token: 'receiver-token',
          partnerId: 'alice',
          partnerName: 'Alice',
          rateCoinsPerMinute: 600,
          hostEarningCoinsPerMinute: 360,
          receiverShareBps: 6000,
          expiresAt: 1760000030000,
        }),
      );
    });

    await assertSucceeds(get(ref(db('alice'), 'direct_calls/bob')));
    await assertSucceeds(get(ref(db('bob'), 'direct_calls/bob')));
    await assertFails(get(ref(db('charlie'), 'direct_calls/bob')));
    await assertSucceeds(remove(ref(db('bob'), 'direct_calls/bob')));
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
        userId: 'viewer',
        name: 'Viewer',
        text: 'Hi',
        ts: 1760000000000,
      }),
    );
    await assertFails(
      set(ref(db('viewer'), 'live_rooms/room-1/comments/comment-2'), {
        userId: 'host',
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
    await assertFails(
      set(ref(db('viewer'), 'live_rooms/room-1/audience_count'), 1),
    );
    await assertSucceeds(
      set(ref(db('viewer'), 'live_rooms/room-1/audience/viewer'), {
        joinedAt: 1760000000000,
        lastSeen: 1760000000000,
      }),
    );
    await assertFails(
      set(ref(db('viewer'), 'live_rooms/room-1/audience/host'), {
        joinedAt: 1760000000000,
        lastSeen: 1760000000000,
      }),
    );
    await assertSucceeds(remove(ref(db('viewer'), 'live_rooms/room-1/audience/viewer')));
    await assertFails(remove(ref(db('viewer'), 'live_rooms/room-1')));
    await assertSucceeds(
      set(ref(db('host'), 'live_rooms/room-1/status'), 'ended'),
    );
  });

  test('block client gift fan-out while backend/admin trusted gifts remain readable', async () => {
    await assertSucceeds(set(ref(db('host'), 'live_rooms/room-1'), liveRoom()));
    await assertFails(
      set(ref(db('viewer'), 'live_rooms/room-1/gifts/gift-1'), {
        senderUserId: 'viewer',
        senderName: 'Viewer',
        giftId: 'rose',
        giftName: 'Rose',
        quantity: 1,
        ts: 1760000000000,
      }),
    );

    await env.withSecurityRulesDisabled(async (context) => {
      await set(ref(context.database(), 'live_rooms/room-1/gifts/gift-1'), {
        trusted: true,
        senderUserId: 'viewer',
        senderName: 'Viewer',
        giftId: 'rose',
        giftName: 'Rose',
        quantity: 1,
        totalGiftCoins: 99,
        ts: 1760000000000,
      });
    });

    await assertSucceeds(get(ref(db('viewer'), 'live_rooms/room-1/gifts/gift-1')));
    await assertFails(
      set(ref(db('host'), 'live_rooms/room-2'), {
        ...liveRoom(),
        gifts: {
          forged: {
            senderName: 'Viewer',
            giftId: 'rose',
            giftName: 'Rose',
            quantity: 1,
            ts: 1760000000000,
          },
        },
      }),
    );
  });
});
