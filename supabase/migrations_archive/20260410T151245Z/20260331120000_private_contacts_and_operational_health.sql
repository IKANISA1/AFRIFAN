-- ==========================================================================
-- AFRICLUB Private Contacts + Operational Health
-- ==========================================================================
-- 1. Move private contact fields (MoMo / WhatsApp) out of public.profiles so
--    same-club reads cannot expose raw phone numbers.
-- 2. Create the operational_health_events table expected by the current
--    observability helpers and edge function contracts.
-- ==========================================================================

CREATE TABLE IF NOT EXISTS public.user_private_contacts (
  user_id         uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  club_id         bigint REFERENCES public.african_football_clubs(id),
  momo_number     text,
  momo_provider   text,
  whatsapp_number text,
  country_code    text REFERENCES public.countries(id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_private_contacts_club
  ON public.user_private_contacts (club_id);

ALTER TABLE public.user_private_contacts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_private_contacts_select_own
  ON public.user_private_contacts;
CREATE POLICY user_private_contacts_select_own
  ON public.user_private_contacts FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS user_private_contacts_insert_own
  ON public.user_private_contacts;
CREATE POLICY user_private_contacts_insert_own
  ON public.user_private_contacts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_private_contacts_update_own
  ON public.user_private_contacts;
CREATE POLICY user_private_contacts_update_own
  ON public.user_private_contacts FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP TRIGGER IF EXISTS trg_user_private_contacts_updated
  ON public.user_private_contacts;
CREATE TRIGGER trg_user_private_contacts_updated
  BEFORE UPDATE ON public.user_private_contacts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

INSERT INTO public.user_private_contacts (
  user_id,
  club_id,
  momo_number,
  whatsapp_number,
  country_code,
  created_at,
  updated_at
)
SELECT
  p.id,
  p.club_id,
  NULLIF(btrim(p.momo_number), ''),
  COALESCE(NULLIF(btrim(p.phone), ''), NULLIF(btrim(p.momo_number), '')),
  p.country_code,
  p.created_at,
  p.updated_at
FROM public.profiles p
WHERE COALESCE(NULLIF(btrim(p.momo_number), ''), NULLIF(btrim(p.phone), '')) IS NOT NULL
ON CONFLICT (user_id) DO UPDATE
SET
  club_id = COALESCE(EXCLUDED.club_id, public.user_private_contacts.club_id),
  momo_number = COALESCE(EXCLUDED.momo_number, public.user_private_contacts.momo_number),
  whatsapp_number = COALESCE(
    EXCLUDED.whatsapp_number,
    public.user_private_contacts.whatsapp_number
  ),
  country_code = COALESCE(EXCLUDED.country_code, public.user_private_contacts.country_code),
  updated_at = now();

UPDATE public.profiles
SET
  momo_number = NULL,
  phone = NULL
WHERE COALESCE(NULLIF(btrim(momo_number), ''), NULLIF(btrim(phone), '')) IS NOT NULL;

CREATE OR REPLACE FUNCTION public.sync_profile_compat_columns()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.display_name := COALESCE(
    NULLIF(btrim(NEW.display_name), ''),
    NULLIF(btrim(NEW.full_name), '')
  );
  NEW.full_name := COALESCE(
    NULLIF(btrim(NEW.full_name), ''),
    NEW.display_name
  );

  NEW.country_code := COALESCE(
    NULLIF(upper(btrim(NEW.country_code)), ''),
    NULLIF(upper(btrim(NEW.country)), '')
  );
  NEW.country := COALESCE(
    NULLIF(upper(btrim(NEW.country)), ''),
    NEW.country_code
  );

  -- Private contact details now live in public.user_private_contacts.
  NEW.momo_number := NULL;
  NEW.phone := NULL;

  NEW.language_code := COALESCE(NULLIF(btrim(NEW.language_code), ''), 'en');
  NEW.is_active := COALESCE(NEW.is_active, true);
  RETURN NEW;
END;
$$;

CREATE TABLE IF NOT EXISTS public.operational_health_events (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service       text NOT NULL,
  component     text NOT NULL DEFAULT 'general',
  status        text NOT NULL DEFAULT 'ok'
                CHECK (status IN ('ok', 'warn', 'error')),
  severity      text NOT NULL DEFAULT 'info'
                CHECK (severity IN ('info', 'warning', 'critical')),
  issue_code    text,
  message       text NOT NULL,
  function_name text,
  user_id       uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  subject_type  text,
  subject_id    text,
  metadata      jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at   timestamptz NOT NULL DEFAULT now(),
  ingest_origin text NOT NULL DEFAULT 'system'
                CHECK (ingest_origin IN ('system', 'mobile_app')),
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_operational_health_service_created
  ON public.operational_health_events (service, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_operational_health_user_created
  ON public.operational_health_events (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_operational_health_status_severity
  ON public.operational_health_events (status, severity, created_at DESC);

ALTER TABLE public.operational_health_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS operational_health_events_select_own
  ON public.operational_health_events;
CREATE POLICY operational_health_events_select_own
  ON public.operational_health_events FOR SELECT
  USING (user_id = auth.uid());

GRANT SELECT ON public.user_private_contacts TO authenticated;
GRANT INSERT, UPDATE ON public.user_private_contacts TO authenticated;
GRANT SELECT ON public.operational_health_events TO authenticated;
