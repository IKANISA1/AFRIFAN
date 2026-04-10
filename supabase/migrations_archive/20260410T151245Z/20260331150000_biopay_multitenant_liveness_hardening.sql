-- Harden BioPay runtime/schema alignment:
-- 1. Keep the generic payment_code contract instead of drifting back to ussd_code.
-- 2. Make active BioPay enrollments unique per (user_id, club_id), not globally.
-- 3. Persist server-issued one-time liveness challenges for replay protection.
-- 4. Backfill club_id on legacy match/payment rows and tighten nullability where safe.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'biopay_payment_intents'
      AND column_name = 'ussd_code'
  ) AND NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'biopay_payment_intents'
      AND column_name = 'payment_code'
  ) THEN
    ALTER TABLE public.biopay_payment_intents
      RENAME COLUMN ussd_code TO payment_code;
  END IF;
END $$;

DROP INDEX IF EXISTS public.biopay_profiles_user_id_active_idx;

CREATE UNIQUE INDEX IF NOT EXISTS biopay_profiles_user_id_club_id_active_idx
  ON public.biopay_profiles(user_id, club_id)
  WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS public.biopay_liveness_challenges (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  club_id     bigint NOT NULL REFERENCES public.african_football_clubs(id) ON DELETE CASCADE,
  mode        text NOT NULL CHECK (mode IN ('enrollment', 'payment')),
  nonce       text NOT NULL UNIQUE,
  issued_at   timestamptz NOT NULL DEFAULT timezone('utc', now()),
  expires_at  timestamptz NOT NULL,
  consumed_at timestamptz,
  created_at  timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_biopay_liveness_challenges_user_club_mode
  ON public.biopay_liveness_challenges (user_id, club_id, mode, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_biopay_liveness_challenges_open
  ON public.biopay_liveness_challenges (expires_at)
  WHERE consumed_at IS NULL;

ALTER TABLE public.biopay_liveness_challenges ENABLE ROW LEVEL SECURITY;

UPDATE public.biopay_match_events AS event
SET club_id = profile.club_id
FROM public.biopay_profiles AS profile
WHERE event.club_id IS NULL
  AND event.matched_profile_id = profile.id;

UPDATE public.biopay_match_events AS event
SET club_id = profile.club_id
FROM public.biopay_profiles AS profile
WHERE event.club_id IS NULL
  AND profile.user_id = event.requester_user_id
  AND profile.active = true
  AND profile.deleted_at IS NULL;

UPDATE public.biopay_payment_intents AS intent
SET club_id = profile.club_id
FROM public.biopay_profiles AS profile
WHERE intent.club_id IS NULL
  AND intent.profile_id = profile.id;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.biopay_payment_intents
    WHERE club_id IS NULL
  ) THEN
    ALTER TABLE public.biopay_payment_intents
      ALTER COLUMN club_id SET NOT NULL;
  ELSE
    RAISE WARNING 'biopay_payment_intents still contains NULL club_id rows; NOT NULL not applied';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.biopay_match_events
    WHERE club_id IS NULL
  ) THEN
    ALTER TABLE public.biopay_match_events
      ALTER COLUMN club_id SET NOT NULL;
  ELSE
    RAISE WARNING 'biopay_match_events still contains NULL club_id rows; NOT NULL not applied';
  END IF;
END $$;
