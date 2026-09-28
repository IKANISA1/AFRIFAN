# AFRICLUB Cloudflare migration: stage-0 live inventory

Captured 24 September 2026 at 08:36 UTC via Supabase Management API read-only queries. The machine-readable metadata and checksums are in ignored `output/migration/cloudflare-stage0/`; no member records, payment references, phone numbers or secret values were written to this inventory. Counts were queried sequentially, so they are a point-in-time working baseline, not one transactionally consistent snapshot.

**Current scope correction, 25 September:** the original four-schema table below omitted the live `africlub_game` schema. The refreshed five-schema inventory has 234 relations: 197 tables and 37 views, 342 application functions, 354 policies, 198 non-internal triggers and 769 indexes. The additional game schema has 25 tables (46 rows at refresh), 36 functions, 42 policies, 12 triggers and 122 indexes. `cron`, `net` and other provider-managed schemas are separate archival dependencies; they are not part of the 197 application/Auth/Storage table count. The ignored JSON inventory now reflects this corrected scope. The original table below is retained as the dated initial observation.

## Live scope

| Item | Observed |
| --- | ---: |
| PostgreSQL version | 17.6 |
| Database bytes | 228,895,891 |
| Auth users | 178 |
| Applied migration records | 126 |
| Relations in public, football, auth and storage | 209: 172 tables and 37 views |
| Exact table counts captured in those schemas | 172 of 172 |
| Public/football functions | 306 |
| Policies / non-internal triggers / indexes | 312 / 186 / 647 |
| Deployed Edge Functions / active cron jobs | 18 / 6 |
| Edge Function secret names | 25; values excluded |
| Storage buckets / objects | 2 / 8 |
| Club registry rows | 96 |

The local source scan captured 384 literal Supabase call sites: 301 `.from`, 49 `.rpc`, 27 auth operations and seven Edge Function invokes. Dynamic names and calls constructed indirectly still need runtime tracing or targeted code review. The catalog pass above is scoped to four key schemas; extension-managed schemas such as `cron` still need a full archival inventory. For example, `cron.job_run_details` separately has about 194,840 rows and occupies 73.7 MB including indexes.

Only club ID 24, `rayon_sports_rw`, is both `is_onboarded` and `is_active` in the live registry. This does not establish that the other app flavors are ready or retired.

Large exact table counts include `football.fixture_markets` 86,975, `public.operational_health_events` 33,778, `public.admin_audit_log` 1,701 and `football.fixtures` 1,175. These are live counts from the API, while `pg_class.reltuples` in the JSON inventory is only an estimate.

`product-images` is public and holds eight objects with 12,695,265 bytes recorded in object metadata. `africlub-product-images` is public and empty. The object byte sum has not been verified against downloaded originals.

The six active scheduled jobs are `check-momo-sms-migration-safety-daily`, `daily-fixture-sync`, `predict-pool-locks`, `purge_edge_function_rate_events`, `redact-momo-sms-artifacts-daily` and `settle-prediction-notifications`. The inventory stores command fingerprints, not command text.

All 18 live Edge Functions were listed. `game-session-action` and `generate-question-drafts` are deployed but absent from local `supabase/functions`. `google-wallet-ticket-pass` and `sync-google-wallet-ticket-state` exist locally but are not deployed. Recover or specify the two live-only functions before replacing them; confirm whether the local-only Wallet functions are intended for a future release.

## Export state and next gate

- Read-only database catalog and count queries succeed. The direct PostgreSQL hostname resolved only to IPv6 and timed out from this host. A PostgreSQL 17 client in Docker authenticated through the session pooler and began a full logical dump. The pooler then closed SSL during `COPY cron.job_run_details` (about 194,840 rows). The incomplete archive was removed. A full logical dump and restore test have **not** happened. Retry with a supported stable export route or independently export the large operational table in verified chunks; do not count a partial archive as the backup gate.
- A separate schema-only custom archive for `public`, `football`, `auth` and `storage` succeeded at ignored `output/migration/cloudflare-stage0/database/africlub-schema-four-schemas-2026-09-24.dump` (2,026,891 bytes; SHA-256 `b316f2572afe9f622cd7874969954514389fb4a34aa874033f378331ad4e0f08`). PostgreSQL 17 `pg_restore --list` found 3,305 archive entries and `pg_restore --file=/dev/null` extracted SQL successfully. This validates archive readability, not a restore or data backup.
- An eight-object Storage export was attempted using authenticated access; the first object returned HTTP 402. A public-object read also returned HTTP 402. No media original or checksum manifest was exported. `tools/scripts/export_supabase_storage_for_cloudflare.py` can rerun after source access is restored.
- On 25 September, the Storage API's HTTP 402 body identified `exceed_storage_size_quota` and stated that the project owner must upgrade the plan or remove the spend cap. The migration has not changed billing or deleted source objects.
- No Cloudflare production database, media bucket or API was created. No Supabase runtime was changed. Cutover and Supabase retirement are blocked until a restorable database export, complete object export and reconciliation are proven.
- The connected Cloudflare account currently lists no AFRICLUB D1 database or R2 bucket. Existing resources belong to other projects; AFRICLUB isolation must be created deliberately at the infrastructure stage.

The inventory can be refreshed with `python3 tools/scripts/inventory_cloudflare_migration.py`. The Storage exporter uses read-only object downloads and writes to ignored `output/`; its output remains incomplete while Supabase returns HTTP 402.

## Continuation: 25 September 2026

The large `cron.job_run_details` table was exported separately through the session pooler in 40 bounded CSV segments. The captured range contained 197,392 rows; the segment row counts matched the count recorded at export start, and all 40 file hashes matched their manifest. The files total 64,305,436 bytes under ignored `output/migration/cloudflare-stage0/database/cron-job-run-details/`. This is not one transactionally consistent snapshot; live cron jobs continued while the segments were read. `tools/scripts/export_supabase_cron_history_for_cloudflare.py` reproduces the export.

The separate Gikundiro **public content used by Rayon** was captured through its anonymous read API, without migrating the standalone website or its member transactions. The dated snapshot contains 1,770 approved public prediction fixtures, 99 open pools, 30 public news posts, 39 players, 42 fanclubs, three partners, 15 shop products, 16 ticket sales with 160 categories, six membership tiers, and the supporting club/team/category/media metadata. These counts are a 25 September source snapshot and differ from the earlier 23 September parity checkpoint. Eleven media originals referenced by the current app squad, partners and eligible shop products were downloaded; each matched its registered byte size and SHA-256. The private row and media manifests are under ignored `output/migration/cloudflare-stage0/gikundiro-public/`. `tools/scripts/snapshot_gikundiro_public_for_cloudflare.py` and `tools/scripts/export_gikundiro_app_media_for_cloudflare.py` reproduce those artifacts. Publication still requires current-season filtering, rights checks, mapping to AFRICLUB IDs and a Cloudflare destination.

The AFRICLUB PostgreSQL archive excluding only `cron.job_run_details` table data completed at ignored `output/migration/cloudflare-stage0/database/africlub-excluding-cron-history-2026-09-25.dump` (8,628,304 bytes; SHA-256 `b63b028fd1c4a664855e4121dea37985805a6d0c649a31c844b09cac358ef851`). PostgreSQL 17 listed 5,033 archive entries and extracted its SQL successfully. It contains Auth and application table data. It is paired with the segmented cron history above, but the pair is **not a transactionally consistent snapshot** and has not passed a restore drill. The eight AFRICLUB Storage originals remain inaccessible with HTTP 402. `tools/scripts/export_supabase_database_for_cloudflare.py` reproduces the archive after source access and local Docker are available.

A local-only Cloudflare D1 staging database was created from the Gikundiro public snapshot under `cloudflare/rayon-public/`. The schema preserves source table, source ID, payload hash, media path, checksum and rights metadata. The ignored seed imported 2,628 source rows and 11 media metadata records; `tools/scripts/verify_rayon_public_d1_local.py` confirmed exact payload and rights parity and SQLite integrity. A local Worker reads those rows through nine fixed public routes. `tools/scripts/verify_rayon_public_api_local.py` exercised every route and denied write and unknown methods. At that check, the routes returned 15 future confirmed Rayon fixtures, 30 recent news posts, 39 squad members, 42 fanclubs, three partners, two rights-eligible current-season products, 15 future reservation-only ticket sales, six tier descriptions and 15 read-only pool previews. This is local implementation, not a remote Cloudflare API or app cutover. The media originals remain in the private export directory until R2 is provisioned and upload hashes are read back.

Supabase documents [logical backup and session-pooler use](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore) and confirms that [database backups exclude Storage originals](https://supabase.com/docs/guides/platform/backups).

## Remote staging and restore drill: 25 September 2026

An isolated Cloudflare D1 database (`africlub-rayon-public-staging`) and private R2 bucket (`africlub-rayon-public-media-staging`) were created. A remote D1 export was restored into local SQLite and passed exact JSON/hash parity for all 2,628 approved source rows and 11 media metadata records. All 11 downloaded source originals were uploaded to R2, read back, and SHA-256 matched. Two partner SVGs have `review-before-commercial-reuse` rights; their originals are preserved privately, while the public Worker suppresses their logos. The staging Worker version `0e214540-75af-4331-82e3-bf27381e74a0` serves nine read-only public routes at `https://africlub-rayon-public-staging.ikanisa.workers.dev`, plus rights-checked media. Remote route tests passed, including exact bytes for published shop images and denial of uncleared partner media. Responses fail closed after 24 hours without a fresh approved snapshot. The Rayon web source adapter has an explicit Cloudflare staging option; its focused tests and live smoke passed, but no production client has been switched.

The AFRICLUB custom archive was restored with `pg_restore --exit-on-error` into a freshly recreated `postgres` database in an isolated `public.ecr.aws/supabase/postgres:17.6.1.158` container. All 40 checksum-verified cron CSV segments were then imported. Readback found 178 Auth users, 197,392 cron-history rows, 86,975 fixture-market rows, 1,175 football fixtures and eight Storage metadata rows, matching their source snapshots. The six restored cron jobs were disabled in the disposable container, and the container was stopped and removed. This is a successful archive and sampled-count restore drill, **not** a transactionally consistent final backup; Storage originals remain outside the archive and inaccessible through the source Storage API.

The eight AFRICLUB Storage originals have no same-size copy in this checkout or the separate recovered Gikundiro checkout. Source downloads still return HTTP 402 `exceed_storage_size_quota`. No Supabase billing or spend-cap setting was changed. This blocks a complete export and retirement. Cloudflare staging contains only the separate Rayon public-content source subset, not AFRICLUB Auth, transactional tables, functions or jobs.

All 18 deployed Edge Function bodies were also downloaded through the read-only Management API body endpoint into ignored `output/migration/cloudflare-stage0/edge-functions/`. Their 139,408,593 bytes and SHA-256 hashes passed local readback. The bundles are ESZIP 2.3. A compatible parser extracted 107 copies of first-party modules into a private directory, including the `game-session-action` and `generate-question-drafts` entrypoints absent from the checkout. The former exposes managed-session, join, answer, draft-review, pack-publication and TV actions; the latter creates source-linked question drafts for admin review. Raw entrypoint hashes differ from the local checkout for all 16 functions present in both places; some differences may be bundling transformations, so the deployed code needs a behavior-level comparison before replacement. None of these functions has been ported to Cloudflare. The supported CLI download path failed before extraction because the remote project's SMS Auth hook secret configuration was rejected by its validator; the parser supplied a read-only alternative.
