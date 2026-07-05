-- Database-owned admin dashboard shortcuts.
-- Keeps admin navigation flexible without hardcoding the dashboard action list
-- in the web app.

create table if not exists public.admin_dashboard_actions (
  id uuid primary key default gen_random_uuid(),
  action_key text not null,
  title text not null,
  subtitle text,
  route text not null,
  icon_key text not null default 'settings',
  category text not null default 'operations',
  club_id bigint references public.african_football_clubs(id) on delete cascade,
  required_role text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now()),
  constraint admin_dashboard_actions_action_key_check
    check (action_key ~ '^[a-z0-9][a-z0-9_:-]*$'),
  constraint admin_dashboard_actions_route_check
    check (route ~ '^/admin(/|$)'),
  constraint admin_dashboard_actions_required_role_check
    check (
      required_role is null
      or required_role in ('super_admin', 'admin', 'club_admin', 'club_moderator')
    ),
  constraint admin_dashboard_actions_metadata_object_check
    check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists admin_dashboard_actions_global_action_key_unique
  on public.admin_dashboard_actions (action_key)
  where club_id is null;

create unique index if not exists admin_dashboard_actions_club_action_key_unique
  on public.admin_dashboard_actions (club_id, action_key)
  where club_id is not null;

create index if not exists idx_admin_dashboard_actions_active_order
  on public.admin_dashboard_actions (is_active, sort_order, title);

create index if not exists idx_admin_dashboard_actions_club_active
  on public.admin_dashboard_actions (club_id, is_active, sort_order)
  where club_id is not null;

drop trigger if exists trg_admin_dashboard_actions_updated
  on public.admin_dashboard_actions;
create trigger trg_admin_dashboard_actions_updated
  before update on public.admin_dashboard_actions
  for each row execute function public.set_updated_at();

alter table public.admin_dashboard_actions enable row level security;

drop policy if exists admin_dashboard_actions_select_admin
  on public.admin_dashboard_actions;
create policy admin_dashboard_actions_select_admin
  on public.admin_dashboard_actions
  for select
  to authenticated
  using (public.is_admin_user());

drop policy if exists admin_dashboard_actions_insert_admin
  on public.admin_dashboard_actions;
create policy admin_dashboard_actions_insert_admin
  on public.admin_dashboard_actions
  for insert
  to authenticated
  with check (public.is_admin_user());

drop policy if exists admin_dashboard_actions_update_admin
  on public.admin_dashboard_actions;
create policy admin_dashboard_actions_update_admin
  on public.admin_dashboard_actions
  for update
  to authenticated
  using (public.is_admin_user())
  with check (public.is_admin_user());

drop policy if exists admin_dashboard_actions_delete_admin
  on public.admin_dashboard_actions;
create policy admin_dashboard_actions_delete_admin
  on public.admin_dashboard_actions
  for delete
  to authenticated
  using (public.is_admin_user());

create or replace function public.get_admin_dashboard_actions(
  p_club_id bigint default null,
  p_role text default null,
  p_is_super_admin boolean default false
)
returns table (
  id uuid,
  action_key text,
  title text,
  subtitle text,
  route text,
  icon_key text,
  category text,
  club_id bigint,
  required_role text,
  sort_order integer,
  metadata jsonb
)
language sql
stable
set search_path = public, pg_temp
as $$
  with scoped as (
    select
      ada.*,
      case when ada.club_id = p_club_id then 0 else 1 end as scope_rank
    from public.admin_dashboard_actions ada
    where ada.is_active = true
      and (ada.club_id is null or ada.club_id = p_club_id)
      and (
        ada.required_role is null
        or p_is_super_admin = true
        or ada.required_role = p_role
      )
  ),
  preferred as (
    select distinct on (scoped.action_key)
      scoped.id,
      scoped.action_key,
      scoped.title,
      scoped.subtitle,
      scoped.route,
      scoped.icon_key,
      scoped.category,
      scoped.club_id,
      scoped.required_role,
      scoped.sort_order,
      scoped.metadata
    from scoped
    order by scoped.action_key, scoped.scope_rank, scoped.sort_order
  )
  select
    preferred.id,
    preferred.action_key,
    preferred.title,
    preferred.subtitle,
    preferred.route,
    preferred.icon_key,
    preferred.category,
    preferred.club_id,
    preferred.required_role,
    preferred.sort_order,
    preferred.metadata
  from preferred
  order by preferred.sort_order, preferred.title;
$$;

grant execute on function public.get_admin_dashboard_actions(bigint, text, boolean)
  to authenticated;

insert into public.admin_dashboard_actions (
  action_key,
  title,
  subtitle,
  route,
  icon_key,
  category,
  required_role,
  sort_order,
  is_active,
  metadata
)
values
  (
    'manage_website',
    'Manage Website',
    'Publish and revise site content',
    '/admin/cms',
    'newspaper',
    'content',
    null,
    10,
    true,
    '{"surface": "web_admin"}'::jsonb
  ),
  (
    'notifications',
    'App Push & Alerts',
    'Send operational supporter alerts',
    '/admin/notifications',
    'bell',
    'engagement',
    null,
    20,
    true,
    '{"surface": "web_admin"}'::jsonb
  ),
  (
    'matches',
    'Matchday Centre',
    'Manage fixtures and matchday data',
    '/admin/matches',
    'calendar',
    'operations',
    null,
    30,
    true,
    '{"surface": "web_admin"}'::jsonb
  ),
  (
    'membership',
    'Memberships',
    'Manage supporter tiers and approvals',
    '/admin/membership',
    'crown',
    'commerce',
    null,
    40,
    true,
    '{"surface": "web_admin"}'::jsonb
  ),
  (
    'shop',
    'Shop Operations',
    'Maintain products and orders',
    '/admin/shop',
    'shopping_bag',
    'commerce',
    null,
    50,
    true,
    '{"surface": "web_admin"}'::jsonb
  ),
  (
    'access',
    'Role Management',
    'Grant and review admin access',
    '/admin/access',
    'users',
    'security',
    'super_admin',
    60,
    true,
    '{"surface": "web_admin"}'::jsonb
  ),
  (
    'settings',
    'Platform Config',
    'Update club profile and runtime settings',
    '/admin/settings',
    'settings',
    'platform',
    null,
    70,
    true,
    '{"surface": "web_admin"}'::jsonb
  )
on conflict (action_key) where club_id is null do update
set
  title = excluded.title,
  subtitle = excluded.subtitle,
  route = excluded.route,
  icon_key = excluded.icon_key,
  category = excluded.category,
  required_role = excluded.required_role,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  metadata = public.admin_dashboard_actions.metadata || excluded.metadata,
  updated_at = timezone('utc'::text, now());
