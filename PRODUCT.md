# Zephyr — Product & Technical Reference

> This file is the living source of truth for product decisions, pricing, architecture, and development context. Read this first before touching any code or starting a new session. The app evolves; the latest dated snapshot and TODOs supersede older direction.

---

## Product Vision

- **Goal:** build a flawless, top-tier, Steve Jobs-level Chamet/Olamet-style social video app.
- **Primary mobile audience:** iPhone users first, with Android parity through Flutter.
- **Stack choice:** Flutter is intentional because one product-quality codebase can serve iOS and Android while keeping interaction, animation, and realtime behavior consistent.
- **Target market:** Arab Gulf users calling Philippines/Asia hosts.
- **Core revenue:** coin-based gifts + direct/random video calls + live streaming.
- **Expansion path:** premium live / premium room flow where hosts can start premium directly or upgrade free live into a paid-per-minute room.
- **Execution style:** build robust reusable cells first, then compose flawless modules and product organs.

---

## Operating Rule

Every meaningful work slice must update this file before commit/push when it changes product truth, architecture truth, launch state, or next-work priority:

- Update **Current TODO Tracker** with what changed, what is next, and what is blocked.
- Update **Current Solution Snapshot** when the overall state, grade, blockers, or launch direction changes.
- Update **Audit Log** when a feature/module quality grade changes.
- Remove or rewrite stale product claims as soon as implementation makes them outdated.
- Preserve one source of truth per domain; do not add parallel truth systems for convenience.
- Keep iPhone user experience as the primary polish bar, while preserving Flutter Android parity.
- Keep `.github/copilot-instructions.md` aligned with this file when engineering rules, architecture ownership, or hard constraints change.

### Direction Supersession Rule

Zephyr is moving fast. Treat this document as a dated decision log, not a permanent spec.

Priority order when sections disagree:

1. **Current Solution Snapshot** and **Immediate next work** describe where the product is today.
2. **Current TODO Tracker** describes committed next action and blockers.
3. **Architecture Direction** and **Canonical Realtime Availability Model** describe the current engineering baseline.
4. **Audit Log** records history. Later-dated audit entries supersede older entries.
5. Older launch checklists and historical audit rows are useful context only when they still match current code.

When the app direction changes, do not patch around stale wording. Replace it, date it, and say what it supersedes.

---

## Current TODO Tracker

| Priority | Status | Owner | Item | Why it matters |
|---|---|---|---|---|
| P0 | Done | User | Install Java 17 JDK for Apple Silicon/M4 Mac | Verified locally with Temurin `17.0.19`; Firebase RTDB emulator can run through repo-local `firebase-tools@14` |
| P0 | Done | Codex | Add executable RTDB emulator tests | `tests/rtdb/rules.test.mjs` proves canonical presence, profile ownership, direct-call ownership, live-room host ownership, and event validation |
| P0 | Done | Codex | Run RTDB emulator rules suite and record results in Audit Log | `pnpm test:rtdb:rules` passed 7/7 tests on 7 Jun 2026 |
| P0 | Action required | User | Update Render billing payment method | Render reported invalid payment info on 6 Jun 2026; service is healthy now but can be suspended if payment fails again |
| P0 | Done | Codex | Deploy `dev` to Render backend through `main` | PR #2 merged on 6 Jun 2026; Render health returned `ok` after merge |
| P0 | Done | Codex | Launch iPhone 17 Pro Max simulator against Render API | `com.zephyr.zephyrMobile` launched on simulator with `API_BASE_URL=https://zephyr-api-wr1s.onrender.com` |
| P0 | Action required | User | Manual simulator smoke test | Check login/onboarding/feed/inbox/presence/direct call/random call/live basics while Render billing is fixed |
| P0 | Done | Codex | Generate Android internal testing AAB `1.0.4+5` | Built signed release bundle at `apps/zephyr-mobile/build/app/outputs/bundle/release/app-release.aab`; manifest verifies version name `1.0.4`, version code `5` |
| P0 | Done | Codex | Promote Android internal testing build `1.0.4+5` to `main` | PR #3 carries the Play version bump and release tracker to `main` so Render/GitHub state matches the upload build |
| P0 | Done | Codex | Fix direct-call `API 400` user experience | Mobile now parses backend error envelopes into product messages; Firebase `onPresenceChanged` now mirrors RTDB create/update/delete writes into Postgres availability and was deployed on 6 Jun 2026 |
| P0 | Action required | User | Retest direct call with two online accounts | Open/log in both accounts after the Functions deploy so each account rewrites presence, then call only when the receiver badge is online/live and not busy |
| P0 | Done | Codex | Fix random-call receiver signaling lifecycle | Home now consumes backend `event=matched`, shows a host earning ribbon, routes accepted calls into Agora random mode, cleanly declines/timeouts, and Cloud Function cleanup no longer ends matched random sessions before join |
| P0 | Action required | User | Manual two-account random-call smoke test | Use one customer and one host/girl account to verify live-host priority, receiver ribbon, accept, decline, timeout, end, and next-call behavior on simulator/device |
| P0 | Done | Codex | Make wallet and session ledger writes transactional | Call ticks, direct/random call gifts, live gifts, dev coin credit, IAP credit, and IAP refunds now use PostgreSQL transactions/row locks where needed |
| P0 | Done | Codex | Add ledger idempotency keys and real Postgres race tests | Call ticks, call gifts, and live-room gifts now accept `X-Idempotency-Key`; mobile sends stable paid-action keys; `pnpm --filter zephyr-api test:db:race` passed 3/3 against local Postgres on 6 Jun 2026 |
| P0 | Done | Codex | Fix Google Play IAP verification contract | Android now sends the Play purchase token as canonical transaction ID, consumes coin packs after backend credit, backend defaults match real app IDs, and Google RTDN refunds resolve by purchase token |
| P0 | Done | User | Set production IAP env on Render | `GOOGLE_PLAY_PACKAGE_NAME`, `APPLE_BUNDLE_ID`, Google Play service-account key, and existing `NODE_ENV=production` were confirmed by the user on 6 Jun 2026 |
| P0 | Done | Codex | Promote Google Play IAP hardening to `main` | PR #5 merged `dev` into `main` on 6 Jun 2026; Render readiness endpoint returned `ok` with Postgres storage after merge |
| P0 | Done | Codex | Generate Android IAP smoke AAB `1.0.5+6` | Built signed release bundle at `apps/zephyr-mobile/build/app/outputs/bundle/release/app-release.aab` after the purchase-token fix; generated manifest verifies package `com.zephyr.zephyr_mobile`, version name `1.0.5`, version code `6` |
| P0 | Done | User | Upload Android IAP smoke AAB `1.0.5+6` to internal testing | User confirmed the fresh AAB was uploaded and published on 6 Jun 2026; earlier `1.0.4+5` does not contain the mobile purchase-token/consume fix |
| P0 | Done | Codex | Harden wallet IAP catalog UX | Wallet top-up now reads explicit Play/App Store catalog state, shows loading/retry/status copy, disables inactive products, displays store-localized prices when active, and logs missing product IDs for setup debugging |
| P0 | Done | Codex | Generate Android wallet/IAP AAB `1.0.6+7` | Built signed release bundle at `apps/zephyr-mobile/build/app/outputs/bundle/release/app-release.aab` after catalog UX hardening; Gradle `bundleRelease` passed on 7 Jun 2026, package remains `com.zephyr.zephyr_mobile`, version name `1.0.6`, version code `7` |
| P0 | Pending review | Google | Google Play merchant/bank verification | User submitted the Play payments profile and SBM bank statement on 7 Jun 2026; one-time product creation and catalog visibility are blocked until Google completes or accepts verification |
| P0 | Blocked | User | Manual Google Play internal-test purchase smoke | Current tester build cannot buy because no matching Play one-time products exist/are visible yet; after merchant verification, upload/use `1.0.6+7`, create/publish `pack_299`, wait for catalog propagation, then retry backend credit/consume/refund smoke |
| P0 | Done | Codex | Make inbox core messaging A+ | Firestore chat/message writes are rules-constrained, sends are transactional/idempotent, push is backend-verified from committed Firestore data, and block/report ownership moved to backend with Firestore block projections |
| P0 | Done | Codex | Add Firestore rules emulator suite | `pnpm test:firestore:rules` proves participant-only chat ownership, immutable participants, bounded unread, message immutability, receiver-only receipts, constrained deletes, and block projection denial |
| P0 | Done | Codex | Add Storage rules emulator suite | `pnpm test:storage:rules` proves participant-only chat image reads, uploader-only image creation, image/type/size bounds, outsider denial, and immutable chat image objects |
| P0 | Done | Codex | Generate Android inbox A+ AAB `1.0.7+8` | Built signed release bundle at `apps/zephyr-mobile/build/app/outputs/bundle/release/app-release.aab`; direct Gradle `:app:bundleRelease` passed on 7 Jun 2026 and package remains `com.zephyr.zephyr_mobile` |
| P0 | Done | Codex | Make inbox text sends optimistic | Text bubbles now appear immediately, the composer clears without blocking the send arrow, pending sends show an in-bubble clock, and failed sends stay in-thread with red `Retry` using the same idempotency key |
| P0 | Done | Codex | Enforce one active mobile API session per account | OAuth login sends a stable app-install device id; backend stamps a new active session id on the user, deletes older session rows, and rejects older bearer tokens after another phone logs in |
| P0 | Done | Codex | Generate Android session/inbox AAB `1.0.8+9` | Built signed release bundle at `apps/zephyr-mobile/build/app/outputs/bundle/release/app-release.aab`; manifest verifies package `com.zephyr.zephyr_mobile`, version name `1.0.8`, version code `9`; SHA-256 `cc83910b0a0b7c243bddb8077fd7ba810c0b681a57d050af784d7ff112ae69fb` |
| P0 | Done | Codex | Enforce canonical presence coherence in RTDB rules | Rules now reject incoherent availability cells such as premium live with random routing enabled or display/state mismatch |
| P0 | Done | Codex | Move live audience ownership to per-viewer RTDB cells | Viewers now own only `live_rooms/{roomId}/audience/{userId}`; shared `audience_count` is no longer client-writable |
| P0 | Done | Codex | Move live-room gift display fan-out behind backend/Admin SDK | Client gift UI now waits for backend economy success; backend writes trusted RTDB gift events and clients cannot forge them |
| P0 | Done | Codex | Wire realtime and backend ledger gates into CI/default checks | Root `pnpm check` runs RTDB + Firestore + Storage rules, backend test/build, and GitHub Actions runs RTDB/Firestore/Storage rules, backend tests, DB race tests, and backend build |
| P0 | Done | Codex | Replace stale Flutter widget test harness | Widget tests now cover current OAuth/legal surface, no guest copy, cancellation copy, profile setup ordering, following-response parsing, Follow empty state, and call safety/post-call reporting; `flutter test` passed 6/6 on 7 Jun 2026 |
| P1 | Done | Codex | Wire follow/profile/feed host model end-to-end | Mobile now accepts the deployed following-ID response shape, ProfilePage follow/unfollow calls backend endpoints, follower counts come from Postgres profile responses, Following has an empty state, and feed cards open host/profile discovery instead of starting immediate direct calls |
| P1 | Done | Codex | Add host card cover defaults | Added six optimized local 540x960 cover assets (jazz, beach, club, rooftop, cafe, music); female host onboarding now persists one identity-seeded default cover when `cover_url` is empty, feed cards consume `hostCoverUrl`, uploaded covers replace the default, and identity-seeded local fallback remains only for old/offline data |
| P1 | Done | Codex | Filter customer/boy accounts out of host feed | Backend `/v1/feed/live` now returns only `is_host = true` + `gender = Female` users; database startup backfills Female accounts into host status and removes legacy host status from non-female rows; in-memory fallback matches production behavior; unit coverage proves a customer live room does not enter the host feed |
| P1 | Done | Codex | Move Me entry into app header | Root shell now has a reusable Zephyr header with avatar/profile access plus customer coin/recharge or host spark balance; Me is no longer a footer destination |
| P1 | Done | Codex | Move Follow out of Home into footer Following tab | Followed hosts live in the second footer destination, Following, matching the cleaner Tango-style information architecture |
| P1 | Done | Codex | Replace old Home shell with For you card grid | Extreme-left footer tab is now For you with the shared Zephyr header and a dense Tango-style 2x2 host card grid using thin gutters and barely-rounded cards |
| P1 | Direction locked | User/Codex | Rework For you into Tango-style live discovery | For you is not a low-inventory directory: it must scale to hundreds/thousands of live host/girl cards, show live supply first, avoid user-facing filters, support pull-to-refresh, lazy loading, viewer counts, body-tap live entry, identity-strip profile entry, and later live preview/hide-chrome polish |
| P1 | Done | Codex | Implement launch-minimum For you live discovery core | For you now requests live-only paged feed data, removes normal placeholder/offline cards, shows viewer counts, supports pull-to-refresh, triggers lazy loading near the end of the grid, keeps body-tap live entry, keeps identity-strip profile entry, and uses a premium empty state with customer Random match CTA |
| P1 | Done | Codex | Add reversible backend For you demo host simulator | Zephyr API can seed marked female demo hosts, write RTDB canonical `profiles`/`presence`, mirror Postgres feed projections, rotate through live, premium live, online, away, direct-call busy, random-call busy, and offline every 15/30/60/120 seconds, and cleanup all marked demo users/rooms through protected internal controls |
| P1 | Done | Codex | Upgrade Me/profile/wallet/settings entrance | Me now shows live wallet overview metrics, sparks, revenue, and call price; profile avatar/cover updates preserve full returned profile state; Account/Privacy/Notifications settings rows open real subpages; Level/Revenue/Wallet show spark context; widget coverage guards the new entrance |
| P1 | Done | Codex | Unify block/report ownership | Thread chat and profile moderation now use backend `user_blocks`/`user_reports`; Firestore keeps only backend-written block projections for rules enforcement |
| P1 | Audit finding | Codex | Refresh stale non-Markdown contracts/test helpers/source comments | Markdown docs now carry the living-direction protocol; OpenAPI, smoke/e2e helpers, and a few source comments still describe old guest/socket behavior |
| P1 | Done | Codex | Add in-call report entry point | DirectCallScreen now exposes an accessible report action, direct calls exit to a post-call screen with Message/Report/Done actions, and widget coverage proves the safety/report path |
| P1 | Planned | Codex | Expand reusable Gift module beyond live | Live-room gifts now use backend-confirmed fan-out; inbox, direct call, random call, and premium live still need the shared gift surface |
| P1 | Planned | Codex | Implement premium live lifecycle | Free live -> premium, start premium directly, paid entry, per-minute billing, lock screen, cleanup |
| P1 | Planned | Codex | Add `PremiumLiveRealtime` module once lifecycle exists | Keeps premium live non-interruptible and owned by a dedicated realtime module |
| P1 | Done | Codex | Replace live audience counter with per-viewer presence/count derivation | Prevents inaccurate counts from duplicate joins/disconnect edge cases |
| P2 | Done | Codex | Move trusted live-room gift event fan-out to backend/Admin SDK confirmation | Prevents spoofed live gift display events while keeping gift economy reusable |

Immediate next work:

1. Manual smoke the launch-minimum For you page on iPhone using the reversible demo host simulator: live-only feed, viewer count, pull-to-refresh, lazy-load trigger, body-tap live entry, identity-strip profile entry, and empty state with Random match after cleanup.
2. Manually smoke test random call with two accounts: customer seeks, host sees ribbon, host accepts, host declines, host timeout, customer next, both end.
3. Upload and smoke the session/inbox Android AAB `1.0.8+9`: OAuth login, second-phone login invalidates the older API session, inbox optimistic text send, failed-send retry, send image, receipts, block, report, logout/offline.
4. Wait for Google Play merchant/bank verification, create/publish `pack_299`, then smoke one internal-test purchase/refund.
5. Refresh stale non-Markdown contracts/test helpers/source comments: OpenAPI guest-login, smoke/e2e guest helpers, socket/LiveKit comments.
6. Retest direct call with two online accounts after the deployed presence-sync trigger, including in-call report and post-call Message/Report/Done behavior.
7. Manual smoke the Following + Me entrances: follow/unfollow/count adjustment, empty Following state, feed card opens the selected host/profile, Me dashboard metrics load, Settings subpages open, and profile avatar/cover edits return cleanly.
8. Expand the reusable Gift module beyond live, then wire inbox gifts first and reuse it for call/random call/premium live.
9. Implement premium live lifecycle, paid entry, lock screen, metered billing, and `PremiumLiveRealtime`.

---

## Current Solution Snapshot (8 Jun 2026)

This is the current working truth after re-auditing `PRODUCT.md`, `.github/copilot-instructions.md`, and the repository implementation.

| Area | Current state |
|---|---|
| Overall solution grade | B+ today. The architecture and core safety rails are strong; the remaining gap is product completion, manual smoke sign-off, and stale non-Markdown artifacts. |
| Verified checks | `pnpm check` passed earlier on 7 Jun; `pnpm --filter zephyr-api test:db:race` passed 3/3 against local Postgres; current pass on 8 Jun: `pnpm --filter zephyr-api test` passed 24 tests with 3 skipped DB-race tests, `pnpm --filter zephyr-api build` passed, `flutter analyze` passed, `flutter test` passed 10/10, and direct Gradle `./gradlew :app:bundleRelease` produced signed AAB `1.0.8+9`. |
| Known failing check | Local `flutter build appbundle` wrapper reported native debug-symbol stripping failure; direct Gradle `:app:bundleRelease` succeeds and produced the uploadable signed AAB. `flutter doctor -v` still reports Android cmdline-tools missing and Android license status unknown on this Mac. |
| Auth/session | Launch-level A. OAuth login carries a stable app-install device id; the backend maintains one active mobile API session per account, so a newer phone login invalidates older bearer tokens. On next launch, an older phone clears its local backend token and Firebase chat session when restore is rejected. Full A+ still needs Firebase rule-level session revocation/custom-claim checks so already-open Firestore/RTDB sessions are also forced out instantly. |
| Realtime architecture | A+. Canonical RTDB presence, RTDB rules, module ownership, backend projection, per-viewer live audience, and backend-trusted live gift fan-out are in place and covered by emulator tests. |
| Messaging/inbox | A+ core and media. Firestore/Storage rules, transactional sends, backend-verified push, block/report ownership, image upload rules, optimistic text sends, in-bubble failed-send retry, and Android AAB `1.0.8+9` are ready for manual smoke. |
| Backend economy | A+. Call ticks, direct/random call gifts, live gifts, IAP credit/refund, and race/idempotency paths are transaction-safe and tested. |
| IAP | A pending store sign-off. Code/backend/env are hardened, but Google Play merchant/bank verification and real internal-test purchase/refund smoke remain blocked. |
| Calls | Direct and random call flows are implemented, with in-call report entry and post-call Message/Report/Done safety flow now wired and widget-tested. Home keeps the floating Random match CTA for customer accounts only; host/girl accounts receive random-call invite ribbons instead. Both call flows still need two-account manual smoke. |
| Follow/feed | Launch-minimum For you core is in place. Backend follow endpoints, footer Following tab, empty state, deployed following-ID parsing, female host-only feed filtering, ProfilePage follow/count persistence, customer-only Random match CTA, persisted identity-seeded default host covers with uploaded-cover override, and identity-seeded card-cover fallback are in place. For you now requests live-only paged feed data, removes normal placeholder/offline cards, shows viewer count, supports pull-to-refresh, lazy-loads near the end of the grid, uses body-tap live entry, uses identity-strip profile entry, and keeps a premium empty state with customer Random match CTA. Later polish: short live preview while scrolling, hide header/footer on scroll, stronger backend ranking, and mini-live after exit. |
| Me/profile/wallet/settings | A-level entrance. Me dashboard now surfaces coins, sparks, revenue, and call price; profile avatar/cover uploads return full profile state; wallet/level/revenue pages show spark context; Account/Privacy/Notifications settings rows are no longer dead. A+ still needs manual smoke, deeper revenue/payout detail, persisted notification controls, and localization of the new English settings copy. |
| Gifts | Live gift sending now goes backend -> Postgres ledger -> Admin RTDB fan-out. Shared gift module still needs expansion to inbox, direct/random calls, and premium live. |
| Premium live | Documented, not implemented. Paid entry, lock screen, per-minute premium billing, and `PremiumLiveRealtime` remain future work. |
| Documentation status | `PRODUCT.md` and Copilot instructions now reflect the current architecture. Non-Markdown OpenAPI/smoke/e2e helpers and a few source comments still need cleanup. |

---

## Architecture

| Layer | Stack | Location |
|---|---|---|
| Mobile | Flutter (Dart) | `apps/zephyr-mobile` |
| Backend API | NestJS (TypeScript) | `services/zephyr-api` |
| Database | PostgreSQL (Render) | Singapore region |
| Messaging | Firebase Firestore + Storage + backend-verified FCM | `firebase_chat_service.dart`, Firestore rules, backend `/v1/messages/push` |
| Status & Presence | Firebase RTDB (asia-southeast1) | Canonical realtime availability cell: connection, activity, routing, display status, call/live context |
| User Identity | Firebase RTDB `profiles/{userId}` | displayName, avatarUrl, countryCode, language, birthday — **source of truth for identity**. LRU-cached listeners, reactive via `profileVersion` ValueNotifier |
| Live Rooms | Firebase RTDB | Host-owned status, per-viewer audience cells, comments, reactions, and backend-trusted gift display events via `live_rooms/{roomId}/` |
| Video | Agora (calls + live streaming) | SDK in mobile |
| Deploy | Render (auto-deploy from `main`) | `https://zephyr-api-wr1s.onrender.com` |

---

## Run Commands

```bash
# iOS (iPhone 17 Pro Max simulator)
cd apps/zephyr-mobile && flutter run -d 8B6780BE-FC4B-47F0-8980-3D9D7504004A --dart-define=ENVIRONMENT=development

# Android emulator
cd apps/zephyr-mobile && flutter run -d emulator-5554 --dart-define=ENVIRONMENT=development

# Launch Android emulator if not running
flutter emulators --launch Medium_Phone_API_36.1

# Build debug APK
cd apps/zephyr-mobile && flutter build apk --debug --dart-define=ENVIRONMENT=development

# Run API locally (hits real production DB via .env)
pnpm --filter zephyr-api start:dev

# Run API against local Postgres (Docker)
pnpm --filter zephyr-api db:up
pnpm --filter zephyr-api start:dev:localdb
pnpm --filter zephyr-api db:down

# Local reversible For you demo hosts against the selected DATABASE_URL + RTDB
pnpm --filter zephyr-api demo:for-you -- run --count=24 --yes
pnpm --filter zephyr-api demo:for-you -- cleanup --yes

# Backend-owned For you simulator controls (Render, protected by SERVICE_KEY)
curl -fsS -H "X-Service-Key: $SERVICE_KEY" -H "Content-Type: application/json" -d '{"count":24,"intervals":[15,30,60,120],"routeable":false}' https://zephyr-api-wr1s.onrender.com/v1/internal/demo-for-you/start
curl -fsS -H "X-Service-Key: $SERVICE_KEY" https://zephyr-api-wr1s.onrender.com/v1/internal/demo-for-you/status
curl -fsS -H "X-Service-Key: $SERVICE_KEY" -X POST https://zephyr-api-wr1s.onrender.com/v1/internal/demo-for-you/stop
curl -fsS -H "X-Service-Key: $SERVICE_KEY" -X POST https://zephyr-api-wr1s.onrender.com/v1/internal/demo-for-you/cleanup

# Test and build (backend)
pnpm --filter zephyr-api test
pnpm --filter zephyr-api build
pnpm --filter zephyr-api smoke
pnpm --filter zephyr-api smoke:db

# Test (Flutter)
cd apps/zephyr-mobile && flutter test
```

---

## Environment Variables (Backend)

| Variable | Required | Notes |
|----------|----------|-------|
| `DATABASE_URL` | Yes | Postgres connection string |
| `JWT_SECRET` | Production | Optional in local dev |
| `DB_SSL` | No | `true` for managed Postgres requiring SSL |
| `NODE_ENV` | Production | Set `production` in deploy |
| `PORT` | Deploy | Platform usually injects this |
| `CORS_ORIGINS` | Production | Comma-separated allowed origins |
| `GOOGLE_CLIENT_IDS` | Yes | Comma-separated Google client IDs (iOS + Android) |
| `APPLE_CLIENT_ID` | Yes | e.g. `com.zephyr.zephyrMobile` |
| `APPLE_BUNDLE_ID` | Production IAP | `com.zephyr.zephyrMobile` |
| `GOOGLE_PLAY_PACKAGE_NAME` | Production IAP | `com.zephyr.zephyr_mobile` |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_KEY` or `GOOGLE_PLAY_SERVICE_ACCOUNT_KEY_BASE64` | Production IAP | Google Play Developer API service account JSON for Android Publisher verification |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Realtime/Admin fan-out + demo simulator | Firebase Admin service account JSON for RTDB/FCM server writes |
| `FIREBASE_DATABASE_URL` | Realtime/Admin fan-out + demo simulator | Optional explicit RTDB URL; defaults from Firebase project ID |
| `DEMO_FOR_YOU_SIMULATOR_ENABLED` | No | `true` starts the backend-owned For you simulator on API boot; keep `false`/unset outside temporary test windows |
| `DEMO_FOR_YOU_SIMULATOR_COUNT` | No | Demo host count when auto-enabled; default `24`, max `100` |
| `DEMO_FOR_YOU_SIMULATOR_INTERVALS` | No | Comma-separated rotation seconds; default `15,30,60,120` |
| `DEMO_FOR_YOU_SIMULATOR_ROUTEABLE` | No | `true` makes demo hosts eligible for routing; keep `false` unless testing fake matchmaking behavior |
| `AGORA_APP_ID` | Yes | Agora RTC app ID |
| `AGORA_APP_CERTIFICATE` | Yes | Agora RTC certificate |
| `DIRECT_CALL_ALLOWED_RATES` | No | Comma-separated coins/min (default: `2100,3200,4200,5400,6400,8000,27000`) |
| `ALLOW_FAKE_PURCHASES` | No | `true` in dev only — enables direct coin credit |

Tables are auto-created on startup when `DATABASE_URL` is set.

---

## Security Defaults (Backend)

- Global DTO validation (`whitelist`, `forbidNonWhitelisted`)
- Global rate limiting (120 requests / 60s per IP)
- Unified JSON error envelope on all failures
- Google token verified server-side with audience check
- Apple token verified via JWKS
- OAuth sessions are single-active per account at the backend API layer; a new phone login replaces the older bearer token
- IAP receipts verified cryptographically (Apple JWS + Google Publisher API)
- Internal endpoints protected by `X-Service-Key` header

---

## Deploy Checklist (Render)

**Target:** Render Web Service + managed Postgres. Blueprint: `render.yaml` at repo root.

**Pre-deploy:**

```bash
pnpm install
pnpm --filter zephyr-api test
pnpm --filter zephyr-api build
```

**Render setup:**

1. Push branch to GitHub
2. Create Blueprint from repo — Render detects `render.yaml`, creates `zephyr-api`
3. Set secret env values: `JWT_SECRET`, `DATABASE_URL` (internal URL), `CORS_ORIGINS`, `AGORA_APP_ID`, `AGORA_APP_CERTIFICATE`, `GOOGLE_CLIENT_IDS`, `APPLE_CLIENT_ID`
4. Trigger deploy

**Start command** (already in blueprint): `pnpm --filter zephyr-api start:prod`

**Post-deploy smoke test:**

```bash
cd services/zephyr-api
BASE_URL=https://your-api-domain.com node scripts/smoke.mjs
```

**Rollback:** Keep previous deployment available. If smoke fails, roll back immediately. Confirm `/v1/auth/google-login` and `/v1/rooms` before reopening traffic.

**Mobile switch:** `flutter run --dart-define=API_BASE_URL=https://your-api-domain.com`

**Security baseline:**
- Strong random `JWT_SECRET` (32+ chars)
- `CORS_ORIGINS` strict — never `*`
- Service visibility private to repo/team
- Rotate secrets if exposed

---

## Flutter App Structure (`apps/zephyr-mobile/lib/`)

| File | Purpose |
|------|---------|
| `main.dart` | App bootstrap, session restore via `flutter_secure_storage` |
| `app_constants.dart` | `apiBaseUrl`, `googleServerClientId`, env constants |
| `models/models.dart` | All data models: `UserProfile`, `Room`, `ZephyrMessage`, `WalletSummary`, `CoinPack`, `CallSession`, etc. |
| `services/api_client.dart` | All HTTP calls — GET/POST/PATCH/DELETE |
| `services/firebase_chat_service.dart` | Firebase chat — Firestore messages, RTDB presence + profiles (LRU-cached), Storage images, block/report |
| `pages/home_screen.dart` | Feed, inbox badge, RTDB presence/listeners, incoming direct call listener |
| `features/call/direct_call_screen.dart` | Reusable Agora video call screen (direct + random), remote mute detection, PIP |
| `features/call/incoming_call_overlay.dart` | Incoming call overlay — accept/decline, caller info |
| `features/live/host_live_screen.dart` | Host live stream, heartbeat timer (15s) |
| `features/live/go_live_countdown_page.dart` | 3-2-1 countdown, creates room |
| `features/live/viewer_live_screen.dart` | Viewer live stream, reactions, comments |
| `features/onboarding/onboarding_page.dart` | Login screen — Google Sign-In + Apple Sign-In, API offline check, legal links ||
| `features/onboarding/profile_setup_screen.dart` | Post-login setup — gender picker → language picker (2-page PageView), auto-detects country, writes profile to RTDB |
| `pages/explore_page.dart` | Search users by name or 8-digit public ID |
| `pages/inbox_firebase_page.dart` | Conversation list (real-time Firestore), presence dots, unread badges |
| `pages/thread_firebase_page.dart` | DM chat — real-time messages, read/delivered receipts (✓✓), images, translate, delete, anti-spam |
| `pages/my_profile_page.dart` | View/edit profile |
| `widgets/` | Shared widgets: gifts, spark icon, coin icon, language picker |

---

## Backend Structure (`services/zephyr-api/src/`)

| File | Notes |
|------|-------|
| `main.ts` | Bootstrap — standard NestJS HTTP server |
| `core/store.service.ts` | All DB logic — messages, rooms, economy, wallets |
| `core/database.service.ts` | Schema init, migrations, periodic cleanup |
| `core/rtc.service.ts` | Agora token generation |
| `core/fcm.service.ts` | Firebase Admin — push notifications + RTDB writes for backend-owned call, match, and live gift fan-out |
| `auth/auth.controller.ts` | `POST /v1/auth/google-login`, `/apple-login`, `/firebase-token` — OAuth sessions and custom Firebase token for client auth |
| `messages/messages.controller.ts` | `POST /v1/messages/push` — FCM push relay, device tokens, delivery/read receipts |
| `rooms/rooms.controller.ts` | Live room management — create/join/leave/end/gift/rtc-token |
| `economy/economy.controller.ts` | All economy endpoints |
| `economy/matchmaking.controller.ts` | Random call matchmaking — seek/cancel/next/end (REST + RTDB signals) |

---

## DB Schema (Postgres)

Tables: `users`, `wallets`, `spark_wallets`, `wallet_transactions`, `user_following`, `user_blocks`, `rooms`, `messages`, `call_sessions`, `gifts`

Key columns:
- `users.public_id TEXT UNIQUE` — 8-digit derived hash
- `users.call_rate_coins_per_minute INT` — receiver sets their direct call rate
- `rooms.last_heartbeat TIMESTAMPTZ` — updated every 15s by host
- `messages.read_at TIMESTAMPTZ` — null = unread, set = read (blue tick)

---

## API Endpoints

```
GET  /v1/health/live
GET  /v1/health/ready
POST /v1/auth/google-login
POST /v1/auth/apple-login
POST /v1/auth/firebase-token
GET  /v1/users/me
PATCH /v1/users/me
DELETE /v1/users/me
POST /v1/users/me/avatar
POST /v1/users/me/cover
GET  /v1/users/me/following
GET  /v1/users/search
GET  /v1/users/by-public-id/:publicId
POST /v1/users/batch
GET  /v1/users/:userId
POST /v1/users/:userId/follow
DELETE /v1/users/:userId/follow
POST /v1/users/:userId/block
DELETE /v1/users/:userId/block
GET  /v1/users/:userId/block
POST /v1/users/:userId/report
GET  /v1/rooms
POST /v1/rooms
POST /v1/rooms/:roomId/join
POST /v1/rooms/:roomId/leave
GET  /v1/rooms/:roomId/viewers
POST /v1/rooms/:roomId/heartbeat
DELETE /v1/rooms/:roomId
POST /v1/rooms/:roomId/rtc-token
POST /v1/rooms/:roomId/gift
GET  /v1/feed/live
GET  /v1/economy/config
GET  /v1/economy/call-rate-tiers
GET  /v1/economy/coin-packs
GET  /v1/economy/wallet
POST /v1/economy/purchase-coins
POST /v1/economy/verify-purchase
GET  /v1/economy/private-call/quote
GET  /v1/economy/gifts/catalog
POST /v1/economy/gifts/send
GET  /v1/economy/calls
GET  /v1/economy/transactions
POST /v1/economy/calls/start
POST /v1/economy/calls/:sessionId/tick
POST /v1/economy/calls/:sessionId/end
POST /v1/economy/calls/:sessionId/rtc-token
POST /v1/economy/calls/:sessionId/report
POST /v1/calls/random/seek
POST /v1/calls/random/next
POST /v1/calls/random/end
DELETE /v1/calls/random/seek
POST /v1/webhooks/apple
POST /v1/webhooks/google
POST /v1/messages/device-token
POST /v1/messages/push
DELETE /v1/messages/device-token
POST /v1/messages
GET  /v1/messages/conversations
GET  /v1/messages/conversations/:userId
PATCH /v1/messages/:messageId/delivered
PATCH /v1/messages/:messageId/read
```

Firebase Chat:
- Backend: `POST /v1/auth/firebase-token` -> custom token for Firebase Auth
- Firestore: messages + conversations (real-time listeners)
- RTDB: canonical presence (connection/activity/routing/display status with onDisconnect)
- Storage: image uploads (5MB limit, format validation)
- FCM: push via `POST /v1/messages/push`
- Features: read/delivered receipts, block/report, delete for me/everyone, translate, anti-spam, pagination

---

## Flutter Packages

| Package | Purpose |
|---|---|
| `cloud_firestore` | Firebase Firestore — messages, conversations |
| `firebase_database` | Firebase RTDB — real-time presence |
| `firebase_storage` | Firebase Storage — image uploads |
| `firebase_auth` | Firebase Auth — custom token sign-in |
| `agora_rtc_engine: ^6.5.2` | Agora RTC — video calls + live streaming |
| `flutter_secure_storage: 10.1.0` | Token in iOS Keychain / Android Keystore |
| `google_sign_in` | Google OAuth |
| `sign_in_with_apple` | Apple Sign-In |
| `country_picker: ^2.0.27` | Country flag + dial code picker |
| `flutter_svg` | SVG rendering |

---

## Architecture Direction (Current Baseline)

These are current architectural defaults, not eternal constraints. They stay in force until a later dated audit or implementation pass deliberately replaces them and updates this section plus `.github/copilot-instructions.md`.

- **Firebase Chat** — Firestore for messages/conversations, RTDB for real-time presence (onDisconnect), Storage for image uploads. Backend generates custom Firebase tokens.
- **Firebase RTDB is the single source of truth for real-time availability** — `presence/{userId}` is not a single overloaded status string. It is the canonical availability cell for connection, activity, routing eligibility, display status, and call/live context. RTDB's `onDisconnect` guarantees cleanup even on app kill/crash. All clients listen to RTDB for user availability before initiating calls, routing random calls, or showing status badges.
- **Firebase Cloud Functions (asia-southeast1)** — 3 deployed functions provide server-side safety nets:
  - `onCallSignalDeleted`: RTDB trigger on `direct_calls/{userId}` deletion → ends Postgres call session via internal API
  - `onPresenceChanged`: RTDB trigger on `presence/{userId}` update → syncs the canonical display/availability/routing projection to Postgres, and ends the room when `displayStatus` leaves `live`
  - `reapStalePresence`: Scheduled every 5 min → scans all presence nodes, resets stale entries (>5min) to the canonical offline payload, ends orphaned live rooms
  - Internal endpoints: `POST /v1/internal/end-call-session`, `POST /v1/internal/end-room` (validated via `X-Service-Key` header)
- **Agora RTC** — replaces LiveKit for ALL video (calls + live streaming). Proprietary UDP bypasses Gulf WebRTC filtering. Single SDK, smaller APK.
- **Zero app-owned Socket.IO runtime** — All real-time product flows use Firebase RTDB, Firestore listeners, FCM, or REST. Live room comments/reactions/audience state use RTDB; trusted room status and gift events must be backend-confirmed before fan-out. Random call matchmaking uses REST + RTDB signals. There are no direct Socket.IO/WebSocket dependencies or app-owned socket paths; lockfile cleanup may still show transitive Nest websocket artifacts.
- **FCM/APNs** — push notifications for chat messages (backend relays via `POST /v1/messages/push`)
- **Firebase is truth** — Firestore is source of truth for messages/conversations. RTDB is source of truth for realtime availability, call/live signaling, visible live events, and user identity (`profiles/{userId}` — displayName, avatarUrl, countryCode, language, birthday). Backend validates economy and issues tokens.

---

## Canonical Realtime Availability Model

This section is the current contract for the realtime cell. The goal is not just "show a badge"; the goal is to make inbox, direct call, random call, live, Agora, and backend matchmaking read the same authoritative availability truth.

### Source-of-truth boundaries

| Domain | Canonical owner | Notes |
|---|---|---|
| Inbox/messages | Firestore | Message bodies, conversation metadata, read/delivered state |
| Display identity | RTDB `profiles/{userId}` | displayName, avatarUrl, countryCode, language, birthday |
| Realtime availability | RTDB `presence/{userId}` | Connection, current activity, routing eligibility, display status |
| Media session | Agora | Audio/video transport only; Agora events may trigger presence intents, but Agora does not own availability |
| Money/session ledger | Postgres | Wallets, call sessions, gifts, IAP, revenue, reports |
| Gifts | Backend + reusable gift module | Same gift catalog/animation/economy pipeline reused in inbox, live, premium live, direct call, and random call |

### Presence cell shape

`presence/{userId}` is a canonical state cell. It should be written only through the realtime availability module, never by feature screens with raw status strings.

```json
{
  "schemaVersion": 1,
  "connection": "online",
  "activity": "idle",
  "availability": "available",
  "routing": {
    "directCall": true,
    "randomCall": true
  },
  "displayStatus": "online",
  "interruptible": true,
  "roomId": null,
  "roomMode": null,
  "callSessionId": null,
  "premiumRoomSessionId": null,
  "previousActivity": null,
  "previousRoomId": null,
  "state": "online",
  "updatedAt": 1234567890
}
```

Allowed values:

| Field | Values | Meaning |
|---|---|---|
| `connection` | `online`, `offline` | RTDB reachability. Owned by connect/onDisconnect/reaper logic. |
| `activity` | `idle`, `away`, `free_live_host`, `free_live_viewer`, `premium_live_host`, `premium_live_viewer`, `live_paused`, `direct_call`, `random_call` | What the user is doing. Owned by intent methods such as `startLive`, `upgradeLiveToPremium`, `enterRandomCall`, `finishCall`. |
| `availability` | `available`, `busy`, `unavailable` | Coarse product availability. Matchmaking must never infer this from display text. |
| `routing.directCall` | boolean | Whether explicit paid direct call may route to this user. |
| `routing.randomCall` | boolean | Whether automatic random matchmaking may select this user. |
| `displayStatus` | `online`, `away`, `live`, `premium_live`, `busy`, `offline` | UI badge only. It is derived from canonical state, not used as algorithm truth. |
| `interruptible` | boolean | Whether a higher-value flow may pause the current activity. Free live can be interruptible; premium live and calls are not. |
| `roomId` | string/null | Present only for active or paused live/premium live context. |
| `roomMode` | `free_live`, `premium_live`, null | Current room monetization mode. |
| `callSessionId` | string/null | Present only during direct/random call. |
| `premiumRoomSessionId` | string/null | Present only during metered premium live participation. |
| `previousActivity`, `previousRoomId` | string/null | Used for live -> random/direct transitions and safe resume/end decisions. |
| `state` | same as `displayStatus` | Temporary legacy compatibility field. New code must read/write canonical fields first. |
| `updatedAt` | server timestamp | Last canonical state write. |

### Backend projection

Postgres stores only a queryable projection of RTDB presence. RTDB remains source of truth.

| Postgres field | Source | Purpose |
|---|---|---|
| `users.status` | `displayStatus` | Legacy/UI display fallback |
| `users.presence_connection` | `connection` | Offline/freshness projection |
| `users.presence_activity` | `activity` | Current canonical activity |
| `users.presence_availability` | `availability` | Backend availability guard |
| `users.can_direct_call` | `routing.directCall` | Direct-call API routeability |
| `users.can_random_call` | `routing.randomCall` | Random-call matchmaking routeability |
| `users.presence_updated_at` | `updatedAt` | Last canonical RTDB write mirrored to Postgres |

Backend matching and call creation must use `presence_availability`, `can_direct_call`, and `can_random_call`; they must not infer routeability from `users.status` or UI badge text.

### Canonical transitions

| Intent | Resulting state |
|---|---|
| App foreground and idle | `connection=online`, `activity=idle`, `availability=available`, `routing.directCall=true`, `routing.randomCall=true`, `displayStatus=online` |
| App idle/away | `connection=online`, `activity=away`, `availability=available`, `routing.directCall=true`, `routing.randomCall=false`, `displayStatus=away` |
| Start free live as host | `connection=online`, `activity=free_live_host`, `availability=available`, `routing.directCall=true`, `routing.randomCall=true`, `interruptible=true`, `displayStatus=live`, `roomId=<roomId>`, `roomMode=free_live` |
| Join free live as viewer | `connection=online`, `activity=free_live_viewer`, `availability=available`, `routing.directCall=true`, `routing.randomCall=true`, `interruptible=true`, `displayStatus=online`, `roomId=<roomId>`, `roomMode=free_live` |
| Upgrade free live to premium live | Host presses the premium action; backend creates premium room pricing/session; current viewers see a locked screen with entry gift/payment CTA |
| Enter premium live as host | `connection=online`, `activity=premium_live_host`, `availability=busy`, `routing.directCall=false`, `routing.randomCall=false`, `interruptible=false`, `displayStatus=premium_live`, `roomId=<roomId>`, `roomMode=premium_live` |
| Enter premium live as viewer | `connection=online`, `activity=premium_live_viewer`, `availability=busy`, `routing.directCall=false`, `routing.randomCall=false`, `interruptible=false`, `displayStatus=busy`, `roomId=<roomId>`, `roomMode=premium_live`, `premiumRoomSessionId=<sessionId>` |
| Enter direct call | `connection=online`, `activity=direct_call`, `availability=busy`, `routing.directCall=false`, `routing.randomCall=false`, `interruptible=false`, `displayStatus=busy`, `callSessionId=<sessionId>` |
| Enter random call | `connection=online`, `activity=random_call`, `availability=busy`, `routing.directCall=false`, `routing.randomCall=false`, `interruptible=false`, `displayStatus=busy`, `callSessionId=<sessionId>` |
| Free live host pulled into random/direct call | Store `previousActivity=free_live_host` and `previousRoomId=<roomId>`, pause the free live room, then enter call state |
| Premium live host receives call/random route | No transition. Premium live is non-interruptible; routing must skip the host. |
| Call ends after live was paused | `connection=online`, `activity=live_paused`, `availability=unavailable`, `routing.directCall=false`, `routing.randomCall=false`, `displayStatus=busy`, `roomId=<previousRoomId>` until host explicitly resumes or ends live |
| Resume paused free live | Return to the Start free live state |
| End live | Clear `roomId`, return to idle/away based on foreground activity |
| App disconnect/crash | `connection=offline`, `activity=idle`, `availability=unavailable`, `routing.directCall=false`, `routing.randomCall=false`, `displayStatus=offline`; cleanup functions end affected call/live sessions |

### Module ownership target

Feature screens should express intent, not RTDB protocol details.

Target modules/classes:

| Module | Owns |
|---|---|
| `PresenceRealtime` | `presence/{userId}` fields, transitions, onDisconnect, local cache, status badge derivation |
| `ProfilesRealtime` | `profiles/{userId}` reads/writes and profile cache |
| `DirectCallSignals` | Direct-call signaling schema, accept/decline/cancel/timeout cleanup |
| `RandomCallSignals` | Random match signaling schema, partner-left/next/end events |
| `LiveRoomRealtime` | Free live comments/reactions/audience reads; trusted room status should move toward backend/Admin SDK writes |
| `PremiumLiveRealtime` | Premium live lock/unlock state, premium audience presence, room mode changes, and non-interruptible realtime state |
| `GiftModule` | Reusable gift catalog, animation rendering, backend economy confirmation, and post-confirm RTDB/Firestore event fan-out |

Screens should call methods like `presence.enterRandomCall(sessionId)`, `presence.startLive(roomId)`, `presence.finishCall()`, and `directSignals.acceptCall(sessionId)`. Screens must not write raw `busy`, `live`, `offline`, `direct_calls/$id/status`, or `live_rooms/$id/status` values directly.

RTDB rules and emulator tests must enforce the same ownership model: users can write only their own presence/profile, cannot overwrite another user's call signal, cannot end another host's room, and cannot publish trusted gift/status events without backend validation.

---

## Content & Store Compliance Rules

Zephyr is an 18+ social video product. Adult age rating is a gate, not a permission slip for unmoderated sexual content.

Product law:

- App Store / Play Store listing, screenshots, onboarding, public feeds, normal live, and premium live must not promote nudity, pornographic content, prostitution, or explicitly sexual services.
- Normal live has a no-nudity rule.
- Premium live is paid access to a more intimate group experience, but still must follow platform rules, reporting, blocking, moderation, and host enforcement.
- Direct/random calls are private adult interactions between consenting adults, but the app must still provide report, block, ban, and safety tooling.
- User-generated content surfaces must include terms acceptance, report, block, moderation response, and a clear abuse channel before production launch.
- Gifts are never "maybe." Gifts are a reusable monetization primitive across inbox, normal live, premium live, direct calls, and random calls.

---

## Scaling Plan

| Users | Infrastructure | Est. cost |
|---|---|---|
| 0–5K | Current Render free tier | ~$0 |
| 5K–10K | Upgrade API to Standard + Redis Starter | ~$40/mo |
| 10K–100K | 3x instances + Pro Postgres + PgBouncer | ~$200/mo |
| 100K+ | Migrate to AWS/GCP with auto-scaling | Variable |

**Pre-production must-do:** Upgrade API from free (sleeps after 15 min) to Standard ($25/mo).

---

## MVP Completion Status

| Area | Status | % |
|------|--------|---|
| Auth (Google / Apple) | ✅ Done | 100% |
| Home feed (cards, status, real-time) | ✅ Done | 90% |
| Go Live / Host screen (Agora) | ✅ Done | 85% |
| Viewer screen (Agora) | ✅ Done | 80% |
| Direct messages (Firebase Chat) | ✅ Done | 95% |
| Explore / Search | ✅ Done | 85% |
| My Profile | ✅ Done | 92% |
| Persistent login | ✅ Done | 100% |
| Economy backend (coins, sparks, calls, gifts) | ✅ Built | 80% |
| Random video calls (Agora) | ✅ Done | 90% |
| Block system | ✅ Done | 100% |
| Push notifications (FCM) | ✅ Done (Android + iOS) | 90% |
| Report system (chat) | ✅ Done | 100% |
| Follow/unfollow UI | ✅ Backend-backed, needs smoke | 85% |
| Wallet / coins UI | ✅ Built, needs store smoke | 85% |
| Gifts during live | ✅ Live path built | 70% |
| Report system (calls) | ✅ UI + backend path wired, needs smoke | 90% |
| Direct call (signaling + video) | ✅ Done | 96% |
| Cloud Functions (call + live + reaper) | ✅ Done | 100% |
| App icon + splash | ✅ Done | 100% |
| Onboarding flow | ✅ Done | 100% |

---

## Known Blockers Before Ship

| Blocker | Solution |
|---|---|
| ~~Agora env vars not on Render~~ | ✅ Done — `AGORA_APP_ID` + `AGORA_APP_CERTIFICATE` confirmed in Render dashboard |
| ~~Mock cards in feed~~ | ✅ Done — feed uses backend/live/profile data; follow/feed polish remains separate |
| Render API sleeps | Upgrade to Standard plan ($25/mo) |
| ~~In-call report button missing~~ | ✅ Done — DirectCallScreen has report UI and direct calls exit to Message/Report/Done post-call safety flow |
| ~~Stale Flutter widget test~~ | ✅ Done — current widget tests pass and no longer require Firebase-backed `MyApp` |
| Stale non-Markdown contracts/helpers | Refresh OpenAPI, smoke/e2e guest-login helpers, and stale socket/LiveKit comments |
| ~~No direct call ringing~~ | ✅ Done — RTDB signaling + Agora video + accept/decline overlay |
| ~~Stale call/live sessions~~ | ✅ Done — Cloud Functions (onCallSignalDeleted + onPresenceChanged + reapStalePresence) |

---

---

## Coin Packages (In-App Purchase)

Users buy coins with real money. These are the available packages:

| Price (USD) | Coins | Coins per dollar |
|-------------|-------|-----------------|
| $2.99 | 16,500 | ~5,519 |
| $5.99 | 33,000 | ~5,509 |
| $9.99 | 55,000 | ~5,505 |
| $29.99 | 165,000 | ~5,502 |
| $59.99 | 330,000 | ~5,501 |
| $99.99 | 550,000 | ~5,501 |

**Ratio is flat** — no meaningful bulk discount. ~5,500 coins per dollar across all tiers.

---

## Direct Calls (caller → receiver, per minute)

Receiver sets their own rate based on their level. They earn 60% of what the caller pays.

These are product default rate options. Backend config/database owns the active options; mobile renders the options returned by API.

| Tier | Caller pays (coins/min) | Receiver earns (sparks/min) | Platform keeps |
|------|------------------------|----------------------------|----------------|
| ≤Lv3 | 2,100 | 1,260 | 840 |
| Lv4  | 3,200 | 1,920 | 1,280 |
| Lv5  | 4,200 | 2,520 | 1,680 |
| Lv6  | 5,400 | 3,240 | 2,160 |
| Lv7  | 6,400 | 3,840 | 2,560 |
| Lv8  | 8,000 | 4,800 | 3,200 |
| Lv9+ | 27,000 | 16,200 | 10,800 |

---

## Random Calls (per minute)

| | Coins/min |
|---|---|
| Caller pays | 600 |
| Receiver earns | 360 (60%) |
| Platform keeps | 240 (40%) |

These are product defaults. Backend config owns the active random-call rate and split.

---

## Reusable Gift Module

Gifts are a first-class reusable monetization primitive, not a live-only feature.

| Surface | Gift behavior |
|---|---|
| Inbox | Send a gift from a DM thread; message timeline shows the gift event |
| Normal live | Viewers send gifts during free live |
| Premium live | Viewers can pay the entry gift/sticker and continue sending gifts inside |
| Direct call | Caller can send gifts during paid 1:1 call |
| Random call | Caller can send gifts during paid random call |

Gift rules:

- One gift catalog and one animation renderer are reused across all surfaces.
- Backend validates balance, deducts coins, records the ledger transaction, credits host sparks/revenue, then emits/permits the visible gift event.
- Gift events are visible UX; wallet/revenue truth is always Postgres.
- Default split: host receives 60% value in sparks/revenue, platform keeps 40% before infrastructure and store economics are modeled.
- Gift assets are CDN-hosted Lottie/SVGA/animation payloads; 0 heavy gift animations ship in the app bundle.

---

## Premium Live Rooms (paid group live)

Premium live is Zephyr's original monetized group mode: a host can convert a normal free live into a paid room.

| Mode | Many viewers? | Paid per minute? | Gifts? | Interruptible by direct/random call? |
|---|---:|---:|---:|---:|
| Normal live | yes | no | yes | yes |
| Premium live | yes | yes | yes | no |
| Random call | no | yes | yes | no |
| Direct call | no | yes | yes | no |

Premium live mechanics:

- Host starts a normal live first.
- Host can press an upgrade action to transition the room into premium live.
- Existing viewers see the stream locked and must send/pay an entry gift, such as a 200-coin car sticker, to enter.
- After entry, viewers are billed per minute while inside, for example 600 coins/min.
- Premium live entry fee and per-minute rate are set by the host within level-based limits.
- All premium live limits are backend-configured variables, not client hardcodes.
- Host earns a percentage of entry gifts, per-minute premium live billing, and gifts sent inside the room.
- Premium live is non-interruptible: direct call and random-call routing must skip the host while premium live is active.
- If a viewer balance is insufficient, backend ends that viewer's premium room session and the UI returns to the locked state or exits.
- RTDB owns realtime lock/unlock/audience/comment/reaction display; Postgres owns paid room sessions, billing ticks, entry payments, and revenue.

Premium live is not a replacement for direct/random calls. It fills the gap between free discovery live and private 1:1 monetization: many customers can pay modestly at the same time, while the host gets a stable earning mode.

---

## Leveling & Limits

Zephyr has two separate level systems. Do not mix them.

| Track | Who | Measures | Unlocks |
|---|---|---|---|
| Host Level | Hosts/creators | earning quality, completed paid minutes, gifts received, retention, trust, low reports | direct-call rate options, premium live pricing limits, premium viewer caps, discovery priority |
| Customer VIP Level | Customers/spenders | purchases, gifts sent, paid minutes, loyalty, account trust | profile frames, gift perks, coupons, support priority, cosmetic status |

The inspiration from apps like Tango is the shape, not the exact economy: loyalty/VIP systems reward purchases, gifts, and recurring monthly status, while creator levels should reflect earning power and platform trust. Zephyr's originality is that host earning level and customer VIP level are separate canonical tracks.

### Host Level

Host Level is the creator's earning/trust level. It should be earned by useful activity, not just account age.

Host XP inputs:

- Cleared sparks/revenue earned from direct calls, random calls, premium live, and gifts.
- Completed paid minutes with low dispute/report rate.
- Gifts received from unique customers.
- Free-live to paid conversion quality.
- Repeat customer/follower retention.
- Active hosting days.
- Manual verification and moderation trust.

Host XP exclusions/penalties:

- Refunded, charged back, or fraud-flagged purchases do not count.
- Sessions later marked abusive, fake, or policy-violating can remove XP.
- High report rate, bans, chargeback clusters, or moderation strikes can freeze level progression or demote caps.

Host Level controls configurable limits:

| Config key | Meaning |
|---|---|
| `canStartPremiumLiveDirectly` | Whether host can open premium live without first starting free live |
| `premiumEntryGiftCoinMin` / `premiumEntryGiftCoinMax` | Allowed entry gift/sticker range |
| `premiumRateCoinsPerMinuteMin` / `premiumRateCoinsPerMinuteMax` | Allowed premium live per-minute range |
| `premiumViewerCap` | Max paying viewers in premium live |
| `freeLiveViewerCap` | Max viewers in normal live |
| `directCallRateOptions` | Direct-call rate choices available to host |
| `randomMatchWeight` | Discovery/matchmaking boost for trusted high-level hosts |

Suggested policy:

- Early hosts can start free live and upgrade to premium live only after minimum room activity.
- Trusted mid-level hosts can start premium live directly with conservative limits.
- High-level verified hosts get higher entry/rate/viewer caps and stronger discovery.
- All limits live in backend config/database tables. Mobile reads allowed options from API and never hardcodes pricing.

### Customer VIP Level

Customer VIP Level is spender loyalty plus account trust. It should make customers feel recognized without letting them bypass safety rules.

VIP XP inputs:

- Settled in-app purchases.
- Gifts sent across inbox, live, premium live, direct calls, and random calls.
- Paid minutes consumed in direct/random/premium live.
- Recurring monthly activity.

VIP XP exclusions/penalties:

- Refunded or charged-back purchases remove VIP progress.
- Fraud, abusive behavior, or moderation actions can freeze VIP perks.
- VIP level never bypasses report/block/moderation systems.

VIP Level controls configurable perks:

| Config key | Meaning |
|---|---|
| `profileFrame` | Cosmetic frame/badge |
| `chatBadge` | Visible badge in inbox/live comments |
| `monthlyCoupons` | Optional coin/gift purchase coupon count |
| `freeGiftAllowance` | Optional reusable gift allowance |
| `supportPriority` | Support priority tier |
| `premiumRoomPerks` | Optional cosmetic/queue perks, never free unauthorized entry |

Suggested policy:

- Maintain both `rolling30dVipLevel` and `lifetimeVipRank`.
- Rolling VIP creates monthly motivation; lifetime rank preserves prestige.
- VIP progress is backend-calculated from cleared ledger data.
- VIP perks are configurable and can be A/B tested without client releases.

### Level Config Contract

Level rules are product variables. Store them server-side and expose them through API.

```json
{
  "schemaVersion": 1,
  "hostLevels": [
    {
      "level": 1,
      "canStartPremiumLiveDirectly": false,
      "premiumEntryGiftCoinMin": 0,
      "premiumEntryGiftCoinMax": 0,
      "premiumRateCoinsPerMinuteMin": 0,
      "premiumRateCoinsPerMinuteMax": 0,
      "premiumViewerCap": 0,
      "freeLiveViewerCap": 0,
      "directCallRateOptions": [],
      "randomMatchWeight": 1.0
    }
  ],
  "customerVipLevels": [
    {
      "level": 1,
      "rolling30dXpRequired": 0,
      "lifetimeXpRequired": 0,
      "perks": {
        "profileFrame": null,
        "chatBadge": null,
        "monthlyCoupons": 0,
        "freeGiftAllowance": 0,
        "supportPriority": "standard"
      }
    }
  ]
}
```

---

## Platform Economics (Calls Only — No Gifts)

> Worst-case estimate. Assumes 100% of user spend goes to random calls. Gifts are pure margin on top of this.

**Per $1.00 a user spends — full cost waterfall:**

| Deduction | Amount |
|---|---|
| User pays | $1.00 |
| − Apple / Google store cut (30%) | −$0.30 |
| − Host payout (60% of coins) | −$0.42 |
| **Gross profit** | **$0.28** |
| − Agora random call (~$0.008/min × ~9.2 min) | −$0.074 |
| **Net before fixed costs** | **~$0.206 per $1** |

**Monthly fixed infrastructure costs:**

| Service | Cost/month |
|---|---|
| Apple Developer Account | ~$8.25 |
| Google Play Developer | ~$0 (one-time $25, done) |
| Render API (Standard, no sleep) | $25.00 |
| Render PostgreSQL | $7.00 |
| Render Redis (when added) | $12.00 |
| Firebase (FCM + Auth) | $0.00 (free tier to ~50K MAU) |
| Domain / SSL | ~$1.25 |
| **Total fixed** | **~$53.50/month** |

**Net profit projection (random calls only, no gifts):**

| Monthly gross revenue | Variable net (20.6%) | − Fixed costs | **Monthly net profit** | Effective margin |
|---|---|---|---|---|
| $500 | $103 | −$53.50 | **$49.50** | 9.9% |
| $1,000 | $206 | −$53.50 | **$152.50** | 15.3% |
| $2,500 | $515 | −$53.50 | **$461.50** | 18.5% |
| $5,000 | $1,030 | −$53.50 | **$976.50** | 19.5% |
| $10,000 | $2,060 | −$53.50 | **$2,006.50** | 20.1% |

**Floor is ~20% net margin** at scale on calls alone. Gifts push this toward 28%.  
Calls are the volume driver. Gifts are the profit driver.

---

## Video Infrastructure: Agora

Chosen for its proprietary UDP protocol that bypasses Gulf region (UAE, Saudi) WebRTC filtering — a hard requirement for our target market. Single SDK covers both calls and live streaming.

**Agora live streaming cost breakdown:**

| Scenario | Host | Viewers | Duration | Agora cost |
|---|---|---|---|---|
| Small stream | 1 | 10 | 1hr | ~$0.72 |
| Medium stream | 1 | 50 | 1hr | ~$3.12 |
| Large stream | 1 | 200 | 1hr | ~$11.52 |

> Free live audience is naturally self-limiting: users in a random call cannot simultaneously watch a free live stream. Random calls pull users out of passive watching into active paid calls. Premium live is different: it is already paid and non-interruptible.

**Live stream viewer cap (by host level):**

These are product default caps. Backend config/database owns the active values; mobile must not hardcode them.

| Host Level | Max Viewers | Agora cost (1hr, no gifts) |
|---|---|---|
| ≤Lv3 | 20 | ~$1.32 |
| Lv4–Lv5 | 50 | ~$3.12 |
| Lv6–Lv8 | 100 | ~$5.92 |
| Lv9+ | 200 | ~$11.52 |

Caps serve two purposes: protect the platform from costly zero-gift streams at low levels, and incentivise hosts to level up (more viewers = more gift potential = more earning). In practice, free-live viewer counts stay lower because random calls can pull users into paid calls; premium live uses paid entry/per-minute billing instead.

---

## Random Call Strategy

Random calls are priced cheap intentionally (600 coins/min = ~$0.11/min to caller). The goal is volume, not margin per call.

**Why random calls win at scale:**
- Low barrier to tap → high frequency of use
- Caller is always paying — no passive free-riders like live
- 1,000 users × 30 min/day = 30,000 call-minutes/day = **~$6,180/month net profit** (before gifts)
- Margin is thin per call (~20%) but volume makes it the biggest revenue line

**Random call as a hook:**
- Caller meets someone interesting → wants to call them again → books a direct call (higher rate)
- Direct call rates are 3.5× to 45× higher than random → upsell path
- Random call is the entry drug; direct call and gifts are the monetisation

**Free Live → Random / Premium Live → Direct Call funnel:**
1. User watches a live stream (free, no cost to them)
2. User taps random call, or host upgrades the room to premium live
3. User pays 600 coins/min in random or premium live
4. User likes the host → books direct call (Lv6 = 5,400 coins/min)
5. During inbox/live/premium/calls, user sends gifts → highest margin reusable feature

---

## Call Types & Mechanics

### Random Call

| State | Coins | What happens |
|---|---|---|
| Searching | 0 | Algorithm finds match (priority: interruptible free-live hosts → idle hosts/users) |
| Connected | 600/min | Both parties in call, coins tick |
| Next tapped | 0 | Coins stop instantly, screen blurs, new match search begins |
| New match found | 600/min | Coins resume |
| Call ended | 0 | Call over, coins stop |

- Both parties opt in implicitly — no accept/decline screen
- If matched host is in free live: their stream **pauses**, status → **busy**
- If host is in premium live: skip; premium live is non-interruptible
- When random call ends: stream stays paused — host must manually resume (safety)
- "Next" is free — no coins charged during transition between randoms

### Direct Call (paid, receiver sets rate)

- Caller initiates from receiver's `ProfilePage` → writes to Firebase RTDB at `/direct_calls/{receiverUserId}`
- RTDB payload: `callerId`, `callerName`, `callerAvatarUrl`, `sessionId`, `status`, `ts`
- Receiver's `HomeScreen` listens on that RTDB path → shows `IncomingCallOverlay` (accept/decline)
- On accept: both navigate to `DirectCallScreen` (Agora video), backend `startCallSession` begins billing
- On decline: caller is not charged, RTDB node cleaned up
- Rate is set by receiver based on their level (2,100 → 27,000 coins/min)
- Receiver earns 60% of the rate they set
- Camera-off detection: `onRemoteVideoStateChanged` with reason-based muting (not state-based) to avoid false positives on camera flip

---

## Screens & UI

### Onboarding (`features/onboarding/`)

Two screens, one flow:

**1. Login — `onboarding_page.dart`**
- Dark background (`#150805`) with mascot branding (60% of screen)
- Apple Sign-In button (iOS only, shown first) + Google Sign-In button
- No guest login — real identity required
- API offline warning banner (checks `/health/live` on init)
- Buttons disabled during loading, error text below
- Legal links at bottom: Terms of Service + Privacy Policy (opens in browser)
- On success: checks `user.onboardedAt` — if null → profile setup, else → home

**2. Profile Setup — `profile_setup_screen.dart`**
- 2-page horizontal PageView (no swipe — programmatic navigation only)
- **Page 1 — Gender:** "I am" heading, two large gradient cards (Male / Female). Tap auto-advances after 300ms
- **Page 2 — Language:** Grid of 12 languages (EN, AR, PT, ES, FIL, HI, ID, TH, VI, ZH, FR, RU) with flag emoji. Back button to return to gender
- On language select: calls `PATCH /v1/users/me` (gender + language + auto-detected country), persists a default host card cover for Female hosts when `coverUrl` is empty, writes profile to RTDB `profiles/{userId}`, then navigates to home
- `onboardedAt` set server-side via `COALESCE(onboarded_at, NOW())` — idempotent

### App Shell

5-tab bottom navigation bar (accent `#FF8F00` amber):

| Index | Icon | Label | Badge |
|---|---|---|---|
| 0 | auto_awesome_rounded | For you | — |
| 1 | favorite_rounded | Following | — |
| 2 | live_tv_rounded | Live | — |
| 3 | explore_rounded | Explore | — |
| 4 | chat_bubble_rounded | Inbox | Unread count (99+ cap) |

---

### Tab 0 — For you

Target: Tango-style live discovery feed at real supply scale, not a filtered user directory.

Shared Zephyr header plus dense `HostCardGrid`:
- 2 columns x 2 visible rows on phone
- Thin 4px gutters
- Barely-rounded card corners, mostly rectangular
- No visible user filter on For you
- Feed should scale to hundreds/thousands of live host/girl cards per day; the visible 2x2 grid is only the viewport
- Launch-minimum implementation requests live-only paged feed data; offline hosts do not appear as normal For you cards
- Uses persisted host `coverUrl` first; Female hosts get one identity-seeded default local cover during onboarding, uploaded covers replace it, and identity-seeded local fallback remains for old/offline data
- Card shows viewer count so users can read stream momentum before entering
- Main card/image tap enters the host live room when a live `roomId` exists; tapping the compact avatar/name/flag identity strip opens the host profile
- Pull-to-refresh/elastic swipe down reloads the live set and can reshuffle discovery ordering
- Infinite scroll/lazy loading is in place through `limit` + `offset`; never load the full live supply into memory at once
- If no live host is returned, For you shows a premium empty state with customer Random match CTA instead of fake suggested cards
- Later polish: short live preview for visible cards while scrolling, header/footer hide on upward scroll and return on small downward scroll, and a floating recording/live action that hides with the footer
- Deferred: mini-live floating rectangle after leaving a live. It is useful Tango behavior but too complex for this pass

### Tab 1 — Following

- Reuses the exact same `HostCardGrid` instance/pattern as For you, filtered to followed users only
- Empty state: "Follow someone to see them here"
- Green **"Random match"** button pinned at bottom

**Feed card anatomy:**
- Background gradient: `#1C1C2E` → `#2D2D44` (dark purple-blue)
- Top-left: status badge — `Live` (red `#FF3B30`) / `Busy` (orange `#FF9500`) / `Online` (green `#34C759`) / `Offline` (grey `#8E8E93`)
- Bottom-left: compact circular host avatar + host display name + country flag/language context
- No immediate card call button; future preview cards may reveal a timed "phantom" call CTA after intent is detected

**Random match button:**
- Color: `#7BEA3B` (bright green), black text
- Tapping: opens the random-call flow and starts matchmaking at 600 coins/min

---

### Tab 2 — Live

Centered screen with:
- Radial amber glow behind a flame-gradient circle icon (`live_tv_rounded`)
- Large "Go Live" heading
- Subtitle: "Start Live Stream and Connect"
- Button → `GoLiveCountdownPage` (3-2-1 countdown) → `HostLiveScreen`

---

### Tab 3 — Explore

→ `ExplorePage` — search users by name or 8-digit public ID

---

### Tab 4 — Inbox

→ `InboxPage` — conversation list, unread badges, timestamps

---

### 💰 0. Revenue Feature — Random Call (Agora)

> Store compliance: 17+ age rating. ToS prohibits explicit content. Report button = safety net. Reactive bans only at v1.

**Backend** ✅
- [x] Matchmaking queue — REST endpoints (`seek/cancel/next/end`) + RTDB match signals; block-aware pairing
- [x] Call session table — `call_sessions` (id, user_a_id, user_b_id, agora_channel, started_at, ended_at, ended_by)
- [x] Agora token generation — `rtc.service.ts` generates per-user tokens via `agora-token` npm package
- [x] Coin billing — `tickCallSession` every 15s; 600 coins/min
- [x] Block system — `user_blocks` table; blocked users cannot be matched
- [x] Report endpoint — `POST /v1/economy/calls/:sessionId/report`; stores one report per reporter/session and counts reports against the reported user
- [x] Auto-ban threshold — 5+ reports in 7 days -> `is_banned = true`; banned users rejected from queue

**Flutter** ✅
- [x] "Random match" button on Home tab → navigates to `RandomCallScreen`
- [x] Waiting/searching screen — animated pulsing ring, Cancel button calls `DELETE /v1/calls/random/seek`
- [x] In-call screen — full-screen remote video (Agora), local PiP top-right, End / Next / Mute / Flip controls
- [x] Skip / Next — 600ms blur transition, re-joins queue, no coins during transition
- [x] `event=partner_left` RTDB signal -> auto re-searches
- [ ] Post-call screen — "Call ended", option to send a DM
- [ ] Report button in-call

**Block system** ✅
- [x] `POST/DELETE/GET /v1/users/:userId/block` endpoints
- [x] Profile page `⋮` menu → Block / Unblock with confirmation dialog
- [x] Matchmaking rejects pairs where either user has blocked the other

**Store compliance (one-time setup, no code)**
- [ ] Set 17+ rating — App Store Connect → Age Rating
- [ ] Set 17+ rating — Google Play Console → Content Rating wizard
- [ ] Terms of Service — "Users must be 17+. Explicit content is prohibited."

---

### 🔴 1. Ship Blockers

- [x] Apple Developer account ($99/yr)
- [x] Google Play Developer account ($25 once)
- [x] iOS APNs — APNs Auth Key uploaded to Firebase; Push Notifications entitlement added
- [x] Sign in with Apple — App ID registered, Xcode entitlement added, backend endpoint done

---

### 🟠 2. First Impression

- [x] Onboarding flow — login (Google + Apple) → profile setup (gender → language), auto-detect country, writes to RTDB profiles
- [x] Follow / unfollow UI — backend endpoints, deployed following-ID parsing, footer Following feed, ProfilePage follow toggle, and follower counts are wired
- [x] Empty Following feed state — tells users to follow someone when the Following tab has no followed hosts
- [ ] Optimistic message send — bubble appears instantly before server ACK (~8% messaging gap)

---

### 🟡 3. Product Completeness

- [x] Wallet / coins UI — balance display, store catalog state, top-up packs, revenue/rate/level pages; still needs Play internal-test purchase smoke
- [ ] Gift tray during live / calls — live gift tray is wired to backend-confirmed room gifts; call/inbox/premium surfaces still need shared module wiring
- [ ] Gift sending from DM — wait for reusable Gift module; backend call-gift ledger exists, but DM gift API/UI is not wired
- [ ] Typing indicator — "..." bubble when other user is typing
- [ ] Message ordering under rapid fire — no sequence numbers; 3 fast messages can appear out of order (~3% gap)
- [ ] MessageCache eviction — thread messages unbounded in memory; causes pressure on long sessions (~2% gap)
- [x] Report user in-call — DirectCallScreen exposes report action on top of existing `POST /v1/economy/calls/:sessionId/report` endpoint
- [x] Direct call ringing — caller sees "calling…", receiver gets accept/decline overlay (RTDB signaling)
- [x] Post-call screen — "Call ended", Message, Report, and Done actions
- [ ] Custom Sentry breadcrumbs — log RTDB/FCM/message send/login lifecycle events

---

### 🟢 4. Needs Testing

- [ ] Double tick cross-device — send from iPhone, read on Android → verify blue tick on iPhone
- [ ] Render upgrade — free tier sleeps after 15 min; upgrade to Standard ($25/mo) before real users
- [ ] Redis on Render — add Redis Starter ($10/mo) + set `REDIS_URL` env var; code already wired
- [ ] Logout stops push — verify no push received after logout
- [x] Send failure UI — verified: red bubble → tap retry → sends

---

### 🔵 5. Polish

- [ ] App icon — replace default Flutter icon with Zephyr brand
- [ ] Splash screen — branded launch screen
- [ ] Emoji / sticker picker — basic emoji in thread
- [ ] Dark mode — respect system preference
- [ ] Profile editing QA — verify country, language, birthday save/display end-to-end

---

### ⚪ 6. Post-Launch

- [ ] TestFlight — iOS release build, App Store Connect submission
- [ ] Play Store — signed AAB, store listing, screenshots
- [ ] Web admin panel — moderate users, manage rooms, analytics

---

### ✅ Done

- [x] Agora integration — replaces LiveKit entirely for all video (random calls + live streaming)
- [x] Random call matchmaking — REST + RTDB signals, Agora token per-user, block-aware queue
- [x] Block system — `user_blocks` DB table, REST endpoints, profile UI, matchmaking guard
- [x] Host live screen — Agora broadcaster role, flip camera, mute, heartbeat
- [x] Viewer live screen — Agora audience role, remote video, reactions
- [x] Android APK size — `packaging.jniLibs.excludes` strips x86/x86_64/armeabi for debug builds (175MB debug → ~50MB prod per-device)
- [x] Gift assets strategy — all gift animations hosted on CDN (Lottie JSON/SVGA), downloaded on demand; 0 gift assets ship in APK
- [x] Message pagination — cursor-based; backend returns `hasMore`; scroll-to-top triggers fetch
- [x] Pagination slice bug fixed — `getThread` slice(1) fix; was cutting off newest message >50 msgs
- [x] Send failure UI — red bubble + retry
- [x] Idempotency key — `X-Idempotency-Key` header on every `sendMessage`
- [x] Message read receipts — single tick (dark) = sent, double tick (blue) = read
- [x] Thread date separators — Today / Yesterday / date headers
- [x] Firestore listener stability — inbox/thread listeners resubscribe cleanly with app lifecycle/session changes
- [x] Real-time delivery — Firestore listeners route committed messages to open ThreadPage
- [x] Cursor-based reconnect sync — fetches only messages after last known timestamp on reconnect
- [x] Cross-device send confirmation — Firestore commit + backend-verified push keep sender/receiver state in sync
- [x] Android FCM — push on message send, coalesced per sender
- [x] Tap notification → Inbox tab
- [x] FCM token cleanup on logout
- [x] iOS Firebase init — `firebase_options.dart`, Podfile iOS 15.0
- [x] Unread badge — Firestore unread state + app-resume refresh clears on open
- [x] Avatar image caching — `CachedNetworkImageProvider` across all screens
- [x] Persistent HttpClient — single client reused across all API calls
- [x] Sentry Flutter + NestJS — uncaught exceptions captured
- [x] Auth — Google, Apple (iOS + Android)
- [x] Home feed — live cards, user cards, RTDB presence/profile listeners
- [x] Inbox — conversation list, unread badges, timestamps
- [x] Thread (DM) — chat bubbles, send, mark-read, auto-scroll
- [x] Explore — search by name or 8-digit public ID
- [x] Live streaming — host + viewer screens, timer, viewer count
- [x] Avatar upload — Cloudinary, camera/gallery picker
- [x] Profile editing — nickname, gender, birthday, country, language
- [x] Settings — logout at Me → ⚙ Settings → Sign Out
- [x] Socket.IO app runtime removed — product real-time uses Firebase RTDB, Firestore listeners, FCM, and REST; no direct socket dependency or app-owned socket path remains
- [x] Mock data removed — mock feed cards, mock followingIds, debug logs gone
- [x] Direct call — RTDB signaling (`/direct_calls/{receiverUserId}`), incoming call overlay (accept/decline), Agora video screen with remote mute detection, camera-off PIP placeholder, dispose cleanup
- [x] Direct call camera-off handling — remote mute detected via `onRemoteVideoStateChanged` (reason-based, not state-based), camera flip no longer triggers false "camera off" on remote side

---

## Audit Log

Quality grades (A+ to F) recorded after each feature audit. This is our history of quality.

Later-dated audits supersede older entries when implementation has moved on. Historical entries are preserved for context, but the current working truth is the 7 Jun 2026 snapshot and later audit blocks.

### Live Streaming — 29 May 2026 — Overall: A+
| Aspect | Grade | Notes |
|--------|-------|-------|
| Architecture | A+ | Agora RTC + RTDB signaling, Cloud Function auto-ends on disconnect. Zero dead code — backend is pure REST (create/join/leave/end/gift/token), all real-time flows through RTDB directly. |
| Reconnection | A | `onConnectionStateChanged` with overlay, token refresh handler |
| Rate limiting | A | 500ms throttle on reactions/comments |
| Error handling | A | User-facing snackbars, graceful fallback |
| Resource cleanup | A | `_ending` guard prevents double-end, proper dispose |
| Code quality | A+ | ValueNotifier for comments, isolated state, no leaks, zero dead endpoints or unused dependencies |

### Messaging / Inbox — 7 Jun 2026 — Overall: A+ core and media, Gift module pending
| Aspect | Grade | Notes |
|--------|-------|-------|
| Architecture | A+ | Firestore owns chat/message state, RTDB owns presence/profile state, Storage owns chat images, backend owns moderation and verified FCM. No polling and no client-owned money/security decisions. |
| Message correctness | A+ | Text/image sends write message + unread + last-message metadata in one Firestore transaction; idempotency keys use deterministic message IDs so retries cannot double-send. |
| Firestore rules | A+ | Emulator suite proves participant-only chat creation, immutable participants, bounded unread counters, committed-message shape, receiver-only receipts, constrained delete-for-me/delete-for-everyone, and block projection denial. |
| Storage rules | A+ | Chat uploads are owner-scoped and immutable under `chats/{chatId}/{uploaderId}/`; emulator suite proves participant reads, outsider denial, uploader-only writes, image/type/size bounds, and no overwrite/delete. |
| Moderation | A+ | Blocks and reports route through backend `user_blocks`/`user_reports`; backend writes Firestore block projections so message rules can reject blocked conversations. |
| Push | A+ | Client no longer sends arbitrary notification title/body; backend verifies the committed Firestore chat/message before sending FCM and includes a `source=firestore` marker. |
| Presence/logout | A+ | Foreground/background availability uses the canonical RTDB cell; logout now awaits offline write, FCM unregister, and chat session cleanup before clearing the API token. |
| UX | A | Inbox/thread include search, live preview, inline translation, text/image send, read receipts, direct-call entry, block, and report. Missing: typing indicator, message reactions, and the reusable gift picker. |
| Gift readiness | Pending | Inbox gifts should wait for the reusable Gift module pass so inbox, direct call, random call, premium live, and normal live share one catalog/economy component. |

### Call (Direct + Random) — 29 May 2026 — Overall: A
| Aspect | Grade | Notes |
|--------|-------|-------|
| Architecture | A+ | REST matchmaking + RTDB signaling + Agora RTC. No app-owned Socket.IO runtime remains. Random inherits from Direct (shared DirectCallScreen). |
| Signaling | A | writeRinging → listen accept/decline → 30s timeout → Agora. Block check both directions. Cloud Function safety net on signal deletion. |
| Economy/Billing | A- | Tick every 15s, billing starts only when partner joins, insufficient balance auto-ends call |
| Reconnection | A | `onConnectionStateChanged` with overlay, `onTokenPrivilegeWillExpire` with renewal |
| Error handling | A | User-facing snackbars (balance, connection, Agora errors), graceful fallback, tick retries silently |
| Resource cleanup | A- | `_disposed` guard, engine release in dispose, timers cancelled. `_leaveWithResult` for random mode. |
| Security | A | Block check both directions, backend validates all billing, service key on internals |
| Code quality | A+ | Random = thin matchmaking layer inheriting DirectCallScreen. Zero duplication. Zero dead code. |

### IAP / Billing — 2 Jun 2026 — Overall: A+
| Aspect | Grade | Notes |
|--------|-------|-------|
| Architecture | A+ | Flutter `in_app_purchase` → backend verify-purchase → credit coins. StoreKit 2 + Google Play Billing. Direct credit endpoint blocked in production. |
| Apple verification | A+ | Full JWS certificate chain verified against Apple G3 root CA via `decodeTransaction()`. Forged receipts detected as `CertificateValidationError`. Validates bundleId + productId cryptographically. Rejects revoked transactions. |
| Google verification | A+ | Android now sends the Play purchase token, backend verifies `packageName + productId + token` with Android Publisher API, requires service-account credentials in production, and checks purchased/unconsumed state. |
| Refund handling | A+ | Apple ASNS V2 webhook + Google RTDN webhook. Google voided purchases now refund by purchase token, not order ID. `processRefund()` deducts coins immediately, records `iap_refund`, and is idempotent. |
| Idempotency | A+ | `iap_purchases.transaction_id` UNIQUE constraint. Check-before-insert prevents double-credit. Race conditions caught by PostgreSQL. |
| Retry safety | A+ | Store completion happens only after backend confirms credit. Android consumable coin packs are consumed after credit, so users can rebuy the same pack safely. Failed verifications retry on next app launch automatically. |
| Production hardening | A+ | `POST /v1/economy/purchase-coins` blocked unless `ALLOW_FAKE_PURCHASES=true`. Flutter fallback restricted to `kDebugMode`. |
| Store catalog UX | A+ | Mobile now keeps explicit `IapCatalogState`, disables unavailable packs, shows loading/retry/status copy, displays Play/App Store localized prices for active products, and logs missing product IDs so Play Console setup issues are obvious during smoke testing. |
| Code quality | A+ | Singleton `IapService.instance`. Clean separation: Flutter handles store interaction, backend handles all validation + crediting. Zero trust on client. |

### Onboarding — 7 Jun 2026 — Overall: A+
| Aspect | Grade | Notes |
|--------|-------|-------|
| Architecture | A+ | Google + Apple login flows are injected behind `OnboardingAuthGateway`, profile setup dependencies are injectable, and incomplete saved sessions resume directly into setup instead of forcing re-auth. |
| Login flow | A+ | Buttons disable during loading, API offline warning remains, OAuth cancellation gets product-safe copy, raw exception strings are not shown, and legal/17+ copy is explicit and accessible. |
| Profile setup | A+ | Gender/language setup uses localized display text while preserving stable backend values, auto-detects country through an injectable resolver, awaits backend profile save and RTDB profile sync before entering Home, and exposes semantic selection/progress states. |
| Backend | A | `issueGoogleSession` / `issueAppleSession` -> find-or-create user -> JWT. `updateMe` sets `onboarded_at` via COALESCE on first profile save. Backfill migration for existing users. |
| Session restore | A+ | `main.dart` now keeps a valid saved token for incomplete profiles and resumes `ProfileSetupScreen`; completed users still skip setup on re-login. |
| Security/compliance | A+ | No guest login path or generated guest localization remains; Google/Apple tokens are verified server-side; onboarding shows 17+ requirement plus Terms/Privacy links before sign-in. |
| Testability | A+ | `flutter test` now covers current OAuth/legal surface, no guest copy, cancellation copy, and new-user setup ordering; `flutter analyze` passes. |
| Code quality | A+ | Clean module split remains, tap recognizer leak was removed from legal links, profile RTDB write is awaited, and `UserProfile.derivePublicId` recursion was fixed after tests surfaced it. |

### Me / Profile / Wallet Entrance — 7 Jun 2026 — Overall: A
| Aspect | Grade | Notes |
|--------|-------|-------|
| Me dashboard | A | Me tab now loads the wallet summary and shows coins, sparks, revenue, and call price at a glance, with taps into Wallet, Level, Revenue, and Call Price. It refreshes wallet metrics when returning from those screens. |
| Profile return correctness | A+ | Avatar and cover uploads now preserve the full `UserProfile` state when returning to Me, including cover URL, host/admin flags, follower/following counts, onboarding state, and call rate. |
| Settings navigation | A | Account, Privacy, and Notifications rows are now real routes. Account exposes sign-out/delete, Privacy opens Terms/Privacy, and Notifications explains the currently supported alert surfaces. |
| Economy subpages | A- | Wallet, Level, and Revenue now show spark context instead of isolated numbers, and Level/Revenue support pull-to-refresh/retry. A+ still needs revenue statement/payout depth and real notification preference persistence. |
| Test coverage | A | Widget coverage now proves Me dashboard metrics render and Settings subpages open. `flutter analyze` passed and `flutter test` passed 7/7 on 7 Jun 2026. |
| A+ gates | Pending | Manual iPhone smoke, localized copy for the new settings/economy labels, persisted notification controls or a system-settings deep link, and deeper host revenue/payout history. |

### RTDB Architecture & Data Modeling — 3 Jun 2026 — Historical: A- (superseded by 7 Jun RTDB audits)
| Aspect | Grade | Notes |
|--------|-------|-------|
| Data model | A+ | 4 clean root nodes only: `presence`, `profiles`, `direct_calls`, `live_rooms`. Flat, predictable paths. |
| Normalization | A+ | Identity is centralized in `profiles/{userId}`. No broad denormalized name fan-out in persistent docs. |
| Presence robustness | A+ | `onDisconnect` + Cloud Function sync/reaper gives strong crash/offline recovery. |
| Client caching | A | LRU subscription cache (50 cap) for presence and profiles. RTDB remains source of truth. |
| Security rules | B- | `direct_calls` and `live_rooms/status` are too permissive; need stricter writer validation. |
| Indexing | C | Missing `.indexOn` for `comments.ts`, `reactions.ts`, `gifts.ts`; add indexes to avoid scans/warnings. |
| Scale posture | A- | Current approach is strong for MVP and early growth; scheduled global presence scan should evolve later at very high scale. |

### Full Solution Audit — 5 Jun 2026 — Historical: B- (superseded by 7 Jun full audit)
| Aspect | Grade | Notes |
|--------|-------|-------|
| Product architecture | A- | Strong Flutter + NestJS + Postgres + Firebase RTDB/Firestore + Agora split. Clear source-of-truth intent and good MVP focus. |
| Hard-rule compliance | B | Source mostly avoids Socket.IO and centralizes RTDB in `FirebaseChatService.instance`; docs/comments still contain socket/polling drift, and API room heartbeat/cleanup uses periodic HTTP/timers. |
| Backend money safety | C | IAP and call/gift billing need real PostgreSQL transactions/idempotency. `IapService` uses `BEGIN`/`COMMIT` through pooled queries, so it is not a guaranteed transaction; call ticks can double-charge or lose session totals under retry/concurrency. |
| Random call flow | C | Backend matches live/online hosts, but only `RandomCallScreen` consumes `event: matched`. Hosts on Home/Live do not auto-join, so the core revenue flow can create sessions where the caller waits and the receiver never enters. |
| Firebase security | C+ | Firestore/Storage are reasonable for MVP, but RTDB `direct_calls`, `live_rooms/status`, and gift/comment/reaction writes are too permissive. UI events can be spoofed even when backend balances are safe. |
| IAP production readiness | C | Apple path is stronger, but Android passes purchase ID/order ID while backend treats it as Google purchase token; Google verification/refund correlation likely breaks in production. |
| Mobile architecture | B+ | Good singleton services, Agora screens, lifecycle cleanup, LRU presence/profile caches, and real-time UX. Needs stronger testability, random-match receiver handling, and fewer stale assumptions. |
| Test posture | C | Backend build passes and Functions build passes; backend unit tests, backend e2e, and Flutter widget tests currently fail due stale expectations/harnesses. No Postgres race/idempotency tests cover the highest-risk paths. |
| Documentation accuracy | C+ | `PRODUCT.md`, READMEs, tests, and instructions disagree on guest login, WebSocket/socket language, and some completion claims. Product direction is strong, but operating docs need cleanup. |

### RTDB Module Audit — 5 Jun 2026 — Historical: C+ (superseded by 7 Jun RTDB audits)
| Aspect | Grade | Notes |
|--------|-------|-------|
| Module ownership | A- | RTDB client usage is mostly centralized in `FirebaseChatService.instance`, with backend Admin SDK writes limited to call signaling and cleanup. This matches the no-Socket.IO architecture. |
| Presence | B+ | `onDisconnect`, Cloud Function sync, and stale-presence reaper give good crash recovery. Needs stricter RTDB validation for allowed states/fields and stronger handling of live/busy/background transitions. |
| Direct-call signaling | C | `direct_calls/{userId}` is functionally simple, but any authenticated user can overwrite any user's signal node. Payload shape and caller/receiver ownership are not validated by rules. |
| Random-call signaling | C- | Backend writes `event: matched` to `direct_calls/{receiverId}`, but the Home listener only handles direct-call `status` values. Receivers outside `RandomCallScreen` may never join matched sessions. |
| Live-room realtime | C | Comments/reactions are acceptable MVP events, but room `status`, `audience_count`, and gifts are client-writable with weak validation. Gift UI can be spoofed even if backend economy is checked separately. |
| Counters/idempotency | C | Audience count uses client-side increments/decrements plus `onDisconnect`; duplicate joins, double dispose, or spoofed writes can produce inaccurate counts. Use per-viewer presence nodes or transactions for stronger counts. |
| Security rules | C- | Rules protect user-owned `presence` and `profiles`, but `direct_calls`, `live_rooms/status`, events, and counters are too broad. Add ownership constraints, field validation, enum checks, and `.indexOn` for timestamped event streams. |
| Scale posture | B- | Flat root nodes and LRU caches are good for MVP. Scheduled global presence scans and unbounded live event retention should evolve before larger scale. |

### Canonical Realtime Availability — 7 Jun 2026 — Overall: A+
| Aspect | Grade | Notes |
|--------|-------|-------|
| Canonical RTDB cell | A+ | Mobile writes `schemaVersion`, `connection`, `activity`, `availability`, `routing`, `displayStatus`, `interruptible`, context IDs, timestamps, and legacy `state` only for compatibility. RTDB rules now reject incoherent state combinations. |
| Backend projection | A | Cloud Functions mirror canonical presence into Postgres fields for display, availability, routeability, and freshness. RTDB remains source of truth. |
| Direct-call routeability | A+ | Profile/chat UI and backend direct-call creation reject offline, busy, and premium-live receivers using canonical availability/routing instead of badge text. |
| Random-call routeability | A+ | Live-host and online fallback matchmaking require `presence_availability='available'` and `can_random_call=true`; away, busy, offline, and premium-live users are skipped. |
| Premium/free-live transitions | A+ | `PresenceRealtime` now owns free-live pause/resume plus premium-live host/viewer states; rules prove premium live is busy, non-interruptible, and unroutable. |
| Compatibility | A+ | Existing UI readers still work through legacy `state`, while new readers prefer `displayStatus`. This keeps the module upgrade safe for current screens. |
| Proof | A+ | `pnpm test:rtdb:rules` passed 7/7, `pnpm check` passed, `flutter analyze` passed, and backend test/build gates passed on 7 Jun 2026. |
| Remaining product risk | B+ | The realtime source of truth is A+. Product sign-off still needs manual direct/random-call smoke and full premium-live product implementation. |

### Direct Call Availability Hotfix — 6 Jun 2026 — Overall: A
| Aspect | Grade | Notes |
|--------|-------|-------|
| Error UX | A | Mobile parses backend error envelopes and maps direct-call failures to product messages instead of raw `API 400` transport text. |
| Presence projection | A | `onPresenceChanged` now uses RTDB written events, so first-time presence creates, updates, and deletes all mirror into Postgres availability. Deployed to Firebase project `zephyr-495115` on 6 Jun 2026. |
| Remaining risk | B+ | Manual two-account call retest is still required. Existing online users may need app foreground/login after deploy to rewrite their presence. |

### Random Call Receiver Lifecycle — 6 Jun 2026 — Overall: A
| Aspect | Grade | Notes |
|--------|-------|-------|
| Receiver entrance | A+ | `HomeScreen` now consumes backend `event=matched` from any app tab and shows a floating earning ribbon instead of requiring the receiver to already be inside `RandomCallScreen`. |
| Host UX | A | Ribbon shows caller name, host earning per minute, customer price per minute, accept, and decline. Host earning is derived from backend rate/share, not a hardcoded mobile claim. |
| Session cleanup | A | Accept removes the matched signal without triggering premature Cloud Function session end; decline, timeout, app pause, and partner-left events call backend random cleanup. |
| Shared call engine | A+ | Accepted random calls still enter `DirectCallScreen(mode=random)`, so Agora, billing, presence busy state, token renewal, and media controls stay reusable. |
| Matchmaking priority | A | Backend already favors available free-live hosts first, then available online hosts, while respecting block lists, busy sessions, routeability, and recent-match cooldown. |
| Rules coverage | A | RTDB emulator now covers random matched signal participant read/delete behavior. |
| Remaining A+ gate | A- | Needs manual two-account smoke on simulator/device before final A+ sign-off. Deeper telemetry-based host ranking can come after real usage data. |

### RTDB Module Ownership — 7 Jun 2026 — Overall: A+
| Aspect | Grade | Notes |
|--------|-------|-------|
| Presence module | A+ | `PresenceRealtime` owns `presence/{userId}` payloads, onDisconnect, local LRU cache, foreground/background/live/call transitions, and display-status derivation. |
| Profile module | A+ | `ProfilesRealtime` owns `profiles/{userId}` writes, profile cache, and profile listener lifecycle. |
| Direct-call signals | A+ | `DirectCallSignals` owns `direct_calls/{userId}` ringing/status/remove/listen behavior. Rules restrict caller/receiver ownership, validate payload shape, and keep caller/session metadata immutable after creation. |
| Live-room realtime | A+ | `LiveRoomRealtime` owns room init/status, comments, reactions, derived audience count, per-viewer audience cells, gift listeners, and end cleanup. Room init is create-once, then host-owned `status` only. |
| Trusted gift fan-out | A+ | Live gift display events are no longer client-written. Backend ledger success triggers Firebase Admin fan-out to `live_rooms/{roomId}/gifts`, with deterministic idempotency-key event IDs when supplied. |
| Facade compatibility | A+ | `FirebaseChatService.instance` remains as the stable app-facing facade, forwarding to modules so existing screens do not churn. |
| Rules enforcement | A+ | RTDB rules validate canonical presence coherence, profiles, direct-call signals, live-room host ownership, status enums, per-viewer audience ownership, comment/reaction sender identity, client gift denial, and direct-call metadata immutability. |
| CI/default gate | A+ | Root `pnpm check` now runs the RTDB rules suite and backend test/build; GitHub Actions also runs RTDB rules, backend tests, DB race tests, and backend build on PRs and `main`/`dev` pushes. |
| Remaining product risk | B+ | RTDB ownership is A+. Premium-live screens/API and reusable gift-module surfaces outside live room still need product implementation. |

### RTDB Rules Emulator Suite — 7 Jun 2026 — Overall: A+
| Aspect | Grade | Notes |
|--------|-------|-------|
| Test harness | A+ | Added repo-local `test:rtdb:rules` using Firebase Database emulator + `@firebase/rules-unit-testing`. |
| Coverage | A+ | Covers presence owner/schema/coherence, premium-live route denial, profile owner/shape, direct-call caller/receiver access, immutable call metadata, random matched signal participant read/delete, live-room host ownership, comment/reaction sender identity, per-viewer audience ownership, audience-count denial, and trusted gift read/client-forge denial. |
| Execution | A+ | `pnpm test:rtdb:rules` passed 7 tests / 0 failures on 7 Jun 2026. |
| Tooling stability | A | Pinned repo-local `firebase-tools@14` so Java 17 works today. Future Firebase CLI v15+ requires Java 21, so plan that upgrade deliberately. |
| Remaining risk | A- | Rules are strong for the current RTDB surface. Future premium-live and reusable gift surfaces must add emulator coverage as they are introduced. |

### Backend Money Ledger — 6 Jun 2026 — Overall: A+
| Aspect | Grade | Notes |
|--------|-------|-------|
| Idempotency | A+ | Call ticks, call gifts, and live-room gifts now support `X-Idempotency-Key`/body keys. Duplicate retries replay the first stored response; reusing a key for different money details is rejected. |
| Call tick ledger | A+ | Database-backed call ticks run in one PostgreSQL transaction, lock the idempotency row, call session, and caller wallet with `FOR UPDATE`, check balance, update wallet/revenue/history/session totals together, and end insufficient-balance sessions inside the same transaction. |
| Call/live gifts | A+ | Direct/random call gifts and live-room gifts validate the active session/room, lock idempotency and spender wallet rows, check balance, update receiver revenue, and write spend/earning history in the same transaction. Live gifts use shared economy config instead of a hardcoded split. |
| IAP credit/refund | A | Purchase credit uses `DatabaseService.transaction`, inserts the unique purchase before wallet credit, and refund processing is transactional with a unique partial refund index. |
| Test coverage | A+ | Backend unit suite covers duplicate/reused idempotency keys, and `pnpm --filter zephyr-api test:db:race` passed 3/3 against local Postgres for duplicate concurrent ticks, low-balance concurrent ticks, and duplicate concurrent gifts. |
| Tooling | A+ | Added `test:db:race`, `DatabaseService.waitUntilReady()`, root `pnpm check`, and CI quality gates so RTDB/backend build/test/race coverage runs deliberately instead of living as tribal knowledge. |

### Full Solution Audit — 7 Jun 2026 — Overall: B+
| Aspect | Grade | Notes |
|--------|-------|-------|
| Product architecture | B+ | The source-of-truth design is strong: Flutter + NestJS + Postgres + Firebase RTDB/Firestore + Agora is the right split for this app. The gap is execution completeness, not the big architecture choice. |
| Mobile entrances | A | Login, onboarding, For you, Following, explore, inbox, direct call, random call, live, profile, wallet, and settings are present. Root navigation now uses a Zephyr header for avatar/profile access plus wallet context, with Me removed from the footer and Following promoted to the second footer tab. The old Home Popular/Discover shell is no longer active; For you has the launch-minimum Tango-style live discovery core: live-only paged feed, no visible user filter, viewer counts, pull-to-refresh, lazy-load trigger, body tap enters live when a room exists, identity strip opens profile, and premium empty state with customer Random match CTA. Persisted host covers come first, Female host onboarding assigns a default cover when empty, uploaded covers override it, backend feed returns female host/girl accounts only, ProfilePage follow/counts are backend-backed, Following empty state exists, Me dashboard shows wallet/spark/revenue/rate context, Settings subpages are wired, and call report/post-call safety is covered. Remaining gap: manual entrance smoke, Explore identity polish, deeper revenue/notification settings, future live preview/hide-chrome polish, future phantom CTA, and premium live. |
| Realtime availability | A+ | Canonical RTDB presence is now a real source-of-truth cell: coherent rules, premium/free-live transition states, backend projection, and routeability gates are proven by emulator tests and `pnpm check`. |
| Backend economy | A+ | Paid call ticks and gifts have transaction-safe row locks, idempotency replay, real Postgres race tests, transactional IAP credit/refund, Android token verification, and backend-confirmed live gift fan-out. |
| IAP production readiness | A | Android code/backend contract now matches Google Play token verification and real app IDs, Render production env is set, and wallet catalog UX now exposes unavailable Play products cleanly. Remaining sign-off: Google Play merchant/bank verification, one-time product catalog visibility, and one internal-test purchase/refund smoke. |
| Firebase ownership | A+ | RTDB module ownership is A+: presence, profiles, direct-call signals, live-room per-viewer audience, host-owned status, and backend-owned live gift fan-out are enforced. Firestore/Storage messaging ownership is now A+ core too: participants, receipts, deletes, blocks, committed-message push, and chat image ownership are rules/backend controlled. |
| Premium live | C | Product model is documented, but implementation is not present yet: no paid-entry transition, host caps, per-minute premium-room billing, lock screen, or premium realtime module. |
| Test posture | A | Backend unit tests/build, Flutter analyze, RTDB + Firestore + Storage emulator rules, root `pnpm check`, DB race tests, expanded Flutter widget tests, and GitHub quality gates are in place. Wider mobile widget coverage can continue expanding feature by feature. |
| Documentation accuracy | B+ | `PRODUCT.md` and `.github/copilot-instructions.md` now match the current architecture. Remaining drift is non-Markdown: OpenAPI, smoke/e2e guest helpers, and stale source comments. |
| A+ gates | Pending | Finish manual random/direct call smoke, Google Play internal-test IAP smoke, premium live lifecycle, reusable Gift module expansion, Explore identity polish, and stale non-Markdown contracts/helpers. |

### Documentation & Current-State Audit — 7 Jun 2026 — Overall: B+
| Aspect | Grade | Notes |
|--------|-------|-------|
| Markdown source of truth | A- | `PRODUCT.md` now has a current solution snapshot, corrected TODOs, current endpoint map, updated completion/blocker tables, and historical labels on superseded audits. |
| Copilot instructions | A- | `.github/copilot-instructions.md` now describes canonical presence fields, Postgres projection fields, current matchmaking gates, RTDB ownership, and backend-confirmed live gifts. |
| Direction governance | A | `PRODUCT.md` and Copilot instructions now explicitly say latest dated snapshots/audits supersede older direction, while hard constraints remain hard. |
| Historical audit clarity | A | Older 3 Jun/5 Jun audit blocks are preserved as history and explicitly marked superseded instead of silently upgraded. |
| Non-Markdown drift | C+ | `packages/zephyr-contracts/openapi.yaml`, smoke/e2e helpers, and a few socket/LiveKit comments still need cleanup. |
| Test truth | A | Docs now record the current check results: `pnpm check`, DB race tests, `flutter analyze`, and current `flutter test` pass. |
| Next-work clarity | B+ | Immediate work now points to manual random/direct smoke, inbox AAB smoke, Google Play purchase smoke, non-Markdown cleanup, follow/feed persistence, gift expansion, and premium live. |
