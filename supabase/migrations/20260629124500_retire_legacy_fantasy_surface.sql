begin;

-- Retire the old FANZONE/fantasy game surface. AFRICLUB production launch now
-- uses partner-centered WDW pools, partner initiatives, and LiveScore-backed
-- football fixtures instead of fantasy squads, music games, or broad game modes.
do $$
declare
  routine record;
begin
  for routine in
    select p.oid::regprocedure::text as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'fantasy_%'
  loop
    execute format('drop function if exists %s cascade', routine.signature);
  end loop;
end $$;

drop view if exists public.fantasy_competitions cascade;
drop table if exists public.fantasy_competition_enablements cascade;
drop table if exists public.fantasy_fet_activity_awards cascade;
drop table if exists public.fantasy_fet_activities cascade;
drop schema if exists fantasy cascade;

commit;
