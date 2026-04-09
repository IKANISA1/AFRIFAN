# White-Label Club Web

This app is the shared white-label web surface for AfriClub. Rayon Sports remains the reference club profile and seeded default.

The repo now contains two web surfaces only:

- a public, SEO-friendly website for club discovery
- a centralized admin PWA at `/admin`

Fan journeys now live in the Flutter mobile app. The website can hand users off to the native supporter app without hosting a browser fan portal.

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

- if server Supabase env vars are present, public pages and admin APIs can read live club data server-side
- club resolution can be driven by `CLUB_HOST_MAP_JSON` / `NEXT_PUBLIC_CLUB_HOST_MAP_JSON`
- if env vars are absent, the site falls back to embedded reference content so the app still builds and renders

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
- `/supporters`

Admin PWA:

- `/admin`
- `/admin/settings`
- `/admin/matches`
- `/admin/cms`

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

The public site and admin PWA share one codebase and are club-scoped by hostname and club configuration. Device-native supporter workflows such as NFC, face capture, SMS auto-read, and authenticated fan journeys remain Flutter-only.
