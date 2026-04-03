-- ==========================================================================
-- Add missing USSD patterns for 6 new countries in the countries table
-- ==========================================================================
-- The user reported that while the countries (BI, TG, CG, GA, BJ, CD) 
-- were inserted, their ussd_code_format and ussd_number_format 
-- columns were missing data.
-- ==========================================================================

-- Burundi (BI) - Lumitel
UPDATE public.countries
SET 
  ussd_code_format   = '*150*2*{amount}*{momo}#',
  ussd_number_format = '*150*2*{amount}*{momo}#'
WHERE id = 'BI';

-- Togo (TG) - Moov
UPDATE public.countries
SET 
  ussd_code_format   = '*144*{amount}*{momo}#',
  ussd_number_format = '*144*{amount}*{momo}#'
WHERE id = 'TG';

-- Congo (Republic) (CG) - Airtel
UPDATE public.countries
SET 
  ussd_code_format   = '*144*{amount}*{momo}#',
  ussd_number_format = '*144*{amount}*{momo}#'
WHERE id = 'CG';

-- Gabon (GA) - Airtel
UPDATE public.countries
SET 
  ussd_code_format   = '*126*{amount}*{momo}#',
  ussd_number_format = '*126*{amount}*{momo}#'
WHERE id = 'GA';

-- Benin (BJ) - MTN
UPDATE public.countries
SET 
  ussd_code_format   = '*144*{amount}*{momo}#',
  ussd_number_format = '*144*{amount}*{momo}#'
WHERE id = 'BJ';

-- DR Congo (CD) - Vodacom (m-Pesa)
UPDATE public.countries
SET 
  ussd_code_format   = '*126*1*1*{amount}*{momo}#',
  ussd_number_format = '*126*1*1*{amount}*{momo}#'
WHERE id = 'CD';
