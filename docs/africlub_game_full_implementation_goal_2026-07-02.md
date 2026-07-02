# AFRICLUB Game Platform Full Implementation Goal

Date: 2026-07-02
Source report: `docs/africlub_game_architecture_review_and_plan_2026-07-02.md`

## Objective

Implement AFRICLUB as a no-financial-value, TV-led, mobile-controlled game platform while preserving the existing white-label club architecture.

The end state is not a larger prediction wallet. The end state is:

- TV/display is the stage.
- Mobile is the controller.
- Admin is the control room.
- Supabase is the authority.
- Points are social/reward status only.
- No active runtime surface uses betting, odds, stake, payout, cash-out, or fintech-wallet positioning.

## Non-Negotiable Product Contract

- No real-money betting.
- No cash purchase of points.
- No cash-out.
- No odds.
- No AI pick recommendations.
- No customer-to-customer public value transfer.
- No correct-answer leakage to TV or mobile before reveal/claim.
- Every sensitive mutation is server-authoritative, scoped, idempotent where retried, and audited.

## Implementation Phases

### Phase 0: Governance And Guardrails

Deliverables:

- One canonical implementation goal.
- Product-boundary scan for active runtime copy.
- Scoped realtime scan for Flutter/Web source.
- Validation script that ties the goal, report, migration, and guardrails together.

Acceptance:

- Scripts run from repo root.
- Guardrail scans can run in report mode today and fail-on-findings mode for release gates.
- The goal clearly names protected surfaces and required approval boundaries.

### Phase 1: Supabase Game Runtime Foundation

Deliverables:

- Additive game runtime schema.
- TV-safe session-state view/RPC.
- First-correct answer submission RPC.
- Host/admin session-control RPCs.
- Question draft/moderation tables.
- RLS and grants aligned to current club tenancy helpers.
- SQL contract test file documenting required invariants.

Acceptance:

- Migration contains session, player, team, question, attempt, claim, points, TV device, and audit objects.
- RPCs enforce one attempt per player/question and one winning claim per question.
- TV-safe payload excludes correct answers before reveal.

### Phase 2: App Surfaces

Deliverables:

- TV/display surface.
- Mobile controller flow.
- Admin control room modules.

Acceptance:

- A seeded session can be controlled from admin, displayed on TV, and answered from mobile.
- No new Flutter flavor is added without explicit owner approval.

### Phase 3: AI Content Pipeline

Deliverables:

- Admin-triggered draft generation.
- Source/provenance storage.
- Human moderation workflow.
- Pack builder with exactly 20 approved questions per round.

Acceptance:

- AI never publishes directly.
- Drafts store source, model, schema, validation, and reviewer state.

### Phase 4: Full Pilot Evidence

Deliverables:

- UAT script for one pilot.
- SQL/RLS proof.
- Runtime guardrail proof.
- Mobile, TV, admin validation evidence.
- Known gaps register.

Acceptance:

- A real pilot round can run without manual database edits.

## Current Implementation Slice

This slice intentionally avoids protected Flutter UI/package churn and focuses on the foundation:

- Add goal and guardrail scripts.
- Add additive Supabase runtime foundation.
- Add SQL contract tests.
- Add validation script.

Files intentionally not touched in this slice:

- `packages/features/feat_home/**`
- `packages/core/core_theme/**`
- root `pubspec.yaml`
- `melos.yaml`
- `.github/workflows/**`
- per-club Flutter flavor declarations

## Completion Definition

The full goal is complete only when all phases are implemented and the final report includes:

- files changed;
- commands run;
- test outputs;
- unresolved blockers;
- remaining manual approvals;
- release/UAT evidence path.
