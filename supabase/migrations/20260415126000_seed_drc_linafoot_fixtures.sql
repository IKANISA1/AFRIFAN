-- ============================================================================
-- DRC Linafoot 2025/26 — Real fixtures (Rayon Sports–May 2026)
-- Adds missing teams + inserts all remaining fixtures
-- ============================================================================

DO $$
DECLARE
  v_competition_id uuid;
  v_season_id uuid;
BEGIN
  SELECT id INTO v_competition_id
  FROM football.competitions WHERE slug = 'Linafoot';

  SELECT id INTO v_season_id
  FROM football.seasons WHERE slug = 'Linafoot-2026';

  IF v_competition_id IS NULL OR v_season_id IS NULL THEN
    RAISE EXCEPTION 'Linafoot competition or season not found.';
  END IF;

  -- ── Upsert additional teams not in initial seed ──
  WITH team_values (slug, name, short_name, city) AS (
    VALUES
      ('fc-les-aigles-du-congo', 'FC Les Aigles du Congo', 'Aigles du Congo', 'Kinshasa'),
      ('lubumbashi-sport', 'Lubumbashi Sport', 'Lubumbashi Sport', 'Lubumbashi'),
      ('as-new-soger', 'AS New Soger', 'New Soger', 'Goma'),
      ('malole-fc', 'Malole FC', 'Malole', 'Lubumbashi'),
      ('js-groupe-bazano', 'JS Groupe Bazano', 'Bazano', 'Lubumbashi'),
      ('us-panda-b52', 'US Panda B52', 'Panda B52', 'Likasi'),
      ('etoile-de-kivu', 'Etoile de Kivu', 'Etoile de Kivu', 'Bukavu'),
      -- Ensure existing teams have correct metadata
      ('tp-mazembe', 'TP Mazembe', 'Mazembe', 'Lubumbashi'),
      ('as-vita-club', 'AS Vita Club', 'Vita Club', 'Kinshasa'),
      ('dc-motema-pembe', 'DC Motema Pembe', 'DCMP', 'Kinshasa'),
      ('st-eloi-lupopo', 'Saint-Eloi Lupopo', 'St. Eloi', 'Lubumbashi'),
      ('cs-don-bosco', 'CS Don Bosco', 'CS Don Bosco', 'Lubumbashi'),
      ('as-maniema-union', 'AS Maniema Union', 'Maniema Union', 'Kindu'),
      ('as-dauphins-noirs', 'AS Dauphins Noirs', 'Dauphins Noirs', 'Goma'),
      ('fc-blessing', 'FC Blessing', 'Blessing', 'Kinshasa'),
      ('fc-celeste', 'FC Celeste', 'Celeste', 'Likasi'),
      ('fc-simba-kolwezi', 'FC Simba Kolwezi', 'Simba', 'Kolwezi')
  )
  INSERT INTO football.teams AS t (
    slug, name, short_name, team_type,
    country_code, country_name, city, metadata
  )
  SELECT
    tv.slug, tv.name, tv.short_name,
    'club'::football.team_type,
    'CD', 'Democratic Republic of the Congo', tv.city,
    jsonb_build_object('linafoot_2026', true)
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
      ('fc-les-aigles-du-congo'), ('lubumbashi-sport'), ('as-new-soger'),
      ('malole-fc'), ('js-groupe-bazano'), ('us-panda-b52'),
      ('etoile-de-kivu'), ('fc-simba-kolwezi')
  )
  INSERT INTO football.season_teams AS st (season_id, team_id, metadata)
  SELECT v_season_id, t.id, jsonb_build_object('source', 'manual-drc-fixtures-2026')
  FROM stv
  JOIN football.teams t ON t.slug = stv.team_slug
  ON CONFLICT (season_id, team_id) DO UPDATE
  SET is_active = true, metadata = st.metadata || EXCLUDED.metadata;

  -- ── Fixtures ──
  WITH fixture_values (match_date, home_slug, away_slug) AS (
    VALUES
      -- April 14
      ('2026-04-14', 'malole-fc', 'fc-blessing'),
      ('2026-04-14', 'fc-les-aigles-du-congo', 'fc-celeste'),
      -- April 15
      ('2026-04-15', 'as-new-soger', 'tp-mazembe'),
      ('2026-04-15', 'cs-don-bosco', 'st-eloi-lupopo'),
      -- April 18
      ('2026-04-18', 'as-vita-club', 'dc-motema-pembe'),
      ('2026-04-18', 'as-maniema-union', 'fc-les-aigles-du-congo'),
      ('2026-04-18', 'lubumbashi-sport', 'cs-don-bosco'),
      -- April 19
      ('2026-04-19', 'st-eloi-lupopo', 'tp-mazembe'),
      ('2026-04-19', 'as-dauphins-noirs', 'fc-celeste'),
      ('2026-04-19', 'fc-simba-kolwezi', 'js-groupe-bazano'),
      -- April 22
      ('2026-04-22', 'tp-mazembe', 'lubumbashi-sport'),
      ('2026-04-22', 'dc-motema-pembe', 'as-maniema-union'),
      ('2026-04-22', 'fc-blessing', 'fc-simba-kolwezi'),
      -- April 25
      ('2026-04-25', 'fc-les-aigles-du-congo', 'as-vita-club'),
      ('2026-04-25', 'cs-don-bosco', 'as-new-soger'),
      ('2026-04-25', 'st-eloi-lupopo', 'malole-fc'),
      -- April 26
      ('2026-04-26', 'fc-celeste', 'dc-motema-pembe'),
      ('2026-04-26', 'as-maniema-union', 'as-dauphins-noirs'),
      ('2026-04-26', 'js-groupe-bazano', 'us-panda-b52'),
      -- April 29
      ('2026-04-29', 'as-vita-club', 'as-maniema-union'),
      ('2026-04-29', 'tp-mazembe', 'cs-don-bosco'),
      ('2026-04-29', 'fc-les-aigles-du-congo', 'dc-motema-pembe'),
      -- May 2
      ('2026-05-02', 'st-eloi-lupopo', 'lubumbashi-sport'),
      ('2026-05-02', 'as-dauphins-noirs', 'fc-les-aigles-du-congo'),
      ('2026-05-02', 'fc-blessing', 'js-groupe-bazano'),
      -- May 3
      ('2026-05-03', 'as-maniema-union', 'fc-celeste'),
      ('2026-05-03', 'as-vita-club', 'as-dauphins-noirs'),
      ('2026-05-03', 'dc-motema-pembe', 'etoile-de-kivu'),
      -- May 6
      ('2026-05-06', 'tp-mazembe', 'st-eloi-lupopo'),
      ('2026-05-06', 'cs-don-bosco', 'malole-fc'),
      ('2026-05-06', 'fc-simba-kolwezi', 'us-panda-b52'),
      -- May 9
      ('2026-05-09', 'dc-motema-pembe', 'as-vita-club'),
      ('2026-05-09', 'fc-les-aigles-du-congo', 'as-maniema-union'),
      ('2026-05-09', 'fc-celeste', 'etoile-de-kivu'),
      -- May 10
      ('2026-05-10', 'lubumbashi-sport', 'tp-mazembe'),
      ('2026-05-10', 'as-new-soger', 'st-eloi-lupopo'),
      -- May 16
      ('2026-05-16', 'tp-mazembe', 'as-vita-club'),
      ('2026-05-16', 'st-eloi-lupopo', 'dc-motema-pembe'),
      ('2026-05-16', 'as-maniema-union', 'cs-don-bosco'),
      -- May 17
      ('2026-05-17', 'fc-les-aigles-du-congo', 'lubumbashi-sport'),
      ('2026-05-17', 'fc-celeste', 'fc-blessing'),
      -- May 23
      ('2026-05-23', 'as-vita-club', 'st-eloi-lupopo'),
      ('2026-05-23', 'dc-motema-pembe', 'tp-mazembe'),
      ('2026-05-23', 'as-maniema-union', 'lubumbashi-sport'),
      ('2026-05-23', 'cs-don-bosco', 'fc-les-aigles-du-congo'),
      -- May 30
      ('2026-05-30', 'tp-mazembe', 'as-maniema-union'),
      ('2026-05-30', 'as-vita-club', 'fc-les-aigles-du-congo'),
      ('2026-05-30', 'st-eloi-lupopo', 'as-dauphins-noirs'),
      ('2026-05-30', 'dc-motema-pembe', 'cs-don-bosco')
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
    'manual-drc-linafoot-2026',
    format('drc-lf-2026-%s-%s-vs-%s', fv.match_date, fv.home_slug, fv.away_slug),
    jsonb_build_object(
      'compiled_at', '2026-04-15',
      'source', 'Linafoot official calendar'
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
