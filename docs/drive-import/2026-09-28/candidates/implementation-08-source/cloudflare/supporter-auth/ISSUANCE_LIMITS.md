# Tenant-reserved authentication issuance budgets

New OTP challenges require `AUTH_ISSUANCE_POLICY_JSON`. Its absence fails closed;
existing session reads/refreshes are not disabled by a missing issuance-only policy.
No runtime or provider was enabled by this change.

Schema example for isolated tests, NOT approved production capacity:
```json
{"version":1,"globalPerMinute":50,"perIpPerMinute":10,"phonePer15Minutes":3,"clubs":{"6":10,"24":10,"26":10,"44":10,"1001":10}}
```
The sum of all club caps must be <= the global provider-cost ceiling. Limits commit
in the same transaction as the challenge. Rejected transactions consume no quota;
idempotent replays return the original challenge. IP budgets are per-club and
hashed; the phone anti-spam budget intentionally spans clubs. No raw phone is a key.
Update policy only at a drained fixed-window boundary, keep the same policy on all
instances, and reconcile any previous unallocated global budget before activation.
The database serializes these counters; edge WAF/abuse limits are still required.

Measure real delivery drain rate, carrier latency, provider fees and expected
shared-network demand before selecting values. These tests prove isolation and
atomicity locally, not adequate game-day capacity or globally fair abuse controls.
Unknown club caps block issuance. The reserved source ID 1001 needs its existing
collision and onboarding checks before any live use. The policy does not onboard it.
