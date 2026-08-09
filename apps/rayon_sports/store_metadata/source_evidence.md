# Store-answer source evidence

| Topic | Current evidence | Store-pack conclusion |
| --- | --- | --- |
| Identity | `pubspec.yaml`, Android `build.gradle.kts`, Xcode project | Android `rw.gikundiro.app`; iOS `rw.ikanisa.rayonSports`; `1.0.3 (5)` |
| Authentication | `core_auth`, onboarding phone-auth screen | Anonymous sessions and phone OTP are implemented; restricted paths still need reviewer access |
| Account deletion | edit-profile screen, typed confirmation overlay, `delete-account` Edge Function invocation | In-app deletion exists; live completion and public web request route still need end-to-end evidence |
| Android permissions | source and generated release manifest | Notification permission is present; source removes location, audio, storage, and phone-state permissions; inspected release output has no SMS/Call Log permission |
| SMS behavior | production define and SMS service gates | `ENABLE_ANDROID_MOMO_SMS_AUTOREAD=false` in the tracked production define; do not market SMS auto-read or request restricted-permission approval for this candidate |
| Ads | package inventory and merged manifest | No ads SDK or ad placement found; Firebase dependencies introduce advertising-ID-related manifest entries in the inspected output, so exact-artifact review remains required |
| Firebase | core-network bootstrap/config | Firebase SDKs are bundled. Analytics, Crashlytics, and Performance require a compile-time observability gate; analytics additionally requires consent. Messaging can initialize after notification permission. App Check has its own compile-time gate |
| Backend | Supabase packages and repositories | Account/user IDs, profile, membership, ticket, shop, contribution, prediction, and device/session data can be transmitted to Supabase |
| Payments | shop, ticketing, membership, contribution flows | App can create pending records and hand off an authorized MoMo USSD route; confirmation remains authoritative. Digital-benefit classification is unresolved |
| Rewards and predictions | gamification packages and feature registry | Predictions, points, leaderboards, and reward surfaces exist. Challenge routes require feature opt-in. No cash withdrawal implementation was found, but value/prize and production-feature decisions require approval |
| UGC | editable nickname, public/friend ranking rows, challenge-note models | Another user can potentially see user-selected text. No clear report-and-block implementation was found; this is a release-blocking classification unless the store build exposes only controlled aliases |
| Rights | onboarding `SOURCES.md` | Images came from the club ecosystem, but reuse and trademark authority are explicitly pending |
| Locales | club config, Flutter localizations, and current official portal language lists | Mobile UI supports English, French, and Kinyarwanda. English/French upload metadata and Kinyarwanda source copy remain pending approval; Kinyarwanda is kept outside Fastlane because neither store currently accepts that metadata language |
| iPad | Xcode `TARGETED_DEVICE_FAMILY = "1,2"` | The app runs on iPad; iPad App Store screenshots are required |

Generated build outputs are supporting evidence only. Re-run this assessment on
the exact frozen commit and signed artifacts before submission.
