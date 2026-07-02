#!/usr/bin/env bash
set -euo pipefail

cat <<'CHECKLIST'
AFRICLUB game pilot UAT checklist

[ ] Admin can create or select a game session for one club.
[ ] Admin can pair a TV/display with the session.
[ ] TV display shows attract/join/lobby state without correct answers.
[ ] Player can join from mobile with a session code or deep link.
[ ] Admin can open a question.
[ ] Two players can submit answers.
[ ] Server accepts only one attempt per player per question.
[ ] First correct answer creates the only answer claim.
[ ] Wrong answers do not create a claim.
[ ] TV display does not reveal correct answer before claim/reveal/closed state.
[ ] Admin can reveal the question.
[ ] Leaderboard/points update from server state only.
[ ] Refresh/reconnect preserves player and TV state.
[ ] Audit rows exist for answer claim and admin state changes.
[ ] Product-boundary scan and scoped realtime scan have been run.
[ ] SQL contract tests have been run against a disposable database.
CHECKLIST
