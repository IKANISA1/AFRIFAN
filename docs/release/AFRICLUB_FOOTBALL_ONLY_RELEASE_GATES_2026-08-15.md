# AFRICLUB Football-Only Release Gates

Status: active source-boundary checklist; not release authorization.

## Candidate Boundary

- Mobile, public web, admin, and venue surfaces expose only club, football,
  prediction, membership, supporter, contribution, ticket, shop, reward, and
  venue capabilities.
- Workspace registration, routes, localization, push configuration, backend
  objects, store metadata, documentation, and evidence records follow the same
  boundary.
- The database is reproducible from one clean baseline and governed seed.

## Required Local Gates

- Flutter dependency resolution, strict workspace analysis, and all package
  tests pass.
- Football-first route tests and visual baselines pass.
- Android and iOS local build checks pass in the available environment.
- Web typecheck, tests, zero-warning lint, and production build pass.
- Repository boundary, route inventory, UI guardrail, evidence privacy,
  provenance, secret, store, and shell validators pass.
- A fresh local Supabase reset, all pgTAP contracts, schema lint, and empty
  schema drift pass.
- Positive checks prove predictions and all other supported football-platform
  capabilities remain registered and executable.
- No generated dependency, cache, build, coverage, or evidence-output
  directory remains in the worktree.

## Required Release Evidence

- Create a clean exact-candidate source freeze.
- Capture new Android, iPhone, and iPad screenshots from the exact signed
  candidate using synthetic or masked data.
- Verify Android and iOS signing, package identity, entitlements, permissions,
  links, privacy manifests, notification setup, and artifact hashes.
- Complete physical Android/iOS accessibility, lifecycle, deep-link, push,
  offline/reconnect, upgrade, rollback, and performance testing.
- Revalidate production schema, RLS, RPCs, Edge Functions, storage, schedules,
  privacy declarations, public-domain deployment, monitoring, observation, and
  rollback.
- Record accountable product, design, accessibility, privacy, security, legal,
  content-rights, language, QA, operations, and final release approvals.

Repository completion does not authorize production database changes,
deployment, store submission, or external approval.
