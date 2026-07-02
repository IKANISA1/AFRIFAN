# AFRICLUB Mobile Design Source

This path remains for existing repo rules, tests, and agents that still read
`docs/design.md`.

The enforced design contract has moved to:

- `DESIGN.md`
- `docs/design/DESIGN_SYSTEM.md`
- `docs/design/MOBI_REVOLUT_100_PERCENT_ALIGNMENT_MATRIX.md`

Direction: Rayon Sports and AFRICLUB Flutter fan apps target a
MOBI/Revolut-style mobile UX benchmark while preserving AFRICLUB product facts,
Rayon Sports identity, Supabase-backed data, tenant behavior, and approved owned
assets.

`packages/core/core_theme` is the Flutter implementation source of truth. Feature
packages and club apps consume shared tokens, typography, chrome, navigation,
cards, controls, sheets, dialogs, state views, and route primitives from that
package. They must not ship parallel visual systems.

Historical dated design reports are superseded. Do not use old
recommendation-style files to weaken the active MOBI/Revolut alignment matrix.
