ALTER TABLE public.biopay_payment_intents
ADD COLUMN IF NOT EXISTS amount integer;
