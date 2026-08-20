# AFRICLUB football-only split closure

Date: 2026-08-20

Status: local engineering closure; not deployment or release authorization.

## Implemented boundary

AFRICLUB retains football, club, prediction, supporter-points, membership,
contribution, ticketing, shop, venue, content, and football-administration
features. Active TV and trivia apps, packages, routes, localized copy, push
routing, web control rooms, display APIs, Edge Functions, and build
registrations have been removed.

The forward migration
`20260820080202_decommission_tv_trivia_runtime.sql` preserves historical data
and the immutable migration ledger while revoking public, anonymous,
authenticated, and service-role access to the retired schema and functions,
removing its Realtime publication, and disabling public wrappers. It does not
drop production data. A later baseline squash or physical deletion requires a
separate retention, export, dependency, rollback, and migration-history
approval.

## Local validation completed

| Area | Result |
| --- | --- |
| Flutter analysis | Melos strict analysis passed across 63 packages. |
| Flutter tests | Full deterministic matrix passed across all 43 test-bearing packages. |
| Ownership tests | Registry negative test and active-source scan passed; 2,525 active files contained no retired TV/trivia source, route, package, or RPC identifier. |
| Supabase | Fresh reset passed; all 247 assertions in 18 pgTAP files passed; database lint reported no warnings. |
| Backend guards | Edge contract, local-only migration contract, and scoped Realtime scan passed. |
| Mobile builds | Rayon Sports Android debug APK and iOS Simulator app built using the sanitized staging configuration. |
| Web | Node 22.23.2/npm 11.8.0; typecheck passed; 890 tests in 110 files passed; zero-warning ESLint passed; Next production build passed. |
| Store/privacy | Store/privacy contract passed 32 assertions; the iOS release structure contract passed. |
| Secrets | Source secret and signing-material scan passed. Production-dependency npm audit reported zero vulnerabilities. |

One route-inventory test previously depended on an untracked screenshot under
`output/`. It now uses temporary tracked fixtures and continues to prove that
missing evidence remains fail-closed. One venue-shell test still expected the
removed TV destination; it now asserts the six retained football operations
links. The complete test matrices passed after both corrections.

The first iOS build attempt encountered an internal Xcode Swift Package Manager
exception. A clean retry completed successfully; generated Xcode lock/project
rewrites were removed from the source diff.

## Known non-blocking toolchain notices

- Flutter warns that the app and several plugins must migrate to Built-in
  Kotlin before a future Flutter release.
- Next reports its documented middleware deprecation and Edge-runtime warning;
  typecheck, zero-warning source lint, tests, and the production build pass.
- The complete npm tree reports six high-severity development-tool findings;
  `npm audit --omit=dev --audit-level=high` reports zero production dependency
  vulnerabilities. Dependency remediation remains separate from this split.

## Gates that remain open

- production execution of the forward decommission migration and verification
  against every deployed environment;
- production retention/export approval and any later schema deletion or
  migration-history reconciliation;
- new signed football-only Android/iOS artifacts and replacement store
  screenshots;
- physical Android/iOS accessibility, deep-link, push, offline/reconnect,
  lifecycle, and performance testing;
- production Cloudflare/Supabase deployment, monitoring, rollback rehearsal,
  store submission, and accountable product/privacy/security/legal/release
  approvals.

No production database, deployment, store, or external service was changed.

## Rollback

The work remains isolated on `codex/split-tv-trivia-to-lets-play`. Before
merge, rollback is to leave the branch unmerged. After merge, use normal Git
reverts. Database rollback is separate because no production migration was run.
