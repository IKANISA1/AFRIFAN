# Web dependency remediation — 5 September 2026

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

## External service status

Production build-time feature-config reads report Supabase
`exceed_storage_size_quota`. The build completes, but live data availability
remains restricted. This change does not alter storage, billing, service limits,
deployments or store submissions. Remote advisory closure is verified separately
after the lockfile reaches `main`.
