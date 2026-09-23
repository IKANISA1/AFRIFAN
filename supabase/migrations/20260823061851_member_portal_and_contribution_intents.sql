-- Member-facing web portal for Gikundiro.
--
-- This migration deliberately keeps payment finality outside the browser:
-- the web app creates a pending contribution intent and opens the official
-- database-configured MoMo route. Existing SMS/provider reconciliation is the
-- only path that may move a contribution to `confirmed`.

alter table public.fan_memberships
  add column if not exists member_code text;

create or replace function public.generate_unique_member_code()
returns text
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  candidate text;
begin
  for attempt in 1..64 loop
    candidate := lpad(
      (
        100000 + mod(
          abs(hashtextextended(gen_random_uuid()::text, attempt)::numeric),
          900000
        )
      )::text,
      6,
      '0'
    );

    exit when not exists (
      select 1
      from public.fan_memberships membership
      where membership.member_code = candidate
    );
  end loop;

  if candidate is null or exists (
    select 1
    from public.fan_memberships membership
    where membership.member_code = candidate
  ) then
    raise exception 'Could not allocate a unique member code.';
  end if;

  return candidate;
end;
$$;

revoke all on function public.generate_unique_member_code() from public;
revoke all on function public.generate_unique_member_code() from anon;
revoke all on function public.generate_unique_member_code() from authenticated;

do $$
declare
  membership_row record;
begin
  for membership_row in
    select id
    from public.fan_memberships
    where member_code is null or member_code !~ '^[0-9]{6}$'
    order by created_at, id
  loop
    update public.fan_memberships
       set member_code = public.generate_unique_member_code()
     where id = membership_row.id;
  end loop;
end;
$$;

alter table public.fan_memberships
  alter column member_code set not null;

alter table public.fan_memberships
  drop constraint if exists fan_memberships_member_code_format_check;

alter table public.fan_memberships
  add constraint fan_memberships_member_code_format_check
  check (member_code ~ '^[0-9]{6}$');

create unique index if not exists fan_memberships_member_code_key
  on public.fan_memberships (member_code);

create or replace function public.rs_sync_membership_fields()
returns trigger
language plpgsql
set search_path to 'public'
as $$
declare
  v_explicit_tier text := lower(btrim(coalesce(new.tier, '')));
begin
  new.points := greatest(coalesce(new.points, 0), 0);

  if v_explicit_tier in (
    'fan',
    'bronze',
    'silver',
    'gold',
    'platinum',
    'imena',
    'inyamibwa',
    'ingenzi-imanzi'
  ) then
    new.tier := v_explicit_tier;
  else
    new.tier := case
      when new.points >= 5000 then 'platinum'
      when new.points >= 2000 then 'gold'
      when new.points >= 1000 then 'bronze'
      else 'fan'
    end;
  end if;

  new.chapter := coalesce(
    nullif(btrim(coalesce(new.chapter, '')), ''),
    'Kigali Central'
  );
  new.display_name := public.rs_resolve_public_identity(
    new.user_id,
    new.display_name
  );

  if coalesce(nullif(btrim(coalesce(new.membership_number, '')), ''), '') = '' then
    new.membership_number := 'RS-' ||
      to_char(coalesce(new.joined_at, now()), 'YYYY') ||
      '-' ||
      upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
  end if;

  if coalesce(nullif(btrim(coalesce(new.member_code, '')), ''), '') = '' then
    new.member_code := public.generate_unique_member_code();
  end if;

  if tg_op = 'INSERT' then
    new.created_at := coalesce(new.created_at, now());
    new.joined_at := coalesce(new.joined_at, new.created_at, now());
  end if;

  new.updated_at := now();
  return new;
end;
$$;

grant select (member_code) on table public.fan_memberships to authenticated;

create or replace view public.rs_fan_memberships
with (security_invoker = true)
as
select
  id,
  user_id,
  partner_id,
  tier,
  points,
  joined_at,
  chapter,
  membership_number,
  created_at,
  updated_at,
  is_mock,
  mock_batch,
  display_name,
  expires_at,
  club_id,
  renewed_at,
  payment_status,
  member_code,
  status
from public.fan_memberships;

grant select on table public.rs_fan_memberships to authenticated;

grant select (
  id,
  momo_reference,
  confirmed_at,
  updated_at
) on table public.initiative_contributions to authenticated;

create or replace function public.create_member_contribution_intent(
  p_initiative_id uuid,
  p_amount integer
)
returns table (
  contribution_id uuid,
  amount integer,
  status text,
  momo_reference text,
  created_at timestamptz,
  ussd_code text
)
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_club_id bigint;
  v_membership public.fan_memberships;
  v_initiative public.initiatives;
  v_partner public.partners;
  v_template text;
  v_reference text;
  v_ussd text;
  v_contribution public.initiative_contributions;
begin
  if v_actor_id is null then
    raise exception 'Authentication is required.';
  end if;

  if p_amount is null or p_amount < 100 or p_amount > 5000000 then
    raise exception 'Contribution amount must be between 100 and 5,000,000 RWF.';
  end if;

  begin
    v_club_id := nullif(public.requesting_club_id(), '')::bigint;
  exception
    when invalid_text_representation then
      raise exception 'A valid trusted club scope is required.';
  end;

  if v_club_id is null then
    raise exception 'A trusted club scope is required.';
  end if;

  -- Serialize contribution-intent creation per supporter. This makes the
  -- recent-pending reuse below safe across impatient double taps and retries.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_actor_id::text, 0)
  );

  select membership.*
    into v_membership
    from public.fan_memberships membership
   where membership.user_id = v_actor_id
     and membership.club_id = v_club_id
     and membership.status = 'active'
   order by membership.updated_at desc, membership.id
   limit 1;

  if v_membership.id is null then
    raise exception 'An active Gikundiro membership is required.';
  end if;

  select initiative.*
    into v_initiative
    from public.initiatives initiative
   where initiative.id = p_initiative_id
     and initiative.club_id = v_membership.club_id
     and initiative.is_active is true
     and initiative.status = 'active'
     and (initiative.ends_at is null or initiative.ends_at > now())
   for share;

  if v_initiative.id is null then
    raise exception 'The selected club initiative is not accepting contributions.';
  end if;

  select partner.*
    into v_partner
    from public.partners partner
   where partner.id = v_membership.partner_id
     and partner.is_active is true
   limit 1;

  select nullif(btrim(club.momo_ussd_template), '')
    into v_template
    from public.african_football_clubs club
   where club.id = v_membership.club_id
     and club.is_active is true
   limit 1;

  if v_template is null or nullif(btrim(v_partner.momo_code), '') is null then
    raise exception 'The official Rayon Sports MoMo route is not configured.';
  end if;

  v_reference := 'GKD-' || to_char(now(), 'YYYYMMDD') || '-' ||
    upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
  v_ussd := replace(
    replace(v_template, '{amount}', p_amount::text),
    '{momo}',
    btrim(v_partner.momo_code)
  );

  if v_ussd !~ '^\\*[0-9*]+#$' then
    raise exception 'The official Rayon Sports MoMo route is invalid.';
  end if;

  select contribution.*
    into v_contribution
    from public.initiative_contributions contribution
   where contribution.user_id = v_actor_id
     and contribution.initiative_id = v_initiative.id
     and contribution.amount = p_amount
     and contribution.status = 'pending'
     and contribution.created_at > now() - interval '15 minutes'
   order by contribution.created_at desc, contribution.id
   limit 1;

  if v_contribution.id is not null then
    return query
    select
      v_contribution.id,
      v_contribution.amount,
      v_contribution.status,
      v_contribution.momo_reference,
      v_contribution.created_at,
      v_ussd;
    return;
  end if;

  if (
    select count(*)
      from public.initiative_contributions contribution
     where contribution.user_id = v_actor_id
       and contribution.created_at > now() - interval '1 hour'
  ) >= 12 then
    raise exception 'Too many contribution attempts. Try again later.';
  end if;

  insert into public.initiative_contributions (
    initiative_id,
    user_id,
    amount,
    momo_reference,
    status,
    club_id,
    supporter_name
  ) values (
    v_initiative.id,
    v_actor_id,
    p_amount,
    v_reference,
    'pending',
    v_membership.club_id,
    v_membership.member_code
  )
  returning * into v_contribution;

  return query
  select
    v_contribution.id,
    v_contribution.amount,
    v_contribution.status,
    v_contribution.momo_reference,
    v_contribution.created_at,
    v_ussd;
end;
$$;

revoke all on function public.create_member_contribution_intent(uuid, integer)
  from public;
revoke all on function public.create_member_contribution_intent(uuid, integer)
  from anon;
grant execute on function public.create_member_contribution_intent(uuid, integer)
  to authenticated;

comment on function public.create_member_contribution_intent(uuid, integer) is
  'Creates a pending member contribution and returns the official configured MoMo USSD route. Payment confirmation remains provider/SMS governed.';
