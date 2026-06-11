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
  console.log(`Running smoke test against ${baseUrl}`);

  const live = await request('/v1/health/live', { method: 'GET' });
  const ready = await request('/v1/health/ready', { method: 'GET' });
  const rooms = await request('/v1/rooms', { method: 'GET' });

  console.log('Public smoke summary:');
  console.log(`- live status: ${live.status}`);
  console.log(`- ready storage: ${ready.storage}`);
  console.log(`- public live rooms: ${rooms.length}`);

  if (!accessToken) {
    console.log(
      'Authenticated smoke skipped: set ZEPHYR_SMOKE_ACCESS_TOKEN from a real OAuth login to include /users/me.',
    );
    console.log('Smoke test passed ✅');
    return;
  }

  const authHeader = { authorization: `Bearer ${accessToken}` };

  const me = await request('/v1/users/me', {
    method: 'GET',
    headers: authHeader,
  });

  console.log('Authenticated smoke summary:');
  console.log(`- user: ${me.id} (${me.displayName})`);

  if (!shouldCreateRoom) {
    console.log(
      'Room mutation skipped: set ZEPHYR_SMOKE_CREATE_ROOM=true to create/join a room with the supplied token.',
    );
    console.log('Smoke test passed ✅');
    return;
  }

  const room = await request('/v1/rooms', {
    method: 'POST',
    headers: authHeader,
    body: JSON.stringify({ title: 'Smoke Room' }),
  });

  const listBeforeJoin = await request('/v1/rooms', { method: 'GET' });

  const joined = await request(`/v1/rooms/${room.id}/join`, {
    method: 'POST',
    headers: authHeader,
  });

  const listAfterJoin = await request('/v1/rooms', { method: 'GET' });

  console.log('Room mutation smoke summary:');
  console.log(`- room: ${room.id}`);
  console.log(`- rooms before join: ${listBeforeJoin.length}`);
  console.log(`- rooms after join: ${listAfterJoin.length}`);
  console.log(`- joined audience count: ${joined.audienceCount}`);
  console.log('Smoke test passed ✅');
}

main().catch((error) => {
  console.error('Smoke test failed ❌');
  console.error(error);
  process.exit(1);
});
