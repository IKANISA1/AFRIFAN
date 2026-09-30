# Source-security containment — actions not performed by a source patch

> Imported Implementation 08 source record. Statements about an earlier tool session or delivery describe that source snapshot. Current implementation, executed checks and release status are recorded in `docs/release/production-readiness-task-register.json`; no historical approval is promoted to current acceptance.

The latest connector metadata still reports an anyone/writer permission on the
AFRICLUB root. The connector in this session cannot modify permissions or upload.
No credential contents have been read, rotated, validated against a provider or
published by this remediation. Do not infer an actual breach from metadata alone.

An authorized owner must restrict public-link access at the root AND review child
files/archives/direct grants, retain access/revision evidence, distinguish live
keys from public configuration and test material, and revoke/replace identified
exposed live secrets via their provider. Preserve the owner and approved named
collaborators; do not revoke unidentified principals or delete backups blindly.
Upload-key remediation is distinct from app-signing-key rotation.

The added read-only `check_sensitive_source.py` guards the canonical Git selection
(tracked plus non-ignored new source), reports only paths/categories, and blocks
private env/signing paths, actual private-key blocks and service-role JWT literals.
It does not inspect ordinary ignored workstation files, certify Drive permissions,
prove token liveness, scan arbitrary external archives, or replace secret scanning.
Run it in protected CI alongside the existing source-secrets/privacy validators.
The source checks are not a substitute for restricting the real sharing setting.
