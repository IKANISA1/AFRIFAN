-- ============================================================================
-- Platform Feature Management System
-- ============================================================================
-- Transforms hardcoded ClubConfig feature flags into a centrally managed,
-- admin-controlled, channel-aware, auditable feature registry.
--
-- Tables:
--   1. platform_features          – central feature registry (club-scoped)
--   2. platform_feature_channels  – per-channel (mobile/web) config
--   3. platform_feature_rules     – auth, role, schedule, dependency rules
--   4. platform_content_blocks    – admin-managed homepage/banner/promo blocks
--   5. platform_feature_audit_logs – feature-specific change tracking
--
-- Conventions:
--   - club_id NULL = global default for all clubs
--   - club-specific rows override global rows (resolved in RPC)
--   - Reuses existing is_admin_user(), log_admin_mutation(), set_updated_at()
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────────
-- 1. platform_features
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.platform_features (
  id         uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  feature_key text       NOT NULL,
  display_name text      NOT NULL,
  description text,
  category   text,
  club_id    bigint      REFERENCES public.african_football_clubs(id) ON DELETE CASCADE,
  is_enabled boolean     NOT NULL DEFAULT true,
  visibility_state text  NOT NULL DEFAULT 'visible'
    CHECK (visibility_state IN ('visible', 'hidden', 'maintenance')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(feature_key, club_id)
);

COMMENT ON TABLE public.platform_features IS
  'Central feature registry. club_id NULL = global default; specific club_id = override.';

-- Handle NULL UNIQUE properly: create a partial unique index for global features
CREATE UNIQUE INDEX idx_platform_features_global_unique
  ON public.platform_features (feature_key) WHERE club_id IS NULL;

CREATE INDEX idx_platform_features_club
  ON public.platform_features (club_id) WHERE club_id IS NOT NULL;

CREATE INDEX idx_platform_features_category
  ON public.platform_features (category);

-- ──────────────────────────────────────────────────────────────────────────────
-- 2. platform_feature_channels
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.platform_feature_channels (
  id         uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  feature_id uuid        NOT NULL REFERENCES public.platform_features(id) ON DELETE CASCADE,
  channel    text        NOT NULL CHECK (channel IN ('mobile', 'web')),
  is_enabled boolean     NOT NULL DEFAULT true,
  is_visible boolean     NOT NULL DEFAULT true,
  show_in_navigation boolean NOT NULL DEFAULT false,
  show_on_home boolean   NOT NULL DEFAULT false,
  sort_order integer,
  route_key  text,
  placement_key text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(feature_id, channel)
);

COMMENT ON TABLE public.platform_feature_channels IS
  'Per-channel (mobile/web) configuration for each feature.';

CREATE INDEX idx_platform_feature_channels_feature
  ON public.platform_feature_channels (feature_id);

-- ──────────────────────────────────────────────────────────────────────────────
-- 3. platform_feature_rules
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.platform_feature_rules (
  id               uuid    DEFAULT gen_random_uuid() PRIMARY KEY,
  feature_id       uuid    NOT NULL REFERENCES public.platform_features(id) ON DELETE CASCADE,
  auth_required    boolean NOT NULL DEFAULT false,
  role_restrictions jsonb  NOT NULL DEFAULT '[]',
  dependency_rules jsonb   NOT NULL DEFAULT '{}',
  rollout_rules    jsonb   NOT NULL DEFAULT '{}',
  schedule_start_at timestamptz,
  schedule_end_at  timestamptz,
  metadata         jsonb   NOT NULL DEFAULT '{}',
  created_at       timestamptz DEFAULT now(),
  updated_at       timestamptz DEFAULT now(),
  UNIQUE(feature_id)
);

COMMENT ON TABLE public.platform_feature_rules IS
  'Auth, role, schedule, and dependency rules per feature.';

-- ──────────────────────────────────────────────────────────────────────────────
-- 4. platform_content_blocks
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.platform_content_blocks (
  id             uuid    DEFAULT gen_random_uuid() PRIMARY KEY,
  block_key      text    UNIQUE NOT NULL,
  block_type     text    NOT NULL,
  title          text,
  subtitle       text,
  content        jsonb   NOT NULL DEFAULT '{}',
  target_channel text    NOT NULL CHECK (target_channel IN ('mobile', 'web', 'both')),
  placement_key  text    NOT NULL,
  feature_id     uuid    REFERENCES public.platform_features(id) ON DELETE SET NULL,
  club_id        bigint  REFERENCES public.african_football_clubs(id) ON DELETE CASCADE,
  is_active      boolean NOT NULL DEFAULT true,
  sort_order     integer,
  metadata       jsonb   NOT NULL DEFAULT '{}',
  created_at     timestamptz DEFAULT now(),
  updated_at     timestamptz DEFAULT now()
);

COMMENT ON TABLE public.platform_content_blocks IS
  'Admin-managed content blocks for homepage sections, banners, quick actions, promos.';

CREATE INDEX idx_platform_content_blocks_placement
  ON public.platform_content_blocks (placement_key, sort_order);

CREATE INDEX idx_platform_content_blocks_feature
  ON public.platform_content_blocks (feature_id) WHERE feature_id IS NOT NULL;

CREATE INDEX idx_platform_content_blocks_active
  ON public.platform_content_blocks (is_active, target_channel);

-- ──────────────────────────────────────────────────────────────────────────────
-- 5. platform_feature_audit_logs
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.platform_feature_audit_logs (
  id           uuid    DEFAULT gen_random_uuid() PRIMARY KEY,
  feature_id   uuid    REFERENCES public.platform_features(id) ON DELETE SET NULL,
  action       text    NOT NULL,
  changed_by   uuid,
  before_state jsonb   NOT NULL DEFAULT '{}',
  after_state  jsonb   NOT NULL DEFAULT '{}',
  created_at   timestamptz DEFAULT now()
);

COMMENT ON TABLE public.platform_feature_audit_logs IS
  'Tracks feature configuration changes: who changed what, when, before/after.';

CREATE INDEX idx_platform_feature_audit_logs_feature
  ON public.platform_feature_audit_logs (feature_id, created_at DESC);

CREATE INDEX idx_platform_feature_audit_logs_actor
  ON public.platform_feature_audit_logs (changed_by) WHERE changed_by IS NOT NULL;

-- ──────────────────────────────────────────────────────────────────────────────
-- Triggers: set_updated_at
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TRIGGER trg_platform_features_updated
  BEFORE UPDATE ON public.platform_features
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_platform_feature_channels_updated
  BEFORE UPDATE ON public.platform_feature_channels
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_platform_feature_rules_updated
  BEFORE UPDATE ON public.platform_feature_rules
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_platform_content_blocks_updated
  BEFORE UPDATE ON public.platform_content_blocks
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ──────────────────────────────────────────────────────────────────────────────
-- Triggers: admin audit via existing log_admin_mutation()
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TRIGGER trg_audit_platform_features
  AFTER INSERT OR DELETE OR UPDATE ON public.platform_features
  FOR EACH ROW EXECUTE FUNCTION public.log_admin_mutation();

CREATE TRIGGER trg_audit_platform_feature_channels
  AFTER INSERT OR DELETE OR UPDATE ON public.platform_feature_channels
  FOR EACH ROW EXECUTE FUNCTION public.log_admin_mutation();

CREATE TRIGGER trg_audit_platform_feature_rules
  AFTER INSERT OR DELETE OR UPDATE ON public.platform_feature_rules
  FOR EACH ROW EXECUTE FUNCTION public.log_admin_mutation();

CREATE TRIGGER trg_audit_platform_content_blocks
  AFTER INSERT OR DELETE OR UPDATE ON public.platform_content_blocks
  FOR EACH ROW EXECUTE FUNCTION public.log_admin_mutation();

-- ──────────────────────────────────────────────────────────────────────────────
-- Custom audit trigger → platform_feature_audit_logs
-- Fires on changes to platform_features and platform_feature_channels
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.log_feature_config_change() RETURNS trigger
  LANGUAGE plpgsql SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE
  v_feature_id uuid;
  v_action text;
  v_before jsonb := '{}'::jsonb;
  v_after  jsonb := '{}'::jsonb;
BEGIN
  -- Derive feature_id from the row
  IF TG_TABLE_NAME = 'platform_features' THEN
    IF TG_OP = 'DELETE' THEN
      v_feature_id := OLD.id;
    ELSE
      v_feature_id := NEW.id;
    END IF;
  ELSIF TG_TABLE_NAME = 'platform_feature_channels' THEN
    IF TG_OP = 'DELETE' THEN
      v_feature_id := OLD.feature_id;
    ELSE
      v_feature_id := NEW.feature_id;
    END IF;
  ELSIF TG_TABLE_NAME = 'platform_feature_rules' THEN
    IF TG_OP = 'DELETE' THEN
      v_feature_id := OLD.feature_id;
    ELSE
      v_feature_id := NEW.feature_id;
    END IF;
  END IF;

  -- Derive action label
  v_action := lower(TG_OP) || '_' || TG_TABLE_NAME;

  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    v_before := to_jsonb(OLD);
  END IF;
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    v_after := to_jsonb(NEW);
  END IF;

  INSERT INTO public.platform_feature_audit_logs (
    feature_id, action, changed_by, before_state, after_state
  ) VALUES (
    v_feature_id, v_action, auth.uid(), v_before, v_after
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_feature_audit_features
  AFTER INSERT OR UPDATE OR DELETE ON public.platform_features
  FOR EACH ROW EXECUTE FUNCTION public.log_feature_config_change();

CREATE TRIGGER trg_feature_audit_channels
  AFTER INSERT OR UPDATE OR DELETE ON public.platform_feature_channels
  FOR EACH ROW EXECUTE FUNCTION public.log_feature_config_change();

CREATE TRIGGER trg_feature_audit_rules
  AFTER INSERT OR UPDATE OR DELETE ON public.platform_feature_rules
  FOR EACH ROW EXECUTE FUNCTION public.log_feature_config_change();

-- ──────────────────────────────────────────────────────────────────────────────
-- RLS: Enable on all tables
-- ──────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.platform_features ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_feature_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_feature_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_content_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_feature_audit_logs ENABLE ROW LEVEL SECURITY;

-- ── platform_features: public read, admin write ──
CREATE POLICY "Public read platform_features"
  ON public.platform_features FOR SELECT USING (true);

CREATE POLICY platform_features_insert_admin
  ON public.platform_features FOR INSERT TO authenticated
  WITH CHECK (public.is_admin_user());

CREATE POLICY platform_features_update_admin
  ON public.platform_features FOR UPDATE TO authenticated
  USING (public.is_admin_user()) WITH CHECK (public.is_admin_user());

CREATE POLICY platform_features_delete_admin
  ON public.platform_features FOR DELETE TO authenticated
  USING (public.is_admin_user());

-- ── platform_feature_channels: public read, admin write ──
CREATE POLICY "Public read platform_feature_channels"
  ON public.platform_feature_channels FOR SELECT USING (true);

CREATE POLICY platform_feature_channels_insert_admin
  ON public.platform_feature_channels FOR INSERT TO authenticated
  WITH CHECK (public.is_admin_user());

CREATE POLICY platform_feature_channels_update_admin
  ON public.platform_feature_channels FOR UPDATE TO authenticated
  USING (public.is_admin_user()) WITH CHECK (public.is_admin_user());

CREATE POLICY platform_feature_channels_delete_admin
  ON public.platform_feature_channels FOR DELETE TO authenticated
  USING (public.is_admin_user());

-- ── platform_feature_rules: public read, admin write ──
CREATE POLICY "Public read platform_feature_rules"
  ON public.platform_feature_rules FOR SELECT USING (true);

CREATE POLICY platform_feature_rules_insert_admin
  ON public.platform_feature_rules FOR INSERT TO authenticated
  WITH CHECK (public.is_admin_user());

CREATE POLICY platform_feature_rules_update_admin
  ON public.platform_feature_rules FOR UPDATE TO authenticated
  USING (public.is_admin_user()) WITH CHECK (public.is_admin_user());

CREATE POLICY platform_feature_rules_delete_admin
  ON public.platform_feature_rules FOR DELETE TO authenticated
  USING (public.is_admin_user());

-- ── platform_content_blocks: public read (active only), admin write ──
CREATE POLICY "Public read active platform_content_blocks"
  ON public.platform_content_blocks FOR SELECT USING (is_active = true);

CREATE POLICY "Admin read all platform_content_blocks"
  ON public.platform_content_blocks FOR SELECT TO authenticated
  USING (public.is_admin_user());

CREATE POLICY platform_content_blocks_insert_admin
  ON public.platform_content_blocks FOR INSERT TO authenticated
  WITH CHECK (public.is_admin_user());

CREATE POLICY platform_content_blocks_update_admin
  ON public.platform_content_blocks FOR UPDATE TO authenticated
  USING (public.is_admin_user()) WITH CHECK (public.is_admin_user());

CREATE POLICY platform_content_blocks_delete_admin
  ON public.platform_content_blocks FOR DELETE TO authenticated
  USING (public.is_admin_user());

-- ── platform_feature_audit_logs: admin read only, no public write ──
CREATE POLICY "Admin read platform_feature_audit_logs"
  ON public.platform_feature_audit_logs FOR SELECT TO authenticated
  USING (public.is_admin_user());

-- No insert/update/delete policies for audit logs — written only by triggers

-- ──────────────────────────────────────────────────────────────────────────────
-- RPC: get_platform_config(p_channel, p_club_id)
-- Returns the fully resolved feature config for a given channel and club.
-- Club-specific rows override global (NULL club_id) rows.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_platform_config(
  p_channel text DEFAULT 'mobile',
  p_club_id bigint DEFAULT NULL
) RETURNS jsonb
  LANGUAGE plpgsql STABLE SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE
  v_result jsonb;
  v_features jsonb;
  v_content_blocks jsonb;
  v_now timestamptz := now();
BEGIN
  -- Resolve features: club-specific overrides global
  WITH resolved_features AS (
    SELECT DISTINCT ON (pf.feature_key)
      pf.id,
      pf.feature_key,
      pf.display_name,
      pf.description,
      pf.category,
      pf.club_id,
      pf.is_enabled,
      pf.visibility_state
    FROM public.platform_features pf
    WHERE pf.club_id IS NULL
       OR pf.club_id = p_club_id
    ORDER BY pf.feature_key, pf.club_id DESC NULLS LAST
  )
  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'feature_key', rf.feature_key,
      'display_name', rf.display_name,
      'description', rf.description,
      'category', rf.category,
      'is_enabled', rf.is_enabled,
      'visibility_state', rf.visibility_state,
      'channel', (
        SELECT jsonb_build_object(
          'is_enabled', coalesce(ch.is_enabled, true),
          'is_visible', coalesce(ch.is_visible, true),
          'show_in_navigation', coalesce(ch.show_in_navigation, false),
          'show_on_home', coalesce(ch.show_on_home, false),
          'sort_order', ch.sort_order,
          'route_key', ch.route_key,
          'placement_key', ch.placement_key
        )
        FROM public.platform_feature_channels ch
        WHERE ch.feature_id = rf.id
          AND ch.channel = p_channel
      ),
      'rules', (
        SELECT jsonb_build_object(
          'auth_required', coalesce(r.auth_required, false),
          'role_restrictions', coalesce(r.role_restrictions, '[]'::jsonb),
          'dependency_rules', coalesce(r.dependency_rules, '{}'::jsonb),
          'rollout_rules', coalesce(r.rollout_rules, '{}'::jsonb),
          'schedule_start_at', r.schedule_start_at,
          'schedule_end_at', r.schedule_end_at,
          'is_within_schedule',
            CASE
              WHEN r.schedule_start_at IS NULL AND r.schedule_end_at IS NULL THEN true
              WHEN r.schedule_start_at IS NOT NULL AND r.schedule_end_at IS NOT NULL
                THEN v_now >= r.schedule_start_at AND v_now < r.schedule_end_at
              WHEN r.schedule_start_at IS NOT NULL THEN v_now >= r.schedule_start_at
              WHEN r.schedule_end_at IS NOT NULL THEN v_now < r.schedule_end_at
              ELSE true
            END
        )
        FROM public.platform_feature_rules r
        WHERE r.feature_id = rf.id
      )
    )
    ORDER BY rf.feature_key
  ), '[]'::jsonb)
  INTO v_features
  FROM resolved_features rf;

  -- Resolve content blocks for the requested channel
  SELECT coalesce(jsonb_agg(
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
    ORDER BY cb.sort_order NULLS LAST, cb.created_at
  ), '[]'::jsonb)
  INTO v_content_blocks
  FROM public.platform_content_blocks cb
  LEFT JOIN public.platform_features pf ON pf.id = cb.feature_id
  WHERE cb.is_active = true
    AND (cb.target_channel = p_channel OR cb.target_channel = 'both')
    AND (cb.club_id IS NULL OR cb.club_id = p_club_id);

  v_result := jsonb_build_object(
    'features', v_features,
    'content_blocks', v_content_blocks,
    'config_version', v_now,
    'channel', p_channel,
    'club_id', p_club_id
  );

  RETURN v_result;
END;
$$;

COMMENT ON FUNCTION public.get_platform_config IS
  'Returns the fully resolved platform feature config for a given channel and club. '
  'Club-specific rows override global (NULL club_id) rows.';

-- ──────────────────────────────────────────────────────────────────────────────
-- RPC: check_feature_enabled(p_feature_key, p_channel, p_club_id)
-- Lightweight check for backend enforcement.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.check_feature_enabled(
  p_feature_key text,
  p_channel text DEFAULT 'mobile',
  p_club_id bigint DEFAULT NULL
) RETURNS boolean
  LANGUAGE plpgsql STABLE SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE
  v_feature public.platform_features;
  v_channel_enabled boolean;
  v_now timestamptz := now();
  v_schedule_ok boolean := true;
BEGIN
  -- Resolve: club-specific overrides global
  SELECT * INTO v_feature
  FROM public.platform_features
  WHERE feature_key = p_feature_key
    AND (club_id IS NULL OR club_id = p_club_id)
  ORDER BY club_id DESC NULLS LAST
  LIMIT 1;

  IF NOT FOUND THEN
    -- Feature not registered → default enabled (backward compat)
    RETURN true;
  END IF;

  -- Global kill switch
  IF NOT v_feature.is_enabled THEN
    RETURN false;
  END IF;

  -- Visibility state
  IF v_feature.visibility_state = 'hidden' THEN
    RETURN false;
  END IF;

  -- Channel check
  SELECT ch.is_enabled INTO v_channel_enabled
  FROM public.platform_feature_channels ch
  WHERE ch.feature_id = v_feature.id
    AND ch.channel = p_channel;

  IF FOUND AND NOT v_channel_enabled THEN
    RETURN false;
  END IF;

  -- Schedule check
  PERFORM 1
  FROM public.platform_feature_rules r
  WHERE r.feature_id = v_feature.id
    AND (
      (r.schedule_start_at IS NOT NULL AND v_now < r.schedule_start_at)
      OR
      (r.schedule_end_at IS NOT NULL AND v_now >= r.schedule_end_at)
    );
  IF FOUND THEN
    RETURN false;
  END IF;

  RETURN true;
END;
$$;

COMMENT ON FUNCTION public.check_feature_enabled IS
  'Lightweight feature check for backend enforcement. Returns false if feature is '
  'globally disabled, hidden, channel-disabled, or outside schedule window.';

-- ──────────────────────────────────────────────────────────────────────────────
-- SEED DATA: Insert global features matching current hardcoded FeatureModules
-- ──────────────────────────────────────────────────────────────────────────────

-- All 13 feature modules as global defaults (club_id = NULL)
INSERT INTO public.platform_features
  (feature_key, display_name, description, category, club_id, is_enabled, visibility_state)
VALUES
  ('home',          'Home',           'Main home screen with hero, stats, and feed',            'core',         NULL, true, 'visible'),
  ('live',          'Live Match',     'Live match center with real-time updates',                'core',         NULL, true, 'visible'),
  ('fanzone',       'Fan Zone',       'Predictions, fixtures, leaderboard, wallet, and badges',  'gamification', NULL, true, 'visible'),
  ('challenge',     'Challenge',      'Fan challenges and competitions',                         'gamification', NULL, true, 'visible'),
  ('BioPay',        'BioPay',         'Facial recognition payment system',                       'commerce',     NULL, true, 'visible'),
  ('settings',      'Settings',       'User settings and profile management',                    'core',         NULL, true, 'visible'),
  ('onboarding',    'Onboarding',     'Welcome flow and phone auth',                             'core',         NULL, true, 'visible'),
  ('membership',    'Membership',     'Fan membership tiers and packages',                       'social',       NULL, true, 'visible'),
  ('contributions', 'Contributions',  'Community savings and fundraising groups',                 'social',       NULL, true, 'visible'),
  ('ticketing',     'Ticketing',      'Match ticket purchase and management',                    'commerce',     NULL, true, 'visible'),
  ('fan_clubs',     'Fan Clubs',      'Fan club communities and activities',                     'social',       NULL, true, 'visible'),
  ('admin',         'Admin Panel',    'Club administration and content management',              'core',         NULL, true, 'visible'),
  ('shop',          'Shop',           'Merchandise and rewards marketplace',                     'commerce',     NULL, true, 'visible')
ON CONFLICT DO NOTHING;

-- ── Channel configs: Mobile ──
INSERT INTO public.platform_feature_channels
  (feature_id, channel, is_enabled, is_visible, show_in_navigation, show_on_home, sort_order, route_key, placement_key)
SELECT
  pf.id, 'mobile', true, true,
  CASE pf.feature_key
    WHEN 'home'          THEN true
    WHEN 'contributions' THEN true
    WHEN 'fanzone'       THEN true
    WHEN 'settings'      THEN true
    ELSE false
  END,
  CASE pf.feature_key
    WHEN 'home'          THEN true
    WHEN 'fanzone'       THEN true
    WHEN 'live'          THEN true
    WHEN 'BioPay'        THEN true
    WHEN 'contributions' THEN true
    WHEN 'ticketing'     THEN true
    WHEN 'shop'          THEN true
    WHEN 'membership'    THEN true
    ELSE false
  END,
  CASE pf.feature_key
    WHEN 'home'          THEN 10
    WHEN 'contributions' THEN 20
    WHEN 'fanzone'       THEN 30
    WHEN 'settings'      THEN 40
    WHEN 'live'          THEN 50
    WHEN 'BioPay'        THEN 60
    WHEN 'ticketing'     THEN 70
    WHEN 'membership'    THEN 80
    WHEN 'fan_clubs'     THEN 90
    WHEN 'shop'          THEN 100
    WHEN 'challenge'     THEN 110
    WHEN 'onboarding'    THEN 200
    WHEN 'admin'         THEN 900
    ELSE 500
  END,
  CASE pf.feature_key
    WHEN 'home'          THEN '/home'
    WHEN 'contributions' THEN '/contribute'
    WHEN 'fanzone'       THEN '/fanzone'
    WHEN 'settings'      THEN '/settings'
    WHEN 'live'          THEN '/live'
    WHEN 'BioPay'        THEN '/BioPay'
    WHEN 'ticketing'     THEN '/tickets'
    WHEN 'membership'    THEN '/membership'
    WHEN 'fan_clubs'     THEN '/fan-clubs'
    WHEN 'shop'          THEN '/shop'
    WHEN 'challenge'     THEN '/challenge'
    WHEN 'onboarding'    THEN '/onboarding'
    WHEN 'admin'         THEN '/admin'
    ELSE NULL
  END,
  CASE pf.feature_key
    WHEN 'home'          THEN 'bottom_nav'
    WHEN 'contributions' THEN 'bottom_nav'
    WHEN 'fanzone'       THEN 'bottom_nav'
    WHEN 'settings'      THEN 'bottom_nav'
    WHEN 'live'          THEN 'home_action'
    WHEN 'BioPay'        THEN 'home_action'
    ELSE NULL
  END
FROM public.platform_features pf
WHERE pf.club_id IS NULL
ON CONFLICT (feature_id, channel) DO NOTHING;

-- ── Channel configs: Web ──
INSERT INTO public.platform_feature_channels
  (feature_id, channel, is_enabled, is_visible, show_in_navigation, show_on_home, sort_order, route_key, placement_key)
SELECT
  pf.id, 'web', true, true,
  CASE pf.feature_key
    WHEN 'fanzone'       THEN true
    WHEN 'ticketing'     THEN true
    WHEN 'membership'    THEN true
    WHEN 'contributions' THEN true
    WHEN 'shop'          THEN true
    WHEN 'fan_clubs'     THEN true
    ELSE false
  END,
  CASE pf.feature_key
    WHEN 'home'          THEN true
    WHEN 'fanzone'       THEN true
    WHEN 'ticketing'     THEN true
    WHEN 'membership'    THEN true
    WHEN 'contributions' THEN true
    WHEN 'shop'          THEN true
    ELSE false
  END,
  CASE pf.feature_key
    WHEN 'fanzone'       THEN 20
    WHEN 'ticketing'     THEN 40
    WHEN 'membership'    THEN 50
    WHEN 'contributions' THEN 60
    WHEN 'shop'          THEN 70
    WHEN 'fan_clubs'     THEN 80
    ELSE 500
  END,
  CASE pf.feature_key
    WHEN 'fanzone'       THEN '/fixtures'
    WHEN 'ticketing'     THEN '/tickets'
    WHEN 'membership'    THEN '/membership'
    WHEN 'contributions' THEN '/circles'
    WHEN 'shop'          THEN '/shop'
    WHEN 'fan_clubs'     THEN '/fan-clubs'
    ELSE NULL
  END,
  CASE pf.feature_key
    WHEN 'fanzone'       THEN 'main_nav'
    WHEN 'ticketing'     THEN 'main_nav'
    WHEN 'membership'    THEN 'main_nav'
    WHEN 'contributions' THEN 'main_nav'
    WHEN 'shop'          THEN 'main_nav'
    WHEN 'fan_clubs'     THEN 'main_nav'
    ELSE NULL
  END
FROM public.platform_features pf
WHERE pf.club_id IS NULL
ON CONFLICT (feature_id, channel) DO NOTHING;

-- ── Feature rules: defaults ──
INSERT INTO public.platform_feature_rules
  (feature_id, auth_required, role_restrictions, dependency_rules)
SELECT
  pf.id,
  CASE pf.feature_key
    WHEN 'home'       THEN false
    WHEN 'onboarding' THEN false
    WHEN 'live'       THEN false
    WHEN 'fanzone'    THEN false
    WHEN 'shop'       THEN false
    WHEN 'ticketing'  THEN false
    WHEN 'membership' THEN false
    WHEN 'fan_clubs'  THEN false
    WHEN 'admin'      THEN true
    ELSE true
  END,
  CASE pf.feature_key
    WHEN 'admin' THEN '["admin", "super_admin", "club_admin"]'::jsonb
    ELSE '[]'::jsonb
  END,
  CASE pf.feature_key
    WHEN 'challenge' THEN '{"requires": ["fanzone"]}'::jsonb
    ELSE '{}'::jsonb
  END
FROM public.platform_features pf
WHERE pf.club_id IS NULL
ON CONFLICT (feature_id) DO NOTHING;

-- ── Content blocks: homepage sections for mobile ──
INSERT INTO public.platform_content_blocks
  (block_key, block_type, title, subtitle, content, target_channel, placement_key, feature_id, is_active, sort_order)
VALUES
  ('mobile_home_hero',        'hero',    'Match Hero',      NULL, '{"widget": "match_score_card"}'::jsonb,         'mobile', 'home_hero',   (SELECT id FROM public.platform_features WHERE feature_key='home' AND club_id IS NULL), true, 10),
  ('mobile_home_actions',     'section', 'Primary Actions', NULL, '{"widget": "primary_action_buttons"}'::jsonb,   'mobile', 'home_top',    (SELECT id FROM public.platform_features WHERE feature_key='home' AND club_id IS NULL), true, 20),
  ('mobile_home_quick',       'section', 'Shortcuts',       NULL, '{"widget": "quick_actions_grid"}'::jsonb,       'mobile', 'home_top',    (SELECT id FROM public.platform_features WHERE feature_key='home' AND club_id IS NULL), true, 30),
  ('mobile_home_stats',       'section', 'Stats',           NULL, '{"widget": "stats_row"}'::jsonb,               'mobile', 'home_mid',    (SELECT id FROM public.platform_features WHERE feature_key='fanzone' AND club_id IS NULL), true, 40),
  ('mobile_home_leaderboard', 'section', 'Leaderboard',     NULL, '{"widget": "contributor_leaderboard"}'::jsonb,  'mobile', 'home_mid',    (SELECT id FROM public.platform_features WHERE feature_key='contributions' AND club_id IS NULL), true, 50),
  ('mobile_home_intel',       'section', 'Latest Intel',    NULL, '{"widget": "latest_intel_section"}'::jsonb,     'mobile', 'home_bottom', (SELECT id FROM public.platform_features WHERE feature_key='home' AND club_id IS NULL), true, 60)
ON CONFLICT (block_key) DO NOTHING;

-- ── Content blocks: homepage sections for web ──
INSERT INTO public.platform_content_blocks
  (block_key, block_type, title, subtitle, content, target_channel, placement_key, feature_id, is_active, sort_order)
VALUES
  ('web_home_hero',       'hero',    'Hero',               NULL, '{"component": "hero-block"}'::jsonb,                    'web', 'home_hero',   (SELECT id FROM public.platform_features WHERE feature_key='home' AND club_id IS NULL), true, 10),
  ('web_home_circles',    'section', 'Groups & Matchday',  NULL, '{"component": "circles-matchday-block"}'::jsonb,        'web', 'home_top',    (SELECT id FROM public.platform_features WHERE feature_key='contributions' AND club_id IS NULL), true, 20),
  ('web_home_fixtures',   'section', 'Fixtures',           NULL, '{"component": "fixtures-block"}'::jsonb,                'web', 'home_mid',    (SELECT id FROM public.platform_features WHERE feature_key='fanzone' AND club_id IS NULL), true, 30),
  ('web_home_membership', 'section', 'Membership',         NULL, '{"component": "membership-standings-block"}'::jsonb,    'web', 'home_mid',    (SELECT id FROM public.platform_features WHERE feature_key='membership' AND club_id IS NULL), true, 40),
  ('web_home_news',       'section', 'News',               NULL, '{"component": "news-block"}'::jsonb,                   'web', 'home_bottom', (SELECT id FROM public.platform_features WHERE feature_key='home' AND club_id IS NULL), true, 50),
  ('web_home_shop',       'section', 'Shop & Identity',    NULL, '{"component": "shop-identity-block"}'::jsonb,           'web', 'home_bottom', (SELECT id FROM public.platform_features WHERE feature_key='shop' AND club_id IS NULL), true, 60)
ON CONFLICT (block_key) DO NOTHING;
