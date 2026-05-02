# README_AI

This file is a handoff snapshot so we can resume Zephyr quickly in the next session.

## Product aim

- Build a **minimal Chamet-like MVP** in Flutter + NestJS.
- Ship fast with strong backend direction (contract-first, test-backed, scalable).
- Budget now: **$50–$100/month**, scale infra spending after revenue.

## Current architecture

- Monorepo root: `/Users/wolf/dev/zephyr`
- Mobile app: `apps/zephyr-mobile` (Flutter)
- Backend API: `services/zephyr-api` (NestJS)
- API contract: `packages/zephyr-contracts/openapi.yaml`
- Deploy prep: `render.yaml`, `docs/api/deploy-checklist.md`

## Current status (as of 2 May 2026, latest update)

### Staging deployment status (newest)

- Render staging API is live at: `https://zephyr-api-wr1s.onrender.com`
- Verified health endpoints:
   - `GET /v1/health/live` → `HTTP 200`
   - `GET /v1/health/ready` → `HTTP 200`
- Mobile app is wired to live staging API:
   - `apps/zephyr-mobile/lib/main.dart` default `API_BASE_URL` now points to `https://zephyr-api-wr1s.onrender.com`
- iOS simulator run against staging is validated (API badge green, feed/room flow visible)

### Auth rollout decision (latest)

- **Launch auth now**: `Guest + Google`
- **Apple auth**: deferred until Apple Developer payment/account is active (`$99/year`, billed annually)
- **Important**: existing auth architecture is reusable; Apple can be enabled later without reworking core session/user flow

### Local workflow shortcuts (new)

Added root-level facilitation scripts in `/Users/wolf/dev/zephyr/package.json`:

- `pnpm run dev:status` → compact readiness snapshot (tools, docker/postgres, API storage mode, devices)
- `pnpm run dev:doctor` → verifies local readiness (pnpm, docker, flutter, pod, API health)
- `pnpm run dev:api:db:up` → starts local Postgres container
- `pnpm run dev:api` → starts API in localdb mode
- `pnpm run dev:api:health` → checks readiness endpoint
- `pnpm run dev:mobile:pods` → runs iOS `pod install` with correct Ruby gem PATH
- `pnpm run dev:mobile:android` → launches Flutter app with local API URL (Android target selection via Flutter)
- `pnpm run dev:mobile:ios` → launches Flutter app with local API URL
- `pnpm run dev:all:android` → one-command orchestrator for DB + API + Android run
- `pnpm run dev:all:ios` → one-command orchestrator for DB + API + (optional) pods + iOS run

`dev:all:ios` optional env vars:

- `IOS_DEVICE_ID=<simulator-id>` choose explicit iOS simulator/device
- `SKIP_PODS=1` skip `pod install`
- `KEEP_API=1` keep API alive after Flutter exits
- `API_BASE_URL=http://localhost:3000` override API URL

Status commands validated:

- `pnpm run dev:status` passes and reports Docker/Postgres/API/device readiness
- `pnpm run dev:doctor` passes on current machine
- `pnpm run dev:all:ios` launches simulator flow successfully

`dev:all:android` optional env vars:

- `ANDROID_DEVICE_ID=<emulator-or-device-id>` choose explicit Android device/emulator
- `KEEP_API=1` keep API alive after Flutter exits
- `API_BASE_URL=http://localhost:3000` override API URL

### Backend

Implemented endpoints:

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
- `GET /v1/feed/live`

Recent backend validation additions:

- E2E coverage for feed route in `services/zephyr-api/test/app.e2e-spec.ts`:
   - unauthenticated `GET /v1/feed/live` returns `401`
   - authenticated feed fetch returns room cards after room creation

Backend hardening completed:

- JWT session tokens
- DTO validation
- Rate limiting (`@nestjs/throttler`)
- Unified error response filter
- Smoke test script: `services/zephyr-api/scripts/smoke.mjs`
- DB smoke test script: `services/zephyr-api/scripts/smoke-db.mjs`

Persistence state:

- Postgres integration exists in code (`DatabaseService`, schema auto-create)
- If `DATABASE_URL` is missing, API falls back to in-memory storage
- Local Postgres workflow added:
   - `services/zephyr-api/docker-compose.postgres.yml`
   - scripts: `pnpm db:up`, `pnpm db:down`, `pnpm start:dev:localdb`

### Frontend

Implemented onboarding/auth options:

- Guest login
- Continue with Google
- Continue with Apple

Current validated runtime:

- Google login is confirmed working end-to-end on iOS simulator (login succeeds and lands in app)

Implemented app flow:

- Fetch profile
- Swipe live feed cards (`/v1/feed/live`)
- Create room
- Enter/join room from swipe card CTA

Recent UI/dev productivity additions:

- Onboarding now shows API status badge (`Checking API...`, `API Connected`, `API Offline`) + manual refresh icon
- Home app bar now shows compact API chip (`API...`, `API ✓`, `API ✕`) and refresh updates both feed + API status

Tablet responsiveness status:

- Initial responsive pass is implemented (breakpoint-based layout, centered max width, tablet-friendly feed presentation)
- Deep tablet UX optimization (split-pane/details-heavy layout) is intentionally deferred to a later iteration

## What is validated

- `zephyr-api`: tests and build pass
- `zephyr-mobile`: `flutter test` and `flutter analyze` pass
- `zephyr-api`: `test:e2e` includes feed endpoint coverage and passes
- Local smoke flow has passed against running API
- iOS simulator run confirmed
- Root facilitation commands validated (`dev:status`, `dev:doctor`, `dev:api:health`)

## Important runtime/config notes

- Running `pnpm start` from monorepo root fails (no root start script)
- Use package-scoped commands for backend
- Frequent local issue seen during iteration: app shows `SocketException ... Connection refused` when API process is not running/listening on `:3000`
- `pnpm db:up` only starts Postgres; it does **not** start Nest API (must run API command separately or use `dev:all:ios`)
- Google and Apple login code is implemented, but real sign-in requires provider config
- Apple Sign-In production setup requires paid Apple Developer enrollment

Required env vars (backend):

- `JWT_SECRET`
- `DATABASE_URL` (for persistence)
- `GOOGLE_CLIENT_ID` (single Google audience)
- `GOOGLE_CLIENT_IDS` (comma-separated Google audiences for iOS + Android)
- `APPLE_CLIENT_ID` (for Apple ID token verification)

Staging env vars currently required on Render (`zephyr-api`):

- `JWT_SECRET`
- `DATABASE_URL`
- `CORS_ORIGINS`
- `GOOGLE_CLIENT_IDS` (required for Google login on staging)

## Resume plan (next session)

1. Keep shipping with `Guest + Google` auth while Apple enrollment is pending
2. Confirm `GOOGLE_CLIENT_IDS` is set on Render and validate Google login on staging end-to-end
3. Keep Flutter pointed to staging API and run smoke checks
4. Add next MVP features after staging is stable (realtime room events/chat + moderation baseline)
5. After Apple Developer payment: enable Sign in with Apple capability + validate end-to-end

## Verified command patterns

Top-tier root flow (recommended):

```bash
cd /Users/wolf/dev/zephyr
pnpm run dev:status
pnpm run dev:all:ios
```

Backend (recommended):

```bash
cd /Users/wolf/dev/zephyr/services/zephyr-api
JWT_SECRET=dev-secret pnpm start:dev
```

Backend with local Postgres:

```bash
cd /Users/wolf/dev/zephyr/services/zephyr-api
pnpm db:up
pnpm start:dev:localdb
```

Backend tests/build:

```bash
cd /Users/wolf/dev/zephyr/services/zephyr-api
pnpm test
pnpm build
```

Smoke test:

```bash
cd /Users/wolf/dev/zephyr/services/zephyr-api
BASE_URL=http://localhost:3000 pnpm smoke
```

DB smoke test (requires Postgres mode):

```bash
cd /Users/wolf/dev/zephyr/services/zephyr-api
BASE_URL=http://localhost:3000 pnpm smoke:db
```

Flutter run (iOS simulator):

```bash
cd /Users/wolf/dev/zephyr/apps/zephyr-mobile
flutter emulators --launch apple_ios_simulator
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

Flutter run (iOS simulator against staging):

```bash
cd /Users/wolf/dev/zephyr/apps/zephyr-mobile
flutter emulators --launch apple_ios_simulator
flutter run --dart-define=API_BASE_URL=https://zephyr-api-wr1s.onrender.com
```

## Quick prompt to continue tomorrow

"Continue Zephyr from `README_AI.md`. First re-verify backend + Flutter health, then complete auth provider setup and persistent DB validation."