# Zephyr Code Reference

Repository structure, data model reference, endpoint map, and dependency notes.

This file is a source-checked reference, not a launch-status report or architecture decision record. Launch state lives in [current-state.md](./current-state.md); module ownership and source-of-truth rules live in [architecture.md](./architecture.md); operational commands live in [operations.md](./operations.md).

When code changes a path, controller route, table, column, package, or generated contract, update this file in the same work slice.

Last source check: 11 Jun 2026 against repository paths, Nest controller decorators, `DatabaseService` table creation, `apps/zephyr-mobile/pubspec.yaml`, and package manifests.

## Flutter App Structure (`apps/zephyr-mobile/lib/`)

| File | Purpose |
|------|---------|
| `main.dart` | App bootstrap, session restore via `flutter_secure_storage` |
| `app_constants.dart` | `apiBaseUrl`, `googleServerClientId`, env constants |
| `models/models.dart` | All data models: `UserProfile`, `Room`, `ZephyrMessage`, `WalletSummary`, `CoinPack`, `CallSession`, etc. |
| `services/api_client.dart` | REST API client for auth, users, rooms, economy, calls, feed, messages, uploads, and reports |
| `services/api_error_messages.dart` | Product-safe API error copy |
| `services/device_session_service.dart` | Stable app-install device id for one-active-session enforcement |
| `services/firebase_chat_service.dart` | Firebase facade for chat, Storage image prep/upload, and realtime module access |
| `services/firebase_realtime_database.dart` | RTDB instance factory; do not create alternate RTDB singletons |
| `services/presence_realtime.dart` | Owns `presence/{userId}` lifecycle, onDisconnect, LRU presence cache, and availability transitions |
| `services/realtime_profiles.dart` | Owns `profiles/{userId}` writes, profile cache, and profile listener lifecycle |
| `services/direct_call_signals.dart` | Owns direct/random call signal cells under `direct_calls/{userId}` |
| `services/live_room_realtime.dart` | Owns live-room RTDB audience, comments, reactions, status, and trusted gift listeners |
| `services/iap_service.dart` | Store purchase flow and backend purchase verification handoff |
| `services/local_db.dart` | Local persistent cache support |
| `services/translation_service.dart` | Lightweight message translation helper |
| `features/home/home_screen.dart` | App shell, footer navigation, inbox badge, presence lifecycle, incoming call/random invite listeners |
| `features/home/widgets/*.dart` | For you, Following, Popular, Discover, host-card grid, live-feed card, and shake-call UI components |
| `features/call/direct_call_screen.dart` | Reusable Agora video call screen (direct + random), remote mute detection, PIP |
| `features/call/call_ended_screen.dart` | Post-call Message/Report/Done actions |
| `features/call/incoming_call_overlay.dart` | Incoming call overlay — accept/decline, caller info |
| `features/call/random_call_screen.dart` | Random-call customer seek/next/end flow |
| `features/call/random_call_invite_ribbon.dart` | Host random-call invite ribbon |
| `features/live/host_live_screen.dart` | Host live stream, heartbeat timer (15s) |
| `features/live/go_live_countdown_page.dart` | 3-2-1 countdown, creates room |
| `features/live/viewer_live_screen.dart` | Viewer live stream, reactions, comments |
| `features/onboarding/onboarding_page.dart` | Login screen — Google Sign-In + Apple Sign-In, API offline check, legal links |
| `features/onboarding/profile_setup_screen.dart` | Post-login setup — gender picker → language picker (2-page PageView), auto-detects country, writes profile to RTDB |
| `features/explore/explore_page.dart` | Search users by name or 8-digit public ID |
| `features/chat/inbox_firebase_page.dart` | Conversation list (real-time Firestore), presence dots, unread badges |
| `features/chat/thread_firebase_page.dart` | DM chat — real-time messages, read/delivered receipts, images, translate, delete, anti-spam |
| `features/profile/my_profile_page.dart` | View/edit own profile |
| `features/profile/profile_page.dart` | View another user profile, follow/call/moderation entry |
| `features/me/me_tab.dart` | Me dashboard entrance for wallet, revenue, settings, and profile context |
| `features/me/balance_page.dart` | Wallet balance and coin-pack entry |
| `features/me/call_price_page.dart` | Host direct-call rate selection |
| `features/me/level_page.dart` | Level/spark progress view |
| `features/me/revenue_page.dart` | Host revenue summary |
| `features/me/settings_page.dart` | Settings subpages |
| `widgets/` | Shared widgets: gifts, spark icon, coin icon, language picker |

---

## Backend Structure (`services/zephyr-api/src/`)

| File | Notes |
|------|-------|
| `main.ts` | Bootstrap — standard NestJS HTTP server |
| `app.module.ts` | Nest module composition |
| `app.controller.ts` | Root `GET /` health/hello endpoint |
| `health/health.controller.ts` | `/v1/health/*` and protected `/v1/internal/*` cleanup/demo/presence endpoints |
| `legal/legal.controller.ts` | Static privacy and terms pages |
| `core/store.service.ts` | All DB logic — messages, rooms, economy, wallets |
| `core/database.service.ts` | Schema init, migrations, periodic cleanup |
| `core/rtc.service.ts` | Agora token generation |
| `core/fcm.service.ts` | Firebase Admin — push notifications, active-session projections, custom-token claims, RTDB writes for backend-owned call/match/live gift fan-out |
| `core/iap.service.ts` | Apple/Google purchase verification and refund support |
| `core/demo-for-you-simulator.service.ts` | Reversible backend-owned For you demo host simulator |
| `core/agora-chat.service.ts` | Agora Chat REST helper; currently support integration, not the main app messaging source of truth |
| `auth/auth.controller.ts` | `POST /v1/auth/google-login`, `/apple-login`, `/firebase-token`, `/logout` — OAuth sessions, custom Firebase token for client auth, and current-session revocation |
| `users/users.controller.ts` | Profile, following, search, avatar/cover, block, and report endpoints |
| `feed/feed.controller.ts` | Live discovery feed endpoint |
| `messages/messages.controller.ts` | `POST /v1/messages/push` — FCM push relay, device tokens, delivery/read receipts |
| `rooms/rooms.controller.ts` | Live room management — create/join/leave/end/gift/rtc-token |
| `economy/economy.controller.ts` | All economy endpoints |
| `economy/webhooks.controller.ts` | Apple and Google IAP/refund webhooks |
| `economy/matchmaking.controller.ts` | Random call matchmaking — seek/cancel/next/end (REST + RTDB signals) |

---

## DB Schema (Postgres)

Tables are created in `services/zephyr-api/src/core/database.service.ts`.

Core tables:
- `users`
- `sessions`
- `wallets`
- `user_revenue`
- `wallet_transactions`
- `ledger_idempotency`
- `rooms`
- `room_viewers`
- `messages`
- `call_sessions`
- `user_following`
- `user_blocks`
- `call_reports`
- `user_reports`
- `random_call_matches`
- `call_rate_tiers`
- `device_tokens`
- `iap_purchases`

Key columns:
- `users.public_id TEXT UNIQUE` — 8-digit derived hash
- `users.active_session_id TEXT` — current mobile session; newer login revokes older bearer tokens
- `users.status` — display-status fallback only; do not use as routeability truth
- `users.presence_connection`, `presence_activity`, `presence_availability`, `presence_updated_at` — Postgres projection of RTDB `presence/{userId}`
- `users.can_direct_call`, `can_random_call` — backend routing projection from RTDB presence
- `sessions.session_id TEXT` + `sessions.device_id TEXT` — API token session metadata used to mint session-bound Firebase tokens
- `user_revenue.spark_balance INTEGER` — host spark balance/revenue projection
- `ledger_idempotency (user_id, idempotency_key)` — protects call ticks and gifts from duplicate ledger writes
- `users.call_rate_coins_per_minute INT` — receiver sets their direct call rate
- `rooms.audience_count INT` — backend/feed projection updated by room join/leave REST calls; visible live audience presence lives in RTDB
- `rooms.last_heartbeat TIMESTAMPTZ` — updated every 15s by host
- `messages.read_at TIMESTAMPTZ` — null = unread, set = read (blue tick)
- `device_tokens.session_id` + `device_tokens.device_id` — active-session-scoped push delivery
- `iap_purchases.transaction_id TEXT UNIQUE` — purchase verification idempotency

---

## API Endpoints

This map is source-checked from the current Nest controllers. `packages/zephyr-contracts/openapi.yaml` is still partial and should not be treated as the complete route list.

```
GET  /
GET  /v1/health/live
GET  /v1/health/ready
POST /v1/health/end-stale-calls
GET  /v1/internal/demo-for-you/status
POST /v1/internal/demo-for-you/start
POST /v1/internal/demo-for-you/stop
POST /v1/internal/demo-for-you/cleanup
POST /v1/internal/end-call-session
POST /v1/internal/end-room
POST /v1/internal/sync-presence
POST /v1/auth/google-login
POST /v1/auth/apple-login
POST /v1/auth/firebase-token
POST /v1/auth/logout
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
GET  /legal/privacy
GET  /legal/terms
```

Firebase Chat:
- Backend: `POST /v1/auth/firebase-token` -> session-bound custom token for Firebase Auth
- Backend: `POST /v1/auth/logout` -> revoke current API session and clear Firebase session controls only if still matching
- Firestore: messages + conversations (real-time listeners)
- RTDB: canonical presence (connection/activity/routing/display status with onDisconnect)
- Storage: image uploads (5MB limit, format validation)
- FCM: push via `POST /v1/messages/push`
- Active-session guard: backend writes `session_controls/{userId}` in Firestore + RTDB; Firestore/RTDB/Storage rules allow pre-projection sessions during migration, then require `request.auth.token.sessionId` / `auth.token.sessionId` to match the active record once present
- Features: read/delivered receipts, block/report, delete for me/everyone, translate, anti-spam, pagination

---

## Key Flutter Packages

| Package | Purpose |
|---|---|
| `firebase_core` | Firebase initialization |
| `cloud_firestore` | Firebase Firestore — messages, conversations |
| `firebase_database` | Firebase RTDB — real-time presence |
| `firebase_storage` | Firebase Storage — image uploads |
| `firebase_auth` | Firebase Auth — custom token sign-in |
| `firebase_messaging` | FCM token registration and push delivery |
| `agora_rtc_engine: ^6.5.2` | Agora RTC — video calls + live streaming |
| `flutter_secure_storage: 10.1.0` | Token in iOS Keychain / Android Keystore |
| `google_sign_in` | Google OAuth |
| `sign_in_with_apple` | Apple Sign-In |
| `country_picker: ^2.0.27` | Country flag + dial code picker |
| `flutter_svg` | SVG rendering |
| `permission_handler` | Runtime camera/microphone/photo permissions |
| `image` | Off-main-thread chat-image preparation/compression |
| `image_picker` | Camera/photo library selection |
| `http` + `http_parser` | REST requests and multipart media metadata |
| `sqflite` + `path` + `path_provider` | Local cache/storage support |
| `cached_network_image` | Remote image cache/display |
| `wakelock_plus` | Keep screen awake during call/live flows |
| `url_launcher` | External legal/support/settings links |
| `in_app_purchase` + `in_app_purchase_android` | Store purchase flow |
| `sentry_flutter` | Mobile crash/error reporting |
| `flutter_native_splash` + `flutter_launcher_icons` | Launch screen and icon generation tooling |

## Key Backend Packages

| Package | Purpose |
|---|---|
| `@nestjs/common`, `@nestjs/core`, `@nestjs/platform-express` | NestJS REST API |
| `@nestjs/throttler` | Global rate limiting |
| `pg` | PostgreSQL access |
| `firebase-admin` | Firebase Admin custom tokens, FCM, Firestore/RTDB projections, trusted realtime fan-out |
| `agora-token` | Agora RTC token generation |
| `app-store-server-api` | Apple StoreKit transaction and refund handling |
| `google-auth-library` | Google OAuth/IAP verification support |
| `jose` + `jsonwebtoken` | Apple/Google/JWT token handling |
| `class-validator` + `class-transformer` | DTO validation and transformation |
| `multer` + `cloudinary` | Profile avatar/cover uploads |
| `helmet` | HTTP security headers |
| `@sentry/nestjs` | Backend crash/error reporting |

## Firebase Functions Packages

| Package | Purpose |
|---|---|
| `firebase-admin` | Admin SDK for RTDB/Firestore/API integration |
| `firebase-functions` | RTDB triggers and scheduled cleanup functions |

---
