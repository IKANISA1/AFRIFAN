# White-Label Club Web

This app is the shared white-label web surface for AfriClub. Rayon Sports remains the reference club profile and seeded default.

This application contains:

- the public club website;
- authenticated membership access and contribution initiation at `/membership`;
- the club admin PWA at `/admin`;
- the venue operator portal at `/venue`.

Flutter remains the full supporter app. Web membership actions require trusted
server-side identity and club scope. Opening a MoMo route or creating an intent
does not confirm payment; backend reconciliation owns payment finality.

## Stack

- `Next.js 16` with the App Router
- `React 19`
- `TypeScript`
- `Supabase` for auth and data
- `Vitest` + Testing Library for verification

## Local development

1. Copy `.env.example` into `.env.local`.
2. Fill in the Supabase values when you want live data.
3. Load the repository Node version and install the exact locked dependencies:

```bash
nvm use
corepack npm ci
corepack npm run check:dependencies
corepack npm run dev
```

The package-manager contract is `npm@12.0.2` via Corepack. Do not add a second
lockfile or use pnpm/yarn in this app.

The site will run on `http://localhost:3000`.

## Environment variables

- `NEXT_PUBLIC_SITE_URL`
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

Behavior:

- if server Supabase env vars are present, public pages and authorized member/admin/venue APIs can read club data server-side
- club resolution can be driven by `CLUB_HOST_MAP_JSON` / `NEXT_PUBLIC_CLUB_HOST_MAP_JSON`
- if env vars are absent, the site falls back to embedded reference content so the app still builds and renders

## Commands

```bash
corepack npm run dev
corepack npm run preview
corepack npm run deploy
corepack npm run lint
corepack npm run typecheck
corepack npm test
corepack npm run build
```

## Route map

Public site:

- `/`
- `/news`
- `/news/[articleId]`
- `/fixtures`
- `/fixtures/[matchId]`
- `/results`
- `/standings`
- `/squad`
- `/shop`
- `/shop/[productId]`
- `/tickets`
- `/tickets/[matchId]`
- `/membership`
- `/fan-clubs`
- `/history`
- `/contact`
- `/privacy`
- `/terms`
- `/supporters`

Admin PWA:

- `/admin`
- `/admin/settings`
- `/admin/matches`
- `/admin/cms`
- additional operator domains under `src/app/admin`

Venue portal:

- `/venue`
- assigned-venue operations and ticket verification under `src/app/venue`

## Deployment notes

- use the public site on the main club domain
- point the Supabase environment variables at the production project
- keep the service role key server-only
- rotate any previously committed secrets before exposing this app publicly

## Cloudflare deployment

The production worker is deployed with OpenNext for Cloudflare. The current worker name is `gikundiro-web`.

Preview locally through the Cloudflare runtime:

```bash
corepack npm run preview
```

Deploy to Cloudflare Workers:

```bash
corepack npm run deploy
```

The worker uses:

- `KV` incremental cache namespace: `NEXT_INC_CACHE_KV`
- `Workers` self-reference binding: `WORKER_SELF_REFERENCE`
- `Images` binding for `next/image`

Local preview envs are generated from `.env.local` into `.dev.vars` by `scripts/sync-cloudflare-dev-vars.mjs`.

### Release verification

`wrangler.jsonc` declares this checkout's deployment targets. Verify actual
DNS, domains, Worker version, backend project, and release approval at release
time. A repository README does not establish current hosting or serving status.
Do not infer deployment ownership for another Gikundiro checkout from the
shared product name.

Use [the release and rollback runbook](docs/cloudflare-release-cutover.md) and
[the repository release checklist](../../../docs/rayon_sports_release_checklist.md).
