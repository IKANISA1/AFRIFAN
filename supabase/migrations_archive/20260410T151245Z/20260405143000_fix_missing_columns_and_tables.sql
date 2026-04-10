-- =============================================================================
-- Fix missing columns and tables for admin portal
-- Resolves:
--   1) contribution_groups.club_id does not exist
--   2) contribution_groups.currency does not exist
--   3) membership_packages.club_id does not exist (RLS / cache)
--   4) squad_players table not found
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) contribution_groups — add missing multi-tenant columns
-- -----------------------------------------------------------------------------

ALTER TABLE public.contribution_groups
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id),
  ADD COLUMN IF NOT EXISTS partner_id text,
  ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'RWF',
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;

-- Backfill club_id for legacy rows (Rayon Sports = club 1)
UPDATE public.contribution_groups
   SET club_id = (SELECT id FROM public.african_football_clubs WHERE club_slug = 'rayon-sports' LIMIT 1)
 WHERE club_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_contribution_groups_club
  ON public.contribution_groups (club_id, is_closed, created_at DESC);

DROP TRIGGER IF EXISTS trg_contribution_groups_updated ON public.contribution_groups;
CREATE TRIGGER trg_contribution_groups_updated
  BEFORE UPDATE ON public.contribution_groups
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_contribution_groups_partner_sync ON public.contribution_groups;
CREATE TRIGGER trg_contribution_groups_partner_sync
  BEFORE INSERT OR UPDATE ON public.contribution_groups
  FOR EACH ROW EXECUTE FUNCTION public.sync_partner_club_columns();

-- RLS for contribution_groups
ALTER TABLE public.contribution_groups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS contribution_groups_select_club ON public.contribution_groups;
CREATE POLICY contribution_groups_select_club
  ON public.contribution_groups FOR SELECT
  USING (
    club_id IS NULL
    OR club_id::text = public.requesting_club_id()
  );

DROP POLICY IF EXISTS contribution_groups_admin_all ON public.contribution_groups;
CREATE POLICY contribution_groups_admin_all
  ON public.contribution_groups FOR ALL
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

GRANT SELECT, INSERT, UPDATE, DELETE ON public.contribution_groups TO authenticated;

-- -----------------------------------------------------------------------------
-- 2) contributions table — ensure club_id column exists
-- -----------------------------------------------------------------------------

ALTER TABLE public.contributions
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);

-- Backfill from group
UPDATE public.contributions c
   SET club_id = g.club_id
  FROM public.contribution_groups g
 WHERE c.group_id = g.id
   AND c.club_id IS NULL
   AND g.club_id IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 3) membership_packages — ensure RLS allows club-scoped reads
--    (club_id column already exists from previous migration)
-- -----------------------------------------------------------------------------

-- Re-create RLS policies to ensure they reference club_id correctly
DROP POLICY IF EXISTS membership_packages_select_club ON public.membership_packages;
CREATE POLICY membership_packages_select_club
  ON public.membership_packages FOR SELECT
  USING (
    club_id IS NULL
    OR club_id::text = public.requesting_club_id()
    OR is_active = true
  );

DROP POLICY IF EXISTS membership_packages_admin_all ON public.membership_packages;
CREATE POLICY membership_packages_admin_all
  ON public.membership_packages FOR ALL
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

-- -----------------------------------------------------------------------------
-- 4) squad_players — create the table
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.squad_players (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id         bigint REFERENCES public.african_football_clubs(id),
  partner_id      text,
  name            text NOT NULL,
  position        text NOT NULL DEFAULT 'Player',
  shirt_number    integer NOT NULL DEFAULT 0,
  nationality     text NOT NULL DEFAULT 'Rwanda',
  bio             text,
  image_url       text,
  photo_url       text,
  is_active       boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_squad_players_club
  ON public.squad_players (club_id, shirt_number);

DROP TRIGGER IF EXISTS trg_squad_players_updated ON public.squad_players;
CREATE TRIGGER trg_squad_players_updated
  BEFORE UPDATE ON public.squad_players
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_squad_players_partner_sync ON public.squad_players;
CREATE TRIGGER trg_squad_players_partner_sync
  BEFORE INSERT OR UPDATE ON public.squad_players
  FOR EACH ROW EXECUTE FUNCTION public.sync_partner_club_columns();

ALTER TABLE public.squad_players ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS squad_players_select_club ON public.squad_players;
CREATE POLICY squad_players_select_club
  ON public.squad_players FOR SELECT
  USING (
    club_id IS NULL
    OR club_id::text = public.requesting_club_id()
  );

DROP POLICY IF EXISTS squad_players_admin_all ON public.squad_players;
CREATE POLICY squad_players_admin_all
  ON public.squad_players FOR ALL
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

GRANT SELECT ON public.squad_players TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.squad_players TO authenticated;

-- -----------------------------------------------------------------------------
-- 5) Notify PostgREST to reload schema cache
-- -----------------------------------------------------------------------------

NOTIFY pgrst, 'reload schema';
