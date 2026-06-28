# AFRICLUB Revolut-Borrowed UI Goal - 2026-06-27

## Reference Review

Reviewed local implementation references:

- `/Volumes/PRO-G40/COOL/docs/design/DESIGN_SYSTEM.md`
- `/Volumes/PRO-G40/COOL/docs/design/REVOLUT10_SCREENSHOT_ROUTE_REVIEW_MATRIX_2026-06-27.md`
- `/Volumes/PRO-G40/COOL/docs/release/COLLECT_PREMIUM_MOBILE_FRONTEND_COMPLETION_REPORT_2026-06-27.md`
- `/Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/mobi_top_command_bar.dart`
- `/Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/mobi_bottom_nav.dart`
- `/Volumes/PRO-G40/MOBI/mobi_app/lib/shared/widgets/mobi_surface_panel.dart`
- `/Volumes/PRO-G40/COLLECT SCREENS/collect_complete_screen_map.md`

The reusable typology is:

- Route-mapped full-screen vertical gradients.
- Black glass top chrome with profile/search/action circles.
- Floating black glass bottom navigation with active capsule treatment.
- Large rounded translucent cards for finance/member data.
- Compact one-line labels, no decorative explanatory panels.
- Local borrowed finance UI font assets routed through shared typography.

## AFRICLUB Current-State Review

AFRICLUB already has a shared Flutter design-system package, `packages/core/core_theme`, used by club apps through shared shell/components. That is the correct replacement point. The current UI had good module separation but still used a flatter generic dark shell, small/rectangular nav treatment, weaker glass surfaces, a generic route background, and no reference-grade top command chrome on the main home surface.

## Implementation Goal

Replace the previous local shell styling with a shared Revolut-borrowed finance shell while preserving AFRICLUB product behavior:

1. Keep AFRICLUB tab/module contracts intact.
2. Centralize route background families in `ColorTokens.screenGradientForPath`.
3. Use local borrowed font assets from COOL in `core_theme`.
4. Make glass cards use real backdrop blur and finance-panel borders/shadows.
5. Replace bottom nav with floating black glass dock.
6. Add a reusable `AfriTopCommandBar`.
7. Apply route backgrounds and chrome to home, onboarding, and membership.
8. Validate with focused token/nav tests, analyzer, and known test blockers.

## Implemented In This Pass

- Added route-family gradients, black chrome colors, stronger glass tokens, and reference colors in `ColorTokens`.
- Registered `RevolutBorrowed` fonts in `core_theme` and added the copied local font/provenance files.
- Added `AfriTopCommandBar` to `core_theme`.
- Refactored `GradientBackground`, `GlassCard`, `ClayCard`, and `AfriClubBottomNav`.
- Applied `/home`, `/onboarding`, and `/membership` route backgrounds.
- Added top command chrome to `HomeScreen`.
- Kept club accents, crests, routes, and module ordering intact.

## Validation

- `flutter pub get` passed.
- `flutter analyze --no-fatal-infos --no-fatal-warnings packages/core/core_theme packages/features/feat_home packages/features/feat_onboarding packages/features/feat_membership` passed with 41 remaining non-fatal lint items from existing package debt.
- `flutter test packages/core/core_theme/test/design_tokens_test.dart packages/core/core_theme/test/africlub_bottom_nav_test.dart packages/features/feat_home/test/home_widgets_test.dart` passed.
- The `feat_home` widget test harness now declares its `core_auth` test dependency, overrides the auth provider, and uses the current fallback quick-action expectations.

## Remaining Follow-Up

- Capture fresh mobile screenshots for one club app after the existing dirty release/config work is stabilized.
- Extend the top command bar to fanzone/settings surfaces after route-level screenshot review.
