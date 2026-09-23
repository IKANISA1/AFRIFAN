# Gikundiro Cloudflare release and rollback runbook

This runbook verifies and promotes the `gikundiro-web` Worker declared in this
checkout. Inspect current routing before choosing a cutover. The hostname
procedure below applies only when the intended domains are still attached to
an existing Pages deployment; it is not a statement of current DNS ownership.
Preserve any active origin until its replacement and rollback are verified.

## Candidate gate

1. Confirm the repository is clean and record the exact source commit. Obtain
   the Google Play **app-signing** SHA-256 fingerprint (not only the upload-key
   fingerprint), then provide it to the release build through the controlled
   public build setting:

   ```bash
   export NEXT_PUBLIC_ANDROID_APP_LINK_SHA256_FINGERPRINTS="PLAY_APP_SIGNING_SHA256"
   ```

   A candidate that does not publish this fingerprint must not be cut over.
2. Run `npm ci`, `npm run lint`, `npm run typecheck`, `npm test`, and
   `npm run test:cloudflare-release` from this directory.
3. Build the Cloudflare bundle, then validate it without deployment:

   ```bash
   npm run build
   npx opennextjs-cloudflare build --skipNextBuild
   node scripts/fix-route-group-manifests.mjs --open-next
   npx wrangler deploy --dry-run
   ```
4. Upload, but do not deploy, the exact candidate as a version with a preview
   alias. `versions upload` is the safe candidate operation: it must leave the
   current deployment and routes unchanged.

   ```bash
   npx wrangler versions upload \
     --strict \
     --keep-vars \
     --tag "SOURCE_COMMIT" \
     --message "Gikundiro release candidate SOURCE_COMMIT" \
     --preview-alias "candidate-SHORT_COMMIT"
   ```

   Record the version ID and exact preview URL printed by Wrangler. Confirm the
   active deployment is still the pre-release version before continuing.
5. Run:

   ```bash
   npm run validate:cloudflare-release -- \
     --url https://PREVIEW_ALIAS_FROM_WRANGLER \
     --play-fingerprint "PLAY_APP_SIGNING_SHA256" \
     --output /absolute/evidence/path/workers-dev-validation.json
   ```

6. Record the prior deployment/version ID and candidate version ID. Keep the
   prior version available for `wrangler rollback`. Start a filtered
   `wrangler tail` session for the candidate during cutover.

## Read-only snapshot

Copy `cloudflare-cutover-evidence.template.json` outside the repository and
record:

- every DNS record for `gikundiro.com`, especially apex, `www`, `admin`,
  `fans`, MX, TXT, CAA, and mail records;
- all Pages custom-domain associations and their IDs;
- all Worker custom domains/routes and their IDs;
- the current Pages deployment and Worker deployment/version IDs;
- active TLS status for each hostname.

Do not change MX, TXT, CAA, mail, or unrelated subdomain records. Do not delete
the Pages project.

Before the first hostname is moved, deploy the already validated candidate
version at 100% to the Worker service:

```bash
npx wrangler versions deploy "CANDIDATE_VERSION_ID@100%" \
  --yes \
  --message "Promote validated Gikundiro candidate SOURCE_COMMIT"
```

Re-run the validator against the normal `workers.dev` URL and confirm the
version ID. Do **not** run `npm run deploy`, `opennextjs-cloudflare deploy`, or
`wrangler deploy` during the canary: `wrangler.jsonc` declares all four
production domains and a full deploy can attach them as one change.

## Canary cutover

Use this order: `fans`, `admin`, `www`, then apex.

For each hostname:

1. Remove only that hostname's Pages custom-domain association and only the DNS
   record owned by that association when Cloudflare requires it.
2. Attach only that hostname to `gikundiro-web` as a Worker Custom Domain,
   using the Cloudflare Custom Domains control or an equivalently scoped API
   call.
3. Wait for Custom Domain and TLS status to become active.
4. Run the validator against that exact hostname and attach the JSON report to
   the evidence record.
5. For `admin`, additionally confirm an unauthenticated Admin API request
   returns a controlled JSON authentication/configuration response rather than
   HTML.
6. Observe Worker errors, 5xx rate, and latency before proceeding to the next
   hostname.

Final validation:

```bash
npm run validate:cloudflare-release -- \
  --url https://fans.gikundiro.com \
  --url https://admin.gikundiro.com \
  --url https://www.gikundiro.com \
  --url https://gikundiro.com \
  --play-fingerprint "PLAY_APP_SIGNING_SHA256" \
  --output /absolute/evidence/path/custom-domain-validation.json
```

## Rollback

Rollback one hostname when its TLS, policy pages, association files, Admin
boundary, or critical journeys fail:

1. Detach only the failed Worker Custom Domain.
2. Restore the exact saved DNS record and Pages custom-domain association for
   that hostname.
3. Wait for TLS and Pages association status to become active.
4. Re-run HTTP checks and record the rollback result.
5. If the Worker itself is faulty but routing is correct, run the exact-version
   rollback below, validate `workers.dev`, and then validate every hostname
   still attached to the Worker before retrying:

   ```bash
   npx wrangler rollback "VERSION_ID_BEFORE" \
     --yes \
     --message "Rollback Gikundiro cutover after failed release gate"
   ```

Keep Pages until all four hosts have remained healthy through the approved
observation window and the release owner has accepted the rollback evidence.
