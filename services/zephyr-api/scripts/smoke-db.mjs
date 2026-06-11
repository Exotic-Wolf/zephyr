const baseUrl = process.env.BASE_URL ?? 'http://localhost:3000';
const accessToken =
  process.env.ZEPHYR_SMOKE_ACCESS_TOKEN ?? process.env.SMOKE_ACCESS_TOKEN;
const shouldCreateRoom = process.env.ZEPHYR_SMOKE_CREATE_ROOM === 'true';

async function request(path, options = {}) {
  const response = await fetch(`${baseUrl}${path}`, {
    ...options,
    headers: {
      'content-type': 'application/json',
      ...(options.headers ?? {}),
    },
  });

  const text = await response.text();
  const body = text ? JSON.parse(text) : null;

  if (!response.ok) {
    throw new Error(`Request failed ${response.status} ${path}: ${text}`);
  }

  return body;
}

async function main() {
  console.log(`Running DB smoke test against ${baseUrl}`);

  const ready = await request('/v1/health/ready', { method: 'GET' });
  if (ready.storage !== 'postgres') {
    throw new Error(
      `Expected postgres storage mode, received: ${ready.storage}. Set DATABASE_URL first.`,
    );
  }

  const listedBeforeAuth = await request('/v1/rooms', { method: 'GET' });
  console.log(
    `DB-backed public room list returned ${listedBeforeAuth.length} rooms.`,
  );

  if (!accessToken) {
    console.log(
      'Authenticated DB smoke skipped: set ZEPHYR_SMOKE_ACCESS_TOKEN from a real OAuth login to include /users/me or room mutations.',
    );
    console.log('DB smoke test passed ✅');
    return;
  }

  const authHeader = { authorization: `Bearer ${accessToken}` };
  const me = await request('/v1/users/me', {
    method: 'GET',
    headers: authHeader,
  });
  console.log(`Authenticated DB smoke user: ${me.id} (${me.displayName})`);

  if (!shouldCreateRoom) {
    console.log(
      'Room mutation skipped: set ZEPHYR_SMOKE_CREATE_ROOM=true to create/list a room with the supplied token.',
    );
    console.log('DB smoke test passed ✅');
    return;
  }

  const room = await request('/v1/rooms', {
    method: 'POST',
    headers: authHeader,
    body: JSON.stringify({ title: 'DB Smoke Room' }),
  });

  const listed = await request('/v1/rooms', { method: 'GET' });
  const foundRoom = listed.find((item) => item.id === room.id);
  if (!foundRoom) {
    throw new Error('Created room was not returned by room listing.');
  }

  console.log('DB smoke test passed ✅');
}

main().catch((error) => {
  console.error('DB smoke test failed ❌');
  console.error(error);
  process.exit(1);
});
