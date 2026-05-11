# README_AI

This file is a handoff snapshot so we can resume Zephyr quickly in the next session.
**Always read this first before touching any code.**

---

## Product aim

- Build a **minimal Chamet-like MVP** in Flutter + NestJS.
- Ship fast. Budget: **$50–$100/month**, scale infra after revenue.

---

## Current architecture

- Monorepo root: `/Users/wolf/dev/zephyr`
- Mobile app: `apps/zephyr-mobile` (Flutter)
- Backend API: `services/zephyr-api` (NestJS)
- API contract: `packages/zephyr-contracts/openapi.yaml`
- Deploy: Render auto-deploys `services/zephyr-api` from `main` branch
- API live at: `https://zephyr-api-wr1s.onrender.com`

---

## Run commands

```bash
# iOS (iPhone 17 Pro Max simulator)
cd apps/zephyr-mobile && flutter run -d "8B6780BE-FC4B-47F0-8980-3D9D7504004A" --dart-define=API_BASE_URL=https://zephyr-api-wr1s.onrender.com

# Android emulator
cd apps/zephyr-mobile && flutter run -d emulator-5554 --dart-define=API_BASE_URL=https://zephyr-api-wr1s.onrender.com

# Launch Android emulator if not running
flutter emulators --launch Medium_Phone_API_36.1

# Build debug APK
flutter build apk --debug --dart-define=API_BASE_URL=https://zephyr-api-wr1s.onrender.com
```

---

## Key IDs & credentials

| Item | Value |
|------|-------|
| iOS Google client ID | `724639603736-n8v2kjqfg40l7bqkt26kov8cmofhn2db.apps.googleusercontent.com` |
| Android Google client ID | `724639603736-08tovsj719dsb6atip932tqo1jg0gtl2.apps.googleusercontent.com` |
| Web Google client ID (`GOOGLE_SERVER_CLIENT_ID`) | `724639603736-f7v5k8112bjpfaq2igjm0b5fndlm8vc8.apps.googleusercontent.com` |
| Owner Google email | `mr.gopaul.akshay@gmail.com` |
| Owner UUID | `4a21364d-d84c-4ac2-8d57-1e7ce033b0dc` |
| Owner publicId | `28282828` |
| Android debug SHA-1 | `10:60:A8:68:95:90:87:37:4A:C7:7A:39:C6:F8:48:D4:BF:31:07:66` |
| iOS simulator UDID | `8B6780BE-FC4B-47F0-8980-3D9D7504004A` |
| Android emulator ID | `emulator-5554` / `Medium_Phone_API_36.1` |

---

## Current status (as of 12 May 2026)

### Latest commit: `b323f4ea`

### ✅ Completed this session

- **File refactor**: `main.dart` was 7400 lines → split into 18 files (0 `flutter analyze` errors)
- **Persistent login**: `flutter_secure_storage 10.1.0` — token saved to iOS Keychain / Android Keystore. Auto-restored on app launch via `_restoreSession()` in `main.dart`.
- **WebSocket feed**: Socket.io gateway on `/feed` namespace. `IoAdapter` added to `main.ts` (was the root cause of sockets never working). Events: `feed:room-created`, `feed:room-ended`, `feed:room-updated`.
- **5s poll fallback**: `Timer.periodic(5s, _refreshFeed)` in `home_screen.dart` as safety net if socket drops.
- **Own card filter**: `_feedCards` filters out `c.hostUserId == _me?.id` so host doesn't see their own card.
- **Heartbeat system**: Host sends `POST /v1/rooms/:id/heartbeat` every **15 seconds**. Server cleanup runs every **10 seconds** — deletes rooms with no heartbeat for **40 seconds**, or older than 30 minutes.
- **endRoom idempotent**: Server no longer throws `NotFoundException` if room already deleted.
- **🐛 ROOT BUG FIXED**: `DELETE` method was missing from `_request()` switch in `api_client.dart` — fell through to `GET`, causing all DELETE calls (endRoom, unfollow, etc.) to silently send a `GET` and get a 404. **One-line fix: `'DELETE' => await client.deleteUrl(uri)`.**
- **Mock cards**: Prefixed with `[Mock]`, sorted by status (live→busy→online→offline).

### ⚠️ Known issues / warnings

- Mock cards (`[Mock] SarahBusy`, `[Mock] TaniaOnline`, `[Mock] MikeOffline`) still in `_feedCards` — remove before production
- Mock `_followingIds` hardcoded in `_loadData` — remove before production
- Socket debug logs still in `home_screen.dart` (`[socket] connected`, `[socket] connect_error`) — remove before production
- `endRoom` debug logs still in `host_live_screen.dart` — remove before production

---

## Flutter app file structure (`apps/zephyr-mobile/lib/`)

| File | Purpose |
|------|---------|
| `main.dart` | App bootstrap, session restore via `flutter_secure_storage` |
| `app_constants.dart` | `apiBaseUrl`, `googleServerClientId`, `tabletBreakpoint`, `maxContentWidth` |
| `models/models.dart` | All data models: `UserProfile`, `Room`, `LiveFeedCard`, `AuthSession`, `WalletSummary`, `CoinPack`, `CallQuote`, `CallSession`, `ZephyrMessage`, `ZephyrConversation`, etc. |
| `services/api_client.dart` | All HTTP API calls. Uses `dart:io` `HttpClient`. **CRITICAL: switch has GET/POST/PATCH/DELETE cases.** |
| `pages/home_screen.dart` | Main home screen — feed tabs, socket connection, 5s poll fallback |
| `pages/host_live_screen.dart` | Host's live stream — heartbeat timer (15s), socket for viewer count, `_end()` dialog |
| `pages/go_live_countdown_page.dart` | 3-2-1 countdown — creates room, `pushReplacement` to HostLiveScreen |
| `pages/viewer_live_screen.dart` | Viewer's live stream — reactions, comment input |
| `pages/onboarding_page.dart` | Google Sign-In, Apple Sign-In, guest login |
| `pages/explore_page.dart` | Search users by name or 8-digit public ID |
| `pages/inbox_page.dart` | Conversation list, polls every 5s |
| `pages/thread_page.dart` | Chat bubbles, polls every 4s, `MessageCache` class |
| `pages/my_profile_page.dart` | View/edit profile |
| `widgets/shared_live_widgets.dart` | `LiveComment`, `FloatingGift`, `FloatingGiftWidget`, `LiveCtrlBtn` |
| `widgets/spark_icon.dart` | `SparkIcon`, flame painters |
| `widgets/coin_icon.dart` | `CoinIcon` |
| `widgets/hero_bullet.dart` | `HeroBullet`, `StatCell` |
| `widgets/language_picker_sheet.dart` | `LanguagePickerSheet` |

---

## Backend key files (`services/zephyr-api/src/`)

| File | Key notes |
|------|-----------|
| `main.ts` | `IoAdapter` added — required for Socket.io to work |
| `rooms/rooms.gateway.ts` | `@WebSocketGateway` on `/feed` namespace. `emitRoomCreated`, `emitRoomEnded`, `emitRoomUpdated` |
| `rooms/rooms.controller.ts` | Injects `RoomsGateway`, emits socket events on create/end/join/leave |
| `core/store.service.ts` | All DB logic. `endRoom()` idempotent. `heartbeatRoom()` updates `last_heartbeat`. `searchUsers()` by name OR public_id |
| `core/database.service.ts` | Schema init + migrations. Startup cleanup (>30min rooms). Periodic cleanup every 10s (40s heartbeat TTL) |

---

## DB schema (Postgres on Render)

Tables: `users`, `wallets`, `user_revenue`, `wallet_transactions`, `user_following`, `rooms`, `messages`

Key columns:
- `users.public_id TEXT UNIQUE` — 8-digit derived hash
- `users.is_admin BOOL`
- `users.call_rate_coins_per_minute INT`
- `rooms.last_heartbeat TIMESTAMPTZ` — updated every 15s by host

---

## Backend endpoints (all deployed)

```
GET  /v1/health/live, /v1/health/ready
POST /v1/auth/guest-login, /google-login, /apple-login
GET  /v1/users/me
PATCH /v1/users/me
GET  /v1/users/by-public-id/:publicId
GET  /v1/users/:userId
POST /v1/users/:userId/follow
DELETE /v1/users/:userId/follow
GET  /v1/rooms
POST /v1/rooms
POST /v1/rooms/:roomId/join
POST /v1/rooms/:roomId/heartbeat
DELETE /v1/rooms/:roomId
GET  /v1/feed/live
GET  /v1/economy/config, /coin-packs, /wallet
POST /v1/economy/purchase-coins
GET  /v1/economy/private-call/quote
GET  /v1/economy/gifts/catalog
POST /v1/economy/calls/start, /tick, /end, /rtc-token
POST /v1/messages
GET  /v1/messages/conversations
GET  /v1/messages/conversations/:userId
PATCH /v1/messages/:messageId/read
```

WebSocket: `wss://zephyr-api-wr1s.onrender.com/feed` (namespace `/feed`)
Events emitted by server: `feed:room-created`, `feed:room-ended`, `feed:room-updated`

---

## Flutter packages in use

- `socket_io_client: 3.1.4`
- `flutter_secure_storage: 10.1.0`
- `google_sign_in`
- `sign_in_with_apple`
- `country_picker: ^2.0.27`
- `flutter_svg`

---

## MVP completion status (as of 12 May 2026)

Overall: **~55%**

| Area | Status | % |
|------|--------|---|
| Auth (Google/Apple/Guest) | ✅ Done | 100% |
| Home feed (cards, status, real-time) | ✅ Done | 90% |
| Go Live / Host screen | ✅ Done | 80% |
| Viewer screen | ✅ Basic done | 60% |
| Direct messages (real-time, WebSocket) | ✅ Done | 90% |
| Explore / Search | ✅ Done | 85% |
| My Profile | ✅ Done | 75% |
| Persistent login | ✅ Done | 100% |
| **Real video/audio (LiveKit)** | ❌ Missing | 0% |
| Push notifications (FCM) | ❌ Missing | 0% |
| Follow/unfollow UI | ❌ Missing | 20% |
| Wallet / coins UI | ❌ Missing | 30% |
| Gifts during live | ❌ Missing | 10% |
| App icon + splash | ❌ Missing | 0% |
| Pagination / lazy load | ❌ Missing | 0% |

**Blockers to shipping**: Real video/audio (LiveKit) + Push notifications (FCM). Everything else is polish.

---

## Backlog (priority order)

1. **LiveKit RTC** — real video/audio for live streams and private calls (biggest missing piece)
2. **Push notifications** — Firebase Cloud Messaging (FCM), required for chat to be useful when app is closed
3. Remove debug logs + mock cards before production
4. Follow/unfollow UI on ProfilePage
5. Wallet UI (coin balance, purchase, transaction history)
6. Gifts during live stream
7. App icon + splash screen
8. Pagination / lazy load on home feed
9. Onboarding flow

---

## Lessons learned (do not repeat)

- **Always check `_request()` switch for missing HTTP methods before debugging server-side.** The `DELETE` case was missing — spent hours debugging server cleanup logic when the bug was one line in the client.
- Socket.io URL: pass `https://` directly — socket.io handles upgrade internally. Do NOT convert to `wss://`.
- `IoAdapter` must be added to `main.ts` — without it, WebSocket gateway silently never binds.
- `double.infinity.toInt()` throws on Flutter native — use `999999` for "unlimited" reconnect attempts.
- Owner startup seeding uses `OWNER_GOOGLE_EMAIL` env var on Render.
- `catch (_) {}` silently swallows errors — always use `catch (e) { debugPrint(...) }` during development.
- `InboxPage` is destroyed when navigating to `ThreadPage` — persistent sockets must live in `HomeScreenState`, not in page state.
- `null == null` is `true` in Dart — always guard nullable ID comparisons with a non-null check first.
