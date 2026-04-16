-- ============================================================================
-- Harden platform feature management
-- ============================================================================
-- Tightens public access, adds richer access evaluation, resolves club-specific
-- content block overrides, and exposes stable config versioning for caching.

-- ──────────────────────────────────────────────────────────────────────────────
-- Canonical feature keys and club-scoped content block overrides
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.canonicalize_platform_feature_key(p_key text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT regexp_replace(lower(trim(coalesce(p_key, ''))), '[^a-z0-9]+', '_', 'g');
$$;

COMMENT ON FUNCTION public.canonicalize_platform_feature_key IS
  'Normalizes feature keys for case-insensitive, punctuation-insensitive matching.';

CREATE INDEX IF NOT EXISTS idx_platform_features_canonical_lookup
  ON public.platform_features (
    public.canonicalize_platform_feature_key(feature_key),
    club_id
  );

ALTER TABLE public.platform_content_blocks
  DROP CONSTRAINT IF EXISTS platform_content_blocks_block_key_key;

ALTER TABLE public.platform_content_blocks
  ADD CONSTRAINT platform_content_blocks_block_key_club_unique
  UNIQUE (block_key, club_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_platform_content_blocks_global_unique
  ON public.platform_content_blocks (block_key)
  WHERE club_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_platform_content_blocks_club
  ON public.platform_content_blocks (club_id)
  WHERE club_id IS NOT NULL;

-- ──────────────────────────────────────────────────────────────────────────────
-- Seed additional web/admin surface features that were still hardcoded
-- ──────────────────────────────────────────────────────────────────────────────
INSERT INTO public.platform_features
  (feature_key, display_name, description, category, club_id, is_enabled, visibility_state)
VALUES
  ('news',          'News',          'Editorial news and stories pages',                 'content',      NULL, true, 'visible'),
  ('squad',         'Squad',         'First team roster and player profiles',            'content',      NULL, true, 'visible'),
  ('notifications', 'Notifications', 'Push notifications and outbound alert surfaces',   'operations',   NULL, true, 'visible'),
  ('campaigns',     'Campaigns',     'Campaign, promo, and banner-led marketing blocks', 'marketing',    NULL, true, 'visible')
ON CONFLICT DO NOTHING;

INSERT INTO public.platform_feature_channels
  (feature_id, channel, is_enabled, is_visible, show_in_navigation, show_on_home, sort_order, route_key, placement_key)
SELECT
  pf.id,
  'web',
  true,
  true,
  CASE pf.feature_key
    WHEN 'news'  THEN true
    WHEN 'squad' THEN true
    ELSE false
  END,
  CASE pf.feature_key
    WHEN 'news'      THEN true
    WHEN 'campaigns' THEN true
    ELSE false
  END,
  CASE pf.feature_key
    WHEN 'news'      THEN 15
    WHEN 'squad'     THEN 35
    WHEN 'campaigns' THEN 65
    ELSE 500
  END,
  CASE pf.feature_key
    WHEN 'news'  THEN '/news'
    WHEN 'squad' THEN '/squad'
    ELSE NULL
  END,
  CASE pf.feature_key
    WHEN 'news'      THEN 'main_nav'
    WHEN 'squad'     THEN 'main_nav'
    WHEN 'campaigns' THEN 'home_top'
    ELSE NULL
  END
FROM public.platform_features pf
WHERE pf.club_id IS NULL
  AND pf.feature_key IN ('news', 'squad', 'notifications', 'campaigns')
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
    WHEN 'campaigns'     THEN true
    ELSE false
  END,
  CASE pf.feature_key
    WHEN 'notifications' THEN 120
    WHEN 'campaigns'     THEN 130
    ELSE 500
  END,
  NULL,
  CASE pf.feature_key
    WHEN 'notifications' THEN 'home_bottom'
    WHEN 'campaigns'     THEN 'home_top'
    ELSE NULL
  END
FROM public.platform_features pf
WHERE pf.club_id IS NULL
  AND pf.feature_key IN ('news', 'squad', 'notifications', 'campaigns')
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
  AND pf.feature_key IN ('news', 'squad', 'notifications', 'campaigns')
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

-- ──────────────────────────────────────────────────────────────────────────────
-- Rich access evaluation
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_feature_access_state(
  p_feature_key text,
  p_channel text DEFAULT 'mobile',
  p_club_id bigint DEFAULT NULL,
  p_is_authenticated boolean DEFAULT false,
  p_roles text[] DEFAULT ARRAY[]::text[]
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_now timestamptz := now();
  v_feature record;
  v_channel record;
  v_rules record;
  v_schedule_ok boolean := true;
  v_dependencies_ok boolean := true;
  v_role_allowed boolean := true;
  v_auth_allowed boolean := true;
  v_is_registered boolean := false;
  v_is_globally_enabled boolean := true;
  v_is_channel_enabled boolean := true;
  v_is_channel_visible boolean := true;
  v_is_visible boolean := true;
  v_is_operational boolean := true;
  v_is_available boolean := true;
  v_reason text := 'ok';
BEGIN
  SELECT DISTINCT ON (public.canonicalize_platform_feature_key(pf.feature_key))
    pf.id,
    pf.feature_key,
    pf.display_name,
    pf.description,
    pf.category,
    pf.club_id,
    pf.is_enabled,
    pf.visibility_state
  INTO v_feature
  FROM public.platform_features pf
  WHERE public.canonicalize_platform_feature_key(pf.feature_key) =
        public.canonicalize_platform_feature_key(p_feature_key)
    AND (pf.club_id IS NULL OR pf.club_id = p_club_id)
  ORDER BY public.canonicalize_platform_feature_key(pf.feature_key), pf.club_id DESC NULLS LAST;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'requested_feature_key', p_feature_key,
      'feature_key', p_feature_key,
      'is_registered', false,
      'is_visible', true,
      'is_operational', true,
      'is_available', true,
      'reason', 'unregistered'
    );
  END IF;

  v_is_registered := true;
  v_is_globally_enabled := coalesce(v_feature.is_enabled, true);
  v_is_visible := v_feature.visibility_state <> 'hidden';

  SELECT *
  INTO v_channel
  FROM public.platform_feature_channels ch
  WHERE ch.feature_id = v_feature.id
    AND ch.channel = p_channel;

  IF FOUND THEN
    v_is_channel_enabled := coalesce(v_channel.is_enabled, true);
    v_is_channel_visible := coalesce(v_channel.is_visible, true);
    v_is_visible := v_is_visible AND v_is_channel_visible;
  END IF;

  SELECT *
  INTO v_rules
  FROM public.platform_feature_rules r
  WHERE r.feature_id = v_feature.id;

  IF FOUND THEN
    v_schedule_ok :=
      CASE
        WHEN v_rules.schedule_start_at IS NULL AND v_rules.schedule_end_at IS NULL THEN true
        WHEN v_rules.schedule_start_at IS NOT NULL AND v_rules.schedule_end_at IS NOT NULL
          THEN v_now >= v_rules.schedule_start_at AND v_now < v_rules.schedule_end_at
        WHEN v_rules.schedule_start_at IS NOT NULL THEN v_now >= v_rules.schedule_start_at
        WHEN v_rules.schedule_end_at IS NOT NULL THEN v_now < v_rules.schedule_end_at
        ELSE true
      END;

    IF coalesce(v_rules.auth_required, false) AND NOT p_is_authenticated THEN
      v_auth_allowed := false;
    END IF;

    IF jsonb_typeof(coalesce(v_rules.role_restrictions, '[]'::jsonb)) = 'array'
       AND jsonb_array_length(coalesce(v_rules.role_restrictions, '[]'::jsonb)) > 0 THEN
      SELECT exists (
        SELECT 1
        FROM jsonb_array_elements_text(v_rules.role_restrictions) AS allowed(role_name)
        JOIN unnest(p_roles) AS caller(role_name)
          ON lower(trim(allowed.role_name)) = lower(trim(caller.role_name))
      )
      INTO v_role_allowed;

      IF NOT p_is_authenticated THEN
        v_role_allowed := false;
      END IF;
    END IF;

    IF jsonb_typeof(coalesce(v_rules.dependency_rules -> 'requires', '[]'::jsonb)) = 'array'
       AND jsonb_array_length(coalesce(v_rules.dependency_rules -> 'requires', '[]'::jsonb)) > 0 THEN
      SELECT coalesce(bool_and(
        dep_feature.is_enabled
        AND dep_feature.visibility_state <> 'maintenance'
        AND coalesce(dep_channel.is_enabled, true)
      ), true)
      INTO v_dependencies_ok
      FROM jsonb_array_elements_text(v_rules.dependency_rules -> 'requires') AS dep(required_key)
      LEFT JOIN LATERAL (
        SELECT DISTINCT ON (public.canonicalize_platform_feature_key(pf.feature_key))
          pf.id,
          pf.is_enabled,
          pf.visibility_state
        FROM public.platform_features pf
        WHERE public.canonicalize_platform_feature_key(pf.feature_key) =
              public.canonicalize_platform_feature_key(dep.required_key)
          AND (pf.club_id IS NULL OR pf.club_id = p_club_id)
        ORDER BY public.canonicalize_platform_feature_key(pf.feature_key), pf.club_id DESC NULLS LAST
      ) AS dep_feature ON true
      LEFT JOIN public.platform_feature_channels AS dep_channel
        ON dep_channel.feature_id = dep_feature.id
       AND dep_channel.channel = p_channel;
    END IF;
  END IF;

  v_is_operational :=
    v_is_globally_enabled
    AND v_is_channel_enabled
    AND v_feature.visibility_state <> 'maintenance'
    AND v_schedule_ok
    AND v_dependencies_ok;

  v_is_available := v_is_operational AND v_auth_allowed AND v_role_allowed;

  IF NOT v_is_registered THEN
    v_reason := 'unregistered';
  ELSIF NOT v_is_globally_enabled THEN
    v_reason := 'global_disabled';
  ELSIF NOT v_is_channel_enabled THEN
    v_reason := 'channel_disabled';
  ELSIF v_feature.visibility_state = 'hidden' THEN
    v_reason := 'hidden';
  ELSIF NOT v_is_channel_visible THEN
    v_reason := 'channel_hidden';
  ELSIF v_feature.visibility_state = 'maintenance' THEN
    v_reason := 'maintenance';
  ELSIF NOT v_schedule_ok THEN
    v_reason := 'outside_schedule';
  ELSIF NOT v_dependencies_ok THEN
    v_reason := 'dependency_blocked';
  ELSIF NOT v_auth_allowed THEN
    v_reason := 'auth_required';
  ELSIF NOT v_role_allowed THEN
    v_reason := 'role_restricted';
  END IF;

  RETURN jsonb_build_object(
    'requested_feature_key', p_feature_key,
    'feature_key', v_feature.feature_key,
    'display_name', v_feature.display_name,
    'description', v_feature.description,
    'category', v_feature.category,
    'visibility_state', v_feature.visibility_state,
    'is_registered', v_is_registered,
    'is_visible', v_is_visible,
    'is_operational', v_is_operational,
    'is_available', v_is_available,
    'is_globally_enabled', v_is_globally_enabled,
    'is_channel_enabled', v_is_channel_enabled,
    'channel', p_channel,
    'show_in_navigation', coalesce(v_channel.show_in_navigation, false),
    'show_on_home', coalesce(v_channel.show_on_home, false),
    'sort_order', v_channel.sort_order,
    'route_key', v_channel.route_key,
    'placement_key', v_channel.placement_key,
    'auth_required', coalesce(v_rules.auth_required, false),
    'role_restrictions', coalesce(v_rules.role_restrictions, '[]'::jsonb),
    'dependency_rules', coalesce(v_rules.dependency_rules, '{}'::jsonb),
    'rollout_rules', coalesce(v_rules.rollout_rules, '{}'::jsonb),
    'schedule_start_at', v_rules.schedule_start_at,
    'schedule_end_at', v_rules.schedule_end_at,
    'is_within_schedule', v_schedule_ok,
    'dependencies_satisfied', v_dependencies_ok,
    'role_allowed', v_role_allowed,
    'reason', v_reason
  );
END;
$$;

COMMENT ON FUNCTION public.get_feature_access_state IS
  'Returns the resolved visibility, operational, and access state for a feature.';

CREATE OR REPLACE FUNCTION public.check_feature_enabled(
  p_feature_key text,
  p_channel text DEFAULT 'mobile',
  p_club_id bigint DEFAULT NULL
) RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_state jsonb;
BEGIN
  v_state := public.get_feature_access_state(
    p_feature_key,
    p_channel,
    p_club_id,
    auth.uid() IS NOT NULL,
    ARRAY[]::text[]
  );

  RETURN coalesce((v_state ->> 'is_available')::boolean, true);
END;
$$;

COMMENT ON FUNCTION public.check_feature_enabled IS
  'Operational feature check for backend actions. Hidden UI state does not disable backend execution.';

CREATE OR REPLACE FUNCTION public.log_feature_config_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_feature_id uuid;
  v_action text;
  v_before jsonb := '{}'::jsonb;
  v_after  jsonb := '{}'::jsonb;
BEGIN
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
  ELSIF TG_TABLE_NAME = 'platform_content_blocks' THEN
    IF TG_OP = 'DELETE' THEN
      v_feature_id := OLD.feature_id;
    ELSE
      v_feature_id := NEW.feature_id;
    END IF;
  END IF;

  v_action := lower(TG_OP) || '_' || TG_TABLE_NAME;

  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    v_before := to_jsonb(OLD);
  END IF;
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    v_after := to_jsonb(NEW);
  END IF;

  INSERT INTO public.platform_feature_audit_logs (
    feature_id,
    action,
    changed_by,
    before_state,
    after_state
  ) VALUES (
    v_feature_id,
    v_action,
    auth.uid(),
    v_before,
    v_after
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_feature_audit_content_blocks
  ON public.platform_content_blocks;

CREATE TRIGGER trg_feature_audit_content_blocks
  AFTER INSERT OR UPDATE OR DELETE ON public.platform_content_blocks
  FOR EACH ROW EXECUTE FUNCTION public.log_feature_config_change();

-- ──────────────────────────────────────────────────────────────────────────────
-- Stable config payload versioning + content block override resolution
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_platform_config(
  p_channel text DEFAULT 'mobile',
  p_club_id bigint DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_result jsonb;
  v_features jsonb;
  v_content_blocks jsonb;
  v_config_version timestamptz;
  v_now timestamptz := now();
BEGIN
  WITH resolved_features AS (
    SELECT DISTINCT ON (public.canonicalize_platform_feature_key(pf.feature_key))
      pf.id,
      pf.feature_key,
      pf.display_name,
      pf.description,
      pf.category,
      pf.club_id,
      pf.is_enabled,
      pf.visibility_state,
      pf.created_at,
      pf.updated_at
    FROM public.platform_features pf
    WHERE pf.club_id IS NULL OR pf.club_id = p_club_id
    ORDER BY public.canonicalize_platform_feature_key(pf.feature_key), pf.club_id DESC NULLS LAST
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
          'metadata', coalesce(r.metadata, '{}'::jsonb),
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
    ORDER BY coalesce((
      SELECT ch.sort_order
      FROM public.platform_feature_channels ch
      WHERE ch.feature_id = rf.id
        AND ch.channel = p_channel
    ), 999), rf.feature_key
  ), '[]'::jsonb)
  INTO v_features
  FROM resolved_features rf;

  WITH resolved_blocks AS (
    SELECT DISTINCT ON (cb.block_key)
      cb.id,
      cb.block_key,
      cb.block_type,
      cb.title,
      cb.subtitle,
      cb.content,
      cb.target_channel,
      cb.placement_key,
      cb.feature_id,
      cb.is_active,
      cb.sort_order,
      cb.metadata,
      cb.created_at,
      cb.updated_at,
      cb.club_id
    FROM public.platform_content_blocks cb
    WHERE cb.is_active = true
      AND (cb.target_channel = p_channel OR cb.target_channel = 'both')
      AND (cb.club_id IS NULL OR cb.club_id = p_club_id)
    ORDER BY cb.block_key, cb.club_id DESC NULLS LAST
  )
  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'block_key', rb.block_key,
      'block_type', rb.block_type,
      'title', rb.title,
      'subtitle', rb.subtitle,
      'content', rb.content,
      'target_channel', rb.target_channel,
      'placement_key', rb.placement_key,
      'feature_key', pf.feature_key,
      'is_active', rb.is_active,
      'sort_order', rb.sort_order,
      'metadata', rb.metadata
    )
    ORDER BY rb.placement_key, rb.sort_order NULLS LAST, rb.created_at
  ), '[]'::jsonb)
  INTO v_content_blocks
  FROM resolved_blocks rb
  LEFT JOIN public.platform_features pf ON pf.id = rb.feature_id;

  SELECT greatest(
    coalesce((
      SELECT max(ts)
      FROM (
        SELECT max(pf.updated_at) AS ts
        FROM public.platform_features pf
        WHERE pf.club_id IS NULL OR pf.club_id = p_club_id
        UNION ALL
        SELECT max(ch.updated_at) AS ts
        FROM public.platform_feature_channels ch
        JOIN public.platform_features pf ON pf.id = ch.feature_id
        WHERE pf.club_id IS NULL OR pf.club_id = p_club_id
        UNION ALL
        SELECT max(r.updated_at) AS ts
        FROM public.platform_feature_rules r
        JOIN public.platform_features pf ON pf.id = r.feature_id
        WHERE pf.club_id IS NULL OR pf.club_id = p_club_id
        UNION ALL
        SELECT max(cb.updated_at) AS ts
        FROM public.platform_content_blocks cb
        WHERE (cb.target_channel = p_channel OR cb.target_channel = 'both')
          AND (cb.club_id IS NULL OR cb.club_id = p_club_id)
      ) version_inputs
    ), v_now),
    v_now
  )
  INTO v_config_version;

  v_result := jsonb_build_object(
    'features', v_features,
    'content_blocks', v_content_blocks,
    'config_version', v_config_version,
    'channel', p_channel,
    'club_id', p_club_id
  );

  RETURN v_result;
END;
$$;

COMMENT ON FUNCTION public.get_platform_config IS
  'Returns the resolved platform config for a channel and club, including stable config versioning.';

-- ──────────────────────────────────────────────────────────────────────────────
-- Tighten public access: runtime reads must use the RPC surface
-- ──────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Public read platform_features"
  ON public.platform_features;
DROP POLICY IF EXISTS "Public read platform_feature_channels"
  ON public.platform_feature_channels;
DROP POLICY IF EXISTS "Public read platform_feature_rules"
  ON public.platform_feature_rules;
DROP POLICY IF EXISTS "Public read active platform_content_blocks"
  ON public.platform_content_blocks;
DROP POLICY IF EXISTS "Admin read all platform_content_blocks"
  ON public.platform_content_blocks;
DROP POLICY IF EXISTS "Admin read platform_feature_audit_logs"
  ON public.platform_feature_audit_logs;

CREATE POLICY platform_features_select_admin
  ON public.platform_features
  FOR SELECT
  TO authenticated
  USING (public.is_admin_user());

CREATE POLICY platform_feature_channels_select_admin
  ON public.platform_feature_channels
  FOR SELECT
  TO authenticated
  USING (public.is_admin_user());

CREATE POLICY platform_feature_rules_select_admin
  ON public.platform_feature_rules
  FOR SELECT
  TO authenticated
  USING (public.is_admin_user());

CREATE POLICY platform_content_blocks_select_admin
  ON public.platform_content_blocks
  FOR SELECT
  TO authenticated
  USING (public.is_admin_user());

CREATE POLICY platform_feature_audit_logs_select_admin
  ON public.platform_feature_audit_logs
  FOR SELECT
  TO authenticated
  USING (public.is_admin_user());

REVOKE ALL ON FUNCTION public.get_platform_config(text, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.check_feature_enabled(text, text, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_feature_access_state(text, text, bigint, boolean, text[]) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_platform_config(text, bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_feature_enabled(text, text, bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_feature_access_state(text, text, bigint, boolean, text[]) TO anon, authenticated;
