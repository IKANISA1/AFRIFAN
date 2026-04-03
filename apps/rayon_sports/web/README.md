# Rayon Sports Web App

This is the production web surface for Rayon Sports. It complements the Flutter mobile app with:

- a public, SEO-friendly website for club discovery
- a mobile-optimized fan portal at `/app`
- Supabase-backed supporter flows for profile, membership, tickets, shop, fan clubs, contributions, and XP

## Stack

- `Next.js 16` with the App Router
- `React 19`
- `TypeScript`
- `Supabase` for auth and data
- `Vitest` + Testing Library for verification

## Local development

1. Copy `.env.example` into `.env.local`.
2. Fill in the Supabase values when you want live data.
3. Run:

```bash
npm install
npm run dev
```

The site will run on `http://localhost:3000`.

## Environment variables

- `NEXT_PUBLIC_SITE_URL`
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

Behavior:

- if browser Supabase env vars are present, the fan portal bootstraps an anonymous supporter session in the browser
- if server Supabase env vars are present, public pages can read live club data server-side
- if env vars are absent, the site falls back to embedded Rayon Sports content so the app still builds and renders

## Commands

```bash
npm run dev
npm run preview
npm run deploy
npm run lint
npm run typecheck
npm test
npm run build
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

Fan portal:

- `/app`
- `/app/profile`
- `/app/membership`
- `/app/tickets`
- `/app/shop`
- `/app/contributions`
- `/app/fan-clubs`
- `/app/xp`
- `/app/live/[matchId]`

## Deployment notes

- use the public site on the main club domain
- point the Supabase environment variables at the production project
- keep the service role key server-only
- rotate any previously committed secrets before exposing this app publicly

## Cloudflare deployment

The production worker is deployed with OpenNext for Cloudflare. The current worker name is `gikundiro-web`.

Preview locally through the Cloudflare runtime:

```bash
npm run preview
```

Deploy to Cloudflare Workers:

```bash
npm run deploy
```

The worker uses:

- `KV` incremental cache namespace: `NEXT_INC_CACHE_KV`
- `Workers` self-reference binding: `WORKER_SELF_REFERENCE`
- `Images` binding for `next/image`

Local preview envs are generated from `.env.local` into `.dev.vars` by `scripts/sync-cloudflare-dev-vars.mjs`.

### Custom domain cutover status

`gikundiro.com` is still delegated to Vercel DNS (`ns1.vercel-dns.com`, `ns2.vercel-dns.com`), and the current apex responds with `x-vercel-error: DEPLOYMENT_DISABLED`.

The Cloudflare worker is live and verified at:

- `https://gikundiro-web.ikanisa.workers.dev`

Cloudflare-side cutover is now prepared:

- zone created in account `Ikanisa`
- zone id: `6ea1b5005cb4305055062be88a5d65a8`
- assigned Cloudflare nameservers:
  - `robert.ns.cloudflare.com`
  - `stephane.ns.cloudflare.com`
- worker custom domains attached:
  - `gikundiro.com`
  - `www.gikundiro.com`

The remaining step is registrar-side only: update the authoritative nameservers at `Name.com` from Vercel DNS to the Cloudflare pair above. No usable `Name.com` credentials or API keys were present on this machine during the migration, so that final registrar change was not automated here.

## Current implementation boundary

Web v1 covers supporter-friendly browser features. Device-native mobile features such as NFC, face capture, and SMS auto-read remain mobile-only.
