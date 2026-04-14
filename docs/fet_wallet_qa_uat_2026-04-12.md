# FET Wallet QA/UAT

Date: `2026-04-12`

Scope:
- supporter FET wallet balance
- supporter transfer flow
- supporter redemption flow
- admin wallet investigation and manual adjustment
- seeded regression coverage for the active AFRICLUB wallet scope

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
3. Supporter Alpha transfers FET to Supporter Beta.
   Expected:
   - Alpha balance decreases by the transfer amount
   - Beta balance increases by the same amount
   - both ledger histories show counterparty details
4. Supporter Alpha redeems FET.
   Expected:
   - redemption request succeeds
   - wallet balance drops by the redeemed amount
   - ledger shows `redeem`
5. Club admin signs in on `/admin`.
   Expected:
   - OTP sign-in completes
   - admin dashboard and wallet ops route are accessible
6. Club admin opens `/admin/gamification/wallet`.
   Expected:
   - seeded supporters appear
   - wallet totals load without error
7. Club admin applies a positive wallet adjustment to Supporter Alpha.
   Expected:
   - success toast appears
   - Supporter Alpha balance updates
   - ledger shows `admin_adjustment` with the audit note
8. Club admin applies a negative wallet adjustment.
   Expected:
   - destructive confirmation appears
   - deduction succeeds only when balance is sufficient
9. Supporter reopens the wallet on mobile after admin adjustment.
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
- transfer and redeem flows remain idempotent under retries
- admin adjustments require an audit reason and appear in ledger history
- mobile wallet and admin wallet show consistent balances after every mutation
- all automated runner steps succeed
