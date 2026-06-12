# Zephyr Architecture

This file owns durable architecture truth: source-of-truth boundaries, module ownership, realtime boundaries, and hard constraints. Exact RTDB paths and fields live in [rtdb-contract.md](./rtdb-contract.md). Current launch state lives in [current-state.md](./current-state.md), source-checked paths/routes/tables live in [code-reference.md](./code-reference.md), and operational commands live in [operations.md](./operations.md).

## Update Standard

- Keep architecture current, not historical.
- Update this file when a source of truth, module owner, trust boundary, realtime contract, schema authority, or hard constraint changes.
- Do not duplicate route maps, table lists, exact RTDB path/field contracts, release records, quality grades, or UX checklists here.
- Every shared behavior must have one owner, one public contract, one source of truth, and one verification path.
- If a fix needs raw writes or repeated conditionals across screens, stop and identify the missing module boundary before editing.
- Architecture changes require matching tests or smoke gates in the owning layer before the change can be called proven.

## Architecture Control Principles

| Principle | Zephyr rule |
|---|---|
| Single source of truth | Each domain has one canonical writer and one canonical read model. Projections are disposable. |
| Intent over protocol | Screens call module methods such as `setBusy`, `joinAudience`, or `writeRinging`; screens do not hand-write protocol payloads. |
| Backend owns trust | Money, sessions, gifts, IAP, refunds, moderation, and trusted fan-out are backend/Postgres/Admin-owned. |
| Realtime owns liveness | RTDB owns presence, call signals, live-room liveness, and visible realtime events; Firestore owns message state. |
| RTDB is never best-effort | Every RTDB path, field, listener, write contract, and permission change needs an owning module plus targeted rules/tests before reuse. |
| Rules are contracts | Firebase rules and emulator tests must change with any client data-shape or permission change. |
| Small reversible changes | Extract or move ownership only when a focused task proves the boundary and preserves existing behavior. |

## Code Architecture Baseline (11 Jun 2026)

| Area | Current owner | Current boundary note |
|---|---|---|
| Mobile app | `apps/zephyr-mobile` | Feature folders are clear, and realtime service facades exist. Some screens still own too much lifecycle/state and should be pushed toward module contracts over time. |
| Mobile realtime facade | `FirebaseChatService.instance` with `PresenceRealtime`, `ProfilesRealtime`, `DirectCallSignals`, `LiveRoomRealtime` | This is the strongest module boundary in the app. Keep all RTDB access behind these facades. |
| Backend API | `services/zephyr-api/src/*` Nest modules | Module routing is clean at controller/module level. `StoreService` is a large domain service and should be split carefully only when a focused change proves a boundary. |
| Money/economy | Backend `StoreService`, `IapService`, PostgreSQL transactions | Correctly backend-owned. The reusable gift send contract validates catalog surface eligibility, writes wallet/revenue changes, and creates durable `gift_events` receipts inside the wallet transaction. Any gift/IAP/call-billing change must keep idempotency and DB race tests in scope. |
| Firebase Functions | `functions/src/index.ts` | Owns RTDB trigger glue: presence projection, stale presence reaping, and signal deletion cleanup. Keep product logic in backend where possible. |
| Firebase rules | `database.rules.json`, `firestore.rules`, `storage.rules` | Rules are first-class contracts and have emulator suites. Storage rules read Firestore `session_controls`, so production also requires the Firebase Storage service agent to hold `roles/firebaserules.firestoreServiceAgent`. Any client data-shape change must update rules and tests together. |
| Contracts | `packages/zephyr-contracts/openapi.yaml` | Partial public API contract for core auth/profile/room/feed flows. Nest controllers and `docs/product/code-reference.md` are the current full route map until OpenAPI is expanded. |

## Architecture

| Layer | Stack | Location |
|---|---|---|
| Mobile | Flutter (Dart) | `apps/zephyr-mobile` |
| Backend API | NestJS (TypeScript) | `services/zephyr-api` |
| Database | PostgreSQL (Render) | Singapore region |
| Messaging | Firebase Firestore + Storage + backend-verified FCM | `firebase_chat_service.dart`, Firestore rules, backend `/v1/messages/push` |
| Status & Presence | Firebase RTDB (asia-southeast1) | Canonical realtime availability cell: connection, activity, routing, display status, call/live context |
| User Identity | Firebase RTDB `profiles/{userId}` | displayName, avatarUrl, countryCode, language, birthday — **source of truth for identity**. LRU-cached listeners, reactive via `profileVersion` ValueNotifier |
| Live Rooms | Firebase RTDB + Postgres projection | RTDB owns host status, per-viewer audience cells, comments, reactions, and backend-trusted gift display events via `live_rooms/{roomId}/`. Postgres `rooms.audience_count` remains the backend/feed projection updated by join/leave REST calls. Client/host-owned room status is transitional and must not be used for money or security decisions. |
| Video | Agora (calls + live streaming) | SDK in mobile |
| Deploy | Render (auto-deploy from `main`) | `https://zephyr-api-wr1s.onrender.com` |

---

## Architecture Direction (Current Baseline)

These are current architectural defaults, not eternal constraints. They stay in force until a later architecture update or implementation pass deliberately replaces them and updates this section.

- **Firebase Chat** — Firestore for messages/conversations, RTDB for real-time presence (onDisconnect), Storage for image uploads. Backend generates custom Firebase tokens.
- **Firebase RTDB is the single source of truth for real-time availability** — `presence/{userId}` is not a single overloaded status string. It is the canonical availability cell for connection, activity, routing eligibility, display status, and call/live context. RTDB's `onDisconnect` guarantees cleanup even on app kill/crash. All clients listen to RTDB for user availability before initiating calls, routing random calls, or showing status badges.
- **Firebase Cloud Functions (asia-southeast1)** — 3 deployed functions provide server-side safety nets:
  - `onCallSignalDeleted`: RTDB trigger on `direct_calls/{userId}` deletion → ends Postgres call session via internal API
  - `onPresenceChanged`: RTDB trigger on `presence/{userId}` update → syncs the canonical display/availability/routing projection to Postgres, and ends the room when `displayStatus` leaves `live`
  - `reapStalePresence`: Scheduled every 5 min → scans all presence nodes, resets stale entries (>5min) to the canonical offline payload, ends orphaned live rooms
  - Internal endpoints: `POST /v1/internal/end-call-session`, `POST /v1/internal/end-room` (validated via `X-Service-Key` header)
- **Agora RTC** — replaces LiveKit for ALL video (calls + live streaming). Proprietary UDP bypasses Gulf WebRTC filtering. Single SDK, smaller APK.
- **Zero app-owned Socket.IO runtime** — All real-time product flows use Firebase RTDB, Firestore listeners, FCM, or REST. Live room comments/reactions/audience state use RTDB; trusted room status and gift events must be backend-confirmed before fan-out. Random call matchmaking uses REST + RTDB signals. There are no direct Socket.IO/WebSocket dependencies or app-owned socket paths; lockfile cleanup may still show transitive Nest websocket artifacts.
- **FCM/APNs** — push notifications for chat messages (backend relays via `POST /v1/messages/push`)
- **Firebase is truth** — Firestore is source of truth for messages/conversations. RTDB is source of truth for realtime availability, call/live signaling, visible live events, and user identity (`profiles/{userId}` — displayName, avatarUrl, countryCode, language, birthday). Backend validates economy and issues tokens.

---

## Canonical Ownership Matrix

| Domain | Canonical owner | Writers | Readers / projections | Verification |
|---|---|---|---|---|
| OAuth login | Backend Auth module | `AuthController` / `StoreService` | Mobile secure storage, backend sessions | Backend unit/e2e, Flutter login smoke |
| API session | Postgres `sessions`, `users.active_session_id` | Backend only | API guards, Firebase custom token claims | Backend unit/e2e, Firebase rules tests, two-device smoke |
| Firebase session control | Firestore/RTDB `session_controls/{userId}` | Backend/Admin only | Firebase rules, mobile listeners | Rules tests plus auth/session smoke |
| Display identity | RTDB `profiles/{userId}` | Current user through `ProfilesRealtime` | Mobile LRU profile cache, backend fallback profile fields | RTDB rules tests, profile smoke |
| Realtime availability | RTDB `presence/{userId}` | Current user through `PresenceRealtime`, Functions reaper for stale offline | Postgres presence projection, UI badges, routing guards | RTDB rules tests, backend projection tests/smoke |
| Message state | Firestore chats/conversations | Chat participants through `FirebaseChatService` | Inbox/thread UI, backend push verifier | Firestore rules tests, Flutter tests/smoke |
| Chat media | Firebase Storage | Uploader through `FirebaseChatService` prepared upload path | Firestore message metadata, thread UI | Storage rules tests, media smoke |
| Push delivery | Backend FCM service | Backend only | FCM/APNs, mobile notification handling | Backend tests, no-push-after-logout smoke |
| Direct-call signal | RTDB `direct_calls/{userId}` | Caller/receiver through `DirectCallSignals`; backend/Admin for trusted random-match events | Incoming overlay, call screens, Functions cleanup | RTDB rules tests, two-account smoke |
| Random matchmaking | Backend REST + Postgres projection | Backend `MatchmakingController` / `StoreService` | RTDB matched signal, call screen | Backend tests, two-account random smoke |
| Live-room realtime | RTDB `live_rooms/{roomId}` | `LiveRoomRealtime`; backend/Admin for trusted gift events | Host/viewer live screens | RTDB rules tests, live smoke |
| Video transport | Agora RTC | Backend token issuer, mobile SDK | Call/live screens | Backend token tests, device smoke |
| Wallet/economy ledger | Postgres | Backend `StoreService` / `IapService` only | Mobile wallet/revenue views | Backend unit/e2e, DB race/idempotency tests |
| Gifts | Backend ledger + reusable gift module | Backend owns the server catalog, price, surface eligibility, receiver/context validation, wallet/revenue transaction, and Postgres `gift_events`; Admin fans out trusted visible events that reference `giftEventId` into RTDB live gifts and Firestore inbox gift cards | Live/call/inbox/premium gift surfaces; mobile gift module reads catalog/send results, renders cards, and plays animations only after committed receipts | Backend tests, DB race/idempotency tests, mobile model/widget tests, Firestore/RTDB rules tests for visible projections, surface smoke |
| IAP/refunds | Store APIs + Postgres `iap_purchases` | Backend `IapService` and webhooks | Wallet/revenue views | Backend tests, store purchase/refund smoke |
| Moderation reports/blocks | Postgres + Firestore block projection | Backend only for durable state | UI block/report surfaces, Firestore rules | Backend tests, rules tests, smoke |

---

## Realtime Contract Boundary

Exact RTDB paths, fields, allowed writers, readers, security rules, presence transitions, projection fields, and addition gates live in [rtdb-contract.md](./rtdb-contract.md).

Architecture owns the boundary:

- RTDB owns realtime availability, display identity, direct-call signals, live-room liveness, audience cells, comments, reactions, and backend-trusted visible gift fan-out.
- Firestore owns chat messages/conversations.
- Postgres/backend owns sessions, money, wallet, gift ledger, IAP, refunds, moderation, and paid call/live billing.
- Agora owns audio/video transport only.
- Screens must express intent through module facades; they must not hand-write RTDB protocol payloads.

---

## Architecture Change Gate

Before changing architecture ownership, answer these in the task or PR notes:

1. What behavior is moving, and from which owner to which owner?
2. What is the new public contract?
3. What source of truth writes the durable state?
4. What projections or caches become derived and disposable?
5. What tests/rules/smoke prove the new boundary?
6. Which docs need updates: architecture, code reference, product model, operations, current state, or quality dashboard?

Stop the change if the new owner cannot be named, if two modules would write the same durable state, or if money/security trust would move to the client.
