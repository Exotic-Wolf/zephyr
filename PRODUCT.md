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
| Real-time | Socket.IO (`/chat`, `/feed` namespaces) | Backend |
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
| `pages/home_screen.dart` | Feed, socket connection, inbox badge, 5s poll fallback |
| `pages/host_live_screen.dart` | Host live stream, heartbeat timer (15s) |
| `pages/go_live_countdown_page.dart` | 3-2-1 countdown, creates room |
| `pages/viewer_live_screen.dart` | Viewer live stream, reactions, comments |
| `pages/onboarding_page.dart` | Google Sign-In, Apple Sign-In, guest login |
| `pages/explore_page.dart` | Search users by name or 8-digit public ID |
| `pages/inbox_page.dart` | Conversation list |
| `pages/thread_page.dart` | DM chat bubbles, real-time via MessageBus, read receipts |
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
| `messages/messages.gateway.ts` | Socket.IO `/chat` namespace — emits to both sender and receiver |
| `rooms/rooms.gateway.ts` | Socket.IO `/feed` namespace — room created/ended/updated |
| `economy/economy.controller.ts` | All economy endpoints |

---

## DB Schema (Postgres)

Tables: `users`, `wallets`, `spark_wallets`, `wallet_transactions`, `user_following`, `rooms`, `messages`, `call_sessions`, `gifts`

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
- `/chat` — real-time messaging (`chat:message`, `chat:read`, `chat:join`)
- `/feed` — live room events (`feed:room-created`, `feed:room-ended`, `feed:room-updated`)

---

## Flutter Packages

| Package | Purpose |
|---|---|
| `socket_io_client: 3.1.4` | Real-time Socket.IO |
| `flutter_secure_storage: 10.1.0` | Token in iOS Keychain / Android Keystore |
| `google_sign_in` | Google OAuth |
| `sign_in_with_apple` | Apple Sign-In |
| `country_picker: ^2.0.27` | Country flag + dial code picker |
| `flutter_svg` | SVG rendering |

---

## Architecture Decisions (Locked)

- **Agora** — replaces LiveKit for ALL video (calls + live streaming). Proprietary UDP bypasses Gulf WebRTC filtering. Single SDK, smaller APK.
- **Socket.IO** — foreground real-time for messaging and matchmaking
- **FCM/APNs** — background/killed state push notifications (not yet built)
- **Redis Socket.IO adapter** — wired, falls back to in-memory. Enable by setting `REDIS_URL` on Render. Required at 5K+ users.
- **Server always truth** — `getConversations` is authoritative unread count. Socket does optimistic increments only.

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
| Go Live / Host screen | ✅ Done | 80% |
| Viewer screen | ✅ Basic done | 60% |
| Direct messages (real-time, WebSocket) | ✅ Done | 90% |
| Explore / Search | ✅ Done | 85% |
| My Profile | ✅ Done | 75% |
| Persistent login | ✅ Done | 100% |
| Economy backend (coins, sparks, calls, gifts) | ✅ Built | 80% |
| Real video/audio (Agora) | ❌ Not started | 0% |
| Push notifications (FCM) | ❌ Not started | 0% |
| Follow/unfollow UI | ❌ Partial | 20% |
| Wallet / coins UI | ❌ Partial | 30% |
| Gifts during live | ❌ Partial | 10% |
| App icon + splash | ❌ Missing | 0% |
| Onboarding flow | ❌ Missing | 0% |

---

## Known Blockers Before Ship

| Blocker | Solution |
|---|---|
| No real video/audio | Agora SDK integration |
| No push notifications | Firebase Cloud Messaging (FCM) |
| Mock cards in feed | Remove `[Mock]` cards before production |
| No Apple Developer account | Enroll at developer.apple.com ($99/year) |
| Render API sleeps | Upgrade to Standard plan ($25/mo) |

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

- Caller initiates from a profile
- Receiver gets an incoming call screen — they can **accept** or **decline**
- If declined: caller is not charged for that minute
- Rate is set by receiver based on their level (2,100 → 27,000 coins/min)
- Receiver earns 60% of the rate they set
