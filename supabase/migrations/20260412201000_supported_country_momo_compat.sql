DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'supported_countries'
  ) THEN
    CREATE TYPE public.supported_countries AS (
      iso_code text,
      country_name text,
      dial_code text,
      momo_provider_id text,
      momo_code_ussd_template text,
      mobile_national_number_pattern text,
      mobile_possible_lengths integer[],
      mobile_example_e164 text,
      momo_number_local_pattern text,
      momo_number_e164_pattern text,
      momo_code_pattern text,
      momo_code_min_length integer,
      momo_code_max_length integer
    );
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_supported_country_momo_config(p_country text)
RETURNS public.supported_countries
LANGUAGE plpgsql STABLE
SET search_path TO 'public'
AS $$
DECLARE
  v_country_code text := public.normalize_country_code(p_country);
  v_config public.supported_countries;
BEGIN
  WITH curated_catalog AS (
    SELECT *
    FROM (
      VALUES
        (
          'RW',
          'Rwanda',
          '+250',
          'momo_rw',
          '*182*8*1*{CODE}#',
          '^0?7[23589]\d{7}$',
          ARRAY[9, 10]::integer[],
          '+250781234567',
          '^0?7[23589]\d{7}$',
          '^\+2507[23589]\d{7}$',
          '^\d{4,9}$',
          4,
          9
        ),
        (
          'UG',
          'Uganda',
          '+256',
          'momo_ug',
          NULL,
          '^0?7[0-9]\d{7}$',
          ARRAY[9, 10]::integer[],
          '+256771234567',
          '^0?7[0-9]\d{7}$',
          '^\+2567[0-9]\d{7}$',
          NULL,
          NULL,
          NULL
        ),
        (
          'KE',
          'Kenya',
          '+254',
          'momo_ke',
          '*247*{recipient}*{amount}#',
          '^0?7[0-9]\d{7}$',
          ARRAY[9, 10]::integer[],
          '+254712345678',
          '^0?7[0-9]\d{7}$',
          '^\+2547[0-9]\d{7}$',
          '^\d{4,10}$',
          4,
          10
        ),
        (
          'TZ',
          'Tanzania',
          '+255',
          'momo_tz',
          NULL,
          '^0?[67][0-9]\d{7}$',
          ARRAY[9, 10]::integer[],
          '+255712345678',
          '^0?[67][0-9]\d{7}$',
          '^\+255[67][0-9]\d{7}$',
          NULL,
          NULL,
          NULL
        ),
        (
          'GH',
          'Ghana',
          '+233',
          'momo_gh',
          NULL,
          '^0?[235][0-9]\d{7}$',
          ARRAY[9, 10]::integer[],
          '+233241234567',
          '^0?[235][0-9]\d{7}$',
          '^\+233[235][0-9]\d{7}$',
          NULL,
          NULL,
          NULL
        )
    ) AS catalog (
      iso_code,
      country_name,
      dial_code,
      momo_provider_id,
      momo_code_ussd_template,
      mobile_national_number_pattern,
      mobile_possible_lengths,
      mobile_example_e164,
      momo_number_local_pattern,
      momo_number_e164_pattern,
      momo_code_pattern,
      momo_code_min_length,
      momo_code_max_length
    )
  ),
  current_countries AS (
    SELECT
      c.id::text AS iso_code,
      c.name::text AS country_name,
      c.dialing_code::text AS dial_code,
      'momo_' || lower(c.id::text) AS momo_provider_id,
      NULLIF(c.ussd_code_format, '')::text AS momo_code_ussd_template,
      '^[0-9]{8,12}$'::text AS mobile_national_number_pattern,
      ARRAY[8, 9, 10, 11, 12]::integer[] AS mobile_possible_lengths,
      CASE
        WHEN c.dialing_code IS NULL OR btrim(c.dialing_code) = '' THEN NULL
        ELSE c.dialing_code || '000000000'
      END AS mobile_example_e164,
      '^[0-9]{8,12}$'::text AS momo_number_local_pattern,
      CASE
        WHEN c.dialing_code IS NULL OR btrim(c.dialing_code) = '' THEN NULL
        ELSE '^\+' || replace(c.dialing_code, '+', '') || '[0-9]{6,12}$'
      END AS momo_number_e164_pattern,
      CASE
        WHEN NULLIF(c.ussd_code_format, '') IS NULL THEN NULL
        ELSE '^\d{4,12}$'
      END AS momo_code_pattern,
      CASE
        WHEN NULLIF(c.ussd_code_format, '') IS NULL THEN NULL
        ELSE 4
      END AS momo_code_min_length,
      CASE
        WHEN NULLIF(c.ussd_code_format, '') IS NULL THEN NULL
        ELSE 12
      END AS momo_code_max_length
    FROM public.countries c
    WHERE c.id = v_country_code
      AND coalesce(c.is_active, true) = true
  ),
  resolved_catalog AS (
    SELECT
      coalesce(cur.iso_code, cat.iso_code) AS iso_code,
      coalesce(cur.country_name, cat.country_name) AS country_name,
      coalesce(cur.dial_code, cat.dial_code) AS dial_code,
      coalesce(cat.momo_provider_id, cur.momo_provider_id) AS momo_provider_id,
      coalesce(cat.momo_code_ussd_template, cur.momo_code_ussd_template) AS momo_code_ussd_template,
      coalesce(cat.mobile_national_number_pattern, cur.mobile_national_number_pattern) AS mobile_national_number_pattern,
      coalesce(cat.mobile_possible_lengths, cur.mobile_possible_lengths) AS mobile_possible_lengths,
      coalesce(cat.mobile_example_e164, cur.mobile_example_e164) AS mobile_example_e164,
      coalesce(cat.momo_number_local_pattern, cur.momo_number_local_pattern) AS momo_number_local_pattern,
      coalesce(cat.momo_number_e164_pattern, cur.momo_number_e164_pattern) AS momo_number_e164_pattern,
      coalesce(cat.momo_code_pattern, cur.momo_code_pattern) AS momo_code_pattern,
      coalesce(cat.momo_code_min_length, cur.momo_code_min_length) AS momo_code_min_length,
      coalesce(cat.momo_code_max_length, cur.momo_code_max_length) AS momo_code_max_length
    FROM curated_catalog cat
    FULL OUTER JOIN current_countries cur ON cur.iso_code = cat.iso_code
    WHERE coalesce(cur.iso_code, cat.iso_code) = v_country_code
  )
  SELECT
    iso_code,
    country_name,
    dial_code,
    momo_provider_id,
    momo_code_ussd_template,
    mobile_national_number_pattern,
    mobile_possible_lengths,
    mobile_example_e164,
    momo_number_local_pattern,
    momo_number_e164_pattern,
    momo_code_pattern,
    momo_code_min_length,
    momo_code_max_length
  INTO v_config
  FROM resolved_catalog
  LIMIT 1;

  RETURN v_config;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_supported_country_momo_config(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_supported_country_momo_config(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_supported_country_momo_config(text) TO service_role;
