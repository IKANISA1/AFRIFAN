-- Drop dead legacy public RPCs that are no longer referenced by this repo and
-- currently fail database lint because their backing tables/columns are gone.
--
-- Kept out of this migration intentionally:
-- - purchase_club_tickets: still called by feat_club.
-- - prediction_admin_settle: still called by feat_admin.
-- - allocate_momo_manual_review / admin_reject_momo_sms_manual_review_batch:
--   still called by the admin SMS workspace.

do $$
begin
  execute 'drop function if exists public.award_cool_achievement(uuid, text, integer)';
  execute 'drop function if exists public.confirm_contribution(uuid)';
  execute 'drop function if exists public.create_group_atomic(text, text, text, text, bigint, text, integer, text, bigint, text, text, text, uuid)';
  execute 'drop function if exists public.get_admin_groups_summary()';
  execute 'drop function if exists public.get_bank_analytics_summary(uuid)';
  execute 'drop function if exists public.get_platform_analytics_summary()';
  execute 'drop function if exists public.get_rs_notifications(uuid, integer, integer)';
  execute 'drop function if exists public.purge_mock_batch(text)';
  execute 'drop function if exists public.send_rs_match_notification(uuid, text, text)';
end
$$;
