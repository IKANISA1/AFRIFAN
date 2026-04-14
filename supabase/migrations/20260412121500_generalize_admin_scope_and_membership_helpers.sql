begin;

create or replace function public.resolve_partner_ids_for_club(
  p_club_id bigint
) returns uuid[]
language sql
stable
security definer
set search_path to 'public'
as $$
  with partner_sources as (
    select ppr.partner_id
    from public.partner_payment_routes ppr
    where ppr.club_id = p_club_id
      and ppr.partner_id is not null
    union
    select i.partner_id
    from public.initiatives i
    where i.club_id = p_club_id
      and i.partner_id is not null
    union
    select m.partner_id
    from public.matches m
    where m.club_id = p_club_id
      and m.partner_id is not null
    union
    select mp.partner_id
    from public.membership_packages mp
    where mp.club_id = p_club_id
      and mp.partner_id is not null
    union
    select sp.partner_id
    from public.shop_products sp
    where sp.club_id = p_club_id
      and sp.partner_id is not null
    union
    select so.partner_id
    from public.shop_orders so
    where so.club_id = p_club_id
      and so.partner_id is not null
  )
  select coalesce(
    array_agg(distinct partner_id) filter (where partner_id is not null),
    '{}'::uuid[]
  )
  from partner_sources;
$$;

create or replace function public.is_partner_admin(
  p_partner_id uuid
) returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  with scoped_clubs as (
    select distinct ppr.club_id
    from public.partner_payment_routes ppr
    where ppr.partner_id = p_partner_id
      and ppr.club_id is not null
    union
    select distinct i.club_id
    from public.initiatives i
    where i.partner_id = p_partner_id
      and i.club_id is not null
    union
    select distinct m.club_id
    from public.matches m
    where m.partner_id = p_partner_id
      and m.club_id is not null
    union
    select distinct mp.club_id
    from public.membership_packages mp
    where mp.partner_id = p_partner_id
      and mp.club_id is not null
    union
    select distinct sp.club_id
    from public.shop_products sp
    where sp.partner_id = p_partner_id
      and sp.club_id is not null
    union
    select distinct so.club_id
    from public.shop_orders so
    where so.partner_id = p_partner_id
      and so.club_id is not null
  )
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
        or (
          ara.role in ('club_admin', 'club_moderator')
          and ara.club_id in (select club_id from scoped_clubs)
        )
      )
  ) or exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.is_admin = true
  );
$$;

create or replace function public.rs_is_partner_admin(
  p_partner_id uuid
) returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select public.is_partner_admin(p_partner_id);
$$;

create or replace function public.user_has_admin_workspace_access(
  p_club_id bigint default null::bigint,
  p_partner_id uuid default null::uuid
) returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    public.is_admin_user()
    or (p_club_id is not null and public.is_club_admin(p_club_id))
    or (p_partner_id is not null and public.is_partner_admin(p_partner_id));
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
        and ara.role in (
          'partner',
          'rayon_sport',
          'club_admin',
          'club_moderator',
          'bank'
        )
    );
$$;

create or replace function public.assign_admin_role(
  p_target_user_id uuid,
  p_role text,
  p_club_id bigint,
  p_partner_scope_id uuid default null::uuid,
  p_notes text default null::text
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_caller_id uuid := auth.uid();
  v_assignment_id uuid;
  v_role text;
  v_club_id bigint := p_club_id;
begin
  if not exists (
    select 1
    from public.users u
    where u.id = v_caller_id
      and u.is_admin = true
  ) then
    raise exception 'Only platform admins can assign admin roles.';
  end if;

  v_role := case lower(btrim(coalesce(p_role, '')))
    when 'admin' then 'admin'
    when 'super_admin' then 'super_admin'
    when 'bank' then 'bank'
    when 'partner' then 'partner'
    when 'rayon_sport' then 'partner'
    when 'rayon-sport' then 'partner'
    when 'club_admin' then 'club_admin'
    when 'club_moderator' then 'club_moderator'
    else null
  end;

  if v_role is null then
    raise exception
      'Invalid role: %. Must be super_admin, admin, bank, partner, club_admin, or club_moderator.',
      p_role;
  end if;

  if v_role in ('admin', 'super_admin') then
    if p_partner_scope_id is not null or v_club_id is not null then
      raise exception 'Platform roles cannot be scoped to a club or partner.';
    end if;
  elsif v_role in ('bank', 'partner') then
    if p_partner_scope_id is null then
      raise exception 'Partner scope is required for % role.', v_role;
    end if;
    v_club_id := coalesce(v_club_id, public.compat_parse_partner_id(p_partner_scope_id));
  else
    if v_club_id is null then
      raise exception 'Club scope is required for % role.', v_role;
    end if;
  end if;

  insert into public.admin_role_assignments (
    user_id,
    role,
    partner_scope_id,
    club_id,
    granted_by,
    granted_at,
    is_active,
    notes
  )
  values (
    p_target_user_id,
    v_role,
    p_partner_scope_id,
    v_club_id,
    v_caller_id,
    now(),
    true,
    p_notes
  )
  on conflict (user_id, role, partner_scope_id)
  do update set
    club_id = excluded.club_id,
    is_active = true,
    granted_by = v_caller_id,
    granted_at = now(),
    revoked_at = null,
    notes = coalesce(p_notes, public.admin_role_assignments.notes)
  returning id into v_assignment_id;

  return jsonb_build_object(
    'status', 'assigned',
    'assignment_id', v_assignment_id,
    'role', v_role,
    'user_id', p_target_user_id,
    'club_id', v_club_id,
    'partner_scope_id', p_partner_scope_id
  );
end;
$$;

create or replace function public.assign_admin_role(
  p_target_user_id uuid,
  p_role text,
  p_partner_scope_id uuid default null::uuid,
  p_notes text default null::text
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  return public.assign_admin_role(
    p_target_user_id,
    p_role,
    public.compat_parse_partner_id(p_partner_scope_id),
    p_partner_scope_id,
    p_notes
  );
end;
$$;

create or replace function public.get_partner_member_registry(
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

  if not (public.is_partner_admin(p_partner_id) or public.is_admin_user()) then
    raise exception 'Unauthorized: Requires partner or platform admin access.';
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

create or replace function public.get_club_member_registry(
  p_club_id bigint,
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
  v_partner_ids uuid[] := public.resolve_partner_ids_for_club(p_club_id);
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.';
  end if;

  if not (public.is_super_admin() or public.is_club_admin(p_club_id) or public.is_admin_user()) then
    raise exception 'Unauthorized: Requires club or platform admin access.';
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
  where coalesce(array_length(v_partner_ids, 1), 0) > 0
    and membership.partner_id = any(v_partner_ids)
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
begin
  return query
  select *
  from public.get_partner_member_registry(
    p_partner_id,
    p_search_query,
    p_filter_tier,
    p_region,
    p_limit,
    p_offset
  );
end;
$$;

create or replace function public.apply_membership_points(
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
begin
  return public.apply_membership_points(
    p_user_id,
    p_partner_id,
    p_points,
    p_chapter
  );
end;
$$;

create or replace function public.get_club_fan_analytics(
  p_club_id bigint default null::bigint
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_club_id bigint := coalesce(p_club_id, nullif(public.requesting_club_id(), '')::bigint);
  v_partner_ids uuid[] := '{}'::uuid[];
  v_result jsonb;
begin
  if v_club_id is null then
    raise exception 'Club scope is required.';
  end if;

  if not (public.is_super_admin() or public.is_club_admin(v_club_id) or public.is_admin_user()) then
    raise exception 'Unauthorized: Requires club or platform admin access.';
  end if;

  v_partner_ids := public.resolve_partner_ids_for_club(v_club_id);

  select jsonb_build_object(
    'club_id', v_club_id,
    'partner_ids', to_jsonb(v_partner_ids),
    'total_fans', (
      select count(*)
      from public.fan_memberships fm
      where coalesce(array_length(v_partner_ids, 1), 0) > 0
        and fm.partner_id = any(v_partner_ids)
    ),
    'active_memberships', (
      select count(*)
      from public.fan_memberships fm
      where coalesce(array_length(v_partner_ids, 1), 0) > 0
        and fm.partner_id = any(v_partner_ids)
    ),
    'total_tickets_sold', (
      select count(*)
      from public.tickets t
      where t.club_id = v_club_id
        and t.status in ('valid', 'used')
    ),
    'ticket_revenue', (
      select coalesce(sum(t.amount_paid), 0)
      from public.tickets t
      where t.club_id = v_club_id
        and t.status in ('valid', 'used')
    ),
    'total_initiatives', (
      select count(*)
      from public.initiatives i
      where i.club_id = v_club_id
    ),
    'total_contributions', (
      select coalesce(sum(ic.amount), 0)
      from public.initiative_contributions ic
      where ic.club_id = v_club_id
        and ic.status = 'confirmed'
    ),
    'total_shop_revenue', (
      select coalesce(sum(so.total), 0)
      from public.shop_orders so
      where so.club_id = v_club_id
        and so.status in ('paid', 'confirmed', 'packed', 'fulfilled', 'delivered')
    ),
    'tier_breakdown', (
      select coalesce(jsonb_object_agg(tier, cnt), '{}'::jsonb)
      from (
        select fm.tier, count(*) as cnt
        from public.fan_memberships fm
        where coalesce(array_length(v_partner_ids, 1), 0) > 0
          and fm.partner_id = any(v_partner_ids)
        group by fm.tier
      ) t
    )
  )
  into v_result;

  return v_result;
end;
$$;

create or replace function public.get_rs_fan_analytics() returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  return public.get_club_fan_analytics(nullif(public.requesting_club_id(), '')::bigint);
end;
$$;

create or replace function public.get_admin_access_for_user(
  p_user_id uuid default null::uuid
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_user_id uuid := coalesce(p_user_id, auth.uid());
  v_is_platform_admin boolean := false;
  v_has_partner boolean := false;
  v_role_rows jsonb := '[]'::jsonb;
  v_bank_ids jsonb := '[]'::jsonb;
  v_partner_ids jsonb := '[]'::jsonb;
  v_club_ids jsonb := '[]'::jsonb;
begin
  if v_user_id is null then
    return jsonb_build_object(
      'has_platform_access', false,
      'has_bank_access', false,
      'has_partner_access', false,
      'has_rayon_access', false,
      'bank_partner_ids', '[]'::jsonb,
      'partner_admin_ids', '[]'::jsonb,
      'club_admin_ids', '[]'::jsonb,
      'role_assignments', '[]'::jsonb
    );
  end if;

  select coalesce(u.is_admin, false)
  into v_is_platform_admin
  from public.users u
  where u.id = v_user_id;

  if not v_is_platform_admin then
    select exists (
      select 1
      from public.admin_role_assignments ra
      where ra.user_id = v_user_id
        and ra.is_active = true
        and ra.role in ('admin', 'super_admin')
    )
    into v_is_platform_admin;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ra.id,
        'role', ra.role,
        'partner_scope_id', ra.partner_scope_id,
        'club_id', ra.club_id,
        'partner_name', p.name,
        'granted_at', ra.granted_at,
        'is_active', ra.is_active
      )
      order by ra.granted_at desc
    ),
    '[]'::jsonb
  )
  into v_role_rows
  from public.admin_role_assignments ra
  left join public.partners p
    on p.id = ra.partner_scope_id
  where ra.user_id = v_user_id
    and ra.is_active = true;

  select coalesce(jsonb_agg(ra.partner_scope_id), '[]'::jsonb)
  into v_bank_ids
  from public.admin_role_assignments ra
  where ra.user_id = v_user_id
    and ra.is_active = true
    and ra.role = 'bank'
    and ra.partner_scope_id is not null;

  select coalesce(jsonb_agg(ra.partner_scope_id), '[]'::jsonb)
  into v_partner_ids
  from public.admin_role_assignments ra
  where ra.user_id = v_user_id
    and ra.is_active = true
    and ra.role in ('partner', 'rayon_sport')
    and ra.partner_scope_id is not null;

  select coalesce(jsonb_agg(ra.club_id), '[]'::jsonb)
  into v_club_ids
  from public.admin_role_assignments ra
  where ra.user_id = v_user_id
    and ra.is_active = true
    and ra.role in ('club_admin', 'club_moderator')
    and ra.club_id is not null;

  v_has_partner := v_is_platform_admin
    or jsonb_array_length(v_partner_ids) > 0
    or jsonb_array_length(v_club_ids) > 0;

  return jsonb_build_object(
    'has_platform_access', v_is_platform_admin,
    'has_bank_access', v_is_platform_admin or jsonb_array_length(v_bank_ids) > 0,
    'has_partner_access', v_has_partner,
    'has_rayon_access', v_has_partner,
    'bank_partner_ids', v_bank_ids,
    'partner_admin_ids', v_partner_ids,
    'club_admin_ids', v_club_ids,
    'role_assignments', v_role_rows
  );
end;
$$;

grant execute on function public.resolve_partner_ids_for_club(bigint) to authenticated, service_role;
grant execute on function public.is_partner_admin(uuid) to authenticated, service_role;
grant execute on function public.user_has_admin_workspace_access(bigint, uuid) to authenticated, service_role;
grant execute on function public.get_partner_member_registry(uuid, text, text, text, integer, integer) to authenticated, service_role;
grant execute on function public.get_club_member_registry(bigint, text, text, text, integer, integer) to authenticated, service_role;
grant execute on function public.apply_membership_points(uuid, uuid, integer, text) to service_role;
grant execute on function public.get_club_fan_analytics(bigint) to authenticated, service_role;

commit;
