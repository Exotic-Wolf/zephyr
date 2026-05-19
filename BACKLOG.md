# Zephyr — Product Backlog

> **Inbox messaging robustness: 80/100** — dual-path delivery (socket + FCM), reliable read receipts, badge accuracy fixed, failure UI with retry, Sentry on both sides. Gaps: no pagination (will break on long threads), no optimistic send, backend doesn't deduplicate on idempotency key yet, iOS APNs requires Apple Dev account.
> **Hard blockers to ship**: Apple Developer account ($99/yr) + Google Play account ($25 once).

---

## 🔴 Critical / Blockers

### Push Notifications
- [x] **Android FCM** — Firebase Admin SDK on backend, `firebase_messaging` Flutter, device token stored in DB, push fires on `sendMessage`, coalesced per sender
- [x] **Tap notification → Inbox tab** — notification payload opens inbox directly
- [x] **FCM token cleanup on logout** — `DELETE /v1/messages/device-token` on sign-out; no push after logout
- [x] **FCM foreground no double-count** — foreground FCM does not increment badge (socket already handles it)
- [x] **FCM silent push read receipts** — double-tick delivered via silent FCM push, more reliable than socket alone
- [ ] **iOS APNs** — requires Apple Developer account ($99); upload APNs Auth Key (.p8) to Firebase console

### Store Accounts (hard blockers to ship)
- [ ] **Apple Developer account** — $99/year — unlocks App Store, TestFlight, APNs, real device push
- [ ] **Google Play Developer account** — $25 once — unlocks Play Store

### Error Observability
- [x] **Sentry Flutter** — `SentryFlutter.init()` in `main.dart`; catches all uncaught exceptions
- [x] **Sentry NestJS** — `@sentry/nestjs` in `main.ts`; backend errors captured
- [ ] **Sentry source maps** — upload Flutter/Dart symbols so stack traces are readable (not obfuscated)
- [ ] **Custom Sentry breadcrumbs** — log socket connect/disconnect, message send, markRead, login

### Message Robustness
- [x] **Send failure UI** — red bubble with `Icons.refresh` + "Failed · tap to retry"; tap restores text to input
- [x] **Idempotency key (client-side)** — `X-Idempotency-Key` header sent on every `sendMessage`; backend not yet deduplicating
- [ ] **Backend idempotency dedup** — reject duplicate `X-Idempotency-Key` within 60s window in `MessagesService`
- [ ] **Message pagination** — scroll-up to load older messages; currently loads all at once — **will break on long threads**
- [ ] **Optimistic send** — show message immediately in thread before server confirms; reduces perceived latency

### Badge / Inbox Accuracy
- [x] **Unread badge** — socket increment + 60s resync + clears on open + resyncs on reconnect + app-resume refresh
- [x] **Badge accurate while in thread** — messages from other conversations bump the badge even when a thread is open
- [x] **Inbox re-fetches on socket connect** — catches messages missed while disconnected

### Needs testing
- [ ] **Double tick cross-device** — send from iPhone, read on Android → verify double tick appears on iPhone
- [ ] **Logout stops push** — log in on Android, log out → verify no push received after logout
- [x] **Send failure UI** — verified: disable network → red bubble → re-enable → tap retry → sends

### Remove before production
- [x] Mock feed cards (`[Mock] SarahBusy`, `[Mock] TaniaOnline`, `[Mock] MikeOffline`) — removed
- [x] Mock `_followingIds` override in `_loadData` — removed
- [x] Debug logs `[socket]` in `home_screen.dart` — removed

---

## 🟡 High Priority

- [x] **Thread missing messages** — `getThread` returns latest 50 (DESC LIMIT subquery re-sorted ASC)
- [x] **Socket room stability** — `chat:join` on every `connect`; thread resyncs on reconnect
- [x] **Thread date separators** — Today / Yesterday / date headers between messages
- [ ] **Optimistic message send** — message appears instantly before server confirms
- [ ] **Message pagination** — moved to 🔴 Critical
- [ ] **Follow / unfollow UI** — Follow button on ProfilePage, follower/following counts (backend done)
- [ ] **Onboarding flow** — first-launch screen: set nickname, pick country/language

---

## 🟠 Medium Priority

- [ ] **Typing indicator** — "..." bubble when other user is typing
- [ ] **Profile editing** — verify country, language, birthday save/display correctly end-to-end
- [ ] **Wallet / coins UI** — balance display, transaction history (backend fully done)
- [ ] **Gift sending from DM thread** — send coins as gift directly from thread
- [ ] **Block / report user** — safety feature, backend not built

---

## 🟢 Low Priority / Polish

- [ ] **App icon** — replace default Flutter icon with Zephyr brand icon
- [ ] **Splash screen** — branded launch screen
- [ ] **Emoji/sticker sending** — basic emoji picker in thread
- [ ] **Dark mode** — respect system preference

## ⚪ Later / Post-Launch

- [ ] **TestFlight** — iOS release build, App Store Connect submission
- [ ] **Play Store** — Android release build, signed APK/AAB, store listing
- [ ] **Calls feature** — 1-on-1 audio/video call (scrapped, may revisit)
- [ ] **Web admin panel** — moderate users, manage rooms, analytics

---

## ✅ Done

- [x] **Android FCM push** — Firebase Admin SDK + `firebase_messaging`; device token stored; push on `sendMessage`; coalesced per sender; foreground no double-count
- [x] **Tap notification → Inbox** — FCM tap payload opens inbox tab directly
- [x] **FCM token cleanup on logout** — `DELETE /v1/messages/device-token` on sign-out
- [x] **FCM silent push read receipts** — double-tick via FCM, more reliable than socket alone
- [x] **Inbox re-fetches on socket connect** — catches messages missed while disconnected
- [x] **Badge accurate while in thread** — messages from other convos bump badge even when thread open
- [x] **Mock data removed** — mock feed cards, mock followingIds, debug logs all gone
- [x] **Idempotency key (client-side)** — `X-Idempotency-Key` header sent on every sendMessage
- [x] **iOS Firebase init** — `firebase_options.dart` with explicit `FirebaseOptions`; Podfile iOS 15.0
- [x] **Google G logo** — replaced broken CustomPainter with official SVG paths
- [x] **Mascot PNG background** — stripped solid dark background via flood-fill; transparent
- [x] **Android adaptive icon** — `adaptive_icon_background` + `adaptive_icon_foreground`; no white square on Android 8+
- [x] **ProfilePage dark mode** — bottom bar and modal sheet respect system dark/light theme
- [x] **Thread date separators** — Today / Yesterday / date headers between messages
- [x] **Inbox header cleanup** — removed refresh + logout from non-home tab AppBar
- [x] **Settings page** — `SettingsPage`; logout at Me → ⚙ Settings → Sign Out
- [x] **Message read receipts** — single/double tick in chat bubbles; real-time via socket + FCM
- [x] **Badge 60s resync** — periodic timer prevents drift when socket is down
- [x] **Send failure UI** — red bubble with tap-to-retry; failed messages restored to input on tap
- [x] **Sentry Flutter** — `SentryFlutter.init()` in `main.dart`
- [x] **Sentry NestJS** — `@sentry/nestjs` in `main.ts`
- [x] **Unread badge** — socket increment + 60s resync + clears on open + reconnect resync + app-resume
- [x] **Thread missing messages** — `getThread` returns latest 50 (DESC LIMIT subquery re-sorted ASC)
- [x] **Socket room stability** — `chat:join` on every `connect`; thread resyncs on reconnect
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
