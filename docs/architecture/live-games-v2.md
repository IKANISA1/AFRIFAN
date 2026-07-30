# Live Games V2 Architecture Decision

**Status:** Proposed — product decisions and protected approvals remain open  
**Goal:** `africlub_live_games_v2_full_implementation_20260730`  
**Design authority:** `DESIGN.md`  
**Implementation authority:** The controlled goal and task register under
`output/live_games_v2_goal_20260730/`

This ADR records the proposed system architecture. It does not define visual
tokens or UI rules and does not override `DESIGN.md`, `RULES.md`, RLS, or
accountable owner decisions.

## Context

AFRICLUB currently has one shared backend but three inconsistent live-game
client models:

- participant mobile discovers a session using a TV/session code and refreshes
  manually;
- native TV polls a reduced state and does not render the full trivia
  projection;
- web TV compatibility renders a fuller projection and uses a different
  Realtime contract.

The required product model is one server-authoritative session shared across
participant mobile, owner/organizer mobile, native TV, and admin.

## Proposed decisions

These positions remain subject to DEC-01 through DEC-06 in the controlled
decision log:

1. A session may be assigned to multiple authorized TV installations.
2. A TV installation belongs to an authenticated owner and either a home or
   venue scope.
3. Venue display management and organizer game control are separate
   capabilities.
4. Participant public identity is the governed alias; V2 does not collect a
   free-text display name.
5. “Live streaming” means synchronized trivia state. Video delivery is outside
   this programme.
6. Legacy participant-code and web-TV compatibility are retired through a
   measured, reversible rollout.

## Domain boundaries

### Content

- `QuestionDraft`
- `Question`
- `QuestionPack`
- source evidence
- moderation/audit decision

AI may propose drafts, but only an authorized human can approve and publish
questions or packs.

### Orchestration

- `GameSchedule`
- `GameSession`
- `SessionQuestion`
- `Participant`
- `AnswerClaim`
- `GameAuditEvent`

The server owns lifecycle, phase deadlines, scoring, correct-answer release,
and final standings.

### Displays

- `TvInstallation`
- `PairingChallenge`
- `DeviceCredential`
- `GameDisplayAssignment`

The TV is a read-only public projection. It never receives personal identity,
wallet, check-in, order, or private participant data.

## Authoritative lifecycle

```text
draft
  → validated
  → published
  → scheduled
  → activated/lobby
  → question_open
  → reveal
  → next_question
  → completed

Exceptional states:
paused, cancelled, degraded, reconnecting
```

Every transition must:

- validate caller role and resource scope;
- validate expected current state and version;
- accept an idempotency key;
- increment session version and ordered event sequence;
- write an audit event;
- return a fresh role-specific projection.

## Pairing

1. An unpaired native TV requests a short-lived single-use challenge.
2. The TV displays the challenge and QR.
3. An authenticated owner opens **My TVs** and claims the challenge.
4. The backend validates club, role, owner, and home/venue scope.
5. The TV receives or rotates a revocable device credential.
6. Pairing material disappears.

Participants never use the pairing challenge and never enter a TV code to join
a V2 game.

## Role-specific projections

The backend exposes sanitized projections for:

- participant;
- organizer;
- native TV;
- admin.

Every projection includes:

- `club_id`;
- `session_id`;
- lifecycle phase;
- `session_version`;
- ordered `event_sequence`;
- authoritative `server_time`;
- current phase deadline;
- current question version;
- freshness/reconnect metadata;
- caller-allowed actions where applicable.

The correct answer is absent from participant and TV projections until reveal.

## Synchronization

Realtime is an invalidation mechanism, not the source of truth.

1. Subscribe with `{club_id}:game_session:{session_id}`.
2. Receive a minimal invalidation hint.
3. Fetch the role-specific authoritative projection.
4. Apply only a newer session version/event sequence.
5. Reconcile again after reconnect, app resume, timeout, or detected gap.
6. Use bounded polling only as a recovery fallback.

Service targets:

- normal propagation p95 at most 2 seconds;
- recovery to the current snapshot at most 5 seconds after network restoration;
- zero state rollback from stale/out-of-order events;
- zero duplicate lifecycle advancement.

## Authorization

- Participants see only eligible sessions for their club/account context.
- Owners manage only their TV installations.
- Venue managers manage only installations in assigned venues.
- Organizers manage only assigned sessions and displays.
- Admins retain governed review and oversight.
- Device credentials authorize only the TV projection contract.
- RLS and server transitions enforce access; client routing is not a security
  boundary.

## Client responsibilities

### Participant mobile

- show eligible **Live now** and scheduled sessions;
- join by authenticated eligibility;
- answer through the governed alias;
- reconcile automatically;
- expose loading, empty, error, offline, reconnecting, conflict, permission,
  paused, completed, large-text, and reduced-motion states.

### Owner and organizer mobile

- provide role-gated **My TVs** and **Games I manage**;
- never expose generic admin routes;
- show one valid next lifecycle action;
- confirm destructive/exception actions;
- display truthful freshness and degraded states.

### Native TV

- perform owner-claim pairing;
- render lobby, question, choices, deadline, reveal, leader summary, pause,
  completion, offline-retained, and reconnect states;
- preserve native D-pad/focus, 720p/1080p, overscan, and privacy contracts;
- never control game progression.

### Admin

- Content Studio for evidence-backed AI moderation;
- Session Planner for pack, schedule, eligibility, organizer, and display
  assignment;
- Live Control for authoritative state, projections, health, guarded
  transitions, and audit detail.

## Compatibility and rollout

Implementation is additive first:

1. backend contracts and security tests;
2. admin planning/control;
3. native TV;
4. owner/organizer mobile;
5. participant V2 discovery;
6. measured adoption and rollback window;
7. disable participant-code navigation;
8. sunset compatibility adapters and web TV after approval.

No legacy surface is removed before native replacement, adoption evidence, and
rollback approval exist.

## Consequences

- New additive schema/RLS work and protected approvals are required.
- Existing game client contracts must migrate to versioned projections.
- Owner and organizer mobile capabilities require a narrow repository-rule
  amendment.
- Current iOS deployment-target incompatibility must be resolved before clean
  release proof.
- The goal remains fail-closed until authenticated staging, multi-client,
  physical-device, accessibility, security, performance, signing, deployment,
  and rollback evidence is current.

