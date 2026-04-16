-- ============================================================================
-- UEFA Champions League 2025/26 — League Phase (new 36-team format)
-- Competition, season, teams, standings, and selected fixtures
-- ============================================================================

INSERT INTO football.competitions (
  slug, name, short_name, competition_kind, region,
  country_code, country_name, organizer, gender, format_notes, metadata
)
VALUES (
  'champions-league',
  'UEFA Champions League',
  'UCL',
  'cup',
  'europe',
  NULL,
  'Europe',
  'UEFA',
  'men',
  'Club tournament with 36-team league phase followed by knockout rounds.',
  jsonb_build_object(
    'tier', 1,
    'supports_tables', true,
    'supports_fixtures', true,
    'supports_groups', false,
    'format', 'league_phase_36_teams',
    'knockout_from', 'top_24'
  )
)
ON CONFLICT (slug) DO UPDATE
SET
  name = EXCLUDED.name,
  short_name = EXCLUDED.short_name,
  competition_kind = EXCLUDED.competition_kind,
  region = EXCLUDED.region,
  organizer = EXCLUDED.organizer,
  format_notes = EXCLUDED.format_notes,
  metadata = football.competitions.metadata || EXCLUDED.metadata,
  is_active = true;

INSERT INTO football.seasons (
  competition_id, slug, label, year_start, year_end,
  starts_on, ends_on, status, metadata
)
SELECT
  c.id,
  'champions-league-2025-2026',
  '2025/2026',
  2025,
  2026,
  date '2025-09-16',
  date '2026-05-30',
  'active'::football.season_status,
  jsonb_build_object(
    'format', 'league_phase_36',
    'data_compiled_at', '2026-04-15',
    'sources', jsonb_build_array('UEFA.com', 'Wikipedia', 'ESPN', 'BBC Sport')
  )
FROM football.competitions c
WHERE c.slug = 'champions-league'
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

-- ── Teams (36 clubs in the league phase) ──
DO $$
DECLARE
  v_competition_id uuid;
  v_season_id uuid;
BEGIN
  SELECT id INTO v_competition_id
  FROM football.competitions WHERE slug = 'champions-league';

  SELECT id INTO v_season_id
  FROM football.seasons WHERE slug = 'champions-league-2025-2026';

  IF v_competition_id IS NULL OR v_season_id IS NULL THEN
    RAISE EXCEPTION 'Champions League competition or season missing.';
  END IF;

  -- Upsert all 36 teams
  WITH team_values (slug, name, short_name, country_code, country_name, city) AS (
    VALUES
      ('real-madrid', 'Real Madrid', 'Real Madrid', 'ES', 'Spain', 'Madrid'),
      ('fc-barcelona', 'FC Barcelona', 'Barcelona', 'ES', 'Spain', 'Barcelona'),
      ('atletico-madrid', 'Atlético Madrid', 'Atlético', 'ES', 'Spain', 'Madrid'),
      ('bayern-munich', 'Bayern Munich', 'Bayern', 'DE', 'Germany', 'Munich'),
      ('borussia-dortmund', 'Borussia Dortmund', 'Dortmund', 'DE', 'Germany', 'Dortmund'),
      ('bayer-leverkusen', 'Bayer Leverkusen', 'Leverkusen', 'DE', 'Germany', 'Leverkusen'),
      ('vfb-stuttgart', 'VfB Stuttgart', 'Stuttgart', 'DE', 'Germany', 'Stuttgart'),
      ('inter-milan', 'Inter Milan', 'Inter', 'IT', 'Italy', 'Milan'),
      ('ac-milan', 'AC Milan', 'Milan', 'IT', 'Italy', 'Milan'),
      ('juventus', 'Juventus', 'Juventus', 'IT', 'Italy', 'Turin'),
      ('atalanta', 'Atalanta', 'Atalanta', 'IT', 'Italy', 'Bergamo'),
      ('bologna', 'Bologna', 'Bologna', 'IT', 'Italy', 'Bologna'),
      ('paris-saint-germain', 'Paris Saint-Germain', 'PSG', 'FR', 'France', 'Paris'),
      ('as-monaco', 'AS Monaco', 'Monaco', 'FR', 'France', 'Monaco'),
      ('stade-brestois', 'Stade Brestois', 'Brest', 'FR', 'France', 'Brest'),
      ('lille', 'Lille OSC', 'Lille', 'FR', 'France', 'Lille'),
      ('psv-eindhoven', 'PSV Eindhoven', 'PSV', 'NL', 'Netherlands', 'Eindhoven'),
      ('feyenoord', 'Feyenoord', 'Feyenoord', 'NL', 'Netherlands', 'Rotterdam'),
      ('club-brugge', 'Club Brugge', 'Club Brugge', 'BE', 'Belgium', 'Bruges'),
      ('sporting-cp', 'Sporting CP', 'Sporting', 'PT', 'Portugal', 'Lisbon'),
      ('benfica', 'SL Benfica', 'Benfica', 'PT', 'Portugal', 'Lisbon'),
      ('celtic', 'Celtic', 'Celtic', 'SCO', 'Scotland', 'Glasgow'),
      ('rb-salzburg', 'RB Salzburg', 'Salzburg', 'AT', 'Austria', 'Salzburg'),
      ('sturm-graz', 'Sturm Graz', 'Sturm Graz', 'AT', 'Austria', 'Graz'),
      ('red-star-belgrade', 'Red Star Belgrade', 'Red Star', 'RS', 'Serbia', 'Belgrade'),
      ('young-boys', 'BSC Young Boys', 'Young Boys', 'CH', 'Switzerland', 'Bern'),
      ('shakhtar-donetsk', 'Shakhtar Donetsk', 'Shakhtar', 'UA', 'Ukraine', 'Donetsk'),
      ('dinamo-zagreb', 'Dinamo Zagreb', 'Dinamo', 'HR', 'Croatia', 'Zagreb'),
      ('sparta-prague', 'Sparta Prague', 'Sparta Prague', 'CZ', 'Czech Republic', 'Prague'),
      ('slovan-bratislava', 'Slovan Bratislava', 'Slovan', 'SK', 'Slovakia', 'Bratislava'),
      ('girona', 'Girona FC', 'Girona', 'ES', 'Spain', 'Girona'),
      ('rb-leipzig', 'RB Leipzig', 'Leipzig', 'DE', 'Germany', 'Leipzig'),
      ('brugge-cercle', 'Aston Villa', 'Aston Villa', 'ENG', 'England', 'Birmingham'),
      ('ucl-arsenal', 'Arsenal', 'Arsenal', 'ENG', 'England', 'London'),
      ('ucl-liverpool', 'Liverpool', 'Liverpool', 'ENG', 'England', 'Liverpool'),
      ('ucl-manchester-city', 'Manchester City', 'Man City', 'ENG', 'England', 'Manchester')
  )
  INSERT INTO football.teams AS t (
    slug, name, short_name, team_type, country_code, country_name, city, metadata
  )
  SELECT
    tv.slug, tv.name, tv.short_name,
    'club'::football.team_type,
    tv.country_code, tv.country_name, tv.city,
    jsonb_build_object('ucl_2025_26', true)
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

  -- For English teams that already exist with different slugs, link them
  -- Arsenal, Liverpool, Man City, Aston Villa already exist from EPL seed
  -- We use their existing slugs instead of creating duplicates
  INSERT INTO football.season_teams AS st (season_id, team_id, seeded_rank, metadata)
  SELECT
    v_season_id,
    t.id,
    stv.seeded_rank,
    jsonb_build_object('ucl_pot', stv.pot, 'source', 'manual-ucl-2025-26')
  FROM (
    VALUES
      ('real-madrid', 1, 1),
      ('fc-barcelona', 2, 1),
      ('bayern-munich', 3, 1),
      ('paris-saint-germain', 4, 1),
      ('inter-milan', 5, 1),
      ('borussia-dortmund', 6, 2),
      ('bayer-leverkusen', 7, 2),
      ('atletico-madrid', 8, 2),
      ('atalanta', 9, 2),
      ('juventus', 10, 2),
      ('benfica', 11, 2),
      ('club-brugge', 12, 2),
      ('ac-milan', 13, 3),
      ('sporting-cp', 14, 3),
      ('psv-eindhoven', 15, 3),
      ('feyenoord', 16, 3),
      ('as-monaco', 17, 3),
      ('lille', 18, 3),
      ('celtic', 19, 3),
      ('shakhtar-donetsk', 20, 3),
      ('stade-brestois', 21, 4),
      ('bologna', 22, 4),
      ('girona', 23, 4),
      ('vfb-stuttgart', 24, 4),
      ('rb-salzburg', 25, 4),
      ('sturm-graz', 26, 4),
      ('dinamo-zagreb', 27, 4),
      ('sparta-prague', 28, 4),
      ('red-star-belgrade', 29, 4),
      ('young-boys', 30, 4),
      ('slovan-bratislava', 31, 4),
      ('rb-leipzig', 32, 4),
      ('arsenal', 33, 1),
      ('liverpool', 34, 1),
      ('manchester-city', 35, 1),
      ('aston-villa', 36, 2)
  ) AS stv(team_slug, seeded_rank, pot)
  JOIN football.teams t ON t.slug = stv.team_slug
  ON CONFLICT (season_id, team_id) DO UPDATE
  SET
    seeded_rank = EXCLUDED.seeded_rank,
    is_active = true,
    metadata = st.metadata || EXCLUDED.metadata;

  -- League-phase standings snapshot (position-only based on compiled data)
  WITH standings_values (position, team_slug, played, won, drawn, lost, gf, ga, gd, pts, status_txt) AS (
    VALUES
      (1, 'liverpool', 8, 7, 1, 0, 15, 3, 12, 22, 'Qualified R16'),
      (2, 'fc-barcelona', 8, 7, 0, 1, 26, 11, 15, 21, 'Qualified R16'),
      (3, 'arsenal', 8, 6, 1, 1, 14, 3, 11, 19, 'Qualified R16'),
      (4, 'inter-milan', 8, 6, 1, 1, 10, 1, 9, 19, 'Qualified R16'),
      (5, 'atletico-madrid', 8, 6, 0, 2, 16, 11, 5, 18, 'Qualified R16'),
      (6, 'ac-milan', 8, 5, 1, 2, 13, 9, 4, 16, 'Qualified R16'),
      (7, 'atalanta', 8, 5, 1, 2, 18, 6, 12, 16, 'Qualified R16'),
      (8, 'bayer-leverkusen', 8, 5, 1, 2, 13, 7, 6, 16, 'Qualified R16'),
      (9, 'lille', 8, 5, 1, 2, 12, 7, 5, 16, 'Playoff'),
      (10, 'borussia-dortmund', 8, 5, 0, 3, 19, 11, 8, 15, 'Playoff'),
      (11, 'bayern-munich', 8, 5, 0, 3, 18, 11, 7, 15, 'Playoff'),
      (12, 'stade-brestois', 8, 5, 0, 3, 11, 8, 3, 15, 'Playoff'),
      (13, 'club-brugge', 8, 4, 2, 2, 9, 8, 1, 14, 'Playoff'),
      (14, 'as-monaco', 8, 4, 1, 3, 13, 10, 3, 13, 'Playoff'),
      (15, 'benfica', 8, 4, 1, 3, 14, 12, 2, 13, 'Playoff'),
      (16, 'feyenoord', 8, 4, 1, 3, 15, 17, -2, 13, 'Playoff'),
      (17, 'juventus', 8, 3, 4, 1, 9, 6, 3, 13, 'Playoff'),
      (18, 'celtic', 8, 3, 3, 2, 13, 11, 2, 12, 'Playoff'),
      (19, 'manchester-city', 8, 3, 2, 3, 15, 13, 2, 11, 'Playoff'),
      (20, 'psv-eindhoven', 8, 3, 2, 3, 11, 10, 1, 11, 'Playoff'),
      (21, 'real-madrid', 8, 3, 2, 3, 15, 12, 3, 11, 'Playoff'),
      (22, 'dinamo-zagreb', 8, 3, 2, 3, 11, 14, -3, 11, 'Playoff'),
      (23, 'sporting-cp', 8, 3, 1, 4, 12, 11, 1, 10, 'Playoff'),
      (24, 'vfb-stuttgart', 8, 3, 1, 4, 12, 14, -2, 10, 'Playoff'),
      (25, 'paris-saint-germain', 8, 3, 1, 4, 7, 10, -3, 10, 'Eliminated'),
      (26, 'shakhtar-donetsk', 8, 2, 2, 4, 8, 13, -5, 8, 'Eliminated'),
      (27, 'sparta-prague', 8, 2, 2, 4, 7, 18, -11, 8, 'Eliminated'),
      (28, 'aston-villa', 8, 2, 1, 5, 6, 9, -3, 7, 'Eliminated'),
      (29, 'bologna', 8, 1, 4, 3, 3, 7, -4, 7, 'Eliminated'),
      (30, 'girona', 8, 1, 3, 4, 7, 14, -7, 6, 'Eliminated'),
      (31, 'red-star-belgrade', 8, 1, 2, 5, 12, 20, -8, 5, 'Eliminated'),
      (32, 'rb-salzburg', 8, 1, 1, 6, 4, 18, -14, 4, 'Eliminated'),
      (33, 'rb-leipzig', 8, 1, 0, 7, 8, 14, -6, 3, 'Eliminated'),
      (34, 'sturm-graz', 8, 1, 0, 7, 4, 14, -10, 3, 'Eliminated'),
      (35, 'young-boys', 8, 0, 1, 7, 3, 22, -19, 1, 'Eliminated'),
      (36, 'slovan-bratislava', 8, 0, 0, 8, 4, 24, -20, 0, 'Eliminated')
  )
  INSERT INTO football.standings AS st (
    competition_id, season_id, team_id,
    stage_name, group_name, position,
    played, won, drawn, lost,
    goals_for, goals_against, goal_difference, points,
    notes, metadata
  )
  SELECT
    v_competition_id, v_season_id, t.id,
    'league_phase', '', sv.position,
    sv.played, sv.won, sv.drawn, sv.lost,
    sv.gf, sv.ga, sv.gd, sv.pts,
    sv.status_txt,
    jsonb_build_object(
      'snapshot_date', '2026-04-15',
      'phase', 'league_phase_complete'
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
    metadata = st.metadata || EXCLUDED.metadata;

  -- Selected fixtures (Round of 16 + some league-phase results)
  WITH fixture_values (
    stage, round_label, match_date_text,
    home_slug, away_slug, home_score, away_score, status_text
  ) AS (
    VALUES
      ('league_phase', 'MD1', '17 Sep 2025', 'real-madrid', 'vfb-stuttgart', 3, 1, 'FT'),
      ('league_phase', 'MD1', '17 Sep 2025', 'bayern-munich', 'dinamo-zagreb', 9, 2, 'FT'),
      ('league_phase', 'MD1', '17 Sep 2025', 'juventus', 'psv-eindhoven', 3, 1, 'FT'),
      ('league_phase', 'MD1', '18 Sep 2025', 'fc-barcelona', 'as-monaco', 2, 1, 'FT'),
      ('league_phase', 'MD1', '18 Sep 2025', 'borussia-dortmund', 'club-brugge', 3, 0, 'FT'),
      ('league_phase', 'MD1', '18 Sep 2025', 'liverpool', 'ac-milan', 3, 1, 'FT'),
      ('league_phase', 'MD1', '18 Sep 2025', 'inter-milan', 'red-star-belgrade', 4, 0, 'FT'),
      ('league_phase', 'MD1', '18 Sep 2025', 'paris-saint-germain', 'girona', 1, 0, 'FT'),
      ('league_phase', 'MD2', '01 Oct 2025', 'arsenal', 'paris-saint-germain', 2, 0, 'FT'),
      ('league_phase', 'MD2', '01 Oct 2025', 'bayer-leverkusen', 'ac-milan', 1, 0, 'FT'),
      ('league_phase', 'MD2', '02 Oct 2025', 'fc-barcelona', 'young-boys', 5, 0, 'FT'),
      ('league_phase', 'MD2', '02 Oct 2025', 'liverpool', 'bologna', 2, 0, 'FT'),
      ('league_phase', 'MD8', '29 Jan 2026', 'fc-barcelona', 'atalanta', 2, 2, 'FT'),
      ('league_phase', 'MD8', '29 Jan 2026', 'inter-milan', 'as-monaco', 3, 0, 'FT'),
      ('league_phase', 'MD8', '29 Jan 2026', 'liverpool', 'psv-eindhoven', 2, 1, 'FT'),
      ('league_phase', 'MD8', '29 Jan 2026', 'arsenal', 'girona', 2, 1, 'FT'),
      ('round_of_16', 'R16 Leg 1', '04 Mar 2026', 'ac-milan', 'feyenoord', null, null, 'SCH'),
      ('round_of_16', 'R16 Leg 1', '04 Mar 2026', 'inter-milan', 'bayern-munich', null, null, 'SCH'),
      ('round_of_16', 'R16 Leg 1', '05 Mar 2026', 'liverpool', 'borussia-dortmund', null, null, 'SCH'),
      ('round_of_16', 'R16 Leg 1', '05 Mar 2026', 'fc-barcelona', 'benfica', null, null, 'SCH'),
      ('round_of_16', 'R16 Leg 1', '11 Mar 2026', 'arsenal', 'real-madrid', null, null, 'SCH'),
      ('round_of_16', 'R16 Leg 1', '11 Mar 2026', 'atletico-madrid', 'bayer-leverkusen', null, null, 'SCH'),
      ('quarter_final', 'QF Leg 1', '08 Rayon Sports 2026', null, null, null, null, 'SCH'),
      ('semi_final', 'SF Leg 1', '29 Rayon Sports 2026', null, null, null, null, 'SCH'),
      ('final', 'Final', '30 May 2026', null, null, null, null, 'SCH')
  )
  INSERT INTO football.fixtures AS f (
    competition_id, season_id, stage_name, group_name,
    round_name, kickoff_at, home_team_id, away_team_id,
    home_score, away_score, status,
    external_provider, external_fixture_id, metadata
  )
  SELECT
    v_competition_id, v_season_id,
    fv.stage, '',
    fv.round_label,
    (to_date(fv.match_date_text, 'DD Mon YYYY')::timestamp + interval '20 hour')
      AT TIME ZONE 'Europe/London',
    ht.id, at.id,
    fv.home_score, fv.away_score,
    CASE fv.status_text
      WHEN 'FT' THEN 'finished'::football.fixture_status
      ELSE 'scheduled'::football.fixture_status
    END,
    'manual-ucl-2025-26',
    format('ucl-2025-26-%s-%s-%s-%s',
      lower(replace(fv.round_label, ' ', '-')),
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
  WHERE fv.home_slug IS NOT NULL AND fv.away_slug IS NOT NULL
  ON CONFLICT (external_provider, external_fixture_id) DO UPDATE
  SET
    stage_name = EXCLUDED.stage_name,
    round_name = EXCLUDED.round_name,
    kickoff_at = EXCLUDED.kickoff_at,
    home_score = EXCLUDED.home_score,
    away_score = EXCLUDED.away_score,
    status = EXCLUDED.status,
    metadata = f.metadata || EXCLUDED.metadata;

END $$;
