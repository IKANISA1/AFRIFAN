# Venue App Architecture

Updated: 2026-07-30

## Purpose

The venue app is a venue-scoped operator portal for approved partner venues. It is not a supporter fan portal and it is not the centralized club admin PWA.

The first implementation lives under `apps/rayon_sports/web/src/app/venue` to reuse the existing Next.js app, Supabase client setup, PWA shell, and `DESIGN.md`-governed runtime theme implementation. It can be extracted later only if deployment, auth, or venue operations require a separate app.

Venue capability is a secondary matchday extension of the football-club
product. It must not determine the supporter app's primary navigation or
displace Club, football, or Membership. Supporter discovery belongs under a
contextual “Matchday experiences” or “Places to watch” entry; venue operations
remain in this portal.

## Product Boundary

| Capability | Venue app | Admin PWA | Mobile supporter app | Public website | TV display |
| --- | --- | --- | --- | --- | --- |
| Today dashboard | Yes | Oversight only | No | No | No |
| Orders queue | Yes | Oversight/export | User receipt/status | No | No |
| Drinks menu | Manage top 10 | Approve/disable | Browse/order | No | No |
| Check-ins | Review assigned venue | Review all scoped venues | Check in | No | Code prompt only |
| Promotions/FET campaigns | Draft/run approved templates | Approve/disable/export | Earn/receipt | Discovery only | Screen-safe promo |
| Staff roles | View assigned roles | Assign/revoke | No | No | No |
| TV code | Display assigned venue code | Pair/disable | Enter/scan | No | Display QR/code |

Game events and promotions use the authoritative club-scoped game and reward
contracts. A venue may host or display an approved event, but it must not create
an independent scoring, eligibility, question, reward, or supporter identity
truth.

## Feature Flags

- `venue_app_enabled`
- `venue_checkin_enabled`
- `venue_drinks_ordering_enabled`
- `venue_fet_rewards_enabled`
- `venue_geolocation_verification_enabled`
- `venue_tv_qr_enabled`
- `venue_games_promotions_enabled`

## Route Plan

| Route | Purpose | Gate |
| --- | --- | --- |
| `/venue` | Today dashboard and permission state | `venue_app_enabled` |
| `/venue/orders` | Order queue | `venue_drinks_ordering_enabled` |
| `/venue/menu` | Drinks menu manager with max 10 active drinks | `venue_drinks_ordering_enabled` |
| `/venue/checkins` | Check-in list/review | `venue_checkin_enabled` |
| `/venue/promotions` | Campaign template launcher | `venue_fet_rewards_enabled` |
| `/venue/tv-code` | Screen-safe QR/code view for venue staff | `venue_tv_qr_enabled` |
| `/venue/staff` | Assigned staff role view | `venue_app_enabled` |

## Data Ownership

- Every venue record has `club_id`.
- Every venue-owned record has `venue_id`.
- Venue staff access is granted through `venue_staff_memberships`.
- Venue staff can only access assigned venues.
- Club admins can inspect all venues inside their club scope.
- TV state is read-only and screen-safe.
- Public website reads only approved venue profile fields.

## MVP Data Model

The additive migration creates:

- `venues`
- `venue_staff_memberships`
- `venue_checkin_campaigns`
- `venue_checkin_codes`
- `venue_checkins`
- `venue_drink_items`
- `venue_drink_orders`
- `venue_drink_order_items`
- `venue_order_events`
- `venue_promotion_events`
- `venue_fet_wallets`
- `fet_ledger_reservations`

## RPC Contracts

- `venue_checkin_validate`: validates QR/code hash, expiry, duplicate, campaign state, and idempotency.
- `venue_order_create`: creates a drinks-only order and initial event row.
- `venue_order_update_status`: updates status and writes an event row.
- `venue_staff_can_access`: central venue staff permission helper.

## UAT Gates

- Supporter entry is secondary and contextual to a fixture, Home, Fan Zone, or
  global search; it is not a primary navigation destination.
- Venue staff can access only assigned venues.
- Permission denied state is visible and keyboard reachable.
- Orders write event rows for every status change.
- Max 10 active drinks is enforced server-side.
- Alcohol flag is required for drink items.
- Campaign budget and per-user limits are enforced server-side.
- No service-role key is exposed to browser clients.
