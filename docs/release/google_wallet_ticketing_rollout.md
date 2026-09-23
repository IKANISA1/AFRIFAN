# Google Wallet ticketing rollout

Status: implementation foundation complete; production activation blocked by the gates below.

## Delivered in this slice

- Confirmed, non-mock tickets can be prepared for Google Wallet through an authenticated, tenant-scoped RPC.
- The Wallet Edge Function creates or updates an Event Ticket class/object and returns a signed save JWT that references the object.
- Each pass uses a server-derived rotating TOTP barcode. The per-pass secret is never stored in the mobile app, returned by an API, or embedded in the save JWT.
- The Rayon Sports Android app checks Google Wallet availability and opens the native `savePassesJwt` flow.
- Ticket lifecycle changes create an outbox record for Wallet object state synchronization.
- A cron-authenticated worker claims each pass queue in order, patches the Wallet
  object, retries transient failures with bounded backoff, reclaims stale leases,
  and sends an eighth failure to a dead-letter review state.
- The runtime feature is seeded hidden and disabled.

## Security boundaries

- AFRICLUB is the authority for payment finality, ticket status and Wallet issuance. Google Wallet is a presentation channel.
- The service-account JSON and `GOOGLE_WALLET_TOTP_MASTER_SECRET` exist only as Edge Function secrets.
- A master secret must be generated with at least 32 random characters. Do not reuse a Supabase, payment, or signing secret.
- Direct clients cannot read Wallet credentials, pass records, or the synchronization outbox.
- Direct clients cannot invoke the service-only pass-recording RPCs.
- Each pass is restricted to one Wallet account while remaining available on that fan's devices.

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
5. Deploy `google-wallet-ticket-pass` and
   `sync-google-wallet-ticket-state`.
6. Confirm the Vault-backed schedule can authenticate and retain the worker's
   bounded summary counters in the governed operations evidence.
7. Create one active `ticket_organizations` record per ticket operator and set its issuer ID.
8. Create an active `ticket_events` record for the match with its own stadium name, address, country code and timezone. Keep `google_wallet_enabled` false until UAT.
9. Activate the event switch, then enable and expose `google_wallet_tickets` for the intended club/mobile channel.

## UAT release gates

- A real confirmed production-like ticket can be added on a supported Android device.
- A pending, cancelled, refunded, voided, expired, or mock ticket cannot be issued as an active pass.
- Ticket state changes produce the expected Wallet outbox state.
- Operations can disable the runtime feature without shipping a new mobile binary.

## Remaining work before production enablement

- Deploy and operationally prove the implemented outbox worker against approved
  Google Wallet objects; local code and contracts do not prove live operation.
- Add Google-approved "Add to Google Wallet" brand artwork after the protected visual-asset workflow approves it.
- Run physical-device UAT with an approved issuer, a real Wallet account and controlled test tickets.
- Add monitoring and alerts for issuance failures,
  clock drift, outbox lag, and `dead_letter` records, with a governed replay and
  incident-closure procedure.

## Rollback

Disable and hide the `google_wallet_tickets` runtime feature and the affected event switches first. Existing passes may remain in users' Wallets; the synchronization worker must mark them inactive when operational authority requires it.

## Primary references

- [Google Wallet Event Tickets for Android](https://developers.google.com/wallet/tickets/events/android)
- [Google Wallet rotating barcodes](https://developers.google.com/wallet/generic/resources/rotating-barcodes)
- [Google Wallet pass constraints](https://developers.google.com/wallet/reference/rest/v1/PassConstraints)
- [Supabase Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
