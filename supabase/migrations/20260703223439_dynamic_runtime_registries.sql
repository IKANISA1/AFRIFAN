-- Dynamic runtime registries for the Supabase-first AFRICLUB regime.
-- Moves mutable routes, option sets, small copy, navigation/search metadata,
-- venue governance controls, and TV display state into database-owned objects.

begin;

create table if not exists public.platform_route_registry (
  id uuid primary key default gen_random_uuid(),
  route_key text not null,
  path_pattern text not null,
  surface text not null default 'mobile',
  feature_key text not null,
  label text,
  auth_required boolean not null default false,
  required_roles jsonb not null default '[]'::jsonb,
  presentation text not null default 'screen',
  show_in_navigation boolean not null default false,
  show_on_home boolean not null default false,
  sort_order integer not null default 0,
  club_id bigint references public.african_football_clubs(id) on delete cascade,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint platform_route_registry_key_check
    check (route_key ~ '^[a-z0-9][a-z0-9_:-]*$'),
  constraint platform_route_registry_surface_check
    check (surface in ('mobile', 'web', 'tv', 'venue', 'admin', 'both')),
  constraint platform_route_registry_required_roles_array_check
    check (jsonb_typeof(required_roles) = 'array'),
  constraint platform_route_registry_metadata_object_check
    check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists idx_platform_route_registry_global_unique
  on public.platform_route_registry (route_key, surface)
  where club_id is null;

create unique index if not exists idx_platform_route_registry_club_unique
  on public.platform_route_registry (club_id, route_key, surface)
  where club_id is not null;

create index if not exists idx_platform_route_registry_runtime
  on public.platform_route_registry (surface, is_active, sort_order, route_key);

drop trigger if exists platform_route_registry_set_updated_at
  on public.platform_route_registry;
create trigger platform_route_registry_set_updated_at
before update on public.platform_route_registry
for each row execute function public.set_updated_at();

create table if not exists public.platform_option_sets (
  id uuid primary key default gen_random_uuid(),
  option_set_key text not null,
  label text not null,
  description text,
  value_type text not null default 'text',
  surface text not null default 'both',
  club_id bigint references public.african_football_clubs(id) on delete cascade,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint platform_option_sets_key_check
    check (option_set_key ~ '^[a-z0-9][a-z0-9_:-]*$'),
  constraint platform_option_sets_value_type_check
    check (value_type in ('text', 'number', 'boolean', 'json')),
  constraint platform_option_sets_surface_check
    check (surface in ('mobile', 'web', 'tv', 'venue', 'admin', 'both')),
  constraint platform_option_sets_metadata_object_check
    check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists idx_platform_option_sets_global_unique
  on public.platform_option_sets (option_set_key)
  where club_id is null;

create unique index if not exists idx_platform_option_sets_club_unique
  on public.platform_option_sets (club_id, option_set_key)
  where club_id is not null;

create index if not exists idx_platform_option_sets_runtime
  on public.platform_option_sets (surface, is_active, option_set_key);

drop trigger if exists platform_option_sets_set_updated_at
  on public.platform_option_sets;
create trigger platform_option_sets_set_updated_at
before update on public.platform_option_sets
for each row execute function public.set_updated_at();

create table if not exists public.platform_option_values (
  id uuid primary key default gen_random_uuid(),
  option_set_id uuid not null references public.platform_option_sets(id) on delete cascade,
  option_key text not null,
  label text not null,
  value jsonb not null,
  sort_order integer not null default 0,
  is_default boolean not null default false,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint platform_option_values_key_check
    check (option_key ~ '^[a-z0-9][a-z0-9_:-]*$'),
  constraint platform_option_values_metadata_object_check
    check (jsonb_typeof(metadata) = 'object'),
  unique (option_set_id, option_key)
);

create index if not exists idx_platform_option_values_runtime
  on public.platform_option_values (option_set_id, is_active, sort_order, label);

drop trigger if exists platform_option_values_set_updated_at
  on public.platform_option_values;
create trigger platform_option_values_set_updated_at
before update on public.platform_option_values
for each row execute function public.set_updated_at();

create table if not exists public.runtime_copy (
  id uuid primary key default gen_random_uuid(),
  copy_key text not null,
  surface text not null default 'both',
  locale text not null default 'en',
  text_value text not null,
  description text,
  club_id bigint references public.african_football_clubs(id) on delete cascade,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint runtime_copy_key_check
    check (copy_key ~ '^[a-z0-9][a-z0-9_.:-]*$'),
  constraint runtime_copy_surface_check
    check (surface in ('mobile', 'web', 'tv', 'venue', 'admin', 'both')),
  constraint runtime_copy_locale_check
    check (locale ~ '^[a-z]{2}(-[A-Z]{2})?$'),
  constraint runtime_copy_metadata_object_check
    check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists idx_runtime_copy_global_unique
  on public.runtime_copy (copy_key, surface, locale)
  where club_id is null;

create unique index if not exists idx_runtime_copy_club_unique
  on public.runtime_copy (club_id, copy_key, surface, locale)
  where club_id is not null;

create index if not exists idx_runtime_copy_runtime
  on public.runtime_copy (surface, locale, is_active, copy_key);

drop trigger if exists runtime_copy_set_updated_at on public.runtime_copy;
create trigger runtime_copy_set_updated_at
before update on public.runtime_copy
for each row execute function public.set_updated_at();

create table if not exists public.site_navigation_items (
  id uuid primary key default gen_random_uuid(),
  nav_key text not null,
  label text not null,
  href text not null,
  nav_group text not null default 'primary',
  surface text not null default 'web',
  feature_key text,
  club_id bigint references public.african_football_clubs(id) on delete cascade,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint site_navigation_items_key_check
    check (nav_key ~ '^[a-z0-9][a-z0-9_:-]*$'),
  constraint site_navigation_items_surface_check
    check (surface in ('web', 'mobile', 'admin', 'venue', 'tv', 'both')),
  constraint site_navigation_items_metadata_object_check
    check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists idx_site_navigation_global_unique
  on public.site_navigation_items (nav_key, surface, nav_group)
  where club_id is null;

create unique index if not exists idx_site_navigation_club_unique
  on public.site_navigation_items (club_id, nav_key, surface, nav_group)
  where club_id is not null;

create index if not exists idx_site_navigation_runtime
  on public.site_navigation_items (surface, nav_group, is_active, sort_order);

drop trigger if exists site_navigation_items_set_updated_at
  on public.site_navigation_items;
create trigger site_navigation_items_set_updated_at
before update on public.site_navigation_items
for each row execute function public.set_updated_at();

create table if not exists public.site_search_items (
  id uuid primary key default gen_random_uuid(),
  search_key text not null,
  title text not null,
  description text not null default '',
  href text not null,
  category text not null default 'Page',
  meta_label text,
  surface text not null default 'web',
  feature_key text,
  club_id bigint references public.african_football_clubs(id) on delete cascade,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint site_search_items_key_check
    check (search_key ~ '^[a-z0-9][a-z0-9_:-]*$'),
  constraint site_search_items_surface_check
    check (surface in ('web', 'mobile', 'admin', 'venue', 'tv', 'both')),
  constraint site_search_items_metadata_object_check
    check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists idx_site_search_global_unique
  on public.site_search_items (search_key, surface)
  where club_id is null;

create unique index if not exists idx_site_search_club_unique
  on public.site_search_items (club_id, search_key, surface)
  where club_id is not null;

create index if not exists idx_site_search_runtime
  on public.site_search_items (surface, is_active, sort_order, category);

drop trigger if exists site_search_items_set_updated_at
  on public.site_search_items;
create trigger site_search_items_set_updated_at
before update on public.site_search_items
for each row execute function public.set_updated_at();

create table if not exists public.venue_governance_controls (
  id uuid primary key default gen_random_uuid(),
  control_key text not null,
  label text not null,
  detail text not null default '',
  status_label text not null default 'review_required',
  action_label text,
  control_group text not null default 'general',
  club_id bigint references public.african_football_clubs(id) on delete cascade,
  venue_id uuid references public.venues(id) on delete cascade,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint venue_governance_controls_key_check
    check (control_key ~ '^[a-z0-9][a-z0-9_:-]*$'),
  constraint venue_governance_controls_metadata_object_check
    check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists idx_venue_governance_global_unique
  on public.venue_governance_controls (control_key)
  where club_id is null and venue_id is null;

create unique index if not exists idx_venue_governance_club_unique
  on public.venue_governance_controls (club_id, control_key)
  where club_id is not null and venue_id is null;

create unique index if not exists idx_venue_governance_venue_unique
  on public.venue_governance_controls (venue_id, control_key)
  where venue_id is not null;

create index if not exists idx_venue_governance_runtime
  on public.venue_governance_controls (club_id, venue_id, control_group, is_active, sort_order);

drop trigger if exists venue_governance_controls_set_updated_at
  on public.venue_governance_controls;
create trigger venue_governance_controls_set_updated_at
before update on public.venue_governance_controls
for each row execute function public.set_updated_at();

alter table public.platform_route_registry enable row level security;
alter table public.platform_option_sets enable row level security;
alter table public.platform_option_values enable row level security;
alter table public.runtime_copy enable row level security;
alter table public.site_navigation_items enable row level security;
alter table public.site_search_items enable row level security;
alter table public.venue_governance_controls enable row level security;

drop policy if exists platform_route_registry_select_runtime
  on public.platform_route_registry;
create policy platform_route_registry_select_runtime
  on public.platform_route_registry
  for select
  using (is_active = true);

drop policy if exists platform_route_registry_select_admin
  on public.platform_route_registry;
create policy platform_route_registry_select_admin
  on public.platform_route_registry
  for select
  to authenticated
  using (public.is_admin_user() or (club_id is not null and public.is_club_admin(club_id)));

drop policy if exists platform_route_registry_write_admin
  on public.platform_route_registry;
create policy platform_route_registry_write_admin
  on public.platform_route_registry
  for all
  to authenticated
  using (public.is_admin_user() or (club_id is not null and public.is_club_admin(club_id)))
  with check (public.is_admin_user() or (club_id is not null and public.is_club_admin(club_id)));

drop policy if exists platform_option_sets_select_runtime
  on public.platform_option_sets;
create policy platform_option_sets_select_runtime
  on public.platform_option_sets
  for select
  using (is_active = true);

drop policy if exists platform_option_sets_write_admin
  on public.platform_option_sets;
create policy platform_option_sets_write_admin
  on public.platform_option_sets
  for all
  to authenticated
  using (public.is_admin_user() or (club_id is not null and public.is_club_admin(club_id)))
  with check (public.is_admin_user() or (club_id is not null and public.is_club_admin(club_id)));

drop policy if exists platform_option_values_select_runtime
  on public.platform_option_values;
create policy platform_option_values_select_runtime
  on public.platform_option_values
  for select
  using (
    is_active = true
    and exists (
      select 1
      from public.platform_option_sets pos
      where pos.id = option_set_id
        and pos.is_active = true
    )
  );

drop policy if exists platform_option_values_write_admin
  on public.platform_option_values;
create policy platform_option_values_write_admin
  on public.platform_option_values
  for all
  to authenticated
  using (
    exists (
      select 1
      from public.platform_option_sets pos
      where pos.id = option_set_id
        and (public.is_admin_user() or (pos.club_id is not null and public.is_club_admin(pos.club_id)))
    )
  )
  with check (
    exists (
      select 1
      from public.platform_option_sets pos
      where pos.id = option_set_id
        and (public.is_admin_user() or (pos.club_id is not null and public.is_club_admin(pos.club_id)))
    )
  );

drop policy if exists runtime_copy_select_runtime on public.runtime_copy;
create policy runtime_copy_select_runtime
  on public.runtime_copy
  for select
  using (is_active = true);

drop policy if exists runtime_copy_write_admin on public.runtime_copy;
create policy runtime_copy_write_admin
  on public.runtime_copy
  for all
  to authenticated
  using (public.is_admin_user() or (club_id is not null and public.is_club_admin(club_id)))
  with check (public.is_admin_user() or (club_id is not null and public.is_club_admin(club_id)));

drop policy if exists site_navigation_items_select_runtime
  on public.site_navigation_items;
create policy site_navigation_items_select_runtime
  on public.site_navigation_items
  for select
  using (is_active = true);

drop policy if exists site_navigation_items_write_admin
  on public.site_navigation_items;
create policy site_navigation_items_write_admin
  on public.site_navigation_items
  for all
  to authenticated
  using (public.is_admin_user() or (club_id is not null and public.is_club_admin(club_id)))
  with check (public.is_admin_user() or (club_id is not null and public.is_club_admin(club_id)));

drop policy if exists site_search_items_select_runtime on public.site_search_items;
create policy site_search_items_select_runtime
  on public.site_search_items
  for select
  using (is_active = true);

drop policy if exists site_search_items_write_admin on public.site_search_items;
create policy site_search_items_write_admin
  on public.site_search_items
  for all
  to authenticated
  using (public.is_admin_user() or (club_id is not null and public.is_club_admin(club_id)))
  with check (public.is_admin_user() or (club_id is not null and public.is_club_admin(club_id)));

drop policy if exists venue_governance_controls_select_runtime
  on public.venue_governance_controls;
create policy venue_governance_controls_select_runtime
  on public.venue_governance_controls
  for select
  using (is_active = true);

drop policy if exists venue_governance_controls_write_admin
  on public.venue_governance_controls;
create policy venue_governance_controls_write_admin
  on public.venue_governance_controls
  for all
  to authenticated
  using (public.is_admin_user() or (club_id is not null and public.is_club_admin(club_id)))
  with check (public.is_admin_user() or (club_id is not null and public.is_club_admin(club_id)));

-- The production public-schema default ACL grants broad privileges to new
-- Data API relations. Reset those inherited grants before adding the exact
-- privileges required by RLS and the admin registry editor.
revoke all on table
  public.platform_route_registry,
  public.platform_option_sets,
  public.platform_option_values,
  public.runtime_copy,
  public.site_navigation_items,
  public.site_search_items,
  public.venue_governance_controls
from public, anon, authenticated, service_role;

grant select on table
  public.platform_route_registry,
  public.platform_option_sets,
  public.platform_option_values,
  public.runtime_copy,
  public.site_navigation_items,
  public.site_search_items,
  public.venue_governance_controls
to anon, authenticated;
grant insert, update, delete on public.platform_route_registry to authenticated;
grant insert, update, delete on public.platform_option_sets to authenticated;
grant insert, update, delete on public.platform_option_values to authenticated;
grant insert, update, delete on public.runtime_copy to authenticated;
grant insert, update, delete on public.site_navigation_items to authenticated;
grant insert, update, delete on public.site_search_items to authenticated;
grant insert, update, delete on public.venue_governance_controls to authenticated;
grant select, insert, update, delete on table
  public.platform_route_registry,
  public.platform_option_sets,
  public.platform_option_values,
  public.runtime_copy,
  public.site_navigation_items,
  public.site_search_items,
  public.venue_governance_controls
to service_role;

create or replace function public.get_platform_config(
  p_channel text default 'mobile',
  p_club_id bigint default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_result jsonb;
  v_features jsonb;
  v_content_blocks jsonb;
  v_routes jsonb;
  v_option_sets jsonb;
  v_runtime_copy jsonb;
  v_site_navigation jsonb;
  v_site_search jsonb;
  v_venue_governance jsonb;
  v_now timestamptz := now();
begin
  with resolved_features as (
    select distinct on (pf.feature_key)
      pf.id,
      pf.feature_key,
      pf.display_name,
      pf.description,
      pf.category,
      pf.club_id,
      pf.is_enabled,
      pf.visibility_state
    from public.platform_features pf
    where pf.club_id is null
       or pf.club_id = p_club_id
    order by pf.feature_key, pf.club_id desc nulls last
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'feature_key', rf.feature_key,
      'display_name', rf.display_name,
      'description', rf.description,
      'category', rf.category,
      'is_enabled', rf.is_enabled,
      'visibility_state', rf.visibility_state,
      'channel', (
        select jsonb_build_object(
          'is_enabled', coalesce(ch.is_enabled, true),
          'is_visible', coalesce(ch.is_visible, true),
          'show_in_navigation', coalesce(ch.show_in_navigation, false),
          'show_on_home', coalesce(ch.show_on_home, false),
          'sort_order', ch.sort_order,
          'route_key', ch.route_key,
          'placement_key', ch.placement_key
        )
        from public.platform_feature_channels ch
        where ch.feature_id = rf.id
          and ch.channel = p_channel
      ),
      'rules', (
        select jsonb_build_object(
          'auth_required', coalesce(r.auth_required, false),
          'role_restrictions', coalesce(r.role_restrictions, '[]'::jsonb),
          'dependency_rules', coalesce(r.dependency_rules, '{}'::jsonb),
          'rollout_rules', coalesce(r.rollout_rules, '{}'::jsonb),
          'schedule_start_at', r.schedule_start_at,
          'schedule_end_at', r.schedule_end_at,
          'is_within_schedule',
            case
              when r.schedule_start_at is null and r.schedule_end_at is null then true
              when r.schedule_start_at is not null and r.schedule_end_at is not null
                then v_now >= r.schedule_start_at and v_now < r.schedule_end_at
              when r.schedule_start_at is not null then v_now >= r.schedule_start_at
              when r.schedule_end_at is not null then v_now < r.schedule_end_at
              else true
            end
        )
        from public.platform_feature_rules r
        where r.feature_id = rf.id
      )
    )
    order by rf.feature_key
  ), '[]'::jsonb)
  into v_features
  from resolved_features rf;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'block_key', cb.block_key,
      'block_type', cb.block_type,
      'title', cb.title,
      'subtitle', cb.subtitle,
      'content', cb.content,
      'target_channel', cb.target_channel,
      'placement_key', cb.placement_key,
      'feature_key', pf.feature_key,
      'is_active', cb.is_active,
      'sort_order', cb.sort_order,
      'metadata', cb.metadata
    )
    order by cb.sort_order nulls last, cb.created_at
  ), '[]'::jsonb)
  into v_content_blocks
  from public.platform_content_blocks cb
  left join public.platform_features pf on pf.id = cb.feature_id
  where cb.is_active = true
    and (cb.target_channel = p_channel or cb.target_channel = 'both')
    and (cb.club_id is null or cb.club_id = p_club_id);

  with resolved_routes as (
    select distinct on (prr.route_key, prr.surface)
      prr.*
    from public.platform_route_registry prr
    where prr.is_active = true
      and (prr.surface = p_channel or prr.surface = 'both')
      and (prr.club_id is null or prr.club_id = p_club_id)
    order by prr.route_key, prr.surface, prr.club_id desc nulls last
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'route_key', route_key,
      'path_pattern', path_pattern,
      'surface', surface,
      'feature_key', feature_key,
      'label', label,
      'auth_required', auth_required,
      'required_roles', required_roles,
      'presentation', presentation,
      'show_in_navigation', show_in_navigation,
      'show_on_home', show_on_home,
      'sort_order', sort_order,
      'metadata', metadata
    )
    order by sort_order, route_key
  ), '[]'::jsonb)
  into v_routes
  from resolved_routes;

  with resolved_sets as (
    select distinct on (pos.option_set_key)
      pos.*
    from public.platform_option_sets pos
    where pos.is_active = true
      and (pos.surface = p_channel or pos.surface = 'both')
      and (pos.club_id is null or pos.club_id = p_club_id)
    order by pos.option_set_key, pos.club_id desc nulls last
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'option_set_key', rs.option_set_key,
      'label', rs.label,
      'description', rs.description,
      'value_type', rs.value_type,
      'surface', rs.surface,
      'metadata', rs.metadata,
      'values', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'option_key', pov.option_key,
            'label', pov.label,
            'value', pov.value,
            'sort_order', pov.sort_order,
            'is_default', pov.is_default,
            'metadata', pov.metadata
          )
          order by pov.sort_order, pov.label
        )
        from public.platform_option_values pov
        where pov.option_set_id = rs.id
          and pov.is_active = true
      ), '[]'::jsonb)
    )
    order by rs.option_set_key
  ), '[]'::jsonb)
  into v_option_sets
  from resolved_sets rs;

  with resolved_copy as (
    select distinct on (rc.copy_key, rc.locale)
      rc.*
    from public.runtime_copy rc
    where rc.is_active = true
      and (rc.surface = p_channel or rc.surface = 'both')
      and (rc.club_id is null or rc.club_id = p_club_id)
    order by rc.copy_key, rc.locale, rc.club_id desc nulls last
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'copy_key', copy_key,
      'surface', surface,
      'locale', locale,
      'text_value', text_value,
      'description', description,
      'metadata', metadata
    )
    order by copy_key, locale
  ), '[]'::jsonb)
  into v_runtime_copy
  from resolved_copy;

  with resolved_navigation as (
    select distinct on (sni.nav_key, sni.surface, sni.nav_group)
      sni.*
    from public.site_navigation_items sni
    where sni.is_active = true
      and (sni.surface = p_channel or sni.surface = 'both' or (p_channel = 'web' and sni.surface = 'web'))
      and (sni.club_id is null or sni.club_id = p_club_id)
    order by sni.nav_key, sni.surface, sni.nav_group, sni.club_id desc nulls last
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'nav_key', nav_key,
      'label', label,
      'href', href,
      'nav_group', nav_group,
      'surface', surface,
      'feature_key', feature_key,
      'sort_order', sort_order,
      'metadata', metadata
    )
    order by nav_group, sort_order, label
  ), '[]'::jsonb)
  into v_site_navigation
  from resolved_navigation;

  with resolved_search as (
    select distinct on (ssi.search_key, ssi.surface)
      ssi.*
    from public.site_search_items ssi
    where ssi.is_active = true
      and (ssi.surface = p_channel or ssi.surface = 'both' or (p_channel = 'web' and ssi.surface = 'web'))
      and (ssi.club_id is null or ssi.club_id = p_club_id)
    order by ssi.search_key, ssi.surface, ssi.club_id desc nulls last
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'search_key', search_key,
      'title', title,
      'description', description,
      'href', href,
      'category', category,
      'meta_label', meta_label,
      'surface', surface,
      'feature_key', feature_key,
      'sort_order', sort_order,
      'metadata', metadata
    )
    order by sort_order, title
  ), '[]'::jsonb)
  into v_site_search
  from resolved_search;

  with resolved_venue_controls as (
    select distinct on (vgc.control_key)
      vgc.*
    from public.venue_governance_controls vgc
    where vgc.is_active = true
      and (vgc.club_id is null or vgc.club_id = p_club_id)
      and vgc.venue_id is null
    order by vgc.control_key, vgc.club_id desc nulls last
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'control_key', control_key,
      'label', label,
      'detail', detail,
      'status_label', status_label,
      'action_label', action_label,
      'control_group', control_group,
      'sort_order', sort_order,
      'metadata', metadata
    )
    order by control_group, sort_order, label
  ), '[]'::jsonb)
  into v_venue_governance
  from resolved_venue_controls;

  v_result := jsonb_build_object(
    'features', v_features,
    'content_blocks', v_content_blocks,
    'route_registry', v_routes,
    'option_sets', v_option_sets,
    'runtime_copy', v_runtime_copy,
    'site_navigation', v_site_navigation,
    'site_search', v_site_search,
    'venue_governance_controls', v_venue_governance,
    'config_version', v_now,
    'channel', p_channel,
    'club_id', p_club_id
  );

  return v_result;
end;
$$;

revoke execute on function public.get_platform_config(text, bigint)
  from public, anon, authenticated, service_role;
grant execute on function public.get_platform_config(text, bigint)
  to anon, authenticated, service_role;

create or replace function public.get_platform_option_set(
  p_option_set_key text,
  p_channel text default 'mobile',
  p_club_id bigint default null
) returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with resolved_set as (
    select distinct on (pos.option_set_key)
      pos.*
    from public.platform_option_sets pos
    where pos.is_active = true
      and pos.option_set_key = p_option_set_key
      and (pos.surface = p_channel or pos.surface = 'both')
      and (pos.club_id is null or pos.club_id = p_club_id)
    order by pos.option_set_key, pos.club_id desc nulls last
  )
  select coalesce(
    (
      select jsonb_build_object(
        'option_set_key', rs.option_set_key,
        'label', rs.label,
        'description', rs.description,
        'value_type', rs.value_type,
        'surface', rs.surface,
        'metadata', rs.metadata,
        'values', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'option_key', pov.option_key,
              'label', pov.label,
              'value', pov.value,
              'sort_order', pov.sort_order,
              'is_default', pov.is_default,
              'metadata', pov.metadata
            )
            order by pov.sort_order, pov.label
          )
          from public.platform_option_values pov
          where pov.option_set_id = rs.id
            and pov.is_active = true
        ), '[]'::jsonb)
      )
      from resolved_set rs
    ),
    '{}'::jsonb
  );
$$;

revoke execute on function public.get_platform_option_set(text, text, bigint)
  from public, anon, authenticated, service_role;
grant execute on function public.get_platform_option_set(text, text, bigint)
  to anon, authenticated, service_role;

create or replace function africlub_game.get_tv_display_state(
  p_device_id uuid default null,
  p_pairing_code text default null,
  p_club_id bigint default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, africlub_game, pg_temp
as $$
declare
  v_device africlub_game.tv_devices%rowtype;
  v_session africlub_game.game_sessions%rowtype;
  v_campaign record;
  v_venue record;
  v_expires_at timestamptz;
  v_reward integer := 0;
  v_prompt text;
  v_metadata_venue_id text;
  v_metadata_expires_at text;
  v_metadata_reward text;
  v_session_reward text;
begin
  select null::uuid as id, null::text as display_name, null::text as city,
         null::text as status
    into v_venue;
  select null::uuid as id, null::text as campaign_name,
         null::integer as fet_award_per_checkin, null::timestamptz as ends_at
    into v_campaign;

  if p_device_id is not null then
    select *
      into v_device
    from africlub_game.tv_devices
    where id = p_device_id
      and (p_club_id is null or club_id = p_club_id);
  elsif nullif(btrim(coalesce(p_pairing_code, '')), '') is not null then
    select *
      into v_device
    from africlub_game.tv_devices
    where upper(pairing_code) = upper(btrim(p_pairing_code))
      and (p_club_id is null or club_id = p_club_id);
  else
    return jsonb_build_object(
      'status', 'unpaired',
      'phase', 'offline',
      'message', 'Pair this TV display from the admin panel.'
    );
  end if;

  if not found or v_device.status <> 'paired' then
    return jsonb_build_object(
      'status', 'unpaired',
      'phase', 'offline',
      'message', 'Pair this TV display from the admin panel.'
    );
  end if;

  if v_device.current_session_id is not null then
    select *
      into v_session
    from africlub_game.game_sessions
    where id = v_device.current_session_id
      and club_id = v_device.club_id;
  end if;

  v_metadata_venue_id := nullif(v_device.metadata->>'venue_id', '');
  if v_metadata_venue_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    select v.id,
           v.display_name,
           v.city,
           v.status
      into v_venue
    from public.venues v
    where v.id = v_metadata_venue_id::uuid
    limit 1;
  end if;

  if v_venue.id is not null then
    select vcc.id,
           vcc.campaign_name,
           vcc.fet_award_per_checkin,
           vcc.ends_at
      into v_campaign
    from public.venue_checkin_campaigns vcc
    where vcc.venue_id = v_venue.id
      and vcc.club_id = v_device.club_id
      and vcc.status = 'approved'
      and now() >= vcc.starts_at
      and now() < vcc.ends_at
    order by vcc.ends_at asc
    limit 1;
  end if;

  v_expires_at := coalesce(v_campaign.ends_at, v_session.ended_at);
  v_metadata_expires_at := nullif(v_device.metadata->>'expires_at', '');
  if v_expires_at is null and v_metadata_expires_at is not null then
    begin
      v_expires_at := v_metadata_expires_at::timestamptz;
    exception
      when others then
        v_expires_at := null;
    end;
  end if;

  v_session_reward := nullif(v_session.metadata->>'fet_reward', '');
  v_metadata_reward := nullif(v_device.metadata->>'fet_reward', '');
  v_reward := coalesce(
    v_campaign.fet_award_per_checkin,
    case when v_session_reward ~ '^[0-9]+$' then v_session_reward::integer end,
    case when v_metadata_reward ~ '^[0-9]+$' then v_metadata_reward::integer end,
    0
  );
  v_prompt := coalesce(
    nullif(v_session.metadata->>'tv_prompt', ''),
    nullif(v_device.metadata->>'tv_prompt', ''),
    'Open Fan Zone in the supporter app to join this live experience.'
  );

  return jsonb_build_object(
    'status', 'ready',
    'device_id', v_device.id,
    'club_id', v_device.club_id,
    'venue_name', coalesce(v_venue.display_name, nullif(v_device.metadata->>'venue_name', ''), v_device.device_label),
    'session_id', v_session.id,
    'session_title', v_session.title,
    'session_code', coalesce(v_session.join_code, nullif(v_device.metadata->>'session_code', '')),
    'phase', coalesce(v_session.status, 'lobby'),
    'prompt', v_prompt,
    'fet_reward', v_reward,
    'reward_label', case when v_reward > 0 then v_reward::text || ' FET reward' else 'Approved rewards only' end,
    'expires_at', v_expires_at,
    'campaign_id', v_campaign.id,
    'campaign_name', v_campaign.campaign_name,
    'updated_at', coalesce(v_session.updated_at, v_device.updated_at)
  );
end;
$$;

revoke execute on function africlub_game.get_tv_display_state(uuid, text, bigint)
  from public, anon, authenticated, service_role;
grant execute on function africlub_game.get_tv_display_state(uuid, text, bigint)
  to authenticated, service_role;

create or replace function public.get_tv_display_state(
  p_device_id uuid default null,
  p_pairing_code text default null,
  p_club_id bigint default null
) returns jsonb
language sql
stable
security definer
set search_path = public, africlub_game, pg_temp
as $$
  select africlub_game.get_tv_display_state(p_device_id, p_pairing_code, p_club_id);
$$;

revoke execute on function public.get_tv_display_state(uuid, text, bigint)
  from public, anon, authenticated, service_role;
grant execute on function public.get_tv_display_state(uuid, text, bigint)
  to authenticated, service_role;

insert into public.platform_route_registry (
  route_key,
  path_pattern,
  surface,
  feature_key,
  label,
  auth_required,
  required_roles,
  presentation,
  show_in_navigation,
  show_on_home,
  sort_order,
  metadata
)
values
  ('home', '/home', 'mobile', 'home', 'Home', false, '[]'::jsonb, 'screen', true, true, 10, '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('tickets', '/tickets', 'mobile', 'ticketing', 'Tickets', false, '[]'::jsonb, 'screen', false, true, 20, '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('membership', '/membership', 'mobile', 'membership', 'Membership', false, '[]'::jsonb, 'screen', false, true, 30, '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('fan_clubs', '/fan-clubs', 'mobile', 'fan_clubs', 'Fan Clubs', false, '[]'::jsonb, 'screen', false, true, 40, '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('contributions', '/contribute', 'mobile', 'contributions', 'Support', true, '[]'::jsonb, 'screen', true, true, 50, '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('fanzone', '/fanzone', 'mobile', 'fanzone', 'Fan Zone', false, '[]'::jsonb, 'screen', true, true, 60, '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('challenge', '/challenge', 'mobile', 'challenge', 'Challenge', true, '[]'::jsonb, 'screen', false, true, 70, '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('shop', '/shop', 'mobile', 'shop', 'Shop', false, '[]'::jsonb, 'screen', false, true, 80, '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('venue_checkin', '/fanzone/venue', 'mobile', 'venue_checkin', 'Venue Check-in', true, '[]'::jsonb, 'screen', false, true, 90, '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('settings', '/settings', 'mobile', 'settings', 'Settings', true, '[]'::jsonb, 'screen', true, false, 100, '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('admin', '/admin', 'mobile', 'admin', 'Admin', true, '["admin", "super_admin", "club_admin", "club_moderator"]'::jsonb, 'blocked_mobile', false, false, 900, '{"source": "dynamic_runtime_registries", "mobile_policy": "not_user_app_accessible"}'::jsonb),
  ('web_home', '/', 'web', 'home', 'Home', false, '[]'::jsonb, 'page', true, true, 10, '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('web_fixtures', '/fixtures', 'web', 'live', 'Fixtures', false, '[]'::jsonb, 'page', true, true, 20, '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('web_tickets', '/tickets', 'web', 'ticketing', 'Tickets', false, '[]'::jsonb, 'page', true, true, 30, '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('web_membership', '/membership', 'web', 'membership', 'Membership', false, '[]'::jsonb, 'page', true, true, 40, '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('web_groups', '/circles', 'web', 'contributions', 'Groups', false, '[]'::jsonb, 'page', true, true, 50, '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('web_shop', '/shop', 'web', 'shop', 'Shop', false, '[]'::jsonb, 'page', true, true, 60, '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('web_news', '/news', 'web', 'news', 'News', false, '[]'::jsonb, 'page', true, true, 70, '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('web_admin', '/admin', 'admin', 'admin', 'Admin', true, '["admin", "super_admin", "club_admin", "club_moderator"]'::jsonb, 'admin_page', true, false, 10, '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('tv_display', '/tv-display', 'tv', 'tv_display', 'TV Display', false, '[]'::jsonb, 'native_tv', false, false, 10, '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('venue_portal', '/venue', 'venue', 'venue_app', 'Venue Portal', true, '["venue_owner", "venue_manager", "club_admin", "admin", "super_admin"]'::jsonb, 'portal', true, false, 10, '{"source": "dynamic_runtime_registries"}'::jsonb)
on conflict do nothing;

insert into public.platform_option_sets (
  option_set_key,
  label,
  description,
  value_type,
  surface,
  metadata
)
values
  ('challenge_stake_fet', 'Challenge stake options', 'Allowed FET stakes for friend and public challenges.', 'number', 'mobile', '{"domain": "prediction_challenges"}'::jsonb),
  ('prediction_market_category_order', 'Prediction market category order', 'Display order for market categories in market selectors.', 'text', 'both', '{"domain": "predictions"}'::jsonb),
  ('membership_tier_slugs', 'Membership tier slugs', 'Canonical membership tier slugs for forms, filters, and notifications.', 'text', 'both', '{"domain": "membership"}'::jsonb),
  ('notification_audiences', 'Notification audiences', 'Admin-selectable notification target audiences.', 'text', 'admin', '{"domain": "notifications"}'::jsonb),
  ('content_distributions', 'Content distributions', 'Allowed surfaces for CMS and banner distribution.', 'text', 'admin', '{"domain": "cms"}'::jsonb),
  ('venue_order_statuses', 'Venue order statuses', 'Venue drink order workflow statuses.', 'text', 'venue', '{"domain": "venue"}'::jsonb)
on conflict do nothing;

with sets as (
  select id, option_set_key from public.platform_option_sets
)
insert into public.platform_option_values (
  option_set_id,
  option_key,
  label,
  value,
  sort_order,
  is_default,
  metadata
)
select sets.id, seed.option_key, seed.label, seed.value, seed.sort_order, seed.is_default, seed.metadata
from sets
join (
  values
    ('challenge_stake_fet', 'stake_500', '500 FET', '500'::jsonb, 10, false, '{}'::jsonb),
    ('challenge_stake_fet', 'stake_1000', '1,000 FET', '1000'::jsonb, 20, true, '{}'::jsonb),
    ('challenge_stake_fet', 'stake_3000', '3,000 FET', '3000'::jsonb, 30, false, '{}'::jsonb),
    ('challenge_stake_fet', 'stake_5000', '5,000 FET', '5000'::jsonb, 40, false, '{}'::jsonb),
    ('challenge_stake_fet', 'stake_10000', '10,000 FET', '10000'::jsonb, 50, false, '{}'::jsonb),
    ('prediction_market_category_order', 'match_picks', 'Match Picks', '"Match Picks"'::jsonb, 10, true, '{}'::jsonb),
    ('prediction_market_category_order', 'goal_picks', 'Goal Picks', '"Goal Picks"'::jsonb, 20, false, '{}'::jsonb),
    ('prediction_market_category_order', 'goalscorer_markets', 'Goalscorer Markets', '"Goalscorer Markets"'::jsonb, 30, false, '{}'::jsonb),
    ('prediction_market_category_order', 'handicap_picks', 'Handicap Picks', '"Handicap Picks"'::jsonb, 40, false, '{}'::jsonb),
    ('prediction_market_category_order', 'corner_picks', 'Corner Picks', '"Corner Picks"'::jsonb, 50, false, '{}'::jsonb),
    ('prediction_market_category_order', 'card_picks', 'Card Picks', '"Card Picks"'::jsonb, 60, false, '{}'::jsonb),
    ('prediction_market_category_order', 'player_props', 'Player Props', '"Player Props"'::jsonb, 70, false, '{}'::jsonb),
    ('prediction_market_category_order', 'match_props', 'Match Props', '"Match Props"'::jsonb, 80, false, '{}'::jsonb),
    ('prediction_market_category_order', 'match_events', 'Match Events', '"Match Events"'::jsonb, 90, false, '{}'::jsonb),
    ('prediction_market_category_order', 'in_play_live', 'In-Play/Live', '"In-Play/Live"'::jsonb, 100, false, '{}'::jsonb),
    ('prediction_market_category_order', 'combo_markets', 'Combo Markets', '"Combo Markets"'::jsonb, 110, false, '{}'::jsonb),
    ('membership_tier_slugs', 'gold', 'Gold', '"gold"'::jsonb, 10, false, '{}'::jsonb),
    ('membership_tier_slugs', 'silver', 'Silver', '"silver"'::jsonb, 20, false, '{}'::jsonb),
    ('membership_tier_slugs', 'bronze', 'Bronze', '"bronze"'::jsonb, 30, false, '{}'::jsonb),
    ('membership_tier_slugs', 'imena', 'Imena', '"imena"'::jsonb, 40, true, '{}'::jsonb),
    ('membership_tier_slugs', 'inyamibwa', 'Inyamibwa', '"inyamibwa"'::jsonb, 50, false, '{}'::jsonb),
    ('membership_tier_slugs', 'ingenzi_imanzi', 'Ingenzi / Imanzi', '"ingenzi-imanzi"'::jsonb, 60, false, '{}'::jsonb),
    ('notification_audiences', 'all_fans', 'All fans', '"all_fans"'::jsonb, 10, true, '{}'::jsonb),
    ('notification_audiences', 'by_tier', 'By tier', '"by_tier"'::jsonb, 20, false, '{}'::jsonb),
    ('notification_audiences', 'by_group', 'By group', '"by_group"'::jsonb, 30, false, '{}'::jsonb),
    ('content_distributions', 'both', 'Both Web and App', '"both"'::jsonb, 10, true, '{}'::jsonb),
    ('content_distributions', 'web', 'Website only', '"web"'::jsonb, 20, false, '{}'::jsonb),
    ('content_distributions', 'app', 'Mobile App only', '"app"'::jsonb, 30, false, '{}'::jsonb),
    ('venue_order_statuses', 'created', 'Created', '"created"'::jsonb, 10, true, '{}'::jsonb),
    ('venue_order_statuses', 'accepted', 'Accepted', '"accepted"'::jsonb, 20, false, '{}'::jsonb),
    ('venue_order_statuses', 'preparing', 'Preparing', '"preparing"'::jsonb, 30, false, '{}'::jsonb),
    ('venue_order_statuses', 'ready', 'Ready', '"ready"'::jsonb, 40, false, '{}'::jsonb),
    ('venue_order_statuses', 'served', 'Served', '"served"'::jsonb, 50, false, '{}'::jsonb),
    ('venue_order_statuses', 'cancelled', 'Cancelled', '"cancelled"'::jsonb, 60, false, '{}'::jsonb)
) as seed(option_set_key, option_key, label, value, sort_order, is_default, metadata)
  on seed.option_set_key = sets.option_set_key
on conflict (option_set_id, option_key) do update
set
  label = excluded.label,
  value = excluded.value,
  sort_order = excluded.sort_order,
  is_default = excluded.is_default,
  metadata = public.platform_option_values.metadata || excluded.metadata,
  is_active = true,
  updated_at = timezone('utc', now());

insert into public.runtime_copy (
  copy_key,
  surface,
  locale,
  text_value,
  description,
  metadata
)
values
  ('home.feed.degraded', 'mobile', 'en', 'Live club data is temporarily unavailable. Try again shortly.', 'Neutral mobile home degraded-state message.', '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('home.latest_intel.empty', 'mobile', 'en', 'Club updates will appear when published.', 'Neutral mobile latest-intel empty state.', '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('shop.product.not_found', 'mobile', 'en', 'Product not found.', 'Shop product detail empty state.', '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('tv.unpaired.message', 'tv', 'en', 'Pair this TV display from the admin panel.', 'Native TV unpaired display copy.', '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('tv.default.prompt', 'tv', 'en', 'Open Fan Zone in the supporter app to join this live experience.', 'Native TV default prompt.', '{"source": "dynamic_runtime_registries"}'::jsonb),
  ('momo.instructions.rw', 'mobile', 'en', 'Use the official in-app payment flow or verified club MoMo instructions shown at checkout.', 'MoMo display instruction copy.', '{"source": "dynamic_runtime_registries"}'::jsonb)
on conflict do nothing;

insert into public.site_navigation_items (
  nav_key,
  label,
  href,
  nav_group,
  surface,
  feature_key,
  sort_order,
  metadata
)
values
  ('home', 'Home', '/', 'primary', 'web', 'home', 10, '{}'::jsonb),
  ('fixtures', 'Fixtures', '/fixtures', 'primary', 'web', 'live', 20, '{}'::jsonb),
  ('tickets', 'Tickets', '/tickets', 'primary', 'web', 'ticketing', 30, '{}'::jsonb),
  ('membership', 'Membership', '/membership', 'primary', 'web', 'membership', 40, '{}'::jsonb),
  ('groups', 'Groups', '/circles', 'primary', 'web', 'contributions', 50, '{}'::jsonb),
  ('shop', 'Shop', '/shop', 'primary', 'web', 'shop', 60, '{}'::jsonb),
  ('news', 'News', '/news', 'primary', 'web', 'news', 70, '{}'::jsonb),
  ('squad', 'Squad', '/squad', 'primary', 'web', 'squad', 80, '{}'::jsonb),
  ('standings', 'Standings', '/standings', 'primary', 'web', 'live', 90, '{}'::jsonb),
  ('fan_clubs', 'Fan Clubs', '/fan-clubs', 'primary', 'web', 'fan_clubs', 100, '{}'::jsonb),
  ('history', 'History', '/history', 'primary', 'web', 'club_history', 110, '{}'::jsonb),
  ('contact', 'Contact', '/contact', 'primary', 'web', 'contact_support', 120, '{}'::jsonb),
  ('results', 'Results', '/results', 'utility', 'web', 'live', 10, '{}'::jsonb),
  ('utility_history', 'History', '/history', 'utility', 'web', 'club_history', 20, '{}'::jsonb),
  ('utility_contact', 'Contact', '/contact', 'utility', 'web', 'contact_support', 30, '{}'::jsonb),
  ('footer_fixtures', 'Fixtures', '/fixtures', 'footer_matchday', 'web', 'live', 10, '{}'::jsonb),
  ('footer_tickets', 'Tickets', '/tickets', 'footer_matchday', 'web', 'ticketing', 20, '{}'::jsonb),
  ('footer_results', 'Results', '/results', 'footer_matchday', 'web', 'live', 30, '{}'::jsonb),
  ('footer_standings', 'Standings', '/standings', 'footer_matchday', 'web', 'live', 40, '{}'::jsonb),
  ('footer_membership', 'Membership', '/membership', 'footer_supporters', 'web', 'membership', 10, '{}'::jsonb),
  ('footer_groups', 'Groups', '/circles', 'footer_supporters', 'web', 'contributions', 20, '{}'::jsonb),
  ('footer_fan_clubs', 'Fan Clubs', '/fan-clubs', 'footer_supporters', 'web', 'fan_clubs', 30, '{}'::jsonb),
  ('footer_news', 'News', '/news', 'footer_club', 'web', 'news', 10, '{}'::jsonb),
  ('footer_squad', 'Squad', '/squad', 'footer_club', 'web', 'squad', 20, '{}'::jsonb),
  ('footer_history', 'History', '/history', 'footer_club', 'web', 'club_history', 30, '{}'::jsonb),
  ('footer_contact', 'Contact', '/contact', 'footer_club', 'web', 'contact_support', 40, '{}'::jsonb),
  ('privacy', 'Privacy', '/privacy', 'legal', 'web', 'privacy_policy', 10, '{}'::jsonb),
  ('terms', 'Terms', '/terms', 'legal', 'web', 'terms', 20, '{}'::jsonb)
on conflict do nothing;

insert into public.site_search_items (
  search_key,
  title,
  description,
  href,
  category,
  meta_label,
  surface,
  feature_key,
  sort_order,
  metadata
)
values
  ('page_home', 'Homepage', 'Live matchday, tickets, groups, and club storytelling.', '/', 'Page', 'Overview', 'web', 'home', 10, '{}'::jsonb),
  ('page_fixtures', 'Fixtures', 'Upcoming matches, live center links, and recent results.', '/fixtures', 'Match', 'Schedule', 'web', 'live', 20, '{}'::jsonb),
  ('page_tickets', 'Tickets', 'Official ticket hub with live pricing and fixture detail.', '/tickets', 'Match', 'Buy', 'web', 'ticketing', 30, '{}'::jsonb),
  ('page_membership', 'Membership', 'Tier comparison, benefits, and supporter identity.', '/membership', 'Membership', 'Plans', 'web', 'membership', 40, '{}'::jsonb),
  ('page_groups', 'Groups', 'Supporter groups and club initiatives.', '/circles', 'Supporters', 'Groups', 'web', 'contributions', 50, '{}'::jsonb),
  ('page_shop', 'Shop', 'Official merchandise and supporter products.', '/shop', 'Shop', 'Products', 'web', 'shop', 60, '{}'::jsonb),
  ('page_news', 'News', 'Published club updates and matchday stories.', '/news', 'News', 'Updates', 'web', 'news', 70, '{}'::jsonb),
  ('page_fan_clubs', 'Fan Clubs', 'Supporter chapters and fan communities.', '/fan-clubs', 'Supporters', 'Chapters', 'web', 'fan_clubs', 80, '{}'::jsonb)
on conflict do nothing;

insert into public.venue_governance_controls (
  control_key,
  label,
  detail,
  status_label,
  action_label,
  control_group,
  sort_order,
  metadata
)
values
  ('onboarding_review', 'Pending public profile review', 'Confirm venue status, city, radius policy, and approved public copy.', 'Needs club approval', 'Approve profile', 'onboarding', 10, '{}'::jsonb),
  ('staff_assignment', 'Assign venue operator', 'Owner, manager, and staff roles are scoped to one venue.', 'Admin only', 'Assign staff', 'staff', 10, '{}'::jsonb),
  ('campaign_approval', 'Check-in campaign approval', 'Review dates, FET budget, location rules, and max check-ins per supporter.', 'Approval required', 'Approve campaign', 'campaigns', 10, '{}'::jsonb),
  ('campaign_disable', 'Disable campaign', 'Pause rewards immediately when abuse, budget, or compliance review starts.', 'Fails closed', 'Disable', 'campaigns', 20, '{}'::jsonb),
  ('fet_export', 'FET export', 'Export check-in awards, reservations, reversals, and campaign events.', 'Closed-loop only', 'Download CSV', 'fet', 10, '{}'::jsonb),
  ('fet_reversal', 'Reversal readiness', 'Reasoned reversals require approval before ledger adjustment.', 'Approval gated', 'Prepare reversal', 'fet', 20, '{}'::jsonb),
  ('order_audit', 'Order status audit', 'Created, accepted, preparing, ready, served, and cancelled events stay visible.', 'Event trail', 'View audit', 'audit', 10, '{}'::jsonb),
  ('location_retention', 'Location retention', 'Location is foreground-only and must remain privacy-reviewed before release.', 'Review required', 'Flag review', 'compliance', 10, '{}'::jsonb),
  ('alcohol_age_gate', 'Alcohol age gate', 'Alcohol items remain blocked unless staff procedure and copy are approved.', 'Blocked', 'Keep blocked', 'compliance', 20, '{}'::jsonb)
on conflict do nothing;

commit;
