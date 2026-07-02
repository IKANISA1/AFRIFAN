# Rayon Mobile Deferred Route Classification

Date: 2026-07-01
Goal: `output/mobi_borrowed_rayon_mobile_ux_full_implementation_goal_2026-07-01.md`

## Decision Summary

`AfriDeferredRouteLoader` exists and is tested in `core_router`, but this
rollout does not yet defer feature route libraries. The candidate screens are
currently compiled inside their feature packages, have stable focused tests, and
are not proven startup bottlenecks. Introducing deferred imports without a size
or startup profile would add routing/build complexity before there is evidence
that it improves the supporter experience.

Current decision: apply shared pushed-route motion to the remaining true detail
screens, use `afriSheetPage` for secondary surfaces that should stay
deep-linkable, and keep deferred loading available for the first candidate that
is proven heavy by bundle/runtime evidence.

## Classification

| Route | Feature package | Current decision | Evidence / reason |
| --- | --- | --- | --- |
| `/tickets/detail/:id` | `feat_ticketing` | Sheet route, not deferred now | Checkout detail remains deep-linkable but presents as a full-height sheet from Tickets. Defer only after route-level size/profile evidence shows startup cost. |
| `/tickets/map/:id` | `feat_ticketing` | Full-height modal, watchlist | Seat map is visually specialized and now presents as a modal route inside the ticket flow. Defer after profiling or after extracting the map into a clean deferred library. |
| `/e-ticket/:id` | `feat_ticketing` | Watchlist | QR route is visually specialized and scanner-adjacent, but current reduced-motion test coverage is stable. Defer only after confirming QR/scanner dependencies materially affect startup or route load. |
| `/shop/product/:productId` | `feat_shop` | Sheet route, not deferred now | Product detail remains deep-linkable but presents as a full-height sheet from Shop. Deferred loading is unnecessary without evidence. |
| `/fanzone/match/:fixtureId` | `feat_gamification` | Watchlist | Match detail is data-heavy and can become a deferred candidate, but Fan Zone navigation and prediction providers are currently package-coupled. Defer after provider boundary review. |
| `/fanzone/team/:teamSlug` | `feat_gamification` | Sheet route, watchlist | Team profile is deep-link context only and now presents as a full-height sheet. Consider deferred split after tab/provider profiling. |
| `/fanzone/league/:competitionSlug` | `feat_gamification` | Sheet route, watchlist | League hub may be heavy when standings/fixtures expand, but now presents as hub depth instead of a full destination. |
| `/fanzone/standings/:competitionSlug` | `feat_gamification` | Sheet route, not deferred now | Standings belongs inside league/match context and now presents as a full-height sheet. |
| `/challenge/:id` | `feat_gamification` | Watchlist | Challenge detail is opt-in and potentially data-heavy, but challenge is already feature-gated and package-local. Defer after launch gating and provider split are stable. |

## Required Evidence Before Deferring A Route

- a measured startup or first-route-load issue
- a clean import boundary that avoids pulling the deferred screen into the root
  feature module
- widget tests for deferred loading, loaded, and failure states
- route tests proving deep links and shell tab behavior still work
- manual or golden evidence that the skeleton loader does not regress layout

## Current Implementation Action

All classified candidate routes should use either `afriRoutePage` when they are
approved full screens or `afriSheetPage` when they are secondary surfaces.
Deferred loading remains implemented in shared infrastructure and covered by
router tests, but no production feature route is deferred in this slice.
