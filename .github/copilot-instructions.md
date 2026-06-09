# Zephyr — Current Engineering Direction

**Top-tier. Built to serve 100,000+ users from day one. Every decision optimizes for performance at scale — we foresee, not react. Steve Jobs' vision and perfectionism. Toyota's reliability. Zero defects. Direct rival to Chamet — we're taking the majority market share in live social.**

This file is the agent operating guide. `PRODUCT.md` is the living product/architecture source of truth. The app evolves quickly: always read the latest **Current Solution Snapshot**, **Immediate next work**, and latest dated audit before treating older guidance as current.

## Direction Protocol
- Latest dated `PRODUCT.md` snapshot/audit supersedes older sections and older comments.
- Hard constraints stay hard: no guest login, no new socket runtime, no client-owned economy, no presence polling, no unsafe moderation/compliance shortcuts.
- Product bets and module boundaries may evolve. When they do, update both `PRODUCT.md` and this file in the same work slice.
- If code and docs disagree, inspect the actual implementation/tests, then update the docs instead of copying stale assumptions forward.

## NEVER:
- Guest login — removed permanently. Google + Apple only.
- New Socket.IO/WebSocket runtime — product real-time is Firebase RTDB, Firestore listeners, FCM, or REST.
- Presence polling — listen, don't ask. The live-room heartbeat endpoint is room liveness only, not presence sync.
- New RTDB instances — `FirebaseChatService.instance` or the module facades behind it, nothing else.
- New product Markdown sprawl — product truth lives in `PRODUCT.md`; this file only carries agent rules. Add another Markdown file only when the user explicitly asks or a platform requires it.

## Real-time stack:
| Layer | Tool |
|-------|------|
| Presence / signaling / live events | Firebase RTDB via `FirebaseChatService.instance` and module facades (`PresenceRealtime`, `ProfilesRealtime`, `DirectCallSignals`, `LiveRoomRealtime`) |
| Chat/message real-time | Firestore listeners; Storage for chat images |
| Presence -> PG sync | Firebase Cloud Function trigger on `presence/{userId}` |
| Backend-trusted fan-out | Firebase Admin through backend `FcmService` for active-session projections, custom-token claims, call/match signals, push, and live gift display events |
| Media (video/audio) | Agora RTC |
| Persistent data / validation | PostgreSQL via REST (`ZephyrApiClient`) |
| Push notifications | FCM (`FcmService` on backend) |

## Identity sync architecture:
- **Single source of truth for user identity**: Firebase RTDB `profiles/{userId}` — displayName, avatarUrl, countryCode, language, birthday
- Owner writes on profile save. All clients listen via LRU-cached subscriptions (50 max). UI rebuilds via `profileVersion` ValueNotifier.
- **NEVER** denormalize names into N documents. One node, N listeners.

## Presence sync architecture:
- **Single source of truth**: Firebase RTDB `presence/{userId}` canonical availability cell.
- **Canonical fields**: `schemaVersion`, `connection`, `activity`, `availability`, `routing.directCall`, `routing.randomCall`, `displayStatus`, `interruptible`, room/call context IDs, `updatedAt`, plus legacy `state` only for compatibility.
- **PG sync**: Cloud Function mirrors RTDB into `users.status`, `presence_connection`, `presence_activity`, `presence_availability`, `can_direct_call`, `can_random_call`, and `presence_updated_at`.
- **Matchmaking and direct-call gates**: query `presence_availability='available'` plus `can_random_call=true` or `can_direct_call=true`; never infer routeability from UI badge text.
- **Client shows** presence via RTDB listeners and `displayStatus` (no PG involvement for badges).
- **NEVER** use client-side HTTP heartbeats to sync presence to PG. Live-room heartbeat is only host room liveness.
- **NEVER** duplicate presence state across systems with periodic timers.

## Firebase RTDB paths:
- `session_controls/{userId}` — backend/Admin-owned active mobile session projection. Clients never read or write it directly; RTDB/Firestore/Storage rules allow pre-projection sessions for migration safety, then use it to reject stale Firebase custom tokens once present.
- `presence/{userId}` — canonical availability cell owned by `PresenceRealtime`; users write only their own node.
- `profiles/{userId}` — displayName, avatarUrl, countryCode, language, birthday (single source of truth for user identity).
- `direct_calls/{userId}` — direct/random call signaling owned by `DirectCallSignals`; participant ownership and immutable session metadata are rules-checked.
- `live_rooms/{roomId}/status` — host-owned status only.
- `live_rooms/{roomId}/audience/{userId}` — per-viewer audience cells; shared `audience_count` is not client-writable.
- `live_rooms/{roomId}/comments` and `/reactions` — client-visible events constrained by sender identity and timestamp shape.
- `live_rooms/{roomId}/gifts` — backend/Admin trusted display fan-out after Postgres ledger success; clients cannot forge gift events.

## Presence fields:
| Field | Current values / meaning |
|-------|--------------------------|
| `connection` | `online`, `offline` — RTDB reachability/onDisconnect truth |
| `activity` | `idle`, `away`, `free_live_host`, `free_live_viewer`, `premium_live_host`, `premium_live_viewer`, `live_paused`, `direct_call`, `random_call` |
| `availability` | `available`, `busy`, `unavailable` — backend routeability guard |
| `routing.directCall` / `routing.randomCall` | Explicit route flags for paid direct/random matching |
| `displayStatus` | `online`, `away`, `live`, `premium_live`, `busy`, `offline` — UI badge only |
| `interruptible` | Free live can be interruptible; premium live and calls are not |

## Before writing code:
1. Real-time intent? -> `FirebaseChatService.instance` or one of its modules (`PresenceRealtime`, `ProfilesRealtime`, `DirectCallSignals`, `LiveRoomRealtime`).
2. Chat messages? -> Firestore through the existing chat service; images go through Storage rules.
3. Media? -> Agora RTC.
4. Validation / economy / DB write? -> REST endpoint and Postgres.
5. Auth/realtime access? -> backend mints session-bound Firebase custom tokens; never client-write `session_controls`.
6. Never create a new Firebase or RTDB instance anywhere.
7. Never add socket.io, web_socket_channel, or any socket library.
8. Never poll for presence/realtime state; use listeners. Room heartbeat is the liveness exception for live hosts.

## Economy:
- Gifts: 60% receiver, 40% platform. ~5500 coins/USD.
- Backend validates ALL transactions. Wallet, call tick, call gift, live gift, IAP credit, and refund paths must stay Postgres-transactional and idempotent.
- Live gift display events are backend/Admin RTDB fan-out after ledger success. Clients never write trusted gift events.
- Direct/random call gift ledger exists in backend; mobile shared gift UI expansion is still planned outside live rooms.

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
