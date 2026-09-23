# Browser evidence review

## 20 September 2026 implementation revision

The sole authority remains `revolut-design`. The owner requested replacement of
conflicting presentation across the repository and a `review-agent` review.
The latter is a read-only defect review of the implementation diff, not another
design standard or an owner-acceptance decision.

The public reference was inspected at https://www.revolut.com/ on 20 September:
photographic hero, sentence-case heading (500 weight; 48/48px at 390px and about
84.7/84.7px at 1280px), dark pill call to action, restrained navigation. The club
website retains its own photos, names, content, routes and feature flags. Inter
is the self-hosted product typography adapter from the historical UI Kit; the
live public site's Aeonik Pro font is not bundled here. Exact font equivalence
therefore remains open, rather than being claimed from similar geometry.

`src/ui-kit/tokens.css` implements semantic colours from the skill's versioned
UI Kit and signed-out web evidence. It replaces the falsely labelled generated
token file. The club palette derivation module is removed; tenant colour values
remain identity data for marks and swatches. Public and admin/PWA chrome, ordinary
groups, inputs and actions use neutral roles. Status colours remain distinct.
Blue Home, violet membership and photographic editorial content are explicitly
selected product adaptations; they do not establish source-page equivalence.
The native Dark · Glow sources are not presented as web geometry evidence.

The unused legacy hero, gold UI accents, condensed 900-weight display face,
uppercase tracking, bevelled groups and per-club page washes are replaced.
The signed-out admin form retains WhatsApp OTP, permissions and session behavior;
provider colour no longer defines its controls. The public bottom navigation
retains its destinations and safe-area clearance in a floating neutral group.

Before/after command logs, retained failures, native contrast diffs and new
browser captures are stored under `output/qa/full-stack-20260914/goal-update-revolut-*`.
Older browser packets belong to the earlier source and are not acceptance of
this revision. Current captures are engineering evidence until compared and
accepted through the existing registers. A backend storage-quota restriction
observed during the first run is separate from isolated UI outcomes.

### Frontend approval candidate

The current refinement removes duplicate admin CSS and theme-specific utility
colours, aligns admin inputs, buttons, chips and notices with the shared semantic
roles, and keeps both light and dark themes readable. The public compact drawer
covers the viewport. A single optional Home tab fits its label instead of filling
the phone width. Unavailable home content has one recovery notice and unknown
summary counts remain unknown. Membership inputs and labels use readable sizes,
shared spacing and grouped history rows. These are frontend presentation changes;
provider availability and owner acceptance are separate and remain unclaimed.

The next review packet uses the `goal-update-frontend-*` command logs and captures
under `output/qa/full-stack-20260914/`. Earlier failed or interrupted runs remain
there as diagnostic evidence. The gallery is a local review aid assembled from
existing route and baseline registers, not an acceptance register. Backend,
provider, hosted CI and release work waits for owner approval of the frontend.

## Provenance and review procedure

Production builds and raw captures must remain tied to their exact source. Run
the pinned web `corepack npm run build` command with the intended QA environment.
It seals production inputs, the build ID and compiled artifacts. Browser state
tests reject an unsealed or stale build and use separate output directories for
each project, test and retry. Each completed capture records its test/helper
hashes, actual browser version, viewport, device pixel ratio, media preferences,
full-page tiles and artifact hashes. The current six Playwright projects include
three desktop engines, two mobile profiles and a tablet profile.

From the repository root, stage completed captures with:

```sh
node tools/scripts/register_web_route_state_evidence.mjs \
  --capture-dir=output/qa/<run>/<test>/<capture-directory> \
  --output=output/qa/<new-review-packet>.json
```

Repeat `--capture-dir` to include several completed cases. Use the exact
directories written by the run. Keep the original files available while staging;
archived historical images must be restored and verified in their original
capture directory before use. Captures from another build remain historical.
The command checks current production, test/helper and lockfile hashes, artifact
completeness, image decoding, dimensions, tile continuity and applicable states.
It supports public and admin manifests, including multi-route documents.
It rejects unfinished, stale or incomplete captures and preserves existing
review packets by requiring a new output path.

Staging produces **unreviewed engineering evidence** under `output/`. It never
writes `docs/governance/route-state-evidence.json` or `evidence-bundles.json`, and
`--admit-reviewed` is rejected. Neither a successful test nor a staging packet
creates a reviewer identity, signature, review date or acceptance decision.
Existing evidence registries remain the authority for subsequent documented
review; there is no second acceptance registry.

A reviewer must inspect the matched reference and target state, confirm state
applicability and record visual fidelity, usability, accessibility, performance
and resilience independently. Browser emulation does not prove an installed PWA
or a native/physical-device result. Synthetic response checks do not prove real
backend mutation, delivery, settlement or provider integration. Hosted CI,
deployment, release signing and owner acceptance remain separate results.

Run `node --test tools/scripts/register_web_route_state_evidence.test.mjs` after
changes to the staging command. The web CI job runs these regressions using the
installed web dependencies.
