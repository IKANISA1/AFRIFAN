alter table public.fet_wallet_ledger_entries
  drop constraint if exists fet_wallet_ledger_entries_created_by_fkey;

alter table public.fet_wallet_ledger_entries
  add constraint fet_wallet_ledger_entries_created_by_fkey
  foreign key (created_by)
  references auth.users(id)
  on delete set null;

comment on column public.fet_wallet_ledger_entries.created_by is
  'Auth user that executed the wallet action. This can be an admin account without a public.users profile row.';
