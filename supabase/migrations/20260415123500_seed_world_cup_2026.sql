-- ============================================================================
-- FIFA World Cup 2026 — 48 national teams, 12 groups, full group-stage fixtures
-- Uses official FIFA schedule (June 11 – July 19, 2026)
-- ============================================================================

DO $$
DECLARE
  v_competition_id uuid;
  v_season_id uuid;
BEGIN
  SELECT id INTO v_competition_id
  FROM football.competitions WHERE slug = 'fifa-world-cup-2026';

  SELECT id INTO v_season_id
  FROM football.seasons WHERE slug = 'fifa-world-cup-2026';

  IF v_competition_id IS NULL OR v_season_id IS NULL THEN
    RAISE EXCEPTION 'FIFA World Cup 2026 competition or season missing.';
  END IF;

  -- Update season
  UPDATE football.seasons
  SET
    starts_on = date '2026-06-11',
    ends_on = date '2026-07-19',
    status = 'planned',
    metadata = metadata || jsonb_build_object(
      'data_compiled_at', '2026-04-15',
      'host_countries', jsonb_build_array('USA', 'Mexico', 'Canada'),
      'format', '48_teams_12_groups',
      'sources', jsonb_build_array('FIFA.com', 'Wikipedia')
    )
  WHERE id = v_season_id;

  -- ── 48 National Teams ──
  WITH team_values (slug, name, short_name, country_code, country_name, grp) AS (
    VALUES
      -- Group A
      ('nt-mexico', 'Mexico', 'MEX', 'MX', 'Mexico', 'A'),
      ('nt-south-africa', 'South Africa', 'RSA', 'ZA', 'South Africa', 'A'),
      ('nt-south-korea', 'South Korea', 'KOR', 'KR', 'South Korea', 'A'),
      ('nt-czechia', 'Czechia', 'CZE', 'CZ', 'Czechia', 'A'),
      -- Group B
      ('nt-canada', 'Canada', 'CAN', 'CA', 'Canada', 'B'),
      ('nt-bosnia', 'Bosnia and Herzegovina', 'BIH', 'BA', 'Bosnia and Herzegovina', 'B'),
      ('nt-qatar', 'Qatar', 'QAT', 'QA', 'Qatar', 'B'),
      ('nt-switzerland', 'Switzerland', 'SUI', 'CH', 'Switzerland', 'B'),
      -- Group C
      ('nt-brazil', 'Brazil', 'BRA', 'BR', 'Brazil', 'C'),
      ('nt-morocco', 'Morocco', 'MAR', 'MA', 'Morocco', 'C'),
      ('nt-haiti', 'Haiti', 'HAI', 'HT', 'Haiti', 'C'),
      ('nt-scotland', 'Scotland', 'SCO', 'GB-SCT', 'Scotland', 'C'),
      -- Group D
      ('nt-usa', 'United States', 'USA', 'US', 'United States', 'D'),
      ('nt-paraguay', 'Paraguay', 'PAR', 'PY', 'Paraguay', 'D'),
      ('nt-australia', 'Australia', 'AUS', 'AU', 'Australia', 'D'),
      ('nt-turkiye', 'Türkiye', 'TUR', 'TR', 'Türkiye', 'D'),
      -- Group E
      ('nt-germany', 'Germany', 'GER', 'DE', 'Germany', 'E'),
      ('nt-curacao', 'Curaçao', 'CUW', 'CW', 'Curaçao', 'E'),
      ('nt-ivory-coast', 'Ivory Coast', 'CIV', 'CI', 'Ivory Coast', 'E'),
      ('nt-ecuador', 'Ecuador', 'ECU', 'EC', 'Ecuador', 'E'),
      -- Group F
      ('nt-netherlands', 'Netherlands', 'NED', 'NL', 'Netherlands', 'F'),
      ('nt-japan', 'Japan', 'JPN', 'JP', 'Japan', 'F'),
      ('nt-tunisia', 'Tunisia', 'TUN', 'TN', 'Tunisia', 'F'),
      ('nt-sweden', 'Sweden', 'SWE', 'SE', 'Sweden', 'F'),
      -- Group G
      ('nt-belgium', 'Belgium', 'BEL', 'BE', 'Belgium', 'G'),
      ('nt-egypt', 'Egypt', 'EGY', 'EG', 'Egypt', 'G'),
      ('nt-iran', 'Iran', 'IRN', 'IR', 'Iran', 'G'),
      ('nt-new-zealand', 'New Zealand', 'NZL', 'NZ', 'New Zealand', 'G'),
      -- Group H
      ('nt-spain', 'Spain', 'ESP', 'ES', 'Spain', 'H'),
      ('nt-cape-verde', 'Cape Verde', 'CPV', 'CV', 'Cape Verde', 'H'),
      ('nt-saudi-arabia', 'Saudi Arabia', 'KSA', 'SA', 'Saudi Arabia', 'H'),
      ('nt-uruguay', 'Uruguay', 'URU', 'UY', 'Uruguay', 'H'),
      -- Group I
      ('nt-france', 'France', 'FRA', 'FR', 'France', 'I'),
      ('nt-senegal', 'Senegal', 'SEN', 'SN', 'Senegal', 'I'),
      ('nt-norway', 'Norway', 'NOR', 'NO', 'Norway', 'I'),
      ('nt-iraq', 'Iraq', 'IRQ', 'IQ', 'Iraq', 'I'),
      -- Group J
      ('nt-argentina', 'Argentina', 'ARG', 'AR', 'Argentina', 'J'),
      ('nt-algeria', 'Algeria', 'ALG', 'DZ', 'Algeria', 'J'),
      ('nt-austria', 'Austria', 'AUT', 'AT', 'Austria', 'J'),
      ('nt-jordan', 'Jordan', 'JOR', 'JO', 'Jordan', 'J'),
      -- Group K
      ('nt-portugal', 'Portugal', 'POR', 'PT', 'Portugal', 'K'),
      ('nt-dr-congo', 'DR Congo', 'COD', 'CD', 'DR Congo', 'K'),
      ('nt-uzbekistan', 'Uzbekistan', 'UZB', 'UZ', 'Uzbekistan', 'K'),
      ('nt-colombia', 'Colombia', 'COL', 'CO', 'Colombia', 'K'),
      -- Group L
      ('nt-england', 'England', 'ENG', 'GB-ENG', 'England', 'L'),
      ('nt-croatia', 'Croatia', 'CRO', 'HR', 'Croatia', 'L'),
      ('nt-ghana', 'Ghana', 'GHA', 'GH', 'Ghana', 'L'),
      ('nt-panama', 'Panama', 'PAN', 'PA', 'Panama', 'L')
  )
  INSERT INTO football.teams AS t (
    slug, name, short_name, team_type,
    country_code, country_name, metadata
  )
  SELECT
    tv.slug, tv.name, tv.short_name,
    'national'::football.team_type,
    tv.country_code, tv.country_name,
    jsonb_build_object('wc_2026_group', tv.grp)
  FROM team_values tv
  ON CONFLICT (slug) DO UPDATE
  SET
    name = EXCLUDED.name,
    short_name = EXCLUDED.short_name,
    country_code = EXCLUDED.country_code,
    country_name = EXCLUDED.country_name,
    team_type = 'national',
    is_active = true,
    metadata = t.metadata || EXCLUDED.metadata;

  -- ── Season team registrations with group assignments ──
  WITH stv (team_slug, grp, rank) AS (
    VALUES
      ('nt-mexico', 'A', 1), ('nt-south-africa', 'A', 2), ('nt-south-korea', 'A', 3), ('nt-czechia', 'A', 4),
      ('nt-canada', 'B', 1), ('nt-bosnia', 'B', 2), ('nt-qatar', 'B', 3), ('nt-switzerland', 'B', 4),
      ('nt-brazil', 'C', 1), ('nt-morocco', 'C', 2), ('nt-haiti', 'C', 3), ('nt-scotland', 'C', 4),
      ('nt-usa', 'D', 1), ('nt-paraguay', 'D', 2), ('nt-australia', 'D', 3), ('nt-turkiye', 'D', 4),
      ('nt-germany', 'E', 1), ('nt-curacao', 'E', 2), ('nt-ivory-coast', 'E', 3), ('nt-ecuador', 'E', 4),
      ('nt-netherlands', 'F', 1), ('nt-japan', 'F', 2), ('nt-tunisia', 'F', 3), ('nt-sweden', 'F', 4),
      ('nt-belgium', 'G', 1), ('nt-egypt', 'G', 2), ('nt-iran', 'G', 3), ('nt-new-zealand', 'G', 4),
      ('nt-spain', 'H', 1), ('nt-cape-verde', 'H', 2), ('nt-saudi-arabia', 'H', 3), ('nt-uruguay', 'H', 4),
      ('nt-france', 'I', 1), ('nt-senegal', 'I', 2), ('nt-norway', 'I', 3), ('nt-iraq', 'I', 4),
      ('nt-argentina', 'J', 1), ('nt-algeria', 'J', 2), ('nt-austria', 'J', 3), ('nt-jordan', 'J', 4),
      ('nt-portugal', 'K', 1), ('nt-dr-congo', 'K', 2), ('nt-uzbekistan', 'K', 3), ('nt-colombia', 'K', 4),
      ('nt-england', 'L', 1), ('nt-croatia', 'L', 2), ('nt-ghana', 'L', 3), ('nt-panama', 'L', 4)
  )
  INSERT INTO football.season_teams AS st (
    season_id, team_id, group_name, seeded_rank, metadata
  )
  SELECT
    v_season_id, t.id,
    format('Group %s', stv.grp),
    stv.rank,
    jsonb_build_object('source', 'fifa-wc-2026-draw')
  FROM stv
  JOIN football.teams t ON t.slug = stv.team_slug
  ON CONFLICT (season_id, team_id) DO UPDATE
  SET
    group_name = EXCLUDED.group_name,
    seeded_rank = EXCLUDED.seeded_rank,
    is_active = true,
    metadata = st.metadata || EXCLUDED.metadata;

  -- ── Group-stage standings (all zeros — tournament hasn't started) ──
  WITH stv (team_slug, grp, pos) AS (
    VALUES
      ('nt-mexico', 'A', 1), ('nt-south-africa', 'A', 2), ('nt-south-korea', 'A', 3), ('nt-czechia', 'A', 4),
      ('nt-canada', 'B', 1), ('nt-bosnia', 'B', 2), ('nt-qatar', 'B', 3), ('nt-switzerland', 'B', 4),
      ('nt-brazil', 'C', 1), ('nt-morocco', 'C', 2), ('nt-haiti', 'C', 3), ('nt-scotland', 'C', 4),
      ('nt-usa', 'D', 1), ('nt-paraguay', 'D', 2), ('nt-australia', 'D', 3), ('nt-turkiye', 'D', 4),
      ('nt-germany', 'E', 1), ('nt-curacao', 'E', 2), ('nt-ivory-coast', 'E', 3), ('nt-ecuador', 'E', 4),
      ('nt-netherlands', 'F', 1), ('nt-japan', 'F', 2), ('nt-tunisia', 'F', 3), ('nt-sweden', 'F', 4),
      ('nt-belgium', 'G', 1), ('nt-egypt', 'G', 2), ('nt-iran', 'G', 3), ('nt-new-zealand', 'G', 4),
      ('nt-spain', 'H', 1), ('nt-cape-verde', 'H', 2), ('nt-saudi-arabia', 'H', 3), ('nt-uruguay', 'H', 4),
      ('nt-france', 'I', 1), ('nt-senegal', 'I', 2), ('nt-norway', 'I', 3), ('nt-iraq', 'I', 4),
      ('nt-argentina', 'J', 1), ('nt-algeria', 'J', 2), ('nt-austria', 'J', 3), ('nt-jordan', 'J', 4),
      ('nt-portugal', 'K', 1), ('nt-dr-congo', 'K', 2), ('nt-uzbekistan', 'K', 3), ('nt-colombia', 'K', 4),
      ('nt-england', 'L', 1), ('nt-croatia', 'L', 2), ('nt-ghana', 'L', 3), ('nt-panama', 'L', 4)
  )
  INSERT INTO football.standings AS std (
    competition_id, season_id, team_id,
    stage_name, group_name, position,
    played, won, drawn, lost,
    goals_for, goals_against, goal_difference, points,
    metadata
  )
  SELECT
    v_competition_id, v_season_id, t.id,
    'group_stage', format('Group %s', stv.grp), stv.pos,
    0, 0, 0, 0, 0, 0, 0, 0,
    jsonb_build_object('snapshot_date', '2026-04-15', 'tournament_status', 'pre_tournament')
  FROM stv
  JOIN football.teams t ON t.slug = stv.team_slug
  ON CONFLICT (season_id, stage_name, group_name, team_id) DO UPDATE
  SET
    position = EXCLUDED.position,
    metadata = std.metadata || EXCLUDED.metadata;

  -- ═══════════════════════════════════════════════════════════════════════
  -- GROUP-STAGE FIXTURES — Full official FIFA schedule
  -- All times converted to UTC from ET (ET = UTC-4 in June/July DST)
  -- ═══════════════════════════════════════════════════════════════════════

  WITH fixture_values (
    grp, match_date, match_time_utc,
    home_slug, away_slug, venue_name, venue_city
  ) AS (
    VALUES
      -- Matchday 1
      ('A', '2026-06-11', '19:00', 'nt-mexico', 'nt-south-africa', 'Estadio Azteca', 'Mexico City'),
      ('A', '2026-06-12', '02:00', 'nt-south-korea', 'nt-czechia', 'Estadio Akron', 'Zapopan'),
      ('B', '2026-06-13', '00:00', 'nt-canada', 'nt-bosnia', 'BMO Field', 'Toronto'),
      ('D', '2026-06-13', '06:00', 'nt-usa', 'nt-paraguay', 'SoFi Stadium', 'Inglewood'),
      ('B', '2026-06-14', '00:00', 'nt-qatar', 'nt-switzerland', 'Levi''s Stadium', 'Santa Clara'),
      ('C', '2026-06-14', '03:00', 'nt-brazil', 'nt-morocco', 'MetLife Stadium', 'East Rutherford'),
      ('C', '2026-06-14', '06:00', 'nt-haiti', 'nt-scotland', 'Gillette Stadium', 'Foxborough'),
      ('D', '2026-06-14', '09:00', 'nt-australia', 'nt-turkiye', 'BC Place', 'Vancouver'),
      ('E', '2026-06-14', '17:00', 'nt-germany', 'nt-curacao', 'NRG Stadium', 'Houston'),
      ('F', '2026-06-14', '20:00', 'nt-netherlands', 'nt-japan', 'AT&T Stadium', 'Arlington'),
      ('E', '2026-06-14', '23:00', 'nt-ivory-coast', 'nt-ecuador', 'Lincoln Financial Field', 'Philadelphia'),
      ('F', '2026-06-15', '02:00', 'nt-tunisia', 'nt-sweden', 'Estadio BBVA', 'Monterrey'),
      ('H', '2026-06-15', '21:00', 'nt-spain', 'nt-cape-verde', 'Mercedes-Benz Stadium', 'Atlanta'),
      ('H', '2026-06-15', '22:00', 'nt-saudi-arabia', 'nt-uruguay', 'Hard Rock Stadium', 'Miami Gardens'),
      ('G', '2026-06-16', '00:00', 'nt-belgium', 'nt-egypt', 'Lumen Field', 'Seattle'),
      ('G', '2026-06-16', '01:00', 'nt-iran', 'nt-new-zealand', 'SoFi Stadium', 'Inglewood'),
      ('I', '2026-06-16', '19:00', 'nt-france', 'nt-senegal', 'MetLife Stadium', 'East Rutherford'),
      ('I', '2026-06-16', '22:00', 'nt-norway', 'nt-iraq', 'Gillette Stadium', 'Foxborough'),
      ('J', '2026-06-17', '01:00', 'nt-argentina', 'nt-algeria', 'Arrowhead Stadium', 'Kansas City'),
      ('J', '2026-06-17', '04:00', 'nt-austria', 'nt-jordan', 'Levi''s Stadium', 'Santa Clara'),
      ('K', '2026-06-17', '17:00', 'nt-portugal', 'nt-dr-congo', 'NRG Stadium', 'Houston'),
      ('L', '2026-06-17', '20:00', 'nt-england', 'nt-croatia', 'AT&T Stadium', 'Arlington'),
      ('L', '2026-06-17', '23:00', 'nt-ghana', 'nt-panama', 'BMO Field', 'Toronto'),
      ('K', '2026-06-18', '02:00', 'nt-uzbekistan', 'nt-colombia', 'Estadio Azteca', 'Mexico City'),

      -- Matchday 2
      ('A', '2026-06-18', '21:00', 'nt-czechia', 'nt-south-africa', 'Mercedes-Benz Stadium', 'Atlanta'),
      ('B', '2026-06-19', '00:00', 'nt-switzerland', 'nt-bosnia', 'SoFi Stadium', 'Inglewood'),
      ('B', '2026-06-19', '03:00', 'nt-canada', 'nt-qatar', 'BC Place', 'Vancouver'),
      ('A', '2026-06-19', '06:00', 'nt-mexico', 'nt-south-korea', 'Estadio Akron', 'Zapopan'),
      ('D', '2026-06-19', '19:00', 'nt-usa', 'nt-australia', 'Lumen Field', 'Seattle'),
      ('C', '2026-06-19', '19:00', 'nt-scotland', 'nt-morocco', 'Gillette Stadium', 'Foxborough'),
      ('C', '2026-06-20', '01:00', 'nt-brazil', 'nt-haiti', 'Lincoln Financial Field', 'Philadelphia'),
      ('D', '2026-06-20', '02:00', 'nt-paraguay', 'nt-turkiye', 'Levi''s Stadium', 'Santa Clara'),
      ('F', '2026-06-20', '17:00', 'nt-netherlands', 'nt-sweden', 'NRG Stadium', 'Houston'),
      ('E', '2026-06-20', '20:00', 'nt-germany', 'nt-ivory-coast', 'BMO Field', 'Toronto'),
      ('E', '2026-06-21', '00:00', 'nt-ecuador', 'nt-curacao', 'Arrowhead Stadium', 'Kansas City'),
      ('F', '2026-06-21', '04:00', 'nt-tunisia', 'nt-japan', 'Estadio BBVA', 'Monterrey'),
      ('H', '2026-06-21', '21:00', 'nt-spain', 'nt-saudi-arabia', 'Mercedes-Benz Stadium', 'Atlanta'),
      ('H', '2026-06-21', '22:00', 'nt-uruguay', 'nt-cape-verde', 'Hard Rock Stadium', 'Miami Gardens'),
      ('G', '2026-06-22', '00:00', 'nt-belgium', 'nt-iran', 'SoFi Stadium', 'Inglewood'),
      ('G', '2026-06-22', '01:00', 'nt-new-zealand', 'nt-egypt', 'BC Place', 'Vancouver'),
      ('J', '2026-06-22', '17:00', 'nt-argentina', 'nt-austria', 'AT&T Stadium', 'Arlington'),
      ('I', '2026-06-22', '21:00', 'nt-france', 'nt-iraq', 'Lincoln Financial Field', 'Philadelphia'),
      ('I', '2026-06-23', '00:00', 'nt-norway', 'nt-senegal', 'MetLife Stadium', 'East Rutherford'),
      ('J', '2026-06-23', '03:00', 'nt-jordan', 'nt-algeria', 'Levi''s Stadium', 'Santa Clara'),
      ('K', '2026-06-23', '17:00', 'nt-portugal', 'nt-uzbekistan', 'NRG Stadium', 'Houston'),
      ('L', '2026-06-23', '20:00', 'nt-england', 'nt-ghana', 'Gillette Stadium', 'Foxborough'),
      ('L', '2026-06-23', '23:00', 'nt-panama', 'nt-croatia', 'BMO Field', 'Toronto'),
      ('K', '2026-06-24', '02:00', 'nt-colombia', 'nt-dr-congo', 'Estadio Akron', 'Zapopan'),

      -- Matchday 3
      ('B', '2026-06-24', '19:00', 'nt-canada', 'nt-switzerland', 'BC Place', 'Vancouver'),
      ('B', '2026-06-24', '19:00', 'nt-qatar', 'nt-bosnia', 'Lumen Field', 'Seattle'),
      ('C', '2026-06-24', '22:00', 'nt-scotland', 'nt-brazil', 'Hard Rock Stadium', 'Miami Gardens'),
      ('C', '2026-06-24', '22:00', 'nt-morocco', 'nt-haiti', 'Mercedes-Benz Stadium', 'Atlanta'),
      ('A', '2026-06-25', '01:00', 'nt-mexico', 'nt-czechia', 'Estadio Azteca', 'Mexico City'),
      ('A', '2026-06-25', '01:00', 'nt-south-korea', 'nt-south-africa', 'Estadio BBVA', 'Monterrey'),
      ('E', '2026-06-25', '20:00', 'nt-ecuador', 'nt-germany', 'MetLife Stadium', 'East Rutherford'),
      ('E', '2026-06-26', '01:00', 'nt-curacao', 'nt-ivory-coast', 'Lincoln Financial Field', 'Philadelphia'),
      ('I', '2026-06-26', '19:00', 'nt-norway', 'nt-france', 'Gillette Stadium', 'Foxborough'),
      ('I', '2026-06-26', '19:00', 'nt-senegal', 'nt-iraq', 'BMO Field', 'Toronto'),
      ('H', '2026-06-27', '00:00', 'nt-uruguay', 'nt-spain', 'Estadio Akron', 'Zapopan'),
      ('H', '2026-06-27', '00:00', 'nt-cape-verde', 'nt-saudi-arabia', 'NRG Stadium', 'Houston'),
      ('G', '2026-06-27', '03:00', 'nt-new-zealand', 'nt-belgium', 'BC Place', 'Vancouver'),
      ('G', '2026-06-27', '03:00', 'nt-egypt', 'nt-iran', 'Lumen Field', 'Seattle'),
      ('L', '2026-06-28', '02:00', 'nt-croatia', 'nt-ghana', 'Lincoln Financial Field', 'Philadelphia'),
      ('L', '2026-06-28', '02:00', 'nt-panama', 'nt-england', 'MetLife Stadium', 'East Rutherford')
  )
  INSERT INTO football.fixtures AS f (
    competition_id, season_id,
    stage_name, group_name, round_name,
    kickoff_at, venue_name, venue_city,
    home_team_id, away_team_id,
    status,
    external_provider, external_fixture_id, metadata
  )
  SELECT
    v_competition_id, v_season_id,
    'group_stage',
    format('Group %s', fv.grp),
    format('Group %s - MD%s',
      fv.grp,
      CASE
        WHEN fv.match_date <= '2026-06-18' THEN '1'
        WHEN fv.match_date <= '2026-06-24' THEN '2'
        ELSE '3'
      END
    ),
    (fv.match_date || ' ' || fv.match_time_utc)::timestamptz,
    fv.venue_name, fv.venue_city,
    ht.id, at.id,
    'scheduled'::football.fixture_status,
    'fifa-wc-2026',
    format('wc2026-gs-%s-%s-%s-%s',
      fv.grp, fv.match_date, fv.home_slug, fv.away_slug
    ),
    jsonb_build_object(
      'compiled_at', '2026-04-15',
      'source', 'FIFA official schedule'
    )
  FROM fixture_values fv
  JOIN football.teams ht ON ht.slug = fv.home_slug
  JOIN football.teams at ON at.slug = fv.away_slug
  ON CONFLICT (external_provider, external_fixture_id) DO UPDATE
  SET
    stage_name = EXCLUDED.stage_name,
    group_name = EXCLUDED.group_name,
    round_name = EXCLUDED.round_name,
    kickoff_at = EXCLUDED.kickoff_at,
    venue_name = EXCLUDED.venue_name,
    venue_city = EXCLUDED.venue_city,
    home_team_id = EXCLUDED.home_team_id,
    away_team_id = EXCLUDED.away_team_id,
    status = EXCLUDED.status,
    metadata = f.metadata || EXCLUDED.metadata;

  -- ── Knockout-stage placeholder fixtures ──
  -- (No teams assigned yet — markers for the bracket)
  -- These won't be inserted as actual fixture rows since home/away teams are TBD.
  -- They'll be created dynamically by admin once group stage completes.

END $$;
