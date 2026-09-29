# Source-to-adapter map

Source authority is the current AFRICLUB Drive repository. Hashes and exact file IDs
for the freshly downloaded contracts are in `source-provenance.json`. All original
source files and applied SQL are unchanged by this additive gateway.

| Source | Preserved behavior | New adapter responsibility |
| --- | --- | --- |
| `supporter-auth/src/identity-verifier-worker.mjs` | Private `current({clubId,accessToken})` result envelope. | Validate the exact response and use only its verified identity. |
| `supporter-auth/src/identity-service.mjs` | Current session, revocation, account/club state, verified-phone supporter role. | Pre/post introspection and explicit expected-session correlation; no cached JWT claims or body actor override. |
| `payment-allocation/src/checkout-service.mjs` | Private prepare/read, frozen descriptor, original-key replay, owner-scoped current status. | Derive user/club from identity, reject pricing overrides, never expose instructions on original-result replay. |
| `payment-allocation/migrations/0002_membership_checkout.sql` | Transactional order preparation/cancellation, 24-hour snapshot and current status. | No SQL changes. Suppress instructions if not current or expiry passed during final checks. |
| `payment-allocation/src/service.mjs` | Immutable historical receipt and service-level read grant. | Prove ownership with the narrower checkout reader first; correlate the full receipt and strip internal evidence/owner IDs. |
| `payment-allocation/checkout-client.ts` | Strict private contract and explicit unknown write outcome. | A separate native HTTP reference client, not a replacement of this trusted-server adapter. |
| Current native auth ingress | Native marker, exact HTTPS origin and runtime CF context, no browser cookies. | Same transport class with bounded body reading and explicit session header. |

The gateway adds pilot rate controls and public response minimization. The source
implements neither a distributed checkout/auth transaction nor a secure device store;
these are not silently filled in as completed behavior. Tests document the revocation
race, and the reference coordinator requires caller-supplied durable process-safe
storage. No OS-specific implementation, paid entitlement or browser session is added.

No matching changes are made to Flutter shells or application routes. The existing
five-club inventory and root Dart/Flutter SDK constraints are preserved. New files
live under one Cloudflare adapter module, not an alternative financial backend.
