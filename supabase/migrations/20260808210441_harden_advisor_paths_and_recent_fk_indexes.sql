-- Resolve the current code-owned Supabase advisor findings without rewriting
-- previously applied migration history or changing the public RPC contract.

-- Every affected function now has an immutable lookup path. The two public
-- fixture read RPCs retain their existing unqualified public-view reference;
-- pg_temp remains last and no untrusted API role can CREATE in public.
alter function africlub_game.current_club_id()
  set search_path = '';
alter function africlub_game.normalize_question_prompt(text)
  set search_path = '';
alter function football._seed_fixture(text, text, text, text, timestamp with time zone, text, text)
  set search_path = '';
alter function football._seed_season(text, text, integer, integer)
  set search_path = '';
alter function football._seed_team(text, text, text, integer, text)
  set search_path = '';
alter function football.auto_lock_fixture_markets()
  set search_path = '';
alter function football.kickoff_date(timestamp with time zone)
  set search_path = '';
alter function football.prediction_fixture_club_id(uuid)
  set search_path = '';
alter function football.prediction_seed_outcomes(text, jsonb)
  set search_path = '';
alter function public.canonicalize_platform_feature_key(text)
  set search_path = '';
alter function public.compat_parse_partner_id(text)
  set search_path = '';
alter function public.fixtures_calendar(date, date, text, text, integer)
  set search_path = public, pg_temp;
alter function public.fixtures_date_summary(date, date, text)
  set search_path = public, pg_temp;
alter function public.populate_group_message_defaults()
  set search_path = '';
alter function public.populate_event_club_scope()
  set search_path = '';
alter function public.refresh_match_ticket_sales()
  set search_path = '';
alter function public.resolve_fan_tier(integer)
  set search_path = '';
alter function public.set_updated_at()
  set search_path = '';
alter function public.sync_fan_club_member_scope()
  set search_path = '';
alter function public.sync_fan_membership_defaults()
  set search_path = '';
alter function public.sync_group_member_count()
  set search_path = '';
alter function public.sync_initiative_contribution_scope()
  set search_path = '';
alter function public.sync_partner_club_columns()
  set search_path = '';
alter function public.sync_ticket_scope()
  set search_path = '';
alter function public.update_fan_club_member_count()
  set search_path = '';
alter function public.update_group_member_count()
  set search_path = '';
alter function public.update_group_totals()
  set search_path = '';

-- This SECURITY DEFINER function is a trigger implementation, not a callable
-- API. Trigger execution does not require callers to hold EXECUTE on it.
revoke execute on function football.auto_lock_fixture_markets()
  from public, anon, authenticated, service_role;

-- Cover each foreign-key lookup introduced by the recent live-game and venue
-- migration tranche. All affected production relations are currently empty or
-- small, so ordinary atomic index creation is the safer deterministic path.
create index if not exists idx_display_assignments_assigned_by
  on africlub_game.display_assignments (assigned_by);
create index if not exists idx_display_assignments_club_id
  on africlub_game.display_assignments (club_id);
create index if not exists idx_display_bootstrap_challenges_consumed_by
  on africlub_game.display_bootstrap_challenges (consumed_by);
create index if not exists idx_display_bootstrap_challenges_display_id
  on africlub_game.display_bootstrap_challenges (display_id);
create index if not exists idx_display_pairing_challenges_club_id
  on africlub_game.display_pairing_challenges (club_id);
create index if not exists idx_display_pairing_challenges_consumed_by
  on africlub_game.display_pairing_challenges (consumed_by);
create index if not exists idx_display_pairing_challenges_display_id
  on africlub_game.display_pairing_challenges (display_id);
create index if not exists idx_game_events_actor_id
  on africlub_game.game_events (actor_id);
create index if not exists idx_game_events_club_id
  on africlub_game.game_events (club_id);
create index if not exists idx_operation_requests_club_id
  on africlub_game.operation_requests (club_id);
create index if not exists idx_role_grants_granted_by
  on africlub_game.role_grants (granted_by);
create index if not exists idx_role_grants_user_id
  on africlub_game.role_grants (user_id);
create index if not exists idx_role_grants_venue_id
  on africlub_game.role_grants (venue_id);
create index if not exists idx_session_eligibility_club_id
  on africlub_game.session_eligibility (club_id);
create index if not exists idx_session_eligibility_created_by
  on africlub_game.session_eligibility (created_by);
create index if not exists idx_session_invitations_club_id
  on africlub_game.session_invitations (club_id);
create index if not exists idx_session_invitations_invited_by
  on africlub_game.session_invitations (invited_by);
create index if not exists idx_session_invitations_user_id
  on africlub_game.session_invitations (user_id);
create index if not exists idx_session_organizers_assigned_by
  on africlub_game.session_organizers (assigned_by);
create index if not exists idx_session_organizers_club_id
  on africlub_game.session_organizers (club_id);
create index if not exists idx_session_organizers_user_id
  on africlub_game.session_organizers (user_id);
create index if not exists idx_transition_requests_actor_id
  on africlub_game.transition_requests (actor_id);
create index if not exists idx_transition_requests_club_id
  on africlub_game.transition_requests (club_id);
create index if not exists idx_tv_devices_owner_user_id
  on africlub_game.tv_devices (owner_user_id);
create index if not exists idx_tv_devices_venue_id
  on africlub_game.tv_devices (venue_id);
create index if not exists idx_venue_staff_audit_events_venue_id
  on public.venue_staff_audit_events (venue_id);
