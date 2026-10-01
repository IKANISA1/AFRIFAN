# AFRICLUB product mapping for revolut-design

## Sole design authority

The owner's 30 September 2026 instruction selects **revolut-design exclusively**
for the complete system: all five Android/iOS club apps, consumer and member web,
Admin PWA, native role-guarded administration, and the browser operator console.
The target is **100% fidelity to the selected Revolut visual typologies and
colours**, with each product's own identity, content and workflows.

Read the selected [revolut-design skill](</Volumes/PRO-G40/Application Data/Codex/Codex-Home/skills/revolut-design/SKILL.md>)
and its applicable bundled references before changing presentation. Its authority
order, brand adaptation, native/web/PWA patterns, component contracts, colour
roles and evidence rules govern every included surface and state.

This file contains AFRICLUB product facts and source mappings. It does not define
another palette, type scale, spacing system, visual benchmark or design standard.
Repository theme implementations, route maps, screenshots, reports and regression
baselines cannot override the skill. Retired design specifications, alternative
visual references and obsolete style aliases must be deleted, including retained
source copies that could reintroduce those instructions.

Accessibility requirements, platform APIs and technical frameworks support the
selected design; they do not select another visual system.

## Product identity and scope

Keep the actual names, crests, icons, approved imagery, domains, currencies,
terminology and legal identity of Rayon Sports/Gikundiro, AS Vita, Nkana,
Vital'O and Costa do Sol. Logo artwork retains its own colours and proportions.
Surrounding application colours come from the selected visual family, independently
of club artwork. Do not ship Revolut marks, account screenshots, company names,
source-specific product labels or unsupported banking functionality.

All five app shells share presentation primitives and domain contracts. Club
configuration supplies identity and actual data; Rayon is not a hardcoded shared
assumption. Preserve route guards, permissions, supported capabilities, data
ownership and server-authoritative outcomes.

## AFRICLUB Football-Club-First Product Contract

The product is the official digital home of each football club. Its content and
workflows remain football-club-first while presentation follows revolut-design.
The product priority is:

1. Club identity, team, news, fixtures, results, standings and history.
2. Membership, fan clubs, contributions, projects, tickets and shop.
3. Selected-match football predictions and competitions.

The mobile primary navigation remains `Home · Club · Predict · Membership`.
Profile contains account, settings, appearance, privacy, notifications and support.

- Home shows current club/football context and actual available supporter actions.
- Club contains overview, team, news, fixtures, results, standings, history,
  projects, tickets and shop.
- Membership contains the digital card, plan/status, fan clubs, contributions,
  statements, projects and history.
- Predict retains prepared fixtures, personal picks and authoritative FET activity.
- Search respects content availability, permissions and actual supported entities.
- Admin/operator tasks retain their queues, records, reports, audit trails,
  review steps and role boundaries.

The historical fixed-price FET implementation is not authorization to enable
financial entry mechanics. The current decision remains in
[Predict economics](docs/governance/predict_economics_decision.md) and its
machine-readable record. Preserve historical ledger data and the current
repository product boundary.

Payment initiation never means confirmation. Keep anonymous supporter entry,
existing WhatsApp number/code verification, keyboard/autofill support, review,
cancellation, retry, idempotency and server-confirmed membership/payment state.
MoMo linking remains in account settings and is not a first-launch requirement.

## Source mappings and evidence

Use the skill's matching platform and state comparator. The existing native
mapping is [native-reference-map.json](docs/governance/native-reference-map.json).
It selects the 5 September 2026 native iOS Dark · Glow cohort, with separate
onboarding comparators. Light, Android, tablet and football-specific compositions
remain explicit product/platform adaptations where direct source evidence is
absent. Native images do not establish desktop, consumer web or Business parity.

Public/consumer web uses the applicable bundled website/product references;
admin and operator surfaces use the bundled Business/operator references;
installed web modes also use the bundled PWA reference. Keep source cohorts and
variant limitations explicit instead of blending incompatible contexts.

Source originals remain in the external private reference collection. Inspect the
actual selected image before implementation. Keep source provenance, dates,
known viewport/build and comparator limitations in evidence. Repository route
maps and rendered target images are implementation evidence, not design authority.

The authority revision and this product mapping are bound in
[design-exceptions.json](docs/governance/design-exceptions.json). That binding
checks source integrity only. It cannot certify visual equivalence.

## English-only product policy

Maintained application code, static/runtime copy, tests, configuration, store
metadata and documentation use English. Only the English catalog ships. Device
locale and old profile preferences cannot change application language. Official
club, person/place names and ISO country identifiers retain their identity.
Public content requires an approved English edition before publishing.

## Implementation and completion

Use shared semantic primitives in `packages/core/core_theme`, the web UI kit,
and the operator theme. Map every applicable route, component, overlay, theme and
interaction state to the selected skill. Remove obsolete hardcoded or
club-derived application colours and competing default-library styling.

Preserve the target's actual tasks and truthfully represent loading, empty,
invalid, disabled, pending, failed, offline, permission, recovery, selected,
focused and pressed states. Compare settled rendered implementations with the
state-appropriate source, including compact/enlarged views, keyboard, safe areas,
reduced motion and applicable accessibility conditions.

Use existing route, widget, golden, browser and accessibility harnesses. Record
actual source/artifact hashes and unresolved differences. The skill's
MOBILE-DESIGN-100 rule governs mobile visual acceptance; no repository-owned
score or alternative design contract replaces it. Apply the skill's corresponding
web/admin evidence rules to those surfaces independently.

A 100% completion claim requires coverage of every applicable route/state,
reviewed source comparisons with no unexplained material differences, and
verified target interactions. Missing or stale evidence remains unverified.
Keep fidelity, usability, accessibility, performance, runtime resilience,
technical checks and release/device/provider acceptance distinct.
