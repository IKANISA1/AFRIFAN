# Web dependency remediation

## Remote verification — 15 September 2026

After commit `703e78be032b3f6771d688a8c7e90acd575e3267` reached `main`,
GitHub marked Dependabot alerts 99–106 fixed at 09:24:13–14 UTC. A fresh
open-alert API query returned zero entries. The push-time message reporting
eight alerts preceded this refresh; none was manually dismissed. This verifies
the remote dependency state separately from the earlier local npm audit.

The pinned `corepack npm run check:dependencies` passes all nine regressions
with npm 12.0.2. Invoking the adjacent unpinned `npm` executable selected
11.8.0 and correctly failed the package-manager contract before running tests.

The [hosted run for the same commit](https://github.com/IKANISA1/AFRIFAN/actions/runs/34952363716)
started zero jobs. Its authenticated run-page annotation identifies failed
account payments or the spending limit as the blocker. The terminal result is
`startup_failure`; account-owner action is required before hosted verification
can run. No billing setting was changed.

Evidence: `output/qa/full-stack-20260914/hosted-ci-root-cause-and-alert-closure.json`
and `dependencies-after-push-pinned.json`. This does not establish deployed
versions or whole-system release readiness.

## Current local review — 14 September 2026

The full-stack QA baseline found eight vulnerable installed-package entries:
one critical, four high and three moderate. These entries include consumers of
the same vulnerable dependency and are not eight demonstrated application
exploits. The installed tree now reports zero known vulnerabilities after the
following updates:

| Package | Before → after | Supporting advisory |
| --- | --- | --- |
| Next.js and its ESLint configuration | 16.3.0 → 16.3.5 | [Windows path handling](https://github.com/vercel/next.js/security/advisories/GHSA-p293-qw3h-jr36), [AVIF image processing](https://github.com/vercel/next.js/security/advisories/GHSA-2xp9-vwfh-vxw4) |
| Sharp, including Miniflare's dependency | 0.35.2 / 0.35.3 → 0.35.4 | [Image processing advisory](https://github.com/lovell/sharp/security/advisories/GHSA-rgj7-g3m4-5g8c) |
| Vitest and coverage provider | 4.1.9 → 4.1.11 | [Vitest advisory](https://github.com/vitest-dev/vitest/security/advisories/GHSA-82fw-gwwq-j7x9) |
| js-yaml | 4.2.0 → 4.3.2 | [Merge-source limits](https://github.com/nodeca/js-yaml/security/advisories/GHSA-2883-xcg3-v3hh) |

The Sharp patch override stays within the existing 0.35 release series. The
existing dependency regression suite now has nine passing checks: the six
earlier cases below, bounded repeated YAML merge sources with an ordinary-merge
control, and AVIF resize/PNG output through both Next.js and Miniflare's resolved
Sharp packages. The image checks establish patch compatibility; they do not
demonstrate exploit reachability. The Windows-specific condition is not claimed
to apply to this macOS runtime.

Pinned Node 22.23.2 and Corepack/npm 12.0.2 were used. Dependency validation,
strict lint, type checking, all 920 web unit tests and the Next.js build passed.
The build uses synthetic endpoints and controlled QA fixtures; expected failed
feature-config reads do not establish live backend health. Browser, database,
native-device, Cloudflare runtime and release acceptance results are tracked
separately in `output/qa/full-stack-20260914/`. No deployment or remote advisory
closure is asserted by these local results.

## Earlier remediation — 5 September 2026

This follow-up addresses the five Dependabot advisories reported against
`apps/rayon_sports/web/package-lock.json` after the mobile design commit
`c84f543646d752d52153f40d0f2136111bd14aa2`. The affected packages are transitive
dependencies; the review did not establish an exposed supporter endpoint for
the advisory-specific input paths.

| Advisory | Package before → after | Boundary corrected |
| --- | --- | --- |
| [GHSA-4mjr-xmp4-gh2g](https://github.com/ljharb/qs/security/advisories/GHSA-4mjr-xmp4-gh2g) | qs 6.15.3 → 6.16.0 | Treat hostile `constructor.isBuffer` values as data during serialization. |
| [GHSA-x5fp-wj9c-mxmx](https://github.com/ljharb/qs/security/advisories/GHSA-x5fp-wj9c-mxmx) | qs 6.15.3 → 6.16.0 | Enforce comma-array limits for bracketed and encoded query keys. |
| [GHSA-c83g-rgw3-j3cx](https://github.com/browserslist/browserslist/security/advisories/GHSA-c83g-rgw3-j3cx) | browserslist 4.28.4 → 4.28.9 | Bound cached distinct queries. |
| [GHSA-73wf-gq98-2v4g](https://github.com/browserslist/browserslist/security/advisories/GHSA-73wf-gq98-2v4g) | browserslist 4.28.4 → 4.28.9 | Handle prototype-shaped custom statistics without inherited-property access. |
| [GHSA-p498-v437-472g](https://github.com/humanwhocodes/humanfs/security/advisories/GHSA-p498-v437-472g) | @humanfs/node 0.16.7 → 0.16.8 | Preserve file symlinks during copy instead of materializing their target contents. |

## Reachability and patch scope

- OpenNext's AWS adapter brings Express and body-parser, which use `qs.parse`.
  Express's extended parser allows prototype-named keys. The inspected wrapper
  and application do not forward that parsed value to `qs.stringify`, and the
  body-parser invocation does not enable `comma: true`. The patch closes the
  library behavior without claiming a demonstrated public-app exploit.
- Next's ESLint configuration brings the React Hooks plugin, Babel and
  Browserslist. Babel's compilation-target resolver queries Browserslist; no
  application HTTP input into its query or custom-statistics arguments was found.
- ESLint brings `@humanfs/node`. Application source does not call its copy APIs.
  Symlink preservation does not confine later traversal of the copied link.

The qs override now requires at least 6.16.0. The lockfile resolves compatible
patched versions of all three packages, the required humanfs core/types updates,
and Browserslist's browser-data dependencies. Framework versions and application
request handling are unchanged.

## Regression evidence

`apps/rayon_sports/web/scripts/dependency-security.node-test.mjs` exercises the
installed packages. Its six checks cover the two qs cases, two Browserslist
cases, and both humanfs copy operations. It includes ordinary query round trips,
valid array limits, cached-result equivalence and ordinary file-copy controls.
The cache workload is bounded; filesystem cases use synthetic temporary files.

The same test file produced **six failures against the prior package versions**
and **six passes against the patched dependency tree**. `npm run
check:dependencies` now runs these regressions after the existing package-manager,
lockfile, dependency-tree and audit checks. The patched audit reported **zero
known vulnerabilities**. This is the installed-tree result, not a guarantee
against unknown vulnerabilities or a deployment claim.

Web lint, type checking, production build and the existing 918-test suite passed.
The five Cloudflare release-validator tests also passed. The CSS size gate found
unused rules retained in the shared stylesheet; cleanup removes 29 unreferenced
rules, four unused keyframes, twelve unused custom properties and 24 earlier
identical declarations. The later declarations and supported dynamic animation
variants remain. Twenty-one identical loading animations are consolidated into
three shared definitions while retaining their durations and reduced-motion
selectors. The existing size ceilings remain in force.

The production CSS total fell from **45.59 KiB to 44.86 KiB**, below the
unchanged 45 KiB limit; critical JavaScript remains **166.28 KiB** against
170 KiB. A source-level comparison verified that all 33 retained animation
declarations preserve their keyframes, timing, iteration and selector context.

## Historical external service observation — 5 September 2026

The 5 September production build-time feature-config reads reported Supabase
`exceed_storage_size_quota`. The build completes, but live data availability
was restricted. This observation has not been refreshed by the 14 September
synthetic QA build. This change does not alter storage, billing, service limits,
deployments or store submissions. Remote advisory closure is verified separately
after the lockfile reaches `main`.
