# Rayon Sports Quality Remediation Plan

Date: 2026-04-02

Scope: convert the current review findings for `rayon_sports` / `Gikundiro` into an implementation plan that closes technical soundness, UI/UX, loading, navigation, accessibility, performance, and UAT gaps without drifting from the broader production roadmap in `docs/rayon_sports_fullstack_implementation_plan_2026-04-02.md`.

Primary inputs:

- `docs/rayon_sports_readiness_report_2026-04-02.md`
- `docs/rayon_sports_fullstack_implementation_plan_2026-04-02.md`
- review findings from the 2026-04-02 technical/UX/accessibility/UAT pass
- current Flutter monorepo implementation and test surface

## Target Outcome

Deliver a Rayon Sports app that is:

- technically stable under normal widget, integration, and device-level test execution
- accessible enough to pass a serious internal accessibility QA pass
- explicit and trustworthy in loading, empty, degraded, and error states
- performant on representative Android production hardware
- covered by credible UAT and release gates rather than smoke-only checks

## Current Findings Being Addressed

1. The app-level integration smoke test fails during startup because the test path boots production startup dependencies directly.
2. The bottom nav, hero cards, quick actions, and latest intel cards are still touch-first `GestureDetector` surfaces rather than fully accessible/focusable controls.
3. The bottom nav visual implementation does not match its intended contract for active labels.
4. Home loading is fragmented, and placeholder hero content can look like real empty content.
5. Latest Intel collapses silently on fetch failure.
6. Performance risk exists because the home shell uses multiple blur-heavy surfaces without explicit profile budgets or device evidence.
7. Navigation and UAT coverage are still too shallow for production confidence.

## Program Structure

This remediation program is split into 6 workstreams:

1. App startup and UAT harness stabilization
2. Navigation and accessibility hardening
3. Loading, empty, degraded, and error-state architecture
4. Performance profiling and rendering optimization
5. QA, UAT, and certification coverage
6. Release gates, observability, and rollout control

## Workstream 1: App Startup And UAT Harness Stabilization

### Objective

Make app-level testing reliable so quality claims are based on executable end-to-end signals, not widget-only smoke tests.

### Primary file targets

- `apps/rayon_sports/integration_test/rayon_sports_smoke_test.dart`
- `packages/core/core_app/lib/src/startup_coordinator.dart`
- `packages/core/core_app/lib/src/bootstrap.dart`
- `packages/core/core_network/lib/src/firebase_bootstrap_service.dart`
- `packages/core/core_network/lib/src/app_check_service.dart`

### Implementation tasks

- Split production bootstrap from test bootstrap.
- Introduce a test-safe startup mode that can bypass or fake plugin-bound initialization such as `Hive.initFlutter`, Firebase bootstrap, App Check, and push registration.
- Add explicit startup dependency injection so integration tests can provide fake persistence, fake auth state, fake Supabase responses, and fake content repositories.
- Make the integration harness boot the real app shell and router while substituting only external platform/plugin dependencies.
- Ensure all integration tests can run via `flutter test` in CI without hidden manual setup.
- Add one integration bootstrap test for cold app start.
- Add one integration bootstrap test for anonymous or signed-out state.
- Add one integration bootstrap test for signed-in happy path.

### Backend and platform tasks

- Provide deterministic seed data or fixture injection for `matches`, `news_articles`, and profile-facing records so integration tests do not depend on mutable production-like tables.
- Define a test environment contract for Supabase URL/key usage so app-level tests never hit live services.

### Deliverables

- stable integration test harness
- test bootstrap adapter
- fixture strategy for app-shell tests

### Acceptance criteria

- `flutter test apps/rayon_sports/integration_test/...` passes locally and in CI
- no app-level integration test requires live plugin infrastructure or production credentials
- startup failures are surfaced as test failures, not hidden in manual QA

## Workstream 2: Navigation And Accessibility Hardening

### Objective

Replace touch-only interaction patterns with shared, accessible controls and bring navigation behavior in line with the UI contract.

### Primary file targets

- `packages/core/core_theme/lib/src/widgets/africlub_bottom_nav.dart`
- `packages/features/feat_home/lib/src/widgets/quick_actions_grid.dart`
- `packages/features/feat_home/lib/src/widgets/match_card.dart`
- `packages/features/feat_home/lib/src/widgets/latest_intel_section.dart`
- `packages/core/core_theme/lib/src/widgets/afri_button.dart`
- `packages/core/core_theme/lib/src/widgets/afri_press_feedback.dart`

### Implementation tasks

- Replace raw `GestureDetector` usage on primary tappable surfaces with shared pressable components that support:
  - semantics labels
  - focus highlights
  - keyboard activation
  - tooltip behavior where appropriate
  - minimum tap target sizing
- Introduce or expand a shared `AfriPressable` pattern so navigation surfaces do not each reinvent interaction semantics.
- Update `AfriClubBottomNav` so the active item visually renders its label, matching the intended “icon + label” design.
- Add explicit selected-state semantics and focus order verification for bottom nav items.
- Add semantic labels or explicit action hints for hero slide navigation and content cards.
- Review text contrast and focus visibility on glass/blur surfaces.
- Add screen-reader review notes for:
  - bottom nav
  - quick actions
  - latest intel cards
  - hero slide call-to-action

### QA tasks

- Add widget tests that verify bottom-nav selection semantics.
- Add widget tests that verify keyboard activation on primary controls.
- Add a manual TalkBack and VoiceOver pass for the top-level navigation shell.

### Deliverables

- shared accessible pressable pattern
- corrected bottom-nav visual contract
- accessibility test coverage for primary navigation

### Acceptance criteria

- all primary home and shell navigation surfaces are focusable and keyboard-activatable
- active bottom-nav items show visible labels
- top-level navigation passes internal TalkBack and VoiceOver QA without blocker findings

## Workstream 3: Loading, Empty, Degraded, And Error-State Architecture

### Objective

Make home and content flows trustworthy by ensuring every state is intentional and user-explained.

### Primary file targets

- `packages/features/feat_home/lib/src/screens/home_screen.dart`
- `packages/features/feat_home/lib/src/widgets/latest_intel_section.dart`
- `packages/features/feat_home/lib/src/widgets/match_card.dart`
- `packages/core/core_theme/lib/src/widgets/afri_empty_view.dart`
- `packages/core/core_theme/lib/src/widgets/afri_error_view.dart`

### Implementation tasks

- Replace placeholder-first home loading with a coordinated page-state model.
- Separate home states into:
  - initial loading
  - partial content loading
  - success
  - empty
  - degraded content
  - retryable error
- Add a hero skeleton or suspended hero state instead of defaulting immediately to “no fixture” placeholder content.
- Move loading affordances nearer to the surfaces actually waiting on data.
- Add explicit empty and degraded copy for news/article failures rather than hiding the section.
- Add retry affordances where content is user-recoverable.
- Define stale-data behavior:
  - if cached content exists, render stale content with a “last updated” or degraded label
  - if no content exists, show an explained empty/error state
- Prevent one failing query from collapsing unrelated home sections when the rest of the screen can still load.

### Backend and data tasks

- Review Supabase query failure patterns for `matches`, `fan_memberships`, and `news_articles`.
- Add repository-level timeouts and clearer error mapping so frontend state can distinguish:
  - no data
  - permission issue
  - network issue
  - backend failure
- Define whether news content should support cached fallback or stale-while-revalidate behavior.

### Deliverables

- page-state model for Home
- explicit degraded/error views for Latest Intel
- retry and refresh behavior for content sections

### Acceptance criteria

- no major home surface silently disappears on failure
- loading states are visible where users expect them
- home never presents placeholder content that can be mistaken for resolved real data

## Workstream 4: Performance Profiling And Rendering Optimization

### Objective

Measure and reduce rendering risk on representative production hardware before wider rollout.

### Primary file targets

- `packages/core/core_theme/lib/src/widgets/africlub_bottom_nav.dart`
- `packages/features/feat_home/lib/src/widgets/contributor_leaderboard.dart`
- `packages/features/feat_home/lib/src/widgets/latest_intel_section.dart`
- `packages/core/core_theme/lib/src/widgets/glass_card.dart`

### Implementation tasks

- Define a performance budget for the home screen:
  - cold-start time target
  - time-to-first-usable-home target
  - scroll jank threshold
  - acceptable raster and UI frame times on target devices
- Run profile-mode traces on at least:
  - one low/mid-range Android device
  - one current flagship Android device
- Measure the cost of stacked `BackdropFilter` usage on home and shell surfaces.
- Reduce blur usage or move heavy effects to cheaper alternatives where profiling shows frame drops.
- Ensure large image surfaces use bounded sizes, caching, and placeholders that do not trigger expensive relayout.
- Audit unnecessary rebuilds on `HomeScreen` and supporting widgets.
- Add a profile checklist for image-heavy and blur-heavy screens.

### QA tasks

- Capture before/after profile traces.
- Record frame pacing and scroll smoothness on:
  - home
  - latest intel horizontal list
  - hero carousel
  - bottom nav transitions

### Deliverables

- performance budget document
- device trace evidence
- optimized home rendering path

### Acceptance criteria

- home interaction is smooth on at least one representative mid-range Android device
- any blur-heavy surface kept in production has measured justification
- there is objective trace evidence for performance sign-off

## Workstream 5: QA, UAT, And Certification Coverage

### Objective

Move from smoke checks to realistic route, interaction, degraded-state, and user-journey coverage.

### Primary file targets

- `apps/rayon_sports/integration_test/rayon_sports_smoke_test.dart`
- `apps/rayon_sports/test/rayon_sports_biopay_host_test.dart`
- `packages/features/feat_home/test/home_widgets_test.dart`
- `packages/features/feat_settings/test/settings_screens_test.dart`
- `packages/core/core_app/test/bootstrap_architecture_test.dart`

### Implementation tasks

- Expand integration coverage for the actual top-level user journeys:
  - app boot
  - initial route selection
  - bottom-nav switching
  - home refresh
  - degraded home content
  - settings navigation
  - BioPay tab reachability
- Add route regression tests for back-stack and deep-link behavior.
- Add accessibility assertions for shell navigation and primary content cards.
- Add golden or screenshot-based QA only where visual regressions would be expensive to catch manually.
- Add a UAT matrix that names explicit pass/fail scenarios for:
  - first launch
  - offline startup
  - low-connectivity content loading
  - push-permission prompt path
  - biometric/BioPay entry path
  - account and settings path

### Manual QA matrix

- Device classes:
  - low/mid-range Android
  - flagship Android
  - tablet if supported
- Accessibility modes:
  - TalkBack on
  - larger text / display scaling
  - keyboard or switch-style focus navigation where available
- Network conditions:
  - normal
  - slow 3G equivalent
  - offline

### Deliverables

- expanded integration suite
- UAT scenario matrix
- release certification checklist

### Acceptance criteria

- the app has executable coverage for all top-level routes and primary shell transitions
- UAT sign-off is based on a named checklist, not ad hoc exploration
- degraded/offline behavior has explicit pass/fail criteria

## Workstream 6: Release Gates, Observability, And Rollout Control

### Objective

Make quality regressions block release automatically and make runtime failures visible quickly after rollout.

### Primary file targets

- `.github/workflows/rayon_release_guard.yml`
- `tools/scripts/validate_club_release.sh`
- release and QA docs in `docs/`

### Implementation tasks

- Add CI gates for:
  - `dart analyze`
  - targeted widget tests
  - integration test suite
  - accessibility-focused test slices where feasible
- Fail release if the integration harness is red.
- Add a release checklist section for:
  - accessibility QA pass complete
  - performance trace evidence attached
  - UAT matrix signed off
- Improve runtime observability for content-load and startup failures:
  - startup init failure logging
  - home data fetch failure counts
  - latest intel fetch failure counts
  - navigation crash or route-resolution failure signals
- Define staged rollout controls and rollback triggers tied to crash-free sessions and blocker issue counts.

### Backend and ops tasks

- Ensure backend logs can distinguish client startup, App Check, content fetch, and notification failures.
- Add dashboards or at least queryable log views for:
  - startup failures
  - edge-function failures
  - push delivery failures
  - content query failures affecting home

### Deliverables

- updated CI quality gates
- rollout checklist
- runtime monitoring notes

### Acceptance criteria

- a release cannot proceed with a red integration suite
- startup and content failures are visible in operations
- rollout and rollback criteria are documented before go-live

## Phased Execution Order

## Phase 0: Testability And Shell Safety

Goal: make quality measurable before changing behavior.

Tasks:

- implement test-safe startup bootstrap
- fix integration harness
- add route and shell integration coverage
- add bottom-nav accessibility remediation

Exit criteria:

- integration suite passes
- primary navigation is accessible enough for QA review

## Phase 1: Home State Architecture

Goal: make home trustworthy under all content states.

Tasks:

- refactor `HomeScreen` loading orchestration
- implement hero skeleton / suspended hero state
- implement explicit Latest Intel empty and degraded states
- improve retry and refresh behavior

Exit criteria:

- no silent disappearance of major home content
- no misleading placeholder-first home state

## Phase 2: Performance Evidence And Optimization

Goal: confirm the chosen design language is shippable on target hardware.

Tasks:

- run profile traces
- reduce heavy blur usage where needed
- tune home rendering and image behavior

Exit criteria:

- performance budget met on representative Android hardware

## Phase 3: Certification And Rollout Readiness

Goal: convert engineering fixes into release confidence.

Tasks:

- complete UAT matrix
- run manual accessibility pass
- attach performance evidence
- enforce CI and release-gate updates

Exit criteria:

- release checklist complete
- staged rollout can proceed with named rollback triggers

## Backlog By Priority

### P0

- Fix the broken integration harness.
- Introduce test-safe startup dependency injection.
- Convert bottom nav to a fully accessible/focusable control.
- Replace touch-only primary navigation widgets with shared accessible pressables.

### P1

- Refactor home loading and degraded states.
- Add explicit Latest Intel error and empty UI.
- Add route, refresh, and degraded-state integration coverage.
- Run performance profiling and remove any proven blur bottlenecks.

### P2

- Add broader accessibility automation where feasible.
- Add golden/screenshot checks for the shell and home.
- Expand rollout dashboards and operational alerts.

## Definition Of Done

This remediation plan is complete only when all of the following are true:

- `dart analyze` is clean
- app and feature widget tests are green
- the Rayon integration suite is green in CI
- top-level navigation is keyboard/focus accessible
- home loading, empty, and degraded states are explicit and reviewed
- performance evidence exists for target Android hardware
- UAT and accessibility checklists are complete and signed off
- release gates block regression automatically

## Suggested Ownership Split

- Mobile platform: startup harness, shell navigation, shared pressables, performance tuning
- Feature/frontend: home state architecture, Latest Intel behavior, route coverage
- Backend/platform: fixture strategy, error mapping, observability, content failure visibility
- QA/product: UAT matrix, accessibility pass, device certification, rollout checklist

## Immediate Next Step

Start with Workstream 1 and Workstream 2 together:

1. fix the integration harness so app-level tests are credible
2. harden bottom-nav and primary shell interactions
3. then refactor home loading/error states on top of a stable test foundation

That sequencing keeps the next UI/UX changes measurable and prevents another round of subjective QA without executable proof.
