# AFRICLUB production goal: implementation checkpoint

Execution began 29 September 2026 and continued into 30 September in Kigali.
The goal remains **active**. Production decision: **NO-GO**.

## Scope and control

The [living task register](production-readiness-task-register.json) preserves all
130 original task objects, priorities, dependencies and acceptance criteria from
Implementation 08. It tracks current evidence independently. All 130 remain
applicable, all release acceptance fields remain false, and the 34 outstanding QA
checks retain their original text. Historical frontend approval retains its
four-club scope. Current scope is five clubs and ten Android/iOS targets.

The candidate is being implemented on `codex/production-readiness-20260929`,
starting at `589698c64d83e0c0209a648b1eda30a60498b27c`. Main and the original
Drive archives remain recoverable. This checkpoint includes local implementation
and validation; it does not record a deployment or store submission.

## Changes implemented

| Change | Reason and practical limit |
| --- | --- |
| Integrated 81 selected payment-allocation, shared-reference and operational-inbox files from Implementation 08 | Supplies coherent immutable allocation, checkout handoff, history, recovery, delivery journal and deduplicated inbox contracts. Ordered migrations retain one global consumed-reference authority. Configurations remain disabled; real D1/provider acceptance remains open. [Per-file hashes and corrections](payment-core-integration-2026-09-29.json). |
| Bounded all three source delivery RPCs and sink acceptance independently | A stalled club previously prevented every later club from being examined. Timeouts preserve unknown outcomes and original event/lease/command identity. Late commits recover through the existing journal; no financial allocation is reposted. Four regressions failed before the correction and pass afterward. |
| Repaired the repository boundary validator | Hyphen normalization previously missed retired routes. New source, SQL/routes, forced tracked build output, binary text and symlink bypasses are checked. Historical inventory exceptions are exact-hash and expire. Archive evidence stays outside live source; exact audit-control fixtures receive separately governed review. |
| Added five-club/ten-target scope verification | The QA table, workspace/app registrations, tenants, country codes and platform identities are reconciled. Missing release configuration remains visible even when source scope passes. Signing and store registration require independent evidence. |
| Redacted source and evidence scanner diagnostics | Rejected credentials, private phone values and codes are no longer printed into validation logs. Twelve behavior regressions cover rejection and clean evidence, including pending human review. Broader publication policy remains an owner requirement. |
| Updated Undici 7.29.0 to 7.29.1 through a version-specific dependency override | Repairs current dependency advisories without changing Next, Wrangler, Workerd or script permissions. Security regressions fail against the former dependency and pass against the patched dependency. |
| Corrected the club-identity SQL contract | A stale assertion wrongly classified Costa do Sol's legitimate profile as Rayon leakage. The 29 assertions detect injected whole/partial Rayon leaks, preserve independent club attribution, and check all five public identities, private fields and inactive-club suppression. No migration or club facts were changed. |
| Corrected active-source analyzer and design-scan scope | Preserved archive candidates cannot establish active design authority or runtime asset rights. Negative fixtures still reject competing design files and ungoverned assets introduced into live paths. Existing golden bytes remain intact. |
| Integrated feature availability and empty-module recovery across seven source/test paths | Optional modules cannot expand an explicitly disabled club capability. Malformed flags and supplied wrong-club/channel scope fail closed; an empty route graph renders recovery. Existing always-visible Club/Membership behavior is preserved when the club capability is enabled. Typed snapshots omit club ID, so their existing scoped fetch/cache still governs provenance. [Hashes and rationale](feature-availability-integration-2026-09-29.json). |
| Registered new contract suites in CI source | Scope, financial recovery/delivery, strict client compilation and redaction behavior run in the workflow. Hosted execution remains unverified until a current candidate run succeeds. |

The [416-path lineage disposition](candidate-lineage-disposition-2026-09-29.tsv)
records 87 adopted candidate paths: 77 exact and ten with reviewed corrections.
Another 12 already match, 25 require reconciliation, and 292 remain pending
integration. One additional registry test and one delivery timeout test were
written locally. Source presence does not establish acceptance.

## Executed checks

| Check | Current observed result | Limit |
| --- | --- | --- |
| Pinned toolchain and lock resolution | Flutter 3.44.9 / Dart 3.12.2, Node 22.23.2 / npm 12.0.2; enforced Flutter lock resolution passed | Apple/Android release toolchain and fresh-clone artifact acceptance remain open. |
| Strict Flutter analyzer | Final active-workspace run passed with fatal warnings and infos after all Dart corrections | Native release builds and hosted CI remain required. |
| Whole workspace Flutter run and repairs | Initial aggregate: 27 packages passed, core_theme failed on three stale scan assumptions. Complete corrected core_theme rerun: 451 passed. Modified router/registry rerun: 96 passed; all five app scopes afterward: 27 passed | These are separate runs, with their failed baseline retained. A fresh all-green hosted/fresh-candidate run remains required. |
| Feature-availability standalone policy | 36 checks passed | Backend operation authorization and typed snapshot provenance remain separate. |
| Repository boundary and source scope | 37 boundary regressions and 13 scope regressions passed; actual boundary passed | Four exact-hash control/inventory exceptions expire 29 October; implementation review does not supply owner/release approval. |
| Gamification package | 155 passed | Included again in the complete workspace run; these counts must not be added. |
| Financial allocation and reliable delivery | 688 passed, zero failed/skipped | Synthetic SQLite/D1 adapter checks; isolated hosted D1 and provider evidence remain open. |
| Allocation/inbox schema replay | Six ordered allocation migrations and a separate inbox migration passed SQLite integrity and FK checks | The old conflicting handoff migration is preserved as source evidence and excluded from this lineage. |
| Supabase fresh replay | 37 SQL contracts, 678 assertions and 46 concurrent/race checks passed | Fresh portless disposable containers, real pinned auth/storage vendor schemas, synthetic data; no deployed-database parity inferred. |
| Edge Functions | 293 tests passed; all 18 entrypoints type checked | Test runtime network access was restricted to loopback. Provider and deployed-bundle verification remain open. |
| Web | Lint, typecheck, production build and size gate passed; 113 unit files, 962 tests passed and one skipped | The skipped case, browser evidence, installed PWA and real journeys remain required. |
| Web dependency controls | Audit zero vulnerabilities; 11 dependency regressions and five deployment-config regressions passed | Complete SBOM, licenses and historic credential review remain open. |
| Web bundles | JS 166.67/170 kB; CSS 36.45/45 kB | A static compressed-size budget does not establish device or game-day performance. |
| Native source scope | Five clubs/ten targets pass; production bootstrap blocked for Costa do Sol | Its Supabase URL and anonymous key are missing; do not substitute another tenant's configuration. |

## Observed release blockers

- The inspected hosted run ended `startup_failure` with **zero jobs** at remote
  commit `6fa4588eec0903ea76a3d2f148c4942381dd40d0`. A local successful test
  is not a hosted candidate run.
- The private repository's branch-protection API returned HTTP 403 requiring an
  eligible GitHub plan. No repository visibility or billing setting was changed.
- The web build's backend reads reported `exceed_storage_size_quota`. Build
  completion does not establish backend availability; the existing project
  restriction needs an authorized operational resolution and fresh verification.
- Costa do Sol bootstrap inputs, approved brand and registered signing/provider
  identities remain unresolved. All ten signed and installed native targets
  still require current device/store evidence.
- Custom identity, OTP dispatch, native membership composition, browser portal,
  operator/exception workflows and immutable public snapshots remain further
  candidate integration groups. Their dependencies and divergent existing paths
  require explicit reconciliation.
- Business rules, rights, provider authenticity, privacy/deletion, restores,
  rollback, on-call ownership, five-club journeys, accessibility/performance,
  named independent review and final release approval remain governed acceptance
  criteria in the 130-task register.

## Next execution sequence

1. Finish coherent source convergence: feature availability, identity/OTP,
   membership/native protected recovery, browser portal, then operator/exception
   and immutable public publication. Preserve each original source hash and
   record any correction and superseded path.
2. Complete source/route/object/permission inventories and fail-closed candidate
   gates. Produce an exact source/configuration/migration/artifact manifest and
   reproduce the complete candidate with the pinned toolchains.
3. Execute every applicable club/platform/role/state journey in isolated
   environments; verify real D1 behavior and authorized providers, native
   installations, browser/PWA behavior, accessibility and performance.
4. Reconcile live service restrictions and hosted CI/protection, rehearse
   restore/rollback and staged operations, then obtain named owner and independent
   acceptance for the exact candidate. Release acceptance remains false until
   those results exist.

The [evidence manifest](production-goal-evidence-2026-09-29.json) binds commands,
sanitized local logs and current source hashes. Evidence text retains automatic
privacy scanning and pending human review; test counts do not replace release
criteria.
