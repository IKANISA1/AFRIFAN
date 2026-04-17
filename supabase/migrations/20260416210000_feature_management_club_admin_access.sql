-- ============================================================================
-- Feature management club-admin access alignment
-- ============================================================================
-- The mobile admin workspace uses authenticated user clients, not the web
-- server's service-role admin client. The hardened feature-management RLS
-- therefore needs scoped club-admin access for:
--   - reading global defaults plus their own club overrides
--   - creating and mutating only club-scoped override rows
-- Global rows remain writable only by platform admins.

-- ──────────────────────────────────────────────────────────────────────────────
-- platform_features
-- ──────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS platform_features_select_admin
  ON public.platform_features;
DROP POLICY IF EXISTS platform_features_insert_admin
  ON public.platform_features;
DROP POLICY IF EXISTS platform_features_update_admin
  ON public.platform_features;
DROP POLICY IF EXISTS platform_features_delete_admin
  ON public.platform_features;

CREATE POLICY platform_features_select_admin
  ON public.platform_features
  FOR SELECT
  TO authenticated
  USING (
    public.is_admin_user()
    OR (club_id IS NULL AND public.is_club_admin())
    OR (club_id IS NOT NULL AND public.is_club_admin(club_id))
  );

CREATE POLICY platform_features_insert_admin
  ON public.platform_features
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_admin_user()
    OR (club_id IS NOT NULL AND public.is_club_admin(club_id))
  );

CREATE POLICY platform_features_update_admin
  ON public.platform_features
  FOR UPDATE
  TO authenticated
  USING (
    public.is_admin_user()
    OR (club_id IS NOT NULL AND public.is_club_admin(club_id))
  )
  WITH CHECK (
    public.is_admin_user()
    OR (club_id IS NOT NULL AND public.is_club_admin(club_id))
  );

CREATE POLICY platform_features_delete_admin
  ON public.platform_features
  FOR DELETE
  TO authenticated
  USING (
    public.is_admin_user()
    OR (club_id IS NOT NULL AND public.is_club_admin(club_id))
  );

-- ──────────────────────────────────────────────────────────────────────────────
-- platform_feature_channels
-- ──────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS platform_feature_channels_select_admin
  ON public.platform_feature_channels;
DROP POLICY IF EXISTS platform_feature_channels_insert_admin
  ON public.platform_feature_channels;
DROP POLICY IF EXISTS platform_feature_channels_update_admin
  ON public.platform_feature_channels;
DROP POLICY IF EXISTS platform_feature_channels_delete_admin
  ON public.platform_feature_channels;

CREATE POLICY platform_feature_channels_select_admin
  ON public.platform_feature_channels
  FOR SELECT
  TO authenticated
  USING (
    public.is_admin_user()
    OR EXISTS (
      SELECT 1
      FROM public.platform_features pf
      WHERE pf.id = platform_feature_channels.feature_id
        AND (
          (pf.club_id IS NULL AND public.is_club_admin())
          OR (pf.club_id IS NOT NULL AND public.is_club_admin(pf.club_id))
        )
    )
  );

CREATE POLICY platform_feature_channels_insert_admin
  ON public.platform_feature_channels
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_admin_user()
    OR EXISTS (
      SELECT 1
      FROM public.platform_features pf
      WHERE pf.id = platform_feature_channels.feature_id
        AND pf.club_id IS NOT NULL
        AND public.is_club_admin(pf.club_id)
    )
  );

CREATE POLICY platform_feature_channels_update_admin
  ON public.platform_feature_channels
  FOR UPDATE
  TO authenticated
  USING (
    public.is_admin_user()
    OR EXISTS (
      SELECT 1
      FROM public.platform_features pf
      WHERE pf.id = platform_feature_channels.feature_id
        AND pf.club_id IS NOT NULL
        AND public.is_club_admin(pf.club_id)
    )
  )
  WITH CHECK (
    public.is_admin_user()
    OR EXISTS (
      SELECT 1
      FROM public.platform_features pf
      WHERE pf.id = platform_feature_channels.feature_id
        AND pf.club_id IS NOT NULL
        AND public.is_club_admin(pf.club_id)
    )
  );

CREATE POLICY platform_feature_channels_delete_admin
  ON public.platform_feature_channels
  FOR DELETE
  TO authenticated
  USING (
    public.is_admin_user()
    OR EXISTS (
      SELECT 1
      FROM public.platform_features pf
      WHERE pf.id = platform_feature_channels.feature_id
        AND pf.club_id IS NOT NULL
        AND public.is_club_admin(pf.club_id)
    )
  );

-- ──────────────────────────────────────────────────────────────────────────────
-- platform_feature_rules
-- ──────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS platform_feature_rules_select_admin
  ON public.platform_feature_rules;
DROP POLICY IF EXISTS platform_feature_rules_insert_admin
  ON public.platform_feature_rules;
DROP POLICY IF EXISTS platform_feature_rules_update_admin
  ON public.platform_feature_rules;
DROP POLICY IF EXISTS platform_feature_rules_delete_admin
  ON public.platform_feature_rules;

CREATE POLICY platform_feature_rules_select_admin
  ON public.platform_feature_rules
  FOR SELECT
  TO authenticated
  USING (
    public.is_admin_user()
    OR EXISTS (
      SELECT 1
      FROM public.platform_features pf
      WHERE pf.id = platform_feature_rules.feature_id
        AND (
          (pf.club_id IS NULL AND public.is_club_admin())
          OR (pf.club_id IS NOT NULL AND public.is_club_admin(pf.club_id))
        )
    )
  );

CREATE POLICY platform_feature_rules_insert_admin
  ON public.platform_feature_rules
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_admin_user()
    OR EXISTS (
      SELECT 1
      FROM public.platform_features pf
      WHERE pf.id = platform_feature_rules.feature_id
        AND pf.club_id IS NOT NULL
        AND public.is_club_admin(pf.club_id)
    )
  );

CREATE POLICY platform_feature_rules_update_admin
  ON public.platform_feature_rules
  FOR UPDATE
  TO authenticated
  USING (
    public.is_admin_user()
    OR EXISTS (
      SELECT 1
      FROM public.platform_features pf
      WHERE pf.id = platform_feature_rules.feature_id
        AND pf.club_id IS NOT NULL
        AND public.is_club_admin(pf.club_id)
    )
  )
  WITH CHECK (
    public.is_admin_user()
    OR EXISTS (
      SELECT 1
      FROM public.platform_features pf
      WHERE pf.id = platform_feature_rules.feature_id
        AND pf.club_id IS NOT NULL
        AND public.is_club_admin(pf.club_id)
    )
  );

CREATE POLICY platform_feature_rules_delete_admin
  ON public.platform_feature_rules
  FOR DELETE
  TO authenticated
  USING (
    public.is_admin_user()
    OR EXISTS (
      SELECT 1
      FROM public.platform_features pf
      WHERE pf.id = platform_feature_rules.feature_id
        AND pf.club_id IS NOT NULL
        AND public.is_club_admin(pf.club_id)
    )
  );

-- ──────────────────────────────────────────────────────────────────────────────
-- platform_content_blocks
-- ──────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS platform_content_blocks_select_admin
  ON public.platform_content_blocks;
DROP POLICY IF EXISTS platform_content_blocks_insert_admin
  ON public.platform_content_blocks;
DROP POLICY IF EXISTS platform_content_blocks_update_admin
  ON public.platform_content_blocks;
DROP POLICY IF EXISTS platform_content_blocks_delete_admin
  ON public.platform_content_blocks;

CREATE POLICY platform_content_blocks_select_admin
  ON public.platform_content_blocks
  FOR SELECT
  TO authenticated
  USING (
    public.is_admin_user()
    OR (club_id IS NULL AND public.is_club_admin())
    OR (club_id IS NOT NULL AND public.is_club_admin(club_id))
  );

CREATE POLICY platform_content_blocks_insert_admin
  ON public.platform_content_blocks
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_admin_user()
    OR (club_id IS NOT NULL AND public.is_club_admin(club_id))
  );

CREATE POLICY platform_content_blocks_update_admin
  ON public.platform_content_blocks
  FOR UPDATE
  TO authenticated
  USING (
    public.is_admin_user()
    OR (club_id IS NOT NULL AND public.is_club_admin(club_id))
  )
  WITH CHECK (
    public.is_admin_user()
    OR (club_id IS NOT NULL AND public.is_club_admin(club_id))
  );

CREATE POLICY platform_content_blocks_delete_admin
  ON public.platform_content_blocks
  FOR DELETE
  TO authenticated
  USING (
    public.is_admin_user()
    OR (club_id IS NOT NULL AND public.is_club_admin(club_id))
  );

-- ──────────────────────────────────────────────────────────────────────────────
-- platform_feature_audit_logs
-- ──────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS platform_feature_audit_logs_select_admin
  ON public.platform_feature_audit_logs;

CREATE POLICY platform_feature_audit_logs_select_admin
  ON public.platform_feature_audit_logs
  FOR SELECT
  TO authenticated
  USING (
    public.is_admin_user()
    OR EXISTS (
      SELECT 1
      FROM public.platform_features pf
      WHERE pf.id = platform_feature_audit_logs.feature_id
        AND (
          (pf.club_id IS NULL AND public.is_club_admin())
          OR (pf.club_id IS NOT NULL AND public.is_club_admin(pf.club_id))
        )
    )
  );
