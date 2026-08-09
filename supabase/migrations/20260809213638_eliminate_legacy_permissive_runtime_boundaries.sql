-- Remove baseline compatibility policies that bypass the governed club/owner
-- boundaries.  Explicit grants below also repair any hosted ACL drift without
-- relying on the default privileges of the environment that replays the file.

drop policy if exists rs_fan_club_members_select_authenticated
  on public.fan_club_members;
drop policy if exists rs_fan_club_members_insert_own
  on public.fan_club_members;
drop policy if exists rs_fan_club_members_delete_own
  on public.fan_club_members;

revoke all privileges on table public.fan_club_members
  from public, anon, authenticated;
grant select, insert, update, delete on table public.fan_club_members
  to service_role;

drop policy if exists rs_initiative_contributions_select_authenticated
  on public.initiative_contributions;
drop policy if exists rs_initiative_contributions_select_own
  on public.initiative_contributions;
drop policy if exists rs_initiative_contributions_insert_own
  on public.initiative_contributions;
drop policy if exists rs_initiative_contributions_update_own
  on public.initiative_contributions;

drop policy if exists initiative_contributions_update_own_or_admin
  on public.initiative_contributions;
create policy initiative_contributions_update_own_or_admin
  on public.initiative_contributions
  for update
  to authenticated
  using (
    club_id::text = public.requesting_club_id()
    and (user_id = (select auth.uid()) or public.is_club_admin(club_id))
  )
  with check (
    club_id::text = public.requesting_club_id()
    and (user_id = (select auth.uid()) or public.is_club_admin(club_id))
  );

revoke all privileges on table public.initiative_contributions
  from public, anon, authenticated;
grant select (initiative_id, amount, status, created_at, user_id, club_id)
  on table public.initiative_contributions to authenticated;
grant select, insert, update, delete on table public.initiative_contributions
  to service_role;

drop policy if exists momo_sms_sender_allowlist_select_authenticated
  on public.momo_sms_sender_allowlist;
revoke all privileges on table public.momo_sms_sender_allowlist
  from public, anon, authenticated;
grant select, insert, update, delete on table public.momo_sms_sender_allowlist
  to service_role;

-- These two analytical views are internal probability-engine inputs.  They
-- must never rely on view-owner privileges or remain inherited PUBLIC APIs.
alter view football.fixture_features set (security_invoker = true);
alter view football.prediction_volume set (security_invoker = true);
revoke all privileges on table football.fixture_features
  from public, anon, authenticated;
revoke all privileges on table football.prediction_volume
  from public, anon, authenticated;
grant select on table football.fixture_features to service_role;
grant select on table football.prediction_volume to service_role;
