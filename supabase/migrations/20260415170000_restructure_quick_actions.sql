-- Restructure quick_actions: consolidate to 5 core shortcuts.
-- Groups, Predict, Tickets, Shop, Members.
-- "Predict" merges old predict + my_picks + live.
-- Leaderboard is now accessible via the stats-row "RANK" tap.

-- Deactivate retired quick actions.
UPDATE public.quick_actions
SET is_active = false, updated_at = now()
WHERE action_key IN ('my_picks', 'live', 'leaderboard', 'wallet');

-- Upsert the canonical 5 quick actions.
INSERT INTO public.quick_actions (
  action_key, title, subtitle, emoji, icon_key, route, country, sort_order, is_active
)
VALUES
  ('groups',   'Groups',   'Savings & fundraising',         '🤝', 'groups',     '/contribute', NULL, 10, true),
  ('predict',  'Predict',  'Fixtures, picks & live',        '⚽', 'predict',    '/fanzone',    NULL, 20, true),
  ('tickets',  'Tickets',  'Match access',                  '🎟️', 'tickets',    '/tickets',    NULL, 30, true),
  ('shop',     'Shop',     'Rewards & merchandise',         '🛍️', 'shop',       '/shop',       NULL, 40, true),
  ('members',  'Members',  'Club supporters',               '👥', 'members',    '/membership', NULL, 50, true)
ON CONFLICT (action_key) DO UPDATE
SET
  title      = EXCLUDED.title,
  subtitle   = EXCLUDED.subtitle,
  emoji      = EXCLUDED.emoji,
  icon_key   = EXCLUDED.icon_key,
  route      = EXCLUDED.route,
  country    = EXCLUDED.country,
  sort_order = EXCLUDED.sort_order,
  is_active  = EXCLUDED.is_active,
  updated_at = now();
