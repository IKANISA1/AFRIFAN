# AFRICLUB — Batch 6 signed delivery receipts

Date: 26 September 2026. Authority: current AFRICLUB Drive workspace,
folder `1izZgoOKfEONHZTyHkE0MzBW9Eeo4-VeH`, and the checked Batch 5 source subset.

## Actual delivery state

**All 21 source paths are installed in their correct Google Drive locations and
have passed downloaded SHA-256 readback:** 19 new files, one README update and
completion of the previously pending Batch 5 `supporter-auth/src/delivery.mjs`
integration. Both existing-file updates preserve their original Drive IDs.
The current connector accepted the runtime file reference for in-place replacement.

The delivery file changed from
`a28aee4ebae173e857a8f055b6f019ba435a717221e58df5be3cf031c90f56a5`
to the previously tested replacement
`29439e44d9efc0b54f4c8b058e70eb2b2f20205ceaeaa8502d6c013079b3196d`.
Its ID remains `1g57kNjdwxPjyGc5zEWXMrniFPHI3wQrt`.
The README ID remains `1QxtShiuJnRHW5k72-T2hClK7030Tcj3H`.

No remote migration, provider subscription, secret provision, live message,
identity import, deployment, billing change, client cutover, financial writer
change or Supabase retirement occurred. All three new runtime templates remain
disabled with placeholder database IDs. Uploading SQL source does not apply it.
Earlier repository edits outside this scope are not claimed as integrated.

## Implemented behavior

| Component | Implementation |
| --- | --- |
| Tracked private sender | Immutable pre-send club/account/sender/keyed-recipient binding, then delegation to the existing deduplicated service; no competing sender. |
| Signed callback | Exact path, verification handshake, HMAC-SHA-256 over original POST bytes before parsing, distinct app/verification secrets, required edge limiter and bounded input. |
| Receipt evidence | Forward-only companion tables for bindings, normalized status events and exact links; existing acceptance and identity records are preserved. |
| Exact correlation | Accepted dispatch message ID, pre-send binding, club, account, sender, recipient commitment, key version and timestamp window must match. A SQL trigger repeats the conditions. |
| Early callbacks | Minimized observations remain pending until a matching accepted message exists. Unknown sends cannot be converted into accepted ones by a callback. |
| Ordering and retries | Semantic event IDs deduplicate retries. Inserts and immediate links share one batch. Late sent events do not regress delivered/read; contradictory failure/success facts remain visible. |
| Bounded reconciliation | At most 100 eligible links per invocation, with eligible selection before LIMIT so unrelated earlier observations do not starve a later exact match. |
| Private status reader | Exact club/challenge information-only lookup. The consuming service must authenticate the actor and authorize ownership. No public read endpoint or operator-screen integration is claimed. |
| Delivery controls | Three disabled configurations, strict configuration checker, contract description, key separation and a detailed staging/retention runbook. |

A provider receipt does not create/revoke a session, activate membership, adjust
FET, move money, issue a ticket or erase an account. A queue-to-receipt-to-code-
verification integration test confirms that only code verification creates the
session in the local test. A reported read does not prove identity.

## Executed verification

The assembled incremental package passed **362 targeted tests**:

| Group | Passed |
| --- | ---: |
| Preserved current-Drive identity/delivery/HTTP regressions | 77 |
| Preserved Batch 5 provider/queue regressions | 124 |
| New receipt HTTP/storage/integration/configuration tests | 128 |
| Installer and rollback regressions | 33 |
| **Total** | **362** |

Final failures and skips were zero. Eighteen syntax/JSON checks and both disabled
configuration checks also passed. All 21 source downloads were independently
substituted into the checkout; **329 code tests passed again**. Repeated executions
are not double-counted. Historical results for a different v4 auth implementation
are not added to this current-source total.

Coverage includes forged/tampered signatures, exact raw-byte signing, malformed,
oversized or timed-out bodies, wrong accounts/senders/recipients, ignored inbound
content, batch limits, duplicates, ordering/conflicts, early callbacks, wrong-club
reads, disabled controls, timestamps, immutable evidence, link guards, rollback at
every position of a two-event batch, lost replies after commit, bounded pending
reconciliation, over-limit histories and separate authentication effects.

Environment: Node 22.16.0, Python 3.13.5, genuine local SQLite and Web Crypto.
Provider responses, edge bindings, callback signatures and service calls are
synthetic fixtures. WorkerEntrypoint wrappers were syntax checked, not executed
in workerd. No real D1/Meta/handset, full Flutter/Next build, device accessibility
or production load test was performed. Higher repository toolchain requirements
remain unchanged. Prior browser policy blocks were not bypassed.

## Source application and rollback

The exact payload passed preflight, application, after-hash verification,
idempotent reapplication and rollback in three disposable reconstructions:

| Starting state | Changed | Rollback |
| --- | ---: | --- |
| Before pending Batch 5 delivery integration | 21 | Starting bytes restored |
| Delivery integration already installed | 20 | Starting bytes restored |
| Integration plus all 19 new files present | 1 | README restored; additions retained |

A reconstruction using all downloaded current Drive files reports **zero changes,
21 already matching**. Unknown edits stop the installer; rollback preserves
recognized starting versions. Source writes are individually atomic, not one
multi-file transaction. Stop editors/builds during local application.

The backup contains 30 scoped source/test files, not the complete monorepo or a
production database. No real user export, code/token, media original, dependency
cache or font file is included. Synthetic fixture credentials are test-only.

## Operational limits and remaining work

Raw webhook bodies, phones, OTPs, inbound text and free-text provider errors are
not persisted. IDs and keyed recipient values remain linkable personal data.
Minimized unknown-message statuses from configured senders can remain unlinked;
shared-sender traffic, retention/archival/erasure, alerts, dashboards, status export,
spend controls and online key rotation still require implementation and review.
Immutable evidence is not a claim of satisfying every privacy requirement.

The eight-day intake horizon, five-minute timestamp tolerance, 64 KiB request limit,
twenty status objects and 600/minute local edge limit are pilot choices, not approved
production capacity. Provider timestamps are not replay nonces. Large provider
batches and D1 scan costs need measured staging proof. Deleted is a provider
observation, not an erasure instruction. The private reader's caller authorization
is required but not supplied by this primitive.

Determine existing Meta webhook ownership before subscription; do not overwrite
another product callback. Existing unbound dispatches cannot be retroactively
assigned a recipient. Unknown submissions remain unknown and cannot be resent
automatically. Do not downgrade in-flight private sends to a legacy path that
bypasses their retained claims.

Supporter anonymous/linking, phone recovery/change, native storage, browser auth,
full client and staff-role migration, transactional membership/payment/stock/ticket/
FET commands, remaining provider/job ports, final backup and media recovery, visual
acceptance and economic-policy approval remain unfinished. Full cutover and
Supabase retirement are still unperformed.

## Saved destinations and use

New source: `AFRICLUB/cloudflare/auth-code-delivery/` in its existing source,
test, script, contract and migration folders. Existing README and auth-queue edits
preserve IDs. All 21 path/ID/hash records are in the source readback register.

Deliverables: `AFRICLUB/output/refactor-2026-09-26/batch6-delivery-receipts/`.
The archive includes exact paths, checksums, context, tests, evidence and a
reversible installer. It is an incremental current-source patch, not a cumulative
v4 downgrade. Historical v1-v4 files remain preservation artifacts.

```sh
python3 apply_patch.py --root "/path/to/AFRICLUB"
python3 apply_patch.py --root "/path/to/AFRICLUB" --apply
python3 verify_bundle.py --results "/tmp/africlub-batch6-verification"
```

A checkout matching Drive should report already matching source. No installer
command makes network, provider, SQL, account or deployment calls.

## Primary references

Checked 26 September 2026; guidance, not deployment evidence:
- https://www.postman.com/meta/whatsapp-business-platform/request/rgtfq23/message-status-update-notifications
- https://github.com/fbsamples/whatsapp-api-examples/blob/main/signature-validation-with-webhooks-payloads/app.py
- https://developers.cloudflare.com/workers/runtime-apis/web-crypto/
- https://developers.cloudflare.com/d1/worker-api/d1-database/
