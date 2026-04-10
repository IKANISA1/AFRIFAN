-- ==========================================================================
-- AFRICLUB Prerequisite Foundation
-- ==========================================================================
-- This baseline migration restores the foundational objects that already exist
-- in the remote project but were missing from this workspace:
--   1) public.set_updated_at()
--   2) public.app_config
--   3) public.countries
--
-- Later migrations already depend on these objects, and
-- 20260330200000_phase1_multitenant_foundation.sql keeps compatible
-- CREATE IF NOT EXISTS / CREATE OR REPLACE definitions.
-- ==========================================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := timezone('utc', now());
  RETURN NEW;
END;
$$;

CREATE TABLE IF NOT EXISTS public.app_config (
  key         text PRIMARY KEY,
  value       text NOT NULL DEFAULT '',
  description text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS app_config_select_all ON public.app_config;
CREATE POLICY app_config_select_all
  ON public.app_config FOR SELECT USING (true);

CREATE TABLE IF NOT EXISTS public.countries (
  id                        text PRIMARY KEY,
  name                      text NOT NULL,
  flag                      text NOT NULL DEFAULT '',
  currency_code             text NOT NULL DEFAULT 'USD',
  phone_code                text,
  provider_id               text,
  momo_code_ussd_template   text,
  momo_number_ussd_template text,
  telecom_name              text,
  brand_name                text,
  sort_order                int NOT NULL DEFAULT 0,
  is_active                 boolean NOT NULL DEFAULT true,
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.countries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS countries_select_all ON public.countries;
CREATE POLICY countries_select_all
  ON public.countries FOR SELECT USING (true);
