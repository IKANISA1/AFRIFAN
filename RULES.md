# AFRICLUB contributor rules

These rules apply to this repository. Follow the owner's current task scope;
existing authorization does not need to be requested again.

## Sources of truth

- `README.md`: repository entry point and development commands.
- `docs/blueprint.md`: product boundary, architecture, and tenancy.
- Selected `revolut-design` skill: sole visual and interaction authority for the
  complete app, web, admin, PWA and operator system.
- `DESIGN.md`: product facts and mappings to that skill, never another design standard.
- Root `pubspec.yaml` and `pubspec.lock`: Flutter workspace, resolved dependencies,
  and Melos commands.
- `.fvmrc`, `.nvmrc`, and the web `package.json` and lockfile: toolchain versions.
- `supabase/migrations/` and `supabase/tests/`: database history and contracts.
- `docs/rayon_sports_release_checklist.md`: release procedure.

Keep these responsibilities separate. A runbook, screenshot, old task report,
or source comment must not introduce a competing product or design contract.
When documentation disagrees with current source, inspect the implementation
and the owner's accepted decisions before updating either.

## Scope and change control

Inspect the worktree and relevant code before editing. Preserve unrelated
changes. Work on a `codex/` branch and keep the cleanup reviewable in Git.

Obtain owner direction when a task does not already authorize a material change
to the supporter home, shared theme, dependencies, club flavors, workspace,
CI/CD, authentication, schema, RLS, or branded assets. Prepare and validate the
concrete change before requesting any final external-action approval.
Repository maintenance does not itself authorize production database changes,
deployment, store submission, or messages to third parties.

## Repository hygiene

- Delete replaced code and unused assets; update imports, manifests, tests, and
  documentation in the same change.
- Keep reusable tools with documented inputs. Delete completed one-off scripts,
  duplicate setup instructions, old task ledgers, and generated audit reports.
- Use Git history for historical source. Do not add archive or backup folders.
- Keep dependencies, build output, local configuration, coverage, and generated
  evidence ignored. Local caches are allowed; they are not repository source.
- Do not remove applied migrations, signing material, operational data, or
  current release artifacts merely because they are old.
- Keep current, reproducible tests and golden baselines. Remove evidence claims
  when their source artifacts are removed; missing evidence remains unverified.
- Avoid duplicate implementations, commented-out code, speculative dependencies,
  and suppression of real analyzer failures.

## Flutter architecture

The workspace currently uses Riverpod 2.x, as declared in package manifests.
Use its existing providers for shared state and GoRouter for application
navigation. Keep business logic and data access in providers, repositories,
and services. Keep app shells thin and shared behavior club-configurable.

Follow the dependency boundaries in `docs/blueprint.md`. Shared club data lives
in `packages/data/club_data`; shared test harnesses live in `packages/testing`.
Keep test dependencies in `dev_dependencies`, use public package entry points,
and run `dart run tools/scripts/validate_workspace_architecture.dart` after
changing workspace layout, imports, or dependencies.

Use `core_l10n` for interface copy, runtime club configuration for identity,
and approved backend data for dynamic content. Respect runtime feature flags.
Do not fabricate content or success states when data is unavailable.

Supporter onboarding permits anonymous entry. MoMo linking belongs in account
settings and must not become a first-launch requirement. Follow the selected `revolut-design` skill
for loading, empty, error, offline, and accessibility states; there is no
blanket requirement to hide every empty screen.

## Data and security

- Keep tenant queries explicitly scoped where the data contract requires it.
  RLS, ownership checks, and role checks remain the authorization boundary;
  a client filter or channel name alone cannot provide isolation.
- Resolve trusted club and operator context server-side. Never accept a request
  body tenant identifier as sufficient authorization.
- Enable RLS on exposed tables and grant only operations required by the
  feature. Do not add permissive CRUD policies to satisfy a template.
- Use fixed search paths and explicit grants for privileged functions. Keep
  monetary, stock, ticket admission, membership, and prediction state changes
  authoritative and idempotent on the backend.
- Preserve applied migration files. Add forward migrations and validate them
  against an isolated database before any approved production operation.
- Keep service-role keys, signing keys, provider credentials, and private feed
  details server-side or in ignored local/CI secret storage.
- Minimize personal data. Use public supporter aliases and masked contact
  details; follow the current SMS redaction, private-profile, staff privacy,
  account deletion, and retention contracts.
- Keep free predictions and governed FET rewards within the product policy in
  `docs/fet_ledger_and_rewards_policy.md`. Payment initiation is not payment
  confirmation. AI drafts require review before publication.

## Verification and release reporting

Run checks appropriate to the change. For Flutter changes, format changed Dart
files, run strict workspace analysis, and run affected package and route tests.
For web changes, use the pinned Corepack/npm toolchain and run typecheck, tests,
lint, and build as appropriate. Run database contracts for schema changes.

Use the release checklist for full release validation. Record the actual source
commit and distinguish local checks, hosted CI, deployed versions, physical
device UAT, provider review, and accountable release approval. Never infer one
from another. Empty evidence registries do not mean validation is complete.
