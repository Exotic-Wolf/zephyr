# zephyr-api

NestJS backend for Zephyr MVP.

## Current MVP endpoints

- `GET /v1/health/live`
- `GET /v1/health/ready`
- `POST /v1/auth/guest-login`
- `POST /v1/auth/google-login`
- `POST /v1/auth/apple-login`
- `GET /v1/users/me`
- `PATCH /v1/users/me`
- `GET /v1/rooms`
- `POST /v1/rooms`
- `POST /v1/rooms/:roomId/join`

API contract source: `../../packages/zephyr-contracts/openapi.yaml`

## Local run

```bash
pnpm install
pnpm start:dev
```

Default URL: `http://localhost:3000`

## Local Postgres quickstart

Run local Postgres with Docker:

```bash
pnpm db:up
```

Run API against local Postgres:

```bash
pnpm start:dev:localdb
```

Stop local Postgres:

```bash
pnpm db:down
```

## Database configuration

By default, the service uses an in-memory fallback store.

To enable Postgres persistence, set:

- `DATABASE_URL` (required)
- `DB_SSL=true` (optional for managed Postgres that requires SSL)
- `JWT_SECRET` (required in production, optional in local dev)
- `GOOGLE_CLIENT_ID` (single Google client ID)
- `GOOGLE_CLIENT_IDS` (comma-separated Google client IDs for multi-platform apps)
- `APPLE_CLIENT_ID` (required to verify Apple ID tokens)

Example:

```bash
export DATABASE_URL=postgres://postgres:postgres@localhost:5432/zephyr
export JWT_SECRET=replace-with-a-strong-secret
export GOOGLE_CLIENT_IDS=your-ios-client-id.apps.googleusercontent.com,your-android-client-id.apps.googleusercontent.com
export APPLE_CLIENT_ID=com.zephyr.zephyrMobile
pnpm start:dev
```

If both variables are set, `GOOGLE_CLIENT_IDS` is used.

When Postgres is enabled, tables (`users`, `sessions`, `rooms`) are auto-created on startup.

## Security defaults

- Global DTO validation enabled (`whitelist`, `forbidNonWhitelisted`)
- Global rate limiting enabled (default: `120` requests per `60` seconds per IP)
- Unified JSON error envelope returned for all failed requests

## Test and build

```bash
pnpm test
pnpm build
pnpm smoke
pnpm smoke:db
```

Run smoke against another URL:

```bash
BASE_URL=https://your-api-domain.com pnpm smoke
```

## Quick smoke flow

1. Call `POST /v1/auth/guest-login` and copy `accessToken`
2. Use header `Authorization: Bearer <accessToken>`
3. Call `POST /v1/rooms` with `{ "title": "My Room" }`
4. Call `GET /v1/rooms`
