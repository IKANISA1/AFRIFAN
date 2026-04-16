ALTER TABLE public.BioPay_payment_intents
ADD COLUMN IF NOT EXISTS amount integer;
