# AFRICLUB Football-Club-First Implementation Plan

Updated: 2026-07-30

Status: active implementation contract; not a completion or release claim.

Design authority: [`../DESIGN.md`](../DESIGN.md). This plan controls product
priority, information architecture, domain ownership, sequencing, and evidence
gates. It does not redefine visual tokens or component rules.

Evidence baseline:
[`../output/ui_ux_architecture_audit_20260730/AFRICLUB_CURRENT_UI_UX_ARCHITECTURE_JOURNEY_AUDIT_2026-07-30.md`](../output/ui_ux_architecture_audit_20260730/AFRICLUB_CURRENT_UI_UX_ARCHITECTURE_JOURNEY_AUDIT_2026-07-30.md).

## 1. Product Doctrine

AFRICLUB is a football club platform first. Its product hierarchy is:

1. Club identity, team, football calendar, results, standings, and news.
2. Membership, fan clubs, contributions, projects, tickets, and shop.
3. Fan engagement through selected-match predictions, competitions, and
   reviewed trivia.
4. Secondary matchday utilities such as venues, drinks ordering, promotions,
   and venue-hosted game events.

Every supported club app uses the same platform, shared domain contracts, and
club-scoped database. Branding, configuration, publishing, feature flags, and
content vary by club. A club app must not become a venue app, generic rewards
wallet, or entertainment catalogue with a club badge attached.

## 2. Current-State Finding

The current architecture has strong shared packages, tenant controls, broad
route/state evidence, public football routes, membership foundations, venue
operations, and game infrastructure. The consumer mobile hierarchy does not
yet express the governing product identity:

- primary mobile navigation is Home, Fan Zone, and Settings;
- football information is fragmented or absent as a first-class mobile branch;
- `feat_club` has data/repository foundations but no complete Club module;
- projects and contributions are not presented as a coherent club journey;
- venue utilities are more prominent than their secondary product role;
- the game runtime exists, but the approved prediction/trivia taxonomy and
  cross-surface journey are not yet complete;
- search does not yet provide complete club, team, news, football, project, and
  venue discovery;
- 256 applicable route-state cells remain open and `design_complete=false`.

Existing locally green checks remain valid for their exact scope. They do not
close this product-identity plan.

## 3. Target Consumer Information Architecture

### 3.1 Primary navigation

| Destination | First-viewport job | Owned domains |
| --- | --- | --- |
| Home | Show the club pulse and next relevant action | next fixture/live result, latest club news, membership state, ticket prompt, selected engagement |
| Club | Provide the complete official club record | overview, team/squad, news, fixtures, results, standings, history, projects, tickets, shop |
| Fan Zone | Let supporters participate safely | free predictions, main competitions, selected-match picks, football trivia, approved music trivia, TV games, points/rewards, supporters |
| Membership | Make belonging and contribution tangible | digital card, plans, fan registry, fan clubs, payments, contributions/statements, projects |

Settings, privacy, notifications, support, language, theme, and account controls
move behind the profile/avatar entry. Search remains a global command available
from Home and Club.

### 3.2 Club route family

The target Flutter route family is:

- `/club`
- `/club/team`
- `/club/news` and `/club/news/:articleId`
- `/club/fixtures` and `/club/fixtures/:matchId`
- `/club/results`
- `/club/standings`
- `/club/history`
- `/club/projects` and `/club/projects/:projectId`
- `/tickets` and `/tickets/:matchId`
- `/shop` and `/shop/:productId`

Aliases may preserve existing deep links during migration, but the router,
analytics taxonomy, search catalogue, notification links, and tests must
resolve to one canonical destination per object.

### 3.3 Fan Zone game taxonomy

Only two consumer game families are approved:

1. Prediction games: free-to-enter predictions limited to selected football
   matches from approved main leagues, the local league, and approved club
   competitions. Availability is configured and published; the client must not
   imply that every match is playable.
2. Trivia and entertainment games: AI-assisted football trivia and, only when
   rights, safety, and content policy approve it, music trivia. AI may draft
   questions, but a governed review/publish workflow owns correctness,
   difficulty, duplication, rights, language, and answer integrity.

No odds, staking, cash payout, betting copy, fantasy-squad implication, or
unreviewed AI question reaches a consumer surface. Game scoring, session state,
eligibility, and rewards have one authoritative backend contract shared by
mobile, TV, venue, admin, and web projections.

### 3.4 Matchday experiences

Venues appear under a secondary “Matchday experiences” or “Places to watch”
entry, reachable from Fan Zone, a relevant fixture, Home, or global search.
They may support:

- approved venue discovery and availability;
- explicit supporter check-in;
- a bounded top-10 drinks menu with ordering/pickup;
- venue-hosted game events and approved promotions;
- screen-safe TV pairing and game display.

Venue operations remain in the venue portal. Public web remains discovery-only.
The supporter app never exposes venue-staff or broad admin controls.

## 4. Target Architecture

### 4.1 Domain ownership

| Domain | Authoritative package/service | Consumer projection | Operator projection |
| --- | --- | --- | --- |
| Club identity and football | `feat_club` plus football repositories | Home and Club | Admin CMS, match, squad, standings |
| Membership and community | membership, fan-club, supporter, contribution packages | Membership | Admin membership/community/contributions |
| Commerce | ticketing and shop packages | Club, Home, Search | Admin ticket/shop |
| Games | one game-session, question, scoring, eligibility, and reward domain | Fan Zone and native TV | Admin game console and bounded organizer controls |
| Venues | venue/check-in/order domain | Matchday experiences | Venue portal and club oversight |
| Rewards | FET ledger domain | receipts and balance context | governed finance/admin review |

### 4.2 Shared-data rules

- `club_id` is mandatory for every club-owned record and query.
- `club_slug` is for routing, host resolution, and brand lookup.
- `venue_id`, competition, match, game, membership, project, ticket, order, and
  ledger identifiers add scope; they never replace `club_id`.
- Each object has one source of truth. Mobile, web, TV, venue, and admin use
  scoped projections, not copied datasets.
- Realtime channels use a club-scoped namespace such as
  `{club_id}:{feature}:{resource_id}` and reconcile ordered snapshots/events.
- Feature flags control availability, not authorization.
- No shared package contains Rayon-only logic outside reference configuration.

### 4.3 Flutter composition

Implement a complete `ClubModule` in `feat_club` with:

- typed club overview and football view models;
- repository interfaces and club-scoped implementations;
- Club hub, team, news, fixtures, results, standings, history, and project
  screen contracts;
- loading, data, empty, error, offline, refreshing, permission, and deep-link
  recovery states;
- route registration, search projection, analytics semantics, localization,
  accessibility, and golden/state evidence.

Home composes bounded read models from club, fixture, membership, ticket, and
engagement domains. It does not reimplement their repositories or business
rules.

## 5. User Journeys

### Journey A — follow the club

Open app → see next fixture/current result → enter Club → inspect team, news,
fixtures, results, or standings → follow a deep link back to the same object.

### Journey B — become and remain a member

Home or Membership → compare plan → review terms and amount → pay or recover
from failure → receive membership state and digital card → view contribution
history and relevant club projects.

### Journey C — attend or watch a match

Fixture → ticket availability or venue discovery → buy/access ticket or choose
approved venue → check in only after explicit action → optionally order a
bounded drink → receive status and recovery actions.

### Journey D — play a selected football game

Fan Zone → view eligible selected matches/competitions → open prediction or
trivia → review rules → submit → receive authoritative result/reward state →
inspect history. A TV code may join a venue session but is not the only
discovery mechanism.

### Journey E — publish and operate

Authorized admin → select active club → publish football/content/game data →
preview the correct consumer projection → audit the mutation. Venue staff see
only assigned venues; narrow organizer/TV-owner capabilities require explicit
role and product decisions.

## 6. Implementation Workstreams

### Phase 0 — contract and baseline

- Record this plan in README, DESIGN, architecture, UAT, game, venue, and
  governed goal documents.
- Preserve the existing 87-task denominator; map this plan as nested acceptance
  criteria until the controlled register explicitly changes it.
- Confirm route aliases, feature ownership, game content policy, named owners,
  and due dates.
- Capture a clean-build log. The checked-in iOS floor is 15.5, but package
  reproducibility remains open after missing cached Swift-package artifacts.

Exit gate: documents agree on product hierarchy, route ownership, game types,
venue priority, evidence boundary, and open decisions.

### Phase 1 — Club foundation

- Complete `ClubModule`, canonical routes, and club-scoped repositories.
- Add official club hub and football screen states.
- Integrate club destinations into search, notifications, deep links,
  localization, and analytics.
- Provide admin publishing preview for the same records.

Exit gate: club/team/news/fixtures/results/standings/history are reachable,
scoped, localized, accessible, tested, and evidenced on current Flutter builds.

### Phase 2 — shell and Home hierarchy

- Migrate primary navigation to Home, Club, Fan Zone, Membership.
- Move Settings behind profile without breaking existing deep links.
- Recompose Home around next fixture/live result, latest news, membership, and
  one contextually selected action.
- Remove venue-first or generic-engagement-first visual dominance.

Exit gate: compact and large-screen navigation, branch restoration, deep links,
200% text, screen-reader semantics, offline recovery, light/dark, and reduced
motion pass.

### Phase 3 — membership, projects, tickets, and commerce

- Unify membership card, plans, fan clubs, contribution history, statements,
  and projects.
- Give projects first-class club and membership routes instead of redirecting
  to generic supporters.
- Connect fixtures to relevant tickets and products without fabricating stock,
  price, availability, or payment success.

Exit gate: payment, idempotency, recovery, receipt, privacy, and operator audit
contracts pass with approved copy.

### Phase 4 — games and engagement

- Publish only selected eligible matches for free predictions and competitions.
- Complete one cross-client game runtime with ordered Realtime reconciliation.
- Add football trivia and keep music trivia feature-gated until content/rights
  approval.
- Make AI question generation draft-only with human review and audit.
- Separate points/rewards receipts from betting or monetary claims.

Exit gate: mobile, native TV, admin, and applicable venue flows use the same
session, scoring, eligibility, and reward truth; all mapped `GAME-*` criteria
close.

### Phase 5 — secondary venue experiences

- Reposition venue entry points under matchday context.
- Retain strict assigned-venue operations, explicit check-in, bounded menu,
  order-event history, and screen-safe TV data.
- Prove public discovery, supporter action, venue operation, and admin
  oversight as separate permission surfaces.

Exit gate: location, alcohol/age, privacy, reward, staff-acceptance, and
operations approvals close; no public or consumer operator leak exists.

### Phase 6 — release evidence

- Regenerate route inventory and route-state closure after route changes.
- Run touched-package analysis/tests, web checks, SQL contracts, source guards,
  accessibility matrices, performance/resilience, and privacy scans.
- Capture exact-current simulator/emulator evidence, then named physical-device
  UAT.
- Complete signing, CI, backend migration/rollback, store, observability,
  incident, and accountable human approvals separately.

Exit gate: `design_complete=true`, all applicable route-state cells evidenced,
all governed tasks verified complete, and release approvals recorded. Local
green checks alone cannot satisfy this gate.

## 7. Decision Register

The following remain explicit decisions; implementation must not invent them:

- named product/engineering/design/content/linguistic/release owners and dates;
- eligible leagues, competitions, and match-selection authority;
- music-trivia rights and moderation policy;
- home-TV audience, multi-display assignment, organizer authority, and
  participant identity;
- final project-contribution financial/legal copy;
- FET redemption/spend policy;
- location retention and alcohol/age procedure;
- canonical admin surface and any bounded mobile organizer capability.

## 8. Definition of Done

A workstream is complete only when:

- its current source and data contract implement the approved product hierarchy;
- tenant/role boundaries and destructive/financial controls pass;
- applicable loading, data, empty, error, offline, refreshing, permission,
  conflict, timeout, selected/focused, locale, theme, and accessibility states
  pass;
- exact-current evidence is linked to commit, dirty state, build, device,
  locale, theme, viewport, test data, and timestamp;
- named human and external approvals are recorded where required.

An old screenshot, installed binary, local mock, route count, test total,
generated matrix, or successful build is evidence for its exact scope only.
