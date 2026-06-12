# Zephyr Release And Change History

This file keeps only the latest completed release/change record so product docs stay compact. Current launch truth lives in [current-state.md](./current-state.md).

## Latest Release Record

| Date | Type | Version / build | Record | Proof and caveats |
|---|---|---|---|---|
| 13 Jun 2026 | Android AAB build | `1.0.23+25` | Built a fresh signed Android release bundle after the onboarding compact-safe-area and presence listener recovery fixes. Current artifact: `apps/zephyr-mobile/build/app/outputs/bundle/release/app-release.aab`, package `com.zephyr.zephyr_mobile`, size `74341695` bytes, SHA-256 `fe59945b9d1c1c1a6d8d379a346c2d4231f9e39eb0dd734c531af9225c1e14d4`. | `pnpm check` and direct Gradle `./gradlew :app:bundleRelease` passed. Generated release manifest confirms `versionCode=25` and `versionName=1.0.23`. If Play has already accepted version code `25`, bump the build number before upload. Manual device/internal-test smoke remains. |
