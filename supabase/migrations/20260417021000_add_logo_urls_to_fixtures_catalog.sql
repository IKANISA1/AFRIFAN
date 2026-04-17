-- ============================================================================
-- Add Logo URL Support to Fixture Catalog Views
-- ============================================================================
-- 1. Add logo_url column to football.competitions
-- 2. Rebuild football_fixtures_catalog with team crest and competition logo
-- 3. Rebuild prediction_supported_fixtures_catalog with logo columns
-- 4. Seed team crest URLs for known teams (API-Football CDN)
-- 5. Seed competition logo URLs
-- ============================================================================

-- 1. Add logo_url to competitions
ALTER TABLE football.competitions ADD COLUMN IF NOT EXISTS logo_url text;
COMMENT ON COLUMN football.competitions.logo_url IS 'API-Football CDN logo URL for the competition';

-- 2. Refresh fixtures catalog with logo columns without dropping dependent views
CREATE OR REPLACE VIEW public.football_fixtures_catalog AS
SELECT f.id,
   f.competition_id,
   c.slug AS competition_slug,
   c.name AS competition_name,
   f.season_id,
   s.slug AS season_slug,
   s.label AS season_label,
   f.stage_name,
   f.group_name,
   f.round_name,
   f.matchday,
   f.fixture_number,
   f.kickoff_at,
   f.venue_name,
   f.venue_city,
   f.venue_country,
   f.home_team_id,
   ht.slug AS home_team_slug,
   ht.name AS home_team_name,
   ht.short_name AS home_team_short_name,
   ht.crest_url AS home_team_logo_url,
   f.away_team_id,
   at.slug AS away_team_slug,
   at.name AS away_team_name,
   at.short_name AS away_team_short_name,
   at.crest_url AS away_team_logo_url,
   f.home_score,
   f.away_score,
   f.leg_number,
   f.status,
   COALESCE(
     c.logo_url,
     c.metadata ->> 'api_league_logo',
     c.metadata ->> 'storage_league_logo_url'
   ) AS competition_logo_url,
   f.metadata,
   f.created_at,
   f.updated_at,
   f.external_provider,
   f.external_fixture_id,
   COALESCE(ht.crest_url, f.metadata ->> 'home_team_logo') AS home_team_logo,
   COALESCE(at.crest_url, f.metadata ->> 'away_team_logo') AS away_team_logo,
   COALESCE(
     c.logo_url,
     c.metadata ->> 'api_league_logo',
     c.metadata ->> 'storage_league_logo_url'
   ) AS competition_logo,
   COALESCE((f.metadata ->> 'api_elapsed')::integer, 0) AS live_elapsed,
   (f.metadata ->> 'api_status_short') AS api_status_short
  FROM football.fixtures f
    JOIN football.competitions c ON c.id = f.competition_id
    JOIN football.seasons s ON s.id = f.season_id
    JOIN football.teams ht ON ht.id = f.home_team_id
    JOIN football.teams at ON at.id = f.away_team_id;

-- 3. Refresh prediction-supported fixtures catalog with logo columns
CREATE OR REPLACE VIEW public.prediction_supported_fixtures_catalog AS
SELECT f.id,
   f.competition_id,
   f.competition_slug,
   f.competition_name,
   f.season_id,
   f.season_slug,
   f.season_label,
   f.stage_name,
   f.group_name,
   f.round_name,
   f.matchday,
   f.fixture_number,
   f.kickoff_at,
   f.venue_name,
   f.venue_city,
   f.venue_country,
   f.home_team_id,
   f.home_team_slug,
   f.home_team_name,
   f.home_team_short_name,
   f.home_team_logo_url,
   f.away_team_id,
   f.away_team_slug,
   f.away_team_name,
   f.away_team_short_name,
   f.away_team_logo_url,
   f.home_score,
   f.away_score,
   f.leg_number,
   f.status,
   f.competition_logo_url,
   f.metadata,
   f.created_at,
   f.updated_at
  FROM football_fixtures_catalog f
    JOIN prediction_supported_competitions psc ON psc.competition_id = f.competition_id
  WHERE psc.is_active = true;

-- 4. Grants
GRANT SELECT ON public.football_fixtures_catalog TO anon, authenticated, service_role;
GRANT SELECT ON public.prediction_supported_fixtures_catalog TO anon, authenticated, service_role;

-- 5. Seed team crest URLs (API-Football CDN)
UPDATE football.teams SET crest_url = CASE short_name
  WHEN 'Arsenal'      THEN 'https://media.api-sports.io/football/teams/42.png'
  WHEN 'Real Madrid'  THEN 'https://media.api-sports.io/football/teams/541.png'
  WHEN 'Barcelona'    THEN 'https://media.api-sports.io/football/teams/529.png'
  WHEN 'Inter'        THEN 'https://media.api-sports.io/football/teams/505.png'
  WHEN 'Bayern'       THEN 'https://media.api-sports.io/football/teams/157.png'
  WHEN 'Liverpool'    THEN 'https://media.api-sports.io/football/teams/40.png'
  WHEN 'Dortmund'     THEN 'https://media.api-sports.io/football/teams/165.png'
  WHEN 'Milan'        THEN 'https://media.api-sports.io/football/teams/489.png'
  WHEN 'Atlético'    THEN 'https://media.api-sports.io/football/teams/530.png'
  WHEN 'Leverkusen'   THEN 'https://media.api-sports.io/football/teams/168.png'
  WHEN 'PSG'          THEN 'https://media.api-sports.io/football/teams/85.png'
  WHEN 'Man City'     THEN 'https://media.api-sports.io/football/teams/50.png'
  WHEN 'Chelsea'      THEN 'https://media.api-sports.io/football/teams/49.png'
  WHEN 'Benfica'      THEN 'https://media.api-sports.io/football/teams/211.png'
  WHEN 'Juventus'     THEN 'https://media.api-sports.io/football/teams/496.png'
  WHEN 'Feyenoord'    THEN 'https://media.api-sports.io/football/teams/215.png'
  WHEN 'Rayon Sports' THEN 'https://media.api-sports.io/football/teams/13299.png'
  WHEN 'APR'          THEN 'https://media.api-sports.io/football/teams/2178.png'
  WHEN 'AS Kigali'    THEN 'https://media.api-sports.io/football/teams/2183.png'
  WHEN 'Kiyovu'       THEN 'https://media.api-sports.io/football/teams/2179.png'
  WHEN 'Police FC'    THEN 'https://media.api-sports.io/football/teams/2181.png'
  WHEN 'Musanze'      THEN 'https://media.api-sports.io/football/teams/13295.png'
  WHEN 'Bugesera'     THEN 'https://media.api-sports.io/football/teams/13296.png'
  WHEN 'Mukura VS'    THEN 'https://media.api-sports.io/football/teams/2184.png'
  WHEN 'Etincelles'   THEN 'https://media.api-sports.io/football/teams/13297.png'
  WHEN 'Gorilla FC'   THEN 'https://media.api-sports.io/football/teams/13298.png'
  WHEN 'Marine FC'    THEN 'https://media.api-sports.io/football/teams/13300.png'
  WHEN 'Amagaju'      THEN 'https://media.api-sports.io/football/teams/13301.png'
  WHEN 'Gasogi'       THEN 'https://media.api-sports.io/football/teams/13302.png'
  WHEN 'Gicumbi'      THEN 'https://media.api-sports.io/football/teams/13303.png'
  WHEN 'AS Muhanga'   THEN 'https://media.api-sports.io/football/teams/13304.png'
  WHEN 'Al Merrikh'   THEN 'https://media.api-sports.io/football/teams/13305.png'
  WHEN 'Rutsiro'      THEN 'https://media.api-sports.io/football/teams/13306.png'
  WHEN 'Al-Hilal'     THEN 'https://media.api-sports.io/football/teams/13307.png'
  ELSE crest_url
END
WHERE crest_url IS NULL OR crest_url = '';

-- 6. Seed competition logos
UPDATE football.competitions SET logo_url = CASE slug
  WHEN 'rwanda-premier-league' THEN 'https://media.api-sports.io/football/leagues/269.png'
  WHEN 'champions-league'      THEN 'https://media.api-sports.io/football/leagues/2.png'
  WHEN 'premier-league'        THEN 'https://media.api-sports.io/football/leagues/39.png'
  WHEN 'la-liga'               THEN 'https://media.api-sports.io/football/leagues/140.png'
  WHEN 'serie-a'               THEN 'https://media.api-sports.io/football/leagues/135.png'
  WHEN 'bundesliga'            THEN 'https://media.api-sports.io/football/leagues/78.png'
  WHEN 'ligue-1'               THEN 'https://media.api-sports.io/football/leagues/61.png'
  WHEN 'linafoot'              THEN 'https://media.api-sports.io/football/leagues/274.png'
  WHEN 'world-cup-2026'        THEN 'https://media.api-sports.io/football/leagues/1.png'
  WHEN 'zambia-super-league'   THEN 'https://media.api-sports.io/football/leagues/271.png'
  ELSE logo_url
END
WHERE logo_url IS NULL OR logo_url = '';
