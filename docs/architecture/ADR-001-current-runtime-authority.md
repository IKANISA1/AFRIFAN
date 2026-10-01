# ADR-001: Current source runtime and command authority

Recorded 1 October 2026. Status: codifies the existing repository architecture;
deployed parity and replacement cutover remain unverified.

The current implementation uses Supabase as the authoritative transactional
runtime. This records the existing [blueprint](../blueprint.md), rather than
activating a replacement backend. Flutter and Next/PWA clients call that runtime
with their verified subject and server-resolved club. A privileged service caller
must verify the current actor and resource scope at the mutation boundary.

| Domain | Current command and record authority | Proposed or staged boundary |
| --- | --- | --- |
| Identity and sessions | Supabase Auth; application profiles and the custom access-token hook | Cloudflare identity/session candidates remain conditional on migration acceptance |
| Staff capabilities | PostgreSQL `admin_role_assignments`; current global/club checks and audit | Access or service-binding possession cannot substitute for resource authorization |
| Membership and contributions | Supabase checkout, allocation and activation RPCs; payment orders, pending transactions and memberships | Supporter membership API may be a gateway; its staging flags do not authorize a second entitlement writer |
| Commerce and inventory | Supabase checkout receipts, shop orders, reservations and confirmation RPCs | Browser or delivery gateways carry the original operation; they do not allocate stock independently |
| Tickets | Supabase purchase, issue, redemption and revocation contracts | A scan gateway must preserve the canonical admission transaction and replay identity |
| Prediction entries, settlement and FET | Supabase `football` pools/entries and ledger commands; versioned economics | New free entry and historical paid liabilities require separate behavior; release approval remains distinct |
| Payment source, allocation and consumed references | Canonical Supabase raw/parsed evidence, reconciliation and confirmation transactions | Staged allocation/evidence stores cannot become a competing writer; trusted real ingress remains an implementation and provider acceptance gap |
| Erasure and retained financial history | Supabase leased erasure jobs and service commands; financial snapshots remain retained | Auth, Storage, processor and backup obligations require their own real completion receipts |
| Club content and public read projections | Supabase content records and approved media references | Cloudflare immutable public snapshots are read projections; approved publication does not transfer financial authority |
| Operator publication and observations | Separate staged operator/publication and privacy-minimized observation surfaces | They remain disabled under their checked-in staging flags; publishing content cannot imply entitlement or payment settlement |

Financial mutation, its original operation identity, consumed payment reference,
inventory/entitlement change and audit must commit within the canonical database
transaction. Separate delivery queues preserve original keys and explicit unknown
outcomes. They cannot claim a cross-database atomic transaction. Raw SMS, an AI
interpretation, a digest or an attestation string alone does not prove money moved.

No rollout here switches writers, retires Supabase, activates staging capabilities,
changes provider bindings or grants a new administrative role. This ADR names
source ownership; only a real deployment readback can establish runtime ownership.

A replacement must use the existing
[`validate_migration_release.py`](../../tools/scripts/validate_migration_release.py)
and its eighteen cutover conditions. Evidence must bind the actual candidate,
resource/caller inventory, issuer/tenant/principal, original UUID/reference history,
financial and entitlement totals, final write freeze/delta, recovery and rollback.
The rollback procedure must disable the replacement writer before restoring the
previous writer; duplicate delivery must retain the original operation identity.
Retirement adds the validator's four retirement conditions. This document creates
no additional checklist and records none of those conditions as accepted.

Current release state is recorded in [CURRENT_RELEASE](../release/CURRENT_RELEASE.md).
