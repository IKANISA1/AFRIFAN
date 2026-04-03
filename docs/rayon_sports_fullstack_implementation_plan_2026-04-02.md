# Rayon Sports Full-Stack Implementation Plan

Date: 2026-04-02

Scope: make `rayon_sports` the production-grade reference implementation for AFRICLUB and the baseline template for all future club apps.

Primary inputs:

- `docs/rayon_sports_readiness_report_2026-04-02.md`
- current Flutter monorepo implementation
- current Supabase schema and edge-function set
- current Play metadata and release assets

## Target Outcome

Deliver a Rayon Sports mobile app and backend platform that satisfy all of the following:

- production-safe for Google Play submission
- operationally complete across frontend, backend, database, release, and compliance
- structurally reusable as the white-label gold master for future clubs
- measurable against explicit acceptance criteria rather than aspirational docs

## Delivery Principles

### 1. Stop adding surface area until the baseline is trustworthy

The next phase is not about adding more features. It is about making the existing platform real, secure, testable, supportable, and legally accurate.

### 2. Treat Rayon as the template, not a one-off exception

Every fix made for Rayon should either:

- become a shared platform capability in `packages/` or `supabase/`
- become a club manifest requirement for all future club apps

### 3. Make the build fail when the platform contract is broken

If a club app is missing required branding, legal URLs, Firebase config, signing configuration, or policy alignment, the pipeline should fail automatically.

### 4. Replace mock fallbacks with explicit product behavior

Demo-safe placeholders were useful during prototyping. For production, every important state must be one of:

- real data
- empty state
- loading state
- degraded-but-explained state
- feature-off state

## Program Structure

The work is organized into 8 workstreams:

1. Release, environments, and secrets
2. White-label platform contract
3. Security, privacy, and compliance
4. Core mobile app completion
5. Backend and database hardening
6. UX, content, and accessibility
7. QA, observability, and supportability
8. Store readiness and rollout

## Phase Plan

## Phase 0: Immediate Containment

Goal: remove the highest-risk issues before any wider release activity continues.

### Work items

- Rotate Android signing credentials immediately.
- Remove committed keystores and signing passwords from the codebase.
- Move Android signing to secret-managed release infrastructure only.
- Freeze Play listing copy until implementation parity is restored.
- Freeze privacy policy publication until legal/data declarations are corrected.
- Confirm whether BioPay remains in the Rayon launch scope.
- Confirm whether SMS auto-read remains in the Play-distributed build scope.

### Deliverables

- new signing setup with no secrets in source
- updated release secret handling procedure
- temporary product scope statement for Rayon launch

### Acceptance criteria

- no signing credentials exist in the repo
- no `.jks` file is stored in the repo
- release build can be signed using CI-injected secrets only
- launch scope is documented and approved

## Phase 1: Platform Foundation

Goal: make the platform buildable, environment-aware, and reusable.

### Workstream 1: Release, Environments, and Secrets

#### Objectives

- make build and release behavior deterministic
- align implementation with the documented white-label model
- introduce proper environment separation

#### Tasks

- Decide the build model:
  - Option A: implement true Android/iOS flavors
  - Option B: standardize on a single app-per-club build path with explicit environment config and remove flavor language
- Add environment configs for at least:
  - local
  - staging
  - production
- Separate:
  - Supabase project refs
  - Firebase projects
  - app identifiers
  - signing configs
  - deep-link domains
  - legal URLs
- Add validation script for each club app:
  - required config keys present
  - required assets present
  - legal URLs non-empty
  - Firebase config present when BioPay or push is enabled
- Build a canonical release command for Android and iOS.
- Add release metadata generation for app version, build number, commit SHA, environment, and club slug.

#### Deliverables

- canonical build matrix document
- environment config spec
- validation script integrated into CI
- reproducible release pipeline

#### Acceptance criteria

- staging and production builds exist and are distinguishable
- the documented release command matches the actual build output
- missing environment prerequisites fail the build early

### Workstream 2: White-Label Platform Contract

#### Objectives

- define what every club app must provide
- remove silent fallback branding

#### Tasks

- Create a mandatory `club_manifest` schema for each app containing:
  - club identity
  - visual branding
  - venue and competition metadata
  - support/legal URLs
  - enabled features
  - markets and languages
  - payments and MoMo metadata
  - BioPay capability flags
- Replace permissive runtime branding fallbacks with validated inputs.
- Fix the Rayon crest asset mismatch.
- Add brand lint checks:
  - crest file exists
  - app icon exists
  - feature graphic exists
  - privacy/terms URLs present
  - support email present
- Generate store metadata from the same manifest rather than maintaining marketing copy separately from code.

#### Deliverables

- club manifest schema
- manifest validator
- Rayon manifest complete and correct
- generated store metadata workflow

#### Acceptance criteria

- Rayon builds without generic placeholders like `Home Stadium` or `Rivals`
- store copy and enabled features derive from the same source-of-truth
- every future club app can be bootstrapped from the manifest contract

## Phase 2: Security, Privacy, and Compliance

Goal: align real app behavior with declared behavior and harden sensitive flows.

### Workstream 3: Security, Privacy, and Compliance

#### Objectives

- eliminate declaration mismatch
- harden sensitive features
- satisfy Play and internal security review

#### Tasks

### Privacy and legal alignment

- Rewrite Privacy Policy, Terms, and Data Safety declarations to match actual system behavior.
- Document exactly what biometric data is:
  - captured
  - transformed
  - transmitted
  - stored
  - retained
  - deleted
- Document exactly what device identifiers, tokens, logs, and analytics are collected.
- Add public account deletion instructions and a support flow outside the app if required by policy.

### BioPay security hardening

- Provision Firebase for Rayon Android and iOS.
- Enforce Firebase App Check with production attestors:
  - Play Integrity on Android
  - App Attest on Apple platforms
- Decide and document the biometric architecture:
  - on-device only
  - or hybrid local inference plus server-side matching
- If server-side biometric matching remains:
  - add explicit consent capture
  - add retention policy
  - add revocation/deletion guarantees
  - add audit logging and rate limiting
- Threat-model BioPay against OWASP MASVS and abuse scenarios.

### Secrets and access control

- Move all production secrets to secret-managed CI/runtime storage.
- Review Supabase service-role usage in edge functions.
- Review RLS coverage table-by-table.
- Add migration checks so new tables cannot ship without policy review.

### Permissions and policy

- Review every Android and iOS permission against actual behavior.
- Keep SMS permissions out of Play builds unless the final approved feature genuinely requires them and passes policy review.
- Add prominent disclosure flows where permissions are sensitive.

#### Deliverables

- corrected legal documents
- security architecture note for BioPay
- threat model for BioPay and sensitive payment/account flows
- permission matrix by feature

#### Acceptance criteria

- no material mismatch remains between product behavior and public declarations
- BioPay attestation works in staging and production
- a security review can be completed without open critical findings

## Phase 3: Core Mobile Product Completion

Goal: make the app operational in its core fan journeys.

### Workstream 4: Core Mobile App Completion

This workstream is split into product domains.

### A. Home and news

#### Tasks

- Remove mock leaderboard, XP, and article fallbacks from production logic.
- Replace them with:
  - explicit empty state
  - cached real data state
  - degraded network state messaging
- Define content freshness rules for:
  - hero cards
  - news articles
  - leaderboard
  - user stats
- Add telemetry for empty and degraded home states.

#### Acceptance criteria

- home screen never presents fabricated fan data in production
- every empty state is intentional and branded

### B. Live match

#### Tasks

- Define the source-of-truth for live data:
  - CMS/admin feed
  - data provider integration
  - manual operations mode
- Create a `matches_live` data model with:
  - fixture state
  - minute
  - scoreline
  - events
  - possession/stats
  - lineups if available
- Build real-time update pipeline via Supabase Realtime or polling with freshness controls.
- Add pre-match, live, half-time, post-match, and postponed/cancelled states.
- Add push integration for match alerts.
- Add live share payloads using real match URLs and metadata.

#### Acceptance criteria

- live screen reflects actual fixture state
- stale live data is visibly marked as stale
- listing copy can truthfully claim live match updates

### C. Notifications

#### Tasks

- Add `firebase_messaging` and APNs/FCM integration.
- Add first-run notification education and actual OS permission requests.
- Implement token registration lifecycle to `user_fcm_tokens`.
- Handle:
  - token refresh
  - sign-out cleanup
  - per-club token scoping
  - foreground/background behavior
- Connect user preferences to routing logic on the server.
- Add notification inbox or history view if product requires traceability.

#### Acceptance criteria

- Rayon users can receive real push notifications on production devices
- preferences control actual delivery categories
- tokens are correctly registered and cleaned up

### D. Membership

#### Tasks

- Audit the membership lifecycle end to end:
  - onboarding
  - membership join
  - identity state
  - card rendering
  - tier/benefits
  - renewal or expiry
- Add explicit membership status states:
  - active
  - pending
  - expired
  - suspended
- Add support and recovery UX for failed enrollments or missing records.

#### Acceptance criteria

- membership status is deterministic and supportable
- membership UI does not depend on hidden assumptions or silent fallbacks

### E. Ticketing

#### Tasks

- Confirm the ticketing operating model for Rayon:
  - seat map or general admission
  - digital wallet/pass
  - QR validation
  - refund or cancellation rules
- Build clear ticket states:
  - available
  - reserved
  - sold
  - transferred if supported
  - used
  - refunded
- Add offline-safe access path for already-issued tickets.
- Add support flow and receipt history.

#### Acceptance criteria

- a real customer can buy, retrieve, and present a ticket reliably
- the support team can diagnose ticket state issues

### F. Contributions and MoMo

#### Tasks

- Audit the contributions flow from initiation to reconciliation.
- Define authoritative transaction states:
  - initiated
  - pending confirmation
  - confirmed
  - failed
  - reversed
- Add receipt and transaction history UX.
- Expose reconciliation states clearly to the user and to operations.
- Integrate operational health events with actionable admin reporting.

#### Acceptance criteria

- contributions are not ambiguous to users
- support and finance teams can reconcile contribution records

### G. SMS ledger

#### Tasks

- Decide product scope:
  - Play build excludes SMS auto-read
  - or a compliant approved SMS flow is implemented
- If retained for non-Play channels or internal tools:
  - remove placeholders and stubs
  - harden ingestion
  - add explicit disclosure
  - add operational monitoring
- Keep production Play copy accurate to the chosen scope.

#### Acceptance criteria

- SMS ledger is either real and policy-approved, or clearly out of scope

### H. Shop

#### Tasks

- Define the commerce flow:
  - catalog
  - stock
  - cart
  - checkout
  - payment
  - fulfillment
  - support
- Add order states and supportability.
- Add empty-state and out-of-stock UX.
- Add image and asset quality checks.

#### Acceptance criteria

- the shop reflects a real operational commerce workflow, not only a UI shell

## Phase 4: Backend and Database Hardening

Goal: make backend behavior production-safe, observable, and aligned with the client.

### Workstream 5: Backend and Database Hardening

#### Objectives

- enforce data integrity
- close parity gaps between backend capability and client usage
- make operations supportable

#### Tasks

### Data model review

- Audit all core tables for:
  - `club_id` presence
  - indexes
  - retention and archival strategy
  - RLS coverage
  - admin access rules
- Introduce lifecycle columns where missing:
  - status
  - source
  - created_by
  - updated_by
  - reconciled_at
  - deleted_at if soft deletion is needed

### Edge-function review

- Review all edge functions for:
  - auth requirements
  - App Check handling
  - rate limiting
  - idempotency
  - structured logging
  - consistent error envelopes
- Add function-level runbooks for:
  - BioPay
  - notifications
  - account deletion
  - contributions

### Admin and content operations

- Build or complete operational admin controls for:
  - news/article publishing
  - live match updates
  - ticket inventory
  - contribution reconciliation
  - user support lookup
  - notification campaigns
- Define which actions belong to:
  - platform admin
  - club admin
  - support agent

### Realtime and sync

- Standardize whether each feature uses:
  - Realtime
  - polling
  - explicit refresh
- Add client cache invalidation rules.
- Add stale-data detection for realtime-dependent screens.

#### Deliverables

- data model audit
- RLS review sheet
- edge-function hardening checklist
- admin operations matrix

#### Acceptance criteria

- every user-facing critical flow has a server-side source-of-truth and observable status
- every critical mutation is idempotent or safely retryable

## Phase 5: UX, Content, and Accessibility

Goal: turn the app from visually strong into genuinely world-class and supportable.

### Workstream 6: UX, Content, and Accessibility

#### Objectives

- make all states intentional
- ensure the app works for a broader user base
- make Rayon content feel fully authentic

#### Tasks

### UX state design

- Define state matrices for each core screen:
  - loading
  - empty
  - success
  - stale
  - permission denied
  - auth required
  - payment failed
  - network degraded
- Replace hidden technical behavior with user-understandable messaging.

### Content design

- Replace placeholder copy with Rayon-specific editorial copy.
- Create content rules for:
  - notifications
  - transactional messages
  - error messages
  - support flows
  - legal consent copy

### Accessibility

- Audit contrast ratios.
- Audit dynamic type and text scaling behavior.
- Add semantics labels to key interactive components.
- Test screen-reader basics for core flows.
- Validate touch targets and motion sensitivity where relevant.

### Adaptive and localization quality

- Validate phone sizes, tablets, and landscape edge behavior where applicable.
- Reconcile iOS orientation support with the app's portrait-only startup behavior.
- Audit localization completeness across Kinyarwanda, French, and English.

#### Deliverables

- UX state matrix
- content style guide for transactional and support copy
- accessibility remediation list
- responsive/adaptive QA matrix

#### Acceptance criteria

- every critical flow has designed empty/error/degraded states
- the app passes baseline accessibility and adaptive checks for release

## Phase 6: QA, Observability, and Supportability

Goal: make the product testable and operable at scale.

### Workstream 7: QA, Observability, and Supportability

#### Objectives

- establish confidence before release
- detect issues quickly after release
- give operations and support teams tools they can actually use

#### Tasks

### Test strategy

- Maintain unit/widget tests for packages.
- Add integration tests for:
  - app startup
  - auth/onboarding
  - profile and membership setup
  - notification opt-in
  - contribution happy path and failure path
  - ticket retrieval
  - BioPay enrollment/match if in scope
- Add smoke tests to CI for the Rayon release build.

### Observability

- Integrate real crash reporting.
- Add structured non-fatal event logging for critical user journeys.
- Correlate client app version with backend logs.
- Create dashboards for:
  - auth failures
  - contribution failures
  - notification registration failures
  - BioPay failures
  - live data freshness failures

### Supportability

- Define internal runbooks for:
  - failed sign-in
  - missing membership
  - payment mismatch
  - duplicate contribution
  - ticket unavailable
  - BioPay enrollment/match problems
  - notification not received
- Add admin diagnostics views where needed.

#### Deliverables

- test strategy
- CI test matrix
- monitoring dashboard definitions
- support runbooks

#### Acceptance criteria

- a failed production user journey can be diagnosed from logs and dashboards
- release gating includes automated checks beyond unit tests

## Phase 7: Store Readiness and Rollout

Goal: move from technically complete to safely publishable.

### Workstream 8: Store Readiness and Rollout

#### Objectives

- ensure metadata, legal, and app behavior are aligned
- make rollout reversible and measurable

#### Tasks

### Store metadata and assets

- Regenerate listing text from the actual implemented feature set.
- Verify screenshots reflect the real product, not prototype-only surfaces.
- Verify feature graphic, icon, short description, full description, category, and support info.

### Compliance and declarations

- Complete Play Data Safety responses from actual data flow documentation.
- Verify account deletion flow meets policy expectations.
- Verify permission declarations match runtime behavior.

### Rollout mechanics

- Set up:
  - internal testing
  - closed testing
  - staged production rollout
- Define release gates:
  - all critical tests pass
  - no open critical security findings
  - legal URLs live
  - crash-free threshold acceptable in testing
  - support playbook ready

### Post-launch controls

- Define launch-day monitoring checklist.
- Define rollback criteria and rollback path.
- Define first-week KPI dashboard:
  - install success
  - onboarding completion
  - notification opt-in
  - contribution success rate
  - ticket retrieval success
  - crash-free sessions

#### Deliverables

- final Play submission package
- staged rollout plan
- launch-day runbook
- rollback plan

#### Acceptance criteria

- the Play submission package is internally auditable and factually accurate
- Rayon can be rolled out in stages with observability and rollback readiness

## Cross-Functional Roles

Recommended ownership model:

### Mobile engineering

- Flutter app architecture
- feature completion
- notification client
- offline/cache behavior
- integration tests

### Backend engineering

- Supabase schema and migrations
- edge functions
- data integrity and idempotency
- admin capabilities
- operational dashboards

### DevOps / release engineering

- CI/CD
- signing
- secrets
- environment separation
- release pipelines

### Product / UX

- scope control
- state design
- information architecture
- content quality
- rollout decisions

### Security / compliance

- App Check and attestation review
- permission review
- privacy/data safety alignment
- threat modeling

### QA

- test plan
- regression matrix
- release validation
- device coverage

## Suggested Timeline

This is the shortest realistic timeline for a disciplined production push, assuming focused delivery.

### Sprint 1

- containment
- secrets rotation
- release path decision
- environment contract
- legal/data declaration correction draft

### Sprint 2

- Firebase/App Check provisioning
- white-label manifest contract
- branding fixes
- notification architecture implementation start
- home/news mock removal

### Sprint 3

- real push token flow
- live match data pipeline
- contribution flow hardening
- support/legal URLs live
- crash reporting and dashboards

### Sprint 4

- membership and ticketing end-to-end validation
- BioPay hardening or scoped removal from launch
- integration test suite
- admin operational tooling

### Sprint 5

- accessibility and adaptive QA
- app-size optimization
- Play metadata regeneration
- internal/closed testing

### Sprint 6

- bug burn-down
- staged release prep
- support runbooks
- go/no-go review

## Prioritized Backlog

### P0: Must happen first

- rotate signing credentials and remove keystores from repo
- correct privacy/data safety declarations
- make legal URLs live
- align documented build path with actual build path
- provision Firebase/App Check if BioPay remains enabled

### P1: Must happen before release candidate

- add true notifications stack
- replace mock production fallbacks
- implement real live match data flow
- define and enforce white-label manifest
- add integration tests and CI release gating
- add crash reporting and operational dashboards

### P2: Should happen before scale-out to other clubs

- admin operations completion
- adaptive/accessibility pass
- app-size reduction
- localization completeness audit
- generated store metadata pipeline

## Definition of Done

Rayon Sports is considered complete as the white-label reference implementation only when all of the following are true:

- the release path is deterministic and documented
- no production secrets exist in source control
- all public legal and policy statements match actual implementation
- no critical flow depends on mock data in production
- push notifications work end to end
- live match updates work end to end or are honestly removed from claims
- every enabled sensitive feature has working attestation and monitoring
- critical user journeys have integration coverage
- launch support runbooks exist
- Play submission materials are accurate and review-ready
- a new club can be onboarded from the Rayon baseline without custom firefighting

## Immediate Next Actions

The first execution sequence should be:

1. Security containment:
   - rotate keys
   - remove committed signing material
   - freeze release
2. Truth alignment:
   - correct legal/data safety/store claims
   - decide launch scope for BioPay and SMS auto-read
3. Platform readiness:
   - fix build model
   - add environments
   - add manifest contract
4. Product completion:
   - notifications
   - live match
   - remove mock production behavior
5. Release readiness:
   - CI/CD
   - integration tests
   - dashboards
   - staged rollout

## Recommended Companion Artifacts

To execute this plan cleanly, create these next:

- `docs/rayon_sports_delivery_backlog.md`
- `docs/rayon_sports_release_checklist.md`
- `docs/rayon_sports_permission_matrix.md`
- `docs/rayon_sports_data_flow_map.md`
- `docs/club_manifest_spec.md`
- `docs/white_label_readiness_gate.md`

## Final Recommendation

Do not treat Rayon as "almost finished feature-wise". Treat it as "architecturally promising but operationally unproven".

The right move now is disciplined completion, not feature expansion.

If this plan is executed in order, Rayon Sports becomes more than a club app. It becomes the enforceable platform template for the rest of the AFRICLUB fleet.
