-- The member portal orders active public campaigns by creation time.
-- Column ACLs apply to ORDER BY as well as the selected response columns.
-- Preserve existing row policies and the remaining private column boundary.
grant select (created_at) on table public.initiatives to authenticated;
