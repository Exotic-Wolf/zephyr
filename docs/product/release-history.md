# Zephyr Release And Change History

This file keeps only the latest completed release/change record so product docs stay compact. Current launch truth lives in [current-state.md](./current-state.md).

## Latest Release Record

| Date | Type | Version / build | Record | Proof and caveats |
|---|---|---|---|---|
| 11 Jun 2026 | Inbox media UI + Android AAB candidate | `1.0.21+22` | Polished Inbox media tray, added sent/received image viewer, and built release AAB for device testing | `pnpm check` passed before release build. Direct Gradle `:app:bundleRelease` succeeded. Artifact: `apps/zephyr-mobile/build/app/outputs/bundle/release/app-release.aab`; package `com.zephyr.zephyr_mobile`; version name `1.0.21`; version code `22`; size `74287442` bytes; SHA-256 `555344584eccc27f3eafebb5824f95ac4c400ea1500bea90a7e4bb1ad7c6f099`. Build emitted known non-fatal R8 Kotlin metadata and Gradle deprecation warnings. Manual real-device Inbox/media smoke remains required. |
