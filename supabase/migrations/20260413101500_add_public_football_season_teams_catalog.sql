create or replace view public.football_season_teams_catalog
with (security_invoker = true) as
select
  st.id,
  st.season_id,
  s.slug as season_slug,
  s.label as season_label,
  st.team_id,
  t.slug as team_slug,
  t.name as team_name,
  t.short_name as team_short_name,
  st.group_name,
  st.seeded_rank,
  st.is_active,
  st.metadata,
  st.created_at,
  st.updated_at
from football.season_teams st
join football.seasons s
  on s.id = st.season_id
join football.teams t
  on t.id = st.team_id;

grant select on public.football_season_teams_catalog to anon, authenticated, service_role;
