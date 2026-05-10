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
- Deploy: Render auto-deploys from `main` branch

## Current status (as of 11 May 2026)

### Critical handoff for next session (11 May 2026, end-of-day)

- ✅ Latest pushed commit: `b4603c1e`
- ✅ Branch state: `main` synced to `origin/main`
- ✅ iOS simulator confirmed running (iPhone 17 Pro Max `8B6780BE-FC4B-47F0-8980-3D9D7504004A`)
- ✅ Android emulator: `google-services.json` added + Gradle plugin wired — Google Sign-In may now work but needs validation tomorrow
- ⚠️ Inbox message entry point issue reported by user — to be debugged next session
- ⚠️ Mock cards (`SarahBusy`, `TaniaOnline`, `MikeOffline`) injected into `_feedCards` — remove before production
- ⚠️ Mock `_followingIds` set hardcoded in `_loadData` — remove before production
- ⚠️ `lib/flags.dart` (`CountryFlags`) is in use — do not delete

### Next session priority order

1. Debug Inbox message entry point issue (user reported it, details coming)
2. Test Android Google Sign-In with new `google-services.json` (SHA-1 registered in Firebase)
3. Add Search by public ID (8-digit) UI — backend `GET /v1/users/by-public-id/:publicId` already deployed
4. Remove all mock cards + mock `_followingIds` once API sends real `hostStatus`
5. Push notifications (Firebase Cloud Messaging — Firebase project now exists)
6. Wire LiveKit RTC for real video/audio

### Messaging (completed 11 May 2026)

- ✅ `ZephyrMessage` + `ZephyrConversation` Flutter models added
- ✅ API client methods: `getConversations`, `getThread`, `sendMessage`, `markMessageRead`
- ✅ `InboxPage`: conversation list, avatars, unread badge, relative timestamps, empty state
- ✅ `ThreadPage`: chat bubbles (sent=right/blue, received=left/white), send bar, auto-scroll, mark-read on open
- ✅ Tab 3 wired to `InboxPage`
- ✅ `_MessageCache` singleton: cache-first load — instant back/forward navigation within session
- ✅ Backend endpoints: `POST /v1/messages`, `GET /v1/messages/conversations`, `GET /v1/messages/conversations/:userId`, `PATCH /v1/messages/:messageId/read`
- ✅ API tested end-to-end with curl (two guest accounts, bidirectional messaging confirmed)

### Owner account + profile UX (completed 10 May 2026)

- ✅ Owner Google email: `mr.gopaul.akshay@gmail.com` → `is_admin=TRUE`, `level=10` seeded on startup via `OWNER_GOOGLE_EMAIL` env var
- ✅ Custom `publicId = 28282828` set and persisted in DB
- ✅ Gold OWNER badge shown in Me tab + My Profile when `isAdmin=true`
- ✅ My Profile: view/edit mode toggle (Edit/Save in appBar)
- ✅ My Profile: tap-to-copy ID (Clipboard + snackbar)
- ✅ My Profile: "View Public Profile" preview button
- ✅ `GET /v1/users/by-public-id/:publicId` endpoint deployed (useful for search + test tooling)
- ✅ Nickname persistence fixed — Google/Apple re-login no longer overwrites `display_name`
- ✅ CallPricePage: stale `_me` fix (returns updated `UserProfile` on pop)

### Android Google Sign-In setup (11 May 2026)

- ✅ Firebase project created (linked to existing Google Cloud `zephyr-495115`)
- ✅ Android app registered in Firebase: package `com.zephyr.zephyr_mobile`
- ✅ SHA-1 fingerprint added: `10:60:A8:68:95:90:87:37:4A:C7:7A:39:C6:F8:48:D4:BF:31:07:66`
- ✅ `google-services.json` placed at `apps/zephyr-mobile/android/app/google-services.json`
- ✅ `com.google.gms.google-services` plugin added to `app/build.gradle.kts` + `settings.gradle.kts`
- ⚠️ Android Sign-In not yet confirmed working — needs test next session

### Key OAuth / IDs reference

- iOS Google client ID: `724639603736-n8v2kjqfg40l7bqkt26kov8cmofhn2db.apps.googleusercontent.com`
- Android Google client ID: `724639603736-08tovsj719dsb6atip932tqo1jg0gtl2.apps.googleusercontent.com`
- Web Google client ID (`GOOGLE_SERVER_CLIENT_ID`): `724639603736-f7v5k8112bjpfaq2igjm0b5fndlm8vc8.apps.googleusercontent.com`
- Owner UUID: `4a21364d-d84c-4ac2-8d57-1e7ce033b0dc`
- Owner publicId: `28282828`
- Android debug keystore SHA-1: `10:60:A8:68:95:90:87:37:4A:C7:7A:39:C6:F8:48:D4:BF:31:07:66`
- Java (for keytool): `/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool`

### Run commands

- iOS: `cd apps/zephyr-mobile && flutter run -d "8B6780BE-FC4B-47F0-8980-3D9D7504004A" --dart-define=API_BASE_URL=https://zephyr-api-wr1s.onrender.com`
- Android: `cd apps/zephyr-mobile && flutter run -d emulator-5554 --dart-define=API_BASE_URL=https://zephyr-api-wr1s.onrender.com`
- Android emulator ID: `Medium_Phone_API_36.1` (launch with `flutter emulators --launch Medium_Phone_API_36.1`)

### Backend endpoints (all deployed)

- `GET /v1/health/live` + `/v1/health/ready`
- `POST /v1/auth/guest-login`, `/google-login`, `/apple-login`
- `GET /v1/users/me`, `PATCH /v1/users/me`
- `GET /v1/users/by-public-id/:publicId` ← new
- `GET /v1/users/:userId`, `POST /v1/users/:userId/follow`, `DELETE /v1/users/:userId/follow`
- `GET /v1/rooms`, `POST /v1/rooms`, `POST /v1/rooms/:roomId/join`, `DELETE /v1/rooms/:roomId`
- `GET /v1/feed/live`
- `GET /v1/economy/config`, `/coin-packs`, `/wallet`, `POST /purchase-coins`
- `GET /v1/economy/private-call/quote`
- `GET /v1/economy/gifts/catalog`
- `POST /v1/economy/calls/start`, `/tick`, `/end`, `/rtc-token`
- `POST /v1/messages`
- `GET /v1/messages/conversations`
- `GET /v1/messages/conversations/:userId`
- `PATCH /v1/messages/:messageId/read`

### DB schema (Postgres, Render)

Tables: `users`, `wallets`, `user_revenue`, `wallet_transactions`, `user_following`, `rooms`, `messages`
Key columns: `users.public_id TEXT UNIQUE`, `users.is_admin BOOL`, `users.call_rate_coins_per_minute INT`

### Flutter packages in use

`country_picker: ^2.0.27`, `flutter_svg`, `flutter/services.dart` (Clipboard), `google_sign_in`, `sign_in_with_apple`



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

## Current status (as of 9 May 2026, latest update)

### Critical handoff for next session (9 May 2026, end-of-day — session 2)

- ✅ Latest pushed commit: see push below
- ✅ Branch state at handoff: `main` synced to `origin/main`
- ✅ iOS simulator confirmed running (iPhone 17 Pro Max `8B6780BE-FC4B-47F0-8980-3D9D7504004A`)
- ⚠️ Android emulator auth regression still unresolved
- ⚠️ Mock cards (`SarahBusy`, `TaniaOnline`, `MikeOffline`) injected into `_feedCards` — remove before production
- ⚠️ Mock `_followingIds` set (`mock-busy-user`, `mock-offline-user`) hardcoded in `_loadData` — remove before production
- ⚠️ `lib/flags.dart` (`CountryFlags`) is in use — do not delete

Next session priority order:

1. Fix Android emulator login regression (`emulator-5554`)
2. Remove all mock cards + mock `_followingIds` once API sends real `hostStatus` and `/v1/users/me/following`
3. Add viewer count (`👁 124`) to card bottom row (uses existing `audienceCount`)
4. Wire LiveKit RTC for real video/audio (critical path to shipping)
5. Gift sending flow UI + execution
6. In-app coin purchase (RevenueCat / StoreKit)
7. Push notifications

### Popular tab + Follow tab + Offline status (9 May 2026, session 2)

- ✅ Popular tab locale line: removed language — now shows flag + country code only (e.g. `🇺🇸 US`)
- ✅ Popular tab status badge: camera icon hidden (Discover keeps it, Popular does not)
- ✅ Offline status added to all tabs:
  - Faded gray dot (`#8E8E93`) + "Offline" label
  - Cards sorted: Live → Busy → Online → Offline across both Popular and Discover
  - Mock `MikeOffline` (🇳🇬 NG) added for preview
- ✅ Follow tab built — identical grid to Popular (`showPreview: false`, 2 columns):
  - Filters `_feedCards` to only those whose `hostUserId` is in `_followingIds`
  - Empty state: "Follow someone to see them here."
  - "Random match" button at bottom (same as Popular)
- ✅ `getFollowingIds(accessToken)` added to `ZephyrApiClient`:
  - Calls `GET /v1/users/me/following`
  - Gracefully returns empty set if endpoint not yet deployed (no crash)
- ✅ Mock `_followingIds = {'mock-busy-user', 'mock-offline-user'}` injected so Follow tab is testable now

### Discover card status system + Popular tab (9 May 2026, session 1)

- ✅ `LiveFeedCard` model extended with `hostStatus: 'live' | 'online' | 'busy' | 'offline'`
- ✅ Status badge top-left: camera icon (Discover only) + coloured dot + label
  - 🔴 red = Live, 🟠 orange = Busy, 🟢 green = Online, ⚫ gray = Offline
- ✅ `showPreview` flag on `_buildDiscoverLiveCard` — Popular/Follow pass `false`, Discover passes `true`
- ✅ Popular tab: 2-column grid, no preview box, no camera icon, flag+code only
- ✅ `withOpacity` → `withValues(alpha:)` deprecation fix (2 locations)
- ✅ `tsconfig.json` `baseUrl` deprecation fix

## Current status (as of 8 May 2026)

### Critical handoff for next session (8 May 2026, end-of-day)

- ✅ Latest pushed commit: `52655a60` (`feat(mobile): refresh home UI and switch country flag to SVG`)
- ✅ Branch state at handoff: `main` synced to `origin/main`
- ✅ `flutter test` passing (`+1`) after all today's changes
- ✅ iOS simulator confirmed running against staging (iPhone 17 Pro Max `8B6780BE-FC4B-47F0-8980-3D9D7504004A`)
- ✅ Android emulator confirmed running against staging (`emulator-5554`, Android 16 API 36)
- ⚠️ Android emulator auth regression is still unresolved — login flow needs a dedicated fix session
- ⚠️ `lib/flags.dart` (`CountryFlags`) is now back in use — do not delete it

Next session priority order:

1. Fix Android emulator login regression (`emulator-5554`) — blocks Android users
2. Continue Home Discover card polish or move to next screen (Call screen UI pass)
3. Wire LiveKit RTC into a real call/live session (biggest remaining feature)
4. Gift sending flow UI + execution
5. Follow/subscribe system (key for streamer discoverability and earning)

### Home Discover UI milestone completed (8 May 2026)

- ✅ Country flag in Home AppBar migrated from emoji to SVG (`assets/flags/mu.svg`, `flutter_svg ^2.0.10+1`)
- ✅ Home AppBar redesigned: `Popular / Discover / Follow` tab row as title, compact action icons (search, flag, trophy)
- ✅ Discover tab added with vertical `PageView` of live feed cards
- ✅ Blue discover card layout — full `Stack` overlay structure:
  - Top-left: "Opening live…" label (fades in only while joining)
  - Top-right: black preview box (placeholder for live video thumbnail)
  - Bottom: single `Positioned` `Row` with text stack left + green call button right
- ✅ Card bottom-left text stack: two lines vertically aligned
  - Line 1: `hostDisplayName` (username, bold white)
  - Line 2: country flag emoji + country code + language (e.g. `🇵🇭 PH English`)
- ✅ `LiveFeedCard` model extended with `hostCountryCode` and `hostLanguage` fields (API-optional, defaults `PH` / `English`)
- ✅ `CountryFlags.flagEmoji()` reused from `lib/flags.dart` for the locale line
- ✅ Green animated call button (`_ShakeCallButton`) placed bottom-right of card:
  - Diagonal gradient: Pantone green (`#00A651`) bottom-left → lime (`#7BEA3B`) top-right
  - Animation cycle (3.8 s): gentle phone shake (±6°, first 15%) + two staggered expanding ripple rings that fade out, then long rest pause
  - Tapping routes to `_openCallTabForHost()` (separate from card-wide tap which enters live)
  - Text stack and button share a single `Positioned` `Row` with `crossAxisAlignment.center` — always vertically aligned
- ✅ "Random match" `FilledButton` repositioned to sit on the card/whitespace boundary (bottom: 0) — top half on card, bottom half in white space
- ✅ Hot-reload red flash fixed: replaced `Ink` wrapper with `Material` color + `ClipRRect`
- ✅ `RepaintBoundary` noted as an optional future optimisation for the call button animation (not yet applied)

### Design decisions confirmed (8 May 2026)

- Blue card = placeholder for user's profile/cover photo (full card background)
- Black preview box = placeholder for live video thumbnail (LiveKit widget)
- Tap anywhere on card = enter full-screen live (`_enterRoom`)
- Tap green phone button = call the host (separate intent)
- Screens-first approach is correct: polish UI shell before wiring RTC/real data
- Economy philosophy: streamers earn first — 60% receiver share (`RECEIVER_SHARE_BPS=6000`) is above market
- Product mission: enable people to earn a living, not just side income

### SVG flag migration completed (8 May 2026)

- ✅ Added `apps/zephyr-mobile/assets/flags/mu.svg` (Mauritius flag, 4 horizontal stripes vector)
- ✅ `pubspec.yaml`: added `flutter_svg: ^2.0.10+1`, registered `assets/flags/`
- ✅ `main.dart` AppBar country action: `SvgPicture.asset('assets/flags/mu.svg', width: 20, height: 14)`
- ✅ `lib/flags.dart` restored to import use for locale line on discover cards

## Current status (as of 4 May 2026)

### Critical handoff for next session (4 May 2026, end-of-day)

- ✅ Latest pushed commit: `8df88051` (`fix(mobile): prevent iOS call action row overflow`)
- ✅ Branch state at handoff: `main` synced to `origin/main`
- ✅ Render staging health confirmed:
   - `GET /v1/health/live` → `HTTP 200`
   - `GET /v1/health/ready` → `HTTP 200`
- ✅ iOS simulator app boot against staging confirmed after overflow fix
- ⚠️ Android emulator login is reported broken again and must be treated as active regression (reproduce first tomorrow)
- ⚠️ Product-direction correction from owner:
   - current UI changes are not final
   - 3rd footer icon must remain `Go Live` (call action should not replace that primary behavior)
   - next session should be a screen-by-screen walkthrough before further UI refactors

Tomorrow-first execution order (do not skip):

1. Reproduce and fix Android emulator login on `emulator-5554`
2. Walk screen-by-screen with product owner and document intended behavior
3. Restore footer 3rd icon to `Go Live` flow
4. Apply agreed UI corrections only after the walkthrough

### UI shell + profile milestone completed (4 May 2026)

- ✅ Added post-login bottom navigation with 5 tabs: `Home`, `Live`, `Calls`, `Inbox`, `Me`.
- ✅ Home + Live now operate on **ephemeral live sessions** (no static pre-created room inventory).
- ✅ Apple sign-in button is now iOS-only (hidden on Android).
- ✅ Added `Me` menu with pages for `Level`, `My Balance`, `My Revenue`, `Settings`.

### Ephemeral live-session flow completed (4 May 2026)

- ✅ `POST /v1/rooms` now behaves as **Go Live**:
   - creates a live session immediately
   - enforces one active live per host (new Go Live replaces previous active live)
- ✅ `DELETE /v1/rooms/:roomId` added so host can end live; ended sessions disappear from live feed/list.
- ✅ `GET /v1/rooms` now returns only active live sessions (`status='live'`).
- ✅ `POST /v1/rooms/:roomId/join` now joins only active lives (non-live/missing returns not found).
- ✅ Flutter Home now supports host lifecycle directly:
   - `Go Live` (title + start)
   - `End Live` for host-owned active session
- ✅ Flutter live cards now expose viewer actions:
   - `Watch Live`
   - `Call Host` (routes to private-call flow)

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
- ✅ RTC join-token scaffold is now implemented for live call sessions:
   - backend token service added (`RtcService`)
   - participant-auth endpoint added: `POST /v1/economy/calls/:sessionId/rtc-token`
   - only live-session caller/receiver can request join token
   - mobile includes RTC token preparation hook + readiness indicator (room UI plugin integration is next)
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
- ✅ Live authenticated call flow smoke validated on Render after latest deploy:
   - guest logins (`caller`, `receiver`, `third`) all `HTTP 201`
   - `POST /v1/economy/calls/start` → `HTTP 201`
   - `POST /v1/economy/calls/:sessionId/tick` (`10s`) → `HTTP 201`
   - `POST /v1/economy/calls/:sessionId/end` → `HTTP 201`
   - busy protections verified:
      - busy caller second start attempt → `HTTP 400`
      - busy receiver called by third user → `HTTP 400`
   - wallet/economy deltas verified:
      - caller coin delta: `-350`
      - receiver spark delta: `+210`
      - receiver coin delta: `0` (Spark-only earning behavior confirmed)

### Auth milestone completed (3 May 2026)

- ✅ Google login was previously working end-to-end on both Android emulator and iOS simulator against staging.
- ✅ iOS flow still works after Android auth fixes (no regression).
- ✅ Backend Google audience allowlist now includes iOS + Android + Web OAuth client IDs.
- ✅ Mobile app now requests Google ID tokens with `GOOGLE_SERVER_CLIENT_ID` (Web client ID) via `--dart-define`.
- ✅ Latest auth fix commit is on `main`: `de008ac4`.

Regression note (4 May 2026, latest):

- ⚠️ Android emulator login has reportedly stopped working again and is currently unresolved.
- ✅ iOS simulator still launches and reaches app runtime; auth regression appears Android-specific until proven otherwise.

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
- Latest deploy/build incident (resolved):
   - Render build failed once with TypeScript nullability error (`TS18047`) on `result.rowCount`
   - fixed in commit `a8a9e2d2` by null-safe check: `(result.rowCount ?? 0) > 0`
   - Render auto-deploy after push succeeded; service is live and healthy

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
- `DELETE /v1/rooms/:roomId`
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
- `POST /v1/economy/calls/:sessionId/rtc-token`

Recent backend validation additions:

- E2E coverage for feed route in `services/zephyr-api/test/app.e2e-spec.ts`:
   - unauthenticated `GET /v1/feed/live` returns `401`
   - authenticated feed fetch returns room cards after room creation
- Unit coverage for call economics/state in `services/zephyr-api/src/core/store.service.spec.ts` now includes:
   - same user can act as both caller and receiver
   - caller coin deduction + receiver Spark accrual
   - busy caller cannot start a second live call
   - busy receiver cannot be called by another user
   - live caller/receiver participant resolution for RTC token auth path
   - outsider rejection for RTC token auth path

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

- iOS simulator launch and runtime are confirmed against staging.
- Android emulator login currently requires re-validation due to reported regression.

Implemented app flow:

- Fetch profile
- Swipe live feed cards (`/v1/feed/live`)
- Go live (`POST /v1/rooms`) and end live (`DELETE /v1/rooms/:roomId`) from Home
- Watch/join live from feed card CTA (`POST /v1/rooms/:roomId/join`)
- Start private call to host via `Call Host` from live card (separate from live viewing flow)

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
- `zephyr-api`: focused `store.service.spec.ts` passes (`12` tests), including RTC participant auth checks
- Render live health checks pass:
   - `GET /v1/health/live` → `HTTP 200`
   - `GET /v1/health/ready` → `HTTP 200` (`storage: postgres`)
- Render live quote checks pass:
   - direct quote (`2 min @ 2100`) returns `requiredCoins=4200`
   - random quote (`2 min @ 600`) returns `requiredCoins=1200`
- Render live authenticated call smoke passes with busy-state + Spark assertions
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
- `LIVEKIT_API_KEY` (required for RTC token signing)
- `LIVEKIT_API_SECRET` (required for RTC token signing)
- `LIVEKIT_WS_URL` (returned to client for room connection)

Optional RTC env vars (backend):

- `RTC_TOKEN_TTL_SECONDS` (default: `3600`, max: `86400`)

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

When enabling RTC token issuance on staging, also set:

- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`
- `LIVEKIT_WS_URL`

## Resume plan (next session)

1. Fix Android emulator login regression (`emulator-5554`) — first, always
2. Continue Discover card polish or start Call screen UI pass
3. Wire LiveKit RTC into real call/live session (core product feature)
4. Gift sending flow — UI + execution (key for streamer earnings)
5. Follow system — discoverability for new streamers
6. In-app purchases (RevenueCat / StoreKit) for coins
7. Push notifications — users need to know when someone calls them
8. Spark cashout/redeem flow for streamers
9. App Store + Play Store submission prep

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

"Continue Zephyr from `README_AI.md`. Latest work is on `main`. Fix Android emulator login on `emulator-5554` first, then remove the two mock busy/online cards in `_HomeScreenState._feedCards` and wire real `hostStatus` from the API. Then add viewer count to the Discover card and start the Live tab UI."