# Venue Portal Architecture

## Purpose

The venue portal is a venue-scoped operator surface for approved matchday
partners. It is not a supporter portal and does not replace the centralized
club admin PWA.

The implementation lives under `apps/rayon_sports/web/src/app/venue` and uses
the shared Next.js shell, Supabase integration, PWA configuration, and
`DESIGN.md` tokens.

Venue capability is secondary to the football-club product. Supporter discovery
appears contextually under matchday experiences or places to watch; operator
work remains in the venue portal.

## Capability Boundary

| Capability | Venue portal | Admin PWA | Supporter app | Public site |
| --- | --- | --- | --- | --- |
| Today dashboard | Assigned venue | Club oversight | No | No |
| Order queue | Operate | Oversight/export | Receipt/status | No |
| Drinks menu | Manage top 10 | Approve/disable | Browse/order | No |
| Check-ins | Review assigned venue | Review club venues | Check in | No |
| Promotions and FET campaigns | Run approved templates | Approve/disable/export | Earn/receipt | Discovery only |
| Staff roles | View assignment | Assign/revoke | No | No |

The venue never creates an independent source of truth for football results,
prediction eligibility, supporter identity, points, or rewards.

## Feature Flags

- `venue_app_enabled`
- `venue_checkin_enabled`
- `venue_drinks_ordering_enabled`
- `venue_fet_rewards_enabled`
- `venue_geolocation_verification_enabled`

## Routes

| Route | Purpose | Gate |
| --- | --- | --- |
| `/venue` | Today dashboard and permission state | `venue_app_enabled` |
| `/venue/orders` | Order queue | `venue_drinks_ordering_enabled` |
| `/venue/menu` | Drinks menu manager with maximum 10 active items | `venue_drinks_ordering_enabled` |
| `/venue/checkins` | Check-in list and review | `venue_checkin_enabled` |
| `/venue/promotions` | Approved campaign launcher | `venue_fet_rewards_enabled` |
| `/venue/staff` | Assigned staff role view | `venue_app_enabled` |

## Data Ownership

- Every venue record carries `club_id`.
- Every venue-owned record carries `venue_id`.
- Access is granted through `venue_staff_memberships`.
- Staff can access only assigned venues.
- Club admins can inspect venues only within their club scope.
- The public site reads only approved venue profile fields.

## Data Model

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

## Server Contracts

- `venue_checkin_validate` validates code hash, expiry, duplicate use, campaign
  state, location rule, and idempotency.
- `venue_order_create` authoritatively prices and creates a drinks-only order
  plus its initial audit event.
- `venue_order_update_status` enforces the state machine and writes an event.
- `venue_staff_can_access` is the central staff permission helper.

## UAT Gates

- Venue entry is secondary and contextual; it is not primary supporter
  navigation.
- Staff can access only assigned venues.
- Permission denied is visible and keyboard reachable.
- Every order status change writes an event.
- The maximum of 10 active drinks is enforced server-side.
- Alcohol classification and approved age controls are enforced.
- Campaign budget and per-user limits are enforced server-side.
- Offline, conflict, timeout, retry, and stale-queue states recover safely.
- No service-role key or private supporter field reaches the browser.
