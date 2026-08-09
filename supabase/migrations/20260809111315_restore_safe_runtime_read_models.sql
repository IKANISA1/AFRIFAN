-- Restore the release runtime's deliberately public/owner read models without
-- reopening the legacy broad table grants. Store-sensitive approvals remain a
-- service-controlled operation; ordinary admins may configure only non-gating
-- feature metadata.

alter default privileges for role postgres in schema public
  revoke truncate, references, trigger, maintain on tables
  from public, anon, authenticated;

revoke truncate, references, trigger, maintain on all tables in schema public
  from public, anon, authenticated;

-- Public club identity. Private contacts, market research, MoMo routing, and
-- ungoverned image URLs are intentionally absent from the client projection.
revoke all privileges on table public.african_football_clubs
  from public, anon, authenticated;
grant select (
  id,
  club_name,
  country_name,
  country_flag,
  country_iso_code,
  is_onboarded,
  is_active,
  region,
  league,
  nickname_brand_identity,
  club_slug,
  currency_code,
  currency_symbol,
  default_language,
  primary_color_hex,
  secondary_color_hex,
  accent_color_hex,
  supported_languages,
  feature_flags
) on public.african_football_clubs to anon, authenticated;
grant all privileges on table public.african_football_clubs to service_role;

drop policy if exists "Anyone can read active clubs"
  on public.african_football_clubs;
drop policy if exists clubs_public_catalog_read
  on public.african_football_clubs;
create policy clubs_public_catalog_read
  on public.african_football_clubs
  for select
  to anon, authenticated
  using (is_active is true);

-- Published news may expose an image only when the media-governance record is
-- approved. Prompt text and approving-user identifiers remain server-only.
revoke all privileges on table public.news_articles
  from public, anon, authenticated;
grant select (
  id,
  club_id,
  title,
  subtitle,
  body,
  category,
  image_url,
  is_published,
  published_at,
  is_featured,
  sort_order,
  created_at,
  updated_at,
  author_name,
  image_provenance_id,
  image_rights_approved
) on public.news_articles to anon, authenticated;
grant insert (
  club_id,
  title,
  subtitle,
  body,
  category,
  image_url,
  is_published,
  published_at,
  is_featured,
  sort_order,
  author_name
) on public.news_articles to authenticated;
grant update (
  title,
  subtitle,
  body,
  category,
  image_url,
  is_published,
  published_at,
  is_featured,
  sort_order,
  author_name
) on public.news_articles to authenticated;
grant all privileges on table public.news_articles to service_role;

drop policy if exists news_articles_select_published on public.news_articles;
drop policy if exists public_read_published_articles on public.news_articles;
create policy news_articles_public_read
  on public.news_articles
  for select
  to anon, authenticated
  using (
    is_published is true
    and (image_url is null or image_rights_approved is true)
  );

-- Player imagery has no durable rights/provenance fields in the legacy table,
-- so the public release receives the text roster only.
revoke all privileges on table public.squad_players
  from public, anon, authenticated;
grant select (
  id,
  club_id,
  partner_id,
  name,
  position,
  shirt_number,
  nationality,
  bio,
  is_active,
  created_at,
  updated_at
) on public.squad_players to anon, authenticated;
grant all privileges on table public.squad_players to service_role;

drop policy if exists squad_players_public_read on public.squad_players;
drop policy if exists squad_players_select_club on public.squad_players;
create policy squad_players_public_read
  on public.squad_players
  for select
  to anon, authenticated
  using (is_active is true);

revoke all privileges on table public.standings
  from public, anon, authenticated;
grant select (
  id,
  club_id,
  partner_id,
  position,
  club_name,
  club_slug,
  played,
  won,
  drawn,
  lost,
  goals_for,
  goals_against,
  goal_difference,
  points,
  form,
  season,
  league,
  is_active,
  updated_at
) on public.standings to anon, authenticated;
grant all privileges on table public.standings to service_role;

drop policy if exists standings_public_read on public.standings;
create policy standings_public_read
  on public.standings
  for select
  to anon, authenticated
  using (is_active is true);

revoke all privileges on table public.ai_content
  from public, anon, authenticated;
grant select (
  id,
  content_type,
  title,
  subtitle,
  body,
  icon_emoji,
  cta_action,
  cta_label,
  country,
  sort_order,
  status,
  is_active,
  club_id,
  distribution,
  updated_at
) on public.ai_content to anon, authenticated;
grant all privileges on table public.ai_content to service_role;

-- Geography and navigation are intentionally public catalogs.
revoke all privileges on table public.countries
  from public, anon, authenticated;
grant select on table public.countries to anon, authenticated;
grant all privileges on table public.countries to service_role;
drop policy if exists "Public read app_config" on public.app_config;
drop policy if exists app_config_select_all on public.app_config;
drop policy if exists club_app_config_public_read on public.club_app_config;
revoke all privileges on table public.app_config, public.club_app_config
  from public, anon, authenticated;
grant all privileges on table public.app_config, public.club_app_config
  to service_role;

drop function if exists public.get_runtime_app_config(text);
create or replace function public.get_runtime_app_config(
  p_key text default null,
  p_club_id bigint default null
)
returns table (
  scope text,
  key text,
  value text,
  club_id bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  with allowed_global as (
    select
      'global'::text as scope,
      config.key,
      config.value,
      null::bigint as club_id,
      0 as precedence
    from public.app_config as config
    where (
      config.key like 'feature\_%' escape '\'
      or config.key like 'kill\_%' escape '\'
      or config.key in (
        'default_payment_method',
        'support_whatsapp',
        'support_email'
      )
    )
      and (p_key is null or config.key = p_key)
  ),
  allowed_club as (
    select
      'club'::text as scope,
      config.key,
      config.value,
      config.club_id,
      1 as precedence
    from public.club_app_config as config
    where config.club_id = coalesce(
      p_club_id,
      nullif(public.requesting_club_id(), '')::bigint
    )
      and (
        config.key like 'feature\_%' escape '\'
        or config.key like 'kill\_%' escape '\'
        or config.key in (
          'default_payment_method',
          'support_whatsapp',
          'support_email'
        )
      )
      and (p_key is null or config.key = p_key)
  )
  select allowed.scope, allowed.key, allowed.value, allowed.club_id
  from (
    select * from allowed_global
    union all
    select * from allowed_club
  ) as allowed
  order by allowed.key, allowed.precedence;
$$;

revoke all on function public.get_runtime_app_config(text, bigint)
  from public, anon, authenticated, service_role;
grant execute on function public.get_runtime_app_config(text, bigint)
  to anon, authenticated;

revoke all privileges on table public.quick_actions
  from public, anon, authenticated;
grant select on table public.quick_actions to anon, authenticated;
grant insert, update, delete on table public.quick_actions to authenticated;
grant all privileges on table public.quick_actions to service_role;
drop policy if exists "Public read quick_actions" on public.quick_actions;
create policy quick_actions_public_active_read
  on public.quick_actions
  for select
  to anon, authenticated
  using (is_active is true);
drop policy if exists quick_actions_admin_read on public.quick_actions;
create policy quick_actions_admin_read
  on public.quick_actions
  for select
  to authenticated
  using (public.is_admin_user());

-- Partner cards expose public business copy, never the legacy WhatsApp/MoMo
-- contact fields or free-form metadata.
revoke all privileges on table public.partners
  from public, anon, authenticated;
grant select (
  id,
  name,
  category,
  country,
  description,
  fan_count,
  club_count,
  game_count,
  slug,
  emoji,
  subtitle,
  is_active,
  sort_order,
  updated_at,
  brand_primary_color,
  brand_secondary_color,
  website_url,
  gamification_enabled
) on public.partners to anon, authenticated;
grant insert (
  name,
  slug,
  category,
  country,
  emoji,
  subtitle,
  description,
  is_active,
  gamification_enabled,
  sort_order
) on public.partners to authenticated;
grant update (
  name,
  slug,
  category,
  country,
  emoji,
  subtitle,
  description,
  is_active,
  gamification_enabled,
  sort_order,
  brand_primary_color,
  brand_secondary_color,
  website_url
) on public.partners to authenticated;
grant all privileges on table public.partners to service_role;
drop policy if exists partners_select_all on public.partners;
create policy partners_public_active_read
  on public.partners
  for select
  to anon, authenticated
  using (is_active is true);
drop policy if exists partners_admin_read on public.partners;
create policy partners_admin_read
  on public.partners
  for select
  to authenticated
  using (public.is_admin_user());

revoke all privileges on table public.partner_services
  from public, anon, authenticated;
grant select (
  id,
  partner_id,
  title,
  subtitle,
  emoji,
  category,
  details,
  cta_label,
  cta_action,
  country,
  sort_order,
  is_active,
  created_at,
  updated_at,
  service_slug,
  gamification_enabled
) on public.partner_services to anon, authenticated;
grant insert (
  partner_id,
  title,
  subtitle,
  emoji,
  category,
  details,
  cta_label,
  cta_action,
  country,
  sort_order,
  is_active,
  service_slug,
  gamification_enabled
) on public.partner_services to authenticated;
grant update (
  partner_id,
  title,
  subtitle,
  emoji,
  category,
  details,
  cta_label,
  cta_action,
  country,
  sort_order,
  is_active,
  service_slug,
  gamification_enabled
) on public.partner_services to authenticated;
grant delete on table public.partner_services to authenticated;
grant all privileges on table public.partner_services to service_role;
drop policy if exists "Public read partner_services" on public.partner_services;
create policy partner_services_public_active_read
  on public.partner_services
  for select
  to anon, authenticated
  using (is_active is true);
drop policy if exists partner_services_admin_read on public.partner_services;
create policy partner_services_admin_read
  on public.partner_services
  for select
  to authenticated
  using (public.is_admin_user());

revoke all privileges on table public.initiatives
  from public, anon, authenticated;
grant select (
  id,
  partner_id,
  title,
  description,
  category,
  target_amount,
  raised_amount,
  supporter_count,
  is_active,
  ends_at,
  club_id,
  goal_amount,
  status,
  updated_at
) on public.initiatives to anon, authenticated;
grant all privileges on table public.initiatives to service_role;
drop policy if exists initiatives_public_read on public.initiatives;
drop policy if exists initiatives_select_club on public.initiatives;
drop policy if exists rs_initiatives_select_authenticated on public.initiatives;
create policy initiatives_public_active_read
  on public.initiatives
  for select
  to anon, authenticated
  using (is_active is true and status = 'active');

-- Fan activity is owner-only and read-only to the client. Award creation is
-- confined to hardened server functions/service workflows.
revoke all privileges on table public.cool_events, public.fet_events
  from public, anon, authenticated;
grant select (
  id,
  user_id,
  club_id,
  event_type,
  fet_awarded,
  event_at,
  created_at
) on public.fet_events to authenticated;
grant all privileges on table public.cool_events, public.fet_events
  to service_role;

drop policy if exists xp_events_insert_own on public.fet_events;
drop policy if exists xp_events_select_own on public.fet_events;
create policy fet_events_owner_read
  on public.fet_events
  for select
  to authenticated
  using (
    user_id = (select auth.uid())
    and club_id::text = public.requesting_club_id()
  );

-- Reward redemption stays fail-closed in store builds. The service may curate
-- the catalog, but the raw table is not a client API surface.
revoke all privileges on table public.fet_reward_store_items
  from public, anon, authenticated;
grant all privileges on table public.fet_reward_store_items to service_role;

-- Payment instructions are visible only to an authenticated user in the
-- active club; write authority remains server-side.
revoke all privileges on table public.partner_payment_routes
  from public, anon, authenticated;
grant select (
  id,
  partner_id,
  club_id,
  partner_name,
  partner_slug,
  country,
  provider,
  recipient_code,
  reconciliation_label,
  status
) on public.partner_payment_routes to authenticated;
grant all privileges on table public.partner_payment_routes to service_role;

-- Public venue discovery and authenticated owner/staff order context.
revoke all privileges on table public.venues,
  public.venue_checkins,
  public.venue_drink_items,
  public.venue_drink_orders
  from public, anon, authenticated;
grant select (
  id,
  club_id,
  slug,
  display_name,
  status,
  venue_type,
  address_line,
  city,
  country_code,
  timezone,
  approved_public_profile,
  public_summary,
  checkin_radius_meters
) on public.venues to anon, authenticated;
grant select (
  id,
  club_id,
  venue_id,
  user_id,
  status,
  location_verification_status,
  location_accuracy_meters,
  fet_awarded,
  reviewed_at,
  review_reason,
  checked_in_at,
  created_at
) on public.venue_checkins to authenticated;
grant select (
  id,
  club_id,
  venue_id,
  item_name,
  description,
  price_amount,
  currency_code,
  is_active,
  is_alcohol,
  sort_order,
  updated_at
) on public.venue_drink_items to authenticated;
grant select (
  id,
  club_id,
  venue_id,
  checkin_id,
  user_id,
  status,
  total_amount,
  currency_code,
  payment_status,
  age_gate_confirmed,
  created_at,
  updated_at
) on public.venue_drink_orders to authenticated;
grant all privileges on table public.venues,
  public.venue_checkins,
  public.venue_drink_items,
  public.venue_drink_orders
  to service_role;

-- Admin context is readable only through the user's own role row or a scoped
-- admin policy. Notification mutations continue through the server workflow.
revoke all privileges on table public.admin_role_assignments,
  public.admin_audit_log,
  public.notifications
  from public, anon, authenticated;
grant select (
  id,
  user_id,
  role,
  club_id,
  partner_scope_id,
  granted_by,
  granted_at,
  is_active
) on public.admin_role_assignments to authenticated;
grant select (
  id,
  action,
  entity_type,
  entity_id,
  metadata,
  created_at,
  club_id
) on public.admin_audit_log to authenticated;
grant select (
  id,
  title,
  body,
  audience_type,
  audience_tier,
  audience_group_name,
  delivery_mode,
  status,
  scheduled_at,
  sent_at,
  requested_recipient_count,
  sent_count,
  failed_count,
  created_at,
  club_id
) on public.notifications to authenticated;
grant all privileges on table public.admin_role_assignments,
  public.admin_audit_log,
  public.notifications
  to service_role;

drop policy if exists admin_role_assignments_select_policy
  on public.admin_role_assignments;
drop policy if exists admin_roles_select on public.admin_role_assignments;
create policy admin_role_assignments_own_or_super_read
  on public.admin_role_assignments
  for select
  to authenticated
  using (user_id = (select auth.uid()) or public.is_super_admin());

drop policy if exists "Admins can read audit log" on public.admin_audit_log;
drop policy if exists admin_audit_log_scoped_read on public.admin_audit_log;
create policy admin_audit_log_scoped_read
  on public.admin_audit_log
  for select
  to authenticated
  using (
    public.is_super_admin()
    or (
      club_id is not null
      and club_id::text = public.requesting_club_id()
      and public.is_club_admin(club_id)
    )
  );

drop policy if exists rs_notifications_admin on public.notifications;

-- Canonical fan-club chapters. The client uses this table directly; images are
-- excluded until a per-record rights/provenance contract exists.
revoke all privileges on table public.fan_clubs
  from public, anon, authenticated;
grant select (
  id,
  partner_id,
  name,
  region,
  description,
  member_count,
  event_count,
  rating,
  banner_emoji,
  club_id,
  is_active,
  created_at,
  updated_at
) on public.fan_clubs to anon, authenticated;
grant all privileges on table public.fan_clubs to service_role;
drop policy if exists fan_clubs_public_read on public.fan_clubs;
drop policy if exists fan_clubs_select_club on public.fan_clubs;
drop policy if exists rs_fan_clubs_select_authenticated on public.fan_clubs;
create policy fan_clubs_public_active_read
  on public.fan_clubs
  for select
  to anon, authenticated
  using (is_active is true);

-- Platform feature configuration is an admin-only base-table surface. Runtime
-- consumers continue through get_platform_config(). Store-review assertions in
-- rollout_rules can be set only by service-role operational tooling.
revoke all privileges on table public.platform_features,
  public.platform_feature_channels,
  public.platform_feature_rules,
  public.platform_content_blocks,
  public.platform_feature_audit_logs
  from public, anon, authenticated;
grant select, insert, update, delete on table public.platform_features,
  public.platform_feature_channels,
  public.platform_feature_rules,
  public.platform_content_blocks
  to authenticated;
grant select on table public.platform_feature_audit_logs to authenticated;
grant all privileges on table public.platform_features,
  public.platform_feature_channels,
  public.platform_feature_rules,
  public.platform_content_blocks,
  public.platform_feature_audit_logs
  to service_role;

-- Option sets are consumed only by the governed admin registry in the current
-- release. Remove the inherited anonymous raw-table surface.
revoke all privileges on table public.platform_option_sets,
  public.platform_option_values
  from public, anon, authenticated;
grant select, insert, update, delete on table public.platform_option_sets,
  public.platform_option_values
  to authenticated;
grant all privileges on table public.platform_option_sets,
  public.platform_option_values
  to service_role;
drop policy if exists platform_option_sets_select_runtime
  on public.platform_option_sets;
drop policy if exists platform_option_values_select_runtime
  on public.platform_option_values;

create or replace function public.enforce_store_release_rule_authority()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  sensitive_keys constant text[] := array[
    'store_release_authorized',
    'stakes_have_no_real_world_value',
    'contest_rules_approved',
    'rewards_have_no_real_world_value',
    'rewards_catalog_approved',
    'terms_acceptance_enabled',
    'content_filtering_enabled',
    'reporting_enabled',
    'blocking_enabled',
    'moderation_operations_approved',
    'store_billing_authorized'
  ];
  key text;
begin
  if auth.role() = 'service_role' then
    return new;
  end if;

  foreach key in array sensitive_keys loop
    if coalesce((new.rollout_rules ->> key)::boolean, false) then
      raise exception using
        errcode = '42501',
        message = 'Store-release approval rules require service-role authority';
    end if;
  end loop;

  return new;
exception
  when invalid_text_representation then
    raise exception using
      errcode = '22023',
      message = 'Store-release approval rules must be boolean values';
end;
$$;

revoke all on function public.enforce_store_release_rule_authority()
  from public, anon, authenticated, service_role;

drop trigger if exists enforce_store_release_rule_authority
  on public.platform_feature_rules;
create trigger enforce_store_release_rule_authority
before insert or update of rollout_rules on public.platform_feature_rules
for each row execute function public.enforce_store_release_rule_authority();
