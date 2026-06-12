# Zephyr Release And Change History

This file keeps only the latest completed release/change record so product docs stay compact. Current launch truth lives in [current-state.md](./current-state.md).

## Latest Release Record

| Date | Type | Version / build | Record | Proof and caveats |
|---|---|---|---|---|
| 13 Jun 2026 | Android AAB build | `1.0.23+26` | Built a fresh signed Android release bundle after enforcing build-number increment for Play/internal-test candidates. Current artifact: `apps/zephyr-mobile/build/app/outputs/bundle/release/app-release.aab`, package `com.zephyr.zephyr_mobile`, size `74341692` bytes, SHA-256 `c7f26b4f48036658f8c9f3164de385636fff06a81fa2b6075a5e96f83a73b763`. | `pnpm check` and direct Gradle `./gradlew :app:bundleRelease` passed. Generated release manifest confirms `versionCode=26` and `versionName=1.0.23`. Manual device/internal-test smoke remains. |
