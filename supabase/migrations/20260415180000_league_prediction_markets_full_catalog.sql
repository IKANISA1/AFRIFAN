-- ============================================================================
-- Global & African Leagues — Full Prediction Markets Catalog
-- Adds all missing generic (non-WC-prefixed) league prediction markets for:
--   EPL, La Liga, Rwanda PL, Zambia SL, DRC Linafoot
-- Also adds league_availability column to control which leagues each market
-- applies to, and updates the seeding function to filter by it.
-- ============================================================================

-- ── 1. Add league_availability column ──────────────────────────────────────

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'football'
      AND table_name = 'prediction_markets'
      AND column_name = 'league_availability'
  ) THEN
    ALTER TABLE football.prediction_markets
      ADD COLUMN league_availability text[] NOT NULL DEFAULT '{All}'::text[];
  END IF;
END $$;

-- ── 2. Tag existing generic markets as available for all leagues ────────────

UPDATE football.prediction_markets
SET league_availability = '{All}'::text[]
WHERE league_availability = '{}'::text[]
   OR league_availability IS NULL;

-- ── 3. Tag WC-specific markets so they don't seed into league fixtures ─────

UPDATE football.prediction_markets
SET league_availability = '{FIFA World Cup 2026}'::text[]
WHERE slug LIKE 'wc-%';

-- ── 4. Seed all generic league prediction markets ──────────────────────────

INSERT INTO football.prediction_markets (
  slug, name, short_name, market_group, market_category, bet_type,
  difficulty_tier, default_fet_value, base_fet, description,
  example_selection, outcome_template, sort_order, is_active,
  league_availability
)
VALUES
  -- ═══════════════════════════════════════════════════════════════════════════
  -- OUTRIGHT MARKETS
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'league-winner',
    'League Winner',
    'Champion',
    'outright',
    'Outright',
    'Outright',
    'advanced',
    500,
    500,
    'Predict the overall champion of the league season.',
    'Arsenal',
    '[]'::jsonb,
    100,
    true,
    '{All}'::text[]
  ),
  (
    'relegation',
    'Relegation',
    'Relegation',
    'outright',
    'Outright',
    'Outright',
    'hard',
    375,
    375,
    'Predict a team to be relegated.',
    'Luton Town',
    '[]'::jsonb,
    110,
    true,
    '{All}'::text[]
  ),
  (
    'top-goalscorer',
    'Top Goalscorer',
    'Top Scorer',
    'outright',
    'Outright',
    'Outright',
    'hard',
    250,
    250,
    'Predict the player with most league goals.',
    'Haaland',
    '[]'::jsonb,
    120,
    true,
    '{All}'::text[]
  ),
  (
    'top-4-finish',
    'Top 4 Finish',
    'Top 4',
    'outright',
    'Outright',
    'Outright',
    'hard',
    250,
    250,
    'Predict a team to finish in the top 4.',
    'Aston Villa',
    '[]'::jsonb,
    130,
    true,
    '{EPL,La Liga}'::text[]
  ),
  (
    'most-assists',
    'Most Assists',
    'Assists Leader',
    'outright',
    'Outright',
    'Outright',
    'hard',
    250,
    250,
    'Predict the player with most assists.',
    'De Bruyne',
    '[]'::jsonb,
    140,
    true,
    '{EPL,La Liga}'::text[]
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- MATCH PREDICTION MARKETS
  -- (1x2 and half-time-result already exist as generic slugs)
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'double-chance',
    'Double Chance',
    'DC',
    'match_betting',
    'Match Prediction',
    'Pre-Match',
    'entry',
    50,
    50,
    'Bet on two of three match outcomes.',
    '1X (Home/Draw)',
    '[{"key":"1x","label":"Home or Draw"},{"key":"12","label":"Home or Away"},{"key":"x2","label":"Draw or Away"}]'::jsonb,
    210,
    true,
    '{All}'::text[]
  ),
  (
    'draw-no-bet',
    'Draw No Bet',
    'DNB',
    'match_betting',
    'Match Prediction',
    'Pre-Match',
    'entry',
    50,
    50,
    'Stakes refunded if match is a draw.',
    'Away Team',
    '[{"key":"home","label":"Home Win"},{"key":"away","label":"Away Win"}]'::jsonb,
    220,
    true,
    '{All}'::text[]
  ),
  (
    'second-half-result',
    'Second Half Result',
    '2H 1X2',
    'match_betting',
    'Match Prediction',
    'Pre-Match',
    'mid',
    50,
    50,
    'Predict the result of the second half exclusively.',
    'Home Team',
    '[{"key":"home","label":"Home Win"},{"key":"draw","label":"Draw"},{"key":"away","label":"Away Win"}]'::jsonb,
    230,
    true,
    '{All}'::text[]
  ),
  (
    'ht-ft',
    'HT/FT',
    'HT/FT',
    'match_betting',
    'Match Prediction',
    'Pre-Match',
    'hard',
    100,
    100,
    'Predict half-time and full-time result.',
    'Draw/Home',
    '[{"key":"home-home","label":"Home/Home"},{"key":"home-draw","label":"Home/Draw"},{"key":"home-away","label":"Home/Away"},{"key":"draw-home","label":"Draw/Home"},{"key":"draw-draw","label":"Draw/Draw"},{"key":"draw-away","label":"Draw/Away"},{"key":"away-home","label":"Away/Home"},{"key":"away-draw","label":"Away/Draw"},{"key":"away-away","label":"Away/Away"}]'::jsonb,
    240,
    true,
    '{All}'::text[]
  ),
  (
    'anytime-correct-score',
    'Anytime Correct Score',
    'Any CS',
    'match_betting',
    'Match Prediction',
    'Pre-Match',
    'mid',
    75,
    75,
    'Predict if a scoreline will occur at any point during the match.',
    '1-0',
    '[{"key":"0-0","label":"0-0"},{"key":"1-0","label":"1-0"},{"key":"0-1","label":"0-1"},{"key":"1-1","label":"1-1"},{"key":"2-0","label":"2-0"},{"key":"0-2","label":"0-2"},{"key":"2-1","label":"2-1"},{"key":"1-2","label":"1-2"},{"key":"other","label":"Other"}]'::jsonb,
    250,
    true,
    '{All}'::text[]
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- GOALS PREDICTION MARKETS
  -- (btts, over-under-1-5/2-5/3-5, correct-score already exist)
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'btts-first-half',
    'BTTS - First Half',
    'BTTS 1H',
    'goals',
    'Goals Prediction',
    'Pre-Match',
    'mid',
    100,
    100,
    'Both teams to score in 1st half.',
    'Yes',
    '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb,
    310,
    true,
    '{All}'::text[]
  ),
  (
    'btts-second-half',
    'BTTS - Second Half',
    'BTTS 2H',
    'goals',
    'Goals Prediction',
    'Pre-Match',
    'entry',
    75,
    75,
    'Both teams to score in 2nd half.',
    'No',
    '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb,
    320,
    true,
    '{All}'::text[]
  ),
  (
    'btts-both-halves',
    'BTTS in Both Halves',
    'BTTS Both',
    'goals',
    'Goals Prediction',
    'Pre-Match',
    'advanced',
    200,
    200,
    'Both teams to score in both halves.',
    'Yes',
    '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb,
    330,
    true,
    '{All}'::text[]
  ),
  (
    'btts-match-winner',
    'BTTS & Match Winner',
    'BTTS+Win',
    'goals',
    'Goals Prediction',
    'Pre-Match',
    'hard',
    125,
    125,
    'Both teams score AND match winner.',
    'Yes & Home',
    '[{"key":"yes-home","label":"Yes & Home"},{"key":"yes-away","label":"Yes & Away"},{"key":"yes-draw","label":"Yes & Draw"},{"key":"no-home","label":"No & Home"},{"key":"no-away","label":"No & Away"},{"key":"no-draw","label":"No & Draw"}]'::jsonb,
    340,
    true,
    '{All}'::text[]
  ),
  (
    'over-under-0-5',
    'Over/Under 0.5 Goals',
    'O/U 0.5',
    'goals',
    'Goals Prediction',
    'Pre-Match/Live',
    'entry',
    25,
    25,
    'Total goals over/under 0.5.',
    'Over 0.5',
    '[{"key":"over","label":"Over 0.5"},{"key":"under","label":"Under 0.5"}]'::jsonb,
    350,
    true,
    '{All}'::text[]
  ),
  (
    'over-under-4-5',
    'Over/Under 4.5 Goals',
    'O/U 4.5',
    'goals',
    'Goals Prediction',
    'Pre-Match/Live',
    'mid',
    75,
    75,
    'Total goals over/under 4.5.',
    'Under 4.5',
    '[{"key":"over","label":"Over 4.5"},{"key":"under","label":"Under 4.5"}]'::jsonb,
    360,
    true,
    '{All}'::text[]
  ),
  (
    'home-team-total-goals',
    'Home Team Goals (O/U)',
    'Home O/U',
    'goals',
    'Goals Prediction',
    'Pre-Match',
    'mid',
    50,
    50,
    'Total goals by Home Team.',
    'Over 1.5',
    '[{"key":"over-0-5","label":"Over 0.5"},{"key":"under-0-5","label":"Under 0.5"},{"key":"over-1-5","label":"Over 1.5"},{"key":"under-1-5","label":"Under 1.5"},{"key":"over-2-5","label":"Over 2.5"},{"key":"under-2-5","label":"Under 2.5"}]'::jsonb,
    370,
    true,
    '{All}'::text[]
  ),
  (
    'away-team-total-goals',
    'Away Team Goals (O/U)',
    'Away O/U',
    'goals',
    'Goals Prediction',
    'Pre-Match',
    'mid',
    50,
    50,
    'Total goals by Away Team.',
    'Under 1.5',
    '[{"key":"over-0-5","label":"Over 0.5"},{"key":"under-0-5","label":"Under 0.5"},{"key":"over-1-5","label":"Over 1.5"},{"key":"under-1-5","label":"Under 1.5"},{"key":"over-2-5","label":"Over 2.5"},{"key":"under-2-5","label":"Under 2.5"}]'::jsonb,
    380,
    true,
    '{All}'::text[]
  ),
  (
    'first-half-goals',
    'First Half Goals (O/U)',
    '1H Goals',
    'goals',
    'Goals Prediction',
    'Pre-Match',
    'mid',
    75,
    75,
    'Total goals in first half.',
    'Over 1.5',
    '[{"key":"over-0-5","label":"Over 0.5"},{"key":"under-0-5","label":"Under 0.5"},{"key":"over-1-5","label":"Over 1.5"},{"key":"under-1-5","label":"Under 1.5"}]'::jsonb,
    390,
    true,
    '{All}'::text[]
  ),
  (
    'second-half-goals',
    'Second Half Goals (O/U)',
    '2H Goals',
    'goals',
    'Goals Prediction',
    'Pre-Match',
    'mid',
    75,
    75,
    'Total goals in second half.',
    'Over 1.5',
    '[{"key":"over-0-5","label":"Over 0.5"},{"key":"under-0-5","label":"Under 0.5"},{"key":"over-1-5","label":"Over 1.5"},{"key":"under-1-5","label":"Under 1.5"}]'::jsonb,
    400,
    true,
    '{All}'::text[]
  ),
  (
    'exact-total-goals',
    'Exact Total Goals',
    'Exact Goals',
    'goals',
    'Goals Prediction',
    'Pre-Match',
    'hard',
    100,
    100,
    'Exact number of match goals.',
    '3 Goals',
    '[{"key":"0","label":"0 Goals"},{"key":"1","label":"1 Goal"},{"key":"2","label":"2 Goals"},{"key":"3","label":"3 Goals"},{"key":"4","label":"4 Goals"},{"key":"5","label":"5 Goals"},{"key":"6+","label":"6+ Goals"}]'::jsonb,
    410,
    true,
    '{All}'::text[]
  ),
  (
    'ht-correct-score',
    'Half-Time Correct Score',
    'HT CS',
    'goals',
    'Goals Prediction',
    'Pre-Match',
    'hard',
    100,
    100,
    'Exact score at half-time.',
    '0-0',
    '[{"key":"0-0","label":"0-0"},{"key":"1-0","label":"1-0"},{"key":"0-1","label":"0-1"},{"key":"1-1","label":"1-1"},{"key":"2-0","label":"2-0"},{"key":"0-2","label":"0-2"},{"key":"2-1","label":"2-1"},{"key":"1-2","label":"1-2"},{"key":"other","label":"Other"}]'::jsonb,
    420,
    true,
    '{All}'::text[]
  ),
  (
    'team-to-score-first',
    'Team to Score First',
    '1st Score',
    'goals',
    'Goals Prediction',
    'Pre-Match/Live',
    'entry',
    50,
    50,
    'Which team scores the first goal.',
    'Home Team',
    '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"},{"key":"none","label":"No Goal"}]'::jsonb,
    430,
    true,
    '{All}'::text[]
  ),
  (
    'team-to-score-last',
    'Team to Score Last',
    'Last Score',
    'goals',
    'Goals Prediction',
    'Pre-Match/Live',
    'entry',
    50,
    50,
    'Which team scores the last goal.',
    'Away Team',
    '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"},{"key":"none","label":"No Goal"}]'::jsonb,
    440,
    true,
    '{All}'::text[]
  ),
  (
    'time-of-first-goal',
    'Time of First Goal',
    '1st Goal Time',
    'goals',
    'Goals Prediction',
    'Pre-Match',
    'mid',
    75,
    75,
    '15-min bracket of first goal.',
    '16-30 Minutes',
    '[{"key":"0-15","label":"0-15 mins"},{"key":"16-30","label":"16-30 mins"},{"key":"31-45","label":"31-45 mins"},{"key":"46-60","label":"46-60 mins"},{"key":"61-75","label":"61-75 mins"},{"key":"76-90","label":"76-90 mins"},{"key":"no-goal","label":"No Goal"}]'::jsonb,
    450,
    true,
    '{All}'::text[]
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- HANDICAP PREDICTION MARKETS
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'asian-handicap-0-5',
    'Asian Handicap -0.5',
    'AH -0.5',
    'handicap',
    'Handicap Prediction',
    'Pre-Match/Live',
    'mid',
    50,
    50,
    'Team must win by 1+ goals.',
    'Away -0.5',
    '[{"key":"home","label":"Home -0.5"},{"key":"away","label":"Away +0.5"}]'::jsonb,
    510,
    true,
    '{All}'::text[]
  ),
  (
    'asian-handicap-1-0',
    'Asian Handicap -1.0',
    'AH -1.0',
    'handicap',
    'Handicap Prediction',
    'Pre-Match/Live',
    'mid',
    75,
    75,
    'Team must win by 2+ (refund on 1).',
    'Home -1.0',
    '[{"key":"home","label":"Home -1.0"},{"key":"away","label":"Away +1.0"}]'::jsonb,
    520,
    true,
    '{All}'::text[]
  ),
  (
    'asian-handicap-1-5',
    'Asian Handicap -1.5',
    'AH -1.5',
    'handicap',
    'Handicap Prediction',
    'Pre-Match/Live',
    'mid',
    75,
    75,
    'Team must win by 2+ goals.',
    'Home -1.5',
    '[{"key":"home","label":"Home -1.5"},{"key":"away","label":"Away +1.5"}]'::jsonb,
    530,
    true,
    '{All}'::text[]
  ),
  (
    'asian-handicap-plus-0-5',
    'Asian Handicap +0.5',
    'AH +0.5',
    'handicap',
    'Handicap Prediction',
    'Pre-Match/Live',
    'mid',
    50,
    50,
    'Team must win or draw.',
    'Away +0.5',
    '[{"key":"home","label":"Home -0.5"},{"key":"away","label":"Away +0.5"}]'::jsonb,
    540,
    true,
    '{All}'::text[]
  ),
  (
    'asian-handicap-plus-1-5',
    'Asian Handicap +1.5',
    'AH +1.5',
    'handicap',
    'Handicap Prediction',
    'Pre-Match/Live',
    'mid',
    75,
    75,
    'Team can win, draw, or lose by 1.',
    'Away +1.5',
    '[{"key":"home","label":"Home -1.5"},{"key":"away","label":"Away +1.5"}]'::jsonb,
    550,
    true,
    '{All}'::text[]
  ),
  (
    '3way-handicap-minus-1',
    '3-Way Handicap -1',
    '3WH -1',
    'handicap',
    'Handicap Prediction',
    'Pre-Match',
    'mid',
    75,
    75,
    'European handicap outcome.',
    'Home -1',
    '[{"key":"home","label":"Home -1"},{"key":"draw","label":"Tie (after -1)"},{"key":"away","label":"Away +1"}]'::jsonb,
    560,
    true,
    '{All}'::text[]
  ),
  (
    '3way-handicap-tie',
    '3-Way Handicap Tie',
    '3WH Tie',
    'handicap',
    'Handicap Prediction',
    'Pre-Match',
    'hard',
    100,
    100,
    'Draw after handicap applied.',
    'Tie (Home -1)',
    '[{"key":"home-1-tie","label":"Tie (Home -1)"},{"key":"home-2-tie","label":"Tie (Home -2)"},{"key":"away-1-tie","label":"Tie (Away -1)"}]'::jsonb,
    570,
    true,
    '{All}'::text[]
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- GOALSCORER MARKETS
  -- (first-goalscorer already exists as generic)
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'anytime-goalscorer',
    'Anytime Goalscorer',
    'AGS',
    'goalscorer',
    'Goalscorer Markets',
    'Pre-Match',
    'mid',
    75,
    75,
    'Player to score anytime.',
    'Jude Bellingham',
    '[]'::jsonb,
    610,
    true,
    '{All}'::text[]
  ),
  (
    'last-goalscorer',
    'Last Goalscorer',
    'LGS',
    'goalscorer',
    'Goalscorer Markets',
    'Pre-Match',
    'hard',
    100,
    100,
    'Player to score last goal.',
    'Bukayo Saka',
    '[]'::jsonb,
    620,
    true,
    '{All}'::text[]
  ),
  (
    'player-2-plus-goals',
    'Player to Score 2+ Goals',
    '2+ Goals',
    'goalscorer',
    'Goalscorer Markets',
    'Pre-Match',
    'hard',
    150,
    150,
    'Player to score two or more.',
    'Vinicius Jr',
    '[]'::jsonb,
    630,
    true,
    '{All}'::text[]
  ),
  (
    'player-hat-trick',
    'Player to Score a Hat-Trick',
    'Hat-Trick',
    'goalscorer',
    'Goalscorer Markets',
    'Pre-Match',
    'advanced',
    250,
    250,
    'Player to score three or more.',
    'Erling Haaland',
    '[]'::jsonb,
    640,
    true,
    '{All}'::text[]
  ),
  (
    'to-score-first-half',
    'To Score in First Half',
    'Score 1H',
    'goalscorer',
    'Goalscorer Markets',
    'Pre-Match',
    'hard',
    125,
    125,
    'Player to score in 1st half.',
    'Ollie Watkins',
    '[]'::jsonb,
    650,
    true,
    '{All}'::text[]
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- MATCH PROPS
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'winning-margin',
    'Winning Margin',
    'Win Margin',
    'match_props',
    'Match Props',
    'Pre-Match',
    'hard',
    100,
    100,
    'Exact goal margin of victory.',
    'Home by 2',
    '[{"key":"home-1","label":"Home by 1"},{"key":"home-2","label":"Home by 2"},{"key":"home-3+","label":"Home by 3+"},{"key":"draw","label":"Draw"},{"key":"away-1","label":"Away by 1"},{"key":"away-2","label":"Away by 2"},{"key":"away-3+","label":"Away by 3+"}]'::jsonb,
    710,
    true,
    '{All}'::text[]
  ),
  (
    'win-to-nil',
    'To Win to Nil',
    'Win to Nil',
    'match_props',
    'Match Props',
    'Pre-Match',
    'mid',
    100,
    100,
    'Win without conceding.',
    'Home Team',
    '[{"key":"home","label":"Home to Nil"},{"key":"away","label":"Away to Nil"},{"key":"no","label":"No"}]'::jsonb,
    720,
    true,
    '{All}'::text[]
  ),
  (
    'win-from-behind',
    'To Win from Behind',
    'Comeback',
    'match_props',
    'Match Props',
    'Pre-Match',
    'hard',
    150,
    150,
    'Concede first but win.',
    'Away Team',
    '[{"key":"home","label":"Home Comeback"},{"key":"away","label":"Away Comeback"},{"key":"no","label":"No Comeback"}]'::jsonb,
    730,
    true,
    '{All}'::text[]
  ),
  (
    'win-both-halves',
    'Win Both Halves',
    'Win Both',
    'match_props',
    'Match Props',
    'Pre-Match',
    'hard',
    175,
    175,
    'Score more goals in BOTH halves.',
    'Home Team',
    '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"},{"key":"neither","label":"Neither"}]'::jsonb,
    740,
    true,
    '{All}'::text[]
  ),
  (
    'score-in-both-halves',
    'Score in Both Halves',
    'Score Both',
    'match_props',
    'Match Props',
    'Pre-Match',
    'mid',
    100,
    100,
    'Score at least one in both halves.',
    'Away Team',
    '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"},{"key":"both","label":"Both Teams"},{"key":"neither","label":"Neither"}]'::jsonb,
    750,
    true,
    '{All}'::text[]
  ),
  (
    'odd-even-goals',
    'Odd/Even Total Goals',
    'Odd/Even',
    'match_props',
    'Match Props',
    'Pre-Match',
    'entry',
    50,
    50,
    'Total goals odd or even.',
    'Even',
    '[{"key":"odd","label":"Odd"},{"key":"even","label":"Even"}]'::jsonb,
    760,
    true,
    '{All}'::text[]
  ),
  (
    'clean-sheet-home',
    'Clean Sheet - Home Team',
    'CS Home',
    'match_props',
    'Match Props',
    'Pre-Match',
    'mid',
    75,
    75,
    'Home team keeps clean sheet.',
    'Yes',
    '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb,
    770,
    true,
    '{All}'::text[]
  ),
  (
    'own-goal',
    'Own Goal in Match',
    'Own Goal?',
    'match_props',
    'Match Props',
    'Pre-Match',
    'hard',
    150,
    150,
    'Own goal scored.',
    'Yes',
    '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb,
    780,
    true,
    '{All}'::text[]
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- CORNERS PREDICTION
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'total-corners',
    'Total Corners (O/U)',
    'Corners O/U',
    'corners',
    'Corners Prediction',
    'Pre-Match/Live',
    'entry',
    50,
    50,
    'Total corners over/under.',
    'Over 9.5',
    '[{"key":"over","label":"Over 9.5"},{"key":"under","label":"Under 9.5"}]'::jsonb,
    810,
    true,
    '{All}'::text[]
  ),
  (
    'first-half-corners',
    'First Half Corners (O/U)',
    '1H Corners',
    'corners',
    'Corners Prediction',
    'Pre-Match',
    'entry',
    50,
    50,
    '1st half corners over/under.',
    'Over 4.5',
    '[{"key":"over","label":"Over 4.5"},{"key":"under","label":"Under 4.5"}]'::jsonb,
    820,
    true,
    '{All}'::text[]
  ),
  (
    'home-team-total-corners',
    'Home Team Total Corners',
    'Home Corners',
    'corners',
    'Corners Prediction',
    'Pre-Match',
    'entry',
    50,
    50,
    'Home team corners over/under.',
    'Over 5.5',
    '[{"key":"over","label":"Over 5.5"},{"key":"under","label":"Under 5.5"}]'::jsonb,
    830,
    true,
    '{All}'::text[]
  ),
  (
    'away-team-total-corners',
    'Away Team Total Corners',
    'Away Corners',
    'corners',
    'Corners Prediction',
    'Pre-Match',
    'entry',
    50,
    50,
    'Away team corners over/under.',
    'Under 4.5',
    '[{"key":"over","label":"Over 4.5"},{"key":"under","label":"Under 4.5"}]'::jsonb,
    840,
    true,
    '{All}'::text[]
  ),
  (
    'most-corners',
    'Most Corners',
    'Most Corners',
    'corners',
    'Corners Prediction',
    'Pre-Match',
    'entry',
    50,
    50,
    'Team with most corners.',
    'Home Team',
    '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"},{"key":"tie","label":"Same"}]'::jsonb,
    850,
    true,
    '{All}'::text[]
  ),
  (
    'race-to-5-corners',
    'Race to 5 Corners',
    'Race 5 Corners',
    'corners',
    'Corners Prediction',
    'Pre-Match/Live',
    'mid',
    75,
    75,
    'First to reach 5 corners.',
    'Away Team',
    '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"},{"key":"neither","label":"Neither"}]'::jsonb,
    860,
    true,
    '{All}'::text[]
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- CARDS PREDICTION
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'total-match-cards',
    'Total Match Cards (O/U)',
    'Cards O/U',
    'cards',
    'Cards Prediction',
    'Pre-Match/Live',
    'entry',
    50,
    50,
    'Total cards over or under.',
    'Over 4.5',
    '[{"key":"over","label":"Over 4.5"},{"key":"under","label":"Under 4.5"}]'::jsonb,
    910,
    true,
    '{All}'::text[]
  ),
  (
    'total-match-yellow-cards',
    'Total Match Yellow Cards',
    'Yellows O/U',
    'cards',
    'Cards Prediction',
    'Pre-Match',
    'entry',
    50,
    50,
    'Total yellow cards over/under.',
    'Over 3.5',
    '[{"key":"over","label":"Over 3.5"},{"key":"under","label":"Under 3.5"}]'::jsonb,
    920,
    true,
    '{All}'::text[]
  ),
  (
    'most-cards-team',
    'Team with Most Cards',
    'Most Cards',
    'cards',
    'Cards Prediction',
    'Pre-Match',
    'entry',
    50,
    50,
    'Team receiving most cards.',
    'Away Team',
    '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"},{"key":"tie","label":"Same"}]'::jsonb,
    930,
    true,
    '{All}'::text[]
  ),
  (
    'red-card-in-match',
    'Red Card in Match',
    'Red Card?',
    'cards',
    'Cards Prediction',
    'Pre-Match/Live',
    'hard',
    125,
    125,
    'Any player sent off.',
    'Yes',
    '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb,
    940,
    true,
    '{All}'::text[]
  ),
  (
    'first-card-received',
    'First Card Received',
    '1st Card',
    'cards',
    'Cards Prediction',
    'Pre-Match',
    'entry',
    50,
    50,
    'First team to get a card.',
    'Home Team',
    '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"}]'::jsonb,
    950,
    true,
    '{All}'::text[]
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- PLAYER PROPS
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'player-shots',
    'Player Shots (O/U)',
    'Shots O/U',
    'player_props',
    'Player Props',
    'Pre-Match',
    'mid',
    75,
    75,
    'Player total shots.',
    'Over 2.5',
    '[{"key":"over","label":"Over 2.5"},{"key":"under","label":"Under 2.5"}]'::jsonb,
    1010,
    true,
    '{EPL,La Liga}'::text[]
  ),
  (
    'player-shots-on-target',
    'Player Shots on Target (O/U)',
    'SOT O/U',
    'player_props',
    'Player Props',
    'Pre-Match',
    'mid',
    75,
    75,
    'Player shots on target.',
    'Over 1.5',
    '[{"key":"over","label":"Over 1.5"},{"key":"under","label":"Under 1.5"}]'::jsonb,
    1020,
    true,
    '{EPL,La Liga}'::text[]
  ),
  (
    'player-total-passes',
    'Player Total Passes (O/U)',
    'Passes O/U',
    'player_props',
    'Player Props',
    'Pre-Match',
    'mid',
    75,
    75,
    'Player passes completed.',
    'Over 45.5',
    '[{"key":"over","label":"Over 45.5"},{"key":"under","label":"Under 45.5"}]'::jsonb,
    1030,
    true,
    '{EPL,La Liga}'::text[]
  ),
  (
    'player-tackles',
    'Player Tackles (O/U)',
    'Tackles O/U',
    'player_props',
    'Player Props',
    'Pre-Match',
    'mid',
    75,
    75,
    'Player tackles made.',
    'Over 2.5',
    '[{"key":"over","label":"Over 2.5"},{"key":"under","label":"Under 2.5"}]'::jsonb,
    1040,
    true,
    '{EPL,La Liga}'::text[]
  ),
  (
    'player-assists',
    'Player Assists (O/U)',
    'Assists O/U',
    'player_props',
    'Player Props',
    'Pre-Match',
    'hard',
    100,
    100,
    'Player assists registered.',
    'Over 0.5',
    '[{"key":"over","label":"Over 0.5"},{"key":"under","label":"Under 0.5"}]'::jsonb,
    1050,
    true,
    '{EPL,La Liga}'::text[]
  ),
  (
    'goalkeeper-saves',
    'Goalkeeper Saves (O/U)',
    'Saves O/U',
    'player_props',
    'Player Props',
    'Pre-Match',
    'mid',
    75,
    75,
    'Total saves by goalkeeper.',
    'Over 3.5',
    '[{"key":"over","label":"Over 3.5"},{"key":"under","label":"Under 3.5"}]'::jsonb,
    1060,
    true,
    '{EPL,La Liga}'::text[]
  ),
  (
    'player-to-be-carded',
    'Player to be Carded',
    'Carded?',
    'player_props',
    'Player Props',
    'Pre-Match/Live',
    'mid',
    75,
    75,
    'Player receives a card.',
    'Player X',
    '[]'::jsonb,
    1070,
    true,
    '{EPL,La Liga}'::text[]
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- MATCH EVENTS
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'penalty-awarded',
    'Penalty Awarded',
    'Penalty?',
    'match_events',
    'Match Events',
    'Pre-Match/Live',
    'mid',
    100,
    100,
    'Penalty awarded in match.',
    'Yes',
    '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb,
    1110,
    true,
    '{All}'::text[]
  ),
  (
    'penalty-scored',
    'Penalty Scored',
    'Pen Scored?',
    'match_events',
    'Match Events',
    'Pre-Match/Live',
    'hard',
    125,
    125,
    'Penalty awarded and scored.',
    'Yes',
    '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb,
    1120,
    true,
    '{All}'::text[]
  ),
  (
    'var-goal-disallowed',
    'VAR Review Goal Disallowed',
    'VAR Disallow?',
    'match_events',
    'Match Events',
    'Pre-Match/Live',
    'hard',
    125,
    125,
    'Goal ruled out by VAR.',
    'Yes',
    '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb,
    1130,
    true,
    '{EPL,La Liga}'::text[]
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- COMBO MARKETS
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'winner-over-under-2-5',
    'Match Winner + O/U 2.5',
    'Win+O/U 2.5',
    'combo',
    'Combo Markets',
    'Pre-Match',
    'mid',
    75,
    75,
    'Winner and total goals.',
    'Home + Over 2.5',
    '[{"key":"home-over","label":"Home + Over 2.5"},{"key":"home-under","label":"Home + Under 2.5"},{"key":"draw-over","label":"Draw + Over 2.5"},{"key":"draw-under","label":"Draw + Under 2.5"},{"key":"away-over","label":"Away + Over 2.5"},{"key":"away-under","label":"Away + Under 2.5"}]'::jsonb,
    1210,
    true,
    '{All}'::text[]
  ),
  (
    'double-chance-btts',
    'Double Chance + BTTS',
    'DC+BTTS',
    'combo',
    'Combo Markets',
    'Pre-Match',
    'mid',
    75,
    75,
    'Double chance and BTTS.',
    '1X + Yes',
    '[{"key":"1x-yes","label":"1X + Yes"},{"key":"1x-no","label":"1X + No"},{"key":"12-yes","label":"12 + Yes"},{"key":"12-no","label":"12 + No"},{"key":"x2-yes","label":"X2 + Yes"},{"key":"x2-no","label":"X2 + No"}]'::jsonb,
    1220,
    true,
    '{All}'::text[]
  ),
  (
    'double-chance-total-goals',
    'Double Chance + Total Goals',
    'DC+Goals',
    'combo',
    'Combo Markets',
    'Pre-Match',
    'mid',
    75,
    75,
    'Double chance and Over/Under.',
    '12 + Over 2.5',
    '[{"key":"1x-over","label":"1X + Over 2.5"},{"key":"1x-under","label":"1X + Under 2.5"},{"key":"12-over","label":"12 + Over 2.5"},{"key":"12-under","label":"12 + Under 2.5"},{"key":"x2-over","label":"X2 + Over 2.5"},{"key":"x2-under","label":"X2 + Under 2.5"}]'::jsonb,
    1230,
    true,
    '{All}'::text[]
  ),
  (
    'winner-most-corners',
    'Match Winner + Most Corners',
    'Win+Corners',
    'combo',
    'Combo Markets',
    'Pre-Match',
    'hard',
    100,
    100,
    'Winner and most corners.',
    'Home + Home',
    '[{"key":"home-home","label":"Home Win + Home Corners"},{"key":"home-away","label":"Home Win + Away Corners"},{"key":"draw-home","label":"Draw + Home Corners"},{"key":"draw-away","label":"Draw + Away Corners"},{"key":"away-home","label":"Away Win + Home Corners"},{"key":"away-away","label":"Away Win + Away Corners"}]'::jsonb,
    1240,
    true,
    '{All}'::text[]
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- IN-PLAY / LIVE MARKETS
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'next-team-to-score',
    'Next Team to Score',
    'Next Goal',
    'in_play',
    'In-Play/Live',
    'Live',
    'entry',
    50,
    50,
    'Team scoring the next goal.',
    'Home Team',
    '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"},{"key":"none","label":"No More Goals"}]'::jsonb,
    1310,
    true,
    '{All}'::text[]
  ),
  (
    'rest-of-match-winner',
    'Rest of the Match Winner',
    'Rest Winner',
    'in_play',
    'In-Play/Live',
    'Live',
    'entry',
    50,
    50,
    'Winner from current score.',
    'Away Team',
    '[{"key":"home","label":"Home Team"},{"key":"draw","label":"Draw"},{"key":"away","label":"Away Team"}]'::jsonb,
    1320,
    true,
    '{All}'::text[]
  ),
  (
    'next-corner',
    'Next Team to get a Corner',
    'Next Corner',
    'in_play',
    'In-Play/Live',
    'Live',
    'entry',
    25,
    25,
    'Team getting next corner.',
    'Home Team',
    '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"}]'::jsonb,
    1330,
    true,
    '{All}'::text[]
  ),
  (
    'next-card',
    'Next Team to get a Card',
    'Next Card',
    'in_play',
    'In-Play/Live',
    'Live',
    'entry',
    50,
    50,
    'Team getting next card.',
    'Away Team',
    '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"}]'::jsonb,
    1340,
    true,
    '{All}'::text[]
  )

ON CONFLICT (slug) DO UPDATE
SET
  name = EXCLUDED.name,
  short_name = EXCLUDED.short_name,
  market_group = EXCLUDED.market_group,
  market_category = EXCLUDED.market_category,
  bet_type = EXCLUDED.bet_type,
  difficulty_tier = EXCLUDED.difficulty_tier,
  default_fet_value = EXCLUDED.default_fet_value,
  base_fet = EXCLUDED.base_fet,
  description = EXCLUDED.description,
  example_selection = EXCLUDED.example_selection,
  outcome_template = EXCLUDED.outcome_template,
  sort_order = EXCLUDED.sort_order,
  is_active = true,
  league_availability = EXCLUDED.league_availability;

-- ── 5. Update existing generic markets with league_availability + metadata ─

UPDATE football.prediction_markets SET
  market_category = 'Match Prediction',
  bet_type = 'Pre-Match',
  base_fet = 50,
  example_selection = '1 (Home Win)',
  league_availability = '{All}'::text[]
WHERE slug = '1x2';

UPDATE football.prediction_markets SET
  market_category = 'Goals Prediction',
  bet_type = 'Pre-Match/Live',
  base_fet = 50,
  example_selection = 'Yes',
  league_availability = '{All}'::text[]
WHERE slug = 'btts';

UPDATE football.prediction_markets SET
  market_category = 'Goals Prediction',
  bet_type = 'Pre-Match/Live',
  base_fet = 50,
  example_selection = 'Over 1.5',
  league_availability = '{All}'::text[]
WHERE slug = 'over-under-1-5';

UPDATE football.prediction_markets SET
  market_category = 'Goals Prediction',
  bet_type = 'Pre-Match/Live',
  base_fet = 50,
  example_selection = 'Over 2.5',
  league_availability = '{All}'::text[]
WHERE slug = 'over-under-2-5';

UPDATE football.prediction_markets SET
  market_category = 'Goals Prediction',
  bet_type = 'Pre-Match/Live',
  base_fet = 50,
  example_selection = 'Under 3.5',
  league_availability = '{All}'::text[]
WHERE slug = 'over-under-3-5';

UPDATE football.prediction_markets SET
  market_category = 'Goals Prediction',
  bet_type = 'Pre-Match',
  base_fet = 125,
  example_selection = '2-1',
  league_availability = '{All}'::text[]
WHERE slug = 'correct-score';

UPDATE football.prediction_markets SET
  market_category = 'Match Prediction',
  bet_type = 'Pre-Match',
  base_fet = 50,
  example_selection = 'Draw',
  league_availability = '{All}'::text[]
WHERE slug = 'half-time-result';

UPDATE football.prediction_markets SET
  market_category = 'Goalscorer Markets',
  bet_type = 'Pre-Match',
  base_fet = 100,
  example_selection = 'Mo Salah',
  league_availability = '{All}'::text[]
WHERE slug = 'first-goalscorer';

-- ── 6. Refresh the public catalog view with league_availability ────────────

DROP VIEW IF EXISTS public.prediction_markets_catalog;

CREATE VIEW public.prediction_markets_catalog
WITH (security_invoker = true) AS
SELECT
  pm.id,
  pm.slug,
  pm.name,
  pm.short_name,
  pm.market_group,
  pm.market_category,
  pm.bet_type,
  pm.difficulty_tier,
  pm.default_fet_value,
  pm.base_fet,
  pm.description,
  pm.example_selection,
  pm.outcome_template,
  pm.sort_order,
  pm.is_active,
  pm.league_availability,
  pm.metadata,
  pm.created_at
FROM football.prediction_markets pm
WHERE pm.is_active = true;

GRANT SELECT ON public.prediction_markets_catalog TO anon, authenticated, service_role;

-- ── 7. Update seed_outcomes to handle all generic league markets ───────────

CREATE OR REPLACE FUNCTION football.prediction_seed_outcomes(
  p_market_slug text,
  p_outcome_template jsonb
) RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  -- If the market already has outcomes defined, use them
  IF jsonb_typeof(p_outcome_template) = 'array'
     AND jsonb_array_length(p_outcome_template) > 0 THEN
    RETURN p_outcome_template;
  END IF;

  -- Generate default outcomes for well-known market types
  RETURN CASE lower(coalesce(p_market_slug, ''))
    -- Match result variants
    WHEN '1x2' THEN
      '[{"key":"home","label":"Home Win"},{"key":"draw","label":"Draw"},{"key":"away","label":"Away Win"}]'::jsonb
    WHEN 'half-time-result' THEN
      '[{"key":"home","label":"Home Win"},{"key":"draw","label":"Draw"},{"key":"away","label":"Away Win"}]'::jsonb
    WHEN 'second-half-result' THEN
      '[{"key":"home","label":"Home Win"},{"key":"draw","label":"Draw"},{"key":"away","label":"Away Win"}]'::jsonb
    -- Goals
    WHEN 'btts' THEN
      '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb
    WHEN 'over-under-0-5' THEN
      '[{"key":"over","label":"Over 0.5"},{"key":"under","label":"Under 0.5"}]'::jsonb
    WHEN 'over-under-1-5' THEN
      '[{"key":"over","label":"Over 1.5"},{"key":"under","label":"Under 1.5"}]'::jsonb
    WHEN 'over-under-2-5' THEN
      '[{"key":"over","label":"Over 2.5"},{"key":"under","label":"Under 2.5"}]'::jsonb
    WHEN 'over-under-3-5' THEN
      '[{"key":"over","label":"Over 3.5"},{"key":"under","label":"Under 3.5"}]'::jsonb
    WHEN 'over-under-4-5' THEN
      '[{"key":"over","label":"Over 4.5"},{"key":"under","label":"Under 4.5"}]'::jsonb
    WHEN 'odd-even-goals' THEN
      '[{"key":"odd","label":"Odd"},{"key":"even","label":"Even"}]'::jsonb
    -- Correct score
    WHEN 'correct-score' THEN
      '[
        {"key":"0-0","label":"0-0"},
        {"key":"1-0","label":"1-0"},
        {"key":"1-1","label":"1-1"},
        {"key":"2-0","label":"2-0"},
        {"key":"2-1","label":"2-1"},
        {"key":"2-2","label":"2-2"},
        {"key":"0-1","label":"0-1"},
        {"key":"0-2","label":"0-2"},
        {"key":"1-2","label":"1-2"},
        {"key":"3-1","label":"3-1"},
        {"key":"1-3","label":"1-3"},
        {"key":"other","label":"Other"}
      ]'::jsonb
    -- Binary yes/no markets
    WHEN 'btts-first-half' THEN
      '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb
    WHEN 'btts-second-half' THEN
      '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb
    WHEN 'btts-both-halves' THEN
      '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb
    WHEN 'penalty-awarded' THEN
      '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb
    WHEN 'penalty-scored' THEN
      '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb
    WHEN 'red-card-in-match' THEN
      '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb
    WHEN 'var-goal-disallowed' THEN
      '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb
    WHEN 'own-goal' THEN
      '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb
    WHEN 'clean-sheet-home' THEN
      '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb
    -- Team-based
    WHEN 'team-to-score-first' THEN
      '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"},{"key":"none","label":"No Goal"}]'::jsonb
    WHEN 'team-to-score-last' THEN
      '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"},{"key":"none","label":"No Goal"}]'::jsonb
    WHEN 'most-corners' THEN
      '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"},{"key":"tie","label":"Same"}]'::jsonb
    WHEN 'most-cards-team' THEN
      '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"},{"key":"tie","label":"Same"}]'::jsonb
    WHEN 'first-card-received' THEN
      '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"}]'::jsonb
    WHEN 'next-team-to-score' THEN
      '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"},{"key":"none","label":"No More Goals"}]'::jsonb
    WHEN 'rest-of-match-winner' THEN
      '[{"key":"home","label":"Home Team"},{"key":"draw","label":"Draw"},{"key":"away","label":"Away Team"}]'::jsonb
    WHEN 'next-corner' THEN
      '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"}]'::jsonb
    WHEN 'next-card' THEN
      '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"}]'::jsonb
    WHEN 'draw-no-bet' THEN
      '[{"key":"home","label":"Home Win"},{"key":"away","label":"Away Win"}]'::jsonb
    -- Handicap
    WHEN 'asian-handicap-0-5' THEN
      '[{"key":"home","label":"Home -0.5"},{"key":"away","label":"Away +0.5"}]'::jsonb
    WHEN 'asian-handicap-1-0' THEN
      '[{"key":"home","label":"Home -1.0"},{"key":"away","label":"Away +1.0"}]'::jsonb
    WHEN 'asian-handicap-1-5' THEN
      '[{"key":"home","label":"Home -1.5"},{"key":"away","label":"Away +1.5"}]'::jsonb
    WHEN 'asian-handicap-plus-0-5' THEN
      '[{"key":"home","label":"Home -0.5"},{"key":"away","label":"Away +0.5"}]'::jsonb
    WHEN 'asian-handicap-plus-1-5' THEN
      '[{"key":"home","label":"Home -1.5"},{"key":"away","label":"Away +1.5"}]'::jsonb
    -- Total corners/cards
    WHEN 'total-corners' THEN
      '[{"key":"over","label":"Over 9.5"},{"key":"under","label":"Under 9.5"}]'::jsonb
    WHEN 'first-half-corners' THEN
      '[{"key":"over","label":"Over 4.5"},{"key":"under","label":"Under 4.5"}]'::jsonb
    WHEN 'total-match-cards' THEN
      '[{"key":"over","label":"Over 4.5"},{"key":"under","label":"Under 4.5"}]'::jsonb
    WHEN 'total-match-yellow-cards' THEN
      '[{"key":"over","label":"Over 3.5"},{"key":"under","label":"Under 3.5"}]'::jsonb
    -- Outright / goalscorer / player props: dynamic outcomes (team/player lists)
    ELSE '[]'::jsonb
  END;
END;
$$;

-- ── 8. Update seeding function to filter by league_availability ────────────
-- Only seed fixture-level (non-outright) markets that match the fixture's
-- competition context.

CREATE OR REPLACE FUNCTION football.seed_fixture_prediction_markets(
  p_fixture_id uuid,
  p_force boolean DEFAULT false
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, football
AS $$
DECLARE
  v_seeded integer := 0;
BEGIN
  WITH fixture_state AS (
    SELECT
      fixture.id,
      fixture.kickoff_at,
      fixture.status,
      comp.slug AS competition_slug,
      comp.short_name AS competition_short_name,
      (
        fixture.status IN ('live', 'finished')
        OR (fixture.kickoff_at IS NOT NULL AND fixture.kickoff_at <= now())
      ) AS is_locked_now
    FROM football.fixtures fixture
    JOIN football.competitions comp ON comp.id = fixture.competition_id
    WHERE fixture.id = p_fixture_id
  ),
  seed_rows AS (
    SELECT
      fs.id AS fixture_id,
      market.id AS market_id,
      football.prediction_seed_outcomes(
        market.slug,
        market.outcome_template
      ) AS outcomes,
      fs.is_locked_now AS is_locked,
      CASE WHEN fs.is_locked_now THEN coalesce(fs.kickoff_at, now()) END AS locked_at
    FROM fixture_state fs
    JOIN football.prediction_markets market ON market.is_active = true
    WHERE
      -- Must have resolvable outcomes
      jsonb_array_length(
        football.prediction_seed_outcomes(market.slug, market.outcome_template)
      ) > 0
      -- Skip outright markets (they are not per-fixture)
      AND market.market_group != 'outright'
      -- Filter by league_availability:
      -- 'All' means available everywhere, otherwise check competition context
      AND (
        'All' = ANY(market.league_availability)
        OR fs.competition_slug = ANY(market.league_availability)
        OR fs.competition_short_name = ANY(market.league_availability)
        -- Handle common league name variants
        OR (EXISTS (
          SELECT 1 FROM unnest(market.league_availability) AS avail(val)
          WHERE
            (avail.val = 'EPL' AND (
              fs.competition_slug ILIKE '%premier-league%'
              OR fs.competition_short_name ILIKE '%EPL%'
              OR fs.competition_short_name ILIKE '%Premier%'
            ))
            OR (avail.val = 'La Liga' AND (
              fs.competition_slug ILIKE '%laliga%'
              OR fs.competition_slug ILIKE '%la-liga%'
              OR fs.competition_short_name ILIKE '%La Liga%'
            ))
            OR (avail.val = 'RPL' AND (
              fs.competition_slug ILIKE '%rwanda%'
              OR fs.competition_short_name ILIKE '%RPL%'
              OR fs.competition_short_name ILIKE '%Rwanda%'
            ))
            OR (avail.val = 'ZSL' AND (
              fs.competition_slug ILIKE '%zambia%'
              OR fs.competition_short_name ILIKE '%ZSL%'
              OR fs.competition_short_name ILIKE '%Zambia%'
            ))
            OR (avail.val = 'Linafoot' AND (
              fs.competition_slug ILIKE '%linafoot%'
              OR fs.competition_short_name ILIKE '%Linafoot%'
              OR fs.competition_short_name ILIKE '%DRC%'
            ))
            OR (avail.val ILIKE '%world%cup%' AND (
              fs.competition_slug ILIKE '%world-cup%'
              OR fs.competition_short_name ILIKE '%World Cup%'
            ))
        ))
      )
  ),
  upserted AS (
    INSERT INTO football.fixture_markets (
      fixture_id,
      market_id,
      outcomes,
      is_locked,
      locked_at
    )
    SELECT
      fixture_id,
      market_id,
      outcomes,
      is_locked,
      locked_at
    FROM seed_rows
    ON CONFLICT (fixture_id, market_id) DO UPDATE
      SET outcomes = CASE
            WHEN p_force THEN excluded.outcomes
            ELSE football.fixture_markets.outcomes
          END,
          is_locked = excluded.is_locked,
          locked_at = excluded.locked_at,
          updated_at = now()
    RETURNING 1
  )
  SELECT count(*) INTO v_seeded
  FROM upserted;

  RETURN coalesce(v_seeded, 0);
END;
$$;
