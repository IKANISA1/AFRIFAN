# AFRICLUB Fantasy Fullstack Implementation Plan

Date: 2026-04-10

Primary inputs:

- `/Users/jeanbosco/Downloads/africlub_fantasy_guide.docx.md`
- [README.md](/Volumes/PRO-G40/AFRICLUB/README.md)
- [docs/blueprint.md](/Volumes/PRO-G40/AFRICLUB/docs/blueprint.md)
- [1supabase.md](/Volumes/PRO-G40/AFRICLUB/1supabase.md)
- [packages/core/core_app/lib/src/module_registry.dart](/Volumes/PRO-G40/AFRICLUB/packages/core/core_app/lib/src/module_registry.dart)
- [packages/features/feat_home/lib/src/screens/home_screen.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_home/lib/src/screens/home_screen.dart)
- [packages/features/feat_home/lib/src/repositories/home_content_repository.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_home/lib/src/repositories/home_content_repository.dart)
- [packages/features/feat_home/lib/src/widgets/quick_actions_grid.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_home/lib/src/widgets/quick_actions_grid.dart)
- [packages/features/feat_home/lib/src/widgets/match_card.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_home/lib/src/widgets/match_card.dart)
- [apps/rayon_sports/web/src/app/(site)/page.tsx](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/web/src/app/(site)/page.tsx)
- [apps/rayon_sports/web/src/app/(site)/_sections/hero-block.tsx](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/web/src/app/(site)/_sections/hero-block.tsx)
- [apps/rayon_sports/web/src/lib/data/public/cms.ts](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/web/src/lib/data/public/cms.ts)
- [apps/rayon_sports/web/src/lib/data/admin/cms-content.ts](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/web/src/lib/data/admin/cms-content.ts)
- [packages/core/core_network/lib/src/app_config_repository.dart](/Volumes/PRO-G40/AFRICLUB/packages/core/core_network/lib/src/app_config_repository.dart)
- [supabase/migrations_archive/20260410T151245Z/20260408103000_cms_multitenant_scope.sql](/Volumes/PRO-G40/AFRICLUB/supabase/migrations_archive/20260410T151245Z/20260408103000_cms_multitenant_scope.sql)
- [supabase/migrations/20260410151531_remote_schema_baseline.sql](/Volumes/PRO-G40/AFRICLUB/supabase/migrations/20260410151531_remote_schema_baseline.sql)

## Executive Decision

The source guide is directionally strong, but it should not be implemented verbatim in this repository.

AFRICLUB Fantasy should be built as:

- a Flutter-first gameplay feature
- a read-only public web discovery and handoff surface
- an admin-operated competition and promo surface
- a Supabase-backed scoring platform with club-scoped rollout controls
- a provider-qualified competition engine, not a provider-assumed engine

Because today is April 10, 2026 and the FIFA World Cup 2026 starts on June 11, 2026, a fully generalized platform that launches World Cup fantasy, Premier League fantasy, Rwanda league fantasy, and multiple country-local leagues at the same time is not realistic without unacceptable delivery risk.

Recommended launch sequence:

1. Build the platform foundation once.
2. Launch one competition first.
3. Use the same engine to add later competitions by configuration and provider onboarding.

Recommended first live competition:

- `World Cup 2026` if the business goal is to capitalize on the June 11, 2026 tournament window.

Recommended next competitions:

- `Premier League 2026/27` after the season-long transfer, pricing, and chip engine is hardened.
- `Rwanda National Soccer League` only after provider readiness is validated for fixture events, lineups, player stats, and operational freshness.

## What The Source Guide Gets Right

The guide is strong on product intent and on several important architectural instincts:

- competition-driven configuration rather than per-competition code forks
- a scoring engine that is authoritative and server-side
- live scoring as the retention core
- private leagues as a retention multiplier
- separate flows for squad selection, transfers, captaincy, and chips
- support for season-long and tournament modes
- use of Supabase Realtime, Edge Functions, and Cloudflare as part of the delivery model

Those are the right foundations. The changes below are about fitting them to this repo and making them production-safe.

## Critical Corrections To The Source Guide

### C-001 Tenancy model mismatch

The guide treats fantasy as a standalone product domain. This repo is not built that way.

The current platform rules require:

- club-scoped tenancy for club-owned operational data
- club-aware public and admin loaders
- no unsafe unscoped reads

The guide's proposed fantasy tables do not account for the existing AFRICLUB tenancy model. In particular:

- there is no `club_id` rollout or visibility layer
- there is no distinction between global sports reference data and club-owned fan engagement data
- the delivery model assumes one generic fantasy product, not one white-label platform with club-specific promotion and enablement

Correction:

- split fantasy into `global catalog data` and `club-scoped enablement + fan data`
- global competition reference tables do not need `club_id`
- user entries, private leagues, promotion settings, and launch surfaces do need `club_id`

### C-002 Schema strategy mismatch

The guide proposes that all tables live under a new `fantasy` schema. That is clean in theory, but it does not match the current repo operating pattern.

Today:

- runtime code, admin loaders, public loaders, and Realtime subscriptions assume `public` tables
- current repository patterns do not show an established multi-schema application convention
- the active baseline migration does not currently include all of the CMS multi-tenant tables relied on by runtime code

Correction:

- for MVP, use `public.fantasy_*` prefixed tables instead of introducing a new schema
- keep schema naming boring and explicit until the fantasy domain is stable
- if a dedicated `fantasy` schema is still desired later, migrate into it after the client repositories, tests, typed access, and ops tooling support multi-schema consistently

### C-003 Launch-surface gap

The guide says fantasy should feature on the home page and have banners, but it does not specify how that works in this repo.

Current state:

- mobile home is driven by `matches`, `fan_memberships`, and `news_articles`
- web home already supports `home_banners` and `ai_content`
- the mobile home hero slide component is explicitly locked and should not be redesigned casually

Correction:

- mobile promo should be implemented as a new fantasy launch strip or quick action, not as a hero redesign
- web promo should reuse `home_banners` and a new `/fantasy` landing page
- club-level runtime flags should control whether fantasy shows at all, whether a competition is featured, and whether entry is open

### C-004 Provider assumption is too optimistic

The guide implies a single provider can be selected and then used across Premier League, World Cup, Rwanda league, and other country-local leagues without structural risk.

That is not a safe assumption.

Official provider guidance confirms the opposite:

- API-Football says league-season data availability must be checked through the `coverage` object before building downstream features.
- API-Football also notes that a `true` coverage flag still does not guarantee complete availability for every match in smaller leagues.
- Sportmonks explicitly says league-level data features change over time and should be verified dynamically rather than hardcoded.

Correction:

- add a provider readiness gate per competition
- do not let a competition move from `planned` to `playable` until it meets a minimum capability matrix
- support `marketing-only`, `read-only`, and `full-playable` states per competition

### C-005 Scoring engine is underspecified

The guide covers headline rules, but not the edge cases that decide whether users trust the product.

Missing or incomplete concerns include:

- automatic substitutions while preserving formation legality
- vice-captain fallback
- points for goals conceded and goalkeeper saves
- bonus tie resolution
- postponed fixtures and replayed fixtures
- transfer banking rules
- chip lock windows and cross-half-season chip inventories
- score corrections after late stat updates
- auditability of recalculations
- idempotent replay of scoring runs

Correction:

- build a pure scoring engine with deterministic inputs and outputs
- version scoring profiles
- store per-run snapshots and per-entry scoring breakdowns
- design for replay from raw provider snapshots, not one-way mutation only

### C-006 Admin operating model is missing

The guide proposes public-facing screens and backend tables, but it does not define the admin tools needed to run the system in production.

Missing admin capabilities:

- competition enablement per club
- launch banner and homepage feature control
- provider health and lag visibility
- manual scoring correction workflows
- player mapping remediation
- status management for planned versus active competitions
- QA preview for competition config before public release

Correction:

- ship admin operations as a first-class workstream, not as post-MVP cleanup

### C-007 Web surface needs explicit boundary

The guide reads like fantasy might be playable everywhere. That conflicts with the current architecture.

AFRICLUB explicitly states:

- authenticated fan journeys belong in Flutter
- the website is public discovery, storytelling, SEO, and handoff
- there is no browser fan portal target state

Correction:

- full gameplay stays in Flutter
- web supports discovery, rules, public leaderboards, marketing, and app handoff
- do not build authenticated web squad management in this phase

### C-008 Repository migration drift must be fixed first

Runtime code reads and writes `club_app_config`, but the current active baseline migration does not include that table even though an archived migration does.

This is a platform risk unrelated to fantasy rules, but it directly affects fantasy rollout because feature flags and launch controls rely on the same configuration path.

Correction:

- repair migration lineage before fantasy rollout begins
- make `club_app_config` part of the active, verified database state in every environment

## Corrected Product Model

AFRICLUB Fantasy should be treated as four connected layers.

### 1. Global competition catalog

Shared across all clubs:

- Premier League
- World Cup 2026
- Rwanda National Soccer League
- future local country leagues

This layer owns:

- competition identity
- game periods
- fixtures
- teams
- players
- provider mappings
- scoring profile versions

### 2. Club-scoped enablement and promotion

Per club:

- whether fantasy is visible
- which competitions are surfaced
- which competition is featured on home
- which banners and content blocks are used
- whether entry is open
- whether the competition is playable or preview-only

### 3. User gameplay state

Per user, per club, per competition:

- fantasy entry
- team name
- squad snapshots
- transfers
- chips
- scores
- leagues
- notification preferences

### 4. Live scoring and operations

Cross-cutting:

- provider ingestion
- raw snapshot storage
- scoring runs
- ranking materialization
- correction workflows
- observability

## Recommended Scope Strategy

### Scope for Launch 1

Deliver:

- mobile competition hub
- one fully playable competition
- live scoring
- public leaderboard
- private leagues in classic mode only
- web marketing/landing page
- home banners and home CTA
- admin enablement and provider health

Do not deliver in Launch 1:

- daily fantasy
- cash contests
- NFT/card mechanics
- transfer-market mechanics
- AI advisor
- season-long price-change engine for multiple leagues at once
- web-based authenticated gameplay

### Scope for Launch 2

Deliver:

- second competition template
- expanded chips
- head-to-head leagues
- richer public league pages
- notification personalization

### Scope for Launch 3

Deliver:

- provider-qualified local leagues
- country-specific localization
- expanded AI layer

## Recommended Competition Rollout Order

### Option A: World Cup first

Best if the business priority is June 2026 visibility.

Why:

- tournament mode is shorter
- pricing can remain static
- fewer periods than a full season
- can market around a fixed global event window

Additional work needed:

- bracket progression
- stage-advance bonuses
- special transfer windows

### Option B: Premier League first

Best if the business priority is long-term product quality over immediate June traffic.

Why:

- FPL is the reference mental model for users
- season-long format forces the engine to solve the hardest persistence and pricing problems early

Tradeoff:

- bigger build
- less realistic if the target is to go live before June 11, 2026

### Recommendation

Build a shared platform foundation, then launch `World Cup 2026` first if the June 2026 market window matters, and treat `Premier League 2026/27` as the first full season-long release.

## Data Model Recommendation

Use `public.fantasy_*` tables for MVP.

### Global catalog tables

- `fantasy_competitions`
- `fantasy_periods`
- `fantasy_teams`
- `fantasy_players`
- `fantasy_fixtures`
- `fantasy_player_fixture_stats`
- `fantasy_scoring_profiles`
- `fantasy_transfer_profiles`
- `fantasy_chip_profiles`
- `fantasy_provider_mappings`

### User gameplay tables

- `fantasy_entries`
- `fantasy_entry_squad_snapshots`
- `fantasy_entry_squad_players`
- `fantasy_entry_transfers`
- `fantasy_entry_chip_activations`
- `fantasy_entry_period_scores`
- `fantasy_entry_notifications`

### Social tables

- `fantasy_leagues`
- `fantasy_league_members`
- `fantasy_h2h_fixtures`
- `fantasy_h2h_results`

### Club rollout tables

- `fantasy_competition_enablements`
- `fantasy_competition_promotions`
- `fantasy_competition_waitlists`

### Operational tables

- `fantasy_ingest_runs`
- `fantasy_scoring_runs`
- `fantasy_score_events`
- `fantasy_manual_adjustments`
- `fantasy_deadline_audit`

## Data Ownership Rules

### Global tables

No `club_id` required:

- competitions
- periods
- fixtures
- teams
- players
- raw provider stats
- scoring profile versions

### Club-owned tables

Must include `club_id`:

- competition enablements
- public/private league presentation
- banners and launch copy
- user entries
- user leagues
- invite codes
- per-club competition settings

### Rationale

The same World Cup or Premier League catalog should be reusable across all clubs. The club-specific concern is not the sporting data itself. The club-specific concern is visibility, promotion, moderation, and user engagement inside a white-label app.

## Minimal Capability Matrix Per Competition

Every competition must be classified before launch.

### Tier 1: Marketing only

Required:

- competition metadata
- branding assets
- start and end dates

Allowed user experience:

- home banner
- waitlist
- rules page
- app handoff

### Tier 2: Read-only live experience

Required:

- fixtures
- teams
- standings
- basic events

Allowed user experience:

- rules
- live ticker
- public leaderboard if computed centrally

### Tier 3: Full fantasy playable

Required:

- players
- lineups
- player stats
- event freshness
- deadline certainty
- test fixtures and replay fixtures for QA

Allowed user experience:

- squad creation
- captaincy
- transfers
- scoring
- leagues

No competition should move into `full fantasy playable` without clearing Tier 3.

## Backend Architecture

### Scoring engine

Build the scoring engine as a pure TypeScript domain package first, then wrap it in Edge Functions.

Recommended shape:

- `supabase/functions/_shared/fantasy_scoring.ts`
- `supabase/functions/_shared/fantasy_rules.ts`
- `supabase/functions/_shared/fantasy_provider.ts`
- `supabase/functions/_shared/fantasy_rankings.ts`

Then expose workflows through functions:

- `fantasy-sync-catalog`
- `fantasy-ingest-live`
- `fantasy-score-period`
- `fantasy-finalize-period`
- `fantasy-recompute-ranks`
- `fantasy-send-notifications`

### Why pure scoring first

This allows:

- deterministic unit tests
- replay-based debugging
- manual correction re-runs
- isolation of provider normalization from scoring logic

### Ingestion flow

1. Pull provider fixture and player data.
2. Normalize into internal event and stat models.
3. Store raw payload snapshots for replay.
4. Upsert normalized rows.
5. Trigger a scoring run with idempotency keys.
6. Materialize entry and leaderboard read models.
7. Emit Realtime updates and notifications.

### Provider abstraction

Do not code the engine directly against one provider response format.

Create an adapter boundary:

- `FantasyProviderAdapter`
- `ApiFootballAdapter`
- `SportmonksAdapter`

The scoring engine should consume internal normalized shapes only.

## Provider Qualification Plan

### API-Football

Use for:

- fast MVP validation
- broad initial catalog discovery
- fixture and event ingestion for globally covered competitions

Hard rule:

- before enabling a competition, programmatically validate the league-season `coverage` object and record the result in the database

### Sportmonks

Use for:

- premium competitions that need stronger match facts, broader enrichment, or paid league selection guarantees

Hard rule:

- treat the account's active league and feature matrix as the source of truth, not documentation screenshots or static spreadsheets

### Local leagues

Rwanda and other localized leagues must pass a production-readiness checklist:

- league exists in provider catalog
- season exists
- players exist
- lineups arrive before kickoff
- player stats arrive during or after matches
- event lag is acceptable
- fixture status changes are reliable
- at least one full round can be replay-tested end to end

If any of those fail, the competition can still ship as:

- marketing only
- waitlist only
- rules and preview only

It should not ship as full fantasy.

## Mobile App Implementation Plan

### New feature module

Create:

- `packages/features/feat_fantasy/`

Recommended structure:

```text
packages/features/feat_fantasy/
  lib/
    feat_fantasy.dart
    src/
      fantasy_module.dart
      models/
      providers/
      repositories/
      screens/
      widgets/
```

Recommended first screens:

- `FantasyHubScreen`
- `FantasyCompetitionDetailScreen`
- `FantasyCreateEntryScreen`
- `FantasySquadBuilderScreen`
- `FantasyGameweekScreen`
- `FantasyLeaderboardScreen`
- `FantasyRulesScreen`

Deferred screens:

- `FantasyTransfersScreen`
- `FantasyLeagueDetailScreen`
- `FantasyBracketScreen`
- `FantasyChipCenterScreen`

### Router integration

Add `FantasyModule()` to [packages/core/core_app/lib/src/module_registry.dart](/Volumes/PRO-G40/AFRICLUB/packages/core/core_app/lib/src/module_registry.dart).

Keep it as a non-tab module initially.

Recommended routes:

- `/fantasy`
- `/fantasy/competition/:slug`
- `/fantasy/competition/:slug/rules`
- `/fantasy/competition/:slug/squad`
- `/fantasy/competition/:slug/live`
- `/fantasy/competition/:slug/leaderboard`

### Mobile home integration

Current home entry points:

- hero
- quick actions
- latest intel

Recommended mobile entry points:

1. Add a `FANTASY` quick action to [packages/features/feat_home/lib/src/widgets/quick_actions_grid.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_home/lib/src/widgets/quick_actions_grid.dart) behind a runtime flag.
2. Add a `FantasyLaunchStrip` section below hero and above Latest Intel in [packages/features/feat_home/lib/src/screens/home_screen.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_home/lib/src/screens/home_screen.dart).
3. Load fantasy promo data through the home repository or a dedicated fantasy teaser repository.

Important constraint:

- do not redesign [packages/features/feat_home/lib/src/widgets/match_card.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_home/lib/src/widgets/match_card.dart) without explicit product approval because that hero component is locked

### State management

Follow current package conventions:

- Riverpod providers
- repository abstraction over Supabase
- Realtime channel subscription in the live screen only

### Mobile notifications

Use the existing push infrastructure for:

- deadline alerts
- captain scored
- score finalized
- league overtaken
- entry incomplete before deadline

## Public Web Plan

The public website should support discovery and handoff, not full authenticated gameplay.

### New route

Add:

- `apps/rayon_sports/web/src/app/(site)/fantasy/page.tsx`

Contents:

- featured competitions
- rules and scoring summary
- public leaderboard preview
- launch countdown
- deep link or app install handoff

### Homepage integration

The website already reads `home_banners` in [apps/rayon_sports/web/src/lib/data/public/cms.ts](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/web/src/lib/data/public/cms.ts) and surfaces them in [apps/rayon_sports/web/src/app/(site)/_sections/hero-block.tsx](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/web/src/app/(site)/_sections/hero-block.tsx).

Recommended changes:

- add one or more fantasy banners through the existing CMS banner model
- add a dedicated fantasy section on the homepage beneath hero or fixtures
- keep the final CTA as app handoff for entry management

### Read-only public data allowed on web

- competition catalog
- rule summaries
- public top leaderboard
- fixture and score context
- bracket state for World Cup mode

### Data not allowed on public web in this phase

- authenticated squad edits
- private league management
- transfer actions
- chip activation

## Admin Web Plan

Create a dedicated fantasy admin surface under `/admin/fantasy`.

### MVP admin pages

- `Competitions`
- `Enablement`
- `Promotions`
- `Provider health`
- `Manual corrections`

### What each page should do

#### Competitions

- create and edit competition metadata
- assign provider IDs
- attach scoring profile versions
- attach transfer and chip profiles

#### Enablement

- toggle visibility per club
- set featured competition
- configure open and close windows
- set preview-only versus playable state

#### Promotions

- manage fantasy launch banners
- manage hero copy
- set CTA routing for mobile and web

#### Provider health

- last ingest time
- provider lag
- missing lineups
- missing player stats
- failed scoring runs

#### Manual corrections

- add score adjustments
- rerun ranking materialization
- log reason, operator, and timestamp

### Reuse existing patterns

Base the new admin domain on the same patterns already present for:

- [apps/rayon_sports/web/src/app/admin/cms/banners/page.tsx](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/web/src/app/admin/cms/banners/page.tsx)
- [apps/rayon_sports/web/src/app/admin/cms/content/page.tsx](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/web/src/app/admin/cms/content/page.tsx)
- [apps/rayon_sports/web/src/app/admin/cms/config/page.tsx](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/web/src/app/admin/cms/config/page.tsx)

## Runtime Config And Feature Flags

Use the existing `app_config` and `club_app_config` pattern for rollout gates.

Recommended keys:

- `feature_fantasy_enabled`
- `feature_fantasy_home_promo_enabled`
- `feature_fantasy_web_enabled`
- `fantasy_featured_competition_slug`
- `fantasy_default_competition_slug`
- `fantasy_entry_window_open`
- `fantasy_readonly_mode`
- `fantasy_provider_primary`
- `fantasy_provider_fallback`

### Immediate platform task

Before fantasy work starts, repair the migration lineage so `club_app_config` is present and validated in active environments, not only in archived migration history.

## Security And Integrity Rules

### Server-authoritative actions only

Must be enforced server-side:

- entry creation
- squad submission
- transfer execution
- chip activation
- deadline lock
- score calculation
- leaderboard ranking

### Anti-abuse

Add:

- per-user rate limits on mutating fantasy actions
- transfer audit log
- deadline audit log
- invite code entropy requirements
- immutable scoring-run snapshots
- manual adjustment audit history

### RLS

Entry owner can read and mutate:

- their own entry
- their own squad snapshots
- their own transfer history
- their own private league memberships where applicable

Public can read only:

- published competition catalog
- public leaderboards
- published rules

Public must not read:

- hidden squads before deadline
- private league membership details unless explicitly allowed

## Testing Strategy

### Backend tests

- scoring engine unit tests for every rule edge case
- provider normalization tests with saved payloads
- replay tests using full real fixture snapshots
- RLS policy verification
- deadline enforcement tests
- ranking materialization tests

### Flutter tests

- module routing tests
- widget tests for competition hub, squad builder, and live screen states
- repository tests with mocked Supabase responses
- home integration tests for fantasy CTA visibility

### Web tests

- public fantasy route renders with and without live data
- admin fantasy pages handle empty, loading, and populated states
- banner and feature-flag integration tests
- lint, typecheck, and route-level smoke coverage

### End-to-end tests

- create entry
- build squad
- lock squad
- ingest provider events
- see live score update
- finalize period
- see rank update

## Observability And Operations

Track:

- provider request success rate
- ingest lag by competition
- missing lineup rate
- missing player-stat rate
- scoring duration
- rank recompute duration
- notification send success
- Realtime subscription errors

Add dashboards or structured logs for:

- `competition_slug`
- `period_id`
- `provider`
- `run_id`
- `club_id`

## Delivery Workstreams

### Workstream 0: Platform correction

Objective:

- stabilize the underlying config and migration path before fantasy starts

Tasks:

- restore `club_app_config` into active migration lineage
- validate `home_banners`, `ai_content`, and `club_app_config` in all target environments
- define fantasy feature keys in runtime config
- add empty public `/fantasy` landing shell and placeholder mobile route

Exit criteria:

- feature flags work from database to clients
- both mobile and web can safely hide and show fantasy surfaces by config

### Workstream 1: Domain schema and provider qualification

Objective:

- create the catalog, enablement, entry, scoring, and ops tables

Tasks:

- create `public.fantasy_*` migrations
- add RLS
- build provider coverage sync tables and jobs
- implement competition readiness status transitions

Exit criteria:

- a competition can exist in `planned`, `preview`, `playable`, and `archived` states

### Workstream 2: Scoring engine and ingestion

Objective:

- build deterministic scoring and replayable ingest

Tasks:

- create pure scoring library
- build provider adapter layer
- persist raw provider snapshots
- build scoring run and ranking workflows

Exit criteria:

- one full round can be replayed and scored repeatably

### Workstream 3: Mobile gameplay MVP

Objective:

- deliver the primary gameplay experience in Flutter

Tasks:

- add `feat_fantasy`
- add competition hub and squad builder
- add live score screen and leaderboard
- add home quick action and promo strip

Exit criteria:

- a tester can create an entry, set a squad, and watch scores update

### Workstream 4: Web and admin support surfaces

Objective:

- give marketing and operators the control surfaces they need

Tasks:

- public `/fantasy` landing
- admin `/admin/fantasy`
- homepage banner integration
- provider health and correction tooling

Exit criteria:

- marketing can feature the competition without app redeploy
- admins can monitor data health and correct issues

### Workstream 5: Hardening and launch

Objective:

- make the feature safe to release

Tasks:

- performance and load tests
- push notification validation
- replay QA using stored fixtures
- launch checklist and rollback plan

Exit criteria:

- one named competition is approved for public release

## Proposed Timeline From April 10, 2026

### If targeting a pre-World Cup launch

Recommended timeline:

- April 11 to April 18: Workstream 0
- April 18 to May 2: Workstreams 1 and 2 foundation
- May 1 to May 20: Workstreams 3 and 4 MVP build
- May 20 to May 31: Workstream 5 hardening
- June 1 to June 7: soft launch and monitored rollout

This is only realistic for:

- one competition
- no AI layer
- limited league mechanics
- read-only web experience

It is not realistic for:

- World Cup plus Premier League plus Rwanda plus other local leagues all fully playable by June 11, 2026

## What To Build First

If implementation starts now, the highest-value first tasks are:

1. Repair `club_app_config` migration drift.
2. Add runtime fantasy feature flags.
3. Create the `public.fantasy_*` foundation migration.
4. Build provider readiness ingestion and persistence.
5. Ship a mobile `FantasyHubScreen` with mocked data.
6. Add mobile home CTA and web `/fantasy` landing.
7. Build the pure scoring engine before wiring live ingestion.

## Final Recommendation

Do not treat AFRICLUB Fantasy as one monolithic feature drop.

Treat it as:

- a reusable competition engine
- a club-scoped launch system
- a mobile-first gameplay module
- a public web marketing surface
- an admin-operated live data product

Build the foundation once, launch one competition well, and use provider qualification plus club-scoped enablement to expand safely into Premier League, Rwanda, and other localized leagues afterward.

## External Validation Notes

These sources informed the provider and tournament-readiness corrections:

- FIFA World Cup 2026 official schedule and dates: https://www.fifa.com/en/articles/match-schedule-fixtures-results-teams-stadiums
- API-Football coverage list and league coverage guidance: https://www.api-football.com/coverage/
- Sportmonks league feature availability guidance: https://docs.sportmonks.com/v3/tutorials-and-guides/tutorials/data-features-per-league
