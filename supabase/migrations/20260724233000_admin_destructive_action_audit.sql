-- Atomic, role-safe, auditable deletes for the governed admin workspace.
--
-- Admin API routes use a service-role client after resolving the human actor.
-- This RPC re-validates that actor, performs the loaded-version delete, and
-- writes the immutable audit row in the same database transaction.

create or replace function public.admin_delete_mutable_record_if_unchanged(
  p_table_name text,
  p_record_id text,
  p_expected_updated_at timestamptz,
  p_actor_id uuid,
  p_club_id bigint default null,
  p_enforce_club_scope boolean default false,
  p_requires_platform_admin boolean default false,
  p_action text default 'delete',
  p_source text default 'admin_workspace'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_allowed_tables constant text[] := array[
    'ai_content',
    'club_app_config',
    'club_players',
    'club_standings',
    'contribution_groups',
    'fan_clubs',
    'fan_engagement_token_catalog',
    'fet_partner_offers',
    'groups',
    'home_banners',
    'league_standings',
    'livescore_competition_sources',
    'matches',
    'membership_tiers',
    'news_articles',
    'players',
    'platform_content_blocks',
    'platform_option_sets',
    'platform_option_values',
    'platform_route_registry',
    'rs_news_articles',
    'rs_shop_products',
    'rs_squad_players',
    'rs_standings',
    'runtime_copy',
    'shop_products',
    'site_navigation_items',
    'site_search_items',
    'squad_players',
    'standings',
    'venue_governance_controls'
  ];
  v_is_platform_admin boolean := false;
  v_is_club_admin boolean := false;
  v_deleted jsonb;
  v_sql text;
begin
  if p_table_name is null or not (p_table_name = any(v_allowed_tables)) then
    raise exception 'Table is not approved for governed admin deletion.';
  end if;

  if p_record_id is null or btrim(p_record_id) = '' then
    raise exception 'A record id is required.';
  end if;

  if p_expected_updated_at is null then
    raise exception
      'This record has no loaded version. Refresh the latest data before deleting it.';
  end if;

  if p_actor_id is null then
    raise exception 'An authenticated audit actor is required.';
  end if;

  select exists (
    select 1
    from public.admin_role_assignments assignment
    where assignment.user_id = p_actor_id
      and assignment.is_active = true
      and assignment.revoked_at is null
      and assignment.role in ('super_admin', 'admin')
  )
  into v_is_platform_admin;

  select exists (
    select 1
    from public.admin_role_assignments assignment
    where assignment.user_id = p_actor_id
      and assignment.is_active = true
      and assignment.revoked_at is null
      and assignment.role = 'club_admin'
      and p_club_id is not null
      and assignment.club_id = p_club_id
  )
  into v_is_club_admin;

  if p_requires_platform_admin and not v_is_platform_admin then
    raise exception 'Platform admin access is required for this deletion.';
  end if;

  if not p_requires_platform_admin
     and not v_is_platform_admin
     and not v_is_club_admin then
    raise exception 'Club-admin access is required for this deletion.';
  end if;

  if p_enforce_club_scope and p_club_id is null then
    raise exception 'An active club scope is required for this deletion.';
  end if;

  v_sql := format(
    'delete from public.%I
       where id::text = $1
         and updated_at = $2',
    p_table_name
  );

  if p_enforce_club_scope then
    v_sql := v_sql || ' and club_id = $3';
  end if;

  v_sql := v_sql || ' returning to_jsonb(' || quote_ident(p_table_name) || '.*)';

  if p_enforce_club_scope then
    execute v_sql
      into v_deleted
      using p_record_id, p_expected_updated_at, p_club_id;
  else
    execute v_sql
      into v_deleted
      using p_record_id, p_expected_updated_at;
  end if;

  if v_deleted is null then
    raise exception
      'Record changed after it was loaded or is outside the active admin scope. Refresh and review before retrying.';
  end if;

  insert into public.admin_audit_log (
    actor_id,
    user_id,
    action,
    target_table,
    target_id,
    old_data,
    club_id,
    entity_type,
    entity_id,
    metadata
  )
  values (
    p_actor_id,
    p_actor_id,
    coalesce(nullif(btrim(p_action), ''), 'delete'),
    p_table_name,
    p_record_id,
    v_deleted,
    p_club_id,
    p_table_name,
    p_record_id,
    jsonb_build_object(
      'scope',
      case
        when p_enforce_club_scope then 'active_club'
        when p_requires_platform_admin then 'platform'
        else 'authorized_admin'
      end,
      'source',
      coalesce(nullif(btrim(p_source), ''), 'admin_workspace'),
      'undo',
      'not_available'
    )
  );

  return v_deleted;
end;
$$;

revoke all on function public.admin_delete_mutable_record_if_unchanged(
  text,
  text,
  timestamptz,
  uuid,
  bigint,
  boolean,
  boolean,
  text,
  text
) from public, anon, authenticated;

grant execute on function public.admin_delete_mutable_record_if_unchanged(
  text,
  text,
  timestamptz,
  uuid,
  bigint,
  boolean,
  boolean,
  text,
  text
) to service_role;

comment on function public.admin_delete_mutable_record_if_unchanged(
  text,
  text,
  timestamptz,
  uuid,
  bigint,
  boolean,
  boolean,
  text,
  text
) is
  'Atomically re-validates the resolved admin actor, deletes a whitelisted mutable record at its loaded version and scope, and records immutable audit evidence.';

create or replace function public.audit_admin_sms_review_rejection()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
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
    auth.uid(),
    auth.uid(),
    'reject_sms_manual_review',
    tg_table_name,
    new.id::text,
    to_jsonb(old),
    to_jsonb(new),
    coalesce(new.club_id, old.club_id),
    'momo_sms_manual_review',
    new.id::text,
    jsonb_build_object(
      'scope',
      'record_and_active_club',
      'source',
      'admin_sms_monitor',
      'undo',
      'manual_recovery'
    )
  );
  return new;
end;
$$;

drop trigger if exists trg_audit_admin_sms_review_rejection
  on public.momo_reconciliations;

create trigger trg_audit_admin_sms_review_rejection
after update of match_status on public.momo_reconciliations
for each row
when (
  old.match_status is distinct from new.match_status
  and new.match_status = 'rejected'
)
execute function public.audit_admin_sms_review_rejection();

revoke all on function public.audit_admin_sms_review_rejection()
  from public, anon, authenticated;
