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
  console.log(`Running DB smoke test against ${baseUrl}`);

  const ready = await request('/v1/health/ready', { method: 'GET' });
  if (ready.storage !== 'postgres') {
    throw new Error(
      `Expected postgres storage mode, received: ${ready.storage}. Set DATABASE_URL first.`,
    );
  }

  const login = await request('/v1/auth/guest-login', {
    method: 'POST',
    body: JSON.stringify({ displayName: 'db-smoke' }),
  });

  const token = login.accessToken;
  const authHeader = { authorization: `Bearer ${token}` };

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