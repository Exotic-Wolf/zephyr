# Zephyr Release And Change History

This file keeps only the latest completed release/change record so product docs stay compact. Current launch truth lives in [current-state.md](./current-state.md).

## Latest Release Record

| Date | Type | Version / build | Record | Proof and caveats |
|---|---|---|---|---|
| 13 Jun 2026 | Backend gift reliability | unchanged `1.0.22+24` | Added bank-grade gift projection delivery tracking: inbox/live gifts now queue `gift_delivery_outbox` in the same Postgres transaction as `gift_events`, use `GiftDeliveryService` for idempotent Firestore/RTDB projection fan-out, and expose service-key retry at `POST /v1/internal/gifts/retry-delivery` | `pnpm --filter zephyr-api test`, `pnpm --filter zephyr-api build`, and `pnpm check:backend` passed. No mobile UI, Firebase rules, release version, or production deploy changed. Manual two-account inbox/live gift smoke remains required before calling gift delivery fully proven on devices. |
