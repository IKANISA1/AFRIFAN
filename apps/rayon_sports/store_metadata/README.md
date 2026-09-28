# Gikundiro store-delivery package

This directory is the controlled, repository-local working package for the
Google Play and Apple App Store submissions for the Gikundiro mobile app.

The package deliberately separates three kinds of evidence:

1. **Code-backed facts** — package identifiers, version, permissions, bundled
   SDKs, authentication paths, account deletion, and current feature behavior.
2. **Draft store answers** — conservative answers prepared for Play Console and
   App Store Connect, subject to final-archive and production-configuration
   reconciliation.
3. **Portal or accountable-owner facts** — developer-account status, app IDs,
   signing-certificate registration, territories, reviewer credentials,
   agreements, rights, legal classifications, approvals, uploads, and review
   status. These are never invented or stored as secrets in this repository.

## Status vocabulary

- `verified_code`: supported by current source or an inspected generated
  artifact.
- `draft_pending_approval`: prepared but not approved for portal entry.
- `portal_only`: must be obtained from an authenticated store account.
- `blocking`: submission must not proceed until the item is closed.
- `not_applicable`: supported by a recorded product or policy decision.
- `not_applicable_candidate_disabled`: code and backend controls keep the
  capability unavailable in this exact candidate; future enablement requires a
  new assessment and artifact.

## Validation

Run the code-owned package validator from the repository root:

```sh
python3 apps/rayon_sports/store_metadata/validate_store_package.py
```

Run the stronger pre-upload gate only when actual artwork, reviewer access,
portal values, and accountable approvals have been completed:

```sh
python3 apps/rayon_sports/store_metadata/validate_store_package.py --release-ready
```

Use `--submission-ready` after the artifact is uploaded and processed, all
portal forms are complete, and the version is ready to submit or promote:

```sh
python3 apps/rayon_sports/store_metadata/validate_store_package.py --submission-ready
```

The default check proves internal package consistency. It does **not** claim
that either store submission is ready. `--release-ready` is the pre-upload gate;
`--submission-ready` adds post-upload and portal-form evidence. Both are
expected to fail while `approvals.json`, artwork manifests, classifications, or
required portal values remain pending.

## Required final reconciliation

Before any upload, bind every answer to the exact signed AAB/IPA and final
production feature configuration. In particular:

- confirm the merged Android manifest has no SMS/Call Log permissions and no
  message collector is present in the app dependency graph;
- confirm whether Firebase observability and App Check were enabled in the
  actual release build;
- confirm the production feature registry keeps stake/challenge and any
  unmoderated social/UGC surface disabled unless separately approved;
- reconcile the signed iOS archive privacy report and all embedded SDK privacy
  manifests;
- verify the public privacy, terms, support, and account-deletion URLs return
  their intended content rather than a generic application shell;
- record Play App Signing and Apple distribution identities without committing
  private keys, passwords, one-time codes, or reviewer credentials.

## Official source baseline

The answer sheets use the official sources recorded in
`official_sources.md`. Store policies and questionnaires change; refresh those
sources immediately before portal entry.
