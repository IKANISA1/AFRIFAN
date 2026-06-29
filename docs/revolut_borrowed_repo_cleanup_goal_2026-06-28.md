# AFRICLUB Repo-Wide Revolut-Borrowed Cleanup Goal - 2026-06-28

## Objective

Refactor AFRICLUB so every Flutter app, shared package, feature surface, test
fixture, and design document follows the Revolut-borrowed/Mobi/COOL/Collect UI
system without contradictory typography, shell, surface, navigation, or asset
patterns.

## Reference Inputs

- `/Volumes/PRO-G40/COOL/docs/design/DESIGN_SYSTEM.md`
- `/Volumes/PRO-G40/COOL/docs/design/REVOLUT10_SCREENSHOT_ROUTE_REVIEW_MATRIX_2026-06-27.md`
- `/Volumes/PRO-G40/COOL/docs/release/COLLECT_PREMIUM_MOBILE_FRONTEND_COMPLETION_REPORT_2026-06-27.md`
- `/Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/mobi_top_command_bar.dart`
- `/Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/mobi_bottom_nav.dart`
- `/Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/mobi_surface_panel.dart`
- `/Volumes/PRO-G40/COLLECT SCREENS/collect_complete_screen_map.md`

## Enforcement Rules

1. `docs/design.md` is the only written UI/UX source of truth.
2. `core_theme` is the only Flutter visual-token and component source of truth.
3. Typography must use bundled `RevolutBorrowed` from `core_theme`.
4. Feature packages must not ship local external-font fixtures.
5. Feature packages must not introduce direct negative letter spacing.
6. Old non-borrowed design-system wording must be removed from active docs or reduced to backwards-compatible code aliases only.
7. Route backgrounds must use `ColorTokens.screenGradientForPath`.
8. Main navigation must use the shared black-glass top and bottom chrome.

## Current Cleanup Slice

- Removed external-font runtime usage from `core_theme`, `core_app`, and feature tests.
- Removed feature-local test font asset declarations.
- Deleted tracked legacy feature and Rayon font assets.
- Replaced direct `Display` and `monospace` font-family overrides with `TypographyTokens.borrowedFontFamily`.
- Removed negative letter spacing from the scanned source hits.
- Replaced legacy design docs with the canonical borrowed-system `docs/design.md`.
- Removed the old shared surface/button API family from authored source:
  surface calls now use `AfriSurfaceCard`, panel calls now use
  `AfriPanelCard`, button calls now use `AfriButton`, and the home match strip
  is now `borrowed_match_strip.dart`.
- Added a source guardrail that fails tests if removed legacy surface/button
  names return to packages/apps.
- Centralized feature/app gradient construction through `ColorTokens`
  borrowed helpers, including surface tint, image scrim, and product fallback
  gradients.
- Added a source guardrail that fails tests if feature packages or apps
  construct local `LinearGradient`, `RadialGradient`, or `SweepGradient`
  instances.
- Added `AfriAppBar` as the shared borrowed route chrome wrapper and migrated
  direct feature/app `appBar: AppBar(...)` route usage to it.
- Added `AfriSliverAppBar` as the shared borrowed sliver chrome wrapper and
  migrated the remaining four feature hero sliver routes to it.
- Added a source guardrail that fails tests if direct route-level
  `appBar: AppBar(...)` or `SliverAppBar(...)` usage returns to feature
  packages or apps.
- Added shared `AfriTextButton`, `AfriOutlinedButton`, and
  `AfriElevatedButton` compatibility primitives, then migrated direct feature
  and app `TextButton`, `OutlinedButton`, and `ElevatedButton` constructors to
  the shared wrappers.
- Added a source guardrail that fails tests if direct platform button widgets
  return to feature packages or apps.
- Added borrowed-paper color tokens (`ColorTokens.borrowedPaper`,
  `ColorTokens.borrowedInk*`, and `ColorTokens.transparent`) for Revolut-style
  ticket/pass/card surfaces, then migrated the borrowed match strip, fan-club
  cards, and e-ticket QR pass away from raw `Colors.white`/`Colors.black`
  literals.
- Added a source guardrail that fails tests if raw `Colors.*` returns to the
  migrated borrowed-paper widgets.
- Replaced feature/app `Colors.transparent` usages with
  `ColorTokens.transparent` and added a source guardrail that prevents raw
  transparent colors from returning outside `core_theme`.
- Removed the remaining real feature/app `Colors.*` usages by routing dark
  foregrounds, dividers, shadows, status colors, warning chips, borrowed-card
  ink, and pass text through `ColorTokens`.
- Replaced the narrower raw-color guardrails with a repo-wide source guardrail
  that fails tests if any direct Flutter `Colors.*` usage returns to
  feature/app UI. Existing `ExternalBrandColors` references remain allowed
  because they are centralized in `core_theme`.
- Added shared `AfriChip` and `AfriChoiceChip` primitives for compact filters
  and metadata, then migrated all direct feature/app `ChoiceChip` and `Chip`
  constructors to the shared wrappers.
- Added a source guardrail that fails tests if direct Material chip widgets
  return to feature/app UI.
- Added shared `AfriListTile` and `AfriSwitchListTile` compatibility
  primitives, then migrated the remaining direct feature/app `ListTile` and
  `SwitchListTile` usages to the shared wrappers.
- Added a source guardrail that fails tests if direct Material list/toggle rows
  return to feature/app UI.

## 2026-06-28 Borrowed Onboarding Toast Migration Slice

- Migrated the onboarding entry flow away from direct Material snackbar
  feedback. Anonymous-session failures in
  `packages/features/feat_onboarding/lib/src/screens/onboarding_screen.dart`
  now route through `AfriToast.error`.
- Migrated WhatsApp phone-auth and OTP feedback in
  `packages/features/feat_onboarding/lib/src/screens/supporter_phone_auth_screen.dart`
  to shared borrowed toasts: validation/auth failures use `AfriToast.error`,
  while successful OTP resend confirmation uses `AfriToast.success`.
- Expanded the `Migrated packages use shared toast primitives` source
  guardrail to include `packages/features/feat_onboarding` alongside
  contributions and settings, preventing raw `ScaffoldMessenger.of`,
  `showSnackBar`, or `SnackBar` from returning to the migrated packages.
- Production scan result:
  `rg -n "ScaffoldMessenger\.of|\bSnackBar\b|showSnackBar|SnackBarAction" packages/features/feat_onboarding -g '*.dart' -g '!**/test/**'`
  returns no hits.
- Focused analyzer gate passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_onboarding`
  exits 0. Output still includes existing nonfatal `core_theme` info-level
  lint/debt items such as discarded futures and directive ordering.
- Focused tests passed:
  `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart packages/features/feat_onboarding/test/onboarding_flow_test.dart packages/features/feat_onboarding/test/onboarding_module_test.dart packages/features/feat_onboarding/test/supporter_phone_auth_screen_test.dart`
  passed 46/46 tests, including the expanded migrated-package toast guardrail.
- Drift and whitespace guardrails passed after the report update:
  `bash tools/scripts/rayon_mobile_design_drift_report.sh --fail-on-findings`
  reports 0 total findings, and `git diff --check` is clean.

## 2026-06-28 Borrowed Ticketing Toast And Golden Stabilization Slice

- Migrated ticket purchase feedback in
  `packages/features/feat_ticketing/lib/src/screens/match_detail_screen.dart`
  away from direct Material `ScaffoldMessenger` and `SnackBar` usage.
  Guest sign-in guidance now uses `AfriToast.info`, MOMO setup/dialer and
  reservation failures use `AfriToast.error`, and successful ticket requests
  use `AfriToast.success`.
- Expanded the `Migrated packages use shared toast primitives` guardrail to
  include `packages/features/feat_ticketing` alongside contributions,
  onboarding, and settings. The guardrail now catches `ScaffoldMessenger.of`,
  `showSnackBar`, `SnackBar`, and `SnackBarAction` in migrated packages.
- Fixed a shared button typography leak in
  `packages/core/core_theme/lib/src/widgets/afri_button.dart`: `AfriButton`
  now renders labels through `TypographyTokens.labelLarge` instead of ambient
  Material `ThemeData` text styles, keeping borrowed font and zero tracking in
  golden/test paths and production surfaces.
- Stabilized the ticketing golden fixture in
  `packages/features/feat_ticketing/test/match_list_golden_test.dart` by
  replacing the expired April 18, 2026 fixture with a far-future April 18, 2099
  fixture and restoring the intended `Rayon Sports vs APR` card state. The
  previous fixture had aged into the past as of June 28, 2026, causing the
  upcoming tab to render blank.
- Regenerated only the ticketing match-list golden:
  `flutter test --update-goldens packages/features/feat_ticketing/test/match_list_golden_test.dart`
  passed 1/1 and produced a visible borrowed ticket card with readable
  `AfriButton` typography.
- Production scan result:
  `rg -n "ScaffoldMessenger\.of|\bSnackBar\b|showSnackBar|SnackBarAction" packages/features/feat_ticketing packages/features/feat_onboarding packages/features/feat_contributions packages/features/feat_settings -g '*.dart' -g '!**/test/**'`
  returns no hits in the migrated packages.
- Focused analyzer gate passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_ticketing`
  exits 0. Output still includes existing nonfatal info-level lint/debt items
  such as discarded futures and directive ordering.
- Focused tests passed:
  `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart packages/features/feat_ticketing/test/ticketing_module_test.dart packages/features/feat_ticketing/test/match_list_golden_test.dart`
  passed 34/34 tests, including the expanded migrated-package toast guardrail
  and the stabilized ticketing golden.
- Drift and whitespace guardrails passed after the report update:
  `bash tools/scripts/rayon_mobile_design_drift_report.sh --fail-on-findings`
  reports 0 total findings, and `git diff --check` is clean.

## 2026-06-28 Borrowed Fan Clubs Toast Migration Slice

- Migrated fan-club join/leave and share-link feedback in
  `packages/features/feat_fan_clubs` away from direct Material snackbar
  usage. Join/leave failures in list and detail screens now use
  `AfriToast.error`, while copied share links use `AfriToast.success`.
- Expanded the `Migrated packages use shared toast primitives` guardrail to
  include `packages/features/feat_fan_clubs` alongside contributions,
  onboarding, settings, and ticketing.
- Production scan result:
  `rg -n "ScaffoldMessenger\.of|\bSnackBar\b|showSnackBar|SnackBarAction" packages/features/feat_fan_clubs packages/features/feat_ticketing packages/features/feat_onboarding packages/features/feat_contributions packages/features/feat_settings -g '*.dart' -g '!**/test/**'`
  returns no hits in the migrated packages.
- Focused analyzer gate passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_fan_clubs`
  exits 0. Output still includes existing nonfatal info-level lint/debt items
  such as discarded futures and directive ordering.
- Focused tests passed:
  `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart packages/features/feat_fan_clubs/test/fan_clubs_module_test.dart packages/features/feat_fan_clubs/test/fan_clubs_results_test.dart packages/features/feat_fan_clubs/test/fan_club_matchday_agenda_section_test.dart`
  passed 38/38 tests, including the expanded migrated-package toast guardrail.
- Drift and whitespace guardrails passed after the report update:
  `bash tools/scripts/rayon_mobile_design_drift_report.sh --fail-on-findings`
  reports 0 total findings, and `git diff --check` is clean.

## 2026-06-28 Borrowed Membership And Live Toast Migration Slice

- Migrated membership and live-match feedback away from direct Material
  snackbars. Fan-registry pagination failures now use `AfriToast.error`;
  membership activation states now route through explicit `AfriToast.info`,
  `AfriToast.success`, or `AfriToast.error` helpers; copied membership details
  use `AfriToast.success`; live match-share copy confirmation uses
  `AfriToast.success`.
- Expanded the `Migrated packages use shared toast primitives` guardrail to
  include `packages/features/feat_membership` and
  `packages/features/feat_live` alongside contributions, fan clubs,
  onboarding, settings, and ticketing.
- Production scan result:
  `rg -n "ScaffoldMessenger\.of|\bSnackBar\b|showSnackBar|SnackBarAction" packages/features/feat_membership packages/features/feat_live packages/features/feat_fan_clubs packages/features/feat_ticketing packages/features/feat_onboarding packages/features/feat_contributions packages/features/feat_settings -g '*.dart' -g '!**/test/**'`
  returns no hits in the migrated packages.
- Focused analyzer gate passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_membership packages/features/feat_live`
  exits 0. Output still includes existing nonfatal info-level lint/debt items
  such as discarded futures, directive ordering, and pre-existing membership
  const suggestions.
- Focused tests passed:
  `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart packages/features/feat_membership/test/membership_module_test.dart packages/features/feat_membership/test/fan_registry_results_test.dart packages/features/feat_membership/test/contribution_history_test.dart packages/features/feat_live/test/live_module_test.dart packages/features/feat_live/test/live_match_fallback_test.dart`
  passed 50/50 tests, including the expanded migrated-package toast guardrail.
- Drift and whitespace guardrails passed after the report update:
  `bash tools/scripts/rayon_mobile_design_drift_report.sh --fail-on-findings`
  reports 0 total findings, and `git diff --check` is clean.

## 2026-06-28 Borrowed Shop Toast And Action Migration Slice

- Extended `AfriToast` with optional `actionLabel` and `onAction` support so
  feature packages can preserve short snackbar actions, such as `View Cart`,
  without owning raw Material `SnackBarAction` usage.
- Migrated shop catalog, product detail, and cart checkout feedback away from
  direct Material snackbars. Add-to-cart and order-created states use
  `AfriToast.success`; validation prompts such as missing size/address use
  `AfriToast.info`; stock, MOMO, setup, and checkout failures use
  `AfriToast.error`.
- Preserved the product-detail `View Cart` action through the shared
  `AfriToast.success(..., actionLabel: 'View Cart', onAction: ...)` API.
- Expanded the `Migrated packages use shared toast primitives` guardrail to
  include `packages/features/feat_shop` alongside contributions, fan clubs,
  live, membership, onboarding, settings, and ticketing.
- Production scan result:
  `rg -n "ScaffoldMessenger\.of|\bSnackBar\b|showSnackBar|SnackBarAction" packages/features/feat_shop packages/features/feat_membership packages/features/feat_live packages/features/feat_fan_clubs packages/features/feat_ticketing packages/features/feat_onboarding packages/features/feat_contributions packages/features/feat_settings -g '*.dart' -g '!**/test/**'`
  returns no hits in the migrated packages.
- Focused analyzer gate passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_shop`
  exits 0. Output still includes existing nonfatal info-level lint/debt items
  such as discarded futures, directive ordering, and pre-existing shop
  noop/const suggestions.
- Focused tests passed:
  `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart packages/features/feat_shop/test/shop_module_test.dart packages/features/feat_shop/test/shop_cart_provider_test.dart packages/features/feat_shop/test/shop_screen_catalog_test.dart packages/features/feat_shop/test/checkout_bar_test.dart`
  passed 46/46 tests, including the expanded migrated-package toast guardrail.
- Drift and whitespace guardrails passed after the report update:
  `bash tools/scripts/rayon_mobile_design_drift_report.sh --fail-on-findings`
  reports 0 total findings, and `git diff --check` is clean.
- Replaced remaining direct feature/app `style: TextStyle(...)` constructors
  with `TypographyTokens` calls, including borrowed-paper badges, ticket pass
  metadata, cart counters, and decorative glyph sizing.
- Added a source guardrail that fails tests if direct feature/app
  `TextStyle(...)` constructors return.
- Migrated the fixture browser widgets away from feature-local raw typography
  sizes by using semantic `TypographyTokens`, `AfriMetricTile`,
  `AfriChoiceChip`, `AfriInfoChip`, and compact borrowed helper primitives for
  fixture dots, scores, and action pills.
- Updated `AfriMetricTile` so its `accentColor` applies to the primary value,
  preserving positive metric emphasis when feature overview cards move to the
  shared primitive.
- Migrated team-profile shared widgets away from direct feature-local
  typography sizes by using `AfriMetricTile`, `AfriPanelCard`,
  `AfriInfoChip`, and semantic `TypographyTokens` for mini stats, tier counts,
  contributor rows, step markers, and about rows.
- Migrated the membership profile screen away from direct typography sizes by
  using semantic `TypographyTokens`, shared `AfriListRow` menu rows, and
  borrowed token helpers for the profile avatar and tier badge.
- Migrated the inline match card away from direct typography sizes by using
  semantic `TypographyTokens`, `AfriInfoChip` for live state, tokenized team
  avatars, and shared shape tokens for prediction option pills.
- Migrated the team profile tab surfaces away from direct typography sizes by
  using semantic label, title, metric, and inline action text helpers for
  contribution routes, standings headings, members headings, fixture CTAs, and
  about/contribute section titles.
- Migrated leaderboard shared widgets away from direct typography sizes by
  using semantic headline/title helpers for podium ranks, FET totals, pinned
  rows, and standard rank rows.
- Migrated match statistics, lineup, and H2H shared widgets away from direct
  typography sizes by using semantic metric, label, title, and headline helpers
  for comparison labels, formation chips, empty states, score summaries, and
  encounter rows.
- Replaced raw Material empty-state icons in lineup and H2H widgets with
  semantic `AfriIcons` entries.
- Migrated the prediction share card away from direct typography sizes by using
  semantic label, title, and headline helpers for competition/status pills,
  team names, scores, metrics, and the share footer.
- Migrated the FET split model away from direct typography sizes by using
  semantic section, metric, label, and title helpers for progress labels,
  membership rows, and split ratios.
- Replaced the FET split model's remaining inline emoji/info glyph with the
  semantic `AfriIcons.statusInfo` icon.
- Migrated the prediction settlement screen away from direct typography sizes
  by using semantic headline, display, label, and title helpers for the route
  heading, settlement hero, score/date value, timeline label, metrics, and
  timeline rows.
- Migrated the Fan ID screen away from direct typography sizes by using
  semantic headline, display, metric, label, and title helpers for app chrome,
  Fan ID labels, privacy/identity section headings, badges, and numbered rules.
- Replaced the Fan ID screen's decorative football text glyph with the
  semantic `AfriIcons.fanzone` icon.
- Migrated the fan club detail screen away from direct typography sizes and raw
  Material icons by using semantic `AfriIcons`, display/headline/title helpers,
  and shared token colors for hero chrome, status pills, section headings,
  matchday agenda, and detail stats.
- Migrated the league hub screen away from direct typography sizes by using
  semantic headline/title helpers for app chrome, competition hero text,
  fixture status labels, league metrics, standing ranks, and points.
- Migrated the challenge detail flow and MoMo contribution surfaces away from
  direct typography sizes and raw Material icons by using semantic
  title/headline/display/metric helpers, `AfriIcons`, and shared accent tokens
  for score controls, settlement labels, contribution amounts, USSD copy, and
  payment status dialogs.
- Migrated repeated challenge, top-scorer, membership-card, prediction-slip,
  social-hub, and group-detail surfaces away from direct typography sizes by
  using semantic labels, headlines, display values, metric labels, and shared
  accent tokens for card identity, slip totals, leaderboard ranks, contribution
  totals, ledger rows, score chips, and compact stat badges.
- Migrated settings overlays, full digital membership cards, fan registry,
  home match cards, borrowed match strips, market selector, jackpot countdown,
  fanzone hub widgets, and privacy settings away from direct typography sizes
  and raw Material icons by using semantic display/headline/title/metric
  helpers, `AfriIcons`, and shared token colors for dialog headings, Fan ID
  cards, registry rows, match posters, odds filters, countdown digits, and
  privacy section headers.
- Migrated gamification prediction, match detail, jackpot, create challenge,
  and club fan zone screens plus tier detail, gamification overlay, and FET arc
  surfaces away from direct typography sizes, raw Material icons, and theme
  primary lookups by using semantic headline/display/title/metric helpers,
  `AfriIcons`, and shared club accent/primary tokens for route chrome, score
  steppers, prize pools, leaderboard rows, tier hero copy, level-up modals, and
  FET balances.
- Cleared the remaining feature/app direct typography backlog by migrating the
  token history, team profile, streak calendar, onboarding profile setup,
  league standings, FET wallet, challenges, fan club cards, contribution
  ledger/group/project/statement surfaces, ticket QR/purchase surfaces, shop
  search, settings/admin dialogs, live match widgets, badge grid, auth gate,
  market option, reward/prediction/challenge screens, and admin feature
  management/detail rows to semantic `TypographyTokens`, `AfriIcons`, and
  shared accent/status colors.
- Cleared the remaining feature/app raw Material icon and theme-primary color
  backlog by migrating shop/cart/product details, ticket wallet states, admin
  dashboards, SMS pipeline, CMS cards, competition/fixture operations, push
  notifications, membership profile menus, settings setup, community prediction
  markers, fan-club detail, and latest-intel cards to `AfriIcons` plus
  `ColorTokens.clubAccent`.
- Migrated shared-package fallback UI into the borrowed system by routing the
  `core_network` offline banner, `core_feature_config` disabled-feature
  fallback, and `core_router` unavailable/error routes through `core_theme`
  dependencies, `AfriStateView`, `AfriIcons`, `TypographyTokens`,
  `SpacingTokens`, and `ColorTokens`.
- Cleared the remaining shared-package non-rendered visual exceptions by
  routing `core_utils` fan-tier and FET-event icon getters through `AfriIcons`,
  moving core app test fixtures to borrowed token colors/icons, and replacing
  startup device-chrome transparency with `ColorTokens.transparent`.
- Repaired the core route/deep-link fixtures to match production routing
  contracts after the borrowed-system migration: fake onboarding routes now
  declare public splash/onboarding paths, fake settings renders as a bottom-tab
  module, and the compact borrowed unavailable/error state no longer overflows
  in guard tests.
- Replaced remaining test-fixture club color literals in app registry, Rayon
  shell, core app, and settings tests with borrowed `ColorTokens` reference
  colors, then added a guardrail that prevents raw `Color(...)` values from
  returning to test `ClubColors` fixtures.
- Superseded stale Rayon-specific audit/readiness docs and retargeted the
  screen inventory to the active repo-wide cleanup report so old claims about
  missing governance files, raw typography, colors, gradients, and emoji
  cleanup do not contradict the current borrowed-system migration.
- Continued the Rayon mobile empty-section cleanup by hiding the Challenge Feed
  empty list section when no challenge pools exist while preserving the create
  challenge action. The source-only Rayon drift report is now down to 91 total
  findings, with visible placeholder/empty-section copy down to 20.
- Continued the Rayon mobile empty-section cleanup by hiding the Share Card
  Generator empty prediction panel when there are no settled predictions,
  extracting `ShareCardGeneratorContent` for focused empty and populated widget
  coverage. The source-only Rayon drift report is now down to 90 total
  findings, with visible placeholder/empty-section copy down to 19.
- Continued the Rayon mobile empty-section/accessibility cleanup by hiding the
  Streak zero-activity empty copy while preserving the metric surface,
  extracting `StreakCalendarContent` for focused empty and active widget
  coverage, and adding semantic labels to the streak heat-map cells so activity
  is not color-only. The current source-only Rayon drift report is down to 77
  total findings, with visible placeholder/empty-section copy down to 18 and
  emoji codepoint findings down to 0 in the current worktree.
- Continued the Rayon mobile Fan Zone empty-section cleanup by extracting
  `FriendSupportersSection` and hiding the friends/results section entirely
  when there are no friends or search matches. Focused widget coverage now
  verifies empty friends, empty search results, and populated supporter-row
  action behavior. The current source-only Rayon drift report is down to 62
  total findings, with visible placeholder/empty-section copy down to 17 in the
  current worktree.
- Continued the Rayon mobile Social Hub empty-section cleanup by extracting
  `SocialHubFriendsSection` and `SocialHubLeaderboardSection`, hiding empty
  friend-result and leaderboard sections entirely while preserving populated
  friend challenge rows and current-user leaderboard highlighting. Focused
  widget coverage now verifies empty and populated paths for both sections. The
  current source-only Rayon drift report is down to 39 total findings, with
  visible placeholder/empty-section copy down to 15 in the current worktree.
- Refreshed stale app-registry and settings test expectations after the
  borrowed routing/settings migration: fanzone journey tests now assert nested
  tab routes directly, settings copy follows the current support/privacy rows,
  the settings golden was regenerated, and `SettingsModule.tabRoute` tests no
  longer carry obsolete nullability assertions.
- Removed a remaining settings feature theme-primary lookup by routing the edit
  profile avatar surface through `ColorTokens.clubAccent` and shared shape
  tokens.
- Replaced the three remaining non-locked admin `GestureDetector` controls
  with `AfriPressFeedback`, adding tooltips and semantics for date/time,
  half-time score, and feature-tile actions. The only raw gesture left in the
  Rayon drift report is the product-locked Home hero file, which still needs an
  owner-approved hero pass before changing its widget tree.
- Removed emoji codepoints from authored feature source by dropping unused Home
  quick-action fallback emoji defaults and making admin partner emoji defaults
  optional instead of hardcoded.
- Removed all direct `Navigator.*` usage from `feat_settings` by routing modal,
  sheet, dialog, and settings-child back behavior through GoRouter
  `context.pop`, `context.canPop`, and `context.go` calls while preserving the
  existing confirmation return values.
- Removed all direct `Navigator.*` usage from `feat_gamification` by routing
  prediction slips, auth gates, market selectors, challenge confirmations,
  wallet confirmations, team profile dialogs, offer sheets, onboarding exits,
  and level/badge modals through GoRouter `context.pop`, `context.canPop`, and
  captured-router pushes while preserving the existing typed sheet/dialog
  return values.
- Removed the remaining feature-package direct `Navigator.*` usage from admin,
  contributions, membership, shop, and ticketing surfaces by routing match
  composer saves, competition/season editors, settlement dialogs, checkout
  confirmations, MoMo sheets, SMS permission dialogs, contribution
  confirmations, and ticketing purchase confirmations through GoRouter
  `context.pop` while preserving typed sheet/dialog return values.
- Continued the Rayon mobile Team Profile contribution-route cleanup by hiding
  overview and contribution-tab route placeholders when no active route exists,
  preserving populated MoMo route instructions, and replacing the route-null
  fallback toast with concise support copy. Focused widget coverage now
  verifies missing-route and populated-route behavior for both overview and
  contribution tabs.
- Continued the Rayon mobile Contributions Group Detail cleanup by extracting
  the ledger section and hiding the entire ledger header/body when there are no
  recorded contribution rows. Focused widget coverage now verifies the empty
  ledger renders nothing and populated ledger rows still render aliases,
  amounts, and status text.
- Continued the Rayon mobile Fan Club Detail cleanup by extracting the
  matchday agenda section and hiding the entire agenda card when the chapter is
  inactive or no linked upcoming match exists. Focused widget coverage now
  verifies inactive, missing-match, and populated matchday agenda states.
- Removed shared-core direct `Navigator.*` defaults by routing
  `core_theme` action sheets, filter sheets, kill-switch fallbacks, shared
  screen scaffolds, and `core_feature_config` disabled-feature fallback actions
  through GoRouter `context.pop`/`context.canPop`. `core_theme` and
  `core_feature_config` now declare GoRouter directly because their shared UI
  primitives own navigation chrome behavior.
- Revalidated the touched UI slice with focused Flutter tests, a legacy-name
  source scan, a raw-font/negative-letter-spacing scan, and analyzer over the
  touched core/feature packages.

## Remaining Work

- Continue migrating any remaining bespoke surface treatments to
  `AfriSurfaceCard`, `AfriPanelCard`, `GlassCard`, and shared button
  primitives.
- Continue migrating remaining bespoke card/nav treatments now that direct
  feature/app `Colors.*` usage is guarded.
- Continue replacing bespoke handmade row/card compositions with
  higher-level shared primitives now that direct Material list/toggle rows are
  guarded.
- Continue reducing token `.copyWith(fontSize: ...)` overrides into semantic
  typography helpers if any are reintroduced. Current guarded source inventory
  is down to 0 feature/app direct font-size override hits after the fixture
  browser, team-profile widget/tab, membership profile screen, inline match
  card, leaderboard, stats, lineup, H2H, prediction share card, FET split
  model, prediction settlement, Fan ID, fan club detail, league hub, challenge
  detail, MoMo contribution, challenge card, top scorers, membership card,
  prediction slip, social hub, group detail, settings overlays, digital
  membership card, fan registry, home match card, borrowed match strip, market
  selector, jackpot countdown, fanzone hub widget, privacy settings,
  prediction detail, match detail, jackpot challenge, create challenge, club
  fan zone, tier detail, gamification overlay, FET arc, contribution, ticketing,
  shop, live, fan club, and admin cleanup migrations.
- Continue expanding the borrowed-paper/raw-color guardrail as additional
  shared-package files are migrated to core tokens. Current guarded source
  inventory is down to 0 feature/app raw Material icon hits and 0 feature/app
  theme-primary color lookup hits after the admin, shop, ticketing, membership,
  home, fan-club, settings, and gamification icon/color cleanup pass.
- Current guarded core-package inventory outside `core_theme` is down to 0 raw
  Material icon hits, 0 raw `Colors.*` hits, 0 direct `TextStyle` hits, 0 local
  gradient constructor hits, and 0 theme-primary color lookup hits.
- Current focused core validation is green: the combined design-system,
  domain-type, bootstrap, route-guard, and deep-link test bundle passed 53/53,
  and the route/deep-link tests passed independently after fixture alignment.
- Current test-fixture ClubColors inventory is down to 0 raw `Color(...)`
  values in test color fields across `packages` and `apps`.
- Current feature/app/theme-primary inventory outside `core_theme` is down to
  0 direct `Theme.of(context).colorScheme.primary` or `primaryColor` hits.
- Current Rayon source-only drift report is down to 0 total findings across the
  scripted categories: 0 raw `TextStyle`, 0 small font sizes, 0 raw
  Material/direct hex colors, 0 raw gestures, 0 direct `Navigator` hits,
  0 hardcoded `Image.network`, 0 local gradients, 0 direct Material buttons,
  0 visible placeholder/empty-section copy hits, and 0 emoji codepoints.
- Stale Rayon-specific audit/readiness material is superseded and redirects to
  this report plus `docs/design.md` and `docs/screen_inventory.md`.
- Refresh goldens after the borrowed typography and deleted font fixtures settle.
- Extend source guardrails to block stale design docs and bespoke card/nav
  treatments.
- Capture mobile route screenshots for the Rayon shell after analyzer and focused tests pass.

## Validation Gates

- `flutter test packages/core/core_app/test/app_routing_guard_test.dart packages/core/core_app/test/app_deep_link_test.dart`
  passed.
- `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart packages/core/core_utils/test/domain_types_test.dart packages/core/core_app/test/bootstrap_architecture_test.dart packages/core/core_app/test/app_routing_guard_test.dart packages/core/core_app/test/app_deep_link_test.dart`
  passed 53/53.
- `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_utils packages/core/core_app packages/core/core_theme`
  exited 0 with 23 existing info-level findings.
- `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart packages/app_registry/test/module_registry_test.dart packages/app_registry/test/navigation_journeys_test.dart packages/core/core_app/test/bootstrap_architecture_test.dart packages/core/core_app/test/app_routing_guard_test.dart packages/features/feat_settings/test/settings_screens_test.dart apps/rayon_sports/test/rayon_sports_shell_navigation_test.dart`
  passed 50/50.
- `flutter test packages/features/feat_settings/test/settings_module_test.dart packages/features/feat_settings/test/settings_screens_test.dart`
  passed 12/12 after the settings golden refresh.
- `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/app_registry packages/core/core_app packages/features/feat_settings apps/rayon_sports`
  exited 0 with 20 existing core_theme info-level findings.
- `flutter analyze --no-fatal-infos --no-fatal-warnings packages/features/feat_admin packages/features/feat_home`
  exited 0 with existing nonfatal admin/home analyzer debt.
- `flutter test packages/features/feat_home/test/home_content_repository_test.dart packages/features/feat_home/test/home_widgets_test.dart packages/features/feat_admin/test/admin_module_test.dart`
  passed 14/14.
- `flutter test packages/features/feat_admin/test/admin_module_test.dart`
  passed 7/7.
- Source scans for raw core-package visual exceptions outside `core_theme`
  returned 0 hits.
- Source scans for raw `Color(...)` in test `ClubColors` fixture fields across
  `packages` and `apps` returned 0 hits.
- Source scans for stale Rayon audit phrases and feature/app theme-primary
  lookups returned 0 hits.
- Source scans for emoji codepoints in authored feature/app Dart source
  returned 0 hits; raw gesture scans now return only the locked Home hero hit.
- `git diff --check` and `git diff --numstat -- pubspec.lock` are clean.
- `dart analyze packages/features/feat_gamification/lib/src/screens/challenge_feed_screen.dart packages/features/feat_gamification/test/challenge_feature_test.dart`
  passed with no issues under the mounted Flutter 3.44.3 Dart SDK.
- Focused Challenge Feed widget tests passed:
  `feed hides challenge list section when no pools are available` and
  `feed renders featured, open, mine, and settled sections`.
- `flutter analyze --no-pub` from `apps/rayon_sports` passed with no issues in
  91.9s under the mounted Flutter 3.44.3 SDK.
- `flutter test --no-pub test` from `apps/rayon_sports` passed 12/12 under the
  mounted Flutter 3.44.3 SDK.
- `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 91 total
  findings: 0 raw `TextStyle`, 0 small font-size, 0 raw Material/direct hex
  color, 4 raw `GestureDetector`, 58 direct `Navigator`, 0 hardcoded
  `Image.network`, 0 local gradient, 0 direct Material button, 20 visible
  placeholder/empty-section copy, and 9 emoji codepoint findings.
- Full `challenge_feature_test.dart` remains unsuitable as a slice gate under
  the mounted SDK because the unrelated My Challenges tab test hits an existing
  shader asset runtime-stage mismatch; the touched Challenge Feed tests passed
  independently.
- `flutter analyze --no-pub packages/features/feat_gamification/lib/src/screens/share_card_generator_screen.dart packages/features/feat_gamification/test/share_card_generator_screen_test.dart`
  passed with no issues under the mounted Flutter 3.44.3 SDK.
- `flutter test --no-pub packages/features/feat_gamification/test/share_card_generator_screen_test.dart`
  passed 2/2 under the mounted Flutter 3.44.3 SDK.
- `flutter analyze --no-pub` from `apps/rayon_sports` passed with no issues in
  25.7s under the mounted Flutter 3.44.3 SDK after the Share Card slice.
- `flutter test --no-pub test` from `apps/rayon_sports` passed 12/12 under the
  mounted Flutter 3.44.3 SDK after the Share Card slice.
- `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 90 total
  findings after the Share Card slice: 0 raw `TextStyle`, 0 small font-size, 0
  raw Material/direct hex color, 4 raw `GestureDetector`, 58 direct
  `Navigator`, 0 hardcoded `Image.network`, 0 local gradient, 0 direct
  Material button, 19 visible placeholder/empty-section copy, and 9 emoji
  codepoint findings.
- `flutter analyze --no-pub packages/features/feat_gamification/lib/src/screens/streak_calendar_screen.dart packages/features/feat_gamification/test/streak_calendar_content_test.dart`
  passed with no issues under the mounted Flutter 3.44.3 SDK.
- `flutter test --no-pub packages/features/feat_gamification/test/streak_calendar_content_test.dart`
  passed 2/2 under the mounted Flutter 3.44.3 SDK.
- `flutter analyze --no-pub` from `apps/rayon_sports` passed with no issues in
  22.6s under the mounted Flutter 3.44.3 SDK after the Streak slice.
- `flutter test --no-pub test` from `apps/rayon_sports` passed 12/12 under the
  mounted Flutter 3.44.3 SDK after the Streak slice.
- `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 77 total
  findings after the Streak slice in the current worktree: 0 raw `TextStyle`, 0
  small font-size, 0 raw Material/direct hex color, 1 raw `GestureDetector`, 58
  direct `Navigator`, 0 hardcoded `Image.network`, 0 local gradient, 0 direct
  Material button, 18 visible placeholder/empty-section copy, and 0 emoji
  codepoint findings.
- `flutter test packages/features/feat_settings/test/settings_module_test.dart packages/features/feat_settings/test/settings_screens_test.dart packages/features/feat_settings/test/user_privacy_settings_test.dart`
  passed after the settings GoRouter navigation cleanup.
- `flutter analyze --no-fatal-infos --no-fatal-warnings packages/features/feat_settings`
  exited 0 with no issues after the settings GoRouter navigation cleanup.
- `rg -n "Navigator\\." packages/features/feat_settings -g '*.dart' -g '!**/test/**'`
  returned 0 hits after the settings GoRouter navigation cleanup.
- `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 62 total
  findings after the settings GoRouter navigation cleanup: 0 raw `TextStyle`,
  0 small font-size, 0 raw Material/direct hex color, 1 raw `GestureDetector`,
  44 direct `Navigator`, 0 hardcoded `Image.network`, 0 local gradient, 0
  direct Material button, 17 visible placeholder/empty-section copy, and 0
  emoji codepoint findings.
- `flutter analyze --no-pub packages/features/feat_gamification/lib/src/screens/friends_list_screen.dart packages/features/feat_gamification/test/friends_list_content_test.dart`
  passed with no issues under the mounted Flutter 3.44.3 SDK.
- `flutter test --no-pub packages/features/feat_gamification/test/friends_list_content_test.dart`
  passed 3/3 under the mounted Flutter 3.44.3 SDK.
- `flutter analyze --no-pub` from `apps/rayon_sports` passed with no issues in
  18.0s under the mounted Flutter 3.44.3 SDK after the Friends slice.
- `flutter test --no-pub test` from `apps/rayon_sports` passed 12/12 under the
  mounted Flutter 3.44.3 SDK after the Friends slice.
- `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 62 total
  findings after the Friends slice in the current worktree: 0 raw `TextStyle`,
  0 small font-size, 0 raw Material/direct hex color, 1 raw `GestureDetector`,
  44 direct `Navigator`, 0 hardcoded `Image.network`, 0 local gradient, 0
  direct Material button, 17 visible placeholder/empty-section copy, and 0
  emoji codepoint findings.
- `rg -n "Navigator\\." packages/features/feat_gamification -g '*.dart' -g '!**/test/**'`
  returned 0 hits after the gamification GoRouter navigation cleanup.
- `flutter analyze --no-fatal-infos --no-fatal-warnings packages/features/feat_gamification`
  exited 0 after the gamification GoRouter navigation cleanup; the package
  still reports existing nonfatal warning/info debt unrelated to this slice.
- `flutter test packages/features/feat_gamification/test/challenge_feature_test.dart --plain-name "create screen confirms submission and navigates to detail"`
  passed after the gamification GoRouter navigation cleanup.
- `flutter test packages/features/feat_gamification/test/challenge_module_test.dart packages/features/feat_gamification/test/fanzone_hub_screen_test.dart packages/features/feat_gamification/test/share_card_generator_screen_test.dart packages/features/feat_gamification/test/friends_list_content_test.dart`
  passed after rerunning sequentially; the first parallel attempt collided on
  Flutter native-asset code signing with a missing generated
  `objective_c.dylib`.
- A broader gamification test attempt including
  `packages/features/feat_gamification/test/fet_wallet_screen_test.dart`
  remains unsuitable as a slice gate until stale wallet expectations are
  refreshed for the current confirmation-gated wallet UI. The same broad run
  also reproduced the existing My Challenges shader runtime-stage mismatch.
- `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 39 total
  findings after the gamification GoRouter navigation cleanup: 0 raw
  `TextStyle`, 0 small font-size, 0 raw Material/direct hex color, 1 raw
  `GestureDetector`, 23 direct `Navigator`, 0 hardcoded `Image.network`, 0
  local gradient, 0 direct Material button, 15 visible placeholder/empty-section
  copy, and 0 emoji codepoint findings.
- `flutter analyze --no-pub packages/features/feat_gamification/lib/src/screens/social_hub_screen.dart packages/features/feat_gamification/test/social_hub_content_test.dart`
  passed with no issues under the mounted Flutter 3.44.3 SDK.
- `flutter test --no-pub packages/features/feat_gamification/test/social_hub_content_test.dart`
  passed 4/4 under the mounted Flutter 3.44.3 SDK.
- `flutter analyze --no-pub` from `apps/rayon_sports` passed with no issues in
  32.2s under the mounted Flutter 3.44.3 SDK after the Social Hub slice.
- `flutter test --no-pub test` from `apps/rayon_sports` passed 12/12 under the
  mounted Flutter 3.44.3 SDK after the Social Hub slice.
- `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 39 total
  findings after the Social Hub slice in the current worktree: 0 raw
  `TextStyle`, 0 small font-size, 0 raw Material/direct hex color, 1 raw
  `GestureDetector`, 23 direct `Navigator`, 0 hardcoded `Image.network`, 0
  local gradient, 0 direct Material button, 15 visible placeholder/empty-section
  copy, and 0 emoji codepoint findings.
- `rg -n "Navigator\\." packages/features -g '*.dart' -g '!**/test/**'`
  returned 0 hits after the remaining feature-package GoRouter navigation
  cleanup.
- `flutter analyze --no-fatal-infos --no-fatal-warnings packages/features/feat_admin packages/features/feat_membership packages/features/feat_contributions packages/features/feat_shop packages/features/feat_ticketing`
  exited 0 after the remaining feature-package GoRouter navigation cleanup;
  those packages still report existing nonfatal warning/info debt unrelated to
  this slice.
- `flutter test packages/features/feat_admin/test/admin_module_test.dart packages/features/feat_contributions/test/contribution_models_test.dart packages/features/feat_contributions/test/contributions_module_test.dart packages/features/feat_contributions/test/groups_screen_empty_state_test.dart packages/features/feat_membership/test/contribution_history_test.dart packages/features/feat_membership/test/fan_registry_results_test.dart packages/features/feat_membership/test/membership_module_test.dart packages/features/feat_shop/test/checkout_bar_test.dart packages/features/feat_shop/test/shop_cart_provider_test.dart packages/features/feat_shop/test/shop_module_test.dart packages/features/feat_shop/test/shop_screen_catalog_test.dart packages/features/feat_ticketing/test/ticketing_module_test.dart`
  passed after the remaining feature-package GoRouter navigation cleanup.
- `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 15 total
  findings after the remaining feature-package GoRouter navigation cleanup: 0
  raw `TextStyle`, 0 small font-size, 0 raw Material/direct hex color, 1 raw
  `GestureDetector`, 0 direct `Navigator`, 0 hardcoded `Image.network`, 0 local
  gradient, 0 direct Material button, 14 visible placeholder/empty-section
  copy, and 0 emoji codepoint findings.
- `flutter analyze --no-pub packages/features/feat_gamification/lib/src/screens/team_profile_screen.dart packages/features/feat_gamification/lib/src/widgets/team_profile_tabs.dart packages/features/feat_gamification/test/team_contribution_content_test.dart`
  passed with no issues under the mounted Flutter 3.44.3 SDK after the Team
  Profile contribution-route cleanup.
- `flutter test --no-pub packages/features/feat_gamification/test/team_contribution_content_test.dart`
  passed 4/4 under the mounted Flutter 3.44.3 SDK after the Team Profile
  contribution-route cleanup.
- `flutter analyze --no-pub` from `apps/rayon_sports` passed with no issues in
  16.0s under the mounted Flutter 3.44.3 SDK after the Team Profile
  contribution-route cleanup.
- `flutter test --no-pub test` from `apps/rayon_sports` passed 12/12 under the
  mounted Flutter 3.44.3 SDK after the Team Profile contribution-route cleanup.
- `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 15 total
  findings after the Team Profile contribution-route cleanup: 0 raw
  `TextStyle`, 0 small font-size, 0 raw Material/direct hex color, 1 raw
  `GestureDetector`, 0 direct `Navigator`, 0 hardcoded `Image.network`, 0 local
  gradient, 0 direct Material button, 14 visible placeholder/empty-section
  copy, and 0 emoji codepoint findings.
- `rg -n "Navigator\\." packages/core packages/features apps -g '*.dart' -g '!**/test/**'`
  returned 0 hits after the shared-core GoRouter navigation cleanup.
- `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/core/core_feature_config packages/core/core_router packages/core/core_app`
  exited 0 after the shared-core GoRouter navigation cleanup; the analyzed
  packages still report existing nonfatal warning/info debt unrelated to this
  slice.
- `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart packages/core/core_app/test/bootstrap_architecture_test.dart packages/core/core_app/test/app_routing_guard_test.dart packages/core/core_app/test/app_deep_link_test.dart`
  passed after the shared-core GoRouter navigation cleanup.
- `flutter test packages/core/core_feature_config/test/models_test.dart packages/core/core_feature_config/test/service_test.dart`
  passed after the shared-core GoRouter navigation cleanup.
- `git diff --check` and `git diff --numstat -- pubspec.lock` are clean after
  the shared-core GoRouter navigation cleanup; adding direct GoRouter package
  dependencies to `core_theme` and `core_feature_config` did not change the
  resolved lockfile.
- `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 14 total
  findings in the current worktree after the shared-core GoRouter navigation
  cleanup: 0 raw `TextStyle`, 0 small font-size, 0 raw Material/direct hex
  color, 1 raw `GestureDetector`, 0 direct `Navigator`, 0 hardcoded
  `Image.network`, 0 local gradient, 0 direct Material button, 13 visible
  placeholder/empty-section copy, and 0 emoji codepoint findings.
- `flutter analyze --no-pub packages/features/feat_contributions/lib/src/screens/group_detail_screen.dart packages/features/feat_contributions/test/group_detail_ledger_section_test.dart`
  passed with no issues under the mounted Flutter 3.44.3 SDK after the Group
  Detail ledger cleanup.
- `flutter test --no-pub packages/features/feat_contributions/test/group_detail_ledger_section_test.dart`
  passed 2/2 under the mounted Flutter 3.44.3 SDK after the Group Detail
  ledger cleanup.
- `flutter analyze --no-pub` from `apps/rayon_sports` passed with no issues in
  16.5s under the mounted Flutter 3.44.3 SDK after the Group Detail ledger
  cleanup.
- `flutter test --no-pub test` from `apps/rayon_sports` passed 12/12 under the
  mounted Flutter 3.44.3 SDK after the Group Detail ledger cleanup.
- `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 14 total
  findings after the Group Detail ledger cleanup: 0 raw `TextStyle`, 0 small
  font-size, 0 raw Material/direct hex color, 1 raw `GestureDetector`, 0 direct
  `Navigator`, 0 hardcoded `Image.network`, 0 local gradient, 0 direct Material
  button, 13 visible placeholder/empty-section copy, and 0 emoji codepoint
  findings.
- `flutter analyze --no-pub packages/features/feat_fan_clubs/lib/src/screens/fan_club_detail_screen.dart packages/features/feat_fan_clubs/test/fan_club_matchday_agenda_section_test.dart`
  passed with no issues under the mounted Flutter 3.44.3 SDK after the Fan
  Club Detail matchday agenda cleanup.
- `flutter test --no-pub packages/features/feat_fan_clubs/test/fan_club_matchday_agenda_section_test.dart`
  passed 3/3 under the mounted Flutter 3.44.3 SDK after the Fan Club Detail
  matchday agenda cleanup.
- `flutter analyze --no-pub` from `apps/rayon_sports` passed with no issues in
  28.4s under the mounted Flutter 3.44.3 SDK after the Fan Club Detail
  matchday agenda cleanup.
- `flutter test --no-pub test` from `apps/rayon_sports` passed 12/12 under the
  mounted Flutter 3.44.3 SDK after the Fan Club Detail matchday agenda cleanup.
- `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 0 total
  findings after the Fan Club Detail matchday agenda cleanup: 0 raw
  `TextStyle`, 0 small font-size, 0 raw Material/direct hex color, 0 raw
  `GestureDetector`, 0 direct `Navigator`, 0 hardcoded `Image.network`, 0 local
  gradient, 0 direct Material button, 0 visible placeholder/empty-section copy,
  and 0 emoji codepoint findings.

## 2026-06-28 Placeholder and Home Finalization Slice

- Removed the remaining drift-script placeholder surfaces from Admin,
  Ticketing, Membership, and Home. Empty admin CMS/audit/history/seasons
  regions now collapse instead of rendering "No ..." copy; Ticketing empty tabs
  collapse or route to the shared borrowed browse action; Membership uses a
  pending-setup message instead of "not configured yet".
- Removed Home's synthetic empty fixture slide and the visible "No fixture"
  hero fallback. When no confirmed hero slide exists, the CMS hero block now
  collapses quietly and does not manufacture a match card.
- Replaced the remaining Home hero raw `GestureDetector` control with
  `AfriPressFeedback` and wrapped auto-slide/page navigation futures in
  `unawaited`.
- Fixed a real CMS renderer bug found during the Home golden refresh: hidden
  stats and leaderboard blocks now return `SliverToBoxAdapter` placeholders
  instead of box widgets directly inside `CustomScrollView.slivers`.
- Updated Home state tests to seed the same bootstrap feature-config/content
  block shape used by the app, refreshed `goldens/home_screen.png`, and kept
  Latest Intel hidden-empty tests aligned with the borrowed quiet-empty rule.
- `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 0 total
  findings: 0 raw `TextStyle`, 0 small font-size, 0 raw Material/direct hex
  color, 0 raw `GestureDetector`, 0 direct `Navigator`, 0 hardcoded
  `Image.network`, 0 local gradient, 0 direct Material button, 0 visible
  placeholder/empty-section copy, and 0 emoji codepoint findings.
- `flutter analyze --no-fatal-infos --no-fatal-warnings packages/features/feat_home`
  reports no issues after this slice.
- `flutter test packages/features/feat_home/test/home_screen_states_test.dart packages/features/feat_home/test/home_module_test.dart packages/features/feat_home/test/home_content_repository_test.dart packages/features/feat_home/test/home_widgets_test.dart packages/features/feat_home/test/latest_intel_empty_state_test.dart`
  passed after the Home golden/test refresh.
- `flutter analyze --no-fatal-infos --no-fatal-warnings packages/features/feat_admin packages/features/feat_ticketing packages/features/feat_membership packages/features/feat_home`
  exits 0. The remaining reported items are pre-existing nonfatal admin,
  membership, and ticketing warning/info debt outside the Home finalization
  slice.
- `flutter test packages/features/feat_home/test/home_screen_states_test.dart packages/features/feat_home/test/home_module_test.dart packages/features/feat_home/test/home_content_repository_test.dart packages/features/feat_home/test/home_widgets_test.dart packages/features/feat_home/test/latest_intel_empty_state_test.dart packages/features/feat_ticketing/test/ticketing_module_test.dart packages/features/feat_membership/test/membership_module_test.dart packages/features/feat_admin/test/admin_module_test.dart`
  passed.
- `git diff --check` is clean.

## 2026-06-28 Raw Input Component Migration Slice

- Extended `AfriInputField` in `core_theme` so the borrowed input primitive now
  covers centered numeric entry, tokenized custom text styles, helper text,
  `minLines`, and compact content padding without feature-local
  `InputDecoration` overrides.
- Replaced all active feature/admin raw `TextField` usages with
  `AfriInputField` across market search, shop search, checkout delivery,
  account deletion confirmation, contribution amount entry, CMS dialogs,
  competition/season forms, match composer forms, push notification composer,
  and fixture settlement score entry.
- The only remaining production `TextField(` scan hit is the internal
  implementation in
  `packages/core/core_theme/lib/src/widgets/afri_input_field.dart`, which is
  the intended centralized borrowed-system component.
- `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_gamification packages/features/feat_shop packages/features/feat_admin packages/features/feat_settings`
  exits 0. The command still prints pre-existing nonfatal warning/info debt,
  and the touched shop search unawaited-future findings were removed during
  this slice.
- `flutter test packages/features/feat_shop/test/shop_screen_catalog_test.dart packages/features/feat_admin/test/admin_module_test.dart packages/features/feat_settings/test/settings_screens_test.dart packages/features/feat_gamification/test/fanzone_hub_screen_test.dart`
  passed.
- `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 0 total
  findings across all scripted categories.
- `git diff --check` is clean.

## 2026-06-28 Gamification Icon Control Migration Slice

- Removed all raw production `IconButton(` usage from
  `packages/features/feat_gamification/lib/src` by migrating gamification
  app-bar backs, overflow/filter actions, inline back affordances, slip remove
  controls, wallet clear controls, and numeric steppers to `AfriIconButton`.
- Preserved existing navigation and bounds behavior while moving controls onto
  the borrowed press/focus treatment: `context.pop()` back buttons, challenge
  fallback routing, fixtures "My Predictions" navigation, market selector
  availability, and 0-20 wager/value steppers.
- Active non-test raw `IconButton(` usage across the repo dropped to 26
  occurrences after this slice. Remaining hits are outside gamification and
  are concentrated in shop/product quantity controls, fan-club headers,
  onboarding/auth, live screens, and admin action rows.
- `rg -n "\bIconButton\(" packages/features/feat_gamification/lib/src -g '*.dart'`
  returns no matches.
- `flutter analyze --no-fatal-infos --no-fatal-warnings packages/features/feat_gamification packages/core/core_theme`
  exits 0. The command still prints pre-existing nonfatal warning/info debt.
- `flutter test packages/features/feat_gamification/test/fanzone_hub_screen_test.dart packages/features/feat_gamification/test/leaderboard_content_test.dart packages/features/feat_gamification/test/team_contribution_content_test.dart packages/features/feat_gamification/test/social_hub_content_test.dart packages/features/feat_gamification/test/my_predictions_list_test.dart packages/features/feat_gamification/test/friends_list_content_test.dart packages/features/feat_gamification/test/share_card_generator_screen_test.dart packages/features/feat_gamification/test/streak_calendar_content_test.dart packages/features/feat_gamification/test/token_history_transaction_list_test.dart packages/features/feat_gamification/test/prediction_notifications_list_test.dart`
  passed.
- `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 0 total
  findings across all scripted categories.
- `git diff --check` is clean.

## 2026-06-28 Borrowed Icon Control Migration Slice

- Migrated shared chrome/back affordances in `AfriScreenScaffold` and
  `KillSwitchGate` from raw Material `IconButton` to the tokenized
  `AfriIconButton` primitive, so screens using those wrappers inherit the
  borrowed press/focus treatment automatically.
- Replaced a cross-feature batch of raw app-bar/header icon controls with
  `AfriIconButton` across fanzone, shop, ticketing, admin, contributions,
  settings, and membership surfaces. The batch covered search/cart actions,
  refresh/filter controls, close/back affordances, and fan-registry clear-search
  suffix controls.
- Active non-test raw `IconButton(` usage dropped to 69 occurrences after this
  slice. Remaining occurrences are concentrated mostly in gamification detail
  screens, product detail quantity controls, fan-club headers, and admin
  competition/detail action rows for subsequent migration.
- `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_gamification packages/features/feat_shop packages/features/feat_ticketing packages/features/feat_admin packages/features/feat_contributions packages/features/feat_settings packages/features/feat_membership`
  exits 0. The command still prints pre-existing nonfatal warning/info debt.
- `flutter test packages/features/feat_ticketing/test/ticketing_module_test.dart packages/features/feat_settings/test/settings_screens_test.dart packages/features/feat_membership/test/membership_module_test.dart packages/features/feat_membership/test/fan_registry_results_test.dart packages/features/feat_contributions/test/groups_screen_empty_state_test.dart packages/features/feat_contributions/test/group_detail_ledger_section_test.dart packages/features/feat_shop/test/shop_screen_catalog_test.dart packages/features/feat_admin/test/admin_module_test.dart packages/features/feat_gamification/test/fanzone_hub_screen_test.dart`
  passed.
- `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 0 total
  findings across all scripted categories.
- `git diff --check` is clean.

## 2026-06-28 Production IconButton Elimination Slice

- Removed the remaining active non-test raw `IconButton(` usage outside
  gamification by migrating shop/cart/product detail, fan-club detail/list,
  onboarding phone auth, live match/news article, admin manager/detail, and
  competition season controls to `AfriIconButton`.
- Preserved existing behavior while moving controls onto the borrowed icon
  primitive: close/back routing, product quantity bounds, product fallback
  routing, live-match prediction-history navigation, competition add/toggle
  actions, and admin screen returns.
- `rg -n "\bIconButton\(" packages/features packages/core apps -g '*.dart' -g '!**/test/**'`
  returns no matches, completing the active production `IconButton` cleanup.
- `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_shop packages/features/feat_fan_clubs packages/features/feat_onboarding packages/features/feat_live packages/features/feat_admin`
  exits 0. The command still prints pre-existing nonfatal warning/info debt.
- `flutter test packages/features/feat_shop/test/shop_screen_catalog_test.dart packages/features/feat_fan_clubs/test/fan_club_matchday_agenda_section_test.dart packages/features/feat_fan_clubs/test/fan_clubs_results_test.dart packages/features/feat_live/test/live_match_fallback_test.dart packages/features/feat_admin/test/admin_module_test.dart`
  passed.
- `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 0 total
  findings across all scripted categories.
- `git diff --check` is clean.

## 2026-06-28 Borrowed Switch and Icon-Action Control Slice

- Added shared `AfriTextIconButton` and `AfriOutlinedIconButton` wrappers in
  `core_theme` so icon+label text and outline actions are centralized behind
  borrowed typography, padding, radius, foreground, and disabled-state tokens.
- Replaced raw feature `TextButton.icon`, `OutlinedButton.icon`, and
  `SwitchListTile.adaptive` usages with borrowed wrappers across admin CMS,
  admin competition/match/notification workflows, ticket seat configuration,
  and onboarding phone-auth entry.
- Tightened core helper widgets by replacing direct text-button usage in
  `AfriErrorBoundary` and `AfriFilterSheet` with `AfriTextIconButton` /
  `AfriTextButton`, leaving raw Material button constructors only inside the
  shared wrapper implementation file.
- `rg -n "\bSwitchListTile\.adaptive\(|\bSwitchListTile\(|\bTextButton\.icon\(|\bTextButton\(|\bOutlinedButton\.icon\(|\bOutlinedButton\(" packages/features packages/core apps -g '*.dart' -g '!**/test/**'`
  now reports only intended wrapper internals in `core_theme`:
  `afri_material_buttons.dart` and `afri_list_row.dart`.
- The remaining direct selection-control baseline is 12
  `DropdownButtonFormField<String>` usages, all in admin forms. These remain a
  separate migration target because `core_theme` does not yet expose a shared
  borrowed dropdown field primitive.
- `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_admin packages/features/feat_ticketing packages/features/feat_onboarding`
  exits 0. The command still prints pre-existing nonfatal warning/info debt.
- `flutter test packages/features/feat_admin/test/admin_module_test.dart packages/features/feat_ticketing/test/ticketing_module_test.dart packages/features/feat_shop/test/shop_screen_catalog_test.dart`
  passed.
- `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 0 total
  findings across all scripted categories.
- `git diff --check` is clean.

## 2026-06-28 Release Readiness Evidence Slice

- Fixed the shared `test_support` borrowed-font loader so widget tests can keep
  loading local font files while on-device integration tests load the packaged
  `core_theme` font assets through Flutter's asset bundle. This unblocked the
  Rayon release-readiness integration smoke suite, which previously failed in
  `setUpAll` because the device runtime reported `/` as the current directory.
- `bash tools/scripts/validate_club_release.sh rayon_sports` passed, including
  iOS release contract validation, public release metadata URL checks, stale
  release metadata scans, committed credential checks, and production
  flavor/asset validation.
- `flutter analyze --no-pub packages/features/test_support/lib/design_font_loader.dart apps/rayon_sports/integration_test/release_readiness_smoke_test.dart`
  passed with no issues under the mounted Flutter 3.44.3 SDK.
- `flutter test --no-pub apps/rayon_sports/test/rayon_sports_shell_navigation_test.dart`
  passed 2/2 after the borrowed-font loader change.
- `flutter test --no-pub integration_test` from `apps/rayon_sports` passed 3/3
  after rebuilding and installing the Android debug integration APK. The suite
  verifies authenticated fan restore into the production home shell, safe
  fallback to onboarding when session restore fails, and the streamlined
  production settings surface.
- `bash tools/scripts/dry_run_android_release.sh rayon_sports` passed with an
  ephemeral dry-run keystore and produced
  `apps/rayon_sports/build/app/outputs/bundle/release/app-release.aab`.
  Artifact evidence: 150.3 MB reported by Flutter, 143 MB on disk, SHA-256
  `ac00c3c5747e266cf683249adebdb97ad20cfb961aba65c97d978550578394b5`.
- Release build performance evidence: the Android release build tree-shook
  `CupertinoIcons.ttf` from 257,628 bytes to 848 bytes and
  `MaterialIcons-Regular.otf` from 1,645,184 bytes to 18,616 bytes.
- `bash tools/scripts/dry_run_ios_release.sh rayon_sports` was attempted under
  Xcode 26.2 and Flutter 3.44.3. The repo-side release contract and
  `validate_club_release.sh` gates passed before the native build, and the
  Xcode build ran for 233.7s before failing at Apple signing:
  `Building a deployable iOS app requires a selected Development Team with a
  Provisioning Profile.` No unsigned `Runner.app.zip` artifact was produced.
- The iOS dry run generated Flutter's current UIScene lifecycle migration in
  `Runner/AppDelegate.swift` and `Runner/Info.plist`, plus Swift Package
  Manager pins in
  `Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved`. `Podfile.lock`
  now only tracks the remaining CocoaPods-backed plugins while Firebase and
  related native packages are pinned through SwiftPM.
- `flutter analyze --no-pub` from `apps/rayon_sports` passed with no issues in
  43.3s after the integration harness fix.
- `flutter test --no-pub test` from `apps/rayon_sports` passed 12/12 after the
  integration harness fix.
- `bash tools/scripts/rayon_mobile_design_drift_report.sh` still reports 0
  total findings across the scripted categories after the release-evidence
  slice.
- `bash tools/scripts/validate_ios_release_contract.sh rayon_sports &&
  bash tools/scripts/validate_club_release.sh rayon_sports` passed after the
  iOS migration artifacts were generated.
- Hardened `apps/rayon_sports/scripts/capture_screenshots.py` from a
  manual-only ADB helper into an evidence-producing capture/validation tool.
  It now supports static Fastlane screenshot validation, guided capture, rapid
  capture, noninteractive `--launch --capture-current` device capture, portable
  JSON manifests, device metadata, PNG dimension checks, and configurable
  minimum screenshot counts.
- `python3 apps/rayon_sports/scripts/capture_screenshots.py
  --validate-existing --min-count 4` passed against the current Fastlane Play
  screenshots. Evidence:
  `apps/rayon_sports/store_metadata/play_store/screenshots_manifest.json`
  records 8/8 valid PNG screenshots at 1080 x 1920.
- During live Pixel 4a validation, the first device captures exposed a real
  first-frame readiness issue: Android kept the app behind the launch/splash
  surface while Firebase Installations returned `403 CONSUMER_SUSPENDED` for
  the configured Firebase API key/project. Startup logs also showed early
  skipped-frame bursts.
- Bounded best-effort Firebase, App Check, Crashlytics, and connectivity
  startup tasks in `AppStartupCoordinator` so telemetry/attestation services
  cannot indefinitely block the first rendered Flutter frame. Supabase
  initialization remains on the critical path.
- Rebuilt and reinstalled the Android debug APK with
  `--dart-define-from-file=assets/flavors/production.json` on a physical Pixel
  4a (`1080x2340`, Android 13). After the startup timeout fix, `dumpsys window`
  reported `MainActivity` as the top opaque window and the app displayed in
  `+6s502ms`; a post-display screenshot was captured to
  `apps/rayon_sports/store_metadata/play_store/screenshots/live_main_pixel4a_after_display_2026-06-28.png`
  with evidence manifest
  `apps/rayon_sports/store_metadata/play_store/live_main_after_display_manifest.json`.
- The live screenshot is valid device evidence, but it is not yet final store
  screenshot evidence: it is an onboarding screen capture on the developer
  Pixel 4a and includes the device's floating accessibility shortcut overlay.
  Final Play/App Store screenshots still need a clean device profile and
  route-by-route captures.
- Added `apps/rayon_sports/scripts/collect_android_performance_evidence.py`
  as a repeatable ADB-only startup/frame evidence collector. It records device
  metadata, `am start -W` cold-start timing, `dumpsys window` readiness,
  `dumpsys gfxinfo framestats`, filtered runtime logs, and an explicit
  assessment separating "evidence collected" from "performance signoff ready."
- `python3 apps/rayon_sports/scripts/collect_android_performance_evidence.py
  --device 13111JEC215558 --settle-seconds 10 --output
  apps/rayon_sports/store_metadata/play_store/android_performance_pixel4a_manifest.json`
  collected valid Pixel 4a evidence, but the assessment is not release-ready:
  cold start was 4372 ms against the current 3000 ms target, and the frame
  sample had only 2 frames, below the 60-frame minimum useful jank sample.
  The app did reach `MainActivity` as the focused/top opaque window and was no
  longer stuck behind the Android launch screen.
- Built a profile APK with
  `flutter build apk --profile --dart-define-from-file=assets/flavors/production.json`
  and installed it on the same Pixel 4a. Artifact evidence:
  `apps/rayon_sports/build/app/outputs/flutter-apk/app-profile.apk`, 99.8 MB
  reported by Flutter, 95 MB on disk, SHA-256
  `305b9fbe47fab2577ce45d437f7fddadd83bf0ce6202698c537be2f05c253e75`.
- Re-ran the Android performance collector against the installed profile APK:
  `python3 apps/rayon_sports/scripts/collect_android_performance_evidence.py
  --device 13111JEC215558 --build-mode profile --settle-seconds 8
  --exercise-swipes 16 --output
  apps/rayon_sports/store_metadata/play_store/android_performance_pixel4a_profile_manifest.json`.
  The manifest records a true cold launch (`process_stopped_before_launch:
  true`, `LaunchState: COLD`) with `TotalTime: 1540 ms`, meeting the 3000 ms
  startup target. `dumpsys window` reported `MainActivity` as current focus and
  top fullscreen opaque window, with no splash window on top after settle.
- The profile APK evidence is still not full performance signoff. Android
  `dumpsys gfxinfo ... framestats` returned 0 rendered frames after a 16-swipe
  exercise, so the collector marks `frame_stats_available: false` and
  `performance_signoff_ready: false`. The next performance phase needs a
  Flutter timeline/DevTools or Perfetto trace that can produce a useful
  frame/jank sample for a named route interaction.
- Captured a profile-device screenshot after the swipe exercise:
  `apps/rayon_sports/store_metadata/play_store/screenshots/live_profile_after_swipe_exercise_2026-06-28.png`
  with manifest
  `apps/rayon_sports/store_metadata/play_store/live_profile_after_swipe_manifest.json`.
  Like the earlier live screenshot, it is valid device-render evidence but not
  final store evidence because it was captured on the developer Pixel 4a with
  the device accessibility shortcut overlay visible.
- Extended the Android performance collector with optional Perfetto capture:
  `--perfetto-duration-seconds` starts device Perfetto before launch, traces the
  same startup/swipe flow, pulls the `.pftrace`, and records trace metadata in
  the JSON manifest. The log excerpt redacts Firebase API-key shaped values
  before writing evidence artifacts.
- Captured a 30-second Pixel 4a profile-flow Perfetto trace with
  `python3 apps/rayon_sports/scripts/collect_android_performance_evidence.py
  --device 13111JEC215558 --build-mode profile --settle-seconds 8
  --exercise-swipes 16 --perfetto-duration-seconds 30 --output
  apps/rayon_sports/store_metadata/play_store/android_performance_pixel4a_profile_perfetto_manifest.json`.
  The manifest records `LaunchState: COLD`, `TotalTime: 1612 ms`,
  `process_stopped_before_launch: true`, app focus/top-window success, and a
  pulled trace at
  `apps/rayon_sports/store_metadata/play_store/performance_traces/rayon-profile-flow-2026-06-28T12-06-06-445680-00-00.pftrace`
  with size 33,438,357 bytes.
- Decoded the Perfetto trace with the official `trace_processor` wrapper. The
  frame timeline showed 313 actual frame rows, 312 on-time presents, and 1 late
  present on the system StatusBar layer, for 0.32% jank against the current 5%
  target. The app main-thread max slice was 4.310 ms, so the bottleneck was not
  Dart main-thread work.
- The same decoded trace showed a real app raster-thread concern:
  300 `GPURasterizer::Draw` slices, 297 over 16 ms, 1 over 33 ms, average
  21.981 ms, and max 51.219 ms.
- Replaced the onboarding route's two blurred `GlassCard` surfaces with
  tokenized solid `AfriSurfaceCard` surfaces and adjusted the first-slide
  headline/body offsets so the text no longer overlaps the hero card on Pixel
  4a-sized viewports.
- Rebuilt and reinstalled the profile APK after the onboarding surface change.
  Artifact evidence:
  `apps/rayon_sports/build/app/outputs/flutter-apk/app-profile.apk`, 131.3 MB
  reported by Flutter, 125 MB on disk, SHA-256
  `3d8a0fed9718a12621bae823c8282ad52d8699611b882798e0e5078197a9343b`.
- Captured an after-change Perfetto trace with
  `apps/rayon_sports/store_metadata/play_store/android_performance_pixel4a_profile_perfetto_after_onboarding_surface_manifest.json`
  and trace
  `apps/rayon_sports/store_metadata/play_store/performance_traces/rayon-profile-flow-2026-06-28T12-17-26-961959-00-00.pftrace`
  sized 33,455,386 bytes. The after run remained a cold launch with app
  focus/top-window success and no splash top window after settle, but startup
  was noisier at 2506 ms and logcat recorded `Skipped 54 frames`.
- Decoded after-change Perfetto evidence shows the surface change materially
  reduced worst-case raster cost: `GPURasterizer::Draw` average dropped from
  21.981 ms to 16.635 ms, max dropped from 51.219 ms to 18.737 ms, and >33 ms
  raster draws dropped from 1 to 0. The after trace still had 311/349 raster
  draws over 16 ms, so performance signoff remains open.
- Added decoded trace summary:
  `apps/rayon_sports/store_metadata/play_store/performance_traces/rayon_profile_perfetto_summary_2026-06-28.md`.
- Captured a post-change Pixel 4a screenshot at
  `apps/rayon_sports/store_metadata/play_store/screenshots/live_profile_after_onboarding_surface_2026-06-28.png`
  with manifest
  `apps/rayon_sports/store_metadata/play_store/live_profile_after_onboarding_surface_manifest.json`.
  The screenshot verifies the app rendering with solid onboarding surfaces,
  but it also exposed a headline/hero overlap and remains non-store-final
  because the developer device accessibility shortcut overlay is visible. The
  overlap was fixed afterward and is covered by the updated onboarding golden.
- Rebuilt and reinstalled the profile APK after the final offset fix so device
  evidence matches the current code. Artifact evidence:
  `apps/rayon_sports/build/app/outputs/flutter-apk/app-profile.apk`, 131.2 MB
  reported by Flutter, 125 MB on disk, SHA-256
  `fb7d13e674ab05ab3a4567bde388afa446dc432d35d5571d17c71fc803748ea2`.
- Temporarily hid and then restored the developer-device accessibility
  shortcut to capture a clean final Pixel 4a onboarding screenshot:
  `apps/rayon_sports/store_metadata/play_store/screenshots/live_profile_after_final_offset_2026-06-28.png`
  with manifest
  `apps/rayon_sports/store_metadata/play_store/live_profile_after_final_offset_manifest.json`.
  The PNG is 1080 x 2340, 133,475 bytes, and verifies that the first-slide
  headline no longer overlaps the hero surface.
- Tightened the Android performance collector log filter so generated evidence
  excerpts include lines from the Rayon app PID or lines explicitly mentioning
  `rw.gikundiro.app`, instead of pulling unrelated Firebase/error logs from
  other apps on the device.
- Captured and decoded a final offset-rebuild Perfetto trace with scoped logs:
  `apps/rayon_sports/store_metadata/play_store/android_performance_pixel4a_profile_perfetto_final_scoped_logs_manifest.json`
  and
  `apps/rayon_sports/store_metadata/play_store/performance_traces/rayon-profile-flow-2026-06-28T12-36-05-463906-00-00.pftrace`
  sized 33,422,667 bytes. The run was a cold launch with `TotalTime: 1561 ms`,
  app focus/top-window success, no splash top window after settle, and the
  accessibility shortcut restored afterward.
- Final decoded Perfetto evidence shows improved frame-timeline behavior:
  376 actual frame rows, 376 on-time presents, 0 late/jank frames, 0.00% jank,
  and max actual-frame duration 10.584 ms. App-specific `dumpsys gfxinfo`
  returned 0 frames in this Impeller/profile run, so the final frame claim is
  based on Perfetto, not `gfxinfo`.
- Final decoded raster evidence remains below full signoff: 370
  `GPURasterizer::Draw` slices, 321 over 16 ms, 0 over 33 ms, average
  16.628 ms, and max 18.979 ms. The fix removed the original >33 ms raster
  spike and materially improved worst-case cost, but repeated raster draws
  still sit too close to or above the 16 ms budget.
- The performance evidence also records external/service instability during
  the device run: Firebase Messaging still reports FIS auth failures, and the
  device could not resolve the Supabase host during feature-config and country
  refreshes. These are now explicit release-readiness follow-ups rather than
  hidden local observations.
- `git diff --check` and
  `git diff --numstat -- pubspec.lock apps/rayon_sports/pubspec.lock packages/features/test_support/pubspec.yaml .dart_tool/package_config.json apps/rayon_sports/.dart_tool/package_config.json`
  are clean after the dry run.
- Non-blocking release-maintenance risks observed during these gates:
  Flutter warns that the app and several Android plugins still apply the Kotlin
  Gradle Plugin and must migrate to built-in Kotlin before future Flutter
  versions make that a hard failure; the iOS build warns that
  `flutter_secure_storage` and `permission_handler_apple` do not yet support
  Swift Package Manager and that several MLKit targets do not support arm64 for
  Apple Silicon iOS 26+ simulators; `flutter pub get` reports 75 packages with
  newer versions incompatible with current constraints.
- Post-profile evidence validation passed:
  `python3 -m py_compile apps/rayon_sports/scripts/capture_screenshots.py
  apps/rayon_sports/scripts/collect_android_performance_evidence.py`.
- Post-profile evidence validation passed for the generated JSON manifests:
  `android_performance_pixel4a_manifest.json`,
  `android_performance_pixel4a_profile_manifest.json`, and
  `live_profile_after_swipe_manifest.json`.
- Post-Perfetto evidence validation passed for
  `android_performance_pixel4a_profile_perfetto_manifest.json`; the pulled
  `.pftrace` exists under `store_metadata/play_store/performance_traces/` and
  the generated evidence manifests do not contain unredacted Firebase API-key
  shaped values.
- Final offset evidence validation passed:
  `python3 -m py_compile apps/rayon_sports/scripts/capture_screenshots.py
  apps/rayon_sports/scripts/collect_android_performance_evidence.py`, JSON
  loading for `live_profile_after_final_offset_manifest.json`,
  `android_performance_pixel4a_profile_perfetto_final_offset_manifest.json`,
  `android_performance_pixel4a_profile_perfetto_final_scoped_logs_manifest.json`,
  and `android_performance_pixel4a_profile_perfetto_after_onboarding_surface_manifest.json`,
  and `git diff --check`.
- Final offset secret hygiene check passed for generated Play Store evidence:
  `rg -n "AIza|api_key:[A-Za-z0-9_-]+"
  apps/rayon_sports/store_metadata/play_store apps/rayon_sports/scripts -g
  '*.json' -g '*.py'` only matched the intended redaction regex in
  `collect_android_performance_evidence.py`.
- Post-profile focused Flutter analysis passed:
  `flutter analyze --no-pub packages/core/core_app/lib/src/startup_coordinator.dart
  packages/features/test_support/lib/design_font_loader.dart
  apps/rayon_sports/test/rayon_sports_shell_navigation_test.dart`.
- Post-Perfetto focused Flutter analysis passed:
  `flutter analyze --no-pub packages/core/core_app/lib/src/startup_coordinator.dart
  apps/rayon_sports/test/rayon_sports_shell_navigation_test.dart`.
- Post-onboarding-surface focused Flutter analysis passed:
  `flutter analyze --no-pub packages/features/feat_onboarding/lib/src/screens/onboarding_screen.dart`.
- Final offset focused Flutter analysis passed:
  `flutter analyze --no-pub packages/features/feat_onboarding/lib/src/screens/onboarding_screen.dart
  packages/core/core_app/lib/src/startup_coordinator.dart
  apps/rayon_sports/test/rayon_sports_shell_navigation_test.dart`.
- Post-profile focused Flutter tests passed 7/7:
  `flutter test --no-pub packages/core/core_app/test/bootstrap_architecture_test.dart
  apps/rayon_sports/test/rayon_sports_shell_navigation_test.dart`.
- Post-Perfetto focused Flutter tests passed 7/7 with the same focused
  bootstrap and Rayon shell navigation command.
- Post-onboarding-surface tests passed after refreshing the intentional golden
  change:
  `flutter test --no-pub --update-goldens packages/features/feat_onboarding/test/onboarding_flow_test.dart --plain-name "matches the onboarding editorial layout on mobile"`,
  then sequential non-golden checks for `matches the onboarding editorial
  layout on mobile`, `onboarding stays usable on compact-height viewports`, and
  `§2.2: onboarding GET STARTED signs in anonymously then goes straight to
  home` passed. A full onboarding-flow run still reproduces the existing
  unrelated `ink_sparkle.frag` runtime-stage mismatch in the OTP-route test.
- Final offset focused onboarding golden test passed:
  `flutter test --no-pub packages/features/feat_onboarding/test/onboarding_flow_test.dart
  --plain-name "matches the onboarding editorial layout on mobile"`.
- Post-profile guardrails passed:
  `bash tools/scripts/rayon_mobile_design_drift_report.sh` still reports 0
  findings, `bash tools/scripts/validate_club_release.sh rayon_sports` passed,
  and `git diff --check` is clean.
- Post-Perfetto guardrails passed: the Rayon mobile design drift report still
  reports 0 findings, `validate_club_release.sh rayon_sports` passed, and
  `git diff --check` is clean.
- Final offset guardrails passed: `bash
  tools/scripts/rayon_mobile_design_drift_report.sh` reports 0 findings and
  `bash tools/scripts/validate_club_release.sh rayon_sports` passed.

## 2026-06-28 Expanded Placeholder-Copy Cleanup Slice

- Ran a broader source scan beyond
  `tools/scripts/rayon_mobile_design_drift_report.sh` for user-facing
  `No ...`, `coming soon`, and `placeholder` copy in active Dart source. This
  found additional UI strings that were outside the scripted drift categories.
- Removed or reworded the remaining visible `No ...` empty-state copy across
  gamification, admin CMS/admin monitors, membership, ticketing, shop,
  fan-club detail, contributions export, shared network/core messages, and
  shared component examples.
- Collapsed additional empty sections to quiet borrowed-system surfaces instead
  of rendering placeholder cards: gamification fixture/market/challenge empty
  regions, admin CMS empty lists, admin match/filter empty lists, and
  membership package empty surfaces.
- Reworded route/setup and access messages to setup/action language:
  checkout/ticket payment setup pending, admin privileges required, competition
  catalog pending, matching record unavailable, connection unavailable, and
  photo library empty.
- Removed dead empty-state helpers introduced by the quiet-empty migration:
  `_buildEmptyState` in `feature_detail_screen.dart` and `_EmptySectionState`
  in admin CMS widgets.
- The expanded scan now only reports Flutter/CachedNetworkImage
  `placeholder:` callback names in product/detail/home image widgets. Those are
  framework API names, not visible placeholder copy.
- `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 0 total
  findings: 0 raw `TextStyle`, 0 small font-size, 0 raw Material/direct hex
  color, 0 raw `GestureDetector`, 0 direct `Navigator`, 0 hardcoded
  `Image.network`, 0 local gradient, 0 direct Material button, 0 visible
  placeholder/empty-section copy, and 0 emoji codepoint findings.
- `flutter analyze --no-fatal-infos --no-fatal-warnings packages/features/feat_gamification packages/features/feat_admin packages/features/feat_membership packages/features/feat_contributions packages/features/feat_shop packages/features/feat_ticketing packages/features/feat_fan_clubs packages/features/feat_club packages/features/feat_sms_ledger packages/core/core_auth packages/core/core_network packages/core/core_utils packages/core/core_feature_config packages/core/core_theme packages/core/core_app`
  exits 0. Remaining output is pre-existing nonfatal warning/info debt.
- `flutter test packages/features/feat_gamification/test/challenge_feature_test.dart --plain-name "create screen confirms submission and navigates to detail"`
  passed.
- `flutter test packages/features/feat_gamification/test/fanzone_hub_screen_test.dart packages/features/feat_gamification/test/leaderboard_content_test.dart packages/features/feat_gamification/test/team_contribution_content_test.dart packages/features/feat_gamification/test/social_hub_content_test.dart packages/features/feat_gamification/test/my_predictions_list_test.dart packages/features/feat_membership/test/membership_module_test.dart packages/features/feat_membership/test/fan_registry_results_test.dart packages/features/feat_contributions/test/groups_screen_empty_state_test.dart packages/features/feat_contributions/test/group_detail_ledger_section_test.dart packages/features/feat_shop/test/shop_screen_catalog_test.dart packages/features/feat_ticketing/test/ticketing_module_test.dart packages/features/feat_admin/test/admin_module_test.dart packages/features/feat_fan_clubs/test/fan_club_matchday_agenda_section_test.dart packages/features/feat_fan_clubs/test/fan_clubs_results_test.dart packages/features/feat_home/test/home_screen_states_test.dart`
  passed.
- A broader attempt that included all of
  `packages/features/feat_gamification/test/challenge_feature_test.dart` still
  reproduces the existing shader runtime-stage failure in the
  `my challenges screen switches across status tabs` case:
  `Unsupported runtime stages format version. Expected 2, got 0.` This is the
  same known shader test blocker documented earlier and is unrelated to the
  placeholder-copy cleanup.
- `git diff --check` is clean.

## 2026-06-28 Borrowed Dropdown Field Migration Slice

- Added `AfriDropdownField<T>` in `core_theme` as the single borrowed-system
  dropdown primitive for Flutter form menus. The wrapper keeps the remaining
  Material `DropdownButtonFormField` implementation inside the design-system
  package and applies semantic surfaces, tokenized typography, tokenized
  spacing, shared input radius, and accent-focused borders.
- Exported `AfriDropdownField` from `packages/core/core_theme/lib/core_theme.dart`
  so feature packages can use the same form-menu primitive as the rest of the
  borrowed UI system.
- Migrated all active admin dropdowns from raw `DropdownButtonFormField<String>`
  to `AfriDropdownField<String>` in:
  `match_composer_sheet.dart`, `push_notifications_screen.dart`, and
  `cms_content_manager_screen.dart`.
- Replaced the deprecated controlled `value:` dropdown property with
  `initialValue:` during the migration so the admin forms stay aligned with the
  current Flutter form-field API.
- Production scan result:
  `rg -n "\bDropdownButtonFormField<" packages/features packages/core apps -g '*.dart' -g '!**/test/**'`
  now reports only
  `packages/core/core_theme/lib/src/widgets/afri_dropdown_field.dart`, which is
  the intentional design-system wrapper boundary.
- Usage scan result:
  `rg -n "AfriDropdownField" packages/core/core_theme packages/features/feat_admin -g '*.dart'`
  confirms 12 migrated feature usages plus the core wrapper and export.
- Focused analyzer gate passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_admin`
  exits 0. Output still includes existing nonfatal lint/debt items such as
  discarded futures, directive ordering, and the existing protected-member
  warning in admin CMS builders.
- Focused admin test passed:
  `flutter test packages/features/feat_admin/test/admin_module_test.dart`
  passed 7/7 tests.
- Drift and whitespace guardrails passed:
  `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 0 total
  findings, and `git diff --check` is clean.

## 2026-06-28 Borrowed Tab Navigation Migration Slice

- Added `AfriTabBar` in `core_theme` as the shared borrowed-system primitive
  for route-level and in-page tab navigation. It owns the remaining Material
  `TabBar` implementation inside the design-system boundary and provides line
  and segmented variants with tokenized typography, semantic dark surfaces,
  quiet overlays, and shared route padding.
- Exported `AfriTabBar` from `packages/core/core_theme/lib/core_theme.dart`.
- Migrated all active feature-level raw tab bars in gamification and ticketing:
  my predictions, challenges, my challenges, match detail, social hub,
  leaderboard segmented tabs, team profile pinned tabs, ticket match list, and
  my tickets.
- Updated `TeamTabBarDelegate` to accept `PreferredSizeWidget`, preserving the
  pinned header behavior while allowing the shared `AfriTabBar` wrapper.
- Added a design-system guardrail test that fails on future feature/app
  `TabBar(` usage and directs authors to `AfriTabBar`.
- Production scan result:
  `rg -n "\bTabBar\s*\(" packages/features apps packages/core -g '*.dart' -g '!**/test/**'`
  now reports only `packages/core/core_theme/lib/src/widgets/afri_tab_bar.dart`,
  the intentional design-system wrapper boundary.
- Usage scan result:
  `rg -n "AfriTabBar" packages/core/core_theme packages/features/feat_gamification packages/features/feat_ticketing -g '*.dart'`
  confirms 9 migrated feature usages plus the core wrapper, export, and
  guardrail reference.
- Focused analyzer gate passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_gamification packages/features/feat_ticketing`
  exits 0. Output still includes existing nonfatal lint/debt items such as
  discarded futures, directive ordering, unused imports, and unused private
  declarations in unrelated files.
- Focused tests passed:
  `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart packages/features/feat_ticketing/test/ticketing_module_test.dart packages/features/feat_gamification/test/my_predictions_list_test.dart packages/features/feat_gamification/test/leaderboard_content_test.dart packages/features/feat_gamification/test/social_hub_content_test.dart`
  passed 33/33 tests, including the new raw-tab guardrail.
- Drift and whitespace guardrails passed after the report update:
  `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 0 total
  findings, and `git diff --check` is clean.

## 2026-06-28 Borrowed Contributions Toast Migration Slice

- Migrated all direct contributions-package `ScaffoldMessenger.of(...).showSnackBar`
  and `SnackBar` usage to `AfriToast`, continuing the transient-feedback
  cleanup started in settings.
- Routed MoMo dialer launch failure and SMS sync permission/sync failures
  through `AfriToast.error`.
- Routed CSV export completion, successful SMS sync enablement, and manual SMS
  sync completion through `AfriToast.success`; neutral unsupported-PDF and SMS
  disabled messages now use `AfriToast.info`.
- Expanded the focused design-system toast guardrail to cover both migrated
  packages: `feat_settings` and `feat_contributions`.
- Production scan result:
  `rg -n "ScaffoldMessenger\.of|\bSnackBar\b" packages/features/feat_contributions packages/features/feat_settings -g '*.dart' -g '!**/test/**'`
  returns no production hits in the migrated packages.
- Focused analyzer gate passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_contributions packages/features/feat_settings`
  exits 0. Output still includes existing nonfatal lint/debt items such as
  discarded futures, directive ordering, and a pre-existing const suggestion in
  the MoMo contribution overlay.
- Focused tests passed:
  `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart packages/features/feat_contributions/test/group_detail_ledger_section_test.dart packages/features/feat_contributions/test/groups_screen_empty_state_test.dart packages/features/feat_settings/test/settings_module_test.dart`
  passed 41/41 tests, including the expanded migrated-package toast guardrail.
- Drift and whitespace guardrails passed after the report update:
  `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 0 total
  findings, and `git diff --check` is clean.

## 2026-06-28 Borrowed Settings Toast Migration Slice

- Migrated all direct settings-package `ScaffoldMessenger.of(...).showSnackBar`
  and `SnackBar` usage to `AfriToast`, centralizing settings feedback chrome
  through the borrowed toast primitive.
- Routed support-link launch failures, missing WhatsApp support configuration,
  missing support contact configuration, and expired-session admin access
  feedback through `AfriToast.error`.
- Routed edit-profile, privacy, and notification-preference helper messages
  through `AfriToast.info`, preserving their existing neutral message behavior
  while applying borrowed card surface, icon, typography, haptics, and
  accessibility treatment.
- Added a focused design-system guardrail that fails if `feat_settings`
  reintroduces direct `ScaffoldMessenger.of` or `SnackBar` usage before the
  remaining feature packages are migrated.
- Production scan result:
  `rg -n "ScaffoldMessenger\.of|\bSnackBar\b" packages/features/feat_settings -g '*.dart' -g '!**/test/**'`
  returns no settings production hits.
- Focused analyzer gate passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_settings`
  exits 0. Output still includes existing nonfatal core lint/debt items such
  as discarded futures and directive ordering.
- Focused tests passed:
  `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart packages/features/feat_settings/test/settings_module_test.dart packages/features/feat_settings/test/settings_screens_test.dart`
  passed 38/38 tests, including the new settings toast guardrail.
- Drift and whitespace guardrails passed after the report update:
  `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 0 total
  findings, and `git diff --check` is clean.

## 2026-06-28 Borrowed Bottom Sheet Route Migration Slice

- Extended `showAfriBottomSheet` in `core_theme` with a
  `useBorrowedSurface` option so feature sheets can centralize route chrome
  while preserving custom draggable or already-tokenized sheet bodies.
- Updated `AfriBottomSheet` so large content receives flexible bounded height
  inside the borrowed surface instead of overflowing the modal shell.
- Migrated all active feature/app direct `showModalBottomSheet` route calls to
  `showAfriBottomSheet` across gamification, shop, settings, contributions,
  admin, and membership surfaces. Existing return types, scroll-controlled
  behavior, confirmation results, and custom sheet bodies were preserved.
- Added a design-system guardrail test that fails on future feature/app direct
  `showModalBottomSheet` calls and directs authors to `showAfriBottomSheet`.
- Production scan result:
  `rg -n "\bshowModalBottomSheet\s*(?:<[^>]+>)?\s*\(" packages/features apps packages/core -g '*.dart' -g '!**/test/**'`
  now reports only core wrapper internals:
  `afri_bottom_sheet.dart` and `afri_action_sheet.dart`.
- Focused analyzer gate passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_gamification packages/features/feat_shop packages/features/feat_settings packages/features/feat_contributions packages/features/feat_admin packages/features/feat_membership`
  exits 0. Output still includes existing nonfatal lint/debt items such as
  discarded futures, directive ordering, unused imports/elements, const
  suggestions, and the existing protected-member warning in admin CMS builders.
- Validation caught and fixed one migration-specific layout issue: the first
  focused test run found the challenge confirmation sheet overflowing inside
  the shared shell, so `AfriBottomSheet` now wraps sheet content with
  `Flexible(fit: FlexFit.loose, ...)`.
- Focused tests passed after the shell fix:
  `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart packages/features/feat_admin/test/admin_module_test.dart packages/features/feat_gamification/test/challenge_feature_test.dart packages/features/feat_settings/test/settings_module_test.dart packages/features/feat_contributions/test/group_detail_ledger_section_test.dart packages/features/feat_membership/test/contribution_history_test.dart`
  passed 51/51 tests, including the new raw-bottom-sheet-route guardrail.
- Drift and whitespace guardrails passed after the report update:
  `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 0 total
  findings, and `git diff --check` is clean.

## 2026-06-28 Borrowed Form And Toggle Control Migration Slice

- Added `AfriTextFormField` in `core_theme` for form-backed borrowed-system
  inputs. The remaining Flutter `TextFormField` constructor now lives inside
  the design-system boundary and shares the same tokenized input surface,
  typography, content padding, max-length behavior, and focus border treatment
  as `AfriInputField`.
- Added `AfriSwitch` in `core_theme` for compact inline toggle rows. The
  remaining Flutter `Switch` constructor now lives inside the design-system
  boundary and applies shared club accent, borrowed active track, and dark
  inactive track/thumb colors.
- Exported the compact switch primitive from `core_theme`; `AfriTextFormField`
  is exported through the existing input field export.
- Migrated the remaining active feature/app direct `TextFormField` and `Switch`
  usage in the admin feature detail rules/sort-order editor to
  `AfriTextFormField` and `AfriSwitch`, preserving numeric entry, centered
  alignment, disabled saving state, and submit parsing behavior.
- Added design-system guardrail tests that fail on future feature/app direct
  `TextField`/`TextFormField` usage and future direct compact
  `Switch`/`Checkbox`/`Radio`/`Slider` usage.
- Production scan result:
  `rg -n "\b(TextField|TextFormField|Switch|Checkbox|Radio|Slider)\s*\(" packages/features apps packages/core -g '*.dart' -g '!**/test/**'`
  now reports only core wrapper internals:
  `afri_input_field.dart` and `afri_switch.dart`.
- Focused analyzer gate passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_admin`
  exits 0. Output still includes existing nonfatal lint/debt items such as
  discarded futures, directive ordering, const suggestions, and the existing
  protected-member warning in admin CMS builders.
- Focused tests passed:
  `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart packages/features/feat_admin/test/admin_module_test.dart`
  passed 31/31 tests, including the new raw-input and raw-compact-toggle
  guardrails.
- Drift and whitespace guardrails passed after the report update:
  `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 0 total
  findings, and `git diff --check` is clean.

## 2026-06-28 Borrowed Dialog Surface Migration Slice

- Added `AfriDialog` in `core_theme` as the shared borrowed modal surface. The
  remaining Flutter `Dialog` constructor now lives inside the design-system
  boundary and applies the shared transparent route shell plus borrowed
  `GlassCard` content surface.
- Added `AfriAlertDialog` in `core_theme` as the replacement for feature-level
  `AlertDialog` usage. Titles, body text, scrollable content, and action rows
  now inherit borrowed typography, spacing, radius, and modal card treatment
  from the shared primitive instead of feature-local Material defaults.
- Exported the dialog primitives from `core_theme`.
- Migrated all active feature/app direct `Dialog`, `AlertDialog`,
  `SimpleDialog`, and `AboutDialog` constructor usage to `AfriDialog` or
  `AfriAlertDialog` across gamification, contributions, settings, and admin
  CMS/competition surfaces. Existing `showDialog` routes, return values,
  stateful dialog builders, and typed close semantics were preserved.
- Removed converted admin dialog `backgroundColor:` overrides so modal surface
  color is owned by the borrowed design system instead of each feature.
- Added a design-system guardrail test that fails on future feature/app direct
  Material dialog surfaces and directs authors to `AfriDialog` or
  `AfriAlertDialog`.
- Production scan result:
  `rg -n "\b(Dialog|AlertDialog|SimpleDialog|AboutDialog)\s*\(" packages/features apps packages/core -g '*.dart' -g '!**/test/**'`
  now reports only `packages/core/core_theme/lib/src/widgets/afri_dialog.dart`,
  the intentional design-system wrapper boundary.
- Focused analyzer gate passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_gamification packages/features/feat_contributions packages/features/feat_settings packages/features/feat_admin`
  exits 0. Output still includes existing nonfatal lint/debt items such as
  discarded futures, directive ordering, unused imports/elements, const
  suggestions, and the existing protected-member warning in admin CMS builders.
- Focused tests passed:
  `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart packages/features/feat_admin/test/admin_module_test.dart packages/features/feat_gamification/test/challenge_feature_test.dart packages/features/feat_gamification/test/team_contribution_content_test.dart packages/features/feat_contributions/test/group_detail_ledger_section_test.dart packages/features/feat_settings/test/settings_module_test.dart`
  passed 50/50 tests, including the new raw-dialog guardrail.
- Drift and whitespace guardrails passed after the report update:
  `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 0 total
  findings, and `git diff --check` is clean.

## 2026-06-28 Borrowed Separator Migration Slice

- Added `AfriDivider` in `core_theme` as the shared borrowed-system separator
  primitive for quiet in-card and route boundaries. The remaining Material
  `Divider` implementation now lives inside the design-system package and
  applies `BorderTokens.hairline` plus `ColorTokens.ghostBorder` by default.
- Exported `AfriDivider` from `packages/core/core_theme/lib/core_theme.dart`.
- Migrated all active feature-level raw `Divider` separators in gamification
  and admin feature-management surfaces, including fanzone settings, top
  scorers, friend lists, jackpot fixtures/leaders, friend challenge fixtures,
  privacy guarantees/toggles, social-hub rows, feature-detail toggles, and
  feature-management channel metadata.
- Preserved the stronger admin hairline treatment where it was already
  intentional by passing `ColorTokens.onDarkHairline` into `AfriDivider`.
- Added a design-system guardrail test that fails on future feature/app
  `Divider(` or `VerticalDivider(` usage and directs authors to `AfriDivider`.
- Production scan result:
  `rg -n "\b(Divider|VerticalDivider)\(" packages/features apps packages/core -g '*.dart' -g '!**/test/**'`
  now reports only `packages/core/core_theme/lib/src/widgets/afri_divider.dart`,
  the intentional design-system wrapper boundary.
- Usage scan result:
  `rg -n "AfriDivider" packages/core/core_theme packages/features/feat_gamification packages/features/feat_admin -g '*.dart'`
  confirms 19 migrated feature usages plus the core wrapper, export, and
  guardrail reference.
- Focused analyzer gate passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_gamification packages/features/feat_admin`
  exits 0. Output still includes existing nonfatal lint/debt items such as
  discarded futures, directive ordering, unused imports/elements, and the
  existing protected-member warning in admin CMS builders.
- Focused tests passed:
  `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart packages/features/feat_admin/test/admin_module_test.dart packages/features/feat_gamification/test/leaderboard_content_test.dart packages/features/feat_gamification/test/social_hub_content_test.dart packages/features/feat_gamification/test/friends_list_content_test.dart`
  passed 35/35 tests, including the new raw-separator guardrail.

## 2026-06-28 Borrowed Press Feedback Migration Slice

- Migrated the remaining feature-level direct Material press surfaces from
  `InkWell` to `AfriPressFeedback`, preserving the existing card layouts while
  routing tap, hover, focus, keyboard activation, haptic feedback, tooltip, and
  semantics behavior through the shared borrowed-system primitive.
- Updated the statement download date cards and format cards to use
  `AfriPressFeedback` with explicit labels and selected semantics.
- Updated the edit-profile destructive account action to use
  `AfriPressFeedback` with disabled state, tooltip, semantic label, and
  destructive-action hint.
- Added a design-system guardrail test that fails on future feature/app
  `InkWell(` or `InkResponse(` usage and directs authors to
  `AfriPressFeedback`.
- Production scan result:
  `rg -n "\b(InkWell|InkResponse)\(" packages/features apps packages/core -g '*.dart' -g '!**/test/**'`
  now reports no feature/app/core production hits.
- Usage scan result:
  `rg -n "AfriPressFeedback" packages/features/feat_contributions/lib/src/screens/statement_download_screen.dart packages/features/feat_settings/lib/src/screens/edit_profile_screen.dart packages/core/core_theme/test/design_system_source_of_truth_test.dart`
  confirms 3 migrated feature usages plus the new guardrail reference.
- Focused analyzer gate passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_contributions packages/features/feat_settings`
  exits 0. Output still includes existing nonfatal lint/debt items such as
  discarded futures, directive ordering, and a pre-existing const suggestion in
  the MoMo contribution overlay.
- Focused tests passed:
  `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart packages/features/feat_contributions/test/group_detail_ledger_section_test.dart packages/features/feat_settings/test/settings_module_test.dart packages/features/feat_settings/test/settings_screens_test.dart`
  passed 32/32 tests, including the new raw-press-surface guardrail.
- Drift and whitespace guardrails passed after the report update:
  `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 0 total
  findings, and `git diff --check` is clean.

## 2026-06-28 Borrowed Popup Menu Migration Slice

- Added `AfriPopupMenuButton<T>` in `core_theme` as the shared borrowed-system
  popup-menu trigger. The remaining Material `PopupMenuButton` implementation
  now lives inside the design-system boundary and applies tokenized dark
  surfaces, no Material elevation/surface tint, and shared rounded menu shape.
- Exported `AfriPopupMenuButton` from
  `packages/core/core_theme/lib/core_theme.dart`.
- Migrated the remaining feature-level raw popup menu triggers in the admin
  feature detail and feature manager screens to `AfriPopupMenuButton<String>`.
  The visibility choices and existing chip/pill child surfaces were preserved.
- Added a design-system guardrail test that fails on future feature/app
  `PopupMenuButton(` usage and directs authors to `AfriPopupMenuButton`.
- Production scan result:
  `rg -n "\bPopupMenuButton\b" packages/features apps packages/core -g '*.dart' -g '!**/test/**'`
  now reports only
  `packages/core/core_theme/lib/src/widgets/afri_popup_menu_button.dart`, the
  intentional design-system wrapper boundary.
- Usage scan result:
  `rg -n "AfriPopupMenuButton|PopupMenuButton" packages/core/core_theme packages/features/feat_admin -g '*.dart'`
  confirms 2 migrated feature usages plus the core wrapper, export, and
  guardrail reference.
- Focused analyzer gate passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_admin`
  exits 0. Output still includes existing nonfatal lint/debt items such as
  discarded futures, directive ordering outside the touched export, and the
  existing protected-member warning in admin CMS builders.
- Focused tests passed:
  `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart packages/features/feat_admin/test/admin_module_test.dart`
  passed 26/26 tests, including the new raw-popup-menu guardrail.
- Drift and whitespace guardrails passed after the report update:
  `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 0 total
  findings, and `git diff --check` is clean.

## 2026-06-28 Borrowed Pull-to-Refresh Migration Slice

- Added `AfriRefreshIndicator` in `core_theme` as the shared borrowed-system
  pull-to-refresh primitive. The remaining Material `RefreshIndicator`
  implementation now lives inside the design-system boundary and applies the
  shared club accent spinner, borrowed dark surface background, zero elevation,
  and pass-through refresh semantics/trigger options.
- Exported `AfriRefreshIndicator` from
  `packages/core/core_theme/lib/core_theme.dart`.
- Migrated all active feature/app `RefreshIndicator(` wrappers to
  `AfriRefreshIndicator(` across gamification, admin, contributions, home,
  membership, live, and fan-club surfaces. Existing refresh callbacks, scroll
  physics, and child layouts were preserved.
- Added a design-system guardrail test that fails on future feature/app
  `RefreshIndicator(` usage and directs authors to `AfriRefreshIndicator`.
- Production scan result:
  `rg -n "\bRefreshIndicator\(" packages/features apps packages/core -g '*.dart' -g '!**/test/**'`
  now reports only
  `packages/core/core_theme/lib/src/widgets/afri_refresh_indicator.dart`, the
  intentional design-system wrapper boundary.
- Usage scan result:
  `rg -n "AfriRefreshIndicator" packages/features apps packages/core/core_theme -g '*.dart'`
  confirms 42 migrated feature/app usages plus the core wrapper and guardrail
  reference.
- Focused analyzer gate passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_gamification packages/features/feat_admin packages/features/feat_contributions packages/features/feat_home packages/features/feat_membership packages/features/feat_live packages/features/feat_fan_clubs`
  exits 0. Output still includes existing nonfatal lint/debt items such as
  discarded futures, directive ordering, unused imports/elements, const
  suggestions, and the existing protected-member warning in admin CMS builders.
- Focused tests passed:
  `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart packages/features/feat_admin/test/admin_module_test.dart packages/features/feat_gamification/test/my_predictions_list_test.dart packages/features/feat_contributions/test/group_detail_ledger_section_test.dart packages/features/feat_home/test/home_screen_states_test.dart packages/features/feat_membership/test/fan_registry_results_test.dart packages/features/feat_fan_clubs/test/fan_clubs_results_test.dart`
  passed 40/40 tests, including the new raw-refresh guardrail.
- Drift and whitespace guardrails passed after the report update:
  `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 0 total
  findings, and `git diff --check` is clean.

## 2026-06-28 Borrowed Progress Indicator Migration Slice

- Extended `AfriLoadingIndicator` in `core_theme` with `strokeWidth` and
  determinate `value` support so circular loading chrome can cover inline,
  dialog, button-adjacent, image-loading, and sliver-list loading states without
  feature-local Material spinners.
- Added `AfriLinearProgressIndicator` in `core_theme` for borrowed-system
  determinate and indeterminate linear progress bars. The wrapper applies the
  shared club accent, borrowed dark progress track, and full-radius progress
  shape by default.
- Migrated all active feature/app direct `CircularProgressIndicator` and
  `LinearProgressIndicator` usage to `AfriLoadingIndicator` or
  `AfriLinearProgressIndicator` across gamification, contributions, admin,
  live, membership, and onboarding surfaces.
- Preserved determinate image-loading behavior in live match avatars by passing
  the existing loading fraction into `AfriLoadingIndicator.value`.
- Fixed the one migration-specific analyzer issue found during validation:
  a converted contributions progress bar initially retained Material's
  `valueColor:` argument and was corrected to `color:`.
- Added a design-system guardrail test that fails on future feature/app
  `CircularProgressIndicator(` or `LinearProgressIndicator(` usage and directs
  authors to the shared progress primitives.
- Production scan result:
  `rg -n "\b(CircularProgressIndicator|LinearProgressIndicator)\(" packages/features apps packages/core -g '*.dart' -g '!**/test/**'`
  now reports only `core_theme` wrapper internals:
  `afri_loading_indicator.dart` and `afri_button.dart`.
- Usage scan result:
  `rg -n "AfriLinearProgressIndicator|AfriLoadingIndicator" packages/features apps packages/core/core_theme -g '*.dart'`
  confirms 16 migrated feature/app progress usages plus the core wrapper and
  guardrail reference.
- Focused analyzer gate passed after the `valueColor` fix:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_gamification packages/features/feat_contributions packages/features/feat_admin packages/features/feat_live packages/features/feat_membership packages/features/feat_onboarding`
  exits 0. Output still includes existing nonfatal lint/debt items such as
  discarded futures, directive ordering, unused imports/elements, const
  suggestions, and the existing protected-member warning in admin CMS builders.
- Focused tests passed:
  `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart packages/features/feat_admin/test/admin_module_test.dart packages/features/feat_gamification/test/friends_list_content_test.dart packages/features/feat_contributions/test/group_detail_ledger_section_test.dart packages/features/feat_membership/test/fan_registry_results_test.dart packages/features/feat_live/test/live_match_fallback_test.dart packages/features/feat_onboarding/test/onboarding_module_test.dart`
  passed 46/46 tests, including the new raw-progress guardrail.
- Drift and whitespace guardrails passed after the report update:
  `bash tools/scripts/rayon_mobile_design_drift_report.sh` reports 0 total
  findings, and `git diff --check` is clean.

## 2026-06-28 Guest Auth And Live Route Evidence Slice

- Added an anonymous-auth resilience path in `AuthNotifier`: when Supabase
  anonymous sign-in fails with raw network errors or SafeRpc's normalized
  "Unable to connect / check your internet connection" message, the app now
  continues with a local guest `UserProfile` and `AdminWorkspaceAccess.none`
  instead of trapping supporters on onboarding.
- Added focused coverage in
  `packages/core/core_auth/test/auth_lifecycle_test.dart` for both raw
  Supabase DNS failures and normalized connection failures. Validation passed:
  `flutter test --no-pub packages/core/core_auth/test/auth_lifecycle_test.dart`
  completed 21/21 tests, and focused `flutter analyze --no-pub` reported no
  issues for the touched auth files and screenshot helper.
- Hardened `apps/rayon_sports/scripts/capture_screenshots.py` with an
  automated ADB mode that force-stops, launches, waits through transient
  Flutter semantics frames, advances onboarding by accessibility label, captures
  screenshots, and records JSON manifests. The helper now parses Android UI XML
  defensively and treats XML element existence explicitly.
- Built and installed a fresh debug APK for device proof after the profile AOT
  build stalled twice and was interrupted with exit 130. Debug artifact evidence:
  `apps/rayon_sports/build/app/outputs/flutter-apk/app-debug.apk`, 224 MB,
  SHA-256
  `22fd38f541649cb070091ac1a0aa091b9ac8ca08847d8d616df4f7a33dd5500a`,
  installed successfully on Pixel 4a `13111JEC215558`.
- Device evidence captured on Pixel 4a:
  `apps/rayon_sports/store_metadata/play_store/screenshots/automated_2026-06-28/01_home_dashboard.png`,
  `02_fanzone.png`, and `07_settings_manual.png`; Settings manifest:
  `apps/rayon_sports/store_metadata/play_store/screenshots_settings_manual_manifest.json`.
- Critical blocker found: the guest/offline Home screen reaches the shell but
  renders only top chrome and bottom navigation; the body is blank, so quick
  actions such as Members, Tickets, Shop, and Groups are not visible or
  accessible. Fan Zone reaches its tab but remains skeleton-only under the same
  Supabase DNS failure. This is not store-ready: authenticated-shell reachability
  is fixed, but offline/degraded body states for primary routes still need real
  fallback content or explicit empty/error states.
- Additional blocker: feature data providers still log repeated Supabase DNS
  failures and Crashlytics records during offline guest navigation. These should
  degrade to bounded UI states and non-crashing/non-Crashlytics expected-offline
  handling before release evidence is considered clean.
- Hygiene after this slice: `python3 -m py_compile
  apps/rayon_sports/scripts/capture_screenshots.py` passed and
  `git diff --check` is clean.

## 2026-06-28 Offline Guest Home And Fanzone Fallback Slice

- Fixed the primary Home regression found in live device evidence: when remote
  CMS content blocks are unavailable, Home now composes a local fallback block
  sequence for the hero/error state, primary actions, quick actions, and latest
  intel. This keeps the shell usable even when Supabase/config cannot be
  reached.
- Fixed the Fan Zone first-load experience: loading now shows bounded state copy
  plus route shortcuts instead of skeleton-only cards, and fully offline
  snapshots show explicit section states for markets, leaderboard, and
  challenges.
- Corrected `FanzoneHubNotifier` to actually launch its eight upstream loads
  concurrently. The previous implementation described concurrent loading but
  awaited calls sequentially, amplifying DNS/offline delays.
- Added focused widget coverage:
  `HomeScreen states renders fallback home actions when CMS blocks are
  unavailable`, `loading state still exposes fanzone route shortcuts`, and
  `offline snapshot shows bounded degraded sections`.
- Refreshed the Home golden after confirming the current rendered image exposes
  proper button labels instead of the stale masked-label baseline.
- Validation passed:
  `flutter analyze --no-pub packages/features/feat_home/lib/src/screens/home_screen.dart packages/features/feat_home/test/home_screen_states_test.dart packages/features/feat_gamification/lib/src/providers/fanzone_hub_provider.dart packages/features/feat_gamification/lib/src/screens/fanzone_hub_screen.dart packages/features/feat_gamification/test/fanzone_hub_screen_test.dart`
  reported no issues, and
  `flutter test --no-pub packages/features/feat_home/test/home_screen_states_test.dart packages/features/feat_gamification/test/fanzone_hub_screen_test.dart`
  passed 9/9 tests.
- Device evidence passed on Pixel 4a after rebuilding/installing a fresh debug
  APK. Debug artifact:
  `apps/rayon_sports/build/app/outputs/flutter-apk/app-debug.apk`, 224 MB,
  SHA-256
  `4efd0e909d26c287bc3153d6cc02486fd658ee959d46e93244ffb0ebf7279bd6`.
  Automated capture manifest:
  `apps/rayon_sports/store_metadata/play_store/screenshots_automated_after_offline_fallback_manifest.json`.
  It captured 7/7 valid screenshots across Home, Fan Zone, Membership,
  Ticketing, Shop, Contributions, and Settings under the offline/guest path.
- Remaining release gaps: the evidence screenshots still include the Android
  accessibility shortcut overlay, so they are QA proof, not final Play Store
  marketing screenshots. Home still reports "Could not resolve the active club"
  under the tested DNS failure, and Fan Zone still depends on downstream
  repositories that log network failures. Those are now bounded in the UI, but
  final release readiness still needs clean profile/release evidence and
  expected-offline observability cleanup.

## 2026-06-28 Clean Automated Screenshot Capture Slice

- Hardened `apps/rayon_sports/scripts/capture_screenshots.py` so automated
  captures temporarily hide the Android accessibility shortcut overlay before
  taking screenshots and restore the previous device settings afterward. The
  helper snapshots `accessibility_button_targets` and
  `accessibility_button_mode`, deletes the shortcut target during capture, then
  restores the original Sound Amplifier target.
- The first implementation attempt used an empty secure setting value and failed
  on-device with Android settings exit 255. The final implementation uses
  `settings delete secure accessibility_button_targets` for the temporary hide
  step, which was verified on Pixel 4a `13111JEC215558`.
- Clean Pixel evidence captured successfully:
  `apps/rayon_sports/store_metadata/play_store/screenshots_automated_clean_accessibility_manifest.json`.
  The manifest reports `success: true`, `screenshot_count: 7`,
  `accessibility_shortcut_hidden: true`, and
  `accessibility_shortcut_restored: true`.
- Captured routes are stored in
  `apps/rayon_sports/store_metadata/play_store/screenshots/automated_clean_accessibility_2026-06-28/`:
  Home, Fan Zone, Membership, Ticketing, Shop, Contributions, and Settings.
  Visual inspection confirmed the Sound Amplifier accessibility overlay is no
  longer present in the Home and Fan Zone screenshots.
- Device restore proof: after capture, `adb shell settings get secure
  accessibility_button_targets` returned
  `com.google.android.accessibility.soundamplifier/com.google.android.accessibility.soundamplifier.ui.SoundAmplifierSettingActivity`.
- Validation passed: `python3 -m py_compile
  apps/rayon_sports/scripts/capture_screenshots.py` and `git diff --check`.
- Remaining release gaps: this evidence still comes from a debug APK, not a
  profile/release build. Home still shows "Could not resolve the active club"
  under the tested DNS failure, so the app now has better bounded fallback
  surfaces but is not product-ready for final store screenshots or release
  submission until active-club fallback, expected-offline logging, and
  profile/release performance evidence are completed.

## 2026-06-28 Home Active-Scope Local Fallback Slice

- Removed the user-visible active-club scope blocker from offline/guest Home.
  `SupabaseHomeFeedRepository` now converts unresolved local club scope into a
  degraded local Home snapshot instead of returning an error snapshot with
  internal tenancy copy.
- Added an explicit local fallback message:
  `Live club data is temporarily unavailable. Home shortcuts remain available.`
  The Home surface keeps the primary actions and fallback quick actions visible
  for Fan Zone, Contributions, Live, Groups, Predict, Tickets, Shop, Members,
  and Offers.
- Fixed the secondary Home issue found in device evidence: Latest Intel now
  treats unresolved local club scope as an empty local news state, so offline
  guest Home does not render a retryable News error card behind the bottom
  navigation. Real query/network failures can still produce the existing
  retryable Latest Intel error state.
- Added focused coverage in
  `packages/features/feat_home/test/home_content_repository_test.dart`,
  `packages/features/feat_home/test/home_screen_states_test.dart`, and
  `packages/features/feat_home/test/latest_intel_empty_state_test.dart`.
- Validation passed with the Flutter 3.38.9 toolchain after clearing a stale
  test compiler cache and pinning PATH/FLUTTER_ROOT away from an older
  `/Volumes/PRO-G40/Apps/SDKs/flutter` checkout:
  `flutter analyze --no-pub packages/features/feat_home/lib/src/repositories/home_content_repository.dart packages/features/feat_home/test/home_content_repository_test.dart packages/features/feat_home/test/home_screen_states_test.dart packages/features/feat_home/test/latest_intel_empty_state_test.dart`
  and
  `flutter test --no-pub packages/features/feat_home/test/home_content_repository_test.dart packages/features/feat_home/test/home_screen_states_test.dart packages/features/feat_home/test/latest_intel_empty_state_test.dart`
  passed 12/12 tests.
- Built and installed a fresh debug APK using
  `apps/rayon_sports/assets/flavors/production.local.json`. Debug artifact:
  `apps/rayon_sports/build/app/outputs/flutter-apk/app-debug.apk`, 161 MB,
  SHA-256
  `2e53f695e11779f6969240e7af6e30a0d7d948b1c81ee340f9c27ee1f3048253`.
- Clean Pixel evidence captured successfully:
  `apps/rayon_sports/store_metadata/play_store/screenshots_automated_after_home_local_fallback_manifest.json`.
  The manifest reports `success: true`, `screenshot_count: 7`,
  `accessibility_shortcut_hidden: true`, and
  `accessibility_shortcut_restored: true`.
- Captured routes are stored in
  `apps/rayon_sports/store_metadata/play_store/screenshots/automated_after_home_local_fallback_2026-06-28/`.
  Visual inspection of `01_home_dashboard.png` confirmed the internal
  "Could not resolve the active club" copy is gone, the News error card is no
  longer present behind the bottom navigation, and the local degraded Home
  actions remain visible.
- Device restore proof: after capture, `adb shell settings get secure
  accessibility_button_targets` returned
  `com.google.android.accessibility.soundamplifier/com.google.android.accessibility.soundamplifier.ui.SoundAmplifierSettingActivity`.
- Remaining release gaps: this is still debug APK evidence. Release readiness
  still needs profile/release build proof, expected-offline observability cleanup
  so routine degraded data does not create noisy crash/performance signals, and
  screen-by-screen responsive/accessibility review across the rest of the app.

## 2026-06-28 Borrowed Admin Toast Migration Slice

- Replaced remaining raw `ScaffoldMessenger`/`SnackBar` feedback in
  `packages/features/feat_admin` with `AfriToast.success`,
  `AfriToast.error`, or `AfriToast.info`. Covered competition and season
  management, fixture settlement, match management, CMS content, push
  notifications, challenge operations, feature detail errors, and contribution
  CSV export.
- Preserved existing message intent while removing Material snackbar styling:
  validation and failed RPC paths now use borrowed error chrome, create/update
  and clipboard confirmations use success chrome, and neutral CMS helper
  messages use the informational toast.
- Extended `packages/core/core_theme/test/design_system_source_of_truth_test.dart`
  so `feat_admin` is part of the migrated-package toast guardrail. The
  guardrail now prevents reintroducing `ScaffoldMessenger.of`, `showSnackBar`,
  `SnackBar`, or `SnackBarAction` in admin production source.
- Production scan passed with no raw snackbar matches across admin plus the
  already migrated settings, contributions, onboarding, ticketing, fan clubs,
  membership, live, and shop feature packages.
- Validation passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_admin`
  exited 0. It still reports existing nonfatal lint noise and one pre-existing
  admin warning in `cms_section_builders.dart`.
- Focused tests passed:
  `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart packages/features/feat_admin/test/admin_module_test.dart`
  passed 33/33 tests, including the expanded migrated-toast guardrail.
- Remaining UI cleanup: `packages/features/feat_gamification` still has raw
  snackbar usage and is the next large feature package to migrate before the
  repo-wide toast guardrail can cover all feature source.

## 2026-06-28 Borrowed Gamification Toast Migration Slice

- Replaced remaining raw `ScaffoldMessenger`/`SnackBar` feedback in
  `packages/features/feat_gamification` with shared `AfriToast` variants.
  Covered prediction slip, market selection, match markets, prediction share
  and detail actions, my predictions cancellation, fan ID copy, FET wallet
  helper messages, team profile validation, jackpot entry, rewards redemption,
  friend challenge actions, friends list actions, challenge join/cancel, and
  create-challenge failure feedback.
- Preserved async context behavior in `prediction_slip_widgets.dart` by showing
  post-submit failure toasts through the preserved host context after the sheet
  closes.
- Removed the now-unused `core_utils` import from
  `prediction_detail_screen.dart`, which became dead after replacing the raw
  snackbar code path.
- Extended the migrated-toast guardrail so `feat_gamification` is covered
  alongside admin, settings, contributions, onboarding, ticketing, fan clubs,
  membership, live, and shop. The guardrail now blocks raw snackbars across all
  currently migrated feature packages.
- Production scan passed with no raw snackbar matches across the migrated
  feature packages:
  `feat_admin`, `feat_gamification`, `feat_shop`, `feat_membership`,
  `feat_live`, `feat_fan_clubs`, `feat_ticketing`, `feat_onboarding`,
  `feat_contributions`, and `feat_settings`.
- Validation passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_admin packages/features/feat_gamification`
  exited 0. Remaining output is pre-existing nonfatal lint debt in core/admin
  and gamification.
- Focused tests passed:
  `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart packages/features/feat_admin/test/admin_module_test.dart packages/features/feat_gamification/test/fanzone_hub_screen_test.dart packages/features/feat_gamification/test/challenge_models_test.dart packages/features/feat_gamification/test/fet_models_test.dart`
  passed 79/79 tests, including the expanded migrated-toast guardrail.

## 2026-06-28 Borrowed Icon Token Centralization Slice

- Centralized remaining direct platform icon choices in shared Flutter UI
  source. Core shared widgets now consume `AfriIcons` instead of direct
  `Icons.*` constants for maintenance gates, branded error fallbacks, filter
  sheets, action-sheet chevrons, empty/error/state views, list rows, scanner
  states, scanner privacy badges, and toast variants.
- Added semantic icon tokens for `maintenance`, `statusLoading`, and `offline`
  in `packages/core/core_theme/lib/src/tokens/icon_tokens.dart`, keeping
  Material icon selection localized to the single icon-token source of truth.
- Updated shared widget examples to reference `AfriIcons` rather than raw
  Material constants so copied examples do not reintroduce old icon selection
  patterns.
- Added the design-system guardrail
  `Icon choices route through AfriIcons tokens`, which scans authored Dart
  source in `packages` and `apps` and allows direct `Icons.*` /
  `CupertinoIcons.*` only in `icon_tokens.dart`, tests, and integration tests.
- Production scan passed: direct platform icon constants now appear only in
  `packages/core/core_theme/lib/src/tokens/icon_tokens.dart` outside test and
  generated build source.
- Validation passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme`
  exited 0 with existing nonfatal lint debt, and
  `flutter test packages/core/core_theme/test/design_system_source_of_truth_test.dart`
  passed 27/27 tests including the new icon-token guardrail.

## 2026-06-28 Tracked Visual Artifact And Font Audit Slice

- Audited tracked visual and font artifacts using `git ls-files` so generated
  `build/unit_test_assets` copies did not distort the result.
- No tracked `test/failures`, `maskedDiff`, `isolatedDiff`, `testImage`, or
  `masterImage` artifacts remain in the repository.
- The only tracked feature golden baselines are the expected reviewed files:
  `feat_home/test/goldens/home_screen.png`,
  `feat_membership/test/goldens/membership_screen.png`,
  `feat_onboarding/test/goldens/onboarding_screen.png`,
  `feat_settings/test/goldens/settings_screen.png`, and
  `feat_ticketing/test/goldens/match_list_screen.png`.
- Font declarations are centralized: tracked pubspec declarations show only
  `packages/core/core_theme/pubspec.yaml` declaring the
  `RevolutBorrowed` family. Feature packages do not declare local font
  fixtures in tracked pubspecs.
- Authored assets remain concentrated in app branding/launcher/crest/stadium
  media, core utility data, core borrowed font assets, and the gamification
  reward catalog. No stale feature-local visual failure artifacts were found.

## 2026-06-28 Borrowed Shop Shape And Spacing Tokenization Slice

- Migrated the shop production UI away from local raw shape and spacing values
  toward the borrowed design-system tokens. The product card, loading skeleton,
  cart item row, checkout bar, shop top bar, shop screen badge/category rail,
  search sheet, and product detail quantity/variant controls now use
  `ShapeTokens` and `SpacingTokens` for the updated radii and layout sizes.
- Replaced the remaining direct Material bottom-sheet route in the shop search
  sheet with `showAfriBottomSheet`, preserving the existing search behavior
  while routing modal chrome through the shared borrowed surface primitive.
- Added the guardrail `Migrated shop routes shape and spacing through tokens`
  in `packages/core/core_theme/test/design_system_source_of_truth_test.dart`.
  The scanner now fails future `feat_shop` authored source that reintroduces
  raw `BorderRadius`, `Radius.circular`, `EdgeInsets`, or fixed `SizedBox`
  shape/spacing literals covered by this migration.
- A direct scan with the same matcher over `packages/features/feat_shop/lib`
  returned `hits=0`.
- Validation passed:
  `flutter test --timeout 180s packages/core/core_theme/test/design_system_source_of_truth_test.dart`
  passed 28/28 tests,
  `flutter test packages/features/feat_shop/test/checkout_bar_test.dart`
  passed 2/2 tests, and
  `flutter test packages/features/feat_shop/test/shop_screen_catalog_test.dart`
  passed 2/2 tests.
- Hygiene passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_shop`
  exited 0 with existing info-level lint debt,
  `bash tools/scripts/rayon_mobile_design_drift_report.sh --fail-on-findings`
  reported 0 total findings, and `git diff --check` was clean.

## 2026-06-28 Borrowed Ticketing Shape And Spacing Tokenization Slice

- Migrated the ticketing production UI away from local raw shape and spacing
  literals in the QR pass, wallet ticket card, match list metadata row, seat map
  painter shell, ticket purchase sheet handle, and ticket configuration CTA.
  The migrated surfaces now use `SpacingTokens`, `ShapeTokens`, and
  `BorderTokens.hairline` for borrowed-system rhythm and radii.
- Kept the match-list golden stable while replacing the old 4px metadata gaps
  with `SpacingTokens.spacing1`, preserving the visible spacing through the
  shared token scale.
- Added the guardrail `Migrated ticketing routes shape and spacing through
  tokens` in `packages/core/core_theme/test/design_system_source_of_truth_test.dart`.
  The scanner now fails future `feat_ticketing` authored source that
  reintroduces raw `BorderRadius`, `Radius.circular`, `EdgeInsets`, or fixed
  `SizedBox` shape/spacing literals covered by this migration.
- A direct scan with the same matcher over
  `packages/features/feat_ticketing/lib` returned `hits=0`.
- Validation passed:
  `flutter test --timeout 180s packages/core/core_theme/test/design_system_source_of_truth_test.dart`
  passed 29/29 tests, and
  `flutter test packages/features/feat_ticketing/test/ticketing_module_test.dart packages/features/feat_ticketing/test/match_list_golden_test.dart`
  passed 8/8 tests, including the ticketing golden.
- Hygiene passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_ticketing`
  exited 0 with existing info-level lint debt,
  `bash tools/scripts/rayon_mobile_design_drift_report.sh --fail-on-findings`
  reported 0 total findings, and `git diff --check` was clean.

## 2026-06-28 Borrowed Membership Shape, Spacing, And Golden Slice

- Migrated remaining membership raw shape and spacing literals in contribution
  history rows, the digital membership card share pill, tier progress labels,
  and the contribution confirmation sheet. The updated widgets now route
  micro-gaps, pill radii, and label heights through `SpacingTokens` and
  `ShapeTokens`.
- Added the guardrail `Migrated membership routes shape and spacing through
  tokens` in `packages/core/core_theme/test/design_system_source_of_truth_test.dart`.
  The scanner now fails future `feat_membership` authored source that
  reintroduces raw `BorderRadius`, `Radius.circular`, `EdgeInsets`, or fixed
  `SizedBox` shape/spacing literals covered by this migration.
- A direct scan with the same matcher over
  `packages/features/feat_membership/lib` returned `hits=0`.
- The membership golden was stale against the current borrowed dark/gold
  membership surface already present in the worktree. The previous master image
  showed the older purple membership layout; `--update-goldens` refreshed
  `packages/features/feat_membership/test/goldens/membership_screen.png` to
  the current rendered screen, then generated failure artifacts were removed.
- Validation passed:
  `flutter test --timeout 180s packages/core/core_theme/test/design_system_source_of_truth_test.dart`
  passed 30/30 tests, and
  `flutter test packages/features/feat_membership/test/contribution_history_test.dart packages/features/feat_membership/test/fan_registry_results_test.dart packages/features/feat_membership/test/membership_module_test.dart packages/features/feat_membership/test/membership_screen_golden_test.dart`
  passed 14/14 tests after the golden refresh.
- Hygiene passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_membership`
  exited 0 with existing info-level lint debt,
  `bash tools/scripts/rayon_mobile_design_drift_report.sh --fail-on-findings`
  reported 0 total findings, and `git diff --check` was clean.

## 2026-06-28 Borrowed Gamification Surface Tokenization Slice

- Migrated the highest-density clean gamification shape/spacing file,
  `packages/features/feat_gamification/lib/src/widgets/leaderboard_widgets.dart`,
  away from local raw UI literals. Leaderboard period chips, FET/supporter list
  rows, pinned user rows, rank placeholders, and leaderboard badges now route
  their spacing and radii through `SpacingTokens` and `ShapeTokens`.
- Migrated the repeated challenge card component,
  `packages/features/feat_gamification/lib/src/widgets/challenge_card.dart`,
  away from local raw UI literals. Challenge metadata gaps, kickoff/status
  spacing, stake badges, status chips, score prediction pills, and info chips
  now use `SpacingTokens` and `ShapeTokens` for borrowed-system card and pill
  treatment.
- Migrated the FET split model,
  `packages/features/feat_gamification/lib/src/widgets/fet_split_model.dart`,
  away from local raw UI literals and removed the stale competing reference
  comment. Tier badges, the split progress bar, active-tier rows, and the
  explanatory information panel now route through shared borrowed shape and
  spacing tokens.
- Migrated the match-detail H2H tab,
  `packages/features/feat_gamification/lib/src/widgets/h2h_tab_body.dart`,
  away from local raw UI literals and removed the stale competing reference
  comment. Empty-state icon radii, win-distribution bars, goal metric gaps, and
  score capsules now route through shared borrowed shape and spacing tokens.
- Migrated the match-detail lineups tab,
  `packages/features/feat_gamification/lib/src/widgets/lineups_tab_body.dart`,
  away from local raw UI literals and removed the stale competing reference
  comment. Empty-state icon radii, formation chip radii, and lineup number
  column sizing now route through shared borrowed shape and spacing tokens.
- Migrated the market selector sheet,
  `packages/features/feat_gamification/lib/src/widgets/market_selector_sheet.dart`,
  away from its remaining local raw shape and spacing literals. The sheet drag
  handle, category rail, category count badges, active-section accent bar, FET
  badge, and compact bet-type gap now route through shared borrowed spacing and
  full-pill shape tokens.
- Migrated the FET wallet screen,
  `packages/features/feat_gamification/lib/src/screens/fet_wallet_screen.dart`,
  away from remaining local raw shape and spacing literals. The wallet hero
  card padding, balance/stat gaps, search loading affordance, compact stat gap,
  and stale unused borrowed-stat helper were removed or routed through shared
  spacing tokens.
- Migrated the League Hub screen,
  `packages/features/feat_gamification/lib/src/screens/league_hub_screen.dart`,
  away from remaining local raw shape and spacing literals. Competition chips,
  fixture metadata gaps, league metrics, and standing row rank columns now use
  shared spacing and full-pill shape tokens.
- Migrated the Club Fan Zone screen,
  `packages/features/feat_gamification/lib/src/screens/club_fan_zone_screen.dart`,
  away from remaining local raw shape, spacing, and progress thickness
  literals. Competition filter pills, top-club rank columns, supporter-lean
  micro-gaps, and progress bars now use shared borrowed spacing and full-pill
  shape tokens.
- Migrated the Jackpot Challenge screen and its shared market option pill,
  `packages/features/feat_gamification/lib/src/screens/jackpot_challenge_screen.dart`
  and
  `packages/features/feat_gamification/lib/src/widgets/market_option_pill.dart`,
  away from remaining local raw shape, spacing, minimum-size, and progress
  thickness literals. Jackpot progress bars, tight helper-text gaps, bottom
  scroll clearance, leaderboard rank columns, and outcome pill min-height/radii
  now route through `SpacingTokens` and `ShapeTokens`.
- Migrated the League Standings screen,
  `packages/features/feat_gamification/lib/src/screens/league_standings_screen.dart`,
  away from remaining local raw spacing, width, and pill-radius literals.
  Header columns, standings rank columns, team metadata gaps, and recent-form
  badges now route through `SpacingTokens` and `ShapeTokens`.
- Migrated the Fanzone Privacy Settings screen,
  `packages/features/feat_gamification/lib/src/screens/privacy_settings_screen.dart`,
  away from remaining local raw spacing and fixed container-size literals.
  Privacy guarantee rows, visibility controls, the privacy badge, and bottom
  scroll clearance now route through shared spacing tokens; visibility toggles
  now use the shared `AfriSwitch`; the stale competing external-reference
  comment was replaced with the borrowed privacy-pattern contract; and profile
  sync calls now use explicit `unawaited` fire-and-forget semantics.
- Migrated the Fan ID screen,
  `packages/features/feat_gamification/lib/src/screens/fan_id_screen.dart`,
  away from remaining local fixed sizes and raw pill/card radii. The hero Fan
  ID emblem, tier pill, copy affordance, privacy badge icons, identity-rule
  number pills, and rule text offset now route through `SpacingTokens` and
  `ShapeTokens`, while the existing copy-to-clipboard toast remains on
  `AfriToast`.
- Migrated the Challenges screen and first-time FET tutorial,
  `packages/features/feat_gamification/lib/src/screens/challenges_screen.dart`,
  away from remaining local progress height/radii, custom modal surface
  geometry, drag-handle sizing, step-indicator sizing, and tutorial icon size.
  The tutorial now uses the shared borrowed bottom-sheet surface, progress and
  step indicators use tokenized full-pill radii, and first-load/tutorial
  persistence futures use explicit fire-and-forget semantics.
- Migrated the community-prediction bar and prediction slip widgets,
  `packages/features/feat_gamification/lib/src/widgets/community_prediction_bar.dart`
  and
  `packages/features/feat_gamification/lib/src/widgets/prediction_slip_widgets.dart`,
  away from remaining local bar heights, row widths, chip radii, success badge
  dimensions, and tiny helper gaps. The prediction slip Acca toggle now uses
  the shared `AfriSwitch`, while share/copy actions use explicit
  `unawaited(...)` semantics.
- Completed the remaining `feat_gamification` raw geometry and fixed-dimension
  sweep. Prediction share cards, token-history rows, match/stat panels,
  notification toasts, prediction notifications, auth gates, badge grids,
  fixture browsers, FET arcs, social/team/profile rows, prediction detail and
  share-card generator chips, challenge detail/create/friend controls,
  fanzone settings/hub rows, streak/rewards/offers/friends/match detail
  surfaces, overlays, wallet widgets, and settlement headers now route icon
  sizes, widths, heights, compact gaps, border widths, pill radii, and line
  heights through `SpacingTokens`, `ShapeTokens`, `BorderTokens`, and
  `TypographyTokens`.
- Added `SpacingTokens.spacing0`,
  `TypographyTokens.lineHeightCompact`, and
  `TypographyTokens.lineHeightSolid` so zero insets and compact headline/score
  typography are explicitly tokenized instead of feature-local literals.
- Extended the migrated-surface cleanup to fixed container dimensions exposed
  by the stronger matcher. The challenge avatar badge in
  `challenge_card.dart` and the empty-state icon containers in
  `h2h_tab_body.dart` and `lineups_tab_body.dart` now use shared spacing tokens
  instead of raw 36px/72px sizes.
- Strengthened migrated route guardrails for shop, ticketing, membership, and
  the migrated gamification allowlist so raw `minWidth`/`minHeight` literals
  are caught alongside raw `BorderRadius`, `EdgeInsets`, and `SizedBox`
  geometry. The strengthened scan exposed and fixed the shop cart badge
  minimum dimensions in `shop_screen.dart` and `shop_top_bar.dart`, plus the
  digital membership share-chip minimum height in
  `digital_membership_card.dart`.
- Fixed the shared `AfriListTile` and `AfriSwitchListTile` primitives so their
  Material list controls render inside a local transparent `Material` ancestor.
  This preserves ink/tile behavior when the borrowed list rows are placed inside
  decorated card surfaces and removes Flutter's decorated-box/ListTile assertion
  from wallet interaction tests.
- Refreshed `packages/features/feat_gamification/test/fet_wallet_screen_test.dart`
  against the current borrowed wallet flow: the test harness now provides a
  `GoRouter` context, scrolls to below-fold borrowed controls, and confirms the
  shared wallet bottom sheet before asserting transfer/redemption effects.
- Preserved existing leaderboard layout intent with token-derived values where
  the previous UI used intermediate measurements, such as
  `SpacingTokens.spacing10 + SpacingTokens.spacing1` for the 44px period chip
  minimum height and `SpacingTokens.spacing1 / 2` for tight label gaps.
- Added the guardrail `Migrated gamification surfaces shape and spacing
  through tokens` in
  `packages/core/core_theme/test/design_system_source_of_truth_test.dart`. The
  scanner now fails future `BorderRadius`, `EdgeInsets`, `SizedBox`, fixed
  `Container`/`AnimatedContainer` dimension, and minimum-dimension raw-literal
  regressions across the whole `feat_gamification/lib` package. Added the
  guardrail `Gamification fixed dimensions route through tokens` so direct
  numeric icon sizes, widths, heights, minimum dimensions, raw radii, and
  feature-local typography heights cannot return.
- A direct scan with the strengthened matchers over
  `packages/features/feat_gamification/lib` returned no raw shape/spacing
  violations and no direct numeric width/height/size/min-dimension/line-height
  hits. The strengthened package guardrail scan over migrated shop, ticketing,
  and membership surfaces returned `package_guardrail_violations=0`.
- Validation passed:
  `flutter test --timeout 180s packages/core/core_theme/test/design_system_source_of_truth_test.dart`
  passed 31/31 tests, and
  `flutter test packages/features/feat_gamification/test/leaderboard_content_test.dart`
  passed 4/4 tests, while
  `flutter test packages/features/feat_gamification/test/challenge_feature_test.dart`
  passed 7/7 tests. A combined focused run of
  `challenge_feature_test.dart` and `leaderboard_content_test.dart` passed
  11/11 tests after the lineups migration. After the market-selector migration,
  `flutter test packages/features/feat_gamification/test/fanzone_hub_screen_test.dart`
  passed 3/3 tests. After the FET split/list primitive and wallet-test refresh,
  `flutter test packages/features/feat_gamification/test/fet_wallet_screen_test.dart packages/features/feat_gamification/test/fanzone_hub_screen_test.dart`
  passed 6/6 tests. After the wallet-screen tokenization pass,
  `flutter test packages/features/feat_gamification/test/fet_wallet_screen_test.dart`
  passed 3/3 tests. After the League Hub tokenization pass,
  `flutter test packages/app_registry/test/navigation_journeys_test.dart`
  passed 10/10 tests. After the Club Fan Zone and strengthened minimum-size
  guardrail pass,
  `flutter test --timeout 180s packages/core/core_theme/test/design_system_source_of_truth_test.dart`
  passed 31/31 tests, and
  `flutter test packages/app_registry/test/navigation_journeys_test.dart`
  passed 10/10 tests. After the Jackpot Challenge and market-option pill
  tokenization pass,
  `flutter test --timeout 180s packages/core/core_theme/test/design_system_source_of_truth_test.dart`
  passed 31/31 tests, and
  `flutter test packages/app_registry/test/navigation_journeys_test.dart`
  passed 10/10 tests. After the League Standings and fixed-container-dimension
  guardrail pass,
  `flutter test --timeout 180s packages/core/core_theme/test/design_system_source_of_truth_test.dart`
  passed 31/31 tests, and
  `flutter test packages/app_registry/test/navigation_journeys_test.dart`
  passed 10/10 tests. After the Fanzone Privacy Settings tokenization and
  shared-switch migration pass,
  `flutter test --timeout 180s packages/core/core_theme/test/design_system_source_of_truth_test.dart`
  passed 31/31 tests, and
  `flutter test packages/app_registry/test/navigation_journeys_test.dart`
  passed 10/10 tests. After the Fan ID tokenization pass,
  `flutter test --timeout 180s packages/core/core_theme/test/design_system_source_of_truth_test.dart`
  passed 31/31 tests, and
  `flutter test packages/app_registry/test/navigation_journeys_test.dart`
  passed 10/10 tests. After the Challenges, community-prediction bar, and
  prediction-slip tokenization pass,
  `flutter test --timeout 180s packages/core/core_theme/test/design_system_source_of_truth_test.dart`
  passed 31/31 tests,
  `flutter test packages/app_registry/test/navigation_journeys_test.dart`
  passed 10/10 tests, and
  `flutter test packages/features/feat_gamification/test/challenge_feature_test.dart`
  passed 7/7 tests. After the package-wide gamification geometry and
  fixed-dimension sweep,
  `flutter test --timeout 180s packages/core/core_theme/test/design_system_source_of_truth_test.dart`
  passed 32/32 tests,
  `flutter test packages/features/feat_gamification/test` passed 121/121
  tests, and
  `flutter test packages/app_registry/test/navigation_journeys_test.dart`
  passed 10/10 tests.
- Hygiene passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_gamification`
  exited 0 with existing warning/info debt outside the migrated surface slice.
  Removing the stale unused wallet helper reduced analyzer output from 69 to 68
  nonfatal issues.
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_gamification packages/features/feat_shop packages/features/feat_membership`
  exited 0 with 84 existing nonfatal issues after the Club Fan Zone import
  ordering cleanup.
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_gamification`
  exited 0 with 62 existing nonfatal issues after the jackpot import ordering
  cleanup.
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_gamification`
  exited 0 with 61 existing nonfatal issues after the League Standings
  tokenization and import ordering cleanup.
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/features/feat_gamification/lib/src/screens/privacy_settings_screen.dart`
  reported `No issues found`, and
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_gamification`
  exited 0 with 51 existing nonfatal issues after the privacy async cleanup.
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/features/feat_gamification/lib/src/screens/fan_id_screen.dart`
  reported `No issues found`, and
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_gamification`
  exited 0 with 50 existing nonfatal issues after the Fan ID tokenization pass.
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/features/feat_gamification/lib/src/widgets/prediction_slip_widgets.dart packages/features/feat_gamification/lib/src/widgets/community_prediction_bar.dart packages/features/feat_gamification/lib/src/screens/challenges_screen.dart`
  reported `No issues found`, and
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_gamification`
  exited 0 with 44 existing nonfatal issues after the Challenges/community
  prediction/prediction-slip tokenization pass.
  After the package-wide gamification geometry and fixed-dimension sweep,
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_gamification`
  exited 0 with the same 44 existing nonfatal issues; direct raw-dimension scans
  over `packages/features/feat_gamification/lib` returned no hits.
  `bash tools/scripts/rayon_mobile_design_drift_report.sh --fail-on-findings`
  reported 0 total findings, and `git diff --check` was clean.

## 2026-06-28 Borrowed Home Non-Locked Dimension Tokenization Slice

- Migrated non-locked Home surfaces away from direct UI dimensions and
  feature-local typography heights. `borrowed_match_strip.dart`,
  `latest_intel_section.dart`, `home_screen.dart`, and
  `contributor_leaderboard.dart` now route match-strip padding, status-chip
  gaps/radii, divider sizing, chevron size, latest-intel card width/image
  height/skeleton sizes, loading skeleton dimensions, contributor rank badges,
  and compressed match-strip title line-height through `SpacingTokens`,
  `ShapeTokens`, `BorderTokens`, and `TypographyTokens`.
- Added `TypographyTokens.lineHeightHero` for the compressed borrowed match
  strip title treatment. Existing `match_card.dart` still contains raw hero
  geometry by design because the file carries an explicit product-owner lock
  prohibiting visual layout, sizing, typography, or widget-tree edits.
- Validation passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_home`
  exited 0 with 16 existing nonfatal `core_theme` info-level issues and no
  Home-specific analyzer findings.
  `flutter test packages/features/feat_home/test` passed 22/22 tests.
  `flutter test packages/app_registry/test/navigation_journeys_test.dart`
  passed 10/10 tests.
  `flutter test --timeout 180s packages/core/core_theme/test/design_system_source_of_truth_test.dart`
  passed 32/32 tests after the token additions.
  `bash tools/scripts/rayon_mobile_design_drift_report.sh --fail-on-findings`
  reported 0 total findings, and `git diff --check` was clean.

## 2026-06-29 Borrowed Settings Dimension Tokenization Slice

- Added `SizeTokens` in `core_theme` as the shared source for fixed-format
  borrowed UI dimensions such as sheet handles, icon sizes, avatar sizes, and
  full-width button minimum height. The token file is exported through
  `core_theme.dart` for feature packages.
- Migrated Settings surfaces away from raw sizing and local typography
  contradictions. `settings_overlays.dart`, `settings_screen.dart`,
  `notification_preferences_screen.dart`, `privacy_settings_screen.dart`, and
  `edit_profile_screen.dart` now route avatar sizes, dialog icons, sheet
  handles, outline button heights/radii, profile/delete icons, admin-panel
  padding, and relaxed admin warning copy through `SizeTokens`,
  `SpacingTokens`, `ShapeTokens`, and `TypographyTokens`.
- Removed the positive `letterSpacing: 1.6` overrides from Settings child
  route titles so they follow the borrowed typography contract instead of
  carrying local tracking behavior.
- Added the `Migrated settings dimensions and typography route through tokens`
  guardrail to `design_system_source_of_truth_test.dart`. It fails if raw
  fixed dimensions, raw full-width button heights, raw radii,
  `EdgeInsets.all(<number>)`, or positive letter-spacing return to
  `packages/features/feat_settings/lib`.
- Refreshed only the Settings golden fixture
  `packages/features/feat_settings/test/goldens/settings_screen.png` after the
  intended tokenized layout shift.
- Validation passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_settings`
  exited 0 with the existing 16 nonfatal `core_theme` info-level issues and no
  Settings-specific analyzer findings.
  `flutter test --timeout 180s packages/core/core_theme/test/design_system_source_of_truth_test.dart`
  passed 33/33 tests, including the new Settings guardrail.
  `flutter test --update-goldens packages/features/feat_settings/test/settings_screens_test.dart`
  passed 4/4 tests and updated the Settings golden.
  `flutter test packages/features/feat_settings/test` passed 16/16 tests.
  `flutter test packages/app_registry/test/navigation_journeys_test.dart`
  passed 10/10 tests.
  `bash tools/scripts/rayon_mobile_design_drift_report.sh --fail-on-findings`
  reported 0 total findings. The Settings raw-dimension/letter-spacing scan
  returned no hits, and `git diff --check` was clean before the report update.

## 2026-06-29 Borrowed Fan Clubs Dimension Tokenization Slice

- Migrated Fan Clubs surfaces away from raw chip, icon, row, and share-button
  geometry. `fan_club_cards.dart`, `fan_club_detail_screen.dart`, and
  `fan_clubs_list_screen.dart` now route featured badges, compact status
  chips, hero/group icons, verified icons, row gaps, snapshot-row radii,
  share-button dimensions, and list-header padding through `SizeTokens`,
  `SpacingTokens`, `ShapeTokens`, and `TypographyTokens`.
- Removed local positive letter-spacing overrides from Fan Clubs titles,
  status chips, section headers, and list headers. Intentional compressed title
  height now uses `TypographyTokens.lineHeightHero` or
  `TypographyTokens.lineHeightSolid` instead of feature-local numeric heights.
- Added `SizeTokens.iconXlg` for the 32dp icon size used by the Fan Clubs
  detail hero and future borrowed surfaces.
- Added the `Migrated fan club dimensions and typography route through tokens`
  guardrail to `design_system_source_of_truth_test.dart`. It fails if raw
  fixed dimensions, raw full-width button heights, raw radii,
  `EdgeInsets.all(<number>)`, or positive letter-spacing return to
  `packages/features/feat_fan_clubs/lib`.
- Validation passed:
  `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_fan_clubs`
  exited 0 with the existing 16 nonfatal `core_theme` info-level issues and no
  Fan Clubs-specific analyzer findings.
  `flutter test --timeout 180s packages/core/core_theme/test/design_system_source_of_truth_test.dart`
  passed 34/34 tests, including the new Fan Clubs guardrail.
  `flutter test packages/features/feat_fan_clubs/test` passed 12/12 tests.
  The Fan Clubs raw-dimension/letter-spacing scan returned no hits.

## 2026-06-28 Expected Offline Observability Cleanup Slice

- Reclassified transient mobile connectivity failures in
  `packages/core/core_network/lib/src/safe_rpc.dart` through the public
  `SafeRpc.isTransientConnectivityError` helper. DNS failures, missing hostname
  addresses, `getaddrinfo`, socket, connection, timeout, network, EOF, and reset
  conditions now share the same expected-offline path.
- Preserved retries for transient reads while fixing the RPC retry branch so a
  retryable failure continues to the next attempt instead of falling through to
  the non-transient error path.
- Suppressed Crashlytics recording for exhausted transient connectivity
  failures in `SafeRpc.call` and `SafeRpc.query`. These paths now return the
  normalized offline failure and log a warning, while PostgREST and non-transient
  failures still log as errors and record diagnostic events.
- Updated `packages/core/core_network/lib/src/country_repository.dart` so a
  transient country-catalog load failure uses a warning and the hardcoded
  offline fallback instead of emitting an error with stack trace. Unexpected
  country-catalog failures still retain the error-level log.
- Added focused coverage in
  `packages/core/core_network/test/safe_rpc_test.dart` for exhausted DNS/socket
  retry handling and transient-connectivity classification.
- Validation passed with the pinned Flutter SDK:
  `flutter analyze --no-pub packages/core/core_network/lib/src/safe_rpc.dart packages/core/core_network/lib/src/country_repository.dart packages/core/core_network/test/safe_rpc_test.dart`
  exited 0, and
  `flutter test --no-pub packages/core/core_network/test/safe_rpc_test.dart`
  passed 16/16 tests.
- Tooling note: the first test run failed because `.dart_tool` still referenced
  `/Volumes/PRO-G40/Apps/SDKs/flutter` while the active validated SDK is
  `/usr/local/share/flutter` 3.38.9. Refreshing package config with the pinned
  SDK resolved the mismatch.
- Remaining release gap: this is deterministic code and unit-test proof. The
  performance/readiness phase still needs a fresh profile or release device
  run, logcat review, and performance capture to prove the expected-offline
  runtime noise is reduced on device.

## 2026-06-28 Profile Performance Evidence After Expected-Offline Cleanup

- Rebuilt and installed a fresh Flutter profile APK after the SafeRpc and
  country-catalog observability cleanup. Artifact:
  `apps/rayon_sports/build/app/outputs/flutter-apk/app-profile.apk`, 96 MB,
  SHA-256
  `f6e858f807be4e02bff342d92197b2b5a1fe303df008484f39fdf9cef803af12`.
- Captured a new Pixel 4a Android 13 profile run with the existing collector:
  `python3 apps/rayon_sports/scripts/collect_android_performance_evidence.py
  --device 13111JEC215558 --build-mode profile --settle-seconds 8
  --exercise-swipes 16 --perfetto-duration-seconds 30 --output
  apps/rayon_sports/store_metadata/play_store/android_performance_pixel4a_profile_perfetto_after_expected_offline_observability_manifest.json`.
- Manifest evidence:
  `apps/rayon_sports/store_metadata/play_store/android_performance_pixel4a_profile_perfetto_after_expected_offline_observability_manifest.json`
  reports successful launch/window collection, cold start `TotalTime: 2004 ms`,
  app focused/top window after settle, and Perfetto trace pull success.
- Pulled trace:
  `apps/rayon_sports/store_metadata/play_store/performance_traces/rayon-profile-flow-2026-06-28T18-51-40-883593-00-00.pftrace`,
  33,360,042 bytes, decoded with Perfetto `trace_processor` v56.1.
- Observability result: the manifest excerpt and current filtered logcat search
  for `FeatureConfigRepo`, `CountryRepository`, `SafeRpc`,
  `get_platform_config`, `Failed host lookup`, `[ERROR]`, and `[WARN]` returned
  no app SafeRpc/offline fallback noise for this run. This proves the previous
  `FeatureConfigRepo` DNS failure is no longer emitted as a profile-device
  error in the exercised flow.
- Perfetto frame timeline result: 379 SurfaceFlinger actual frame rows, 2 late
  or jank frames, 0.53% jank rate, and max actual-frame duration 29.480 ms.
  This remains under the current 5% jank threshold in this single run.
- Perfetto raster result: 355 `GPURasterizer::Draw` slices, 0 slices over 16 ms,
  0 slices over 33 ms, average draw duration 7.808 ms, and max draw duration
  15.096 ms. This is the cleanest captured raster profile so far and materially
  improves on the previous final scoped-log run, where 321/370 draw slices were
  over 16 ms.
- Performance signoff remains open. `dumpsys gfxinfo ... framestats` still
  returned 0 rendered frames for this profile/Impeller run, so the frame claim
  depends on Perfetto rather than app-level `gfxinfo`; the profile capture is
  still a single-device/single-run sample; and Firebase Installations/Firebase
  Messaging still emits invalid/suspended configuration errors during startup.
- Updated
  `apps/rayon_sports/store_metadata/play_store/performance_traces/rayon_profile_perfetto_summary_2026-06-28.md`
  with the new trace, startup, frame-timeline, raster, and observability
  comparison.
- Post-capture validation passed: `python3 -m py_compile
  apps/rayon_sports/scripts/collect_android_performance_evidence.py
  apps/rayon_sports/scripts/capture_screenshots.py`; JSON/trace existence
  checks passed for the new manifest and pulled `.pftrace`; focused analyzer
  passed for `safe_rpc.dart`, `country_repository.dart`, and
  `safe_rpc_test.dart`; and the focused SafeRpc test passed 16/16 when run
  consistently with the workspace-resolved Flutter 3.44.3 SDK at
  `/Volumes/PRO-G40/Apps/SDKs/flutter`.
- Tooling note: attempts to rerun the SafeRpc test with
  `/usr/local/share/flutter` hit the known mixed-SDK failure because the
  generated root `.dart_tool` state was rewritten to Flutter 3.44.3 during test
  startup. The final test/analyze result above used one SDK consistently.

## 2026-06-28 FCM Startup Gate And Profile Evidence Slice

- Added a native Android startup guard in
  `apps/rayon_sports/android/app/src/main/kotlin/rw/gikundiro/app/RayonSportsApplication.kt`
  and registered it from `android/app/src/main/AndroidManifest.xml`. It
  disables persisted Firebase Messaging auto-init before Dart/plugin startup,
  covering upgrade installs where earlier builds had already enabled FCM.
- Preserved manifest-level opt-out metadata:
  `firebase_messaging_auto_init_enabled=false` and
  `firebase_analytics_collection_enabled=false`.
- Tightened `packages/core/core_network/lib/src/push_notification_service.dart`
  so deferred app startup no longer registers `onBackgroundMessage`,
  `onTokenRefresh`, or foreground `onMessage` listeners. Those Messaging
  runtime hooks are now registered only after notification permission and token
  sync eligibility are reached.
- Added
  `apps/rayon_sports/test/firebase_startup_contract_test.dart` to lock the
  manifest, native application guard, and Dart startup contract.
- Validation passed with the workspace Flutter 3.44.3 SDK:
  `flutter analyze --no-pub packages/core/core_network/lib/src/push_notification_service.dart apps/rayon_sports/test/firebase_startup_contract_test.dart`
  exited 0; `flutter test --no-pub apps/rayon_sports/test/firebase_startup_contract_test.dart packages/core/core_network/test/safe_rpc_test.dart`
  passed 19/19 tests; and profile APK build succeeded at 127 MB with SHA-256
  `31c85f7b8c27b1fd789af21f55caa00fc957700d65c6737b2c68e5f5ac02d436`.
- Captured two Pixel 4a profile runs. The Dart-only gate run proved the first
  fix was insufficient because `FirebaseMessaging`, `FIS_AUTH_ERROR`, and the
  FlutterFire background messaging service still appeared. The native + Dart
  gate run removed those Messaging startup errors in the log excerpt.
- Native + Dart gate profile evidence:
  `apps/rayon_sports/store_metadata/play_store/android_performance_pixel4a_profile_perfetto_after_native_fcm_startup_gate_manifest.json`
  with trace
  `apps/rayon_sports/store_metadata/play_store/performance_traces/rayon-profile-flow-2026-06-28T19-17-42-389411-00-00.pftrace`.
  Cold startup was 2409 ms, app/window focus was correct after settle, and the
  Perfetto frame timeline reported 391 actual frame rows with 0 late/jank
  frames and max actual-frame duration 10.495 ms.
- Remaining blocker: Firebase Installations still emits
  `CONSUMER_SUSPENDED` against the current Firebase project through
  Crashlytics/Sessions even after Messaging startup is gated. Release readiness
  still requires a valid production Firebase project/API key or an explicit
  decision to gate Crashlytics/Firebase services until that configuration is
  corrected.

## 2026-06-28 Firebase Clean Startup Gate Evidence Slice

- Added `FirebaseObservabilityConfig` in
  `packages/core/core_network/lib/src/firebase_observability_config.dart`.
  Firebase-backed observability is now disabled by default and can only be
  re-enabled with explicit build defines:
  `ENABLE_FIREBASE_OBSERVABILITY=true` and, separately,
  `ENABLE_FIREBASE_APP_CHECK=true`.
- Updated Firebase startup code so disabled observability is a no-touch path:
  `FirebaseBootstrapService` no longer touches Firebase Performance unless
  observability is enabled; `CrashlyticsService` returns before touching
  `FirebaseCrashlytics.instance`; `FirebaseAnalyticsService` returns null while
  observability is disabled; and `AppCheckService` skips activation unless the
  App Check define is enabled.
- Added Android manifest defaults for
  `firebase_data_collection_default_enabled=false`,
  `firebase_crashlytics_collection_enabled=false`,
  `firebase_performance_collection_enabled=false`, and
  `firebase_sessions_enabled=false`. The manifest now also removes the
  Crashlytics, Sessions, Performance, and Analytics component registrars from
  `ComponentDiscoveryService` so those SDKs cannot auto-start against the
  suspended Firebase project.
- Verified the merged profile manifest after rebuild: Crashlytics, Sessions,
  Performance, and Analytics registrars were absent; Firebase Core/Installations
  remained available for Firebase Core dependency wiring.
- Rebuilt and installed the final profile APK. Artifact:
  `apps/rayon_sports/build/app/outputs/flutter-apk/app-profile.apk`, 113 MB,
  SHA-256
  `f98b56dcc53ba175af0456a70f010be01a38db895069318806ae4b51abf395d3`.
- Captured final Pixel 4a evidence:
  `apps/rayon_sports/store_metadata/play_store/android_performance_pixel4a_profile_perfetto_after_firebase_clean_startup_gate_manifest.json`
  with trace
  `apps/rayon_sports/store_metadata/play_store/performance_traces/rayon-profile-flow-2026-06-28T19-38-44-385530-00-00.pftrace`.
- Final clean log result: no `Firebase-Installations`, no
  `CONSUMER_SUSPENDED`, no `FirebaseMessaging`, no `FIS_AUTH_ERROR`, no
  `FLTFireBGExecutor`, no local Crashlytics component error, and no `[ERROR]`
  or `[WARN]` entries in the collector excerpt.
- Final clean performance result: cold startup `2086 ms`; Perfetto frame
  timeline `372` rows, `0` late/jank frames, max actual-frame duration
  `10.379 ms`; raster thread `357` `GPURasterizer::Draw` slices with `1`
  slice over 16 ms, `0` over 33 ms, average draw `7.092 ms`, max draw
  `21.774 ms`.
- Validation passed with the workspace Flutter 3.44.3 SDK:
  focused analyzer exited 0 for Firebase bootstrap/observability/App Check and
  the startup contract test; focused tests passed 24/24 across
  `firebase_startup_contract_test.dart`, `crashlytics_service_test.dart`, and
  `safe_rpc_test.dart`; profile APK build succeeded; merged manifest checks
  confirmed registrar removal; and the device collector completed successfully.
- Remaining release condition: Firebase observability/App Check are now safely
  gated rather than proven production-ready. Before final release, provide a
  valid production Firebase project, restore/allow the required registrars for
  the enabled SDKs, build with explicit enablement defines, and repeat the
  profile/logcat evidence pass.

## 2026-06-28 Profile Screenshot Responsive Navigation Slice

- Hardened `apps/rayon_sports/scripts/capture_screenshots.py` so automated
  profile captures wait for Home quick-action labels instead of relying on one
  immediate UI hierarchy snapshot. The manifest now records the installed
  build mode and APK metadata, including SHA-256, so screenshot evidence can be
  tied to a concrete profile artifact.
- Fixed Home navigation semantics for primary tab targets. Home quick actions
  and the top Fan Zone/search entry now use `go()` for `/fanzone` and
  `/settings` instead of pushing a duplicate tab route over the Home branch.
  This resolves the profile-device defect where the visible Fan Zone route kept
  the Home bottom tab selected.
- Improved responsive text fitting in shared chrome without retaining the
  higher-raster-cost `FittedBox` approach. The Home command search button shows
  the compact visible label `Search` while preserving the fuller accessibility
  label `Search fans, fixtures, wallet`; the cramped Home primary action uses
  `Support`; and the compact Fan Zone leaderboard route uses `Leaders`.
- Refreshed the Home golden after the intended label-fitting change.
- Final profile APK:
  `apps/rayon_sports/build/app/outputs/flutter-apk/app-profile.apk`, 113 MB,
  SHA-256
  `c7b89e0e88379efe0c42aa70700fc4860dc94fee09eb127aa08b9036efbd88d4`.
- Final Pixel 4a screenshot evidence:
  `apps/rayon_sports/store_metadata/play_store/screenshots_automated_profile_after_low_cost_label_fit_manifest.json`.
  The manifest reports `success: true`, `build_mode: profile`,
  `screenshot_count: 7`, `accessibility_shortcut_hidden: true`, and
  `accessibility_shortcut_restored: true`.
- Captured routes are stored in
  `apps/rayon_sports/store_metadata/play_store/screenshots/automated_profile_after_low_cost_label_fit_2026-06-28/`.
  Visual inspection confirmed Home no longer truncates `Search` or
  the primary support action; Fan Zone now has the Fan Zone bottom tab
  selected; and the compact leaderboard route label fits as `Leaders`.
- Final Pixel 4a performance evidence:
  `apps/rayon_sports/store_metadata/play_store/android_performance_pixel4a_profile_perfetto_after_low_cost_label_fit_manifest.json`
  with trace
  `apps/rayon_sports/store_metadata/play_store/performance_traces/rayon-profile-flow-2026-06-28T20-57-40-290801-00-00.pftrace`.
  Cold startup was `1763 ms`, the app window was focused after settle, and
  critical Firebase startup-noise terms remained absent from the collector log
  excerpt (`Firebase-Installations`, `CONSUMER_SUSPENDED`, `FIS_AUTH_ERROR`,
  `FirebaseMessaging`, `FLTFireBGExecutor`, `Crashlytics`).
- Final Perfetto decode for this slice: frame timeline `377` rows, `1`
  not-on-time/jank frame, average frame duration `10.122 ms`, max frame
  duration `23.814 ms`. Raster remains below full signoff: `370`
  `GPURasterizer::Draw` slices, `341` over 16 ms, `0` over 33 ms, average draw
  `16.630 ms`, max draw `20.160 ms`.
- Validation passed with the workspace Flutter 3.44.3 SDK:
  focused analyzer passed for the touched Home and core_theme widgets; focused
  Home/shell/bottom-nav/Fan Zone tests passed 18/18; the Home golden update
  test passed 7/7; `design_system_source_of_truth_test.dart` passed 31/31; the
  source design-drift report returned 0 findings; `git diff --check` passed;
  profile APK build succeeded; install to Pixel 4a `13111JEC215558` succeeded;
  final automated profile screenshot collection completed successfully; and the
  final profile Perfetto capture/decode completed.
- Remaining release conditions: this closes the debug-only screenshot evidence
  gap for the seven primary marketing/readiness surfaces, but it is still a
  single-device Pixel 4a profile capture. Final release is not performance
  signed off because raster slices remain heavily over the 16 ms budget in the
  latest trace and `gfxinfo` still reports 0 frames for this profile/Impeller
  path. Final release should still include a second form factor or emulator
  size pass, a dedicated raster optimization pass, repeated profile/release
  performance evidence, and the production Firebase observability re-enable
  pass once a valid production Firebase project is available.

## 2026-06-28 Release APK Responsive Evidence Slice

- Rebuilt and installed the current release APK after the compact Home action
  and command-bar fixes. Artifact:
  `apps/rayon_sports/build/app/outputs/flutter-apk/app-release.apk`, 71 MB,
  SHA-256
  `f9d5c81c0774810501910caa03ea7dc783469c95edbcc82c7edcd07b43ae9edc`.
- Added responsive command-bar behavior in
  `packages/core/core_theme/lib/src/widgets/afri_top_command_bar.dart`: the
  search chip keeps the full semantic label `Search fans, fixtures, wallet`
  but falls back to an icon-only visual control when the available slot is too
  narrow for text. This removes the previous `S...` / `Fi...` truncation on
  small-phone captures.
- Tightened Home/Fan Zone visible labels for compact phone widths:
  Home primary action labels now fit as `Fans`, `Support`, and `Live`; the
  Fan Zone leaderboard shortcut fits as `Leaders`; and Home tab navigation
  continues to use `go()` rather than stacking duplicate tab routes.
- Final standard Pixel 4a screenshot evidence:
  `apps/rayon_sports/store_metadata/play_store/screenshots_automated_release_responsive_search_manifest.json`.
  The manifest reports `success: true`, `build_mode: release`,
  `screenshot_count: 7`, `accessibility_shortcut_hidden: true`, and
  `accessibility_shortcut_restored: true`, tied to APK SHA-256
  `f9d5c81c0774810501910caa03ea7dc783469c95edbcc82c7edcd07b43ae9edc`.
- Final small-phone responsive screenshot evidence:
  `apps/rayon_sports/store_metadata/play_store/screenshots_automated_release_responsive_search_small_phone_720x1560_manifest.json`.
  The manifest reports `success: true`, `screenshot_count: 7`, width
  `720`, height `1560`, `build_mode: release`, and the same release APK hash.
  The device display override was reset afterward and verified as physical
  `1080x2340` at density `440`.
- Visual inspection of the final small-phone screenshots confirmed the earlier
  responsive defects are closed: the Home search control is icon-only rather
  than truncated, Home action labels fit, shortcut tiles fit, Fan Zone labels
  fit, and the Fan Zone bottom tab remains selected on the Fan Zone route.
- Final release startup/performance evidence:
  `apps/rayon_sports/store_metadata/play_store/android_performance_pixel4a_release_perfetto_responsive_search_startup_manifest.json`
  with trace
  `apps/rayon_sports/store_metadata/play_store/performance_traces/rayon-profile-flow-2026-06-28T21-46-42-833452-00-00.pftrace`.
  The manifest reports `success: true`, app focus retained after settle,
  cold startup `570 ms`, and zero occurrences in the collector log excerpt of
  `Firebase-Installations`, `CONSUMER_SUSPENDED`, `FIS_AUTH_ERROR`,
  `FirebaseMessaging`, `FLTFireBGExecutor`, `Crashlytics`, or
  `FirebaseCrashlytics component is not present`.
- Final Perfetto FrameTimeline decode for the same release trace: `173`
  actual frame rows, `0` not-on-time finishes, `1` jank-classified frame,
  average actual-frame duration `6.669 ms`, and max actual-frame duration
  `20.912 ms`.
- Collector caveat: horizontal scripted swipes on this Pixel 4a / Android 13
  run were intercepted by the system edge-back gesture and moved the app to the
  launcher, even after narrowing the gesture band and switching to leftward
  swipes. The final accepted release performance evidence is therefore a
  startup/focus Perfetto run plus decoded FrameTimeline metrics, not a full
  scripted interaction jank signoff.
- Validation passed with the workspace Flutter 3.44.3 SDK:
  `dart format` on touched files; focused analyzer on Home/core_theme files;
  Home golden update test passed 7/7; focused Home/shell/bottom-nav/Fan Zone
  plus Firebase startup contract tests passed 22/22; the design-drift report
  returned 0 findings; `git diff --check` passed; and
  `design_system_source_of_truth_test.dart` passed 32/32.
- Remaining blockers before production release signoff:
  production Firebase observability and App Check are intentionally gated off
  by default and still require a valid production Firebase project plus an
  explicit re-enable build/evidence pass; `apksigner` was not available on
  PATH for local signer-certificate verification; Flutter still warns about
  future Kotlin Gradle Plugin migration; and the repo remains too dirty for a
  clean release branch without isolating this mobile remediation slice.

## 2026-06-29 Gikundiro Ticketing, Membership, Fanclubs, Admin, and Home Data Slice

- Added official Gikundiro/Rayon Sports public data helpers:
  `official_membership_tiers.dart` with the six official membership
  categories (`Gold`, `Silver`, `Bronze`, `Imena`, `Inyamibwa`,
  `Ingenzi / Imanzi`), `official_ticket_categories.dart` with the ten
  approved ticket tiers from `General` through `SkyBox`, and
  `official_fanclub_register.dart` with the real user-provided fanclub
  register source/fallback.
- Membership now prefers approved `membership_tiers` rows, normalizes them to
  the existing package UI contract, and falls back only to the official six
  category list. The tier detail screen no longer renders the old FET perk
  model and now resolves official categories, benefits, seating/match access,
  annual prices, and source labels.
- Membership visible surfaces were cleaned of the old FET/Fanzone
  terminology and tracked-letter typography in the card, profile, registry,
  contribution, and progress widgets; they now use official category and
  activity-review wording.
- Fan Clubs now prefer approved, active, public `fanclubs` rows and fall back
  to the verified Gikundiro register when the live data path is unavailable.
  Cards and detail pages no longer show fake ratings or event counts; they
  render public member labels, register status, source labels, region, and
  protected review-path copy.
- Ticket configuration now exposes the official Gikundiro ticket tier ladder
  and uses official General/VIP placement copy while keeping the current
  two-path purchase model until the underlying ticket order schema is expanded.
  The remaining raw seat-button dimensions in this widget were routed through
  shared size/shape tokens.
- Admin match composition now defaults newly created matches to the official
  General and VIP prices (`3,000 RWF` and `30,000 RWF`) while leaving existing
  match records untouched.
- Home fallback shortcuts now mirror the Gikundiro public action model:
  `Tickets`, `Join Gikundiro`, `Fanclubs`, `Shop`, `Matchday`, and
  `Contribute`, mapped to valid Flutter routes such as `/membership` and
  `/fan-clubs`.
- Validation passed with the workspace Flutter SDK:
  focused analyzer exited 0 for `core_theme`, Home, Admin, Ticketing,
  Membership, and Fan Clubs; `design_system_source_of_truth_test.dart` passed
  34/34; Fan Clubs tests passed 12/12; Membership tests passed 14/14 after
  refreshing the intended golden; Ticketing tests passed 8/8; navigation
  journeys passed 10/10; and the Rayon mobile design-drift report returned
  0 findings.
