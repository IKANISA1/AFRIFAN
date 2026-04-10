-- =============================================================================
-- Restrict admin phone eligibility lookup to trusted server-side callers.
-- The function returns auth-linked admin identity data and must not be callable
-- from public anon/authenticated clients.
-- =============================================================================

REVOKE ALL ON FUNCTION public.find_admin_auth_user_by_phone(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.find_admin_auth_user_by_phone(text)
  FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.find_admin_auth_user_by_phone(text)
  TO service_role, postgres, supabase_auth_admin;

NOTIFY pgrst, 'reload schema';
