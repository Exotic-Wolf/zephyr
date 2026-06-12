# Zephyr Release And Change History

This file keeps only the latest completed release/change record so product docs stay compact. Current launch truth lives in [current-state.md](./current-state.md).

## Latest Release Record

| Date | Type | Version / build | Record | Proof and caveats |
|---|---|---|---|---|
| 13 Jun 2026 | Android AAB build | `1.0.22+24` | Built fresh signed Android App Bundle after the gift backend reliability deploy. Artifact: `apps/zephyr-mobile/build/app/outputs/bundle/release/app-release.aab`, size `74339838` bytes, SHA-256 `3e64f3f95ae9e2669b47d04523a38e486062ca4fe6fc0d509ad0fed97806652f` | `./gradlew :app:bundleRelease` passed. Build used the already-pushed `84bf17ea` backend gift outbox code; no mobile code, version, Firebase rules, or production deploy changed. Build still emits known Flutter/Kotlin/R8/Gradle warnings. Manual play-around smoke remains next. |
