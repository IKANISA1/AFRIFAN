-- ============================================================================
-- Rayon / AFRICLUB live match state support
-- ============================================================================
-- Adds live-state columns to public.matches so the mobile live center can be
-- driven from the existing admin workflow and synchronized over Realtime.
-- ============================================================================

ALTER TABLE public.matches
  ADD COLUMN IF NOT EXISTS match_status text NOT NULL DEFAULT 'scheduled',
  ADD COLUMN IF NOT EXISTS home_score integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS away_score integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS live_minute integer,
  ADD COLUMN IF NOT EXISTS match_summary text,
  ADD COLUMN IF NOT EXISTS live_stats jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS live_events jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS is_featured boolean NOT NULL DEFAULT false;

UPDATE public.matches
SET match_status = CASE
  WHEN match_date < now() THEN 'fulltime'
  ELSE 'scheduled'
END
WHERE match_status IS NULL OR btrim(match_status) = '';

UPDATE public.matches
SET home_score = GREATEST(COALESCE(home_score, 0), 0),
    away_score = GREATEST(COALESCE(away_score, 0), 0)
WHERE home_score IS NULL OR away_score IS NULL;

CREATE INDEX IF NOT EXISTS idx_matches_live_status
  ON public.matches (club_id, match_status, match_date);

CREATE INDEX IF NOT EXISTS idx_matches_featured
  ON public.matches (club_id, is_featured, match_date);
