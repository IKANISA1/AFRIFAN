begin;

-- Venue access resolves the signed-in user's membership and assigned venue
-- through the authenticated client. RLS already limits both queries, but the
-- baseline omitted the membership identity/filter/order column grants.
-- Keep private assignment notes and all direct mutation privileges private.
grant select (id, club_id, venue_id, user_id, role, is_active, granted_at)
  on table public.venue_staff_memberships to authenticated;
commit;
