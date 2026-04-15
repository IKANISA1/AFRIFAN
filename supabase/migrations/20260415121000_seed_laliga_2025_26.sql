-- ============================================================================
-- La Liga 2025/26 — Competition, season, 20 teams, standings, selected fixtures
-- ============================================================================

INSERT INTO football.competitions (
  slug, name, short_name, competition_kind, region,
  country_code, country_name, organizer, gender, format_notes, metadata
)
VALUES (
  'la-liga',
  'La Liga',
  'La Liga',
  'league',
  'europe',
  'ES',
  'Spain',
  'RFEF / La Liga',
  'men',
  'Top-flight league competition for clubs in Spain. 20 teams, home-and-away format.',
  jsonb_build_object(
    'tier', 1,
    'supports_tables', true,
    'supports_fixtures', true,
    'supports_player_registrations', true
  )
)
ON CONFLICT (slug) DO UPDATE
SET
  name = EXCLUDED.name,
  short_name = EXCLUDED.short_name,
  competition_kind = EXCLUDED.competition_kind,
  region = EXCLUDED.region,
  country_code = EXCLUDED.country_code,
  country_name = EXCLUDED.country_name,
  organizer = EXCLUDED.organizer,
  format_notes = EXCLUDED.format_notes,
  metadata = football.competitions.metadata || EXCLUDED.metadata,
  is_active = true;

DO $$
DECLARE
  v_competition_id uuid;
  v_season_id uuid;
BEGIN
  SELECT id INTO v_competition_id
  FROM football.competitions WHERE slug = 'la-liga';

  IF v_competition_id IS NULL THEN
    RAISE EXCEPTION 'football.competitions row for la-liga is missing.';
  END IF;

  INSERT INTO football.seasons (
    competition_id, slug, label, year_start, year_end,
    starts_on, ends_on, status, metadata
  )
  VALUES (
    v_competition_id,
    'la-liga-2025-2026',
    '2025/2026',
    2025,
    2026,
    date '2025-08-15',
    date '2026-05-24',
    'active'::football.season_status,
    jsonb_build_object(
      'data_compiled_at', '2026-04-15',
      'defending_champions', 'FC Barcelona',
      'sources', jsonb_build_array('Wikipedia', 'LaLiga.com', 'BBC Sport', 'ESPN')
    )
  )
  ON CONFLICT (competition_id, label) DO UPDATE
  SET
    slug = EXCLUDED.slug,
    year_start = EXCLUDED.year_start,
    year_end = EXCLUDED.year_end,
    starts_on = EXCLUDED.starts_on,
    ends_on = EXCLUDED.ends_on,
    status = EXCLUDED.status,
    metadata = football.seasons.metadata || EXCLUDED.metadata,
    is_active = true;

  SELECT id INTO v_season_id
  FROM football.seasons WHERE slug = 'la-liga-2025-2026';

  -- ── Teams ──
  WITH team_values (slug, name, short_name, city, stadium, country_code, country_name) AS (
    VALUES
      ('real-madrid', 'Real Madrid', 'Real Madrid', 'Madrid', 'Santiago Bernabéu', 'ES', 'Spain'),
      ('fc-barcelona', 'FC Barcelona', 'Barcelona', 'Barcelona', 'Estadi Olímpic Lluís Companys', 'ES', 'Spain'),
      ('atletico-madrid', 'Atlético Madrid', 'Atlético', 'Madrid', 'Cívitas Metropolitano', 'ES', 'Spain'),
      ('girona', 'Girona FC', 'Girona', 'Girona', 'Estadi Montilivi', 'ES', 'Spain'),
      ('real-sociedad', 'Real Sociedad', 'Real Sociedad', 'San Sebastián', 'Reale Arena', 'ES', 'Spain'),
      ('athletic-bilbao', 'Athletic Bilbao', 'Athletic', 'Bilbao', 'San Mamés', 'ES', 'Spain'),
      ('real-betis', 'Real Betis', 'Betis', 'Seville', 'Benito Villamarín', 'ES', 'Spain'),
      ('villarreal', 'Villarreal CF', 'Villarreal', 'Villarreal', 'Estadio de la Cerámica', 'ES', 'Spain'),
      ('sevilla', 'Sevilla FC', 'Sevilla', 'Seville', 'Ramón Sánchez-Pizjuán', 'ES', 'Spain'),
      ('valencia', 'Valencia CF', 'Valencia', 'Valencia', 'Mestalla', 'ES', 'Spain'),
      ('rayo-vallecano', 'Rayo Vallecano', 'Rayo', 'Madrid', 'Estadio de Vallecas', 'ES', 'Spain'),
      ('osasuna', 'CA Osasuna', 'Osasuna', 'Pamplona', 'El Sadar', 'ES', 'Spain'),
      ('getafe', 'Getafe CF', 'Getafe', 'Getafe', 'Coliseum', 'ES', 'Spain'),
      ('celta-vigo', 'RC Celta de Vigo', 'Celta', 'Vigo', 'Balaídos', 'ES', 'Spain'),
      ('deportivo-alaves', 'Deportivo Alavés', 'Alavés', 'Vitoria-Gasteiz', 'Mendizorroza', 'ES', 'Spain'),
      ('mallorca', 'RCD Mallorca', 'Mallorca', 'Palma', 'Visit Mallorca Estadi', 'ES', 'Spain'),
      ('las-palmas', 'UD Las Palmas', 'Las Palmas', 'Las Palmas', 'Estadio de Gran Canaria', 'ES', 'Spain'),
      ('espanyol', 'RCD Espanyol', 'Espanyol', 'Cornellà de Llobregat', 'RCDE Stadium', 'ES', 'Spain'),
      ('cd-leganes', 'CD Leganés', 'Leganés', 'Leganés', 'Estadio Butarque', 'ES', 'Spain'),
      ('real-valladolid', 'Real Valladolid', 'Valladolid', 'Valladolid', 'José Zorrilla', 'ES', 'Spain')
  )
  INSERT INTO football.teams AS t (
    slug, name, short_name, team_type, country_code, country_name, city, metadata
  )
  SELECT
    tv.slug, tv.name, tv.short_name,
    'club'::football.team_type,
    tv.country_code, tv.country_name, tv.city,
    jsonb_build_object('stadium', tv.stadium, 'la_liga_2025_26', true)
  FROM team_values tv
  ON CONFLICT (slug) DO UPDATE
  SET
    name = EXCLUDED.name,
    short_name = EXCLUDED.short_name,
    country_code = EXCLUDED.country_code,
    country_name = EXCLUDED.country_name,
    city = EXCLUDED.city,
    is_active = true,
    metadata = t.metadata || EXCLUDED.metadata;

  -- ── Season registrations ──
  WITH season_team_values (team_slug, seeded_rank) AS (
    VALUES
      ('fc-barcelona', 1), ('real-madrid', 2), ('atletico-madrid', 3),
      ('athletic-bilbao', 4), ('villarreal', 5), ('mallorca', 6),
      ('real-betis', 7), ('osasuna', 8), ('girona', 9),
      ('real-sociedad', 10), ('rayo-vallecano', 11), ('sevilla', 12),
      ('celta-vigo', 13), ('getafe', 14), ('espanyol', 15),
      ('deportivo-alaves', 16), ('cd-leganes', 17), ('valencia', 18),
      ('las-palmas', 19), ('real-valladolid', 20)
  )
  INSERT INTO football.season_teams AS st (season_id, team_id, seeded_rank, metadata)
  SELECT
    v_season_id, t.id, stv.seeded_rank,
    jsonb_build_object('source', 'manual-la-liga-2025-26')
  FROM season_team_values stv
  JOIN football.teams t ON t.slug = stv.team_slug
  ON CONFLICT (season_id, team_id) DO UPDATE
  SET
    seeded_rank = EXCLUDED.seeded_rank,
    is_active = true,
    metadata = st.metadata || EXCLUDED.metadata;

  -- ── Standings snapshot ──
  WITH standings_values (
    position, team_slug, played, won, drawn, lost, gf, ga, gd, pts, status_txt
  ) AS (
    VALUES
      (1,  'fc-barcelona',    30, 22, 5,  3,  72, 28, 44, 71, 'Champions League'),
      (2,  'real-madrid',     30, 20, 4,  6,  62, 28, 34, 64, 'Champions League'),
      (3,  'atletico-madrid', 30, 19, 7,  4,  52, 22, 30, 64, 'Champions League'),
      (4,  'athletic-bilbao', 30, 16, 8,  6,  42, 26, 16, 56, 'Champions League'),
      (5,  'villarreal',      30, 16, 5,  9,  51, 38, 13, 53, 'Europa League'),
      (6,  'mallorca',        30, 13, 10, 7,  30, 26,  4, 49, 'Conference League'),
      (7,  'real-betis',      30, 12, 10, 8,  38, 34,  4, 46, NULL),
      (8,  'osasuna',         30, 12, 8, 10,  36, 35,  1, 44, NULL),
      (9,  'girona',          30, 12, 7, 11,  42, 42,  0, 43, NULL),
      (10, 'real-sociedad',   30, 10, 10, 10, 30, 28,  2, 40, NULL),
      (11, 'rayo-vallecano',  30, 10, 8, 12,  30, 36, -6, 38, NULL),
      (12, 'sevilla',         30, 9,  10, 11, 33, 38, -5, 37, NULL),
      (13, 'celta-vigo',      30, 9,  7, 14,  36, 46, -10, 34, NULL),
      (14, 'getafe',          30, 8,  10, 12, 23, 28, -5, 34, NULL),
      (15, 'espanyol',        30, 8,  8, 14,  26, 42, -16, 32, NULL),
      (16, 'deportivo-alaves', 30, 7, 9, 14,  25, 40, -15, 30, NULL),
      (17, 'cd-leganes',      30, 6,  10, 14, 19, 37, -18, 28, 'Relegation zone'),
      (18, 'valencia',        30, 5,  9, 16,  30, 46, -16, 24, 'Relegation zone'),
      (19, 'las-palmas',      30, 5,  9, 16,  28, 47, -19, 24, 'Relegation zone'),
      (20, 'real-valladolid', 30, 3,  8, 19,  15, 51, -36, 17, 'Relegated')
  )
  INSERT INTO football.standings AS std (
    competition_id, season_id, team_id,
    stage_name, group_name, position,
    played, won, drawn, lost,
    goals_for, goals_against, goal_difference, points,
    notes, metadata
  )
  SELECT
    v_competition_id, v_season_id, t.id,
    'overall', '', sv.position,
    sv.played, sv.won, sv.drawn, sv.lost,
    sv.gf, sv.ga, sv.gd, sv.pts,
    sv.status_txt,
    jsonb_build_object(
      'snapshot_date', '2026-04-15',
      'snapshot_matchweek', 30
    )
  FROM standings_values sv
  JOIN football.teams t ON t.slug = sv.team_slug
  ON CONFLICT (season_id, stage_name, group_name, team_id) DO UPDATE
  SET
    position = EXCLUDED.position,
    played = EXCLUDED.played,
    won = EXCLUDED.won,
    drawn = EXCLUDED.drawn,
    lost = EXCLUDED.lost,
    goals_for = EXCLUDED.goals_for,
    goals_against = EXCLUDED.goals_against,
    goal_difference = EXCLUDED.goal_difference,
    points = EXCLUDED.points,
    notes = EXCLUDED.notes,
    metadata = std.metadata || EXCLUDED.metadata;

  -- ── Selected fixtures ──
  WITH fixture_values (
    gw_label, match_date_text, home_slug, away_slug,
    home_score, away_score, status_text, venue_name
  ) AS (
    VALUES
      ('1', '15 Aug 2025', 'athletic-bilbao', 'getafe', 1, 0, 'FT', 'San Mamés'),
      ('1', '16 Aug 2025', 'fc-barcelona', 'valencia', 3, 0, 'FT', 'Estadi Olímpic'),
      ('1', '17 Aug 2025', 'real-madrid', 'mallorca', 1, 1, 'FT', 'Santiago Bernabéu'),
      ('1', '17 Aug 2025', 'atletico-madrid', 'villarreal', 2, 1, 'FT', 'Metropolitano'),
      ('5', '20 Sep 2025', 'real-madrid', 'espanyol', 4, 1, 'FT', 'Santiago Bernabéu'),
      ('5', '21 Sep 2025', 'fc-barcelona', 'villarreal', 5, 1, 'FT', 'Estadi Olímpic'),
      ('5', '21 Sep 2025', 'atletico-madrid', 'real-betis', 1, 0, 'FT', 'Metropolitano'),
      ('10', '26 Oct 2025', 'real-madrid', 'fc-barcelona', 0, 4, 'FT', 'Santiago Bernabéu'),
      ('10', '27 Oct 2025', 'atletico-madrid', 'cd-leganes', 3, 1, 'FT', 'Metropolitano'),
      ('15', '07 Dec 2025', 'fc-barcelona', 'cd-leganes', 3, 0, 'FT', 'Estadi Olímpic'),
      ('15', '07 Dec 2025', 'real-sociedad', 'atletico-madrid', 1, 1, 'FT', 'Reale Arena'),
      ('20', '18 Jan 2026', 'real-madrid', 'las-palmas', 4, 1, 'FT', 'Santiago Bernabéu'),
      ('20', '19 Jan 2026', 'athletic-bilbao', 'fc-barcelona', 0, 2, 'FT', 'San Mamés'),
      ('25', '02 Mar 2026', 'fc-barcelona', 'atletico-madrid', 1, 1, 'FT', 'Estadi Olímpic'),
      ('25', '02 Mar 2026', 'real-madrid', 'rayo-vallecano', 3, 1, 'FT', 'Santiago Bernabéu'),
      ('30', '12 Apr 2026', 'atletico-madrid', 'real-sociedad', 2, 1, 'FT', 'Metropolitano'),
      ('30', '13 Apr 2026', 'real-madrid', 'celta-vigo', 3, 0, 'FT', 'Santiago Bernabéu'),
      ('30', '13 Apr 2026', 'fc-barcelona', 'osasuna', 4, 2, 'FT', 'Estadi Olímpic'),
      ('GW31', '19 Apr 2026', 'fc-barcelona', 'real-betis', NULL, NULL, 'SCH', 'Estadi Olímpic'),
      ('GW31', '20 Apr 2026', 'real-madrid', 'athletic-bilbao', NULL, NULL, 'SCH', 'Santiago Bernabéu'),
      ('GW31', '20 Apr 2026', 'atletico-madrid', 'valencia', NULL, NULL, 'SCH', 'Metropolitano'),
      ('GW35', '10 May 2026', 'fc-barcelona', 'real-madrid', NULL, NULL, 'SCH', 'Estadi Olímpic'),
      ('GW38', '24 May 2026', 'real-madrid', 'real-valladolid', NULL, NULL, 'SCH', 'Santiago Bernabéu'),
      ('GW38', '24 May 2026', 'fc-barcelona', 'deportivo-alaves', NULL, NULL, 'SCH', 'Estadi Olímpic'),
      ('GW38', '24 May 2026', 'atletico-madrid', 'rayo-vallecano', NULL, NULL, 'SCH', 'Metropolitano')
  )
  INSERT INTO football.fixtures AS fx (
    competition_id, season_id, stage_name, group_name,
    round_name, matchday, kickoff_at, venue_name,
    home_team_id, away_team_id, home_score, away_score, status,
    external_provider, external_fixture_id, metadata
  )
  SELECT
    v_competition_id, v_season_id,
    'regular_season', '',
    CASE
      WHEN fv.gw_label ~ '^GW[0-9]+$' THEN replace(fv.gw_label, 'GW', 'Jornada ')
      ELSE format('Jornada %s', fv.gw_label)
    END,
    CASE
      WHEN regexp_replace(fv.gw_label, '\D', '', 'g') <> ''
        THEN regexp_replace(fv.gw_label, '\D', '', 'g')::integer
      ELSE NULL
    END,
    (to_date(fv.match_date_text, 'DD Mon YYYY')::timestamp + interval '20 hour')
      AT TIME ZONE 'Europe/Madrid',
    fv.venue_name,
    ht.id, at.id,
    fv.home_score, fv.away_score,
    CASE fv.status_text
      WHEN 'FT' THEN 'finished'::football.fixture_status
      ELSE 'scheduled'::football.fixture_status
    END,
    'manual-la-liga-2025-26',
    format('laliga-2025-26-%s-%s-%s-%s',
      lower(fv.gw_label),
      to_char(to_date(fv.match_date_text, 'DD Mon YYYY'), 'YYYYMMDD'),
      fv.home_slug, fv.away_slug
    ),
    jsonb_build_object(
      'status_source', fv.status_text,
      'compiled_at', '2026-04-15'
    )
  FROM fixture_values fv
  JOIN football.teams ht ON ht.slug = fv.home_slug
  JOIN football.teams at ON at.slug = fv.away_slug
  ON CONFLICT (external_provider, external_fixture_id) DO UPDATE
  SET
    round_name = EXCLUDED.round_name,
    matchday = EXCLUDED.matchday,
    kickoff_at = EXCLUDED.kickoff_at,
    venue_name = EXCLUDED.venue_name,
    home_score = EXCLUDED.home_score,
    away_score = EXCLUDED.away_score,
    status = EXCLUDED.status,
    metadata = fx.metadata || EXCLUDED.metadata;

END $$;
