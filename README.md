# AFRICLUB PLATFORM

White-label football-club platform with four product surfaces:

1. Flutter native mobile app for authenticated supporters.
2. Venue app/portal for venue-scoped operators.
3. Centralized admin PWA for club operators.
4. White-label public website for each club.

Rayon Sports is the reference club profile and seeded default. The platform is not a browser fan portal. Authenticated fan journeys belong in Flutter.

## Product Identity And Priority

AFRICLUB is a football club app first. Product decisions follow this order:

1. Club identity, team, news, fixtures, results, standings, and history.
2. Membership, fan clubs, contributions, projects, tickets, and shop.
3. Selected-match football predictions and competitions.
4. Secondary matchday utilities: venue discovery, check-in, bounded drinks
   ordering, and promotions.

The target supporter navigation is `Home · Club · Fan Zone · Membership`.
Settings belongs behind profile. Venue utilities must not displace club or
football destinations in primary navigation.

The governed implementation sequence and evidence gates are in
[`docs/FOOTBALL_CLUB_FIRST_IMPLEMENTATION_PLAN_2026-07-30.md`](docs/FOOTBALL_CLUB_FIRST_IMPLEMENTATION_PLAN_2026-07-30.md).
It is an active plan, not a completion or release claim.

## Current Architecture

- One Melos monorepo for mobile, web, shared packages, and Supabase migrations.
- Melos 8 configuration lives in the root `pubspec.yaml`; workspace dependency
  resolution starts with `flutter pub get`, and repository commands run through
  `dart run melos`.
- One shared Supabase backend with club-scoped tenancy.
- One canonical tenant model:
  - `club_id` for database scoping.
  - `club_slug` for routing, host mapping, and branding resolution.
  - `partner_id` retained only for archived migration compatibility.

### Controlled restructuring checkpoint — 15 August 2026

- AFRICLUB is a football-only workspace: club identity, team, news, fixtures,
  live match information, results, standings, membership, supporter groups,
  contributions, tickets, shop, and free football predictions.
- TV display, trivia participation, question-pack administration, and live
  trivia session operations were transferred to the separate LET'S PLAY
  repository and are no longer registered by this workspace.
- Historical Supabase migrations remain in the immutable migration ledger so
  deployed databases can still replay and reconcile safely. They are not active
  product modules; destructive schema retirement requires a separately
  approved data-retention and deployment runbook.
- The split is source-only and local until both repository branches pass their
  validation gates and an accountable release owner authorizes deployment.

## Product Surfaces

### Flutter Native Fan App

- White-label fan app per club.
- Target mobile hierarchy: Home, Club, Fan Zone, and Membership.
- Club owns official team, news, fixtures, results, standings, history,
  projects, ticket, and shop discovery.
- Fan Zone owns selected-match football predictions and competitions.
- Shared features live in `packages/features/*`.
- Per-club identity lives in `packages/clubs/*`.
- Club apps under `apps/*` are thin shells around shared modules and configuration data.

### Admin PWA

- Centralized multi-club operator workspace.
- Lives in `apps/rayon_sports/web/src/app/admin`.
- Club access is resolved server-side and all admin data operations are scoped by `club_id`.
### Venue App / Portal

- Venue operator surface lives in `apps/rayon_sports/web/src/app/venue`.
- Venue capability is a secondary matchday extension of the football-club
  product, not the app's primary identity.
- Access is scoped by `venue_staff_memberships`.
- Handles assigned-venue dashboard, check-ins, drinks-only top-10 order queue,
  promotions, and staff role visibility.

### Public Website

- White-label public club website.
- Lives in `apps/rayon_sports/web/src/app/(site)`.
- Club branding and content resolve from hostname, slug, and club configuration.
- Website hands users off to the supporter app instead of hosting a fan portal.
- Approved venues can be discovered publicly, but check-in and ordering stay in the supporter app.

## Repo Structure

```text
apps/
  rayon_sports/
    web/                  Next.js website + admin PWA
  <club apps>/            Flutter fan apps

packages/
  core/                   shared app shell, routing, auth, network, theme
  features/               shared product features
  clubs/                  per-club config packages

supabase/
  migrations/             schema and tenancy migrations
```

## Platform Rules

- No unscoped club queries on app data.
- No fan web portal surface.
- No public browser check-in or live venue order queues.
- No broad admin or venue-staff console in the supporter app; the `/admin`
  route family remains excluded from consumer builds.
- LiveScore data remains source-of-record controlled by admin/server sync.
- FET is a closed-loop monetary-equivalent reward ledger until legal/payment review approves otherwise.
- Predictions are free-to-enter and limited to selected approved matches; no
  odds, staking, payout, or betting copy is permitted.
- No frontend hardcoding that assumes Rayon outside reference defaults.
- UI changes must follow `DESIGN.md`, the only design authority for this repo.
- Architecture and runbook documents are operational references only. They must
  not redefine product visuals, screen inventories, token values, or interface
  rules outside `DESIGN.md`.

## Common Commands

```bash
flutter pub get
dart run melos run analyze --no-select
dart run melos run test_all --no-select
(cd apps/rayon_sports/web && npm run typecheck && npm test && npm run lint && npm run build)
npx --yes supabase test db
```

## Key Docs

- [docs/FOOTBALL_CLUB_FIRST_IMPLEMENTATION_PLAN_2026-07-30.md](/Volumes/PRO-G40/AFRICLUB/docs/FOOTBALL_CLUB_FIRST_IMPLEMENTATION_PLAN_2026-07-30.md)
- [docs/blueprint.md](/Volumes/PRO-G40/AFRICLUB/docs/blueprint.md)
- [docs/venue_app_architecture.md](/Volumes/PRO-G40/AFRICLUB/docs/venue_app_architecture.md)
- [docs/fet_ledger_and_rewards_policy.md](/Volumes/PRO-G40/AFRICLUB/docs/fet_ledger_and_rewards_policy.md)
- [docs/release/rayon_fullstack_uat_matrix.md](/Volumes/PRO-G40/AFRICLUB/docs/release/rayon_fullstack_uat_matrix.md)
- [DESIGN.md](/Volumes/PRO-G40/AFRICLUB/DESIGN.md)
- [apps/rayon_sports/web/README.md](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/web/README.md)
- [1supabase.md](/Volumes/PRO-G40/AFRICLUB/1supabase.md)

Confidential & Proprietary — IKANISA Ltd.
