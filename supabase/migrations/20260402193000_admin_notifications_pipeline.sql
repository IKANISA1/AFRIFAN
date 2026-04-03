-- ============================================================================
-- AFRICLUB Admin Notification Delivery Pipeline
-- ============================================================================
-- Adds persistent notification history for club admins, including queued and
-- delivered broadcasts backed by FCM token delivery.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.notifications (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id                   bigint NOT NULL REFERENCES public.african_football_clubs(id) ON DELETE CASCADE,
  created_by                uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  title                     text NOT NULL,
  body                      text NOT NULL,
  image_url                 text,
  audience_type             text NOT NULL DEFAULT 'all_fans'
                            CHECK (audience_type IN ('all_fans', 'by_tier', 'by_group')),
  audience_tier             text,
  audience_group_id         uuid REFERENCES public.contribution_groups(id) ON DELETE SET NULL,
  audience_group_name       text,
  delivery_mode             text NOT NULL DEFAULT 'send_now'
                            CHECK (delivery_mode IN ('send_now', 'schedule')),
  status                    text NOT NULL DEFAULT 'scheduled'
                            CHECK (status IN ('scheduled', 'processing', 'sent', 'partial', 'failed', 'cancelled')),
  scheduled_at              timestamptz,
  requested_recipient_count integer NOT NULL DEFAULT 0,
  successful_user_count     integer NOT NULL DEFAULT 0,
  failed_user_count         integer NOT NULL DEFAULT 0,
  sent_count                integer NOT NULL DEFAULT 0,
  failed_count              integer NOT NULL DEFAULT 0,
  cleaned_tokens            integer NOT NULL DEFAULT 0,
  sent_at                   timestamptz,
  last_error                text,
  delivery_summary          jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_club_created
  ON public.notifications (club_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_dispatch_queue
  ON public.notifications (status, scheduled_at)
  WHERE status = 'scheduled';

CREATE INDEX IF NOT EXISTS idx_notifications_club_status
  ON public.notifications (club_id, status, created_at DESC);

DROP TRIGGER IF EXISTS trg_notifications_updated ON public.notifications;
CREATE TRIGGER trg_notifications_updated
  BEFORE UPDATE ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notifications_select_admin ON public.notifications;
CREATE POLICY notifications_select_admin
  ON public.notifications FOR SELECT
  USING (
    club_id::text = public.requesting_club_id()
    AND public.is_club_admin(club_id)
  );

DROP POLICY IF EXISTS notifications_insert_admin ON public.notifications;
CREATE POLICY notifications_insert_admin
  ON public.notifications FOR INSERT
  WITH CHECK (
    club_id::text = public.requesting_club_id()
    AND public.is_club_admin(club_id)
  );

DROP POLICY IF EXISTS notifications_update_admin ON public.notifications;
CREATE POLICY notifications_update_admin
  ON public.notifications FOR UPDATE
  USING (
    club_id::text = public.requesting_club_id()
    AND public.is_club_admin(club_id)
  )
  WITH CHECK (
    club_id::text = public.requesting_club_id()
    AND public.is_club_admin(club_id)
  );

GRANT SELECT, INSERT, UPDATE ON public.notifications TO authenticated;
