-- ==========================================================================
-- AFRICLUB Profile + Settings Foundation
-- ==========================================================================
-- Align profile persistence with the checked-in Flutter contract and add
-- dedicated storage for privacy + notification settings.
-- ==========================================================================

-- Resolve club context from JWT when available, otherwise fall back to the
-- caller's own profile row. This keeps same-club RLS functional even when
-- anonymous sign-up metadata only lands in user_metadata.
CREATE OR REPLACE FUNCTION public.requesting_club_id()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    NULLIF(
      COALESCE(
        current_setting('request.jwt.claims', true)::jsonb ->> 'club_id',
        current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'club_id',
        current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'club_id'
      ),
      ''
    ),
    (
      SELECT p.club_id::text
      FROM public.profiles p
      WHERE p.id = auth.uid()
      LIMIT 1
    )
  );
$$;

CREATE OR REPLACE FUNCTION public.normalize_club_id(raw_club_id text)
RETURNS bigint
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
BEGIN
  IF raw_club_id IS NULL OR btrim(raw_club_id) = '' THEN
    RETURN NULL;
  END IF;

  IF raw_club_id ~ '^[0-9]+$' THEN
    RETURN raw_club_id::bigint;
  END IF;

  IF raw_club_id = 'rayon_sports_rw' THEN
    RETURN 24;
  END IF;

  RETURN NULL;
END;
$$;

DROP POLICY IF EXISTS profiles_select_same_club ON public.profiles;
CREATE POLICY profiles_select_same_club
  ON public.profiles FOR SELECT
  USING (
    club_id::text = public.requesting_club_id()
  );

CREATE TABLE IF NOT EXISTS public.user_privacy_settings (
  user_id                    uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  club_id                    bigint REFERENCES public.african_football_clubs(id),
  group_visibility           text NOT NULL DEFAULT 'members'
                             CHECK (group_visibility IN ('public', 'members', 'private')),
  analytics_enabled          boolean NOT NULL DEFAULT true,
  biometric_login_enabled    boolean NOT NULL DEFAULT true,
  show_activity_status       boolean NOT NULL DEFAULT true,
  created_at                 timestamptz NOT NULL DEFAULT now(),
  updated_at                 timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_notification_settings (
  user_id                    uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  club_id                    bigint REFERENCES public.african_football_clubs(id),
  push_enabled               boolean NOT NULL DEFAULT false,
  allow_all                  boolean NOT NULL DEFAULT false,
  match_alerts               boolean NOT NULL DEFAULT true,
  contribution_receipts      boolean NOT NULL DEFAULT true,
  xp_milestones              boolean NOT NULL DEFAULT true,
  team_news                  boolean NOT NULL DEFAULT false,
  challenges                 boolean NOT NULL DEFAULT true,
  group_chat                 boolean NOT NULL DEFAULT false,
  created_at                 timestamptz NOT NULL DEFAULT now(),
  updated_at                 timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
  id                         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id                    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  club_id                    bigint REFERENCES public.african_football_clubs(id),
  token                      text NOT NULL UNIQUE,
  device_platform            text,
  created_at                 timestamptz NOT NULL DEFAULT now(),
  updated_at                 timestamptz NOT NULL DEFAULT now(),
  last_seen_at               timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_fcm_tokens
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);

ALTER TABLE public.user_fcm_tokens
  ADD COLUMN IF NOT EXISTS device_platform text;

ALTER TABLE public.user_fcm_tokens
  ADD COLUMN IF NOT EXISTS last_seen_at timestamptz NOT NULL DEFAULT now();

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'user_fcm_tokens'
      AND column_name = 'platform'
  ) THEN
    EXECUTE $sql$
      UPDATE public.user_fcm_tokens
      SET device_platform = COALESCE(device_platform, platform)
      WHERE device_platform IS NULL
    $sql$;
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_user_privacy_settings_club
  ON public.user_privacy_settings (club_id);

CREATE INDEX IF NOT EXISTS idx_user_notification_settings_club
  ON public.user_notification_settings (club_id);

CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user
  ON public.user_fcm_tokens (user_id);

CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_club
  ON public.user_fcm_tokens (club_id);

DROP TRIGGER IF EXISTS trg_user_privacy_settings_updated ON public.user_privacy_settings;
CREATE TRIGGER trg_user_privacy_settings_updated
  BEFORE UPDATE ON public.user_privacy_settings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_user_notification_settings_updated ON public.user_notification_settings;
CREATE TRIGGER trg_user_notification_settings_updated
  BEFORE UPDATE ON public.user_notification_settings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_user_fcm_tokens_updated ON public.user_fcm_tokens;
CREATE TRIGGER trg_user_fcm_tokens_updated
  BEFORE UPDATE ON public.user_fcm_tokens
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.user_privacy_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_notification_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_privacy_settings_select_own ON public.user_privacy_settings;
CREATE POLICY user_privacy_settings_select_own
  ON public.user_privacy_settings FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS user_privacy_settings_insert_own ON public.user_privacy_settings;
CREATE POLICY user_privacy_settings_insert_own
  ON public.user_privacy_settings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_privacy_settings_update_own ON public.user_privacy_settings;
CREATE POLICY user_privacy_settings_update_own
  ON public.user_privacy_settings FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_notification_settings_select_own ON public.user_notification_settings;
CREATE POLICY user_notification_settings_select_own
  ON public.user_notification_settings FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS user_notification_settings_insert_own ON public.user_notification_settings;
CREATE POLICY user_notification_settings_insert_own
  ON public.user_notification_settings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_notification_settings_update_own ON public.user_notification_settings;
CREATE POLICY user_notification_settings_update_own
  ON public.user_notification_settings FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_fcm_tokens_select_own ON public.user_fcm_tokens;
CREATE POLICY user_fcm_tokens_select_own
  ON public.user_fcm_tokens FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS user_fcm_tokens_insert_own ON public.user_fcm_tokens;
CREATE POLICY user_fcm_tokens_insert_own
  ON public.user_fcm_tokens FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_fcm_tokens_update_own ON public.user_fcm_tokens;
CREATE POLICY user_fcm_tokens_update_own
  ON public.user_fcm_tokens FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_fcm_tokens_delete_own ON public.user_fcm_tokens;
CREATE POLICY user_fcm_tokens_delete_own
  ON public.user_fcm_tokens FOR DELETE
  USING (auth.uid() = user_id);

GRANT SELECT, INSERT, UPDATE ON public.user_privacy_settings TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.user_notification_settings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_fcm_tokens TO authenticated;

INSERT INTO public.user_privacy_settings (user_id, club_id)
SELECT id, public.normalize_club_id(club_id::text)
FROM public.profiles
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.user_notification_settings (user_id, club_id)
SELECT id, public.normalize_club_id(club_id::text)
FROM public.profiles
ON CONFLICT (user_id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_club_id bigint;
  v_country_code text;
BEGIN
  v_club_id := public.normalize_club_id(
    COALESCE(
      NEW.raw_app_meta_data ->> 'club_id',
      NEW.raw_user_meta_data ->> 'club_id'
    )
  );

  v_country_code := COALESCE(NEW.raw_user_meta_data ->> 'country_code', 'RW');

  INSERT INTO public.profiles (id, club_id, country_code)
  VALUES (NEW.id, v_club_id, v_country_code)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.user_privacy_settings (user_id, club_id)
  VALUES (NEW.id, v_club_id)
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.user_notification_settings (user_id, club_id)
  VALUES (NEW.id, v_club_id)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  claims      jsonb;
  app_meta    jsonb;
  user_meta   jsonb;
  v_club_id   text;
  v_user_role text;
BEGIN
  claims := event -> 'claims';
  app_meta := claims -> 'app_metadata';
  user_meta := claims -> 'user_metadata';

  v_club_id := COALESCE(
    app_meta ->> 'club_id',
    user_meta ->> 'club_id',
    ''
  );
  v_user_role := COALESCE(app_meta ->> 'role', 'fan');

  claims := jsonb_set(claims, '{club_id}', to_jsonb(v_club_id));
  claims := jsonb_set(claims, '{role}', to_jsonb(v_user_role));
  event := jsonb_set(event, '{claims}', claims);
  RETURN event;
END;
$$;
