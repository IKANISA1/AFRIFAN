# Rayon public-source D1 staging

This local-only D1 database proves that the Rayon app's approved public Gikundiro source snapshot can be preserved with source IDs, row hashes and media rights metadata. A Worker serves fixed read-only routes for fixtures, news, squad, fanclubs, partners, shop, tickets, tier descriptions and pool previews. It does not serve deployed application traffic, authenticate members, or implement payment, ticket or Predict transactions. The separate Gikundiro website is outside this delivery target.

1. Capture source rows with `python3 tools/scripts/snapshot_gikundiro_public_for_cloudflare.py`.
2. Export registered app media with `python3 tools/scripts/export_gikundiro_app_media_for_cloudflare.py`.
3. From the repository root, apply the local schema:

   ```sh
   apps/rayon_sports/web/node_modules/.bin/wrangler d1 execute africlub-rayon-public-local --local --config cloudflare/rayon-public/wrangler.local.jsonc --file cloudflare/rayon-public/migrations/0001_source_staging.sql
   ```

4. Generate and import the ignored seed:

   ```sh
   python3 tools/scripts/seed_rayon_public_d1_local.py
   apps/rayon_sports/web/node_modules/.bin/wrangler d1 execute africlub-rayon-public-local --local --config cloudflare/rayon-public/wrangler.local.jsonc --file output/migration/cloudflare-stage0/cloudflare-rayon-public-local/seed.sql
   ```

5. Run `python3 tools/scripts/verify_rayon_public_d1_local.py` for row, hash, media-rights and database-integrity parity.
6. Start the local Worker with `apps/rayon_sports/web/node_modules/.bin/wrangler dev --config cloudflare/rayon-public/wrangler.local.jsonc --local --port 8799`, then run `python3 tools/scripts/verify_rayon_public_api_local.py` in another terminal.

All captured rows, media files, generated SQL and the local D1 state are git-ignored. The local Wrangler database ID is a placeholder. The Worker exposes only whitelisted public fields and disables paid ticket issuance, checkout, tier purchase and prediction entry.

The isolated remote staging configuration is `wrangler.staging.jsonc`. The 25 September snapshot was imported to its D1 database, exported back and checked against all 2,628 source rows and 11 media metadata records. The 11 originals were uploaded to its private R2 bucket and downloaded for SHA-256 comparison. The Worker serves cleared images from R2; two partner SVGs marked `review-before-commercial-reuse` remain private and partner rows have no logo URL. The Worker returns `source_stale` after 24 hours without a new approved snapshot. Its staging URL is `https://africlub-rayon-public-staging.ikanisa.workers.dev`.

Rayon web can opt into this source with `RAYON_PUBLIC_CLOUDFLARE_URL` set to that exact staging origin. It fails closed on stale or invalid responses; the production web environment has not been switched. The remote staging service is a migration proof, not the production backend. Production still needs a governed content-authoring and refresh path, permanent domain, full AFRICLUB media export, Auth, transactional commands, jobs, realtime, client upgrades and cutover controls.
