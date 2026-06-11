# Zephyr Release And Change History

This file keeps only the latest completed release/change record so product docs stay compact. Current launch truth lives in [current-state.md](./current-state.md).

## Latest Release Record

| Date | Type | Version / build | Record | Proof and caveats |
|---|---|---|---|---|
| 11 Jun 2026 | Android AAB | `1.0.21+22` | Generate Android chat-media/logout-push AAB | `pubspec.yaml` bumped to `1.0.21+22`; root `pnpm check` passed and includes realtime rules, backend unit/e2e, real Postgres DB race, backend build, Flutter analyze, and Flutter tests 16/16 including chat media preparation. Direct Gradle `./gradlew :app:bundleRelease` passed in 1m34s; merged and packaged manifests verify package `com.zephyr.zephyr_mobile`, version name `1.0.21`, version code `22`, and Android image-read permissions. Artifact: `apps/zephyr-mobile/build/app/outputs/bundle/release/app-release.aab`; size `70.8 MiB / 74,251,964 bytes`; SHA-256 `aa9ce83c5b0eb0f06f05d833eeeacbf217c46a2edb40e03094d4b3fe47588911`. Caveats: non-fatal R8 Kotlin metadata warnings and Gradle 9 deprecation warning. Backend active-session push cleanup still needs Render deploy before no-push-after-logout smoke is meaningful. |
