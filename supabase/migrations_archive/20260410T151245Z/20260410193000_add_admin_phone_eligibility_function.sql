-- =============================================================================
-- Admin phone eligibility lookup for WhatsApp OTP
-- Lets server-side admin login flows and auth hooks verify that a phone number
-- belongs to an active admin assignment before sending any OTP.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.find_admin_auth_user_by_phone(p_phone text)
RETURNS TABLE (
  user_id uuid,
  phone text,
  club_ids bigint[]
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  WITH normalized_input AS (
    SELECT regexp_replace(COALESCE(p_phone, ''), '[^0-9]', '', 'g') AS digits
  ),
  matching_users AS (
    SELECT
      u.id AS user_id,
      COALESCE(
        NULLIF(regexp_replace(COALESCE(u.phone, ''), '[^0-9]', '', 'g'), ''),
        NULLIF(regexp_replace(COALESCE(i.identity_data->>'phone', ''), '[^0-9]', '', 'g'), '')
      ) AS user_phone_digits,
      COALESCE(NULLIF(u.phone, ''), i.identity_data->>'phone') AS raw_phone
    FROM auth.users AS u
    LEFT JOIN auth.identities AS i
      ON i.user_id = u.id
      AND i.provider = 'phone'
    CROSS JOIN normalized_input AS input
    WHERE COALESCE(
      NULLIF(regexp_replace(COALESCE(u.phone, ''), '[^0-9]', '', 'g'), ''),
      NULLIF(regexp_replace(COALESCE(i.identity_data->>'phone', ''), '[^0-9]', '', 'g'), '')
    ) = input.digits
  )
  SELECT
    users.user_id,
    users.raw_phone AS phone,
    ARRAY_REMOVE(ARRAY_AGG(DISTINCT assignments.club_id), NULL) AS club_ids
  FROM matching_users AS users
  JOIN public.admin_role_assignments AS assignments
    ON assignments.user_id = users.user_id
   AND assignments.is_active = true
   AND assignments.role IN (
     'super_admin',
     'admin',
     'club_admin',
     'club_moderator',
     'rayon_sport',
     'bank'
   )
  GROUP BY users.user_id, users.raw_phone;
$$;

REVOKE ALL ON FUNCTION public.find_admin_auth_user_by_phone(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.find_admin_auth_user_by_phone(text)
  FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.find_admin_auth_user_by_phone(text)
  TO service_role, postgres, supabase_auth_admin;

NOTIFY pgrst, 'reload schema';
