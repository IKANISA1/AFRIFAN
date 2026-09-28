# AFRICLUB — production-remediation implementation

**28 September 2026 · source-only candidate · production release remains blocked**

Authoritative Drive folder: `1izZgoOKfEONHZTyHkE0MzBW9Eeo4-VeH`.
This continuation implements source changes arising from the 27 September audit.
It does not reclassify prior source archives, test counts or report text as a deployed
release, an accepted financial migration or evidence of real provider settlement.

## 1. Delivered state

The delivery contains a **169-path source overlay** and **113 exact-hash unchanged
prerequisites**, assembling a **282-file scoped source candidate**. Within that
candidate, **57 files were newly authored or revised in this continuation: 24
additions and 33 revisions**. The other overlay paths carry selected earlier fixes
and their dependencies into their canonical paths instead of leaving them as
unreferenced revised siblings. The overlay is not a full monorepo export.

Thirty critical source files were downloaded afresh from Drive, including the
current public reader, boundary validator, identity service, operator API, web
configuration, CI/deployment workflows, client source and root toolchain pins. The
remaining scoped context comes from checksum-verified earlier packages; it was not
silently described as a fresh complete checkout. `fresh-source-register.json`,
`assembly-provenance.json` and `source_reconciliation.json` record the distinctions.

**No files were uploaded or changed in Google Drive in this continuation.** The
available Google Drive and Files actions exposed reads/materialization, but no
upload, source update or permission-management action. The plugin-directory lookup
returned the same installed connection, and final upload-action discovery again
returned nothing. This is a tool-capability limitation, not an assertion that the
user lacks Drive edit permission. The supplied upload register contains every
payload destination, checksum and known original file ID.

The root folder still reported `anyone / writer / allowFileDiscovery:false` in
fresh metadata. No sensitive key/environment contents were read. No permission was
changed, no credential was rotated, and no unauthorized access or actual credential
use was established. Restrict and review that access before trusting the folder as
a release source. The local scanner and runbook are not remediation of the ACL.

## 2. Implemented source changes

### 2.1 Canonical source convergence and public publishing

The proposed canonical public reader and operator service now use the previously
implemented immutable approved-snapshot model. This removes reliance on the newest
timestamp anywhere in the import tables. The same approved/fresh snapshot governs
the nine public content routes and rights-eligible media. Media bytes must agree
with the recorded digest; equal size alone is insufficient.

Additional response-boundary checks reread the active snapshot after content/media
loading, reject a changed or removed head, repeat freshness validation and recompute
cache lifetime immediately before returning. A concurrent publication can therefore
produce a safe service error rather than present a knowingly superseded head as the
current content. This is still a point-in-time response, not an atomic transaction
with a user's browser cache or a forever-valid media-rights assertion.

The proposed `cloudflare/operator-api/src/index.mjs` includes the selected archived
API/UI assembly and its strict publication operations. The route in this candidate
is `/operator/clubs/24/public-source`. `CONSOLE.md` now describes that actual assembly
and does not claim the old standalone wrapper/configuration or an embedded Next.js
PWA screen is installed. The current UI assets agree with their source generator.
The API and UI remain disabled unless explicitly configured.

The selected public/operator suite passes 194 tests, including five additional
response-boundary cases. These tests use real local SQL and byte hashes with
synthetic bindings. No actual Cloudflare publication, R2 upload, source refresh or
production content promotion occurred.

### 2.2 OTP isolation and cost control

The previous ten-per-minute shared issuance rule could let one club consume another
club's allowance. The identity service now requires an explicit issuance policy
for new challenges: a global provider-cost ceiling, per-club ceilings and per-club
IP limits. A phone's shared anti-abuse budget remains intact across clubs; changing
clubs is not permission to send unlimited codes to one number. Invalid/missing
policy or an unconfigured club fails closed for new issuance.

The validation rejects unknown keys, non-integer/out-of-range budgets, invalid club
IDs and club-cap allocations exceeding the global ceiling. Existing transactional
rate/account checks remain. This does not invalidate already issued sessions merely
because a new policy is absent.

Thirty-one additional policy/fairness tests pass, with 108 total current auth tests.
The controlled regression shows Rayon cannot exhaust Nkana's club/IP allowance.
The values in synthetic fixtures are not measured game-day capacity or a production
policy. Provider throughput, shared-network fairness, policy changes mid-window,
queue fairness, WAF and actual abuse/cost monitoring remain operational work.
No real code was sent and no provider setting was changed.

### 2.3 Server-authoritative payment handoff journal

A forward-only migration, `0003_payment_handoff_journal.sql`, adds a private journal
in the **same allocation/checkout database**. Existing migrations are preserved.
It records an immutable reservation, one active user/club head, an immutable claim
and an audit trail. A claimed but unallocated order cannot be cancelled merely to
replace its checkout, and retained claims cannot be erased to permit another use.

The journal does not take payment, allocate evidence, activate membership, issue a
ticket, change points, or call a carrier. It records that a client may have attempted
a handoff. Only the first successful claim response can return
`mayOpenDialer:true`. Every repeated claim, including the original request key,
returns read-only state and **never grants another dialer opportunity**. A lost
response after commit is therefore conservative: the claim may remain unresolved.

The current payment allocator still owns evidence matching and financial/member
fulfillment. An allocated order resolves the journal's status; a claim itself is
never treated as payment evidence. Current principals, user/club scope, order state,
configuration revisions and expiry are checked during database mutations.

The three new gateway operations are authenticated native-bearer routes under
`/v1/supporter/clubs/{clubId}`:

| Method/path suffix | Purpose |
| --- | --- |
| `GET /membership/handoffs/current` | Read the current user's server journal without sending or preparing anything. |
| `POST /membership/handoffs/reservations` | Reserve an owned order using the original UUID operation key. |
| `POST /membership/handoffs/claims` | Record one claim; a repeated response never regrants permission to dial. |

The gateway derives the user from the identity service. Caller-selected user, club
claims, price, recipient, public SQL and browser-cookie fallbacks remain rejected.
The OpenAPI contract now covers seven paths, and a separate private journal contract
records precise fields. The new capability is exposed only through the existing
private checkout/read interfaces, not a public financial command endpoint.

The TypeScript controller persists local recovery state, reserves and claims on the
server, then rechecks session, lifecycle generation, elapsed time and current
instructions before one external application call. Recovery reads the server even
when local storage is empty. Opening an application, resuming the app, receiving a
transport acknowledgement or expiring an order does not verify payment.

The matching Dart API/models/controller and three additional authored harness cases
are included. **No Dart test, Flutter build or native platform call was executed.**
The required SDK is absent. The existing native entrypoints remain opt-in and are
not composed into the five applications in this continuation.

Seventy-one journal/gateway tests pass, including three races on independent SQLite
connections in separate worker threads. Additional existing client/handoff tests
exercise actual local identity, checkout and allocation services. The tests include
lost responses, wrong ownership/club, duplicate and competing claims, claimed-order
cancellation and an opaque D1 statement adapter. The latter exposed and helped remove
an initial dependency on test-only `.sql`/`.args` fields; the final service uses only
the real prepared-statement API and explicit assertion IDs.

**Limits remain important.** A crash can strand an unclaimed reservation or a claimed
but unsent handoff. The reference client conservatively blocks every unallocated
server head; a complete operator/explicit-resumption and late-payment resolution
workflow is not supplied. Old app versions or manual payments that ignore this
journal are outside its protection. Minimum-client admission, retained historical
claims and unresolved-payment reconciliation are required before cutover. The
journal does not make separate identity and financial databases one transaction;
the cross-database revocation interval remains. A sufficiently late revocation can
leave a claim committed while its response is withheld.

### 2.4 CI, immutable artifact promotion and source controls

The Next.js configuration no longer ignores TypeScript build errors. This restores
failure behavior rather than declaring the original build-generation race solved;
full pinned Next.js build evidence remains necessary.

The independent deployment workflow is replaced in source with a reusable promotion
workflow. It is called only after the named current CI jobs succeed, only for the
main-branch candidate, and only when the explicit promotion switch is enabled. It
uses a protected `africlub-production` environment and the same run's sealed OpenNext
artifact. The promotion job does not rebuild a different source candidate before
publication.

`release_artifact.py` binds the source commit, CI run, exact build/control files and
per-file digests. Verification rejects digest mismatches, wrong commits/runs,
unsafe/duplicate ZIP paths, symlinks, unexpected controls and oversized archives.
Extraction is into a fresh destination. `release_evidence.py` requires a fresh,
candidate/digest-bound envelope with all required named approval gates. **An envelope
or operator-entered name is not independent proof of approval**; its origin and the
protected environment still require owner administration and audit.

A combined `verify_converged_source.py` is registered through Melos/CI. It preserves
the exact existing Node and mobile SDK requirements and records missing or wrong
runtimes as blocked. CI now includes backend source gates, pure-Dart verification,
and the portable Swift check within the iOS job. No real GitHub workflow, branch
protection, environment rule or repository setting was created or run here.

Four action versions in the new promotion path are pinned to verified commit SHAs;
that is not a claim of completed supply-chain review of every pre-existing action.
The source security guard checks tracked/new Git source, private environment/signing
paths, private-key material and classified privileged tokens without printing the
matched values. It does not inspect ignored files unless tracked, certify all
historical archives, revoke secrets or change Drive sharing.

The boundary validator retains positive football-module preservation while tightening
its narrowly registered legacy references: exact path/hash, valid date, finite entry
count and symlink checks. No broad documentation exclusion or suppression of retired
runtime features was introduced.

## 3. Final executed evidence

All counted suites below completed. Repeated and focused-subset executions are not
added together, and authored but unexecuted platform/Dart cases are excluded.

| Group | Passed |
| --- | ---: |
| Six backend-module groups plus boundary/economic-decision Node tests | 1,378 |
| Python source/import/security/artifact/evidence/CI tests | 156 |
| Portable Kotlin/JVM recovery tests | 69 |
| Portable Swift recovery tests | 68 |
| Reused installer/rollback unit tests | 33 |
| **Unique targeted tests passed** | **1,704** |

The exact packaged payload was installed into disposable source roots before the
final contract, native-portable and installer runs. Strict TypeScript compilation,
UI asset parity and all six relevant disabled service/configuration checks passed.
The 282-path scoped sensitive-source scan passed; it is not a fresh scan of the full
Drive folder or Git history. YAML parsing and final source syntax results are kept
as separate checks, not counted as additional tests.

Two implementation/testing issues were corrected rather than hidden: the D1 adapter
dependency described above, and a receipt-integration fixture whose synthetic
approval expiry no longer matched its shifted clock. The latter was corrected in
fixture setup; the production expiry rule was not relaxed. An initial delivery
verifier expected the installer's conflict exit code to be 1; the installer actually
uses 2. The verifier was corrected and all final conflict/rollback tests rerun.

The installer scenarios are:

| Selected local starting state | Actual source files changed | Outcome |
| --- | ---: | --- |
| Known-hash scoped baseline | 160 | Repeat writes nothing; rollback restores every starting byte. |
| Alternating overlay files already matching | 79 | Already-present entries retained; rollback restores the mixed baseline. |
| Every overlay entry already matching | 0 | No source mutation. |

There are 169 overlay entries, but nine already match the selected baseline. These
are local reconstructed states, not modifications or readback acceptance of actual
Drive files. Unknown source edits stopped preflight and remained unchanged. Individual
file replacement is atomic; the full multi-file update is not one globally atomic
filesystem transaction. Stop source editors/builds and retain the rollback journal.

## 4. Release gates that did not pass

The strict combined gate returns **blocked**, not green:

- Local Node is **22.16.0**; the unchanged repository `.nvmrc` pins **22.23.2**.
  The targeted Node executions are explicitly non-pinned evidence. The required
  release exists upstream, but SDK download attempts did not install it here.
- Dart/Flutter are absent. The unchanged minima are Dart **>=3.10.0 <4.0.0** and
  Flutter **>=3.38.0**. No analyzer or test result is invented for authored Dart.
- Chromium navigation to the local authenticated operator fixture was rejected with
  `ERR_BLOCKED_BY_ADMINISTRATOR` before page load. No policy was changed or bypassed;
  no rendered page, accessibility, screenshot or interactive-browser pass is claimed.
- Portable Kotlin/Swift exercise genuine local crypto/files/locks, not actual Android
  Keystore, Apple Keychain, app entitlements, signed binaries or physical handsets.
- No full monorepo Flutter/Next.js/pgTAP run, actual workerd/D1/R2 validation, live
  provider, game-day capacity, independent security assessment or five-club UAT ran.

The local environment was Node22.16.0, Python3.13.5, TypeScript5.8.3, Kotlin/JVM1.9.0,
OpenJDK21 and Swift6.2.1 Linux. The portable compilers do not replace the application's
Android/iOS toolchain. All provider/deployment/migration/payment action counts are zero.

## 5. Task status and scope still outstanding

The updated register preserves **all 130 audit IDs, dependencies and acceptance
criteria**. **Twenty-one tasks have documented partial local implementation and
remain In progress; 109 remain Open; zero are release-accepted or Closed.** This is
not a reset of implemented product code. It distinguishes useful source progress
from the unmet acceptance evidence in the original audit.

The continuation does not complete browser member authentication, protected native
credential storage, all app compositions and accessible confirmation screens,
phone-change/lost-phone/account linking, real provider evidence, full contribution
rewards/referrals, refunds, ticket/shop fulfillment, downstream account erasure,
observability/on-call operations, actual data import/history reconciliation, the
blocked media originals, full restore/cutover drills or source retirement. It also
does not grant data-location, legal, financial, brand, store or Predict/FET approval.
Those tasks cannot be truthfully closed by source generation or synthetic tests.

## 6. Safe source application and delivery

`files/` contains the overlay at intended repository-relative paths. `context/`
contains the exact selected pre-change/unchanged test context, not a replacement
monorepo. The installer checks all prerequisites and recognizes only listed before
hashes. Do not copy the context directory over a live checkout or bypass a conflict.

```sh
# With builds/editors stopped, against the full controlled checkout:
python3 apply_patch.py --root "/path/to/AFRICLUB"
python3 apply_patch.py --root "/path/to/AFRICLUB" --apply

# Resource-bounded independent verification phases:
python3 verify_bundle.py --phase contracts --results /tmp/africlub-contracts
python3 verify_bundle.py --phase installer --results /tmp/africlub-installer
python3 verify_bundle.py --phase native --results /tmp/africlub-native
```

Exit 2 from the bundle/native source verifier records a blocked runtime gate; exit
2 from `apply_patch.py` denotes a stopped/conflicting patch operation. Inspect the
JSON/log before proceeding. No script installs SDKs, applies remote SQL, enables
flags, provisions keys, dials, sends messages, deploys or retires Supabase.

The proposed Drive delivery directory is
`AFRICLUB/output/production-remediation-2026-09-28/`. The manifest lists intended
canonical source destinations separately. **Neither destination has been written
in this continuation.** Existing Drive originals, permissions and previous archives
remain unchanged. Older historical packages must not be applied over this selected
candidate without reconciliation.
