begin;

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'payment_receiver_accounts_purpose_check'
      and conrelid = 'public.payment_receiver_accounts'::regclass
  ) then
    alter table public.payment_receiver_accounts
      drop constraint payment_receiver_accounts_purpose_check;
  end if;
end;
$$;

alter table public.payment_receiver_accounts
  add constraint payment_receiver_accounts_purpose_check
  check (
    purpose = any (
      array[
        'personal_wallet'::text,
        'bank_custody'::text,
        'rayon_shop'::text,
        'club_shop'::text,
        'agent_till'::text,
        'subscription'::text,
        'system_pool'::text
      ]
    )
  );

commit;
