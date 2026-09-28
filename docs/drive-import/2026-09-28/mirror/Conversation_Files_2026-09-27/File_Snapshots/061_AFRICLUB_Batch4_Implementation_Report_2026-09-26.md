# AFRICLUB — batch 4 supporter identity/session implementation

Date: 26 September 2026.
Authority: the AFRICLUB Google Drive repository and previously delivered cumulative
v3 source patch. This batch advances the existing migration, not a replacement
architecture chosen independently of the source.

## 1. Actual delivery state

Batch 4 contains **21 source changes: 20 additions and one change to the source-check
script**. Cumulative v4 contains **103 source changes: 24 original-file modifications
and 79 additions**. All prior v1/v2/v3 changes are included.

**453 targeted tests passed** in a fresh run of the assembled cumulative package,
including **145 new identity/session tests**. Strict reference-client compilation,
configuration checks and 19 syntax/parse checks also passed. These counts do not
include unexecuted browser, Dart/Flutter, workerd, provider or production tests.

**No Google Drive upload or original-file replacement was performed.** Current full
Google Drive/Files discovery exposes reads only. The installed-provider search did
not expose an authorized write action. Prior denied writes were not retried or
worked around. v3 and v4 remain local downloadable packages, not saved source
updates in the authoritative Drive folder.

No resource provisioning, real message, identity import, operator enrollment,
remote SQL migration, existing-job change, app release, billing/secret operation,
financial writer switch or Supabase retirement occurred. The new configuration is
empty and disabled and uses a placeholder identity-database ID.

## 2. Source-grounded scope

The existing `packages/core/core_auth/lib/src/auth_repository.dart` was retrieved
again from Drive (file ID `1Zp71f8l9qpnKblsI2maOWgFP6PcRuLS6`). Its existing functions
include anonymous entry, WhatsApp-default phone OTP, phone changes and profile
hydration/restoration. The new candidate does not replace that file or pretend that
those flows have all been migrated. Its bytes were preserved in all four local
installation/rollback trials.

The implemented scope is **verified-phone sign-in for approved imported identities**
with explicit club bindings. It does not implement new signup, anonymous-to-verified
linking, phone-change/lost-phone recovery, full profile/bootstrap, account deletion,
staff role migration, native storage or actual provider delivery. Those remain
release-blocking workstreams, not hidden fallbacks to a partially working service.

## 3. Implemented components

| Component | Implemented behavior and boundary |
| --- | --- |
| Separate identity schema | Empty database schema with tenants, source UUID mapping, identities, club bindings, code challenges, phone/network controls, session generations, hashed refresh credentials and append-only audit events. It is not the public-content or financial schema. |
| Offline import planner | Exact source and mapping hashes, duplicate and eligibility checks, original UUID preservation, explicit reviewed club bindings, disabled tenants/grants and suspended users. It writes a new private parameterized plan, never executes or enables it. Only synthetic inputs were exercised. |
| Code request and verification | Six-digit random code, five-minute validity, client-verifier binding, keyed phone/code hashes, cooldown and layered attempt/send limits. Single-use verification commits with session/audit creation; user/club metadata cannot create or enable an identity. |
| Private delivery boundary | Exact `OTP_DELIVERY.deliver` contract and matching dispatch acknowledgement, eight-second timeout and explicit unknown state. No actual WhatsApp/SMS adapter, provider account or real message exists in this delivery. Missing or ambiguous delivery is not treated as verification. |
| Sessions | Independent opaque access/refresh tokens, five-minute access validity and seven-day absolute session lifetime. Every identity read checks current identity, tenant and club-binding revisions through a primary-first read. |
| Rotation and interrupted requests | Atomic credential rotation, same-request encrypted response recovery for two minutes, different-request refresh reuse revokes the family. No automatic client retry or silent new request key. Recovery is deliberately bounded, not unrestricted token reuse. |
| Revocation and tenant isolation | Current/other/all session revocation scoped to the authenticated user and current club. Disable/re-enable increments revisions so old credentials do not revive. Private identity lookup grants only `supporter:self`, not paid membership, staff or financial entitlement. |
| HTTP and reference client | Five versioned native-bearer endpoints, bounded JSON request/response handling, no cookies/CORS, exact origin, safe errors, strict response/identity correlation, no implicit write retry. TypeScript reference adapter is not integrated into Flutter or Next.js. |
| Privacy maintenance | Indexed selections scrub at most 500 expired encrypted recovery bodies per table and 500 old rate-window rows per run. This is not account deletion or a complete retention/archival service; historical source/audit rows remain. |
| Deployment controls | Disabled service/maintenance flags, placeholder isolated database, no public routes or provider bindings; ready-config checker never reports live identity/provider/runtime/approval as verified. |
| Source gate | Added auth regression, client-compile and disabled-config checks to the existing refactor gate without reducing the pinned web/mobile toolchain. |

Each source is under `cloudflare/supporter-auth/`, apart from the existing
`tools/scripts/run_refactor_checks.sh` integration. `batch4-changes.json` contains the
exact paths and before-v3/after hashes. Source additions do not apply database SQL.

## 4. Verified behavior and test totals

| Freshly executed group | Passed |
| --- | ---: |
| Repository boundary, economic-decision and public snapshots | 52 |
| Existing operator/API/controller/static-interface regressions | 163 |
| New supporter identity, HTTP, cryptography, import, client and contract regressions | 145 |
| Existing Python source/import/migration-control regressions | 60 |
| Installer and rollback regressions | 33 |
| **Total** | **453** |

Final failures and skips were zero. Nineteen additional syntax/parse checks passed,
including JavaScript modules, strict JSON, source-check shell syntax and verifier
Python syntax. Actual TypeScript compilation and previous generated-UI parity
checks passed separately; these checks are not extra unit tests in the total.

The new suite exercises valid and invalid code/verifier combinations, consumed-code
recovery, concurrent duplicate verification, cross-club denial, disabled/re-enabled
identities and mappings, expired code/session boundaries, resend-resistant phone
failure counts, rate limits, missing/ambiguous delivery, refresh reuse, simultaneous
refresh, current/other/all club-scoped sign-out, and response loss after commit.
Injected SQL failure tests cover every verification and refresh batch position.
Importer cases cover exact hashes, duplicate UUIDs/phones, unverified/anonymous/
banned/deleted identities and unexpected binding instructions. Contract checks
compare emitted field shapes and request arguments; they are not a general OpenAPI
or JSON Schema validator. Cleanup queries use the intended indexes in local SQLite.

All identities, code-delivery responses, network origins and credentials in these
tests are synthetic. No live user export was processed and no real telephone number
was messaged. Repeated operations produced one session/rotation effect in the
covered synthetic cases; this is not production concurrency or capacity evidence.

## 5. Environment and limitations

Executed with Node 22.16.0, Python 3.13.5, TypeScript 5.8.3, real Web Crypto and local
Node SQLite. The D1-shaped adapter uses genuine SQL/triggers but simulates D1
bindings, batch calls, race injection and delivery. The Cloudflare WorkerEntrypoint
wrapper was syntax-checked, not run under workerd. References to primary-first
reads and batch rollback follow platform documentation and local API-shaped tests;
actual deployment, scheduling and replication behavior still need staging proof.

No installed Wrangler/workerd, Dart/Flutter, complete pinned Next.js environment,
real delivery provider, native secure storage, device build or real access workflow
was tested. Existing higher pinned toolchain requirements remain unchanged. The
prior 13 operator browser cases blocked by administrator policy were not rerun; no
browser policy was changed. Existing public-source regression tests ran, but the
actual 2,628-row saved public export and 11 originals were NOT replayed again in
this batch. Their previous replay results remain dated historical evidence.

This custom bearer protocol is not OAuth/OIDC or a NIST certification. Phone codes
are not phishing-resistant. Recycled numbers, SIM/provider compromise, lost-phone
recovery and appropriate risk assessment are unfinished. The pilot rate limits are
not approved production capacity. A same-request recovery window can benefit an
attacker who steals both the consumed credential and original request identifier;
native secure storage and single-flight operation recovery remain mandatory.

Sensitive encrypted response copies are short-lived and bounded, but UUIDs and
HMAC lookup values remain personal data. Key rotation, challenge/token-history
retention, complete deletion/archival, abuse alerts and operational recovery still
require implementation. The source disables deletion of retained audit/mapping rows
rather than falsely claiming to satisfy every privacy requirement.

## 6. Cumulative source installation and rollback

The exact 103-file payload passed read-only preflight, application, all after-hash
checks, idempotent reapplication and rollback against four disposable source states:

| Starting state | Changed | Already matching |
| --- | ---: | ---: |
| Original scoped baseline | 103 | 0 |
| v1 source already applied | 58 | 45 |
| v2 source already applied | 48 | 55 |
| v3 source already applied | 21 | 82 |

All rollback trials restored every starting source byte, including the separately
retrieved unchanged Flutter auth repository. The installer refuses unrecognized
changes and journals the actual existing version. These are local scoped trials,
not updates to Drive or a complete production backup. The manifest hash in the
trial evidence binds those results to this precise source manifest.

The installer is unchanged from v3. Cumulative manifest entries recognize the
previous exact source-check versions; it does not authorize arbitrary merges.
Individual file writes are atomic, but a multi-file install is not globally atomic
for concurrent readers: stop source editors and builds. Retain the rollback journal.
No script application here modifies a database, provider, account or deployment.

## 7. Remaining work

R07 advances from not implemented to **imported verified-phone/session candidate
implemented locally**, not a completed auth migration. Actual delivery, full auth
journey parity, reviewed production UUID/tenant import, native storage and typed
client integration remain unfinished. The reference TypeScript client advances a
subset of R10 only. The private delivery contract and optional maintenance handler
do not claim completion of R09 or any of the six existing scheduled jobs.

R01 still requires authorized Drive writing/source integration. R05 still requires
browser and real staging acceptance. R06 dispositions, transactional payment/
membership/stock/ticket/FET implementation, provider/function/job migration, full
repository cleanup, visual/mobile acceptance and the final consistent backup/media
recovery remain. Predict/FET policy approval is unresolved. No new inference that
the eight missing AFRICLUB originals were recovered is made.

Do not enable the candidate or remove Supabase until the incomplete flows, real
runtime/provider tests, final reconciliation and release gates are resolved.
Production cutover and retirement remain blocked and unperformed.

## 8. Delivery and use

`AFRICLUB_Cumulative_Source_Patch_v4_2026-09-26.zip` contains all earlier changes plus
this batch, exact source paths and hashes, reversible installer, evidence, source
runbook, disabled configuration and remaining-actions register. It excludes raw
identity exports/plans, real credentials, media, databases, dependency caches and
font files. The companion verification JSON records local file hashes and current
scope; it is not a Google Drive delivery receipt.

Use v4 instead of applying v1/v2/v3 afterward. From the extracted package directory:

```sh
python3 apply_patch.py --root "/path/to/AFRICLUB"
python3 apply_patch.py --root "/path/to/AFRICLUB" --apply
python3 verify_bundle.py --results "/tmp/africlub-v4-verification"
```

## Primary references checked 26 September 2026

- D1 batch/sessions: https://developers.cloudflare.com/d1/worker-api/d1-database/
- D1 read replication: https://developers.cloudflare.com/d1/best-practices/read-replication/
- Web Crypto: https://developers.cloudflare.com/workers/runtime-apis/web-crypto/
- NIST SP 800-63B-4: https://pages.nist.gov/800-63-4/sp800-63b.html
- OAuth rotation/replay guidance used as background, not protocol-compliance proof:
  https://www.rfc-editor.org/rfc/rfc9700.html

The decisions and pilot constants above are implementation choices. Sources do not
establish that this particular service is live, compliant, secure against every
threat, or authorized for release.
