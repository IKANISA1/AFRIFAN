-- Harden BioPay by moving sensitive RPC entrypoints behind service-role-only
-- server functions. Edge functions pass the verified user_id and club_id
-- explicitly; authenticated clients lose direct execute access.

CREATE OR REPLACE FUNCTION public.biopay_upsert_enrollment_server(
  p_requester_user_id uuid,
  p_club_id bigint,
  p_display_name text DEFAULT NULL,
  p_route_type text DEFAULT NULL,
  p_recipient_value text DEFAULT NULL,
  p_country_code text DEFAULT 'RW',
  p_consent_version text DEFAULT 'biopay-v1',
  p_embedding double precision[] DEFAULT NULL,
  p_model_version text DEFAULT 'mobilefacenet_int8_v1',
  p_quality_score double precision DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  public_id text,
  user_id uuid,
  club_id bigint,
  display_name text,
  route_type text,
  recipient_value text,
  country_code text,
  active boolean,
  consent_version text,
  consent_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz,
  revoked_at timestamptz,
  enrolled_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_user_id uuid := p_requester_user_id;
  v_profile public.biopay_profiles%rowtype;
  v_embedding extensions.vector(192);
  v_display_name text;
  v_route_type text;
  v_recipient_value text;
  v_country_code text;
  v_consent_version text;
  v_enrolled_at timestamptz := timezone('utc', now());
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  IF p_club_id IS NULL THEN
    RAISE EXCEPTION 'Club context required.';
  END IF;

  IF p_embedding IS NULL THEN
    RAISE EXCEPTION 'Embedding is required for BioPay enrollment.';
  END IF;

  v_display_name := nullif(trim(coalesce(p_display_name, '')), '');
  IF v_display_name IS NULL THEN
    RAISE EXCEPTION 'Display name is required.';
  END IF;

  v_route_type := lower(trim(coalesce(nullif(p_route_type, ''), '')));
  IF v_route_type NOT IN ('phone_number', 'code') THEN
    RAISE EXCEPTION 'A valid payment route type (phone_number or code) is required.';
  END IF;

  v_recipient_value := trim(coalesce(nullif(p_recipient_value, ''), ''));
  IF v_recipient_value = '' THEN
    RAISE EXCEPTION 'A valid payout recipient is required.';
  END IF;

  v_country_code := upper(trim(coalesce(nullif(p_country_code, ''), 'RW')));
  v_consent_version := coalesce(nullif(trim(p_consent_version), ''), 'biopay-v1');
  v_embedding := public.biopay_array_to_vector(p_embedding);

  SELECT * INTO v_profile
  FROM public.biopay_profiles
  WHERE biopay_profiles.user_id = v_user_id
    AND biopay_profiles.club_id = p_club_id
    AND deleted_at IS NULL
  LIMIT 1;

  IF FOUND THEN
    UPDATE public.biopay_profiles SET
      display_name = v_display_name,
      route_type = v_route_type,
      recipient_value = v_recipient_value,
      country_code = v_country_code,
      active = true,
      consent_version = v_consent_version,
      consent_at = timezone('utc', now()),
      revoked_at = NULL,
      deleted_at = NULL
    WHERE biopay_profiles.id = v_profile.id
    RETURNING * INTO v_profile;
  ELSE
    INSERT INTO public.biopay_profiles (
      user_id, club_id, display_name, route_type, recipient_value,
      country_code, active, consent_version, consent_at
    ) VALUES (
      v_user_id, p_club_id, v_display_name, v_route_type, v_recipient_value,
      v_country_code, true, v_consent_version, timezone('utc', now())
    ) RETURNING * INTO v_profile;
  END IF;

  UPDATE public.biopay_embeddings SET
    active = false, retired_at = timezone('utc', now())
  WHERE biopay_embeddings.profile_id = v_profile.id
    AND biopay_embeddings.club_id = p_club_id
    AND biopay_embeddings.active = true;

  INSERT INTO public.biopay_embeddings (
    profile_id, club_id, embedding, model_version, quality_score, active, enrolled_at
  ) VALUES (
    v_profile.id, p_club_id, v_embedding,
    coalesce(nullif(trim(p_model_version), ''), 'mobilefacenet_int8_v1'),
    p_quality_score, true, v_enrolled_at
  );

  INSERT INTO public.biopay_enrollment_audits (profile_id, user_id, club_id, event_type, metadata)
  VALUES (v_profile.id, v_user_id, p_club_id, 'enrolled', jsonb_build_object(
    'route_type', v_route_type,
    'country_code', v_country_code,
    'model_version', coalesce(nullif(trim(p_model_version), ''), 'mobilefacenet_int8_v1'),
    'origin', 'edge'
  ));

  RETURN QUERY SELECT
    v_profile.id, v_profile.public_id, v_profile.user_id,
    v_profile.club_id,
    v_profile.display_name, v_profile.route_type, v_profile.recipient_value,
    v_profile.country_code, v_profile.active, v_profile.consent_version,
    v_profile.consent_at, v_profile.created_at, v_profile.updated_at,
    v_profile.revoked_at, v_enrolled_at;
END;
$$;

CREATE OR REPLACE FUNCTION public.match_biopay_profile_server(
  p_club_id bigint,
  p_embedding double precision[]
)
RETURNS TABLE (
  profile_id uuid,
  public_id text,
  user_id uuid,
  club_id bigint,
  display_name text,
  route_type text,
  recipient_value text,
  country_code text,
  consent_version text,
  consent_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz,
  score double precision
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  WITH query_vector AS (
    SELECT public.biopay_array_to_vector(p_embedding) AS embedding
  )
  SELECT
    p.id AS profile_id, p.public_id, p.user_id, p.club_id,
    p.display_name, p.route_type, p.recipient_value, p.country_code,
    p.consent_version, p.consent_at, p.created_at, p.updated_at,
    1 - (e.embedding <=> q.embedding) AS score
  FROM public.biopay_embeddings e
  JOIN public.biopay_profiles p ON p.id = e.profile_id
  CROSS JOIN query_vector q
  WHERE e.active = true
    AND p.active = true
    AND p.deleted_at IS NULL
    AND p.club_id = p_club_id
  ORDER BY e.embedding <=> q.embedding ASC
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.biopay_revoke_profile_server(
  p_requester_user_id uuid,
  p_club_id bigint,
  p_reason text DEFAULT NULL
)
RETURNS TABLE (
  profile_id uuid,
  public_id text,
  revoked_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_user_id uuid := p_requester_user_id;
  v_profile public.biopay_profiles%rowtype;
  v_revoked_at timestamptz := timezone('utc', now());
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  IF p_club_id IS NULL THEN
    RAISE EXCEPTION 'Club context required.';
  END IF;

  SELECT * INTO v_profile
  FROM public.biopay_profiles
  WHERE user_id = v_user_id
    AND club_id = p_club_id
    AND active = true
    AND deleted_at IS NULL
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No active BioPay enrollment was found.';
  END IF;

  UPDATE public.biopay_profiles SET
    active = false, revoked_at = v_revoked_at
  WHERE id = v_profile.id
  RETURNING * INTO v_profile;

  UPDATE public.biopay_embeddings SET
    active = false, retired_at = v_revoked_at
  WHERE profile_id = v_profile.id
    AND club_id = p_club_id
    AND active = true;

  INSERT INTO public.biopay_revocations (profile_id, user_id, club_id, reason, metadata)
  VALUES (
    v_profile.id,
    v_user_id,
    p_club_id,
    nullif(trim(coalesce(p_reason, '')), ''),
    jsonb_build_object('public_id', v_profile.public_id, 'origin', 'edge')
  );

  INSERT INTO public.biopay_enrollment_audits (profile_id, user_id, club_id, event_type, metadata)
  VALUES (v_profile.id, v_user_id, p_club_id, 'revoked', jsonb_build_object(
    'reason', nullif(trim(coalesce(p_reason, '')), ''),
    'public_id', v_profile.public_id,
    'origin', 'edge'
  ));

  RETURN QUERY SELECT v_profile.id, v_profile.public_id, v_revoked_at;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.biopay_upsert_enrollment(
  text, text, text, text, text, double precision[], text, double precision
) FROM authenticated;

REVOKE EXECUTE ON FUNCTION public.match_biopay_profile(double precision[])
FROM authenticated;

REVOKE EXECUTE ON FUNCTION public.biopay_revoke_profile(text)
FROM authenticated;

GRANT EXECUTE ON FUNCTION public.biopay_upsert_enrollment_server(
  uuid, bigint, text, text, text, text, text, double precision[], text, double precision
) TO service_role;

GRANT EXECUTE ON FUNCTION public.match_biopay_profile_server(bigint, double precision[])
TO service_role;

GRANT EXECUTE ON FUNCTION public.biopay_revoke_profile_server(uuid, bigint, text)
TO service_role;
