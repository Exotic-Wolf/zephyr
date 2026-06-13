# Zephyr Quality Dashboard

This file owns the current quality grade for each product area. It is not a historical log. Update the same row when evidence changes.

Current launch blockers live in [current-state.md](./current-state.md). Architecture boundaries live in [architecture.md](./architecture.md). Release artifacts live in [release-history.md](./release-history.md). Operational incident/change structure lives in [operations.md](./operations.md).

## Update Standard

- Keep one canonical table.
- Do not append dated audit sections.
- Do not preserve old grades as history in this file.
- Raise a grade only when code inspection, relevant gates, and required smoke support the claim.
- Lower a grade immediately when a regression, failed gate, failed smoke, or source-of-truth conflict is found.
- Use `operations.md` A3 format for major failures or repeated regressions; update this dashboard only with the resulting current grade and next gap.
- If a row needs a long explanation, the owner doc is missing detail. Fix the owner doc instead of bloating this table.

## Grade Scale

| Grade | Meaning |
|---|---|
| A+ | Contract is implemented, covered by the right automated gates, and required manual smoke is complete. |
| A | Strong implementation and automated proof; limited manual smoke, polish, or edge proof remains. |
| B | Usable or partially proven, but launch-significant gaps remain. |
| C | Product model or partial implementation exists, but the feature is not launch-complete. |
| Pending | Not implemented or not meaningfully audited yet. |

## Canonical Quality Dashboard (13 Jun 2026)

| Area | Current grade | Evidence | Current gap | Owner doc |
|---|---|---|---|---|
| Closed/internal testing readiness | A- | Root `pnpm check` passed on 13 Jun 2026; fresh local AAB `1.0.26+27` exists; user-reported smoke on 13 Jun passed Thread image, message send, direct call, and Inbox gift | Upload/test `1.0.26+27`, then complete remaining launch-minimum smoke | `current-state.md` |
| Minimum public Android launch | B+ | Core app, backend, Firebase rules, and signed AAB build path are in place | Play upload/acceptance, two-account smoke, Play IAP product/purchase smoke, store assets, Render billing stability, and launch operations remain | `current-state.md` |
| Full Zephyr Live v1 vision | C+ | Core social/live/call/economy foundation exists and the reusable gift module is started with Inbox wired | Premium live, full gift migration, admin/moderation operations, production brand assets, and iOS release remain incomplete | `current-state.md` |
| Onboarding | A | Google/Apple login, signed-in-elsewhere notice, compact safe-area overflow coverage, legal copy, and profile setup are implemented with tests | Keep smoke coverage during launch-minimum device test | `roadmap-ui.md` |
| Auth / one-device sessions | A | Stable device id, active API session, Firebase session claims, push scoping, and tests are in place | Render deploy plus two-device latest-login/no-push-after-logout smoke remain | `architecture.md` |
| RTDB / realtime architecture | A | Presence/profile/call/live facades, fail-closed client contract helpers, presence listener stale-cache invalidation/reattach regression coverage, Flutter module tests, rules, backend projection, and emulator tests are in place | Manual multi-state smoke across foreground/background/call/live remains | `rtdb-contract.md` |
| Messaging / Inbox | A- | Text/media send path, Admin-written gift cards, reusable gift picker/card UI, once-only unseen gift animation, and automated Firestore/Storage/media prep gates pass; `pnpm check:firebase:iam` stamps the Storage cross-service IAM role; simulator image upload passes and Firestore has the committed image message with non-empty `imageUrl`; user-reported smoke on 13 Jun passed Thread image, message send, and Inbox gift | Complete failed-send retry, warm-cache repeat entry, receipts, block/report, no-push-after-logout, second-device sign-out, gift retry, and re-entry animation smoke before A/A+ | `roadmap-ui.md` |
| Performance / perceived speed | A- | Warm cache, reduced repeat token round trip, nonblocking feed boot, and off-thread chat image prep are in place | Release-device profiling for cold login, image cache pressure, low network, frames, and startup remains | `current-state.md` |
| Backend economy / wallet ledger | A | Transaction-safe wallet/call/gift paths, gift delivery outbox/retry, and DB race/idempotency tests are in place | External IAP smoke and store refund proof remain | `product-model.md` |
| Direct + random calls | A- | Direct/random flows, shared call screen, receiver ribbon, billing/report paths, and routeability rules exist; basic direct call passed user smoke on 13 Jun | Direct-call report/post-call follow-up and two-account random-call smoke remain | `product-model.md` |
| Normal live streaming | A- | Agora live, RTDB room events, per-viewer audience cells, heartbeat, and backend-trusted live gift fan-out exist | Production-like host/viewer/comment/reaction/gift/cleanup smoke remains | `product-model.md` |
| For you / Following feed | A- | Live discovery, host cards, pull refresh, lazy-load trigger, viewer counts, body/profile entry, and Following state exist | iPhone polish, live inventory behavior, ranking tuning, and manual smoke remain | `roadmap-ui.md` |
| Me / profile / wallet / settings | A- | Me dashboard, wallet/level/revenue/call-price/settings/profile edit entrances exist | Deeper revenue/payout detail, notification persistence, localization, and manual smoke remain | `roadmap-ui.md` |
| IAP / billing | B | Backend/store code is hardened and production fake-purchase path is blocked | Google Play product visibility and one real internal-test purchase/refund smoke remain | `product-model.md` |
| Gifts overall | B+ | Backend catalog/send contract is surface-aware; call/live/inbox gifts use backend ledger, durable `gift_events` receipts, `gift_delivery_outbox` retry tracking for inbox/live projections, idempotency/race tests, inbox receiver/context/block validation, mobile gift response models/UI, Admin Firestore inbox gift cards, Admin RTDB fan-out for live, Firestore rules deny client-forged gift messages, and basic Inbox gift smoke passed on 13 Jun | Gift delivery retry, real asset animation renderer/dependency decision, and migration across direct call, random call, live, and premium live remain | `product-model.md` |
| Brand / store presence | B- | Premium Zephyr Live direction and concept asset exist | Production icon, splash, store listing, and screenshots remain | `current-state.md` |
| Admin / moderation operations | Pending | Block/report primitives exist | Admin/moderation operations surface remains unfinished | `product-model.md` |
| Premium live | C | Product model and realtime states are documented | Paid entry, lock screen, per-minute billing, lifecycle, and `PremiumLiveRealtime` are not implemented | `product-model.md` |
| iOS release path | Pending | Flutter app has iOS parity path | Signing/export/TestFlight/App Store path is not worked through | `operations.md` |
| Documentation normalization | A | Product docs are split by owner; `AGENTS.md` enforces documentation gate | Keep docs current with each product/code/config/release change | `AGENTS.md` |
