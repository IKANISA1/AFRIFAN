-- Gikundiro.com (Rayon Sports) - Phase 1 Remediation
-- Fixes critical content completeness and unrealistic shop pricing gaps identified in audit.
-- Also ensures key features are enabled for the web navigation.

begin;

-- Find Rayon Sports club ID
do $$
declare
  rayon_id bigint;
begin
  select id into rayon_id
  from public.african_football_clubs
  where club_name ilike '%Rayon Sports FC%' or club_slug = 'rayon_sports_rw'
  limit 1;

  if rayon_id is null then
    raise notice 'Rayon Sports FC not found, skipping remediation.';
    return;
  end if;

  -- 1. Correct Shop Product Prices & Currency (Critical)
  update public.shop_products
  set 
    price = 35000, 
    currency = 'RWF', 
    name = '2026 Home Replica Jersey',
    subtitle = 'Matchday fit, club crest embroidery, breathable knit.',
    description = 'Official Rayon Sports replica built for matchdays and supporter travel. Includes woven crest, sponsor print, and a premium finish.'
  where club_id = rayon_id and (name ilike '%KINETIC HOME%' or name ilike '%Jersey%');

  update public.shop_products
  set 
    price = 42000, 
    currency = 'RWF',
    name = 'Blue Travel Hoodie',
    subtitle = 'Heavyweight fleece with a tonal crest hit.',
    description = 'Supporter travel layer with a clean front mark and a wide cut for cooler evening kickoffs.'
  where club_id = rayon_id and (name ilike '%STEALTH JACKET%' or name ilike '%Hoodie%');

  update public.shop_products
  set 
    price = 12000, 
    currency = 'RWF',
    name = 'Rayon Sports Matchday Scarf',
    subtitle = 'Stadium knit in blue, white, and gold.',
    description = 'A supporter staple for derby days, cup nights, and away sections.'
  where club_id = rayon_id and (name ilike '%GOLD CREST SCARF%' or name ilike '%Scarf%');

  -- 2. Correct News Article Bodies (Critical)
  update public.news_articles
  set
    title = 'The Blue Wall: Preparing for Matchday at the Cathedral',
    subtitle = 'Witness the mobilization of Rwanda''s most passionate fanbase as we prepare for the headline clash against Police FC.',
    body = 'Rayon Sports FC is finalizing a world-class matchday experience for our supporters. From the choreographed Blue Wall tifo to enhanced hospitality in the Platinum Lounge, every detail is being refined to ensure matchday remains the heartbeat of Rwandan football. Gates open at 14:00. Arrive early, wear your colors, and be the twelfth man.'
  where club_id = rayon_id and (title ilike '%TRANSFER WINDOW%' or title ilike '%Blue Wall%');

  update public.news_articles
  set
    title = 'Digital Fan Identity: Your Portal to the Beloved',
    subtitle = 'Manage your membership, secure priority tickets, and join Support Circles through our new integrated digital platform.',
    body = 'Being a member of Rayon Sports is more than just a ticket—it''s a digital-first identity. Our new fan portal allows supporters across Rwanda and the diaspora to manage their tiers, earn FET tokens, and fund community projects through Support Circles. Your fan card is now live in the supporter app. Access the future of fan engagement today.'
  where club_id = rayon_id and (title ilike '%MATCH DAY%' or title ilike '%Fan Identity%');

  update public.news_articles
  set
    title = 'The 2026 Heritage Collection: Out Now',
    subtitle = 'The new home kit has arrived. A tribute to our 50-year legacy, built for the modern supporter.',
    body = 'Our 2026 Heritage Collection is officially live. Featuring the iconic cobalt blue with gold accents, the new home replica jersey combines breathable performance fabrics with the prestige of the Gikundiro crest. Available now in the official shop and selected retail partners across Kigali. Own the colors. Own the history.'
  where club_id = rayon_id and (title ilike '%YOUTH ACADEMY%' or title ilike '%Heritage Collection%');

  -- 3. Enable missing global features (squad, news) if they don't exist
  insert into public.platform_features (feature_key, display_name, category, is_enabled, visibility_state)
  values 
    ('news', 'News', 'core', true, 'visible'),
    ('squad', 'Squad', 'core', true, 'visible')
  on conflict (feature_key) where club_id is null do nothing;

  -- 4. Enable Features for Web Navigation for Rayon Sports (High)
  -- This ensures the persistent nav bar actually shows the items.
  with rayon_features as (
    select pf.id, pf.feature_key
    from public.platform_features pf
    where pf.club_id is null or pf.club_id = rayon_id
  )
  insert into public.platform_feature_channels (feature_id, channel, is_enabled, is_visible, show_in_navigation, show_on_home, sort_order)
  select 
    rf.id, 
    'web', 
    true, 
    true, 
    true, 
    true,
    case rf.feature_key
      when 'live' then 10
      when 'news' then 20
      when 'squad' then 30
      when 'ticketing' then 40
      when 'membership' then 50
      when 'contributions' then 60
      when 'shop' then 70
      else 100
    end
  from rayon_features rf
  where rf.feature_key in ('live', 'news', 'squad', 'ticketing', 'membership', 'contributions', 'shop')
  on conflict (feature_id, channel) do update set
    is_enabled = true,
    is_visible = true,
    show_in_navigation = true,
    show_on_home = true;

  raise notice 'Remediated content, pricing, and feature navigation for Rayon Sports FC (club_id=%)', rayon_id;
end $$;

commit;
