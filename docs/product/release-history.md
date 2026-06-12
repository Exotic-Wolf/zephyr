# Zephyr Release And Change History

This file keeps only the latest completed release/change record so product docs stay compact. Current launch truth lives in [current-state.md](./current-state.md).

## Latest Release Record

| Date | Type | Version / build | Record | Proof and caveats |
|---|---|---|---|---|
| 13 Jun 2026 | Android AAB build | `1.0.23+25` | Built a fresh signed Android release bundle after Play rejected version code `24`. Current artifact: `apps/zephyr-mobile/build/app/outputs/bundle/release/app-release.aab`, size `74339848` bytes, SHA-256 `e72d725fa708a55c0785727a3e7755a14af1fcd5c353dde512816ef6c0720907`. | `pnpm check` and `./gradlew :app:bundleRelease` passed; generated release metadata confirms `versionCode=25` and `versionName=1.0.23`. No app behavior, Firebase rules, backend deploy, or production data changed. Upload to Play/internal testing and manual smoke remain. |
