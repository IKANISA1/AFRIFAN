-- ==============================================================================
-- Migration: Phase 2 Schema Normalization & Multi-Tenant Finalization
-- Description: Renames lingering 'rs_*' Rayon Sports tables to generic names, 
-- adds `club_id` columns to all unmigrated gamification schemas, and enforces 
-- strict RLS boundaries for full multi-tenancy.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- §1: RENAME LINGERING SINGLE-TENANT TABLES
-- ------------------------------------------------------------------------------

DO $$
BEGIN
  -- Gamification Badges/Achievements
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'rs_achievements' AND table_schema = 'public') 
     AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'achievements' AND table_schema = 'public') THEN
    ALTER TABLE public.rs_achievements RENAME TO achievements;
  END IF;

  -- Fan Clubs
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'rs_fan_clubs' AND table_schema = 'public') THEN
    ALTER TABLE public.rs_fan_clubs RENAME TO fan_clubs;
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'rs_fan_club_members' AND table_schema = 'public') THEN
    ALTER TABLE public.rs_fan_club_members RENAME TO fan_club_members;
  END IF;

  -- Ticketing & Matches
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'rs_matches' AND table_schema = 'public') THEN
    ALTER TABLE public.rs_matches RENAME TO matches;
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'rs_tickets' AND table_schema = 'public') THEN
    ALTER TABLE public.rs_tickets RENAME TO tickets;
  END IF;

  -- Shop Orders
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'rs_shop_orders' AND table_schema = 'public') THEN
    ALTER TABLE public.rs_shop_orders RENAME TO shop_orders;
  END IF;

  -- Initiatives & Crowdfunding
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'rs_initiatives' AND table_schema = 'public') THEN
    ALTER TABLE public.rs_initiatives RENAME TO initiatives;
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'rs_initiative_contributions' AND table_schema = 'public') THEN
    ALTER TABLE public.rs_initiative_contributions RENAME TO initiative_contributions;
  END IF;

  -- Memberships & Packages
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'rs_membership_packages' AND table_schema = 'public') THEN
    ALTER TABLE public.rs_membership_packages RENAME TO membership_packages;
  END IF;
END $$;


-- ------------------------------------------------------------------------------
-- §2: INJECT club_id BOUNDARIES INTO GAMIFICATION & GENERALIZED TABLES
-- ------------------------------------------------------------------------------

-- Cool Gamification Tables
ALTER TABLE public.cool_status ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);
ALTER TABLE public.cool_achievements ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);
ALTER TABLE public.cool_missions ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);
ALTER TABLE public.cool_reward_redemptions ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);

-- Renamed Core Tables
ALTER TABLE public.achievements ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);
ALTER TABLE public.matches ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);
ALTER TABLE public.shop_orders ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);
ALTER TABLE public.fan_clubs ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id);

-- Create basic indexes for RLS performance
CREATE INDEX IF NOT EXISTS idx_cool_status_club ON public.cool_status (club_id);
CREATE INDEX IF NOT EXISTS idx_tickets_club ON public.tickets (club_id);
CREATE INDEX IF NOT EXISTS idx_shop_orders_club ON public.shop_orders (club_id);
CREATE INDEX IF NOT EXISTS idx_fan_clubs_club ON public.fan_clubs (club_id);


-- ------------------------------------------------------------------------------
-- §3: ENFORCE RLS ON NON-ISOLATED TABLES
-- ------------------------------------------------------------------------------

-- Example isolating cool_status
DROP POLICY IF EXISTS "Users can only see own status" ON public.cool_status;
CREATE POLICY cool_status_multitenant_select
  ON public.cool_status FOR SELECT
  USING (
    user_id = auth.uid() 
    AND club_id::text = public.requesting_club_id()
  );

DROP POLICY IF EXISTS "Users can only insert own status" ON public.cool_status;
CREATE POLICY cool_status_multitenant_insert
  ON public.cool_status FOR INSERT
  WITH CHECK (
    user_id = auth.uid() 
    AND club_id::text = public.requesting_club_id()
  );


-- Example isolating Tickets
DROP POLICY IF EXISTS "Users can read own tickets" ON public.tickets;
CREATE POLICY tickets_multitenant_select
  ON public.tickets FOR SELECT
  USING (
    user_id = auth.uid() 
    AND club_id::text = public.requesting_club_id()
  );

-- Admin can manage all tickets in their club
CREATE POLICY tickets_admin_manage
  ON public.tickets FOR ALL
  USING (
    auth.role() = 'authenticated' AND
    club_id::text = public.requesting_club_id() AND
    EXISTS (
        SELECT 1 FROM auth.users u
        WHERE u.id = auth.uid()
        AND (u.raw_user_meta_data ->> 'role')::text IN ('admin', 'club_admin')
    )
  );

-- ------------------------------------------------------------------------------
-- §4: CLEANUP DEAD / OUT-OF-SCOPE TABLES
-- ------------------------------------------------------------------------------
-- Safe drops for duplicated or mobility data that shouldn't be in DineIn template.

DROP TABLE IF EXISTS public.groups CASCADE;  -- Superceded by contribution_groups
DROP TABLE IF EXISTS public.mobility_trips CASCADE;
DROP TABLE IF EXISTS public.driver_profiles CASCADE;

-- Validation Output
DO $$
BEGIN
  RAISE NOTICE 'Phase 2: Single-tenant tables generalized, gamification isolated, dead tables removed.';
END $$;
