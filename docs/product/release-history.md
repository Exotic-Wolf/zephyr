# Zephyr Release And Change History

This file keeps only the latest completed release/change record so product docs stay compact. Current launch truth lives in [current-state.md](./current-state.md).

## Latest Release Record

| Date | Type | Version / build | Record | Proof and caveats |
|---|---|---|---|---|
| 13 Jun 2026 | Play upload check | `1.0.22+24` rejected | Play Console rejected the fresh signed AAB because version code `24` has already been used. Artifact remains locally at `apps/zephyr-mobile/build/app/outputs/bundle/release/app-release.aab`, size `74339838` bytes, SHA-256 `3e64f3f95ae9e2669b47d04523a38e486062ca4fe6fc0d509ad0fed97806652f`, but it is not reusable for Play upload. | `./gradlew :app:bundleRelease` passed before upload; next release must bump `apps/zephyr-mobile/pubspec.yaml` to an unused build number, such as `1.0.23+25` or higher, rebuild, and upload that new AAB. No mobile code, Firebase rules, backend deploy, or production data changed. |
