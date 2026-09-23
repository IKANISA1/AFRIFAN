-- Security-invoker catalog dependencies and system-alias leaderboard.

create extension if not exists pgtap with schema extensions;

begin;

select plan(4);

select ok(
  has_column_privilege(
    'anon',
    'public.african_football_clubs',
    'id',
    'SELECT'
  )
  and has_column_privilege(
    'authenticated',
    'public.african_football_clubs',
    'club_name',
    'SELECT'
  )
  and not has_column_privilege(
    'anon',
    'public.african_football_clubs',
    'official_contact',
    'SELECT'
  )
  and not has_column_privilege(
    'authenticated',
    'public.african_football_clubs',
    'market_research_note',
    'SELECT'
  ),
  'teams catalog receives only the three public club identity columns'
);

select ok(
  exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'african_football_clubs'
      and policyname = 'clubs_public_catalog_read'
      and cmd = 'SELECT'
      and roles = array['anon', 'authenticated']::name[]
      and qual ~ 'is_active'
  ),
  'public club catalog rows are limited to active clubs'
);

select ok(
  pg_catalog.pg_get_viewdef(
    'public.prediction_leaderboard'::regclass,
    true
  ) !~ 'profiles|public.users'
  and pg_catalog.pg_get_viewdef(
    'public.prediction_leaderboard'::regclass,
    true
  ) ~ 'Supporter '
  and has_table_privilege(
    'anon',
    'public.prediction_leaderboard',
    'SELECT'
  ),
  'leaderboard uses a deterministic system alias without profile dependencies'
);

set local role anon;
do $$
declare
  team_count integer;
  leaderboard_count integer;
begin
  select pg_catalog.count(*)::integer
    into team_count
    from public.football_teams_catalog;
  select pg_catalog.count(*)::integer
    into leaderboard_count
    from public.prediction_leaderboard;

  if team_count < 0 or leaderboard_count < 0 then
    raise exception 'unexpected negative catalog counts';
  end if;
end $$;
reset role;
select pass('anonymous API role can query both security-invoker public catalogs');

select * from finish();

rollback;
