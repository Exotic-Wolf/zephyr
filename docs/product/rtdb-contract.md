# Zephyr RTDB Contract

This file owns the Firebase Realtime Database contract: paths, fields, writers, readers, module owners, rules coverage, failure posture, and smoke expectations. Architecture owns boundaries; this file owns the tree.

## Update Standard

- Update this file with every RTDB path, field, listener, writer, rule, or module-owner change.
- Update `database.rules.json` and `tests/rtdb/rules.test.mjs` with every client-readable or client-writable contract change.
- Keep RTDB for realtime state only. Do not move wallet, IAP, refunds, paid billing, durable gift ledger, moderation ledger, or chat message truth into RTDB.
- Treat RTDB as mission-critical. A failed RTDB rule test, listener contract, Admin fan-out, or projection sync is a stop-the-line event.
- Label Admin-only and demo-only fields explicitly. Client rules do not need to validate Admin-only payloads, but product code must not trust them unless the backend owns the originating durable event.

## A++ Standard

RTDB work is A++ only when every affected path has:

- one owning module and public API
- one canonical writer class
- documented allowed readers and projections
- fail-closed behavior when data is missing, stale, denied, or malformed
- security rule coverage for every client-readable or client-writable shape
- targeted emulator tests for allowed writes, denied writes, allowed reads, denied reads, and malformed payloads
- module-level tests when the Dart facade contains branching or lifecycle logic
- manual smoke for reconnect, `onDisconnect`, multi-account timing, Agora/call/live state, or push-visible behavior

Documentation alone is never enough. The contract becomes real only when rules, tests, modules, and smoke agree.

Implemented client proof:

- `apps/zephyr-mobile/lib/services/rtdb_contracts.dart` owns pure client-side RTDB parsing/building contracts.
- `apps/zephyr-mobile/test/rtdb_contracts_test.dart` proves fail-closed presence, profile, direct/random signal, and live-room event behavior.
- `PresenceRealtime`, `ProfilesRealtime`, `DirectCallSignals`, and `LiveRoomRealtime` route listener input through the contract helpers before updating UI-facing state.

## Runtime Boundaries

| Domain | RTDB path | Owner module | Writers | Readers/projections | Required proof |
|---|---|---|---|---|---|
| Active Firebase session guard | `session_controls/{userId}` | Backend session/Firebase module | Backend/Admin only | RTDB rules session gate, Firebase token claims | RTDB rules plus auth/session smoke |
| Display identity | `profiles/{userId}` | `ProfilesRealtime` | Current user through facade; Admin cleanup/demo | Mobile profile cache, UI cards | RTDB rules plus profile smoke |
| Realtime availability | `presence/{userId}` | `PresenceRealtime` | Current user through facade; Functions reaper; Admin demo/cleanup | UI badges, routing guards, Postgres projection | RTDB rules, backend projection tests/smoke |
| Direct-call signal | `direct_calls/{userId}` | `DirectCallSignals` | Caller/receiver through facade; Backend/Admin random-match signal | Incoming overlay, call screens, Functions cleanup | RTDB rules plus two-account call smoke |
| Live-room realtime | `live_rooms/{roomId}` | `LiveRoomRealtime` | Host/viewers through facade; Backend/Admin trusted gift fan-out/demo/cleanup | Live screens, audience count, comments, reactions, gift animation | RTDB rules plus live smoke |

## Enforcement Status

| Path | Client enforcement today | A++ hardening rule |
|---|---|---|
| `session_controls/{userId}` | Client read/write denied; used by rules as a session gate | Any change requires matching Firestore/RTDB session-control behavior and auth/session smoke |
| `profiles/{userId}` | Owner write/read with required visible identity fields | New visible identity fields require rules tests and profile UI smoke |
| `presence/{userId}` | Owner write/read with coherent canonical states and session-token guard | Any new state or field needs presence rules tests, backend projection review, and call/live adjacency review |
| `direct_calls/{userId}` | Caller/receiver read/write/delete, immutable core metadata, backend/Admin random-match extras | Random-call signaling should move to `RandomCallSignals` or a stricter sub-contract before expansion |
| `live_rooms/{roomId}` | Host room ownership, viewer audience cells, comments, reactions, client gift fan-out blocked | Premium live and gifts need dedicated realtime module contracts before expansion |

Admin writes bypass client security rules by design. Admin-only fields are allowed only when created from backend-owned durable truth or reversible demo tooling.

## Canonical Tree

```text
/
  session_controls/
    {userId}/
      activeSessionId
      activeDeviceId
      updatedAt

  profiles/
    {userId}/
      displayName
      avatarUrl
      countryCode
      language
      birthday
      updatedAt                 Admin/demo optional

  presence/
    {userId}/
      schemaVersion             1
      connection                online | offline
      activity                  idle | away | free_live_host | free_live_viewer | premium_live_host | premium_live_viewer | live_paused | direct_call | random_call
      availability              available | busy | unavailable
      routing/
        directCall              boolean
        randomCall              boolean
      displayStatus             online | away | live | premium_live | busy | offline
      interruptible             boolean
      state                     legacy mirror of displayStatus
      lastSeen                  server timestamp
      updatedAt                 server timestamp
      roomId                    string, when in live/premium live context
      roomMode                  free_live | premium_live, when roomId exists
      callSessionId             string, when in direct/random call
      premiumRoomSessionId      string, when in premium live as viewer
      previousActivity          string, when preserving resumable live context
      previousRoomId            string, when preserving resumable live context
      demo/                     Admin/demo only
        simulator
        routeable
        nextDelaySeconds
        nextRotationAt
        nextRotationAtIso

  direct_calls/
    {receiverUserId}/
      callerId
      callerName
      callerAvatarUrl
      sessionId
      status                    ringing | accepted | declined | matched
      ts
      event                     Backend/Admin random-match optional
      appId                     Backend/Admin random-match optional
      channelName               Backend/Admin random-match optional
      uid                       Backend/Admin random-match optional
      token                     Backend/Admin random-match optional
      partnerId                 Backend/Admin random-match optional
      partnerName               Backend/Admin random-match optional
      rateCoinsPerMinute        Backend/Admin random-match optional
      hostEarningCoinsPerMinute Backend/Admin random-match optional
      receiverShareBps          Backend/Admin random-match optional
      expiresAt                 Backend/Admin random-match optional

  live_rooms/
    {roomId}/
      status                    live | ended
      hostUserId
      audience_count
      started_at
      roomMode                  Admin/demo optional
      hostId                    Admin/demo compatibility optional
      hostName                  Admin/demo optional
      updatedAt                 Admin/demo optional
      audience/
        {viewerId}/
          joinedAt
          lastSeen
      comments/
        {commentId}/
          userId
          name
          text
          ts
      reactions/
        {reactionId}/
          userId
          emoji
          ts
      gifts/
        {giftEventId}/          Backend/Admin only
          trusted
          senderUserId
          senderName
          giftId
          giftName
          quantity
          totalGiftCoins
          eventId
          ts
```

## Presence State Contract

`presence/{userId}` is the canonical realtime availability cell. Screens must express intent through `PresenceRealtime`; they must not hand-write raw RTDB status values.

| Intent | Required state |
|---|---|
| Offline/disconnected | `connection=offline`, `activity=idle`, `availability=unavailable`, `routing.directCall=false`, `routing.randomCall=false`, `displayStatus=offline`, `interruptible=false` |
| Foreground idle | `connection=online`, `activity=idle`, `availability=available`, `routing.directCall=true`, `routing.randomCall=true`, `displayStatus=online`, `interruptible=true` |
| Away | `connection=online`, `activity=away`, `availability=available`, `routing.directCall=true`, `routing.randomCall=false`, `displayStatus=away`, `interruptible=true` |
| Free live host | `activity=free_live_host`, `availability=available`, `routing.directCall=true`, `routing.randomCall=true`, `displayStatus=live`, `interruptible=true`, `roomMode=free_live` |
| Free live viewer | `activity=free_live_viewer`, `availability=available`, `routing.directCall=true`, `routing.randomCall=true`, `displayStatus=online`, `interruptible=true`, `roomMode=free_live` |
| Premium live host | `activity=premium_live_host`, `availability=busy`, `routing.directCall=false`, `routing.randomCall=false`, `displayStatus=premium_live`, `interruptible=false`, `roomMode=premium_live` |
| Premium live viewer | `activity=premium_live_viewer`, `availability=busy`, `routing.directCall=false`, `routing.randomCall=false`, `displayStatus=busy`, `interruptible=false`, `roomMode=premium_live` |
| Live paused | `activity=live_paused`, `availability=unavailable`, `routing.directCall=false`, `routing.randomCall=false`, `displayStatus=busy`, `interruptible=false`, `roomMode=free_live` |
| Direct call | `activity=direct_call`, `availability=busy`, `routing.directCall=false`, `routing.randomCall=false`, `displayStatus=busy`, `interruptible=false` |
| Random call | `activity=random_call`, `availability=busy`, `routing.directCall=false`, `routing.randomCall=false`, `displayStatus=busy`, `interruptible=false` |

`state` is legacy compatibility and must equal `displayStatus`. New code reads and writes canonical fields first.

## Failure Posture

RTDB failures must fail closed:

- Missing, denied, stale, or malformed `presence/{userId}` means the user is unavailable for routing until fresh canonical data is read.
- Missing `profiles/{userId}` may use safe display fallback only; it must not create a second identity source.
- Missing `direct_calls/{userId}` means no active signal. Do not infer a call from UI state alone.
- Missing `live_rooms/{roomId}` means the live surface should exit or show ended/unavailable. Do not continue paid/live lifecycle from a stale screen.
- Missing `live_rooms/{roomId}/gifts/{giftEventId}` affects only visible animation. Gift spend/refund truth remains Postgres/backend.
- RTDB permission-denied must be handled as a session/auth state problem, not hidden behind generic UI retry loops.

## Projection Contract

Postgres stores only a projection of RTDB presence for backend queries. RTDB remains canonical.

| Postgres field | RTDB source |
|---|---|
| `users.status` | `displayStatus` |
| `users.presence_connection` | `connection` |
| `users.presence_activity` | `activity` |
| `users.presence_availability` | `availability` |
| `users.can_direct_call` | `routing.directCall` |
| `users.can_random_call` | `routing.randomCall` |
| `users.presence_updated_at` | `updatedAt` |

Backend matching and call creation must use `presence_availability`, `can_direct_call`, and `can_random_call`; they must not infer routeability from `users.status` or UI badge text.

## Security Contract

- Root reads/writes are denied.
- Session-bound Firebase tokens must match `session_controls/{userId}.activeSessionId` when a session control exists.
- Users can write only their own `presence/{userId}` and `profiles/{userId}` through the validated schema.
- Direct-call nodes are readable and mutable only by the receiver or caller.
- Viewers can join/remove only their own `live_rooms/{roomId}/audience/{viewerId}` cell.
- Live comments and reactions must carry `userId == auth.uid`.
- Clients cannot publish `live_rooms/{roomId}/gifts`; backend/Admin fan-out is required after the durable economy ledger succeeds.
- Users cannot end another host's live room or write unknown live-room child paths through client rules.

## Addition Gate

Before adding or changing any RTDB contract:

1. Name the owning module and public method.
2. Define the path, exact fields, writer, readers, projection, and cleanup behavior here.
3. Update `database.rules.json` and `tests/rtdb/rules.test.mjs`.
4. Add or update module-level tests for any client facade logic.
5. Run `pnpm check:realtime` at minimum.
6. Run broader gates when auth/session, call routing, live, economy, or cross-module behavior can regress.
7. Complete manual smoke when real devices, reconnect/onDisconnect, Agora, push, or multi-account timing is involved.

If any step is missing, the RTDB change is not done.
