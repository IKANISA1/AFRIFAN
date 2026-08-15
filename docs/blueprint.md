# AFRICLUB Architecture Blueprint

Updated: 2026-08-15

Status: superseded for product-surface boundaries by
[`architecture/AFRICLUB_LETS_PLAY_SPLIT_2026-08-15.md`](architecture/AFRICLUB_LETS_PLAY_SPLIT_2026-08-15.md).
The historical TV/trivia architecture below is retained only as an audit
record and is not part of the active AFRICLUB build.

Design authority: this document is architecture-only. `../DESIGN.md` is the
sole source for product visuals, interface rules, tokens, screen archetypes, and
state requirements.

## 1. Target State

AFRICLUB is a white-label club platform with five governed surfaces:

1. Flutter native mobile app for authenticated supporters.
2. Flutter native TV app for owner-paired, screen-safe public game projections
   and approved venue runtime experiences.
3. Venue app/portal for venue-scoped operators.
4. Centralized admin PWA for club operators.
5. White-label public website for clubs.

Rayon Sports is the reference club profile used to seed defaults, configuration data, and example content. The platform does not support a browser fan portal.

The platform is football-club-first. The product hierarchy is club and
football, membership and club participation, governed fan engagement, then
secondary venue/matchday utility. The operating sequence is controlled in
[`FOOTBALL_CLUB_FIRST_IMPLEMENTATION_PLAN_2026-07-30.md`](FOOTBALL_CLUB_FIRST_IMPLEMENTATION_PLAN_2026-07-30.md).

### Current implementation checkpoint — 1 August 2026

- The target four-branch Flutter shell and canonical Club route family are
  implemented and contract-tested. Settings is profile-owned.
- Shared network scope rejects missing or invalid `club_id`; `partner_id`
  remains compatibility metadata and cannot authorize or broaden a query.
- The repository uses Melos 8 from the root `pubspec.yaml`, with deterministic
  one-package/one-Flutter-process test execution.
- The same club-scoped database and projection model serves Flutter mobile,
  native TV, public web, Admin PWA, and venue portal. Local pgTAP and Edge tests
  pass; no production mutation is claimed.
- Authorized Admin Live Control uses the richer server projection for
  identity-free participant and TV previews, authoritative refresh/event
  health, and server-time latency buckets. Assigned organizers retain a
  narrower projection, and reconnect requires refresh before mutation.
- The audited authoritative game core now has database-bounded display
  capabilities, an explicit many-display assignment relation, typed safe
  participant/organizer/admin/TV projections with monotonic versions and
  freshness, and reasoned idempotent skip/early-end controls. This locally
  closes GAME-BE-01..06 after the full migration chain and 80-check pgTAP suite
  pass in an isolated database, including display-role RLS and authorized,
  privacy-safe event refresh hints. A deterministic six-state fixture now
  proves participant mobile, organizer mobile, native TV, and Admin render the
  same authoritative phase/version sequence with surface-appropriate data.
  An eleven-scenario deterministic resilience matrix additionally controls
  interruption, late join, app resume, TV restart, duplicate tap,
  stale/out-of-order reconciliation, clock skew, role/device revocation,
  partial failure, and recovery through 86 passing Flutter tests. Shared/live
  deployment, actual network timing, synchronized devices, physical
  accessibility, and exact-candidate release execution remain gated.
- The current ledger has 176 routes and 2,816 governed route-state cells:
  1,881 cells are admitted, 256 remain open, and 679 are not applicable. The
  final nine Admin PWA and seven Venue portal matrices require corrected
  exact-current browser execution and review.
  The eleven-route Club family is locally closed at 153/153 applicable cells;
  live content authority, physical-device accessibility, named approval and
  release remain separate. The static `/game-operations` hub is also locally
  complete at 6/6 applicable cells with ten explicit non-applicability
  decisions. `/my-tvs` is locally complete at 14/14 applicable cells with two
  explicit non-applicability decisions, and `/my-tvs/pair` is complete at
  16/16 applicable cells with fail-closed field and authority gating.
  `/my-tvs/:displayId` is complete at 16/16 with permission clearing,
  valid-change gating, and mutation uncertainty lockout. The organizer
  inventory is complete at 14/14 applicable cells, the planner at 16/16, and
  live control at 14/14 applicable cells with empty and selected explicitly
  N/A. All seven local owner/organizer projections are evidence-complete.
  Participant discovery closes 15/15 applicable cells with selected explicitly
  N/A, and participant live play closes all 16 cells. The corrected
  exact-current matrices for the final nine Admin PWA and seven Venue portal
  routes pass and are admitted, closing the local route-state ledger;
  authorized shared/live-role evidence remains separate.
- Organizer planning and live control now preserve last-confirmed context only
  for recovery, lock actions during any unconfirmed refresh, clear protected
  data on permission loss, and reuse idempotent intent only for definite
  retryable mutations. The organizer planner now closes all sixteen applicable
  cells with complete-plan gating, selected-invitee proof, organizer-specific
  offline recovery, exact interaction/theme evidence, and readable
  200-percent action copy. Live control adds exact focus, held press,
  200-percent text, reduced-motion, theme, retained-sync, conflict, and timeout
  proof; normal transitions use imperative copy and all primary/exception
  actions lock when authority or mutation outcome is uncertain. The 172-test
  Game Operations regression and strict analysis pass.
  Component closure is complete for all 316 applicable cells across 71
  components. Local route-state closure remains incomplete; `design_complete`
  remains false because browser admission, live, physical-device, accountable approval, clean-candidate,
  signing, store, deployment, and release gates are separate.
- The shared localization architecture now carries 3,183 exact-parity
  EN/FR/RW messages. Its fail-closed inventory scans 292 production Dart files
  with 63 controlled dispositions and zero pending static candidates; dynamic
  content and accountable linguistic approval remain separate gates.
- Local fan-app iOS/Android and native-TV debug artifacts build. Production TV
  signing, physical-device UAT, authenticated role UAT, CI/distribution, store
  evidence, and named approvals remain outside local source authority.

## 2. Architectural Decisions

### ADR-001: Shared Backend, Club-Scoped Tenancy

- One Supabase project serves all clubs.
- Every club-owned table is scoped by `club_id`.
- `club_slug` is used for routing, hostname mapping, and identity lookup.
- `partner_id` remains legacy-only and must not be used for unscoped fallback queries.

### ADR-002: Native Fan Journeys

- Authenticated supporter flows live in Flutter only.
- Web may present public discovery, marketing, search, and supporter handoff.
- Ticket purchase, membership management, contributions, and authenticated fan workflows continue in the native app.

### ADR-003: Centralized Admin Workspace

- Admin lives in a single web workspace.
- Access is role-based and club-scoped.
- Admin CRUD must always include the active `club_id`.

### ADR-004: White-Label Website

- Public website resolves the active club from host mapping or slug.
- Branding, copy, and data loaders must derive from the active club context.
- Rayon-specific defaults are acceptable only as the seeded reference profile when club data is absent.

### ADR-005: Venue And TV Product Surfaces

- Native TV is a Flutter app target under `apps/rayon_sports_tv`.
- Web `/tv-display` is a browser compatibility/admin pairing surface, not the TV app of record.
- Venue app starts under `apps/rayon_sports/web/src/app/venue` to reuse auth, Supabase, CI, and PWA infrastructure.
- Venue records require `club_id`; venue-owned records also require `venue_id`.
- Venue check-in is rotating QR/code first. Foreground location is optional verification only.
- Drinks ordering is a drinks-only top-10 MVP, not full POS or delivery.
- TV surfaces are read-only and must not expose personal, order, or wallet data.

### ADR-006: Football-Club-First Consumer Architecture

- Primary Flutter navigation is Home, Club, Fan Zone, and Membership.
- Settings, privacy, support, and account controls live behind profile.
- Club owns team, news, fixtures, results, standings, history, projects,
  tickets, and shop discovery.
- Fan Zone owns selected-match predictions, competitions, football trivia,
  approved music trivia, TV games, rewards context, and supporter engagement.
- Venue entry points are contextual matchday experiences, not a primary
  product branch.
- Existing deep links may be aliased during migration, but every object has one
  canonical route and analytics identity.

### ADR-007: One Shared Domain Truth, Surface-Specific Projections

- Mobile, native TV, public web, admin, and venue portal share authoritative
  club-scoped domain records.
- One game session may target several explicitly assigned displays. Home
  displays are owner/invitation scoped; venue managers operate assigned
  displays and require an explicit organizer grant for game control;
  participants use their authenticated AFRICLUB account through a session-safe
  public alias.
- Surfaces receive role-appropriate projections; they do not duplicate or
  independently score/publish the same object.
- Realtime channels are club-scoped and resource-scoped.
- Native TV uses a dedicated anonymous Auth identity bound to one active,
  revocable device credential. Event RLS permits only explicitly assigned
  club/session pairs, and Realtime remains an invalidation hint followed by an
  authoritative projection refresh; bounded polling is recovery-only.
- The local game QA contract must fail closed unless projection safety,
  role/action matrices, grants/RLS, lifecycle preconditions, idempotency,
  ordering/version rejection, deadlines, append-only audit, and pre-reveal
  answer protection all remain executable. Cross-client and device proof is a
  separate gate.
- AI may draft trivia content, but inserts remain `pending_review` and human
  review/publish owns consumer truth. Approval requires retained citation,
  schema/model provenance and deterministic duplicate, ambiguity, answer,
  supported-language and entertainment-policy checks.
- Live games synchronize structured prediction/trivia state. No live or
  prerecorded video programme, ingest/transcoding/CDN path, or streaming
  telemetry/rights pipeline is part of the approved product contract.
- Feature flags control availability only; RLS and role checks control access.

## 3. Product Surface Ownership

### Flutter Fan App

Purpose:
- Official club identity and football, membership, ticketing, supporter
  communities, commerce, and authenticated fan engagement. Venue check-in and
  ordering are secondary matchday extensions.

Code shape:
- `apps/<club>/` contains the native shell and configuration data.
- `packages/core/` contains shared shell, auth, routing, theme, and network.
- `packages/features/` contains shared features.
- `packages/clubs/` contains per-club config.

Rules:
- No broad admin or venue-staff console lives in the supporter app. Narrow
  `My TVs` owner and `Games I manage` organizer journeys are allowed only
  behind explicit role projections and club scope.
- The primary shell is Home, Club, Fan Zone, and Membership.
- Club routes are official club/football truth, not generic engagement cards.
- Prediction games are free-to-enter, selected-match-only, and contain no odds,
  stakes, or payout language.
- Venue check-in and drinks-ordering routes stay under contextual matchday
  experiences and behind launch flags.
- Foreground location is requested only after supporter action.

### Flutter Native TV App

Purpose:
- Screen-safe venue QR/code display, club-scoped game runtime, and shared
  matchday state.

Code shape:
- `apps/rayon_sports_tv`
- `apps/rayon_sports/web/src/app/tv-display` remains browser compatibility only.
- `africlub_game` schema for game runtime.
- `venue_checkin_codes` for hashed rotating venue code contracts.

Rules:
- Read-only.
- No personal data, wallet balance, check-in identity, or live order queue.
- Supports 720p and 1080p UAT screenshots.

### Venue App / Portal

Purpose:
- Venue-scoped operator dashboard for assigned venues, check-ins, drinks-only order queue, top-10 menu, promotions, TV code, and staff role visibility.

Code shape:
- `apps/rayon_sports/web/src/app/venue`
- `public.venues`, `venue_staff_memberships`, `venue_checkins`, `venue_drink_orders`, and related event tables.

Rules:
- Venue staff access only assigned `venue_id`.
- Day-to-day menu and order handling lives here, while club-wide oversight stays in Admin PWA.
- No service-role keys or private partner/feed data in browser clients.

### Public Website

Purpose:
- Discovery, storytelling, fixtures, standings, public ticket context, approved venue discovery, supporter acquisition, and supporter-app handoff.

Code shape:
- `apps/rayon_sports/web/src/app/(site)`
- `apps/rayon_sports/web/src/lib/data/public/*`

Rules:
- No authenticated fan portal routes.
- No anonymous browser fan session bootstrapping.
- No authenticated check-in or live order queues.
- Public loaders must resolve club context first, then query by `club_id`.

### Admin PWA

Purpose:
- Publishing, operations, match control, standings, shop/catalog, membership, supporter groups, notifications, venue oversight, FET review/export, and configuration.

Code shape:
- `apps/rayon_sports/web/src/app/admin`
- `apps/rayon_sports/web/src/lib/data/admin/*`

Rules:
- Desktop/tablet-first shell.
- All writes require same-origin mutation checks and role-scoped access.
- All admin queries and mutations must be club-scoped.
- Venue mutations must write audit/event rows.

## 4. Tenant Model

### Canonical Identity

- `club_id`: primary tenant identifier in data storage.
- `club_slug`: public routing and hostname identifier.
- `club_app_config`: per-club config overrides.
- `app_config`: global defaults only.

### Safe Query Rules

- Never fall back from scoped queries to unscoped reads.
- Never resolve club scope by “first row found”.
- Never re-query records by bare `id` without `club_id` when club ownership matters.

### Club Resolution

Web resolves the active club through:

1. Explicit host override map.
2. Default club slug fallback.
3. First subdomain label normalization.

Once resolved, loaders query Supabase by `club_slug` or `club_id` and then merge:

1. Global defaults from `app_config`.
2. Club overrides from `club_app_config`.

## 5. Repo Structure

```text
apps/
  rayon_sports/
    web/
      src/app/(site)/       public website
      src/app/admin/        centralized admin PWA
      src/app/tv-display/   browser compatibility display
      src/app/venue/        venue app/portal
  rayon_sports_tv/          Flutter native TV app
  <club_flutter_apps>/

packages/
  core/
    core_app/
    core_auth/
    core_network/
    core_router/
    core_theme/
    core_utils/
  features/
    feat_home/
    feat_ticketing/
    feat_membership/
    feat_shop/
    feat_contributions/
    feat_fan_clubs/
    feat_settings/
    ...
  clubs/
    club_rayon_sports/
    club_<other clubs>/

supabase/
  migrations/
```

## 6. Mobile App Composition

Each club app is intentionally thin:

- native bundle identifiers
- compile-time config
- bootstrap entrypoint
- generated runtime brand mark and tokenized splash surfaces governed by `../DESIGN.md`

Shared business logic, routes, and modules live in packages. Feature flags determine which modules and routes are active for a club.

Target composition:

```text
App shell
  Home
    club pulse + next fixture/current result + latest news + next action
  Club
    overview + team + news + fixtures + results + standings + history
    projects + tickets + shop
  Fan Zone
    selected-match predictions + competitions + reviewed trivia
    TV games + points/rewards + supporters
  Membership
    card + plans + fan registry + fan clubs + payments
    contributions/statements + projects
  Profile
    settings + privacy + notifications + language + theme + support
```

`packages/features/feat_club` becomes the complete Club module and composes
typed football read models. Home consumes bounded domain projections and must
not duplicate repository or scoring logic.

## 7. Web Composition

### Public Site

- Server components fetch public data through club-aware loaders.
- Metadata is generated per club context.
- Public navigation points fans toward the native app where needed.

### Admin PWA

- Client shell hydrates authenticated admin state.
- Domain modules handle scoped CRUD.
- Game operations are separated into Content Studio, Session Planner, and Live
  Control. Authorized named selectors replace routine raw-ID entry, and
  guarded actions carry version, deadline, ordering, and idempotency internally.
- Content Studio projects answer-safe source, generation, human-review, and QA
  provenance, and publication verifies source completeness plus the exact
  reviewed mobile/TV preview fingerprint.
- PWA support is retained for admin operational workflows and public-site installability.

## 8. Data and Migrations

Recent tenancy hardening includes:

- removal of unsafe unscoped mobile repository fallbacks
- removal of web fan portal routes
- introduction of `club_app_config`
- club-scoped CMS/config access in public and admin loaders
- white-label host/slug resolution in the public website
- venue check-in, venue staff, drinks ordering, FET reservation, and order event foundations

The shared-data migration must also:

- normalize remaining partner-first feature APIs to `club_id`;
- establish one canonical record for each club, fixture, result, standing,
  project, ticket, game session, question, score, and reward event;
- use `{club_id}:{feature}:{resource_id}` Realtime channel names;
- keep prediction eligibility and AI-trivia review/publish server-authoritative.

Migration policy:

- schema changes land in `supabase/migrations/`
- multi-tenant tables must include `club_id` where appropriate
- club-specific configuration belongs in `club_app_config`

## 9. Validation Gates

Required checks:

- Flutter static analysis on touched packages
- Flutter package tests for touched domains
- `npm run lint`
- `npm run typecheck`
- `npm run test`
- Supabase SQL contract tests for touched schema/RPCs
- UAT evidence matrix in `docs/release/rayon_fullstack_uat_matrix.md`
- Security scan for service-role, LiveScore credential, and private feed exposure

The Live Games V2 native-TV accessibility contract currently passes ten of
thirteen governed clauses: 55 tests cover multi-resolution widget layout, simulated
overscan, three-locale long copy, exact 200-percent text, both themes,
D-pad/focus, reduced motion, privacy-safe semantics, and private-field
rejection. The current Android TV API 36 APK also has inspected native
1920 x 1080 and 3840 x 2160 emulator captures of the real isolated-backend
pairing journey. GAME-QA-05 remains open for physical-TV overscan/remote/
screen-reader execution, four-hour burn-in soak, accountable privacy approval,
shared/live execution, and release.

The GAME-QA-06 exact-candidate contract now records a passing exact-current
dirty local build subset across unsigned iOS release, ephemeral-signed Android
AAB, ephemeral-signed native-TV release APK, and the web typecheck/lint/111-
file/933-test/production-build gate. The development-signed current iOS app
also installs and launches on the exact paired iPhone 12 Pro. The criterion
remains open for a sealed clean candidate, pinned CI, complete physical UAT/
AT, production signing/stores, authorized target migration/rollback, named
approvals, and release.

The GAME-QA-03 synchronized-session contract now records a completed exact
device preflight but remains open. No physical phone or native-TV target was
available; one paired iPhone 12 Pro was unavailable, while two iOS simulators
and the Android TV emulator cannot replace the required two independent
physical phones and physical TV. The authorized shared backend, correlated
exact-build logs/video, measured network loss/recovery, physical accessibility,
named approvals, and release stay fail-closed.

The participant GAME-MOB-05 layout contract is locally complete. Its eleven
ordered clauses bind 37 localization, route, and screen tests plus four exact
current-source goldens for standalone safe-area routing, compact/keyboard
reachability, EN/FR/RW exact-200-percent reflow, theme, reduced motion, denial,
offline retention, reconnect/last-update, and timeout recovery. This does not
claim shared/live, physical-device/AT, network-timing, accountable approval, or
release evidence.

GAME-MOB-04 is also complete for deterministic local recovery scope. Its
seven-clause matrix binds 67 tests and the governed offline golden across
network change, missed events, foreground resume, uncertain session-version
recovery, retained safe state, localized last-update, and sanitized recovery.
Shared/live, physical-device, real-network timing/loss, approval, and release
remain fail-closed.

GAME-MOB-03 is complete for deterministic local authoritative synchronization
scope. Its seven-clause matrix binds 68 focused tests and the existing
80-check isolated database contract to validated club/session identity, exact
topic-filtered privacy-safe invalidation, versioned projection refresh,
monotonic scope/version/sequence adoption, server-time deadline calculation,
prohibited client scoring or lifecycle advancement, and subscription-close
recovery/cleanup. Shared/live delivery, physical-device behavior, real-network
ordering/timing, approval, and release remain fail-closed.

GAME-MOB-01 is complete for deterministic local and isolated-database
code-free discovery scope. Its seven-clause matrix binds 69 Flutter tests and
77/77 full-chain pgTAP checks to five governed sources, live/scheduled
separation, targeted deep-link reauthorization, validated cold/warm live-game
notification routes, and fail-closed code/private/stale/ineligible data. The
shared/live discovery, physical-device platform delivery, approval, and
release remain fail-closed.

GAME-MOB-02 is complete for controlled local participant-code retirement
scope. Its seven-clause matrix binds 98 Flutter tests and 42 Admin web tests to
the `Live games` Fan Zone identity, eleven removed legacy source/test files,
session-ID-only Flutter/Edge/Admin joins, retired EN/FR/RW participant-code
copy, preserved owner `My TVs` one-time challenge pairing, and four reviewed
Fan Zone golden changes. Shared/live execution, physical-device entry,
real-network timing, approval, and release remain fail-closed.

GAME-ORG-01 is complete for controlled local organizer planning and control
scope. Its eight-clause matrix binds 36 Flutter tests, 8 localization tests,
80/80 full-chain isolated pgTAP checks, and one inspected deterministic
390 x 844 golden to role gating, published complete 20-question packs,
bounded schedule, governed eligibility and privacy-safe Fan-ID invitations,
authorized paired displays, activation/start, authoritative supervision, and
versioned completion. Shared/live role/RLS/RPC/audit, real-network timing,
physical-device/AT, accountable approval, signing, stores, deployment, and
release remain fail-closed.

GAME-ORG-02 is complete for controlled local guarded organizer operations.
Its seven-clause matrix binds 45 Flutter tests, 8 localization tests, the
unchanged 80/80 isolated pgTAP evidence, and one corrected and inspected
390 x 844 golden to one normal next action, separately confirmed exceptions,
dedicated reasoned skip/early-end RPCs, authoritative pause/resume, stable
retry identity, and conflict/timeout refresh lockout. Shared/live
role/RLS/RPC/audit, real-network timing, physical-device/AT, accountable
approval, signing, stores, deployment, and release remain fail-closed.

GAME-OWN-01 is complete for controlled local owner-inventory scope. Its seven-
clause matrix binds 49 Flutter tests, 8 localization tests, a fresh 80/80
full-chain isolated pgTAP run, and one inspected 390 x 844 golden to role- and
club-scoped displays, complete safe operational metadata, assigned-session
context, explicit empty/denied/offline states, retained-authority recovery, and
credential/pairing-material exclusion. Shared/live role/RLS/RPC/audit, real
displays and network timing, physical-device/AT, accountable approval, signing,
stores, deployment, and release remain fail-closed.

GAME-OWN-02 is complete for controlled local owner pairing and management
scope. Its seven-clause matrix binds 57 Flutter tests, 8 localization tests, a
fresh 80/80 full-chain isolated pgTAP run, and one inspected 390 x 844 golden
to manual/deep-link native-TV bootstrap entry, named authorized location
selection, confirmed audited rename/move/revoke, credential-rotating recovery,
stable retry lockout, and privacy-safe retirement of obsolete owner-issued
pairing interfaces. Shared/live role/RLS/RPC/audit, real displays and network
timing, physical-device/AT, accountable approval, signing, stores, deployment,
and release remain fail-closed.

GAME-TV-03 is complete for controlled local native-TV pairing-only scope. Its
seven-clause matrix binds 56 native-TV Flutter tests, a fresh 80/80 full-chain
isolated pgTAP run, zero-issue analysis, and one side-by-side reviewed
1280 x 720 pairing golden to hashed short-lived challenge creation, the exact
My TVs owner QR deep link, pending authenticated claim, one-time secure
credential exchange, pairing-material removal after binding, revocation, and
fresh-bootstrap recovery. Shared/live, physical-TV/remote/AT, real-network
timing, accountable approval, production signing, stores, deployment, and
release remain fail-closed.

GAME-TV-01 is complete for controlled local native-TV full-projection scope.
Its nine-clause matrix binds 58 native-TV Flutter tests, the fresh unchanged-
backend 80/80 full-chain isolated pgTAP run, zero-issue analysis, and five
exact current-source 1280 x 720 goldens to paired-empty, scheduled, lobby,
question/choices/countdown, reveal/public result, contiguous privacy-safe
standings, completion, pause/cancellation, retained-offline, reconnect, and
strict lifecycle payload validation. Shared/live cross-client execution,
physical-TV/remote/AT, 1080p/4K and soak,
accountable approval, production signing, stores, deployment, and release
remain fail-closed.

GAME-TV-02 is complete for controlled local isolated-Realtime-network scope.
Its seven-clause matrix binds the 58 native-TV tests, a fresh 80/80 full-chain
isolated pgTAP run, and executable Realtime v2.120.3 evidence to Auth-issued
device identity, exact assigned-session scope, five ordered privacy-safe
events, zero unbound delivery through per-event RLS, authoritative refresh,
revocation cutoff, channel recovery, and recovery-only polling. Shared/live
WAN loss/soak, cross-client execution, physical-TV/AT, accountable approval,
production signing, stores, deployment, and release remain fail-closed.

## 10. Non-Goals

The following are intentionally out of scope for the current architecture:

- browser-based fan portal
- public web check-in or live order queues
- cross-club unscoped admin browsing without explicit club context
- duplicate per-club web codebases
- full POS, delivery, open-loop FET spend, or cash-out
- betting, odds, staking, cash-payout, or fantasy-squad mechanics
- unreviewed AI-generated trivia or unapproved music-rights content
- an inferred live/prerecorded video programme or streaming pipeline without a
  separate product, rights, moderation, accessibility, bandwidth, telemetry,
  and fallback approval
- venue-first primary navigation

## 11. Reference Implementation

Rayon Sports remains the seeded reference for:

- default club profile values
- default web environment settings
- example configuration and release evidence
- initial rollout validation

Reference defaults must not become hardcoded assumptions in shared runtime logic.
