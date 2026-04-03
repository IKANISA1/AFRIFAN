-- ═══════════════════════════════════════════════════════════════════════════
-- Fix: infinite recursion in admin_role_assignments SELECT RLS policy
--
-- The original policy self-references admin_role_assignments to check
-- if the requesting user is a super_admin, which triggers the same
-- policy evaluation → infinite recursion (Postgres error 42P17).
--
-- Fix: use the existing SECURITY DEFINER function is_super_admin()
-- which queries the table directly and bypasses RLS.
-- ═══════════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS admin_roles_select ON public.admin_role_assignments;

CREATE POLICY admin_roles_select
  ON public.admin_role_assignments FOR SELECT
  USING (
    -- Users can always read their own role assignments
    user_id = auth.uid()
    -- Super admins can read all assignments (via SECURITY DEFINER function)
    OR public.is_super_admin()
  );
