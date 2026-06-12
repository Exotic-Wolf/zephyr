# Zephyr Release And Change History

This file keeps only the latest completed release/change record so product docs stay compact. Current launch truth lives in [current-state.md](./current-state.md).

## Latest Release Record

| Date | Type | Version / build | Record | Proof and caveats |
|---|---|---|---|---|
| 12 Jun 2026 | Android AAB candidate | `1.0.22+24` | Hardened Android Home resume work against lifecycle/network churn, documented demo simulator recovery, and rebuilt the release AAB with a fresh Play version code | `pnpm check` passed before release build. Direct Gradle `:app:bundleRelease` succeeded. Artifact: `apps/zephyr-mobile/build/app/outputs/bundle/release/app-release.aab`; package `com.zephyr.zephyr_mobile`; version name `1.0.22`; version code `24`; size `74296151` bytes; SHA-256 `a798294c3cbb721959b5c1ce4095d478932bfc1975dcfd5a6e09a1422b2f46c7`. Build emitted known non-fatal R8 Kotlin metadata and Gradle deprecation warnings. Manual Play upload, Android lifecycle ANR watch, and real-device smoke remain required. |
