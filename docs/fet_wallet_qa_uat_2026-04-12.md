# FET Wallet QA/UAT

Date: `2026-04-12`

Scope:
- supporter FET wallet balance
- partner initiative earn events
- partner WDW pool entry, payout, and refund ledger events
- admin wallet investigation and manual adjustment
- seeded regression coverage for the active AFRICLUB wallet scope

Launch alignment note, updated `2026-06-29`: public supporter-to-supporter
transfer and manual amount redemption are no longer launch wallet behavior.
FET is treated as a closed-loop rewards ledger for partner initiatives,
partner-funded football WDW pools, catalog rewards, and audited admin
adjustments.

Out of scope:
- loans

## Prerequisites

- Repo root: `/Volumes/PRO-G40/AFRICLUB`
- Linked Supabase project configured via `supabase link`
- `SUPABASE_DB_PASSWORD` exported only if you want the runner to apply linked migrations automatically
- `apps/rayon_sports/web/.env.local` contains:
  - `SUPABASE_URL`
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
- Flutter, Node/NPM, Playwright, and Supabase CLI installed

## One-command runner

List linked migration state, run wallet regressions, seed personas, and execute the wallet browser pass:

```bash
SUPABASE_DB_PASSWORD=... bash tools/scripts/run_wallet_qa_uat.sh --apply-linked
```

Useful variants:

```bash
bash tools/scripts/run_wallet_qa_uat.sh --skip-e2e
bash tools/scripts/run_wallet_qa_uat.sh --skip-seed
```

## Seeded personas

Default club scope: `24`

| Persona | Phone | Role | Starting balance |
| --- | --- | --- | --- |
| `super_admin` | `+250788100001` | super admin | `0 FET` |
| `club_admin` | `+250788100002` | club admin | `0 FET` |
| `supporter_alpha` | `+250788100010` | supporter | `1250 FET` |
| `supporter_beta` | `+250788100011` | supporter | `640 FET` |
| `supporter_gamma` | `+250788100012` | supporter | `320 FET` |

Manual seed only:

```bash
cd apps/rayon_sports/web
npm run qa:wallet:seed
```

## Automated checks covered by the runner

- `supabase migration list`
- optional linked migration apply
- `flutter analyze` on wallet/auth-related mobile packages
- Flutter tests for `feat_gamification`, `feat_onboarding`, and `feat_settings`
- web `lint`, `typecheck`, `vitest`, and `build`
- wallet-specific Playwright pass on the admin web wallet surface

## Manual UAT evidence sheet

Capture screenshot or video plus resulting DB/ledger evidence for each step.

1. Supporter signs in with phone OTP on mobile.
   Expected:
   - phone auth screen accepts the seeded number
   - user reaches the supporter app shell
2. Supporter Alpha opens the wallet.
   Expected:
   - balance shows `1250 FET` before any test actions
   - recent activity includes the seeded opening balance
3. Supporter Alpha earns FET from a partner initiative or promotion.
   Expected:
   - Alpha balance increases by the partner earn amount
   - ledger shows `partner_promotion_earn`
   - initiative or partner reference is present in the ledger metadata
4. Supporter Alpha joins a partner WDW football prediction pool.
   Expected:
   - Alpha balance decreases by the fixed fan entry FET
   - ledger shows `partner_pool_entry`
   - selected outcome is one of `home`, `draw`, or `away`
   - pool remains partner-scoped and match-linked
5. Settle the partner WDW pool from admin or service role.
   Expected:
   - eligible winners receive `partner_pool_payout`
   - no-winner or no-eligible-winner pools create `partner_pool_refund`
   - settlement is idempotent under retry
   - partner stake, fan entry total, paid total, refunds, and remainder are auditable
6. Club admin signs in on `/admin`.
   Expected:
   - OTP sign-in completes
   - admin dashboard and wallet ops route are accessible
7. Club admin opens `/admin/gamification/wallet`.
   Expected:
   - seeded supporters appear
   - wallet totals load without error
8. Club admin applies a positive wallet adjustment to Supporter Alpha.
   Expected:
   - success toast appears
   - Supporter Alpha balance updates
   - ledger shows `admin_adjustment` with the audit note
9. Club admin applies a negative wallet adjustment.
   Expected:
   - destructive confirmation appears
   - deduction succeeds only when balance is sufficient
10. Supporter reopens the wallet on mobile after admin adjustment.
   Expected:
   - updated balance matches admin ledger state
   - recent activity reflects the admin note

## DB verification queries

Run these against the linked project after manual UAT:

```sql
select user_id, club_id, points, tier
from public.fan_memberships
where club_id = 24
order by points desc, user_id;
```

```sql
select user_id, entry_type, direction, amount, balance_after, note, created_at
from public.fet_wallet_ledger_entries
where club_id = 24
order by created_at desc, id desc
limit 50;
```

## Pass criteria

- supporter wallet balances always match the latest ledger state
- partner earn, pool entry, settlement payout, and refund flows remain
  idempotent under retries
- public transfer and manual redemption controls are absent from the fan wallet
- admin adjustments require an audit reason and appear in ledger history
- mobile wallet and admin wallet show consistent balances after every mutation
- all automated runner steps succeed
