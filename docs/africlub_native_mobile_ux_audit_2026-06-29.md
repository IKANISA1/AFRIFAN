# AFRICLUB Native Mobile UX Audit

Date: 2026-06-29
Scope: `/Volumes/PRO-G40/AFRICLUB`, focused on the Rayon Sports Flutter mobile app, shared Flutter packages, route architecture, design system, accessibility, performance posture, and visual-regression coverage.
Conclusion: **not yet maximum native-mobile quality**. The app has a strong modular foundation and much better design-system governance than a typical prototype, but it cannot be called top-tier native mobile until large-text accessibility, release/profile performance evidence, device screenshot coverage, dependency/toolchain governance, and full-route visual QA are closed.

## Benchmark Used

Official/native standards used as the audit baseline:

- Flutter app architecture: https://docs.flutter.dev/app-architecture/guide
- Flutter adaptive and responsive design: https://docs.flutter.dev/ui/adaptive-responsive
- Flutter accessibility and accessibility testing: https://docs.flutter.dev/ui/accessibility-and-internationalization and https://docs.flutter.dev/ui/accessibility/accessibility-testing
- Flutter performance best practices: https://docs.flutter.dev/perf/best-practices
- Flutter testing overview: https://docs.flutter.dev/testing/overview
- Apple Human Interface Guidelines and accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- Android core app quality and vitals: https://developer.android.com/docs/quality-guidelines/core-app-quality and https://developer.android.com/topic/performance/vitals
- Material Design 3: https://m3.material.io
- WCAG 2.2: https://www.w3.org/TR/WCAG22/

## Validation Run

Commands run from `/Volumes/PRO-G40/AFRICLUB`:

| Gate | Result |
| --- | --- |
| `git status --short --branch` | Clean: `## main...origin/main` |
| `flutter --version` | Flutter `3.38.9`, Dart `3.10.8` |
| `bash tools/scripts/rayon_mobile_design_drift_report.sh --fail-on-findings` | Passed, `0` findings |
| `flutter test packages/core/core_theme/test` | Passed, `73` tests |
| `flutter test packages/app_registry/test packages/core/core_app/test apps/rayon_sports/test/rayon_sports_shell_navigation_test.dart` | Passed, `41` tests |
| `flutter test` for Home, Onboarding, Membership, Settings, Ticketing golden/state tests | Passed, `22` tests |
| Scoped `flutter analyze --no-fatal-infos --no-fatal-warnings ...` | Exit 0, but `34` info issues |

Not run in this pass: full `melos run analyze`, full `melos run test_all`, Android/iOS release builds, profile-mode trace, physical-device accessibility scan, store-readiness checks, or live Supabase/Firebase validation. Those remain evidence gaps.

## Current Strengths

1. **Architecture is real, not a screen pile.** The repo is a Flutter workspace with app, core, feature, and club packages. The route contract is modular through `FeatureModule`, `AppModuleRegistry`, and GoRouter. The primary bottom-tab contract is centralized as `home`, `fanzone`, and `settings` in `packages/core/core_router/lib/src/feature_module.dart`.

2. **The mobile shell is disciplined.** `AppRouter` builds a `StatefulShellRoute.indexedStack`, preserves tab state, collects standalone routes, and redirects disabled features to `/feature-unavailable`. Auth redirects preserve deferred destinations.

3. **Design-system governance is unusually strong.** The design guardrails enforce centralized `ThemeData`, tokenized typography, no raw GoogleFonts, no direct feature `TextStyle`, no local gradients, no raw borders, shared buttons/chips/list rows/inputs/dialogs/sheets/toasts, and no legacy surface names. The dedicated drift script also passed with zero raw TextStyle, raw color, Navigator, Material button, placeholder copy, emoji, or local-gradient findings.

4. **Accessibility primitives exist.** Shared controls such as `AfriPressFeedback`, `AfriButton`, `AfriClubBottomNav`, state views, toasts, cards, and seat-map stand selection expose semantic labels, selected state, hints, focus behavior, or equivalent controls in many places.

5. **Reduced-motion handling is partially implemented.** Splash, Home animated sections, skeletons, e-ticket QR scanner, and several shared components check `disableAnimations` or `accessibleNavigation`.

6. **Visual regression exists and is currently green for key surfaces.** Home, Onboarding, Membership, Settings, and Ticketing goldens/state tests passed in this run.

## Critical Findings

### P0 - Large-Text Accessibility Is Blocked By A Global Text Clamp

Evidence: `packages/core/core_app/lib/src/app.dart` clamps `MediaQuery.textScaler` to max `1.4`.

Impact: the app cannot honestly pass 200 percent text-scale validation while the root tree prevents users from reaching that scale. This conflicts with the repo's own screen inventory, which repeatedly requires 200 percent verification, and it conflicts with native accessibility expectations around Dynamic Type / large fonts.

Fix:

- Remove the global clamp or replace it with per-component layout fixes.
- Add widget tests at `textScaler: TextScaler.linear(2.0)` for Home, Fan Zone, Settings, Onboarding, OTP, Ticket Detail, Seat Map, Membership, Cart, QR, and FET Wallet.
- Only use component-level defensive truncation where content is genuinely nonessential.

### P1 - Platform-Native Appearance Is Constrained By Forced Dark Mode

Evidence: `MaterialApp.router` is hard-wired to `ThemeMode.dark` with the same theme passed to `theme` and `darkTheme`.

Impact: this may be an intentional brand mandate, but it is not a maximum native experience. Users who expect system appearance, high-contrast variants, or lighter reading contexts get no adaptive option.

Fix:

- Record the product decision: brand-locked dark mode or native system mode.
- If aiming for maximum native UX, add a light/system theme path through `ThemeModeNotifier`, and add goldens for light, dark, high contrast, and large text.

### P1 - Performance Is Not Proven In Profile Or Release Mode

Evidence: static source shows heavy visual effects including `BackdropFilter` blur in the bottom nav and multiple glass/blur surfaces. Firebase Performance collection is gated behind `ENABLE_FIREBASE_OBSERVABILITY`; there is no app-specific profile trace or frame benchmark in this pass.

Impact: the UI may look premium but can still jank on low-end Android, especially in scrolling Fan Zone, Home, Shop, QR, and animated glass surfaces. Without profile-mode evidence, there is no basis to call startup, frame pacing, image loading, battery, or memory world-class.

Fix:

- Add a repeatable profile test matrix: cold start, Home scroll, Fan Zone scroll, match detail tabs, Shop product image load, QR screen, Ticket checkout, and OTP entry.
- Capture `flutter run --profile` timeline data on a low-end Android device/emulator.
- Add performance budgets: startup time, first meaningful frame, worst frame build/raster time, image cache memory, and app size.
- Degrade or disable blur/glass intensity under low-power, reduced-motion, or older-device conditions.

### P1 - Visual Regression Coverage Is Too Narrow For The Route Surface

Evidence: five golden baselines exist, while `docs/screen_inventory.md` lists a much broader route surface: Home, Onboarding/Auth, Ticketing, Membership, Contributions, Shop, Fan Clubs, Live, Fan Zone detail routes, Challenge opt-in routes, and Mobile Admin/internal routes.

Impact: the current green goldens prove selected surfaces, not full native-mobile polish. High-risk screens such as Fan Zone, FET Wallet, Match Detail, Cart, Seat Map, QR, Live, Privacy, Contributions, and Shop Search can regress visually without a baseline.

Fix:

- Expand goldens by journey and state, not by every file: Home, Fan Zone hub, Match Detail, FET Wallet, My Predictions, Shop, Cart, Ticket Detail, Seat Map, QR, Membership, Contributions, Settings, OTP.
- For each, capture at least compact mobile, large phone, text scale 2.0, reduced motion, and error/empty/loading states.
- Store screenshots or golden diffs as release evidence, not just test files.

### P1 - Analyzer Is Not Clean Under The Repo's Own Strict Standard

Evidence: scoped `flutter analyze --no-fatal-infos --no-fatal-warnings` found 34 info issues. The repo's `melos.yaml` defines `analyze` as `flutter analyze --fatal-infos --fatal-warnings`.

Impact: the scoped analyzer command exits only because fatal infos were disabled. Under the declared Melos standard, these infos would block. The most relevant quality issues are discarded futures in shared feedback/scanner/skeleton/toast components and a noop expression in `afri_scanner_shell.dart`.

Fix:

- Clean the 34 scoped analyzer infos.
- Then run `melos run analyze` without suppressing infos.
- Treat new analyzer infos in shared UI as regressions because they affect all club apps.

### P1 - Toolchain And Dependency Governance Are Loose

Evidence: current shell uses Flutter `3.38.9` / Dart `3.10.8`; an older local report cited Flutter `3.44.3`, so that prior validation is stale for this environment. Dependency resolution reported `77` packages with newer versions incompatible with current constraints.

Impact: visual goldens, analyzer behavior, Material rendering, platform embeds, and plugin behavior can drift across machines. The app has no visible `.fvmrc` in this inspection to pin the Flutter toolchain.

Fix:

- Pin the Flutter SDK version for this repo with `.fvmrc` or an equivalent checked-in toolchain contract.
- Add a dependency-review lane: `flutter pub outdated`, package risk review, and staged plugin upgrades.
- Do not upgrade all packages blindly; prioritize Firebase, Supabase, go_router, Riverpod, permission/storage, and image/cache plugins.

### P1 - Native Device Evidence Is Missing In This Audit Pass

Evidence: this pass ran source, analyzer, widget, routing, and golden checks. It did not run Android/iOS device screenshots, TalkBack/VoiceOver checks, physical keyboard traversal, profile-mode traces, or release builds.

Impact: Flutter widget tests do not prove native feel. Safe areas, keyboard overlays, status/nav bars, platform text input, OTP autofill, webview/URL launches, permissions, haptics, scroll physics, system back, and wallet/USSD handoffs need real device proof.

Fix:

- Run Android low-end, Android modern, iPhone compact, and iPhone large-device smoke.
- Capture route screenshots after build/install.
- Include TalkBack/VoiceOver audit notes for onboarding, OTP, bottom nav, checkout, QR, and seat map.

### P2 - Route Governance Still Needs One Source Of Truth

Evidence: `docs/screen_inventory.md` says current bottom tabs are `Home`, `Fan Zone`, and `Settings`, while it also notes a stale `RULES.md` conflict that says `Home`, `Contribute`, `Settings`.

Impact: engineers, QA, and product can sign off different route contracts. The code and tests are aligned today, but documentation still carries a launch-governance risk.

Fix:

- Make `docs/screen_inventory.md` the current route contract.
- Update or retire the conflicting `RULES.md` wording.
- Add a CI check that fails if primary bottom-tab labels drift without a screen-inventory update.

### P2 - Observability Exists But Is Not Operationally Proven

Evidence: Crashlytics, Analytics, and Firebase Performance are implemented behind `ENABLE_FIREBASE_OBSERVABILITY`; Crashlytics only records when initialized, and Performance collection is only toggled during Firebase bootstrap. This audit did not verify production Firebase project linkage, dashboard ingestion, or release crash/ANR alerts.

Impact: production reliability claims are not yet evidence-backed. A polished native app needs crash-free sessions, ANR/vitals tracking, performance traces, and alert ownership.

Fix:

- Verify Firebase project, Android/iOS app IDs, Crashlytics symbols/mapping upload, Performance collection, and Analytics event ingestion in staging.
- Define release-health KPIs: crash-free users, ANR rate, cold-start budget, slow frames, failed OTP, failed payment launch, and failed sync.

### P2 - Accessibility Tests Need To Move From Spot Checks To A Matrix

Evidence: semantic labels and a few semantics tests exist, but the suite does not yet show Flutter guideline checks such as tappable target, labeled controls, scrollability, and contrast/large-text matrix across critical journeys.

Impact: accessibility is partially designed, not yet comprehensively verified.

Fix:

- Add `meetsGuideline` tests for tap targets, labels, and text contrast where Flutter can assert it.
- Add screen-reader acceptance notes for custom controls: bottom nav, match markets, QR, seat map, OTP, Fan Zone privacy, and filter/search sheets.
- Add keyboard traversal checks for app bar actions, bottom nav, forms, sheets, and segmented controls.

### P2 - Community And Privacy Flows Need Store-Policy Evidence

Evidence: routes exist for Social Hub, Friends, Fan Zone Privacy, notification preferences, account deletion, and profile privacy. This pass did not prove moderation, report/block, user-generated content handling, or account deletion completion paths.

Impact: for a fan community app, store review risk is not just UI polish. UGC, identity, notifications, and privacy require verifiable flows and policy links.

Fix:

- Add explicit report/block/moderation paths if user-generated content or social interaction is live.
- Verify account deletion in-app and web parity.
- Add privacy/data-safety mapping for phone, MoMo, location if any, contacts/discovery, notifications, analytics, Crashlytics, and FET/wallet data.

## Priority Remediation Backlog

### 0-7 Days

1. Remove or redesign the global text-scale clamp; add 2.0 text-scale tests for the main shell and onboarding/auth.
2. Clean the 34 scoped analyzer infos and run the repo's strict analyzer.
3. Add performance profiling scripts for cold start, Home, Fan Zone, and Shop.
4. Update route governance docs so only one bottom-nav contract exists.
5. Add current device screenshot evidence for Home, Fan Zone, Settings, Onboarding, OTP, Ticket Detail, and QR.

### 8-21 Days

1. Expand goldens to Fan Zone, Match Detail, FET Wallet, Shop, Cart, Contributions, Live, Seat Map, and QR.
2. Add accessibility guideline tests and screen-reader notes.
3. Add low-end Android profile traces and define frame/startup budgets.
4. Pin Flutter SDK tooling and create a dependency governance plan.
5. Prove observability ingestion in staging.

### 22-45 Days

1. Add full release build gates for Android and iOS.
2. Add real-device UAT matrix with screenshots, video, accessibility, and performance artifacts.
3. Add store-policy evidence for account deletion, privacy, UGC/social moderation, notifications, and payment/USSD flows.
4. Create a release evidence manifest that ties source, tests, screenshots, performance, accessibility, and store readiness together.

## Final Verdict

AFRICLUB/Rayon Sports is beyond prototype quality: the architecture, feature gating, shared design system, route tests, design drift scans, and selected goldens are solid. The critical gap is proof at native runtime quality. The app should not be marketed internally as "maximum native mobile" until it passes large text without a clamp, has broad golden/state coverage, runs clean under strict analyzer settings, proves release/profile performance on devices, and produces current accessibility/device evidence for the high-risk fan, ticketing, payment, privacy, and gamification flows.
