# Zephyr Current State

This file owns only current product state: active work, launch blockers, immediate next work, and the live solution snapshot. Current quality grades live in [audit-log.md](./audit-log.md). The latest release record lives in [release-history.md](./release-history.md). Architecture contracts live in [architecture.md](./architecture.md).

## Product Vision

- **Product name:** Zephyr Live.
- **Goal:** premium Chamet/Olamet-style live-social video app with a modular, testable, backend-trusted architecture.
- **Primary mobile audience:** iPhone users first, with Android parity through Flutter.
- **Target market:** Arab Gulf users calling Philippines/Asia hosts.
- **Core revenue:** coin-based gifts, direct/random video calls, and live streaming.
- **Expansion path:** premium live rooms where hosts can start premium directly or upgrade free live into a paid-per-minute room.
- **Brand direction:** warm summer-night breeze, glamorous live-social energy, premium dark/gold identity. The current mascot icon/splash can remain for internal testing; production launch assets should follow the premium Zephyr Live identity.

## Document Ownership

| Truth | Owning file |
|---|---|
| Current blockers, active work, immediate next work, launch snapshot | `docs/product/current-state.md` |
| Module ownership, source-of-truth boundaries, realtime contracts | `docs/product/architecture.md` |
| RTDB paths, fields, writers, readers, rules, listener contracts | `docs/product/rtdb-contract.md` |
| Commands, environment, deploy, rollback | `docs/product/operations.md` |
| Repository structure, DB notes, endpoint map, package notes | `docs/product/code-reference.md` |
| Product model, economy, pricing, gifts, premium live, compliance | `docs/product/product-model.md` |
| Screen/UX contracts | `docs/product/roadmap-ui.md` |
| Latest release/change record | `docs/product/release-history.md` |
| Current quality grades and quality gaps | `docs/product/audit-log.md` |

When two docs disagree, update the owner file instead of copying the fact into another file.

## Active TODO Tracker

| Priority | Status | Owner | Item | Why it matters |
|---|---|---|---|---|
| P0 | Action required | User | Update Render billing payment method | Render reported invalid payment info on 6 Jun 2026; service is healthy now but can be suspended if payment fails again |
| P0 | Partial pass with bugs | User | Manual simulator smoke test | User-reported smoke on 13 Jun 2026 covered Thread image, message send, direct call, Inbox gift, random-call invite path, live path, and one-device takeover; smoke findings are tracked below |
| P0 | Partial pass with bug | User | Retest direct call with two online accounts | Basic direct call passed in user smoke on 13 Jun 2026; caller terminal/end screen has one reported gap and in-call report plus post-call Message/Report/Done still need explicit follow-up |
| P0 | Partial pass with bugs | User | Manual two-account random-call smoke test | Customer seek and receiver ribbon were observed on 13 Jun 2026; caller media/timer starts before receiver accept, live-host invite visibility is weak, decline/timeout/end/next still need follow-up |
| P0 | Pending review | Google | Google Play merchant/bank verification | User submitted the Play payments profile and SBM bank statement on 7 Jun 2026; one-time product creation and catalog visibility are blocked until Google completes or accepts verification |
| P0 | Blocked | User | Manual Google Play internal-test purchase smoke | Fresh local Android AAB `1.0.26+27` exists with onboarding overflow and presence listener recovery fixes; upload it, create/publish `pack_299`, wait for catalog propagation, and retry backend credit/consume/refund smoke |
| P1 | Direction locked | User/Codex | Rework For you into Tango-style live discovery | For you must scale to hundreds/thousands of live host cards, show live supply first, avoid user-facing filters, support pull-to-refresh, lazy loading, viewer counts, body-tap live entry, identity-strip profile entry, and later live preview/hide-chrome polish |
| P1 | In progress | Codex | Expand reusable Gift module beyond live | Backend reusable gift catalog/send contract, durable gift delivery outbox/retry, Admin-owned inbox/live projections, and Inbox picker/card/animation UI exist; manual smoke and live/call/random/premium migration remain |
| P1 | Planned | Codex | Implement premium live lifecycle | Free live -> premium, start premium directly, paid entry, per-minute billing, lock screen, cleanup |
| P1 | Planned | Codex | Add `PremiumLiveRealtime` module once lifecycle exists | Keeps premium live non-interruptible and owned by a dedicated realtime module |
| P2 | Planned | Codex/User | Replace launch logo and splash with Zephyr Live premium identity | Convert the stored concept into deterministic production assets: app icon, splash mark, wordmark, adaptive Android foreground/background, iOS icon set, and dark-mode launch screen |

## Immediate Next Work

1. Follow up launch-minimum For you/Profile smoke from 13 Jun: profile placeholders should clearly show live state, then recheck live-only feed, viewer count, pull-to-refresh, lazy-load trigger, body-tap live entry, identity-strip profile entry, and empty state with Random match after cleanup.
2. Fix and re-smoke random call with two accounts: customer seeks, receiver ribbon/overlay is visible even when host is in live, caller waits without video/timer until accept, accept starts both sides, decline/timeout/next/end all clean up.
3. Deploy the backend active-session push/logout changes to Render, then run public and authenticated backend smoke from [operations.md](./operations.md).
4. Upload/test the fresh Android AAB, then run launch-minimum device smoke. Current local AAB candidate: `apps/zephyr-mobile/build/app/outputs/bundle/release/app-release.aab`, version `1.0.26+27`, package `com.zephyr.zephyr_mobile`, SHA-256 `40f66be70cdffedc9c69a62a3890fa4be4875117b2796b404a2a3ac33425d3ab`, size `74341686` bytes. Each Play/internal-test candidate AAB must use a freshly incremented Android build number.
5. Fix and re-smoke auth/session with two devices/accounts: latest-login takeover logged out the older device on 13 Jun, but the older device did not show the signed-in-elsewhere notice. Still verify explicit logout returns to plain sign-in with no false another-device warning, no push after logout, expired/invalid saved token returns to plain sign-in, OAuth login from any device succeeds, tablet re-login is not bounced by pre-auth RTDB permission-denied, and current-device logout revokes active API/Firebase/session-bound push controls.
6. Fix and re-smoke remaining Inbox/media/gift behavior after Render deploy: user-reported smoke on 13 Jun 2026 passed Thread image, message send, direct call, and basic Inbox gift. Still verify failed-send retry, repeat Inbox/Thread entry from warm cache, receipts, block, report, logout/offline, no-push-after-logout, second-device sign-out, real-device photo send/retry, gift delivery retry, once-only unseen gift animation under re-entry, photo-viewer back behavior, gift send latency, and removal of legacy/free emoji affordances.
7. Wait for Google Play merchant/bank verification, create/publish `pack_299`, then smoke one internal-test purchase/refund.
8. Finish direct-call smoke follow-up after the 13 Jun basic direct-call pass: reproduce the caller terminal/end-screen gap, then verify in-call report and post-call Message/Report/Done behavior.
9. Manual smoke the Following + Me entrances: follow/unfollow/count adjustment, empty Following state, feed card opens the selected host/profile, Me dashboard metrics load, Settings subpages open, and profile avatar/cover edits return cleanly.
10. Finish gift follow-up after the 13 Jun basic Inbox gift pass: profile slow gift sending, verify one service-key gift delivery retry if a projection is pending, then migrate live/call/random/premium surfaces off the legacy tray and onto the reusable gift module.
11. Implement premium live lifecycle, paid entry, lock screen, metered billing, and `PremiumLiveRealtime`.

## Smoke Findings Backlog (13 Jun 2026)

These are manual smoke findings to fix before public launch. They are not implementation contracts; source-of-truth docs and owning code must be inspected again before each fix.

| Priority | Area | Finding | Expected follow-up |
|---|---|---|---|
| P0 | Presence / RTDB | Turning off Wi-Fi left the other device showing the user as online. | Reproduce with `.info/connected`, app foreground/background, listener error, and `onDisconnect`; UI must not keep stale online as truth after disconnect. |
| P0 | Random call | Caller video and timer started while waiting for the receiver to accept. | Caller should stay in matching/ringing state; Agora media, call timer, and billing-visible call state should start only after receiver accept. |
| P0 | Random call / live | Host in live was matched for random call, but the live screen did not make the reason/invite visible enough. | Either show a root/live overlay invite that is impossible to miss, or tighten matching/routeability policy so live hosts are not silently interrupted. |
| P1 | Auth/session | Same-account login on another device logged out the older phone, but the older phone did not show the signed-in-elsewhere notice. | Preserve the takeover notice on stale-session logout and keep explicit self-logout as plain sign-in. |
| P1 | Onboarding / navigation | Sentry reported `FlutterError: Looking up a deactivated widget's ancestor is unsafe` after iOS OAuth/Firebase auth breadcrumbs on 13 Jun 2026; pasted mail did not include a Dart stack frame. | Get the full Sentry stack/event link, then fix stale `BuildContext` usage around login/navigation/sheets; do not use a route context after its widget is deactivated. |
| P1 | Direct call | One caller terminal-state scenario did not open the call-ended/post-call screen. | Reproduce accept/end, decline, timeout, and partner-left paths; caller must always reach a clear terminal state. |
| P1 | Inbox media | Back from the full-screen photo viewer focuses the composer and opens the keyboard. | Returning from image view should restore the thread without auto-focusing the message input. |
| P1 | Gifts / performance | Inbox gift sending feels too slow. | Profile catalog/send/ledger/projection timing and add better progress without playing animation before backend `giftEventId`. |
| P1 | Gifts / UX | Legacy/free emoji affordances still feel present and poor quality. | Remove legacy emoji sending affordances; paid reusable gift module is the only gift path. |
| P1 | Feed / profile | Profile placeholder should show live state. | Profile/feed placeholder should clearly communicate when the user is live and route to the right live/profile surface. |
| P1 | Live chat | Live chat feels weird. | Audit live chat layout, input behavior, readability, and keyboard/inset handling during host/viewer smoke. |
| P1 | Live gifts | Gift is not wired in live yet. | Migrate normal live to the reusable gift module and trusted Admin RTDB gift fan-out. |
| P2 | Live ended UX | Viewer sees the live-ended screen when host ends live. | Decide whether the ended screen is acceptable or should auto-return to feed after a short confirmation. |
| Info | Smoke wording | "Test timeout once" means do not accept or decline the invite; wait until the ringing/invite timer expires. | Re-run timeout smoke after random-call state fixes. |

## Current Solution Snapshot (13 Jun 2026)

| Area | Current state |
|---|---|
| Overall launch state | Strong enough for closed/internal testing, but 13 Jun manual smoke and Sentry found launch-significant bugs that must be fixed before public launch. User-reported smoke covered Thread image, message send, direct call, Inbox gift, random-call invite path, live path, and one-device takeover. Sentry reported a Flutter deactivated-ancestor lifecycle error after iOS OAuth/Firebase auth breadcrumbs; full stack is still needed. Minimum public Android launch is still blocked by random-call/live/presence/auth follow-up fixes, Play IAP product/purchase smoke, store assets, Render billing stability, and remaining launch operations. Full v1 still needs premium live, gift expansion, production brand assets, admin/moderation operations, and iOS release work. |
| Verified checks | Root `pnpm check` passed on 13 Jun 2026 before the fresh Android `1.0.26+27` AAB build. Gates cover RTDB rules, Firestore rules, Storage rules, backend unit tests, backend e2e tests, real Postgres DB race/idempotency tests, backend build, Flutter analyze, and Flutter tests. Latest mobile tests include takeover notice dismissal, compact stale-session notice overflow coverage, expired-token classification, onboarding API-health retry/error revalidation, Firebase permission handling, logout false-notice suppression, gift-specific product-safe error copy, bounded chat-image preparation, RTDB contract parsing, incoming-call overlay safe-area/root-route regression coverage, app-wide away-to-online touch recovery, presence listener stale-cache invalidation/reattach, reusable gift model/UI parsing, and non-image rejection before Storage. |
| Known local build caveat | Local `flutter build appbundle` wrapper reported native debug-symbol stripping failure; direct Gradle `:app:bundleRelease` succeeds and reads version metadata from `pubspec.yaml`. Latest AAB built on 13 Jun 2026: package `com.zephyr.zephyr_mobile`, version `1.0.26+27`, size `74341686` bytes, SHA-256 `40f66be70cdffedc9c69a62a3890fa4be4875117b2796b404a2a3ac33425d3ab`; generated release manifest confirms `versionCode=27` and `versionName=1.0.26`. `flutter doctor -v` still reports Android cmdline-tools missing and Android license status unknown on this Mac. Release build still emits known R8 Kotlin metadata and Gradle deprecation warnings. |
| Auth/session | OAuth login uses a stable app-install device id. Backend maintains one active mobile API session per account, mirrors active session to Firebase `session_controls`, mints Firebase custom tokens with `sessionId`/`deviceId` claims, and binds push tokens to the active session. User smoke on 13 Jun confirmed same-account takeover logs out the older phone, but the older phone did not show the signed-in-elsewhere notice. Sentry also reported a Flutter deactivated-ancestor lifecycle error after iOS OAuth/Firebase auth breadcrumbs; full stack is needed to localize the stale-context owner. Explicit logout/no-push-after-logout still need deployed two-device smoke. |
| Realtime | RTDB presence, rules, module ownership, fail-closed client contract helpers, listener error stale-cache invalidation/reattach, backend projection, per-viewer live audience cells, and backend-trusted live gift fan-out are implemented and covered by emulator plus Flutter module tests. Postgres still owns the feed/API `rooms.audience_count` projection. User smoke on 13 Jun found Wi-Fi-off can leave stale online visible, so disconnect/listener/onDisconnect behavior needs real-device follow-up. |
| Messaging/inbox | Firestore/Storage rules, transactional sends, backend-verified best-effort push, active-session push token selection, block/report ownership, bounded JPEG preparation, optimistic text/media sends, failed-send retry, Firebase auth recovery, warm cache paint, production rules deployment, Storage cross-service IAM, supported-only media tray actions, full-screen sent/received image viewer, reusable paid gift picker, backend/Admin-written gift cards, and once-only unseen gift animation are in place. Simulator image smoke on 11 Jun initially hit `firebase_storage/unauthorized`; root cause was missing `roles/firebaserules.firestoreServiceAgent` on the Firebase Storage service agent while Storage rules used Firestore `session_controls`. After the IAM grant, simulator upload logged `upload-committed` and `download-url-ok`, and Firestore contains the image message with non-empty `imageUrl`. User-reported smoke on 13 Jun 2026 passed Thread image, message send, and basic Inbox gift, but found photo-viewer back focuses the keyboard and gift sending feels slow. Manual smoke remains needed for failed-send retry, warm-cache repeat entry, receipts, block/report, no-push-after-logout after Render deploy, second-device sign-out, gift delivery retry, and once-only gift animation under re-entry. |
| Performance | Inbox/Thread repeat navigation paints from warm cache, normal repeat entry avoids an unnecessary backend token round trip, feed boot avoids accessory blocking, chat photo resize/compression runs off the UI thread, and Android Home resume work is debounced so presence/listener/feed refresh work does not stack during airplane-mode or shutdown churn. User smoke on 13 Jun found gift sending feels slow. Release-device profiling still needs cold login, gift send latency, feed image decode/cache pressure, low-network traces, frame timings, lifecycle ANR traces, and startup metrics. |
| Economy/IAP | Backend economy paths are transaction-safe and tested. IAP code/backend/env are hardened, but Google Play merchant/product visibility and one real internal-test purchase/refund smoke are still blocking. |
| Calls/live | Direct and random call flows are implemented with in-call report and post-call actions. Basic direct call passed user smoke on 13 Jun 2026, but one caller terminal-state gap was reported. Random-call smoke found receiver ribbon is delivered, but caller media/timer starts before accept and live-host invite visibility is weak. Normal live smoke found chat polish issues, live gift not wired, and live-ended UX needs review. |
| Feed/profile/settings | For you live discovery, Following, profile entry, Me dashboard, wallet/level/revenue context, and settings subpages are implemented enough for manual smoke. User smoke on 13 Jun found profile placeholder/live-state clarity needs work. Remaining work includes iPhone polish, live inventory behavior, backend ranking tuning, profile edit QA, deeper revenue/payout detail, persisted notification controls, and localization. |
| Brand/store | Current mascot remains for internal testing. Launch direction is Zephyr Live premium dark/gold. Stored concept asset: `apps/zephyr-mobile/assets/brand_concepts/zephyr_live_premium_mark_concept.png` SHA-256 `5ecc082a19e6339366c0e38cb19af0d45ee8c1cd05f2d04a1d80a1f8ff4304a9`. |
| Gifts/premium live/admin/iOS | Backend gift catalog/send contract is surface-aware; call/live/inbox gifts commit through backend -> Postgres ledger with durable `gift_events` receipts; inbox validates receiver/context/blocks/idempotency; inbox/live projection delivery is queued in `gift_delivery_outbox` inside the ledger transaction and retried through a service-key internal endpoint; live gifts fan out through trusted Admin RTDB events using the same `giftEventId`; inbox gift cards are trusted Firestore projections and the mobile reusable gift picker/card/animation module is wired into Inbox. Basic Inbox gift smoke passed on 13 Jun 2026, but gift sending feels slow and legacy/free emoji affordances should be removed. Gift delivery retry, real animation asset renderer/dependency decision, migration across live/call/random/premium, premium live, admin/moderation operations, and iOS release path remain future work. |

## Public Launch Gate

1. Deploy backend active-session push/logout cleanup to Render, upload/test Android AAB `1.0.26+27`, then complete the two-device/account smoke listed in Immediate Next Work.
2. Finish Google Play product setup and run one real internal-test purchase/refund.
3. Fix any bugs found from smoke, then rebuild with a fresh version code.
4. Finalize launch icon, splash, store listing, and screenshots for Zephyr Live.
5. Decide whether premium live ships later or is required for v1 public launch.
