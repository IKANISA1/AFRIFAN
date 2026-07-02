# MOBI/Revolut-Aligned AFRICLUB Design System

## Direction

Rayon Sports and the wider AFRICLUB Flutter fan apps must target a
MOBI/Revolut-style mobile experience at implementation level:

- dark immersive route gradients
- black glass command chrome
- floating black glass bottom navigation
- compact icon-first scanning
- short labels and dense hierarchy
- shared async, empty, offline, and error handling
- shared sheet, dialog, toast, chip, list, card, and button primitives
- strong route-transition consistency
- accessibility and visual evidence as release gates

The app must still look like the Rayon Sports/AFRICLUB product. Club facts,
crests, legal copy, Supabase-backed content, app routes, and owned assets remain
the product truth. MOBI/Revolut is the UX benchmark, not a license to invent
partnership claims or copy another product's business content.

## Source Of Truth

The active written contract is this file plus
`docs/design/MOBI_REVOLUT_100_PERCENT_ALIGNMENT_MATRIX.md`.

The active Flutter implementation source is `packages/core/core_theme`.
Feature packages and club apps consume the shared system; they do not define
independent visual systems.

Legacy compatibility path: `docs/design.md` intentionally points here because
existing repo rules and tests still name it.

## Non-Negotiables

- Use `TypographyTokens` and the bundled `RevolutBorrowed` font family.
- Keep letter spacing at `0`.
- Use `ColorTokens`, `AfriSemanticColors`, or `ExternalBrandColors`; feature
  and app UI must not use raw `Colors.*`.
- Use `ColorTokens.screenGradientForPath` and borrowed gradient helpers for
  route and surface backgrounds.
- Use shared chrome: `AfriTopCommandBar`, `AfriClubBottomNav`, `AfriAppBar`,
  and `AfriSliverAppBar`.
- Use shared surfaces and controls before creating a feature widget:
  `AfriSurfaceCard`, `AfriPanelCard`, `GlassCard`, `AfriButton`,
  `AfriIconButton`, `AfriChip`, `AfriChoiceChip`, `AfriStatusChip`,
  `AfriInfoChip`, `AfriListRow`, `AfriListTile`, `AfriSwitchListTile`,
  `AfriDialog`, `AfriActionSheet`, and `AfriToast`.
- Use shared state primitives: `AfriAsyncStateView`, `AfriStateView`, and
  `AfriStateBanner`.
- Keep the supporter app phone-first with bottom tabs `Home`, `Fan Zone`, and
  `Settings` unless a separate tablet/foldable/web shell goal is approved.
- Admin is PWA-owned by default. Mobile admin routes are internal opt-in only
  and must not appear in the normal supporter app shell.
- Do not render section-level placeholder cards when data is empty or
  unavailable.
- Do not add generated, downloaded, placeholder, or hardcoded network images
  without owner approval.
- Do not add feature-local fonts, local gradients, local nav bars, screen-local
  design systems, or bespoke copy-heavy state cards.

## Product Identity Rules

Use club identity as accent and trust signal, not as a competing shell system:

- Crest/avatar: shared command avatar may show the configured club crest or
  initials.
- Club colors: use as controlled accent, focus, selection, and semantic states.
- Content: source from Supabase, `ClubConfig`, or approved compile-time values.
- Owned assets: preserve approved club assets; do not replace them with generic
  MOBI/Revolut assets.
- Product copy: use AFRICLUB/Rayon factual wording. Keep it short and direct.

## Implementation Rules

Every mobile screen must resolve the following through shared code:

- route background
- top or pushed-route chrome
- bottom navigation or sheet/pushed-route behavior
- typography
- spacing and radius
- card/surface treatment
- loading, empty, error, offline, permission, and unavailable states
- buttons, chips, list rows, forms, dialogs, sheets, toasts, and scanner shells
- semantics, focus, reduced motion, hit targets, and 200 percent text behavior

If a feature needs a new primitive, add it to `packages/core/core_theme` only
after proving the existing primitives cannot express the behavior.

## Enforcement

Use these checks before claiming alignment:

- `bash tools/scripts/rayon_mobile_design_drift_report.sh --fail-on-findings`
- `FLUTTER_BIN=/Volumes/PRO-G40/flutter_3_44/bin/flutter bash tools/scripts/validate_mobi_revolut_alignment_matrix.sh`
- focused Flutter analyze/test commands for touched packages
- `packages/core/core_app/test/rayon_mobile_visual_coverage_contract_test.dart`
- updated visual evidence when a route surface changes materially
- `FLUTTER_BIN=/Volumes/PRO-G40/flutter_3_44/bin/flutter bash tools/scripts/rayon_mobile_native_ux_gate.sh` when native-mobile UX proof is required

The alignment matrix is the review checklist. A screen is not aligned because it
"looks dark"; it is aligned only when the matrix rows that apply to it are
implemented or explicitly marked as not applicable with evidence.
