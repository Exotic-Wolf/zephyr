# Zephyr Operations

This file owns operational truth: local run commands, regression gates, environment variables, deploy steps, release-build procedure, smoke tests, and rollback notes. Product behavior belongs in [product-model.md](./product-model.md), architecture in [architecture.md](./architecture.md), and launch state in [current-state.md](./current-state.md).

## Operating Standard

- Use the smallest useful gate while iterating, then broaden the gate when shared contracts or release behavior changed.
- Run `pnpm check` before handoff when auth/session, realtime, Firebase rules, economy, navigation, messaging, release, or shared model behavior changed.
- Do not deploy Render, Firebase rules, Firebase Functions, release builds, dependency changes, or schema changes unless the task explicitly calls for it.
- Do not enable `ALLOW_FAKE_PURCHASES` in production.
- Do not leave the backend-owned For you simulator routeable in production test windows unless the task explicitly requires fake matchmaking.
- Record only the latest release/change artifact in [release-history.md](./release-history.md).

## Toyota-Style Operating Model

Translate Toyota Production System ideas into Zephyr operations this way:

| TPS idea | Zephyr operation |
|---|---|
| Standardized work | Use the documented command sequence. If the sequence is wrong, fix this doc immediately. |
| Jidoka / andon | Any failing gate, smoke, deploy, release, data, or config abnormality stops the line until fixed or rolled back. |
| Just-in-Time | Run the smallest useful gate while iterating; do not perform deploys, releases, schema work, or dependency changes before they are needed. |
| Genchi genbutsu | Go to the source: code, tests, logs, Firebase rules, Render state, generated manifests, and real device behavior. |
| Kaizen | Every incident or repeated manual step should improve a test, script, doc, or module boundary. |
| Poka-yoke | Prefer scripts, typed contracts, idempotency keys, rules tests, and preflight checks that make mistakes hard to perform. |
| Heijunka | Keep changes small and level-loaded; avoid bundling unrelated fixes into one risky deploy. |
| A3 thinking | For major failures or risky changes, summarize problem, facts, root cause, countermeasure, owner, verification, and follow-up in one compact record. |

## Operational Control Loop

Every operational action follows the same loop:

1. Define the change scope and the system it touches.
2. Identify the owner doc and owner module.
3. Choose the smallest gate that can catch likely failure.
4. Execute the change with reversible steps where possible.
5. Verify with automated gates and required smoke.
6. If any check fails, stop, record the exact failure, and fix or roll back before continuing.
7. Update the owning docs before handoff.
8. State what changed, what passed, what failed, and what remains unproven.

## Stop-The-Line Rules

Stop immediately and do not continue toward deploy/release when any of these are true:

- A required gate fails.
- A smoke test fails after deploy.
- Docs and code/config disagree on a production command, endpoint, env var, rule, release version, or source-of-truth boundary.
- `ALLOW_FAKE_PURCHASES=true` is present in production.
- `DEMO_FOR_YOU_SIMULATOR_ROUTEABLE=true` is present outside an explicit fake-matchmaking test.
- A release build version/code is not higher than the last uploaded store build.
- Firebase rules changed without matching rules tests.
- Storage rules use `firestore.get()` / `firestore.exists()` without the Firebase Storage service agent holding `roles/firebaserules.firestoreServiceAgent`.
- Economy, wallet, gift, IAP, call billing, or refund behavior changed without backend tests and DB race/idempotency consideration.
- Auth/session/push behavior changed without Firebase rules/session checks and a manual two-device smoke plan.
- A deploy requires a secret that is missing, stale, or exposed.

When a stop rule triggers, update [current-state.md](./current-state.md) if launch state, blockers, or immediate next work changed.

## A3 Incident / Change Record

Use this compact record for production incidents, failed release builds, failed deploys, repeated regressions, payment/IAP issues, auth/session failures, or any change that crosses multiple modules.

```md
### A3: <short title> - <date>

Owner:
Scope:
Customer impact:
Current condition:
Expected condition:
Facts from source:
Root cause:
Countermeasure:
Verification:
Rollback or containment:
Docs updated:
Remaining risk:
Next standard-work improvement:
```

Do not write an A3 from memory. Fill `Facts from source` from commands, logs, code, tests, production state, or manual smoke.

## Local Run Commands

```bash
# Inspect local prerequisites and running services
pnpm dev:doctor
pnpm dev:status

# Local Postgres + API
pnpm dev:api:db:up
pnpm dev:api
pnpm dev:api:health
pnpm dev:api:db:down

# API only, using whatever .env/DATABASE_URL points at
pnpm --filter zephyr-api start:dev

# Mobile against local API
pnpm dev:mobile:android
pnpm dev:mobile:ios

# Start local API + mobile together
pnpm dev:all:android
pnpm dev:all:ios

# Direct Flutter run against local API
cd apps/zephyr-mobile && flutter run --dart-define=API_BASE_URL=http://localhost:3000

# Direct Flutter run against Render API
cd apps/zephyr-mobile && flutter run --dart-define=API_BASE_URL=https://zephyr-api-wr1s.onrender.com

# Launch Android emulator if not running
flutter emulators --launch Medium_Phone_API_36.1

# Install iOS pods if needed
pnpm dev:mobile:pods
```

## Regression Gates

```bash
# Full regression gate
pnpm check

# Backend + realtime gate
pnpm check:backend

# Mobile gate
pnpm check:mobile

# Firebase rules gate
pnpm check:realtime

# Production Firebase IAM preflight
pnpm check:firebase:iam

# Postgres race/idempotency gate
pnpm check:db:race

# Individual backend checks
pnpm --filter zephyr-api test
pnpm --filter zephyr-api test:e2e
pnpm --filter zephyr-api build

# Individual Flutter checks
cd apps/zephyr-mobile && flutter analyze && flutter test
```

CI parity: `.github/workflows/quality-gates.yml` runs RTDB, Firestore, Storage rules, backend unit/e2e/DB-race/build, Flutter analyze, and Flutter tests on PRs and pushes to `main`/`dev`. It also runs `pnpm check:firebase:iam` when the repo has a `FIREBASE_TOKEN` secret available.

## Gate Selection Matrix

| Change type | Minimum gate | Broaden when |
|---|---|---|
| Backend route/service only | `pnpm --filter zephyr-api test` + `pnpm --filter zephyr-api build` | Shared auth/session/economy/realtime contracts changed -> `pnpm check:backend` |
| Economy, wallet, gifts, IAP, refunds, call billing | Backend tests + `pnpm check:db:race` | Any API/mobile/rules interaction changed -> `pnpm check` |
| Firebase RTDB/Firestore/Storage rules | `pnpm check:realtime`; add `pnpm check:firebase:iam` when Storage rules use Firestore | Client/backend data shape changed -> `pnpm check` |
| Mobile UI/navigation/profile/feed/settings | `pnpm check:mobile` | Shared models/auth/realtime/messaging changed -> `pnpm check` |
| Auth/session/logout/push | Backend tests + Firebase rules + Flutter tests | Always plan two-device/manual smoke before launch sign-off |
| Release build/version | `pnpm check` + direct Gradle bundle | Store upload, Firebase/Render deploy, or IAP changed -> add manual smoke |
| Docs-only operation update | Markdown link/check validation + self-review | Commands/env/routes referenced -> verify against package scripts/config |

## Smoke Commands

```bash
# Backend smoke against local API
pnpm --filter zephyr-api smoke
pnpm --filter zephyr-api smoke:db

# Backend smoke against Render API
cd services/zephyr-api
BASE_URL=https://zephyr-api-wr1s.onrender.com node scripts/smoke.mjs
BASE_URL=https://zephyr-api-wr1s.onrender.com ZEPHYR_SMOKE_ACCESS_TOKEN=<real-app-bearer-token> node scripts/smoke.mjs
BASE_URL=https://zephyr-api-wr1s.onrender.com ZEPHYR_SMOKE_ACCESS_TOKEN=<real-app-bearer-token> ZEPHYR_SMOKE_CREATE_ROOM=true node scripts/smoke.mjs
```

Smoke scripts do not mint product guest sessions. Public smoke covers health and room discovery. Authenticated smoke requires a real OAuth/Firebase-backed app token. Room mutation smoke is opt-in only.

## Manual Smoke Matrix

Manual smoke is required when automation cannot prove device/session/store behavior.

| Area | Smoke required |
|---|---|
| Auth/session/logout/push | Two devices or simulator/device pair: latest login invalidates older session, explicit logout shows plain sign-in, no push after logout, stale device gets signed-in-elsewhere notice |
| Inbox/media | Real device or simulator with Firebase: open Inbox/Thread, send text, retry failed send, send bounded photo + message, receipts, block/report, repeat entry warm cache |
| Direct call | Two accounts online: caller rings receiver, accept, decline, timeout/no-answer, end, report, post-call actions |
| Random call | Customer + host account: seek, receiver ribbon, accept, decline, timeout, next, partner-left/end |
| Live | Host + viewer: start live, join, comments, reactions, viewer count, gift, heartbeat cleanup/end |
| IAP | Internal-test purchase/refund after store product visibility; fake purchase path is not proof |
| Release build | Install/upload candidate, verify version code/name, run launch-minimum login/feed/inbox/call smoke |

## Demo Host Simulator

```bash
# Local reversible For you demo hosts against selected DATABASE_URL + RTDB
pnpm --filter zephyr-api demo:for-you -- run --count=24 --yes
pnpm --filter zephyr-api demo:for-you -- cleanup --yes

# Backend-owned For you simulator controls on Render, protected by SERVICE_KEY
curl -fsS -H "X-Service-Key: $SERVICE_KEY" -H "Content-Type: application/json" -d '{"count":24,"intervals":[15,30,60,120],"routeable":false}' https://zephyr-api-wr1s.onrender.com/v1/internal/demo-for-you/start
curl -fsS -H "X-Service-Key: $SERVICE_KEY" https://zephyr-api-wr1s.onrender.com/v1/internal/demo-for-you/status
curl -fsS -H "X-Service-Key: $SERVICE_KEY" -X POST https://zephyr-api-wr1s.onrender.com/v1/internal/demo-for-you/stop
curl -fsS -H "X-Service-Key: $SERVICE_KEY" -X POST https://zephyr-api-wr1s.onrender.com/v1/internal/demo-for-you/cleanup
```

Current `render.yaml` enables `DEMO_FOR_YOU_SIMULATOR_ENABLED=true` with `routeable=false`. Before public launch, deliberately decide whether the simulator should stay enabled; routeable fake hosts must remain disabled outside explicit tests.

If For you shows "No one is live right now" during demo testing:

1. Confirm the backend is not down:

```bash
curl -fsS https://zephyr-api-wr1s.onrender.com/v1/health/live
curl -fsS https://zephyr-api-wr1s.onrender.com/v1/health/ready
```

2. Check simulator status. Do not print the key in logs or screenshots.

```bash
curl -fsS -H "X-Service-Key: $SERVICE_KEY" https://zephyr-api-wr1s.onrender.com/v1/internal/demo-for-you/status
```

3. If `enabled=true`, `firebaseReady=true`, but `running=false`, restart it:

```bash
curl -fsS --max-time 90 \
  -H "X-Service-Key: $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"count":24,"intervals":[15,30,60,120],"routeable":false}' \
  https://zephyr-api-wr1s.onrender.com/v1/internal/demo-for-you/start
```

If the 24-host start times out, check status before retrying. If it still shows `running=false`, start 8 hosts first, then start 24 hosts again:

```bash
curl -fsS --max-time 30 \
  -H "X-Service-Key: $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"count":8,"intervals":[15,30,60,120],"routeable":false}' \
  https://zephyr-api-wr1s.onrender.com/v1/internal/demo-for-you/start
```

## Android Release Build

```bash
# 1. Bump apps/zephyr-mobile/pubspec.yaml version above any Play-uploaded code.
# 2. Run the full gate when release behavior changed.
pnpm check

# 3. Prefer direct Gradle release bundle on this Mac.
cd apps/zephyr-mobile/android
./gradlew :app:bundleRelease

# 4. Record artifact metadata.
cd /Users/wolf/dev/zephyr
shasum -a 256 apps/zephyr-mobile/build/app/outputs/bundle/release/app-release.aab
ls -lh apps/zephyr-mobile/build/app/outputs/bundle/release/app-release.aab
```

Known local caveat: `flutter build appbundle` has reported native debug-symbol stripping failure on this Mac. Direct Gradle `:app:bundleRelease` succeeds and reads version metadata from `pubspec.yaml`. Current release builds still emit known non-fatal R8 Kotlin metadata and Gradle 9 deprecation warnings.

Release preflight:

1. Confirm `pubspec.yaml` version/build is higher than any uploaded Play build.
2. Run `pnpm check`.
3. Build with direct Gradle `:app:bundleRelease`.
4. Verify package, version name, version code, and permissions from generated manifests.
5. Calculate artifact SHA-256 and size.
6. Update [release-history.md](./release-history.md) with only the latest release record.
7. Update [current-state.md](./current-state.md) if launch state, blockers, or immediate next work changed.
8. List required manual smoke before claiming release readiness.

## Firebase Deploys

Production Firebase deploys require explicit task approval.

```bash
# RTDB rules
firebase deploy --only database --project zephyr-495115

# Firestore rules
firebase deploy --only firestore:rules --project zephyr-495115

# Storage rules
firebase deploy --only storage --project zephyr-495115

# Functions
cd functions && npm run build
firebase deploy --only functions --project zephyr-495115
```

Run `pnpm check:realtime` before rules deploys. Run `pnpm check:firebase:iam` before Storage deploys or media smoke when `storage.rules` uses Firestore. After deploy, record the rules/function change in [current-state.md](./current-state.md) when it affects launch state and in [release-history.md](./release-history.md) only if it is the latest release/change record.

Storage rules that read Firestore are a production IAM contract, not just a rules file. If `storage.rules` uses `firestore.get()` or `firestore.exists()`, verify the Google-provided Firebase Storage service account has `roles/firebaserules.firestoreServiceAgent`:

- Service account for Zephyr: `service-724639603736@gcp-sa-firebasestorage.iam.gserviceaccount.com`
- Required role: `roles/firebaserules.firestoreServiceAgent`
- Symptom when missing: emulator rules tests pass, but production Storage uploads fail with `firebase_storage/unauthorized` even when uid, token claims, path, size, and content type are correct.
- Verification path: `pnpm check:firebase:iam` confirms the IAM policy includes both `roles/firebasestorage.serviceAgent` and `roles/firebaserules.firestoreServiceAgent` for the Storage service agent; then simulator/device media smoke logs upload success.

## Environment Variables (Backend)

| Variable | Required | Notes |
|---|---|---|
| `DATABASE_URL` | Yes | Postgres connection string |
| `JWT_SECRET` | Production | Optional only in local dev; production startup requires it |
| `DB_SSL` | No | `true` for managed Postgres requiring SSL |
| `NODE_ENV` | Production | Set `production` in deploy |
| `PORT` | Deploy | Render injects/uses this; current blueprint sets `10000` |
| `CORS_ORIGINS` | Production | Comma-separated allowed origins; never `*` |
| `REDIS_URL` | Reserved | Present in `render.yaml`; current backend code does not consume Redis yet |
| `GOOGLE_CLIENT_IDS` | Yes | Comma-separated Google client IDs for iOS + Android |
| `GOOGLE_CLIENT_ID` | Legacy fallback | Single Google client ID fallback when `GOOGLE_CLIENT_IDS` is not set |
| `APPLE_CLIENT_ID` | Yes | e.g. `com.zephyr.zephyrMobile` |
| `APPLE_BUNDLE_ID` | Production IAP | `com.zephyr.zephyrMobile` |
| `APPLE_IAP_ENVIRONMENT` | IAP | `sandbox` by default; set deliberately for production Apple verification |
| `GOOGLE_PLAY_PACKAGE_NAME` | Production IAP | `com.zephyr.zephyr_mobile` |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_KEY` or `GOOGLE_PLAY_SERVICE_ACCOUNT_KEY_BASE64` | Production IAP | Google Play Developer API service account JSON for Android Publisher verification |
| `GOOGLE_RTDN_WEBHOOK_SECRET` | Google refund webhook | Optional webhook token for Google RTDN calls |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Realtime/Admin fan-out + demo simulator | Firebase Admin service account JSON for RTDB/FCM server writes |
| `FIREBASE_DATABASE_URL` | Realtime/Admin fan-out + demo simulator | Optional explicit RTDB URL; defaults from Firebase project ID |
| `SERVICE_KEY` | Internal endpoints | Required for protected cleanup/sync/demo endpoints |
| `OWNER_GOOGLE_EMAIL` | Optional seed | Promotes the matching Google account to admin and level 10 on DB startup |
| `DEMO_FOR_YOU_SIMULATOR_ENABLED` | No | `true` starts the backend-owned For you simulator on API boot |
| `DEMO_FOR_YOU_SIMULATOR_COUNT` | No | Demo host count when auto-enabled; default `24`, max `100` |
| `DEMO_FOR_YOU_SIMULATOR_INTERVALS` | No | Comma-separated rotation seconds; default `15,30,60,120` |
| `DEMO_FOR_YOU_SIMULATOR_ROUTEABLE` | No | `true` makes demo hosts eligible for routing; keep `false` unless testing fake matchmaking behavior |
| `AGORA_APP_ID` | Yes | Agora RTC app ID |
| `AGORA_APP_CERTIFICATE` | Yes | Agora RTC certificate |
| `RTC_TOKEN_TTL_SECONDS` | No | Agora RTC token TTL; default `3600` |
| `AGORA_CHAT_ORG_NAME` | Optional | Agora Chat integration org name if that service is enabled |
| `AGORA_CHAT_APP_NAME` | Optional | Agora Chat integration app name if that service is enabled |
| `AGORA_CHAT_REST_HOST` | Optional | Agora Chat REST host override |
| `DIRECT_CALL_ALLOWED_RATES` | No | Comma-separated coins/min; default `2100,3200,4200,5400,6400,8000,27000` |
| `DEFAULT_DIRECT_CALL_RATE_COINS_PER_MINUTE` | No | Default direct-call rate; must be one of `DIRECT_CALL_ALLOWED_RATES` |
| `PRIVATE_CALL_RATE_COINS_PER_MINUTE` | Legacy fallback | Older fallback for default direct-call rate |
| `RANDOM_CALL_RATE_COINS_PER_MINUTE` | No | Random-call rate; default `600` |
| `RECEIVER_SHARE_BPS` | No | Receiver share in basis points; default `6000` |
| `COINS_PER_USD_RECEIVER` | No | Conversion basis for receiver revenue; default `10000` |
| `SPARK_PER_USD` | No | Spark conversion basis; defaults to `COINS_PER_USD_RECEIVER` |
| `GIFT_PLATFORM_FEE_BPS` | No | Parsed into economy config; current gift payout uses `RECEIVER_SHARE_BPS` |
| `GIFT_ASSET_BASE_URL` | No | Base URL for server gift catalog thumbnail/animation URLs; defaults to `https://cdn.zephyrlive.app/gifts/v1` |
| `COIN_PACKS_JSON` | No | Optional JSON override for coin pack catalog |
| `ALLOW_FAKE_PURCHASES` | Dev only | `true` enables direct coin credit outside production; never enable in production |
| `CLOUDINARY_CLOUD_NAME` / `CLOUDINARY_API_KEY` / `CLOUDINARY_API_SECRET` | Profile media | Required for backend avatar/cover uploads |

Tables are auto-created on startup when `DATABASE_URL` is set.

## Mobile Build-Time Defines And Secrets

| Variable | Required | Notes |
|---|---|---|
| `API_BASE_URL` | No | Defaults to `https://zephyr-api-wr1s.onrender.com`; set to `http://localhost:3000` for local API |
| `GOOGLE_SERVER_CLIENT_ID` | OAuth | Used by Google Sign-In when supplied |
| `SENTRY_AUTH_TOKEN` | Release symbols | Used by `sentry_dart_plugin` for debug-symbol/source upload |

Current observability caveat: mobile and backend Sentry DSNs are hardcoded in source. Treat this as operational reality until a code change moves DSNs to environment/config.

## Security Defaults (Backend)

- Global DTO validation (`whitelist`, `forbidNonWhitelisted`)
- Global rate limiting (120 requests / 60s per IP)
- Unified JSON error envelope on all failures
- Google token verified server-side with audience check
- Apple token verified via JWKS
- OAuth sessions are single-active per account at the backend API layer; a new phone login replaces the older bearer token
- IAP receipts verified cryptographically (Apple JWS + Google Publisher API)
- Internal endpoints protected by `X-Service-Key` header

## Deploy Checklist (Render)

Target: Render Web Service + managed Postgres. Blueprint: `render.yaml` at repo root.

Current blueprint notes:
- `autoDeploy: true`
- `plan: starter`
- `DEMO_FOR_YOU_SIMULATOR_ENABLED=true`
- `DEMO_FOR_YOU_SIMULATOR_ROUTEABLE=false`
- build command: `pnpm install --frozen-lockfile && pnpm --filter zephyr-api build`
- start command: `pnpm --filter zephyr-api start:prod`

Pre-deploy:

```bash
pnpm install --frozen-lockfile
pnpm check:backend
pnpm --filter zephyr-api build
```

Use `pnpm check` instead of only `check:backend` when mobile contracts, Firebase rules, auth/session, messaging, economy, release behavior, or shared models changed.

Render setup:

1. Push branch to GitHub.
2. Confirm whether auto-deploy should be allowed for this change.
3. Set/verify required secret env values: `JWT_SECRET`, `DATABASE_URL`, `CORS_ORIGINS`, `FIREBASE_SERVICE_ACCOUNT_JSON`, `FIREBASE_DATABASE_URL`, `SERVICE_KEY`, `AGORA_APP_ID`, `AGORA_APP_CERTIFICATE`, `GOOGLE_CLIENT_IDS`, `APPLE_CLIENT_ID`, IAP secrets, and Cloudinary secrets when profile media is needed.
4. Trigger deploy only when the task explicitly calls for it.
5. Run post-deploy smoke.

Post-deploy smoke:

```bash
cd services/zephyr-api
BASE_URL=https://zephyr-api-wr1s.onrender.com node scripts/smoke.mjs
BASE_URL=https://zephyr-api-wr1s.onrender.com ZEPHYR_SMOKE_ACCESS_TOKEN=<real-app-bearer-token> node scripts/smoke.mjs
```

Rollback: keep the previous deployment available. If smoke fails, roll back immediately. Confirm `/v1/health/ready`, `/v1/auth/google-login`, and `/v1/rooms` before reopening traffic.

Rollback standard work:

1. Stop new risky actions first: no further deploys, releases, schema changes, or rules deploys.
2. Capture the failing command, endpoint, status code, and exact error output.
3. Roll back Render to the last known good deploy when backend smoke fails.
4. Roll back Firebase rules/functions to the last known good release when emulator parity or production smoke fails.
5. Disable or cleanup demo simulator data if it polluted feed/live state.
6. Re-run public smoke, then authenticated smoke if the incident touched auth/session/data.
7. Update [current-state.md](./current-state.md) with the blocker or recovered status.
8. Do not mark the issue complete until the rollback is verified or the forward fix passes the same failed gate.

Security baseline:
- Strong random `JWT_SECRET` (32+ chars)
- Strict `CORS_ORIGINS`
- Secrets never committed into docs or source
- Rotate secrets if exposed
- `ALLOW_FAKE_PURCHASES` unset/false in production
