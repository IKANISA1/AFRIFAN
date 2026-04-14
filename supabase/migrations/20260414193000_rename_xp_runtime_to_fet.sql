do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'user_notification_settings'
      and column_name = 'xp_milestones'
  ) and not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'user_notification_settings'
      and column_name = 'fet_milestones'
  ) then
    execute 'alter table public.user_notification_settings rename column xp_milestones to fet_milestones';
  end if;
end;
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'xp_events'
  ) and not exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'fet_events'
  ) then
    execute 'alter table public.xp_events rename to fet_events';
  end if;
end;
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fet_events'
      and column_name = 'xp_awarded'
  ) and not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fet_events'
      and column_name = 'fet_awarded'
  ) then
    execute 'alter table public.fet_events rename column xp_awarded to fet_awarded';
  end if;
end;
$$;

do $$
begin
  begin
    execute 'alter table public.fet_events rename constraint xp_events_pkey to fet_events_pkey';
  exception
    when undefined_object then null;
  end;

  begin
    execute 'alter index public.idx_xp_events_user_date rename to idx_fet_events_user_date';
  exception
    when undefined_object then null;
  end;

  begin
    execute 'alter table public.fet_events rename constraint xp_events_club_id_fkey to fet_events_club_id_fkey';
  exception
    when undefined_object then null;
  end;

  begin
    execute 'alter table public.fet_events rename constraint xp_events_user_id_fkey to fet_events_user_id_fkey';
  exception
    when undefined_object then null;
  end;
end;
$$;

create or replace function public.xp_events_compat_write() returns trigger
language plpgsql
set search_path to 'public'
as $$
declare
  v_event public.fet_events%rowtype;
begin
  if tg_op = 'DELETE' then
    delete from public.fet_events
    where id = old.id;
    return old;
  end if;

  if tg_op = 'UPDATE' then
    update public.fet_events
    set
      user_id = new.user_id,
      club_id = coalesce(new.club_id, old.club_id),
      event_type = new.event_type,
      fet_awarded = coalesce(new.xp_awarded, old.xp_awarded, 0),
      metadata = coalesce(new.metadata, old.metadata, '{}'::jsonb),
      event_at = coalesce(new.event_at, old.event_at),
      created_at = coalesce(new.created_at, old.created_at)
    where id = old.id
    returning * into v_event;

    new.id := v_event.id;
    new.created_at := v_event.created_at;
    new.event_at := v_event.event_at;
    new.xp_awarded := v_event.fet_awarded;
    return new;
  end if;

  insert into public.fet_events (
    user_id,
    club_id,
    event_type,
    fet_awarded,
    metadata,
    event_at,
    created_at
  )
  values (
    new.user_id,
    new.club_id,
    new.event_type,
    coalesce(new.xp_awarded, 0),
    coalesce(new.metadata, '{}'::jsonb),
    coalesce(new.event_at, timezone('utc', now())),
    coalesce(new.created_at, timezone('utc', now()))
  )
  returning * into v_event;

  new.id := v_event.id;
  new.created_at := v_event.created_at;
  new.event_at := v_event.event_at;
  new.xp_awarded := v_event.fet_awarded;
  return new;
end;
$$;

create or replace function public.cool_events_write() returns trigger
language plpgsql
set search_path to 'public'
as $$
declare
  v_event_id uuid;
  v_row record;
begin
  if tg_op = 'DELETE' then
    delete from public.fet_events
    where id = old.id;
    return old;
  end if;

  if tg_op = 'UPDATE' then
    update public.fet_events
    set
      user_id = new.user_id,
      club_id = coalesce(new.club_id, old.club_id),
      event_type = new.event_type,
      fet_awarded = coalesce(new.fet_awarded, new.xp_awarded, new.points_awarded, 0),
      metadata = jsonb_strip_nulls(
        coalesce(new.metadata, '{}'::jsonb)
        || jsonb_build_object(
          'source_id', nullif(btrim(coalesce(new.source_id, '')), ''),
          'referrer_id', new.referrer_id,
          'dedupe_key', nullif(btrim(coalesce(new.dedupe_key, '')), ''),
          'campaign_id', nullif(btrim(coalesce(new.campaign_id, '')), ''),
          'season_id', new.season_id,
          'mock_batch', nullif(btrim(coalesce(new.mock_batch, '')), ''),
          'source_table', 'cool_events'
        )
      ),
      event_at = coalesce(new.event_at, old.event_at),
      created_at = coalesce(new.created_at, old.created_at)
    where id = old.id;
    v_event_id := old.id;
  else
    insert into public.fet_events (
      user_id,
      club_id,
      event_type,
      fet_awarded,
      metadata,
      event_at,
      created_at
    )
    values (
      new.user_id,
      new.club_id,
      new.event_type,
      coalesce(new.fet_awarded, new.xp_awarded, new.points_awarded, 0),
      jsonb_strip_nulls(
        coalesce(new.metadata, '{}'::jsonb)
        || jsonb_build_object(
          'source_id', nullif(btrim(coalesce(new.source_id, '')), ''),
          'referrer_id', new.referrer_id,
          'dedupe_key', nullif(btrim(coalesce(new.dedupe_key, '')), ''),
          'campaign_id', nullif(btrim(coalesce(new.campaign_id, '')), ''),
          'season_id', new.season_id,
          'mock_batch', nullif(btrim(coalesce(new.mock_batch, '')), ''),
          'source_table', 'cool_events'
        )
      ),
      coalesce(new.event_at, timezone('utc', now())),
      coalesce(new.created_at, timezone('utc', now()))
    )
    returning id into v_event_id;
  end if;

  select *
  into v_row
  from public.cool_events
  where id = v_event_id
  order by created_at desc
  limit 1;

  new := v_row;
  return new;
end;
$$;

create or replace view public.cool_events
with (security_invoker = true) as
select
  x.id,
  x.user_id,
  x.event_type,
  nullif(x.metadata ->> 'source_id', '') as source_id,
  coalesce(x.fet_awarded, 0) as points_awarded,
  x.metadata,
  case
    when coalesce(x.metadata ->> 'referrer_id', '') ~* '^[0-9a-f-]{36}$' then (x.metadata ->> 'referrer_id')::uuid
    else null
  end as referrer_id,
  x.created_at,
  nullif(x.metadata ->> 'dedupe_key', '') as dedupe_key,
  nullif(x.metadata ->> 'campaign_id', '') as campaign_id,
  case
    when coalesce(x.metadata ->> 'season_id', '') ~* '^[0-9a-f-]{36}$' then (x.metadata ->> 'season_id')::uuid
    else null
  end as season_id,
  false as is_mock,
  nullif(x.metadata ->> 'mock_batch', '') as mock_batch,
  x.club_id,
  x.fet_awarded,
  x.fet_awarded as xp_awarded,
  x.event_at
from public.fet_events x;

drop trigger if exists trg_cool_events_write on public.cool_events;
create trigger trg_cool_events_write
instead of insert or update or delete on public.cool_events
for each row execute function public.cool_events_write();

drop view if exists public.xp_events;
create view public.xp_events
with (security_invoker = true) as
select
  x.id,
  x.user_id,
  x.club_id,
  x.event_type,
  x.fet_awarded as xp_awarded,
  x.metadata,
  x.event_at,
  x.created_at
from public.fet_events x;

drop trigger if exists trg_xp_events_compat_write on public.xp_events;
create trigger trg_xp_events_compat_write
instead of insert or update or delete on public.xp_events
for each row execute function public.xp_events_compat_write();

grant select, insert, update, delete on public.xp_events to authenticated, service_role;
