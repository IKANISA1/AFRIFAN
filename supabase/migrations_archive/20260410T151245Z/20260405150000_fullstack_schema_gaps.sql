-- =============================================================================
-- Fix all remaining fullstack schema gaps
-- Found via systematic audit of web app code vs remote DB
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) standings — create table (none of the candidates exist)
--    Code candidates: standings, league_standings, club_standings, rs_standings
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.standings (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id         bigint REFERENCES public.african_football_clubs(id),
  partner_id      text,
  position        integer NOT NULL DEFAULT 1,
  club_name       text NOT NULL DEFAULT '',
  club_slug       text,
  played          integer NOT NULL DEFAULT 0,
  won             integer NOT NULL DEFAULT 0,
  drawn           integer NOT NULL DEFAULT 0,
  lost            integer NOT NULL DEFAULT 0,
  goals_for       integer NOT NULL DEFAULT 0,
  goals_against   integer NOT NULL DEFAULT 0,
  goal_difference integer NOT NULL DEFAULT 0,
  points          integer NOT NULL DEFAULT 0,
  form            text[] DEFAULT '{}',
  season          text,
  league          text,
  is_active       boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_standings_club_position
  ON public.standings (club_id, position);

DROP TRIGGER IF EXISTS trg_standings_updated ON public.standings;
CREATE TRIGGER trg_standings_updated
  BEFORE UPDATE ON public.standings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.standings ENABLE ROW LEVEL SECURITY;

-- Anon + authenticated can read standings
DROP POLICY IF EXISTS standings_public_read ON public.standings;
CREATE POLICY standings_public_read
  ON public.standings FOR SELECT
  USING (true);

-- Admin can manage standings
DROP POLICY IF EXISTS standings_admin_all ON public.standings;
CREATE POLICY standings_admin_all
  ON public.standings FOR ALL
  USING (
    club_id IS NULL
    OR (
      club_id::text = public.requesting_club_id()
      AND public.is_club_admin(club_id)
    )
  )
  WITH CHECK (
    club_id IS NULL
    OR (
      club_id::text = public.requesting_club_id()
      AND public.is_club_admin(club_id)
    )
  );

GRANT SELECT ON public.standings TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.standings TO authenticated;


-- -----------------------------------------------------------------------------
-- 2) membership_packages — add annual_price and price columns
--    Code reads: row.annual_price, row.price
--    Code writes: annual_price, price (via mutateRecordWithVariants)
-- -----------------------------------------------------------------------------

ALTER TABLE public.membership_packages
  ADD COLUMN IF NOT EXISTS annual_price numeric(12,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS price numeric(12,2) DEFAULT 0;


-- -----------------------------------------------------------------------------
-- 3) fan_clubs — add is_active column
--    Code writes: is_active in saveAdminFanClub
-- -----------------------------------------------------------------------------

ALTER TABLE public.fan_clubs
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;


-- -----------------------------------------------------------------------------
-- 4) news_articles — add author_name column
--    Code reads: row.author_name (falls back to "Club Media")
-- -----------------------------------------------------------------------------

ALTER TABLE public.news_articles
  ADD COLUMN IF NOT EXISTS author_name text DEFAULT 'Club Media';


-- -----------------------------------------------------------------------------
-- 5) squad_players — add anon SELECT policy for fans PWA public reads
-- -----------------------------------------------------------------------------

DROP POLICY IF EXISTS squad_players_public_read ON public.squad_players;
CREATE POLICY squad_players_public_read
  ON public.squad_players FOR SELECT TO anon
  USING (is_active = true);

GRANT SELECT ON public.squad_players TO anon;


-- -----------------------------------------------------------------------------
-- 6) contribution_groups — ensure anon can read public groups
--    (fans PWA uses getAdminSupabase which is service_role, but belt-and-braces)
-- -----------------------------------------------------------------------------

DROP POLICY IF EXISTS contribution_groups_public_read ON public.contribution_groups;
CREATE POLICY contribution_groups_public_read
  ON public.contribution_groups FOR SELECT TO anon
  USING (
    is_active = true
    AND privacy = 'public'
  );


-- -----------------------------------------------------------------------------
-- 7) membership_packages — ensure anon can read active packages
-- -----------------------------------------------------------------------------

DROP POLICY IF EXISTS membership_packages_public_read ON public.membership_packages;
CREATE POLICY membership_packages_public_read
  ON public.membership_packages FOR SELECT TO anon
  USING (is_active = true);


-- -----------------------------------------------------------------------------
-- 8) news_articles — ensure existing cover_image_url alias works
--    Code reads row.cover_image_url || row.image_url
--    image_url exists, but add cover_image_url as a generated column alias
-- -----------------------------------------------------------------------------

-- No action needed: code falls back cleanly to image_url


-- -----------------------------------------------------------------------------
-- 9) Notify PostgREST to reload schema cache
-- -----------------------------------------------------------------------------

NOTIFY pgrst, 'reload schema';
