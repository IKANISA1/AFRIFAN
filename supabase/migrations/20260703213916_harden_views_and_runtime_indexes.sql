-- Harden exposed catalog views and add covering indexes for new game/venue runtime foreign keys.
-- Generated from Supabase advisors and live catalog inventory on 2026-07-03.

-- Postgres 15+ supports security_invoker views; this keeps Data API reads subject to caller RLS.
alter view "public"."football_fixtures_catalog" set (security_invoker = true);
alter view "public"."prediction_supported_fixtures_catalog" set (security_invoker = true);
alter view "public"."rs_initiative_contributions" set (security_invoker = true);
alter view "public"."rs_initiatives" set (security_invoker = true);
alter view "public"."rs_matches" set (security_invoker = true);
alter view "public"."rs_shop_orders" set (security_invoker = true);
alter view "public"."rs_tickets" set (security_invoker = true);
alter view "public"."unified_matches" set (security_invoker = true);
alter view "public"."unified_roster" set (security_invoker = true);
alter view "public"."unified_standings" set (security_invoker = true);

-- Cover foreign-key columns used by joins, deletes, and RLS checks on the new runtime surfaces.
create index if not exists "idx_africlub_game_answer_attempts_club_id"
  on "africlub_game"."answer_attempts" ("club_id");
create index if not exists "idx_africlub_game_answer_attempts_session_id"
  on "africlub_game"."answer_attempts" ("session_id");
create index if not exists "idx_africlub_game_answer_attempts_session_player_id"
  on "africlub_game"."answer_attempts" ("session_player_id");
create index if not exists "idx_africlub_game_answer_claims_answer_attempt_id"
  on "africlub_game"."answer_claims" ("answer_attempt_id");
create index if not exists "idx_africlub_game_answer_claims_club_id"
  on "africlub_game"."answer_claims" ("club_id");
create index if not exists "idx_africlub_game_answer_claims_session_id"
  on "africlub_game"."answer_claims" ("session_id");
create index if not exists "idx_africlub_game_answer_claims_session_player_id"
  on "africlub_game"."answer_claims" ("session_player_id");
create index if not exists "idx_africlub_game_answer_claims_team_id"
  on "africlub_game"."answer_claims" ("team_id");
create index if not exists "idx_africlub_game_audit_log_actor_id"
  on "africlub_game"."audit_log" ("actor_id");
create index if not exists "idx_africlub_game_audit_log_club_id"
  on "africlub_game"."audit_log" ("club_id");
create index if not exists "idx_africlub_game_game_sessions_created_by"
  on "africlub_game"."game_sessions" ("created_by");
create index if not exists "idx_africlub_game_game_sessions_current_session_qu_dfosa6"
  on "africlub_game"."game_sessions" ("current_session_question_id");
create index if not exists "idx_africlub_game_game_sessions_pack_id"
  on "africlub_game"."game_sessions" ("pack_id");
create index if not exists "idx_africlub_game_game_sessions_template_id"
  on "africlub_game"."game_sessions" ("template_id");
create index if not exists "idx_africlub_game_game_sessions_tv_device_id"
  on "africlub_game"."game_sessions" ("tv_device_id");
create index if not exists "idx_africlub_game_game_templates_created_by"
  on "africlub_game"."game_templates" ("created_by");
create index if not exists "idx_africlub_game_points_ledger_session_id"
  on "africlub_game"."points_ledger" ("session_id");
create index if not exists "idx_africlub_game_points_ledger_user_id"
  on "africlub_game"."points_ledger" ("user_id");
create index if not exists "idx_africlub_game_question_drafts_club_id"
  on "africlub_game"."question_drafts" ("club_id");
create index if not exists "idx_africlub_game_question_drafts_reviewed_by"
  on "africlub_game"."question_drafts" ("reviewed_by");
create index if not exists "idx_africlub_game_question_drafts_source_id"
  on "africlub_game"."question_drafts" ("source_id");
create index if not exists "idx_africlub_game_question_pack_questions_club_id"
  on "africlub_game"."question_pack_questions" ("club_id");
create index if not exists "idx_africlub_game_question_pack_questions_question_id"
  on "africlub_game"."question_pack_questions" ("question_id");
create index if not exists "idx_africlub_game_question_packs_club_id"
  on "africlub_game"."question_packs" ("club_id");
create index if not exists "idx_africlub_game_question_packs_created_by"
  on "africlub_game"."question_packs" ("created_by");
create index if not exists "idx_africlub_game_question_packs_published_by"
  on "africlub_game"."question_packs" ("published_by");
create index if not exists "idx_africlub_game_question_packs_template_id"
  on "africlub_game"."question_packs" ("template_id");
create index if not exists "idx_africlub_game_question_sources_club_id"
  on "africlub_game"."question_sources" ("club_id");
create index if not exists "idx_africlub_game_questions_approved_by"
  on "africlub_game"."questions" ("approved_by");
create index if not exists "idx_africlub_game_questions_club_id"
  on "africlub_game"."questions" ("club_id");
create index if not exists "idx_africlub_game_questions_source_id"
  on "africlub_game"."questions" ("source_id");
create index if not exists "idx_africlub_game_session_players_club_id"
  on "africlub_game"."session_players" ("club_id");
create index if not exists "idx_africlub_game_session_players_team_id"
  on "africlub_game"."session_players" ("team_id");
create index if not exists "idx_africlub_game_session_players_user_id"
  on "africlub_game"."session_players" ("user_id");
create index if not exists "idx_africlub_game_session_questions_club_id"
  on "africlub_game"."session_questions" ("club_id");
create index if not exists "idx_africlub_game_session_questions_question_id"
  on "africlub_game"."session_questions" ("question_id");
create index if not exists "idx_africlub_game_session_teams_club_id"
  on "africlub_game"."session_teams" ("club_id");
create index if not exists "idx_africlub_game_tv_devices_created_by"
  on "africlub_game"."tv_devices" ("created_by");
create index if not exists "idx_africlub_game_tv_devices_current_session_id"
  on "africlub_game"."tv_devices" ("current_session_id");
create index if not exists "idx_public_fet_ledger_reservations_venue_id"
  on "public"."fet_ledger_reservations" ("venue_id");
create index if not exists "idx_public_venue_checkin_campaigns_venue_id"
  on "public"."venue_checkin_campaigns" ("venue_id");
create index if not exists "idx_public_venue_checkin_codes_venue_id"
  on "public"."venue_checkin_codes" ("venue_id");
create index if not exists "idx_public_venue_checkins_campaign_id"
  on "public"."venue_checkins" ("campaign_id");
create index if not exists "idx_public_venue_checkins_code_id"
  on "public"."venue_checkins" ("code_id");
create index if not exists "idx_public_venue_checkins_venue_id"
  on "public"."venue_checkins" ("venue_id");
create index if not exists "idx_public_venue_drink_items_venue_id"
  on "public"."venue_drink_items" ("venue_id");
create index if not exists "idx_public_venue_drink_order_items_club_id"
  on "public"."venue_drink_order_items" ("club_id");
create index if not exists "idx_public_venue_drink_order_items_drink_item_id"
  on "public"."venue_drink_order_items" ("drink_item_id");
create index if not exists "idx_public_venue_drink_order_items_venue_id"
  on "public"."venue_drink_order_items" ("venue_id");
create index if not exists "idx_public_venue_drink_orders_checkin_id"
  on "public"."venue_drink_orders" ("checkin_id");
create index if not exists "idx_public_venue_drink_orders_venue_id"
  on "public"."venue_drink_orders" ("venue_id");
create index if not exists "idx_public_venue_fet_wallets_venue_id"
  on "public"."venue_fet_wallets" ("venue_id");
create index if not exists "idx_public_venue_order_events_club_id"
  on "public"."venue_order_events" ("club_id");
create index if not exists "idx_public_venue_order_events_venue_id"
  on "public"."venue_order_events" ("venue_id");
create index if not exists "idx_public_venue_promotion_events_campaign_id"
  on "public"."venue_promotion_events" ("campaign_id");
create index if not exists "idx_public_venue_promotion_events_checkin_id"
  on "public"."venue_promotion_events" ("checkin_id");
create index if not exists "idx_public_venue_promotion_events_venue_id"
  on "public"."venue_promotion_events" ("venue_id");
create index if not exists "idx_public_venue_staff_memberships_venue_id"
  on "public"."venue_staff_memberships" ("venue_id");
