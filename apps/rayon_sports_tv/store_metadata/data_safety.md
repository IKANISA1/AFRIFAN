# Google Play Data safety working answers — Gikundiro TV

Status: draft for reconciliation against the exact production AAB, backend
configuration, privacy policy, processors, and current Play form wording. These
answers are not a filed declaration.

## Collection and sharing overview

- The app transmits data off the device to Supabase over TLS to provision and
  operate an assigned display.
- The app does not create or sign in a supporter account. It generates an
  installation nonce, obtains a temporary owner-pairing challenge, and stores a
  revocable device credential in platform secure storage.
- The display receives the assigned session projection: club/session identifiers,
  question content, answer options, state/version data, public aliases, scores,
  and ranks.
- No advertising SDK was found in the TV package.
- Do not answer “no data collected” merely because the screen is read-only.
  Reconcile server logs, Supabase operational telemetry, crash reporting, and
  hosting/provider practices before filing.

## Conservative candidate categories

| Play category | Collected? | Shared? | Purpose | Handling | Evidence / gate |
|---|---:|---:|---|---|---|
| Device or other identifiers | Yes | No under service-provider processing | App functionality, security, fraud prevention | Installation nonce and display/device identifiers; encrypted in transit; device credential in secure storage | Runtime provisioning and pairing code |
| App activity — app interactions | Yes | No under service-provider processing | App functionality, security | Pairing, assignment, projection refresh, and realtime events may be logged | Confirm backend and provider logging/retention |
| Diagnostics | Conditional | Conditional | Stability and security | Declare if the exact AAB or infrastructure records crash/performance diagnostics | Inspect AAB SBOM and production services |
| Other user-generated content | Received for display | No under service-provider processing | App functionality | Public aliases and approved session/question content are received from the service | Confirm that no unrestricted user text reaches the TV projection |
| Financial information | No in the TV client | No | Not applicable | The TV projection rejects balances, rewards, claims, orders, and payment data | Projection allowlist/rejection logic |
| Personal information | Not intentionally displayed | No | Not applicable | The public projection uses aliases and rejects sensitive fields | Confirm alias generation and operational logs |
| Location | No | No | Not applicable | No location permission or location code found | Exact-AAB verification required |

“Shared” above assumes Supabase and hosting vendors are processors acting on the
publisher's behalf under Play's service-provider exception. Legal/privacy owners
must verify contracts and every downstream recipient before selecting portal
answers.

## Security and deletion

- Data is encrypted in transit by the HTTPS/realtime services.
- The device credential is held in secure storage and is revocable server-side.
- The TV app has no supporter account to delete. Supporter-account deletion is
  performed in the mobile app or through the published web deletion route.
- Define retention/deletion periods for installation identities, pairing events,
  device assignments, operational logs, and revoked credentials before filing.

## Required reconciliation evidence

1. Inspect the exact signed AAB's merged manifest, SDK inventory, and network
   behavior.
2. Approve processor contracts, retention schedule, privacy URL, and support URL.
3. Verify no real supporter identity or unrestricted user text reaches the
   projection.
4. Enter the final answers in Play Console and preserve dated portal evidence.
