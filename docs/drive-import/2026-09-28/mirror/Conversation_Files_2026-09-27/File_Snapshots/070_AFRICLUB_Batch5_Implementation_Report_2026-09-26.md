# AFRICLUB — batch 5 WhatsApp delivery and Drive reconciliation

Date: 26 September 2026. Workspace: AFRICLUB, Drive folder
`1izZgoOKfEONHZTyHkE0MzBW9Eeo4-VeH`.

## 1. Delivery state

Batch 5 implements **17 source changes: 16 additions and one modification** to the
currently observed queued authentication service. **Sixteen additions were uploaded
directly to their correct source paths and all sixteen passed SHA-256 readback.**
The one existing-file modification is saved as a tested proposed replacement and
inside the incremental source patch; it is **not installed into the existing file**.

The Drive update action advertises a string file reference, but its implementation
requires an object. A serialized reference was rejected by the action and the same
object was rejected by the schema. Both attempts stopped before mutation. This is
not a successful source update and is not the earlier permission error. The current
`cloudflare/supporter-auth/src/delivery.mjs` was downloaded after those failures;
its original hash remained `a28aee4ebae173e857a8f055b6f019ba435a717221e58df5be3cf031c90f56a5`.
The tested replacement hash is
`29439e44d9efc0b54f4c8b058e70eb2b2f20205ceaeaa8502d6c013079b3196d`.
The original Drive ID is preserved. No deletion, rename or same-name substitute
was used to bypass that failure. A before-source archive was saved before the
attempt and its uploaded bytes were verified.

All eight historical v3/v4 deliverables are now present in Drive and match their
conversation copies by checksum. The four v3 files were already present when this
turn inspected the folder. The four v4 files were uploaded during this turn.
Their reports remain dated historical records; the new verification receipt
records the corrected current delivery state without rewriting that history.

## 2. Important source-authority correction

The current Drive `supporter-auth` module differs materially from the prior v4
archive. It already includes a leased WhatsApp queue, ten-minute codes, 60-second
credential recovery, secure-refresh coordination and pending-erasure requests.
Those are pre-existing current-source capabilities, not new achievements claimed
by this batch. Its README, runtime files, schema and focused tests were read and
preserved. No complete new authentication replacement was introduced.

**Do not apply the historical v1-v4 cumulative packages over this newer current
source.** Batch 5 is an incremental, exact-hash patch against the observed Drive
baseline, not a cumulative v5 upgrade from v4. An installer conflict means stop
and reconcile, not force an overwrite. The patch retains the current before-bytes,
source IDs and hashes. It does not rewrite the existing identity schema, erasure
behavior, five supported clubs, feature economics or client interfaces.

## 3. Implemented behavior

| Component | Implementation |
| --- | --- |
| Private provider service | Named `AuthenticationCodeDelivery` Worker RPC; normal and named HTTP entrypoints return 404. Only a reviewed private binding should call it. |
| Current queue integration | An explicit `AUTH_DELIVERY_MODE=private-deduplicated` chooses a private sender. Omitted mode keeps the existing legacy path. Unknown modes and missing private bindings stop before lease acquisition. |
| Server-owned lineage | Queue challenge ID, club, expiry and template are passed with phone/code. The adapter rejects mismatched template, club and request fields. No client-selected actor grants authority. |
| Durable attempt boundary | A unique dispatch claim is inserted before any provider request. Request and route are HMAC-bound. A repeated queued attempt cannot cause another external submission for that challenge. |
| Provider validation | Fixed Graph origin, explicit version and numeric IDs, no redirects, six-second deadline, 16 KiB JSON limit and exact recipient/message correlation. |
| Template check | GET metadata must match configured ID, name, English edition, AUTHENTICATION category and APPROVED state before POST. Button anatomy, expiry wording, sender ownership and consent are still separate live approval gates. |
| Interrupted-response handling | Accepted receipts are persisted before acknowledgement. Queue retries can recover a known immutable receipt after an auth database write failure. Unknown outcomes remain unconfirmed and are not externally resent. |
| Privacy and configuration | No raw phone, code or provider credential is written to dispatch storage. Logging is disabled in the shipped private template. Configuration is empty/disabled with an isolated placeholder database. |
| Offline tools and contract | A private RPC contract, disabled/ready configuration checker and GET-only provider-inspection command. Inspection defaults to zero network; no real provider inspection was performed. |

The existing body/code plus copy-code URL button payload was retained from the
current source `cloudflare/supporter-auth/src/whatsapp.mjs`. The adapter tightens
acceptance validation rather than selecting a different authentication product.
No actual message was sent, template created, sender enrolled, consent granted,
billing changed or live provider account accessed.

## 4. Semantics and operational limits

A provider acceptance is not handset delivery or successful authentication. The
existing identity service still verifies the actual code and owns session creation.
No member entitlement, balance, permission or financial outcome is granted by this
transport. The tests prove that accepted delivery alone creates no account/session.

A crash after reserving but before sending may strand an unsent code. This is the
intentional availability trade-off for refusing an automatic second external
attempt when the original outcome cannot be known. It is not end-to-end exactly-
once delivery. The external provider and two databases do not share a transaction.

The current auth drain still has its existing three-attempt lease behavior. In
private mode those internal retries return a known provider receipt or fail without
sending again. Do not downgrade an in-flight private queue to legacy: the legacy
provider does not consult the new dispatch claims. Freeze/reconcile or expire
pending challenges under an approved recovery procedure before a mode change.

Claims and acceptance IDs are retained. HMAC lookup values and source identifiers
remain linkable information, not anonymous data. Retention, deletion, online key
rotation, delivery-status webhooks, monitoring/spend controls and SMS fallback
remain unfinished. The review-reference string is not proof of actual review.

## 5. Executed checks

The current Drive baseline's identity, delivery and HTTP subset first passed its
**77 existing tests unchanged**. The reconciled package then passed:

| Test group | Passed |
| --- | ---: |
| Current Drive identity, delivery and HTTP regressions | 77 |
| New provider, configuration, contract and current-queue integration tests | 124 |
| Reused installer and rollback regressions | 33 |
| **Total targeted tests in this batch** | **234** |

Final failures and skips were zero. Fourteen additional JavaScript/JSON syntax or
parse checks and the disabled configuration check passed. Downloaded Drive source
payloads independently repeated all **201 code tests**. These repeated executions
are not double-counted in the 234 total. The historical v4 total of 453 is not added
or presented as proof for a different current-source implementation.

New tests cover duplicate drains, changed request/route conflicts, missing binding,
wrong template/recipient, rejected/held/oversized provider replies, expiry, timeout,
no late send after timeout, corrupted or lost write acknowledgements, known receipt
recovery, terminal unknown outcomes, safe errors and immutable dispatch history.
An initial integration run retained a test for v4's absent delivery contract; it
was replaced with the new module's explicit current-queue contract test. An earlier
expectation allowed old-route receipt replay after configuration change; the code
and tests now reject it while preserving no-resend behavior. Initial failure logs
remain separate from final passing evidence.

Environment: Node 22.16.0, Python 3.13.5, genuine local Node SQLite and Web Crypto.
Meta responses and service bindings are synthetic. No real D1, Workers runtime,
handset receipt, full Flutter/Next.js build, browser or production concurrency/load
acceptance is claimed. The original Dart/Flutter and web toolchain requirements
were not lowered. No account, code or credential in the tests represents a live
user or actual sender.

## 6. Source installation and rollback

The exact 17-file patch passed application, after-hash checks, idempotent repeat
application and rollback in two disposable reconstructions:

| Starting source state | Changed | Result |
| --- | ---: | --- |
| Observed current-Drive scoped baseline | 17 | Every starting byte restored on rollback. |
| Current baseline with all sixteen new files already present | 1 | Existing additions retained; only original delivery integration changed/restored. |

The inherited 33 installer regressions cover conflicting edits, corrupt payloads
and backups, symlinks, path traversal, journals, reapplication and rollback
preservation. These are local source trials, not an in-place Drive update or a
production database restore. Source writes are individually atomic, not one
atomic multi-file transaction. Stop editors/builds during local application.

The before-source archive covers 14 scoped files, not the complete repository,
auth database, object storage or every applied migration. It contains source and
synthetic test fixtures, not real identity exports, phones, media, databases or
provider secrets. No font or dependency-cache files are distributed.

## 7. Saved destinations

New direct source: `AFRICLUB/cloudflare/auth-code-delivery/` and the new integration
shim/document inside `AFRICLUB/cloudflare/supporter-auth/`.

Current batch deliverables:
`AFRICLUB/output/refactor-2026-09-26/batch5-whatsapp-delivery/`.

Historical v3/v4 packages:
`.../batch3-operator-interface/` and `.../batch4-supporter-auth/`.

The source readback register records sixteen direct new-file IDs plus the proposed
replacement saved in output. The final delivery receipt records archive/report
upload IDs and matching checksums. Saving SQL source does not apply its migration.

## 8. Use and remaining work

From the extracted Batch5 incremental package, against a matching current checkout:

```sh
python3 apply_patch.py --root "/path/to/AFRICLUB"
python3 apply_patch.py --root "/path/to/AFRICLUB" --apply
python3 verify_bundle.py --results "/tmp/africlub-batch5-verification"
```

The installer performs no network, provider, account, database or deployment work.
Historical cumulative v4 is preserved in Drive but must not downgrade newer source.
The existing file still requires a compatible write connector or this hash-checked
local integration. The new private transport is not enabled by the source upload.

Remaining work includes real sender/template/consent review and staging tests,
private binding and resource proof, full authentication journey/client integration,
provider/job migrations, financial and ticketing commands, full repository cleanup,
visual/native acceptance, final consistent backup and missing-media recovery.
Predict/FET approval remains unresolved. No production writer, application release
or Supabase retirement was performed.

## References

Current repository sources are preserved in `baseline_provenance.json`. Platform
references used as implementation guidance, not runtime approval:
- https://developers.cloudflare.com/d1/worker-api/d1-database/
- https://developers.cloudflare.com/workers/runtime-apis/rpc/
- https://www.postman.com/meta/whatsapp-business-platform/folder/huymv7d/templates
