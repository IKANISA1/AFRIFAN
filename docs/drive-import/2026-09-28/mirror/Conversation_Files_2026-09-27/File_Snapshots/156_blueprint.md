# AFRICLUB Football Platform Blueprint

Status: authoritative repository boundary and architecture contract.

The supported club products are Vital'O (Burundi), Rayon Sports (Rwanda),
Nkana (Zambia), AS Vita (DR Congo), and CD Costa do Sol / Os Canarinhos
(Mozambique). Their app directories are `vitalo`, `rayon_sports`, `nkana`,
`as_vita`, and `costa_do_sol`; club configuration packages match those names.
The root workspace contains five shells and five club configuration packages.

## Product Boundary

AFRICLUB is a white-label football-club platform. Its supported capabilities
are:

- club identity, history, squads, news, fixtures, results, standings, and live
  match information;
- free selected-match predictions, competitions, leaderboards, points, and
  Predict entries;
- memberships, supporter groups, projects, contributions, tickets, shop, and
  governed rewards;
- club-scoped public sites and centralized club administration.

Every new feature must strengthen one of those capabilities. A capability that
does not fit this boundary belongs in a different product and must not be added
to this repository, workspace registry, database, navigation, release pack, or
evidence ledger.

## Repository Architecture

```text
apps/
  rayon_sports/          reference Flutter supporter app
    web/                 public club site and club admin
  <club>/                thin white-label Flutter shells

packages/
  app_registry/          feature composition injected into the app shell
  core/                  app shell, auth, routing, networking, theme
  data/                  club data contracts, repositories, and providers
  features/              shared football and club capabilities
  clubs/                 club identity and configuration
  testing/               development-only shared test infrastructure

supabase/
  migrations/            baseline and forward migrations
  functions/             governed backend entry points
  tests/                 database security and behavior contracts

tools/
  scripts/               repository validation and release controls
```

The Flutter workspace is managed from the root `pubspec.yaml` with Melos.
Applications remain thin: shared behavior belongs in packages, while club
shells select identity, configuration, and allowed feature composition.

### Package dependency boundaries

- Each Flutter app imports `core_app`, `app_registry`, its own club package,
  and any directly used platform bootstrap SDK. Feature and test dependencies
  used only by app tests belong in `dev_dependencies`.
- `app_registry` composes feature modules and injects them into `core_app`.
  Core packages do not import features or club configurations.
- `club_data` owns shared membership, shop, ticket, and contribution models,
  the club repository, and its providers. It depends on core infrastructure.
  `feat_club` owns official club content and screens; commerce and membership
  features import the shared data package directly.
- Features depend on core and data packages. Cross-feature runtime dependencies
  are not permitted. SMS collection belongs to a separate club-management
  gateway; supporter apps display server-confirmed payment outcomes and contain
  no message collector, upload queue, consent control or monitoring route.
- `packages/testing/test_support` contains shared test harnesses. Production
  packages may reference it only in `dev_dependencies`.
- Cross-package production imports use public library entry points. Runtime
  dependencies must be declared directly, and the runtime graph must be acyclic.

`dart run tools/scripts/validate_workspace_architecture.dart` enforces these
boundaries in CI alongside strict analysis and tests. Its regression tests run
with `dart run tools/scripts/validate_workspace_architecture_test.dart`.

The Next.js application remains a separate npm package under the reference
club app. Its public site, membership and admin routes share server-side
tenant resolution; Flutter applications do not import its source. Moving that
package is not required to isolate the two runtimes.

## Product Surfaces

### Supporter App

The native Flutter app owns the full supporter experience. The primary
navigation is:

`Home · Club · Predict · Membership`

- Home prioritizes the next useful club action and current football context.
- Club owns team, news, fixtures, results, standings, history, projects,
  tickets, and shop discovery.
- Predict owns fixtures, Home/Draw/Away picks, personal pick history and FET activity.
- Membership owns status, member card, benefits, contributions, supporter
  groups, renewal, and statements.
- Profile owns settings, privacy, notifications, support, language, export,
  and account deletion.


### Public Club Site

The public website resolves club branding and approved content from hostname,
slug, and club configuration. It provides club discovery and links to the
native app. The implemented `/membership` surface also supports WhatsApp
authentication, explicit membership activation, private member details, and
pending contribution intents. Server-side identity and tenant checks protect
these operations; only server receipt reconciliation can confirm a contribution. Device-message collection belongs to the separate future club-management gateway, never to a supporter app.

### Club Administration

The admin PWA is a centralized, multi-club operator workspace. Club scope is
resolved server-side, every mutation is audited, and privileged operations
require explicit role checks in addition to authentication.

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

The first committed Supabase migration is the reproducible baseline for a fresh
environment. Apply subsequent migrations in filename order to reach the current
`public` and `football` schema state. Preserve applied migration history. Static
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
  and contribution mutations remain server-authoritative.
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

The selected `revolut-design` skill is the sole visual and interaction authority; `DESIGN.md` records product mappings only.

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
- generated dependency, build, or evidence output is tracked as source;
- a historical document reintroduces superseded architecture as current
  authority.

Negative checks complement, but do not replace, positive preservation checks
for predictions, football data, memberships, contributions, tickets, shop,
operations.

## Verification Gates

Before merge:

1. repository boundary scan is clean across tracked source and governed
   metadata;
2. Flutter workspace dependency resolution, strict analysis, and all tests
   pass;
3. web typecheck, unit tests, lint, and production build pass;
4. a fresh local Supabase reset applies the baseline, forward migrations, and seed;
5. all database contract tests and schema lint pass;
6. database drift is empty for `public` and `football`;
7. prediction routes, packages, schema objects, and tests are present;
8. Android and iOS build checks pass in the available local environment;
9. generated dependencies, caches, build output, coverage, and evidence stay
   ignored and are absent from the candidate commit.

Local validation is not deployment evidence. Production data reconciliation,
signing, physical-device accessibility, store processing, deployment,
monitoring, and accountable release approval remain separate governed gates.
