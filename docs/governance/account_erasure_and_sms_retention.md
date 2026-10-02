# Account closure and SMS evidence lifecycle

This is the technical field policy and operating procedure for B-04 and B-07.
It describes the implemented source. It does not establish a legally approved
retention schedule, processor deletion acceptance, hosted job operation, backup
expiry, or territory launch approval.

## Request, recovery and retained subject

The native client creates a random UUIDv4 request capability, persists it, and
reads it back before requesting closure or logging out. A lost first response or
application restart retains the same capability. Onboarding can check its narrow
opaque status without granting access to the closed account. The receipt stores
only the request reference and state, with no user, club, contact, or transaction
facts. A local unconfirmed receipt does not assert revoked access. Hiding it only
removes the local receipt.

`POST delete-account` verifies the current Auth account and writes an idempotent
`account_erasure_jobs` receipt before irreversible Storage or Auth calls. The
database revokes account access, active staff assignments, sessions, refresh
tokens, receiver authority and notification endpoints in that transaction.
Mutation guards and restrictive policies deny existing JWTs, including nested
privileged application functions. Actor locks serialize closure with mutations
that were already waiting. An active service actor can still settle the closed
subject's pre-existing liabilities.

The financial subject UUID remains in Auth, public users/profiles, financial and
retired schemas. Physical deletion of these subject rows is blocked after a
closure request. This avoids cascading away balances, orders, paid or pending
membership obligations, prediction entries, ledgers and consumed evidence.
The UUID is a retained pseudonymous linkage identifier; it is not anonymous data.

## Field map

The executable inventories are `account_erasure_field_policy` and
`account_erasure_fk_inventory`, populated by the forward migration across the
actual public, football and retired schemas. Each entry records a concrete table,
subject column, field and erasure strategy. New personal columns or new references
must be added to these inventories and their contracts before release.

| Record class | Local treatment | Retained integrity facts |
| --- | --- | --- |
| Public users/profiles and private contacts | Replace public identity with a closed-account alias; remove names, contact numbers, avatars, country/contact preferences and private contact fields; disable staff/privacy capabilities. Related compatibility fields are updated together. | Original subject identifiers and required foreign references. |
| Devices, notifications and receiver bindings | Remove notification endpoints and admin phone bindings; deactivate receiver authority and opt-in flags. Scrub personal JSON where present. | Governed transaction references and attribution needed for outstanding obligations. |
| Shop orders and frozen receipts | Remove delivery address from the order and its frozen receipt through the narrow service closure exception. | Total, quantities, product facts, currency, receiver, provider, timestamps, operation reference and all other frozen receipt facts. |
| Membership, prediction, MoMo, FET and retired financial records | Remove personal text/contacts and scrub nested personal JSON. Keep the linked subject and records. | Amounts, balance-after values in financial ledgers, statuses, references, consumed evidence identifiers and anti-reuse keys. |
| Raw SMS, all statuses | Redact body, sender and WhatsApp contact when due; pending/processing records become ignored. Unmatched, failed and malformed records are included. | Provider, country, timestamp, subject linkage and device-message identity. |
| AI parse attempts | Clear request/response JSON and error text for every status when the underlying SMS is due. | Attempt identity, timing, state and non-personal operational facts. |
| Parsed SMS and reconciliation evidence | Remove names, full/partial phones, balances from the parsed SMS, narratives, summaries, recurring hints, structured JSON and reconciliation notes; scrub personal ledger metadata/text. | Transaction amount, fee, currency, provider, global MoMo reference, evidence links and payment integrity facts. Financial ledger balance facts remain. |
| Storage and Auth | Remove exact owned objects through Storage API and verify zero remaining objects; request Auth soft deletion and verify `deleted_at`. | Pseudonymous Auth UUID and financial subject continuity. |
| External processors, exports and backups | Remain pending until accountable evidence is recorded for the applicable obligations. | Necessary financial retention must be specified in the external schedule. |

## Retention and AI egress

The existing 14-day SMS interval is reused as an explicit **technical proposal**,
not as a jurisdictional legal conclusion. Raw bodies, AI payloads and structured
personal fields have separate policy fields, each bounded to 1–14 days. The
service redactor cannot extend these intervals through call parameters.

`hold_sms_evidence` requires an active global or relevant club staff actor, an
unredacted record, a bounded expiry and an evidence reference. A hold lasts at
most 90 days per operation, an engineering cap that still needs accountable
policy approval. Held artifacts are excluded while active and automatically
rejoin catch-up after expiry. The operator must review renewal necessity rather
than treating a technical hold as approval for indefinite retention.

The redactor processes at most 500 rows per record class with row locks and
`SKIP LOCKED`, uses an eight-second statement budget, and reports counts,
`oldest_remaining_due_at` and `has_more`. It runs every ten minutes in source.
Run metrics contain no body or contact data and have a proposed 30-day bounded
operational history. A late parser reply cannot reintroduce already expired PII.

Before AI egress, the parser projects transaction facts: reference, transaction
amount, fee, currency, provider, date/time, bounded merchant code and transaction
category. It excludes the stable user UUID, raw body, names, full phone numbers,
balances, learned rules and unrelated text. AI output remains untrusted evidence;
this minimization does not authenticate the payment source or acknowledge deletion
from the AI provider.

## Resumable processing and truthful completion

`POST delete-account?action=process` requires the configured cron secret. The
worker claims at most five jobs with two-minute leases and a 45-second budget.
It processes local erasure in batches of 250, then at most 100 owned Storage
objects per pass, followed by Auth soft deletion. Every call has bounded request
and response time/bytes. Failed stages retain their durable request and error
code, release the lease, and can be retried. Storage success requires API success
and a database read-back; Auth success requires the actual soft-deleted state.
No synthetic provider success is recorded.

The steps are `local_data`, `storage`, `auth`, `processors`, and `backups`. Overall
state becomes `completed` only after every step has a valid completion record.
Technical steps finishing still leaves the request pending while processor or
backup obligations lack evidence. Failed work shows a failure state while account
access remains revoked. Completion means the specified removal steps completed;
required transaction records remain retained.

An active global administrator may submit an attributable evidence reference
through `POST delete-account?action=acknowledge` for the processor or backup
step. The actor is resolved from authenticated authority; a request body cannot
select another actor. Evidence must identify actual accountable external work.
The wrapper cannot manufacture Storage/Auth completion or clear financial facts.
Support should retain and use the opaque request reference, avoid including raw
SMS/contact data in tickets, and reconcile external failures before retrying an
unknown effect.

## External acceptance still required

Before hosted activation or territory release, the accountable owner must approve
each jurisdiction's record-class schedule, financial retention basis, hold and
exception procedure, processor terms/region/transfers, export/log handling, backup
expiry and restoration handling. It must verify the deployed Vault secret and
cron configuration, observe backlog catch-up under realistic load, and obtain
real processor/backup acknowledgements. Local synthetic contracts do not prove
these external conditions.

Supabase documents the distinction between account deletion and JWT validity,
the service-only soft-delete option, and the Storage removal API. The pinned Auth
source also logs out sessions during soft deletion. The application therefore
uses database access guards in addition to Auth/session changes. References:
[Auth user deletion](https://supabase.com/docs/guides/auth/managing-user-data#deleting-users),
[Admin deleteUser](https://supabase.com/docs/reference/javascript/auth-admin-deleteuser),
[Storage removal](https://supabase.com/docs/reference/javascript/storage-from-remove),
[Auth v2.195.0 admin implementation](https://github.com/supabase/auth/blob/v2.195.0/internal/api/admin.go).
