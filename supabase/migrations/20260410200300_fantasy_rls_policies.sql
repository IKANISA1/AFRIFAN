alter table fantasy.competitions enable row level security;
alter table fantasy.gameweeks enable row level security;
alter table fantasy.players enable row level security;
alter table fantasy.player_competition_prices enable row level security;
alter table fantasy.fantasy_entries enable row level security;
alter table fantasy.squad_selections enable row level security;
alter table fantasy.player_gameweek_stats enable row level security;
alter table fantasy.entry_gameweek_scores enable row level security;
alter table fantasy.leagues enable row level security;
alter table fantasy.league_memberships enable row level security;
alter table fantasy.transfer_history enable row level security;
alter table public.club_app_config enable row level security;
alter table public.fantasy_competition_enablements enable row level security;

create policy "competitions_public_read"
on fantasy.competitions
for select
using (true);

create policy "gameweeks_public_read"
on fantasy.gameweeks
for select
using (true);

create policy "players_public_read"
on fantasy.players
for select
using (true);

create policy "prices_public_read"
on fantasy.player_competition_prices
for select
using (true);

create policy "stats_public_read"
on fantasy.player_gameweek_stats
for select
using (true);

create policy "entry_owner_select"
on fantasy.fantasy_entries
for select
using (user_id = auth.uid());

create policy "entry_owner_insert"
on fantasy.fantasy_entries
for insert
with check (user_id = auth.uid());

create policy "entry_owner_update"
on fantasy.fantasy_entries
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "squad_owner_all"
on fantasy.squad_selections
for all
using (
  entry_id in (
    select id
    from fantasy.fantasy_entries
    where user_id = auth.uid()
  )
)
with check (
  entry_id in (
    select id
    from fantasy.fantasy_entries
    where user_id = auth.uid()
  )
);

create policy "scores_public_read"
on fantasy.entry_gameweek_scores
for select
using (true);

create policy "scores_owner_write"
on fantasy.entry_gameweek_scores
for insert
with check (
  entry_id in (
    select id
    from fantasy.fantasy_entries
    where user_id = auth.uid()
  )
);

create policy "scores_owner_update"
on fantasy.entry_gameweek_scores
for update
using (
  entry_id in (
    select id
    from fantasy.fantasy_entries
    where user_id = auth.uid()
  )
)
with check (
  entry_id in (
    select id
    from fantasy.fantasy_entries
    where user_id = auth.uid()
  )
);

create policy "scores_service_write"
on fantasy.entry_gameweek_scores
for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create policy "leagues_visible_to_members"
on fantasy.leagues
for select
using (
  is_public = true
  or created_by = auth.uid()
  or id in (
    select lm.league_id
    from fantasy.league_memberships lm
    join fantasy.fantasy_entries fe
      on fe.id = lm.entry_id
    where fe.user_id = auth.uid()
  )
);

create policy "leagues_owner_insert"
on fantasy.leagues
for insert
with check (created_by = auth.uid());

create policy "leagues_owner_update"
on fantasy.leagues
for update
using (created_by = auth.uid())
with check (created_by = auth.uid());

create policy "memberships_read"
on fantasy.league_memberships
for select
using (
  league_id in (
    select id
    from fantasy.leagues
    where is_public = true
      or created_by = auth.uid()
  )
  or league_id in (
    select lm.league_id
    from fantasy.league_memberships lm
    join fantasy.fantasy_entries fe
      on fe.id = lm.entry_id
    where fe.user_id = auth.uid()
  )
  or entry_id in (
    select id
    from fantasy.fantasy_entries
    where user_id = auth.uid()
  )
);

create policy "memberships_insert"
on fantasy.league_memberships
for insert
with check (
  entry_id in (
    select id
    from fantasy.fantasy_entries
    where user_id = auth.uid()
  )
);

create policy "transfers_owner_select"
on fantasy.transfer_history
for select
using (
  entry_id in (
    select id
    from fantasy.fantasy_entries
    where user_id = auth.uid()
  )
);

create policy "transfers_owner_insert"
on fantasy.transfer_history
for insert
with check (
  entry_id in (
    select id
    from fantasy.fantasy_entries
    where user_id = auth.uid()
  )
);

create policy "club_app_config_public_read"
on public.club_app_config
for select
using (true);

create policy "club_app_config_admin_insert"
on public.club_app_config
for insert
to authenticated
with check (public.is_admin_user());

create policy "club_app_config_admin_update"
on public.club_app_config
for update
to authenticated
using (public.is_admin_user())
with check (public.is_admin_user());

create policy "club_app_config_admin_delete"
on public.club_app_config
for delete
to authenticated
using (public.is_admin_user());

create policy "fantasy_enablements_public_read"
on public.fantasy_competition_enablements
for select
using (true);

create policy "fantasy_enablements_admin_insert"
on public.fantasy_competition_enablements
for insert
to authenticated
with check (public.is_admin_user());

create policy "fantasy_enablements_admin_update"
on public.fantasy_competition_enablements
for update
to authenticated
using (public.is_admin_user())
with check (public.is_admin_user());

create policy "fantasy_enablements_admin_delete"
on public.fantasy_competition_enablements
for delete
to authenticated
using (public.is_admin_user());

create or replace view fantasy.public_entry_summaries as
select
  fe.id,
  fe.user_id,
  fe.competition_id,
  fe.team_name,
  fe.overall_points,
  fe.overall_rank,
  coalesce(
    nullif(u.official_name, ''),
    nullif(u.full_name, ''),
    nullif(u.phone, ''),
    'Manager'
  ) as manager_name
from fantasy.fantasy_entries fe
left join public.users u
  on u.id = fe.user_id;

grant usage on schema fantasy to anon, authenticated, service_role;
grant select on fantasy.competitions to anon, authenticated, service_role;
grant select on fantasy.gameweeks to anon, authenticated, service_role;
grant select on fantasy.players to anon, authenticated, service_role;
grant select on fantasy.player_competition_prices to anon, authenticated, service_role;
grant select on fantasy.player_gameweek_stats to anon, authenticated, service_role;
grant select on fantasy.public_entry_summaries to anon, authenticated, service_role;
