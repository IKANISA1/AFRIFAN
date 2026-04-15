-- ============================================================================
-- Ensure the core AfriClub MoMo countries are present in every environment.
-- Mirrors the canonical rows already present in the linked remote project.
-- ============================================================================

INSERT INTO public.countries (
  id,
  name,
  flag,
  dialing_code,
  currency,
  phone_placeholder,
  is_active,
  sort_order,
  telecom_provider,
  momo_brand,
  ussd_number_format,
  ussd_code_format,
  currency_name
)
VALUES
  (
    'CD',
    'DR Congo',
    '🇨🇩',
    '+243',
    'CDF',
    '000 000 000',
    true,
    12,
    'Vodacom',
    'm-Pesa',
    '*126*1*1*{amount}*{momo}#',
    '*126*1*1*{amount}*{momo}#',
    'Congolese Franc'
  ),
  (
    'RW',
    'Rwanda',
    '🇷🇼',
    '+250',
    'RWF',
    '000 000 000',
    true,
    35,
    'MTN Rwanda',
    'MTN MoMo',
    '*182*1*1*{PHONE}#',
    '*182*8*1*{CODE}#',
    'Rwandan Franc'
  ),
  (
    'ZM',
    'Zambia',
    '🇿🇲',
    '+260',
    'ZMW',
    '000 000 000',
    true,
    47,
    'MTN Zambia',
    'MTN MoMo',
    '*303*1*{PHONE}#',
    '*303*4*{CODE}#',
    'Zambian Kwacha'
  )
ON CONFLICT (id) DO UPDATE
SET
  name = EXCLUDED.name,
  flag = EXCLUDED.flag,
  dialing_code = EXCLUDED.dialing_code,
  currency = EXCLUDED.currency,
  phone_placeholder = EXCLUDED.phone_placeholder,
  is_active = EXCLUDED.is_active,
  sort_order = EXCLUDED.sort_order,
  telecom_provider = EXCLUDED.telecom_provider,
  momo_brand = EXCLUDED.momo_brand,
  ussd_number_format = EXCLUDED.ussd_number_format,
  ussd_code_format = EXCLUDED.ussd_code_format,
  currency_name = EXCLUDED.currency_name;
