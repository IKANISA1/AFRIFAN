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
