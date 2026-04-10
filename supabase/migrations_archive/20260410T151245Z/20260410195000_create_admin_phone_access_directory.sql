-- =============================================================================
-- Admin phone access directory
-- Maintains a server-side lookup table of admin-approved WhatsApp numbers,
-- synchronized from auth phone identities and active admin role assignments.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.admin_phone_access (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  phone text NOT NULL,
  normalized_phone text NOT NULL UNIQUE,
  club_ids bigint[] NOT NULL DEFAULT '{}',
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

COMMENT ON TABLE public.admin_phone_access IS
  'Server-side lookup table of admin-approved WhatsApp numbers for OTP gating.';

ALTER TABLE public.admin_phone_access ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.admin_phone_access FROM PUBLIC;
REVOKE ALL ON TABLE public.admin_phone_access FROM anon, authenticated;
GRANT SELECT ON TABLE public.admin_phone_access
  TO service_role, postgres, supabase_auth_admin;

CREATE OR REPLACE FUNCTION public.refresh_admin_phone_access_for_user(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_phone text;
  v_phone_digits text;
  v_club_ids bigint[];
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;

  SELECT
    COALESCE(NULLIF(u.phone, ''), i.identity_data->>'phone')
  INTO v_phone
  FROM auth.users AS u
  LEFT JOIN auth.identities AS i
    ON i.user_id = u.id
   AND i.provider = 'phone'
  WHERE u.id = p_user_id
  ORDER BY i.updated_at DESC NULLS LAST
  LIMIT 1;

  SELECT ARRAY_REMOVE(ARRAY_AGG(DISTINCT assignments.club_id), NULL)
  INTO v_club_ids
  FROM public.admin_role_assignments AS assignments
  WHERE assignments.user_id = p_user_id
    AND assignments.is_active = true
    AND assignments.role IN (
      'super_admin',
      'admin',
      'club_admin',
      'club_moderator',
      'rayon_sport',
      'bank'
    );

  v_phone_digits := regexp_replace(COALESCE(v_phone, ''), '[^0-9]', '', 'g');

  IF COALESCE(array_length(v_club_ids, 1), 0) = 0 OR v_phone_digits = '' THEN
    DELETE FROM public.admin_phone_access
    WHERE user_id = p_user_id;
    RETURN;
  END IF;

  DELETE FROM public.admin_phone_access
  WHERE normalized_phone = v_phone_digits
    AND user_id <> p_user_id;

  INSERT INTO public.admin_phone_access (
    user_id,
    phone,
    normalized_phone,
    club_ids,
    updated_at
  )
  VALUES (
    p_user_id,
    v_phone,
    v_phone_digits,
    COALESCE(v_club_ids, '{}'),
    timezone('utc', now())
  )
  ON CONFLICT (user_id) DO UPDATE
  SET phone = EXCLUDED.phone,
      normalized_phone = EXCLUDED.normalized_phone,
      club_ids = EXCLUDED.club_ids,
      updated_at = timezone('utc', now());
END;
$$;

REVOKE ALL ON FUNCTION public.refresh_admin_phone_access_for_user(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.refresh_admin_phone_access_for_user(uuid)
  FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_admin_phone_access_for_user(uuid)
  TO postgres, supabase_auth_admin;

CREATE OR REPLACE FUNCTION public.sync_admin_phone_access_from_role_assignment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  PERFORM public.refresh_admin_phone_access_for_user(COALESCE(NEW.user_id, OLD.user_id));

  IF TG_OP = 'UPDATE' AND NEW.user_id IS DISTINCT FROM OLD.user_id THEN
    PERFORM public.refresh_admin_phone_access_for_user(OLD.user_id);
  END IF;

  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_admin_phone_access_from_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  PERFORM public.refresh_admin_phone_access_for_user(COALESCE(NEW.id, OLD.id));
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_admin_phone_access_from_auth_identity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF TG_OP <> 'DELETE' AND NEW.provider = 'phone' THEN
    PERFORM public.refresh_admin_phone_access_for_user(NEW.user_id);
  END IF;

  IF TG_OP <> 'INSERT' AND OLD.provider = 'phone' THEN
    PERFORM public.refresh_admin_phone_access_for_user(OLD.user_id);
  END IF;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS admin_phone_access_role_assignment_sync
  ON public.admin_role_assignments;
CREATE TRIGGER admin_phone_access_role_assignment_sync
AFTER INSERT OR UPDATE OR DELETE ON public.admin_role_assignments
FOR EACH ROW
EXECUTE FUNCTION public.sync_admin_phone_access_from_role_assignment();

DROP TRIGGER IF EXISTS admin_phone_access_auth_user_sync
  ON auth.users;
CREATE TRIGGER admin_phone_access_auth_user_sync
AFTER INSERT OR UPDATE OF phone OR DELETE ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.sync_admin_phone_access_from_auth_user();

DROP TRIGGER IF EXISTS admin_phone_access_auth_identity_sync
  ON auth.identities;
CREATE TRIGGER admin_phone_access_auth_identity_sync
AFTER INSERT OR UPDATE OF identity_data, provider, user_id OR DELETE
ON auth.identities
FOR EACH ROW
EXECUTE FUNCTION public.sync_admin_phone_access_from_auth_identity();

DO $$
DECLARE
  assignment record;
BEGIN
  FOR assignment IN
    SELECT DISTINCT user_id
    FROM public.admin_role_assignments
  LOOP
    PERFORM public.refresh_admin_phone_access_for_user(assignment.user_id);
  END LOOP;
END
$$;

NOTIFY pgrst, 'reload schema';
