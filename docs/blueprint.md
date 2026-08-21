# AFRICLUB Football Platform Blueprint

Status: authoritative repository boundary and architecture contract.

## Product Boundary

AFRICLUB is a white-label football-club platform. Its supported capabilities
are:

- club identity, history, squads, news, fixtures, results, standings, and live
  match information;
- free selected-match predictions, competitions, leaderboards, points, and
  supporter challenges;
- memberships, supporter groups, projects, contributions, tickets, shop, and
  governed rewards;
- secondary matchday utilities for approved venues, including discovery,
  check-in, bounded ordering, promotions, and staff operations;
- club-scoped public sites and centralized club administration.

Every new feature must strengthen one of those capabilities. A capability that
does not fit this boundary belongs in a different product and must not be added
to this repository, workspace registry, database, navigation, release pack, or
evidence ledger.

## Repository Architecture

```text
apps/
  rayon_sports/          reference Flutter supporter app
    web/                 public club site, club admin, venue portal
  <club>/                thin white-label Flutter shells

packages/
  core/                  app shell, auth, routing, networking, theme
  features/              shared football and club capabilities
  clubs/                 club identity and configuration
  shared/                reusable non-product utilities

supabase/
  migrations/            one reproducible football-platform baseline
  functions/             governed backend entry points
  tests/                 database security and behavior contracts

tools/
  scripts/               repository validation and release controls
```

The Flutter workspace is managed from the root `pubspec.yaml` with Melos.
Applications remain thin: shared behavior belongs in packages, while club
shells select identity, configuration, and allowed feature composition.

## Product Surfaces

### Supporter App

The native Flutter app owns authenticated supporter journeys. The primary
navigation is:

`Home · Club · Fan Zone · Membership`

- Home prioritizes the next useful club action and current football context.
- Club owns team, news, fixtures, results, standings, history, projects,
  tickets, and shop discovery.
- Fan Zone owns free predictions, supporter competitions, leaderboards, and
  points.
- Membership owns status, member card, benefits, contributions, supporter
  groups, renewal, and statements.
- Profile owns settings, privacy, notifications, support, language, export,
  and account deletion.

Venue utilities remain secondary matchday actions and never replace football
or club destinations in primary navigation.

### Public Club Site

The public website resolves club branding and approved content from hostname,
slug, and club configuration. It provides club discovery and hands
authenticated supporter work to the native app. It must not duplicate private
supporter journeys.

### Club Administration

The admin PWA is a centralized, multi-club operator workspace. Club scope is
resolved server-side, every mutation is audited, and privileged operations
require explicit role checks in addition to authentication.

### Venue Portal

The venue portal is scoped through `venue_staff_memberships`. It supports the
assigned venue dashboard, approved check-in campaigns, a bounded order queue,
promotions, and staff visibility. It is an extension of matchday operations,
not an independent primary product.

## Tenancy And Identity

- `club_id` is the canonical database tenant key.
- `club_slug` is the canonical route, host, and branding key.
- `partner_id` may exist only where a current business relationship requires
  it; it must not replace club scope.
- Browser or client-provided tenant identifiers are untrusted until checked
  against authenticated server context.
- Every sensitive query, policy, function, storage path, and realtime channel
  must fail closed when club scope is absent or conflicting.

## Backend Contract

The committed Supabase migration is the reproducible baseline for a fresh
environment. It contains the final `public` and `football` schema state. Static
football catalog and structural configuration data are replayed from
`supabase/seed.sql`.

Database rules:

- RLS is enabled on every exposed table.
- Authentication is not authorization; policies include ownership or tenant
  predicates.
- Views exposed through the Data API use invoker security or are explicitly
  protected.
- Privileged functions use fixed search paths, explicit grants, and internal
  authorization checks.
- Client roles receive only the minimum table, column, function, sequence, and
  publication privileges required by the product.
- Prediction placement, settlement, points, inventory, ticketing, membership,
  contribution, and venue mutations remain server-authoritative.
- No secret or production user data is committed as seed data.

## Predictions Contract

Predictions are free to enter and available only for selected approved
fixtures and markets. AFRICLUB does not present odds, staking, wagering,
cash-out, or guaranteed-return language.

The server owns eligibility, locking, idempotency, official results,
settlement, points, badges, leaderboards, notifications, and audit records.
Clients render authoritative state and provide clear pending, locked, settled,
void, offline, and retry states.

## UI And UX Contract

`DESIGN.md` is the single visual and interaction authority.

Football-first composition rules:

- the first viewport answers what is happening with the club and what the
  supporter can do next;
- live and upcoming fixtures outrank secondary utilities;
- cards use one clear purpose, one dominant action, and concise state copy;
- loading, empty, error, offline, permission, disabled, selected, focused,
  success, warning, and destructive states are designed explicitly;
- compact phones, standard phones, tablets, landscape, large text, light and
  dark themes, keyboard, focus, and reduced motion are covered where
  applicable;
- supporter data, member identifiers, payment references, private contacts,
  and operator-only fields are masked in screenshots and analytics;
- rights-gated imagery fails closed to approved placeholders.

## Ownership Enforcement

Repository validation must fail when any of these occurs:

- an application or package is registered outside the football-platform
  boundary;
- a route or navigation item points to an unsupported product surface;
- a database schema, routine, relation, policy, seed row, or publication
  restores unsupported ownership;
- generated build output or an obsolete evidence directory is committed or
  left in the validated worktree;
- a historical document reintroduces superseded architecture as current
  authority.

Negative checks complement, but do not replace, positive preservation checks
for predictions, football data, memberships, contributions, tickets, shop,
and venue operations.

## Verification Gates

Before merge:

1. repository boundary scan is clean across tracked source and governed
   metadata;
2. Flutter workspace dependency resolution, strict analysis, and all tests
   pass;
3. web typecheck, unit tests, lint, and production build pass;
4. a fresh local Supabase reset applies the single baseline and seed;
5. all database contract tests and schema lint pass;
6. database drift is empty for `public` and `football`;
7. prediction routes, packages, schema objects, and tests are present;
8. Android and iOS build checks pass in the available local environment;
9. the working tree contains no generated dependency, cache, build, coverage,
   or evidence-output directory.

Local validation is not deployment evidence. Production data reconciliation,
signing, physical-device accessibility, store processing, deployment,
monitoring, and accountable release approval remain separate governed gates.
