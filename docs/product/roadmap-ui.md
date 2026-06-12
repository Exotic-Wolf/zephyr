# Zephyr UX Reference

This file owns screen and interaction contracts only. It does not own completion status, grades, blockers, or release history. Current launch state lives in [current-state.md](./current-state.md), and current quality grades live in [audit-log.md](./audit-log.md).

## Global Flutter UI Contract

- Zephyr UI must be responsive by default across iOS phones, Android phones, iPad, and Android tablets.
- Use standard Flutter adaptive layout tools: `SafeArea`, `MediaQuery` insets, `LayoutBuilder`, constraints, flexible sizing, scrollable overflow protection, and platform-safe touch targets.
- Do not approve phone-only fixed layouts unless the screen contract explicitly limits the surface.
- UI handoff must state which device classes were smoked and which remain unproven.

## Onboarding

### Login

- File: `apps/zephyr-mobile/lib/features/onboarding/onboarding_page.dart`
- Dark premium visual direction with mascot branding for internal testing.
- Apple Sign-In on iOS and Google Sign-In everywhere supported.
- No guest login.
- API offline warning checks `/v1/health/live`, retries transient first-check failures, and revalidates before showing network-outage sign-in copy.
- Stale-session / signed-in-elsewhere notice must fit compact safe-area phone viewports with Apple and Google buttons visible and no RenderFlex overflow.
- Buttons disable during loading.
- User-facing errors must use product-safe copy, not raw exception strings.
- Legal links open Terms of Service and Privacy Policy.
- Success route: incomplete profile goes to profile setup; completed profile enters home.

### Profile Setup

- File: `apps/zephyr-mobile/lib/features/onboarding/profile_setup_screen.dart`
- Two-step flow: gender, then language.
- Gender/language display text must map to stable backend values.
- Female host onboarding may persist a default host cover only when `coverUrl` is empty.
- Save path must update backend profile and RTDB `profiles/{userId}` before entering home.
- Profile setup must be idempotent for incomplete saved sessions.

## App Shell

- Root file: `apps/zephyr-mobile/lib/features/home/home_screen.dart`
- App-level activity observation lives above pushed routes so touch activity in Inbox threads, profile pages, image viewers, and settings restores `away` users to online.
- Shared Zephyr header owns avatar/profile entry plus wallet/spark context.
- Footer destinations:

| Index | Label | Primary file |
|---|---|---|
| 0 | For you | `features/home/widgets/for_you_feed.dart` |
| 1 | Following | `features/home/widgets/follow_feed.dart` |
| 2 | Live | `features/live/go_live_countdown_page.dart` -> `features/live/host_live_screen.dart` |
| 3 | Explore | `features/explore/explore_page.dart` |
| 4 | Inbox | `features/chat/inbox_firebase_page.dart` |

Inbox badge displays unread count with a 99+ cap.

## For You

Target: Tango-style live discovery feed at real supply scale, not a filtered user directory.

- Shared Zephyr header plus dense `HostCardGrid`.
- Two columns, thin gutters, mostly rectangular cards.
- No visible user filter.
- Feed should scale to hundreds/thousands of live host cards per day; the visible grid is only the viewport.
- Requests live-only paged feed data; offline hosts must not appear as normal For you cards.
- Uses persisted host `coverUrl` first.
- Female hosts get one identity-seeded default local cover during onboarding when empty.
- Uploaded covers override default covers.
- Card shows viewer count.
- Main card/image tap enters the host live room when a live `roomId` exists.
- Avatar/name/flag identity strip opens the host profile.
- Pull-to-refresh reloads the live set.
- Infinite scroll/lazy loading uses `limit` + `offset`.
- Empty state shows customer Random match CTA rather than fake suggested cards.
- Later polish: short live preview while scrolling, header/footer hide-on-scroll, and mini-live after leaving a room.

## Following

- Reuses the `HostCardGrid` visual pattern.
- Filters to followed users only.
- Empty state tells users to follow someone.
- Customer accounts may see a Random match entry from this tab, including empty states.

## Live

### Go Live Entry

- File: `features/live/go_live_countdown_page.dart`
- Shows a focused live-start CTA and 3-2-1 countdown before host screen.

### Host Screen

- File: `features/live/host_live_screen.dart`
- Agora broadcaster role.
- Host controls: flip camera, mute, end.
- Uses `LiveRoomRealtime` for room realtime events.
- Presence intent goes through `PresenceRealtime`, not raw RTDB writes.

### Viewer Screen

- File: `features/live/viewer_live_screen.dart`
- Agora audience role.
- Shows remote video, comments, reactions, gifts, and viewer context.
- Viewer audience state uses per-viewer RTDB cells.

## Explore

- File: `features/explore/explore_page.dart`
- Search users by display name or 8-digit public ID.
- Profile entry must use the same profile/call/follow contracts as feed cards.

## Inbox

- Files:
  - `features/chat/inbox_firebase_page.dart`
  - `features/chat/thread_firebase_page.dart`
  - `features/chat/live_preview_widget.dart`
- Conversations and messages are Firestore-owned.
- Chat images are Storage-owned and uploaded only after bounded JPEG preparation.
- Plus tray shows only supported media actions: Camera and Photos. Do not show disabled or "soon" media actions.
- Tapping any sent or received chat image opens a full-screen image viewer with pinch/pan zoom and a clear close control.
- Presence and identity display use RTDB cache through `FirebaseChatService`.
- Thread call action uses a compact highlighted top-bar affordance and opens a bottom sheet with only supported call modes; current supported mode is `Video Call` with the receiver's backend-fetched price as `2100 [coin]/min`. If the receiver is offline, busy, in premium live, or still `checking` after presence cache invalidation, tapping the affordance must show product-safe availability copy instead of silently doing nothing. Do not fetch prices for every Inbox row by default, and do not show unsupported call modes as disabled/"soon" actions.
- Thread gift action must open the reusable paid gift module, not a hardcoded/free emoji tray. The module freezes `surface=inbox`, the canonical receiver id/display, and the chat context when opened; every send waits for backend `giftEventId` before playing the full animation or rendering the gift receipt.
- Inbox gift UI presents server catalog sections, shows server coin prices and thumbnails, uses receipt animation metadata, keeps send state idempotent through an `X-Idempotency-Key`, and shows product-safe errors for blocked users, insufficient balance, disabled gifts, stale chat context, or network failure.
- Inbox gift cards are `type=gift` Firestore messages written by backend/Admin only after the gift ledger commits. Recipients auto-play unseen gift animations once when the thread is open or later entered; the card remains in the timeline.
- Text and media sends are optimistic but must be verified by committed Firestore message state.
- Push relay is best-effort after Firestore commit.
- Permission recovery must refresh the session-bound Firebase token before retrying.
- Product-safe error copy only; never show raw Firebase/Storage/network text.

## Calls

### Direct Call

- File: `features/call/direct_call_screen.dart`
- Uses Agora for media and backend/Postgres for billing.
- Signaling goes through `DirectCallSignals`.
- Presence transitions go through `PresenceRealtime`.
- Incoming call UI must mount in the root app overlay so accept/decline remains above message threads, profile pages, image viewers, and other pushed routes.
- Incoming call overlay must be safe-area aware and responsive across iPhone, Android phones, and tablets; accept/decline controls must remain reachable without RenderFlex overflow.
- In-call report entry and post-call Message/Report/Done actions remain part of the safety UX.

### Random Call

- Files:
  - `features/call/random_call_screen.dart`
  - `features/call/random_call_invite_ribbon.dart`
- Customer starts seek through backend REST.
- Host receives invite ribbon outside the random-call screen.
- Accept routes into shared direct-call engine in random mode.
- Decline, timeout, partner-left, next, and end must clean up through backend/realtime contracts.

## Me, Profile, Wallet, Settings

- Files:
  - `features/me/me_tab.dart`
  - `features/profile/my_profile_page.dart`
  - `features/profile/profile_page.dart`
  - `features/me/balance_page.dart`
  - `features/me/call_price_page.dart`
  - `features/me/level_page.dart`
  - `features/me/revenue_page.dart`
  - `features/me/settings_page.dart`
- Me dashboard surfaces wallet, sparks, revenue, and call-price context.
- Profile avatar/cover edits must preserve full returned profile state.
- Wallet uses store-localized IAP prices when available and explicit catalog status when not.
- Settings subpages should not be dead rows; unavailable platform controls should deep-link or show honest product-safe copy.

## Deferred UX

These are product ideas, not current completion claims:

- short live preview while scrolling
- mini-live after room exit
- message reactions
- typing indicator
- reusable gift picker across inbox, calls, random calls, normal live, and premium live
- deeper revenue/payout statement
- persisted notification preferences
- admin/moderation panel
