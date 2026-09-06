# Simplified Predict

The Challenge replacement uses the current implementation in the separate
`/Volumes/PRO-G40/Gikundiro` checkout as the behavioral reference. That checkout
and its database remain separate from AFRICLUB.

## Source review

| Concern | Gikundiro authority | AFRICLUB adaptation |
| --- | --- | --- |
| Supporter journey | `src/components/public/PublicPredictPage.jsx` and `src/lib/predictApi.js` | Dedicated `/predict`, compact fixture cards and Home / Draw / Away choices; no supporter-created pools or exact scores |
| Eligibility | `src/lib/predictFixtures.js`, public dashboard and governed fixture/pool reads | Future, confirmed, approved fixtures with both crests and an open pool; server checks the actual kickoff boundary |
| Session | `member-portal-api` action `place_prediction` | Existing verified Supabase phone session and trusted club claim; no second verification or client-selected user |
| Economics | `20260824124500_predict_fet_partner_bill_settlement.sql` | 100 FET default entry, stored on each pool; 500 FET welcome once per verified supporter and club |
| Settlement | `settle_gikundiro_prediction_pool` in `20260823101000_predict_fet_partner_rewards.sql` | Complete pool shared by correct entries; deterministic remainder; no-winner and void refunds; immutable existing wallet ledger |
| Locking | `20260826133000_automatic_prediction_pool_locking.sql` | Scheduled state synchronization plus exact write-time rejection; no manual Lock control |
| Operations | `predict-admin-api` and `AdminPredictWorkspace.jsx` | Club-scoped fixture ledger, prepare, confirm result, settle and void/refund |

The earlier Gikundiro migration used 500 FET per entry and charged current
settings. The later migration supersedes both rules: 100 FET default, charging
the stored pool price. The source code, rather than the older memory audit,
determines this implementation.

AFRICLUB retains its shared Flutter semantic design system and the selected
September iOS Dark Glow component references. Gikundiro's web-only palette is
not a new mobile theme. Registered team and competition marks remain artwork.

## Data and API boundary

AFRICLUB uses its existing football fixtures, club IDs, verified users,
`fan_memberships.points` balance and `fet_wallet_ledger_entries`. Protected
PostgREST RPCs own writes; mobile code never updates pool or wallet tables.
The replacement does not create a second balance or import Gikundiro records.

Old exact-score Challenge APIs are retired. The remote preflight found no
Challenge records or unsettled entries, so its empty tables were dropped. For
other environments with completed history, the migration retains those rows
in a private archive for ledger traceability. The migration refuses to retire any
unsettled entry; operators must reconcile it using the pre-existing system
before applying the migration. Applied migration history remains intact.

Existing production store-release authorization remains a distinct control,
renamed to the Predict feature. No visual or local test grants that approval.

## Verification status — 6 September 2026

The Google Drive **Supabase** sheet identified the AFRICLUB project. Its
credentials were used outside the repository and are not part of the app,
migration, screenshots or evidence. Gikundiro's database was not modified.

- Migration `20260906082522_simplified_predict.sql` applied through Supabase's
  migration API; the remote migration ledger independently confirms its version.
- Remote inspection confirms RLS on all three Predict tables, no PUBLIC execute
  grants on Predict RPCs, no old Challenge RPCs/tables, the `/predict` feature
  channel, and the active per-minute `predict-pool-locks` schedule.
- `football-sync` version **16**, **ACTIVE**, independently read back after
  deployment. Its automatic maintenance calls Predict locking; payouts still
  require an operator-confirmed official result.
- Anonymous-role `predict_dashboard(24)` succeeded in an explicit rolled-back
  database transaction. It truthfully returned disabled, no prepared fixtures,
  no private wallet or history. No synthetic production fixtures were inserted.
- **80 pgTAP checks** passed against all replayed migrations, including rights,
  tenant isolation, accounting, result authorization, deterministic distribution,
  no-winner/void refunds and idempotency. Three real concurrent-session scenarios
  passed: repeated entry, competing wallet debits, and waiting across kickoff.
  Four complete repeat runs passed after correcting a membership creation race.
- The membership helper now tolerates either of its existing unique constraints
  before locking the canonical wallet row. No second wallet is introduced.
- Flutter package regression produced 750 passing tests and one obsolete route-count
  assertion. After replacing the four Challenge routes with Predict and fixing
  that assertion, the 93-test affected rerun passed, including all 31 new
  supporter/admin golden states. Static analysis reports no issues.
- 219 unused localization keys from the removed Challenge screens were deleted
  from each catalog; English output was regenerated. Literal and dynamic copy
  inventories have zero pending items.
- The iOS simulator screen journey passed with a synthetic backend: a rapid
  double tap creates one pick and one debit, and history/activity display the
  confirmed record. This verifies native UI behavior, not a live API journey.

**Live API limitation:** PostgREST currently returns HTTP **402** with
`exceed_storage_size_quota`. Management access and the deployed function's
ACTIVE state do not resolve that provider restriction. A live authenticated
supporter/API check remains pending restoration of project access. Predict
also remains disabled until operators explicitly enable it and prepare real,
approved fixtures; existing production store-release authorization is preserved.

## Unified navigation and state ownership — 6 September 2026

The current shared mobile shell is Home, Club, Predict and Membership. Predict
is `/predict`; `FanzoneModule` retains only the existing configuration key and
hosts that tab. `PredictModule` is a deprecated compatibility type and is no
longer registered separately. `FanzoneHubScreen` delegates to `PredictScreen`.
The obsolete aggregate Fan Zone provider and unused hub widgets are removed.

`section=history` and `section=wallet` preserve the active shell and are deep
linkable. The old Challenge and Fan Zone entry routes redirect into those
sections. Match/league browsing belongs under Club; communities use `/fan-clubs`
and initiatives use `/contribute`, each with their existing detail routes.
Historical prediction details and operational venue utilities remain registered.

One PredictController owns fixtures, confirmed entries and FET activity. It
blocks offline, duplicate and uncertain submissions, refreshes after reconnect
or foregrounding, and preserves confirmed data on recoverable failures. The
screen schedules the next actual lock/kickoff boundary instead of repainting
every second. Backend RPC, authentication and store-release checks remain the
write authority. This UI consolidation applies no remote database changes.

Community discovery now filters reads by the resolved club id and opens details
for request review; it no longer reports a request as sent without an API write.
Its static club-specific fallback is not substituted into other clubs' data.
