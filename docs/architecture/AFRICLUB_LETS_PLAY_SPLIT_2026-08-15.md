# AFRICLUB and LET'S PLAY split

Date: 2026-08-15

Status: locally implemented on isolated branches; production migration and
release approval are not claimed.

## Product boundary

AFRICLUB is now the football-club product. It retains fixtures and live match
coverage, predictions and prediction leaderboards, supporter points and
rewards, memberships, contributions, ticketing, shop, venue, club content,
and football administration.

LET'S PLAY owns household trivia. It now contains mobile player and organizer
journeys, the household admin console, native Android TV display/pairing,
question drafting and review, immutable question packs, authoritative session
state and scoring, and the associated Supabase runtime.

No shared source dependency connects the two repositories after this split.

## Source disposition

| Former AFRICLUB responsibility | AFRICLUB disposition | LET'S PLAY destination |
| --- | --- | --- |
| `apps/rayon_sports_tv` | Removed from source and workspace | `ikanisa_trivia/apps/tv_android` |
| `packages/features/feat_game_operations` | Removed from source and registry | `ikanisa_trivia/apps/mobile` and `ikanisa_trivia/packages/trivia_core` |
| Fan Zone participant live-game routes/controllers | Removed; football predictions remain | `ikanisa_trivia/apps/mobile` |
| Web `/admin/games`, `/tv-display`, and venue display-code workflow | Removed | `ikanisa_trivia/apps/admin` and native TV app |
| Trivia Edge Functions | Removed from active AFRICLUB configuration | `ikanisa_trivia/supabase/functions` |
| Trivia/session contracts and tests | Removed from active AFRICLUB governance | `ikanisa_trivia/contracts`, migrations, pgTAP, Dart, Deno, Flutter, and Kotlin tests |

The imported AFRICLUB source inventory and hashes are preserved in LET'S PLAY
under `ikanisa_trivia/legacy/africlub_import`. The active LET'S PLAY code is an
adaptation to its household architecture, not a second build of the former
AFRICLUB modules.

## AFRICLUB navigation after the split

- Home: club news, match context, and supporter shortcuts.
- Club: squad, fixtures, standings, tickets, shop, and club services.
- Fan Zone: predictions, matchday rounds, football leaderboards, supporter
  points, venue participation, fan groups, and football rewards.
- Membership: membership and contribution journeys.
- Settings: account, preferences, privacy, support, and security; TV/game
  operations are absent.

Push routing, deep links, route inventory, localized copy, store metadata,
privacy declarations, and visual baselines were updated to this boundary.

## Backend history boundary

Historical AFRICLUB Supabase migrations are an immutable deployment ledger and
still describe schemas that may exist in deployed databases. They are not
registered by the current app, web, or Edge Function surfaces. A forward-only
decommission migration revokes access to the retired runtime and removes its
Realtime publication while retaining historical data. No production schema or
data deletion is included in this source split.

Before the decommission migration is applied, and before any later physical
deletion is approved, the accountable owner must confirm production inventory,
retention/export requirements, rollback, dependent clients, and the LET'S PLAY
cutover. Only then may a separate migration archive or drop the retired objects.

## Local validation and release gates

The split passed Flutter workspace analysis and regression tests, affected
goldens, the web unit suite and production build, Android debug build,
active-source reference scans, and the applicable governance validators.
LET'S PLAY passed database reset/pgTAP/lint, Deno validation, Dart/Flutter
analysis and tests, Flutter Web/mobile builds, and native TV unit/build gates.

The 2026-08-20 closure rerun passes full web typecheck, 890 tests, zero-warning
lint, and production build, plus the complete Flutter analysis/test matrix,
fresh Supabase reset/tests/lint, store/privacy contracts, and active-source
negative scan. See
`docs/release/AFRICLUB_FOOTBALL_ONLY_SPLIT_CLOSURE_2026-08-20.md` for exact
results and remaining gates.

Local validation does not authorize deployment. Remaining gates include:

- production Supabase migration and data-cutover plan;
- secrets and environment configuration;
- physical mobile and TV-device accessibility, focus, disconnect, and recovery
  testing;
- replacement AFRICLUB football-only store screenshots and signed artifacts;
- signing, store setup, deployment, UAT, monitoring, and accountable product,
  privacy, content, legal, and release approvals.

## Rollback and handoff

The work is isolated on `codex/split-tv-trivia-to-lets-play` in AFRICLUB and
`codex/import-africlub-tv-trivia` in LET'S PLAY. Until merge, rollback is simply
to leave those branches unmerged. After merge, use a normal Git revert of the
split commits; do not rewrite repository history. Database rollback is a
separate approved operation because no production database mutation is part of
these commits.
