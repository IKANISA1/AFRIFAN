-- ==========================================================================
-- AFRICLUB Fix — Profiles/Auth Bootstrap Compatibility
-- ==========================================================================
-- The remote project still has the legacy `profiles` shape
-- (`full_name`, `phone`, `country`, text `club_id`) while newer auth/profile
-- code already assumes the normalized columns (`display_name`,
-- `country_code`, `is_active`).
--
-- Result: `public.handle_new_user()` fails during anonymous signup because it
-- tries to insert `country_code` into `public.profiles` before that column
-- exists.
--
-- This migration restores compatibility without changing screen UI:
--   1. Add the normalized columns expected by the current app.
--   2. Backfill from the legacy columns.
--   3. Normalize existing text club identifiers to numeric-text values.
--   4. Keep legacy and normalized profile fields synchronized.
--   5. Replace `handle_new_user()` with a version that writes both shapes.
-- ==========================================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS display_name text,
  ADD COLUMN IF NOT EXISTS country_code text REFERENCES public.countries(id),
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;

UPDATE public.profiles
SET
  club_id = COALESCE(public.normalize_club_id(club_id)::text, club_id),
  display_name = COALESCE(
    NULLIF(btrim(display_name), ''),
    NULLIF(btrim(full_name), '')
  ),
  country_code = COALESCE(
    NULLIF(upper(btrim(country_code)), ''),
    NULLIF(upper(btrim(country)), '')
  ),
  momo_number = COALESCE(
    NULLIF(btrim(momo_number), ''),
    NULLIF(btrim(phone), '')
  ),
  is_active = COALESCE(is_active, true);

CREATE OR REPLACE FUNCTION public.sync_profile_compat_columns()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.club_id := COALESCE(
    public.normalize_club_id(NEW.club_id)::text,
    NULLIF(btrim(NEW.club_id), ''),
    ''
  );

  NEW.display_name := COALESCE(
    NULLIF(btrim(NEW.display_name), ''),
    NULLIF(btrim(NEW.full_name), '')
  );
  NEW.full_name := COALESCE(
    NULLIF(btrim(NEW.full_name), ''),
    NEW.display_name
  );

  NEW.country_code := COALESCE(
    NULLIF(upper(btrim(NEW.country_code)), ''),
    NULLIF(upper(btrim(NEW.country)), '')
  );
  NEW.country := COALESCE(
    NULLIF(upper(btrim(NEW.country)), ''),
    NEW.country_code
  );

  NEW.momo_number := COALESCE(
    NULLIF(btrim(NEW.momo_number), ''),
    NULLIF(btrim(NEW.phone), '')
  );
  NEW.phone := COALESCE(
    NULLIF(btrim(NEW.phone), ''),
    NEW.momo_number
  );

  NEW.is_active := COALESCE(NEW.is_active, true);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_sync_compat_columns ON public.profiles;
CREATE TRIGGER trg_profiles_sync_compat_columns
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.sync_profile_compat_columns();

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_club_id bigint;
  v_club_id_text text;
  v_country_code text;
  v_display_name text;
BEGIN
  v_club_id := public.normalize_club_id(
    COALESCE(
      NEW.raw_app_meta_data ->> 'club_id',
      NEW.raw_user_meta_data ->> 'club_id'
    )
  );
  v_club_id_text := COALESCE(v_club_id::text, '');

  v_country_code := COALESCE(
    NULLIF(upper(NEW.raw_user_meta_data ->> 'country_code'), ''),
    NULLIF(upper(NEW.raw_user_meta_data ->> 'country'), ''),
    'RW'
  );
  v_display_name := COALESCE(
    NULLIF(btrim(NEW.raw_user_meta_data ->> 'display_name'), ''),
    NULLIF(btrim(NEW.raw_user_meta_data ->> 'full_name'), '')
  );

  INSERT INTO public.profiles (
    id,
    club_id,
    display_name,
    full_name,
    country_code,
    country,
    is_active
  )
  VALUES (
    NEW.id,
    v_club_id_text,
    v_display_name,
    v_display_name,
    v_country_code,
    v_country_code,
    true
  )
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
