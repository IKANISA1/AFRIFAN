# Core Theme

`packages/core/core_theme` is the shared mobile UI source of truth for AFRICLUB.

## Current direction

The mobile system now prioritizes:

- calmer dark surfaces instead of legacy ornament
- shorter labels and stronger spacing instead of repeated headings and helper copy
- reusable widgets over screen-specific styling
- icon-led scanning and compact status chips
- restrained club color usage for actions, state, and focus only

## What belongs here

- color, spacing, shape, shadow, and typography tokens
- borrowed pass-card paper/ink tokens such as `ColorTokens.borrowedPaper`,
  `ColorTokens.borrowedInk`, and `ColorTokens.transparent`
- `ThemeData` generation in `src/club_theme.dart`
- reusable primitives such as:
  - `AfriSurfaceCard`
  - `AfriPanelCard`
  - `GlassCard`
  - `AfriButton`
  - `AfriTextButton`
  - `AfriOutlinedButton`
  - `AfriElevatedButton`
  - `AfriChip`
  - `AfriChoiceChip`
  - `AfriIconButton`
  - `AfriAppBar`
  - `AfriSliverAppBar`
  - `AfriTopCommandBar`
  - `AfriClubBottomNav`
  - `AfriSectionHeader`
  - `AfriStatusChip`
  - `AfriMetricTile`
  - `AfriListRow`
  - `AfriListTile`
  - `AfriSwitchListTile`

## Rules for feature packages

- Do not introduce new fonts, colors, shadows, or radii directly in feature code.
- Do not use direct `TextStyle(...)` constructors in feature/app UI; route text
  through `TypographyTokens`.
- Do not use Flutter `Colors.*` in feature/app UI; use `ColorTokens`,
  `AfriSemanticColors`, or `ExternalBrandColors`.
- Do not use Material chip constructors in feature/app UI; use `AfriChip`,
  `AfriChoiceChip`, `AfriInfoChip`, or `AfriStatusChip`.
- Do not use Material list/toggle row constructors in feature/app UI; use
  `AfriListRow`, `AfriListTile`, or `AfriSwitchListTile`.
- Prefer shared cards, list rows, chips, and section headers before creating new screen-level widgets.
- Keep copy short. If a screen needs explanation, prefer a chip, status row, or bottom sheet before a paragraph.
- Use club color as emphasis, not as constant background decoration.
- Keep navigation and business logic intact; migrate visuals additively.

## Migration pattern

1. Replace ad hoc containers with `AfriSurfaceCard` or `GlassCard`.
2. Replace repeated section titles with `AfriSectionHeader`.
3. Replace verbose state labels with `AfriStatusChip`.
4. Replace custom stat blocks with `AfriMetricTile`.
5. Replace settings/menu rows with `AfriListRow`.
6. Replace route-level `AppBar` constructors with `AfriAppBar`.
7. Replace route-level `SliverAppBar` constructors with `AfriSliverAppBar`.
8. Replace platform button constructors with shared `Afri*Button` primitives.
9. Replace local white/black pass-card colors with `ColorTokens.borrowedPaper`
   and `ColorTokens.borrowedInk*`.
10. Replace remaining Material `Colors.*` references with `ColorTokens` or
   `ExternalBrandColors`.
11. Replace Material chip constructors with `Afri*Chip` primitives.
12. Replace Material list/toggle row constructors with shared `Afri*List*`
   primitives.
13. Replace direct `TextStyle(...)` constructors with `TypographyTokens`.
14. Simplify copy last, once hierarchy is clear.

Detailed design guidance lives in
[`docs/design/DESIGN_SYSTEM.md`](/Volumes/PRO-G40/AFRICLUB/docs/design/DESIGN_SYSTEM.md)
and the active alignment matrix at
[`docs/design/MOBI_REVOLUT_100_PERCENT_ALIGNMENT_MATRIX.md`](/Volumes/PRO-G40/AFRICLUB/docs/design/MOBI_REVOLUT_100_PERCENT_ALIGNMENT_MATRIX.md).
