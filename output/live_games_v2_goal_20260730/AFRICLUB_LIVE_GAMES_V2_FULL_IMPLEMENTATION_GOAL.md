# AFRICLUB Live Games V2 Full Implementation Goal

**Goal ID:** `africlub_live_games_v2_full_implementation_20260730`
**Created:** 2026-07-30
**Initial status:** Red — all 27 implementation tasks and all protected/external gates are open
**Workspace:** `/Volumes/PRO-G40/AFRICLUB`
**Implementation plan:** `/Users/jeanbosco/Documents/Codex/2026-05-15/Codex Professional Agents/desktop-output/flutter/africlub_game_architecture_review_20260730/AFRICLUB_LIVE_GAMES_IMPLEMENTATION_PLAN_2026-07-30.md`
**Architecture and UX review:** `/Users/jeanbosco/Documents/Codex/2026-05-15/Codex Professional Agents/desktop-output/flutter/africlub_game_architecture_review_20260730/AFRICLUB_GAME_ARCHITECTURE_AND_UX_REVIEW_2026-07-30.md`
**Design authority:** `/Volumes/PRO-G40/AFRICLUB/DESIGN.md`

## Goal

Fully implement, test, validate, evidence, and release-harden the complete
AFRICLUB Live Games V2 plan across the shared Supabase backend, participant
Flutter mobile experience, owner and organizer mobile operations, native
Flutter TV runtime, admin PWA, AI question workflow, security, privacy,
accessibility, performance, observability, migration, physical-device
validation, and controlled rollout.

The end state must replace the participant-facing TV-code architecture with:

1. code-free eligible-game discovery for participants;
2. owner-claimed TV pairing and owner-scoped TV management in mobile;
3. role-gated organizer scheduling, assignment, activation, start, pause,
   reveal, advance, completion, and exception handling in mobile;
4. full native-TV live trivia projection;
5. one server-authoritative, versioned lifecycle shared by mobile, TV, and
   admin;
6. Realtime invalidation plus authoritative snapshot reconciliation;
7. human-reviewed, evidence-backed AI question publication;
8. cross-club, owner, venue, organizer, participant, and TV credential
   isolation proven by current tests;
9. current exact-build, authenticated, multi-client, accessibility,
   performance, privacy, physical-device, signing, and release evidence.

The goal is not complete when plans, code, migrations, tests, local previews,
simulators, or handoff packs merely exist. It is complete only when all 27
tasks meet their definitions of done, all quality gates pass, all protected
changes have accountable approval, and every applicable external/device/release
gate has current evidence.

## Relationship to existing AFRICLUB controls

This is a scoped execution goal for Live Games V2. It does not:

- replace `DESIGN.md`;
- erase, reduce, or reinterpret the existing 87-task AFRICLUB design and
  release goal;
- treat a Live Games V2 task as complete merely because a related historical
  task was previously closed;
- change the status of the wider programme without controlled reconciliation.

When implementation changes evidence relevant to the existing AFRICLUB goal,
the broader validation manifest and remaining-task register must be reconciled
in the same controlled change. Conflicts are resolved in favour of current
source, current evidence, `DESIGN.md`, and the stricter unresolved gate.

## Role

Act as the AFRICLUB Flutter/full-stack implementation lead inside Codex,
covering mobile, native TV, Next.js admin, Supabase/Postgres/Realtime/Edge
Functions, AI moderation, security, QA, evidence, and release readiness.

## Mission

Deliver the intended unified live trivia system from controlled baseline
through implementation and verified release readiness without narrowing the
scope, preserving the legacy participant-code product, inventing authority,
overwriting user work, or substituting local proxy evidence for required
external proof.

## Authority

### Authorized

- inspect the local workspace and current source;
- create and maintain local goal/evidence artifacts;
- implement directly on `main`; do not create or use a feature branch for this
  goal, per the owner's 2026-07-30 instruction;
- implement local source changes after the applicable protected approvals are
  recorded;
- run local analysis, tests, builds, simulators, emulators, and authorized
  staging validation;
- prepare migrations, release packs, runbooks, and handoffs.

### Not authorized without explicit recorded approval

- mutate production Supabase projects or production data;
- apply migrations to staging or production;
- change RLS, protected repository rules, shared runtime theme, dependencies,
  CI, signing, store listings, deployment configuration, or release channels;
- publish, deploy, submit, sign, certify, pay, contact third parties, or bind
  the product owner;
- discard, reset, clean, overwrite, or reinterpret pre-existing dirty-worktree
  changes.

## Inputs and sources of truth

1. Current AFRICLUB checkout and its live dirty state.
2. `RULES.md`.
3. `DESIGN.md`.
4. The implementation plan identified above, SHA-256
   `2094653cdc3968aee7f350eadb7d0dec8435abc2e96299bbfb5eb6818ce510d5`.
5. The architecture/UX review identified above, SHA-256
   `50d1d936bdb652b40e6bde2e475bb85fe0d50fbc4f8b4583e301dba7ef2f8d3a`.
6. Current backend migrations, Edge Functions, SQL tests, Flutter packages,
   native TV app, admin PWA, and current runtime evidence.
7. Current accountable owner decisions, approval records, device evidence,
   authenticated staging/production-equivalent evidence, signing systems, and
   store/deployment consoles when authorized.

## Scope

### Included

- governance and controlled baseline;
- architecture/rule alignment;
- additive TV ownership, pairing, display assignment, lifecycle, projection,
  audit, discovery, and Realtime backend work;
- participant code-free discovery and live synchronization;
- role-gated owner and organizer mobile operations;
- native TV modularization, owner-claim pairing, and full live projection;
- admin Content Studio, Session Planner, and Live Control;
- AI moderation evidence and safety controls;
- web TV compatibility correction and controlled sunset;
- SQL, Edge Function, Flutter, TV, web/admin, multi-client, accessibility,
  performance, privacy, security, device, build, release, and rollback proof.

### Excluded unless the goal is formally revised

- live video ingest, transcoding, HLS, RTMP, WebRTC, CDN, media rights, or video
  moderation;
- unrelated AFRICLUB product features;
- production deployment without explicit authorization;
- new external dependencies without explicit approval.

## Product decisions required before protected implementation

| ID | Decision | Recommended position | Initial status |
|---|---|---|---|
| DEC-01 | Can one game target multiple TVs? | Yes, through display assignments | pending_owner_approval |
| DEC-02 | What may a home TV show? | Club-wide eligible games plus explicit owner assignment | pending_owner_approval |
| DEC-03 | Can venue managers organize games? | Only with a separately granted organizer capability | pending_owner_approval |
| DEC-04 | What participant identity is public? | Governed alias only; no free-text display name | pending_owner_approval |
| DEC-05 | What does live streaming mean here? | Synchronized trivia state; video is separate | pending_owner_approval |
| DEC-06 | What is the legacy compatibility window? | Additive transition with measured sunset | pending_owner_approval |

## Protected approvals

| ID | Approval | Required before | Initial status |
|---|---|---|---|
| APR-01 | New Supabase migrations | LG-100 through LG-105 | pending |
| APR-02 | RLS policy changes | LG-100 through LG-105 | pending |
| APR-03 | `RULES.md` role-boundary update | LG-002 and mobile operations | pending |
| APR-04 | New Flutter feature package/pubspec entries | LG-300 | pending |
| APR-05 | Shared core localization changes | LG-202, LG-301, LG-302, LG-401, LG-402 | pending |
| APR-06 | CI workflow changes, if required | LG-604 or CI gate work | pending_if_needed |
| APR-07 | Staging migration execution | staging backend validation | pending |
| APR-08 | Production migration/deployment | production rollout | pending |
| APR-09 | Signing/store/release action | external release | pending |

## Controlled task mandate

The denominator is **27 tasks**. Task IDs are immutable.

| Tranche | Tasks | Count | Exit condition |
|---|---|---:|---|
| 0 — Governance and baseline | LG-000, LG-001, LG-002 | 3 | Controlled candidate, approved architecture/rules, and reconciled authority |
| 1 — Backend foundation | LG-100 to LG-105 | 6 | Ownership, pairing, assignments, lifecycle, projections, and Realtime pass security contracts |
| 2 — Shared/participant Flutter | LG-200 to LG-202 | 3 | Versioned models, automatic synchronization, and code-free discovery are verified |
| 3 — Owner/organizer mobile | LG-300 to LG-302 | 3 | Role-gated operations, My TVs, and Games I Manage are verified |
| 4 — Native TV | LG-400 to LG-402 | 3 | Modular native runtime, owner-claim pairing, and full live projection are verified |
| 5 — Admin and AI | LG-500 to LG-503 | 4 | Content Studio, Planner, Live Control, and compatibility sunset controls are verified |
| 6 — Validation and rollout | LG-600 to LG-604 | 5 | Security, UI, multi-client, device, staging, and release gates pass |
| **Total** |  | **27** | Every task is `verified_complete`; no required gate remains open |

The machine-readable task detail is in `task-register.json`.

## Ordered execution

1. Complete LG-000 and record the exact controlled candidate.
2. Resolve DEC-01 through DEC-06 and APR-01 through APR-05.
3. Complete LG-001 and LG-002 so source implementation follows one approved
   architecture and role boundary.
4. Implement LG-100 through LG-105 additively in local/staging-ready form.
5. Prove backend security contracts before exposing new client routes.
6. Implement LG-200 through LG-202.
7. Implement LG-300 through LG-302.
8. Implement LG-400 through LG-402.
9. Implement LG-500 through LG-503.
10. Execute LG-600 through LG-604 and the controlled rollout order.
11. Reconcile all manifests, registers, broader AFRICLUB evidence, and final
    release handoff.

Parallel work is allowed only where file ownership, dependencies, and evidence
boundaries are explicit. No parallel task may edit the same files without an
agreed integration owner.

## Per-task definition of done

A task becomes `verified_complete` only when all applicable conditions hold:

- intended behavior is implemented in authoritative source;
- no unrelated user change was lost or overwritten;
- protected approvals and product decisions are recorded;
- implementation conforms to `DESIGN.md` and `RULES.md`, or an approved
  exception is recorded;
- required unit, SQL, Edge Function, widget, golden, route, browser,
  integration, device, performance, accessibility, security, or release tests
  pass from the exact controlled candidate;
- analysis, formatting, builds, and dependency checks pass for affected
  surfaces;
- role, cross-club, privacy, payload, answer-leakage, stale-event,
  idempotency, reconnect, and rollback implications are addressed;
- required visual/interaction claims have current exact-build evidence;
- control records and task evidence are updated;
- required human, staging, physical-device, signing, store, production, or
  release gates are actually closed.

Preparation, a passing subset, a mocked service, a local browser, a simulator,
an emulator, a generated screenshot, or a handoff request is progress evidence
only when the acceptance criterion requires stronger proof.

## Quality gates

| Gate | Requirement | Initial status |
|---|---|---|
| G0 — Authority and baseline | Controlled candidate, file ownership, decisions and approvals | open |
| G1 — Architecture and scope | One approved lifecycle, role model, pairing direction, and sunset plan | open |
| G2 — Backend and RLS | Additive schema, RLS, credentials, audit, idempotency, projections | open |
| G3 — Participant mobile | Code-free discovery, synchronized play, governed alias, full states | open |
| G4 — Owner/organizer mobile | Scoped TV and game operations with route/role isolation | open |
| G5 — Native TV | Native package, full projection, pairing, D-pad, 720p/1080p, privacy | open |
| G6 — Admin and AI | Human review, planner, live control, auditability, accessibility | open |
| G7 — Cross-client correctness | Version/sequence consistency, reconnect, stale/duplicate handling | open |
| G8 — Security and privacy | Cross-club/role isolation, no answer leak, sanitized payload/evidence | open |
| G9 — Accessibility/performance | Mobile/admin/TV input, semantics, scaling, latency, soak | open |
| G10 — Platform/build | Clean iOS/Android/Android TV/web builds from exact source | open |
| G11 — Staging/device/release | Authenticated staging, physical UAT, signing, deployment, rollback | open |
| G12 — Closeout | 27/27 verified, registers reconciled, broader AFRICLUB controls updated | open |

## Required service levels

- normal state propagation p95 at most 2 seconds;
- reconnect to current authoritative snapshot at most 5 seconds after network
  restoration;
- zero cross-club data exposure;
- zero lifecycle double-advance under duplicate requests;
- zero pre-reveal correct-answer leakage;
- zero participant dependency on TV/session code in V2;
- no personal data on TV;
- no unauthorized owner, venue, organizer, or admin operation.

## Mandatory control records

This goal package must maintain:

1. `engagement-manifest.json`
2. `task-register.json`
3. `validation-manifest.json`
4. `evidence-register.md`
5. `assumptions-register.md`
6. `issue-log.md`
7. `decision-log.md`
8. `deliverables-index.md`
9. `release-readiness-matrix.md`
10. `human-blockers-and-handoff.md`
11. `START_GOAL.md`

Every status change must update the task register, validation manifest, evidence
register, and any affected issue/decision/release record in the same controlled
reconciliation.

## Completion audit

Before closure:

1. enumerate all 27 task IDs and all 13 quality gates;
2. map each acceptance criterion to authoritative current evidence;
3. confirm evidence applies to the exact current candidate and required
   platform/environment;
4. reopen any task whose prior evidence was invalidated;
5. prove status counts mechanically;
6. confirm the participant code path is absent from V2 navigation and copy;
7. confirm legacy adapters remain only where the approved compatibility window
   requires them;
8. confirm all required human/device/staging/signing/store/production gates;
9. reconcile the wider AFRICLUB goal controls;
10. issue the final handoff with residual risks and rollback status.

The goal may be marked complete only when:

```text
total_tasks = 27
verified_complete = 27
verified_incomplete = 0
unverified = 0
blocked = 0
required_open_approvals = 0
required_open_decisions = 0
required_open_quality_gates = 0
```

## Blocking and escalation

Do not mark the goal blocked merely because work is difficult or protected
approval is pending while other useful work remains. Escalate:

- conflicting or missing product decisions;
- protected change without approval;
- dirty-file ownership conflict;
- cross-club/RLS or privacy risk;
- answer leakage or incorrect scoring;
- migration irreversibility;
- missing authenticated staging or device access;
- iOS/Android/TV build or signing failure;
- production, deployment, store, payment, or external action.

Blocked status is allowed only after the same material blocker persists through
the required repeated audit and no useful safe in-scope work remains.

## Required final handoff

- Green/Amber/Red executive status.
- 27-task status reconciliation.
- Quality-gate reconciliation.
- Files changed and implementation locations.
- Exact validation commands and results.
- Backend/RLS/security evidence.
- Mobile, TV, admin, accessibility, performance, and multi-client evidence.
- Staging, physical-device, signing, store, deployment, and rollback status.
- Decisions, approvals, exceptions, and residual risks.
- Reconciliation with the wider AFRICLUB goal.
