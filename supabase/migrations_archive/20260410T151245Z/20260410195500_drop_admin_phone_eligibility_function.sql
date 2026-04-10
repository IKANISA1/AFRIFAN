-- =============================================================================
-- Remove deprecated admin phone eligibility RPC in favor of the
-- admin_phone_access table-based lookup.
-- =============================================================================

DROP FUNCTION IF EXISTS public.find_admin_auth_user_by_phone(text);

NOTIFY pgrst, 'reload schema';
