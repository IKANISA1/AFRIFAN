-- Backfill missing feature registry defaults for notifications and campaigns.
-- Production drift showed these seeds were absent even though server guards and
-- public composition already depend on them.

INSERT INTO public.platform_features
  (feature_key, display_name, description, category, club_id, is_enabled, visibility_state)
VALUES
  ('notifications', 'Notifications', 'Push notifications and outbound alert surfaces', 'operations', NULL, true, 'visible'),
  ('campaigns', 'Campaigns', 'Campaign, promo, and banner-led marketing blocks', 'marketing', NULL, true, 'visible')
ON CONFLICT DO NOTHING;

INSERT INTO public.platform_feature_channels
  (feature_id, channel, is_enabled, is_visible, show_in_navigation, show_on_home, sort_order, route_key, placement_key)
SELECT
  pf.id,
  'web',
  true,
  true,
  false,
  CASE pf.feature_key
    WHEN 'campaigns' THEN true
    ELSE false
  END,
  CASE pf.feature_key
    WHEN 'campaigns' THEN 65
    ELSE 500
  END,
  NULL,
  CASE pf.feature_key
    WHEN 'campaigns' THEN 'home_top'
    ELSE NULL
  END
FROM public.platform_features pf
WHERE pf.club_id IS NULL
  AND pf.feature_key IN ('notifications', 'campaigns')
ON CONFLICT (feature_id, channel) DO NOTHING;

INSERT INTO public.platform_feature_channels
  (feature_id, channel, is_enabled, is_visible, show_in_navigation, show_on_home, sort_order, route_key, placement_key)
SELECT
  pf.id,
  'mobile',
  true,
  true,
  false,
  CASE pf.feature_key
    WHEN 'notifications' THEN true
    WHEN 'campaigns' THEN true
    ELSE false
  END,
  CASE pf.feature_key
    WHEN 'notifications' THEN 120
    WHEN 'campaigns' THEN 130
    ELSE 500
  END,
  NULL,
  CASE pf.feature_key
    WHEN 'notifications' THEN 'home_bottom'
    WHEN 'campaigns' THEN 'home_top'
    ELSE NULL
  END
FROM public.platform_features pf
WHERE pf.club_id IS NULL
  AND pf.feature_key IN ('notifications', 'campaigns')
ON CONFLICT (feature_id, channel) DO NOTHING;

INSERT INTO public.platform_feature_rules
  (feature_id, auth_required, role_restrictions, dependency_rules, rollout_rules)
SELECT
  pf.id,
  CASE pf.feature_key
    WHEN 'notifications' THEN true
    ELSE false
  END,
  '[]'::jsonb,
  '{}'::jsonb,
  '{}'::jsonb
FROM public.platform_features pf
WHERE pf.club_id IS NULL
  AND pf.feature_key IN ('notifications', 'campaigns')
ON CONFLICT (feature_id) DO NOTHING;

INSERT INTO public.platform_content_blocks
  (block_key, block_type, title, subtitle, content, target_channel, placement_key, feature_id, club_id, is_active, sort_order)
VALUES
  (
    'web_home_campaign_banner',
    'banner',
    'Campaign Banner',
    NULL,
    '{"component": "hero-block", "variant": "campaign"}'::jsonb,
    'web',
    'home_top',
    (SELECT id FROM public.platform_features WHERE feature_key = 'campaigns' AND club_id IS NULL),
    NULL,
    true,
    15
  )
ON CONFLICT DO NOTHING;
