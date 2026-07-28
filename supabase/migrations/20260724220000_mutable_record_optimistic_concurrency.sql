-- Optimistic-concurrency foundations for mutable contribution and order records.
--
-- The client and reconciliation paths retain the `updated_at` value they
-- loaded and include it in the mutation predicate. A zero-row mutation is a
-- conflict and must be refreshed/reviewed instead of silently overwriting a
-- newer record.

alter table public.group_contributions
  add column if not exists updated_at timestamptz;

update public.group_contributions
   set updated_at = coalesce(created_at, timezone('utc', now()))
 where updated_at is null;

alter table public.group_contributions
  alter column updated_at set default timezone('utc', now()),
  alter column updated_at set not null;

drop trigger if exists trg_group_contributions_set_updated_at
  on public.group_contributions;

create trigger trg_group_contributions_set_updated_at
before update on public.group_contributions
for each row execute function public.set_updated_at();

create or replace function public.cancel_shop_order_if_unchanged(
  p_order_id uuid,
  p_expected_updated_at timestamptz
)
returns public.shop_orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid := auth.uid();
  v_order public.shop_orders;
begin
  if v_actor_id is null then
    raise exception 'An authenticated supporter is required.';
  end if;

  if p_order_id is null or p_expected_updated_at is null then
    raise exception 'Order id and loaded version are required.';
  end if;

  update public.shop_orders
     set status = 'cancelled'
   where id = p_order_id
     and user_id = v_actor_id
     and status = 'pending'
     and updated_at = p_expected_updated_at
  returning * into v_order;

  if found then
    return v_order;
  end if;

  select *
    into v_order
    from public.shop_orders
   where id = p_order_id
     and user_id = v_actor_id;

  if not found then
    raise exception 'Order was not found in the active supporter account.';
  end if;

  if v_order.status <> 'pending' then
    raise exception 'Order can no longer be cancelled. Refresh order history.';
  end if;

  raise exception
    'Order changed after it was loaded. Refresh order history and review before retrying.';
end;
$$;

revoke all on function public.cancel_shop_order_if_unchanged(
  uuid,
  timestamptz
) from public, anon;

grant execute on function public.cancel_shop_order_if_unchanged(
  uuid,
  timestamptz
) to authenticated;

comment on function public.cancel_shop_order_if_unchanged(uuid, timestamptz) is
  'Cancels only the authenticated supporter''s still-pending shop order when the loaded updated_at token is current.';

create or replace function public.admin_review_group_contribution_if_unchanged(
  p_contribution_id uuid,
  p_expected_updated_at timestamptz,
  p_status text,
  p_club_id bigint,
  p_actor_id uuid,
  p_role text,
  p_is_super_admin boolean default false
)
returns public.group_contributions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_contribution public.group_contributions;
  v_previous public.group_contributions;
begin
  if p_contribution_id is null or p_expected_updated_at is null then
    raise exception 'Contribution id and loaded version are required.';
  end if;

  if p_actor_id is null then
    raise exception 'An authenticated audit actor is required.';
  end if;

  if not coalesce(p_is_super_admin, false)
     and coalesce(p_role, '') not in (
       'super_admin',
       'admin',
       'club_admin',
       'club_moderator'
     ) then
    raise exception 'Your role cannot review contributions.';
  end if;

  if p_status not in ('confirmed', 'failed') then
    raise exception 'Unsupported contribution review status.';
  end if;

  select contribution.*
    into v_previous
    from public.group_contributions as contribution
    join public.contribution_groups as contribution_group
      on contribution_group.id = contribution.group_id
   where contribution.id = p_contribution_id
     and contribution_group.club_id = p_club_id;

  if not found then
    raise exception 'Contribution is missing or outside the active club.';
  end if;

  if v_previous.status <> 'pending' then
    raise exception 'Contribution is no longer pending. Refresh the queue.';
  end if;

  update public.group_contributions
     set status = p_status
   where id = p_contribution_id
     and status = 'pending'
     and updated_at = p_expected_updated_at
  returning * into v_contribution;

  if not found then
    raise exception
      'Contribution changed after it was loaded. Refresh the queue and review before retrying.';
  end if;

  insert into public.admin_audit_log (
    actor_id,
    user_id,
    action,
    target_table,
    target_id,
    old_data,
    new_data,
    club_id,
    entity_type,
    entity_id,
    metadata
  )
  values (
    p_actor_id,
    p_actor_id,
    'contribution_status_review',
    'group_contributions',
    v_contribution.id::text,
    jsonb_build_object(
      'status',
      v_previous.status,
      'updated_at',
      v_previous.updated_at
    ),
    jsonb_build_object(
      'status',
      v_contribution.status,
      'updated_at',
      v_contribution.updated_at
    ),
    p_club_id,
    'contribution',
    v_contribution.id::text,
    jsonb_build_object(
      'scope',
      'active_club',
      'source',
      'admin_contribution_queue'
    )
  );

  return v_contribution;
end;
$$;

revoke all on function public.admin_review_group_contribution_if_unchanged(
  uuid,
  timestamptz,
  text,
  bigint,
  uuid,
  text,
  boolean
) from public, anon, authenticated;

grant execute on function public.admin_review_group_contribution_if_unchanged(
  uuid,
  timestamptz,
  text,
  bigint,
  uuid,
  text,
  boolean
) to service_role;

comment on function public.admin_review_group_contribution_if_unchanged(
  uuid,
  timestamptz,
  text,
  bigint,
  uuid,
  text,
  boolean
) is
  'Atomically reviews a still-pending contribution at its loaded version and records an immutable admin audit entry.';

create or replace function public.admin_review_membership_application_if_unchanged(
  p_application_id uuid,
  p_expected_updated_at timestamptz,
  p_decision text,
  p_notes text,
  p_club_id bigint,
  p_partner_id uuid,
  p_actor_id uuid
) returns public.membership_applications
language plpgsql
security definer
set search_path = public
as $$
declare
  v_application public.membership_applications;
  v_previous public.membership_applications;
  v_membership public.fan_memberships;
  v_chapter text;
begin
  if p_decision not in ('approved', 'rejected') then
    raise exception 'Membership review decision must be approved or rejected.';
  end if;

  select *
    into v_previous
    from public.membership_applications
   where id = p_application_id
     and club_id = p_club_id
   for update;

  if not found then
    raise exception 'Membership application is not available in the active club.';
  end if;

  if v_previous.updated_at is distinct from p_expected_updated_at then
    raise exception
      'Membership application changed after it was loaded. Refresh the queue and review before retrying.';
  end if;

  if v_previous.status <> 'pending' then
    raise exception
      'Membership application is no longer pending. Refresh the queue and review before retrying.';
  end if;

  if p_decision = 'approved' and v_previous.payment_status <> 'paid' then
    raise exception 'Only paid membership applications can be approved.';
  end if;

  update public.membership_applications
     set status = p_decision,
         notes = p_notes,
         review_date = now(),
         reviewer_id = p_actor_id
   where id = p_application_id
     and updated_at = p_expected_updated_at
  returning * into v_application;

  if not found then
    raise exception
      'Membership application changed after it was loaded. Refresh the queue and review before retrying.';
  end if;

  if p_decision = 'approved' then
    v_chapter := coalesce(
      nullif(btrim(v_previous.metadata ->> 'chapter'), ''),
      'Central'
    );

    v_membership := public.apply_membership_points(
      v_previous.user_id,
      p_partner_id,
      0,
      v_chapter
    );

    update public.fan_memberships
       set tier = v_previous.tier,
           status = 'active',
           club_id = p_club_id,
           chapter = v_chapter
     where id = v_membership.id;

    if not found then
      raise exception
        'Membership approval did not materialize a supporter membership row.';
    end if;
  end if;

  insert into public.admin_audit_log (
    actor_id,
    user_id,
    action,
    target_table,
    target_id,
    old_data,
    new_data,
    club_id,
    entity_type,
    entity_id,
    metadata
  )
  values (
    p_actor_id,
    p_actor_id,
    'membership_application_review',
    'membership_applications',
    v_application.id::text,
    to_jsonb(v_previous),
    to_jsonb(v_application),
    p_club_id,
    'membership_application',
    v_application.id::text,
    jsonb_build_object(
      'decision',
      p_decision,
      'partner_id',
      p_partner_id,
      'scope',
      'active_club'
    )
  );

  return v_application;
end;
$$;

revoke all on function public.admin_review_membership_application_if_unchanged(
  uuid,
  timestamptz,
  text,
  text,
  bigint,
  uuid,
  uuid
) from public, anon, authenticated;

grant execute on function public.admin_review_membership_application_if_unchanged(
  uuid,
  timestamptz,
  text,
  text,
  bigint,
  uuid,
  uuid
) to service_role;

comment on function public.admin_review_membership_application_if_unchanged(
  uuid,
  timestamptz,
  text,
  text,
  bigint,
  uuid,
  uuid
) is
  'Atomically reviews a still-pending membership application, materializes paid approvals, and records immutable audit evidence.';

create or replace function public.touch_platform_feature_parent_version()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_feature_id uuid;
begin
  v_feature_id := case
    when tg_op = 'DELETE' then old.feature_id
    else new.feature_id
  end;

  update public.platform_features
     set updated_at = clock_timestamp()
   where id = v_feature_id;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_platform_feature_channels_touch_parent
  on public.platform_feature_channels;
create trigger trg_platform_feature_channels_touch_parent
after insert or update or delete on public.platform_feature_channels
for each row execute function public.touch_platform_feature_parent_version();

drop trigger if exists trg_platform_feature_rules_touch_parent
  on public.platform_feature_rules;
create trigger trg_platform_feature_rules_touch_parent
after insert or update or delete on public.platform_feature_rules
for each row execute function public.touch_platform_feature_parent_version();

create or replace function public.admin_update_platform_feature_if_unchanged(
  p_feature_id uuid,
  p_expected_updated_at timestamptz,
  p_club_id bigint,
  p_updates jsonb,
  p_actor_id uuid
) returns public.platform_features
language plpgsql
security definer
set search_path = public
as $$
declare
  v_source public.platform_features;
  v_target public.platform_features;
  v_target_id uuid;
  v_channel jsonb;
  v_rules jsonb;
begin
  select *
    into v_source
    from public.platform_features
   where id = p_feature_id
   for update;

  if not found then
    raise exception 'Feature configuration is no longer available.';
  end if;

  if v_source.updated_at is distinct from p_expected_updated_at then
    raise exception
      'Feature configuration changed after it was loaded. Refresh and review before retrying.';
  end if;

  if v_source.club_id is not distinct from p_club_id then
    v_target_id := v_source.id;
  elsif v_source.club_id is null and p_club_id is not null then
    select *
      into v_target
      from public.platform_features
     where feature_key = v_source.feature_key
       and club_id = p_club_id
     for update;

    if found then
      raise exception
        'A scoped override was created after this feature was loaded. Refresh and review before retrying.';
    end if;

    insert into public.platform_features (
      feature_key,
      display_name,
      description,
      category,
      club_id,
      is_enabled,
      visibility_state
    )
    values (
      v_source.feature_key,
      v_source.display_name,
      v_source.description,
      v_source.category,
      p_club_id,
      v_source.is_enabled,
      v_source.visibility_state
    )
    returning id into v_target_id;

    insert into public.platform_feature_channels (
      feature_id,
      channel,
      is_enabled,
      is_visible,
      show_in_navigation,
      show_on_home,
      sort_order,
      route_key,
      placement_key
    )
    select
      v_target_id,
      channel,
      is_enabled,
      is_visible,
      show_in_navigation,
      show_on_home,
      sort_order,
      route_key,
      placement_key
    from public.platform_feature_channels
    where feature_id = v_source.id;

    insert into public.platform_feature_rules (
      feature_id,
      auth_required,
      role_restrictions,
      dependency_rules,
      rollout_rules,
      metadata,
      schedule_start_at,
      schedule_end_at
    )
    select
      v_target_id,
      auth_required,
      role_restrictions,
      dependency_rules,
      rollout_rules,
      metadata,
      schedule_start_at,
      schedule_end_at
    from public.platform_feature_rules
    where feature_id = v_source.id;
  else
    raise exception
      'Feature configuration scope changed after it was loaded. Refresh and review before retrying.';
  end if;

  update public.platform_features
     set display_name = case
           when p_updates ? 'displayName'
             then btrim(p_updates ->> 'displayName')
           else display_name
         end,
         description = case
           when p_updates ? 'description'
             then p_updates ->> 'description'
           else description
         end,
         category = case
           when p_updates ? 'category'
             then p_updates ->> 'category'
           else category
         end,
         is_enabled = case
           when p_updates ? 'isEnabled'
             then (p_updates ->> 'isEnabled')::boolean
           else is_enabled
         end,
         visibility_state = case
           when p_updates ? 'visibilityState'
             then p_updates ->> 'visibilityState'
           else visibility_state
         end
   where id = v_target_id;

  for v_channel in
    select value
      from jsonb_array_elements(
        case
          when jsonb_typeof(p_updates -> 'channels') = 'array'
            then p_updates -> 'channels'
          else '[]'::jsonb
        end
      )
  loop
    if v_channel ->> 'channel' not in ('mobile', 'web') then
      raise exception 'Feature channel must be mobile or web.';
    end if;

    insert into public.platform_feature_channels (
      feature_id,
      channel,
      is_enabled,
      is_visible,
      show_in_navigation,
      show_on_home,
      sort_order,
      route_key,
      placement_key
    )
    values (
      v_target_id,
      v_channel ->> 'channel',
      coalesce((v_channel ->> 'isEnabled')::boolean, true),
      coalesce((v_channel ->> 'isVisible')::boolean, true),
      coalesce((v_channel ->> 'showInNavigation')::boolean, false),
      coalesce((v_channel ->> 'showOnHome')::boolean, false),
      (v_channel ->> 'sortOrder')::integer,
      nullif(btrim(v_channel ->> 'routeKey'), ''),
      nullif(btrim(v_channel ->> 'placementKey'), '')
    )
    on conflict (feature_id, channel)
    do update set
      is_enabled = excluded.is_enabled,
      is_visible = excluded.is_visible,
      show_in_navigation = excluded.show_in_navigation,
      show_on_home = excluded.show_on_home,
      sort_order = excluded.sort_order,
      route_key = excluded.route_key,
      placement_key = excluded.placement_key;
  end loop;

  if p_updates ? 'rules'
     and jsonb_typeof(p_updates -> 'rules') = 'object' then
    v_rules := p_updates -> 'rules';

    insert into public.platform_feature_rules (
      feature_id,
      auth_required,
      role_restrictions,
      dependency_rules,
      rollout_rules,
      metadata,
      schedule_start_at,
      schedule_end_at
    )
    values (
      v_target_id,
      coalesce((v_rules ->> 'authRequired')::boolean, false),
      coalesce(v_rules -> 'roleRestrictions', '[]'::jsonb),
      coalesce(v_rules -> 'dependencyRules', '{}'::jsonb),
      coalesce(v_rules -> 'rolloutRules', '{}'::jsonb),
      coalesce(v_rules -> 'metadata', '{}'::jsonb),
      nullif(v_rules ->> 'scheduleStartAt', '')::timestamptz,
      nullif(v_rules ->> 'scheduleEndAt', '')::timestamptz
    )
    on conflict (feature_id)
    do update set
      auth_required = excluded.auth_required,
      role_restrictions = excluded.role_restrictions,
      dependency_rules = excluded.dependency_rules,
      rollout_rules = excluded.rollout_rules,
      metadata = excluded.metadata,
      schedule_start_at = excluded.schedule_start_at,
      schedule_end_at = excluded.schedule_end_at;
  end if;

  select *
    into v_target
    from public.platform_features
   where id = v_target_id;

  insert into public.admin_audit_log (
    actor_id,
    user_id,
    action,
    target_table,
    target_id,
    old_data,
    new_data,
    club_id,
    entity_type,
    entity_id,
    metadata
  )
  values (
    p_actor_id,
    p_actor_id,
    'platform_feature_update',
    'platform_features',
    v_target.id::text,
    to_jsonb(v_source),
    to_jsonb(v_target),
    p_club_id,
    'platform_feature',
    v_target.id::text,
    jsonb_build_object(
      'source_feature_id',
      v_source.id,
      'copy_on_write',
      v_source.id <> v_target.id,
      'scope',
      case when p_club_id is null then 'global' else 'active_club' end
    )
  );

  return v_target;
end;
$$;

revoke all on function public.admin_update_platform_feature_if_unchanged(
  uuid,
  timestamptz,
  bigint,
  jsonb,
  uuid
) from public, anon, authenticated;

grant execute on function public.admin_update_platform_feature_if_unchanged(
  uuid,
  timestamptz,
  bigint,
  jsonb,
  uuid
) to service_role;

comment on function public.admin_update_platform_feature_if_unchanged(
  uuid,
  timestamptz,
  bigint,
  jsonb,
  uuid
) is
  'Atomically version-checks a feature, creates a scoped override when needed, updates feature/channel/rule state, and records audit evidence.';
