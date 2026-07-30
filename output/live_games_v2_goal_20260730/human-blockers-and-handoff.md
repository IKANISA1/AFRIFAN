# Human Blockers and Handoff

## Current status

**Active Red.** The main-only historical implementation candidate,
proposed ADR, machine-readable lifecycle/projection/discovery contract, deterministic
contract validator, code-free participant projection, synchronization, and
discovery domain now exist. The current checkout is dirty with concurrent work,
so exact-candidate gates remain open.

LG-000, LG-001, LG-103, LG-104, LG-105, LG-200, LG-201, and LG-202 are in
progress; 19 tasks remain unverified and all 13 quality gates remain open.
The isolated participant tranche has 58 passing tests and clean focused
analysis. It now includes an answer-submission boundary with expected versions,
stable idempotency, duplicate coalescing, timeout uncertainty, sanitized
failures, and authoritative response reconciliation. It does not close
production gateway, UI, device, or backend gates.

## Decisions required

- DEC-01: multi-TV assignment.
- DEC-02: home-TV eligibility.
- DEC-03: venue-manager versus organizer capability.
- DEC-04: governed alias only.
- DEC-05: state synchronization versus video.
- DEC-06: legacy compatibility window and sunset.

## Protected approvals required

- APR-01: new Supabase migrations.
- APR-02: RLS changes.
- APR-03: narrow `RULES.md` owner/organizer role amendment.
- APR-04: new Flutter feature package/pubspec entries.
- APR-05: shared localization changes.
- APR-06: CI changes only if later required.
- APR-07: staging migration execution.
- APR-08: production migration/deployment.
- APR-09: signing/store/release action.

The exact local-source request is recorded in `approval-request.md`. APR-06
through APR-09 are explicitly excluded from the current request.

## Active blocker audit

The previous blocked status has been superseded by the reactivated goal.
Owner approval and dirty-file ownership remain unresolved, but meaningful
isolated non-protected work resumed without inventing the pending decisions:

- the proposed ADR and validated machine-readable contract;
- typed code-free participant projection and privacy validation;
- monotonic Realtime invalidation reconciliation;
- offline/reconnect-aware participant synchronization;
- code-free eligible-session discovery and session-identity recovery;
- expected-version and idempotent participant answer submission;
- 58 focused tests, clean focused analysis, and reconciled goal evidence.

Protected migrations/RLS/rules/localized messages and overlapping user-owned
backend, mobile, TV, and admin files remain gated. The current Fan Zone diff
still exposes participant TV-code entry and cannot count toward LG-202.

## Immediate next action after approval

Complete LG-000:

1. finish original ownership attribution for overlapping Live Games files;
2. preserve the clean `main` candidate without discarding user work;
3. continue directly on `main` without a feature branch;
4. decide DEC-01 through DEC-06;
5. approve APR-01 through APR-05 before protected implementation.

Resume with the exact approval response in `approval-request.md`, reconcile
file-level ownership, then complete LG-000 through LG-002 before protected
backend implementation. Protected source changes must not begin before their
approval gate.

## External boundary

No staging/production mutation, migration application, deployment, signing,
store action, external communication, or release is authorized by creation of
this goal package.
