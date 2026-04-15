-- ============================================================================
-- admin_role_assignments does not have an updated_at column.
-- Remove the broken generic set_updated_at trigger attached to it.
-- ============================================================================

drop trigger if exists trg_admin_roles_updated
  on public.admin_role_assignments;
