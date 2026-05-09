# zephyr-mobile

Flutter mobile app for Zephyr — a live streaming platform inspired by Olamet/Chamet.

## Features (current)

- **Auth** — Google Sign-In, Apple Sign-In, guest login
- **Discover tab** — live feed cards, PageView, enter room
- **Popular tab** — 2-col grid, tap to open profile
- **Follow tab** — filtered by following IDs, empty state
- **Profile page** — hero, avatar, status badge, live preview, follow/message/call footer pill
- **Call bottom sheet** — status-aware (live/busy/offline), shows rate in coins/min
- **Me tab** — level, balance, revenue, My Call Price, settings
- **My Call Price page** — 7-tier pricing table, level-gated, auto-save on tap
- **My Profile page** — edit avatar, nickname, gender, birthday, country (picker), language (picker)
  - Public ID: stable 8-digit code derived from DB UUID (safe to share)
- **Home search** — inline AppBar search by display name or 8-digit public ID
- **Country filter** — globe icon in AppBar opens country picker, filters all tabs; ✕ badge to clear
- **Economy** — Coins (user) → Sparks (host), 60/40 split
  - 4 coin packs: 16,500 / 55,000 / 165,000 / 550,000 coins
  - 7 call rate tiers: 2,100 → 27,000 coins/min (≤Lv3 → Lv9+)
- **Spark icon** — custom flame painter, reused app-wide
- **Coin icon** — gold gradient Z badge, reused app-wide

## Economy constants

| | |
|---|---|
| ~5,500 coins | = $1 USD |
| Host share | 60% (as Sparks) |
| Platform cut | 40% |

## Run locally

```zsh
# iOS simulator
flutter run --dart-define=API_BASE_URL=http://localhost:3000

# Physical device / production API
flutter run --dart-define=API_BASE_URL=https://zephyr-api-wr1s.onrender.com

# Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

## API endpoints consumed

- `POST /v1/auth/guest-login`
- `POST /v1/auth/google-login`
- `POST /v1/auth/apple-login`
- `GET /v1/users/me`
- `PATCH /v1/users/me`
- `GET /v1/feed/live`
- `GET /v1/users/me/following`
- `GET /v1/economy/wallet`
- `GET /v1/economy/coin-packs`
- `GET /v1/economy/private-call/quote`
- `POST /v1/economy/calls/start`
- `POST /v1/economy/calls/:id/tick`
- `POST /v1/economy/calls/:id/end`

## Validate

```zsh
flutter test
```

## Pending (pre-production)

- LiveKit RTC integration
- Real-time messaging (WebSocket DMs + live chat)
  - DMs: persist to DB, unread counts, inbox
  - Live chat: in-memory broadcast, no persistence
- Remove mock feed cards (SarahBusy, TaniaOnline, MikeOffline)
- Remove mock `_followingIds`
- Save My Profile edits to API
- Profile picture upload (camera/gallery)
- Android emulator auth fix
- Viewer count on cards
- Gift stickers in profile Gifts section
