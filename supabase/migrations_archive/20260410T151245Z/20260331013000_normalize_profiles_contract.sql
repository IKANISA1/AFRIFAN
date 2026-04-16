-- ==========================================================================
-- AFRICLUB Profiles Contract Normalization
-- ==========================================================================
-- Canonicalize `public.profiles` to the contract the current app writes:
--   - bigint club_id with FK to african_football_clubs
--   - non-null public_user_id
--   - non-null language_code default 'en'
--   - non-null is_active default true
-- Keep legacy columns (`full_name`, `phone`, `country`) for a compatibility
-- window, but sync them from/to the canonical columns.
-- ==========================================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS display_name text,
  ADD COLUMN IF NOT EXISTS country_code text REFERENCES public.countries(id),
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;

UPDATE public.profiles
SET
  display_name = COALESCE(
    NULLIF(btrim(display_name), ''),
    NULLIF(btrim(full_name), '')
  ),
  full_name = COALESCE(
    NULLIF(btrim(full_name), ''),
    NULLIF(btrim(display_name), '')
  ),
  country_code = COALESCE(
    NULLIF(upper(btrim(country_code)), ''),
    NULLIF(upper(btrim(country)), '')
  ),
  country = COALESCE(
    NULLIF(upper(btrim(country)), ''),
    NULLIF(upper(btrim(country_code)), '')
  ),
  momo_number = COALESCE(
    NULLIF(btrim(momo_number), ''),
    NULLIF(btrim(phone), '')
  ),
  phone = COALESCE(
    NULLIF(btrim(phone), ''),
    NULLIF(btrim(momo_number), '')
  ),
  language_code = COALESCE(NULLIF(btrim(language_code), ''), 'en'),
  is_active = COALESCE(is_active, true);

UPDATE public.profiles
SET public_user_id = public.generate_public_user_id()
WHERE public_user_id IS NULL OR btrim(public_user_id) = '';

DO $$
DECLARE
  v_unmapped_club_ids text;
  v_duplicate_ text;
BEGIN
  SELECT string_agg(club_id, ', ' ORDER BY club_id)
  INTO v_unmapped_club_ids
  FROM (
    SELECT DISTINCT club_id
    FROM public.profiles
    WHERE NULLIF(btrim(club_id), '') IS NOT NULL
      AND public.normalize_club_id(club_id) IS NULL
  ) unmapped;

  IF v_unmapped_club_ids IS NOT NULL THEN
    RAISE EXCEPTION
      'Cannot normalize public.profiles.club_id. Unmapped values: %',
      v_unmapped_club_ids;
  END IF;

  SELECT string_agg(public_user_id, ', ' ORDER BY public_user_id)
  INTO v_duplicate_
  FROM (
    SELECT public_user_id
    FROM public.profiles
    WHERE public_user_id IS NOT NULL
    GROUP BY public_user_id
    HAVING count(*) > 1
  ) duplicates;

  IF v_duplicate_ IS NOT NULL THEN
    RAISE EXCEPTION
      'Cannot enforce unique public_user_id. Duplicate values: %',
      v_duplicate_;
  END IF;
END;
$$;

ALTER TABLE public.profiles
  ALTER COLUMN club_id DROP DEFAULT,
  ALTER COLUMN club_id DROP NOT NULL;

DROP POLICY IF EXISTS profiles_select_same_club ON public.profiles;

ALTER TABLE public.profiles
  ALTER COLUMN club_id TYPE bigint
  USING public.normalize_club_id(club_id);

ALTER TABLE public.profiles
  ALTER COLUMN public_user_id SET NOT NULL,
  ALTER COLUMN language_code SET DEFAULT 'en',
  ALTER COLUMN language_code SET NOT NULL,
  ALTER COLUMN is_active SET DEFAULT true,
  ALTER COLUMN is_active SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.profiles'::regclass
      AND conname = 'profiles_club_id_fkey'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_club_id_fkey
      FOREIGN KEY (club_id)
      REFERENCES public.african_football_clubs(id);
  END IF;
END;
$$;

DROP INDEX IF EXISTS public.idx_profiles_public_user_id;
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_public_user_id
  ON public.profiles (public_user_id);

CREATE POLICY profiles_select_same_club
  ON public.profiles FOR SELECT
  USING (club_id::text = public.requesting_club_id());

DROP POLICY IF EXISTS users_insert_own_profile ON public.profiles;
DROP POLICY IF EXISTS users_read_own_profile ON public.profiles;
DROP POLICY IF EXISTS users_update_own_profile ON public.profiles;

CREATE OR REPLACE FUNCTION public.sync_profile_compat_columns()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
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

  NEW.language_code := COALESCE(NULLIF(btrim(NEW.language_code), ''), 'en');
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
  v_country_code text;
  v_display_name text;
  v_language_code text;
BEGIN
  v_club_id := public.normalize_club_id(
    COALESCE(
      NEW.raw_app_meta_data ->> 'club_id',
      NEW.raw_user_meta_data ->> 'club_id'
    )
  );

  v_country_code := COALESCE(
    NULLIF(upper(NEW.raw_user_meta_data ->> 'country_code'), ''),
    NULLIF(upper(NEW.raw_user_meta_data ->> 'country'), ''),
    'RW'
  );
  v_display_name := COALESCE(
    NULLIF(btrim(NEW.raw_user_meta_data ->> 'display_name'), ''),
    NULLIF(btrim(NEW.raw_user_meta_data ->> 'full_name'), '')
  );
  v_language_code := COALESCE(
    NULLIF(btrim(NEW.raw_user_meta_data ->> 'language_code'), ''),
    'en'
  );

  INSERT INTO public.profiles (
    id,
    club_id,
    display_name,
    full_name,
    country_code,
    country,
    language_code,
    is_active
  )
  VALUES (
    NEW.id,
    v_club_id,
    v_display_name,
    v_display_name,
    v_country_code,
    v_country_code,
    v_language_code,
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
