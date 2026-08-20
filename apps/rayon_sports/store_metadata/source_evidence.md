# Store-answer source evidence

| Topic | Current evidence | Store-pack conclusion |
| --- | --- | --- |
| Identity | `pubspec.yaml`, Android `build.gradle.kts`, exact IPA `Info.plist` | Android `rw.gikundiro.app`; iOS `rw.ikanisa.rayonSports`; current mobile version `1.0.3 (6)` |
| Authentication | `core_auth`, onboarding phone-auth screen | Anonymous sessions and phone OTP are implemented; restricted paths still need reviewer access |
| Account deletion | edit-profile screen, typed confirmation overlay, `delete-account` Edge Function invocation | In-app deletion exists; live completion and public web request route still need end-to-end evidence |
| Android permissions | source and generated release manifest | Notification permission is present; source removes location, audio, storage, and phone-state permissions; inspected release output has no SMS/Call Log permission |
| SMS behavior | production define and SMS service gates | `ENABLE_ANDROID_MOMO_SMS_AUTOREAD=false` in the tracked production define; do not market SMS auto-read or request restricted-permission approval for this candidate |
| Ads | package inventory and merged manifest | No ads SDK or ad placement found; Firebase dependencies introduce advertising-ID-related manifest entries in the inspected output, so exact-artifact review remains required |
| Firebase | core-network bootstrap/config | Firebase SDKs are bundled. Analytics, Crashlytics, and Performance require a compile-time observability gate; analytics additionally requires consent. Messaging can initialize after notification permission. App Check has its own compile-time gate |
| Backend | Supabase packages and repositories | Account/user IDs, profile, membership, ticket, shop, contribution, prediction, and device/session data can be transmitted to Supabase |
| Payments | `StoreReleasePolicy`; shop/ticket/membership flows; football-platform baseline and pgTAP contracts | Physical goods, event tickets, and contributions remain subject to fulfillment/refund/provider declarations. Paid digital membership is disabled: production policy requires explicit server plus compiled store-billing authorization, and the candidate database exposes only free physical-membership packages while revoking paid membership submission |
| Rewards and predictions | `StoreReleasePolicy`; football-platform baseline and pgTAP contracts | Ordinary read-only/earned-points context may remain, but staked challenges, jackpot entry, reward redemption, partner offers, transfer, and manual redemption are disabled for public clients in this candidate |
| UGC | `StoreReleasePolicy.publicSupporterLabel`; football-platform baseline and pgTAP contracts | Cross-user editable text is disabled. Production falls back to system-controlled aliases, and friend/search/leaderboard/challenge RPCs are unavailable to public release clients; UGC moderation approval is therefore not applicable to this disabled candidate |
| Rights | onboarding `SOURCES.md` | Images came from the club ecosystem, but reuse and trademark authority are explicitly pending |
| Locales | club config, Flutter localizations, and current official portal language lists | Mobile UI supports English, French, and Kinyarwanda. English/French upload metadata and Kinyarwanda source copy remain pending approval; Kinyarwanda is kept outside Fastlane because neither store currently accepts that metadata language |
| iPad | Xcode `TARGETED_DEVICE_FAMILY = "1,2"` | The app runs on iPad; iPad App Store screenshots are required |
| Play artwork | `play_store/artwork_manifest.json`; `tools/generate_store_artwork.swift` | Deterministic 512x512 icon and 1024x500 feature graphic use original Gikundiro geometry only, with no club crest or photography; accountable approval remains open |
| Android screenshots | `../android/fastlane/metadata/android/en-US/images/phoneScreenshots` | Three prior 1080x1920 captures remain. A complete exact-candidate recapture is required before submission. |
| Apple screenshots | `../ios/fastlane/screenshots/en-US`; `app_store/artwork_manifest.json` | Three prior iPhone and three iPad captures remain. Complete exact-candidate recaptures are required before submission. |
| iOS release artifact | `build/ios/ipa/Gikundiro.ipa`; `app_store/artwork_manifest.json` | Exact signed IPA SHA-256 `606739bff02260103ac0ad55eb1b2d1c223f8aea60e9de1c4099ca7572c477bc`; bundle `rw.ikanisa.rayonSports`, version `1.0.3 (6)` |
| iOS app icon | Exact IPA ZIP entries and `Info.plist`; source `AppIcon.appiconset` | `Assets.car`, 120x120 iPhone icon, 152x152 iPad icon, and `CFBundleIcons` declarations are present in the exact build-6 IPA. This closes technical presence only; accountable brand/content-rights approval remains open |

Generated build outputs are supporting evidence only. Generate a new source
freeze, final signed artifacts, screenshots, and portal checks before
submission.
