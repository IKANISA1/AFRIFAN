# AFRICLUB PLATFORM

White-label football-club platform with four product surfaces:

1. Flutter native mobile app for authenticated supporters.
2. Venue app/portal for venue-scoped operators.
3. Centralized admin PWA for club operators.
4. White-label public website for each club.

Rayon Sports is the reference club profile and seeded default. Flutter owns the full supporter experience. The web membership surface also provides authenticated member access and contribution initiation; payment confirmation remains server-controlled.

The supported club products are:

| App | Club | Country | Tenant ID |
| --- | --- | --- | --- |
| `vitalo` | Vital'O FC | Burundi | 44 |
| `rayon_sports` | Rayon Sports FC / Gikundiro | Rwanda | 24 |
| `nkana` | Nkana FC | Zambia | 26 |
| `as_vita` | AS Vita Club | DR Congo | 6 |

The workspace contains these four app shells and 28 packages: 24 shared packages
and four club configurations. Android and iOS acceptance is tracked separately
for each club, giving eight mobile product/platform targets.

Shared football data still includes opponents used by fixtures and league tables;
those teams have no dedicated app, club configuration package or supported-club
catalog entry.

Current native UI implementation: [route and state review](docs/governance/native-design-review.md) and [reference map](docs/governance/native-reference-map.json).

## Product Identity And Priority

AFRICLUB is a football club app first. Product decisions follow this order:

1. Club identity, team, news, fixtures, results, standings, and history.
2. Membership, fan clubs, contributions, projects, tickets, and shop.
3. Selected-match football predictions and competitions.
4. Secondary matchday utilities: venue discovery, check-in, bounded drinks
   ordering, and promotions.

The target supporter navigation is `Home · Club · Predict · Membership`.
Settings belongs behind profile. Venue utilities must not displace club or
football destinations in primary navigation.

The authoritative architecture and evidence gates are in
[`docs/blueprint.md`](docs/blueprint.md).

## Current Architecture

- One Melos monorepo for mobile, web, shared packages, and Supabase migrations.
- Melos 8 configuration lives in the root `pubspec.yaml`; workspace dependency
  resolution starts with `flutter pub get`, and repository commands run through
  `dart run melos`. The committed root `pubspec.lock` pins the shared Flutter
  dependency graph; CI resolves it with `--enforce-lockfile`.
- One shared Supabase backend with club-scoped tenancy.
- One canonical tenant model:
  - `club_id` for database scoping.
  - `club_slug` for routing, host mapping, and branding resolution.
  - `partner_id` describes business partners where required; it does not replace club scope.

### Current repository boundary

- AFRICLUB contains only football, club, membership, supporter, commerce,
  contribution, ticketing, venue, and FET prediction capabilities.
- Supabase uses a reproducible football-platform baseline, subsequent forward migrations,
  and governed seed data for fresh environments.
- Existing deployed databases require approved forward-only reconciliation;
  this repository state is not authorization to reset or rewrite production.

## Product Surfaces

### Flutter Native Fan App

- White-label fan app per club.
- Target mobile hierarchy: Home, Club, Predict, and Membership.
- Club owns official team, news, fixtures, results, standings, history,
  projects, ticket, and shop discovery.
- Predict owns prepared-fixture picks, personal entries, and FET activity.
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
- Website links to the supporter app and provides the implemented membership
  access and contribution-intent journey at `/membership`.
- Approved venues can be discovered publicly, but check-in and ordering stay in the supporter app.

## Repo Structure

```text
apps/
  rayon_sports/
    web/                  Next.js website + admin PWA
  <club apps>/            Flutter fan apps

packages/
  app_registry/           feature composition and registration
  core/                   shared app shell, routing, auth, network, theme
  data/                   shared club data models, repositories, providers
  features/               shared product features
  clubs/                  per-club config packages
  testing/                test helpers, never a production dependency

supabase/
  migrations/             baseline and forward migrations
```

## Platform Rules

- No unscoped club queries on app data.
- Web membership access uses authenticated server checks. The browser cannot
  confirm payments or grant paid membership from a client claim.
- No public browser check-in or live venue order queues.
- No broad admin or venue-staff console in the supporter app; the `/admin`
  route family remains excluded from consumer builds.
- LiveScore data remains source-of-record controlled by admin/server sync.
- FET is a closed-loop monetary-equivalent reward ledger until legal/payment review approves otherwise.
- Predictions are free-to-enter and limited to selected approved matches; no
  odds, staking, payout, or betting copy is permitted.
- No frontend hardcoding that assumes Rayon outside reference defaults.
- UI review across mobile, websites, Admin PWA and venue web follows the selected
  [`revolut-design` skill](/Users/jeanbosco/.codex/skills/revolut-design/SKILL.md).
  `DESIGN.md` is its product adapter; governance inventories, mappings, runbooks
  and review reports record evidence without overriding the skill.
- Android/iOS release acceptance requires the skill's `MOBILE-DESIGN-100` rule.
  Source checks, tests, screenshots and galleries do not grant visual approval.

## Common Commands

```bash
flutter pub get
dart run melos run analyze --no-select
dart run melos run test_all --no-select
dart run tools/scripts/validate_workspace_architecture.dart
(cd apps/rayon_sports/web && corepack npm run typecheck && corepack npm test && corepack npm run lint && corepack npm run build)
node tools/scripts/validate_repository_boundary.mjs
node tools/scripts/validate_supabase_local_only_migrations.mjs
corepack npm exec --yes --package=supabase -- supabase test db --local
```

Generated evidence belongs in ignored `output/` directories and must be captured
for the candidate being reviewed. Tracked tests and golden baselines remain
source controls; old task reports are not current release status.

## Key Docs

- [docs/blueprint.md](docs/blueprint.md)
- [docs/venue_app_architecture.md](docs/venue_app_architecture.md)
- [docs/fet_ledger_and_rewards_policy.md](docs/fet_ledger_and_rewards_policy.md)
- [docs/release/rayon_fullstack_uat_matrix.md](docs/release/rayon_fullstack_uat_matrix.md)
- [DESIGN.md](DESIGN.md)
- [apps/rayon_sports/web/README.md](apps/rayon_sports/web/README.md)

Confidential & Proprietary — IKANISA Ltd.
