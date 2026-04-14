begin;

create or replace function public.resolve_club_country_code(
  p_club_id bigint default null
) returns text
language sql
stable
security definer
set search_path to 'public'
as $$
  select coalesce(
    (
      select nullif(btrim(afc.country_iso_code), '')
      from public.african_football_clubs afc
      where afc.id = coalesce(p_club_id, nullif(public.requesting_club_id(), '')::bigint)
      limit 1
    ),
    'RW'
  );
$$;

create or replace function public.resolve_club_currency_code(
  p_club_id bigint default null
) returns text
language sql
stable
security definer
set search_path to 'public'
as $$
  select coalesce(
    (
      select nullif(btrim(afc.currency_code), '')
      from public.african_football_clubs afc
      where afc.id = coalesce(p_club_id, nullif(public.requesting_club_id(), '')::bigint)
      limit 1
    ),
    (
      select nullif(btrim(c.currency), '')
      from public.african_football_clubs afc
      join public.countries c
        on c.id = afc.country_iso_code
      where afc.id = coalesce(p_club_id, nullif(public.requesting_club_id(), '')::bigint)
      limit 1
    ),
    'RWF'
  );
$$;

create or replace function public.is_admin_user() returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (
    select 1
    from public.users
    where id = auth.uid()
      and is_admin = true
  ) or exists (
    select 1
    from public.admin_role_assignments ara
    where ara.user_id = auth.uid()
      and ara.is_active = true
      and ara.role in ('admin', 'super_admin')
  );
$$;

create or replace function public.is_super_admin() returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  return exists (
    select 1
    from public.admin_role_assignments
    where user_id = auth.uid()
      and is_active = true
      and role = 'super_admin'
  );
end;
$$;

create or replace function public.is_club_admin(
  p_club_id bigint default null::bigint
) returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_user_id uuid;
  v_club_id bigint := coalesce(p_club_id, nullif(public.requesting_club_id(), '')::bigint);
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return false;
  end if;

  return exists (
    select 1
    from public.admin_role_assignments ara
    where ara.user_id = v_user_id
      and ara.is_active = true
      and (
        ara.role in ('admin', 'super_admin')
        or (
          ara.role in ('club_admin', 'club_moderator', 'partner', 'rayon_sport', 'bank')
          and ara.club_id = v_club_id
        )
      )
  ) or exists (
    select 1
    from public.users
    where id = v_user_id
      and is_admin = true
  );
end;
$$;

create or replace function public.rs_is_partner_admin(
  p_partner_id uuid
) returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (
    select 1
    from public.admin_role_assignments ara
    where ara.user_id = auth.uid()
      and ara.is_active = true
      and (
        ara.role in ('admin', 'super_admin')
        or (
          ara.role in ('partner', 'rayon_sport', 'bank')
          and ara.partner_scope_id = p_partner_id
        )
      )
  ) or exists (
    select 1
    from public.users
    where id = auth.uid()
      and is_admin = true
  );
$$;

create or replace function public.user_is_rayon_admin() returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select public.is_admin_user()
    or exists (
      select 1
      from public.admin_role_assignments ara
      where ara.user_id = auth.uid()
        and ara.is_active = true
        and ara.role in ('partner', 'rayon_sport', 'club_admin', 'club_moderator', 'bank')
    );
$$;

create or replace function public.normalize_club_id(raw_club_id text) returns bigint
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_trimmed text;
  v_club_id bigint;
begin
  v_trimmed := nullif(btrim(coalesce(raw_club_id, '')), '');
  if v_trimmed is null then
    return null;
  end if;

  if v_trimmed ~ '^[0-9]+$' then
    return v_trimmed::bigint;
  end if;

  select afc.id
  into v_club_id
  from public.african_football_clubs afc
  where lower(afc.club_slug) = lower(v_trimmed)
     or lower(replace(afc.club_slug, '-', '_')) = lower(replace(v_trimmed, '-', '_'))
  order by afc.is_active desc, afc.id asc
  limit 1;

  return v_club_id;
end;
$$;

alter table public.groups
  add column if not exists allow_chat boolean default true not null;

alter table public.groups
  alter column currency set default public.resolve_club_currency_code();

alter table public.groups
  alter column country set default public.resolve_club_country_code();

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'admin_role_assignments_role_check'
      and conrelid = 'public.admin_role_assignments'::regclass
  ) then
    alter table public.admin_role_assignments
      drop constraint admin_role_assignments_role_check;
  end if;
end;
$$;

alter table public.admin_role_assignments
  add constraint admin_role_assignments_role_check
  check (
    role = any (
      array[
        'admin'::text,
        'super_admin'::text,
        'bank'::text,
        'partner'::text,
        'rayon_sport'::text,
        'club_admin'::text,
        'club_moderator'::text
      ]
    )
  );

create or replace function public.sync_group_contract_columns() returns trigger
language plpgsql
set search_path to 'public'
as $$
declare
  v_group_type text;
  v_privacy text;
begin
  v_group_type := lower(
    nullif(
      btrim(
        coalesce(new.group_type, new.type, 'community')
      ),
      ''
    )
  );

  if v_group_type = 'saving' then
    v_group_type := 'savings';
  elsif v_group_type not in ('club', 'community', 'savings', 'fan_circle') then
    v_group_type := 'community';
  end if;

  new.group_type := v_group_type;
  new.type := case
    when v_group_type = 'savings' then 'saving'
    else v_group_type
  end;

  v_privacy := lower(
    nullif(
      btrim(
        coalesce(new.privacy, new.visibility, 'private')
      ),
      ''
    )
  );

  if v_privacy = 'members' then
    v_privacy := 'friends';
  elsif v_privacy not in ('public', 'friends', 'private') then
    v_privacy := 'private';
  end if;

  new.privacy := v_privacy;
  new.visibility := case
    when v_privacy = 'public' then 'public'
    else 'private'
  end;

  if new.current_total is null then
    new.current_total := coalesce(new.amount, 0);
  end if;

  if new.amount is null then
    new.amount := coalesce(new.current_total, 0)::integer;
  end if;

  if new.receiving_momo_code is null and new.momo_code is not null then
    new.receiving_momo_code := new.momo_code;
  end if;

  if new.momo_code is null and new.receiving_momo_code is not null then
    new.momo_code := new.receiving_momo_code;
  end if;

  if new.contribution_amount is null and new.monthly_contribution is not null then
    new.contribution_amount := new.monthly_contribution;
  end if;

  if new.monthly_contribution is null and new.contribution_amount is not null then
    new.monthly_contribution := new.contribution_amount;
  end if;

  if new.is_closed is null then
    new.is_closed := coalesce(new.is_active, true) = false;
  end if;

  if new.is_active is null then
    new.is_active := coalesce(new.is_closed, false) = false;
  end if;

  new.allow_chat := coalesce(new.allow_chat, true);
  new.member_count := greatest(coalesce(new.member_count, 1), 0);
  new.invite_code := upper(coalesce(new.invite_code, public.generate_invite_code()));

  return new;
end;
$$;

create or replace function public.apply_group_club_defaults() returns trigger
language plpgsql
set search_path to 'public'
as $$
declare
  v_club_id bigint;
  v_country text;
  v_currency text;
begin
  if new.club_id is null then
    new.club_id := nullif(public.requesting_club_id(), '')::bigint;
  end if;

  v_club_id := new.club_id;
  if v_club_id is null then
    return new;
  end if;

  v_country := public.resolve_club_country_code(v_club_id);
  v_currency := public.resolve_club_currency_code(v_club_id);

  if tg_op = 'INSERT' then
    if nullif(btrim(coalesce(new.country, '')), '') is null or (new.country = 'RW' and v_country <> 'RW') then
      new.country := v_country;
    end if;

    if nullif(btrim(coalesce(new.currency, '')), '') is null or (new.currency = 'RWF' and v_currency <> 'RWF') then
      new.currency := v_currency;
    end if;
  else
    if nullif(btrim(coalesce(new.country, '')), '') is null then
      new.country := v_country;
    end if;

    if nullif(btrim(coalesce(new.currency, '')), '') is null then
      new.currency := v_currency;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_groups_contract_sync on public.groups;
create trigger trg_groups_contract_sync
before insert or update on public.groups
for each row execute function public.sync_group_contract_columns();

drop trigger if exists trg_groups_club_defaults on public.groups;
create trigger trg_groups_club_defaults
before insert or update on public.groups
for each row execute function public.apply_group_club_defaults();

create or replace function public.contribution_groups_write() returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_actor_id uuid := auth.uid();
  v_requesting_club_id bigint := nullif(public.requesting_club_id(), '')::bigint;
  v_group_id uuid;
  v_group record;
  v_result record;
  v_display_name text;
begin
  if tg_op = 'DELETE' then
    select g.*
    into v_group
    from public.groups g
    where g.id = old.id;

    if not found then
      return old;
    end if;

    if not (
      public.is_super_admin()
      or public.is_club_admin(v_group.club_id)
      or v_group.creator_id = v_actor_id
    ) then
      raise exception 'You do not have permission to delete this contribution group.';
    end if;

    delete from public.groups where id = old.id;
    return old;
  end if;

  if v_actor_id is null then
    raise exception 'Authentication is required.';
  end if;

  if tg_op = 'INSERT'
     and new.creator_id is not null
     and new.creator_id <> v_actor_id
     and not public.is_super_admin() then
    raise exception 'You cannot create or update a contribution group for another user.';
  end if;

  if tg_op = 'UPDATE' then
    select g.*
    into v_group
    from public.groups g
    where g.id = old.id;

    if not found then
      raise exception 'Contribution group not found.';
    end if;

    if not (
      public.is_super_admin()
      or public.is_club_admin(v_group.club_id)
      or v_group.creator_id = v_actor_id
    ) then
      raise exception 'You do not have permission to update this contribution group.';
    end if;

    if new.club_id is not null and new.club_id <> v_group.club_id and not public.is_super_admin() then
      raise exception 'Contribution groups cannot be moved across clubs.';
    end if;

    if new.creator_id is distinct from v_group.creator_id and not public.is_super_admin() then
      raise exception 'Only super admins can reassign contribution group ownership.';
    end if;

    update public.groups
    set
      creator_id = coalesce(new.creator_id, v_group.creator_id),
      name = new.name,
      description = nullif(btrim(coalesce(new.description, '')), ''),
      group_type = new.group_type,
      privacy = new.privacy,
      target_amount = coalesce(new.target_amount, 0),
      current_total = coalesce(new.current_total, new.amount, 0),
      momo_code = coalesce(
        nullif(btrim(coalesce(new.receiving_momo_code, '')), ''),
        nullif(btrim(coalesce(new.momo_recipient_code, '')), ''),
        nullif(btrim(coalesce(new.momo_number, '')), ''),
        v_group.momo_code
      ),
      deadline = new.deadline,
      is_recurring = coalesce(new.is_recurring, false),
      is_closed = coalesce(new.is_closed, false),
      invite_code = coalesce(nullif(btrim(coalesce(new.invite_code, '')), ''), v_group.invite_code),
      member_count = greatest(coalesce(new.member_count, v_group.member_count, 0), 0),
      club_id = coalesce(new.club_id, v_group.club_id),
      partner_id = coalesce(new.partner_id, v_group.partner_id),
      currency = coalesce(nullif(btrim(coalesce(new.currency, '')), ''), v_group.currency),
      updated_at = now(),
      is_active = coalesce(new.is_active, coalesce(new.is_closed, false) = false),
      country = coalesce(nullif(btrim(coalesce(new.country, '')), ''), v_group.country),
      visibility = coalesce(new.visibility, new.privacy, v_group.visibility),
      type = coalesce(new.type, new.group_type, v_group.type),
      amount = coalesce(new.amount, new.current_total, v_group.amount, 0)::integer,
      monthly_contribution = coalesce(new.monthly_contribution, new.contribution_amount, v_group.monthly_contribution),
      bank_partner_id = coalesce(new.bank_partner_id, v_group.bank_partner_id),
      momo_number = coalesce(new.momo_number, v_group.momo_number),
      frequency = coalesce(new.frequency, v_group.frequency),
      receiving_momo_route_type = coalesce(new.receiving_momo_route_type, new.momo_route_type, v_group.receiving_momo_route_type),
      receiving_momo_code = coalesce(new.receiving_momo_code, new.momo_recipient_code, v_group.receiving_momo_code),
      cycle_days = coalesce(new.cycle_days, v_group.cycle_days, 30),
      contribution_amount = coalesce(new.contribution_amount, new.monthly_contribution, v_group.contribution_amount, 0),
      allow_chat = coalesce(new.allow_chat, v_group.allow_chat, true)
    where id = old.id
    returning id into v_group_id;
  else
    if coalesce(new.club_id, v_requesting_club_id) is null then
      raise exception 'A club scope is required to create a contribution group.';
    end if;

    if new.club_id is not null and new.club_id <> v_requesting_club_id and not public.is_super_admin() then
      raise exception 'Contribution groups must be created within the active club scope.';
    end if;

    insert into public.groups (
      creator_id,
      name,
      description,
      group_type,
      privacy,
      target_amount,
      current_total,
      momo_code,
      deadline,
      is_recurring,
      is_closed,
      invite_code,
      member_count,
      club_id,
      partner_id,
      currency,
      is_active,
      country,
      visibility,
      type,
      amount,
      monthly_contribution,
      bank_partner_id,
      momo_number,
      frequency,
      receiving_momo_route_type,
      receiving_momo_code,
      cycle_days,
      contribution_amount,
      allow_chat
    )
    values (
      coalesce(new.creator_id, v_actor_id),
      new.name,
      nullif(btrim(coalesce(new.description, '')), ''),
      new.group_type,
      new.privacy,
      coalesce(new.target_amount, 0),
      coalesce(new.current_total, new.amount, 0),
      coalesce(
        nullif(btrim(coalesce(new.receiving_momo_code, '')), ''),
        nullif(btrim(coalesce(new.momo_recipient_code, '')), ''),
        nullif(btrim(coalesce(new.momo_number, '')), '')
      ),
      new.deadline,
      coalesce(new.is_recurring, false),
      coalesce(new.is_closed, false),
      coalesce(nullif(btrim(coalesce(new.invite_code, '')), ''), public.generate_invite_code()),
      greatest(coalesce(new.member_count, 1), 1),
      coalesce(new.club_id, v_requesting_club_id),
      new.partner_id,
      nullif(btrim(coalesce(new.currency, '')), ''),
      coalesce(new.is_active, coalesce(new.is_closed, false) = false),
      nullif(btrim(coalesce(new.country, '')), ''),
      coalesce(new.visibility, new.privacy),
      coalesce(new.type, new.group_type),
      coalesce(new.amount, new.current_total, 0)::integer,
      coalesce(new.monthly_contribution, new.contribution_amount),
      new.bank_partner_id,
      nullif(btrim(coalesce(new.momo_number, '')), ''),
      nullif(btrim(coalesce(new.frequency, '')), ''),
      coalesce(new.receiving_momo_route_type, new.momo_route_type),
      coalesce(new.receiving_momo_code, new.momo_recipient_code),
      coalesce(new.cycle_days, 30),
      coalesce(new.contribution_amount, new.monthly_contribution, 0),
      coalesce(new.allow_chat, true)
    )
    returning id into v_group_id;

    select coalesce(nullif(btrim(u.public_user_id), ''), substr(replace(v_actor_id::text, '-', ''), 1, 6))
    into v_display_name
    from public.users u
    where u.id = v_actor_id;

    insert into public.group_members (
      group_id,
      user_id,
      display_name,
      is_admin,
      is_anonymous,
      contribution_amount,
      joined_at
    )
    values (
      v_group_id,
      v_actor_id,
      coalesce(v_display_name, '000000'),
      true,
      false,
      0,
      now()
    )
    on conflict (group_id, user_id)
    do update set
      is_admin = true,
      display_name = excluded.display_name;
  end if;

  select *
  into v_result
  from public.contribution_groups
  where id = v_group_id;

  new := v_result;
  return new;
end;
$$;

create or replace view public.contribution_groups
with (security_invoker = true) as
select
  g.id,
  g.creator_id,
  g.name,
  g.description,
  coalesce(nullif(g.group_type, ''), case when g.type = 'saving' then 'savings' else g.type end) as group_type,
  coalesce(nullif(g.privacy, ''), case when g.visibility = 'public' then 'public' else 'private' end) as privacy,
  g.target_amount,
  coalesce(g.current_total, g.amount, 0) as current_total,
  coalesce(g.receiving_momo_code, g.momo_code, g.momo_number) as momo_recipient_code,
  coalesce(g.receiving_momo_route_type, case when g.momo_number is not null then 'phone_number' else null end) as momo_route_type,
  g.deadline,
  g.is_recurring,
  g.is_closed,
  g.invite_code,
  g.member_count,
  g.created_at,
  g.club_id,
  g.partner_id,
  g.currency,
  g.updated_at,
  g.is_active,
  g.country,
  g.visibility,
  g.type,
  g.amount,
  g.monthly_contribution,
  g.bank_partner_id,
  g.momo_number,
  g.frequency,
  g.receiving_momo_route_type,
  g.receiving_momo_code,
  g.cycle_days,
  g.contribution_amount,
  g.allow_chat
from public.groups g;

drop trigger if exists trg_contribution_groups_write on public.contribution_groups;
create trigger trg_contribution_groups_write
instead of insert or update or delete on public.contribution_groups
for each row execute function public.contribution_groups_write();

create or replace function public.cool_events_write() returns trigger
language plpgsql
set search_path to 'public'
as $$
declare
  v_event_id uuid;
  v_row record;
begin
  if tg_op = 'DELETE' then
    delete from public.xp_events
    where id = old.id;
    return old;
  end if;

  if tg_op = 'UPDATE' then
    update public.xp_events
    set
      user_id = new.user_id,
      club_id = coalesce(new.club_id, old.club_id),
      event_type = new.event_type,
      xp_awarded = coalesce(new.xp_awarded, new.points_awarded, 0),
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
    insert into public.xp_events (
      user_id,
      club_id,
      event_type,
      xp_awarded,
      metadata,
      event_at,
      created_at
    )
    values (
      new.user_id,
      new.club_id,
      new.event_type,
      coalesce(new.xp_awarded, new.points_awarded, 0),
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
      coalesce(new.event_at, now()),
      coalesce(new.created_at, now())
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
  coalesce(x.xp_awarded, 0) as points_awarded,
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
  x.xp_awarded,
  x.event_at
from public.xp_events x;

drop trigger if exists trg_cool_events_write on public.cool_events;
create trigger trg_cool_events_write
instead of insert or update or delete on public.cool_events
for each row execute function public.cool_events_write();

create or replace view public.rs_fan_memberships
with (security_invoker = true) as
select *
from public.fan_memberships;

grant select on public.contribution_groups to anon, authenticated, service_role;
grant insert, update, delete on public.contribution_groups to authenticated, service_role;
grant select, insert, update, delete on public.cool_events to authenticated, service_role;
grant select on public.rs_fan_memberships to authenticated, service_role;

create or replace function public.populate_group_message_defaults() returns trigger
language plpgsql
set search_path to 'public'
as $$
declare
  v_sender_id uuid;
  v_alias text;
begin
  v_sender_id := coalesce(new.sender_id, auth.uid());
  if v_sender_id is null then
    raise exception 'Authentication is required to send group messages.';
  end if;

  new.sender_id := v_sender_id;

  if new.group_id is null then
    raise exception 'group_id is required.';
  end if;

  if new.club_id is null then
    select g.club_id
    into new.club_id
    from public.groups g
    where g.id = new.group_id;
  end if;

  if coalesce(new.alias, '') = '' then
    select coalesce(nullif(btrim(u.public_user_id), ''), substr(md5(v_sender_id::text || new.group_id::text), 1, 6))
    into v_alias
    from public.users u
    where u.id = v_sender_id;

    new.alias := coalesce(v_alias, substr(md5(v_sender_id::text || new.group_id::text), 1, 6));
  end if;

  new.updated_at := coalesce(new.updated_at, coalesce(new.created_at, now()));
  return new;
end;
$$;

create table if not exists public.group_messages (
  id uuid default gen_random_uuid() not null,
  group_id uuid not null,
  sender_id uuid,
  alias character(6),
  content text not null,
  created_at timestamp with time zone default now(),
  club_id bigint,
  updated_at timestamp with time zone default now() not null
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'group_messages_pkey'
      and conrelid = 'public.group_messages'::regclass
  ) then
    alter table public.group_messages
      add constraint group_messages_pkey primary key (id);
  end if;
end;
$$;

create index if not exists idx_group_messages_group on public.group_messages (group_id);
create index if not exists idx_group_messages_group_created on public.group_messages (group_id, created_at desc);

delete from public.group_members gm
where not exists (
  select 1
  from public.groups g
  where g.id = gm.group_id
);

update public.groups g
set member_count = coalesce(member_counts.cnt, 0),
    updated_at = now()
from (
  select gm.group_id, count(*)::integer as cnt
  from public.group_members gm
  group by gm.group_id
) member_counts
where g.id = member_counts.group_id;

update public.groups g
set member_count = 0,
    updated_at = now()
where not exists (
  select 1
  from public.group_members gm
  where gm.group_id = g.id
)
and coalesce(g.member_count, 0) <> 0;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'group_members_group_id_fkey'
      and conrelid = 'public.group_members'::regclass
  ) then
    alter table public.group_members
      add constraint group_members_group_id_fkey
      foreign key (group_id) references public.groups(id) on delete cascade;
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'group_messages_group_id_fkey'
      and conrelid = 'public.group_messages'::regclass
  ) then
    alter table public.group_messages
      add constraint group_messages_group_id_fkey
      foreign key (group_id) references public.groups(id) on delete cascade;
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'group_messages_sender_id_fkey'
      and conrelid = 'public.group_messages'::regclass
  ) then
    alter table public.group_messages
      add constraint group_messages_sender_id_fkey
      foreign key (sender_id) references auth.users(id) on delete set null;
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'group_messages_club_id_fkey'
      and conrelid = 'public.group_messages'::regclass
  ) then
    alter table public.group_messages
      add constraint group_messages_club_id_fkey
      foreign key (club_id) references public.african_football_clubs(id);
  end if;
end;
$$;

alter table public.group_messages enable row level security;

drop trigger if exists trg_group_messages_defaults on public.group_messages;
create trigger trg_group_messages_defaults
before insert or update on public.group_messages
for each row execute function public.populate_group_message_defaults();

drop trigger if exists trg_group_messages_updated on public.group_messages;
create trigger trg_group_messages_updated
before update on public.group_messages
for each row execute function public.set_updated_at();

drop policy if exists group_messages_insert_members on public.group_messages;
create policy group_messages_insert_members
on public.group_messages
for insert
to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1
    from public.groups g
    where g.id = group_messages.group_id
      and (g.club_id)::text = public.requesting_club_id()
      and coalesce(g.allow_chat, true) = true
      and public.is_group_member(group_messages.group_id)
  )
);

drop policy if exists group_messages_select_members on public.group_messages;
create policy group_messages_select_members
on public.group_messages
for select
to authenticated
using (
  exists (
    select 1
    from public.groups g
    where g.id = group_messages.group_id
      and (g.club_id)::text = public.requesting_club_id()
      and (
        public.is_group_member(group_messages.group_id)
        or g.creator_id = auth.uid()
        or public.is_club_admin(g.club_id)
      )
  )
);

drop policy if exists group_messages_update_author_or_admin on public.group_messages;
create policy group_messages_update_author_or_admin
on public.group_messages
for update
to authenticated
using (
  sender_id = auth.uid()
  or exists (
    select 1
    from public.groups g
    where g.id = group_messages.group_id
      and public.is_club_admin(g.club_id)
  )
)
with check (
  sender_id = auth.uid()
  or exists (
    select 1
    from public.groups g
    where g.id = group_messages.group_id
      and public.is_club_admin(g.club_id)
  )
);

drop policy if exists group_messages_delete_author_or_admin on public.group_messages;
create policy group_messages_delete_author_or_admin
on public.group_messages
for delete
to authenticated
using (
  sender_id = auth.uid()
  or exists (
    select 1
    from public.groups g
    where g.id = group_messages.group_id
      and public.is_club_admin(g.club_id)
  )
);

do $$
begin
  execute 'alter publication supabase_realtime add table public.group_messages';
exception
  when duplicate_object or undefined_object then
    null;
end;
$$;

grant select on public.group_messages to authenticated, service_role;
grant insert, update, delete on public.group_messages to authenticated, service_role;

drop policy if exists group_members_select_members on public.group_members;
create policy group_members_select_members
on public.group_members
for select
to authenticated
using (
  exists (
    select 1
    from public.groups g
    where g.id = group_members.group_id
      and (g.club_id)::text = public.requesting_club_id()
      and (
        public.is_group_member(group_members.group_id)
        or g.creator_id = auth.uid()
        or public.is_club_admin(g.club_id)
      )
  )
);

drop policy if exists admin_manage_articles on public.news_articles;
drop policy if exists admin_manage_products on public.shop_products;

drop policy if exists contribution_groups_admin_all on public.groups;
create policy contribution_groups_admin_all
on public.groups
for all
to authenticated
using (
  public.is_super_admin()
  or (
    club_id is not null
    and (club_id)::text = public.requesting_club_id()
    and public.is_club_admin(club_id)
  )
)
with check (
  public.is_super_admin()
  or (
    club_id is not null
    and (club_id)::text = public.requesting_club_id()
    and public.is_club_admin(club_id)
  )
);

drop policy if exists contribution_groups_public_read on public.groups;
create policy contribution_groups_public_read
on public.groups
for select
to anon
using (
  is_active = true
  and coalesce(privacy, visibility, 'private') = 'public'
);

drop policy if exists contribution_groups_select_club on public.groups;
drop policy if exists groups_select_public on public.groups;
create policy groups_select_public
on public.groups
for select
to authenticated
using (
  public.is_super_admin()
  or (
    (club_id)::text = public.requesting_club_id()
    and (
      public.is_club_admin(club_id)
      or creator_id = auth.uid()
      or public.is_group_member(id)
      or coalesce(privacy, visibility, 'private') = 'public'
    )
  )
);

create or replace function public.create_group_atomic(
  p_name text,
  p_description text default null::text,
  p_privacy text default 'private'::text,
  p_group_type text default 'community'::text,
  p_target_amount bigint default 0,
  p_currency text default null::text,
  p_cycle_days integer default 30,
  p_country_code text default null::text,
  p_monthly_contribution bigint default null::bigint,
  p_momo_number text default null::text,
  p_receiving_momo_code text default null::text,
  p_receiving_momo_route_type text default null::text,
  p_bank_partner_id uuid default null::uuid
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_user_id uuid := auth.uid();
  v_group public.groups;
  v_display_name text;
begin
  if v_user_id is null then
    return jsonb_build_object('status', 'error', 'message', 'Not authenticated.');
  end if;

  insert into public.groups (
    creator_id,
    name,
    description,
    group_type,
    privacy,
    target_amount,
    current_total,
    currency,
    country,
    cycle_days,
    monthly_contribution,
    contribution_amount,
    momo_number,
    receiving_momo_code,
    receiving_momo_route_type,
    bank_partner_id,
    amount
  )
  values (
    v_user_id,
    nullif(btrim(p_name), ''),
    nullif(btrim(coalesce(p_description, '')), ''),
    p_group_type,
    p_privacy,
    coalesce(p_target_amount, 0),
    0,
    coalesce(nullif(btrim(coalesce(p_currency, '')), ''), public.resolve_club_currency_code(nullif(public.requesting_club_id(), '')::bigint)),
    coalesce(nullif(btrim(coalesce(p_country_code, '')), ''), public.resolve_club_country_code(nullif(public.requesting_club_id(), '')::bigint)),
    greatest(coalesce(p_cycle_days, 30), 1),
    p_monthly_contribution,
    coalesce(p_monthly_contribution, 0),
    nullif(btrim(coalesce(p_momo_number, '')), ''),
    nullif(btrim(coalesce(p_receiving_momo_code, '')), ''),
    nullif(btrim(coalesce(p_receiving_momo_route_type, '')), ''),
    p_bank_partner_id::text,
    0
  )
  returning * into v_group;

  select coalesce(nullif(btrim(u.public_user_id), ''), substr(replace(v_user_id::text, '-', ''), 1, 6))
  into v_display_name
  from public.users u
  where u.id = v_user_id;

  insert into public.group_members (
    group_id,
    user_id,
    display_name,
    is_admin,
    is_anonymous,
    contribution_amount,
    joined_at
  )
  values (
    v_group.id,
    v_user_id,
    coalesce(v_display_name, '000000'),
    true,
    false,
    0,
    now()
  )
  on conflict (group_id, user_id)
  do update set
    is_admin = true,
    display_name = excluded.display_name;

  return jsonb_build_object(
    'status', 'success',
    'id', v_group.id,
    'group_id', v_group.id,
    'invite_code', v_group.invite_code
  );
exception
  when others then
    return jsonb_build_object('status', 'error', 'message', sqlerrm);
end;
$$;

create or replace function public.get_rayon_member_registry(
  p_partner_id uuid,
  p_search_query text default null::text,
  p_filter_tier text default null::text,
  p_region text default null::text,
  p_limit integer default 20,
  p_offset integer default 0
) returns table(
  user_id uuid,
  display_name text,
  membership_number text,
  points integer,
  tier text,
  chapter text,
  joined_at timestamp with time zone
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_search text := nullif(btrim(coalesce(p_search_query, '')), '');
  v_tier text := lower(nullif(btrim(coalesce(p_filter_tier, '')), ''));
  v_region text := nullif(btrim(coalesce(p_region, '')), '');
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.';
  end if;

  return query
  select
    membership.user_id,
    membership.display_name,
    membership.membership_number,
    membership.points,
    membership.tier,
    membership.chapter,
    membership.joined_at
  from public.fan_memberships membership
  where membership.partner_id = p_partner_id
    and (v_tier is null or lower(membership.tier) = v_tier)
    and (v_region is null or coalesce(membership.chapter, '') ilike '%' || v_region || '%')
    and (
      v_search is null
      or membership.display_name ilike '%' || v_search || '%'
      or membership.membership_number ilike '%' || v_search || '%'
    )
  order by membership.points desc, membership.joined_at asc, membership.membership_number asc
  limit greatest(coalesce(p_limit, 20), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

create or replace function public.rs_apply_membership_points(
  p_user_id uuid,
  p_partner_id uuid,
  p_points integer,
  p_chapter text default null::text
) returns public.fan_memberships
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_membership public.fan_memberships;
  v_chapter text := coalesce(nullif(btrim(coalesce(p_chapter, '')), ''), 'Central');
begin
  insert into public.fan_memberships (
    user_id,
    partner_id,
    display_name,
    points,
    chapter,
    membership_number,
    joined_at,
    created_at,
    updated_at
  )
  values (
    p_user_id,
    p_partner_id,
    public.rs_resolve_public_identity(p_user_id),
    greatest(coalesce(p_points, 0), 0),
    v_chapter,
    'FM-' || to_char(now(), 'YYYY') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)),
    now(),
    now(),
    now()
  )
  on conflict (user_id, partner_id)
  do update set
    points = greatest(public.fan_memberships.points + coalesce(p_points, 0), 0),
    display_name = public.rs_resolve_public_identity(excluded.user_id, public.fan_memberships.display_name),
    chapter = coalesce(nullif(btrim(public.fan_memberships.chapter), ''), excluded.chapter),
    updated_at = now()
  returning * into v_membership;

  return v_membership;
end;
$$;

create or replace function public.get_rs_fan_analytics() returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_result jsonb;
begin
  if not public.user_is_rayon_admin() then
    raise exception 'Unauthorized: Requires admin access';
  end if;

  select jsonb_build_object(
    'total_fans', (select count(*) from public.fan_memberships),
    'active_memberships', (select count(*) from public.fan_memberships),
    'total_tickets_sold', (
      select count(*) from public.rs_tickets
      where status in ('valid', 'used')
    ),
    'ticket_revenue', (
      select coalesce(sum(amount_paid), 0)
      from public.rs_tickets
      where status in ('valid', 'used')
    ),
    'total_initiatives', (select count(*) from public.rs_initiatives),
    'total_contributions', (
      select coalesce(sum(amount), 0)
      from public.rs_initiative_contributions
      where status = 'confirmed'
    ),
    'total_shop_revenue', (
      select coalesce(sum(total), 0)
      from public.rs_shop_orders
      where status in ('paid', 'confirmed', 'packed', 'fulfilled', 'delivered')
    ),
    'tier_breakdown', (
      select coalesce(jsonb_object_agg(tier, cnt), '{}'::jsonb)
      from (
        select tier, count(*) as cnt
        from public.fan_memberships
        group by tier
      ) t
    )
  )
  into v_result;

  return v_result;
end;
$$;

create or replace function public.activate_referral_invite_for_user(
  p_referral_invite_id uuid,
  p_invitee_id uuid,
  p_qualifying_event_type text,
  p_qualifying_event_id text,
  p_inviter_points integer default 0,
  p_invitee_points integer default 0
) returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  return false;
end;
$$;

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

drop policy if exists competitions_public_read on fantasy.competitions;
create policy competitions_public_read
on fantasy.competitions
for select
using (true);

drop policy if exists gameweeks_public_read on fantasy.gameweeks;
create policy gameweeks_public_read
on fantasy.gameweeks
for select
using (true);

drop policy if exists players_public_read on fantasy.players;
create policy players_public_read
on fantasy.players
for select
using (true);

drop policy if exists prices_public_read on fantasy.player_competition_prices;
create policy prices_public_read
on fantasy.player_competition_prices
for select
using (true);

drop policy if exists stats_public_read on fantasy.player_gameweek_stats;
create policy stats_public_read
on fantasy.player_gameweek_stats
for select
using (true);

drop policy if exists entry_owner_select on fantasy.fantasy_entries;
create policy entry_owner_select
on fantasy.fantasy_entries
for select
using (user_id = auth.uid());

drop policy if exists entry_owner_insert on fantasy.fantasy_entries;
create policy entry_owner_insert
on fantasy.fantasy_entries
for insert
with check (user_id = auth.uid());

drop policy if exists entry_owner_update on fantasy.fantasy_entries;
create policy entry_owner_update
on fantasy.fantasy_entries
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists squad_owner_all on fantasy.squad_selections;
create policy squad_owner_all
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

drop policy if exists scores_public_read on fantasy.entry_gameweek_scores;
create policy scores_public_read
on fantasy.entry_gameweek_scores
for select
using (true);

drop policy if exists scores_owner_write on fantasy.entry_gameweek_scores;
create policy scores_owner_write
on fantasy.entry_gameweek_scores
for insert
with check (
  entry_id in (
    select id
    from fantasy.fantasy_entries
    where user_id = auth.uid()
  )
);

drop policy if exists scores_owner_update on fantasy.entry_gameweek_scores;
create policy scores_owner_update
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

drop policy if exists scores_service_write on fantasy.entry_gameweek_scores;
create policy scores_service_write
on fantasy.entry_gameweek_scores
for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

drop policy if exists leagues_visible_to_members on fantasy.leagues;
create policy leagues_visible_to_members
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

drop policy if exists leagues_owner_insert on fantasy.leagues;
create policy leagues_owner_insert
on fantasy.leagues
for insert
with check (created_by = auth.uid());

drop policy if exists leagues_owner_update on fantasy.leagues;
create policy leagues_owner_update
on fantasy.leagues
for update
using (created_by = auth.uid())
with check (created_by = auth.uid());

drop policy if exists memberships_read on fantasy.league_memberships;
create policy memberships_read
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

drop policy if exists memberships_insert on fantasy.league_memberships;
create policy memberships_insert
on fantasy.league_memberships
for insert
with check (
  entry_id in (
    select id
    from fantasy.fantasy_entries
    where user_id = auth.uid()
  )
);

drop policy if exists transfers_owner_select on fantasy.transfer_history;
create policy transfers_owner_select
on fantasy.transfer_history
for select
using (
  entry_id in (
    select id
    from fantasy.fantasy_entries
    where user_id = auth.uid()
  )
);

drop policy if exists transfers_owner_insert on fantasy.transfer_history;
create policy transfers_owner_insert
on fantasy.transfer_history
for insert
with check (
  entry_id in (
    select id
    from fantasy.fantasy_entries
    where user_id = auth.uid()
  )
);

drop policy if exists club_app_config_public_read on public.club_app_config;
create policy club_app_config_public_read
on public.club_app_config
for select
using (true);

drop policy if exists club_app_config_admin_insert on public.club_app_config;
create policy club_app_config_admin_insert
on public.club_app_config
for insert
to authenticated
with check (public.is_admin_user());

drop policy if exists club_app_config_admin_update on public.club_app_config;
create policy club_app_config_admin_update
on public.club_app_config
for update
to authenticated
using (public.is_admin_user())
with check (public.is_admin_user());

drop policy if exists club_app_config_admin_delete on public.club_app_config;
create policy club_app_config_admin_delete
on public.club_app_config
for delete
to authenticated
using (public.is_admin_user());

drop policy if exists fantasy_enablements_public_read on public.fantasy_competition_enablements;
create policy fantasy_enablements_public_read
on public.fantasy_competition_enablements
for select
using (true);

drop policy if exists fantasy_enablements_admin_insert on public.fantasy_competition_enablements;
create policy fantasy_enablements_admin_insert
on public.fantasy_competition_enablements
for insert
to authenticated
with check (public.is_admin_user());

drop policy if exists fantasy_enablements_admin_update on public.fantasy_competition_enablements;
create policy fantasy_enablements_admin_update
on public.fantasy_competition_enablements
for update
to authenticated
using (public.is_admin_user())
with check (public.is_admin_user());

drop policy if exists fantasy_enablements_admin_delete on public.fantasy_competition_enablements;
create policy fantasy_enablements_admin_delete
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
grant select on fantasy.fantasy_entries to authenticated, service_role;
grant select on fantasy.entry_gameweek_scores to anon, authenticated, service_role;
grant select on fantasy.league_memberships to authenticated, service_role;
grant select on fantasy.leagues to authenticated, service_role;

grant execute on function public.create_group_atomic(
  text,
  text,
  text,
  text,
  bigint,
  text,
  integer,
  text,
  bigint,
  text,
  text,
  text,
  uuid
) to authenticated, service_role;

grant execute on function public.activate_referral_invite_for_user(
  uuid,
  uuid,
  text,
  text,
  integer,
  integer
) to service_role;

create or replace function public.fantasy_admin_club_competitions(
  p_club_id bigint
) returns table(
  id uuid,
  slug text,
  name text,
  short_name text,
  season text,
  description text,
  competition_type text,
  status text,
  primary_color text,
  logo_url text,
  country_code text,
  provider text,
  external_league_id integer,
  start_date timestamp with time zone,
  end_date timestamp with time zone,
  promo_title text,
  promo_body text,
  badge_label text,
  cta_label text,
  hero_image_url text,
  sort_order integer,
  is_visible boolean,
  is_featured boolean,
  is_playable boolean,
  entry_window_opens_at timestamp with time zone,
  entry_window_closes_at timestamp with time zone,
  active_entries bigint
)
language plpgsql
stable
security definer
set search_path to 'public', 'fantasy'
as $$
begin
  if not (public.is_super_admin() or public.is_club_admin(p_club_id) or public.is_admin_user()) then
    raise exception 'Admin privileges required';
  end if;

  return query
  with entry_counts as (
    select fe.competition_id, count(*)::bigint as active_entries
    from fantasy.fantasy_entries fe
    group by fe.competition_id
  )
  select
    c.id,
    c.slug,
    c.name,
    c.short_name,
    c.season,
    c.description,
    c.competition_type::text,
    c.status::text,
    c.primary_color,
    c.logo_url,
    c.country_code,
    c.provider::text,
    c.external_league_id,
    c.start_date,
    c.end_date,
    e.promo_title,
    e.promo_body,
    e.badge_label,
    e.cta_label,
    e.hero_image_url,
    e.sort_order,
    e.is_visible,
    e.is_featured,
    e.is_playable,
    e.entry_window_opens_at,
    e.entry_window_closes_at,
    coalesce(ec.active_entries, 0) as active_entries
  from fantasy.competitions c
  left join public.fantasy_competition_enablements e
    on e.competition_id = c.id
   and e.club_id = p_club_id
  left join entry_counts ec
    on ec.competition_id = c.id
  order by c.start_date asc, c.created_at asc;
end;
$$;

create or replace function public.fantasy_admin_operations_summary(
  p_competition_id uuid,
  p_club_id bigint default null::bigint
) returns table(
  competition_id uuid,
  league_count bigint,
  head_to_head_fixture_count bigint,
  injury_count bigint,
  notification_topic text,
  next_deadline_at timestamp with time zone
)
language plpgsql
stable
security definer
set search_path to 'public', 'fantasy'
as $$
declare
  v_club_id bigint := coalesce(p_club_id, nullif(public.requesting_club_id(), '')::bigint);
begin
  if v_club_id is not null and not (public.is_super_admin() or public.is_club_admin(v_club_id) or public.is_admin_user()) then
    raise exception 'Admin privileges required';
  end if;

  return query
  with leagues as (
    select l.id
    from fantasy.leagues l
    where l.competition_id = p_competition_id
  ),
  gameweek_deadlines as (
    select g.deadline_at
    from fantasy.gameweeks g
    where g.competition_id = p_competition_id
      and g.status in ('upcoming', 'live', 'scoring')
    order by
      case g.status
        when 'live' then 0
        when 'scoring' then 1
        else 2
      end,
      g.number asc
    limit 1
  )
  select
    c.id as competition_id,
    (select count(*)::bigint from leagues) as league_count,
    (
      select count(*)::bigint
      from fantasy.league_h2h_fixtures lhf
      where lhf.league_id in (select id from leagues)
    ) as head_to_head_fixture_count,
    (
      select count(*)::bigint
      from fantasy.fixture_injuries fi
      where fi.competition_id = p_competition_id
    ) as injury_count,
    fantasy.topic_for_competition(c.id) as notification_topic,
    (select deadline_at from gameweek_deadlines) as next_deadline_at
  from fantasy.competitions c
  where c.id = p_competition_id;
end;
$$;

grant execute on function public.fantasy_admin_club_competitions(bigint) to authenticated, service_role;
grant execute on function public.fantasy_admin_operations_summary(uuid, bigint) to authenticated, service_role;

commit;
