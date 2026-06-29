# Rayon Sports Flutter Fullstack UI/UX Review

Date: 2026-06-29

Scope: Rayon Sports / Gikundiro Flutter mobile app in `/Volumes/PRO-G40/AFRICLUB`, covering shell navigation, all registered Flutter screens, modals/sheets/toasts, Supabase and Firebase integration points, UI/UX flow quality, accessibility risks, and validation gaps.

## Evidence Used

- Source route graph: `packages/app_registry/lib/src/module_registry.dart`, `packages/core/core_router/lib/src/app_router.dart`, `packages/core/core_router/lib/src/feature_module.dart`, and `packages/features/*/lib/src/*_module.dart`.
- Screen inventory: 71 screen files under `packages/features/*/lib/src/screens`.
- Design source of truth: `docs/design.md` and `packages/core/core_theme`.
- Backend contract scan: Supabase `.from(...)`, `.rpc(...)`, and edge-function invocations in app/core/feature packages.
- Current validation:
  - `flutter --version`: Flutter 3.44.3, Dart 3.12.2.
  - Focused `flutter test` set: 68 passing, 4 failing.
  - Focused `flutter analyze` set: 37 info-level issues.
- Current visual artifacts from failed golden tests:
  - `packages/features/feat_home/test/failures/home_screen_testImage.png`
  - `packages/features/feat_home/test/failures/home_screen_masterImage.png`
  - `packages/features/feat_onboarding/test/failures/onboarding_screen_testImage.png`
  - `packages/features/feat_onboarding/test/failures/onboarding_screen_masterImage.png`

Limit: the Product Design audit workflow prefers in-app Browser or Chrome screenshot capture. Browser/Chrome control was not exposed in this session, so this review uses current source, tests, and golden failure screenshots rather than live device walkthrough screenshots.

## Executive Summary

The app is a broad, modular fan super-app with a coherent three-tab mobile shell: Home, Fan Zone, and Settings. The route architecture is largely sound: authenticated flows are guarded, feature flags gate route availability, and most screens use the shared Revolut-borrowed dark design system. Backend integration is real and wide: Supabase drives content, auth, feature management, tickets, membership, fan clubs, shop, FET, predictions, notifications, and admin operations.

The main product risk is not missing screens. It is governance drift and proof drift: yesterday's route inventory is already stale for some Fan Zone routes, Home tests still expect old shortcut labels, and Home/Onboarding golden screenshots fail after recent UI movement. There are also live UX risks around empty states, checkout/payment confirmation, motion accessibility, and a few screens that are visually implemented but functionally constrained or pending protected review.

## Current Navigation Model

### Bottom navigation

Only these modules are allowed in the bottom nav:

| Tab | Route | Role |
| --- | --- | --- |
| Home | `/home` | Command center, CMS/feed, shortcuts, match cards, live/degraded states |
| Fan Zone | `/fanzone` | Prediction, FET, fixtures, rewards, club/social engagement |
| Settings | `/settings` | Account, profile, notifications, privacy, support, sign-out |

All other user-facing areas are entered from Home shortcuts, Fan Zone cards, Settings rows, or deep links. The shell uses `StatefulShellRoute.indexedStack`, preserving tab state.

### Auth and redirect behavior

- Public routes: `/splash`, `/onboarding`, `/auth/phone`, `/auth/otp`, plus `/feature-unavailable`.
- Unauthenticated protected routes redirect to `/onboarding?from=...`.
- Recoverable auth errors redirect to `/auth/phone?from=...`.
- Authenticated users hitting public routes are sent to the deferred destination or `/home`.
- Non-admin users opening `/admin...` are redirected to `/settings`.
- Deep links are normalized, verified against the router, then pushed onto the current stack.

### Feature gating

Modules are registered from `AppModuleRegistry`, then route availability is checked against the Supabase-driven feature config. Hidden features can remain routable for graceful handling; maintenance/disabled features can be removed from module registration.

## Screen And Flow Inventory

### Primary shell

| Screen | Route | User intent | Key interactions | Backend |
| --- | --- | --- | --- | --- |
| Home | `/home` | See club status and enter major app areas | Pull refresh, primary buttons, quick-action grid, match/hero cards, latest intel | `platform_content_blocks`, `quick_actions`, `fan_memberships`, `profiles`, `unified_matches`, `news_articles` |
| Fan Zone | `/fanzone` | Enter engagement, predictions, FET, rewards, club activity | Hub cards, quick routes, prediction slip entry points, FET/reward CTA | Prediction/FET repositories and cached fallback content |
| Settings | `/settings` | Manage profile, privacy, support, sessions | Edit profile, notifications, privacy, support, sign out, delete/account actions | `profiles`, auth session, notification/privacy tables |

### Onboarding and auth

| Screen | Route | User intent | Key interactions | Popups/states |
| --- | --- | --- | --- | --- |
| Splash | `/splash` | Recover session or enter onboarding | Auth restore and redirect | Loading and fallback error states |
| Onboarding | `/onboarding` | Understand app and start | 3-slide PageView, Next/Get started, anonymous sign-in | Error toast if anonymous session fails |
| WhatsApp number | `/auth/phone` | Request OTP | E.164 phone normalization, WhatsApp OTP request, anonymous fallback | Validation/error toasts |
| WhatsApp OTP | `/auth/otp` | Verify code | OTP input, resend cooldown, verify, deferred redirect | Success/error toasts |

### Tickets

| Screen | Route | User intent | Key interactions | Backend |
| --- | --- | --- | --- | --- |
| Tickets list | `/tickets` | Browse match tickets | Filter/sort sheet, Upcoming/Past tabs, refresh, open detail | `unified_matches` via `clubRepositoryProvider` |
| Ticket detail | `/tickets/detail/:id` | Configure and buy ticket | Seat type, quantity, seat map route, checkout step, MoMo USSD launch | `partner_payment_routes`, `purchase_club_tickets`, tickets invalidation |
| Seat map | `/tickets/map/:id` | Select stand/seat | InteractiveViewer, tap map, confirm selected seat | Local hit testing only |
| My Tickets | `/my-tickets` | View ticket wallet | Ticket list, open QR | `tickets` |
| E-ticket QR | `/e-ticket/:id` | Present valid ticket | QR code, pending/not-found states, animated scanner line | `tickets`, nested match row |

### Membership

| Screen | Route | User intent | Key interactions | Backend |
| --- | --- | --- | --- | --- |
| Membership | `/membership` | Join or manage supporter tier | Package cards, activate, MoMo USSD, pending application feedback | `membership_tiers`, `membership_applications`, `fan_memberships`, `partner_payment_routes` |
| Fan registry | `/membership/fans` | Browse public supporter registry | Paginated/searchable fan list | `fan_memberships`, profiles |
| Tier detail | `/membership/tier/:tierId` | Understand tier benefits | Tier fallback/details, CTA back to membership | `membership_tiers` with official fallback |
| Profile | internal/exported screen | View membership profile | Membership card/detail widgets | `fan_memberships` |

### Contributions

| Screen | Route | User intent | Key interactions | Backend |
| --- | --- | --- | --- | --- |
| Contributions hub | `/contribute` | Support club projects/groups | SMS permission modal, sync controls, project/group entry | `contribution_groups`, SMS ledger services |
| Club projects | `/contribute/projects` | Contribute to initiatives | Project list, contribution CTA | contribution/project tables |
| Groups | `/contribute/groups` | Browse contribution groups | Group list and empty states | `contribution_groups` |
| Group detail | `/contribute/group/:groupId` | See group ledger and contribute | MoMo contribution sheet, ledger rows, statement link | `group_contributions`, `profiles`, payment route |
| Statement download | `/contribute/group/:groupId/statement` | Export records | Date range/export; CSV available, PDF currently not available | `momo_ledger_entries`, `group_contributions` |

### Shop

| Screen | Route | User intent | Key interactions | Backend |
| --- | --- | --- | --- | --- |
| Shop | `/shop` | Browse merchandise | Search bottom sheet, category chips, add to cart, checkout bar | `shop_products` |
| Product detail | `/shop/product/:productId` | Inspect and add product | Image, size, quantity, stock validation, add-to-cart toast | `shop_products` |
| Cart | `/shop/cart` | Complete order | Delivery address, MoMo USSD launch, review order sheet, place order | `partner_payment_routes`, `shop_orders` through `clubRepositoryProvider` |

### Fan clubs

| Screen | Route | User intent | Key interactions | Backend |
| --- | --- | --- | --- | --- |
| Fan clubs list | `/fan-clubs` | Find a supporter chapter | Search, region filters, featured card, join intent | `fanclubs` with official register fallback |
| Fan club detail | `/fan-clubs/:clubId` | Review chapter details | Share link, match agenda, join intent | `fanclubs`, `unified_matches` |

### Live

| Screen | Route | User intent | Key interactions | Backend |
| --- | --- | --- | --- | --- |
| Live match | `/live` | See live/upcoming match and news | Refresh/share/open article | `unified_matches`, published news |
| News article | `/live/news/:articleId` | Read club article | Article detail, back/share | `news_articles` |
| Live redirect | `/live-match` | Legacy deep link | Redirect to `/live` | Router redirect |

### Fan Zone detail routes

| Screen | Route | User intent | Key interactions | Backend |
| --- | --- | --- | --- | --- |
| Fixtures browser | `/fanzone/fixtures` | Browse fixtures | Calendar strip, filters, match cards | fixture catalog |
| Live fixtures | `/fanzone/live` | See live fixtures | Live status filter | fixture catalog |
| My predictions | `/fanzone/my` | Manage picks | Tabs, prediction list, cancel | prediction repositories |
| Prediction detail | `/fanzone/my/:predictionId` | Review one pick | Cancel/share/settlement entry | prediction repositories |
| Prediction settlement | `/fanzone/my/:predictionId/settlement` | See outcome | Settled/pending result | prediction repositories |
| Match detail | `/fanzone/match/:fixtureId` | Predict on a match | Tabs for Pools/Stats/H2H/Lineups, market selector sheet, prediction slip sheet | fixture, market, pool, lineup, H2H repositories |
| FET wallet | `/fanzone/wallet` | See points and wallet activity | Balance, ledger, reward links | `fet_events`, memberships, tickets, groups, private contacts |
| Offers | `/fanzone/offers` | Browse partner offers | Offer detail sheet | partner offer data/fallbacks |
| Rewards store | `/fanzone/rewards` | Redeem FET rewards | Redemption CTA/toast | `fet_reward_store_items`, fallback JSON |
| Token history | `/fanzone/history` | View FET activity | Transaction list/filter patterns | FET repository |
| Leaderboard | `/fanzone/leaderboard` | Compare rank | Segmented tabs, rank cards | prediction leaderboard/FET |
| Notifications | `/fanzone/notifications` | Review prediction alerts | Read/unread list | `prediction_notifications_feed` |
| Badges | `/fanzone/badges` | See achievements | Badge grid | FET/badge repository |
| Streak | `/fanzone/streak` | See streak calendar | Calendar state | prediction repository |
| Share card | `/fanzone/share` | Generate share text/card | Copy/share flows | local/gamification content |
| League hub | `/fanzone/league` | Browse competitions | Competition cards/previews | competition catalog |
| League detail | `/fanzone/league/:competitionSlug` | Drill into competition | Standings/fixtures/team links | competition/fixture catalog |
| Standings | `/fanzone/standings/:competitionSlug` | View table | Responsive standings table | `football_standings_catalog` |
| Team profile | `/fanzone/team/:teamSlug` | See team data and contribute | Tabs, contribution dialog | teams, rosters, `partner_payment_routes`, `fan_memberships` |
| Club zone | `/fanzone/club-zone` | Club-specific fan area | Club cards/actions | gamification repositories |
| Fan ID | `/fanzone/fan-id` | Show supporter identity | Privacy toggles/copy/share | `profiles`, local privacy cache |
| Social hub | `/fanzone/social` | Find social/friends content | Social cards/actions | gamification content |
| Fan Zone privacy | `/fanzone/privacy` | Manage fanzone privacy | Toggle privacy settings | `profiles`, local cache |

### Challenge standalone routes

These are outside launch navigation unless `challenge` is explicitly enabled.

| Screen | Route | User intent | Key interactions |
| --- | --- | --- | --- |
| Challenge hub | `/challenge` | Browse stake-based challenges | Tutorial sheet, list |
| Create challenge | `/challenge/create` | Create pool | Review bottom sheet, validation |
| My challenges | `/challenge/my` | Track own challenges | List, empty state |
| Challenge detail | `/challenge/:id` | Join/cancel challenge | Join/cancel toasts |

### Mobile admin routes

Mobile Admin is registered and guarded, but product ownership remains unresolved because `docs/screen_inventory.md` notes a conflict with a centralized Admin PWA direction.

| Screen | Route | Role |
| --- | --- | --- |
| Admin dashboard | `/admin` | Metrics and admin navigation |
| CMS manager | `/admin/cms` | Content blocks/articles |
| Match manager | `/admin/matches` | Match records |
| Contributions monitor | `/admin/contributions` | Contribution groups and reports |
| Push notifications | `/admin/notifications` | Compose/send notification payloads |
| SMS sync monitor | `/admin/sms-monitor` | MoMo SMS raw/parsed/sync status |
| Fixture settlement | `/admin/settle` | Settle prediction fixtures |
| Challenge ops | `/admin/challenges` | Manage prediction/challenge ops |
| Competition manager | `/admin/competitions` | Competition and seasons |
| Feature manager | `/admin/features` | Feature state and channels |
| Feature detail | `/admin/features/:featureKey` | Feature-specific state/rules/audit |

## Popups, Bottom Sheets, Dialogs, Toasts

Major current overlays:

- Auth: phone/OTP error and success toasts.
- Contributions: SMS permission dialog, amount entry bottom sheet, USSD confirmation sheet, success dialog.
- Ticketing: filter/sort sheet, purchase confirmation sheet, ticket request toasts.
- Shop: search bottom sheet, review order sheet, cart/product validation toasts.
- Settings: sign-out/delete/support/privacy confirmation dialogs and sheets.
- Fan Zone: prediction slip sheet, market selector sheet, auth gate sheet, share card sheet, tutorial sheet, offer detail sheet, match contribution sheet.
- Admin: match composer sheet, competition form sheet, season dialog, fixture settlement sheet, feature-state popup menus, CMS confirmation dialogs, admin toasts.

Most overlays route through shared `core_theme` primitives (`showAfriBottomSheet`, `AfriAlertDialog`, `AfriPopupMenuButton`, `AfriToast`). That is a design-system strength.

## UX And Accessibility Strengths

1. Navigation is simple at the primary level. Three bottom tabs prevent a crowded mobile shell, while Home/Fan Zone carry the broader app surface.
2. The app has clear loading/error/degraded states on core flows such as Home, Tickets, Shop, Membership, and auth.
3. The design system is centralized. The guardrail suite passed its scans during the focused test run, including typography, icon, color, button, chip, dialog, sheet, and toast primitive checks.
4. Backend feature management is integrated into route availability and bottom-nav visibility.
5. Sensitive payment setup is fail-closed: membership, ticketing, and shop checkout show pending club activation rather than hardcoding a MoMo recipient.
6. Public launch fallbacks exist for fan clubs and official membership categories, reducing blank launch surfaces when CMS/backend content is incomplete.
7. Auth preserves deferred destinations so users can resume protected routes after onboarding or OTP.

## Findings And Gaps

### P1 - Home fallback tests are stale against current UI labels

Evidence: `HomeQuickAction.fallbackItems` now renders `Fanclubs`, `Join Gikundiro`, `Tickets`, `Shop`, `Matchday`, and `Contribute`, but `home_screen_states_test.dart` still expects `Groups` and `Members`. The current failure screenshot shows `Fanclubs`, not `Groups`.

Impact: release validation fails even though the UI is rendering the current launch-safe labels. This creates false red gates and weakens confidence in Home QA.

Recommendation: update the test assertions and golden baseline to match the approved shortcut taxonomy, or revert labels only if product wants the old wording.

### P1 - Golden screenshots have drifted and need owner review

Evidence:

- Home golden diff: 0.54 percent, 1,823 px.
- Onboarding golden diff: 0.23 percent, 786 px.

Impact: these are small pixel differences, but they are on high-visibility first-run and Home command-center screens. Without approval, it is unclear whether this is acceptable renderer/toolchain drift or unintended UI movement.

Recommendation: inspect `home_screen_testImage.png` and `onboarding_screen_testImage.png` against master images, then either update goldens with owner signoff or fix the visible regression.

### P1 - Route governance docs are inconsistent

Evidence: `docs/rayon_sports_flutter_screen_cleanup_inventory_2026-06-28.md` still lists nested Fan Zone routes such as `challenges`, `jackpot`, `friends`, and `challenge`, while the current `FanzoneModule` no longer registers them and `navigation_journeys_test.dart` explicitly expects them to be absent. Separately, `docs/screen_inventory.md` records a `RULES.md` bottom-nav conflict.

Impact: product, QA, and release signoff can disagree about what the app is supposed to expose.

Recommendation: make `docs/screen_inventory.md` the active route source and retire/update the older cleanup inventory route table.

### P1 - Mobile Admin ownership is unresolved

Evidence: Admin has 11 mobile routes and a guard, but the inventory says Admin ownership conflicts with a centralized PWA direction.

Impact: keeping admin in mobile increases test, security, and navigation surface. It also makes product QA ambiguous: should mobile admin be fully tested, hidden, or PWA-only?

Recommendation: decide whether mobile Admin remains in the app. If yes, add explicit mobile admin acceptance criteria. If no, unregister it from Rayon mobile and keep admin in the PWA.

### P2 - Seat map is accessible as one semantic button, but not as selectable seats/zones

Evidence: `InteractiveSeatMapScreen` uses a custom painted map with one `Semantics` wrapper and local hit testing. It exposes a generic "Interactive stadium seat map" tap action, not individual stand/seat semantics.

Impact: screen-reader and keyboard users cannot choose equivalent specific zones. Pinch/zoom/tap users get a richer interaction than assistive-tech users.

Recommendation: expose each stand/zone as a semantic button or provide an equivalent list selector under the map.

### P2 - E-ticket scanner animation may violate reduced-motion expectations

Evidence: `ETicketQrScreen` starts a repeating scanner animation in `initState` and does not check reduce-motion settings.

Impact: motion-sensitive users cannot disable the scanner line. This is also unnecessary for QR function.

Recommendation: gate the scanner animation behind reduced-motion/accessibility settings or replace it with a static status affordance when motion is disabled.

### P2 - Some empty states intentionally render nothing, but route-level blankness still needs manual checks

Evidence: tickets list and shop category/product empty paths can return `SizedBox.shrink()`. This matches the documented rule to hide empty sections, but entire tabs can appear empty if all sections are unavailable.

Impact: a user can land on a visually blank route without explanatory copy in some data configurations.

Recommendation: keep section-level empties hidden, but add route-level empty states when the whole screen has no content after filters/backend response.

### P2 - Checkout flows launch MoMo before durable confirmation records in some paths

Evidence: ticketing and shop launch MoMo USSD, then create ticket/order records after user confirmation. Membership creates a pending application after MoMo launch.

Impact: if the app backgrounds, process dies, or the user abandons after USSD launch, the backend may lack a durable pending intent for reconciliation.

Recommendation: create a pending payment/order/ticket/application intent before launching USSD, then update status after user confirmation.

### P2 - Analyzer reports async/no-op cleanup debt

Evidence: focused analyzer found 37 info-level issues. Notable categories: discarded futures in shared theme press feedback/scanner/skeleton/toast, shop and ticketing async actions, and no-op primitive operations in shop/provider/scanner code.

Impact: mostly maintainability, but async UI interactions can hide missed haptic/animation/failure behavior.

Recommendation: clean up discarded futures with `unawaited` or `await`, and remove no-op expressions before release-candidate hardening.

### P3 - Fan club join is informational only

Evidence: list and detail join actions show a protected-review-path toast but do not submit a join request from mobile.

Impact: this may be intentional for launch safety, but users can perceive the CTA as non-functional.

Recommendation: either rename the CTA to "Request via admin review" with a clear next step, or wire a pending request table when the backend decision is ready.

### P3 - Localized framework fallback is English for Kinyarwanda

Evidence: app language defaults to `rw`, but framework localizations fall back to English because Flutter does not ship Kinyarwanda material strings.

Impact: app-specific copy can still be localized later, but system labels/date pickers/dialog controls will remain English.

Recommendation: document this as a launch localization limitation and prioritize app-specific Kinyarwanda copy where it matters most.

## Validation Results

### Passed / healthy

- Flutter toolchain: 3.44.3 / Dart 3.12.2.
- Route/shell/design guardrail focused test run: 68 passing tests.
- Design-system guardrails passed within that run.
- Shell navigation tests passed.
- App registry navigation tests passed except unrelated failed Home/Onboarding tests in the same command.

### Failed / needs action

- `packages/features/feat_home/test/home_screen_states_test.dart`
  - `renders fallback home actions when CMS blocks are unavailable`
  - `renders local shortcuts when active club scope is unavailable`
  - `matches the redesigned home command center layout`
- `packages/features/feat_onboarding/test/onboarding_flow_test.dart`
  - `matches the onboarding editorial layout on mobile`
- `flutter analyze ...`
  - 37 info-level issues.

## Recommended Next Actions

1. Resolve Home fallback label/spec drift and update the Home golden after owner review.
2. Review Onboarding golden diff and either approve/update the baseline or fix the drift.
3. Reconcile route governance docs so the route inventory, tests, and modules agree.
4. Decide the mobile Admin ownership question.
5. Add equivalent accessible controls for the seat map and reduce-motion handling for QR scanner animation.
6. Harden payment intent ordering so MoMo launch is preceded by a durable pending backend record.
7. Re-run focused tests sequentially after cleanup, then add a live simulator/browser screenshot pass when capture tooling is available.

## Implementation Addendum - 2026-06-29

Closed in this implementation pass:

- Home fallback labels/tests now match the launch-safe fallback shortcuts: Tickets, Join Gikundiro, Fanclubs, Shop, Matchday, and Contribute.
- Home and Onboarding golden baselines were reviewed through generated failure images, updated, and rerun successfully.
- Mobile Admin is PWA-owned by default. The mobile `AdminModule` is now explicit opt-in through `mobile_admin` or `admin`, and Settings opens the centralized admin workspace URL instead of pushing `/admin`.
- Route governance docs and tests now distinguish default supporter route graph from explicit internal mobile Admin builds.
- Seat map exposes discrete stand-selection buttons as an equivalent accessible control path.
- E-ticket QR scanner animation now respects reduced-motion/accessibility settings, and the QR screen scrolls on compact heights.
- Ticket and shop empty route states now render explicit empty messages instead of blank screens.
- Fan-club CTA copy now says review is required before joining is confirmed.
- Ticket, shop, and paid membership flows now create durable pending records before launching MoMo/USSD.
- Rayon Sports release checklist documents the Kinyarwanda framework-localization limitation.

Validation after implementation:

- `dart analyze` on all changed Dart files: no issues found.
- `flutter test packages/app_registry/test/module_registry_test.dart packages/app_registry/test/navigation_journeys_test.dart packages/features/feat_admin/test/admin_module_test.dart packages/features/feat_settings/test/settings_screens_test.dart packages/features/feat_home/test packages/features/feat_onboarding/test packages/features/feat_fan_clubs/test packages/features/feat_shop/test packages/features/feat_ticketing/test packages/features/feat_membership/test`: 136/136 passed.
- `git diff --check`: passed.

Remaining limitation:

- Whole-repo `flutter analyze --no-pub` still reports pre-existing monorepo debt outside this implementation slice, including generated club app dependency/import warnings, unrelated Admin/theme async-info lints, and unrelated no-op cleanup items.
- Live simulator/browser screenshot capture was not available in this environment; widget/golden evidence was used for UI verification.
