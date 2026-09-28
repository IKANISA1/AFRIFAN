# AFRICLUB — Remediation continuation 02

**28 September 2026 · locally tested source · not uploaded or deployed**

## Delivered scope

This continuation adds **18 new source files and modifies 31 previous candidate files**
(**49 authored changes**). One additional already-existing Drive index is included byte-for-byte
without claiming it as new implementation. The delta from the previous local candidate is
therefore **50 paths**. The cumulative package provides **194 source-overlay paths and 107
exact-hash unchanged prerequisites**, assembling a **301-file scoped candidate**, not a full
monorepo or an automatically accepted production commit.

The previous unuploaded remediation deliverables are preserved unchanged in `prior_delivery/`.
Their reports describe their original status and their earlier test totals; neither is a
current deployment receipt. The new package accepts the exact previous candidate as an upgrade,
retains a rollback record, and stops on unknown edits. Do not copy the context/previous-candidate
directories over a live repository or apply older cumulative archives over these newer files.

**No Drive writes occurred.** The connected toolset exposed read operations but no file creation,
upload, update or permission-management action. Plugin discovery returned the same installed
Google Drive connection. The intended destination is `/Google Drive/AFRICLUB/output/production-remediation-2026-09-28/continuation-02-reliable-delivery-handoff`; it has NOT been created here.
`UPLOAD_PENDING.json` records intended individual source paths and packaged catch-up files.
This is a tool-capability limitation, not a statement that the user lacks Drive edit rights.

Fresh root metadata still reports an `anyone` permission with role `writer` and
`allowFileDiscovery:false`. No permission was changed, no credential was rotated, and no actual
unauthorized access was established. Key/environment contents were not opened. Restrict and
review sharing before treating the Drive folder as a trusted release source.

## 1. Reliable authentication-code dispatch

The old queue could default to the legacy sender, allow one club's due work to occupy a whole
drain, and count acceptance after an unchecked final database update. The candidate now requires
an explicit private-deduplicated mode, a reviewed bounded queue policy and enabled SQL control.
Missing or malformed policy, unsupported mode, missing private service, or disabled control
blocks sending. The deployment templates remain disabled.

A forward-only `0003_reliable_delivery_control.sql` preserves existing migrations and adds a
persistent per-club scheduling cursor, immutable attempts/outcomes and a quarantine record for
previously attempted legacy work with no safe deduplication journal. The existing
`0002_club_delivery_index.sql` was freshly retrieved and retained unchanged. Old accepted records
are not re-sent or rewritten as new work. Already-attempted unconfirmed legacy rows are
quarantined rather than retried through an incompatible sender.

For each eligible challenge, the lease, immutable attempt and scheduling turn commit before the
private service call. The pre-send check uses a **new first-primary D1 session**, verifies the
current account/club/lease/settings, and checks the remaining code lifetime. A primary-start
session is not described as forcing every later query to primary. Permissions can still change
after the last read and before an external call; no distributed atomicity is claimed.

The provider timeout is bounded and explicitly does **not** cancel remote work. Retrying a
known new attempt uses the same durable challenge identity at the existing deduplicated private
sender. It never invents another provider dispatch to resolve uncertainty. Local acceptance,
immutable outcome and ciphertext clearing commit together. Zero-row updates, lost leases and
post-commit response loss are distinguished; the summary no longer counts an unchecked write
as accepted. Provider acceptance is not handset receipt, login, membership or payment evidence.

The runtime uses per-club/per-run budgets and persistent least-served scheduling, with at most
20 selected dispatches per drain under the validated policy. Cleanup and health reads are
bounded, but configured bounds do not prove game-day fairness, latency, read costs or D1 plan
capacity. Old executables must be frozen/drained before adopting these tables; the new source
cannot stop an old worker that bypasses its journal.

## 2. Secret expiry and private queue health

Scheduled maintenance attempts transient-secret expiry and dispatch independently. A sender
configuration failure or paused delivery does not suppress expiration. Ciphertext expiry needs
the database, not decryption keys, provider credentials or an active sender binding. Fixed errors
avoid exposing SQL/provider diagnostics, while rejected maintenance still signals an incomplete
scheduled run rather than false success.

The new `OtpQueueHealthReader` is a private service interface with an HTTP-404 wrapper. It returns
configured-club counts, whether counts are capped, oldest pending timestamps and control state.
Counts saturate at 1,000; no phone, code, user, challenge, bearer token or provider message ID is
returned. Its independent disabled configuration contains no sender binding, public route or
schedule. A monitoring consumer must still be securely authorized. These reads are bounded
observations, not an atomic cross-query snapshot, a deployed dashboard or a monitoring SLA.

Audit/attempt/quarantine retention, approved erasure, poison-event adjudication, operational
alerts, live Cron subscriptions and provider reconciliation remain separate tasks. No row was
removed from a real identity database and no real code was sent.

## 3. Explicit release of never-claimed handoffs

The previous journal could strand a reservation after a crash before its claim. A new
`0004_release_unclaimed_handoff.sql` supplies a narrowly scoped recovery operation in the SAME
checkout/allocation database. It starts disabled in SQL and requires separate runtime and
gateway switches. No original migration, reservation, order, claim or financial record is deleted.

Only the authenticated owner may release the current reservation while it has **never been
claimed and has not been allocated**. Current principal/user/club permissions are checked at
the mutation boundary. The release is immutable, identified by the original operation key and
recorded with actor/time/reason. Reverse claim/release guards make racing commands mutually
exclusive; a released reservation can never later be claimed by a stale device.

The native gateway adds:

`POST /v1/supporter/clubs/{clubId}/membership/handoffs/releases`

with only `handoffId`, the original UUID Idempotency-Key and existing native bearer/session
headers. User identity is derived on the server. The added state `released` never grants
`mayOpenDialer`. Exact-key replay returns retained state; a conflicting key is rejected. A
subsequent genuine payment can still allocate the original order, and historical release can
then be viewed alongside its allocated state.

The strictly compiled TypeScript client/coordinator implements an explicit acknowledged action.
It rechecks the server head, actor and lifecycle, refuses claimed/allocated/changed heads and
local opened/unknown attempts, and reuses the handoff ID as its deterministic release key.
After authoritative confirmation, only a matching local reserved marker can become not-opened.
Storage failure preserves uncertainty for explicit same-operation recovery. Restore, polling,
app resume, constructors and timers do not release, prepare another checkout or open a dialer.
A later handoff still requires new review and independent confirmation.

Matching Dart API/models/controller and **three authored harness cases** are included but were
not executed without Dart/Flutter. No accessible confirmation screen, route or five-club app
composition was installed. The new OpenAPI contract describes eight native paths, not a public
payment-confirmation or refund endpoint.

**This is not a claim that no money moved.** It proves only that this journal never granted its
claim. Manual payments, older clients and arbitrary software outside the protocol are not ruled
out. A claimed-but-unsent attempt, uncertain payment, partial/late/duplicate/cancelled-order
payment or refund still needs separately governed financial reconciliation. Expiry alone cannot
release a claimed operation. The identity/financial cross-database revocation interval also
remains; a response withheld after commit does not erase a committed operation.

## 4. Verification actually executed

| Executed group | Passed |
| --- | ---: |
| Backend, gateway, client, queue, journal, publication and boundary Node tests | 1,556 |
| Python source/import/security/artifact/CI tests | 156 |
| Portable Kotlin/JVM recovery tests | 69 |
| Portable Swift recovery tests | 68 |
| Installer/rollback tests | 33 |
| **Unique targeted passing tests** | **1,882** |

There are **178 newly added Node tests** compared with the previous candidate. Every counted
suite completed with zero failures, skipped, cancelled or todo cases. Repeated runs and separate
syntax checks are not added to this total. **188 syntax/parse checks** also passed,
along with strict TypeScript client/controller compilation, operator asset parity, disabled
configuration checks and a sensitive-source scan of the scoped 301-file candidate.

The queue and release suites execute genuine local SQLite SQL/triggers, cryptographic operations
and independent database connections in worker threads. They cover lease competition, cross-club
fairness, original dispatch identity, timeouts, account/tenant revocation, zero-row acknowledgements,
rollback at batch positions, lost responses, quarantine, secret expiry without keys, health
redaction, release/claim races, wrong owners, request conflicts and recovery without dialer calls.
The gateway/TypeScript integration uses synthetic identities and simulated transport/bindings.
This is NOT a real workerd/D1/Meta/carrier, app-store, browser or physical-device acceptance run.

Five reversible local source scenarios passed:

| Starting source | Files changed | Outcome |
| --- | ---: | --- |
| Selected original known-hash baseline | 185 | Repeat is a no-op; rollback restores starting bytes. |
| Alternating new overlay already present | 93 | Existing matching files retained; rollback restores mixed baseline. |
| All overlay files already matching | 0 | No source writes. |
| Prior 282-file remediation candidate | 50 | Recognized upgrade; repeat no-op; exact rollback. |
| Prior candidate plus unchanged current Drive index | 49 | Existing index retained; recognized upgrade and rollback. |

Unknown independent edits stop installation and remain untouched. These are disposable local
trials, not edits to the actual repository. The package installer changes only checked local
files; it never applies SQL, provisions resources, sends codes/payments or changes sharing.

Test-development corrections are retained in intermediate logs: an old queue fault injection
was updated to target the actual transactional batch; the retired legacy-default assertion was
replaced by explicit no-fallback tests; the OpenAPI path assertion changed from seven to eight
with a real release-path contract check; duplicate expiry indexes were removed rather than
weakening the existing query-plan assertion. The first packaging attempt called a nonexistent
validation helper; it was corrected to the existing `read_manifest` helper before the package
runs. No incomplete or initially failing run is counted as a pass.

## 5. Source authority and release limits

Five narrow current Drive files were materialized/read for this continuation. The old queue,
private sender and scheduled wrapper match their preserved before-source. The current Drive
identity service remains older than the prior locally remediated candidate; that local policy
fix was preserved rather than downgraded. The existing club-delivery index was added unchanged.
All remaining context is inherited exact-hash source, NOT a fresh full-repository export.

The release gate remains **blocked**. Local Node is 22.16.0; the unchanged repository pin is
22.23.2. Node evidence is explicitly non-pinned. Dart/Flutter are absent; required minima remain
Dart >=3.10.0 <4.0.0 and Flutter >=3.38.0. The portable Kotlin/Swift tests were compiled afresh,
but Android/iOS hosts, platform secure storage, signed apps and real devices were not tested.
The inherited browser-policy blockage was not retried or bypassed. Full Next.js, Flutter,
pgTAP, production capacity, independent security and actual Cloudflare/provider tests did not run.

All 130 original audit task IDs, ownership roles, dependencies and acceptance criteria are
preserved. **26 are In progress and 104 remain Open;
zero are release-accepted or Closed.** Progress notes identify the narrow source contribution,
not completion of broader financial, privacy, operations or native acceptance.

Remaining requirements include restricted sharing and credential assessment, canonical protected
source convergence, native credentials and UI/app composition, browser sessions, lost-phone and
linking flows, cross-database authorization guarantees, complete erasure/retention, authentic
payment evidence, refunds and financial exceptions, contributions/rewards/referrals, tickets/shop,
real monitoring/on-call, complete historical data/media reconciliation, restore/cutover drills,
country/store/brand approvals and controlled single-writer migration. Supabase retirement is not
authorized or performed by this source package.

## 6. Delivery and use

Run from the extracted package with editors/builds stopped:

```sh
python3 apply_patch.py --root "/path/to/AFRICLUB"
python3 apply_patch.py --root "/path/to/AFRICLUB" --apply
python3 verify_bundle.py --phase contracts --results "/tmp/africlub-02-contracts"
python3 verify_bundle.py --phase installer --results "/tmp/africlub-02-installer"
python3 verify_bundle.py --phase native --results "/tmp/africlub-02-native"
python3 tests/verify_previous_upgrade.py --results "/tmp/africlub-02-upgrade"
```

Verifier exit 2 means a blocked release runtime; installer exit 2 means a stopped/conflicting
patch. Read its JSON/log rather than bypassing a failure. Local individual file replacement is
atomic, but the whole multi-file operation is not a transaction for concurrent readers.
`PRIMARY_REFERENCES.json` records primary platform guidance separately from local evidence.

**Source is complete for the scoped changes described above. Upload, deployment, broad production
implementation and release acceptance are not complete.**
