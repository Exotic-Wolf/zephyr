import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

const projectId = 'zephyr-storage-rules-test';
let env;

const storage = (uid) => env.authenticatedContext(uid).storage();
const objectRef = (uid, path) => storage(uid).ref(path);

const imageBytes = new Uint8Array([0x89, 0x50, 0x4e, 0x47]);

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    storage: {
      host: '127.0.0.1',
      port: 9199,
      rules: readFileSync('storage.rules', 'utf8'),
    },
  });
});

beforeEach(async () => {
  await env.clearStorage();
});

after(async () => {
  await env.cleanup();
});

describe('chat image storage rules', () => {
  test('allow participant owner upload/read and reject outsiders', async () => {
    const path = 'chats/alice_bob/alice/pic.png';

    await assertSucceeds(
      objectRef('alice', path).put(imageBytes, { contentType: 'image/png' }),
    );
    await assertSucceeds(objectRef('bob', path).getMetadata());
    await assertFails(objectRef('mallory', path).getMetadata());
  });

  test('reject wrong uploader, non-image payloads, oversize files, and mutation', async () => {
    const path = 'chats/alice_bob/alice/immutable.png';

    await assertFails(
      objectRef('bob', 'chats/alice_bob/alice/wrong-uploader.png').put(
        imageBytes,
        { contentType: 'image/png' },
      ),
    );
    await assertFails(
      objectRef('alice', 'chats/alice_bob/alice/not-image.txt').put(
        imageBytes,
        { contentType: 'text/plain' },
      ),
    );
    await assertFails(
      objectRef('alice', 'chats/alice_bob/alice/too-large.png').put(
        new Uint8Array(5 * 1024 * 1024),
        { contentType: 'image/png' },
      ),
    );

    await assertSucceeds(
      objectRef('alice', path).put(imageBytes, { contentType: 'image/png' }),
    );
    await assertFails(
      objectRef('alice', path).put(imageBytes, { contentType: 'image/png' }),
    );
    await assertFails(objectRef('alice', path).delete());
  });
});
