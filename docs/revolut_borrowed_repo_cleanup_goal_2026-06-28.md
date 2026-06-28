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

## Remaining Work

- Rename backwards-compatible `Clay*` and `Elite*` widgets to borrowed-system names, leaving temporary aliases only where needed for staged migration.
- Migrate remaining feature screens that still use local gradients, direct colors, raw borders, or bespoke card/nav treatments.
- Refresh goldens after the borrowed typography and deleted font fixtures settle.
- Add source guardrails for no direct `fontFamily`, no negative `letterSpacing`, no feature-local gradients, and no stale design docs.
- Capture mobile route screenshots for the Rayon shell after analyzer and focused tests pass.

## Validation Gates

- `flutter pub get`
- `dart format` on touched Dart files
- `flutter analyze --no-fatal-infos --no-fatal-warnings` on touched package set
- `flutter test` for `core_theme`, `test_support`, home/onboarding/membership/settings/ticketing/gamification focused suites
- source scans for forbidden typography/docs terms
