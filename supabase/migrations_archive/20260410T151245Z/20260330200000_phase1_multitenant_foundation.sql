-- ==========================================================================
-- AFRICLUB Phase 1 — Multi-Tenant Foundation
-- ==========================================================================
-- This migration establishes the complete multi-tenant foundation:
--
--   §1  Prerequisite utilities (set_updated_at, app_config)
--   §2  Profiles table (anonymous 6-digit alias system)
--   §3  JWT auth hook (inject club_id into JWT claims)
--   §4  Add club_id to BioPay tables + update RLS + update RPCs
--   §5  Contribution Groups + Members + Contributions tables
--   §6  Group RPCs (atomic create, invite, join)
--   §7  Rename rs_* tables → generic + add club_id
--   §8  Add club_id to SMS/MoMo tables
--   §9  Admin role assignments table
--   §10 Grants and final verification
--
-- All tables get club_id. All RLS policies enforce:
--   auth.jwt() ->> 'club_id' = club_id::text
-- ==========================================================================

-- ═══════════════════════════════════════════════════════════════════════════
-- §1 — PREREQUISITE UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════

-- Generic updated_at trigger function (idempotent)
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := timezone('utc', now());
  RETURN NEW;
END;
$$;

-- App configuration key-value store
CREATE TABLE IF NOT EXISTS public.app_config (
  key         text PRIMARY KEY,
  value       text NOT NULL DEFAULT '',
  description text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS app_config_select_all ON public.app_config;
CREATE POLICY app_config_select_all
  ON public.app_config FOR SELECT USING (true);

-- Countries table (referenced by african_football_clubs)
CREATE TABLE IF NOT EXISTS public.countries (
  id            text PRIMARY KEY,  -- ISO 3166-1 alpha-2 (e.g. 'RW')
  name          text NOT NULL,
  flag          text NOT NULL DEFAULT '',
  currency_code text NOT NULL DEFAULT 'USD',
  phone_code    text,
  provider_id   text,
  momo_code_ussd_template text,
  momo_number_ussd_template text,
  telecom_name  text,
  brand_name    text,
  sort_order    int NOT NULL DEFAULT 0,
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.countries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS countries_select_all ON public.countries;
CREATE POLICY countries_select_all
  ON public.countries FOR SELECT USING (true);


-- ═══════════════════════════════════════════════════════════════════════════
-- §2 — PROFILES TABLE (anonymous 6-digit alias system)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.profiles (
  id              uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  club_id         bigint REFERENCES public.african_football_clubs(id),
  public_user_id  text NOT NULL UNIQUE,  -- 6-digit alias e.g. '482913'
  display_name    text,                   -- optional, user never sees others'
  country_code    text REFERENCES public.countries(id),
  momo_number     text,                   -- linked MoMo for contributions
  language_code   text NOT NULL DEFAULT 'en',
  avatar_url      text,
  is_active       boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_profiles_club ON public.profiles (club_id);
CREATE INDEX IF NOT EXISTS idx_profiles_public_user_id ON public.profiles (public_user_id);

-- Generate unique 6-digit public user ID
CREATE OR REPLACE FUNCTION public.generate_public_user_id()
RETURNS text
LANGUAGE plpgsql
VOLATILE
SET search_path = public
AS $$
DECLARE
  v_candidate text;
BEGIN
  LOOP
    v_candidate := lpad(floor(random() * 1000000)::int::text, 6, '0');
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.profiles WHERE public_user_id = v_candidate
    );
  END LOOP;
  RETURN v_candidate;
END;
$$;

ALTER TABLE public.profiles
ALTER COLUMN public_user_id SET DEFAULT public.generate_public_user_id();

-- Auto-create profile on new user sign-up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, club_id, country_code)
  VALUES (
    NEW.id,
    (NEW.raw_app_meta_data ->> 'club_id')::bigint,
    COALESCE(NEW.raw_user_meta_data ->> 'country_code', 'RW')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Updated_at trigger
DROP TRIGGER IF EXISTS trg_profiles_updated ON public.profiles;
CREATE TRIGGER trg_profiles_updated
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- RLS: users see own profile
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profiles_select_own ON public.profiles;
CREATE POLICY profiles_select_own
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

-- RLS: users can read other profiles in same club (for alias display)
DROP POLICY IF EXISTS profiles_select_same_club ON public.profiles;
CREATE POLICY profiles_select_same_club
  ON public.profiles FOR SELECT
  USING (
    club_id::text = COALESCE(
      (auth.jwt() -> 'app_metadata' ->> 'club_id'),
      (auth.jwt() ->> 'club_id')
    )
  );

DROP POLICY IF EXISTS profiles_insert_own ON public.profiles;
CREATE POLICY profiles_insert_own
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS profiles_update_own ON public.profiles;
CREATE POLICY profiles_update_own
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);


-- ═══════════════════════════════════════════════════════════════════════════
-- §3 — JWT AUTH HOOK (inject club_id into tokens)
-- ═══════════════════════════════════════════════════════════════════════════
-- This function is called by Supabase Auth on every token issue/refresh.
-- It injects the user's club_id from their app_metadata into the JWT claims
-- so RLS policies can enforce multi-tenant isolation via:
--   auth.jwt() -> 'app_metadata' ->> 'club_id'
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  claims      jsonb;
  app_meta    jsonb;
  v_club_id   text;
  v_user_role text;
BEGIN
  -- Extract existing claims
  claims := event -> 'claims';
  app_meta := claims -> 'app_metadata';

  -- Get club_id from app_metadata (set during sign-up or admin assignment)
  v_club_id := COALESCE(app_meta ->> 'club_id', '');

  -- Get user role (default to 'fan')
  v_user_role := COALESCE(app_meta ->> 'role', 'fan');

  -- Inject club_id and role at the top level of claims for easy RLS access
  claims := jsonb_set(claims, '{club_id}', to_jsonb(v_club_id));
  claims := jsonb_set(claims, '{user_role}', to_jsonb(v_user_role));

  -- Return modified event
  event := jsonb_set(event, '{claims}', claims);
  RETURN event;
END;
$$;

-- Grant execute to supabase_auth_admin (required for auth hooks)
GRANT USAGE ON SCHEMA public TO supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.custom_access_token_hook(jsonb)
  TO supabase_auth_admin;
REVOKE EXECUTE ON FUNCTION public.custom_access_token_hook(jsonb)
  FROM authenticated, anon, public;


-- ═══════════════════════════════════════════════════════════════════════════
-- §4 — ADD club_id TO BIOPAY TABLES + UPDATE RLS + UPDATE RPCs
-- ═══════════════════════════════════════════════════════════════════════════

-- Helper function to extract club_id from JWT
CREATE OR REPLACE FUNCTION public.requesting_club_id()
RETURNS text
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(
    current_setting('request.jwt.claims', true)::jsonb ->> 'club_id',
    current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'club_id',
    ''
  );
$$;

-- ── Add club_id columns ──

ALTER TABLE public.biopay_profiles
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);

ALTER TABLE public.biopay_embeddings
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);

ALTER TABLE public.biopay_match_events
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);

ALTER TABLE public.biopay_enrollment_audits
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);

ALTER TABLE public.biopay_revocations
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);

ALTER TABLE public.biopay_payment_intents
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);

-- ── Indexes for club_id on BioPay ──

CREATE INDEX IF NOT EXISTS idx_biopay_profiles_club
  ON public.biopay_profiles (club_id);

CREATE INDEX IF NOT EXISTS idx_biopay_embeddings_club
  ON public.biopay_embeddings (club_id);

CREATE INDEX IF NOT EXISTS idx_biopay_match_events_club
  ON public.biopay_match_events (club_id);

CREATE INDEX IF NOT EXISTS idx_biopay_enrollment_audits_club
  ON public.biopay_enrollment_audits (club_id);

CREATE INDEX IF NOT EXISTS idx_biopay_revocations_club
  ON public.biopay_revocations (club_id);

CREATE INDEX IF NOT EXISTS idx_biopay_intents_club
  ON public.biopay_payment_intents (club_id);

-- ── Update RLS policies for BioPay (club_id isolation) ──

DROP POLICY IF EXISTS biopay_profiles_select_own ON public.biopay_profiles;
CREATE POLICY biopay_profiles_select_own
  ON public.biopay_profiles FOR SELECT
  USING (
    auth.uid() = user_id
    AND club_id::text = public.requesting_club_id()
  );

DROP POLICY IF EXISTS biopay_profiles_insert_own ON public.biopay_profiles;
CREATE POLICY biopay_profiles_insert_own
  ON public.biopay_profiles FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND club_id::text = public.requesting_club_id()
  );

DROP POLICY IF EXISTS biopay_profiles_update_own ON public.biopay_profiles;
CREATE POLICY biopay_profiles_update_own
  ON public.biopay_profiles FOR UPDATE
  USING (
    auth.uid() = user_id
    AND club_id::text = public.requesting_club_id()
  )
  WITH CHECK (
    auth.uid() = user_id
    AND club_id::text = public.requesting_club_id()
  );

DROP POLICY IF EXISTS biopay_match_events_select_own ON public.biopay_match_events;
CREATE POLICY biopay_match_events_select_own
  ON public.biopay_match_events FOR SELECT
  USING (
    auth.uid() = requester_user_id
    AND club_id::text = public.requesting_club_id()
  );

DROP POLICY IF EXISTS biopay_enrollment_audits_select_own ON public.biopay_enrollment_audits;
CREATE POLICY biopay_enrollment_audits_select_own
  ON public.biopay_enrollment_audits FOR SELECT
  USING (
    auth.uid() = user_id
    AND club_id::text = public.requesting_club_id()
  );

DROP POLICY IF EXISTS biopay_revocations_select_own ON public.biopay_revocations;
CREATE POLICY biopay_revocations_select_own
  ON public.biopay_revocations FOR SELECT
  USING (
    auth.uid() = user_id
    AND club_id::text = public.requesting_club_id()
  );

DROP POLICY IF EXISTS biopay_intents_select_own ON public.biopay_payment_intents;
CREATE POLICY biopay_intents_select_own
  ON public.biopay_payment_intents FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    AND club_id::text = public.requesting_club_id()
  );

DROP POLICY IF EXISTS biopay_intents_update_own ON public.biopay_payment_intents;
CREATE POLICY biopay_intents_update_own
  ON public.biopay_payment_intents FOR UPDATE TO authenticated
  USING (
    user_id = auth.uid()
    AND status = 'pending'
    AND club_id::text = public.requesting_club_id()
  )
  WITH CHECK (user_id = auth.uid());

-- ── Update BioPay RPCs to enforce club_id ──

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
  v_user_id uuid := auth.uid();
  v_club_id bigint;
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

  -- Derive club_id from JWT claims
  v_club_id := NULLIF(
    COALESCE(
      current_setting('request.jwt.claims', true)::jsonb ->> 'club_id',
      current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'club_id'
    ), ''
  )::bigint;

  IF v_club_id IS NULL THEN
    RAISE EXCEPTION 'Club context required. Ensure club_id is set in JWT claims.';
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

  -- Upsert profile (scoped to club_id)
  SELECT * INTO v_profile
  FROM public.biopay_profiles
  WHERE biopay_profiles.user_id = v_user_id
    AND biopay_profiles.club_id = v_club_id
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
      v_user_id, v_club_id, v_display_name, v_route_type, v_recipient_value,
      v_country_code, true, v_consent_version, timezone('utc', now())
    ) RETURNING * INTO v_profile;
  END IF;

  -- Retire old embeddings for this club
  UPDATE public.biopay_embeddings SET
    active = false, retired_at = timezone('utc', now())
  WHERE biopay_embeddings.profile_id = v_profile.id
    AND biopay_embeddings.club_id = v_club_id
    AND biopay_embeddings.active = true;

  -- Insert new embedding
  INSERT INTO public.biopay_embeddings (
    profile_id, club_id, embedding, model_version, quality_score, active, enrolled_at
  ) VALUES (
    v_profile.id, v_club_id, v_embedding,
    coalesce(nullif(trim(p_model_version), ''), 'mobilefacenet_int8_v1'),
    p_quality_score, true, v_enrolled_at
  );

  -- Audit trail
  INSERT INTO public.biopay_enrollment_audits (profile_id, user_id, club_id, event_type, metadata)
  VALUES (v_profile.id, v_user_id, v_club_id, 'enrolled', jsonb_build_object(
    'route_type', v_route_type,
    'country_code', v_country_code,
    'model_version', coalesce(nullif(trim(p_model_version), ''), 'mobilefacenet_int8_v1')
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

-- ── Face match scoped to club_id ──

CREATE OR REPLACE FUNCTION public.match_biopay_profile(
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
  ),
  requesting_club AS (
    SELECT NULLIF(
      COALESCE(
        current_setting('request.jwt.claims', true)::jsonb ->> 'club_id',
        current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'club_id'
      ), ''
    )::bigint AS cid
  )
  SELECT
    p.id AS profile_id, p.public_id, p.user_id, p.club_id,
    p.display_name, p.route_type, p.recipient_value, p.country_code,
    p.consent_version, p.consent_at, p.created_at, p.updated_at,
    1 - (e.embedding <=> q.embedding) AS score
  FROM public.biopay_embeddings e
  JOIN public.biopay_profiles p ON p.id = e.profile_id
  CROSS JOIN query_vector q
  CROSS JOIN requesting_club rc
  WHERE e.active = true
    AND p.active = true
    AND p.deleted_at IS NULL
    AND p.club_id = rc.cid -- SCOPED TO REQUESTING CLUB
  ORDER BY e.embedding <=> q.embedding ASC
  LIMIT 1;
$$;


-- ═══════════════════════════════════════════════════════════════════════════
-- §5 — CONTRIBUTION GROUPS + MEMBERS + CONTRIBUTIONS
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.contribution_groups (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id         bigint NOT NULL REFERENCES public.african_football_clubs(id),
  name            text NOT NULL,
  description     text,
  privacy         text NOT NULL DEFAULT 'private'
                  CHECK (privacy IN ('public', 'private')),
  group_type      text NOT NULL DEFAULT 'general'
                  CHECK (group_type IN ('general', 'project', 'savings', 'emergency')),
  target_amount   integer NOT NULL DEFAULT 0,
  current_total   integer NOT NULL DEFAULT 0,
  currency        text NOT NULL DEFAULT 'RWF',
  cycle_days      integer NOT NULL DEFAULT 30,
  member_count    integer NOT NULL DEFAULT 0,
  invite_code     text UNIQUE,
  creator_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  is_active       boolean NOT NULL DEFAULT true,
  momo_recipient_code text,  -- MOMO code for direct contributions
  country_code    text REFERENCES public.countries(id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_contribution_groups_club
  ON public.contribution_groups (club_id);
CREATE INDEX IF NOT EXISTS idx_contribution_groups_creator
  ON public.contribution_groups (creator_id);
CREATE INDEX IF NOT EXISTS idx_contribution_groups_invite
  ON public.contribution_groups (invite_code) WHERE invite_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contribution_groups_active
  ON public.contribution_groups (club_id, is_active) WHERE is_active = true;

-- Generate unique 8-char invite code
CREATE OR REPLACE FUNCTION public.generate_invite_code()
RETURNS text
LANGUAGE plpgsql
VOLATILE
SET search_path = public
AS $$
DECLARE
  v_code text;
  v_chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- no I/O/0/1
BEGIN
  LOOP
    v_code := '';
    FOR i IN 1..8 LOOP
      v_code := v_code || substr(v_chars, floor(random() * length(v_chars) + 1)::int, 1);
    END LOOP;
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.contribution_groups WHERE invite_code = v_code
    );
  END LOOP;
  RETURN v_code;
END;
$$;

ALTER TABLE public.contribution_groups
ALTER COLUMN invite_code SET DEFAULT public.generate_invite_code();

DROP TRIGGER IF EXISTS trg_contribution_groups_updated ON public.contribution_groups;
CREATE TRIGGER trg_contribution_groups_updated
  BEFORE UPDATE ON public.contribution_groups
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── Group Members ──

CREATE TABLE IF NOT EXISTS public.group_members (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id        uuid NOT NULL REFERENCES public.contribution_groups(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  club_id         bigint NOT NULL REFERENCES public.african_football_clubs(id),
  role            text NOT NULL DEFAULT 'member'
                  CHECK (role IN ('admin', 'moderator', 'member')),
  display_alias   text,  -- optional override alias
  is_anonymous    boolean NOT NULL DEFAULT true,
  joined_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE(group_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_group_members_group
  ON public.group_members (group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user
  ON public.group_members (user_id);
CREATE INDEX IF NOT EXISTS idx_group_members_club
  ON public.group_members (club_id);

-- ── Contributions ──

CREATE TABLE IF NOT EXISTS public.contributions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id        uuid NOT NULL REFERENCES public.contribution_groups(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  club_id         bigint NOT NULL REFERENCES public.african_football_clubs(id),
  amount          integer NOT NULL CHECK (amount > 0),
  currency        text NOT NULL DEFAULT 'RWF',
  status          text NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'confirmed', 'failed', 'reversed')),
  payment_method  text NOT NULL DEFAULT 'momo'
                  CHECK (payment_method IN ('momo', 'cash', 'bank', 'nfc')),
  external_ref    text,      -- MOMO tx ID from SMS reconciliation
  ledger_entry_id uuid,      -- FK to momo_ledger_entries (set after reconciliation)
  note            text,
  confirmed_at    timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_contributions_group
  ON public.contributions (group_id);
CREATE INDEX IF NOT EXISTS idx_contributions_user
  ON public.contributions (user_id);
CREATE INDEX IF NOT EXISTS idx_contributions_club
  ON public.contributions (club_id);
CREATE INDEX IF NOT EXISTS idx_contributions_status
  ON public.contributions (status);
CREATE INDEX IF NOT EXISTS idx_contributions_created
  ON public.contributions (group_id, created_at DESC);

DROP TRIGGER IF EXISTS trg_contributions_updated ON public.contributions;
CREATE TRIGGER trg_contributions_updated
  BEFORE UPDATE ON public.contributions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── Auto-update current_total on contribution confirm ──

CREATE OR REPLACE FUNCTION public.update_group_totals()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only act when status changes TO 'confirmed'
  IF NEW.status = 'confirmed' AND (OLD.status IS DISTINCT FROM 'confirmed') THEN
    UPDATE public.contribution_groups SET
      current_total = current_total + NEW.amount,
      updated_at = timezone('utc', now())
    WHERE id = NEW.group_id;
  END IF;

  -- If reversal, subtract
  IF NEW.status = 'reversed' AND OLD.status = 'confirmed' THEN
    UPDATE public.contribution_groups SET
      current_total = GREATEST(0, current_total - NEW.amount),
      updated_at = timezone('utc', now())
    WHERE id = NEW.group_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_contribution_update_totals ON public.contributions;
CREATE TRIGGER trg_contribution_update_totals
  AFTER UPDATE ON public.contributions
  FOR EACH ROW EXECUTE FUNCTION public.update_group_totals();

-- ── Auto-update member count ──

CREATE OR REPLACE FUNCTION public.update_group_member_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.contribution_groups SET
      member_count = member_count + 1,
      updated_at = timezone('utc', now())
    WHERE id = NEW.group_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.contribution_groups SET
      member_count = GREATEST(0, member_count - 1),
      updated_at = timezone('utc', now())
    WHERE id = OLD.group_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_group_member_count ON public.group_members;
CREATE TRIGGER trg_group_member_count
  AFTER INSERT OR DELETE ON public.group_members
  FOR EACH ROW EXECUTE FUNCTION public.update_group_member_count();

-- ── RLS for contribution tables ──

ALTER TABLE public.contribution_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contributions ENABLE ROW LEVEL SECURITY;

-- Groups: see public groups in your club, or groups you're a member of
DROP POLICY IF EXISTS groups_select_accessible ON public.contribution_groups;
CREATE POLICY groups_select_accessible
  ON public.contribution_groups FOR SELECT
  USING (
    club_id::text = public.requesting_club_id()
    AND (
      privacy = 'public'
      OR creator_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.group_members gm
        WHERE gm.group_id = id AND gm.user_id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS groups_insert_own ON public.contribution_groups;
CREATE POLICY groups_insert_own
  ON public.contribution_groups FOR INSERT
  WITH CHECK (
    auth.uid() = creator_id
    AND club_id::text = public.requesting_club_id()
  );

DROP POLICY IF EXISTS groups_update_creator ON public.contribution_groups;
CREATE POLICY groups_update_creator
  ON public.contribution_groups FOR UPDATE
  USING (
    auth.uid() = creator_id
    AND club_id::text = public.requesting_club_id()
  );

-- Group members: see co-members
DROP POLICY IF EXISTS group_members_select ON public.group_members;
CREATE POLICY group_members_select
  ON public.group_members FOR SELECT
  USING (
    club_id::text = public.requesting_club_id()
    AND (
      user_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.group_members gm2
        WHERE gm2.group_id = group_id AND gm2.user_id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS group_members_insert ON public.group_members;
CREATE POLICY group_members_insert
  ON public.group_members FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND club_id::text = public.requesting_club_id()
  );

DROP POLICY IF EXISTS group_members_delete_own ON public.group_members;
CREATE POLICY group_members_delete_own
  ON public.group_members FOR DELETE
  USING (
    user_id = auth.uid()
    AND club_id::text = public.requesting_club_id()
  );

-- Contributions: see contributions for groups you belong to
DROP POLICY IF EXISTS contributions_select ON public.contributions;
CREATE POLICY contributions_select
  ON public.contributions FOR SELECT
  USING (
    club_id::text = public.requesting_club_id()
    AND EXISTS (
      SELECT 1 FROM public.group_members gm
      WHERE gm.group_id = contributions.group_id
        AND gm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS contributions_insert ON public.contributions;
CREATE POLICY contributions_insert
  ON public.contributions FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND club_id::text = public.requesting_club_id()
  );


-- ═══════════════════════════════════════════════════════════════════════════
-- §6 — GROUP RPCs (atomic create, invite preview, join via invite)
-- ═══════════════════════════════════════════════════════════════════════════

-- Atomic group creation + creator becomes admin member
CREATE OR REPLACE FUNCTION public.create_group_atomic(
  p_name text,
  p_description text DEFAULT NULL,
  p_privacy text DEFAULT 'private',
  p_group_type text DEFAULT 'general',
  p_target_amount integer DEFAULT 0,
  p_currency text DEFAULT 'RWF',
  p_cycle_days integer DEFAULT 30,
  p_country_code text DEFAULT 'RW'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_club_id bigint;
  v_group   public.contribution_groups%rowtype;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  v_club_id := NULLIF(public.requesting_club_id(), '')::bigint;
  IF v_club_id IS NULL THEN
    RAISE EXCEPTION 'Club context required.';
  END IF;

  -- Create group
  INSERT INTO public.contribution_groups (
    club_id, name, description, privacy, group_type,
    target_amount, currency, cycle_days, creator_id, country_code
  ) VALUES (
    v_club_id, trim(p_name), nullif(trim(coalesce(p_description, '')), ''),
    p_privacy, p_group_type, p_target_amount, p_currency,
    p_cycle_days, v_user_id, p_country_code
  ) RETURNING * INTO v_group;

  -- Add creator as admin member
  INSERT INTO public.group_members (group_id, user_id, club_id, role)
  VALUES (v_group.id, v_user_id, v_club_id, 'admin');

  RETURN jsonb_build_object(
    'id', v_group.id,
    'name', v_group.name,
    'invite_code', v_group.invite_code,
    'club_id', v_group.club_id,
    'created_at', v_group.created_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_group_atomic(text, text, text, text, integer, text, integer, text)
  TO authenticated;

-- Preview invite code (returns group info without joining)
CREATE OR REPLACE FUNCTION public.preview_invite(p_invite_code text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_group public.contribution_groups%rowtype;
BEGIN
  SELECT * INTO v_group
  FROM public.contribution_groups
  WHERE invite_code = upper(trim(p_invite_code))
    AND is_active = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  RETURN jsonb_build_object(
    'found', true,
    'group_id', v_group.id,
    'name', v_group.name,
    'description', v_group.description,
    'member_count', v_group.member_count,
    'privacy', v_group.privacy,
    'group_type', v_group.group_type,
    'target_amount', v_group.target_amount,
    'current_total', v_group.current_total,
    'currency', v_group.currency,
    'club_id', v_group.club_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.preview_invite(text) TO authenticated;

-- Join group via invite code
CREATE OR REPLACE FUNCTION public.join_group_via_invite(p_invite_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_club_id bigint;
  v_group   public.contribution_groups%rowtype;
  v_already boolean;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  v_club_id := NULLIF(public.requesting_club_id(), '')::bigint;

  SELECT * INTO v_group
  FROM public.contribution_groups
  WHERE invite_code = upper(trim(p_invite_code))
    AND is_active = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid or expired invite code.');
  END IF;

  -- Ensure same club
  IF v_club_id IS NOT NULL AND v_group.club_id != v_club_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'This group belongs to a different club.');
  END IF;

  -- Check if already a member
  SELECT EXISTS(
    SELECT 1 FROM public.group_members
    WHERE group_id = v_group.id AND user_id = v_user_id
  ) INTO v_already;

  IF v_already THEN
    RETURN jsonb_build_object('success', true, 'already_member', true, 'group_id', v_group.id);
  END IF;

  -- Join
  INSERT INTO public.group_members (group_id, user_id, club_id, role)
  VALUES (v_group.id, v_user_id, COALESCE(v_club_id, v_group.club_id), 'member');

  RETURN jsonb_build_object(
    'success', true,
    'already_member', false,
    'group_id', v_group.id,
    'group_name', v_group.name
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_group_via_invite(text) TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- §7 — RENAME rs_* TABLES → GENERIC + ADD club_id
-- ═══════════════════════════════════════════════════════════════════════════

-- Rename tables (idempotent — check if new name exists first)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'rs_shop_products' AND table_schema = 'public')
     AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'shop_products' AND table_schema = 'public')
  THEN
    ALTER TABLE public.rs_shop_products RENAME TO shop_products;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'rs_news_articles' AND table_schema = 'public')
     AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'news_articles' AND table_schema = 'public')
  THEN
    ALTER TABLE public.rs_news_articles RENAME TO news_articles;
  END IF;
END $$;

-- Update RLS policies for shop_products (if table was renamed)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'shop_products' AND table_schema = 'public') THEN
    -- Drop old policies (safe if they don't exist)
    EXECUTE 'DROP POLICY IF EXISTS "Anyone can read active products" ON public.shop_products';
    EXECUTE 'DROP POLICY IF EXISTS "Admins can manage products" ON public.shop_products';

    -- Create club-scoped policies
    EXECUTE 'CREATE POLICY shop_products_select_active
      ON public.shop_products FOR SELECT
      USING (is_active = true AND club_id::text = public.requesting_club_id())';

    EXECUTE 'CREATE POLICY shop_products_admin_all
      ON public.shop_products FOR ALL
      USING (
        auth.role() = ''authenticated'' AND
        club_id::text = public.requesting_club_id() AND
        EXISTS (
          SELECT 1 FROM auth.users u
          WHERE u.id = auth.uid()
          AND (u.raw_user_meta_data ->> ''role'')::text IN (''admin'', ''club_admin'')
        )
      )';
  END IF;
END $$;

-- Update RLS policies for news_articles (if table was renamed)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'news_articles' AND table_schema = 'public') THEN
    EXECUTE 'DROP POLICY IF EXISTS "Anyone can read published articles" ON public.news_articles';
    EXECUTE 'DROP POLICY IF EXISTS "Admins can manage articles" ON public.news_articles';

    EXECUTE 'CREATE POLICY news_articles_select_published
      ON public.news_articles FOR SELECT
      USING (is_published = true AND club_id::text = public.requesting_club_id())';

    EXECUTE 'CREATE POLICY news_articles_admin_all
      ON public.news_articles FOR ALL
      USING (
        auth.role() = ''authenticated'' AND
        club_id::text = public.requesting_club_id() AND
        EXISTS (
          SELECT 1 FROM auth.users u
          WHERE u.id = auth.uid()
          AND (u.raw_user_meta_data ->> ''role'')::text IN (''admin'', ''club_admin'')
        )
      )';
  END IF;
END $$;


-- ═══════════════════════════════════════════════════════════════════════════
-- §8 — ADD club_id TO SMS/MOMO TABLES
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.momo_sms_raw
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);

ALTER TABLE public.momo_sms_parsed
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);

ALTER TABLE public.momo_ledger_entries
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);

ALTER TABLE public.momo_reconciliations
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);

ALTER TABLE public.momo_parse_attempts
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);

CREATE INDEX IF NOT EXISTS idx_momo_sms_raw_club ON public.momo_sms_raw (club_id);
CREATE INDEX IF NOT EXISTS idx_momo_sms_parsed_club ON public.momo_sms_parsed (club_id);
CREATE INDEX IF NOT EXISTS idx_momo_ledger_entries_club ON public.momo_ledger_entries (club_id);
CREATE INDEX IF NOT EXISTS idx_momo_reconciliations_club ON public.momo_reconciliations (club_id);

-- Update SMS RLS to include club_id
DROP POLICY IF EXISTS "momo_sms_raw_select_own" ON public.momo_sms_raw;
CREATE POLICY momo_sms_raw_select_own
  ON public.momo_sms_raw FOR SELECT
  USING (auth.uid() = user_id AND club_id::text = public.requesting_club_id());

DROP POLICY IF EXISTS "momo_sms_raw_insert_own" ON public.momo_sms_raw;
CREATE POLICY momo_sms_raw_insert_own
  ON public.momo_sms_raw FOR INSERT
  WITH CHECK (auth.uid() = user_id AND club_id::text = public.requesting_club_id());

DROP POLICY IF EXISTS "momo_sms_raw_update_own" ON public.momo_sms_raw;
CREATE POLICY momo_sms_raw_update_own
  ON public.momo_sms_raw FOR UPDATE
  USING (auth.uid() = user_id AND club_id::text = public.requesting_club_id())
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "momo_sms_parsed_select_own" ON public.momo_sms_parsed;
CREATE POLICY momo_sms_parsed_select_own
  ON public.momo_sms_parsed FOR SELECT
  USING (auth.uid() = user_id AND club_id::text = public.requesting_club_id());

DROP POLICY IF EXISTS "momo_ledger_entries_select_own" ON public.momo_ledger_entries;
CREATE POLICY momo_ledger_entries_select_own
  ON public.momo_ledger_entries FOR SELECT
  USING (auth.uid() = user_id AND club_id::text = public.requesting_club_id());

DROP POLICY IF EXISTS "momo_reconciliations_select_own" ON public.momo_reconciliations;
CREATE POLICY momo_reconciliations_select_own
  ON public.momo_reconciliations FOR SELECT
  USING (auth.uid() = user_id AND club_id::text = public.requesting_club_id());

DROP POLICY IF EXISTS "momo_parse_attempts_select_own" ON public.momo_parse_attempts;
CREATE POLICY momo_parse_attempts_select_own
  ON public.momo_parse_attempts FOR SELECT
  USING (auth.uid() = user_id AND club_id::text = public.requesting_club_id());


-- ═══════════════════════════════════════════════════════════════════════════
-- §9 — ADMIN ROLE ASSIGNMENTS
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.admin_role_assignments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  club_id     bigint REFERENCES public.african_football_clubs(id),  -- NULL = platform super admin
  role        text NOT NULL DEFAULT 'club_admin'
              CHECK (role IN ('super_admin', 'club_admin', 'club_moderator')),
  assigned_by uuid REFERENCES auth.users(id),
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, club_id, role)
);

CREATE INDEX IF NOT EXISTS idx_admin_roles_user
  ON public.admin_role_assignments (user_id, is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_admin_roles_club
  ON public.admin_role_assignments (club_id, is_active) WHERE is_active = true;

ALTER TABLE public.admin_role_assignments ENABLE ROW LEVEL SECURITY;

-- Super admins can see all roles
DROP POLICY IF EXISTS admin_roles_select ON public.admin_role_assignments;
CREATE POLICY admin_roles_select
  ON public.admin_role_assignments FOR SELECT
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.admin_role_assignments ar
      WHERE ar.user_id = auth.uid()
        AND ar.role = 'super_admin'
        AND ar.is_active = true
    )
  );

-- Helper: check if current user is admin for a club
CREATE OR REPLACE FUNCTION public.is_club_admin(p_club_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.admin_role_assignments
    WHERE user_id = auth.uid()
      AND is_active = true
      AND (
        role = 'super_admin'
        OR (role IN ('club_admin', 'club_moderator') AND club_id = p_club_id)
      )
  );
$$;

-- Helper: check if current user is super admin
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.admin_role_assignments
    WHERE user_id = auth.uid()
      AND role = 'super_admin'
      AND is_active = true
  );
$$;

DROP TRIGGER IF EXISTS trg_admin_roles_updated ON public.admin_role_assignments;
CREATE TRIGGER trg_admin_roles_updated
  BEFORE UPDATE ON public.admin_role_assignments
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ═══════════════════════════════════════════════════════════════════════════
-- §10 — ADMIN AUDIT LOG
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.admin_audit_log (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id),
  club_id     bigint REFERENCES public.african_football_clubs(id),
  action      text NOT NULL,
  entity_type text,        -- 'group', 'contribution', 'user', 'product', etc.
  entity_id   text,        -- UUID or ID of affected entity
  metadata    jsonb NOT NULL DEFAULT '{}'::jsonb,
  ip_address  inet,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_user
  ON public.admin_audit_log (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_club
  ON public.admin_audit_log (club_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_action
  ON public.admin_audit_log (action, entity_type);

ALTER TABLE public.admin_audit_log ENABLE ROW LEVEL SECURITY;

-- Only admins can read audit logs
DROP POLICY IF EXISTS audit_log_select_admin ON public.admin_audit_log;
CREATE POLICY audit_log_select_admin
  ON public.admin_audit_log FOR SELECT
  USING (
    public.is_super_admin()
    OR (club_id IS NOT NULL AND public.is_club_admin(club_id))
  );

-- Insert is service-role / trigger only
DROP POLICY IF EXISTS audit_log_insert_admin ON public.admin_audit_log;
CREATE POLICY audit_log_insert_admin
  ON public.admin_audit_log FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR public.is_club_admin(club_id)
  );


-- ═══════════════════════════════════════════════════════════════════════════
-- §11 — GRANTS
-- ═══════════════════════════════════════════════════════════════════════════

GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT SELECT, INSERT ON public.contribution_groups TO authenticated;
GRANT SELECT, UPDATE ON public.contribution_groups TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.group_members TO authenticated;
GRANT SELECT, INSERT ON public.contributions TO authenticated;
GRANT SELECT ON public.admin_role_assignments TO authenticated;
GRANT SELECT ON public.admin_audit_log TO authenticated;

GRANT EXECUTE ON FUNCTION public.requesting_club_id() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_club_admin(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_super_admin() TO authenticated;

-- Re-grant BioPay RPCs (signatures changed)
GRANT EXECUTE ON FUNCTION public.biopay_upsert_enrollment(
  text, text, text, text, text, double precision[], text, double precision
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.match_biopay_profile(double precision[])
TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- §12 — VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_tables text[] := ARRAY[
    'profiles', 'contribution_groups', 'group_members', 'contributions',
    'admin_role_assignments', 'admin_audit_log'
  ];
  v_table text;
  v_count int;
BEGIN
  FOREACH v_table IN ARRAY v_tables LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = v_table
    ) THEN
      RAISE WARNING 'TABLE MISSING: public.%', v_table;
    ELSE
      EXECUTE format('SELECT count(*) FROM pg_policies WHERE tablename = %L AND schemaname = %L', v_table, 'public') INTO v_count;
      RAISE NOTICE 'OK: public.% created with % RLS policies', v_table, v_count;
    END IF;
  END LOOP;

  -- Verify club_id columns added to BioPay
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'biopay_profiles' AND column_name = 'club_id'
  ) THEN
    RAISE NOTICE 'OK: BioPay tables have club_id column';
  ELSE
    RAISE WARNING 'MISSING: club_id on biopay_profiles';
  END IF;

  -- Verify JWT hook function exists
  IF EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'custom_access_token_hook'
  ) THEN
    RAISE NOTICE 'OK: JWT auth hook function exists';
  ELSE
    RAISE WARNING 'MISSING: custom_access_token_hook function';
  END IF;

  RAISE NOTICE '══════════════════════════════════════════════════';
  RAISE NOTICE 'Phase 1 migration complete. Next steps:';
  RAISE NOTICE '  1. Enable custom_access_token_hook in Supabase Auth settings';
  RAISE NOTICE '  2. Set club_id in app_metadata for all existing users';
  RAISE NOTICE '  3. Run flutter analyze to verify all packages compile';
  RAISE NOTICE '══════════════════════════════════════════════════';
END $$;
