# Browser evidence review

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
It supports public, admin and venue manifests, including multi-route documents.
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
