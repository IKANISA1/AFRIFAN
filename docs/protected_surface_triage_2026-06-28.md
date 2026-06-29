# Protected Surface Triage - 2026-06-28

This triage records the current dirty-tree areas that intersect `RULES.md`
protected surfaces. It does not approve, revert, or normalize the changes.

## Scope

Command basis:

```bash
git status --short
git diff --name-status -- packages/core/core_theme packages/features/feat_home
git ls-files --others --exclude-standard packages/core/core_theme packages/features/feat_home
```

## Agent-Owned Phase 0 Changes

These changes were made during the Phase 0 remediation pass:

| Path | Status | Classification | Notes |
| --- | --- | --- | --- |
| `analysis_options.yaml` | Modified | Phase 0 remediation | Added generated `.dart_tool` and `build` exclusions so analyzer does not inspect generated artifacts. |
| `apps/rayon_sports/test/rayon_sports_shell_navigation_test.dart` | Modified | Phase 0 remediation | Aligned shell test with current source-backed bottom-nav labels: `Home`, `Fan Zone`, `Settings`. |
| `docs/screen_inventory.md` | Added | Phase 0 governance | Required by `RULES.md` before UI remediation work. |
| `docs/rayon_sports_mobile_readiness_goal_2026-06-28.md` | Superseded | Historical pointer | Redirects old Rayon-specific planning references to the active repo-wide borrowed-system report. |
| `docs/protected_surface_triage_2026-06-28.md` | Added | Phase 0 governance | This protected-surface decision aid. |

## Protected Core Theme Drift

`RULES.md` protects design token/theme surfaces. The following dirty paths were
already present when this Phase 0 remediation pass began and require owner
decision before release claims:

| Path | Status | Classification |
| --- | --- | --- |
| `packages/core/core_theme/README.md` | Modified | Owner decision required |
| `packages/core/core_theme/lib/core_theme.dart` | Modified | Owner decision required |
| `packages/core/core_theme/lib/src/tokens/color_tokens.dart` | Modified | Owner decision required |
| `packages/core/core_theme/lib/src/tokens/shadow_tokens.dart` | Modified | Owner decision required |
| `packages/core/core_theme/lib/src/widgets/afri_action_row.dart` | Modified | Owner decision required |
| `packages/core/core_theme/lib/src/widgets/afri_bottom_sheet.dart` | Modified | Owner decision required |
| `packages/core/core_theme/lib/src/widgets/afri_button.dart` | Modified | Owner decision required |
| `packages/core/core_theme/lib/src/widgets/afri_list_row.dart` | Modified | Owner decision required |
| `packages/core/core_theme/lib/src/widgets/afri_metric_tile.dart` | Modified | Owner decision required |
| `packages/core/core_theme/lib/src/widgets/glass_card.dart` | Modified | Owner decision required |
| `packages/core/core_theme/test/design_system_source_of_truth_test.dart` | Modified | Owner decision required |
| `packages/core/core_theme/lib/src/widgets/clay_card.dart` | Deleted | Owner decision required |
| `packages/core/core_theme/lib/src/widgets/claymorphic_button.dart` | Deleted | Owner decision required |
| `packages/core/core_theme/lib/src/widgets/elite_button.dart` | Deleted | Owner decision required |
| `packages/core/core_theme/lib/src/widgets/elite_card.dart` | Deleted | Owner decision required |
| `packages/core/core_theme/lib/src/widgets/afri_app_bar.dart` | Untracked | Owner decision required |
| `packages/core/core_theme/lib/src/widgets/afri_material_buttons.dart` | Untracked | Owner decision required |
| `packages/core/core_theme/lib/src/widgets/afri_panel_card.dart` | Untracked | Owner decision required |
| `packages/core/core_theme/lib/src/widgets/afri_sliver_app_bar.dart` | Untracked | Owner decision required |
| `packages/core/core_theme/lib/src/widgets/afri_surface_card.dart` | Untracked | Owner decision required |

## Protected Home Surface Drift

`RULES.md` locks the Home screen UI and Home-exclusive imports. The following
dirty paths were already present when this Phase 0 remediation pass began and
require owner decision before release claims:

| Path | Status | Classification |
| --- | --- | --- |
| `packages/features/feat_home/lib/src/screens/home_screen.dart` | Modified | Owner decision required |
| `packages/features/feat_home/lib/src/widgets/contributor_leaderboard.dart` | Modified | Owner decision required |
| `packages/features/feat_home/lib/src/widgets/latest_intel_section.dart` | Modified | Owner decision required |
| `packages/features/feat_home/lib/src/widgets/match_card.dart` | Modified | Owner decision required |
| `packages/features/feat_home/lib/src/widgets/elite_match_strip.dart` | Deleted | Owner decision required |
| `packages/features/feat_home/lib/src/widgets/borrowed_match_strip.dart` | Untracked | Owner decision required |

## Related Governance Drift

| Path | Status | Classification | Notes |
| --- | --- | --- | --- |
| `docs/design.md` | Modified | Owner decision required | Canonical design source changed before this Phase 0 pass. |
| `RULES.md` bottom-nav wording | Source conflict | Owner decision required | `RULES.md` says `Home · Contribute · Settings`; router and module tests use `Home · Fan Zone · Settings`. |
| Mobile admin routes | Resolved | PWA-owned by default | `AdminModule` remains implemented for explicit internal mobile builds only; default Rayon/Gikundiro supporter builds use the centralized Admin PWA. |

## Decision Needed

For each protected drift group, the owner should choose one:

- Approve as intended remediation and allow Phase 1/2 work to build on it.
- Keep but request targeted fixes.
- Revert or replace in a separate owner-approved cleanup pass.
- Classify as unrelated user work that must not be touched by this remediation
  goal.

Until this decision is recorded, the app can pass tests and analyzer but cannot
be called release-ready.
