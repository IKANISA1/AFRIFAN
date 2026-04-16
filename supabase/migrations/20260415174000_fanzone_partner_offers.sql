-- FANZONE partner offers catalog + public read model.
-- Restores the dedicated "Offers" quick action as a partner-earnings surface
-- without duplicating the canonical FET catalog definitions.

insert into public.partners (
  slug,
  name,
  category,
  country,
  emoji,
  subtitle,
  description,
  is_active,
  sort_order,
  gamification_enabled,
  brand_primary_color,
  brand_secondary_color,
  metadata
)
values
  (
    'skol',
    'Skol',
    'organization',
    'RW',
    '🍺',
    'Matchday venue activations',
    'Official beverage partner for venue orders, fan zone check-ins, and matchday supporter experiences.',
    true,
    60,
    true,
    '#F6C343',
    '#1B1B1B',
    jsonb_build_object(
      'service_domain', 'matchday_fnb',
      'activation_mode', 'partner_offer',
      'supported_countries', jsonb_build_array('RW')
    )
  ),
  (
    'rayon-shop',
    'Rayon Shop',
    'organization',
    'RW',
    '👕',
    'Official club merchandise',
    'Official merchandise storefront for kits, fanwear, and campaign drops tied to FANZONE rewards.',
    true,
    70,
    true,
    '#0038A8',
    '#D9B24C',
    jsonb_build_object(
      'service_domain', 'merchandise',
      'activation_mode', 'partner_offer',
      'supported_countries', jsonb_build_array('RW')
    )
  )
on conflict (slug) do update
set
  name = excluded.name,
  category = excluded.category,
  country = excluded.country,
  emoji = excluded.emoji,
  subtitle = excluded.subtitle,
  description = excluded.description,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order,
  gamification_enabled = excluded.gamification_enabled,
  brand_primary_color = excluded.brand_primary_color,
  brand_secondary_color = excluded.brand_secondary_color,
  metadata = excluded.metadata,
  updated_at = now();

create table if not exists public.fet_partner_offers (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  catalog_item_id uuid not null references public.fan_engagement_token_catalog(id) on delete cascade,
  partner_id uuid not null references public.partners(id) on delete restrict,
  service_slug text,
  subtitle text,
  cta_label text not null default 'View details',
  verification_mode text not null default 'manual_review',
  deeplink_route text,
  external_url text,
  is_featured boolean not null default false,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fet_partner_offers_catalog_item_id_key unique (catalog_item_id),
  constraint fet_partner_offers_sort_order_check check (sort_order >= 0),
  constraint fet_partner_offers_verification_mode_check check (
    verification_mode = any (
      array[
        'api_confirmation'::text,
        'renewal_confirmation'::text,
        'referral_conversion'::text,
        'receipt_scan'::text,
        'geo_checkin'::text,
        'social_share'::text,
        'community_savings'::text,
        'ecommerce_confirmation'::text,
        'mobility_confirmation'::text,
        'event_qr'::text,
        'manual_review'::text
      ]
    )
  )
);

create index if not exists idx_fet_partner_offers_club_active_sort
  on public.fet_partner_offers (club_id, is_active, sort_order);

drop trigger if exists fet_partner_offers_set_updated_at
  on public.fet_partner_offers;

create trigger fet_partner_offers_set_updated_at
before update on public.fet_partner_offers
for each row execute function public.set_updated_at();

alter table public.fet_partner_offers enable row level security;

drop policy if exists fet_partner_offers_select_active
  on public.fet_partner_offers;
create policy fet_partner_offers_select_active
on public.fet_partner_offers
for select
using (
  is_active = true
  and club_id::text = public.requesting_club_id()
);

drop policy if exists fet_partner_offers_admin_all
  on public.fet_partner_offers;
create policy fet_partner_offers_admin_all
on public.fet_partner_offers
to authenticated
using (
  club_id::text = public.requesting_club_id()
  and public.is_club_admin(club_id)
)
with check (
  club_id::text = public.requesting_club_id()
  and public.is_club_admin(club_id)
);

create or replace function public.fet_get_partner_offers(
  p_club_id bigint default null::bigint,
  p_include_inactive boolean default false,
  p_limit integer default 500
) returns table(
  id uuid,
  club_id bigint,
  catalog_item_id uuid,
  code text,
  partner_id uuid,
  partner_slug text,
  partner_name text,
  partner_emoji text,
  partner_category text,
  partner_subtitle text,
  partner_brand_primary_color text,
  partner_brand_secondary_color text,
  title text,
  subtitle text,
  fet_value integer,
  trigger_condition text,
  activation_timing text,
  description text,
  badge_name text,
  cta_label text,
  verification_mode text,
  deeplink_route text,
  external_url text,
  is_featured boolean,
  is_active boolean,
  sort_order integer,
  metadata jsonb
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_club_id bigint;
  v_limit integer := greatest(coalesce(p_limit, 50), 1);
begin
  v_club_id := public.fet_resolve_public_club_id(p_club_id);
  if v_club_id is null then
    return;
  end if;

  return query
  select
    offer.id,
    offer.club_id,
    offer.catalog_item_id,
    catalog.code,
    offer.partner_id,
    partner.slug as partner_slug,
    partner.name as partner_name,
    partner.emoji as partner_emoji,
    partner.category as partner_category,
    partner.subtitle as partner_subtitle,
    partner.brand_primary_color as partner_brand_primary_color,
    partner.brand_secondary_color as partner_brand_secondary_color,
    catalog.item_name as title,
    coalesce(
      nullif(btrim(offer.subtitle), ''),
      nullif(btrim(partner.subtitle), ''),
      nullif(btrim(catalog.activation_timing), ''),
      'Partner offer'
    ) as subtitle,
    catalog.fet_value,
    catalog.trigger_condition,
    catalog.activation_timing,
    catalog.description,
    nullif(btrim(catalog.badge_name), '') as badge_name,
    offer.cta_label,
    offer.verification_mode,
    offer.deeplink_route,
    offer.external_url,
    offer.is_featured,
    offer.is_active,
    offer.sort_order,
    jsonb_strip_nulls(
      coalesce(offer.metadata, '{}'::jsonb)
      || jsonb_build_object(
        'partner_website_url', nullif(btrim(coalesce(partner.website_url, '')), ''),
        'partner_banner_url', nullif(btrim(coalesce(partner.banner_url, '')), '')
      )
    ) as metadata
  from public.fet_partner_offers as offer
  join public.fan_engagement_token_catalog as catalog
    on catalog.id = offer.catalog_item_id
  join public.partners as partner
    on partner.id = offer.partner_id
  where offer.club_id = v_club_id
    and catalog.club_id = v_club_id
    and partner.is_active = true
    and (p_include_inactive or offer.is_active = true)
  order by
    offer.is_featured desc,
    offer.sort_order asc,
    catalog.fet_value desc,
    catalog.code asc
  limit v_limit;
end;
$$;

grant execute on function public.fet_get_partner_offers(bigint, boolean, integer)
  to anon;
grant execute on function public.fet_get_partner_offers(bigint, boolean, integer)
  to authenticated;
grant execute on function public.fet_get_partner_offers(bigint, boolean, integer)
  to service_role;

do $fet_partner_offer_seed$
declare
  v_rayon_club_id bigint;
begin
  select afc.id
    into v_rayon_club_id
  from public.african_football_clubs as afc
  where lower(regexp_replace(coalesce(afc.club_slug, ''), '[^a-z0-9]+', '', 'g'))
          in ('rayonsportsrw', 'rayonsports')
     or lower(regexp_replace(coalesce(afc.club_name, ''), '[^a-z0-9]+', '', 'g'))
          in ('rayonsportsfc', 'rayonsports')
  order by
    case when afc.club_slug = 'rayon_sports_rw' then 0 else 1 end,
    afc.id asc
  limit 1;

  if v_rayon_club_id is null then
    raise notice 'Skipping partner offers seed because Rayon Sports could not be resolved.';
    return;
  end if;

  with offer_seed as (
    select *
    from (
      values
        (
          'G061',
          'radiant-insurance',
          'insurance-policy',
          'Protection converted into premium FET once policy binding is confirmed.',
          'View policy steps',
          'api_confirmation',
          null,
          null,
          true,
          10,
          jsonb_build_object(
            'campaign_kind', 'insurance',
            'tracking_hint', 'Policy binding confirmation from insurer API',
            'reward_window', 'year_round'
          )
        ),
        (
          'G062',
          'radiant-insurance',
          'insurance-renewal',
          'Retention offer that unlocks when renewal season opens.',
          'Review renewal path',
          'renewal_confirmation',
          null,
          null,
          true,
          20,
          jsonb_build_object(
            'campaign_kind', 'insurance',
            'tracking_hint', 'Policy renewal confirmation before expiry',
            'reward_window', '30_days_before_expiry'
          )
        ),
        (
          'G063',
          'radiant-insurance',
          'insurance-referral',
          'Invite another supporter and collect FET when their policy is activated.',
          'See referral rules',
          'referral_conversion',
          null,
          null,
          false,
          30,
          jsonb_build_object(
            'campaign_kind', 'referral',
            'tracking_hint', 'Referred friend policy conversion',
            'reward_window', 'year_round'
          )
        ),
        (
          'G064',
          'skol',
          'matchday-order',
          'Venue spend offer for supporters ordering during the matchday window.',
          'Matchday details',
          'receipt_scan',
          null,
          null,
          false,
          40,
          jsonb_build_object(
            'campaign_kind', 'matchday_fnb',
            'tracking_hint', 'POS integration or QR receipt scan at partner venue'
          )
        ),
        (
          'G065',
          'skol',
          'squad-round',
          'Group-spend activation designed for squads arriving together.',
          'Squad activation',
          'receipt_scan',
          null,
          null,
          true,
          50,
          jsonb_build_object(
            'campaign_kind', 'matchday_fnb',
            'tracking_hint', 'Receipt QR scan or in-app partner payment'
          )
        ),
        (
          'G066',
          'skol',
          'fan-zone-checkin',
          'Physical-space reward tied to official Skol fan zones and branded events.',
          'Check-in details',
          'geo_checkin',
          null,
          null,
          false,
          60,
          jsonb_build_object(
            'campaign_kind', 'geo_activation',
            'tracking_hint', 'Geofenced check-in at official Skol fan zone'
          )
        ),
        (
          'G067',
          'skol',
          'photo-challenge',
          'UGC activation that turns a matchday post into a partner earn moment.',
          'Content rules',
          'social_share',
          null,
          null,
          false,
          70,
          jsonb_build_object(
            'campaign_kind', 'ugc',
            'tracking_hint', 'Social share with partner tag and club hashtag'
          )
        ),
        (
          'G068',
          'cool',
          'create-group-saving',
          'Launch a high-value group savings pot and unlock a banking conversion reward.',
          'Open savings flow',
          'community_savings',
          '/contribute',
          null,
          true,
          80,
          jsonb_build_object(
            'campaign_kind', 'group_savings',
            'tracking_hint', 'Account opening and savings threshold confirmation'
          )
        ),
        (
          'G069',
          'cool',
          'join-group-saving',
          'Low-friction entry offer for fans joining an existing savings Group.',
          'Join savings',
          'community_savings',
          '/contribute',
          null,
          false,
          90,
          jsonb_build_object(
            'campaign_kind', 'group_savings',
            'tracking_hint', 'Membership join plus minimum contribution confirmation'
          )
        ),
        (
          'G070',
          'cool',
          'share-cool',
          'Spread the community savings product and earn from referral-style adoption.',
          'Share campaign',
          'community_savings',
          '/contribute',
          null,
          false,
          100,
          jsonb_build_object(
            'campaign_kind', 'referral',
            'tracking_hint', 'Savings goal activation via partner API'
          )
        ),
        (
          'G071',
          'rayon-shop',
          'official-kit',
          'Merch launch offer tied to official home and away kit purchases.',
          'Open shop',
          'ecommerce_confirmation',
          '/shop',
          null,
          true,
          110,
          jsonb_build_object(
            'campaign_kind', 'merchandise',
            'tracking_hint', 'Official e-commerce purchase confirmation'
          )
        ),
        (
          'G072',
          'mobio',
          'ride-to-match',
          'Mobility reward that activates in the run-up to kickoff.',
          'Ride activation',
          'mobility_confirmation',
          null,
          null,
          false,
          120,
          jsonb_build_object(
            'campaign_kind', 'mobility',
            'tracking_hint', 'Ride completion confirmation from mobility partner'
          )
        ),
        (
          'G073',
          'mobio',
          'shared-ride',
          'Carpool-style reward for supporters moving together on matchday.',
          'Shared ride rules',
          'mobility_confirmation',
          null,
          null,
          false,
          130,
          jsonb_build_object(
            'campaign_kind', 'mobility',
            'tracking_hint', 'Shared ride confirmation with two or more supporters'
          )
        ),
        (
          'G074',
          'skol',
          'partner-event',
          'Premium pre-match partner experiences with event check-in and hospitality upside.',
          'Event details',
          'event_qr',
          null,
          null,
          true,
          140,
          jsonb_build_object(
            'campaign_kind', 'partner_event',
            'tracking_hint', 'Official event QR code check-in'
          )
        )
    ) as seeded(
      code,
      partner_slug,
      service_slug,
      subtitle,
      cta_label,
      verification_mode,
      deeplink_route,
      external_url,
      is_featured,
      sort_order,
      metadata
    )
  )
  insert into public.fet_partner_offers (
    club_id,
    catalog_item_id,
    partner_id,
    service_slug,
    subtitle,
    cta_label,
    verification_mode,
    deeplink_route,
    external_url,
    is_featured,
    is_active,
    sort_order,
    metadata
  )
  select
    catalog.club_id,
    catalog.id,
    partner.id,
    seed.service_slug,
    seed.subtitle,
    seed.cta_label,
    seed.verification_mode,
    seed.deeplink_route,
    seed.external_url,
    seed.is_featured,
    true,
    seed.sort_order,
    seed.metadata
  from offer_seed as seed
  join public.fan_engagement_token_catalog as catalog
    on catalog.code = seed.code
   and catalog.club_id = v_rayon_club_id
   and catalog.category = 'Partner'
  join public.partners as partner
    on partner.slug = seed.partner_slug
  on conflict (catalog_item_id) do update
  set
    club_id = excluded.club_id,
    partner_id = excluded.partner_id,
    service_slug = excluded.service_slug,
    subtitle = excluded.subtitle,
    cta_label = excluded.cta_label,
    verification_mode = excluded.verification_mode,
    deeplink_route = excluded.deeplink_route,
    external_url = excluded.external_url,
    is_featured = excluded.is_featured,
    is_active = excluded.is_active,
    sort_order = excluded.sort_order,
    metadata = excluded.metadata,
    updated_at = now();
end;
$fet_partner_offer_seed$;

insert into public.quick_actions (
  action_key,
  title,
  subtitle,
  emoji,
  icon_key,
  route,
  country,
  sort_order,
  is_active
)
values
  (
    'offers',
    'Offers',
    'Earn FET with partners',
    '🎁',
    'offers',
    '/fanzone/offers',
    null,
    60,
    true
  )
on conflict (action_key) do update
set
  title = excluded.title,
  subtitle = excluded.subtitle,
  emoji = excluded.emoji,
  icon_key = excluded.icon_key,
  route = excluded.route,
  country = excluded.country,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  updated_at = now();
