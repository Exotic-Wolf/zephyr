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

## Current status (as of 3 May 2026, latest update)

### Auth milestone completed (3 May 2026)

- ✅ Google login now works end-to-end on both Android emulator and iOS simulator against staging.
- ✅ iOS flow still works after Android auth fixes (no regression).
- ✅ Backend Google audience allowlist now includes iOS + Android + Web OAuth client IDs.
- ✅ Mobile app now requests Google ID tokens with `GOOGLE_SERVER_CLIENT_ID` (Web client ID) via `--dart-define`.
- ✅ Latest auth fix commit is on `main`: `de008ac4`.

Key OAuth IDs used in this session:

- iOS Google client ID: `724639603736-n8v2kjqfg40l7bqkt26kov8cmofhn2db.apps.googleusercontent.com`
- Android Google client ID: `724639603736-08tovsj719dsb6atip932tqo1jg0gtl2.apps.googleusercontent.com`
- Web Google client ID (used as `GOOGLE_SERVER_CLIENT_ID`): `724639603736-f7v5k8112bjpfaq2igjm0b5fndlm8vc8.apps.googleusercontent.com`

Security note:

- A Web OAuth client secret was exposed during interactive setup. Rotate/regenerate that secret in Google Cloud before production rollout.

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

- Google login is confirmed working end-to-end on iOS simulator and Android emulator (login succeeds and lands in app)

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
- Google provider config is completed for staging (iOS + Android + Web audience alignment)
- Mobile Google sign-in requires `GOOGLE_SERVER_CLIENT_ID` (Web OAuth client ID) when launching Flutter app
- Apple Sign-In production setup requires paid Apple Developer enrollment

Required env vars (backend):

- `JWT_SECRET`
- `DATABASE_URL` (for persistence)
- `GOOGLE_CLIENT_ID` (legacy/single audience, optional when `GOOGLE_CLIENT_IDS` is used)
- `GOOGLE_CLIENT_IDS` (comma-separated Google audiences for iOS + Android)
- `APPLE_CLIENT_ID` (for Apple ID token verification)

Staging env vars currently required on Render (`zephyr-api`):

- `JWT_SECRET`
- `DATABASE_URL`
- `CORS_ORIGINS`
- `GOOGLE_CLIENT_IDS` (required for Google login on staging; currently iOS + Android + Web IDs)

## Resume plan (next session)

1. Start from current stable auth baseline (Guest + Google verified on iOS/Android)
2. Keep Flutter pointed to staging API and run quick smoke checks
3. Begin next MVP feature: realtime room/feed updates
4. Add moderation baseline after realtime path is stable
5. Rotate exposed Web OAuth client secret in Google Cloud as security cleanup

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

"Continue Zephyr from `README_AI.md`. Keep current auth baseline, re-run quick staging smoke, then implement realtime room/feed updates."