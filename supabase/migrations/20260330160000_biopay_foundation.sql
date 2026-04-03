-- ════════════════════════════════════════════════════════════════
-- BioPay Foundation — AFRICLUB white-label edition.
--
-- Tables, indexes, RPC functions, RLS policies for biometric
-- face recognition and payment handoff.
--
-- Adapted from reference implementation:
--   - 192-dimension embeddings (latest model)
--   - Generic route_type (phone_number, code)
--   - Country-agnostic (driven by AfriCountryCatalog)
-- ════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector;

-- ── Tables ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.biopay_profiles (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  public_id       text NOT NULL UNIQUE,
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name    text NOT NULL,
  route_type      text NOT NULL CHECK (route_type IN ('phone_number', 'code')),
  recipient_value text NOT NULL,
  country_code    text NOT NULL DEFAULT 'RW',
  active          boolean NOT NULL DEFAULT true,
  consent_version text NOT NULL DEFAULT 'biopay-v1',
  consent_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  revoked_at      timestamptz,
  deleted_at      timestamptz,
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at      timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.biopay_embeddings (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id    uuid NOT NULL REFERENCES public.biopay_profiles(id) ON DELETE CASCADE,
  embedding     extensions.vector(192) NOT NULL,
  model_version text NOT NULL DEFAULT 'mobilefacenet_int8_v1',
  quality_score double precision,
  active        boolean NOT NULL DEFAULT true,
  enrolled_at   timestamptz NOT NULL DEFAULT timezone('utc', now()),
  retired_at    timestamptz,
  created_at    timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CHECK (quality_score IS NULL OR (quality_score >= 0 AND quality_score <= 1))
);

CREATE TABLE IF NOT EXISTS public.biopay_match_events (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  matched_profile_id uuid REFERENCES public.biopay_profiles(id) ON DELETE SET NULL,
  matched           boolean NOT NULL DEFAULT false,
  score             double precision NOT NULL DEFAULT 0,
  threshold_used    double precision NOT NULL DEFAULT 0.78,
  metadata          jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at        timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.biopay_enrollment_audits (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.biopay_profiles(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  metadata   jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.biopay_revocations (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.biopay_profiles(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason     text,
  metadata   jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

-- ── Indexes ───────────────────────────────────────────────────

CREATE UNIQUE INDEX IF NOT EXISTS biopay_profiles_user_id_active_idx
  ON public.biopay_profiles(user_id)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS biopay_profiles_public_id_idx
  ON public.biopay_profiles(public_id);

CREATE INDEX IF NOT EXISTS biopay_embeddings_profile_id_idx
  ON public.biopay_embeddings(profile_id, active);

CREATE INDEX IF NOT EXISTS biopay_match_events_requester_user_idx
  ON public.biopay_match_events(requester_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS biopay_enrollment_audits_user_idx
  ON public.biopay_enrollment_audits(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS biopay_revocations_user_idx
  ON public.biopay_revocations(user_id, created_at DESC);

-- Vector similarity index (IVFFlat cosine)
CREATE INDEX IF NOT EXISTS biopay_embeddings_embedding_cosine_idx
  ON public.biopay_embeddings
  USING ivfflat (embedding extensions.vector_cosine_ops)
  WITH (lists = 64);

-- ── Triggers ──────────────────────────────────────────────────

DROP TRIGGER IF EXISTS trg_biopay_profiles_updated ON public.biopay_profiles;
CREATE TRIGGER trg_biopay_profiles_updated
BEFORE UPDATE ON public.biopay_profiles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── Helper Functions ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.generate_biopay_public_id()
RETURNS text
LANGUAGE plpgsql
VOLATILE
SET search_path = public, extensions
AS $$
DECLARE
  v_candidate text;
BEGIN
  LOOP
    v_candidate := lpad(floor(random() * 1000000)::int::text, 6, '0');
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.biopay_profiles WHERE public_id = v_candidate
    );
  END LOOP;
  RETURN v_candidate;
END;
$$;

ALTER TABLE public.biopay_profiles
ALTER COLUMN public_id SET DEFAULT public.generate_biopay_public_id();

CREATE OR REPLACE FUNCTION public.biopay_array_to_vector(p_embedding double precision[])
RETURNS extensions.vector(192)
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, extensions
AS $$
BEGIN
  IF coalesce(array_length(p_embedding, 1), 0) != 192 THEN
    RAISE EXCEPTION 'BioPay embedding must contain exactly 192 values.';
  END IF;
  RETURN ('[' || array_to_string(p_embedding, ',') || ']')::vector(192);
END;
$$;

-- ── RPC: Upsert Enrollment ────────────────────────────────────

CREATE OR REPLACE FUNCTION public.biopay_upsert_enrollment(
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
  v_user_id uuid := auth.uid();
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

  -- Upsert profile
  SELECT * INTO v_profile
  FROM public.biopay_profiles
  WHERE user_id = v_user_id AND deleted_at IS NULL
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
    WHERE id = v_profile.id
    RETURNING * INTO v_profile;
  ELSE
    INSERT INTO public.biopay_profiles (
      user_id, display_name, route_type, recipient_value,
      country_code, active, consent_version, consent_at
    ) VALUES (
      v_user_id, v_display_name, v_route_type, v_recipient_value,
      v_country_code, true, v_consent_version, timezone('utc', now())
    ) RETURNING * INTO v_profile;
  END IF;

  -- Retire old embeddings
  UPDATE public.biopay_embeddings SET
    active = false, retired_at = timezone('utc', now())
  WHERE profile_id = v_profile.id AND active = true;

  -- Insert new embedding
  INSERT INTO public.biopay_embeddings (
    profile_id, embedding, model_version, quality_score, active, enrolled_at
  ) VALUES (
    v_profile.id, v_embedding, coalesce(nullif(trim(p_model_version), ''), 'mobilefacenet_int8_v1'),
    p_quality_score, true, v_enrolled_at
  );

  -- Audit trail
  INSERT INTO public.biopay_enrollment_audits (profile_id, user_id, event_type, metadata)
  VALUES (v_profile.id, v_user_id, 'enrolled', jsonb_build_object(
    'route_type', v_route_type,
    'country_code', v_country_code,
    'model_version', coalesce(nullif(trim(p_model_version), ''), 'mobilefacenet_int8_v1')
  ));

  RETURN QUERY SELECT
    v_profile.id, v_profile.public_id, v_profile.user_id,
    v_profile.display_name, v_profile.route_type, v_profile.recipient_value,
    v_profile.country_code, v_profile.active, v_profile.consent_version,
    v_profile.consent_at, v_profile.created_at, v_profile.updated_at,
    v_profile.revoked_at, v_enrolled_at;
END;
$$;

-- ── RPC: Match Profile ────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.match_biopay_profile(
  p_embedding double precision[]
)
RETURNS TABLE (
  profile_id uuid,
  public_id text,
  user_id uuid,
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
    p.id AS profile_id, p.public_id, p.user_id, p.display_name,
    p.route_type, p.recipient_value, p.country_code, p.consent_version,
    p.consent_at, p.created_at, p.updated_at,
    1 - (e.embedding <=> q.embedding) AS score
  FROM public.biopay_embeddings e
  JOIN public.biopay_profiles p ON p.id = e.profile_id
  CROSS JOIN query_vector q
  WHERE e.active = true AND p.active = true AND p.deleted_at IS NULL
  ORDER BY e.embedding <=> q.embedding ASC
  LIMIT 1;
$$;

-- ── RPC: Revoke Profile ───────────────────────────────────────

CREATE OR REPLACE FUNCTION public.biopay_revoke_profile(
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
  v_user_id uuid := auth.uid();
  v_profile public.biopay_profiles%rowtype;
  v_revoked_at timestamptz := timezone('utc', now());
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  SELECT * INTO v_profile
  FROM public.biopay_profiles
  WHERE user_id = v_user_id AND active = true AND deleted_at IS NULL
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
  WHERE profile_id = v_profile.id AND active = true;

  INSERT INTO public.biopay_revocations (profile_id, user_id, reason, metadata)
  VALUES (v_profile.id, v_user_id,
    nullif(trim(coalesce(p_reason, '')), ''),
    jsonb_build_object('public_id', v_profile.public_id));

  INSERT INTO public.biopay_enrollment_audits (profile_id, user_id, event_type, metadata)
  VALUES (v_profile.id, v_user_id, 'revoked', jsonb_build_object(
    'reason', nullif(trim(coalesce(p_reason, '')), ''),
    'public_id', v_profile.public_id
  ));

  RETURN QUERY SELECT v_profile.id, v_profile.public_id, v_revoked_at;
END;
$$;

-- ── Grants ────────────────────────────────────────────────────

GRANT SELECT, INSERT, UPDATE ON public.biopay_profiles TO authenticated;
GRANT SELECT ON public.biopay_match_events TO authenticated;
GRANT SELECT ON public.biopay_enrollment_audits TO authenticated;
GRANT SELECT ON public.biopay_revocations TO authenticated;

GRANT EXECUTE ON FUNCTION public.biopay_upsert_enrollment(
  text, text, text, text, text, double precision[], text, double precision
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.match_biopay_profile(double precision[])
TO authenticated;

GRANT EXECUTE ON FUNCTION public.biopay_revoke_profile(text)
TO authenticated;

-- ── RLS ───────────────────────────────────────────────────────

ALTER TABLE public.biopay_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biopay_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biopay_match_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biopay_enrollment_audits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biopay_revocations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS biopay_profiles_select_own ON public.biopay_profiles;
CREATE POLICY biopay_profiles_select_own
  ON public.biopay_profiles FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS biopay_profiles_insert_own ON public.biopay_profiles;
CREATE POLICY biopay_profiles_insert_own
  ON public.biopay_profiles FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS biopay_profiles_update_own ON public.biopay_profiles;
CREATE POLICY biopay_profiles_update_own
  ON public.biopay_profiles FOR UPDATE
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS biopay_match_events_select_own ON public.biopay_match_events;
CREATE POLICY biopay_match_events_select_own
  ON public.biopay_match_events FOR SELECT USING (auth.uid() = requester_user_id);

DROP POLICY IF EXISTS biopay_enrollment_audits_select_own ON public.biopay_enrollment_audits;
CREATE POLICY biopay_enrollment_audits_select_own
  ON public.biopay_enrollment_audits FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS biopay_revocations_select_own ON public.biopay_revocations;
CREATE POLICY biopay_revocations_select_own
  ON public.biopay_revocations FOR SELECT USING (auth.uid() = user_id);

-- ── App Config ────────────────────────────────────────────────

INSERT INTO public.app_config (key, value, description) VALUES
  ('feature_biopay_enabled', 'true', 'Enable the BioPay feature module'),
  ('biopay_match_threshold', '0.78', 'Minimum cosine similarity score for a BioPay match'),
  ('biopay_cache_ttl_hours', '24', 'Hours before a cached BioPay match expires on device'),
  ('biopay_stable_frames', '3', 'Stable face frames required before BioPay capture proceeds')
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description;
