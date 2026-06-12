# Zephyr Release And Change History

This file keeps only the latest completed release/change record so product docs stay compact. Current launch truth lives in [current-state.md](./current-state.md).

## Latest Release Record

| Date | Type | Version / build | Record | Proof and caveats |
|---|---|---|---|---|
| 13 Jun 2026 | Android AAB build | `1.0.26+27` | Built a fresh signed Android release bundle after Play reported version code `26` had already been used. Current artifact: `apps/zephyr-mobile/build/app/outputs/bundle/release/app-release.aab`, package `com.zephyr.zephyr_mobile`, size `74341686` bytes, SHA-256 `40f66be70cdffedc9c69a62a3890fa4be4875117b2796b404a2a3ac33425d3ab`. | `pnpm check` and direct Gradle `./gradlew :app:bundleRelease` passed. Generated release manifest confirms `versionCode=27` and `versionName=1.0.26`. Manual device/internal-test smoke remains. |
