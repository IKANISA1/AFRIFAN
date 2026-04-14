-- =============================================================================
-- Supporter compatibility schema
-- Restores the legacy supporter/ticketing/chat surfaces still used by the app
-- while keeping club-scoped isolation aligned with the canonical multi-tenant
-- schema.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Shared helpers
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.compat_parse_partner_id(p_partner_id text)
RETURNS bigint
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT NULLIF(regexp_replace(trim(coalesce(p_partner_id, '')), '[^0-9]', '', 'g'), '')::bigint
$$;

CREATE OR REPLACE FUNCTION public.sync_partner_club_columns()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.club_id IS NULL AND NEW.partner_id IS NOT NULL THEN
    NEW.club_id := public.compat_parse_partner_id(NEW.partner_id);
  END IF;

  IF NEW.partner_id IS NULL AND NEW.club_id IS NOT NULL THEN
    NEW.partner_id := NEW.club_id::text;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_fan_membership_defaults()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.club_id IS NULL AND NEW.partner_id IS NOT NULL THEN
    NEW.club_id := public.compat_parse_partner_id(NEW.partner_id);
  END IF;

  IF NEW.partner_id IS NULL AND NEW.club_id IS NOT NULL THEN
    NEW.partner_id := NEW.club_id::text;
  END IF;

  IF NEW.display_name IS NULL OR btrim(NEW.display_name) = '' THEN
    SELECT COALESCE(NULLIF(btrim(display_name), ''), 'Fan')
      INTO NEW.display_name
      FROM public.profiles
     WHERE id = NEW.user_id;
    NEW.display_name := COALESCE(NEW.display_name, 'Fan');
  END IF;

  IF NEW.membership_number IS NULL OR btrim(NEW.membership_number) = '' THEN
    NEW.membership_number := 'FAN-' || replace(gen_random_uuid()::text, '-', '');
  END IF;

  RETURN NEW;
END;
$$;

-- -----------------------------------------------------------------------------
-- Compatibility columns on existing shop schema
-- -----------------------------------------------------------------------------

ALTER TABLE public.shop_products
  ADD COLUMN IF NOT EXISTS partner_id text,
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS sizes text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS collection text;

UPDATE public.shop_products
   SET description = COALESCE(description, subtitle, name),
       collection = COALESCE(collection, category)
 WHERE description IS NULL
    OR collection IS NULL;

DROP TRIGGER IF EXISTS trg_shop_products_partner_sync ON public.shop_products;
CREATE TRIGGER trg_shop_products_partner_sync
  BEFORE INSERT OR UPDATE ON public.shop_products
  FOR EACH ROW EXECUTE FUNCTION public.sync_partner_club_columns();

-- -----------------------------------------------------------------------------
-- Fan memberships
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.fan_memberships (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  club_id           bigint REFERENCES public.african_football_clubs(id),
  partner_id        text,
  display_name      text,
  tier              text NOT NULL DEFAULT 'fan',
  points            integer NOT NULL DEFAULT 0,
  chapter           text NOT NULL DEFAULT 'Main',
  membership_number text,
  joined_at         timestamptz NOT NULL DEFAULT now(),
  expires_at        timestamptz,
  renewed_at        timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fan_memberships_tier_check
    CHECK (tier IN ('fan', 'bronze', 'gold', 'platinum'))
);

ALTER TABLE public.fan_memberships
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id),
  ADD COLUMN IF NOT EXISTS partner_id text,
  ADD COLUMN IF NOT EXISTS display_name text,
  ADD COLUMN IF NOT EXISTS tier text NOT NULL DEFAULT 'fan',
  ADD COLUMN IF NOT EXISTS points integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS chapter text NOT NULL DEFAULT 'Main',
  ADD COLUMN IF NOT EXISTS membership_number text,
  ADD COLUMN IF NOT EXISTS joined_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS renewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE UNIQUE INDEX IF NOT EXISTS idx_fan_memberships_user_club
  ON public.fan_memberships (user_id, club_id);
CREATE INDEX IF NOT EXISTS idx_fan_memberships_partner
  ON public.fan_memberships (partner_id);
CREATE INDEX IF NOT EXISTS idx_fan_memberships_points
  ON public.fan_memberships (club_id, points DESC);

DROP TRIGGER IF EXISTS trg_fan_memberships_updated ON public.fan_memberships;
CREATE TRIGGER trg_fan_memberships_updated
  BEFORE UPDATE ON public.fan_memberships
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_fan_memberships_defaults ON public.fan_memberships;
CREATE TRIGGER trg_fan_memberships_defaults
  BEFORE INSERT OR UPDATE ON public.fan_memberships
  FOR EACH ROW EXECUTE FUNCTION public.sync_fan_membership_defaults();

ALTER TABLE public.fan_memberships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fan_memberships_select_club ON public.fan_memberships;
CREATE POLICY fan_memberships_select_club
  ON public.fan_memberships FOR SELECT
  USING (club_id::text = public.requesting_club_id());

DROP POLICY IF EXISTS fan_memberships_insert_self ON public.fan_memberships;
CREATE POLICY fan_memberships_insert_self
  ON public.fan_memberships FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND club_id::text = public.requesting_club_id()
  );

DROP POLICY IF EXISTS fan_memberships_update_self_or_admin ON public.fan_memberships;
CREATE POLICY fan_memberships_update_self_or_admin
  ON public.fan_memberships FOR UPDATE
  USING (
    club_id::text = public.requesting_club_id()
    AND (auth.uid() = user_id OR public.is_club_admin(club_id))
  );

GRANT SELECT, INSERT, UPDATE ON public.fan_memberships TO authenticated;

-- -----------------------------------------------------------------------------
-- Membership packages
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.membership_packages (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id     bigint REFERENCES public.african_football_clubs(id),
  partner_id  text,
  tier        text NOT NULL DEFAULT 'bronze',
  title       text NOT NULL,
  description text,
  is_active   boolean NOT NULL DEFAULT true,
  sort_order  integer NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.membership_packages
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id),
  ADD COLUMN IF NOT EXISTS partner_id text,
  ADD COLUMN IF NOT EXISTS tier text NOT NULL DEFAULT 'bronze',
  ADD COLUMN IF NOT EXISTS title text,
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS sort_order integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_membership_packages_club
  ON public.membership_packages (club_id, sort_order);

DROP TRIGGER IF EXISTS trg_membership_packages_updated ON public.membership_packages;
CREATE TRIGGER trg_membership_packages_updated
  BEFORE UPDATE ON public.membership_packages
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_membership_packages_partner_sync ON public.membership_packages;
CREATE TRIGGER trg_membership_packages_partner_sync
  BEFORE INSERT OR UPDATE ON public.membership_packages
  FOR EACH ROW EXECUTE FUNCTION public.sync_partner_club_columns();

ALTER TABLE public.membership_packages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS membership_packages_select_club ON public.membership_packages;
CREATE POLICY membership_packages_select_club
  ON public.membership_packages FOR SELECT
  USING (is_active = true AND club_id::text = public.requesting_club_id());

DROP POLICY IF EXISTS membership_packages_admin_all ON public.membership_packages;
CREATE POLICY membership_packages_admin_all
  ON public.membership_packages FOR ALL
  USING (
    club_id::text = public.requesting_club_id()
    AND public.is_club_admin(club_id)
  )
  WITH CHECK (
    club_id::text = public.requesting_club_id()
    AND public.is_club_admin(club_id)
  );

GRANT SELECT ON public.membership_packages TO authenticated;

-- -----------------------------------------------------------------------------
-- Fan clubs and members
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.fan_clubs (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id          bigint REFERENCES public.african_football_clubs(id),
  partner_id       text,
  name             text NOT NULL,
  region           text NOT NULL DEFAULT 'Official',
  description      text,
  member_count     integer NOT NULL DEFAULT 0,
  event_count      integer NOT NULL DEFAULT 0,
  rating           numeric(3,2) NOT NULL DEFAULT 0,
  banner_image_url text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.fan_clubs
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id),
  ADD COLUMN IF NOT EXISTS partner_id text,
  ADD COLUMN IF NOT EXISTS name text,
  ADD COLUMN IF NOT EXISTS region text NOT NULL DEFAULT 'Official',
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS member_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS event_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rating numeric(3,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS banner_image_url text,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_fan_clubs_partner
  ON public.fan_clubs (partner_id);
CREATE INDEX IF NOT EXISTS idx_fan_clubs_members
  ON public.fan_clubs (club_id, member_count DESC);

DROP TRIGGER IF EXISTS trg_fan_clubs_updated ON public.fan_clubs;
CREATE TRIGGER trg_fan_clubs_updated
  BEFORE UPDATE ON public.fan_clubs
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_fan_clubs_partner_sync ON public.fan_clubs;
CREATE TRIGGER trg_fan_clubs_partner_sync
  BEFORE INSERT OR UPDATE ON public.fan_clubs
  FOR EACH ROW EXECUTE FUNCTION public.sync_partner_club_columns();

CREATE TABLE IF NOT EXISTS public.fan_club_members (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id        uuid NOT NULL REFERENCES public.fan_clubs(id) ON DELETE CASCADE,
  user_id        uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_club_id bigint REFERENCES public.african_football_clubs(id),
  joined_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE(club_id, user_id)
);

ALTER TABLE public.fan_club_members
  ADD COLUMN IF NOT EXISTS tenant_club_id bigint REFERENCES public.african_football_clubs(id),
  ADD COLUMN IF NOT EXISTS joined_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_fan_club_members_user
  ON public.fan_club_members (user_id);
CREATE INDEX IF NOT EXISTS idx_fan_club_members_tenant
  ON public.fan_club_members (tenant_club_id);

CREATE OR REPLACE FUNCTION public.sync_fan_club_member_scope()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.tenant_club_id IS NULL THEN
    SELECT club_id INTO NEW.tenant_club_id
      FROM public.fan_clubs
     WHERE id = NEW.club_id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_fan_club_member_count()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.fan_clubs
       SET member_count = member_count + 1,
           updated_at = timezone('utc', now())
     WHERE id = NEW.club_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.fan_clubs
       SET member_count = GREATEST(0, member_count - 1),
           updated_at = timezone('utc', now())
     WHERE id = OLD.club_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_fan_club_members_scope ON public.fan_club_members;
CREATE TRIGGER trg_fan_club_members_scope
  BEFORE INSERT OR UPDATE ON public.fan_club_members
  FOR EACH ROW EXECUTE FUNCTION public.sync_fan_club_member_scope();

DROP TRIGGER IF EXISTS trg_fan_club_members_count ON public.fan_club_members;
CREATE TRIGGER trg_fan_club_members_count
  AFTER INSERT OR DELETE ON public.fan_club_members
  FOR EACH ROW EXECUTE FUNCTION public.update_fan_club_member_count();

ALTER TABLE public.fan_clubs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fan_club_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fan_clubs_select_club ON public.fan_clubs;
CREATE POLICY fan_clubs_select_club
  ON public.fan_clubs FOR SELECT
  USING (club_id::text = public.requesting_club_id());

DROP POLICY IF EXISTS fan_clubs_admin_all ON public.fan_clubs;
CREATE POLICY fan_clubs_admin_all
  ON public.fan_clubs FOR ALL
  USING (
    club_id::text = public.requesting_club_id()
    AND public.is_club_admin(club_id)
  )
  WITH CHECK (
    club_id::text = public.requesting_club_id()
    AND public.is_club_admin(club_id)
  );

DROP POLICY IF EXISTS fan_club_members_select_own ON public.fan_club_members;
CREATE POLICY fan_club_members_select_own
  ON public.fan_club_members FOR SELECT
  USING (
    tenant_club_id::text = public.requesting_club_id()
    AND user_id = auth.uid()
  );

DROP POLICY IF EXISTS fan_club_members_insert_own ON public.fan_club_members;
CREATE POLICY fan_club_members_insert_own
  ON public.fan_club_members FOR INSERT
  WITH CHECK (
    tenant_club_id::text = public.requesting_club_id()
    AND user_id = auth.uid()
  );

DROP POLICY IF EXISTS fan_club_members_delete_own ON public.fan_club_members;
CREATE POLICY fan_club_members_delete_own
  ON public.fan_club_members FOR DELETE
  USING (
    tenant_club_id::text = public.requesting_club_id()
    AND user_id = auth.uid()
  );

GRANT SELECT ON public.fan_clubs TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.fan_club_members TO authenticated;

-- -----------------------------------------------------------------------------
-- Matches and tickets
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.matches (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id              bigint REFERENCES public.african_football_clubs(id),
  partner_id           text,
  home_team            text NOT NULL,
  away_team            text NOT NULL,
  competition          text NOT NULL DEFAULT 'League',
  venue                text NOT NULL DEFAULT 'Stadium',
  match_date           timestamptz NOT NULL DEFAULT now(),
  kickoff_time         text NOT NULL DEFAULT '15:00:00',
  is_on_sale           boolean NOT NULL DEFAULT false,
  ticket_general_price integer NOT NULL DEFAULT 0,
  ticket_vip_price     integer NOT NULL DEFAULT 0,
  sale_starts_at       timestamptz NOT NULL DEFAULT now(),
  capacity             integer NOT NULL DEFAULT 0,
  sold_count           integer NOT NULL DEFAULT 0,
  image_url            text,
  roster               text[] NOT NULL DEFAULT '{}',
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.matches
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id),
  ADD COLUMN IF NOT EXISTS partner_id text,
  ADD COLUMN IF NOT EXISTS home_team text,
  ADD COLUMN IF NOT EXISTS away_team text,
  ADD COLUMN IF NOT EXISTS competition text NOT NULL DEFAULT 'League',
  ADD COLUMN IF NOT EXISTS venue text NOT NULL DEFAULT 'Stadium',
  ADD COLUMN IF NOT EXISTS match_date timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS kickoff_time text NOT NULL DEFAULT '15:00:00',
  ADD COLUMN IF NOT EXISTS is_on_sale boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS ticket_general_price integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ticket_vip_price integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS sale_starts_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS capacity integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS sold_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS image_url text,
  ADD COLUMN IF NOT EXISTS roster text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_matches_partner
  ON public.matches (partner_id, match_date);
CREATE INDEX IF NOT EXISTS idx_matches_on_sale
  ON public.matches (club_id, is_on_sale, match_date);

DROP TRIGGER IF EXISTS trg_matches_updated ON public.matches;
CREATE TRIGGER trg_matches_updated
  BEFORE UPDATE ON public.matches
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_matches_partner_sync ON public.matches;
CREATE TRIGGER trg_matches_partner_sync
  BEFORE INSERT OR UPDATE ON public.matches
  FOR EACH ROW EXECUTE FUNCTION public.sync_partner_club_columns();

CREATE TABLE IF NOT EXISTS public.tickets (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id     uuid NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  club_id      bigint REFERENCES public.african_football_clubs(id),
  seat_type    text NOT NULL DEFAULT 'general',
  amount_paid  integer NOT NULL DEFAULT 0,
  qr_code      text,
  momo_reference text,
  status       text NOT NULL DEFAULT 'active',
  purchased_at timestamptz NOT NULL DEFAULT now(),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.tickets
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id),
  ADD COLUMN IF NOT EXISTS referral_invite_id uuid,
  ADD COLUMN IF NOT EXISTS seat_type text NOT NULL DEFAULT 'general',
  ADD COLUMN IF NOT EXISTS amount_paid integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS qr_code text,
  ADD COLUMN IF NOT EXISTS momo_reference text,
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS purchased_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_tickets_user_created
  ON public.tickets (user_id, purchased_at DESC);
CREATE INDEX IF NOT EXISTS idx_tickets_match
  ON public.tickets (match_id, status);

CREATE OR REPLACE FUNCTION public.sync_ticket_scope()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.club_id IS NULL THEN
    SELECT club_id INTO NEW.club_id
      FROM public.matches
     WHERE id = NEW.match_id;
  END IF;

  IF NEW.qr_code IS NULL OR btrim(NEW.qr_code) = '' THEN
    NEW.qr_code := 'AFC-' || replace(gen_random_uuid()::text, '-', '');
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_match_ticket_sales()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_match_id uuid;
BEGIN
  v_match_id := COALESCE(NEW.match_id, OLD.match_id);
  UPDATE public.matches
     SET sold_count = (
           SELECT COUNT(*)
             FROM public.tickets
            WHERE match_id = v_match_id
              AND status = 'active'
         ),
         updated_at = timezone('utc', now())
   WHERE id = v_match_id;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_tickets_scope ON public.tickets;
CREATE TRIGGER trg_tickets_scope
  BEFORE INSERT OR UPDATE ON public.tickets
  FOR EACH ROW EXECUTE FUNCTION public.sync_ticket_scope();

DROP TRIGGER IF EXISTS trg_tickets_updated ON public.tickets;
CREATE TRIGGER trg_tickets_updated
  BEFORE UPDATE ON public.tickets
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_tickets_sales_refresh ON public.tickets;
CREATE TRIGGER trg_tickets_sales_refresh
  AFTER INSERT OR UPDATE OR DELETE ON public.tickets
  FOR EACH ROW EXECUTE FUNCTION public.refresh_match_ticket_sales();

ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS matches_select_club ON public.matches;
CREATE POLICY matches_select_club
  ON public.matches FOR SELECT
  USING (club_id::text = public.requesting_club_id());

DROP POLICY IF EXISTS matches_admin_all ON public.matches;
CREATE POLICY matches_admin_all
  ON public.matches FOR ALL
  USING (
    club_id::text = public.requesting_club_id()
    AND public.is_club_admin(club_id)
  )
  WITH CHECK (
    club_id::text = public.requesting_club_id()
    AND public.is_club_admin(club_id)
  );

DROP POLICY IF EXISTS tickets_select_own ON public.tickets;
CREATE POLICY tickets_select_own
  ON public.tickets FOR SELECT
  USING (
    club_id::text = public.requesting_club_id()
    AND user_id = auth.uid()
  );

DROP POLICY IF EXISTS tickets_insert_own ON public.tickets;
CREATE POLICY tickets_insert_own
  ON public.tickets FOR INSERT
  WITH CHECK (
    club_id::text = public.requesting_club_id()
    AND user_id = auth.uid()
  );

DROP POLICY IF EXISTS tickets_update_own_or_admin ON public.tickets;
CREATE POLICY tickets_update_own_or_admin
  ON public.tickets FOR UPDATE
  USING (
    club_id::text = public.requesting_club_id()
    AND (user_id = auth.uid() OR public.is_club_admin(club_id))
  );

GRANT SELECT ON public.matches TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.tickets TO authenticated;

-- -----------------------------------------------------------------------------
-- Shop orders and partner payment routes
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.shop_orders (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  club_id          bigint REFERENCES public.african_football_clubs(id),
  partner_id       text,
  items            jsonb NOT NULL DEFAULT '[]'::jsonb,
  subtotal         integer NOT NULL DEFAULT 0,
  discount_amount  integer NOT NULL DEFAULT 0,
  delivery_fee     integer NOT NULL DEFAULT 0,
  total            integer NOT NULL DEFAULT 0,
  delivery_address text,
  momo_reference   text,
  status           text NOT NULL DEFAULT 'pending',
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.shop_orders
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id),
  ADD COLUMN IF NOT EXISTS partner_id text,
  ADD COLUMN IF NOT EXISTS referral_invite_id uuid,
  ADD COLUMN IF NOT EXISTS items jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS subtotal integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS discount_amount integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS delivery_fee integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS delivery_address text,
  ADD COLUMN IF NOT EXISTS momo_reference text,
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_shop_orders_user
  ON public.shop_orders (user_id, created_at DESC);

DROP TRIGGER IF EXISTS trg_shop_orders_updated ON public.shop_orders;
CREATE TRIGGER trg_shop_orders_updated
  BEFORE UPDATE ON public.shop_orders
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_shop_orders_partner_sync ON public.shop_orders;
CREATE TRIGGER trg_shop_orders_partner_sync
  BEFORE INSERT OR UPDATE ON public.shop_orders
  FOR EACH ROW EXECUTE FUNCTION public.sync_partner_club_columns();

CREATE TABLE IF NOT EXISTS public.partner_payment_routes (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id              bigint REFERENCES public.african_football_clubs(id),
  partner_id           text,
  partner_name         text NOT NULL DEFAULT 'Club',
  partner_slug         text NOT NULL DEFAULT '',
  country              text NOT NULL DEFAULT 'RW',
  provider             text NOT NULL DEFAULT '',
  recipient_code       text NOT NULL DEFAULT '',
  reconciliation_label text NOT NULL DEFAULT '',
  status               text NOT NULL DEFAULT 'draft',
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.partner_payment_routes
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id),
  ADD COLUMN IF NOT EXISTS partner_id text,
  ADD COLUMN IF NOT EXISTS partner_name text NOT NULL DEFAULT 'Club',
  ADD COLUMN IF NOT EXISTS partner_slug text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS country text NOT NULL DEFAULT 'RW',
  ADD COLUMN IF NOT EXISTS provider text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS recipient_code text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS reconciliation_label text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'draft',
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_partner_payment_routes_partner
  ON public.partner_payment_routes (partner_id, status);

DROP TRIGGER IF EXISTS trg_partner_payment_routes_updated ON public.partner_payment_routes;
CREATE TRIGGER trg_partner_payment_routes_updated
  BEFORE UPDATE ON public.partner_payment_routes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_partner_payment_routes_partner_sync ON public.partner_payment_routes;
CREATE TRIGGER trg_partner_payment_routes_partner_sync
  BEFORE INSERT OR UPDATE ON public.partner_payment_routes
  FOR EACH ROW EXECUTE FUNCTION public.sync_partner_club_columns();

ALTER TABLE public.shop_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_payment_routes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS shop_orders_select_own ON public.shop_orders;
CREATE POLICY shop_orders_select_own
  ON public.shop_orders FOR SELECT
  USING (
    club_id::text = public.requesting_club_id()
    AND user_id = auth.uid()
  );

DROP POLICY IF EXISTS shop_orders_insert_own ON public.shop_orders;
CREATE POLICY shop_orders_insert_own
  ON public.shop_orders FOR INSERT
  WITH CHECK (
    club_id::text = public.requesting_club_id()
    AND user_id = auth.uid()
  );

DROP POLICY IF EXISTS shop_orders_update_own ON public.shop_orders;
CREATE POLICY shop_orders_update_own
  ON public.shop_orders FOR UPDATE
  USING (
    club_id::text = public.requesting_club_id()
    AND user_id = auth.uid()
  );

DROP POLICY IF EXISTS partner_payment_routes_select_active ON public.partner_payment_routes;
CREATE POLICY partner_payment_routes_select_active
  ON public.partner_payment_routes FOR SELECT
  USING (
    club_id::text = public.requesting_club_id()
    AND status = 'active'
  );

DROP POLICY IF EXISTS partner_payment_routes_admin_all ON public.partner_payment_routes;
CREATE POLICY partner_payment_routes_admin_all
  ON public.partner_payment_routes FOR ALL
  USING (
    club_id::text = public.requesting_club_id()
    AND public.is_club_admin(club_id)
  )
  WITH CHECK (
    club_id::text = public.requesting_club_id()
    AND public.is_club_admin(club_id)
  );

GRANT SELECT, INSERT, UPDATE ON public.shop_orders TO authenticated;
GRANT SELECT ON public.partner_payment_routes TO authenticated;

-- -----------------------------------------------------------------------------
-- Initiative support and legacy Rayon compatibility views
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.initiatives (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id         bigint REFERENCES public.african_football_clubs(id),
  partner_id      text,
  title           text NOT NULL,
  description     text,
  goal_amount     integer NOT NULL DEFAULT 0,
  raised_amount   integer NOT NULL DEFAULT 0,
  supporter_count integer NOT NULL DEFAULT 0,
  status          text NOT NULL DEFAULT 'active',
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.initiatives
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id),
  ADD COLUMN IF NOT EXISTS partner_id text,
  ADD COLUMN IF NOT EXISTS title text,
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS goal_amount integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS raised_amount integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS supporter_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_initiatives_club_status
  ON public.initiatives (club_id, status, created_at DESC);

DROP TRIGGER IF EXISTS trg_initiatives_updated ON public.initiatives;
CREATE TRIGGER trg_initiatives_updated
  BEFORE UPDATE ON public.initiatives
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_initiatives_partner_sync ON public.initiatives;
CREATE TRIGGER trg_initiatives_partner_sync
  BEFORE INSERT OR UPDATE ON public.initiatives
  FOR EACH ROW EXECUTE FUNCTION public.sync_partner_club_columns();

CREATE TABLE IF NOT EXISTS public.initiative_contributions (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  initiative_id      uuid NOT NULL REFERENCES public.initiatives(id) ON DELETE CASCADE,
  user_id            uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  club_id            bigint REFERENCES public.african_football_clubs(id),
  referral_invite_id uuid,
  amount             integer NOT NULL DEFAULT 0,
  momo_reference     text,
  status             text NOT NULL DEFAULT 'pending',
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.initiative_contributions
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id),
  ADD COLUMN IF NOT EXISTS referral_invite_id uuid,
  ADD COLUMN IF NOT EXISTS amount integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS momo_reference text,
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_initiative_contributions_user_created
  ON public.initiative_contributions (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_initiative_contributions_reference
  ON public.initiative_contributions (momo_reference);

CREATE OR REPLACE FUNCTION public.sync_initiative_contribution_scope()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.club_id IS NULL THEN
    SELECT club_id INTO NEW.club_id
      FROM public.initiatives
     WHERE id = NEW.initiative_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_initiative_contributions_scope ON public.initiative_contributions;
CREATE TRIGGER trg_initiative_contributions_scope
  BEFORE INSERT OR UPDATE ON public.initiative_contributions
  FOR EACH ROW EXECUTE FUNCTION public.sync_initiative_contribution_scope();

DROP TRIGGER IF EXISTS trg_initiative_contributions_updated ON public.initiative_contributions;
CREATE TRIGGER trg_initiative_contributions_updated
  BEFORE UPDATE ON public.initiative_contributions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.initiatives ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.initiative_contributions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS initiatives_select_club ON public.initiatives;
CREATE POLICY initiatives_select_club
  ON public.initiatives FOR SELECT
  USING (
    club_id::text = public.requesting_club_id()
    AND status = 'active'
  );

DROP POLICY IF EXISTS initiatives_admin_all ON public.initiatives;
CREATE POLICY initiatives_admin_all
  ON public.initiatives FOR ALL
  USING (
    club_id::text = public.requesting_club_id()
    AND public.is_club_admin(club_id)
  )
  WITH CHECK (
    club_id::text = public.requesting_club_id()
    AND public.is_club_admin(club_id)
  );

DROP POLICY IF EXISTS initiative_contributions_select_own ON public.initiative_contributions;
CREATE POLICY initiative_contributions_select_own
  ON public.initiative_contributions FOR SELECT
  USING (
    club_id::text = public.requesting_club_id()
    AND user_id = auth.uid()
  );

DROP POLICY IF EXISTS initiative_contributions_insert_own ON public.initiative_contributions;
CREATE POLICY initiative_contributions_insert_own
  ON public.initiative_contributions FOR INSERT
  WITH CHECK (
    club_id::text = public.requesting_club_id()
    AND user_id = auth.uid()
  );

DROP POLICY IF EXISTS initiative_contributions_update_own_or_admin ON public.initiative_contributions;
CREATE POLICY initiative_contributions_update_own_or_admin
  ON public.initiative_contributions FOR UPDATE
  USING (
    club_id::text = public.requesting_club_id()
    AND (user_id = auth.uid() OR public.is_club_admin(club_id))
  );

GRANT SELECT ON public.initiatives TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.initiative_contributions TO authenticated;

DO $$
BEGIN
  IF to_regclass('public.group_contributions') IS NULL THEN
    EXECUTE $view$
      CREATE VIEW public.group_contributions AS
      SELECT
        id,
        group_id,
        user_id,
        club_id,
        amount,
        status,
        payment_method,
        external_ref AS momo_reference,
        ledger_entry_id,
        note,
        confirmed_at,
        created_at,
        updated_at
      FROM public.contributions
    $view$;
  END IF;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.rs_matches') IS NULL THEN
    EXECUTE $view$
      CREATE VIEW public.rs_matches AS
      SELECT
        id,
        club_id,
        partner_id,
        home_team,
        away_team,
        competition,
        venue,
        match_date,
        kickoff_time,
        is_on_sale,
        ticket_general_price,
        ticket_vip_price,
        sale_starts_at,
        capacity,
        sold_count,
        image_url,
        roster,
        created_at,
        updated_at
      FROM public.matches
    $view$;
  END IF;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.rs_tickets') IS NULL THEN
    EXECUTE $view$
      CREATE VIEW public.rs_tickets AS
      SELECT
        id,
        match_id,
        user_id,
        club_id,
        referral_invite_id,
        seat_type,
        amount_paid,
        qr_code,
        momo_reference,
        status,
        purchased_at,
        created_at,
        updated_at
      FROM public.tickets
    $view$;
  END IF;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.rs_shop_orders') IS NULL THEN
    EXECUTE $view$
      CREATE VIEW public.rs_shop_orders AS
      SELECT
        id,
        user_id,
        club_id,
        partner_id,
        referral_invite_id,
        items,
        subtotal,
        discount_amount,
        delivery_fee,
        total,
        delivery_address,
        momo_reference,
        status,
        created_at,
        updated_at
      FROM public.shop_orders
    $view$;
  END IF;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.rs_initiatives') IS NULL THEN
    EXECUTE $view$
      CREATE VIEW public.rs_initiatives AS
      SELECT
        id,
        club_id,
        partner_id,
        title,
        description,
        goal_amount,
        raised_amount,
        supporter_count,
        status,
        created_at,
        updated_at
      FROM public.initiatives
    $view$;
  END IF;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.rs_initiative_contributions') IS NULL THEN
    EXECUTE $view$
      CREATE VIEW public.rs_initiative_contributions AS
      SELECT
        id,
        initiative_id,
        user_id,
        club_id,
        referral_invite_id,
        amount,
        momo_reference,
        status,
        created_at,
        updated_at
      FROM public.initiative_contributions
    $view$;
  END IF;
END;
$$;

-- -----------------------------------------------------------------------------
-- Group chat messages
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.group_messages (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id    uuid NOT NULL REFERENCES public.contribution_groups(id) ON DELETE CASCADE,
  sender_id   uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  club_id     bigint REFERENCES public.african_football_clubs(id),
  alias       text,
  content     text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.group_messages
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id),
  ADD COLUMN IF NOT EXISTS alias text,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_group_messages_group_created
  ON public.group_messages (group_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.populate_group_message_defaults()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.sender_id IS NULL THEN
    NEW.sender_id := auth.uid();
  END IF;

  IF NEW.club_id IS NULL THEN
    SELECT club_id INTO NEW.club_id
      FROM public.contribution_groups
     WHERE id = NEW.group_id;
  END IF;

  IF NEW.alias IS NULL OR btrim(NEW.alias) = '' THEN
    SELECT NULLIF(btrim(public_user_id), '')
      INTO NEW.alias
      FROM public.profiles
     WHERE id = NEW.sender_id;
    NEW.alias := COALESCE(NEW.alias, '000000');
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_group_messages_defaults ON public.group_messages;
CREATE TRIGGER trg_group_messages_defaults
  BEFORE INSERT OR UPDATE ON public.group_messages
  FOR EACH ROW EXECUTE FUNCTION public.populate_group_message_defaults();

DROP TRIGGER IF EXISTS trg_group_messages_updated ON public.group_messages;
CREATE TRIGGER trg_group_messages_updated
  BEFORE UPDATE ON public.group_messages
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.group_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS group_messages_select_members ON public.group_messages;
CREATE POLICY group_messages_select_members
  ON public.group_messages FOR SELECT
  USING (
    club_id::text = public.requesting_club_id()
    AND EXISTS (
      SELECT 1
        FROM public.group_members gm
       WHERE gm.group_id = group_messages.group_id
         AND gm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS group_messages_insert_members ON public.group_messages;
CREATE POLICY group_messages_insert_members
  ON public.group_messages FOR INSERT
  WITH CHECK (
    club_id::text = public.requesting_club_id()
    AND sender_id = auth.uid()
    AND EXISTS (
      SELECT 1
        FROM public.group_members gm
       WHERE gm.group_id = group_messages.group_id
         AND gm.user_id = auth.uid()
    )
  );

GRANT SELECT, INSERT ON public.group_messages TO authenticated;

-- -----------------------------------------------------------------------------
-- FET event tables
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.cool_events (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  club_id    bigint REFERENCES public.african_football_clubs(id),
  event_type text NOT NULL,
  xp_awarded integer NOT NULL DEFAULT 0,
  metadata   jsonb NOT NULL DEFAULT '{}'::jsonb,
  event_at   timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.xp_events (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  club_id    bigint REFERENCES public.african_football_clubs(id),
  event_type text NOT NULL,
  xp_awarded integer NOT NULL DEFAULT 0,
  metadata   jsonb NOT NULL DEFAULT '{}'::jsonb,
  event_at   timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.cool_events
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id),
  ADD COLUMN IF NOT EXISTS event_type text,
  ADD COLUMN IF NOT EXISTS xp_awarded integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS event_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE public.xp_events
  ADD COLUMN IF NOT EXISTS club_id bigint REFERENCES public.african_football_clubs(id),
  ADD COLUMN IF NOT EXISTS event_type text,
  ADD COLUMN IF NOT EXISTS xp_awarded integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS event_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_cool_events_user_date
  ON public.cool_events (user_id, event_at DESC);
CREATE INDEX IF NOT EXISTS idx_xp_events_user_date
  ON public.xp_events (user_id, event_at DESC);

CREATE OR REPLACE FUNCTION public.populate_event_club_scope()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.club_id IS NULL THEN
    NEW.club_id := NULLIF(public.requesting_club_id(), '')::bigint;
  END IF;

  IF NEW.club_id IS NULL THEN
    SELECT club_id INTO NEW.club_id
      FROM public.profiles
     WHERE id = NEW.user_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_cool_events_scope ON public.cool_events;
CREATE TRIGGER trg_cool_events_scope
  BEFORE INSERT OR UPDATE ON public.cool_events
  FOR EACH ROW EXECUTE FUNCTION public.populate_event_club_scope();

DROP TRIGGER IF EXISTS trg_xp_events_scope ON public.xp_events;
CREATE TRIGGER trg_xp_events_scope
  BEFORE INSERT OR UPDATE ON public.xp_events
  FOR EACH ROW EXECUTE FUNCTION public.populate_event_club_scope();

ALTER TABLE public.cool_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.xp_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cool_events_select_own ON public.cool_events;
CREATE POLICY cool_events_select_own
  ON public.cool_events FOR SELECT
  USING (
    club_id::text = public.requesting_club_id()
    AND user_id = auth.uid()
  );

DROP POLICY IF EXISTS cool_events_insert_own ON public.cool_events;
CREATE POLICY cool_events_insert_own
  ON public.cool_events FOR INSERT
  WITH CHECK (
    club_id::text = public.requesting_club_id()
    AND user_id = auth.uid()
  );

DROP POLICY IF EXISTS xp_events_select_own ON public.xp_events;
CREATE POLICY xp_events_select_own
  ON public.xp_events FOR SELECT
  USING (
    club_id::text = public.requesting_club_id()
    AND user_id = auth.uid()
  );

DROP POLICY IF EXISTS xp_events_insert_own ON public.xp_events;
CREATE POLICY xp_events_insert_own
  ON public.xp_events FOR INSERT
  WITH CHECK (
    club_id::text = public.requesting_club_id()
    AND user_id = auth.uid()
  );

GRANT SELECT, INSERT ON public.cool_events TO authenticated;
GRANT SELECT, INSERT ON public.xp_events TO authenticated;

-- -----------------------------------------------------------------------------
-- Compatibility RPCs
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.resolve_fan_tier(p_points integer)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN coalesce(p_points, 0) >= 5000 THEN 'platinum'
    WHEN coalesce(p_points, 0) >= 2000 THEN 'gold'
    WHEN coalesce(p_points, 0) >= 1000 THEN 'bronze'
    ELSE 'fan'
  END
$$;

CREATE OR REPLACE FUNCTION public.add_fan_points(
  p_user_id uuid,
  p_partner_id text,
  p_points integer,
  p_reason text DEFAULT NULL
)
RETURNS public.fan_memberships
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_club_id bigint;
  v_membership public.fan_memberships;
BEGIN
  v_club_id := COALESCE(
    public.compat_parse_partner_id(p_partner_id),
    NULLIF(public.requesting_club_id(), '')::bigint
  );

  IF v_club_id IS NULL THEN
    RAISE EXCEPTION 'Club context required for fan points.';
  END IF;

  INSERT INTO public.fan_memberships (
    user_id,
    club_id,
    partner_id,
    points,
    tier
  )
  VALUES (
    p_user_id,
    v_club_id,
    COALESCE(NULLIF(trim(coalesce(p_partner_id, '')), ''), v_club_id::text),
    GREATEST(coalesce(p_points, 0), 0),
    public.resolve_fan_tier(GREATEST(coalesce(p_points, 0), 0))
  )
  ON CONFLICT (user_id, club_id)
  DO UPDATE SET
    points = public.fan_memberships.points + GREATEST(coalesce(p_points, 0), 0),
    tier = public.resolve_fan_tier(
      public.fan_memberships.points + GREATEST(coalesce(p_points, 0), 0)
    ),
    renewed_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  RETURNING * INTO v_membership;

  INSERT INTO public.cool_events (
    user_id,
    club_id,
    event_type,
    xp_awarded,
    metadata,
    event_at
  )
  VALUES (
    p_user_id,
    v_club_id,
    COALESCE(NULLIF(trim(coalesce(p_reason, '')), ''), 'manual_adjustment'),
    GREATEST(coalesce(p_points, 0), 0),
    jsonb_build_object('reason', p_reason, 'source', 'add_fan_points'),
    timezone('utc', now())
  );

  RETURN v_membership;
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_fan_points(uuid, text, integer, text)
  TO authenticated;
