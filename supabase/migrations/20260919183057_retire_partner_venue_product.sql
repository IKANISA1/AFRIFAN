-- Retire the removed partner-venue product. Historical migrations remain intact.
-- Match stadium details belong to ticket events, independently of partner businesses.
-- Applying this migration removes retired operational tables; run only as part of
-- an explicitly authorized deployment. Repository QA uses isolated synthetic data.
begin;

alter table public.ticket_events
  add column location_name text,
  add column location_address text,
  add column location_country_code text,
  add column location_timezone text;

update public.ticket_events event
set location_name = venue.display_name,
    location_address = coalesce(venue.address_line, match.venue),
    location_country_code = venue.country_code,
    location_timezone = venue.timezone
from public.venues venue, public.matches match
where venue.id = event.venue_id and venue.club_id = event.club_id
  and match.id = event.match_id and match.club_id = event.club_id;

alter table public.ticket_events
  alter column location_name set not null,
  alter column location_address set not null,
  alter column location_country_code set not null,
  alter column location_timezone set not null,
  add constraint ticket_events_location_country_check check (location_country_code ~ '^[A-Z]{2}$'),
  add constraint ticket_events_location_required_check check
    (btrim(location_name) <> '' and btrim(location_address) <> '' and btrim(location_timezone) <> '');

CREATE OR REPLACE FUNCTION public.enforce_ticketing_scope_consistency()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if tg_table_name = 'ticket_events' then
    if not exists (
      select 1
      from public.ticket_organizations as organization
      where organization.id = new.organization_id
        and organization.club_id = new.club_id
    ) or not exists (
      select 1
      from public.matches as match
      where match.id = new.match_id
        and match.club_id = new.club_id
    ) then
      raise exception 'Ticket event scope is inconsistent.';
    end if;
  elsif tg_table_name = 'ticket_wallet_credentials' then
    if not exists (
      select 1
      from public.ticket_events as event
      join public.tickets as ticket
        on ticket.id = new.ticket_id
       and ticket.club_id = new.club_id
       and ticket.match_id = event.match_id
      where event.id = new.ticket_event_id
        and event.club_id = new.club_id
        and event.organization_id = new.organization_id
    ) then
      raise exception 'Ticket Wallet credential scope is inconsistent.';
    end if;
  elsif tg_table_name = 'google_wallet_ticket_passes' then
    if not exists (
      select 1
      from public.ticket_wallet_credentials as credential
      where credential.id = new.credential_id
        and credential.club_id = new.club_id
        and credential.organization_id = new.organization_id
        and credential.ticket_event_id = new.ticket_event_id
        and credential.ticket_id = new.ticket_id
    ) then
      raise exception 'Google Wallet pass scope is inconsistent.';
    end if;
  elsif tg_table_name = 'google_wallet_ticket_outbox' then
    if not exists (
      select 1
      from public.google_wallet_ticket_passes as pass
      where pass.id = new.pass_id
        and pass.club_id = new.club_id
        and pass.ticket_id = new.ticket_id
    ) then
      raise exception 'Google Wallet outbox scope is inconsistent.';
    end if;

  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.prepare_google_wallet_ticket(p_ticket_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_actor uuid := auth.uid();
  v_club_id bigint;
  v_ticket public.tickets;
  v_match public.matches;
  v_event public.ticket_events;
  v_organization public.ticket_organizations;
  v_credential public.ticket_wallet_credentials;
begin
  if v_actor is null then
    return jsonb_build_object('status', 'error', 'code', 'auth_required');
  end if;

  begin
    v_club_id := nullif(public.requesting_club_id(), '')::bigint;
  exception
    when invalid_text_representation then
      return jsonb_build_object('status', 'error', 'code', 'club_scope_required');
  end;

  if v_club_id is null or p_ticket_id is null then
    return jsonb_build_object('status', 'error', 'code', 'invalid_request');
  end if;

  select ticket.*
  into v_ticket
  from public.tickets as ticket
  where ticket.id = p_ticket_id
    and ticket.user_id = v_actor
    and ticket.club_id = v_club_id
  for update;

  if not found then
    return jsonb_build_object('status', 'error', 'code', 'ticket_not_found');
  end if;

  if v_ticket.is_mock then
    return jsonb_build_object('status', 'error', 'code', 'mock_ticket_forbidden');
  end if;

  if v_ticket.status <> 'valid' or v_ticket.confirmed_at is null then
    return jsonb_build_object(
      'status',
      'error',
      'code',
      case
        when v_ticket.status = 'pending' then 'payment_pending'
        else 'ticket_not_active'
      end
    );
  end if;

  select match.*
  into v_match
  from public.matches as match
  where match.id = v_ticket.match_id
    and match.club_id = v_club_id;

  if not found then
    return jsonb_build_object('status', 'error', 'code', 'match_not_found');
  end if;

  select event.*
  into v_event
  from public.ticket_events as event
  where event.match_id = v_ticket.match_id
    and event.club_id = v_club_id
    and event.status = 'active'
    and event.google_wallet_enabled
  limit 1;

  if not found then
    return jsonb_build_object('status', 'error', 'code', 'wallet_not_enabled');
  end if;

  if timezone('utc', now()) >= v_event.entry_closes_at then
    return jsonb_build_object('status', 'error', 'code', 'event_expired');
  end if;


  select organization.*
  into v_organization
  from public.ticket_organizations as organization
  where organization.id = v_event.organization_id
    and organization.club_id = v_club_id
    and organization.status = 'active';

  if not found or v_organization.google_wallet_issuer_id is null then
    return jsonb_build_object('status', 'error', 'code', 'wallet_not_configured');
  end if;

  select credential.*
  into v_credential
  from public.ticket_wallet_credentials as credential
  where credential.ticket_id = v_ticket.id
    and credential.status = 'active'
  for update;

  if not found then
    insert into public.ticket_wallet_credentials (
      club_id,
      organization_id,
      ticket_event_id,
      ticket_id
    ) values (
      v_club_id,
      v_organization.id,
      v_event.id,
      v_ticket.id
    )
    returning * into v_credential;
  end if;

  return jsonb_build_object(
    'status', 'success',
    'code', 'ready',
    'ticket_id', v_ticket.id,
    'ticket_number', right(replace(v_ticket.id::text, '-', ''), 12),
    'credential_id', v_credential.id,
    'credential_version', v_credential.credential_version,
    'ticket_event_id', v_event.id,
    'organization_id', v_organization.id,
    'organization_name', v_organization.display_name,
    'issuer_id', v_organization.google_wallet_issuer_id,
    'entry_opens_at', v_event.entry_opens_at,
    'entry_closes_at', v_event.entry_closes_at,
    'seat_type', v_ticket.seat_type,
    'match_id', v_match.id,
    'home_team', v_match.home_team,
    'away_team', v_match.away_team,
    'competition', v_match.competition,
    'venue', v_event.location_name,
    'venue_address', v_event.location_address,
    'venue_country_code', v_event.location_country_code,
    'venue_timezone', v_event.location_timezone,
    'match_date', v_match.match_date,
    'kickoff_time', v_match.kickoff_time
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_platform_config(p_channel text DEFAULT 'mobile'::text, p_club_id bigint DEFAULT NULL::bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_result jsonb;
  v_features jsonb;
  v_content_blocks jsonb;
  v_routes jsonb;
  v_option_sets jsonb;
  v_runtime_copy jsonb;
  v_site_navigation jsonb;
  v_site_search jsonb;
  v_now timestamptz := now();
begin
  with resolved_features as (
    select distinct on (pf.feature_key)
      pf.id,
      pf.feature_key,
      pf.display_name,
      pf.description,
      pf.category,
      pf.club_id,
      pf.is_enabled,
      pf.visibility_state
    from public.platform_features pf
    where pf.club_id is null
       or pf.club_id = p_club_id
    order by pf.feature_key, pf.club_id desc nulls last
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'feature_key', rf.feature_key,
      'display_name', rf.display_name,
      'description', rf.description,
      'category', rf.category,
      'is_enabled', rf.is_enabled,
      'visibility_state', rf.visibility_state,
      'channel', (
        select jsonb_build_object(
          'is_enabled', coalesce(ch.is_enabled, true),
          'is_visible', coalesce(ch.is_visible, true),
          'show_in_navigation', coalesce(ch.show_in_navigation, false),
          'show_on_home', coalesce(ch.show_on_home, false),
          'sort_order', ch.sort_order,
          'route_key', ch.route_key,
          'placement_key', ch.placement_key
        )
        from public.platform_feature_channels ch
        where ch.feature_id = rf.id
          and ch.channel = p_channel
      ),
      'rules', (
        select jsonb_build_object(
          'auth_required', coalesce(r.auth_required, false),
          'role_restrictions', coalesce(r.role_restrictions, '[]'::jsonb),
          'dependency_rules', coalesce(r.dependency_rules, '{}'::jsonb),
          'rollout_rules', coalesce(r.rollout_rules, '{}'::jsonb),
          'schedule_start_at', r.schedule_start_at,
          'schedule_end_at', r.schedule_end_at,
          'is_within_schedule',
            case
              when r.schedule_start_at is null and r.schedule_end_at is null then true
              when r.schedule_start_at is not null and r.schedule_end_at is not null
                then v_now >= r.schedule_start_at and v_now < r.schedule_end_at
              when r.schedule_start_at is not null then v_now >= r.schedule_start_at
              when r.schedule_end_at is not null then v_now < r.schedule_end_at
              else true
            end
        )
        from public.platform_feature_rules r
        where r.feature_id = rf.id
      )
    )
    order by rf.feature_key
  ), '[]'::jsonb)
  into v_features
  from resolved_features rf;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'block_key', cb.block_key,
      'block_type', cb.block_type,
      'title', cb.title,
      'subtitle', cb.subtitle,
      'content', cb.content,
      'target_channel', cb.target_channel,
      'placement_key', cb.placement_key,
      'feature_key', pf.feature_key,
      'is_active', cb.is_active,
      'sort_order', cb.sort_order,
      'metadata', cb.metadata
    )
    order by cb.sort_order nulls last, cb.created_at
  ), '[]'::jsonb)
  into v_content_blocks
  from public.platform_content_blocks cb
  left join public.platform_features pf on pf.id = cb.feature_id
  where cb.is_active = true
    and (cb.target_channel = p_channel or cb.target_channel = 'both')
    and (cb.club_id is null or cb.club_id = p_club_id);

  with resolved_routes as (
    select distinct on (prr.route_key, prr.surface)
      prr.*
    from public.platform_route_registry prr
    where prr.is_active = true
      and (prr.surface = p_channel or prr.surface = 'both')
      and (prr.club_id is null or prr.club_id = p_club_id)
    order by prr.route_key, prr.surface, prr.club_id desc nulls last
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'route_key', route_key,
      'path_pattern', path_pattern,
      'surface', surface,
      'feature_key', feature_key,
      'label', label,
      'auth_required', auth_required,
      'required_roles', required_roles,
      'presentation', presentation,
      'show_in_navigation', show_in_navigation,
      'show_on_home', show_on_home,
      'sort_order', sort_order,
      'metadata', metadata
    )
    order by sort_order, route_key
  ), '[]'::jsonb)
  into v_routes
  from resolved_routes;

  with resolved_sets as (
    select distinct on (pos.option_set_key)
      pos.*
    from public.platform_option_sets pos
    where pos.is_active = true
      and (pos.surface = p_channel or pos.surface = 'both')
      and (pos.club_id is null or pos.club_id = p_club_id)
    order by pos.option_set_key, pos.club_id desc nulls last
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'option_set_key', rs.option_set_key,
      'label', rs.label,
      'description', rs.description,
      'value_type', rs.value_type,
      'surface', rs.surface,
      'metadata', rs.metadata,
      'values', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'option_key', pov.option_key,
            'label', pov.label,
            'value', pov.value,
            'sort_order', pov.sort_order,
            'is_default', pov.is_default,
            'metadata', pov.metadata
          )
          order by pov.sort_order, pov.label
        )
        from public.platform_option_values pov
        where pov.option_set_id = rs.id
          and pov.is_active = true
      ), '[]'::jsonb)
    )
    order by rs.option_set_key
  ), '[]'::jsonb)
  into v_option_sets
  from resolved_sets rs;

  with resolved_copy as (
    select distinct on (rc.copy_key, rc.locale)
      rc.*
    from public.runtime_copy rc
    where rc.is_active = true
      and (rc.surface = p_channel or rc.surface = 'both')
      and (rc.club_id is null or rc.club_id = p_club_id)
    order by rc.copy_key, rc.locale, rc.club_id desc nulls last
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'copy_key', copy_key,
      'surface', surface,
      'locale', locale,
      'text_value', text_value,
      'description', description,
      'metadata', metadata
    )
    order by copy_key, locale
  ), '[]'::jsonb)
  into v_runtime_copy
  from resolved_copy;

  with resolved_navigation as (
    select distinct on (sni.nav_key, sni.surface, sni.nav_group)
      sni.*
    from public.site_navigation_items sni
    where sni.is_active = true
      and (sni.surface = p_channel or sni.surface = 'both' or (p_channel = 'web' and sni.surface = 'web'))
      and (sni.club_id is null or sni.club_id = p_club_id)
    order by sni.nav_key, sni.surface, sni.nav_group, sni.club_id desc nulls last
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'nav_key', nav_key,
      'label', label,
      'href', href,
      'nav_group', nav_group,
      'surface', surface,
      'feature_key', feature_key,
      'sort_order', sort_order,
      'metadata', metadata
    )
    order by nav_group, sort_order, label
  ), '[]'::jsonb)
  into v_site_navigation
  from resolved_navigation;

  with resolved_search as (
    select distinct on (ssi.search_key, ssi.surface)
      ssi.*
    from public.site_search_items ssi
    where ssi.is_active = true
      and (ssi.surface = p_channel or ssi.surface = 'both' or (p_channel = 'web' and ssi.surface = 'web'))
      and (ssi.club_id is null or ssi.club_id = p_club_id)
    order by ssi.search_key, ssi.surface, ssi.club_id desc nulls last
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'search_key', search_key,
      'title', title,
      'description', description,
      'href', href,
      'category', category,
      'meta_label', meta_label,
      'surface', surface,
      'feature_key', feature_key,
      'sort_order', sort_order,
      'metadata', metadata
    )
    order by sort_order, title
  ), '[]'::jsonb)
  into v_site_search
  from resolved_search;


  v_result := jsonb_build_object(
    'features', v_features,
    'content_blocks', v_content_blocks,
    'route_registry', v_routes,
    'option_sets', v_option_sets,
    'runtime_copy', v_runtime_copy,
    'site_navigation', v_site_navigation,
    'site_search', v_site_search,
    'config_version', v_now,
    'channel', p_channel,
    'club_id', p_club_id
  );

  return v_result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_delete_mutable_record_if_unchanged(p_table_name text, p_record_id text, p_expected_updated_at timestamp with time zone, p_actor_id uuid, p_club_id bigint DEFAULT NULL::bigint, p_enforce_club_scope boolean DEFAULT false, p_requires_platform_admin boolean DEFAULT false, p_action text DEFAULT 'delete'::text, p_source text DEFAULT 'admin_workspace'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
    'standings'
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
$function$;

-- Remove registrations so runtime configuration cannot revive removed routes.
delete from public.platform_route_registry
where surface = 'venue' or feature_key like 'venue_%'
   or path_pattern ~ '^/(venue(s)?|fanzone/venue|admin/venues|admin/tickets/verifiers)(/|$)';
delete from public.site_navigation_items
where surface = 'venue' or feature_key like 'venue_%' or href ~ '^/(venue(s)?|fanzone/venue|admin/venues|admin/tickets/verifiers)(/|$)';
delete from public.site_search_items
where surface = 'venue' or feature_key like 'venue_%' or href ~ '^/(venue(s)?|fanzone/venue|admin/venues|admin/tickets/verifiers)(/|$)';
delete from public.runtime_copy where surface = 'venue' or copy_key ~ '^venue[._]';
delete from public.platform_option_sets where surface = 'venue' or option_set_key like 'venue_%';
delete from public.platform_content_blocks where feature_id in (select id from public.platform_features where feature_key like 'venue_%');
delete from public.platform_features where feature_key like 'venue_%';

alter table public.ticket_events drop column venue_id, drop column verification_enabled;
drop policy ticket_organizations_assigned_or_admin_read on public.ticket_organizations;
create policy ticket_organizations_admin_read on public.ticket_organizations
  for select to authenticated
  using ((club_id::text = public.requesting_club_id() and public.is_club_admin(club_id)) or public.is_super_admin());
drop policy ticket_events_assigned_or_admin_read on public.ticket_events;
create policy ticket_events_admin_read on public.ticket_events
  for select to authenticated
  using ((club_id::text = public.requesting_club_id() and public.is_club_admin(club_id)) or public.is_super_admin());

drop table public.fet_ledger_reservations,
  public.ticket_redemption_events,
  public.ticket_verifier_assignments,
  public.venue_checkin_campaigns,
  public.venue_checkin_codes,
  public.venue_checkins,
  public.venue_drink_items,
  public.venue_drink_order_items,
  public.venue_drink_orders,
  public.venue_fet_wallets,
  public.venue_governance_controls,
  public.venue_order_events,
  public.venue_promotion_events,
  public.venue_staff_audit_events,
  public.venue_staff_memberships,
  public.venues;
drop function public.grant_ticket_verifier_assignment(uuid,bigint,uuid,uuid,text,timestamp with time zone,timestamp with time zone);
drop function public.prevent_ticket_redemption_event_mutation();
drop function public.redeem_ticket_for_verifier(uuid,uuid,integer,uuid,text);
drop function public.revoke_ticket_verifier_assignment(uuid,bigint,uuid,timestamp with time zone);
drop function public.venue_checkin_validate_unscoped_internal(bigint,text,text,numeric);
drop function public.venue_checkin_validate(bigint,text,text,numeric);
drop function public.venue_enforce_active_drink_limit();
drop function public.venue_menu_upsert(uuid,uuid,text,text,integer,text,boolean,boolean,integer);
drop function public.venue_order_create_unscoped_internal(bigint,uuid,uuid,jsonb,boolean,text);
drop function public.venue_order_create(bigint,uuid,uuid,jsonb,boolean,text);
drop function public.venue_order_update_status(bigint,uuid,text,text);
drop function public.venue_promotion_launch(uuid,uuid,text);
drop function public.venue_staff_can_access(uuid,text[]);

-- No runtime registry accepts the removed product surface.
alter table public.platform_route_registry drop constraint if exists platform_route_registry_surface_check;
alter table public.platform_route_registry add constraint platform_route_registry_surface_check check (surface in ('mobile','web','admin','both'));
alter table public.platform_option_sets drop constraint if exists platform_option_sets_surface_check;
alter table public.platform_option_sets add constraint platform_option_sets_surface_check check (surface in ('mobile','web','admin','both'));
alter table public.runtime_copy drop constraint if exists runtime_copy_surface_check;
alter table public.runtime_copy add constraint runtime_copy_surface_check check (surface in ('mobile','web','admin','both'));
alter table public.site_navigation_items drop constraint if exists site_navigation_items_surface_check;
alter table public.site_navigation_items add constraint site_navigation_items_surface_check check (surface in ('mobile','web','admin','both'));
alter table public.site_search_items drop constraint if exists site_search_items_surface_check;
alter table public.site_search_items add constraint site_search_items_surface_check check (surface in ('mobile','web','admin','both'));

update public.partners
set description = 'Club beverage sponsor for matchday supporter experiences.',
    subtitle = 'Matchday sponsorship'
where slug = 'skol'
  and description = 'Official beverage partner for venue orders, fan zone check-ins, and matchday supporter experiences.'
  and subtitle = 'Matchday venue activations';

commit;
