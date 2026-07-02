# AFRICLUB Game Architecture Review And Implementation Plan

Date: 2026-07-02
Workspace: `/Volumes/PRO-G40/AFRICLUB`
Comparator: `/Volumes/PRO-G40/FANZONE`
Product brief folder: `/Users/jeanbosco/Downloads/AFRICLUB GAME PRODUCT DESIGN`

## 1. Review Scope And Evidence

This report reviews four evidence sets:

1. Current AFRICLUB repo architecture, especially `README.md`, `RULES.md`, `DESIGN.md`, `docs/blueprint.md`, `docs/screen_inventory.md`, `packages/core/*`, `packages/features/feat_gamification/*`, `apps/rayon_sports/*`, and Supabase migrations/functions.
2. Rayon Sports app architecture as the reference club implementation, including `apps/rayon_sports/lib/main.dart`, `packages/clubs/club_rayon_sports`, shared module registry, router, `DESIGN.md`-governed UI primitives, and admin/public web surfaces.
3. FanZone repo architecture, especially `README.md`, `docs/architecture/*`, Flutter mobile features, React/Vite admin, venue portal, TV display, shared TypeScript contracts, Supabase functions, migrations, SQL tests, and release gates.
4. Product design markdown files:
   - `Product Design & Architecture v3.md`
   - `Product desing 2.md`

No runtime implementation was changed in this pass. The AFRICLUB working tree was already heavily dirty, so this report is intentionally standalone.

## 2. Executive Verdict

AFRICLUB has a serious monorepo foundation: many club Flutter shells, shared core packages, shared feature modules, club-specific config packages, centralized web admin/public site, Supabase migrations, feature flags, route-presentation metadata, and recent native mobile UX gates. It is not a blank scaffold.

The current repo, however, is still fundamentally a white-label football-club supporter platform with a Fan Zone rewards/prediction layer. The July 2 product-design brief describes a different center of gravity: venue-native entertainment where TV is the stage, mobile is the controller, and admin is the control room. That product needs TV/display state, live game sessions, venue/presence concepts, first-correct answer locking, AI question moderation, host operations, and strict no-financial/no-betting vocabulary.

The most important finding: current AFRICLUB still contains launch-risk concepts such as wallet, token, stake, payout, odds, betting labels, prediction-market sheets, and partner-funded pool payouts. Some of this was already flagged in `docs/gamification_alignment_africlub_vs_fanzone_2026-06-29.md`, but the July 2 product-design documents make the conflict sharper. The product brief says no cash purchase, no cash-out, no betting odds, no financial return, no data-driven pick advice, and consumer-facing points instead of wallet/tokens. AFRICLUB must complete that semantic and backend-contract migration before adding quiz/game features.

Recommended direction: keep AFRICLUB's white-label club architecture, but add a game platform layer informed by FanZone: scoped realtime, TV display surface, venue/event/session model, audited Edge/RPC boundaries, product-boundary scans, settlement/ledger SQL tests, and operational admin tools. Do not transplant FanZone wholesale. Apply its architecture discipline and selected domains, then adapt them to AFRICLUB's club/partner/matchday context.

## 3. Current AFRICLUB Architecture Review

### 3.1 Current Shape

AFRICLUB is a Melos Flutter/Next/Supabase monorepo:

- `apps/<club>/`: thin Flutter app shells for many clubs.
- `apps/rayon_sports/lib/main.dart`: Rayon reference app bootstrap.
- `apps/rayon_sports/web`: Next.js public website and centralized admin PWA.
- `packages/core/core_app`: bootstrap, startup, shell, app orchestration.
- `packages/core/core_router`: GoRouter module architecture, bottom-tab contract, route presentation decisions, transition helpers.
- `packages/core/core_theme`: tokens, typography, shared chrome, navigation, async/loading/banner primitives.
- `packages/core/core_feature_config`: runtime feature flags by club/channel.
- `packages/features/*`: shared feature modules.
- `packages/clubs/*`: per-club configuration.
- `supabase/migrations`: database history and product runtime changes.
- `supabase/functions`: Edge Functions for platform config, notifications, LiveScore/OpenAI sync, MoMo parsing, SMS ingest, etc.

The strongest architectural choices are:

- Thin per-club app shells. Rayon Sports is a reference implementation without duplicating product logic per club.
- Feature modules declare routes and route presentation decisions. This reduces route sprawl and makes app navigation auditable.
- `primaryBottomTabFeatureOrder` is now source-backed as `home`, `fanzone`, `settings`.
- Feature configuration is runtime-aware through platform config snapshots, falling back to compile-time club flags.
- Admin is centralized in web by default; mobile admin is excluded unless explicitly enabled.
- UI ownership is centralized in `core_theme`, with root `DESIGN.md` enforcing universal patterns.

### 3.2 Critical Architecture Problems

1. `RULES.md` is partially corrupted and internally inconsistent. It contains garbled inserted text and older statements that conflict with `docs/screen_inventory.md`. This weakens governance. Fixing this is P0 before major product work.

2. The architecture docs say the product has three surfaces: Flutter fan app, centralized admin PWA, and public website. The July 2 game product requires at least one additional runtime surface: a TV/stage app. It can start as Flutter Web, React/Vite PWA, or Flutter desktop/web, but the current repo does not have it.

3. The current Fan Zone is overloaded. `FanzoneModule` owns fixtures, live redirect, predictions, match detail, wallet, offers, rewards, history, leaderboard, notifications, badges, streak, sharing, league, standings, teams, club zone, fan ID, social, and privacy redirect. Route-presentation metadata mitigates this, but the domain is still too broad for the new product.

4. Product vocabulary and backend semantics are not yet aligned with the July 2 brief. Current code and docs still expose or preserve wallet/token/stake/payout/odds/betting concepts. FanZone has a product-boundary scan that blocks this; AFRICLUB needs the same.

5. The new game spec depends on authoritative server actions that AFRICLUB does not yet expose: first-correct claim, one attempt per player per question, no correct-answer leakage, live question state, host-controlled state changes, reconnect behavior, and question provenance.

6. AFRICLUB has no equivalent of FanZone's TV display source of truth (`venue_screen_states`) or scoped realtime release gate. Realtime subscriptions must be tenant/session scoped from day one.

7. The Supabase migration history is large and operationally active. Any game schema must be additive, with RLS, grants, and SQL contract tests in the same implementation slice.

## 4. Rayon Sports App Architecture Review

Rayon Sports is currently a thin Flutter shell:

- It imports `app_registry`, `club_rayon_sports`, and `core_app/bootstrap`.
- It passes `RayonSportsConfig` into shared bootstrap.
- Modules are built through `AppModuleRegistry.build(config, configSnapshot: snapshot)`.
- Firebase startup options are app-specific, but product modules are shared.

This is the correct architecture for a reference club. The app itself should not become the game product's logic owner. The right split is:

- Keep Rayon app as the reference shell and UAT target.
- Put reusable game primitives in shared packages.
- Put club identity and fixture defaults in `packages/clubs/club_rayon_sports`.
- Put mobile game screens in shared feature packages, not in `apps/rayon_sports/lib`.
- Put web admin/game operations in `apps/rayon_sports/web` only until a dedicated shared admin app exists.

Critical Rayon-specific issue: the current reference app is still Fan Zone first, not game-night first. The July 2 product wants the first mobile game experience to answer: what live quiz or W-D-W pool can I join now, which TV/session am I paired with, what did I pick/answer, and what did I earn? Rayon should become the pilot club for that flow.

## 5. FanZone Architecture Review

FanZone has several architectural decisions AFRICLUB should borrow.

### 5.1 Surfaces

FanZone has clear runtime surfaces:

- Flutter mobile app in `lib/`.
- React/Vite admin console in `apps/admin/`.
- React/Vite venue portal in `apps/venue-portal/`.
- React/Vite public website/PWA in `apps/website/`.
- React/Vite TV display in `apps/tv-display/`.
- Shared TypeScript contracts in `packages/core/`.
- Supabase backend with migrations, Edge Functions, SQL tests, and release scripts.

This directly maps to the July 2 product brief better than current AFRICLUB. The most important missing AFRICLUB surface is TV display. The second missing surface is venue/host operations separate from club admin CRUD.

### 5.2 Backend Discipline

FanZone's best backend patterns:

- Sensitive writes go through RPCs or Edge Functions.
- Edge Functions have explicit auth models: user JWT, service-role/cron secret, or admin-only.
- Settlement is idempotent and audited.
- Realtime subscriptions are scoped, with a static scanner blocking whole-table channels.
- Product boundary scans block betting, odds, cash-out, wallet, transfer, paid-entry, and staking language from active runtime surfaces.
- SQL tests prove RLS, settlement, wallet/rewards, order lifecycle, public URL safety, and scheduler behavior.

AFRICLUB should borrow these exact classes of guardrails, even if implementation details differ.

### 5.3 FanZone Features To Borrow

Borrow:

- TV display app model and display-state source of truth.
- Scoped realtime scan.
- Product-boundary scan.
- Game Edge Function facade pattern for shared game actions.
- Cron/audit wrapper pattern for scheduled jobs.
- SQL contract tests for settlement, RLS, reward ledger, and content governance.
- Admin/venue/host operational separation.
- Release evidence folder discipline.
- Deep link and share payload model for pools/games.
- Explicit no mock data in production state.

Do not borrow blindly:

- Hospitality ordering as-is. AFRICLUB should adapt eligibility to club/event/partner/ticket/check-in contexts.
- Customer wallet language.
- Old FET staking concepts.
- React surface architecture if the repo wants Flutter Web long-term. Borrow the surface boundaries first, technology second.

## 6. Product Design Markdown Analysis

The two markdown files are directionally strong but not implementation-ready without normalization.

### 6.1 Strong Decisions To Preserve

- Entertainment-only posture: no cash purchase, cash-out, odds, financial return, or betting-market framing.
- TV + mobile + admin triad.
- Supabase Postgres, Realtime, RLS, Storage, and Edge Functions as backbone.
- AI drafts but humans publish.
- First-correct quiz: server receipt time, unique claim, idempotent answer submission.
- W-D-W only for MVP.
- Non-transferable social points, badges, streaks, venue champions, family modes, share cards.
- Manual fixture curation for Rwanda/local competitions.
- Strong auditability of answers, point awards, fixture results, admin overrides, and content approvals.

### 6.2 Weaknesses And Conflicts

1. The docs cite current market/research items from June 2026. Those claims were not verified in this repo pass. Treat them as strategic references, not implementation evidence, until independently source-checked.

2. The docs oscillate between v3 and v4. `Product desing 2.md` appears to deepen v3 with family/STEM/current-affairs additions. AFRICLUB needs one canonical product spec, not two near-duplicates.

3. The brief says "Flutter TV app" and "Flutter Web admin panel", while FanZone's working reference uses React/Vite for admin, venue portal, website, and TV display. AFRICLUB's current admin is Next.js. A rewrite to Flutter Web is not the shortest safe path. Recommendation: implement the game admin module inside current Next admin first, then decide whether a Flutter Web admin replacement is justified.

4. The data model in the docs is only a suggested table list. It needs tenant/club/venue/event scoping, RLS policy shape, function grants, indexes, realtime publication decisions, and contract tests before migration.

5. The docs say "no wallet wording", but current AFRICLUB product rules from June 29 still use partner-funded stake/payout mechanics and current code uses wallet/FET terminology. This must be reconciled before implementation.

6. AI pipeline scope is broad. OpenAI research, source collection, validation, localization, rights checks, duplicate checks, and difficulty calibration are several systems, not one feature. MVP should start with admin-assisted import/draft/review, not autonomous daily full pipeline.

## 7. Critical Gaps Against Target Product

### P0 Product Boundary Gaps

- Current active code still contains betting/odds terminology in market selector/settings areas.
- Wallet and token wording still appears in runtime and admin surfaces.
- Partner pool migration still models `partner_stake_fet`, `fan_entry_fet`, and payout/refund entries, which conflicts with the stricter July 2 no-financial framing.
- Product docs and implementation docs disagree on "wallet" vs "points balance".

### P0 Backend Gaps

- No game session schema for first-correct quiz.
- No `session_questions` / `answer_attempts` / `answer_claims` runtime with unique claim constraints.
- No TV display state table or safe payload view.
- No host console RPCs for start/open/skip/reveal/next.
- No content moderation queue for AI-generated questions.
- No SQL tests for answer leakage, claim race, duplicate answer, or host role scoping.

### P0 App Gaps

- No TV app/display.
- Mobile Fan Zone is prediction/wallet oriented, not live-session controller oriented.
- Admin PWA has football/gamification operations but not host console, quiz pack moderation, TV pairing, or game-session control.
- No venue/event/session pairing UX.

### P1 Operational Gaps

- No scoped realtime scanner in AFRICLUB.
- No product-boundary scanner in AFRICLUB.
- No game-night UAT script covering TV, mobile, admin, realtime, reconnect, and settlement.
- No content-quality feedback loop.

## 8. Target Architecture For AFRICLUB Game Platform

Recommended additive architecture:

```text
apps/
  rayon_sports/                 Existing reference Flutter club app
    web/                        Existing Next.js public site + admin PWA
  africlub_tv_display/          New TV/stage app, preferably Flutter Web first

packages/
  core/
    core_app
    core_router
    core_theme
    core_network
    core_feature_config
    core_game_runtime           New shared game client models/providers
  features/
    feat_gamification           Keep rewards and W-D-W, simplify language
    feat_game_sessions          New mobile controller screens
    feat_game_admin             Optional shared admin/domain package if needed
  clubs/
    club_rayon_sports

supabase/
  migrations/
  functions/
    game-session-action         Authenticated mobile/host game actions
    generate-question-drafts    Cron/admin AI draft generation
    publish-game-pack           Admin-only moderation publish
    settle-wdw-pools            Existing/renamed partner pool settlement
```

Use this split:

- Mobile app captures player intent and shows confirmed state.
- TV app renders screen-safe state only.
- Admin app controls sessions, packs, venues/events, fixtures, and moderation.
- Supabase owns all authoritative state, scoring, eligibility, locking, settlement, and audit.

## 9. App-By-App Implementation Plan

### 9.1 Rayon Sports Flutter Mobile App

Role: reference mobile controller and supporter app.

Plan:

1. Keep the three-tab shell: Home, Fan Zone, Settings.
2. Recompose Fan Zone around `Play`, `My Activity`, and `Points`.
3. Remove launch-visible odds/betting/market/slip/wallet/stake/payout language.
4. Add live session join flow:
   - enter code or scan/link from TV;
   - choose player name/avatar/team;
   - waiting room;
   - answer pad;
   - wrong-answer lockout;
   - claim/reveal;
   - leaderboard/results.
5. Add W-D-W pool flow:
   - curated fixture list;
   - pool detail;
   - choose Home/Draw/Away;
   - confirm;
   - locked/result;
   - pool leaderboard.
6. Add reconnect handling:
   - show connection banner;
   - never locally decide winners;
   - retry idempotent submission only where server idempotency key exists.
7. Add tests:
   - route contract tests;
   - first-correct controller widget tests;
   - large text tests;
   - no forbidden copy scan;
   - realtime reconnect and error state tests.

### 9.2 Other Club Flutter Apps

Role: thin white-label shells.

Plan:

1. Do not duplicate game code per club.
2. Ensure club feature flags can enable/disable game surfaces.
3. Keep club colors as accents only through `core_theme`.
4. Add per-club game availability through Supabase feature config, not hardcoded shell edits.
5. Run one smoke test per shell after shared modules stabilize.

### 9.3 Admin PWA In `apps/rayon_sports/web`

Role: near-term control room.

Plan:

1. Add game operations inside existing admin PWA before considering a Flutter Web admin rewrite.
2. Add modules:
   - Game sessions: create/schedule/start/pause/skip/reveal/close.
   - TV devices: pair/unpair/status/last seen/current screen.
   - Question moderation: AI drafts, source evidence, duplicate check, approval/rejection.
   - Pack builder: exactly 20 questions per round, category/difficulty balance.
   - Fixture/pool manager: W-D-W eligibility, lock, void, settle, audit.
   - Audit log: all admin actions and overrides.
3. Use same-origin/admin APIs and RPCs; do not write directly to sensitive tables from browser code.
4. Add admin tests for role scoping and mutation validation.

### 9.4 New TV Display App

Role: stage screen for venues, bars, families, and fan groups.

Plan:

1. Create `apps/africlub_tv_display/`.
2. Start with a Flutter Web app if the product requirement "Flutter TV app" remains firm; otherwise FanZone's React/Vite TV app is a proven reference.
3. Read only screen-safe state:
   - attract loop;
   - join screen;
   - lobby;
   - round intro;
   - question open without correct answer;
   - claimed/reveal;
   - leaderboard flash;
   - pool board;
   - end ceremony.
4. Pair by code/device token.
5. Subscribe only to scoped realtime channels by `screen_id`, `venue_id`, or `game_session_id`.
6. Add route-state checks for nonblank display states.

### 9.5 Public Website

Role: discovery and handoff, not authenticated fan gameplay.

Plan:

1. Keep public site as marketing/discovery.
2. Add public pages only for game-night explanation, venue/family event discovery, and app download/deep-link handoff.
3. Do not build a browser fan gameplay portal unless the product decision changes.
4. Ensure public pages use club/event scoped loaders and never leak admin/session state.

### 9.6 Supabase Backend

Role: authoritative game runtime.

Plan:

1. Add tables:
   - `venues` or `event_hosts` if venue-first is required for AFRICLUB;
   - `tv_devices`;
   - `game_templates`;
   - `question_sources`;
   - `question_drafts`;
   - `questions`;
   - `question_packs`;
   - `game_sessions`;
   - `session_players`;
   - `session_teams`;
   - `session_questions`;
   - `answer_attempts`;
   - `answer_claims`;
   - `points_ledger`;
   - `audit_log` or extend existing audit table.
2. Add constraints:
   - unique one attempt per player/question;
   - unique one winning claim per session question;
   - no correct answer readable before reveal;
   - one pool entry per player per pool;
   - no negative point balance;
   - idempotency keys for answer submission and settlement.
3. Add RPCs/Edge:
   - `submit_answer`;
   - `start_game_session`;
   - `open_session_question`;
   - `claim_first_correct`;
   - `reveal_question`;
   - `advance_question`;
   - `settle_wdw_pool`;
   - `approve_question_draft`;
   - `publish_question_pack`.
4. Add RLS:
   - players read their own attempts and public safe session state;
   - TV reads only screen-safe payloads;
   - hosts manage only assigned venue/event/session;
   - club admins manage only club-scoped resources;
   - service-role only for settlement and privileged scoring.
5. Add SQL tests:
   - answer leakage;
   - first-correct race;
   - duplicate answer rejection;
   - RLS isolation;
   - settlement idempotency;
   - void/refund behavior;
   - ineligible logical winner receives no points where eligibility applies.

### 9.7 AI Content Pipeline

Role: draft assistant, not autonomous publisher.

Plan:

1. Start with admin-triggered draft generation, not autonomous daily generation.
2. Store source URL/title/date/extracted fact/model/schema/prompt version.
3. Use strict JSON schema for question drafts.
4. Add validation pass:
   - correct answer uniqueness;
   - duplicate similarity;
   - family safety;
   - copyright/media rights;
   - prompt injection artifacts;
   - stale/current-affairs date check.
5. Require human approval before publish.
6. Track performance after games: answer speed, correctness, disputes, skips.

## 10. Borrow List From FanZone

High-confidence borrow:

- `apps/tv-display` surface boundary and display-state model.
- `docs/architecture/apps.md` style surface ownership docs.
- `docs/architecture/backend.md` migration/function inventory discipline.
- `supabase/functions/_shared/game_edge.ts` action facade pattern.
- `supabase/functions/_shared/cron_audit.ts` scheduled job audit pattern.
- `supabase/functions/generate-weekly-game-packs` review-gated content generation concept, adapted from Gemini to OpenAI if AFRICLUB standardizes on OpenAI.
- `supabase/functions/settle-match-pools` idempotent settlement wrapper pattern.
- `tool/product_boundary_scan.sh` concept.
- `tool/scoped_realtime_scan.mjs` concept.
- SQL tests for RLS, pool settlement, reward ledger, game content governance, and realtime/read payload safety.
- Venue/host operations separation.

Medium-confidence borrow:

- Venue portal if AFRICLUB truly sells to bars/venues. If the first pilot is a club-owned matchday/family event, start with admin host console instead.
- Public share payload and social-card contract. Beware AFRICLUB's image-generation restriction in `RULES.md`; use payload first, image generation only with owner approval.
- App release evidence matrix and UAT report structure.

Do not borrow:

- Payment/order domain unless venue hospitality becomes a real AFRICLUB requirement.
- Any remaining wallet/stake copy.
- Any customer transfer concept.
- Any code that relies on a different tenant model without club/event adaptation.

## 11. Priority Roadmap

### Phase 0: Governance And Product Contract Lock

Duration: 1-2 days.

Deliverables:

- Clean `RULES.md` corruption and resolve bottom-nav wording conflict.
- Create one canonical game product spec from the two Downloads markdown files.
- Decide public vocabulary: recommended `points`, `fan points`, or `IK points`; avoid `wallet`, `token`, `stake`, `payout`, `odds`, `bet`, `market`.
- Add AFRICLUB product-boundary scan.
- Add scope decision: venue-first, club-event-first, or hybrid.

Exit gate:

- Repo docs and active code agree on product vocabulary and launch boundaries.

### Phase 1: Fan Zone Safety And Recomposition

Duration: 3-5 days.

Deliverables:

- Remove launch-visible betting/odds/market/slip/wallet/stake/payout copy.
- Recompose Fan Zone into play-first sections.
- Hide empty hub sections; keep empty states only on task-specific list screens.
- Disable/quarantine non-launch routes behind feature flags.
- Add focused widget tests and copy scan.

Exit gate:

- Rayon Fan Zone first viewport is entertainment/game-play oriented and passes forbidden-copy scan.

### Phase 2: Backend Game Runtime Foundation

Duration: 1-2 weeks.

Deliverables:

- Add additive game/session/question schema.
- Add first-correct answer RPC/Edge contract.
- Add TV display safe read model.
- Add host/admin session-control RPCs.
- Add RLS and SQL contract tests.

Exit gate:

- A local seeded game session can open a question, accept answers, award first correct, reveal, advance, and preserve audit rows.

### Phase 3: TV Display MVP

Duration: 1 week.

Deliverables:

- New TV app with attract, join, lobby, question, claim, reveal, leaderboard, end states.
- Pairing code.
- Scoped realtime only.
- Route-state smoke checks for all states.

Exit gate:

- Admin-controlled session changes appear on TV without exposing correct answers before reveal.

### Phase 4: Mobile Controller MVP

Duration: 1 week.

Deliverables:

- Join session.
- Team/player setup.
- Waiting room.
- Answer pad.
- Wrong-answer lockout.
- Claim/reveal.
- Result/leaderboard.
- Reconnect/error states.

Exit gate:

- 2+ players can complete a 20-question test round from mobile to TV under server authority.

### Phase 5: Admin Control Room And AI Moderation

Duration: 1-2 weeks.

Deliverables:

- Admin host console.
- Question draft queue.
- Human approval flow.
- Pack builder.
- Fixture/pool manager.
- Audit log.

Exit gate:

- Admin can create/review a pack, run a session, settle a W-D-W pool, and inspect audit evidence.

### Phase 6: Full Pilot Evidence

Duration: 3-5 days.

Deliverables:

- UAT script for one venue/family/club event.
- Mobile + TV + admin test evidence.
- SQL/RLS test outputs.
- Realtime scoped scan.
- Product-boundary scan.
- Performance/reconnect notes.

Exit gate:

- Real pilot can run without manual database intervention.

## 12. Concrete Files To Add Or Change Later

Likely AFRICLUB files:

- `RULES.md`
- `docs/africlub_game_product_spec.md`
- `tools/scripts/africlub_product_boundary_scan.sh`
- `tools/scripts/scoped_realtime_scan.mjs`
- `apps/africlub_tv_display/**`
- `apps/rayon_sports/web/src/app/admin/games/**`
- `apps/rayon_sports/web/src/lib/data/admin/games.ts`
- `packages/features/feat_gamification/**`
- `packages/features/feat_game_sessions/**`
- `packages/core/core_game_runtime/**`
- `supabase/migrations/<timestamp>_game_runtime_foundation.sql`
- `supabase/functions/game-session-action/index.ts`
- `supabase/functions/generate-question-drafts/index.ts`
- `supabase/tests/game_runtime_contract.sql`
- `supabase/tests/game_rls_contract.sql`

Touch only with owner approval or explicit implementation scope where files are protected by `RULES.md`.

## 13. Open Decisions

1. Is the pilot venue-first, club-matchday-first, family-event-first, or hybrid?
2. Should the TV app be Flutter Web because the product brief says Flutter, or React/Vite because FanZone has a working TV PWA pattern?
3. What is the public points vocabulary: `fan points`, `IK points`, `glory points`, or another term?
4. Does AFRICLUB retain FET internally as a database/accounting term while hiding it publicly?
5. Is W-D-W free entry only, or does "entry points" remain as non-transferable participation accounting? The July 2 brief strongly favors free entry and no stake.
6. Which AI source domains are approved for sports, science, history, current affairs, and local culture?
7. What is the first pilot acceptance target: one venue, one family event, one club watch party, or one internal demo?

## 14. Final Recommendation

Do not start by building more UI. Start by locking product boundaries and cleaning the current Fan Zone vocabulary/semantics. Then add a server-authoritative game runtime and TV display surface using FanZone's operational patterns. The winning implementation is not a larger prediction hub; it is a tight live entertainment loop:

Admin approves content and controls the session. TV creates the public drama. Mobile captures fast input. Supabase decides the truth. Points are social status only. Every sensitive action is scoped, audited, and testable.
