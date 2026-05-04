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

## Current status (as of 4 May 2026, latest update)

### UI shell + profile milestone completed (4 May 2026)

- ✅ Added post-login bottom navigation with 5 tabs: `Home`, `Live Rooms`, `Go Live`, `Inbox`, `Me`.
- ✅ Kept existing home/feed/create/join flow fully functional under `Home`.
- ✅ Apple sign-in button is now iOS-only (hidden on Android).
- ✅ Added `Me` menu with pages for `Level`, `My Balance`, `My Revenue`, `Settings`.

### Economy/call billing milestone completed (4 May 2026)

- ✅ Backend economy module scaffolded and wired into app module.
- ✅ New economy endpoints are live in code:
   - `GET /v1/economy/config`
   - `GET /v1/economy/coin-packs`
   - `GET /v1/economy/wallet`
   - `POST /v1/economy/purchase-coins`
   - `GET /v1/economy/private-call/quote?minutes=`
   - `GET /v1/economy/gifts/catalog`
- ✅ Store layer now supports economy config + wallet summary + coin purchases + gift catalog + private-call quote.
- ✅ Postgres schema now includes economy tables:
   - `wallets`
   - `user_revenue`
   - `wallet_transactions`
- ✅ Mobile app now consumes economy APIs for wallet and coin-pack retrieval, and buy-coin actions.
- ✅ Coin-pack pricing ladder is finalized in staging env and backend defaults:
    - `$2.99` → `16,500`
    - `$5.99` → `33,000`
    - `$9.99` → `55,000`
    - `$29.99` → `165,000`
    - `$59.99` → `330,000`
    - `$99.99` → `550,000`
- ✅ Call pricing modes are now configured and deployed:
    - Direct call tier options: `2100`, `4200`, `8400` coins/min
    - Random call: `600` coins/min
- ✅ Mobile `Go Live` tab now calls quote endpoint and renders live pricing (mode, rate/min, total coins, balance guard).
- ✅ Call billing lifecycle scaffold is now implemented in backend and wired in mobile:
   - `start` call session
   - periodic `tick` billing (coin deduction + ledger write)
   - `end` session (manual/insufficient balance)
- ✅ Receiver earnings are Spark-first:
   - caller spends coins
   - receiver earns Spark (`spark_balance`) and revenue USD tracking
   - receiver does not receive spendable coin wallet credit from call ticks
- ✅ One-live-call busy guard is now enforced:
   - a user can be both caller and receiver across the product
   - but cannot be in more than one live call at a time
   - start is rejected when caller or receiver is already in a live call
- ✅ Locked economics defaults in backend config:
   - `COINS_PER_USD_RECEIVER=10000`
   - `RECEIVER_SHARE_BPS=6000`
   - `SPARK_PER_USD=10000` (neutral/no inflation default)
- 🔄 Remaining work is now downstream economy features (gift execution, cashout/redeem flow, payout operations), not core call billing.

### Staging smoke validation completed (4 May 2026)

- ✅ `GET /v1/economy/private-call/quote?minutes=2&mode=direct&rateCoinsPerMinute=4200`
   - response `requiredCoins=8400`, `HTTP 200`
- ✅ `GET /v1/economy/private-call/quote?minutes=2&mode=random`
   - response `requiredCoins=1200`, `HTTP 200`
- ✅ Auth wallet purchase flow on staging:
   - wallet before: `1200`
   - purchase `pack_299`: success `HTTP 201`
   - wallet after: `17700`
- ✅ Call lifecycle smoke passed after redeploy (`start` → `tick` → `end`) with expected charging math.

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
- `GET /v1/economy/config`
- `GET /v1/economy/coin-packs`
- `GET /v1/economy/wallet`
- `POST /v1/economy/purchase-coins`
- `GET /v1/economy/private-call/quote`
- `GET /v1/economy/gifts/catalog`
- `POST /v1/economy/calls/start`
- `POST /v1/economy/calls/:sessionId/tick`
- `POST /v1/economy/calls/:sessionId/end`

Recent backend validation additions:

- E2E coverage for feed route in `services/zephyr-api/test/app.e2e-spec.ts`:
   - unauthenticated `GET /v1/feed/live` returns `401`
   - authenticated feed fetch returns room cards after room creation
- Unit coverage for call economics/state in `services/zephyr-api/src/core/store.service.spec.ts` now includes:
   - same user can act as both caller and receiver
   - caller coin deduction + receiver Spark accrual
   - busy caller cannot start a second live call
   - busy receiver cannot be called by another user

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
- `zephyr-api`: focused `store.service.spec.ts` passes (`8` tests), including busy-state and Spark earning behavior
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
- Call session concurrency rule is enforced backend-side: one user can only participate in one live call at a time

Required env vars (backend):

- `JWT_SECRET`
- `DATABASE_URL` (for persistence)
- `GOOGLE_CLIENT_ID` (legacy/single audience, optional when `GOOGLE_CLIENT_IDS` is used)
- `GOOGLE_CLIENT_IDS` (comma-separated Google audiences for iOS + Android)
- `APPLE_CLIENT_ID` (for Apple ID token verification)

Optional economy env vars (backend, scaffold knobs):

- `COIN_PACKS_JSON` (JSON array of packs: `[{"id":"pack_299","label":"16.5K","coins":16500,"priceUsd":2.99},{"id":"pack_599","label":"33K","coins":33000,"priceUsd":5.99},{"id":"pack_999","label":"55K","coins":55000,"priceUsd":9.99},{"id":"pack_2999","label":"165K","coins":165000,"priceUsd":29.99},{"id":"pack_5999","label":"330K","coins":330000,"priceUsd":59.99},{"id":"pack_9999","label":"550K","coins":550000,"priceUsd":99.99}]`)
- `DIRECT_CALL_ALLOWED_RATES_COINS_PER_MINUTE` (comma-separated, default: `2100,4200,8400`)
- `DEFAULT_DIRECT_CALL_RATE_COINS_PER_MINUTE` (default: first direct tier, typically `2100`)
- `RANDOM_CALL_RATE_COINS_PER_MINUTE` (default: `600`)
- `COINS_PER_USD_RECEIVER` (default: `10000`)
- `RECEIVER_SHARE_BPS` (default: `6000` = 60%)
- `SPARK_PER_USD` (default: `10000`)
- `GIFT_PLATFORM_FEE_BPS` (default scaffold: `3000` = 30%)

Call quote behavior (current scaffold):

- Direct user-to-user call uses receiver-selected rate tier (`2100`, `4200`, or `8400` by default)
- Random call uses fixed rate (`600` by default)
- Quote endpoint supports mode and optional direct tier override:
   - `GET /v1/economy/private-call/quote?minutes=2&mode=direct&rateCoinsPerMinute=4200`
   - `GET /v1/economy/private-call/quote?minutes=2&mode=random`

Render env values currently used for call pricing:

- `DIRECT_CALL_ALLOWED_RATES_COINS_PER_MINUTE=2100,4200,8400`
- `DEFAULT_DIRECT_CALL_RATE_COINS_PER_MINUTE=2100`
- `RANDOM_CALL_RATE_COINS_PER_MINUTE=600`

Staging env vars currently required on Render (`zephyr-api`):

- `JWT_SECRET`
- `DATABASE_URL`
- `CORS_ORIGINS`
- `GOOGLE_CLIENT_IDS` (required for Google login on staging; currently iOS + Android + Web IDs)

## Resume plan (next session)

1. Keep current auth + 5-tab shell baseline and run quick staging smoke checks
2. Add/verify staging smoke for busy-state rejection paths (`caller busy`, `receiver busy`)
3. Implement gift sending + balance deduction + creator revenue accrual transactions
4. Design and implement Spark redeem/cashout workflow (rules, thresholds, settlement path)
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

"Continue Zephyr from `README_AI.md`. Keep current auth + call billing baseline, then implement gifts + Spark redeem/cashout and extend staging smoke coverage."