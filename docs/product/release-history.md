# Zephyr Release And Change History

This file keeps only the latest completed release/change record so product docs stay compact. Current launch truth lives in [current-state.md](./current-state.md).

## Latest Release Record

| Date | Type | Version / build | Record | Proof and caveats |
|---|---|---|---|---|
| 11 Jun 2026 | Inbox media UI + Android AAB candidate | `1.0.21+23` | Polished Inbox media tray, added sent/received image viewer, and rebuilt the release AAB with a fresh Play version code | `pnpm check` passed before release build. Direct Gradle `:app:bundleRelease` succeeded. Artifact: `apps/zephyr-mobile/build/app/outputs/bundle/release/app-release.aab`; package `com.zephyr.zephyr_mobile`; version name `1.0.21`; version code `23`; size `74287441` bytes; SHA-256 `b2aadcf0545d83124a915d8316f46cae6ecdf75907b8adcca5476022364a00c8`. Build emitted known non-fatal R8 Kotlin metadata and Gradle deprecation warnings. Manual real-device Inbox/media smoke remains required. |
