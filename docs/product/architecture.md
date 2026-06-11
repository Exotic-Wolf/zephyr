# Zephyr Architecture

This file owns durable architecture truth: source-of-truth boundaries, module ownership, realtime contracts, and hard constraints. It is not a launch-status report or file catalog. Current launch state lives in [current-state.md](./current-state.md), source-checked paths/routes/tables live in [code-reference.md](./code-reference.md), and operational commands live in [operations.md](./operations.md).

## Update Standard

- Keep architecture current, not historical.
- Update this file when a source of truth, module owner, trust boundary, realtime contract, schema authority, or hard constraint changes.
- Do not duplicate route maps, table lists, release records, quality grades, or UX checklists here.
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
| Rules are contracts | Firebase rules and emulator tests must change with any client data-shape or permission change. |
| Small reversible changes | Extract or move ownership only when a focused task proves the boundary and preserves existing behavior. |

## Code Architecture Baseline (11 Jun 2026)

| Area | Current owner | Current boundary note |
|---|---|---|
| Mobile app | `apps/zephyr-mobile` | Feature folders are clear, and realtime service facades exist. Some screens still own too much lifecycle/state and should be pushed toward module contracts over time. |
| Mobile realtime facade | `FirebaseChatService.instance` with `PresenceRealtime`, `ProfilesRealtime`, `DirectCallSignals`, `LiveRoomRealtime` | This is the strongest module boundary in the app. Keep all RTDB access behind these facades. |
| Backend API | `services/zephyr-api/src/*` Nest modules | Module routing is clean at controller/module level. `StoreService` is a large domain service and should be split carefully only when a focused change proves a boundary. |
| Money/economy | Backend `StoreService`, `IapService`, PostgreSQL transactions | Correctly backend-owned. Any gift/IAP/call-billing change must keep idempotency and DB race tests in scope. |
| Firebase Functions | `functions/src/index.ts` | Owns RTDB trigger glue: presence projection, stale presence reaping, and signal deletion cleanup. Keep product logic in backend where possible. |
| Firebase rules | `database.rules.json`, `firestore.rules`, `storage.rules` | Rules are first-class contracts and have emulator suites. Any client data-shape change must update rules and tests together. |
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
| Gifts | Backend ledger + reusable gift module | Backend confirms spend; Admin fans out trusted visible events | Live/call/inbox/premium gift surfaces | Backend tests, rules tests, surface smoke |
| IAP/refunds | Store APIs + Postgres `iap_purchases` | Backend `IapService` and webhooks | Wallet/revenue views | Backend tests, store purchase/refund smoke |
| Moderation reports/blocks | Postgres + Firestore block projection | Backend only for durable state | UI block/report surfaces, Firestore rules | Backend tests, rules tests, smoke |

---

## Canonical Realtime Availability Model

This section is the current contract for the realtime cell. The goal is not just "show a badge"; the goal is to make inbox, direct call, random call, live, Agora, and backend matchmaking read the same authoritative availability truth.

### Source-of-truth boundaries

| Domain | Canonical owner | Notes |
|---|---|---|
| Inbox/messages | Firestore | Message bodies, conversation metadata, read/delivered state |
| Display identity | RTDB `profiles/{userId}` | displayName, avatarUrl, countryCode, language, birthday |
| Realtime availability | RTDB `presence/{userId}` | Connection, current activity, routing eligibility, display status |
| Live audience presence | RTDB `live_rooms/{roomId}/audience/{userId}` | Per-viewer visible room presence. Backend/feed counts still use Postgres `rooms.audience_count` as a projection. |
| Media session | Agora | Audio/video transport only; Agora events may trigger presence intents, but Agora does not own availability |
| Money/session ledger | Postgres | Wallets, call sessions, gifts, IAP, revenue, reports |
| Gifts | Backend + reusable gift module | Same gift catalog/animation/economy pipeline reused in inbox, live, premium live, direct call, and random call |

### Presence cell shape

`presence/{userId}` is a canonical state cell. It should be written only through the realtime availability module, never by feature screens with raw status strings.

```json
{
  "schemaVersion": 1,
  "connection": "online",
  "activity": "idle",
  "availability": "available",
  "routing": {
    "directCall": true,
    "randomCall": true
  },
  "displayStatus": "online",
  "interruptible": true,
  "roomId": null,
  "roomMode": null,
  "callSessionId": null,
  "premiumRoomSessionId": null,
  "previousActivity": null,
  "previousRoomId": null,
  "state": "online",
  "updatedAt": 1234567890
}
```

Allowed values:

| Field | Values | Meaning |
|---|---|---|
| `connection` | `online`, `offline` | RTDB reachability. Owned by connect/onDisconnect/reaper logic. |
| `activity` | `idle`, `away`, `free_live_host`, `free_live_viewer`, `premium_live_host`, `premium_live_viewer`, `live_paused`, `direct_call`, `random_call` | What the user is doing. Owned by facade/module methods such as `setLiveStatus`, `setPremiumLiveHostStatus`, `setPremiumLiveViewerStatus`, `setBusyStatus`, and `clearBusyStatus`. |
| `availability` | `available`, `busy`, `unavailable` | Coarse product availability. Matchmaking must never infer this from display text. |
| `routing.directCall` | boolean | Whether explicit paid direct call may route to this user. |
| `routing.randomCall` | boolean | Whether automatic random matchmaking may select this user. |
| `displayStatus` | `online`, `away`, `live`, `premium_live`, `busy`, `offline` | UI badge only. It is derived from canonical state, not used as algorithm truth. |
| `interruptible` | boolean | Whether a higher-value flow may pause the current activity. Free live can be interruptible; premium live and calls are not. |
| `roomId` | string/null | Present only for active or paused live/premium live context. |
| `roomMode` | `free_live`, `premium_live`, null | Current room monetization mode. |
| `callSessionId` | string/null | Present only during direct/random call. |
| `premiumRoomSessionId` | string/null | Present only during metered premium live participation. |
| `previousActivity`, `previousRoomId` | string/null | Used for live -> random/direct transitions and safe resume/end decisions. |
| `state` | same as `displayStatus` | Temporary legacy compatibility field. New code must read/write canonical fields first. |
| `updatedAt` | server timestamp | Last canonical state write. |

### Backend projection

Postgres stores only a queryable projection of RTDB presence. RTDB remains source of truth.

| Postgres field | Source | Purpose |
|---|---|---|
| `users.status` | `displayStatus` | Legacy/UI display fallback |
| `users.presence_connection` | `connection` | Offline/freshness projection |
| `users.presence_activity` | `activity` | Current canonical activity |
| `users.presence_availability` | `availability` | Backend availability guard |
| `users.can_direct_call` | `routing.directCall` | Direct-call API routeability |
| `users.can_random_call` | `routing.randomCall` | Random-call matchmaking routeability |
| `users.presence_updated_at` | `updatedAt` | Last canonical RTDB write mirrored to Postgres |

Backend matching and call creation must use `presence_availability`, `can_direct_call`, and `can_random_call`; they must not infer routeability from `users.status` or UI badge text.

### Canonical transitions

| Intent | Resulting state |
|---|---|
| App foreground and idle | `connection=online`, `activity=idle`, `availability=available`, `routing.directCall=true`, `routing.randomCall=true`, `displayStatus=online` |
| App idle/away | `connection=online`, `activity=away`, `availability=available`, `routing.directCall=true`, `routing.randomCall=false`, `displayStatus=away` |
| Start free live as host | `connection=online`, `activity=free_live_host`, `availability=available`, `routing.directCall=true`, `routing.randomCall=true`, `interruptible=true`, `displayStatus=live`, `roomId=<roomId>`, `roomMode=free_live` |
| Join free live as viewer | `connection=online`, `activity=free_live_viewer`, `availability=available`, `routing.directCall=true`, `routing.randomCall=true`, `interruptible=true`, `displayStatus=online`, `roomId=<roomId>`, `roomMode=free_live` |
| Upgrade free live to premium live | Host presses the premium action; backend creates premium room pricing/session; current viewers see a locked screen with entry gift/payment CTA |
| Enter premium live as host | `connection=online`, `activity=premium_live_host`, `availability=busy`, `routing.directCall=false`, `routing.randomCall=false`, `interruptible=false`, `displayStatus=premium_live`, `roomId=<roomId>`, `roomMode=premium_live` |
| Enter premium live as viewer | `connection=online`, `activity=premium_live_viewer`, `availability=busy`, `routing.directCall=false`, `routing.randomCall=false`, `interruptible=false`, `displayStatus=busy`, `roomId=<roomId>`, `roomMode=premium_live`, `premiumRoomSessionId=<sessionId>` |
| Enter direct call | `connection=online`, `activity=direct_call`, `availability=busy`, `routing.directCall=false`, `routing.randomCall=false`, `interruptible=false`, `displayStatus=busy`, `callSessionId=<sessionId>` |
| Enter random call | `connection=online`, `activity=random_call`, `availability=busy`, `routing.directCall=false`, `routing.randomCall=false`, `interruptible=false`, `displayStatus=busy`, `callSessionId=<sessionId>` |
| Free live host pulled into random/direct call | Store `previousActivity=free_live_host` and `previousRoomId=<roomId>`, pause the free live room, then enter call state |
| Premium live host receives call/random route | No transition. Premium live is non-interruptible; routing must skip the host. |
| Call ends after live was paused | `connection=online`, `activity=live_paused`, `availability=unavailable`, `routing.directCall=false`, `routing.randomCall=false`, `displayStatus=busy`, `roomId=<previousRoomId>` until host explicitly resumes or ends live |
| Resume paused free live | Return to the Start free live state |
| End live | Clear `roomId`, return to idle/away based on foreground activity |
| App disconnect/crash | `connection=offline`, `activity=idle`, `availability=unavailable`, `routing.directCall=false`, `routing.randomCall=false`, `displayStatus=offline`; cleanup functions end affected call/live sessions |

### Module ownership

Feature screens should express intent, not RTDB protocol details.

Implemented modules/classes:

| Module | Owns |
|---|---|
| `PresenceRealtime` | `presence/{userId}` fields, transitions, onDisconnect, local cache, status badge derivation |
| `ProfilesRealtime` | `profiles/{userId}` reads/writes and profile cache |
| `DirectCallSignals` | Direct-call signaling schema, accept/decline/cancel/timeout cleanup |
| `LiveRoomRealtime` | Free live audience/comment/reaction/status cells and trusted gift listeners. Backend/Admin owns trusted gift fan-out. Host-owned room status is transitional and must not carry money/security trust. |

Target modules/classes not yet separated:

| Target | Intended owner |
|---|---|
| `RandomCallSignals` | Random match signaling schema, partner-left/next/end events currently routed through `DirectCallSignals` and call screens |
| `PremiumLiveRealtime` | Premium live lock/unlock state, premium audience presence, room mode changes, and non-interruptible realtime state |
| `GiftModule` | Reusable gift catalog, animation rendering, backend economy confirmation, and post-confirm RTDB/Firestore event fan-out currently represented by `widgets/gift_tray.dart` plus backend gift endpoints |

Screens should call the current facade/module methods such as `FirebaseChatService.instance.setBusyStatus(...)`, `setLiveStatus(...)`, `clearBusyStatus()`, `clearLiveStatus()`, `directSignals.writeRinging(...)`, and `directSignals.writeStatus(...)`. Screens must not write raw `busy`, `live`, `offline`, `direct_calls/$id/status`, or `live_rooms/$id/status` values directly.

RTDB rules and emulator tests must enforce the same ownership model: users can write only their own presence/profile, cannot overwrite another user's call signal, cannot end another host's room, and cannot publish trusted gift/status events without backend validation.

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
