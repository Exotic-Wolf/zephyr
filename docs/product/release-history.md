# Zephyr Release And Change History

This file keeps only the latest completed release/change record so product docs stay compact. Current launch truth lives in [current-state.md](./current-state.md).

## Latest Release Record

| Date | Type | Version / build | Record | Proof and caveats |
|---|---|---|---|---|
| 12 Jun 2026 | Mobile UI polish | unchanged `1.0.22+24` | Normalized Inbox gift receipt cards to the reusable premium dark receipt shell and pinned sender/receiver metadata to the bottom-right chat footer | `flutter test test/gift_module_test.dart`, `flutter analyze`, `git diff --check`, and `pnpm check:mobile` passed. No backend, Firestore, RTDB, rules, schema, or economy contract changed. Manual two-account simulator smoke remains the visual proof before calling the Inbox gift UI done. |
