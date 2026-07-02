# MOBI/Revolut 100 Percent Alignment Matrix

Date: 2026-07-02

Scope: repo-level UI/UX and development contract for the Rayon Sports Flutter
mobile app and shared AFRICLUB Flutter packages. Comparator evidence comes from
`/Volumes/PRO-G40/MOBI/mobi_app/design.md`,
`MobiTopCommandBar`, `MobiBottomNav`, `MobiAsyncStateView`,
`MobiStateBanner`, `MobiFeatureTile`, and `app_router.dart`, then maps to
AFRICLUB `docs/design/DESIGN_SYSTEM.md`, `packages/core/core_theme`,
`packages/core/core_app`, `packages/core/core_router`, feature packages, and
route evidence.

Definition of 100 percent: AFRICLUB must match the MOBI/Revolut interaction
quality, hierarchy, density, component discipline, and evidence discipline while
preserving Rayon Sports/AFRICLUB facts, tenant model, club assets, and legal
identity.

| Area | MOBI/Revolut benchmark | AFRICLUB current source | Required AFRICLUB contract | Enforcement / deletion rule |
| --- | --- | --- | --- | --- |
| Design authority | One design system and shared widget library, not parallel reports. | `docs/design.md`, `packages/core/core_theme`, older dated docs. | This matrix plus `DESIGN_SYSTEM.md` are authoritative; `docs/design.md` is a compatibility entrypoint. | Delete superseded recommendation-style design reports instead of leaving them beside this contract. |
| Product identity | Refine current product; preserve business logic and route structure. | Rayon reference club, white-label tenant model, Supabase `club_id`, owned crest/assets. | Borrow UX patterns, not product claims; preserve Rayon/AFRICLUB product facts and approved owned assets. | Any doc implying generic MOBI/Revolut product replacement conflicts with this contract. |
| Shell structure | Persistent bottom shell; compact tab count; state preserved. | `StatefulShellRoute.indexedStack`, `AppShell`, three supporter tabs. | Keep phone supporter shell to `Home`, `Fan Zone`, `Settings`; admin excluded by default. | Tests must reject Admin in normal shell navigation. |
| Top command chrome | Black glass avatar/search/action command bar with two max actions. | `AfriTopCommandBar`. | Primary mobile routes use shared command chrome when top-level actions/search exist. | No feature-local top command bars. |
| Bottom navigation | Floating black glass dock, safe-area aware, active capsule, icon-first. | `AfriClubBottomNav`. | Use shared bottom nav for supporter shell, with compact labels and selected semantics. | No local `BottomNavigationBar` or bespoke nav dock in features/apps. |
| Route backgrounds | Immersive route-mapped vertical gradients. | `ColorTokens.screenGradientForPath`, `GradientBackground`, `AfriScreenScaffold`. | Every full-screen route uses mapped shared gradients, not screen-local gradients. | Drift scan must reject local gradient constructors outside approved token files. |
| Typography | Tight scale, zero letter spacing, short titles, no paragraph bloat. | `TypographyTokens`, bundled `RevolutBorrowed`. | All feature text routes through tokens; labels stay short and sentence case. | No direct feature/app `TextStyle(...)`, raw font families, negative letter spacing, or new font packages. |
| Color system | Dark shell, black chrome, semantic accents, support colors for meaning. | `ColorTokens`, `AfriSemanticColors`, `ExternalBrandColors`. | Club colors are accents only; shell remains borrowed dark/glass system. | No raw `Colors.*` in feature/app UI. |
| Card surfaces | Large rounded translucent cards and readable panels. | `GlassCard`, `AfriSurfaceCard`, `AfriPanelCard`. | Use shared cards for content; use glass for floating chrome and premium overlays. | No feature-local card recipe when shared primitive fits. |
| Buttons | Minimal pill controls with restrained fill and clear hierarchy. | `AfriButton`, `AfriTextButton`, `AfriOutlinedButton`, `AfriElevatedButton`, `AfriIconButton`. | Use shared buttons; choose one primary action per screen or task panel. | No direct Material button constructors in feature/app UI. |
| Feature rows | Icon-led navigation/settings rows with optional subtitle only when needed. | `AfriListRow`, `AfriListTile`, `AfriSwitchListTile`, `AfriFeatureTile` where available. | Replace verbose menu cards with compact icon-led rows and chips. | No local list-row design language. |
| Chips and badges | Status and route metadata expressed as chips/badges, not helper paragraphs. | `AfriChip`, `AfriChoiceChip`, `AfriStatusChip`, `AfriInfoChip`. | Use chips for state, filters, metadata, and compact eligibility. | No direct Material chip constructors in feature/app UI. |
| Async state | One renderer for loading/data/error with domain skeleton hooks. | `AfriAsyncStateView`, `AfriStateView`. | Riverpod-backed screens route loading/error through shared async primitives. | Do not create ad hoc loading/error panels. |
| State banners | Compact inline banner for permission, degraded data, warning, and availability. | `AfriStateBanner`. | Non-fatal states use shared banner, short title, optional subtitle only when it prevents failure. | Delete one-off notice-card patterns. |
| Empty states | Section-level empty data should disappear; screen-level empty states stay deliberate. | `RULES.md` section empty rendering rule; `AfriStateView.empty` for screen-level states. | Hide empty sections; show a screen-level empty state only when the entire route has no taskable data. | Placeholder/coming-soon populated cards conflict. |
| Copy density | Fewer words, fewer competing actions, meaning through widgets. | Feature code and docs must follow compact labels. | Remove explanatory paragraphs from primary surfaces unless they prevent user failure. | Recommendation docs that normalize verbose UI are superseded. |
| Motion | Press feedback, route transition consistency, reduced-motion respect. | `AfriPressFeedback`, `afriRoutePage`, `afriSheetPage`, route transition tests. | Use shared route pages and feedback; honor `disableAnimations` and `accessibleNavigation`. | No raw ad hoc route transitions without documented exception. |
| Pushed routes | Compact pushed-screen chrome and predictable back path. | `AfriAppBar`, `AfriSliverAppBar`, router route pages. | Detail routes use shared pushed chrome or sheet pages, not full custom app bars. | Drift scan/test must reject direct route-level `AppBar`/`SliverAppBar` in feature/app UI. |
| Sheets and modals | Secondary tasks use bottom sheets/action sheets, not new full destinations. | `AfriActionSheet`, `AfriDialog`, `afriSheetPage`. | Filters, confirmations, settings, and secondary detail should use shared sheet/dialog patterns. | Bespoke modal surfaces require core-theme promotion or deletion. |
| Navigation breadth | Primary shell stays focused; secondary routes are sheets, deep links, or hub content. | `FeatureModule.routePresentationDecisions`, `docs/screen_inventory.md`. | Keep the visible supporter app small and route-compatible; avoid growing back into a many-screen tab app. | New visible destinations require screen-inventory and matrix updates. |
| Admin boundary | Admin can exist, but normal passenger/supporter app excludes it. | Admin PWA; mobile admin feature flags only. | Admin is PWA-owned by default; mobile admin is internal opt-in. | Any design doc promoting normal supporter mobile admin conflicts. |
| Search and command actions | Search is black-glass, semantic, one-line, and action-limited. | `AfriTopCommandBar` search slot and action model. | Use search only when a route has real searchable data; no dead decorative search. | Fake search affordances conflict. |
| Accessibility | Semantics, selected state, tooltip, focus, hit target, color-independent status. | Shared widgets and visual coverage tests. | Every interactive shared primitive has semantic labels, focus handling, and minimum target size. | Screen changes need focused accessibility checks. |
| Large text | Labels fit; layouts adapt at 200 percent. | App text-scaling preservation and route goldens. | Hide nonessential nav labels at large text; keep primary tasks usable without clipping. | No global clamp or layout that hides essential controls. |
| Performance | Glass/blur used deliberately; profile/release evidence for heavy routes. | Native UX gate and performance evidence artifacts. | Keep blur/glass centralized; profile when adding heavy animated or scanner surfaces. | Do not claim release-quality premium UX without gate evidence. |
| Offline/degraded state | Direct action and concise state treatment. | `AfriStateBanner`, `AfriStateView.offline`, network error boundaries. | Offline/degraded data appears as compact state, never as a wall of explanatory copy. | One-off offline pages must be replaced. |
| Forms | Shared inputs, short labels, explicit validation, keyboard-safe layout. | `AfriInputField` and shared buttons/sheets. | Auth, OTP, checkout, profile, and admin forms use shared input/button semantics. | Local form-field styling conflicts. |
| Payments/rewards copy | Semantic, non-misleading labels; no cash/betting drift. | Product rules and gamification docs. | Use AFRICLUB-approved rewards/points language; visual style can be finance-grade without implying financial returns. | Docs/code with betting/cash-like consumer positioning require product-boundary cleanup. |
| Public website/admin PWA | Web can share brand discipline but must not become the fan portal. | Root README, web/admin folders. | Flutter mobile owns authenticated fan journeys; admin PWA owns operator workflows. | Design docs must not blur fan mobile and admin/public web ownership. |
| Web design system | Public/admin web has its own implementation, but direction should not contradict mobile. | `apps/rayon_sports/web/src/design-system`. | Web may use web-native components while preserving dark premium club identity and factual handoff to mobile. | Do not copy Flutter-only constraints blindly into web code. |
| Assets | Approved owned assets only; no generated/downloaded placeholders. | Club asset configs and `RuntimeBranding`. | Preserve approved crest/brand assets; request owner approval for new images. | Placeholder image services and generated assets conflict. |
| Localization | Framework fallback may exist; visible copy should be short and localizable. | Locale setup in `AfriClubApp`. | Avoid hardcoded content in features; keep strings ready for localization and Supabase sourcing. | New visible hardcoded product content conflicts with repo rules. |
| Evidence contract | Visual evidence must map to launch routes and states. | `docs/rayon_mobile_visual_evidence_manifest_2026-07-01.md`, route coverage test. | Matrix changes that alter screens require evidence manifest/golden updates. | Do not use absent evidence as proof of alignment. |
| Drift scanning | Raw style and primitive drift fails fast. | `tools/scripts/rayon_mobile_design_drift_report.sh`. | Run drift scan for UI/doc cleanup and before claiming alignment. | If drift is found, fix or document a narrow approved exception. |
| Documentation | Active docs are contract files, not advice piles. | New `DESIGN.md`, `DESIGN_SYSTEM.md`, this matrix. | Design docs must state enforceable rules and source paths. | Old dated recommendation reports should be deleted or replaced by this matrix. |
| Tests | Source-level guardrails prevent old styles from returning. | `core_theme` design tests, router/app tests, route evidence tests. | Add tests when adding a primitive or changing navigation/state behavior. | UI changes without focused tests are incomplete. |
| Release gate | Native-mobile proof bundles static, widget, route, and visual gates. | `rayon_mobile_native_ux_gate.sh`. | Use the native UX gate for major design claims. | Do not mark "100 percent aligned" until the gate has current pass evidence. |

## Comparative Gaps, Findings, And Implementation Plan

This table is the active execution matrix. It converts the comparison into
specific findings, gaps, implementation work, and validation evidence.

| ID | Area | MOBI/Revolut comparator finding | Rayon/AFRICLUB current finding | Gap | Priority | Implementation plan | Validation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UX-01 | Top-level screen command model | MOBI uses a single compact command row: avatar, search, and two max actions. | AFRICLUB has `AfriTopCommandBar`, but route adoption must remain complete as new routes are added. | New top-level screens can regress into local headers or verbose action panels. | P0 | Require top-level mobile routes to use `AfriTopCommandBar` or document why the route is not command-driven. Add new command needs to `core_theme`, not feature code. | Drift scan plus focused widget test for any changed top-level route. |
| UX-02 | Bottom navigation | MOBI uses floating black-glass nav with safe-area handling, active capsule, compact labels, and selected semantics. | AFRICLUB uses `AfriClubBottomNav` for the three-tab supporter shell. | Any new visible tab or admin/mobile route can break the phone-first shell discipline. | P0 | Keep visible supporter tabs to `Home`, `Fan Zone`, `Settings`. Treat new routes as sheets, deep links, or hub content unless explicitly approved. | Shell navigation tests must continue to reject Admin in normal supporter shell. |
| UX-03 | Screen hierarchy and density | MOBI removes explanatory copy and communicates state through widgets, chips, rows, and cards. | AFRICLUB has shared primitives, but broad Fan Zone/game surfaces can still become copy-heavy. | Dense operational/game screens may drift into dashboard-style paragraphs instead of mobile scanning. | P0 | Replace explanatory blocks with `AfriStateBanner`, chips, concise row labels, and bottom sheets. Keep one primary action per panel. | Manual source review plus route/screen widget tests for changed surfaces. |
| UX-04 | Async loading and errors | MOBI centralizes Riverpod async handling with `MobiAsyncStateView` and concise retry states. | AFRICLUB has `AfriAsyncStateView`, `AfriStateView`, and `AfriStateBanner`. | Screens can still introduce ad hoc spinners, local error cards, or verbose empty states. | P0 | Route all provider-backed loading/error/offline paths through shared state primitives. Promote missing state variants to `core_theme`. | `rayon_mobile_design_drift_report.sh` and focused tests for loading/error states. |
| UX-05 | Empty sections | MOBI avoids fake populated cards and keeps helper copy minimal. | AFRICLUB `RULES.md` requires empty sections to render nothing. | New game/reward/wallet areas can reintroduce placeholder or coming-soon sections. | P0 | Hide empty section-level data. Use screen-level `AfriStateView.empty` only when the whole destination has no actionable data. | Drift report placeholder-copy check plus feature tests for empty providers. |
| UX-06 | Route transition model | MOBI uses shared page transitions and defers heavier routes selectively. | AFRICLUB uses shared `afriRoutePage` and `afriSheetPage`; deferred loading is documented but not broadly applied. | New detail routes may bypass shared transitions or grow startup cost without evidence. | P1 | Require detail routes to use shared route builders. Defer only after profiling proves startup or first-route-load cost. | Router tests and native UX gate when route behavior changes. |
| UX-07 | Sheet and modal model | MOBI uses bottom sheets for secondary tasks, keeping the shell focused. | AFRICLUB has `AfriActionSheet`, `AfriDialog`, and sheet route helpers. | Filters, confirmations, and secondary detail can become full-screen custom routes. | P1 | Use sheets/dialogs for filters, confirmations, secondary settings, and short detail tasks. | Widget tests for sheet launch/dismiss and route evidence manifest updates if visible behavior changes. |
| UX-08 | Typography | MOBI uses tight scale, zero letter spacing, and short labels. | AFRICLUB uses `TypographyTokens` and bundled `RevolutBorrowed`. | Feature-local `TextStyle`, raw font family, or tiny font-size drift can return. | P0 | Keep typography in `core_theme`; replace direct `TextStyle` with `TypographyTokens`. | `core_theme` source-of-truth tests and drift report. |
| UX-09 | Color and gradient system | MOBI uses dark shell, black chrome, and semantic accents. | AFRICLUB has `ColorTokens`, `AfriSemanticColors`, and route gradients. | Feature-local colors/gradients can create a one-off look that contradicts the benchmark. | P0 | Use `ColorTokens.screenGradientForPath` and shared gradient helpers. Club colors only accent state, focus, and identity. | Drift report raw color and local-gradient checks. |
| UX-10 | Product identity | MOBI keeps product logic and identity intact while refining UX. | AFRICLUB must preserve Rayon facts, tenant model, club assets, and legal product boundaries. | A literal visual/product clone would be wrong; non-enforcing comparator language is also too weak. | P0 | Match interaction quality and design discipline while keeping AFRICLUB/Rayon data, copy, assets, and product claims factual. | Design review against `DESIGN.md`, product rules, and Supabase-backed data sources. |
| UX-11 | Rewards, wallet, and game language | MOBI finance-grade UI is precise and stateful. | AFRICLUB game/Fan Zone work still has product-boundary risk around wallet/token/betting-like language. | Premium finance styling could imply financial return or regulated prediction behavior if copy is not controlled. | P0 | Keep visual polish but migrate consumer copy to approved rewards/points/challenge language. Hide or quarantine betting/cash-like UI semantics. | Product-boundary scan plus focused Fan Zone/game tests. |
| UX-12 | Admin boundary | MOBI has admin routes but guards them by role/session. | AFRICLUB admin is PWA-owned by default, with mobile admin internal opt-in only. | Mobile supporter UX can become polluted if admin appears in nav, settings, or route evidence. | P0 | Keep admin out of normal mobile shell. Any internal mobile admin surface must be feature-flagged and tested separately. | Shell tests and route inventory checks. |
| UX-13 | Accessibility | MOBI widgets expose semantics, selected state, tooltip, and compact hit targets. | AFRICLUB shared widgets provide many semantics and large-text accommodations. | New local widgets can skip semantic labels, focus states, reduced motion, or 200 percent text behavior. | P0 | Build interactions from shared primitives. Add semantics and large-text tests for any new custom interaction. | Widget tests, golden/route evidence, and native UX gate for major changes. |
| UX-14 | Performance | MOBI centralizes expensive glass/blur and keeps route depth controlled. | AFRICLUB uses blur/glass and has native UX gate evidence, but new game/controller surfaces can add load. | Premium visuals can regress frame pacing on low-end Android if heavy effects spread into features. | P1 | Keep blur/glass in shared primitives. Profile heavy new screens and scanner/game flows before claiming release quality. | Native UX gate, profile traces, and route-specific performance evidence. |
| UX-15 | Documentation governance | MOBI keeps a clear design source and component ownership. | AFRICLUB had active docs plus many dated reports. | Old reports created contradictory or weaker guidance beside the active contract. | P0 | Delete superseded design reports; keep one active contract and one matrix. Do not add dated recommendation reports as parallel guidance. | Stale-reference scan and repo review before design changes. |
| UX-16 | Evidence discipline | MOBI uses tests around shared widgets and readiness contracts. | AFRICLUB has route evidence manifest and mutation-proof coverage test. | Matrix claims can drift from app evidence if route screenshots/goldens are stale. | P0 | Update evidence manifest and goldens whenever visible route behavior changes materially. | `rayon_mobile_visual_coverage_contract_test.dart` and native UX gate. |
| UX-17 | Web/public/admin surfaces | MOBI comparison is mobile-first. | AFRICLUB also has public web and admin PWA. | Web/admin can contradict mobile direction or turn into a fan portal. | P1 | Keep authenticated fan journeys in Flutter mobile; admin remains operator PWA; public site hands off to mobile. Web may share premium dark identity without copying Flutter-only constraints. | Web lint/typecheck/tests for touched web surfaces plus docs review. |
| UX-18 | Component ownership | MOBI shared widgets define repeated jobs once. | AFRICLUB `core_theme` owns reusable visual primitives. | Feature packages may duplicate components for speed. | P0 | Promote reusable visual behavior to `core_theme`; feature widgets stay business-specific and token-driven. | Source scan for duplicated local patterns and focused tests for new core primitives. |

## Implementation Phases

| Phase | Objective | Work | Exit criteria |
| --- | --- | --- | --- |
| Phase 0 | Governance cleanup | Keep this matrix and `DESIGN_SYSTEM.md` as the only active design contract. Remove or rewrite contradictory dated docs. | No stale design-doc references outside the matrix deletion log. |
| Phase 1 | Source drift prevention | Run the drift scanner and fix raw typography, color, gradient, nav, button, chip, list, empty-state, and image drift. | `rayon_mobile_design_drift_report.sh --fail-on-findings` returns `0`. |
| Phase 2 | Primary shell alignment | Verify Home, Fan Zone, Settings, onboarding, auth, ticketing, membership, and shop against command chrome, bottom nav, route gradients, typography, state handling, and large text. | Focused route/widget tests pass; visual evidence manifest remains mapped. |
| Phase 3 | Fan Zone/game product cleanup | Align rewards/game/wallet language and surfaces to club-safe rewards/challenge semantics while preserving shared MOBI/Revolut UX polish. | Product-boundary scan passes and consumer-facing copy avoids betting/cash-like implications. |
| Phase 4 | Evidence refresh | Refresh goldens/screenshots only for routes whose visible behavior changed. Keep admin/internal routes excluded from supporter evidence unless explicitly in scope. | Visual coverage contract and relevant golden tests pass. |
| Phase 5 | Native UX gate | Run the matrix validator and the full native mobile gate for major UI claims, especially after shell, route, game, or heavy visual changes. | `validate_mobi_revolut_alignment_matrix.sh` and the native UX gate pass with current artifacts and no stale evidence claims. |

## Deletion Decisions Applied

The following files were superseded because they are dated, recommendation-style,
or redirect-only design/audit reports that weaken the single-contract model:

- `docs/design_mandate.md`
- `docs/revolut_borrowed_ui_goal_2026-06-27.md`
- `docs/revolut_borrowed_repo_cleanup_goal_2026-06-28.md`
- `docs/rayon_sports_mobile_audit_2026-06-28.md`
- `docs/rayon_sports_mobile_readiness_goal_2026-06-28.md`
- `docs/rayon_sports_flutter_screen_cleanup_inventory_2026-06-28.md`
- `docs/rayon_sports_fullstack_ui_ux_review_2026-06-29.md`
- `docs/africlub_native_mobile_ux_audit_2026-06-29.md`
- `docs/africlub_native_mobile_ux_implementation_2026-06-29.md`
- `docs/protected_surface_triage_2026-06-28.md`

The following evidence/decision artifacts remain because they are current
enforcement support rather than competing design direction:

- `docs/screen_inventory.md`
- `docs/blueprint.md`
- `docs/rayon_mobile_visual_evidence_manifest_2026-07-01.md`
- `docs/rayon_mobile_large_width_shell_decision_2026-07-01.md`
- `docs/rayon_mobile_deferred_route_classification_2026-07-01.md`

## Required Next Review Pattern

For every future UI/UX change:

1. Identify applicable rows in this matrix.
2. Confirm the shared primitive or token that owns the behavior.
3. Delete or replace conflicting local docs/artifacts in the same change.
4. Run the focused drift/test gate for the touched surface.
5. Update route/evidence docs when the visible behavior changes.
