# TV source evidence map

Reviewed 2026-08-09. Re-run against the exact release commit and AAB.

| Claim | Repository evidence |
|---|---|
| Package/version | `pubspec.yaml`; `android/app/build.gradle.kts`; merged release manifest |
| Android TV-only surface | `android/app/src/main/AndroidManifest.xml` requires Leanback and declares touchscreen optional |
| Internet-only source permission | `android/app/src/main/AndroidManifest.xml` |
| Production content locale is Kinyarwanda with English Material fallback | `RayonSportsConfig.language`; `lib/main.dart` fixed `appLocale`, fallback, and `AfriLocalizationsScope` |
| English/French/Kinyarwanda preview coverage | TV golden tests; this does not establish a production language selector |
| Anonymous provisioning, pairing, secure device credential | `lib/src/tv_runtime.dart`; `lib/src/tv_runtime_controller.dart` |
| Assigned-session projection | `lib/src/tv_runtime.dart` projection parsing and realtime refresh |
| Public aliases, scores, ranks | `TvLeaderboardEntry` and projection rendering |
| Sensitive-field rejection | `_rejectSensitiveProjection` and related runtime validation |
| No TV purchases/ads/account creation found | TV source and `pubspec.yaml` review |
| Current source banner is vector | `android/app/src/main/res/drawable/tv_banner.xml` |

The checked-in golden images are automated UI evidence, not store screenshots.
Store screenshots must be captured from the exact signed candidate on a release-
representative TV device with synthetic content.
