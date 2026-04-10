-- ============================================================================
-- Admin policy hardening
-- ----------------------------------------------------------------------------
-- Normalize legacy metadata-based admin policies onto the assignment-backed
-- club admin helpers used by the current admin workspace.
-- ============================================================================

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
      FROM information_schema.tables
     WHERE table_schema = 'public'
       AND table_name = 'african_football_clubs'
  ) THEN
    EXECUTE 'DROP POLICY IF EXISTS "Admins can manage clubs" ON public.african_football_clubs';
    EXECUTE 'DROP POLICY IF EXISTS clubs_admin_update ON public.african_football_clubs';
    EXECUTE '
      CREATE POLICY clubs_admin_update
        ON public.african_football_clubs
        FOR UPDATE
        USING (
          auth.role() = ''authenticated''
          AND (
            public.is_super_admin()
            OR (
              id::text = public.requesting_club_id()
              AND public.is_club_admin(id)
            )
          )
        )
        WITH CHECK (
          auth.role() = ''authenticated''
          AND (
            public.is_super_admin()
            OR (
              id::text = public.requesting_club_id()
              AND public.is_club_admin(id)
            )
          )
        )';
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
      FROM information_schema.tables
     WHERE table_schema = 'public'
       AND table_name = 'rs_shop_products'
  ) THEN
    EXECUTE 'DROP POLICY IF EXISTS "Admins can manage products" ON public.rs_shop_products';
    EXECUTE 'DROP POLICY IF EXISTS rs_shop_products_admin_all ON public.rs_shop_products';
    EXECUTE '
      CREATE POLICY rs_shop_products_admin_all
        ON public.rs_shop_products
        FOR ALL
        USING (
          auth.role() = ''authenticated''
          AND club_id::text = public.requesting_club_id()
          AND public.is_club_admin(club_id)
        )
        WITH CHECK (
          auth.role() = ''authenticated''
          AND club_id::text = public.requesting_club_id()
          AND public.is_club_admin(club_id)
        )';
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
      FROM information_schema.tables
     WHERE table_schema = 'public'
       AND table_name = 'shop_products'
  ) THEN
    EXECUTE 'DROP POLICY IF EXISTS "Admins can manage products" ON public.shop_products';
    EXECUTE 'DROP POLICY IF EXISTS shop_products_admin_all ON public.shop_products';
    EXECUTE '
      CREATE POLICY shop_products_admin_all
        ON public.shop_products
        FOR ALL
        USING (
          auth.role() = ''authenticated''
          AND club_id::text = public.requesting_club_id()
          AND public.is_club_admin(club_id)
        )
        WITH CHECK (
          auth.role() = ''authenticated''
          AND club_id::text = public.requesting_club_id()
          AND public.is_club_admin(club_id)
        )';
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
      FROM information_schema.tables
     WHERE table_schema = 'public'
       AND table_name = 'rs_news_articles'
  ) THEN
    EXECUTE 'DROP POLICY IF EXISTS "Admins can manage articles" ON public.rs_news_articles';
    EXECUTE 'DROP POLICY IF EXISTS rs_news_articles_admin_all ON public.rs_news_articles';
    EXECUTE '
      CREATE POLICY rs_news_articles_admin_all
        ON public.rs_news_articles
        FOR ALL
        USING (
          auth.role() = ''authenticated''
          AND club_id::text = public.requesting_club_id()
          AND public.is_club_admin(club_id)
        )
        WITH CHECK (
          auth.role() = ''authenticated''
          AND club_id::text = public.requesting_club_id()
          AND public.is_club_admin(club_id)
        )';
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
      FROM information_schema.tables
     WHERE table_schema = 'public'
       AND table_name = 'news_articles'
  ) THEN
    EXECUTE 'DROP POLICY IF EXISTS "Admins can manage articles" ON public.news_articles';
    EXECUTE 'DROP POLICY IF EXISTS news_articles_admin_all ON public.news_articles';
    EXECUTE '
      CREATE POLICY news_articles_admin_all
        ON public.news_articles
        FOR ALL
        USING (
          auth.role() = ''authenticated''
          AND club_id::text = public.requesting_club_id()
          AND public.is_club_admin(club_id)
        )
        WITH CHECK (
          auth.role() = ''authenticated''
          AND club_id::text = public.requesting_club_id()
          AND public.is_club_admin(club_id)
        )';
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
      FROM information_schema.tables
     WHERE table_schema = 'public'
       AND table_name = 'tickets'
  ) THEN
    EXECUTE 'DROP POLICY IF EXISTS tickets_admin_manage ON public.tickets';
    EXECUTE '
      CREATE POLICY tickets_admin_manage
        ON public.tickets
        FOR ALL
        USING (
          auth.role() = ''authenticated''
          AND club_id::text = public.requesting_club_id()
          AND public.is_club_admin(club_id)
        )
        WITH CHECK (
          auth.role() = ''authenticated''
          AND club_id::text = public.requesting_club_id()
          AND public.is_club_admin(club_id)
        )';
  END IF;
END $$;
