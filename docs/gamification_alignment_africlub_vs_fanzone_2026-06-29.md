# AFRICLUB Gamification Alignment Report vs FANZONE

Date: 2026-06-29
Scope: `/Volumes/PRO-G40/AFRICLUB` current working tree compared with `/Volumes/PRO-G40/FANZONE` current implementation.
Objective: critically assess AFRICLUB gamification and define an implementation plan to align it with FANZONE's gamification model.

Revisit note: this revision explicitly considers the full AFRICLUB repo surface, including current working-tree content rather than only the `feat_gamification` package. At revisit time, `git status --short`, `git diff --name-only`, and the untracked-file scan returned no visible pending files, but the analysis intentionally treats modified-file scope as in-bounds and includes web admin, docs, services, Supabase functions, migrations, feature configuration, and tests discovered by repo-wide search.

## Executive Summary

AFRICLUB has a substantial gamification implementation, not a superficial stub. The current `feat_gamification` package includes a consolidated Fan Zone module, FET wallet, prediction markets, rewards, leaderboards, badges, streaks, friends, share cards, challenge creation/joining, and Supabase-backed RPC boundaries. It is broader than FANZONE in visible route count and has useful Flutter/Riverpod structure.

The honest gap is that AFRICLUB is not yet aligned to FANZONE's product contract. FANZONE treats gamification as venue-linked entertainment: free-to-play challenges, venue/order eligibility, closed-loop FET rewards, audited settlement, and separate play surfaces for pools and games. AFRICLUB currently treats gamification more like a club-wide prediction and points hub, with direct wallet transfers, manual redemption, broad prediction-market language, fallback reward catalog content, and no equivalent venue/order eligibility loop. The repo-wide revisit makes this gap more serious: AFRICLUB's prediction-engine service explicitly models overround, house edge, wagers, payouts, and house profit. That is incompatible with simply re-skinning the current implementation to look like FANZONE.

Recommended direction: align AFRICLUB to FANZONE's model by turning Fan Zone into a focused club play and rewards loop: curated match challenges, club/venue/event-linked eligibility, closed-loop FET ledger, catalog-only reward redemptions, matchday games, auditable settlement, and end-to-end tests that prove FET movement from challenge entry through settlement and wallet history. The first implementation priority should be product-contract cleanup across service logic, admin copy, docs, and wallet behavior, not more gamification feature expansion.

## Evidence Base

AFRICLUB evidence reviewed:

- `RULES.md` lines 96-152: gamification teaser and leaderboard visibility rules, plus no hardcoded user-visible challenge/FET/badge content.
- `packages/features/feat_gamification/lib/src/fanzone_module.dart` lines 32-217: consolidated Fan Zone route surface.
- `packages/features/feat_gamification/lib/src/providers/fanzone_hub_provider.dart` lines 14-161: Riverpod hub aggregation over predictions, wallet, fixtures, leaderboard, markets, and challenges.
- `packages/features/feat_gamification/lib/src/screens/fanzone_hub_screen.dart` lines 24-469: hub UI and route actions.
- `packages/features/feat_gamification/lib/src/repositories/fet_repository.dart` lines 18-646: catalog, wallet, transfer, redemption, supporter search, reward redemption.
- `packages/features/feat_gamification/assets/reward_store_catalog.json` lines 1-40: fallback reward catalog.
- `packages/features/feat_gamification/lib/src/repositories/challenge_repository.dart` lines 16-180: challenge RPC client.
- `packages/features/feat_gamification/lib/src/models/challenge_models.dart` lines 73-356: challenge entries, settlement, permissions, payouts.
- `supabase/migrations/20260416120000_create_prediction_challenges.sql` and `20260417123000_prediction_challenge_runtime_hardening.sql`: challenge wallet debit/credit, settlement, lock, and service-role flows.
- `supabase/functions/football-sync/auto-settle.ts` lines 25-157: automatic prediction and challenge settlement hook.
- `services/prediction-engine/multiplier_engine.py` lines 1-125 and `services/prediction-engine/run_pipeline.py` lines 193-241: multiplier, overround, wager, payout, and house-profit economy logic.
- `docs/fet_wallet_qa_uat_2026-04-12.md` lines 5-10, 81-90, and 132-137: transfer, redemption, and admin adjustment are documented as active wallet scope.
- `docs/OFFLINE_STRATEGY.md` lines 70-86: predictions, transfers, and redemptions are documented write behaviors.
- `apps/rayon_sports/web/src/app/admin/predictions/page.tsx` lines 32-36 and 140-195: admin prediction markets, bet-type helper copy, and market rows.
- `apps/rayon_sports/web/src/app/admin/gamification/wallet/page.tsx` lines 265-287 and 357-488: admin wallet operations, lifetime spent semantics, transfer/redemption ledger framing, and manual adjustments.
- `packages/features/feat_gamification/test/*`: widget and model tests for hub, wallet, challenge, social, badges, streak, share card, and token history.

FANZONE evidence reviewed:

- `PRODUCT_RULES.md` lines 1-90: venue-linked product rules, non-betting positioning, FET ledger constraints, pool/game eligibility, and discovery model.
- `FET_LEDGER.md` lines 1-44: wallet RPC and database constraints.
- `lib/app_router.dart` lines 260-424: wallet, pool, game, shell route topology.
- `lib/features/wallet/data/wallet_gateway.dart` lines 130-179: wallet balance RPC and disabled customer-to-customer transfer.
- `lib/features/wallet/screens/wallet_screen.dart` lines 21-276: rewards ledger UX framing.
- `lib/features/pools/data/pools_repository.dart` lines 9-247 and 396-513: pool model, venue fields, entry state, stake RPC, create pool, invite, social card.
- `lib/features/pools/screens/pools_screen.dart` lines 21-239: Play hub combining pools and games.
- `lib/features/games/data/games_repository.dart` lines 11-239 and 348-581: venue-linked game sessions, teams, answers, bingo, eligibility.
- `supabase/migrations/20260508154000_pool_eligibility_and_game_content_guardrails.sql` lines 1-133: pool eligibility curation and game guardrails.
- `supabase/migrations/20260504133000_game_user_flow_and_settlement.sql` lines 187-320: game settlement with venue staff role check and eligibility.
- `supabase/tests/fet_wallet_reward_engine.sql` lines 55-151 and `supabase/tests/pool_settlement_engine.sql` lines 138-228: SQL-level wallet and settlement proof.
- `integration_test/app_smoke_test.dart` lines 338-580: end-to-end pool join, order, wallet, and game-listing smoke coverage.

## Comparative Assessment

### 1. Product Contract

FANZONE is explicit: it is not betting, gambling, cash-out, odds, pooled-wager, or fintech wallet. Its engagement mechanics are venue-linked, free-to-play, loyalty-points based, leaderboard based, coupon based, or reward based (`PRODUCT_RULES.md:7-10`). FET is a non-cash loyalty ledger, not e-money or a customer fintech wallet (`PRODUCT_RULES.md:28-39`).

AFRICLUB has partial alignment because it uses FET and club-scoped wallet RPCs, but the user-facing structure still feels closer to a sports prediction product. The hub exposes "Markets", "My Picks", "Jackpot", "Challenge a friend", "Wallet", "Rewards store", and "Token history" in one place. The challenge module comment itself describes "stake-based prediction pools" (`challenge_module.dart:9`). That is a compliance and positioning risk if AFRICLUB is intended to inherit FANZONE's safer product stance.

The deeper issue is that the repo contains service-level betting-economy logic, not only risky labels. `services/prediction-engine/multiplier_engine.py` converts probabilities into multipliers using "overround", "house edge", "vig", "juice", and "user betting 100 FET" examples (`multiplier_engine.py:24-53`). It also adjusts multipliers based on user volume to protect against one-sided liability and explicitly compares this to bookmakers moving the line (`multiplier_engine.py:101-125`). `run_pipeline.py` simulates "1000 wagers", amount per wager, payout, house profit, and house margin (`run_pipeline.py:193-241`). FANZONE's model cannot absorb this as-is.

Recommendation: change AFRICLUB's public vocabulary and service semantics from markets/stakes/tokens/multipliers/house edge to FANZONE-style "challenges", "points entry", "rewards ledger", "reserved FET", "earned FET", "club rewards", and "matchday rooms". Keep legacy database names only where migration cost is high, but do not expose them in UI copy. Retire or quarantine the multiplier/liability service unless legal/product explicitly approves a regulated prediction-economy path.

### 2. Feature Topology

FANZONE's main engagement surface is focused: `/pools` is the Play hub, with games nested under `/pools/games`, wallet at `/wallet`, and pool detail/join/create routes outside the shell (`app_router.dart:288-424`). This gives users a clear loop: discover play activity, join, track rewards, return to wallet.

AFRICLUB's `FanzoneModule` is an omnibus route surface with 25+ child routes under `/fanzone`: fixtures, live, my predictions, match detail, wallet, offers, rewards, history, leaderboard, notifications, challenges, badges, streak, jackpot, share, friends, friend challenge, league, standings, team profile, club zone, fan id, social, privacy (`fanzone_module.dart:62-217`). This creates breadth but weakens the primary gamification loop.

Recommendation: keep `/fanzone` as the club-facing tab if desired, but reorganize inside it around FANZONE's hierarchy:

- Play: curated club match challenges and matchday games.
- Rewards: FET ledger, earned/reserved/pending/spent, catalog redemption.
- Profile: fan ID, badges, privacy, sharing.
- Secondary discovery: fixtures, league, social, and team profile should support Play, not compete with it.

### 3. Wallet And FET Ledger

FANZONE's wallet is a rewards ledger. The gateway reads balance through `get_wallet_balance`, filters user-visible transactions, and explicitly disables customer-to-customer FET movement with a closed-loop message (`wallet_gateway.dart:130-179`). The wallet screen reinforces this by saying FET is for venue rewards, games, and coupons (`wallet_screen.dart:240-276`).

AFRICLUB's wallet repository still supports direct supporter search, `fet_transfer`, and `fet_redeem` (`fet_repository.dart:520-646`). The wallet screen tests assert transfers to searched supporters and manual redemptions (`fet_wallet_screen_test.dart:173-232`). This conflicts with FANZONE's current stance unless explicitly feature-gated for AFRICLUB with non-cash constraints.

This is not incidental or dead surface. The wallet QA/UAT document lists supporter transfer flow, supporter redemption flow, and admin wallet adjustment as active scope (`docs/fet_wallet_qa_uat_2026-04-12.md:5-10`). Manual UAT steps require Supporter Alpha transferring FET to Supporter Beta and redeeming FET (`docs/fet_wallet_qa_uat_2026-04-12.md:81-90`), and pass criteria require transfer and redeem flows to remain idempotent (`docs/fet_wallet_qa_uat_2026-04-12.md:132-137`). The offline strategy also treats transfer and redemption as documented write actions (`docs/OFFLINE_STRATEGY.md:70-86`). The admin wallet page reinforces this by defining lifetime spent as transfers, redemptions, and deductions, and by presenting ledger history as transfers, redemption requests, earnings, and manual adjustments (`apps/rayon_sports/web/src/app/admin/gamification/wallet/page.tsx:265-287`, `487-488`).

Recommendation: deprecate public customer-to-customer transfer and manual amount redemption for launch alignment. Replace them with:

- View-only rewards ledger with `available`, `reserved`, `pending`, `spent`, and `earned` buckets.
- Catalog-based reward redemption only, using server-defined items.
- Admin/supporter adjustments only through admin tools with audit rows.
- Optional future transfer-like behavior only behind explicit feature flag, public Fan ID recipient, and legal/product approval.

### 4. Challenges, Pools, And Settlement

FANZONE separates the challenge/pool domain from wallet internals. Pool summaries carry venue, country, share, entry, stake bounds, camps, and social-card data (`pools_repository.dart:9-247`). Joining calls `stake_fet`; creating calls `create_pool`; share cards and invites are part of the loop (`pools_repository.dart:396-513`). Backend tests prove debits, settlement payouts, refunds, idempotency, and no duplicate credits (`pool_settlement_engine.sql:138-228`).

AFRICLUB has a real challenge engine with `prediction_challenge_create`, `join`, `cancel`, `settle`, lock-due, settle-due, idempotency-style references, and wallet ledger entries. This is a strong base. However, it is exact-score prediction challenge oriented, with `stake_fet`, `total_pool_fet`, `payout_per_winner_fet`, and no equivalent reviewed venue/order eligibility contract in the product model. The strongest FANZONE concept, "logical winners can be ineligible for FET if no qualifying linked venue order exists", is missing from the AFRICLUB challenge model.

Recommendation: keep AFRICLUB's challenge engine but align the domain:

- Add `engagement_context_id` or explicit `club_event_id` / `venue_id` / `matchday_context_id` to challenges.
- Add eligibility status per entry: eligible, ineligible_no_qualifying_activity, pending_review.
- Add settlement metadata for ineligible logical winners.
- Add service-role settlement tests proving no duplicate payouts, no negative balances, refunds on void/cancel/postponed, and ineligible winner visibility with zero payout.
- Reword exact-score challenges as "club challenge rooms" or "matchday prediction challenge", not betting-like markets.

### 5. Games

FANZONE includes a separate games domain: game sessions, teams, questions, bingo cards, edge functions, realtime detail, and eligibility (`games_repository.dart:11-239`, `348-581`). Product rules require centralized templates, approved questions, one venue per session, two teams before competitive settlement, exactly 20 selected approved questions, and backend race protection (`PRODUCT_RULES.md:57-77`).

AFRICLUB does not have an equivalent games module in the reviewed `feat_gamification` package. It has challenges, jackpot, badges, streaks, and social surfaces, but not FANZONE-style matchday games with teams and approved question packs.

Recommendation: add an AFRICLUB matchday games lane after wallet/challenge alignment, not before. Start with one club-safe game type:

- Club Trivia / Matchday Trivia.
- Server-selected approved question pack.
- Team join/create.
- Club/event linked reward settlement.
- No speed bonus and no cross-club competition at launch.

### 6. Venue, Order, And Eligibility Model

This is the biggest architectural gap.

FANZONE's gamification is anchored in venues and orders. Users may join before ordering, but FET settlement requires a qualifying paid order from the linked venue within two hours of the scheduled game/challenge start (`PRODUCT_RULES.md:78-85`). The games repository checks `user_has_qualifying_order` with `venue_id` and scheduled start (`games_repository.dart:566-580`). Game settlement uses venue staff role checks and separates eligible vs ineligible winners (`game_user_flow_and_settlement.sql:187-320`).

AFRICLUB is club-scoped through `ClubScopeResolver` and `club_id`, but there is no comparable eligibility gate in the gamification product loop. For a football-club app, the matching concept may not always be "venue order"; it could be ticket purchase, membership, matchday check-in, approved contribution, partner voucher, or stadium/club-store purchase. The point is not to copy "venue" blindly; it is to copy the eligibility architecture.

Recommendation: define an AFRICLUB "qualifying engagement event" contract:

- `ticket_paid`, `membership_active`, `matchday_checkin`, `club_store_paid`, `partner_offer_verified`, `contribution_verified`.
- Each challenge/game has a linked context and eligible event window.
- Settlement records logical winners separately from FET-credit-eligible winners.
- The UI shows eligibility plainly without blocking joining.

### 7. Content And Fallbacks

AFRICLUB's rules prohibit hardcoded visible challenge names, FET values, and badge names (`RULES.md:138-152`). The gamification repository nevertheless falls back to a bundled reward JSON when reward rows are empty or Supabase fails (`reward_store_content.dart:63-105`), and that JSON contains visible reward options such as Mobile Airtime, FANZONE Premium Badge, Jackpot Extra Entry, Partner Voucher (`reward_store_catalog.json:1-40`).

This is not launch-safe under AFRICLUB's own rules. FANZONE can use UAT fixtures in tests, but production guardrails explicitly disable UAT game sessions and require pool eligibility curation (`pool_eligibility_and_game_content_guardrails.sql:1-54`).

Recommendation: remove production-visible fallback reward catalog content from AFRICLUB. In production, if no Supabase catalog exists, hide the section. In tests, inject fixture data through providers. In local dev, load clearly dev-only seed content only when a dev flag is enabled.

### 8. UX Quality

AFRICLUB's current hub has several good UX qualities:

- Riverpod `AsyncNotifier` snapshot avoids fragile `setState` orchestration.
- Partial failures are degraded rather than fully blank.
- Quick routes make the wide surface discoverable.
- The hub hides live/today/upcoming fixture sections when empty in some places.

But it also violates the spirit of the repo's empty-state mandate. `Markets`, `Leaderboard`, and `Challenges` render unavailable cards inside visible sections when data is absent (`fanzone_hub_screen.dart:281-383`). The repo rules say empty gamification and leaderboard surfaces should hide rather than render empty cards (`RULES.md:96-136`).

FANZONE, by contrast, uses explicit empty states in its Play hub when the user is actively filtering a list (`pools_screen.dart:150-189`). That is different from rendering disabled cards on the default hub.

Recommendation: keep empty states only on destination/list screens where the user's task requires feedback. On the hub, hide empty sections and keep the first screen focused on actionable items.

### 9. Admin And Operations

FANZONE's backend has operational curation and settlement controls: curated matches have `is_pool_eligible`; admin curation writes audit rows; game settlement checks venue roles; SQL tests cover wallet and settlement invariants.

AFRICLUB has admin-facing gamification pages in the web app and feature management, but the reviewed mobile gamification path does not yet show the same production-readiness evidence around curated eligibility, review-safe disablement, SQL-level settlement tests, and launch-safe content gates.

Recommendation: align admin operations before expanding user-facing features:

- Add "eligible for challenge" curation flags for club fixtures/events.
- Add admin settlement retry and audit history UI for challenge/game outcomes.
- Add feature flags for transfer, rewards redemption, game creation, and jackpot.
- Add visible audit reasons for manual FET adjustments.

### 10. Services, Admin Copy, And Documentation Drift

The first report pass focused on the mobile gamification package and Supabase challenge runtime. The broader repo pass shows that AFRICLUB's gamification concept is also encoded in services, admin web, and documentation. That matters because changing only Flutter labels would leave the operating model inconsistent.

Specific drift:

- Prediction-engine code models an odds-like economy with house edge, wagers, payouts, and liability management (`services/prediction-engine/multiplier_engine.py:24-125`, `services/prediction-engine/run_pipeline.py:193-241`).
- Admin Predictions uses "Markets" as the primary tab and "Bet types" as helper copy (`apps/rayon_sports/web/src/app/admin/predictions/page.tsx:32-36`, `140-195`).
- Wallet UAT and offline docs preserve transfer/redemption as planned supporter behavior, while FANZONE disables customer-to-customer movement.
- Admin wallet operations are necessary, but the public-facing mental model should be "audited rewards ledger", not general wallet movement.

Recommendation: treat alignment as a cross-repo product migration. Update service code, admin pages, documentation, tests, and migrations together. A UI-only alignment would be misleading and would leave the highest-risk behavior intact.

## Priority Alignment Plan

### Phase 0: Freeze And Decide Product Contract

Duration: 1-2 days.

1. Declare the AFRICLUB gamification contract in `docs/` and/or `RULES.md`.
2. Decide whether AFRICLUB should retain any customer-to-customer transfer behavior. Default recommendation: no for launch.
3. Decide the AFRICLUB equivalent of FANZONE venue/order eligibility. Recommended: `qualifying_engagement_event`.
4. Define public vocabulary: rewards ledger, points entry, challenge room, matchday game, club reward, eligibility.
5. Freeze all betting-economy language and logic from the launch path: overround, house edge, vig, juice, wagers, payouts, house profit, bet types, and bookmaker-style liability movement.
6. Decide whether `services/prediction-engine` is retained only as a private probability/ranking aid, rewritten as a challenge difficulty/reward estimator, or removed from the gamification launch path.

Deliverables:

- `docs/africlub_gamification_product_rules.md`.
- Product copy glossary.
- Explicit feature-flag matrix.
- Service/code quarantine list for non-FANZONE-aligned mechanics.

### Phase 1: Wallet And Ledger Alignment

Duration: 3-5 days.

1. Refactor wallet read model to mirror FANZONE buckets: available, reserved/staked, pending, spent, earned.
2. Hide or remove customer transfer and manual amount redemption from supporter UI.
3. Update docs and tests that currently treat transfer/redeem as active supporter launch scope.
4. Keep catalog reward redemption, but make it Supabase-only for production.
5. Remove production fallback reward catalog rendering.
6. Add SQL tests for no negative balances, duplicate idempotency, ledger row required for every mutation, and anonymous/auth constraints.

Acceptance criteria:

- No public UI path can mutate FET outside approved RPCs.
- A failed catalog load hides the reward section on hub and shows bounded feedback only on the rewards destination screen.
- Wallet history clearly distinguishes earn, reserve, spend, refund, reward credit, and reward debit.

### Phase 2: Challenge/Pool Alignment

Duration: 1-2 weeks.

1. Add challenge context fields: club/event/venue/partner/ticket context as appropriate.
2. Add eligibility model and settlement metadata.
3. Rework UI copy away from markets/stakes/payout language.
4. Rework admin prediction pages away from "Markets" and "Bet types" toward challenge templates, reward rules, and fixture/event eligibility.
5. Add challenge cards patterned after FANZONE pools: context, status, entry cost, reward estimate, join state, share state.
6. Add admin curation gate for challenge-eligible fixtures.
7. Add service-role settlement tests mirroring FANZONE's pool settlement tests.

Acceptance criteria:

- Users can join a challenge before eligibility is satisfied.
- Logical winner without qualifying event remains visible but receives zero FET.
- Settlement is idempotent and audited.
- Cancelled/postponed/void/no-winner scenarios refund correctly.

### Phase 3: Play Hub Recomposition

Duration: 3-5 days after Phase 2 backend is stable.

1. Recompose `/fanzone` around Play, Rewards, and Profile sections.
2. Promote active challenges and games over generic fixtures/markets.
3. Keep fixture and league discovery secondary.
4. Hide empty hub sections.
5. Build FANZONE-style filters: Live, Soon, Top Rewards, My Entries.

Acceptance criteria:

- First viewport answers: what can I play now, what have I joined, what rewards are at stake?
- Wallet is visibly a rewards ledger, not a fintech wallet.
- Empty data does not make the hub look unfinished.

### Phase 4: Games Lane

Duration: 1-2 weeks.

1. Add matchday game templates and approved question packs.
2. Add game sessions linked to club event or venue context.
3. Add teams and membership.
4. Add backend race protection for answer scoring.
5. Add settlement with eligibility and audit metadata.
6. Add mobile UI for games list and game detail.

Acceptance criteria:

- At least one end-to-end club trivia flow works from list to team join to answer to settlement.
- Questions are selected server-side from approved content.
- Settlement cannot credit ineligible winners.

### Phase 5: End-to-End Evidence

Duration: 3-5 days.

1. Add SQL tests equivalent to FANZONE `fet_wallet_reward_engine.sql` and `pool_settlement_engine.sql`.
2. Add Flutter integration smoke: open Play, join challenge, wallet reserved/available changes, qualifying event, settlement, wallet history.
3. Add widget/snapshot tests for hub, wallet, challenge cards, empty states, eligibility banners.
4. Add feature-flag tests proving launch-disabled surfaces stay hidden.

Acceptance criteria:

- AFRICLUB has the same class of evidence FANZONE has: backend invariants plus app-level user journey.
- Reported proof includes commands, test outputs, and known remaining gaps.

## Recommended Implementation Order

1. Stop expanding current hub routes until the product contract is settled.
2. Quarantine or rewrite prediction-engine multiplier/liability logic before it informs launch UX or backend rewards.
3. Remove launch-risk wallet actions from UI and docs: transfer, manual FET redemption, and any cash-adjacent reward copy.
4. Replace production fallback reward content with database-only production content.
5. Add eligibility fields and settlement metadata to challenge runtime.
6. Recompose `/fanzone` into a Play-first hub.
7. Add FANZONE-style SQL settlement tests.
8. Add matchday games only after the wallet/challenge ledger loop is stable.

## Critical Risks If AFRICLUB Ships As-Is

1. Compliance/product risk: service code and UI/admin copy already contain overround, house edge, wagers, payouts, markets, bet types, jackpot, transfers, and manual redemption. This can make the feature feel like betting or wallet behavior rather than closed-loop loyalty.
2. Ledger trust risk: visible transfers/redemptions expand the financial-like surface before FANZONE-style constraints and tests are proven.
3. Launch-quality risk: hardcoded fallback rewards conflict with AFRICLUB's own no-hardcoded-content rule.
4. UX dilution risk: the hub offers too many destinations before the primary play/reward loop is clear.
5. Evidence gap: widget tests exist, but FANZONE's full-stack wallet/order/pool/game smoke evidence is stronger.

## Bottom Line

AFRICLUB's current gamification work is useful and technically meaningful, but it should be treated as a broad prototype that needs FANZONE discipline before launch. The most important alignment is not visual polish. It is the operating model: closed-loop FET rewards, no public cash-like wallet behavior, curated challenge eligibility, context-linked settlement, visible but unpaid ineligible winners, and end-to-end proof that every FET movement is audited and idempotent.

If the goal is to align with FANZONE, the next implementation should not add more gamification surfaces. It should narrow the surface, harden the ledger, align copy and eligibility, and prove the Play -> Join -> Qualify -> Settle -> Wallet History loop.
