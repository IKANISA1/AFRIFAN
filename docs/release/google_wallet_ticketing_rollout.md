# Google Wallet ticketing and venue verification rollout

Status: implementation foundation complete; production activation blocked by the gates below.

## Delivered in this slice

- Confirmed, non-mock tickets can be prepared for Google Wallet through an authenticated, tenant-scoped RPC.
- The Wallet Edge Function creates or updates an Event Ticket class/object and returns a signed save JWT that references the object.
- Each pass uses a server-derived rotating TOTP barcode. The per-pass secret is never stored in the mobile app, returned by an API, or embedded in the save JWT.
- The Rayon Sports Android app checks Google Wallet availability and opens the native `savePassesJwt` flow.
- Venue verification is exposed only when the signed-in user has a live assignment for that venue and ticket event.
- Verification validates the rotating code server-side, enforces event, venue, gate, shift, ticket, and credential state, then records an immutable decision.
- Admission is atomic and idempotent. A successfully admitted ticket becomes `used`; subsequent scans return `already_used` with first-use time.
- Ticket lifecycle changes create an outbox record for Wallet object state synchronization.
- A cron-authenticated worker claims each pass queue in order, patches the Wallet
  object, retries transient failures with bounded backoff, reclaims stale leases,
  and sends an eighth failure to a dead-letter review state.
- Platform and club administrators can find an active supporter by public user
  ID, grant an event/venue/shift/gate-scoped verifier assignment, review current
  authority, and revoke it with an audit record. Moderators cannot manage this
  authority, and the workspace does not expose phone numbers or email addresses.
- The runtime feature is seeded hidden and disabled.

## Security boundaries

- AFRICLUB is the authority for payment finality, ticket status, verifier authorization, and admission. Google Wallet is a presentation channel.
- The service-account JSON and `GOOGLE_WALLET_TOTP_MASTER_SECRET` exist only as Edge Function secrets.
- A master secret must be generated with at least 32 random characters. Do not reuse a Supabase, payment, or signing secret.
- Direct clients cannot read Wallet credentials, pass records, or the synchronization outbox.
- Direct clients cannot invoke the service-only pass-recording or redemption RPCs.
- Each pass is restricted to one Wallet account while remaining available on that fan's devices.
- An unassigned user receives a minimal `permission_denied` response without ticket or seat details.
- Camera access is enabled only for the verifier route and starts only after an explicit user action.
- Verification is online-only. No offline acceptance cache is permitted in this release.

## Required production configuration

1. Complete Google Wallet issuer enrollment and obtain the production issuer ID.
2. Create a dedicated, least-privilege service account authorized for that issuer.
3. Store these Edge Function secrets:

   - `GOOGLE_WALLET_SERVICE_ACCOUNT_JSON`
   - `GOOGLE_WALLET_TOTP_MASTER_SECRET`

   Confirm the existing Vault entry `africlub_cron_job_secret` is present and
   matches the worker's `AFRICLUB_CRON_JOB_SECRET` runtime secret. Do not place
   either secret value in migrations, logs, or release evidence.

4. Apply the database migration.
5. Deploy `google-wallet-ticket-pass`, `verify-ticket`, and
   `sync-google-wallet-ticket-state`.
6. Confirm the Vault-backed schedule can authenticate and retain the worker's
   bounded summary counters in the governed operations evidence.
7. Create one active `ticket_organizations` record per ticket operator and set its issuer ID.
8. Create an active `ticket_events` record for the match and venue. Keep both Wallet and verification switches false until UAT.
9. Create time-bounded `ticket_verifier_assignments` for named users, event, venue, and optional gate.
10. Activate the event switches, then enable and expose `google_wallet_tickets` for the intended club/mobile channel.

## UAT release gates

- A real confirmed production-like ticket can be added on a supported Android device.
- A pending, cancelled, refunded, voided, expired, or mock ticket cannot be issued as an active pass.
- A screenshot or stale rotating code is rejected.
- An assigned verifier can admit once at the assigned venue, event, shift, and gate.
- An unassigned, revoked, expired-shift, wrong-venue, or wrong-gate user cannot admit.
- A concurrent double-scan results in one admission and one `already_used` result.
- An idempotent network retry returns the original decision without a second admission event.
- Camera denial leaves the manual/external scanner path usable and does not expose the verifier route elsewhere.
- Redemption audit rows cannot be updated or deleted.
- Ticket state changes produce the expected Wallet outbox state.
- Operations can disable the runtime feature without shipping a new mobile binary.

## Remaining work before production enablement

- Deploy and operationally prove the implemented outbox worker against approved
  Google Wallet objects; local code and contracts do not prove live operation.
- Add Google-approved "Add to Google Wallet" brand artwork after the protected visual-asset workflow approves it.
- Run physical-device UAT with an approved issuer, a real Wallet account, real venue staff accounts, and controlled test tickets.
- Add monitoring and alerts for issuance failures, verification rejection spikes,
  clock drift, outbox lag, and `dead_letter` records, with a governed replay and
  incident-closure procedure.

## Rollback

Disable and hide the `google_wallet_tickets` runtime feature and the affected event switches first. Revoke active verifier assignments if verification must also stop. Do not delete redemption audit history. Existing passes may remain in users' Wallets; the synchronization worker must mark them inactive when operational authority requires it.

## Primary references

- [Google Wallet Event Tickets for Android](https://developers.google.com/wallet/tickets/events/android)
- [Google Wallet rotating barcodes](https://developers.google.com/wallet/generic/resources/rotating-barcodes)
- [Google Wallet pass constraints](https://developers.google.com/wallet/reference/rest/v1/PassConstraints)
- [Supabase Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
