# LiveScore Web Sync

AFRICLUB uses admin-managed LiveScore web sources for football fixtures, teams,
results, competition metadata, live score updates, and pool settlement triggers.

The sync runner is:

```bash
tools/scripts/livescore_sync_runner.mjs
```

The deployed Supabase Edge Function for OpenAI-assisted LiveScore extraction is:

```text
supabase/functions/livescore-openai-sync
```

## Data Flow

1. Load active source rows from `public.livescore_competition_sources`.
2. Fetch the configured LiveScore web pages every 60 seconds.
3. Ignore every fixture whose competition does not match an active source row.
4. Extract embedded page JSON and normalize fixtures, competitions, seasons,
   teams, kickoff times, status, scores, team crests, and competition logos.
5. Upsert into `football.competitions`, `football.seasons`,
   `football.teams`, `football.season_teams`, and `football.fixtures`.
6. When a fixture is finished and has final scores, settle linked partner WDW
   pools through `partner_prediction_pool_settle`.

The runner fails closed when no active LiveScore source rows are configured.
The Edge Function uses the same source table and also rejects any OpenAI-returned
row whose supporting `source_url` is not under `livescore.com`.

## Required Environment

```bash
SUPABASE_URL=...
SUPABASE_SERVICE_ROLE_KEY=...
```

By default the runner reads:

```bash
LIVESCORE_WEB_URLS=https://www.livescore.com/en/
```

`LIVESCORE_WEB_URLS` is only a fallback. In production, admins manage source
URLs and competition filters in `public.livescore_competition_sources` from
`/admin/football-sync` > `LiveScore Sources`.

## Optional Environment

```bash
LIVESCORE_CLUB_ID=...
LIVESCORE_FIXTURE_ARRAY_PATH=data.fixtures
LIVESCORE_ENABLE_OPENAI_WEB_SEARCH=false
LIVESCORE_SEARCH_QUERY="site:livescore.com/en/ football live scores fixtures results today"
OPENAI_API_KEY=...
OPENAI_WEB_SEARCH_MODEL=gpt-4.1-mini
OPENAI_WEB_SEARCH_TOOL=web_search_preview
LIVESCORE_POLL_MS=60000
LIVESCORE_RUN_ONCE=false
LIVESCORE_MIRROR_ASSETS=true
LIVESCORE_ASSET_BUCKET=football-assets
LIVESCORE_DRY_RUN=false
```

`LIVESCORE_CLUB_ID` scopes source loading to global rows plus rows for one club.
Leave it unset when the LiveScore source list is platform-global.

`LIVESCORE_ENABLE_OPENAI_WEB_SEARCH=true` enables an optional fallback that asks
OpenAI web search to inspect LiveScore web pages and return fixture JSON. The
primary production path remains direct LiveScore page collection.

## Supabase OpenAI Edge Function

The `livescore-openai-sync` Edge Function uses OpenAI Responses API web search
to inspect LiveScore pages and returns strict fixture JSON. It supports:

- `mode: "preview"`: dry-run only, no writes and no pool settlement.
- `mode: "sync"`: upsert competitions, seasons, teams, fixtures, write
  `public.football_sync_log`, and settle finished linked partner pools.
- `club_id` / `clubId`: include global source rows plus one club-specific set.
- `source_keys` / `sourceKeys`: restrict a run to selected source keys.
- `limit`: maximum fixtures per run, capped at 100.
- `settle_pools` / `settlePools`: disable settlement when set to `false`.

Required deployed secrets:

```bash
OPENAI_API_KEY=...
OPENAI_LIVESCORE_MODEL=gpt-4.1-mini
OPENAI_LIVESCORE_WEB_SEARCH_TOOL=web_search_preview
LIVESCORE_SYNC_SECRET=...
```

The function accepts either `x-cron-secret: $LIVESCORE_SYNC_SECRET` for scheduled
machine calls or an authenticated admin user token. Gateway JWT verification is
disabled in Supabase config because the function performs internal auth.

Preview invocation:

```bash
curl -sS -X POST "$SUPABASE_URL/functions/v1/livescore-openai-sync" \
  -H "x-cron-secret: $LIVESCORE_SYNC_SECRET" \
  -H "content-type: application/json" \
  --data '{"mode":"preview","limit":5}'
```

Production cron should call the same endpoint every 60 seconds with
`{"mode":"sync","limit":100}` after a valid OpenAI key is configured.

## Managed Competition Sources

The source table controls both allowed competitions and page URLs:

```sql
select
  source_key,
  display_name,
  match_aliases,
  country_aliases,
  external_competition_ids,
  source_urls,
  is_active
from public.livescore_competition_sources
order by priority, display_name;
```

Initial seeded rows cover:

- 2026 World Cup
- UEFA Champions League
- UEFA Europa League
- Premier League
- La Liga
- Bundesliga
- Serbia A
- Ligue 1
- Rwanda Premier League
- DR Congo Linafoot
- Zambia Premier League

Admins can add, disable, rename, or remove rows without redeploying the sync
script.

## One-Time Sync

```bash
SUPABASE_URL=... \
SUPABASE_SERVICE_ROLE_KEY=... \
LIVESCORE_WEB_URLS=https://www.livescore.com/en/ \
LIVESCORE_RUN_ONCE=true \
node tools/scripts/livescore_sync_runner.mjs
```

## Continuous 60-Second Sync

```bash
SUPABASE_URL=... \
SUPABASE_SERVICE_ROLE_KEY=... \
LIVESCORE_WEB_URLS=https://www.livescore.com/en/ \
LIVESCORE_POLL_MS=60000 \
LIVESCORE_MIRROR_ASSETS=true \
node tools/scripts/livescore_sync_runner.mjs
```

## Dry Run

```bash
SUPABASE_URL=http://localhost:54321 \
SUPABASE_SERVICE_ROLE_KEY=dummy \
LIVESCORE_WEB_URLS=http://127.0.0.1:3000/en/ \
LIVESCORE_RUN_ONCE=true \
LIVESCORE_DRY_RUN=true \
node tools/scripts/livescore_sync_runner.mjs
```

Dry run parses and normalizes rows without writing Supabase data or settling
pools.

## Expected Fixture Fields

The runner accepts common LiveScore-style field names and nested variants:

- fixture id: `id`, `eventId`, `matchId`, `fixture.id`
- competition: `competition`, `league`, `tournament`
- teams: `homeTeam`, `awayTeam`, `home`, `away`, `teams.home`, `teams.away`
- time: `kickoff`, `kickoffAt`, `startTime`, `fixture.date`
- status: `status`, `state`, `matchStatus`, `fixture.status.short`
- score: `homeScore`, `awayScore`, `score.home`, `score.away`,
  `goals.home`, `goals.away`
- assets: `logo`, `logoUrl`, `crest`, `badge`, `image`

If the embedded LiveScore page data uses a different envelope, set
`LIVESCORE_FIXTURE_ARRAY_PATH`, for example:

```bash
LIVESCORE_FIXTURE_ARRAY_PATH=props.pageProps.fixtures
```
