-- ============================================================================
-- Prediction notifications read model
-- Exposes the authenticated user's prediction notifications through a public
-- invoker view so mobile clients can read a stable feed without querying the
-- football schema directly.
-- ============================================================================

create or replace view public.prediction_notifications_feed
with (security_invoker = true) as
select
  pn.id,
  pn.user_id,
  pn.notification_type,
  pn.title,
  pn.body,
  pn.payload,
  pn.is_sent,
  pn.sent_at,
  pn.created_at
from football.prediction_notifications pn;

grant select on public.prediction_notifications_feed to authenticated;
