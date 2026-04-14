create or replace function public.add_fan_points(
  p_user_id uuid,
  p_partner_id text,
  p_points integer,
  p_reason text default null::text
) returns public.fan_memberships
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_club_id bigint;
  v_membership public.fan_memberships;
  v_points integer := greatest(coalesce(p_points, 0), 0);
  v_reason text := coalesce(nullif(trim(coalesce(p_reason, '')), ''), 'manual_adjustment');
begin
  v_club_id := coalesce(
    public.compat_parse_partner_id(p_partner_id),
    nullif(public.requesting_club_id(), '')::bigint
  );

  if v_club_id is null then
    raise exception 'Club context required for fan points.';
  end if;

  insert into public.fan_memberships (
    user_id,
    club_id,
    partner_id,
    points,
    tier
  )
  values (
    p_user_id,
    v_club_id,
    public.fet_wallet_resolve_partner_id(v_club_id, p_partner_id),
    v_points,
    public.resolve_fan_tier(v_points)
  )
  on conflict (user_id, club_id)
  do update set
    points = public.fan_memberships.points + v_points,
    tier = public.resolve_fan_tier(public.fan_memberships.points + v_points),
    renewed_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  returning * into v_membership;

  insert into public.xp_events (
    user_id,
    club_id,
    event_type,
    xp_awarded,
    metadata,
    event_at
  )
  values (
    p_user_id,
    v_club_id,
    v_reason,
    v_points,
    jsonb_build_object(
      'reason',
      p_reason,
      'source',
      'add_fan_points',
      'source_table',
      'cool_events'
    ),
    timezone('utc', now())
  );

  if v_points > 0 then
    perform public.fet_wallet_append_entry(
      p_club_id := v_club_id,
      p_user_id := p_user_id,
      p_membership_id := v_membership.id,
      p_entry_type := 'earn',
      p_direction := 'credit',
      p_amount := v_points,
      p_balance_after := v_membership.points,
      p_counterparty_user_id := null,
      p_reference_type := 'cool_event',
      p_reference_id := v_reason,
      p_idempotency_key := null,
      p_note := v_reason,
      p_metadata := jsonb_build_object('reason', p_reason, 'source', 'add_fan_points'),
      p_created_by := auth.uid()
    );
  end if;

  return v_membership;
end;
$$;

create or replace function public.fet_admin_adjust_balance(
  p_user_id uuid,
  p_amount integer,
  p_reason text,
  p_idempotency_key text default null,
  p_club_id bigint default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_caller_id uuid := auth.uid();
  v_club_id bigint;
  v_membership public.fan_memberships;
  v_existing public.fet_wallet_ledger_entries;
  v_amount integer := coalesce(p_amount, 0);
  v_abs_amount integer := abs(coalesce(p_amount, 0));
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_idempotency_key text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
  v_direction text;
  v_reference_id text := gen_random_uuid()::text;
begin
  if v_caller_id is null then
    raise exception 'Authentication is required.';
  end if;

  v_club_id := public.fet_require_club_context(p_club_id);

  if not (public.is_club_admin(v_club_id) or public.is_super_admin()) then
    raise exception 'Club admin access is required.';
  end if;

  if p_user_id is null then
    raise exception 'A target user is required.';
  end if;

  if v_reason is null then
    raise exception 'Adjustment reason is required.';
  end if;

  if v_abs_amount = 0 then
    raise exception 'Adjustment amount must be non-zero.';
  end if;

  if v_idempotency_key is not null then
    select *
      into v_existing
      from public.fet_wallet_ledger_entries e
     where e.club_id = v_club_id
       and e.user_id = p_user_id
       and e.idempotency_key = v_idempotency_key
       and e.entry_type = 'admin_adjustment'
     order by e.created_at desc, e.id desc
     limit 1;

    if v_existing.id is not null then
      return jsonb_build_object(
        'status', 'success',
        'already_processed', true,
        'amount', case when v_existing.direction = 'debit' then -v_existing.amount else v_existing.amount end,
        'balance', v_existing.balance_after,
        'reference_id', v_existing.reference_id
      );
    end if;
  end if;

  perform public.fet_wallet_ensure_membership(p_user_id, v_club_id);

  select *
    into v_membership
    from public.fan_memberships
   where user_id = p_user_id
     and club_id = v_club_id
   for update;

  if v_amount < 0 and coalesce(v_membership.points, 0) < v_abs_amount then
    raise exception 'Adjustment would overdraw the supporter wallet.';
  end if;

  if v_amount > 0 then
    update public.fan_memberships
       set points = points + v_abs_amount,
           tier = public.resolve_fan_tier(points + v_abs_amount),
           renewed_at = timezone('utc', now()),
           updated_at = timezone('utc', now())
     where id = v_membership.id
    returning * into v_membership;
    v_direction := 'credit';

    insert into public.xp_events (
      user_id,
      club_id,
      event_type,
      xp_awarded,
      metadata,
      event_at
    )
    values (
      p_user_id,
      v_club_id,
      'admin_adjustment',
      v_abs_amount,
      jsonb_build_object(
        'reason',
        v_reason,
        'source',
        'fet_admin_adjust_balance',
        'source_table',
        'cool_events'
      ),
      timezone('utc', now())
    );
  else
    update public.fan_memberships
       set points = points - v_abs_amount,
           tier = public.resolve_fan_tier(points - v_abs_amount),
           updated_at = timezone('utc', now())
     where id = v_membership.id
    returning * into v_membership;
    v_direction := 'debit';
  end if;

  perform public.fet_wallet_append_entry(
    p_club_id := v_club_id,
    p_user_id := p_user_id,
    p_membership_id := v_membership.id,
    p_entry_type := 'admin_adjustment',
    p_direction := v_direction,
    p_amount := v_abs_amount,
    p_balance_after := v_membership.points,
    p_counterparty_user_id := null,
    p_reference_type := 'admin_adjustment',
    p_reference_id := v_reference_id,
    p_idempotency_key := v_idempotency_key,
    p_note := v_reason,
    p_metadata := jsonb_build_object('requested_amount', v_amount),
    p_created_by := v_caller_id
  );

  return jsonb_build_object(
    'status', 'success',
    'amount', v_amount,
    'balance', v_membership.points,
    'reference_id', v_reference_id
  );
end;
$$;
