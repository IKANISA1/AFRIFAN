-- Runtime function volatility regression checks for `supabase db lint`.

create extension if not exists pgtap with schema extensions;

begin;

select plan(5);

select is(
  (
    select provolatile::text
    from pg_proc
    where oid =
      'public.get_club_member_registry(bigint,text,text,text,integer,integer)'::regprocedure
  ),
  'v',
  'member registry uses the conservative volatile contract'
);

select is(
  (
    select provolatile::text
    from pg_proc
    where oid = 'public.fet_get_wallet(bigint)'::regprocedure
  ),
  'v',
  'wallet lookup remains volatile because it can ensure a membership'
);

select is(
  (
    select provolatile::text
    from pg_proc
    where oid =
      'public.fet_admin_get_wallet_overview(bigint,text,integer,integer)'::regprocedure
  ),
  'v',
  'admin wallet overview does not claim stable execution across volatile authorization helpers'
);

select is(
  (
    select provolatile::text
    from pg_proc
    where oid =
      'public.fet_admin_get_wallet_ledger(bigint,text,uuid,integer,integer)'::regprocedure
  ),
  'v',
  'admin wallet ledger does not claim stable execution across volatile authorization helpers'
);

select is(
  (
    select provolatile::text
    from pg_proc
    where oid =
      'public.predict_dashboard(bigint)'::regprocedure
  ),
  'v',
  'Predict dashboard is volatile because it may grant welcome FET'
);

select * from finish();

rollback;
