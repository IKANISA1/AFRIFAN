# Core Theme

`packages/core/core_theme` is the shared mobile UI source of truth for AFRICLUB.

## Current direction

The mobile system now prioritizes:

- calmer dark surfaces instead of heavy glass/clay ornament
- shorter labels and stronger spacing instead of repeated headings and helper copy
- reusable widgets over screen-specific styling
- icon-led scanning and compact status chips
- restrained club color usage for actions, state, and focus only

## What belongs here

- color, spacing, shape, shadow, and typography tokens
- `ThemeData` generation in `src/club_theme.dart`
- reusable primitives such as:
  - `ClayCard`
  - `GlassCard`
  - `AfriButton`
  - `ClaymorphicButton`
  - `AfriIconButton`
  - `AfriClubBottomNav`
  - `AfriSectionHeader`
  - `AfriStatusChip`
  - `AfriMetricTile`
  - `AfriListRow`

## Rules for feature packages

- Do not introduce new fonts, colors, shadows, or radii directly in feature code.
- Prefer shared cards, list rows, chips, and section headers before creating new screen-level widgets.
- Keep copy short. If a screen needs explanation, prefer a chip, status row, or bottom sheet before a paragraph.
- Use club color as emphasis, not as constant background decoration.
- Keep navigation and business logic intact; migrate visuals additively.

## Migration pattern

1. Replace ad hoc containers with `ClayCard` or `GlassCard`.
2. Replace repeated section titles with `AfriSectionHeader`.
3. Replace verbose state labels with `AfriStatusChip`.
4. Replace custom stat blocks with `AfriMetricTile`.
5. Replace settings/menu rows with `AfriListRow`.
6. Simplify copy last, once hierarchy is clear.

Detailed audit and rollout guidance lives in
[`docs/mobile_minimalist_ui_system_2026-04-11.md`](/Volumes/PRO-G40/AFRICLUB/docs/mobile_minimalist_ui_system_2026-04-11.md).
