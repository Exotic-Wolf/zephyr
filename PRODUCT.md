# Zephyr — Product & Technical Reference

> This file is the single source of truth for product decisions, pricing, architecture, and development context. Read this first before touching any code or starting a new session.

---

## Product Vision

- **Goal:** build a flawless, top-tier, Steve Jobs-level Chamet/Olamet-style social video app.
- **Primary mobile audience:** iPhone users first, with Android parity through Flutter.
- **Stack choice:** Flutter is intentional because one product-quality codebase can serve iOS and Android while keeping interaction, animation, and realtime behavior consistent.
- **Target market:** Arab Gulf users calling Philippines/Asia hosts.
- **Core revenue:** coin-based gifts + direct/random video calls + live streaming.
- **Original bonus idea:** premium live / premium room flow where hosts can start premium directly or upgrade free live into a paid-per-minute room.
- **Execution style:** build robust reusable cells first, then compose flawless modules and product organs.

---

## Operating Rule

Every meaningful work slice must update this file before commit/push:

- Update **Current TODO Tracker** with what changed, what is next, and what is blocked.
- Update **Audit Log** when a feature/module quality grade changes.
- Remove or rewrite stale product claims as soon as implementation makes them outdated.
- Preserve one source of truth per domain; do not add parallel truth systems for convenience.
- Keep iPhone user experience as the primary polish bar, while preserving Flutter Android parity.

---

## Current TODO Tracker

| Priority | Status | Owner | Item | Why it matters |
|---|---|---|---|---|
| P0 | Done | User | Install Java 17 JDK for Apple Silicon/M4 Mac | Verified locally with Temurin `17.0.19`; Firebase RTDB emulator can run through repo-local `firebase-tools@14` |
| P0 | Done | Codex | Add executable RTDB emulator tests | `tests/rtdb/rules.test.mjs` proves canonical presence, profile ownership, direct-call ownership, live-room host ownership, and event validation |
| P0 | Done | Codex | Run RTDB emulator rules suite and record results in Audit Log | `pnpm test:rtdb:rules` passed 5/5 tests on 6 Jun 2026 |
| P0 | Action required | User | Update Render billing payment method | Render reported invalid payment info on 6 Jun 2026; service is healthy now but can be suspended if payment fails again |
| P0 | Done | Codex | Deploy `dev` to Render backend through `main` | PR #2 merged on 6 Jun 2026; Render health returned `ok` after merge |
| P0 | Done | Codex | Launch iPhone 17 Pro Max simulator against Render API | `com.zephyr.zephyrMobile` launched on simulator with `API_BASE_URL=https://zephyr-api-wr1s.onrender.com` |
| P0 | Action required | User | Manual simulator smoke test | Check login/onboarding/feed/inbox/presence/direct call/random call/live basics while Render billing is fixed |
| P0 | Done | Codex | Generate Android internal testing AAB `1.0.4+5` | Built signed release bundle at `apps/zephyr-mobile/build/app/outputs/bundle/release/app-release.aab`; manifest verifies version name `1.0.4`, version code `5` |
| P0 | Done | Codex | Promote Android internal testing build `1.0.4+5` to `main` | PR #3 carries the Play version bump and release tracker to `main` so Render/GitHub state matches the upload build |
| P0 | Done | Codex | Fix direct-call `API 400` user experience | Mobile now parses backend error envelopes into product messages; Firebase `onPresenceChanged` now mirrors RTDB create/update/delete writes into Postgres availability and was deployed on 6 Jun 2026 |
| P0 | Action required | User | Retest direct call with two online accounts | Open/log in both accounts after the Functions deploy so each account rewrites presence, then call only when the receiver badge is online/live and not busy |
| P0 | Next | Codex | Wire RTDB rules suite into normal check/CI path | Prevents future rules drift from silently weakening ownership/security |
| P1 | Planned | Codex | Implement premium live lifecycle | Free live -> premium, start premium directly, paid entry, per-minute billing, lock screen, cleanup |
| P1 | Planned | Codex | Add `PremiumLiveRealtime` module once lifecycle exists | Keeps premium live non-interruptible and owned by a dedicated realtime module |
| P1 | Planned | Codex | Replace live audience counter with per-viewer presence/count derivation | Prevents inaccurate counts from duplicate joins/disconnect edge cases |
| P2 | Planned | Codex | Move trusted gift event fan-out toward backend/Admin SDK confirmation | Prevents spoofed gift display events while keeping gift economy reusable |

Immediate next work:

1. Add RTDB rules suite to the default local/CI check path.
2. Update Render billing, then verify post-deploy health at `https://zephyr-api-wr1s.onrender.com/v1/health/ready`.
3. Retest direct call with two online accounts after the deployed presence-sync trigger.
4. Implement premium live lifecycle and `PremiumLiveRealtime`.
5. Move trusted gift fan-out behind backend confirmation.

---

## Architecture

| Layer | Stack | Location |
|---|---|---|
| Mobile | Flutter (Dart) | `apps/zephyr-mobile` |
| Backend API | NestJS (TypeScript) | `services/zephyr-api` |
| Database | PostgreSQL (Render) | Singapore region |
| Messaging | Firebase Firestore + Storage + FCM | `firebase_chat_service.dart` |
| Status & Presence | Firebase RTDB (asia-southeast1) | Canonical realtime availability cell: connection, activity, routing, display status, call/live context |
| User Identity | Firebase RTDB `profiles/{userId}` | displayName, avatarUrl, countryCode, language, birthday — **source of truth for identity**. LRU-cached listeners, reactive via `profileVersion` ValueNotifier |
| Live Rooms | Firebase RTDB | Comments, reactions, gifts, audience_count, room status — all via `live_rooms/{roomId}/` |
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
| `core/fcm.service.ts` | Firebase Admin — push notifications + RTDB writes (call signaling, match signals) |
| `auth/auth.controller.ts` | `GET /v1/auth/firebase-token` — custom Firebase token for client auth |
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
GET  /v1/health/live, /v1/health/ready
POST /v1/auth/google-login, /apple-login
GET  /v1/users/me
PATCH /v1/users/me
GET  /v1/users/by-public-id/:publicId
GET  /v1/users/:userId
POST /v1/users/:userId/follow
DELETE /v1/users/:userId/follow
POST /v1/users/:userId/block
DELETE /v1/users/:userId/block
GET  /v1/users/:userId/block
GET  /v1/rooms
POST /v1/rooms
POST /v1/rooms/:roomId/join
POST /v1/rooms/:roomId/heartbeat
DELETE /v1/rooms/:roomId
GET  /v1/feed/live
GET  /v1/economy/config, /coin-packs, /wallet
POST /v1/economy/purchase-coins
GET  /v1/economy/gifts/catalog
POST /v1/economy/calls/start, /tick, /end, /rtc-token
POST /v1/messages
GET  /v1/messages/conversations
GET  /v1/messages/conversations/:userId
PATCH /v1/messages/:messageId/read
```

Firebase Chat:
- Backend: `GET /v1/auth/firebase-token` → custom token for Firebase Auth
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

## Architecture Decisions (Locked)

- **Firebase Chat** — Firestore for messages/conversations, RTDB for real-time presence (onDisconnect), Storage for image uploads. Backend generates custom Firebase tokens.
- **Firebase RTDB is the single source of truth for real-time availability** — `presence/{userId}` is not a single overloaded status string. It is the canonical availability cell for connection, activity, routing eligibility, display status, and call/live context. RTDB's `onDisconnect` guarantees cleanup even on app kill/crash. All clients listen to RTDB for user availability before initiating calls, routing random calls, or showing status badges.
- **Firebase Cloud Functions (asia-southeast1)** — 3 deployed functions provide server-side safety nets:
  - `onCallSignalDeleted`: RTDB trigger on `direct_calls/{userId}` deletion → ends Postgres call session via internal API
  - `onPresenceChanged`: RTDB trigger on `presence/{userId}` update → syncs the canonical display/availability/routing projection to Postgres, and ends the room when `displayStatus` leaves `live`
  - `reapStalePresence`: Scheduled every 5 min → scans all presence nodes, resets stale entries (>5min) to the canonical offline payload, ends orphaned live rooms
  - Internal endpoints: `POST /v1/internal/end-call-session`, `POST /v1/internal/end-room` (validated via `X-Service-Key` header)
- **Agora RTC** — replaces LiveKit for ALL video (calls + live streaming). Proprietary UDP bypasses Gulf WebRTC filtering. Single SDK, smaller APK.
- **Zero Socket.IO** — All real-time is Firebase RTDB. Live room comments/reactions/audience state use RTDB; trusted room status and gift events must be backend-confirmed before fan-out. Random call matchmaking uses REST + RTDB signals. No WebSocket libraries exist in the codebase.
- **FCM/APNs** — push notifications for chat messages (backend relays via `POST /v1/messages/push`)
- **Firebase is truth** — Firestore is source of truth for messages/conversations. RTDB is source of truth for realtime availability, call/live signaling, visible live events, and user identity (`profiles/{userId}` — displayName, avatarUrl, countryCode, language, birthday). Backend validates economy and issues tokens.

---

## Canonical Realtime Availability Model

This section is product law for the realtime cell. The goal is not just "show a badge"; the goal is to make inbox, direct call, random call, live, Agora, and backend matchmaking read the same authoritative availability truth.

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
| My Profile | ✅ Done | 75% |
| Persistent login | ✅ Done | 100% |
| Economy backend (coins, sparks, calls, gifts) | ✅ Built | 80% |
| Random video calls (Agora) | ✅ Done | 90% |
| Block system | ✅ Done | 100% |
| Push notifications (FCM) | ✅ Done (Android + iOS) | 90% |
| Report system (chat) | ✅ Done | 100% |
| Follow/unfollow UI | ❌ Partial | 20% |
| Wallet / coins UI | ❌ Partial | 30% |
| Gifts during live | ❌ Not started | 0% |
| Report system (calls) | ❌ Not started | 0% |
| Direct call (signaling + video) | ✅ Done | 95% |
| Cloud Functions (call + live + reaper) | ✅ Done | 100% |
| App icon + splash | ✅ Done | 100% |
| Onboarding flow | ✅ Done | 100% |

---

## Known Blockers Before Ship

| Blocker | Solution |
|---|---|
| ~~Agora env vars not on Render~~ | ✅ Done — `AGORA_APP_ID` + `AGORA_APP_CERTIFICATE` confirmed in Render dashboard |
| Mock cards in feed | Remove `[Mock]` cards before production |
| Render API sleeps | Upgrade to Standard plan ($25/mo) |
| No report system | `POST /v1/calls/:sessionId/report` endpoint + in-call button |
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
- On language select: calls `PATCH /v1/users/me` (gender + language + auto-detected country), writes profile to RTDB `profiles/{userId}`, then navigates to home
- `onboardedAt` set server-side via `COALESCE(onboarded_at, NOW())` — idempotent

### App Shell

5-tab bottom navigation bar (accent `#FF8F00` amber):

| Index | Icon | Label | Badge |
|---|---|---|---|
| 0 | home_rounded | Home | — |
| 1 | live_tv_rounded | Live | — |
| 2 | explore_rounded | Explore | — |
| 3 | chat_bubble_rounded | Inbox | Unread count (99+ cap) |
| 4 | person_rounded | Me | — |

---

### Tab 0 — Home

App bar has 3 sub-tabs: **Popular · Discover · Follow** (default: Discover). Country filter + name search in top bar.

**Popular sub-tab:**
- 2-column grid of `LiveFeedCard` cards
- Tap card → opens `ProfilePage`
- Green **"Random match"** button pinned at bottom

**Discover sub-tab:**
- Vertical `PageView` — swipe up/down through cards (full-height cards)
- Live cards show a preview box (top-right) for future video feed
- Green **"Random match"** button pinned at bottom

**Follow sub-tab:**
- Same 2-column grid, filtered to followed users only
- Empty state: "Follow someone to see them here"
- Green **"Random match"** button pinned at bottom

**Feed card anatomy:**
- Background gradient: `#1C1C2E` → `#2D2D44` (dark purple-blue)
- Top-left: status badge — `Live` (red `#FF3B30`) / `Busy` (orange `#FF9500`) / `Online` (green `#34C759`) / `Offline` (grey `#8E8E93`)
- Bottom-left: host display name + country flag + language
- Bottom-right: shake-animated call button

**Random match button:**
- Color: `#7BEA3B` (bright green), black text
- Tapping: checks coin balance, switches to Explore tab, starts a call session at 600 coins/min

---

### Tab 1 — Live

Centered screen with:
- Radial amber glow behind a flame-gradient circle icon (`live_tv_rounded`)
- Large "Go Live" heading
- Subtitle: "Start Live Stream and Connect"
- Button → `GoLiveCountdownPage` (3-2-1 countdown) → `HostLiveScreen`

---

### Tab 2 — Explore

→ `ExplorePage` — search users by name or 8-digit public ID

---

### Tab 3 — Inbox

→ `InboxPage` — conversation list, unread badges, timestamps

---

### Tab 4 — Me

→ `MyProfilePage` — view/edit profile, settings, logout

---

### 💰 0. Revenue Feature — Random Call (Agora)

> Store compliance: 17+ age rating. ToS prohibits explicit content. Report button = safety net. Reactive bans only at v1.

**Backend** ✅
- [x] Matchmaking queue — REST endpoints (`seek/cancel/next/end`) + RTDB match signals; block-aware pairing
- [x] Call session table — `call_sessions` (id, user_a_id, user_b_id, agora_channel, started_at, ended_at, ended_by)
- [x] Agora token generation — `rtc.service.ts` generates per-user tokens via `agora-token` npm package
- [x] Coin billing — `tickCallSession` every 15s; 600 coins/min
- [x] Block system — `user_blocks` table; blocked users cannot be matched
- [ ] Report endpoint — `POST /v1/calls/:sessionId/report`; stores report, ends Agora channel, increments report count on reported user
- [ ] Auto-ban threshold — 5+ reports in 7 days → `is_banned = true`; banned users rejected from queue

**Flutter** ✅
- [x] "Random match" button on Home tab → navigates to `RandomCallScreen`
- [x] Waiting/searching screen — animated pulsing ring, Cancel button emits `call:leave_queue`
- [x] In-call screen — full-screen remote video (Agora), local PiP top-right, End / Next / Mute / Flip controls
- [x] Skip / Next — 600ms blur transition, re-joins queue, no coins during transition
- [x] `call:partner_left` → auto re-searches
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
- [ ] Follow / unfollow UI — Follow button on ProfilePage, follower/following counts (backend done, no UI)
- [ ] Empty feed state — "Find people" prompt or curated suggestions when following 0 people
- [ ] Optimistic message send — bubble appears instantly before server ACK (~8% messaging gap)

---

### 🟡 3. Product Completeness

- [ ] Wallet / coins UI — balance display, transaction history (backend done, no UI)
- [ ] Gift tray during live / calls — animated gifts (Lottie/SVGA), hosted on CDN, downloaded on demand
- [ ] Gift sending from DM — send coins as gift from thread (backend done)
- [ ] Typing indicator — "..." bubble when other user is typing
- [ ] Message ordering under rapid fire — no sequence numbers; 3 fast messages can appear out of order (~3% gap)
- [ ] MessageCache eviction — thread messages unbounded in memory; causes pressure on long sessions (~2% gap)
- [ ] Report user in-call — report button + `POST /v1/calls/:sessionId/report` endpoint
- [x] Direct call ringing — caller sees "calling…", receiver gets accept/decline overlay (RTDB signaling)
- [ ] Post-call screen — "Call ended", option to send DM
- [ ] Custom Sentry breadcrumbs — log socket events, message send, login

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
- [x] Socket room stability — `chat:join` on every `connect`
- [x] Real-time delivery — MessageBus singleton routes socket messages to open ThreadPage
- [x] Cursor-based reconnect sync — fetches only messages after last known timestamp on reconnect
- [x] Cross-device send confirmation — gateway emits to both sender and receiver rooms
- [x] Android FCM — push on message send, coalesced per sender
- [x] Tap notification → Inbox tab
- [x] FCM token cleanup on logout
- [x] iOS Firebase init — `firebase_options.dart`, Podfile iOS 15.0
- [x] Unread badge — socket increment + 60s resync + clears on open + app-resume refresh
- [x] Avatar image caching — `CachedNetworkImageProvider` across all screens
- [x] Persistent HttpClient — single client reused across all API calls
- [x] Sentry Flutter + NestJS — uncaught exceptions captured
- [x] Auth — Google, Apple (iOS + Android)
- [x] Home feed — live cards, user cards, real-time socket
- [x] Inbox — conversation list, unread badges, timestamps
- [x] Thread (DM) — chat bubbles, send, mark-read, auto-scroll
- [x] Explore — search by name or 8-digit public ID
- [x] Live streaming — host + viewer screens, timer, viewer count
- [x] Avatar upload — Cloudinary, camera/gallery picker
- [x] Profile editing — nickname, gender, birthday, country, language
- [x] Settings — logout at Me → ⚙ Settings → Sign Out
- [x] Socket.IO fully removed — all real-time via Firebase RTDB, zero WebSocket libraries in codebase
- [x] Mock data removed — mock feed cards, mock followingIds, debug logs gone
- [x] Direct call — RTDB signaling (`/direct_calls/{receiverUserId}`), incoming call overlay (accept/decline), Agora video screen with remote mute detection, camera-off PIP placeholder, dispose cleanup
- [x] Direct call camera-off handling — remote mute detected via `onRemoteVideoStateChanged` (reason-based, not state-based), camera flip no longer triggers false "camera off" on remote side

---

## Audit Log

Quality grades (A+ to F) recorded after each feature audit. This is our history of quality.

### Live Streaming — 29 May 2026 — Overall: A+
| Aspect | Grade | Notes |
|--------|-------|-------|
| Architecture | A+ | Agora RTC + RTDB signaling, Cloud Function auto-ends on disconnect. Zero dead code — backend is pure REST (create/join/leave/end/gift/token), all real-time flows through RTDB directly. |
| Reconnection | A | `onConnectionStateChanged` with overlay, token refresh handler |
| Rate limiting | A | 500ms throttle on reactions/comments |
| Error handling | A | User-facing snackbars, graceful fallback |
| Resource cleanup | A | `_ending` guard prevents double-end, proper dispose |
| Code quality | A+ | ValueNotifier for comments, isolated state, no leaks, zero dead endpoints or unused dependencies |

### Messaging / Inbox — 29 May 2026 — Overall: A-
| Aspect | Grade | Notes |
|--------|-------|-------|
| Architecture | A | Firestore messages, RTDB presence, Cloud Function PG sync. Zero polling. |
| Presence | A | LRU cache (50 cap), canonical display statuses, live/premium/busy/away colors |
| Security | A | Block check both directions, anti-spam (5msg/10s + duplicate cooldown) |
| Calling | A- | Full signaling from thread, 30s timeout. Missing: rate preview in thread |
| Performance | A | No polling, debounced search, proper listener cleanup |
| Code quality | A | Dead code gone, clean modules, proper dispose |
| UX | A- | Search for new chat, live preview, inline translation, read receipts. Missing: typing indicator, message reactions |

### Call (Direct + Random) — 29 May 2026 — Overall: A
| Aspect | Grade | Notes |
|--------|-------|-------|
| Architecture | A+ | REST matchmaking + RTDB signaling + Agora RTC. Socket.IO fully purged from codebase (packages removed). Random inherits from Direct (shared DirectCallScreen). |
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
| Google verification | A+ | Publisher API token verification via `google-auth-library`. Validates packageName + productId. Checks `purchaseState === 0` (purchased) and `consumptionState === 0` (unconsumed). |
| Refund handling | A+ | Apple ASNS V2 webhook + Google RTDN webhook. `processRefund()` deducts coins immediately, records `iap_refund` transaction. Idempotent (skips if already refunded). Balance can go negative (fraud protection). |
| Idempotency | A+ | `iap_purchases.transaction_id` UNIQUE constraint. Check-before-insert prevents double-credit. Race conditions caught by PostgreSQL. |
| Retry safety | A+ | `completePurchase()` only called after backend confirms credit. Failed verifications retry on next app launch automatically. |
| Production hardening | A+ | `POST /v1/economy/purchase-coins` blocked unless `ALLOW_FAKE_PURCHASES=true`. Flutter fallback restricted to `kDebugMode`. |
| Code quality | A+ | Singleton `IapService.instance`. Clean separation: Flutter handles store interaction, backend handles all validation + crediting. Zero trust on client. |

### Onboarding — 2 Jun 2026 — Overall: A
| Aspect | Grade | Notes |
|--------|-------|-------|
| Architecture | A | Google + Apple login → `onboardedAt` null-check → profile setup or straight to home. Backend `COALESCE(onboarded_at, NOW())` on PATCH /me. No guest login. |
| Login flow | A | Google Sign-In + Apple Sign-In. Buttons disabled during loading. Proper error display. API offline warning on startup. |
| Profile setup | A | Nickname (2-20 chars, control chars blocked, emoji allowed), country picker, language dropdown. Keyboard dismiss on tap. Semantics labels. |
| Backend | A | `issueGoogleSession` / `issueAppleSession` → find-or-create user → JWT. `updateMe` sets `onboarded_at` via COALESCE on first profile save. Backfill migration for existing users. |
| Session restore | A | `main.dart` checks `profile.onboardedAt != null` — already-onboarded users skip setup on re-login. |
| Security | A | Google token verified server-side with audience check. Apple token verified via JWKS. No client-side trust. |
| Code quality | A | Clean separation: `onboarding_page.dart` (login), `profile_setup_screen.dart` (setup). No dead code. Proper dispose. |

### RTDB Architecture & Data Modeling — 3 Jun 2026 — Overall: A-
| Aspect | Grade | Notes |
|--------|-------|-------|
| Data model | A+ | 4 clean root nodes only: `presence`, `profiles`, `direct_calls`, `live_rooms`. Flat, predictable paths. |
| Normalization | A+ | Identity is centralized in `profiles/{userId}`. No broad denormalized name fan-out in persistent docs. |
| Presence robustness | A+ | `onDisconnect` + Cloud Function sync/reaper gives strong crash/offline recovery. |
| Client caching | A | LRU subscription cache (50 cap) for presence and profiles. RTDB remains source of truth. |
| Security rules | B- | `direct_calls` and `live_rooms/status` are too permissive; need stricter writer validation. |
| Indexing | C | Missing `.indexOn` for `comments.ts`, `reactions.ts`, `gifts.ts`; add indexes to avoid scans/warnings. |
| Scale posture | A- | Current approach is strong for MVP and early growth; scheduled global presence scan should evolve later at very high scale. |

### Full Solution Audit — 5 Jun 2026 — Overall: B-
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

### RTDB Module Audit — 5 Jun 2026 — Overall: C+
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

### Canonical Realtime Availability — 6 Jun 2026 — Overall: A
| Aspect | Grade | Notes |
|--------|-------|-------|
| Canonical RTDB cell | A | Mobile writes `schemaVersion`, `connection`, `activity`, `availability`, `routing`, `displayStatus`, `interruptible`, context IDs, timestamps, and legacy `state` only for compatibility. |
| Backend projection | A | Cloud Functions mirror canonical presence into Postgres fields for display, availability, routeability, and freshness. RTDB remains source of truth. |
| Direct-call routeability | A | Profile/chat UI and backend direct-call creation reject offline, busy, and premium-live receivers using canonical availability/routing. |
| Random-call routeability | A | Live-host and online fallback matchmaking require `presence_availability='available'` and `can_random_call=true`; away, busy, offline, and premium-live users are skipped. |
| Compatibility | A | Existing UI readers still work through legacy `state`, while new readers prefer `displayStatus`. This allows gradual module extraction without breaking current screens. |
| Remaining A+ gates | A- | RTDB emulator suite now passes locally (`pnpm test:rtdb:rules`, 5/5). Premium-live enter/exit transitions still need end-to-end implementation. |

### Direct Call Availability Hotfix — 6 Jun 2026 — Overall: A
| Aspect | Grade | Notes |
|--------|-------|-------|
| Error UX | A | Mobile parses backend error envelopes and maps direct-call failures to product messages instead of raw `API 400` transport text. |
| Presence projection | A | `onPresenceChanged` now uses RTDB written events, so first-time presence creates, updates, and deletes all mirror into Postgres availability. Deployed to Firebase project `zephyr-495115` on 6 Jun 2026. |
| Remaining risk | B+ | Manual two-account call retest is still required. Existing online users may need app foreground/login after deploy to rewrite their presence. |

### RTDB Module Ownership — 6 Jun 2026 — Overall: A
| Aspect | Grade | Notes |
|--------|-------|-------|
| Presence module | A+ | `PresenceRealtime` owns `presence/{userId}` payloads, onDisconnect, local LRU cache, foreground/background/live/call transitions, and display-status derivation. |
| Profile module | A+ | `ProfilesRealtime` owns `profiles/{userId}` writes, profile cache, and profile listener lifecycle. |
| Direct-call signals | A+ | `DirectCallSignals` owns `direct_calls/{userId}` ringing/status/remove/listen behavior. Rules restrict caller/receiver ownership, validate payload shape, and keep caller/session metadata immutable after creation. |
| Live-room realtime | A- | `LiveRoomRealtime` owns comments, reactions, gifts, audience count, status listen/end, and room initialization. Room nodes now include `hostUserId` for host-owned status writes. |
| Facade compatibility | A+ | `FirebaseChatService.instance` remains as the stable app-facing facade, forwarding to modules so existing screens do not churn. |
| Rules enforcement | A+ | RTDB rules validate canonical presence, profiles, direct-call signals, live-room host ownership, status enums, event shapes, reaction sender identity, gift shape limits, and direct-call metadata immutability. Emulator suite passes locally. |
| Remaining A+ gates | A- | Module ownership is now proven by executable rules tests. Product-level A+ still needs premium-live transition methods/rules and backend-confirmed trusted gift fan-out. |

### RTDB Rules Emulator Suite — 6 Jun 2026 — Overall: A+
| Aspect | Grade | Notes |
|--------|-------|-------|
| Test harness | A+ | Added repo-local `test:rtdb:rules` using Firebase Database emulator + `@firebase/rules-unit-testing`. |
| Coverage | A | Covers presence owner/schema, profile owner/shape, direct-call caller/receiver access, immutable call metadata, live-room host ownership, viewer comments/reactions, audience count validation, and gift payload bounds. |
| Execution | A+ | `pnpm test:rtdb:rules` passed 5 tests / 0 failures on 6 Jun 2026. |
| Tooling stability | A | Pinned repo-local `firebase-tools@14` so Java 17 works today. Future Firebase CLI v15+ requires Java 21, so plan that upgrade deliberately. |
| Remaining risk | B+ | Gift display fan-out is still client-written after backend charge success; move trusted fan-out to backend/Admin SDK before larger scale. |
