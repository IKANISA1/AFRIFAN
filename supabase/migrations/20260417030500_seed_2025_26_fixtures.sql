-- ============================================================================
-- Seed 2025/26 Season Fixtures (from public sources via web research)
-- ============================================================================
-- This migration creates upcoming/scheduled fixtures for all tracked leagues
-- using data from official league websites and sports aggregators.
-- ============================================================================

-- Helper: upsert team by name, return id
CREATE OR REPLACE FUNCTION football._seed_team(
  p_name text,
  p_short text,
  p_country text,
  p_api_id int DEFAULT NULL,
  p_type text DEFAULT 'club'
) RETURNS uuid AS $$
DECLARE
  v_id uuid;
  v_slug text;
  v_crest text;
BEGIN
  v_slug := lower(regexp_replace(p_name, '[^a-zA-Z0-9]+', '-', 'g'));
  v_slug := regexp_replace(v_slug, '^-+|-+$', '', 'g');
  v_crest := CASE WHEN p_api_id IS NOT NULL
    THEN 'https://media.api-sports.io/football/teams/' || p_api_id || '.png'
    ELSE NULL END;

  SELECT id
  INTO v_id
  FROM football.teams
  WHERE (
      p_api_id IS NOT NULL
      AND external_provider = 'api-football'
      AND external_team_id = p_api_id::text
    )
    OR slug = v_slug
    OR lower(name) = lower(p_name)
  ORDER BY updated_at DESC NULLS LAST, created_at DESC NULLS LAST
  LIMIT 1;

  IF v_id IS NOT NULL THEN
    UPDATE football.teams
    SET slug = v_slug,
        name = p_name,
        short_name = p_short,
        team_type = p_type::football.team_type,
        country_name = p_country,
        crest_url = COALESCE(v_crest, crest_url),
        external_provider = CASE WHEN p_api_id IS NOT NULL THEN 'api-football' ELSE external_provider END,
        external_team_id = CASE
          WHEN p_api_id IS NOT NULL THEN p_api_id::text
          ELSE COALESCE(external_team_id, 'manual-' || v_slug)
        END,
        is_active = true
    WHERE id = v_id;
  ELSE
    INSERT INTO football.teams (slug, name, short_name, team_type, country_name, crest_url,
      external_provider, external_team_id, is_active)
    VALUES (v_slug, p_name, p_short, p_type::football.team_type, p_country, v_crest,
      CASE WHEN p_api_id IS NOT NULL THEN 'api-football' ELSE 'manual' END,
      COALESCE(p_api_id::text, 'manual-' || v_slug), true)
    RETURNING id INTO v_id;
  END IF;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Helper: create season for competition
CREATE OR REPLACE FUNCTION football._seed_season(
  p_comp_slug text,
  p_label text,
  p_year_start int,
  p_year_end int
) RETURNS uuid AS $$
DECLARE
  v_id uuid;
  v_comp_id uuid;
BEGIN
  SELECT id INTO v_comp_id FROM football.competitions WHERE slug = p_comp_slug;
  IF v_comp_id IS NULL THEN RAISE EXCEPTION 'Competition % not found', p_comp_slug; END IF;

  INSERT INTO football.seasons (competition_id, slug, label, year_start, year_end, status, is_active)
  VALUES (
    v_comp_id,
    p_comp_slug || '-' || p_label,
    p_label,
    p_year_start,
    p_year_end,
    'active'::football.season_status,
    true
  )
  ON CONFLICT (competition_id, label) DO UPDATE SET is_active = true
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Helper: create fixture
CREATE OR REPLACE FUNCTION football._seed_fixture(
  p_comp_slug text,
  p_season_label text,
  p_home text,
  p_away text,
  p_kickoff timestamptz,
  p_round text DEFAULT NULL,
  p_stage text DEFAULT 'regular_season'
) RETURNS uuid AS $$
DECLARE
  v_id uuid;
  v_comp_id uuid;
  v_season_id uuid;
  v_home_id uuid;
  v_away_id uuid;
BEGIN
  SELECT id INTO v_comp_id FROM football.competitions WHERE slug = p_comp_slug;
  SELECT id INTO v_season_id FROM football.seasons
    WHERE competition_id = v_comp_id AND label = p_season_label;
  SELECT id INTO v_home_id FROM football.teams
    WHERE lower(name) = lower(p_home) LIMIT 1;
  SELECT id INTO v_away_id FROM football.teams
    WHERE lower(name) = lower(p_away) LIMIT 1;

  IF v_home_id IS NULL THEN RAISE EXCEPTION 'Home team % not found', p_home; END IF;
  IF v_away_id IS NULL THEN RAISE EXCEPTION 'Away team % not found', p_away; END IF;

  INSERT INTO football.fixtures (
    competition_id, season_id, home_team_id, away_team_id,
    kickoff_at, round_name, stage_name, status,
    external_provider, external_fixture_id
  ) VALUES (
    v_comp_id, v_season_id, v_home_id, v_away_id,
    p_kickoff, p_round, p_stage, 'scheduled'::football.fixture_status,
    'manual', 'manual-' || gen_random_uuid()::text
  )
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- ════════════════════════════════════════════════════════════════════════════
-- 1. CREATE 2025/26 SEASONS
-- ════════════════════════════════════════════════════════════════════════════

SELECT football._seed_season('uefa-champions-league', '2025/26', 2025, 2026);
SELECT football._seed_season('premier-league-england', '2025/26', 2025, 2026);
SELECT football._seed_season('la-liga-spain', '2025/26', 2025, 2026);
SELECT football._seed_season('national-soccer-league-rwanda', '2025/26', 2025, 2026);
SELECT football._seed_season('ligue-1-congo-dr', '2025/26', 2025, 2026);
SELECT football._seed_season('super-league-zambia', '2025/26', 2025, 2026);
SELECT football._seed_season('fkf-premier-league-kenya', '2025/26', 2025, 2026);

-- ════════════════════════════════════════════════════════════════════════════
-- 2. SEED TEAMS (with API-Football IDs for crest URLs)
-- ════════════════════════════════════════════════════════════════════════════

-- UCL Semi-final teams
SELECT football._seed_team('Paris Saint-Germain', 'PSG', 'France', 85);
SELECT football._seed_team('Bayern Munich', 'BAY', 'Germany', 157);
SELECT football._seed_team('Atletico Madrid', 'ATM', 'Spain', 530);
SELECT football._seed_team('Arsenal', 'ARS', 'England', 42);

-- EPL teams (Matchday 34-36)
SELECT football._seed_team('Liverpool', 'LIV', 'England', 40);
SELECT football._seed_team('Crystal Palace', 'CRY', 'England', 52);
SELECT football._seed_team('West Ham United', 'WHU', 'England', 48);
SELECT football._seed_team('Everton', 'EVE', 'England', 45);
SELECT football._seed_team('Wolverhampton Wanderers', 'WOL', 'England', 39);
SELECT football._seed_team('Tottenham Hotspur', 'TOT', 'England', 47);
SELECT football._seed_team('Newcastle United', 'NEW', 'England', 34);
SELECT football._seed_team('Manchester United', 'MUN', 'England', 33);
SELECT football._seed_team('Brentford', 'BRE', 'England', 55);
SELECT football._seed_team('Fulham', 'FUL', 'England', 36);
SELECT football._seed_team('Aston Villa', 'AVL', 'England', 66);
SELECT football._seed_team('Sunderland', 'SUN', 'England', 71);
SELECT football._seed_team('Nottingham Forest', 'NFO', 'England', 65);
SELECT football._seed_team('Manchester City', 'MCI', 'England', 50);
SELECT football._seed_team('Chelsea', 'CHE', 'England', 49);
SELECT football._seed_team('Brighton', 'BHA', 'England', 51);
SELECT football._seed_team('AFC Bournemouth', 'BOU', 'England', 35);
SELECT football._seed_team('Leeds United', 'LEE', 'England', 63);
SELECT football._seed_team('Burnley', 'BUR', 'England', 44);

-- La Liga teams (Matchday 33-34)
SELECT football._seed_team('FC Barcelona', 'BAR', 'Spain', 529);
SELECT football._seed_team('Real Madrid', 'RMA', 'Spain', 541);
SELECT football._seed_team('Real Betis', 'BET', 'Spain', 543);
SELECT football._seed_team('Celta de Vigo', 'CEL', 'Spain', 538);
SELECT football._seed_team('Alaves', 'ALA', 'Spain', 542);
SELECT football._seed_team('RCD Mallorca', 'MAL', 'Spain', 798);
SELECT football._seed_team('Getafe', 'GET', 'Spain', 546);
SELECT football._seed_team('Valencia', 'VAL', 'Spain', 532);
SELECT football._seed_team('Girona FC', 'GIR', 'Spain', 547);
SELECT football._seed_team('Athletic Club', 'ATH', 'Spain', 531);
SELECT football._seed_team('Rayo Vallecano', 'RAY', 'Spain', 728);
SELECT football._seed_team('Real Sociedad', 'RSO', 'Spain', 548);
SELECT football._seed_team('Osasuna', 'OSA', 'Spain', 727);
SELECT football._seed_team('Sevilla', 'SEV', 'Spain', 536);
SELECT football._seed_team('Villarreal', 'VIL', 'Spain', 533);
SELECT football._seed_team('Espanyol', 'ESP', 'Spain', 540);
SELECT football._seed_team('Real Oviedo', 'OVI', 'Spain', 797);
SELECT football._seed_team('Elche', 'ELC', 'Spain', 797);
SELECT football._seed_team('Levante', 'LEV', 'Spain', 539);

-- Rwanda NSL teams
SELECT football._seed_team('Rayon Sports', 'RAY', 'Rwanda', 12657);
SELECT football._seed_team('APR FC', 'APR', 'Rwanda', 12655);
SELECT football._seed_team('AS Kigali', 'ASK', 'Rwanda', 12659);
SELECT football._seed_team('Musanze FC', 'MUS', 'Rwanda', 12806);
SELECT football._seed_team('Police FC', 'POL', 'Rwanda', 12808);
SELECT football._seed_team('Marines FC', 'MAR', 'Rwanda', NULL);
SELECT football._seed_team('Gasogi United', 'GAS', 'Rwanda', NULL);
SELECT football._seed_team('Gorilla FC', 'GOR', 'Rwanda', NULL);
SELECT football._seed_team('Amagaju', 'AMA', 'Rwanda', NULL);
SELECT football._seed_team('Mukura VS', 'MUK', 'Rwanda', 12658);
SELECT football._seed_team('Etincelles FC', 'ETI', 'Rwanda', 12805);
SELECT football._seed_team('Gicumbi FC', 'GIC', 'Rwanda', NULL);
SELECT football._seed_team('Bugesera FC', 'BUG', 'Rwanda', NULL);
SELECT football._seed_team('Kiyovu Sports', 'KIY', 'Rwanda', 12656);

-- Linafoot (DRC) teams — playoff round
SELECT football._seed_team('TP Mazembe', 'MAZ', 'Congo-DR', 4941);
SELECT football._seed_team('AS Vita Club', 'VIT', 'Congo-DR', 4942);
SELECT football._seed_team('Saint Eloi Lupopo', 'LUP', 'Congo-DR', NULL);
SELECT football._seed_team('CS Don Bosco', 'DON', 'Congo-DR', NULL);
SELECT football._seed_team('Les Aigles du Congo', 'AIG', 'Congo-DR', NULL);
SELECT football._seed_team('Celeste FC', 'CEL', 'Congo-DR', NULL);
SELECT football._seed_team('AS Simba', 'SIM', 'Congo-DR', NULL);
SELECT football._seed_team('AS Maniema Union', 'MAN', 'Congo-DR', NULL);

-- Zambia Super League teams
SELECT football._seed_team('ZESCO United', 'ZES', 'Zambia', 5903);
SELECT football._seed_team('Power Dynamos', 'POW', 'Zambia', 5905);
SELECT football._seed_team('Nkana FC', 'NKA', 'Zambia', 5904);
SELECT football._seed_team('Green Buffaloes', 'GBF', 'Zambia', NULL);
SELECT football._seed_team('Green Eagles', 'GEA', 'Zambia', NULL);
SELECT football._seed_team('NAPSA Stars', 'NAP', 'Zambia', NULL);
SELECT football._seed_team('Kabwe Warriors', 'KAB', 'Zambia', NULL);
SELECT football._seed_team('Nkwazi FC', 'NKW', 'Zambia', NULL);
SELECT football._seed_team('Mufulira Wanderers', 'MUF', 'Zambia', NULL);
SELECT football._seed_team('Nchanga Rangers', 'NCH', 'Zambia', NULL);
SELECT football._seed_team('Mutondo Stars', 'MUT', 'Zambia', NULL);
SELECT football._seed_team('Mines United', 'MIN', 'Zambia', NULL);

-- Kenya FKF Premier League teams
SELECT football._seed_team('Gor Mahia', 'GOR', 'Kenya', 14052);
SELECT football._seed_team('AFC Leopards', 'LEO', 'Kenya', 14053);
SELECT football._seed_team('Tusker FC', 'TUS', 'Kenya', NULL);
SELECT football._seed_team('Bandari FC', 'BAN', 'Kenya', NULL);
SELECT football._seed_team('KCB FC', 'KCB', 'Kenya', NULL);
SELECT football._seed_team('Kariobangi Sharks', 'KAR', 'Kenya', NULL);
SELECT football._seed_team('Ulinzi Stars', 'ULI', 'Kenya', NULL);
SELECT football._seed_team('Posta Rangers', 'POS', 'Kenya', NULL);

-- ════════════════════════════════════════════════════════════════════════════
-- 3. SEED FIXTURES (upcoming scheduled matches)
-- ════════════════════════════════════════════════════════════════════════════

-- ─── UCL Semi-Finals ──────────────────────────────────────────────────
SELECT football._seed_fixture('uefa-champions-league', '2025/26',
  'Paris Saint-Germain', 'Bayern Munich', '2026-04-28 19:00:00+00', 'Semi-Final 1st Leg', 'knockout');
SELECT football._seed_fixture('uefa-champions-league', '2025/26',
  'Atletico Madrid', 'Arsenal', '2026-04-29 19:00:00+00', 'Semi-Final 1st Leg', 'knockout');
SELECT football._seed_fixture('uefa-champions-league', '2025/26',
  'Arsenal', 'Atletico Madrid', '2026-05-05 19:00:00+00', 'Semi-Final 2nd Leg', 'knockout');
SELECT football._seed_fixture('uefa-champions-league', '2025/26',
  'Bayern Munich', 'Paris Saint-Germain', '2026-05-06 19:00:00+00', 'Semi-Final 2nd Leg', 'knockout');

-- ─── EPL Matchweek 34 (Apr 24-27) ────────────────────────────────────
SELECT football._seed_fixture('premier-league-england', '2025/26',
  'Sunderland', 'Nottingham Forest', '2026-04-24 19:00:00+00', 'Matchweek 34');
SELECT football._seed_fixture('premier-league-england', '2025/26',
  'Fulham', 'Aston Villa', '2026-04-25 14:00:00+00', 'Matchweek 34');
SELECT football._seed_fixture('premier-league-england', '2025/26',
  'Liverpool', 'Crystal Palace', '2026-04-25 14:00:00+00', 'Matchweek 34');
SELECT football._seed_fixture('premier-league-england', '2025/26',
  'West Ham United', 'Everton', '2026-04-25 14:00:00+00', 'Matchweek 34');
SELECT football._seed_fixture('premier-league-england', '2025/26',
  'Wolverhampton Wanderers', 'Tottenham Hotspur', '2026-04-25 16:30:00+00', 'Matchweek 34');
SELECT football._seed_fixture('premier-league-england', '2025/26',
  'Arsenal', 'Newcastle United', '2026-04-25 19:00:00+00', 'Matchweek 34');
SELECT football._seed_fixture('premier-league-england', '2025/26',
  'Brighton', 'Chelsea', '2026-04-26 14:00:00+00', 'Matchweek 34');
SELECT football._seed_fixture('premier-league-england', '2025/26',
  'Manchester United', 'Brentford', '2026-04-27 19:00:00+00', 'Matchweek 34');

-- ─── EPL Matchweek 35 (May 1-2) ──────────────────────────────────────
SELECT football._seed_fixture('premier-league-england', '2025/26',
  'Leeds United', 'Burnley', '2026-05-01 19:00:00+00', 'Matchweek 35');
SELECT football._seed_fixture('premier-league-england', '2025/26',
  'Arsenal', 'Fulham', '2026-05-02 14:00:00+00', 'Matchweek 35');
SELECT football._seed_fixture('premier-league-england', '2025/26',
  'Aston Villa', 'Tottenham Hotspur', '2026-05-02 14:00:00+00', 'Matchweek 35');
SELECT football._seed_fixture('premier-league-england', '2025/26',
  'Brentford', 'West Ham United', '2026-05-02 14:00:00+00', 'Matchweek 35');
SELECT football._seed_fixture('premier-league-england', '2025/26',
  'Chelsea', 'Nottingham Forest', '2026-05-02 14:00:00+00', 'Matchweek 35');
SELECT football._seed_fixture('premier-league-england', '2025/26',
  'Everton', 'Manchester City', '2026-05-02 16:30:00+00', 'Matchweek 35');
SELECT football._seed_fixture('premier-league-england', '2025/26',
  'AFC Bournemouth', 'Crystal Palace', '2026-05-02 14:00:00+00', 'Matchweek 35');

-- ─── La Liga Matchday 33 (Apr 22-27) ─────────────────────────────────
SELECT football._seed_fixture('la-liga-spain', '2025/26',
  'FC Barcelona', 'Celta de Vigo', '2026-04-22 19:00:00+00', 'Matchday 33');
SELECT football._seed_fixture('la-liga-spain', '2025/26',
  'Real Betis', 'Real Madrid', '2026-04-24 19:00:00+00', 'Matchday 33');
SELECT football._seed_fixture('la-liga-spain', '2025/26',
  'Getafe', 'FC Barcelona', '2026-04-25 14:00:00+00', 'Matchday 33');
SELECT football._seed_fixture('la-liga-spain', '2025/26',
  'Valencia', 'Girona FC', '2026-04-25 16:15:00+00', 'Matchday 33');
SELECT football._seed_fixture('la-liga-spain', '2025/26',
  'Atletico Madrid', 'Athletic Club', '2026-04-25 19:30:00+00', 'Matchday 33');
SELECT football._seed_fixture('la-liga-spain', '2025/26',
  'Alaves', 'RCD Mallorca', '2026-04-26 14:00:00+00', 'Matchday 33');
SELECT football._seed_fixture('la-liga-spain', '2025/26',
  'Rayo Vallecano', 'Real Sociedad', '2026-04-26 16:15:00+00', 'Matchday 33');
SELECT football._seed_fixture('la-liga-spain', '2025/26',
  'Osasuna', 'Sevilla', '2026-04-26 19:30:00+00', 'Matchday 33');
SELECT football._seed_fixture('la-liga-spain', '2025/26',
  'Villarreal', 'Celta de Vigo', '2026-04-26 19:30:00+00', 'Matchday 33');

-- ─── La Liga Matchday 34 (May 2-3) ───────────────────────────────────
SELECT football._seed_fixture('la-liga-spain', '2025/26',
  'Osasuna', 'FC Barcelona', '2026-05-02 19:30:00+00', 'Matchday 34');
SELECT football._seed_fixture('la-liga-spain', '2025/26',
  'Valencia', 'Atletico Madrid', '2026-05-03 16:15:00+00', 'Matchday 34');
SELECT football._seed_fixture('la-liga-spain', '2025/26',
  'Espanyol', 'Real Madrid', '2026-05-03 19:30:00+00', 'Matchday 34');
SELECT football._seed_fixture('la-liga-spain', '2025/26',
  'Sevilla', 'Real Sociedad', '2026-05-03 19:30:00+00', 'Matchday 34');

-- ─── Rwanda NSL (Apr 17 – May 2) ─────────────────────────────────────
SELECT football._seed_fixture('national-soccer-league-rwanda', '2025/26',
  'Marines FC', 'AS Kigali', '2026-04-17 14:00:00+02', 'Matchday 20');
SELECT football._seed_fixture('national-soccer-league-rwanda', '2025/26',
  'Musanze FC', 'Amagaju', '2026-04-17 16:00:00+02', 'Matchday 20');
SELECT football._seed_fixture('national-soccer-league-rwanda', '2025/26',
  'Gasogi United', 'Gorilla FC', '2026-04-17 16:00:00+02', 'Matchday 20');
SELECT football._seed_fixture('national-soccer-league-rwanda', '2025/26',
  'Mukura VS', 'APR FC', '2026-04-25 14:00:00+02', 'Matchday 21');
SELECT football._seed_fixture('national-soccer-league-rwanda', '2025/26',
  'Police FC', 'Marines FC', '2026-04-25 16:00:00+02', 'Matchday 21');
SELECT football._seed_fixture('national-soccer-league-rwanda', '2025/26',
  'Kiyovu Sports', 'Musanze FC', '2026-04-25 16:00:00+02', 'Matchday 21');
SELECT football._seed_fixture('national-soccer-league-rwanda', '2025/26',
  'Bugesera FC', 'Gasogi United', '2026-04-25 14:00:00+02', 'Matchday 21');
SELECT football._seed_fixture('national-soccer-league-rwanda', '2025/26',
  'Etincelles FC', 'Amagaju', '2026-05-02 14:00:00+02', 'Matchday 22');
SELECT football._seed_fixture('national-soccer-league-rwanda', '2025/26',
  'Rayon Sports', 'APR FC', '2026-05-02 16:00:00+02', 'Matchday 22');
SELECT football._seed_fixture('national-soccer-league-rwanda', '2025/26',
  'AS Kigali', 'Mukura VS', '2026-05-02 14:00:00+02', 'Matchday 22');
SELECT football._seed_fixture('national-soccer-league-rwanda', '2025/26',
  'Gorilla FC', 'Police FC', '2026-05-02 16:00:00+02', 'Matchday 22');

-- ─── Linafoot Playoff Round (starting Apr 18) ────────────────────────
SELECT football._seed_fixture('ligue-1-congo-dr', '2025/26',
  'TP Mazembe', 'AS Vita Club', '2026-04-18 15:00:00+02', 'Playoff Round 1', 'playoff');
SELECT football._seed_fixture('ligue-1-congo-dr', '2025/26',
  'Saint Eloi Lupopo', 'Les Aigles du Congo', '2026-04-18 18:00:00+02', 'Playoff Round 1', 'playoff');
SELECT football._seed_fixture('ligue-1-congo-dr', '2025/26',
  'CS Don Bosco', 'Celeste FC', '2026-04-19 15:00:00+02', 'Playoff Round 1', 'playoff');
SELECT football._seed_fixture('ligue-1-congo-dr', '2025/26',
  'AS Simba', 'AS Maniema Union', '2026-04-19 18:00:00+02', 'Playoff Round 1', 'playoff');
SELECT football._seed_fixture('ligue-1-congo-dr', '2025/26',
  'AS Vita Club', 'Saint Eloi Lupopo', '2026-04-25 15:00:00+02', 'Playoff Round 2', 'playoff');
SELECT football._seed_fixture('ligue-1-congo-dr', '2025/26',
  'Les Aigles du Congo', 'TP Mazembe', '2026-04-25 18:00:00+02', 'Playoff Round 2', 'playoff');
SELECT football._seed_fixture('ligue-1-congo-dr', '2025/26',
  'Celeste FC', 'AS Simba', '2026-04-26 15:00:00+02', 'Playoff Round 2', 'playoff');
SELECT football._seed_fixture('ligue-1-congo-dr', '2025/26',
  'AS Maniema Union', 'CS Don Bosco', '2026-04-26 18:00:00+02', 'Playoff Round 2', 'playoff');

-- ─── Zambia Super League (Apr-May) ────────────────────────────────────
SELECT football._seed_fixture('super-league-zambia', '2025/26',
  'ZESCO United', 'Power Dynamos', '2026-04-19 15:00:00+02', 'Round 26');
SELECT football._seed_fixture('super-league-zambia', '2025/26',
  'Nkana FC', 'Green Buffaloes', '2026-04-19 15:00:00+02', 'Round 26');
SELECT football._seed_fixture('super-league-zambia', '2025/26',
  'Green Eagles', 'NAPSA Stars', '2026-04-19 15:00:00+02', 'Round 26');
SELECT football._seed_fixture('super-league-zambia', '2025/26',
  'Kabwe Warriors', 'Nkwazi FC', '2026-04-19 13:00:00+02', 'Round 26');
SELECT football._seed_fixture('super-league-zambia', '2025/26',
  'Mufulira Wanderers', 'Mutondo Stars', '2026-04-22 15:00:00+02', 'Round 27');
SELECT football._seed_fixture('super-league-zambia', '2025/26',
  'Power Dynamos', 'Nkana FC', '2026-04-22 15:00:00+02', 'Round 27');
SELECT football._seed_fixture('super-league-zambia', '2025/26',
  'NAPSA Stars', 'ZESCO United', '2026-04-26 15:00:00+02', 'Round 28');
SELECT football._seed_fixture('super-league-zambia', '2025/26',
  'Green Buffaloes', 'Kabwe Warriors', '2026-04-26 15:00:00+02', 'Round 28');

-- ─── Kenya FKF Premier League (Apr-May) ──────────────────────────────
SELECT football._seed_fixture('fkf-premier-league-kenya', '2025/26',
  'Gor Mahia', 'AFC Leopards', '2026-04-20 16:00:00+03', 'Round 22');
SELECT football._seed_fixture('fkf-premier-league-kenya', '2025/26',
  'Tusker FC', 'KCB FC', '2026-04-20 14:00:00+03', 'Round 22');
SELECT football._seed_fixture('fkf-premier-league-kenya', '2025/26',
  'Bandari FC', 'Kariobangi Sharks', '2026-04-20 14:00:00+03', 'Round 22');
SELECT football._seed_fixture('fkf-premier-league-kenya', '2025/26',
  'Ulinzi Stars', 'Posta Rangers', '2026-04-20 14:00:00+03', 'Round 22');
SELECT football._seed_fixture('fkf-premier-league-kenya', '2025/26',
  'AFC Leopards', 'Tusker FC', '2026-04-27 16:00:00+03', 'Round 23');
SELECT football._seed_fixture('fkf-premier-league-kenya', '2025/26',
  'KCB FC', 'Gor Mahia', '2026-04-27 14:00:00+03', 'Round 23');
SELECT football._seed_fixture('fkf-premier-league-kenya', '2025/26',
  'Kariobangi Sharks', 'Ulinzi Stars', '2026-05-04 14:00:00+03', 'Round 24');
SELECT football._seed_fixture('fkf-premier-league-kenya', '2025/26',
  'Posta Rangers', 'Bandari FC', '2026-05-04 14:00:00+03', 'Round 24');

-- ════════════════════════════════════════════════════════════════════════════
-- 4. VERIFY
-- ════════════════════════════════════════════════════════════════════════════

-- Show summary
SELECT c.name as league, count(f.id) as upcoming_fixtures
FROM football.fixtures f
JOIN football.competitions c ON c.id = f.competition_id
WHERE f.status = 'scheduled'
GROUP BY c.name
ORDER BY upcoming_fixtures DESC;

-- Cleanup helpers (keep them for future use)
-- DROP FUNCTION IF EXISTS football._seed_team;
-- DROP FUNCTION IF EXISTS football._seed_season;
-- DROP FUNCTION IF EXISTS football._seed_fixture;
