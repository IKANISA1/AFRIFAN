-- ============================================================================
-- Football API Sync Infrastructure
-- ============================================================================
-- Adds:
-- 1. football_sync_config — Tracked leagues for automatic API sync
-- 2. football_sync_log — Audit trail for sync operations
-- 3. Column enhancements for API-sourced metadata
-- 4. Convenience views/RPCs for admin dashboard
-- ============================================================================

-- ── 1. Sync Configuration Table ──

CREATE TABLE IF NOT EXISTS public.football_sync_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  competition_id uuid REFERENCES football.competitions(id) ON DELETE SET NULL,
  external_provider text NOT NULL DEFAULT 'api-football',
  external_league_id text NOT NULL,
  league_name text NOT NULL DEFAULT '',
  season_year integer NOT NULL DEFAULT extract(year from now())::integer,
  sync_fixtures boolean NOT NULL DEFAULT true,
  sync_standings boolean NOT NULL DEFAULT true,
  sync_live boolean NOT NULL DEFAULT true,
  sync_squads boolean NOT NULL DEFAULT false,
  sync_interval_minutes integer NOT NULL DEFAULT 60,
  last_synced_at timestamptz,
  last_standings_synced_at timestamptz,
  last_live_synced_at timestamptz,
  last_squads_synced_at timestamptz,
  sync_status text NOT NULL DEFAULT 'idle',
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (external_provider, external_league_id)
);

COMMENT ON TABLE public.football_sync_config IS
  'Tracks which leagues/competitions are automatically synced from API-Football.';

ALTER TABLE public.football_sync_config
  ADD COLUMN IF NOT EXISTS sync_interval_minutes integer NOT NULL DEFAULT 60,
  ADD COLUMN IF NOT EXISTS last_synced_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_standings_synced_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_live_synced_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_squads_synced_at timestamptz,
  ADD COLUMN IF NOT EXISTS sync_status text NOT NULL DEFAULT 'idle',
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'football_sync_config'
      AND column_name = 'last_sync_at'
  ) THEN
    EXECUTE $sql$
      UPDATE public.football_sync_config
      SET last_synced_at = COALESCE(last_synced_at, last_sync_at)
      WHERE last_sync_at IS NOT NULL
        AND (last_synced_at IS NULL OR last_synced_at <> last_sync_at)
    $sql$;
  END IF;
END;
$$;

-- ── 2. Sync Log Table ──

CREATE TABLE IF NOT EXISTS public.football_sync_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sync_config_id uuid REFERENCES public.football_sync_config(id) ON DELETE SET NULL,
  sync_type text NOT NULL,
  status text NOT NULL DEFAULT 'started',
  records_fetched integer NOT NULL DEFAULT 0,
  records_upserted integer NOT NULL DEFAULT 0,
  api_requests_used integer NOT NULL DEFAULT 0,
  error_message text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);

COMMENT ON TABLE public.football_sync_log IS
  'Audit trail for every API-Football sync operation.';

ALTER TABLE public.football_sync_log
  ADD COLUMN IF NOT EXISTS sync_type text;

ALTER TABLE public.football_sync_log
  ALTER COLUMN sync_type SET DEFAULT 'manual';

UPDATE public.football_sync_log
SET sync_type = 'manual'
WHERE sync_type IS NULL;

ALTER TABLE public.football_sync_log
  ALTER COLUMN sync_type SET NOT NULL;

ALTER TABLE public.football_sync_log
  ADD COLUMN IF NOT EXISTS records_fetched integer NOT NULL DEFAULT 0;

ALTER TABLE public.football_sync_log
  ADD COLUMN IF NOT EXISTS records_upserted integer NOT NULL DEFAULT 0;

ALTER TABLE public.football_sync_log
  ADD COLUMN IF NOT EXISTS api_requests_used integer NOT NULL DEFAULT 0;

DO $$
DECLARE
  v_has_command boolean;
  v_has_records_processed boolean;
  v_has_records_created boolean;
  v_has_records_updated boolean;
  v_has_api_calls_used boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'football_sync_log'
      AND column_name = 'command'
  ) INTO v_has_command;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'football_sync_log'
      AND column_name = 'records_processed'
  ) INTO v_has_records_processed;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'football_sync_log'
      AND column_name = 'records_created'
  ) INTO v_has_records_created;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'football_sync_log'
      AND column_name = 'records_updated'
  ) INTO v_has_records_updated;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'football_sync_log'
      AND column_name = 'api_calls_used'
  ) INTO v_has_api_calls_used;

  EXECUTE format(
    $sql$
      UPDATE public.football_sync_log
      SET sync_type = COALESCE(
            NULLIF(sync_type, ''),
            %1$s,
            NULLIF(metadata ->> 'sync_type', ''),
            'manual'
          ),
          records_fetched = COALESCE(
            NULLIF(records_fetched, 0),
            %2$s,
            0
          ),
          records_upserted = COALESCE(
            NULLIF(records_upserted, 0),
            %3$s,
            %2$s,
            0
          ),
          api_requests_used = COALESCE(
            NULLIF(api_requests_used, 0),
            %4$s,
            0
          )
      WHERE sync_type IS NULL
         OR sync_type = ''
         OR records_fetched = 0
         OR records_upserted = 0
         OR api_requests_used = 0
    $sql$,
    CASE
      WHEN v_has_command THEN 'NULLIF(command, '''')'
      ELSE 'NULL'
    END,
    CASE
      WHEN v_has_records_processed THEN 'NULLIF(records_processed, 0)'
      ELSE 'NULL'
    END,
    CASE
      WHEN v_has_records_created AND v_has_records_updated THEN 'NULLIF(records_created + records_updated, 0)'
      WHEN v_has_records_created THEN 'NULLIF(records_created, 0)'
      WHEN v_has_records_updated THEN 'NULLIF(records_updated, 0)'
      ELSE 'NULL'
    END,
    CASE
      WHEN v_has_api_calls_used THEN 'NULLIF(api_calls_used, 0)'
      ELSE 'NULL'
    END
  );
END;
$$;

CREATE INDEX IF NOT EXISTS idx_football_sync_log_started
  ON public.football_sync_log (started_at DESC);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'football_sync_log'
      AND column_name = 'sync_type'
  ) THEN
    EXECUTE '
      CREATE INDEX IF NOT EXISTS idx_football_sync_log_config
      ON public.football_sync_log (sync_config_id, sync_type, started_at DESC)
    ';
  ELSE
    EXECUTE '
      CREATE INDEX IF NOT EXISTS idx_football_sync_log_config
      ON public.football_sync_log (sync_config_id, started_at DESC)
    ';
  END IF;
END $$;

-- ── 3. Triggers ──

DROP TRIGGER IF EXISTS football_sync_config_set_updated_at ON public.football_sync_config;
CREATE TRIGGER football_sync_config_set_updated_at
  BEFORE UPDATE ON public.football_sync_config
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── 4. RLS ──

ALTER TABLE public.football_sync_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.football_sync_log ENABLE ROW LEVEL SECURITY;

-- Admin read for sync config
DROP POLICY IF EXISTS football_sync_config_admin_read ON public.football_sync_config;
CREATE POLICY football_sync_config_admin_read
  ON public.football_sync_config
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS football_sync_config_service_write ON public.football_sync_config;
CREATE POLICY football_sync_config_service_write
  ON public.football_sync_config
  FOR ALL
  TO service_role
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- Sync log: read-only for everyone, write for service role
DROP POLICY IF EXISTS football_sync_log_read ON public.football_sync_log;
CREATE POLICY football_sync_log_read
  ON public.football_sync_log
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS football_sync_log_service_write ON public.football_sync_log;
CREATE POLICY football_sync_log_service_write
  ON public.football_sync_log
  FOR ALL
  TO service_role
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- ── 5. Grants ──

GRANT SELECT ON public.football_sync_config TO anon, authenticated, service_role;
GRANT INSERT, UPDATE, DELETE ON public.football_sync_config TO service_role;
GRANT SELECT ON public.football_sync_log TO anon, authenticated, service_role;
GRANT INSERT, UPDATE, DELETE ON public.football_sync_log TO service_role;

-- ── 6. Convenience view: sync overview ──

CREATE OR REPLACE VIEW public.football_sync_overview
WITH (security_invoker = true) AS
SELECT
  sc.id,
  sc.external_provider,
  sc.external_league_id,
  sc.league_name,
  sc.season_year,
  c.slug AS competition_slug,
  c.name AS competition_name,
  sc.sync_fixtures,
  sc.sync_standings,
  sc.sync_live,
  sc.sync_squads,
  sc.sync_interval_minutes,
  sc.last_synced_at,
  sc.last_standings_synced_at,
  sc.last_live_synced_at,
  sc.sync_status,
  sc.is_active,
  sc.created_at,
  (
    SELECT jsonb_build_object(
      'total_fixtures', COUNT(*) FILTER (WHERE f.external_provider = 'api-football'),
      'live_fixtures', COUNT(*) FILTER (WHERE f.status = 'live'),
      'finished_fixtures', COUNT(*) FILTER (WHERE f.status = 'finished'),
      'scheduled_fixtures', COUNT(*) FILTER (WHERE f.status = 'scheduled')
    )
    FROM football.fixtures f
    WHERE f.competition_id = sc.competition_id
  ) AS fixture_summary,
  (
    SELECT COUNT(*)
    FROM football.standings st
    WHERE st.competition_id = sc.competition_id
  ) AS standings_count
FROM public.football_sync_config sc
LEFT JOIN football.competitions c ON c.id = sc.competition_id
ORDER BY sc.league_name;

GRANT SELECT ON public.football_sync_overview TO anon, authenticated, service_role;

-- ── 7. Admin-writable authenticated policy for sync config ──
-- (So admins can register/toggle leagues from the web admin panel)

DROP POLICY IF EXISTS football_sync_config_admin_write ON public.football_sync_config;
CREATE POLICY football_sync_config_admin_write
  ON public.football_sync_config
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_role_assignments ara
      WHERE ara.user_id = auth.uid()
        AND ara.is_active = true
        AND ara.role IN ('admin', 'super_admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.admin_role_assignments ara
      WHERE ara.user_id = auth.uid()
        AND ara.is_active = true
        AND ara.role IN ('admin', 'super_admin')
    )
  );
