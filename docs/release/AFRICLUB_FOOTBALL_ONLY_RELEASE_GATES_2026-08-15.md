# AFRICLUB football-only release gates

Date: 2026-08-15

Status: active source-boundary checklist; not a release authorization.

## Candidate boundary

- The mobile app, public web, admin, and venue surfaces expose football, club,
  membership, contribution, ticket, shop, prediction, supporter, and venue
  capabilities only.
- The repository contains no active TV app, trivia route, trivia runtime,
  trivia administration, or trivia Edge Function.
- Historical database migrations and dated release records are not active
  product registration and do not authorize destructive production cleanup.

## Required local gates

- Flutter workspace analysis and tests pass.
- Affected Fan Zone and Settings visual baselines are reviewed and pass.
- `apps/rayon_sports` builds for Android using a non-production configuration.
- Modified consumer/admin/venue web source lint, type checks, tests, and
  production build pass; repository-wide pre-existing lint debt is tracked and
  remains release-blocking until resolved or explicitly dispositioned.
- route inventory, UI guardrails, Supabase Edge/local-migration contracts, and
  store-package consistency validators pass. Evidence/privacy findings require
  human review because the current scanner treats migration timestamps as
  possible Rwanda phone numbers.
- an active-source scan finds no moved TV/trivia imports, routes, packages,
  localized copy, push routes, or build registrations.

## Required release evidence

- Generate a clean exact-candidate source freeze after the split.
- Capture new football-only Android, iPhone, and iPad screenshots. The former
  Fan Zone store images were retired because they displayed a moved entry
  point.
- Build and verify new signed Android and iOS artifacts; do not reuse the
  pre-split artifact hashes or equivalence claim.
- Complete physical Android/iOS accessibility, lifecycle, deep-link, push,
  offline/reconnect, and performance testing.
- Revalidate backend schema, RLS, RPC, Edge Functions, privacy declarations,
  Cloudflare deployment, monitoring, rollback, and production data retention.
- Record accountable product, design, accessibility, privacy, security, legal,
  content-rights, language, QA, operations, and release approvals.

No production deployment, store submission, schema deletion, or external
approval is performed by the repository split.
