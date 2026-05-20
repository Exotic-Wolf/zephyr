# Zephyr — Product Backlog

> **State**: Ship blockers cleared. Push notifications wired (APNs → Firebase done; Xcode capability needs verification on device). Apple Sign In missing — required by App Store if Google Sign In is offered. Ready to move into first impression + store submission work.
> **Revenue model**: Random video calls (Olamet model) — 17+ rating, general social, no explicit content policy, report button ends call and flags user. LiveKit already integrated. Coins/gifts backend already done.

---

## 💰 0. Revenue Feature — Random Call (Olamet model)

> **Store compliance**: 17+ age rating (set in App Store Connect + Play Console). ToS prohibits explicit content. Report button = safety net. No AI moderation needed at v1 — reactive bans only. Exactly how Olamet, Azar, BIGO Live operate.

### Backend
- [ ] **Matchmaking queue** — Socket.IO event `call:join_queue` / `call:leave_queue`; server pairs two waiting users and emits `call:matched` with LiveKit room token to both
- [ ] **Call session table** — `call_sessions` (id, user_a_id, user_b_id, livekit_room, started_at, ended_at, ended_by)
- [ ] **Report endpoint** — `POST /v1/calls/:sessionId/report`; stores report, ends LiveKit room, increments report count on reported user
- [ ] **Auto-ban threshold** — user with 5+ reports in 7 days gets `is_banned = true`; banned users rejected from queue
- [ ] **Coin deduction** — deduct X coins per minute from caller (or flat per call); existing economy service handles transaction

### Flutter
- [ ] **"Find a Call" entry point** — button on Home tab or dedicated tab; checks coin balance before joining queue
- [ ] **Waiting screen** — animated UI while in queue; cancel button emits `call:leave_queue`
- [ ] **In-call screen** — full-screen video (LiveKit), flip camera, mute, end call, report button; gift coins button (economy already wired)
- [ ] **Post-call screen** — "Call ended", option to send a DM to the person you just met
- [ ] **Skip / next** — ends current call, re-joins queue immediately

### Store compliance (one-time setup, no code)
- [ ] **Set 17+ rating** — App Store Connect → My Apps → [App] → Age Rating
- [ ] **Set 17+ rating** — Google Play Console → Content Rating wizard
- [ ] **Terms of Service** — add "Users must be 17+. Explicit content is prohibited." to ToS page

---

## 🔴 1. Ship Blockers — can't release without these

- [x] **Apple Developer account** ($99/yr) — unlocks App Store, TestFlight, APNs, real device push on iOS
- [x] **Google Play Developer account** ($25 once) — unlocks Play Store
- [x] **iOS APNs** — APNs Auth Key uploaded to Firebase ✅; still need to enable Push Notifications capability in Xcode (Runner → Signing & Capabilities → + Push Notifications)
- [x] **Backend idempotency dedup** — done: backend checks `X-Idempotency-Key`, returns existing message within 60s window, skips duplicate socket/FCM
- [x] **Sentry source maps** — plugin configured; run `dart run sentry_dart_plugin` after each release build
- [ ] **Sign in with Apple** — App Store REQUIRES this if Google Sign In is offered; package already in pubspec; need Apple Dev portal config + Xcode capability + Flutter screens

---

## 🟠 2. First Impression — what the first real user sees

- [ ] **Onboarding flow** — first-launch screen: set nickname, pick country/language; no one should land on an empty home tab with a default name
- [ ] **Follow / unfollow UI** — Follow button on ProfilePage, follower/following counts; backend is done, button doesn't exist — users can't build a social graph
- [ ] **Empty feed state** — if following 0 people, feed is a blank screen; needs a "Find people" prompt or curated suggestions
- [ ] **Optimistic message send** — bubble appears instantly before server ACK; right now there's a 150–300ms dead gap after tapping Send — feels like 2010

---

## 🟡 3. Product Completeness — features that should exist

- [ ] **Wallet / coins UI** — balance display, transaction history (backend fully done, no UI)
- [ ] **Gift sending from DM** — send coins as gift directly from thread (backend done)
- [ ] **Typing indicator** — "..." bubble when other user is typing
- [ ] **Block / report user** — safety feature; backend not built
- [ ] **Custom Sentry breadcrumbs** — log socket connect/disconnect, message send, markRead, login; makes debugging production issues 10× faster

---

## 🟢 4. Needs Testing — done but unverified

- [ ] **Double tick cross-device** — send from iPhone, read on Android → verify double tick appears on iPhone
- [ ] **Logout stops push** — log in on Android, log out → verify no push received after logout
- [x] **Send failure UI** — verified: disable network → red bubble → re-enable → tap retry → sends

---

## 🔵 5. Polish — the last 10% that makes it feel right

- [ ] **App icon** — replace default Flutter icon with Zephyr brand icon
- [ ] **Splash screen** — branded launch screen
- [ ] **HomeScreen mega-widget refactor** — 5s feed poll `setState` rebuilds 1700-line widget; refactor to `ValueNotifier` + `ListenableBuilder`; not urgent pre-launch, Flutter's diffing absorbs it
- [ ] **Emoji / sticker picker** — basic emoji picker in thread
- [ ] **Dark mode** — respect system preference
- [ ] **Profile editing QA** — verify country, language, birthday save/display correctly end-to-end

---

## ⚪ 6. Post-Launch

- [ ] **TestFlight** — iOS release build, App Store Connect submission
- [ ] **Play Store** — signed AAB, store listing, screenshots
- [ ] **Web admin panel** — moderate users, manage rooms, analytics
- [ ] **Calls feature** — 1-on-1 audio/video call (scrapped, may revisit)

---

## ✅ Done

### Messaging
- [x] **Message pagination** — cursor-based (`before=ISO8601`); backend returns `hasMore`; scroll-to-top triggers fetch; spinner at top
- [x] **Send failure UI** — red bubble with `Icons.refresh` + "Failed · tap to retry"; tap restores text to input
- [x] **Idempotency key (client-side)** — `X-Idempotency-Key` header sent on every `sendMessage`
- [x] **Message read receipts** — single/double tick; real-time via socket + FCM silent push
- [x] **Thread date separators** — Today / Yesterday / date headers between messages
- [x] **Thread missing messages** — `getThread` returns latest 50 (DESC LIMIT subquery re-sorted ASC)
- [x] **Socket room stability** — `chat:join` on every `connect`; thread resyncs on reconnect

### Push Notifications
- [x] **Android FCM** — Firebase Admin SDK, `firebase_messaging` Flutter, device token in DB, push on send, coalesced per sender
- [x] **Tap notification → Inbox tab** — FCM payload opens inbox directly
- [x] **FCM token cleanup on logout** — `DELETE /v1/messages/device-token` on sign-out; no push after logout
- [x] **FCM foreground no double-count** — foreground FCM skips badge increment (socket already handles it)
- [x] **FCM silent push read receipts** — double-tick via FCM, more reliable than socket alone
- [x] **iOS Firebase init** — `firebase_options.dart` with explicit `FirebaseOptions`; Podfile iOS 15.0

### Inbox / Badge
- [x] **Unread badge** — socket increment + 60s resync + clears on open + resyncs on reconnect + app-resume refresh
- [x] **Badge accurate while in thread** — messages from other conversations bump the badge even when a thread is open
- [x] **Inbox re-fetches on socket connect** — catches messages missed while disconnected

### Performance
- [x] **Avatar image caching** — `CachedNetworkImageProvider` across all 9 screens; disk cache on first load
- [x] **Persistent HttpClient** — single `_httpClient` reused across all API calls; no per-request TCP/TLS handshake

### Observability
- [x] **Sentry Flutter** — `SentryFlutter.init()` in `main.dart`; catches all uncaught exceptions
- [x] **Sentry NestJS** — `@sentry/nestjs` in `main.ts`; backend errors captured

### Core Product
- [x] Auth — Google, Apple, Guest login (iOS + Android)
- [x] Home tab — live feed cards, user cards, name/country filter
- [x] Inbox tab — conversation list, unread badges, timestamps, cache-first, auto-poll (5s)
- [x] Thread (DM) page — chat bubbles, send, mark-read, auto-scroll
- [x] Explore tab — search by name or 8-digit public ID, gradient UI
- [x] Live streaming — host + viewer screens, LiveKit RTC, timer, camera-off overlay, viewer count + list
- [x] Avatar upload — Cloudinary, camera/gallery picker, persists across login, shown across all screens
- [x] Profile editing — nickname, gender, birthday, country, language (saves to DB)
- [x] Profile page — view profile, direct message button
- [x] Settings page — logout at Me → ⚙ Settings → Sign Out
- [x] Backend — messages API, search API, public_id backfill, correct message ordering
- [x] Android — Google Sign-In, Firebase, google-services.json
- [x] Google G logo — replaced broken CustomPainter with official SVG paths
- [x] Android adaptive icon — no white square on Android 8+
- [x] ProfilePage dark mode — bottom bar and modal sheet respect system theme
- [x] Mock data removed — mock feed cards, mock followingIds, debug logs all gone
- [x] Lint — all warnings resolved
