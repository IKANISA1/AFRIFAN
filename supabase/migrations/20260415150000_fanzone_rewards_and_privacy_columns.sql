-- Migration: Create fet_reward_store_items table + add privacy columns on profiles
-- Timestamp: 20260415150000
-- Purpose: P1-9 (Rewards store DB — replaces bundled JSON) + P3-13 (Privacy toggle sync)

-- ═══════════════════════════════════════════════════════════════════
-- 1. Privacy toggle columns on profiles
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS favorite_team_slug text,
  ADD COLUMN IF NOT EXISTS privacy_show_real_name boolean DEFAULT false NOT NULL,
  ADD COLUMN IF NOT EXISTS privacy_findable_by_phone boolean DEFAULT false NOT NULL;

COMMENT ON COLUMN public.profiles.favorite_team_slug
  IS 'Preferred football team slug selected during onboarding/profile setup.';
COMMENT ON COLUMN public.profiles.privacy_show_real_name
  IS 'If true, real name is displayed on leaderboards instead of Fan ID.';
COMMENT ON COLUMN public.profiles.privacy_findable_by_phone
  IS 'If true, friends can find the user by phone number. Number stays private.';

-- ═══════════════════════════════════════════════════════════════════
-- 2. Reward Store Items table (matches existing Flutter code's
--    expected table name: `fet_reward_store_items`)
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.fet_reward_store_items (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  reward text NOT NULL,
  cost_fet integer NOT NULL DEFAULT 0,
  cost_label text NOT NULL DEFAULT '0 FET',
  category text NOT NULL DEFAULT 'Utility',
  notes text DEFAULT '',
  emoji text DEFAULT '🎁',
  is_active boolean DEFAULT true NOT NULL,
  sort_order integer DEFAULT 0 NOT NULL,
  club_id bigint,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  CONSTRAINT fet_reward_store_items_cost_positive CHECK (cost_fet >= 0)
);

COMMENT ON TABLE public.fet_reward_store_items
  IS 'Dynamic rewards catalog for the FANZONE reward store. Replaces bundled reward_store_catalog.json.';

-- Enable RLS
ALTER TABLE public.fet_reward_store_items ENABLE ROW LEVEL SECURITY;

-- Public read for active rewards
CREATE POLICY "Anyone can read active reward items"
  ON public.fet_reward_store_items
  FOR SELECT
  USING (is_active = true);

-- Admin-only write
CREATE POLICY "Admins can manage reward items"
  ON public.fet_reward_store_items
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.is_admin = true
    )
  );

-- ═══════════════════════════════════════════════════════════════════
-- 3. Seed rewards from the former JSON catalog
-- ═══════════════════════════════════════════════════════════════════

INSERT INTO public.fet_reward_store_items (reward, cost_fet, cost_label, category, notes, emoji, sort_order)
VALUES
  ('Mobile Airtime', 500, '500 FET', 'Utility', 'Via MoMo API integration', '📱', 1),
  ('FANZONE Premium Badge', 200, '200 FET', 'Cosmetic', 'Profile badge unlock', '🏅', 2),
  ('Jackpot Extra Entry', 100, '100 FET', 'Gameplay', 'Second entry in the weekly round', '🎰', 3),
  ('Custom Avatar Frame', 150, '150 FET', 'Cosmetic', 'Seasonal themed frame', '🖼️', 4),
  ('Club Fan Kit Digital Item', 300, '300 FET', 'Collectible', 'AFRICLUB-linked digital item', '⚽', 5),
  ('Partner Voucher', 1000, '1000 FET', 'Utility', 'Restaurant or retail partner reward', '🎟️', 6)
ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════
-- Rollback (manual):
--   ALTER TABLE public.profiles DROP COLUMN IF EXISTS favorite_team_slug;
--   ALTER TABLE public.profiles DROP COLUMN IF EXISTS privacy_show_real_name;
--   ALTER TABLE public.profiles DROP COLUMN IF EXISTS privacy_findable_by_phone;
--   DROP TABLE IF EXISTS public.fet_reward_store_items;
-- ═══════════════════════════════════════════════════════════════════
