-- Align BioPay payment intent schema with the active edge-function contract.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'BioPay_payment_intents'
      AND column_name = 'payment_code'
  ) AND NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'BioPay_payment_intents'
      AND column_name = 'ussd_code'
  ) THEN
    ALTER TABLE public.BioPay_payment_intents
      RENAME COLUMN payment_code TO ussd_code;
  END IF;
END $$;
