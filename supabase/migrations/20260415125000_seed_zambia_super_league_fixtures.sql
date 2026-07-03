-- ============================================================================
-- ZSL 2025/26 — Real fixtures (Rayon Sports–May 2026)
-- Adds missing teams + inserts all remaining fixtures
-- ============================================================================

DO $$
DECLARE
  v_competition_id uuid;
  v_season_id uuid;
BEGIN
  SELECT id INTO v_competition_id
  FROM football.competitions WHERE slug = 'zambia-super-league';

  SELECT id INTO v_season_id
  FROM football.seasons WHERE slug = 'zambia-super-league-2026';

  IF v_competition_id IS NULL OR v_season_id IS NULL THEN
    RAISE EXCEPTION 'ZSL competition or season not found.';
  END IF;

  -- ── Upsert additional teams not in initial seed ──
  WITH team_values (slug, name, short_name, city) AS (
    VALUES
      ('nkwazi-fc', 'Nkwazi FC', 'Nkwazi', 'Lusaka'),
      ('mines-united-zm', 'Mines United FC', 'Mines United', 'Kitwe'),
      ('mutondo-stars', 'Mutondo Stars FC', 'Mutondo Stars', 'Mufulira'),
      ('nchanga-rangers', 'Nchanga Rangers FC', 'Nchanga Rangers', 'Chingola'),
      ('maestro-united-zm', 'Maestro United Zambia', 'Maestro United', 'Lusaka'),
      ('mufulira-wanderers', 'Mufulira Wanderers FC', 'Mufulira Wanderers', 'Mufulira'),
      ('kansanshi-dynamos', 'Kansanshi Dynamos FC', 'Kansanshi', 'Solwezi'),
      ('zanaco-fc', 'Zanaco FC', 'Zanaco', 'Lusaka'),
      ('red-arrows-zm', 'Red Arrows FC', 'Red Arrows', 'Lusaka')
  )
  INSERT INTO football.teams AS t (
    slug, name, short_name, team_type,
    country_code, country_name, city, metadata
  )
  SELECT
    tv.slug, tv.name, tv.short_name,
    'club'::football.team_type,
    'ZM', 'Zambia', tv.city,
    jsonb_build_object('zambia_super_league_2026', true)
  FROM team_values tv
  ON CONFLICT (slug) DO UPDATE
  SET
    name = EXCLUDED.name,
    short_name = EXCLUDED.short_name,
    is_active = true,
    metadata = t.metadata || EXCLUDED.metadata;

  -- Register new teams into season
  WITH stv (team_slug) AS (
    VALUES
      ('nkwazi-fc'), ('mines-united-zm'), ('mutondo-stars'),
      ('nchanga-rangers'), ('maestro-united-zm'), ('mufulira-wanderers'),
      ('kansanshi-dynamos'), ('zanaco-fc'), ('red-arrows-zm')
  )
  INSERT INTO football.season_teams AS st (season_id, team_id, metadata)
  SELECT v_season_id, t.id, jsonb_build_object('source', 'manual-zm-fixtures-2026')
  FROM stv
  JOIN football.teams t ON t.slug = stv.team_slug
  ON CONFLICT (season_id, team_id) DO UPDATE
  SET is_active = true, metadata = st.metadata || EXCLUDED.metadata;

  -- ── Fixtures ──
  WITH fixture_values (match_date, home_slug, away_slug) AS (
    VALUES
      -- April 15
      ('2026-04-15', 'nkwazi-fc', 'napsa-stars'),
      ('2026-04-15', 'nkana-fc', 'mines-united-zm'),
      ('2026-04-15', 'mutondo-stars', 'green-eagles-zm'),
      -- April 16
      ('2026-04-16', 'kabwe-warriors', 'power-dynamos'),
      ('2026-04-16', 'prison-leopards', 'nchanga-rangers'),
      ('2026-04-16', 'maestro-united-zm', 'green-buffaloes'),
      ('2026-04-16', 'konkola-blades', 'mufulira-wanderers'),
      ('2026-04-16', 'kansanshi-dynamos', 'zesco-united'),
      -- April 18
      ('2026-04-18', 'zanaco-fc', 'mines-united-zm'),
      ('2026-04-18', 'konkola-blades', 'power-dynamos'),
      ('2026-04-18', 'green-eagles-zm', 'mufulira-wanderers'),
      ('2026-04-18', 'nkana-fc', 'nchanga-rangers'),
      ('2026-04-18', 'mutondo-stars', 'red-arrows-zm'),
      ('2026-04-18', 'prison-leopards', 'maestro-united-zm'),
      ('2026-04-18', 'kabwe-warriors', 'napsa-stars'),
      ('2026-04-18', 'kansanshi-dynamos', 'green-buffaloes'),
      ('2026-04-18', 'nkwazi-fc', 'zesco-united'),
      -- April 22
      ('2026-04-22', 'nkwazi-fc', 'power-dynamos'),
      ('2026-04-22', 'nchanga-rangers', 'kabwe-warriors'),
      ('2026-04-22', 'zesco-united', 'nkana-fc'),
      ('2026-04-22', 'maestro-united-zm', 'nkwazi-fc'),
      ('2026-04-22', 'green-buffaloes', 'mufulira-wanderers'),
      ('2026-04-22', 'power-dynamos', 'mutondo-stars'),
      ('2026-04-22', 'kansanshi-dynamos', 'prison-leopards'),
      ('2026-04-22', 'mines-united-zm', 'konkola-blades'),
      ('2026-04-22', 'napsa-stars', 'zanaco-fc'),
      ('2026-04-22', 'red-arrows-zm', 'green-eagles-zm'),
      -- April 29
      ('2026-04-29', 'red-arrows-zm', 'konkola-blades'),
      ('2026-04-29', 'napsa-stars', 'nkana-fc'),
      ('2026-04-29', 'nchanga-rangers', 'nkwazi-fc'),
      ('2026-04-29', 'mufulira-wanderers', 'mutondo-stars'),
      ('2026-04-29', 'power-dynamos', 'zanaco-fc'),
      ('2026-04-29', 'green-buffaloes', 'green-eagles-zm'),
      ('2026-04-29', 'mines-united-zm', 'kabwe-warriors'),
      ('2026-04-29', 'zesco-united', 'prison-leopards'),
      ('2026-04-29', 'maestro-united-zm', 'kansanshi-dynamos'),
      -- May 2
      ('2026-05-02', 'prison-leopards', 'green-buffaloes'),
      ('2026-05-02', 'mutondo-stars', 'mines-united-zm'),
      ('2026-05-02', 'nkana-fc', 'maestro-united-zm'),
      ('2026-05-02', 'mufulira-wanderers', 'red-arrows-zm'),
      ('2026-05-02', 'zanaco-fc', 'nchanga-rangers'),
      ('2026-05-02', 'nkwazi-fc', 'kansanshi-dynamos'),
      ('2026-05-02', 'green-eagles-zm', 'power-dynamos'),
      ('2026-05-02', 'kabwe-warriors', 'zesco-united')
  )
  INSERT INTO football.fixtures AS f (
    competition_id, season_id,
    stage_name, group_name, round_name,
    kickoff_at,
    home_team_id, away_team_id,
    status,
    external_provider, external_fixture_id, metadata
  )
  SELECT
    v_competition_id, v_season_id,
    'regular_season', '', '',
    (fv.match_date || ' 15:00')::timestamptz,
    ht.id, at.id,
    'scheduled'::football.fixture_status,
    'manual-zm-super-2026',
    format('zm-sl-2026-%s-%s-vs-%s', fv.match_date, fv.home_slug, fv.away_slug),
    jsonb_build_object(
      'compiled_at', '2026-04-15',
      'source', 'FAZ official calendar'
    )
  FROM fixture_values fv
  JOIN football.teams ht ON ht.slug = fv.home_slug
  JOIN football.teams at ON at.slug = fv.away_slug
  ON CONFLICT (external_provider, external_fixture_id) DO UPDATE
  SET
    kickoff_at = EXCLUDED.kickoff_at,
    home_team_id = EXCLUDED.home_team_id,
    away_team_id = EXCLUDED.away_team_id,
    status = EXCLUDED.status,
    metadata = f.metadata || EXCLUDED.metadata;

END $$;
