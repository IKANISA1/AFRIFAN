# Rayon Sports Flutter Screen Cleanup Inventory - 2026-06-28

This inventory records the post-cleanup Flutter mobile screen surface for the
Rayon Sports app. It is source-backed from `packages/app_registry`,
`packages/features/*/lib/src/*_module.dart`, and
`packages/features/*/lib/src/screens`.

## Active App Modules

`AppModuleRegistry` currently registers these modules for the mobile app:

- `HomeModule`
- `LiveModule`
- `FanzoneModule`
- `ChallengeModule`
- `SettingsModule`
- `OnboardingModule`
- `MembershipModule`
- `ContributionsModule`
- `TicketingModule`
- `FanClubsModule`
- `AdminModule` (explicit internal mobile opt-in only; centralized Admin PWA is
  the default operations surface)
- `ShopModule`

## Route Inventory

| Module | Active routes |
| --- | --- |
| Home | `/home` tab |
| Fan Zone | `/fanzone` tab, `fixtures`, `live`, `my`, `my/:predictionId`, `my/:predictionId/settlement`, `match/:fixtureId`, `wallet`, `offers`, `rewards`, `history`, `leaderboard`, `notifications`, `badges`, `streak`, `share`, `league`, `league/:competitionSlug`, `standings/:competitionSlug`, `team/:teamSlug`, `club-zone`, `fan-id`, `social`, `privacy` |
| Settings | `/settings` tab, `edit-profile`, `notifications`, `privacy` |
| Onboarding | `/splash`, `/onboarding`, `/auth/phone`, `/auth/otp` |
| Live | `/live`, `/live/news/:articleId`, `/live-match` redirect |
| Challenge | `/challenge`, `/challenge/create`, `/challenge/my`, `/challenge/:id` |
| Membership | `/membership`, `/membership/fans`, `/membership/tier/:tierId` |
| Contributions | `/contribute`, `/contribute/projects`, `/contribute/groups`, `/contribute/group/:groupId`, `/contribute/group/:groupId/statement` |
| Ticketing | `/tickets`, `/tickets/detail/:id`, `/tickets/map/:id`, `/my-tickets`, `/e-ticket/:id` |
| Fan Clubs | `/fan-clubs`, `/fan-clubs/:clubId` |
| Admin | Explicit internal mobile opt-in only: `/admin`, `/admin/cms`, `/admin/matches`, `/admin/contributions`, `/admin/notifications`, `/admin/sms-monitor`, `/admin/settle`, `/admin/challenges`, `/admin/competitions`, `/admin/features`, `/admin/features/:featureKey` |
| Shop | `/shop`, `/shop/cart`, `/shop/product/:productId` |

## Screen File Inventory

After cleanup there are 71 Flutter screen files under `packages/features`.

| Package | Screen files |
| --- | --- |
| `feat_admin` | `admin_dashboard_screen.dart`, `admin_route_guard.dart`, `challenge_ops_screen.dart`, `cms_content_manager_screen.dart`, `competition_manager_screen.dart`, `contributions_monitor_screen.dart`, `feature_detail_screen.dart`, `feature_manager_screen.dart`, `fixture_settlement_screen.dart`, `match_manager_screen.dart`, `push_notifications_screen.dart`, `sms_sync_monitor_screen.dart` |
| `feat_contributions` | `club_projects_screen.dart`, `contributions_hub_screen.dart`, `group_detail_screen.dart`, `groups_screen.dart`, `statement_download_screen.dart` |
| `feat_fan_clubs` | `fan_club_detail_screen.dart`, `fan_clubs_list_screen.dart` |
| `feat_gamification` | `badges_screen.dart`, `challenge_detail_screen.dart`, `challenge_feed_screen.dart`, `challenges_screen.dart`, `club_fan_zone_screen.dart`, `create_challenge_screen.dart`, `fan_id_screen.dart`, `fanzone_hub_screen.dart`, `fet_wallet_screen.dart`, `fixtures_browser_screen.dart`, `friend_challenge_screen.dart`, `friends_list_screen.dart`, `jackpot_challenge_screen.dart`, `leaderboard_screen.dart`, `league_hub_screen.dart`, `league_standings_screen.dart`, `match_detail_screen.dart`, `my_challenges_screen.dart`, `my_predictions_screen.dart`, `offers_screen.dart`, `prediction_detail_screen.dart`, `prediction_notifications_screen.dart`, `prediction_settlement_screen.dart`, `privacy_settings_screen.dart`, `rewards_store_screen.dart`, `share_card_generator_screen.dart`, `social_hub_screen.dart`, `streak_calendar_screen.dart`, `team_profile_screen.dart`, `token_history_screen.dart` |
| `feat_home` | `home_screen.dart` |
| `feat_live` | `live_match_screen.dart`, `news_article_screen.dart` |
| `feat_membership` | `fan_registry_screen.dart`, `membership_screen.dart`, `profile_screen.dart`, `tier_detail_screen.dart` |
| `feat_onboarding` | `onboarding_screen.dart`, `splash_screen.dart`, `supporter_phone_auth_screen.dart` |
| `feat_settings` | `edit_profile_screen.dart`, `notification_preferences_screen.dart`, `privacy_settings_screen.dart`, `settings_screen.dart` |
| `feat_shop` | `cart_screen.dart`, `product_detail_screen.dart`, `shop_screen.dart` |
| `feat_ticketing` | `e_ticket_qr_screen.dart`, `interactive_seat_map_screen.dart`, `match_detail_screen.dart`, `match_list_screen.dart`, `my_tickets_screen.dart` |

## Deleted Leftover Candidates

| Deleted file or route | Reason |
| --- | --- |
| `packages/features/feat_settings/lib/src/screens/profile_setup_screen.dart` | Compatibility-only `/profile_setup` surface. It was not part of the current WhatsApp number -> OTP onboarding flow and only repeated contribution guidance. |
| `SettingsModule.standaloneRoutes` `/profile_setup` | Removed with the stale screen so old onboarding/profile setup links no longer remain in the mobile app route table. |
| `packages/features/feat_gamification/lib/src/screens/onboarding_profile_setup_screen.dart` | Old onboarding-named profile setup surface under Fan Zone. It was only referenced by its own `/fanzone/onboarding-setup` route/export. |
| `FanzoneModule` `onboarding-setup` route | Removed with the stale screen. Current profile editing remains in Settings. |
| `packages/features/feat_admin/lib/src/screens/feature_management_screen.dart` | Duplicate, self-only Admin feature-management screen. The routed screen is `feature_manager_screen.dart`. |
| `apps/rayon_sports/web/src/lib/types-legacy.ts` | Dead legacy web type file with no imports. |
| `apps/rayon_sports/web/src/lib/data/public-legacy.test.ts` | Renamed to `public-fallback.test.ts` so the test name matches its actual fallback-data behavior. |
| Ignored generated artifacts | Removed `.DS_Store`, `apps/rayon_sports/web/coverage`, and `output/playwright/profile_clone`. |

## Retained Non-Leftovers

- `legacyBalanceGap` in FET wallet models is retained because it is an active
  backend compatibility field and appears in tests.
- Supabase migration files containing `legacy` text are retained as historical
  database migration records.
- `RevolutBorrowed` typography/design tokens are retained because they are the
  current approved mobile design-system direction in `docs/design.md`.

## Verification Notes

- Route/name scan after deletion found no `profile_setup`,
  `onboarding-setup`, `ProfileSetupScreen`, `OnboardingProfileSetupScreen`,
  `types-legacy`, `public-legacy`, `Twilio`, or old OTP screen labels in active
  source/docs, excluding historical migration/test numeric fixtures.
- A screen reference pass found no remaining self-only screen files after
  deleting `feature_management_screen.dart`.
