# Rayon Sports Flutter Screen Inventory

Updated: 2026-06-28

This inventory is the governance baseline for the Rayon Sports Flutter mobile
app. It is source-backed from the current feature modules, router,
`docs/design.md`, `docs/blueprint.md`, `RULES.md`, and the active
Revolut-borrowed cleanup report.

Active cleanup report:

- `docs/revolut_borrowed_repo_cleanup_goal_2026-06-28.md`

Source route contracts:

- `packages/core/core_router/lib/src/feature_module.dart`
- `packages/core/core_router/lib/src/app_router.dart`
- `packages/app_registry/lib/src/module_registry.dart`
- `packages/features/*/lib/src/*_module.dart`

## Governance Notes

- Current bottom tabs are source-backed as `Home`, `Fan Zone`, and `Settings`.
  `packages/core/core_router/lib/src/feature_module.dart` allows only
  `home`, `fanzone`, and `settings` in the bottom tab order.
- `RULES.md` still contains an older statement saying the bottom navigation is
  `Home · Contribute · Settings`. That conflicts with current router/module
  source and with `packages/app_registry/test/module_registry_test.dart`.
  Treat this as a governance inconsistency until the owner resolves it.
- `RULES.md` locks `home_screen.dart`, Home-exclusive widgets, and
  `packages/core/core_theme`. Remediation touching those areas needs owner
  approval or a documented owner decision.
- Admin is centralized in the PWA by default. `AdminModule` remains available
  only for explicit internal mobile builds with `mobile_admin` or `admin`
  enabled in the club feature map.
- This file records current source state. It is not a release signoff.

## State Definitions

- Loading: data is being fetched or startup/auth is resolving.
- Data: the intended populated screen state.
- Empty: route has no data to show. Section-level empty states must render
  nothing under `RULES.md` section 2.3.
- Error: user-recoverable failure state.
- Auth: whether the route is public, authenticated fan, or admin/internal.
- Accessibility/Responsive: baseline obligations for Phase 2 verification.

## Primary Shell

| Screen | Route | Module | Auth | States To Verify | Accessibility And Responsive Notes |
| --- | --- | --- | --- | --- | --- |
| Home | `/home` | `HomeModule` | Authenticated fan | loading, data, section-empty, error | Locked surface. Verify six zones hide empty sections, bottom safe area, dynamic text, focus order, reduced motion. |
| Fan Zone | `/fanzone` | `FanzoneModule` | Authenticated fan | loading, data, empty, error | Verify prediction modules, quick actions, leaderboard access, 200 percent text, tab semantics. |
| Settings | `/settings` | `SettingsModule` | Authenticated fan | loading, data, empty, error | Verify account actions, privacy/notification links, destructive-action semantics, keyboard focus. |

## Onboarding And Auth

| Screen | Route | Module | Auth | States To Verify | Accessibility And Responsive Notes |
| --- | --- | --- | --- | --- | --- |
| Splash | `/splash` | `OnboardingModule` | Public | loading, redirect, error fallback | Verify no blocked first frame, branding fallback semantics, reduced motion. |
| Onboarding | `/onboarding` | `OnboardingModule` | Public | carousel data, final CTA, error | MOMO must not be collected. Verify page indicators, CTA hit target, 200 percent text. |
| WhatsApp Number | `/auth/phone` | `OnboardingModule` | Public | input, submitting, error | Verify keyboard type, label, validation errors, small-phone layout, and route handoff to OTP. |
| WhatsApp OTP | `/auth/otp` | `OnboardingModule` | Public | code input, verifying, resend cooldown, missing-phone error | Verify OTP field semantics, resend state, back/change-number path, 200 percent text, and small-phone layout. |

## Ticketing

| Screen | Route | Module | Auth | States To Verify | Accessibility And Responsive Notes |
| --- | --- | --- | --- | --- | --- |
| Tickets List | `/tickets` | `TicketingModule` | Authenticated fan | loading, data, empty, sold out, error | Section/category empty states must hide. Verify filters, card hit targets, price readability. |
| Ticket Detail | `/tickets/detail/:id` | `TicketingModule` | Authenticated fan | loading, data, unavailable, error | Verify quantity controls, checkout CTA, match metadata, large text. |
| Seat Map | `/tickets/map/:id` | `TicketingModule` | Authenticated fan | loading, map data, unavailable, error | Verify pinch/selection accessibility, selected-seat semantics, small screen constraints. |
| My Tickets | `/my-tickets` | `TicketingModule` | Authenticated fan | loading, data, empty, error | Screen-level empty state is allowed only if deliberate and not a fake populated card. |
| E-Ticket | `/e-ticket/:id` | `TicketingModule` | Authenticated fan | loading, valid ticket, expired, error | Verify QR accessibility fallback, wallet actions, brightness and contrast. |

## Membership

| Screen | Route | Module | Auth | States To Verify | Accessibility And Responsive Notes |
| --- | --- | --- | --- | --- | --- |
| Membership | `/membership` | `MembershipModule` | Authenticated fan | loading, data, no tier, error | Verify tier cards, progress indicators, contribution CTA, 200 percent text. |
| Fan Registry | `/membership/fans` | `MembershipModule` | Authenticated fan | loading, data, empty, error | Verify list semantics, masked identities, search/filter controls. |
| Tier Detail | `/membership/tier/:tierId` | `MembershipModule` | Authenticated fan | loading, data, unknown tier, error | Verify benefits, CTA state, back navigation, tablet width. |

## Contributions

| Screen | Route | Module | Auth | States To Verify | Accessibility And Responsive Notes |
| --- | --- | --- | --- | --- | --- |
| Contributions Hub | `/contribute` | `ContributionsModule` | Authenticated fan | loading, data, empty, error | Verify no empty initiative cards, SMS sync controls, MOMO privacy. |
| Club Projects | `/contribute/projects` | `ContributionsModule` | Authenticated fan | loading, data, empty, error | Hide empty project categories. Verify contribution CTA semantics. |
| Groups | `/contribute/groups` | `ContributionsModule` | Authenticated fan | loading, data, empty, error | Existing empty-state test exists; verify it matches `RULES.md` section 2.3. |
| Group Detail | `/contribute/group/:groupId` | `ContributionsModule` | Authenticated fan | loading, data, not found, error | Verify member/contribution lists, MOMO sheet, masked personal data. |
| Group Statement | `/contribute/group/:groupId/statement` | `ContributionsModule` | Authenticated fan | loading, date range, export, error | Verify date fields, export format controls, focus traversal. |

## Shop

| Screen | Route | Module | Auth | States To Verify | Accessibility And Responsive Notes |
| --- | --- | --- | --- | --- | --- |
| Shop | `/shop` | `ShopModule` | Authenticated fan | loading, data, empty category, no products, error | Hide empty categories. Verify search/filter controls, product grid breakpoints. |
| Cart | `/shop/cart` | `ShopModule` | Authenticated fan | loading, items, empty cart, payment pending, error | Verify quantity controls, total updates, payment state, small-phone overflow. |
| Product Detail | `/shop/product/:productId` | `ShopModule` | Authenticated fan | loading, data, out of stock, not found, error | Verify image fallbacks, variant selection, add-to-cart semantics. |

## Fan Clubs

| Screen | Route | Module | Auth | States To Verify | Accessibility And Responsive Notes |
| --- | --- | --- | --- | --- | --- |
| Fan Clubs | `/fan-clubs` | `FanClubsModule` | Authenticated fan | loading, featured, list, empty, error | Hide featured section when no featured clubs exist. Verify list/card semantics. |
| Fan Club Detail | `/fan-clubs/:clubId` | `FanClubsModule` | Authenticated fan | loading, data, not found, error | Verify join/leave CTA, member count, privacy, large text. |

## Live

| Screen | Route | Module | Auth | States To Verify | Accessibility And Responsive Notes |
| --- | --- | --- | --- | --- | --- |
| Live Match | `/live` | `LiveModule` | Authenticated fan | loading, live, scheduled, no live match, error | No empty match panel if no live/upcoming match. Verify live-region semantics if scores update. |
| News Article | `/live/news/:articleId` | `LiveModule` | Authenticated fan | loading, article, not found, error | Verify article typography, back action, share action, large text. |
| Live Match Redirect | `/live-match` | `LiveModule.standaloneRoutes` | Authenticated fan | redirect | Redirects to `/live`; verify deep-link compatibility. |

## Fan Zone Detail Routes

All routes in this section are nested under `/fanzone` and owned by
`FanzoneModule` unless noted otherwise.

| Screen | Route | Auth | States To Verify | Accessibility And Responsive Notes |
| --- | --- | --- | --- | --- |
| Fixtures Browser | `/fanzone/fixtures` | Authenticated fan | loading, fixtures, empty, error | Verify filter chips, fixture cards, no empty section cards. |
| Live Fixtures | `/fanzone/live` | Authenticated fan | loading, live fixtures, empty, error | Verify live status is not color-only. |
| My Predictions | `/fanzone/my` | Authenticated fan | loading, predictions, empty, error | Verify provider/state ownership and empty behavior remain consistent. |
| Prediction Detail | `/fanzone/my/:predictionId` | Authenticated fan | loading, data, not found, error | Verify market/outcome semantics and back path. |
| Prediction Settlement | `/fanzone/my/:predictionId/settlement` | Authenticated fan | loading, settled, pending, error | Verify result status is not color-only. |
| Match Detail | `/fanzone/match/:fixtureId` | Authenticated fan | loading, data, not found, error | Verify tabs, stats, H2H, lineups, responsive tables. |
| FET Wallet | `/fanzone/wallet` | Authenticated fan | loading, balance, partner rewards, ledger activity, empty, error | Verify privacy, partner-led ledger copy, and no public transfer/manual redemption controls. |
| Offers | `/fanzone/offers` | Authenticated fan | loading, offers, empty, error | Hide empty offer sections. Verify deep-link CTA states. |
| Rewards Store | `/fanzone/rewards` | Authenticated fan | loading, rewards, empty, error | Verify item grid, redemption controls, unavailable state. |
| Token History | `/fanzone/history` | Authenticated fan | loading, history, empty, error | Verify list semantics and filter controls. |
| Leaderboard | `/fanzone/leaderboard` | Authenticated fan | loading, ranked users, fewer than 3, error | Hide top supporters if fewer than 3 ranked users exist. Verify semantic rank icons. |
| Notifications | `/fanzone/notifications` | Authenticated fan | loading, notifications, empty, error | Verify notification toggles and read/unread semantics. |
| Badges | `/fanzone/badges` | Authenticated fan | loading, badges, empty, error | Verify responsive layout and empty behavior. |
| Streak | `/fanzone/streak` | Authenticated fan | loading, calendar, empty, error | Verify calendar semantics and small-screen scrolling. |
| Share Card | `/fanzone/share` | Authenticated fan | data, generation, error | Verify no generated/embedded image asset is added without owner approval. |
| League Hub | `/fanzone/league` | Authenticated fan | loading, data, empty, error | Verify competition tabs and standings previews. |
| League Hub Detail | `/fanzone/league/:competitionSlug` | Authenticated fan | loading, data, not found, error | Verify slug not found handling. |
| League Standings | `/fanzone/standings/:competitionSlug` | Authenticated fan | loading, table, empty, error | Verify table readability on narrow screens. |
| Team Profile | `/fanzone/team/:teamSlug` | Authenticated fan | loading, data, not found, error | Verify tier icons stay semantic and responsive at large text. |
| Club Zone | `/fanzone/club-zone` | Authenticated fan | loading, data, empty, error | Verify club-specific data remains config/provider-driven. |
| Fan ID | `/fanzone/fan-id` | Authenticated fan | loading, data, missing profile, error | Verify identity privacy; never display `auth.uid()`. |
| Social Hub | `/fanzone/social` | Authenticated fan | loading, data, empty, error | Verify moderation and privacy states. |
| Fan Zone Privacy | `/fanzone/privacy` | Authenticated fan | data, saved, error | Verify toggles, confirmations, screen-reader labels. |

## Challenge Standalone Routes

These routes are outside AFRICLUB launch scope and require an explicit
`challenge` feature flag. Partner WDW pools are the launch prediction-game
surface.

| Screen | Route | Module | Auth | States To Verify | Accessibility And Responsive Notes |
| --- | --- | --- | --- | --- | --- |
| Challenge Hub | `/challenge` | `ChallengeModule` | Authenticated fan | loading, challenges, empty, error | Opt-in only; do not expose in launch navigation. |
| Create Challenge | `/challenge/create` | `ChallengeModule` | Authenticated fan | input, review, submit, error | Verify form validation and keyboard behavior. |
| My Challenges | `/challenge/my` | `ChallengeModule` | Authenticated fan | loading, list, empty, error | Hide empty sections. |
| Challenge Detail | `/challenge/:id` | `ChallengeModule` | Authenticated fan | loading, data, not found, error | Verify participant list, stake visibility, status semantics. |

## Mobile Admin Routes

These routes remain implemented inside `AdminModule` for explicit internal
mobile builds only. Rayon/Gikundiro supporter builds do not register them by
default; admins should use the centralized PWA.

| Screen | Route | Module | Auth | States To Verify | Accessibility And Responsive Notes |
| --- | --- | --- | --- | --- | --- |
| Admin Dashboard | `/admin` | `AdminModule` | Admin/internal opt-in | loading, authorized, denied, error | PWA-owned by default; verify route guard only in explicit internal mobile builds. |
| CMS Manager | `/admin/cms` | `AdminModule` | Admin/internal | loading, list, edit, error | PWA-owned candidate. |
| Match Manager | `/admin/matches` | `AdminModule` | Admin/internal | loading, list, edit, error | PWA-owned candidate. |
| Contributions Monitor | `/admin/contributions` | `AdminModule` | Admin/internal | loading, data, empty, error | PWA-owned candidate. |
| Push Notifications | `/admin/notifications` | `AdminModule` | Admin/internal | loading, compose, sent, error | PWA-owned candidate. |
| SMS Sync Monitor | `/admin/sms-monitor` | `AdminModule` | Admin/internal | loading, data, empty, error | PWA-owned candidate. |
| Fixture Settlement | `/admin/settle` | `AdminModule` | Admin/internal | loading, fixture, settle, error | PWA-owned candidate. |
| Challenge Ops | `/admin/challenges` | `AdminModule` | Admin/internal | loading, data, action, error | PWA-owned candidate. |
| Competition Manager | `/admin/competitions` | `AdminModule` | Admin/internal | loading, data, edit, error | PWA-owned candidate. |
| Feature Manager | `/admin/features` | `AdminModule` | Admin/internal | loading, data, edit, error | PWA-owned candidate. |
| Feature Detail | `/admin/features/:featureKey` | `AdminModule` | Admin/internal | loading, data, not found, error | PWA-owned candidate. |

## Cross-Cutting Verification Checklist

Apply these checks to every screen before release-candidate signoff:

- No user-visible section renders if its data source is empty or unavailable,
  except deliberate screen-level empty states.
- No hardcoded club content, visible fixture data, scores, player names, or
  membership copy lives in feature source.
- No image generation, downloaded assets, placeholder image services, or
  hardcoded `Image.network()` URLs are introduced without owner approval.
- Colors, typography, spacing, radii, and surfaces route through
  `packages/core/core_theme` tokens and shared primitives.
- No emoji characters are used as UI icons.
- Navigation uses GoRouter APIs; direct `Navigator` usage must be documented as
  an approved exception.
- Interactive controls have semantic labels, roles/selected state where
  applicable, focus behavior, and adequate hit targets.
- Text is readable at 200 percent text scale without clipping or overlapping.
- Status is not conveyed by color alone.
- Reduced motion is respected for decorative animation.
- Phone numbers and identity values are masked; `auth.uid()` is never shown.
- Startup, jank, memory, image loading, and lifecycle behavior are profiled on
  real or emulated mobile targets during Phase 4.

## Open Phase 0 Items

- Resolve the `RULES.md` bottom-nav wording conflict with current router source.
- Triage the dirty worktree and identify which protected-file changes are owner
  approved, remediation-owned, unrelated user work, or revert candidates.
- Keep app shell navigation tests aligned with the current three-tab source
  contract.
- Keep analyzer and focused widget tests green as the borrowed-system cleanup
  continues.
