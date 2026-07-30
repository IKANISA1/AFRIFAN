# Approval Request — AFRICLUB Live Games V2 Protected Implementation

**Requested from:** Repository/product owner
**Goal:** `africlub_live_games_v2_full_implementation_20260730`
**Implementation branch:** `main` only

The following approvals are required before protected or overlapping
implementation begins.

## Product decisions

Approve or revise:

- **DEC-01:** One session may be assigned to multiple TVs.
- **DEC-02:** A home TV may show club-wide eligible games plus explicitly
  assigned games.
- **DEC-03:** Venue display management does not automatically grant organizer
  control; organizer capability is separately assigned.
- **DEC-04:** Participant public identity is the governed alias only; no
  free-text display name.
- **DEC-05:** Live streaming in this goal means synchronized trivia state;
  video streaming remains excluded.
- **DEC-06:** Legacy participant-code and web-TV compatibility use an additive,
  measured sunset with rollback.

## Protected local-source approvals

- **APR-01:** Create additive Supabase migration files for TV ownership,
  pairing, display assignment, lifecycle, projections, and audit.
- **APR-02:** Add or change RLS policies required for owner, venue-manager,
  organizer, admin, and TV credential isolation.
- **APR-03:** Amend `RULES.md` narrowly to permit owner-scoped TV management
  and assigned-organizer game operations in mobile while keeping generic admin
  and venue operations excluded.
- **APR-04:** Create the role-gated Flutter feature package and required local
  workspace pubspec entries. No new third-party dependency is requested.
- **APR-05:** Update shared localization messages to remove participant TV-code
  copy and add owner/organizer/native-TV V2 states.

## Not requested yet

This request does not authorize:

- staging or production migration execution;
- production data changes;
- CI workflow changes;
- deployment, signing, store submission, or release;
- external communication or cost.

Those remain APR-06 through APR-09 and will be requested only when their
evidence gates are ready.

## Approval response

To approve the recommended decisions and protected local-source work, respond:

```text
Approve DEC-01 through DEC-06 and APR-01 through APR-05 for local
implementation directly on main. Treat all pre-existing dirty files as
user-owned; merge carefully and do not discard them. Do not mutate staging or
production, change CI, deploy, sign, submit, or release without separate
approval.
```

Any item may instead be revised or rejected individually.
