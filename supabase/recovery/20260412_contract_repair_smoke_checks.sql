-- Contract repair smoke checks
--
-- Run this after applying the repaired migration chain on a real Supabase/Postgres
-- environment. It validates the objects restored for the audited contract gaps.

\echo '== relations =='
select
  rel,
  to_regclass(rel) is not null as exists
from (
  values
    ('public.contribution_groups'),
    ('public.cool_events'),
    ('public.rs_fan_memberships'),
    ('public.groups'),
    ('public.group_members'),
    ('public.news_articles'),
    ('public.shop_products'),
    ('fantasy.competitions'),
    ('fantasy.gameweeks'),
    ('fantasy.players'),
    ('fantasy.player_competition_prices'),
    ('fantasy.fantasy_entries'),
    ('fantasy.squad_selections'),
    ('fantasy.player_gameweek_stats'),
    ('fantasy.entry_gameweek_scores'),
    ('fantasy.leagues'),
    ('fantasy.league_memberships'),
    ('fantasy.public_entry_summaries'),
    ('fantasy.fantasy_fixtures'),
    ('fantasy.player_fixture_stats'),
    ('fantasy.fixture_injuries'),
    ('fantasy.league_h2h_fixtures')
) s(rel)
order by rel;

\echo '== functions =='
select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_args
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
where (n.nspname, p.proname) in (
  ('public', 'activate_referral_invite_for_user'),
  ('public', 'fantasy_admin_club_competitions'),
  ('public', 'fantasy_admin_operations_summary'),
  ('public', 'get_rayon_member_registry'),
  ('public', 'rs_apply_membership_points'),
  ('public', 'get_rs_fan_analytics')
)
order by n.nspname, p.proname, identity_args;

\echo '== groups defaults =='
select
  column_name,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'groups'
  and column_name in ('country', 'currency')
order by column_name;

\echo '== compatibility view columns =='
select
  table_schema,
  table_name,
  column_name
from information_schema.columns
where (table_schema, table_name) in (
  ('public', 'contribution_groups'),
  ('public', 'cool_events'),
  ('fantasy', 'public_entry_summaries')
)
order by table_schema, table_name, ordinal_position;

\echo '== critical policies =='
select
  schemaname,
  tablename,
  policyname,
  cmd
from pg_policies
where (schemaname, tablename, policyname) in (
  ('public', 'groups', 'contribution_groups_admin_all'),
  ('public', 'groups', 'contribution_groups_public_read'),
  ('public', 'groups', 'groups_select_public'),
  ('public', 'group_members', 'group_members_select_members'),
  ('public', 'news_articles', 'news_articles_admin_all'),
  ('public', 'shop_products', 'shop_products_admin_all'),
  ('fantasy', 'competitions', 'competitions_public_read'),
  ('fantasy', 'gameweeks', 'gameweeks_public_read'),
  ('fantasy', 'players', 'players_public_read'),
  ('fantasy', 'player_competition_prices', 'prices_public_read'),
  ('fantasy', 'fantasy_entries', 'entry_owner_select'),
  ('fantasy', 'fantasy_entries', 'entry_owner_insert'),
  ('fantasy', 'fantasy_entries', 'entry_owner_update'),
  ('fantasy', 'entry_gameweek_scores', 'scores_public_read'),
  ('fantasy', 'entry_gameweek_scores', 'scores_owner_write'),
  ('fantasy', 'entry_gameweek_scores', 'scores_owner_update'),
  ('fantasy', 'entry_gameweek_scores', 'scores_service_write'),
  ('fantasy', 'leagues', 'leagues_visible_to_members'),
  ('fantasy', 'league_memberships', 'memberships_read')
)
order by schemaname, tablename, policyname;

\echo '== privilege spot check =='
select
  'public.contribution_groups select anon' as check_name,
  has_table_privilege('anon', 'public.contribution_groups', 'select') as ok
union all
select
  'fantasy.public_entry_summaries select authenticated',
  has_table_privilege('authenticated', 'fantasy.public_entry_summaries', 'select')
union all
select
  'fantasy.competitions select anon',
  has_table_privilege('anon', 'fantasy.competitions', 'select');

\echo '== notes =='
\echo 'If any row above returns false or is missing, the repaired contract did not fully apply.'
