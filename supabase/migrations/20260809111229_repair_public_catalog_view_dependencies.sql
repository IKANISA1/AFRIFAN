begin;

-- The public teams view needs only these three club identity columns. Granting
-- the dependency columns plus a read policy repairs the security-invoker view
-- without exposing market research, contacts, payment routes, or feature data.
grant select (id, club_slug, club_name)
on table public.african_football_clubs to anon, authenticated;

drop policy if exists clubs_public_catalog_read
on public.african_football_clubs;
create policy clubs_public_catalog_read
on public.african_football_clubs
for select
to anon, authenticated
using (is_active);

-- Public rankings use a deterministic system alias. They no longer depend on
-- profiles/users or publish supporter-entered display names.
create or replace view public.prediction_leaderboard
with (security_invoker = true) as
select
  prediction.user_id,
  'Supporter ' || pg_catalog.upper(
    pg_catalog.substr(
      pg_catalog.md5(prediction.user_id::text),
      1,
      6
    )
  ) as display_name,
  pg_catalog.count(*) filter (
    where prediction.status = 'won'
  ) as wins,
  pg_catalog.count(*) filter (
    where prediction.status in ('won', 'lost')
  ) as total_settled,
  coalesce(pg_catalog.sum(prediction.fet_earned), 0) as total_fet_earned,
  case
    when pg_catalog.count(*) filter (
      where prediction.status in ('won', 'lost')
    ) > 0 then
      pg_catalog.round(
        pg_catalog.count(*) filter (
          where prediction.status = 'won'
        )::numeric /
        pg_catalog.count(*) filter (
          where prediction.status in ('won', 'lost')
        )::numeric * 100,
        1
      )
    else 0
  end as win_rate
from football.predictions as prediction
where prediction.status in ('won', 'lost')
group by prediction.user_id
order by total_fet_earned desc, wins desc;

revoke all privileges on table public.prediction_leaderboard
from public, anon, authenticated, service_role;
grant select on table public.prediction_leaderboard
to anon, authenticated, service_role;

commit;
