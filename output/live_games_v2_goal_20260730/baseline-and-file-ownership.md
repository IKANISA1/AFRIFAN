# LG-000 Baseline and File Ownership

**Captured:** 2026-07-30
**Implementation branch:** `main` only
**Initial HEAD:** `b7d983b3b7b367404a94896824f67bf6dd924499`
**Controlled source candidate:** `aab4999dcc57c6707ecbcf7f036a80d2ef953f87`
**Controlled candidate established:** Yes — clean fast-forward with no divergent commits

## Dirty-state evidence

| Measure | Value |
|---|---|
| Tracked dirty entries | 313 |
| Untracked entries | 557 |
| Total dirty entries | 870 |
| Full `git status --porcelain=v1` SHA-256 | `d6b30997b4c16e393f843f165b715693a6a8dccf7de96a2f95d76bcf3017d322` |
| Live Games scope status SHA-256 | `48206b324bb34be41962c6b2e856855e3eba6a2ef7bb9eee1a3d718255f7a974` |

The scope hash covers the current status of:

- `packages/features/feat_gamification`
- `apps/rayon_sports_tv`
- `apps/rayon_sports/web/src/app/admin/games`
- `apps/rayon_sports/web/src/app/tv-display`
- `supabase`

## Ownership rule

All files that were modified or untracked before the intermediate feature
branch was created remain **user-owned/pre-existing**. Their later inclusion in
commit `aab4999` does not transfer original source authorship to Codex. They
must not be reset, discarded, replaced, or reclassified as Codex-authored work.

Files newly created for this execution are Codex-owned:

- `output/live_games_v2_goal_20260730/*`
- `docs/architecture/live-games-v2.md`
- `docs/architecture/live-games-v2-contract.json`
- `tools/scripts/validate_live_games_v2_contract.mjs`
- `packages/features/feat_gamification/lib/src/models/live_game_v2_models.dart`
- `packages/features/feat_gamification/lib/src/models/live_game_v2_discovery_models.dart`
- `packages/features/feat_gamification/lib/src/controllers/live_game_v2_reconciler.dart`
- `packages/features/feat_gamification/lib/src/controllers/live_game_v2_synchronizer.dart`
- `packages/features/feat_gamification/lib/src/controllers/live_game_v2_discovery_controller.dart`
- `packages/features/feat_gamification/lib/src/controllers/live_game_v2_answer_controller.dart`
- `packages/features/feat_gamification/lib/src/controllers/live_game_v2_participant_controller.dart`
- `packages/features/feat_gamification/lib/src/controllers/live_game_v2_entry_controller.dart`
- `packages/features/feat_gamification/test/live_game_v2_models_test.dart`
- `packages/features/feat_gamification/test/live_game_v2_discovery_models_test.dart`
- `packages/features/feat_gamification/test/live_game_v2_reconciler_test.dart`
- `packages/features/feat_gamification/test/live_game_v2_synchronizer_test.dart`
- `packages/features/feat_gamification/test/live_game_v2_discovery_controller_test.dart`
- `packages/features/feat_gamification/test/live_game_v2_answer_controller_test.dart`
- `packages/features/feat_gamification/test/live_game_v2_participant_controller_test.dart`
- `packages/features/feat_gamification/test/live_game_v2_entry_controller_test.dart`

No pre-existing mobile, native-TV, admin, web-TV, migration, RLS, localization,
theme, CI, authentication, or release file is in the first change set.

## Main-only consolidation evidence

The branch was created directly from the observed `main` HEAD. Creating the
branch preserved the dirty-state hash exactly:

```text
before branch:
d6b30997b4c16e393f843f165b715693a6a8dccf7de96a2f95d76bcf3017d322

after branch:
d6b30997b4c16e393f843f165b715693a6a8dccf7de96a2f95d76bcf3017d322
```

This proves the original branch switch did not rewrite the existing worktree.

The worktree was later consolidated into one clean commit:

```text
main before consolidation:
b7d983b3b7b367404a94896824f67bf6dd924499

controlled source candidate:
aab4999dcc57c6707ecbcf7f036a80d2ef953f87

rev-list main...feature before fast-forward:
0 1

working tree before fast-forward:
clean
```

`main` was fast-forwarded to `aab4999`; there was no merge commit, rebase,
conflict, or divergent history. All further implementation for this goal must
remain directly on `main`.

The controlled goal package was added in `fe9f184`, pushed to `origin/main`,
and verified with identical local and remote commit IDs. The former
`feature/live-games-v2` commit was proven reachable from `origin/main`; the
redundant local and remote feature branches were then deleted.

## Current checkout snapshot

At 2026-07-30 11:29 +02:00, local `main` and `origin/main` both resolved to
`f63dbdf9bddfc97a8bdad15d5149fb10f518e3b3`. The worktree then contained 90
tracked dirty entries and two untracked Codex-owned answer-slice files, for 92
entries in total. The SHA-256 of `git status --porcelain=v1` was
`6e857663dd6709975c9c152a03a0c10bc6abc97aafa9c3033cc2583ddca6923d`.

This is a time-scoped observation, not a clean controlled candidate. In
particular, the concurrent user-owned Fan Zone diff retains `Enter TV code`,
routes participants to `/fanzone/game`, and tests that legacy behavior.
Those files were not modified by this goal execution.

## Remaining LG-000 closure work

- Record file-level ownership for every overlapping Live Games source file.

Until original file-level ownership is reconciled, LG-000 remains
`in_progress`. Protected or overlapping implementation also remains subject to
its decision and approval gates.
