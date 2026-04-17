-- Restore the feature access RPC and its execute grants in environments where
-- the hardening migration was only partially applied.

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

REVOKE ALL ON FUNCTION public.get_feature_access_state(text, text, bigint, boolean, text[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_feature_access_state(text, text, bigint, boolean, text[]) TO anon, authenticated;
