# Rayon public-source migration: immutable publication

This service is limited to the existing approved Gikundiro public-content source
used by Rayon. It is not the standalone Gikundiro website, supporter identity,
transactional backend, or the complete five-club Cloudflare migration.

The public Worker preserves the nine existing read routes and schemaVersion 1.
It adds `snapshotId`, bounds cache freshness, verifies media bytes, and retains
transaction-disabled responses. Both media and JSON require one active, approved,
fresh snapshot. No HTTP route publishes content or writes financial state.

## Migration order

1. Preserve the existing database and original media. Apply the existing `0001`
   and `0002` migrations, then the forward-only
   `0003_immutable_public_snapshots.sql`, to an isolated candidate environment.
   Do not edit previously applied migration files or replace legacy source rows.
2. Capture the approved public source using
   `python3 tools/scripts/snapshot_gikundiro_public_for_cloudflare.py`, then use
   the existing media exporter. These tools require the existing authorized
   source configuration. The export remains non-transactionally consistent and
   must not be represented as a final transactional financial backup.
3. Run `python3 tools/scripts/seed_rayon_public_d1_local.py`. It validates source
   hashes, table completeness, club identity, media bytes and rights provenance.
   The output is an **unpublished import**. Manifest fragments keep SQL statements
   bounded; a large individual source record fails rather than being truncated.
4. Import the generated SQL with the repository's pinned Wrangler process into
   the candidate database. New snapshot rows are versioned; partial imports do
   not change public content. Existing legacy rows and original objects remain.
5. Run `python3 tools/scripts/stage_rayon_public_media_r2.py` for a dry run.
   Only `--execute` uploads to the fixed isolated staging bucket and reads every
   object back. Keys are content-addressed `assets/<sha256>.bin`; this does not
   erase old objects, change billing, or activate a snapshot.
6. Verify the imported snapshot:

   ```sh
   python3 tools/scripts/verify_rayon_public_d1_local.py --database /path/to/candidate.sqlite
   ```

   `--sql-export` accepts a candidate D1 SQL export instead. This verifies stored
   row/hash/media-metadata parity. It does not independently query R2 or prove
   production D1 concurrency/performance.
7. An authenticated, club-authorized content approval service may call the
   private `PublicSourcePublisher.publish` RPC with `snapshotId`, `approvedBy`,
   `approvalRef` and `expectedPreviousId`. It must derive `approvedBy` from its
   authenticated operator, not browser input. First publication requires an
   explicit null previous ID. Subsequent publication requires the exact current
   head. R2 originals are checked again; head, approval and state changes commit
   together. A stale competing request fails without changing the old head.
8. Verify the public candidate before changing the deployed public Worker or
   opting any web client into it. The public Worker expects the new tables and
   an approved head: deploying it prematurely deliberately returns 503, not an
   unreviewed legacy-data fallback.

`wrangler.publisher.staging.jsonc` names the already documented isolated staging
resources, has no public URL/preview, and sets `PUBLICATION_ENABLED=false`.
The authenticated approval caller/service binding and environment enablement
still require integration and accountable approval; this patch does not supply
staff authentication or assert a deployed publication service.

## Checks

```sh
node --experimental-sqlite --test cloudflare/rayon-public/tests/snapshot.test.mjs
(cd tools/scripts && python3 -m unittest -v test_public_snapshot_import)
python3 tools/scripts/verify_rayon_public_api_local.py
```

`replay_public_snapshot_export.mjs --database <local.sqlite> --media-dir <export/app-media>`
uses a disposable SQLite backup and a file-backed R2 test double. Its approval
identity is explicitly synthetic and never changes the source database or any
Cloudflare resource. Saved-source replay is useful evidence, not live deployment
or production authorization.

## Guarantees and remaining boundaries

Imports cannot freshen an older active snapshot. All stored records belong to a
snapshot-specific keyspace. Sealed records and media metadata cannot be edited.
Failed verification leaves the old public head unchanged. Unapproved rights
remain withheld. Media URLs carry snapshot identity and cannot select a different
publication. Cached responses can remain until their bounded cache lifetime;
instant revocation requires an operational cache-purge policy and is not claimed.

The staging export currently preserves a limited public-source subset. Original
AFRICLUB media recovery, identity migration, financial command proofs, function
and cron dispositions, operator approval integration, regional/load validation,
complete client upgrades, cutover and Supabase retirement remain separately gated.
