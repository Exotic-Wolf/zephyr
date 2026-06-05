# Zephyr — Hard Rules

**Top-tier. Built to serve 100,000+ users from day one. Every decision optimizes for performance at scale — we foresee, not react. Steve Jobs' vision and perfectionism. Toyota's reliability. Zero defects. Direct rival to Chamet — we're taking the majority market share in live social.**

## NEVER:
- Guest login — removed permanently. Google + Apple only.
- Socket.IO — dead. Firebase RTDB only.
- Polling — listen, don't ask.
- New RTDB instances — `FirebaseChatService.instance` or nothing.
- New markdown files — `PRODUCT.md` is the single documentation file. No READMEs, no separate docs. Everything lives there.

## Real-time stack:
| Layer | Tool |
|-------|------|
| Presence / signaling / live events | Firebase RTDB via `FirebaseChatService` |
| Presence → PG sync | Firebase Cloud Function (trigger on `presence/{userId}`) |
| Media (video/audio) | Agora RTC |
| Persistent data / validation | PostgreSQL via REST (`ZephyrApiClient`) |
| Push notifications | FCM (`FcmService` on backend) |

## Identity sync architecture:
- **Single source of truth for user identity**: Firebase RTDB `profiles/{userId}` — displayName, avatarUrl, countryCode, language, birthday
- Owner writes on profile save. All clients listen via LRU-cached subscriptions (50 max). UI rebuilds via `profileVersion` ValueNotifier.
- **NEVER** denormalize names into N documents. One node, N listeners.

## Presence sync architecture:
- **Single source of truth**: Firebase RTDB `presence/{userId}`
- **PG sync**: Cloud Function triggers on RTDB presence change → writes `status` + `last_seen_at` to PostgreSQL
- **Matchmaking** queries PG: `WHERE status IN ('online', 'away')`
- **Client shows** presence via RTDB listeners (no PG involvement)
- **NEVER** use client-side HTTP heartbeats to sync presence to PG — that's polling in disguise
- **NEVER** duplicate presence state across systems with periodic timers

## Firebase RTDB paths:
- `presence/{userId}` — state (online/inactive/offline/busy/live), lastSeen, roomId
- `profiles/{userId}` — displayName, avatarUrl, countryCode, language, birthday (single source of truth for user identity)
- `direct_calls/{userId}` — call signaling
- `live_rooms/{roomId}/` — comments, reactions, gifts, audience_count, status

## Presence states:
| State | Color | Meaning |
|-------|-------|---------|
| `online` | Green | App in foreground, user active (touched in last 60s) |
| `away` | Yellow | App in foreground, user idle 60s+ (no touches) |
| `busy` | Orange | In an active call |
| `live` | Red | Hosting a stream |
| `offline` | Gray (hidden) | Backgrounded / screen locked / killed / logged out |

## Before writing code:
1. Real-time? → `FirebaseChatService.instance` (RTDB)
2. Media? → Agora RTC
3. Validation / economy / DB write? → REST endpoint
4. Never create a new Firebase or RTDB instance anywhere
5. Never add socket.io, web_socket_channel, or any socket library
6. Never poll — listen

## Economy:
- Gifts: 60% receiver, 40% platform. ~5500 coins/USD.
- Backend validates ALL transactions. Client writes RTDB event AFTER successful API response.

## Dev philosophy:
- Simple, precise, top-tier. No over-complication.
- Build the minimum that does the job perfectly.
- Don't add abstractions unless clearly needed.
- Find the real root cause — don't layer fixes on symptoms.
- Everything is an encapsulated, reusable module. Bulletproof and self-contained.
- Features are composed of modules. e.g the live feature is built from many smaller robust modules.
- Core features — Messaging, Call, Live — must be flawless and performant. Zero compromises.
- Every module is top-tier — works alone, composes cleanly, fails gracefully.
- Modules are Lego. If one isn't good, throw it out and snap in a replacement. No module death-grips another.
- **Jidoka** — Stop the moment something breaks. Fix it now, never pass a defect forward.
- **Genchi Genbutsu** — Go to the source. Read the actual code, check the actual logs, reproduce it yourself.
- **Kaizen** — Every commit leaves the codebase better than you found it.
- **Muda** — Eliminate waste. Dead code, unused abstractions, unnecessary complexity — cut it all.
- **Mura** — Eliminate inconsistency. Same patterns, same conventions, everywhere.
- **Muri** — Don't overburden. If a class does too much, it will break.
- **Poka-yoke** — Mistake-proof the design. Types, null safety, API contracts that can't be misused.
- **Andon** — Make problems visible. Errors surface loud and clear, never swallowed silently.
- **Hansei** — Reflect after every failure. Not just fix — understand what the system should have prevented.
- **Heijunka** — Level the load. Don't let complexity pile up in one place.
- **Just-in-Time** — Build only what you need now. Not what you might need later.
- **Nemawashi** — Think thoroughly, then act fast. Design before code, then ship.
- **5 Whys** — When it breaks, ask "why" five times until you hit the true root cause.

## Audit log:
When auditing a feature, always grade each aspect (A+ to F) and record results in `PRODUCT.md § Audit Log`.
