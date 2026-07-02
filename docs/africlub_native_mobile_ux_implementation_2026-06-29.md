# AfriClub Native Mobile UX Implementation Evidence

Date: 2026-06-29

This document records the code-owned implementation work following the native-mobile UX audit. It is intentionally narrow: device labs, store-console checks, and production telemetry still require external evidence.

## Implemented

- Removed the app-wide text scaling clamp in `AfriClubApp`, so iOS and Android platform text settings can exceed 140%.
- Added a widget regression test that proves `AfriClubApp` preserves 200% platform text scaling through the app shell.
- Added `.fvmrc` pinned to Flutter `3.38.9`, matching the repository CI workflows.
- Corrected `RULES.md` bottom-navigation governance from `Home / Contribute / Settings` to the implemented `Home / Fan Zone / Settings` contract.
- Cleaned scoped analyzer findings in core theme interaction widgets by explicitly handling unawaited haptic and animation futures.
- Kept the design-system drift scanner as the source of truth for raw UI drift and added a full native UX gate script:
  - `tools/scripts/rayon_mobile_native_ux_gate.sh`

## Accessibility Matrix Now Covered In Repo

| Area | Current Evidence | Gap Remaining |
| --- | --- | --- |
| Dynamic type | 200% shell preservation widget test | Manual largest-text pass on representative iOS and Android devices |
| Semantics | Existing core theme/widget tests and screen tests | VoiceOver and TalkBack transcript or checklist evidence |
| Focus/activation | Core theme press feedback tests and analyzer hygiene | Hardware keyboard and switch-control walkthrough evidence |
| Reduced motion | Tokenized motion layer present | Explicit reduced-motion regression tests |
| Contrast | Tokenized color system and drift checks | Automated contrast assertions across core surfaces |

## Performance Evidence Still Required

The repo can now gate static and widget-level regressions, but maximum-native-mobile performance still needs fresh profile or release traces before release sign-off:

- Android profile/release trace covering startup, tab navigation, feed scrolling, ticket/member flows, and scanner shell animation.
- iOS profile/release trace covering the same paths.
- Memory and jank budgets with before/after artifacts stored under `output/` or release evidence.
- Production crash/performance telemetry dashboard links for the current build train.

## Visual Regression Position

Golden coverage now includes the primary shell tabs, Home, Fan Zone, onboarding, membership, ticketing, settings, loading/empty/error states, and 200% text-scale variants for critical surfaces. A full release still needs physical-device screenshot review and intentional-golden-change approval before marketing or store screenshots are considered final.
