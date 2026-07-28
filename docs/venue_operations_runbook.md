# Venue Operations Runbook

Owner: Venue Operations Lead  
Technical escalation: Backend On-call  
Privacy escalation: Privacy/Security Owner  
Review cadence: before every release and quarterly

## Staff access lifecycle

1. A club administrator verifies the staff member and assigned venue out of band.
2. Grant the minimum role: `reviewer` (read-only), `staff` (orders), `manager` (orders/menu/promotions), or `owner`.
3. Confirm the staff member sees the assigned venue name and cannot access another venue.
4. Revoke membership immediately at role change, termination, lost device, or suspected compromise. Never share accounts.
5. Review active `venue_staff_memberships` before each matchday and quarterly.

## Matchday opening checklist

- Confirm `/venue` shows the correct venue, staff role, and live service state.
- Verify order queue, active menu (maximum 10), check-in campaign window/budget, TV-code lifecycle, and staff roster.
- Perform one test order transition and confirm an audit event exists.
- Confirm support contacts and correlation-ID escalation channel are staffed.

## Incident workflow and SLA

| Severity | Example | Acknowledge | Operational action |
|---|---|---:|---|
| SEV-1 | Cross-venue exposure, credential compromise, incorrect FET award | 10 min | Stop affected workflow, revoke access/credentials, preserve audit evidence, notify security/privacy owner. |
| SEV-2 | Orders/check-ins unavailable during event | 15 min | Switch to documented manual fallback, capture correlation IDs, notify backend on-call. |
| SEV-3 | Degraded or stale non-critical data | 4 hours | Record issue, retry safely, schedule correction. |

Never represent an error state as an empty queue. Record UTC time, venue, workflow, correlation ID, operator, impact, mitigation, and resolution. Do not copy supporter identity, balances, tokens, pairing codes, or order contents into chat or tickets.

## Audit retention

- Retain staff mutation and access audit events for 12 months unless the approved legal schedule requires a different period.
- Restrict audit access to authorized club administrators, security/privacy owners, and incident responders.
- Audit exports must be encrypted, access logged, time-limited, and deleted after the case closes.
- Monthly: review failed/denied operations and unexpected role changes. Quarterly: test revocation and cross-venue isolation.

## Closing checklist

- Close expired campaigns and codes; reconcile order and FET totals.
- Revoke temporary staff assignments.
- Record unresolved incidents and handoff owner/time.
- Confirm no raw check-in code, TV credential, or supporter personal data was retained in operational notes.

