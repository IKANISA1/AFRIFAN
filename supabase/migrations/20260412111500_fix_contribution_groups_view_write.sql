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
begin
  if v_actor_id is null then
    raise exception 'Authentication is required.';
  end if;

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
    ) then
      raise exception 'Only platform or club admins can delete public initiatives.';
    end if;

    delete from public.groups where id = old.id;
    return old;
  end if;

  if tg_op = 'UPDATE' then
    select g.*
    into v_group
    from public.groups g
    where g.id = old.id;

    if not found then
      raise exception 'Contribution initiative not found.';
    end if;

    if not (
      public.is_super_admin()
      or public.is_club_admin(v_group.club_id)
    ) then
      raise exception 'Only platform or club admins can update public initiatives.';
    end if;

    if new.club_id is not null
       and new.club_id <> v_group.club_id
       and not public.is_super_admin() then
      raise exception 'Contribution initiatives cannot be moved across clubs.';
    end if;

    update public.groups
    set
      creator_id = coalesce(new.creator_id, v_group.creator_id),
      name = new.name,
      description = nullif(btrim(coalesce(new.description, '')), ''),
      group_type = coalesce(new.group_type, v_group.group_type, v_group.type, 'community'),
      target_amount = coalesce(new.target_amount, 0),
      current_total = coalesce(new.current_total, new.amount, v_group.current_total, v_group.amount, 0),
      momo_code = coalesce(
        nullif(btrim(coalesce(new.receiving_momo_code, '')), ''),
        nullif(btrim(coalesce(new.momo_recipient_code, '')), ''),
        nullif(btrim(coalesce(new.momo_number, '')), ''),
        v_group.momo_code
      ),
      deadline = new.deadline,
      is_recurring = coalesce(new.is_recurring, false),
      is_closed = coalesce(new.is_closed, false),
      member_count = greatest(coalesce(new.member_count, v_group.member_count, 0), 0),
      club_id = coalesce(new.club_id, v_group.club_id),
      partner_id = coalesce(new.partner_id, v_group.partner_id),
      currency = coalesce(nullif(btrim(coalesce(new.currency, '')), ''), v_group.currency),
      updated_at = now(),
      is_active = coalesce(new.is_active, coalesce(new.is_closed, false) = false),
      country = coalesce(nullif(btrim(coalesce(new.country, '')), ''), v_group.country),
      visibility = 'public',
      type = case
        when lower(coalesce(new.group_type, v_group.group_type, v_group.type, 'community')) in ('project', 'club', 'team_project')
          then 'project'
        else 'community'
      end,
      amount = coalesce(new.amount, new.current_total, v_group.amount, v_group.current_total, 0)::integer,
      monthly_contribution = coalesce(new.monthly_contribution, new.contribution_amount, v_group.monthly_contribution),
      bank_partner_id = coalesce(new.bank_partner_id, v_group.bank_partner_id),
      momo_number = coalesce(new.momo_number, v_group.momo_number),
      frequency = coalesce(new.frequency, v_group.frequency),
      receiving_momo_route_type = coalesce(new.receiving_momo_route_type, new.momo_route_type, v_group.receiving_momo_route_type),
      receiving_momo_code = coalesce(new.receiving_momo_code, new.momo_recipient_code, v_group.receiving_momo_code),
      cycle_days = coalesce(new.cycle_days, v_group.cycle_days, 30),
      contribution_amount = coalesce(new.contribution_amount, new.monthly_contribution, v_group.contribution_amount, 0)
    where id = old.id
    returning id into v_group_id;
  else
    if coalesce(new.club_id, v_requesting_club_id) is null then
      raise exception 'A club scope is required to create a contribution initiative.';
    end if;

    if not (
      public.is_super_admin()
      or public.is_club_admin(coalesce(new.club_id, v_requesting_club_id))
    ) then
      raise exception 'Only platform or club admins can create public initiatives.';
    end if;

    insert into public.groups (
      creator_id,
      name,
      description,
      group_type,
      target_amount,
      current_total,
      momo_code,
      deadline,
      is_recurring,
      is_closed,
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
      contribution_amount
    )
    values (
      coalesce(new.creator_id, v_actor_id),
      new.name,
      nullif(btrim(coalesce(new.description, '')), ''),
      coalesce(new.group_type, 'community'),
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
      greatest(coalesce(new.member_count, 0), 0),
      coalesce(new.club_id, v_requesting_club_id),
      new.partner_id,
      nullif(btrim(coalesce(new.currency, '')), ''),
      coalesce(new.is_active, coalesce(new.is_closed, false) = false),
      nullif(btrim(coalesce(new.country, '')), ''),
      'public',
      case
        when lower(coalesce(new.group_type, 'community')) in ('project', 'club', 'team_project')
          then 'project'
        else 'community'
      end,
      coalesce(new.amount, new.current_total, 0)::integer,
      coalesce(new.monthly_contribution, new.contribution_amount),
      new.bank_partner_id,
      nullif(btrim(coalesce(new.momo_number, '')), ''),
      nullif(btrim(coalesce(new.frequency, '')), ''),
      coalesce(new.receiving_momo_route_type, new.momo_route_type),
      coalesce(new.receiving_momo_code, new.momo_recipient_code),
      coalesce(new.cycle_days, 30),
      coalesce(new.contribution_amount, new.monthly_contribution, 0)
    )
    returning id into v_group_id;
  end if;

  select *
  into v_result
  from public.contribution_groups
  where id = v_group_id;

  new := v_result;
  return new;
end;
$$;
