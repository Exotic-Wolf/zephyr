# Zephyr — Product & Technical Reference

> This file is the single source of truth for product decisions, pricing, architecture, and development context. Read this first before touching any code or starting a new session.

---

## Product Vision

- **Chamet/Olamet-style MVP** in Flutter + NestJS
- Target market: **Arab Gulf users** calling Philippines/Asia hosts
- Revenue: coin-based gifts + random video calls (Agora)
- Ship fast. Scale infra after revenue.

---

## Architecture

| Layer | Stack | Location |
|---|---|---|
| Mobile | Flutter (Dart) | `apps/zephyr-mobile` |
| Backend API | NestJS (TypeScript) | `services/zephyr-api` |
| Database | PostgreSQL (Render) | Singapore region |
| Real-time | Socket.IO (`/feed`, `/call` namespaces) — feed events + matchmaking only | Backend |
| Messaging | Firebase Firestore + Storage + FCM | `firebase_chat_service.dart` |
| Status & Presence | Firebase RTDB (asia-southeast1) | Online/inactive/offline/busy/live, call signaling, live state — **source of truth for availability** |
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
```

---

## Flutter App Structure (`apps/zephyr-mobile/lib/`)

| File | Purpose |
|------|---------|
| `main.dart` | App bootstrap, session restore via `flutter_secure_storage` |
| `app_constants.dart` | `apiBaseUrl`, `googleServerClientId`, env constants |
| `models/models.dart` | All data models: `UserProfile`, `Room`, `ZephyrMessage`, `WalletSummary`, `CoinPack`, `CallSession`, etc. |
| `services/api_client.dart` | All HTTP calls — GET/POST/PATCH/DELETE |
| `services/firebase_chat_service.dart` | Firebase chat — Firestore messages, RTDB presence, Storage images, block/report |
| `pages/home_screen.dart` | Feed, socket connection, inbox badge, 5s poll fallback, RTDB listener for incoming direct calls |
| `features/call/direct_call_screen.dart` | Reusable Agora video call screen (direct + random), remote mute detection, PIP |
| `features/call/incoming_call_overlay.dart` | Incoming call overlay — accept/decline, caller info |
| `pages/host_live_screen.dart` | Host live stream, heartbeat timer (15s) |
| `pages/go_live_countdown_page.dart` | 3-2-1 countdown, creates room |
| `pages/viewer_live_screen.dart` | Viewer live stream, reactions, comments |
| `pages/onboarding_page.dart` | Google Sign-In, Apple Sign-In, guest login |
| `pages/explore_page.dart` | Search users by name or 8-digit public ID |
| `pages/inbox_firebase_page.dart` | Conversation list (real-time Firestore), presence dots, unread badges |
| `pages/thread_firebase_page.dart` | DM chat — real-time messages, read/delivered receipts (✓✓), images, translate, delete, anti-spam |
| `pages/my_profile_page.dart` | View/edit profile |
| `widgets/` | Shared widgets: gifts, spark icon, coin icon, language picker |

---

## Backend Structure (`services/zephyr-api/src/`)

| File | Notes |
|------|-------|
| `main.ts` | Bootstrap — uses `RedisIoAdapter` (falls back to in-memory if no `REDIS_URL`) |
| `redis-io.adapter.ts` | Custom Socket.IO adapter for horizontal scaling |
| `core/store.service.ts` | All DB logic — messages, rooms, economy, wallets |
| `core/database.service.ts` | Schema init, migrations, periodic cleanup |
| `core/rtc.service.ts` | Agora token generation |
| `auth/auth.controller.ts` | `GET /v1/auth/firebase-token` — custom Firebase token for client auth |
| `messages/messages.controller.ts` | `POST /v1/messages/push` — FCM push relay, device tokens, delivery/read receipts |
| `rooms/rooms.gateway.ts` | Socket.IO `/feed` namespace — room created/ended/updated |
| `economy/economy.controller.ts` | All economy endpoints |

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
POST /v1/auth/guest-login, /google-login, /apple-login
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

WebSocket namespaces:
- `/feed` — live room events (`feed:room-created`, `feed:room-ended`, `feed:room-updated`)
- `/call` — random call matchmaking (`call:join_queue`, `call:leave_queue`, `call:next`, `call:end`, `call:matched`, `call:partner_left`)

Firebase Chat:
- Backend: `GET /v1/auth/firebase-token` → custom token for Firebase Auth
- Firestore: messages + conversations (real-time listeners)
- RTDB: presence (online/inactive/offline/busy/live with onDisconnect)
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
- **Firebase RTDB is the single source of truth for real-time status** — Presence (online/inactive/offline/busy/live), call status, and live status all live in RTDB under `presence/{userId}`. RTDB's `onDisconnect` guarantees cleanup even on app kill/crash. `setInactiveStatus()` is written on app background so users appear as "away but reachable" (yellow dot) rather than offline. All clients listen to RTDB for user availability before initiating calls or showing status badges.
- **Firebase Cloud Functions (asia-southeast1)** — 3 deployed functions provide server-side safety nets:
  - `onCallSignalDeleted`: RTDB trigger on `direct_calls/{userId}` deletion → ends Postgres call session via internal API
  - `onPresenceChanged`: RTDB trigger on `presence/{userId}` update → if state leaves 'live', ends the room in Postgres + emits Socket.IO `feed:room-ended`
  - `reapStalePresence`: Scheduled every 5 min → scans all presence nodes, resets stale entries (>5min) to 'offline', ends orphaned live rooms
  - Internal endpoints: `POST /v1/internal/end-call-session`, `POST /v1/internal/end-room` (validated via `X-Service-Key` header)
- **Agora RTC** — replaces LiveKit for ALL video (calls + live streaming). Proprietary UDP bypasses Gulf WebRTC filtering. Single SDK, smaller APK.
- **Socket.IO** — foreground real-time for feed events (`/feed`) and call matchmaking (`/call`) only. NOT used for messaging or presence. `MessagesGateway` was deleted — FCM is the delivery path for chat notifications.
- **FCM/APNs** — push notifications for chat messages (backend relays via `POST /v1/messages/push`)
- **Redis Socket.IO adapter** — wired, falls back to in-memory. Enable by setting `REDIS_URL` on Render. Required at 5K+ users.
- **Firebase is truth** — Firestore is source of truth for messages/conversations. RTDB is source of truth for real-time status (presence + call state). Backend only issues tokens + relays push.

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
| Auth (Google / Apple / Guest) | ✅ Done | 100% |
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
| Onboarding flow | ❌ Missing | 0% |

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

> Live streaming audience is naturally self-limiting: users in a random call cannot simultaneously watch a live stream. Random calls pull users out of passive watching into active (paying) calls. Live works as a discovery surface → direct call conversion funnel, keeping viewer counts low and Agora live costs manageable.

**Live stream viewer cap (by host level):**

| Host Level | Max Viewers | Agora cost (1hr, no gifts) |
|---|---|---|
| ≤Lv3 | 20 | ~$1.32 |
| Lv4–Lv5 | 50 | ~$3.12 |
| Lv6–Lv8 | 100 | ~$5.92 |
| Lv9+ | 200 | ~$11.52 |

Caps serve two purposes: protect the platform from costly zero-gift streams at low levels, and incentivise hosts to level up (more viewers = more gift potential = more earning). In practice, viewer counts stay low anyway — the random call algorithm continuously pulls viewers out of live streams into paid calls.

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

**Live → Random → Direct call funnel:**
1. User watches a live stream (free, no cost to them)
2. Taps random call → starts paying 600 coins/min
3. Likes the person → books direct call (Lv6 = 5,400 coins/min)
4. During calls, sends gifts → highest margin feature

---

## Call Types & Mechanics

### Random Call

| State | Coins | What happens |
|---|---|---|
| Searching | 0 | Algorithm finds match (priority: live hosts → idle users) |
| Connected | 600/min | Both parties in call, coins tick |
| Next tapped | 0 | Coins stop instantly, screen blurs, new match search begins |
| New match found | 600/min | Coins resume |
| Call ended | 0 | Call over, coins stop |

- Both parties opt in implicitly — no accept/decline screen
- If matched person is live: their stream **pauses**, status → **busy**
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
- [x] Matchmaking queue — `call:join_queue` / `call:leave_queue` / `call:next` / `call:end` Socket.IO events on `/call` namespace; block-aware pairing
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

- [ ] Onboarding flow — first-launch screen: set nickname, pick country/language
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
- [x] Random call matchmaking — Socket.IO `/call` namespace, Agora token per-user, block-aware queue
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
- [x] Auth — Google, Apple, Guest (iOS + Android)
- [x] Home feed — live cards, user cards, real-time socket
- [x] Inbox — conversation list, unread badges, timestamps
- [x] Thread (DM) — chat bubbles, send, mark-read, auto-scroll
- [x] Explore — search by name or 8-digit public ID
- [x] Live streaming — host + viewer screens, timer, viewer count
- [x] Avatar upload — Cloudinary, camera/gallery picker
- [x] Profile editing — nickname, gender, birthday, country, language
- [x] Settings — logout at Me → ⚙ Settings → Sign Out
- [x] Redis Socket.IO adapter — wired, no-op without `REDIS_URL`
- [x] Mock data removed — mock feed cards, mock followingIds, debug logs gone
- [x] Direct call — RTDB signaling (`/direct_calls/{receiverUserId}`), incoming call overlay (accept/decline), Agora video screen with remote mute detection, camera-off PIP placeholder, dispose cleanup
- [x] Direct call camera-off handling — remote mute detected via `onRemoteVideoStateChanged` (reason-based, not state-based), camera flip no longer triggers false "camera off" on remote side
