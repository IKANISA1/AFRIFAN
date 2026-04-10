-- PWA analytics and server-side Web Push subscription storage for Gikundiro.

create table if not exists public.pwa_engagement_events (
  id uuid primary key default gen_random_uuid(),
  club_id text not null,
  user_id uuid null references auth.users(id) on delete set null,
  event_type text not null,
  surface text not null,
  path text null,
  display_mode text null,
  payload jsonb not null default '{}'::jsonb,
  user_agent text null,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_pwa_engagement_events_club_created
  on public.pwa_engagement_events (club_id, created_at desc);

create index if not exists idx_pwa_engagement_events_type_created
  on public.pwa_engagement_events (event_type, created_at desc);

alter table public.pwa_engagement_events enable row level security;

drop policy if exists pwa_engagement_events_admin_read on public.pwa_engagement_events;
create policy pwa_engagement_events_admin_read
  on public.pwa_engagement_events
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.admin_role_assignments ara
      where ara.user_id = auth.uid()
        and ara.is_active = true
    )
  );

create table if not exists public.web_push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  club_id text not null,
  user_id uuid null references auth.users(id) on delete cascade,
  session_id text null,
  surface text not null default 'site',
  path text null,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  language_code text null,
  user_agent text null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  last_seen_at timestamptz not null default timezone('utc', now()),
  last_push_at timestamptz null,
  disabled_at timestamptz null
);

create index if not exists idx_web_push_subscriptions_club_active
  on public.web_push_subscriptions (club_id, disabled_at, last_seen_at desc);

create index if not exists idx_web_push_subscriptions_user
  on public.web_push_subscriptions (user_id, disabled_at, updated_at desc);

drop trigger if exists trg_web_push_subscriptions_updated on public.web_push_subscriptions;
create trigger trg_web_push_subscriptions_updated
  before update on public.web_push_subscriptions
  for each row execute function public.set_updated_at();

alter table public.web_push_subscriptions enable row level security;

drop policy if exists web_push_subscriptions_select_own on public.web_push_subscriptions;
create policy web_push_subscriptions_select_own
  on public.web_push_subscriptions
  for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists web_push_subscriptions_insert_own on public.web_push_subscriptions;
create policy web_push_subscriptions_insert_own
  on public.web_push_subscriptions
  for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists web_push_subscriptions_update_own on public.web_push_subscriptions;
create policy web_push_subscriptions_update_own
  on public.web_push_subscriptions
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists web_push_subscriptions_delete_own on public.web_push_subscriptions;
create policy web_push_subscriptions_delete_own
  on public.web_push_subscriptions
  for delete
  to authenticated
  using (user_id = auth.uid());

grant select on public.pwa_engagement_events to authenticated;
grant select, insert, update, delete on public.web_push_subscriptions to authenticated;
