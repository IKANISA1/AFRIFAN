-- ============================================================================
-- Rwanda Premier League 2025/26 — April-May fixtures (Matchdays 25-34)
-- Real schedule data from the official RPL calendar
-- ============================================================================

DO $$
DECLARE
  v_competition_id uuid;
  v_season_id uuid;
BEGIN
  SELECT id INTO v_competition_id
  FROM football.competitions WHERE slug = 'rwanda-premier-league';

  SELECT id INTO v_season_id
  FROM football.seasons WHERE slug = 'rwanda-premier-league-2026';

  IF v_competition_id IS NULL OR v_season_id IS NULL THEN
    RAISE EXCEPTION 'Rwanda Premier League competition or season not found.';
  END IF;

  -- RPL April-May fixtures.
  WITH fixture_values (
    match_date, home_slug, away_slug
  ) AS (
    VALUES
      -- April 17
      ('2026-04-17', 'gasogi-united', 'gorilla-fc'),
      ('2026-04-17', 'marine-fc-rw', 'as-kigali-fc'),
      ('2026-04-17', 'musanze-fc', 'amagaju-fc'),
      -- April 18
      ('2026-04-18', 'etincelles-fc', 'apr-fc'),
      ('2026-04-18', 'gicumbi-fc', 'as-muhanga-fc'),
      ('2026-04-18', 'mukura-victory-sports', 'al-merrikh'),
      ('2026-04-18', 'kiyovu-sports', 'al-hilal-omdurman'),
      -- April 19
      ('2026-04-19', 'police-fc-rw', 'bugesera-fc'),
      ('2026-04-19', 'rutsiro-fc', 'rayon-sports-fc'),
      -- April 24
      ('2026-04-24', 'as-kigali-fc', 'gasogi-united'),
      ('2026-04-24', 'as-muhanga-fc', 'gorilla-fc'),
      ('2026-04-24', 'gicumbi-fc', 'rutsiro-fc'),
      -- April 25
      ('2026-04-25', 'al-hilal-omdurman', 'musanze-fc'),
      ('2026-04-25', 'mukura-victory-sports', 'apr-fc'),
      ('2026-04-25', 'police-fc-rw', 'marine-fc-rw'),
      -- April 26
      ('2026-04-26', 'al-merrikh', 'bugesera-fc'),
      ('2026-04-26', 'amagaju-fc', 'rayon-sports-fc'),
      ('2026-04-26', 'etincelles-fc', 'kiyovu-sports'),
      -- May 1
      ('2026-05-01', 'marine-fc-rw', 'gasogi-united'),
      ('2026-05-01', 'gorilla-fc', 'police-fc-rw'),
      -- May 2
      ('2026-05-02', 'etincelles-fc', 'amagaju-fc'),
      ('2026-05-02', 'gicumbi-fc', 'al-merrikh'),
      ('2026-05-02', 'rayon-sports-fc', 'apr-fc'),
      -- May 3
      ('2026-05-03', 'as-kigali-fc', 'al-hilal-omdurman'),
      ('2026-05-03', 'as-muhanga-fc', 'bugesera-fc'),
      ('2026-05-03', 'mukura-victory-sports', 'rutsiro-fc'),
      ('2026-05-03', 'musanze-fc', 'kiyovu-sports'),
      -- May 5
      ('2026-05-05', 'amagaju-fc', 'kiyovu-sports'),
      ('2026-05-05', 'gasogi-united', 'gicumbi-fc'),
      -- May 6
      ('2026-05-06', 'bugesera-fc', 'marine-fc-rw'),
      ('2026-05-06', 'gorilla-fc', 'as-kigali-fc'),
      ('2026-05-06', 'as-muhanga-fc', 'rayon-sports-fc'),
      ('2026-05-06', 'mukura-victory-sports', 'police-fc-rw'),
      ('2026-05-06', 'rutsiro-fc', 'musanze-fc'),
      ('2026-05-06', 'al-merrikh', 'etincelles-fc'),
      -- May 7
      ('2026-05-07', 'apr-fc', 'al-hilal-omdurman'),
      -- May 9
      ('2026-05-09', 'gicumbi-fc', 'bugesera-fc'),
      ('2026-05-09', 'musanze-fc', 'police-fc-rw'),
      ('2026-05-09', 'rutsiro-fc', 'amagaju-fc'),
      ('2026-05-09', 'al-merrikh', 'kiyovu-sports'),
      ('2026-05-09', 'rayon-sports-fc', 'marine-fc-rw'),
      -- May 10
      ('2026-05-10', 'gasogi-united', 'etincelles-fc'),
      ('2026-05-10', 'as-muhanga-fc', 'al-hilal-omdurman'),
      ('2026-05-10', 'mukura-victory-sports', 'gorilla-fc'),
      ('2026-05-10', 'apr-fc', 'as-kigali-fc'),
      -- May 15
      ('2026-05-15', 'as-kigali-fc', 'gicumbi-fc'),
      ('2026-05-15', 'rayon-sports-fc', 'gorilla-fc'),
      -- May 16
      ('2026-05-16', 'kiyovu-sports', 'as-muhanga-fc'),
      ('2026-05-16', 'marine-fc-rw', 'etincelles-fc'),
      ('2026-05-16', 'mukura-victory-sports', 'bugesera-fc'),
      ('2026-05-16', 'police-fc-rw', 'al-hilal-omdurman'),
      -- May 17
      ('2026-05-17', 'amagaju-fc', 'al-merrikh'),
      ('2026-05-17', 'apr-fc', 'rutsiro-fc'),
      ('2026-05-17', 'musanze-fc', 'gasogi-united'),
      -- May 24
      ('2026-05-24', 'al-hilal-omdurman', 'gasogi-united'),
      ('2026-05-24', 'al-merrikh', 'apr-fc'),
      ('2026-05-24', 'amagaju-fc', 'as-muhanga-fc'),
      ('2026-05-24', 'gicumbi-fc', 'mukura-victory-sports'),
      ('2026-05-24', 'gorilla-fc', 'etincelles-fc'),
      ('2026-05-24', 'marine-fc-rw', 'musanze-fc'),
      ('2026-05-24', 'police-fc-rw', 'kiyovu-sports'),
      ('2026-05-24', 'rayon-sports-fc', 'bugesera-fc'),
      ('2026-05-24', 'rutsiro-fc', 'as-kigali-fc'),
      -- May 31 (Final matchday)
      ('2026-05-31', 'apr-fc', 'gicumbi-fc'),
      ('2026-05-31', 'as-kigali-fc', 'musanze-fc'),
      ('2026-05-31', 'etincelles-fc', 'al-hilal-omdurman'),
      ('2026-05-31', 'gasogi-united', 'police-fc-rw'),
      ('2026-05-31', 'gorilla-fc', 'al-merrikh'),
      ('2026-05-31', 'marine-fc-rw', 'as-muhanga-fc'),
      ('2026-05-31', 'mukura-victory-sports', 'amagaju-fc'),
      ('2026-05-31', 'rayon-sports-fc', 'kiyovu-sports'),
      ('2026-05-31', 'rutsiro-fc', 'bugesera-fc')
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
    'manual-rpl-2025-26',
    format('rpl-2025-26-%s-%s-vs-%s', fv.match_date, fv.home_slug, fv.away_slug),
    jsonb_build_object(
      'compiled_at', '2026-04-15',
      'source', 'RPL official calendar'
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
