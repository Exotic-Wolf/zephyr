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
| P0 | Action required | User | Manual simulator smoke test | Check login/onboarding/feed/inbox/presence/direct call/random call/live basics while Render billing is fixed |
| P0 | Action required | User | Retest direct call with two online accounts | Open/log in both accounts after the Functions deploy so each account rewrites presence, then call only when the receiver badge is online/live and not busy |
| P0 | Action required | User | Manual two-account random-call smoke test | Use one customer and one host/girl account to verify live-host priority, receiver ribbon, accept, decline, timeout, end, and next-call behavior on simulator/device |
| P0 | Pending review | Google | Google Play merchant/bank verification | User submitted the Play payments profile and SBM bank statement on 7 Jun 2026; one-time product creation and catalog visibility are blocked until Google completes or accepts verification |
| P0 | Blocked | User | Manual Google Play internal-test purchase smoke | Current tester build cannot buy because no matching Play one-time products exist/are visible yet; after merchant verification, upload/use Android AAB `1.0.21+23` or a newer store-accepted build, create/publish `pack_299`, wait for catalog propagation, then retry backend credit/consume/refund smoke |
| P1 | Direction locked | User/Codex | Rework For you into Tango-style live discovery | For you must scale to hundreds/thousands of live host cards, show live supply first, avoid user-facing filters, support pull-to-refresh, lazy loading, viewer counts, body-tap live entry, identity-strip profile entry, and later live preview/hide-chrome polish |
| P1 | In progress | Codex | Expand reusable Gift module beyond live | Backend reusable gift catalog/send contract, durable gift delivery outbox/retry, Admin-owned inbox/live projections, and Inbox picker/card/animation UI exist; manual smoke and live/call/random/premium migration remain |
| P1 | Planned | Codex | Implement premium live lifecycle | Free live -> premium, start premium directly, paid entry, per-minute billing, lock screen, cleanup |
| P1 | Planned | Codex | Add `PremiumLiveRealtime` module once lifecycle exists | Keeps premium live non-interruptible and owned by a dedicated realtime module |
| P2 | Planned | Codex/User | Replace launch logo and splash with Zephyr Live premium identity | Convert the stored concept into deterministic production assets: app icon, splash mark, wordmark, adaptive Android foreground/background, iOS icon set, and dark-mode launch screen |

## Immediate Next Work

1. Manual smoke the launch-minimum For you page on iPhone using the reversible demo host simulator: live-only feed, viewer count, pull-to-refresh, lazy-load trigger, body-tap live entry, identity-strip profile entry, and empty state with Random match after cleanup.
2. Manually smoke test random call with two accounts: customer seeks, host sees ribbon, host accepts, host declines, host timeout, customer next, both end.
3. Deploy the backend active-session push/logout changes to Render, then run public and authenticated backend smoke from [operations.md](./operations.md).
4. Upload Android AAB `1.0.22+24` to Play/internal testing or use a newer store-accepted build, then run launch-minimum device smoke. Current local AAB candidate: `apps/zephyr-mobile/build/app/outputs/bundle/release/app-release.aab`, package `com.zephyr.zephyr_mobile`, SHA-256 `3e64f3f95ae9e2669b47d04523a38e486062ca4fe6fc0d509ad0fed97806652f`.
5. Smoke auth/session with two devices/accounts: explicit logout returns to plain sign-in with no false another-device warning, no push after logout, expired/invalid saved token returns to plain sign-in, OAuth login from any device succeeds, tablet re-login is not bounced by pre-auth RTDB permission-denied, latest login invalidates older API/Firebase/push sessions, older running device returns to sign-in with the signed-in-elsewhere notice, and current-device logout revokes active API/Firebase/session-bound push controls.
6. Smoke remaining Inbox/media/gift behavior after Render deploy: Inbox opens without raw Firebase permission text, optimistic text send, failed-send retry, repeat Inbox/Thread entry paints from warm cache, receipts, block, report, logout/offline, real-device photo send, inbox gift send/card, and once-only unseen gift animation. Simulator plus-tray photo send passed on 11 Jun 2026 after the Storage cross-service IAM fix.
7. Wait for Google Play merchant/bank verification, create/publish `pack_299`, then smoke one internal-test purchase/refund.
8. Retest direct call with two online accounts after the deployed presence-sync trigger, including in-call report and post-call Message/Report/Done behavior.
9. Manual smoke the Following + Me entrances: follow/unfollow/count adjustment, empty Following state, feed card opens the selected host/profile, Me dashboard metrics load, Settings subpages open, and profile avatar/cover edits return cleanly.
10. Manually smoke Inbox gifts with two accounts, including one service-key gift delivery retry if a projection is pending, then migrate live/call/random/premium surfaces off the legacy tray and onto the reusable gift module.
11. Implement premium live lifecycle, paid entry, lock screen, metered billing, and `PremiumLiveRealtime`.

## Current Solution Snapshot (13 Jun 2026)

| Area | Current state |
|---|---|
| Overall launch state | Strong enough for closed/internal testing once manual smoke is completed. Minimum public Android launch is still blocked by manual two-account smoke, Play IAP product/purchase smoke, store assets, Render billing stability, and remaining launch operations. Full v1 still needs premium live, gift expansion, production brand assets, admin/moderation operations, and iOS release work. |
| Verified checks | Root `pnpm check` passed on 12 Jun 2026 before the latest Android release bundle. Latest `pnpm check:backend` passed on 13 Jun 2026 after the gift delivery outbox/retry contract; latest `pnpm check:mobile` passed on 12 Jun 2026 after the reusable gift catalog/send contract, Admin-owned inbox gift card projection, and Inbox gift picker/card/animation UI. Gates cover RTDB rules, Firestore rules, Storage rules, backend unit tests, backend e2e tests, real Postgres DB race/idempotency tests, backend build, Flutter analyze, and Flutter tests. Latest mobile tests include takeover notice dismissal, expired-token classification, onboarding API-health retry/error revalidation, Firebase permission handling, logout false-notice suppression, gift-specific product-safe error copy, bounded chat-image preparation, RTDB contract parsing, incoming-call overlay safe-area/root-route regression coverage, app-wide away-to-online touch recovery, reusable gift model/UI parsing, and non-image rejection before Storage. |
| Known local build caveat | Local `flutter build appbundle` wrapper reported native debug-symbol stripping failure; direct Gradle `:app:bundleRelease` succeeds, reads version metadata from `pubspec.yaml`, and produced the uploadable signed AAB. Latest AAB built on 13 Jun 2026: package `com.zephyr.zephyr_mobile`, version `1.0.22+24`, size `74339838` bytes, SHA-256 `3e64f3f95ae9e2669b47d04523a38e486062ca4fe6fc0d509ad0fed97806652f`. `flutter doctor -v` still reports Android cmdline-tools missing and Android license status unknown on this Mac. Release build still emits known Agora namespace, R8 Kotlin metadata, and Gradle deprecation warnings. |
| Auth/session | OAuth login uses a stable app-install device id. Backend maintains one active mobile API session per account, mirrors active session to Firebase `session_controls`, mints Firebase custom tokens with `sessionId`/`deviceId` claims, and binds push tokens to the active session. Explicit logout clears local state and backend push eligibility; latest-login-wins and no-push-after-logout still need deployed two-device smoke. |
| Realtime | RTDB presence, rules, module ownership, fail-closed client contract helpers, backend projection, per-viewer live audience cells, and backend-trusted live gift fan-out are implemented and covered by emulator plus Flutter module tests. Postgres still owns the feed/API `rooms.audience_count` projection. Manual stress smoke across foreground/background/call/live transitions remains needed. |
| Messaging/inbox | Firestore/Storage rules, transactional sends, backend-verified best-effort push, active-session push token selection, block/report ownership, bounded JPEG preparation, optimistic text/media sends, failed-send retry, Firebase auth recovery, warm cache paint, production rules deployment, Storage cross-service IAM, supported-only media tray actions, full-screen sent/received image viewer, reusable paid gift picker, backend/Admin-written gift cards, and once-only unseen gift animation are in place. Simulator image smoke on 11 Jun initially hit `firebase_storage/unauthorized`; root cause was missing `roles/firebaserules.firestoreServiceAgent` on the Firebase Storage service agent while Storage rules used Firestore `session_controls`. After the IAM grant, simulator upload logged `upload-committed` and `download-url-ok`, and Firestore contains the image message with non-empty `imageUrl`. Manual real-device smoke remains needed for media send/retry, image viewer, receipts, block/report, no-push-after-logout after Render deploy, second-device sign-out, and inbox gifts. |
| Performance | Inbox/Thread repeat navigation paints from warm cache, normal repeat entry avoids an unnecessary backend token round trip, feed boot avoids accessory blocking, chat photo resize/compression runs off the UI thread, and Android Home resume work is debounced so presence/listener/feed refresh work does not stack during airplane-mode or shutdown churn. Release-device profiling still needs cold login, feed image decode/cache pressure, low-network traces, frame timings, lifecycle ANR traces, and startup metrics. |
| Economy/IAP | Backend economy paths are transaction-safe and tested. IAP code/backend/env are hardened, but Google Play merchant/product visibility and one real internal-test purchase/refund smoke are still blocking. |
| Calls/live | Direct and random call flows are implemented with in-call report and post-call actions. Both call flows need two-account smoke. Normal live needs host/viewer smoke, long-session cleanup, and comments/reactions/gifts in production-like conditions. |
| Feed/profile/settings | For you live discovery, Following, profile entry, Me dashboard, wallet/level/revenue context, and settings subpages are implemented enough for manual smoke. Remaining work includes iPhone polish, live inventory behavior, backend ranking tuning, profile edit QA, deeper revenue/payout detail, persisted notification controls, and localization. |
| Brand/store | Current mascot remains for internal testing. Launch direction is Zephyr Live premium dark/gold. Stored concept asset: `apps/zephyr-mobile/assets/brand_concepts/zephyr_live_premium_mark_concept.png` SHA-256 `5ecc082a19e6339366c0e38cb19af0d45ee8c1cd05f2d04a1d80a1f8ff4304a9`. |
| Gifts/premium live/admin/iOS | Backend gift catalog/send contract is surface-aware; call/live/inbox gifts commit through backend -> Postgres ledger with durable `gift_events` receipts; inbox validates receiver/context/blocks/idempotency; inbox/live projection delivery is queued in `gift_delivery_outbox` inside the ledger transaction and retried through a service-key internal endpoint; live gifts fan out through trusted Admin RTDB events using the same `giftEventId`; inbox gift cards are trusted Firestore projections and the mobile reusable gift picker/card/animation module is wired into Inbox. Manual inbox gift smoke, real animation asset renderer/dependency decision, migration across live/call/random/premium, premium live, admin/moderation operations, and iOS release path remain future work. |

## Public Launch Gate

1. Deploy backend active-session push/logout cleanup to Render, upload Android AAB `1.0.21+23`, then complete the two-device/account smoke listed in Immediate Next Work.
2. Finish Google Play product setup and run one real internal-test purchase/refund.
3. Fix any bugs found from smoke, then rebuild with a fresh version code.
4. Finalize launch icon, splash, store listing, and screenshots for Zephyr Live.
5. Decide whether premium live ships later or is required for v1 public launch.
