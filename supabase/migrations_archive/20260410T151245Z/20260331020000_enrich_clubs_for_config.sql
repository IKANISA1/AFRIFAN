-- ==========================================================================
-- AfriClub — Enrich clubs table for ClubConfig contract
-- ==========================================================================
-- The ClubConfig interface requires: slug, MOMO template, currency,
-- currency symbol, default language, hex colors, and feature flags.
-- This migration adds those columns and populates the 20 Phase-1 clubs.
-- ==========================================================================

-- ══════════════════════════════════════════════════════════════════════════
-- §1 — Add missing columns
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.african_football_clubs
  ADD COLUMN IF NOT EXISTS club_slug             text UNIQUE,
  ADD COLUMN IF NOT EXISTS momo_prefix           text,
  ADD COLUMN IF NOT EXISTS momo_ussd_template    text,
  ADD COLUMN IF NOT EXISTS momo_sender_name      text,
  ADD COLUMN IF NOT EXISTS currency_code         text NOT NULL DEFAULT 'USD',
  ADD COLUMN IF NOT EXISTS currency_symbol       text NOT NULL DEFAULT '$',
  ADD COLUMN IF NOT EXISTS default_language      text NOT NULL DEFAULT 'en',
  ADD COLUMN IF NOT EXISTS primary_color_hex     text,
  ADD COLUMN IF NOT EXISTS secondary_color_hex   text,
  ADD COLUMN IF NOT EXISTS accent_color_hex      text,
  ADD COLUMN IF NOT EXISTS supported_languages   text[] NOT NULL DEFAULT '{en}',
  ADD COLUMN IF NOT EXISTS feature_flags         jsonb NOT NULL DEFAULT '{"biopay":true,"shop":true,"fan_clubs":true,"ticketing":true,"chat":true,"sms_ledger":true}';

CREATE INDEX IF NOT EXISTS idx_afc_slug ON public.african_football_clubs (club_slug) WHERE club_slug IS NOT NULL;

COMMENT ON COLUMN public.african_football_clubs.club_slug IS 'URL-safe tenant slug e.g. rayon_sports_rw — used as ClubConfig.clubId and JWT claim';
COMMENT ON COLUMN public.african_football_clubs.momo_ussd_template IS 'USSD template e.g. *182*8*1*{amount}*{momo}# — placeholders: {amount}, {momo}';

-- ══════════════════════════════════════════════════════════════════════════
-- §2 — Insert missing country rows
-- ══════════════════════════════════════════════════════════════════════════
-- Several clubs reference countries not yet in the countries table.

INSERT INTO public.countries (id, name, flag, currency, dialing_code, telecom_provider, momo_brand, is_active)
VALUES
  ('BI', 'Burundi',          '🇧🇮', 'BIF', '+257', 'Lumitel',    'Lumitel MoMo', true),
  ('TG', 'Togo',             '🇹🇬', 'XOF', '+228', 'Moov',      'Moov Money',   true),
  ('CG', 'Congo (Republic)', '🇨🇬', 'XAF', '+242', 'Airtel',    'Airtel Money', true),
  ('GA', 'Gabon',            '🇬🇦', 'XAF', '+241', 'Airtel',    'Airtel Money', true),
  ('BJ', 'Benin',            '🇧🇯', 'XOF', '+229', 'MTN',       'MTN MoMo',     true),
  ('CD', 'DR Congo',         '🇨🇩', 'CDF', '+243', 'Vodacom',   'm-Pesa',       true)
ON CONFLICT (id) DO UPDATE SET
  name               = EXCLUDED.name,
  flag               = EXCLUDED.flag,
  currency           = EXCLUDED.currency,
  dialing_code       = EXCLUDED.dialing_code,
  telecom_provider   = EXCLUDED.telecom_provider,
  momo_brand         = EXCLUDED.momo_brand,
  is_active          = true;

-- Also fix NULL country_iso_code for clubs that reference these countries
UPDATE public.african_football_clubs SET country_iso_code = 'BI' WHERE club_name = 'Vital''O FC'       AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'BI' WHERE club_name = 'Musongati FC'      AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'TG' WHERE club_name = 'ASKO de Kara'      AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'TG' WHERE club_name = 'Maranatha FC'      AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'ML' WHERE club_name = 'Djoliba AC'        AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'ML' WHERE club_name = 'Stade Malien'      AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'NE' WHERE club_name = 'Sahel SC'          AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'NE' WHERE club_name = 'Espoir FC de Zinder' AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'BF' WHERE club_name = 'ASFA Yennenga'     AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'BF' WHERE club_name = 'Étoile Filante'    AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'AO' WHERE club_name = 'Petro de Luanda'   AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'AO' WHERE club_name = 'Primeiro de Agosto' AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'SO' WHERE club_name = 'Elman FC'          AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'SO' WHERE club_name = 'Banadir Stars'     AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'SS' WHERE club_name = 'Atlabara FC'       AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'SS' WHERE club_name = 'Al-Hilal Juba FC'  AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'TD' WHERE club_name = 'Foullah Edifice FC' AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'TD' WHERE club_name = 'AS Coton Chad'     AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'CF' WHERE club_name = 'AS Tempête Mocaf'  AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'CF' WHERE club_name = 'Olympique Réal de Bangui' AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'MR' WHERE club_name = 'FC Nouadhibou'     AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'MR' WHERE club_name = 'ASC Ksar'          AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'LS' WHERE club_name = 'Bantu FC'          AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'LS' WHERE club_name = 'Lesotho Mounted Police' AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'NA' WHERE club_name = 'African Stars FC'  AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'NA' WHERE club_name = 'Black Africa FC'   AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'KM' WHERE club_name = 'Volcan Club'       AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'KM' WHERE club_name = 'Fomboni SC'        AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'ER' WHERE club_name = 'Red Sea FC'        AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'ER' WHERE club_name = 'Asha FC'           AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'GM' WHERE club_name = 'Real de Banjul FC' AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'GM' WHERE club_name = 'Gambia Armed Forces' AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'GQ' WHERE club_name = 'Deportivo Mongomo' AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'GQ' WHERE club_name = 'Leones Vegetarianos FC' AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'MU' WHERE club_name = 'AS Port-Louis 2000' AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'MU' WHERE club_name = 'Pamplemousses SC'  AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'DJ' WHERE club_name = 'AS Arta/Solar7'    AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'DJ' WHERE club_name = 'AS Port'           AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'CV' WHERE club_name = 'Sporting Clube de Praia' AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'CV' WHERE club_name = 'FC Académica do Porto Novo' AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'ST' WHERE club_name = 'Sporting Praia Cruz' AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'ST' WHERE club_name = 'FC Porto Real'     AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'SC' WHERE club_name = 'St. Michel United FC' AND country_iso_code IS NULL;
UPDATE public.african_football_clubs SET country_iso_code = 'SC' WHERE club_name = 'Anse Reunion FC'   AND country_iso_code IS NULL;

-- ══════════════════════════════════════════════════════════════════════════
-- §3 — Populate config data for all 20 Phase-1 clubs
-- ══════════════════════════════════════════════════════════════════════════

-- Rayon Sports FC (pilot — already live)
UPDATE public.african_football_clubs SET
  club_slug            = 'rayon_sports_rw',
  momo_prefix          = '*182*',
  momo_ussd_template   = '*182*8*1*{amount}*{momo}#',
  momo_sender_name     = 'MTN MoMo',
  currency_code        = 'RWF',
  currency_symbol      = 'FRw',
  default_language     = 'rw',
  primary_color_hex    = '#C8102E',
  secondary_color_hex  = '#0A0F2C',
  accent_color_hex     = '#D4A017',
  supported_languages  = '{rw,fr,en}',
  feature_flags        = '{"biopay":true,"shop":true,"fan_clubs":true,"ticketing":true,"chat":true,"sms_ledger":true}',
  updated_at           = now()
WHERE club_name = 'Rayon Sports FC';

-- Vital'O FC (Burundi)
UPDATE public.african_football_clubs SET
  club_slug            = 'vitalo_bi',
  momo_prefix          = '*150*',
  momo_ussd_template   = '*150*2*{amount}*{momo}#',
  momo_sender_name     = 'Lumitel MoMo',
  currency_code        = 'BIF',
  currency_symbol      = 'FBu',
  default_language     = 'fr',
  primary_color_hex    = '#7B2D8E',
  secondary_color_hex  = '#FFFFFF',
  accent_color_hex     = '#FFD700',
  supported_languages  = '{fr,rn,en}',
  feature_flags        = '{"biopay":true,"shop":true,"fan_clubs":true,"ticketing":true,"chat":true,"sms_ledger":true}',
  updated_at           = now()
WHERE club_name = 'Vital''O FC';

-- Young Africans (Yanga) — Tanzania
UPDATE public.african_football_clubs SET
  club_slug            = 'yanga_tz',
  momo_prefix          = '*150*',
  momo_ussd_template   = '*150*00*{amount}*{momo}#',
  momo_sender_name     = 'Tigo Pesa',
  currency_code        = 'TZS',
  currency_symbol      = 'TSh',
  default_language     = 'sw',
  primary_color_hex    = '#006B3F',
  secondary_color_hex  = '#FFD700',
  accent_color_hex     = '#FFFFFF',
  supported_languages  = '{sw,en}',
  feature_flags        = '{"biopay":true,"shop":true,"fan_clubs":true,"ticketing":true,"chat":true,"sms_ledger":true}',
  updated_at           = now()
WHERE club_name = 'Young Africans (Yanga)';

-- TP Mazembe — DR Congo
UPDATE public.african_football_clubs SET
  club_slug            = 'tp_mazembe_cd',
  momo_prefix          = '*126*',
  momo_ussd_template   = '*126*1*1*{amount}*{momo}#',
  momo_sender_name     = 'm-Pesa',
  currency_code        = 'CDF',
  currency_symbol      = 'FC',
  default_language     = 'fr',
  primary_color_hex    = '#000000',
  secondary_color_hex  = '#FFFFFF',
  accent_color_hex     = '#C0C0C0',
  supported_languages  = '{fr,ln,en}',
  feature_flags        = '{"biopay":true,"shop":true,"fan_clubs":true,"ticketing":true,"chat":true,"sms_ledger":true}',
  updated_at           = now()
WHERE club_name = 'TP Mazembe';

-- Simba SC — Tanzania
UPDATE public.african_football_clubs SET
  club_slug            = 'simba_tz',
  momo_prefix          = '*150*',
  momo_ussd_template   = '*150*00*{amount}*{momo}#',
  momo_sender_name     = 'Tigo Pesa',
  currency_code        = 'TZS',
  currency_symbol      = 'TSh',
  default_language     = 'sw',
  primary_color_hex    = '#CC0000',
  secondary_color_hex  = '#FFFFFF',
  accent_color_hex     = '#FFD700',
  supported_languages  = '{sw,en}',
  feature_flags        = '{"biopay":true,"shop":true,"fan_clubs":true,"ticketing":true,"chat":true,"sms_ledger":true}',
  updated_at           = now()
WHERE club_name = 'Simba SC';

-- AS Vita Club — DR Congo
UPDATE public.african_football_clubs SET
  club_slug            = 'as_vita_cd',
  momo_prefix          = '*126*',
  momo_ussd_template   = '*126*1*1*{amount}*{momo}#',
  momo_sender_name     = 'm-Pesa',
  currency_code        = 'CDF',
  currency_symbol      = 'FC',
  default_language     = 'fr',
  primary_color_hex    = '#006400',
  secondary_color_hex  = '#000000',
  accent_color_hex     = '#FFD700',
  supported_languages  = '{fr,ln,en}',
  feature_flags        = '{"biopay":true,"shop":true,"fan_clubs":true,"ticketing":true,"chat":true,"sms_ledger":true}',
  updated_at           = now()
WHERE club_name = 'AS Vita Club';

-- Asante Kotoko SC — Ghana
UPDATE public.african_football_clubs SET
  club_slug            = 'asante_kotoko_gh',
  momo_prefix          = '*170*',
  momo_ussd_template   = '*170*1*{amount}*{momo}#',
  momo_sender_name     = 'MTN MoMo',
  currency_code        = 'GHS',
  currency_symbol      = 'GH₵',
  default_language     = 'en',
  primary_color_hex    = '#CC0000',
  secondary_color_hex  = '#FFFFFF',
  accent_color_hex     = '#FFD700',
  supported_languages  = '{en,ak,tw}',
  feature_flags        = '{"biopay":true,"shop":true,"fan_clubs":true,"ticketing":true,"chat":true,"sms_ledger":true}',
  updated_at           = now()
WHERE club_name = 'Asante Kotoko SC';

-- ASEC Mimosas — Côte d'Ivoire
UPDATE public.african_football_clubs SET
  club_slug            = 'asec_mimosas_ci',
  momo_prefix          = '*144*',
  momo_ussd_template   = '*144*4*{amount}*{momo}#',
  momo_sender_name     = 'Orange Money',
  currency_code        = 'XOF',
  currency_symbol      = 'CFA',
  default_language     = 'fr',
  primary_color_hex    = '#FFD700',
  secondary_color_hex  = '#000000',
  accent_color_hex     = '#FF8C00',
  supported_languages  = '{fr,en}',
  feature_flags        = '{"biopay":true,"shop":true,"fan_clubs":true,"ticketing":true,"chat":true,"sms_ledger":true}',
  updated_at           = now()
WHERE club_name = 'ASEC Mimosas';

-- Nyasa Big Bullets FC — Malawi
UPDATE public.african_football_clubs SET
  club_slug            = 'nyasa_bullets_mw',
  momo_prefix          = '*414*',
  momo_ussd_template   = '*414*{amount}*{momo}#',
  momo_sender_name     = 'Airtel Money',
  currency_code        = 'MWK',
  currency_symbol      = 'MK',
  default_language     = 'en',
  primary_color_hex    = '#CC0000',
  secondary_color_hex  = '#FFFFFF',
  accent_color_hex     = '#000000',
  supported_languages  = '{en,ny}',
  feature_flags        = '{"biopay":true,"shop":true,"fan_clubs":true,"ticketing":true,"chat":true,"sms_ledger":true}',
  updated_at           = now()
WHERE club_name = 'Nyasa Big Bullets FC';

-- Dynamos FC — Zimbabwe
UPDATE public.african_football_clubs SET
  club_slug            = 'dynamos_zw',
  momo_prefix          = '*153*',
  momo_ussd_template   = '*153*2*{amount}*{momo}#',
  momo_sender_name     = 'EcoCash',
  currency_code        = 'USD',
  currency_symbol      = '$',
  default_language     = 'en',
  primary_color_hex    = '#0000CC',
  secondary_color_hex  = '#FFFFFF',
  accent_color_hex     = '#FFD700',
  supported_languages  = '{en,sn}',
  feature_flags        = '{"biopay":true,"shop":true,"fan_clubs":true,"ticketing":true,"chat":true,"sms_ledger":true}',
  updated_at           = now()
WHERE club_name = 'Dynamos FC';

-- Africa Sports National — Côte d'Ivoire
UPDATE public.african_football_clubs SET
  club_slug            = 'africa_sports_ci',
  momo_prefix          = '*144*',
  momo_ussd_template   = '*144*4*{amount}*{momo}#',
  momo_sender_name     = 'Orange Money',
  currency_code        = 'XOF',
  currency_symbol      = 'CFA',
  default_language     = 'fr',
  primary_color_hex    = '#006B3F',
  secondary_color_hex  = '#CC0000',
  accent_color_hex     = '#FFFFFF',
  supported_languages  = '{fr,en}',
  feature_flags        = '{"biopay":true,"shop":true,"fan_clubs":true,"ticketing":true,"chat":true,"sms_ledger":true}',
  updated_at           = now()
WHERE club_name = 'Africa Sports National';

-- Nkana FC — Zambia
UPDATE public.african_football_clubs SET
  club_slug            = 'nkana_zm',
  momo_prefix          = '*303*',
  momo_ussd_template   = '*303*{amount}*{momo}#',
  momo_sender_name     = 'Airtel Money',
  currency_code        = 'ZMW',
  currency_symbol      = 'ZK',
  default_language     = 'en',
  primary_color_hex    = '#CC0000',
  secondary_color_hex  = '#FFFFFF',
  accent_color_hex     = '#000000',
  supported_languages  = '{en,bem}',
  feature_flags        = '{"biopay":true,"shop":true,"fan_clubs":true,"ticketing":true,"chat":true,"sms_ledger":true}',
  updated_at           = now()
WHERE club_name = 'Nkana FC';

-- Canon Yaoundé — Cameroon
UPDATE public.african_football_clubs SET
  club_slug            = 'canon_yaounde_cm',
  momo_prefix          = '*126*',
  momo_ussd_template   = '*126*1*{amount}*{momo}#',
  momo_sender_name     = 'Orange Money',
  currency_code        = 'XAF',
  currency_symbol      = 'FCFA',
  default_language     = 'fr',
  primary_color_hex    = '#006B3F',
  secondary_color_hex  = '#CC0000',
  accent_color_hex     = '#FFD700',
  supported_languages  = '{fr,en}',
  feature_flags        = '{"biopay":true,"shop":true,"fan_clubs":true,"ticketing":true,"chat":true,"sms_ledger":true}',
  updated_at           = now()
WHERE club_name = 'Canon Yaoundé';

-- Union Douala — Cameroon
UPDATE public.african_football_clubs SET
  club_slug            = 'union_douala_cm',
  momo_prefix          = '*126*',
  momo_ussd_template   = '*126*1*{amount}*{momo}#',
  momo_sender_name     = 'Orange Money',
  currency_code        = 'XAF',
  currency_symbol      = 'FCFA',
  default_language     = 'fr',
  primary_color_hex    = '#006B3F',
  secondary_color_hex  = '#FFFFFF',
  accent_color_hex     = '#000000',
  supported_languages  = '{fr,en}',
  feature_flags        = '{"biopay":true,"shop":true,"fan_clubs":true,"ticketing":true,"chat":true,"sms_ledger":true}',
  updated_at           = now()
WHERE club_name = 'Union Douala';

-- ZESCO United FC — Zambia
UPDATE public.african_football_clubs SET
  club_slug            = 'zesco_united_zm',
  momo_prefix          = '*303*',
  momo_ussd_template   = '*303*{amount}*{momo}#',
  momo_sender_name     = 'Airtel Money',
  currency_code        = 'ZMW',
  currency_symbol      = 'ZK',
  default_language     = 'en',
  primary_color_hex    = '#006B3F',
  secondary_color_hex  = '#FF8C00',
  accent_color_hex     = '#FFFFFF',
  supported_languages  = '{en,bem}',
  feature_flags        = '{"biopay":true,"shop":true,"fan_clubs":true,"ticketing":true,"chat":true,"sms_ledger":true}',
  updated_at           = now()
WHERE club_name = 'ZESCO United FC';

-- ASKO de Kara — Togo
UPDATE public.african_football_clubs SET
  club_slug            = 'asko_kara_tg',
  momo_prefix          = '*144*',
  momo_ussd_template   = '*144*{amount}*{momo}#',
  momo_sender_name     = 'Moov Money',
  currency_code        = 'XOF',
  currency_symbol      = 'CFA',
  default_language     = 'fr',
  primary_color_hex    = '#FFD700',
  secondary_color_hex  = '#006B3F',
  accent_color_hex     = '#000000',
  supported_languages  = '{fr,ee,en}',
  feature_flags        = '{"biopay":true,"shop":true,"fan_clubs":true,"ticketing":true,"chat":true,"sms_ledger":true}',
  updated_at           = now()
WHERE club_name = 'ASKO de Kara';

-- AC Léopards — Congo Republic
UPDATE public.african_football_clubs SET
  club_slug            = 'ac_leopards_cg',
  momo_prefix          = '*144*',
  momo_ussd_template   = '*144*{amount}*{momo}#',
  momo_sender_name     = 'Airtel Money',
  currency_code        = 'XAF',
  currency_symbol      = 'FCFA',
  default_language     = 'fr',
  primary_color_hex    = '#006B3F',
  secondary_color_hex  = '#FFFFFF',
  accent_color_hex     = '#000000',
  supported_languages  = '{fr,ln,en}',
  feature_flags        = '{"biopay":true,"shop":true,"fan_clubs":true,"ticketing":true,"chat":true,"sms_ledger":true}',
  updated_at           = now()
WHERE club_name = 'AC Léopards';

-- Maranatha FC — Togo
UPDATE public.african_football_clubs SET
  club_slug            = 'maranatha_tg',
  momo_prefix          = '*144*',
  momo_ussd_template   = '*144*{amount}*{momo}#',
  momo_sender_name     = 'Moov Money',
  currency_code        = 'XOF',
  currency_symbol      = 'CFA',
  default_language     = 'fr',
  primary_color_hex    = '#CC0000',
  secondary_color_hex  = '#FFFFFF',
  accent_color_hex     = '#FFD700',
  supported_languages  = '{fr,ee,en}',
  feature_flags        = '{"biopay":true,"shop":true,"fan_clubs":true,"ticketing":true,"chat":true,"sms_ledger":true}',
  updated_at           = now()
WHERE club_name = 'Maranatha FC';

-- AS Mangasport — Gabon
UPDATE public.african_football_clubs SET
  club_slug            = 'as_mangasport_ga',
  momo_prefix          = '*126*',
  momo_ussd_template   = '*126*{amount}*{momo}#',
  momo_sender_name     = 'Airtel Money',
  currency_code        = 'XAF',
  currency_symbol      = 'FCFA',
  default_language     = 'fr',
  primary_color_hex    = '#FFD700',
  secondary_color_hex  = '#006B3F',
  accent_color_hex     = '#000000',
  supported_languages  = '{fr,en}',
  feature_flags        = '{"biopay":true,"shop":true,"fan_clubs":true,"ticketing":true,"chat":true,"sms_ledger":true}',
  updated_at           = now()
WHERE club_name = 'AS Mangasport';

-- Mogas 90 FC — Benin
UPDATE public.african_football_clubs SET
  club_slug            = 'mogas_90_bj',
  momo_prefix          = '*144*',
  momo_ussd_template   = '*144*{amount}*{momo}#',
  momo_sender_name     = 'MTN MoMo',
  currency_code        = 'XOF',
  currency_symbol      = 'CFA',
  default_language     = 'fr',
  primary_color_hex    = '#006B3F',
  secondary_color_hex  = '#FFFFFF',
  accent_color_hex     = '#CC0000',
  supported_languages  = '{fr,en}',
  feature_flags        = '{"biopay":true,"shop":true,"fan_clubs":true,"ticketing":true,"chat":true,"sms_ledger":true}',
  updated_at           = now()
WHERE club_name = 'Mogas 90 FC';

-- ══════════════════════════════════════════════════════════════════════════
-- §4 — Verify
-- ══════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count
  FROM public.african_football_clubs
  WHERE club_slug IS NOT NULL;
  RAISE NOTICE 'Clubs with slug populated: %', v_count;
END $$;
