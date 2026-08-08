# AFRICLUB Football-Club-First Implementation Plan

Updated: 2026-08-02

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

The structural football-club-first correction is implemented in the current
checkout:

- primary mobile navigation is Home, Club, Fan Zone, and Membership;
- Settings is a profile-owned branch, with legacy deep links preserved;
- `feat_club` owns the canonical Club hub, team, news, fixtures, results,
  standings, history, and project routes, with contextual ticket and shop
  routes;
- Home, Club, Fan Zone, and Membership follow the product priority in this
  plan, while venue utilities remain secondary matchday experiences;
- missing or invalid `club_id` now fails closed in shared networking; partner
  identifiers are compatibility metadata only;
- EN/FR/RW catalogs have exhaustive Settings, Admin, and Game key parity;
- strict repository analysis and the deterministic 44-package test suite pass.

The implementation is route-state complete locally, but it is not yet design-
approved or release complete. The fresh route ledger contains 176 routes and
2,816 cells: all 2,137 applicable cells are admitted, zero remain open, and 679
are explicitly not applicable. The final nine Admin PWA routes and seven Venue
portal routes passed exact-current controlled browser execution, visual review,
source-freshness preflight and explicit fail-closed admission. The static
Flutter copy inventory now has zero pending candidates across all 292 scanned
production Dart files; dynamic API/CMS copy and named French/Kinyarwanda review
remain separate.
Cross-surface game ownership/Realtime decisions, physical-device and
authenticated operator UAT, production TV signing, CI/distribution, stores,
rights, and named approvals also remain open. Therefore
`design_complete=false`.

### Implementation checkpoint — 1 August 2026

The football-club-first Club route family has completed its locally actionable
route-state tranche:

- all eleven Club routes have explicit presentation and applicability
  contracts;
- all 153 applicable cells have executable nested-route tests and exact
  current goldens; 23 cells are structurally not applicable;
- Club reads are bounded, confirmed content is retained during refresh, and
  offline, permission-denied, conflict, security-timeout, and unknown failures
  use distinct sanitized recovery;
- the state copy is generated from complete EN/FR/RW catalogs;
- 194 Club tests, strict package analysis, route-inventory generation, and the
  1,252-baseline golden contract pass locally.

This checkpoint closes local route-state evidence only. It does not approve
the live Club History or other CMS content, authenticate production data,
prove physical-device assistive technology, provide named linguistic, design,
or privacy approval, seal a clean candidate, or authorize signing, stores,
deployment, or release. The 87-task denominator remains unchanged. EV-234,
DEC-226, and ISS-217 are the controlling records.

The next locally actionable tranche has also advanced: the static role-gated
`/game-operations` hub closes 6/6 applicable interaction and presentation
cells with ten explicit non-applicability decisions, `/my-tvs` closes 14/14
applicable owner-inventory cells with two explicit N/A decisions, and
`/my-tvs/pair` closes all 16 applicable pairing cells, and
`/my-tvs/:displayId` closes all 16 applicable owner-management cells. Typed offline recovery,
retained-authority lockout, valid-field/current-authority gating, named-scope
privacy, explicit synchronization, and mutation-uncertainty lockout advance
the intermediate ledger to 1,810 evidenced, 332 open, and 674 not applicable,
with 1,304 exact golden baselines. The planner and live-control source contracts now
lock actions during any unconfirmed refresh, clear protected data on
permission loss, preserve stable mutation identity, and pass the 158-test Game
Operations regression. The applicability reconciliation moves the current
ledger to 1,810 evidenced, 328 open, and 678 not applicable. The controlled
`/game-operations/sessions` organizer inventory then closes its 14 applicable
cells with two explicit N/A decisions, bringing the governed contract to 1,318
exact baselines and the current ledger to 1,824 evidenced, 314 open, and 678
not applicable. The organizer planner then closes all 16 applicable cells with
complete-plan gating, selected-invitee evidence, organizer-specific offline
recovery, exact focus and held-press execution, readable 200-percent action
copy, and retained-refresh/conflict/timeout lockout. This brings the governed
contract to 1,334 exact baselines and the current ledger to 1,840 evidenced,
298 open, and 678 not applicable. The organizer live-control route then closes
all fourteen applicable cells, with empty and selected explicitly N/A,
imperative normal-transition copy, organizer-specific offline recovery, exact
interaction/theme/reflow evidence, and complete primary/exception lockout
during refresh or mutation uncertainty. The governed contract reaches 1,348
exact baselines and the current ledger 1,854 evidenced, 284 open, and 678 not
applicable. Shared/live authorization remains open.
Participant discovery then closes 15/15 applicable cells with persistent
selected explicitly N/A, and participant live play closes all 16 cells with
distinct retained synchronization, permission, conflict, bounded timeout,
disabled-answer, focus, held-press, selected-answer, theme, motion, and
200-percent-text evidence. The governed contract reaches 1,379 exact
baselines. That intermediate fail-closed ledger had 1,881 admitted cells, 256
open cells, and 679 not applicable. EV-243, DEC-235, and ISS-226 control the
rejected candidate checkpoint; EV-244 and DEC-236 are rejected contradiction
records, while ISS-227 records the competing-writer risk.

### Final local route-state admission checkpoint — 2 August 2026

The final Admin PWA and Venue portal tranche completed corrective source,
specification, exact-current execution, review, and admission:

- the earlier shared Admin and venue runs produced candidate artifacts, but
  independent admission review rejected incomplete state manifests,
  mislabeled responsive themes, and clipped compact venue navigation;
- current specs now require all sixteen governed states plus tablet and compact
  captures and fail closed before any batch registration;
- the corrected specs require dark and light Axe checks, 48-pixel targets,
  real focus, held press, selection, reduced motion, 200-percent reflow,
  privacy-safe copy, offline, permission, synchronization, conflict, and
  timeout consequences;
- visual review corrected large-text settings and feature layouts, shop-form
  stretching, Admin light-theme contrast, and venue light-theme metadata
  contrast before the exact-current rerun;
- all nine Admin PWA and seven Venue portal suites passed against current
  source; a final seven-route Venue rerun confirmed stable compact navigation
  and complete action-label rendering;
- privacy/source-freshness preflight, controlled visual review and explicit
  atomic registration admitted sixteen bundles, taking evidence governance to
  135 admitted and zero pending;
- the older candidate captures remain rejected contradiction evidence and were
  not used to bypass review.

The local route-state ledger now records all 2,137 applicable cells admitted,
zero open cells, 679 explicit N/A decisions, and `closure_complete=true`.
Design compliance records zero violations, one governed approval warning,
`route_evidence_complete=true`, and `design_complete=false`. This does not
prove authenticated live
roles/RLS, live operational data or mutations, physical assistive technology,
representative-device performance, accountable design/content/privacy review,
a clean pinned-CI candidate, production signing, stores, deployment, or
release approval. EV-248, DEC-240, and ISS-231 control this checkpoint.

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

Both families synchronize structured game state. The current scope does not
authorize a live or prerecorded video programme, ingest, transcoding, CDN,
streaming telemetry, video moderation/rights, bandwidth, or video fallback
pipeline. Any such programme requires a separate approved contract.

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
The supporter app never exposes venue-staff or broad admin controls. Only the
narrow, non-tab, role-gated `My TVs` owner and `Games I manage` organizer
projections are permitted; `/admin` remains excluded from consumer builds.

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
preview the correct consumer projection → audit the mutation. Game work is
separated into Content Studio, Session Planner, and Live Control; normal
operations use authorized named selectors and guarded review/confirmation
instead of pasted identifiers. Venue staff see only assigned venues; narrow
organizer/TV-owner capabilities remain explicitly role-gated.

## 6. Implementation Workstreams

### Phase 0 — contract and baseline

- Record this plan in README, DESIGN, architecture, UAT, game, venue, and
  governed goal documents.
- Preserve the existing 87-task denominator; map this plan as nested acceptance
  criteria until the controlled register explicitly changes it.
- Confirm route aliases, feature ownership, game content policy, named owners,
  and due dates.
- Capture current build logs. The checked-in and generated iOS floor is 15.5;
  the unsigned iOS release artifact now builds. A clean controlled candidate,
  distribution signing, and device/store evidence remain separate gates.

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
- Force generated and imported questions to `pending_review`. Show bounded
  source/citation, schema/model, generation, reviewer, review time, and
  deterministic duplicate, ambiguity, answer-consistency, language, and
  entertainment-policy QA beside every draft without exposing answers. Block
  approval when any required check fails, then require the exact mobile/TV
  preview fingerprint before a source-backed approved pack can publish.
- Keep Content Studio, Session Planner, and Live Control as distinct
  task-oriented workspaces; keep UUID, version, deadline, ordering, and
  idempotency mechanics internal to guarded actions.
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

The following core game decisions are approved and enforced in the controlled
contract and authoritative runtime:

- one session may target several explicitly assigned displays;
- home displays are owner/invitation scoped and never implicitly club-wide;
- venue managers operate assigned displays and require an explicit organizer
  grant to control a game;
- participant identity is the authenticated AFRICLUB account projected through
  a session-safe public alias; and
- synchronized structured prediction/reviewed-trivia state is the approved
  scope; no video pipeline is inferred.

The following remain explicit decisions; implementation must not invent them:

- named product/engineering/design/content/linguistic/release owners and dates;
- eligible leagues, competitions, and match-selection authority;
- music-trivia rights and moderation policy;
- measured retirement of legacy participant-code and browser-TV compatibility;
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

## 9. Implementation and validation checkpoint — 30 July 2026

Locally verified:

- Melos 8 root-workspace migration, deterministic test wrapper, and runtime
  pinning.
- Strict analysis across 64 packages and 2,621 tests across 44 packages.
- Admin 266, Gamification 599, Settings 118, Core Theme 433, Core Network 78,
  Core L10n 8, and native TV 35-test focused package suites.
- Web 916 tests across 110 files, TypeScript, zero-warning lint, production
  build, 161.38 kB
  app shell under 170 kB, and 43.29 kB CSS under the explicit 45 kB ceiling.
- Local Supabase pgTAP 15/15 and Edge/Deno 74/74.
- Three release-readiness integration journeys.
- Unsigned iOS `Runner.app.zip`, ephemeral-key Android AAB, and native-TV debug
  APK builds. These are not distribution-signed or store-approved artifacts.
- 71-component closure with 316/316 applicable state cells evidenced.
- 176-route inventory with zero duplicate keys.

Critical gaps and mismatches that remain:

- Route evidence is not complete: 396 applicable cells remain open, so the
  route ledger and `design_complete` stay false.
- Phase 1 Club route-state implementation is locally closed: all eleven
  canonical routes have bounded and localized loading, truthful empty/fallback
  behavior, explicit refresh and retained-data synchronization, sanitized
  offline/permission/conflict/timeout recovery, focus/press, 200-percent text,
  reduced motion, and dark/light evidence. Approved live content, Admin
  publishing preview, notifications/analytics integration, physical-device
  accessibility, linguistic/design/privacy approval and release remain open.
- The localization source scanner reports zero pending conservative
  candidates across all scanned Flutter packages. Dynamic/server copy, named
  linguistic approval, and approved localized route evidence remain separate.
- The shared game backend exists, and the local AI-trivia draft gate now forces
  `pending_review`, retains citation/schema/model and human-decision evidence,
  and fails approval closed on deterministic content checks. Authorized
  migration/pgTAP execution and accountable editorial approval are still open.
  Organizer ownership, ordered Realtime
  convergence, TV discovery/assignment, approved match-selection authority,
  AI-trivia editorial approval, and music rights are not all externally closed.
- The Admin game console is task-oriented and routine raw-ID entry is removed
  in local source. The signed-out authentication gate now has exact current
  desktop/tablet/compact production renders and a combined same-state
  reference/current/difference review; authenticated game-workspace comparison
  and live role/RLS/RPC/audit execution remain open.
- Content provenance, deterministic QA, and exact mobile/TV preview
  acknowledgement are enforced locally before pack publication; the new
  migration is included in a clean isolated full-chain reset and the expanded
  Live Games V2 contract passes all 80 pgTAP checks. Accountable editorial and
  shared/live-environment approval remain open.
- Admin Live Control now presents the authorized participant and TV
  projections, server-time latency buckets, and explicit refresh/reconnect
  health without participant identity, correct answers, or device credentials.
  A clean isolated full-chain migration passes; authenticated shared/live
  network comparison remains open.
- The light-theme Admin authentication source now uses semantic text/accent
  roles with a measured minimum 5.42:1 contrast ratio. Exact fresh 1280 × 720,
  834 × 1194 and 390 × 844 production captures, saved-file inspection and the
  combined visual comparison pass after compact heading/footer wrap correction.
  GAME-ADM-05 is complete for local source/visual scope; broader authenticated,
  live-backend, physical-AT, approval and release gates remain open.
- Consumer-web TV locally completes GAME-WEB-01: a positive authoritative
  club id gates `{club_id}:game_session:{session_id}`, zero-club subscription
  is rejected, cleanup and reconnect snapshot refresh are tested,
  authorization failure renders fail-closed, and pre-reveal answer-only fields
  are rejected. Live RLS/Realtime, subscription-denial/event-loss timing,
  multi-display/cross-client, device, approval and release gates remain open.
- GAME-BE-01..06 are complete for local source and isolated-database scope:
  display capability bounds
  are enforced at the relation, many-display assignment is explicit and
  audited, every participant/organizer/admin/TV projection carries the required
  version/timing/action/freshness contract, and lifecycle exceptions include
  reasoned retry-safe skip and early end. Owner, venue-manager, organizer,
  club-admin and platform-admin display scope plus participant/denial event RLS,
  Realtime publication, privacy, native-TV identity binding/revocation, and
  mandatory projection refresh pass 77 pgTAP checks after a clean full
  migration. Shared/live-environment deployment,
  real-network Realtime, cross-client/device and release proof remain open.
- Native TV binds a dedicated anonymous Auth identity to one active device
  credential, subscribes only to assigned club/session events, ignores stale
  hints, refreshes the authoritative projection, recovers after channel error,
  clears identity on revocation, and uses five-second polling only as a
  fallback. GAME-TV-02 now passes a fresh isolated Realtime v2.120.3 network
  execution with five ordered assigned-TV events, zero unbound-TV events under
  per-event RLS, 542 ms local p95, and zero post-revocation delivery. Shared/live
  WAN loss/soak, cross-client, physical-TV, approval and release proof remain
  separately open.
- GAME-QA-01 is complete for local source and isolated-database scope: the
  controlled contract and 80-check pgTAP suite cover projection
  serialization/sanitization, role/action matrices, grants/RLS, lifecycle
  preconditions, idempotency, ordering/version rejection, deadlines,
  append-only audit events, and no premature answer exposure. Cross-client,
  shared/live, physical-device, approval and release proof remains open.
- GAME-QA-02 is complete for deterministic local scope: one controlled fixture
  drives participant mobile, organizer mobile, native TV, and Admin through
  lobby, open, reveal, next, completion, and cancellation with identical
  authoritative phase/version/sequence and role-appropriate data. Forty
  Flutter and 22 Admin focused tests pass. Real synchronized devices,
  network/Realtime timing, accessibility, approval and release proof remain
  open under GAME-QA-03 through GAME-QA-06.
- GAME-QA-03 now has a controlled eight-clause execution matrix and completed
  device preflight. Exact inventory found zero available physical phones, one
  paired but unavailable iPhone 12 Pro, zero physical native-TV targets, two
  iOS simulators and the known Android TV emulator. The simulated targets are
  not substitutes. The criterion remains open for authorized shared-backend
  execution, two independent phones plus physical native TV, correlated exact-
  build logs/video, measured network loss/recovery, accessibility and named
  accountable approvals.
- GAME-QA-04 is complete for deterministic local scope: one controlled matrix
  binds all eleven required resilience scenarios to exact participant/mobile
  and native-TV test names. The 86-file-selection test run and strict workspace
  analysis pass, and the static contract fails if a scenario, executable test,
  assertion, or fail-closed environment boundary is removed. This does not
  close GAME-QA-03 real synchronized devices/network timing, GAME-QA-05
  physical accessibility, or GAME-QA-06 exact-candidate/release proof.
- GAME-QA-05 is partially implemented and deliberately remains open. Its
  controlled thirteen-clause matrix records ten passing clauses: nine local
  deterministic clauses backed by 55 native-TV tests and one inspected exact-
  200-percent 720p golden, plus current native Android TV API 36 emulator
  captures at 1920 x 1080 and 3840 x 2160. Physical-TV overscan, remote/
  screen-reader execution, four-hour burn-in/thermal/crash/ANR soak,
  accountable design/privacy approval, shared/live execution, and release are
  not inferred from emulator evidence.
- GAME-QA-06 now has a controlled nine-clause matrix. Exact-current dirty local
  unsigned iOS release, ephemeral-signed Android AAB, ephemeral-signed native-
  TV release APK, and web typecheck/zero-warning lint/111-file/933-test/
  production-build clauses pass. The development-signed current iOS app also
  installs and launches on the exact paired iPhone 12 Pro, advancing physical
  iOS only. A sealed clean candidate, pinned CI, complete physical UAT/AT,
  production signing/stores, authorized target migration/rollback, named
  approvals, and release remain fail-closed.
- GAME-MOB-05 is complete for controlled local source, visual, and
  accessibility scope. The eleven-clause participant-layout matrix requires
  37 passing localization/screen/route tests and four registered exact
  current-source goldens for standalone safe-area gameplay, compact/keyboard
  reachability, EN/FR/RW exact-200-percent reflow, theme, reduced motion,
  denial, offline retention, reconnect/last-update, and timeout recovery.
  Shared/live, physical-device/AT, network-timing, accountable approval, and
  release evidence remain separate fail-closed gates.
- GAME-MOB-04 is complete for controlled local deterministic recovery scope.
  Its seven-clause matrix binds 67 passing controller/widget tests and the
  governed offline golden across network change, missed events, foreground
  resume, uncertain session-version recovery, retained safe state, localized
  last-update, and privacy-safe failure mapping. Shared/live,
  physical-device, real-network timing/loss, approval, and release remain
  separate fail-closed gates.
- GAME-MOB-03 is complete for controlled local authoritative participant
  synchronization scope. Its seven-clause matrix binds 68 focused tests and
  the existing 80-check isolated database contract across validated
  club/session identity, exact topic-filtered privacy-safe hints, versioned
  projection refresh, monotonic stale/out-of-order rejection, server-time
  deadlines, prohibited client scoring/lifecycle authority, and
  unexpected-close recovery/cleanup. Shared/live delivery, physical-device,
  real-network ordering/timing, approval, and release remain separate
  fail-closed gates.
- GAME-MOB-01 is complete for controlled local and isolated-database
  code-free eligible-game discovery scope. Its seven-clause matrix binds 69
  Flutter tests and 77/77 full-chain pgTAP checks across five governed sources,
  live/scheduled grouping, targeted deep-link reauthorization, validated
  live-game notification opens, and fail-closed code/private/stale/ineligible
  data. Shared/live discovery, physical-device notification delivery,
  approval, and release remain separate fail-closed gates.
- GAME-MOB-02 is complete for controlled local participant-code retirement
  scope. Its seven-clause matrix binds 98 Flutter tests, 42 Admin web tests,
  eleven removed legacy source/test files, session-ID-only Flutter/Edge/Admin
  joins, retired EN/FR/RW code-entry messages, preserved owner `My TVs`
  challenge pairing, and four reviewed Fan Zone golden changes. Shared/live,
  physical-device, real-network timing, approval, and release remain separate
  fail-closed gates.
- GAME-ORG-01 is complete for controlled local organizer planning and control
  scope. Its eight ordered clauses bind 36 Flutter tests, 8 localization
  tests, 80/80 full-chain isolated pgTAP checks, and one inspected exact
  390 x 844 planner golden across role gating, published complete packs,
  schedule bounds, eligibility/invitations, paired display assignment,
  activation/start, authoritative supervision, and completion. Shared/live
  role/RLS/RPC/audit, real-network timing, physical-device/AT, accountable
  approval, signing, stores, deployment, and release remain separate
  fail-closed gates.
- GAME-ORG-02 is complete for controlled local guarded organizer operations.
  Its seven ordered clauses bind 45 Flutter tests, 8 localization tests, the
  unchanged 80/80 isolated pgTAP evidence, and one corrected and inspected
  exact 390 x 844 control golden across a single normal next transition,
  separately confirmed exceptions, dedicated reasoned skip/early-end RPCs,
  authoritative pause/resume, stable retry identity, and conflict/timeout
  refresh lockout. Shared/live role/RLS/RPC/audit, real-network timing,
  physical-device/AT, accountable approval, signing, stores, deployment, and
  release remain separate fail-closed gates.
- GAME-OWN-01 is complete for controlled local owner-inventory scope. Its
  seven ordered clauses bind 49 Flutter tests, 8 localization tests, a fresh
  80/80 full-chain isolated pgTAP run, and one inspected exact 390 x 844
  golden across role/club scope, connection health and last seen, app version,
  bounded capabilities, assigned-session context, safe empty/denied/offline
  recovery, and credential/pairing-material exclusion. Shared/live role/RLS/
  RPC/audit, real displays and network timing, physical-device/AT, accountable
  approval, signing, stores, deployment, and release remain separate
  fail-closed gates.
- GAME-OWN-02 is complete for controlled local owner pairing and management
  scope. Its seven ordered clauses bind 57 Flutter tests, 8 localization
  tests, a fresh 80/80 full-chain isolated pgTAP run, and one inspected exact
  390 x 844 TV-detail golden across native-TV bootstrap entry, named
  authorized locations, confirmed audited rename/move/revoke,
  credential-rotating recovery, stable retry lockout, and retirement of the
  obsolete owner-issued pairing interfaces. Shared/live role/RLS/RPC/audit,
  real displays and network timing, physical-device/AT, accountable approval,
  signing, stores, deployment, and release remain separate fail-closed gates.
- GAME-TV-03 is complete for controlled local native-TV pairing-only scope.
  Its seven ordered clauses bind 56 native-TV Flutter tests, a fresh 80/80
  full-chain isolated pgTAP run, zero-issue analysis, and one side-by-side
  reviewed 1280 x 720 pairing golden across hashed short-lived challenge,
  exact My TVs owner QR deep link, pending authenticated claim, one-time secure
  credential exchange, pairing-material removal, revocation, and recovery.
  Shared/live, physical-TV/remote/AT, network timing, accountable approval,
  production signing, stores, deployment, and release remain separate
  fail-closed gates.
- GAME-TV-01 is complete for controlled local native-TV full-projection scope.
  Its nine ordered clauses bind 58 native-TV Flutter tests, the fresh
  unchanged-backend 80/80 full-chain isolated pgTAP run, zero-issue analysis,
  and five exact current-source 1280 x 720 goldens across paired-empty,
  scheduled, lobby, question/choices/countdown, reveal/public result,
  contiguous privacy-safe standings, completion, pause/cancellation,
  retained-offline, reconnect, and strict lifecycle payload validation.
  Authorized real-network Realtime, shared/live cross-client execution,
  physical-TV/remote/AT, 1080p/4K and soak, accountable approval, signing,
  stores, deployment, and release remain separate fail-closed gates.
- GAME-ARCH-02 is complete for the architecture boundary: both DESIGN
  authorities, README, blueprint, this plan, module registration and route
  tests agree that seven narrow owner/organizer projections are permitted but
  `/admin` and broad venue-staff/operator controls remain outside consumer
  builds. Live owner/organizer authorization and release evidence remain open.
- CSS is below its approved ceiling but remains near it; route-level extraction
  is recorded technical debt.
- Flutter warns that two iOS plugins do not yet support Swift Package Manager,
  and Flutter/Android warns about future Built-in Kotlin migration. Current
  builds pass, but these are dependency-upgrade risks.
- Production TV release signing correctly fails closed without external
  `TV_ANDROID_*` credentials.
- Physical-device accessibility/UAT, authenticated Admin/Venue role UAT,
  production backend/migration authority, CI, distribution signing, stores,
  monitoring, incident rehearsal, and named human approvals remain external.

The existing 87-task denominator is unchanged. Current reconciliation records
49 verified complete, 33 verified incomplete, and 5 unverified; 38 task IDs
remain open for route evidence plus external, live, device, approval, CI,
signing, store, deployment, or release evidence.
