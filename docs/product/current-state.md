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
| P0 | Partial pass | User | Manual simulator smoke test | User-reported smoke on 13 Jun 2026 passed Thread image, message send, direct call, and Inbox gift; login/onboarding/feed/presence/random call/live basics still need launch-minimum smoke while Render billing is fixed |
| P0 | Partial pass | User | Retest direct call with two online accounts | Basic direct call passed in user smoke on 13 Jun 2026; in-call report and post-call Message/Report/Done behavior still need explicit smoke if not covered |
| P0 | Action required | User | Manual two-account random-call smoke test | Use one customer and one host/girl account to verify live-host priority, receiver ribbon, accept, decline, timeout, end, and next-call behavior on simulator/device |
| P0 | Pending review | Google | Google Play merchant/bank verification | User submitted the Play payments profile and SBM bank statement on 7 Jun 2026; one-time product creation and catalog visibility are blocked until Google completes or accepts verification |
| P0 | Blocked | User | Manual Google Play internal-test purchase smoke | Fresh local Android AAB `1.0.26+27` exists with onboarding overflow and presence listener recovery fixes; upload it, create/publish `pack_299`, wait for catalog propagation, and retry backend credit/consume/refund smoke |
| P1 | Direction locked | User/Codex | Rework For you into Tango-style live discovery | For you must scale to hundreds/thousands of live host cards, show live supply first, avoid user-facing filters, support pull-to-refresh, lazy loading, viewer counts, body-tap live entry, identity-strip profile entry, and later live preview/hide-chrome polish |
| P1 | In progress | Codex | Expand reusable Gift module beyond live | Backend reusable gift catalog/send contract, durable gift delivery outbox/retry, Admin-owned inbox/live projections, and Inbox picker/card/animation UI exist; manual smoke and live/call/random/premium migration remain |
| P1 | Planned | Codex | Implement premium live lifecycle | Free live -> premium, start premium directly, paid entry, per-minute billing, lock screen, cleanup |
| P1 | Planned | Codex | Add `PremiumLiveRealtime` module once lifecycle exists | Keeps premium live non-interruptible and owned by a dedicated realtime module |
| P2 | Planned | Codex/User | Replace launch logo and splash with Zephyr Live premium identity | Convert the stored concept into deterministic production assets: app icon, splash mark, wordmark, adaptive Android foreground/background, iOS icon set, and dark-mode launch screen |

## Immediate Next Work

1. Manual smoke the launch-minimum For you page on iPhone using the reversible demo host simulator: live-only feed, viewer count, pull-to-refresh, lazy-load trigger, body-tap live entry, identity-strip profile entry, and empty state with Random match after cleanup.
2. Manually smoke test random call with two accounts: customer seeks, host sees ribbon, host accepts, host declines, host timeout, customer next, both end.
3. Deploy the backend active-session push/logout changes to Render, then run public and authenticated backend smoke from [operations.md](./operations.md).
4. Upload/test the fresh Android AAB, then run launch-minimum device smoke. Current local AAB candidate: `apps/zephyr-mobile/build/app/outputs/bundle/release/app-release.aab`, version `1.0.26+27`, package `com.zephyr.zephyr_mobile`, SHA-256 `40f66be70cdffedc9c69a62a3890fa4be4875117b2796b404a2a3ac33425d3ab`, size `74341686` bytes. Each Play/internal-test candidate AAB must use a freshly incremented Android build number.
5. Smoke auth/session with two devices/accounts: explicit logout returns to plain sign-in with no false another-device warning, no push after logout, expired/invalid saved token returns to plain sign-in, OAuth login from any device succeeds, tablet re-login is not bounced by pre-auth RTDB permission-denied, latest login invalidates older API/Firebase/push sessions, older running device returns to sign-in with the signed-in-elsewhere notice, and current-device logout revokes active API/Firebase/session-bound push controls.
6. Smoke remaining Inbox/media/gift behavior after Render deploy: user-reported smoke on 13 Jun 2026 passed Thread image, message send, direct call, and Inbox gift. Still verify failed-send retry, repeat Inbox/Thread entry from warm cache, receipts, block, report, logout/offline, no-push-after-logout, second-device sign-out, real-device photo send/retry, gift delivery retry, and once-only unseen gift animation under re-entry. Simulator plus-tray photo send passed on 11 Jun 2026 after the Storage cross-service IAM fix.
7. Wait for Google Play merchant/bank verification, create/publish `pack_299`, then smoke one internal-test purchase/refund.
8. Finish direct-call smoke follow-up after the 13 Jun basic direct-call pass: verify in-call report and post-call Message/Report/Done behavior.
9. Manual smoke the Following + Me entrances: follow/unfollow/count adjustment, empty Following state, feed card opens the selected host/profile, Me dashboard metrics load, Settings subpages open, and profile avatar/cover edits return cleanly.
10. Finish Inbox gift follow-up after the 13 Jun basic Inbox gift pass: verify one service-key gift delivery retry if a projection is pending, then migrate live/call/random/premium surfaces off the legacy tray and onto the reusable gift module.
11. Implement premium live lifecycle, paid entry, lock screen, metered billing, and `PremiumLiveRealtime`.

## Current Solution Snapshot (13 Jun 2026)

| Area | Current state |
|---|---|
| Overall launch state | Strong enough for closed/internal testing once remaining manual smoke is completed. User-reported smoke on 13 Jun 2026 passed Thread image, message send, direct call, and Inbox gift. Minimum public Android launch is still blocked by random-call/live/presence/auth follow-up smoke, Play IAP product/purchase smoke, store assets, Render billing stability, and remaining launch operations. Full v1 still needs premium live, gift expansion, production brand assets, admin/moderation operations, and iOS release work. |
| Verified checks | Root `pnpm check` passed on 13 Jun 2026 before the fresh Android `1.0.26+27` AAB build. Gates cover RTDB rules, Firestore rules, Storage rules, backend unit tests, backend e2e tests, real Postgres DB race/idempotency tests, backend build, Flutter analyze, and Flutter tests. Latest mobile tests include takeover notice dismissal, compact stale-session notice overflow coverage, expired-token classification, onboarding API-health retry/error revalidation, Firebase permission handling, logout false-notice suppression, gift-specific product-safe error copy, bounded chat-image preparation, RTDB contract parsing, incoming-call overlay safe-area/root-route regression coverage, app-wide away-to-online touch recovery, presence listener stale-cache invalidation/reattach, reusable gift model/UI parsing, and non-image rejection before Storage. |
| Known local build caveat | Local `flutter build appbundle` wrapper reported native debug-symbol stripping failure; direct Gradle `:app:bundleRelease` succeeds and reads version metadata from `pubspec.yaml`. Latest AAB built on 13 Jun 2026: package `com.zephyr.zephyr_mobile`, version `1.0.26+27`, size `74341686` bytes, SHA-256 `40f66be70cdffedc9c69a62a3890fa4be4875117b2796b404a2a3ac33425d3ab`; generated release manifest confirms `versionCode=27` and `versionName=1.0.26`. `flutter doctor -v` still reports Android cmdline-tools missing and Android license status unknown on this Mac. Release build still emits known R8 Kotlin metadata and Gradle deprecation warnings. |
| Auth/session | OAuth login uses a stable app-install device id. Backend maintains one active mobile API session per account, mirrors active session to Firebase `session_controls`, mints Firebase custom tokens with `sessionId`/`deviceId` claims, and binds push tokens to the active session. Explicit logout clears local state and backend push eligibility; latest-login-wins and no-push-after-logout still need deployed two-device smoke. |
| Realtime | RTDB presence, rules, module ownership, fail-closed client contract helpers, listener error stale-cache invalidation/reattach, backend projection, per-viewer live audience cells, and backend-trusted live gift fan-out are implemented and covered by emulator plus Flutter module tests. Postgres still owns the feed/API `rooms.audience_count` projection. Manual stress smoke across foreground/background/call/live transitions remains needed. |
| Messaging/inbox | Firestore/Storage rules, transactional sends, backend-verified best-effort push, active-session push token selection, block/report ownership, bounded JPEG preparation, optimistic text/media sends, failed-send retry, Firebase auth recovery, warm cache paint, production rules deployment, Storage cross-service IAM, supported-only media tray actions, full-screen sent/received image viewer, reusable paid gift picker, backend/Admin-written gift cards, and once-only unseen gift animation are in place. Simulator image smoke on 11 Jun initially hit `firebase_storage/unauthorized`; root cause was missing `roles/firebaserules.firestoreServiceAgent` on the Firebase Storage service agent while Storage rules used Firestore `session_controls`. After the IAM grant, simulator upload logged `upload-committed` and `download-url-ok`, and Firestore contains the image message with non-empty `imageUrl`. User-reported smoke on 13 Jun 2026 passed Thread image, message send, and Inbox gift. Manual smoke remains needed for failed-send retry, warm-cache repeat entry, receipts, block/report, no-push-after-logout after Render deploy, second-device sign-out, gift delivery retry, and once-only gift animation under re-entry. |
| Performance | Inbox/Thread repeat navigation paints from warm cache, normal repeat entry avoids an unnecessary backend token round trip, feed boot avoids accessory blocking, chat photo resize/compression runs off the UI thread, and Android Home resume work is debounced so presence/listener/feed refresh work does not stack during airplane-mode or shutdown churn. Release-device profiling still needs cold login, feed image decode/cache pressure, low-network traces, frame timings, lifecycle ANR traces, and startup metrics. |
| Economy/IAP | Backend economy paths are transaction-safe and tested. IAP code/backend/env are hardened, but Google Play merchant/product visibility and one real internal-test purchase/refund smoke are still blocking. |
| Calls/live | Direct and random call flows are implemented with in-call report and post-call actions. Basic direct call passed user smoke on 13 Jun 2026; direct-call report/post-call actions still need explicit smoke if not covered. Random call still needs two-account smoke. Normal live needs host/viewer smoke, long-session cleanup, and comments/reactions/gifts in production-like conditions. |
| Feed/profile/settings | For you live discovery, Following, profile entry, Me dashboard, wallet/level/revenue context, and settings subpages are implemented enough for manual smoke. Remaining work includes iPhone polish, live inventory behavior, backend ranking tuning, profile edit QA, deeper revenue/payout detail, persisted notification controls, and localization. |
| Brand/store | Current mascot remains for internal testing. Launch direction is Zephyr Live premium dark/gold. Stored concept asset: `apps/zephyr-mobile/assets/brand_concepts/zephyr_live_premium_mark_concept.png` SHA-256 `5ecc082a19e6339366c0e38cb19af0d45ee8c1cd05f2d04a1d80a1f8ff4304a9`. |
| Gifts/premium live/admin/iOS | Backend gift catalog/send contract is surface-aware; call/live/inbox gifts commit through backend -> Postgres ledger with durable `gift_events` receipts; inbox validates receiver/context/blocks/idempotency; inbox/live projection delivery is queued in `gift_delivery_outbox` inside the ledger transaction and retried through a service-key internal endpoint; live gifts fan out through trusted Admin RTDB events using the same `giftEventId`; inbox gift cards are trusted Firestore projections and the mobile reusable gift picker/card/animation module is wired into Inbox. Basic Inbox gift smoke passed on 13 Jun 2026. Gift delivery retry, real animation asset renderer/dependency decision, migration across live/call/random/premium, premium live, admin/moderation operations, and iOS release path remain future work. |

## Public Launch Gate

1. Deploy backend active-session push/logout cleanup to Render, upload/test Android AAB `1.0.26+27`, then complete the two-device/account smoke listed in Immediate Next Work.
2. Finish Google Play product setup and run one real internal-test purchase/refund.
3. Fix any bugs found from smoke, then rebuild with a fresh version code.
4. Finalize launch icon, splash, store listing, and screenshots for Zephyr Live.
5. Decide whether premium live ships later or is required for v1 public launch.
