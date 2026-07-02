# Rayon Mobile Large-Width Shell Decision

Date: 2026-07-01
Goal: `output/mobi_borrowed_rayon_mobile_ux_full_implementation_goal_2026-07-01.md`

## Decision

Large-width shell adaptation is deferred for this Mobi-borrowed UX rollout.

Rayon Sports mobile remains phone-first for this release, with the supporter
shell governed by the existing three-tab bottom navigation:

- `Home`
- `Fan Zone`
- `Settings`

## Evidence Checked

- `packages/core/core_router/lib/src/app_router.dart` uses
  `StatefulShellRoute.indexedStack` for tab switching.
- `packages/core/core_app/lib/src/shell.dart` owns the supporter shell.
- Search found no current `NavigationRail` implementation in
  `packages/core/core_app`, `packages/core/core_router`,
  `packages/core/core_theme`, or `apps/rayon_sports/lib`.
- The full rollout goal explicitly protects phone bottom navigation and says
  large-width adaptation should be implemented only if tablet, foldable, or
  Flutter web supporter layout is in launch scope.

## Rationale

The comparative Mobi report identified `NavigationRail` as useful only if
tablet/PWA mobile-web is part of launch scope. The current Rayon supporter app
work is focused on phone UX, shared async/banner discipline, route transitions,
Fan Zone hierarchy, and route evidence contracts. Adding a responsive shell now
would touch protected shared chrome and app-shell behavior without a concrete
launch requirement or visual acceptance target.

## Acceptance For This Rollout

- No phone shell or bottom-navigation behavior is changed.
- Admin remains PWA-owned by default and absent from normal supporter mobile
  navigation.
- If tablet/web supporter layout becomes launch scope later, implement a
  separate shell goal with:
  - phone and large-width screenshots/goldens
  - navigation tests for both width classes
  - explicit admin/PWA separation assertions
  - route evidence manifest updates

## Status

Deferred with documented reason. No partial large-width shell changes were made
in this rollout.
