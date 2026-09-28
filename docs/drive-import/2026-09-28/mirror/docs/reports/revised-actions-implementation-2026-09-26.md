# AFRICLUB revised-actions implementation manifest — 26 September 2026

Implemented in this change set:

1. Repository-boundary validator now permits legacy identifiers only in narrowly governed Cloudflare migration/disposition evidence; runtime paths and ordinary documentation remain strict. Regression suite expanded from 6 to 9 tests.
2. Public Rayon Cloudflare staging moves to an explicit active-snapshot model. Content and media require the same fresh active snapshot. A migration adds snapshot metadata and snapshot membership; API schema advances to v2 with `snapshotId`.
3. Supporter SMS/device-message boundary validator covers all five supported app shells and is chained into the store/privacy validation path.
4. Predict economics decision gate freezes the safe free-entry contract pending an explicit approved replacement; Cloudflare transactional work may not silently implement historical FET entry debits.
5. Design governance wording is reconciled: `revolut-design` remains sole authority; `DESIGN.md` is the AFRICLUB adapter. The adapter scope is corrected from four to five configured club shells.
6. Cloudflare transactional API contract records server-side identity/tenant/role/resource authorization, idempotency, atomic mutation+ledger+outbox, one-writer cutover, and mandatory negative/concurrency/replay tests.
7. A disposition register prevents deployed/local functions, cron jobs, Auth, and blocked Storage originals from being deleted merely because they are unmapped.

Verified locally in isolation:
- repository-boundary tests: 9/9 pass;
- public Worker active-snapshot contract tests: 3/3 pass;
- design-authority tests: 8/8 pass against the current validator fixture;
- new D1 snapshot migration applies after the existing staging schema in SQLite;
- modified Worker and new Node validators parse successfully;
- updated Python API verifier compiles successfully;
- modified privacy shell script passes shell syntax validation.

Not falsely claimed complete:
- no production Cloudflare deployment or traffic switch;
- no Supabase retirement or deletion;
- no billing/spend-cap change and no recovery of the eight blocked AFRICLUB Storage originals;
- no production identity or transactional data migration;
- no full Flutter/web/pgTAP/device release matrix in this connector-backed workspace;
- no deletion of live functions/jobs without approved disposition and replacement evidence.
