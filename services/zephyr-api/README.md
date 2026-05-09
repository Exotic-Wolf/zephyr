# zephyr-api

NestJS backend for Zephyr — a live streaming platform inspired by Olamet/Chamet.

## Current endpoints

### Health
- `GET /v1/health/live`
- `GET /v1/health/ready`

### Auth
- `POST /v1/auth/guest-login`
- `POST /v1/auth/google-login`
- `POST /v1/auth/apple-login`

### Users
- `GET /v1/users/me`
- `PATCH /v1/users/me`
- `GET /v1/users/me/following`

### Rooms
- `GET /v1/rooms`
- `POST /v1/rooms`
- `POST /v1/rooms/:roomId/join`
- `DELETE /v1/rooms/:roomId`

### Feed
- `GET /v1/feed/live`

### Economy
- `GET /v1/economy/wallet`
- `GET /v1/economy/coin-packs`
- `POST /v1/economy/purchase-coins`
- `GET /v1/economy/private-call/quote`
- `POST /v1/economy/calls/start`
- `POST /v1/economy/calls/:id/tick`
- `POST /v1/economy/calls/:id/end`
- `POST /v1/economy/calls/:id/rtc-token`

API contract source: `../../packages/zephyr-contracts/openapi.yaml`

## Economy constants

| | |
|---|---|
| ~5,500 coins | = $1 USD |
| Host share (`RECEIVER_SHARE_BPS`) | 6000 (60%) |
| Platform cut | 40% |

### Coin packs
| Pack | Coins | Price |
|---|---|---|
| pack_299 | 16,500 | $2.99 |
| pack_999 | 55,000 | $9.99 |
| pack_2999 | 165,000 | $29.99 |
| pack_9999 | 550,000 | $99.99 |

### Call rate tiers
| Level | Coins/min | Sparks/min (host) |
|---|---|---|
| ≤Lv3 | 2,100 | 1,260 |
| Lv4 | 3,200 | 1,920 |
| Lv5 | 4,200 | 2,520 |
| Lv6 | 5,400 | 3,240 |
| Lv7 | 6,400 | 3,840 |
| Lv8 | 8,000 | 4,800 |
| Lv9+ | 27,000 | 16,200 |

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
- `DIRECT_CALL_ALLOWED_RATES` (comma-separated coins/min tiers, default: `2100,3200,4200,5400,6400,8000,27000`)

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
