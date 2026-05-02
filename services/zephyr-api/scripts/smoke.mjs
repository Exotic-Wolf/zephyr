const baseUrl = process.env.BASE_URL ?? 'http://localhost:3000';

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

  const login = await request('/v1/auth/guest-login', {
    method: 'POST',
    body: JSON.stringify({ displayName: 'wolf-smoke' }),
  });

  const token = login.accessToken;
  const authHeader = { authorization: `Bearer ${token}` };

  const me = await request('/v1/users/me', {
    method: 'GET',
    headers: authHeader,
  });

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

  console.log('Smoke summary:');
  console.log(`- user: ${me.id} (${me.displayName})`);
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