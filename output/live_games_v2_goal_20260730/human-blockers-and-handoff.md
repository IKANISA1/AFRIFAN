# Human Blockers and Handoff

## Current status

**Blocked Red pending owner approval.** The main-only historical implementation candidate,
proposed ADR, machine-readable lifecycle/projection/discovery contract, deterministic
contract validator, code-free participant projection, synchronization, and
discovery domain now exist. The current checkout is dirty with concurrent work,
so exact-candidate gates remain open.

LG-000, LG-001, LG-103, LG-104, LG-105, LG-200, LG-201, and LG-202 are in
progress; 19 tasks remain unverified and all 13 quality gates remain open.
The isolated participant tranche has 77 passing tests and clean focused
analysis. It now includes an answer-submission boundary with expected versions,
stable idempotency, duplicate coalescing, timeout uncertainty, sanitized
failures, authoritative response reconciliation, and a unified Riverpod
runtime for automatic invalidation follow, offline retention, reconnect,
permission revocation, and timeout recovery. It does not close production
gateway, UI, device, or backend gates. A code-free entry controller now waits
for authoritative discovery, admits only feed-eligible session identities,
supports invitation/deep-link sources, and rejects alias mismatch.
It forwards answer submission only after eligible live entry.

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

## Third consecutive blocker audit

Owner approval and dirty-file ownership remain unresolved for the third
consecutive goal turn. Meaningful isolated non-protected work was completed
without inventing the pending decisions:

- the proposed ADR and validated machine-readable contract;
- typed code-free participant projection and privacy validation;
- monotonic Realtime invalidation reconciliation;
- offline/reconnect-aware participant synchronization;
- code-free eligible-session discovery and session-identity recovery;
- expected-version and idempotent participant answer submission;
- unified Riverpod participant synchronization and mutation orchestration;
- code-free discovery-to-runtime entry with deep-link race protection;
- 77 focused tests, clean focused analysis, and reconciled goal evidence.

Protected migrations/RLS/rules/localized messages and overlapping user-owned
backend, mobile, TV, and admin files remain gated. The current Fan Zone diff
still exposes participant TV-code entry and cannot count toward LG-202.

No useful safe in-scope work now remains. Further implementation would require
inventing unresolved product decisions, modifying protected files without
approval, or overwriting concurrently edited user-owned surfaces. The goal is
therefore blocked under its repeated-audit rule; this is not a completion or
release-readiness claim.

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
