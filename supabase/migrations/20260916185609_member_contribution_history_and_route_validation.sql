-- Keep complete confirmed totals independent of the visible history page.
-- The caller's ACLs and row policies remain in force; no tenant/user input exists.
create or replace function public.member_contribution_history(
  p_before_created_at timestamptz default null,
  p_before_id uuid default null
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_club_id bigint;
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication is required.';
  end if;
  begin
    v_club_id := nullif(public.requesting_club_id(), '')::bigint;
  exception when invalid_text_representation then
    raise exception using errcode = '42501', message = 'A trusted club scope is required.';
  end;
  if v_club_id is null then
    raise exception using errcode = '42501', message = 'A trusted club scope is required.';
  end if;
  if (p_before_created_at is null) <> (p_before_id is null) then
    raise exception using errcode = '22023', message = 'Both history cursor fields are required.';
  end if;

  with scoped as materialized (
    select id, initiative_id, amount, status, momo_reference, created_at, confirmed_at
    from public.initiative_contributions
    where user_id = v_user_id and club_id = v_club_id
  ), candidates as (
    select * from scoped
    where p_before_created_at is null
       or (created_at, id) < (p_before_created_at, p_before_id)
    order by created_at desc, id desc
    limit 21
  ), page as (
    select * from candidates order by created_at desc, id desc limit 20
  )
  select jsonb_build_object(
    -- A decimal string preserves exact bigint totals through JSON/JavaScript.
    'confirmed_total', (select coalesce(sum(amount) filter (where status = 'confirmed'), 0)::text from scoped),
    'entries', (select coalesce(jsonb_agg(to_jsonb(page) order by created_at desc, id desc), '[]'::jsonb) from page),
    'next_cursor', case when (select count(*) from candidates) > 20 then
      (select jsonb_build_object('created_at', created_at, 'id', id) from page order by created_at, id limit 1)
      else null end
  ) into v_result;
  return v_result;
end;
$$;
revoke all on function public.member_contribution_history(timestamptz, uuid) from public, anon, service_role;
grant execute on function public.member_contribution_history(timestamptz, uuid) to authenticated;
comment on function public.member_contribution_history(timestamptz, uuid) is
  'Own-club supporter history with a complete confirmed total and bounded keyset pages; respects caller ACLs and RLS.';

-- Preserve pending-intent semantics and serialized retries. Require a literal
-- leading asterisk; the earlier double escape also admitted routes without it.
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

  if v_ussd !~ '^[*][0-9*]+#$' then
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
