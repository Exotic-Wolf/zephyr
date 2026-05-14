# Zephyr — Product Backlog

## 🔴 Critical / Next Up

### Go Live Feature
- [ ] **Create Room flow** — "Go Live" button on Home tab, prompts for room title
- [ ] **Live room screen** — host view with mic/camera controls, audience count, end stream button
- [ ] **Viewer screen** — join a live room, see host, send reactions/gifts
- [ ] **Real audio/video** — integrate Agora or LiveKit SDK for actual streaming
- [ ] **Room discovery** — live rooms appear on Home feed in real time (currently mock data)

### Push Notifications
- [ ] Store FCM device token per user in DB (new `device_tokens` table)
- [ ] Backend: fire FCM push when message is sent (Firebase Admin SDK)
- [ ] Flutter: `firebase_messaging` — request permission, get token, handle tap-to-open
- [ ] Flutter: `flutter_local_notifications` — show notification with sender avatar + message preview
- [ ] iOS: APNs key uploaded to Firebase console
- [ ] iOS: Notification Service Extension for rich notifications (avatar image)

---

## 🟡 High Priority

- [ ] **Unread badge on Inbox tab** — red dot on nav icon when unread messages exist
- [ ] **Follow / unfollow UI** — Follow button on ProfilePage, follower/following counts (backend done)
- [ ] **Onboarding flow** — first-launch screen for new users: set nickname, pick country/language

---

## 🟠 Medium Priority

- [ ] **Profile editing** — verify country, language, birthday save and display correctly end-to-end
- [ ] **Wallet / coins UI** — balance display, transaction history screen (backend fully done)
- [ ] **Gift sending in live rooms** — send coins as gifts to hosts during a stream
- [ ] **Block / report user** — safety feature, backend not yet built

---

## 🟢 Low Priority / Polish

- [ ] **App icon** — replace default Flutter icon with Zephyr brand icon
- [ ] **Splash screen** — branded launch screen
- [ ] **Dark mode** — respect system dark mode preference
- [ ] **Message read receipts UI** — show tick/double-tick in thread bubbles
- [ ] **Typing indicator** — "..." when other user is typing

---

## ⚪ Later / Post-Launch

- [ ] **TestFlight** — iOS release build, App Store Connect submission
- [ ] **Play Store** — Android release build, signed APK/AAB, store listing
- [ ] **Calls feature** — 1-on-1 audio/video call (was scrapped, may revisit)
- [ ] **Web admin panel** — moderate users, manage rooms, view analytics

---

## ✅ Done

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
