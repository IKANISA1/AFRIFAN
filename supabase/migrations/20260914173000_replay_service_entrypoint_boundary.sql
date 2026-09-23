-- Vendor defaults also granted service_role every baseline function. Restore
-- the existing caller boundaries without removing server-side table access
-- needed by SMS ingestion, admin operations, and venue services.
begin;

-- These APIs read the calling supporter's JWT or belong to the public read
-- client. Runtime callers live in core_auth/core_network, club_data,
-- feat_admin/feat_gamification, and web/src/lib/data/public/cms.ts (anon key).
-- Internal security-definer delegation continues under the function owner.
revoke execute on function
  public.bootstrap_supporter_profile(bigint,text,text,text,text),
  public.cancel_pending_group_contribution_payment_launch(uuid),
  public.cancel_shop_order_if_unchanged(uuid,timestamptz),
  public.cancel_ticket_if_unchanged(uuid,timestamptz),
  public.create_pending_group_contribution(uuid,integer,text,text),
  public.fixtures_calendar(date,date,text,text,integer),
  public.fixtures_date_summary(date,date,text),
  public.get_momo_sms_operational_summary(),
  public.get_runtime_app_config(text,bigint),
  public.is_super_admin(),
  public.prediction_cancel(uuid),
  public.prediction_get_active(integer,integer),
  public.prediction_get_detail(uuid),
  public.prediction_get_fixture_markets(uuid),
  public.prediction_get_history(integer,integer),
  public.prediction_get_user_badges(uuid),
  public.prediction_get_user_stats(),
  public.prediction_place(uuid,text),
  public.prediction_place_acca(jsonb),
  public.venue_checkin_validate(bigint,text,text,numeric),
  public.venue_order_create(bigint,uuid,uuid,jsonb,boolean,text)
from service_role;

-- Only the version-checked ticket mutation and authoritative membership
-- reviewer are used by the current server. The paid application flow remains
-- unavailable until an authoritative reconciliation route exists.
revoke execute on function
  public.admin_bulk_update_ticket_status(uuid[],text,bigint,uuid,text,boolean),
  public.admin_review_membership_application_if_unchanged(uuid,timestamptz,text,text,bigint,uuid,uuid),
  public.submit_membership_application(text,text,text)
from public, anon, authenticated, service_role;

-- PostgreSQL invokes these through existing triggers. They are not RPCs.
revoke execute on function
  public.rs_check_ticket_capacity(),
  public.refresh_match_ticket_sales(),
  public.rs_decrement_stock_on_order()
from public, anon, authenticated, service_role;

-- The push route upserts subscriptions and disables them on unsubscribe. It
-- does not delete rows or need schema/maintenance privileges.
revoke delete, truncate, references, trigger, maintain
on table public.web_push_subscriptions from service_role;

commit;
