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
