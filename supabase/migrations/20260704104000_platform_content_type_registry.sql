-- Database-owned CMS content type registry.
-- Admin content categories can now be changed in Supabase instead of being
-- hardcoded in the web admin panel.

create table if not exists public.platform_content_types (
  content_type text primary key,
  label text not null,
  description text,
  default_distribution text not null default 'both',
  sort_order integer not null default 0,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now()),
  constraint platform_content_types_key_check
    check (content_type ~ '^[a-z0-9][a-z0-9_:-]*$'),
  constraint platform_content_types_distribution_check
    check (default_distribution in ('web', 'app', 'both')),
  constraint platform_content_types_metadata_object_check
    check (jsonb_typeof(metadata) = 'object')
);

create index if not exists idx_platform_content_types_active_order
  on public.platform_content_types (is_active, sort_order, label);

drop trigger if exists trg_platform_content_types_updated
  on public.platform_content_types;
create trigger trg_platform_content_types_updated
  before update on public.platform_content_types
  for each row execute function public.set_updated_at();

alter table public.platform_content_types enable row level security;

drop policy if exists platform_content_types_select_active
  on public.platform_content_types;
create policy platform_content_types_select_active
  on public.platform_content_types
  for select
  using (is_active = true);

drop policy if exists platform_content_types_select_admin
  on public.platform_content_types;
create policy platform_content_types_select_admin
  on public.platform_content_types
  for select
  to authenticated
  using (public.is_admin_user());

drop policy if exists platform_content_types_insert_admin
  on public.platform_content_types;
create policy platform_content_types_insert_admin
  on public.platform_content_types
  for insert
  to authenticated
  with check (public.is_admin_user());

drop policy if exists platform_content_types_update_admin
  on public.platform_content_types;
create policy platform_content_types_update_admin
  on public.platform_content_types
  for update
  to authenticated
  using (public.is_admin_user())
  with check (public.is_admin_user());

drop policy if exists platform_content_types_delete_admin
  on public.platform_content_types;
create policy platform_content_types_delete_admin
  on public.platform_content_types
  for delete
  to authenticated
  using (public.is_admin_user());

create or replace function public.get_platform_content_types(
  p_include_inactive boolean default false
)
returns table (
  content_type text,
  label text,
  description text,
  default_distribution text,
  sort_order integer,
  is_active boolean,
  metadata jsonb
)
language sql
stable
set search_path = public, pg_temp
as $$
  select
    pct.content_type,
    pct.label,
    pct.description,
    pct.default_distribution,
    pct.sort_order,
    pct.is_active,
    pct.metadata
  from public.platform_content_types pct
  where p_include_inactive = true or pct.is_active = true
  order by pct.sort_order, pct.label;
$$;

grant execute on function public.get_platform_content_types(boolean)
  to anon, authenticated;

insert into public.platform_content_types (
  content_type,
  label,
  description,
  default_distribution,
  sort_order,
  is_active,
  metadata
)
values
  (
    'club_history',
    'Club history',
    'Long-form history and institutional story content.',
    'both',
    10,
    true,
    '{"surface": "cms_content"}'::jsonb
  ),
  (
    'privacy_policy',
    'Privacy policy',
    'Privacy notices shown across web and app surfaces.',
    'both',
    20,
    true,
    '{"surface": "cms_content"}'::jsonb
  ),
  (
    'terms',
    'Terms',
    'Terms and conditions content.',
    'both',
    30,
    true,
    '{"surface": "cms_content"}'::jsonb
  ),
  (
    'contact_support',
    'Contact support',
    'Support and contact guidance.',
    'both',
    40,
    true,
    '{"surface": "cms_content"}'::jsonb
  ),
  (
    'section_heading',
    'Section heading',
    'Reusable section headings and supporting copy.',
    'both',
    50,
    true,
    '{"surface": "cms_content"}'::jsonb
  ),
  (
    'portal_hero',
    'Portal hero',
    'Hero copy for portal and admin-adjacent pages.',
    'web',
    60,
    true,
    '{"surface": "cms_content"}'::jsonb
  ),
  (
    'general',
    'General',
    'General-purpose managed content block.',
    'both',
    100,
    true,
    '{"surface": "cms_content"}'::jsonb
  )
on conflict (content_type) do update
set
  label = excluded.label,
  description = excluded.description,
  default_distribution = excluded.default_distribution,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  metadata = public.platform_content_types.metadata || excluded.metadata,
  updated_at = timezone('utc'::text, now());
