# Zephyr — Product Backlog

> **Messaging score vs Chamet: 78/100** — push notifications alone takes it to 90/100.
> **Hard blockers to ship**: Apple Developer account ($99/yr) + Google Play account ($25 once).

---

## 🔴 Critical / Blockers

### Push Notifications — the #1 gap vs Chamet
- [ ] **Android FCM (do first)** — Firebase Admin SDK on backend, `firebase_messaging` on Flutter, store `device_token` per user in DB, fire push on `sendMessage`
- [ ] **iOS APNs** — requires Apple Developer account first; upload APNs Auth Key (.p8) to Firebase console
- [ ] Backend: `device_tokens` table — `user_id`, `token`, `platform` (android/ios), `updated_at`
- [ ] Backend: send FCM push in `sendMessage` with `badge: unreadCount`, sender name, message preview
- [ ] Flutter: request permission on launch, get FCM token, send to backend on login/token refresh
- [ ] Flutter: tap-to-open — notification payload includes `senderId`, navigates directly to thread
- [ ] Flutter: `flutter_local_notifications` — show in-app banner when app is foreground (since OS suppresses push when open)
- [ ] iOS: Notification Service Extension — for rich notifications with sender avatar

### Store Accounts (hard blockers to ship)
- [ ] **Apple Developer account** — $99/year — unlocks App Store, TestFlight, APNs, real device testing
- [ ] **Google Play Developer account** — $25 once — unlocks Play Store

### Error Observability (blind in production without this)
- [ ] **Sentry Flutter** — `sentry_flutter` package; catches all uncaught exceptions, Flutter errors, ANRs; free tier sufficient for MVP. Init in `main.dart` before `runApp()`.
- [ ] **Sentry NestJS** — `@sentry/nestjs` on backend; catches unhandled exceptions, failed DB queries, 500 errors. Add to `app.module.ts`.
- [ ] **Sentry source maps** — upload Flutter/Dart symbols so stack traces are readable in production (not obfuscated)
- [ ] **Custom Sentry breadcrumbs** — log key events: socket connect/disconnect, message send, markRead, login — so we can replay what happened before a crash

### Message Robustness (no silent failures)
- [ ] **Idempotency key on sendMessage** — generate UUID client-side before HTTP call; include as `X-Idempotency-Key` header; backend rejects duplicate within 60s window — prevents double-send on network retry
- [ ] **Send failure UI** — if `sendMessage` HTTP call fails, show red `!` on the message bubble with a retry tap; currently fails silently
- [ ] **Optimistic send** — append message to thread immediately with a "pending" state before server confirms; flip to confirmed on success, red on failure (+4pts messaging score)

### Remove before production
- [ ] Mock feed cards (`[Mock] SarahBusy`, `[Mock] TaniaOnline`, `[Mock] MikeOffline`)
- [ ] Mock `_followingIds` hardcoded in `_loadData`
- [ ] Debug logs `[socket]`, `[chat-socket]` in `home_screen.dart`

---

## 🟡 High Priority

- [x] **Unread badge on Inbox tab** — real-time socket increment; initial count from API on launch; 99+ cap; clears on open; resyncs from `getConversations` on socket reconnect AND `AppLifecycleState.resumed`
- [x] **Thread missing messages** — `getThread` now returns latest 50 (DESC LIMIT subquery re-sorted ASC)
- [x] **Socket room stability** — explicit `chat:join` on every `connect`; `_socketConnectedOnce` flag; thread resyncs `_load()` on reconnect
- [ ] **Optimistic message send** — message appears instantly in thread before server confirms (currently waits for HTTP response) — +4pts messaging score
- [ ] **Follow / unfollow UI** — Follow button on ProfilePage, follower/following counts (backend done)
- [ ] **Onboarding flow** — first-launch screen: set nickname, pick country/language

---

## 🟠 Medium Priority

- [ ] **Typing indicator** — "..." bubble when other user is typing (+5pts messaging score vs Chamet)
- [ ] **Message pagination** — scroll up to load older messages beyond the 50-message window
- [ ] **Profile editing** — verify country, language, birthday save/display correctly end-to-end
- [ ] **Wallet / coins UI** — balance display, transaction history (backend fully done)
- [ ] **Gift sending from DM thread** — send coins as gift directly from thread (+2pts vs Chamet)
- [ ] **Block / report user** — safety feature, backend not built

---

## 🟢 Low Priority / Polish

- [ ] **App icon** — replace default Flutter icon with Zephyr brand icon
- [ ] **Splash screen** — branded launch screen
- [ ] **Emoji/sticker sending** — basic emoji picker in thread (+3pts vs Chamet)
- [ ] **Typing indicator** — "..." when other user is typing
- [ ] **Dark mode** — respect system preference

---

## ⚪ Later / Post-Launch

- [ ] **TestFlight** — iOS release build, App Store Connect submission
- [ ] **Play Store** — Android release build, signed APK/AAB, store listing
- [ ] **Calls feature** — 1-on-1 audio/video call (scrapped, may revisit)
- [ ] **Web admin panel** — moderate users, manage rooms, analytics

---

## ✅ Done

- [x] **Google G logo** — replaced broken CustomPainter (only painted 240°) with official SVG paths
- [x] **Mascot PNG background** — stripped solid dark background via flood-fill; image is now transparent
- [x] **Android adaptive icon** — added `adaptive_icon_background` + `adaptive_icon_foreground` to flutter_launcher_icons config; icon no longer shows white square on Android 8+
- [x] **ProfilePage dark mode** — bottom bar and modal sheet respect system dark/light theme
- [x] **Thread date separators** — messages now show "Today / Yesterday / Wed, 14 May / 14 May 2025" headers when the date changes between messages
- [x] **Inbox header cleanup** — removed refresh + logout buttons from non-home tab AppBar
- [x] **Settings page** — created `SettingsPage`; logout lives at Me → ⚙ Settings → Sign Out (one place, confirmation dialog)
- [x] **Message read receipts** — single tick (sent) / double tick white (seen) in chat bubbles; real-time via WebSocket chat:read event, fixed-width container prevents layout shift on state change; thread resyncs from API on socket reconnect to catch missed events

- [x] Auth — Google, Apple, Guest login (iOS + Android)
- [x] Home tab — live feed cards, user cards, name/country filter
- [x] Profile page — view profile, direct message button
- [x] Inbox tab — conversation list, unread badges, timestamps, cache-first, auto-poll (5s)
- [x] Thread (DM) page — chat bubbles, send, mark-read, auto-scroll, auto-poll (4s)
- [x] Explore tab — search by name or 8-digit public ID, gradient UI, user result cards
- [x] Backend — messages API, search API, public_id backfill, correct message ordering
- [x] Android — Google Sign-In, Firebase, google-services.json
- [x] Real-time inbox + thread polling (no need to re-enter screen)
- [x] Live streaming — host + viewer screens, LiveKit RTC, timer, camera-off overlay, viewer count + list
- [x] Avatar upload — Cloudinary, camera/gallery picker, persists across login, shown across all screens
- [x] Profile editing — nickname, gender, birthday, country, language (saves to DB)
- [x] Lint — all warnings resolved
