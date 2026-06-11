# Zephyr Release And Change History

This file keeps only the latest completed release/change record so product docs stay compact. Current launch truth lives in [current-state.md](./current-state.md).

## Latest Release Record

| Date | Type | Version / build | Record | Proof and caveats |
|---|---|---|---|---|
| 11 Jun 2026 | Firebase Storage IAM + Inbox media smoke | `zephyr-495115` | Fix production Storage denial for Inbox image upload | Simulator logs proved the failure was `upload-failed:firebase_storage/unauthorized` with matching app user/Firebase uid, active `sessionId` claim, valid path, image size, and `image/jpeg`. Production Storage rules were already up to date, App Check was not enforced, and the default bucket matched app config. Root cause: the Firebase Storage service agent lacked `roles/firebaserules.firestoreServiceAgent`, required because `storage.rules` reads Firestore `session_controls` via `firestore.get/exists`. Granted the role to `service-724639603736@gcp-sa-firebasestorage.iam.gserviceaccount.com`; added `pnpm check:firebase:iam` as the production IAM stamp; `pnpm check:realtime`, `pnpm check:mobile`, and `pnpm check:firebase:iam` passed; simulator retry logged `upload-committed` and `download-url-ok`; Firestore shows the image message with non-empty `imageUrl`. |
