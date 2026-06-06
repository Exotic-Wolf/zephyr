import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const projectId = 'zephyr-firestore-rules-test';
let env;

const db = (uid) => env.authenticatedContext(uid).firestore();

const chat = (overrides = {}) => ({
  participants: ['alice', 'bob'],
  name_alice: 'Alice',
  name_bob: 'Bob',
  ...overrides,
});

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
});

after(async () => {
  await env.cleanup();
});

describe('chat rules', () => {
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
