# Optional private WhatsApp transport integration

**Superseded runtime selection:** `RELIABLE_DELIVERY.md` is the current queue integration contract. There is no default legacy sender in the new queue.

This historical source addition did not activate delivery. It preserves the current queued
identity implementation rather than replacing it with the older v4 candidate.

In the earlier batch, `src/delivery.mjs` defaulted to `legacy`. The current queue rejects missing or legacy modes; explicit `AUTH_DELIVERY_MODE=private-deduplicated` selects
`src/private-delivery-sender.mjs`. The queue passes its server-owned challenge ID,
club ID, expiry and template to `OTP_DELIVERY.deliverWithReceipt`.

In a separately reviewed staging configuration for the identity Worker, add:

```json
{
  "vars": {"AUTH_DELIVERY_MODE":"private-deduplicated"},
  "services":[{
    "binding":"OTP_DELIVERY",
    "service":"africlub-auth-code-delivery-staging",
    "entrypoint":"AuthenticationCodeDelivery"
  }]
}
```

This fragment is not a complete deployable config. Merge it with the existing
reviewed configuration; do not replace other bindings, flags or variables. Keep
`AUTH_SERVICE_ENABLED`, `AUTH_DELIVERY_ENABLED` and private `DELIVERY_ENABLED`
disabled until migrations, import, sender, templates, bindings and runtime tests
are verified. Do not copy a placeholder into a live database ID or key.

The new private Worker has its own dispatch database. The identity database and
existing public-content database are NOT its storage destination. External sender
credentials belong only in the private Worker. The current identity worker's
legacy provider fields can be removed only after a governed cutover proves no
legacy job/caller still uses them; this batch removes no credentials.

The existing queue retries at most three leases. In private mode, an ambiguous
external send cannot be retried externally. A known accepted receipt can be replayed
after an identity-database write failure without sending a second code. A missing
binding or unknown mode fails before claiming a lease. No exception selects legacy
as a fallback. A normal provider message ID means accepted, not handset delivered.

Do not switch an in-flight private queue back to legacy as an automatic recovery:
legacy does not consult private dispatch claims. Disable/freeze and expire or
reconcile pending work before a mode change. Never delete a dispatch claim to
force a resend. New codes must be requested explicitly and remain rate-limited.

Install the current-Drive incremental patch only when exact before-hashes match.
Do NOT apply historical v1-v4 cumulative packages over these newer source files.
Source installation is not database migration or operational enablement. Review
`cloudflare/auth-code-delivery/README.md` and retain the source rollback journal.
