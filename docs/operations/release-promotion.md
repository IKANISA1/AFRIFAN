# Candidate-bound web promotion

> Imported Implementation 08 source record. Statements about an earlier tool session or delivery describe that source snapshot. Current implementation, executed checks and release status are recorded in `docs/release/production-readiness-task-register.json`; no historical approval is promoted to current acceptance.

The independent push deployment has been replaced by a reusable workflow called
only after the parent CI's database, Flutter, web, browser, native-build and
Cloudflare source jobs succeed. The existing Next build now rejects type errors
as well as retaining the separate typecheck. No production setting is enabled.

The web job builds OpenNext from the checked Next output, seals every output and
control-file digest, and publishes a run/SHA-bound archive. Promotion downloads
that same run's artifact, verifies its externally passed SHA-256, candidate,
run, manifest and control files, then extracts into a clean checkout. It uses
OpenNext's deploy command without a Next build. Actual Cloudflare bundling,
caching, upload and provider-side version readback still need staging acceptance.

Required owner setup (not performed by source generation): protect main and the
workflow paths; require all checks; configure `africlub-production` with named
reviewers, no self-review and protected deployment branches; scope Cloudflare
credentials to the intended application; review the actual wrangler routes.
`AFRICLUB_RELEASE_PROMOTION_ENABLED` must remain unset/false until acceptance.
No pull-request-target/workflow-run privilege bridge is introduced.

`AFRICLUB_RELEASE_ACCEPTANCE_JSON` is a protected environment variable containing
schemaVersion=1, exact candidateSha/artifactSha256, expiresAtMs (within 24 hours),
and every check defined in release_evidence.py. Each entry needs status=approved,
a named reviewer, evidence reference and verifiedAtMs within the last 24 hours.
The validator checks declarations and binding, not their truth or legal validity.
No approving template is supplied. Missing/expired/partial/waived records block.

The new workflow has not run on GitHub. Platform/device/runtime checks and the
root dangerous Drive permission remain blockers. A source archive is not a release.
