import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'zephyr-firestore-rules-test';
let env;

const activeSessionId = (uid) => `active-${uid}`;
const db = (uid) =>
  env.authenticatedContext(uid, { sessionId: activeSessionId(uid) }).firestore();
const legacyDb = (uid) => env.authenticatedContext(uid).firestore();
const staleDb = (uid) =>
  env.authenticatedContext(uid, { sessionId: `stale-${uid}` }).firestore();

const seedActiveSessions = async (...uids) => {
  await env.withSecurityRulesDisabled(async (context) => {
    await Promise.all(
      uids.map((uid) =>
        setDoc(doc(context.firestore(), `session_controls/${uid}`), {
          activeSessionId: activeSessionId(uid),
        }),
      ),
    );
  });
};

const chat = (overrides = {}) => {
  const participants = [...(overrides.participants ?? ['alice', 'bob'])].sort();
  return {
    participants,
    participantIds: Object.fromEntries(participants.map((uid) => [uid, true])),
    name_alice: 'Alice',
    name_bob: 'Bob',
    ...overrides,
    participants,
  };
};

const message = (overrides = {}) => ({
  senderId: 'alice',
  body: 'hello',
  type: 'text',
  idempotencyKey: 'send_12345678',
  createdAt: Timestamp.fromMillis(1760000000000),
  deliveredAt: null,
  readAt: null,
  ...overrides,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: readFileSync('firestore.rules', 'utf8'),
    },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await seedActiveSessions('alice', 'bob', 'mallory', 'charlie');
});

after(async () => {
  await env.cleanup();
});

describe('chat rules', () => {
  test('allow pre-migration Firebase sessions before backend projection exists', async () => {
    await env.clearFirestore();

    await assertSucceeds(setDoc(doc(legacyDb('alice'), 'chats/alice_bob'), chat()));
  });

  test('reject stale Firebase custom-token sessions', async () => {
    const alice = staleDb('alice');

    await assertFails(setDoc(doc(alice, 'chats/alice_bob'), chat()));
  });

  test('allow participants to create a valid chat and reject participant tampering', async () => {
    const alice = db('alice');
    const chatRef = doc(alice, 'chats/alice_bob');

    await assertSucceeds(setDoc(chatRef, chat()));
    await assertFails(updateDoc(chatRef, { participants: ['alice', 'mallory'] }));
    await assertFails(updateDoc(chatRef, { unread_bob: -1 }));
    await assertSucceeds(
      updateDoc(chatRef, {
        lastMessage: 'hello',
        lastMessageAt: Timestamp.fromMillis(1760000001000),
        lastSenderId: 'alice',
        unread_bob: 1,
      }),
    );
  });

  test('allow metadata updates on legacy chats while rejecting new unknown fields', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'chats/alice_bob'), {
        ...chat(),
        createdAt: Timestamp.fromMillis(1750000000000),
        legacyPreviewType: 'text',
      });
    });

    const alice = db('alice');
    const chatRef = doc(alice, 'chats/alice_bob');

    await assertSucceeds(
      updateDoc(chatRef, {
        lastMessage: 'hello again',
        lastMessageAt: Timestamp.fromMillis(1760000001000),
        lastSenderId: 'alice',
        unread_bob: 1,
      }),
    );
    await assertFails(updateDoc(chatRef, { legacyEscalation: true }));
  });

  test('allow inbox conversation list query only for the active participant session', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await Promise.all([
        setDoc(doc(context.firestore(), 'chats/alice_bob'), chat()),
        setDoc(
          doc(context.firestore(), 'chats/alice_charlie'),
          chat({
            participants: ['alice', 'charlie'],
            name_charlie: 'Charlie',
          }),
        ),
      ]);
    });

    const alice = db('alice');
    const staleAlice = staleDb('alice');
    const aliceInbox = query(
      collection(alice, 'chats'),
      where('participantIds.alice', '==', true),
    );

    await assertSucceeds(getDocs(aliceInbox));
    await assertFails(getDocs(collection(alice, 'chats')));
    await assertFails(
      getDocs(
        query(
          collection(staleAlice, 'chats'),
          where('participantIds.alice', '==', true),
        ),
      ),
    );
  });

  test('enforce immutable message bodies and receiver-only receipts', async () => {
    const alice = db('alice');
    const bob = db('bob');

    await assertSucceeds(setDoc(doc(alice, 'chats/alice_bob'), chat()));
    await assertSucceeds(
      setDoc(doc(alice, 'chats/alice_bob/messages/send_12345678'), message()),
    );

    await assertFails(
      updateDoc(doc(bob, 'chats/alice_bob/messages/send_12345678'), {
        body: 'edited by receiver',
      }),
    );
    await assertFails(
      updateDoc(doc(alice, 'chats/alice_bob/messages/send_12345678'), {
        deliveredAt: Timestamp.fromMillis(1760000002000),
      }),
    );
    await assertSucceeds(
      updateDoc(doc(bob, 'chats/alice_bob/messages/send_12345678'), {
        deliveredAt: Timestamp.fromMillis(1760000002000),
        readAt: Timestamp.fromMillis(1760000003000),
      }),
    );
  });

  test('allow atomic image message with caption and inbox metadata', async () => {
    const alice = db('alice');
    const chatRef = doc(alice, 'chats/alice_bob');
    const imageMessageRef = doc(
      alice,
      'chats/alice_bob/messages/image_12345678',
    );
    const batch = writeBatch(alice);

    batch.set(
      chatRef,
      {
        ...chat(),
        lastMessage: 'Photo',
        lastMessageAt: Timestamp.fromMillis(1760000001000),
        lastSenderId: 'alice',
        unread_bob: 1,
      },
      { merge: true },
    );
    batch.set(
      imageMessageRef,
      message({
        body: 'sunset from tonight',
        type: 'image',
        imageUrl:
          'https://firebasestorage.googleapis.com/v0/b/zephyr/o/chats%2Falice_bob%2Falice%2Fimage.jpg?alt=media',
        idempotencyKey: 'image_12345678',
      }),
    );

    await assertSucceeds(batch.commit());
  });

  test('reject malformed image messages and text messages with image URLs', async () => {
    const alice = db('alice');

    await assertSucceeds(setDoc(doc(alice, 'chats/alice_bob'), chat()));
    await assertFails(
      setDoc(
        doc(alice, 'chats/alice_bob/messages/image_missing_url'),
        message({
          type: 'image',
          idempotencyKey: 'image_missing_url',
        }),
      ),
    );
    await assertFails(
      setDoc(
        doc(alice, 'chats/alice_bob/messages/image_null_url'),
        message({
          type: 'image',
          imageUrl: null,
          idempotencyKey: 'image_null_url',
        }),
      ),
    );
    await assertFails(
      setDoc(
        doc(alice, 'chats/alice_bob/messages/text_with_url'),
        message({
          imageUrl:
            'https://firebasestorage.googleapis.com/v0/b/zephyr/o/chats%2Falice_bob%2Falice%2Fimage.jpg?alt=media',
          idempotencyKey: 'text_with_url',
        }),
      ),
    );
  });

  test('deny client-forged gift messages while allowing receiver receipts', async () => {
    const alice = db('alice');
    const bob = db('bob');
    const giftMessageRef = doc(
      bob,
      'chats/alice_bob/messages/33333333-3333-4333-8333-333333333333',
    );

    await assertSucceeds(setDoc(doc(alice, 'chats/alice_bob'), chat()));
    await assertFails(
      setDoc(
        doc(alice, 'chats/alice_bob/messages/gift_12345678'),
        message({
          body: 'Rose',
          type: 'gift',
          idempotencyKey: 'gift_12345678',
          giftEventId: '33333333-3333-4333-8333-333333333333',
          giftId: 'rose',
          giftName: 'Rose',
          giftThumbnailUrl: 'https://cdn.example.test/gifts/rose/thumb.webp',
          giftCoinCost: 10,
          giftQuantity: 1,
          giftTotalCoins: 10,
        }),
      ),
    );

    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(
          context.firestore(),
          'chats/alice_bob/messages/33333333-3333-4333-8333-333333333333',
        ),
        {
          senderId: 'alice',
          receiverId: 'bob',
          body: 'Rose',
          type: 'gift',
          giftEventId: '33333333-3333-4333-8333-333333333333',
          giftId: 'rose',
          giftName: 'Rose',
          giftThumbnailUrl: 'https://cdn.example.test/gifts/rose/thumb.webp',
          giftAnimationUrl:
            'https://cdn.example.test/gifts/rose/animation.lottie',
          giftAnimationType: 'lottie',
          giftTier: 'small',
          giftCoinCost: 10,
          giftQuantity: 1,
          giftTotalCoins: 10,
          idempotencyKey: 'gift_12345678',
          createdAt: Timestamp.fromMillis(1760000001000),
          deliveredAt: null,
          readAt: null,
        },
      );
    });

    await assertSucceeds(
      updateDoc(giftMessageRef, {
        deliveredAt: Timestamp.fromMillis(1760000002000),
        readAt: Timestamp.fromMillis(1760000003000),
      }),
    );
    await assertFails(
      updateDoc(
        doc(
          alice,
          'chats/alice_bob/messages/33333333-3333-4333-8333-333333333333',
        ),
        {
          deletedFor: 'all',
          body: '',
          imageUrl: null,
          type: 'deleted',
        },
      ),
    );
  });

  test('allow receiver receipts on legacy messages with unchanged extra fields', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'chats/alice_bob'), chat());
      await setDoc(
        doc(context.firestore(), 'chats/alice_bob/messages/send_legacy'),
        {
          ...message({ idempotencyKey: 'send_legacy_1234' }),
          status: 'sent',
          clientCreatedAt: 1750000000000,
        },
      );
    });

    const bob = db('bob');
    await assertSucceeds(
      updateDoc(doc(bob, 'chats/alice_bob/messages/send_legacy'), {
        deliveredAt: Timestamp.fromMillis(1760000002000),
      }),
    );
    await assertFails(
      updateDoc(doc(bob, 'chats/alice_bob/messages/send_legacy'), {
        status: 'edited',
      }),
    );
  });

  test('allow constrained deletes only for the owner intent', async () => {
    const alice = db('alice');
    const bob = db('bob');

    await assertSucceeds(setDoc(doc(alice, 'chats/alice_bob'), chat()));
    await assertSucceeds(
      setDoc(doc(alice, 'chats/alice_bob/messages/send_12345678'), message()),
    );

    await assertSucceeds(
      updateDoc(doc(bob, 'chats/alice_bob/messages/send_12345678'), {
        deletedFor: ['bob'],
      }),
    );
    await assertFails(
      updateDoc(doc(bob, 'chats/alice_bob/messages/send_12345678'), {
        deletedFor: 'all',
        body: '',
        imageUrl: null,
        type: 'deleted',
      }),
    );
    await assertSucceeds(
      updateDoc(doc(alice, 'chats/alice_bob/messages/send_12345678'), {
        deletedFor: 'all',
        body: '',
        imageUrl: null,
        type: 'deleted',
      }),
    );
  });

  test('backend block projection prevents new chat writes and message sends', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'blocks/alice_bob'), {
        blockedBy: 'alice',
        blockedUser: 'bob',
        createdAt: Timestamp.fromMillis(1760000000000),
      });
    });

    const alice = db('alice');
    await assertFails(setDoc(doc(alice, 'chats/alice_bob'), chat()));

    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'chats/alice_bob'), chat());
    });

    await assertFails(
      setDoc(doc(alice, 'chats/alice_bob/messages/send_12345678'), message()),
    );

    await assertSucceeds(getDoc(doc(alice, 'blocks/alice_bob')));
  });
});
