# Zephyr API Deploy Checklist

Lean production checklist for Zephyr MVP.

## 0) Deployment target

- Primary: Render Web Service + managed Postgres
- Blueprint file already added: `render.yaml` at repo root

## 1) Required environment variables

- `PORT` (platform usually injects this)
- `DATABASE_URL`
- `JWT_SECRET`
- `CORS_ORIGINS` (comma-separated allowed frontend origins)
- `DB_SSL=true` (if your managed Postgres requires SSL)
- `NODE_ENV=production`

Example for staging:

- `CORS_ORIGINS=https://your-staging-mobile-web-host.com`

## 2) Pre-deploy validation

Run from repo root:

```bash
cd /Users/wolf/dev/zephyr
pnpm install
pnpm --filter zephyr-api test
pnpm --filter zephyr-api build
```

## 3) Render setup

1. Push current branch to GitHub.
2. In Render, create a new Blueprint from your repo.
3. Render detects `render.yaml` and creates service `zephyr-api`.
4. Set secret env values:
	- `JWT_SECRET`
	- `DATABASE_URL` (Render Postgres internal URL)
	- `CORS_ORIGINS` (only your trusted origins)
5. Trigger deploy.

## 4) Start command (already in blueprint)

```bash
pnpm --filter zephyr-api start:prod
```

## 5) Post-deploy smoke test

Run locally against deployed URL:

```bash
cd /Users/wolf/dev/zephyr/services/zephyr-api
BASE_URL=https://your-api-domain.com node scripts/smoke.mjs
```

## 6) Rollback readiness

- Keep previous deployment artifact/version available.
- If smoke fails, roll back immediately.
- Confirm `/v1/auth/guest-login` and `/v1/rooms` recovery before reopening traffic.

## 7) Mobile switch

Use deployed API URL in Flutter build:

```bash
cd /Users/wolf/dev/zephyr/apps/zephyr-mobile
flutter run --dart-define=API_BASE_URL=https://your-api-domain.com
```

## 8) Security baseline for internet exposure

- Use a strong random `JWT_SECRET` (at least 32 chars)
- Keep `CORS_ORIGINS` strict; do not use `*`
- Keep Render service visibility private to repo/team maintainers
- Rotate secrets if shared accidentally
