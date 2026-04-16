-- ============================================================================
-- 2026 World Cup — Full Prediction Markets Catalog
-- Expands the prediction_markets table with all market categories, bet types,
-- and ~90 prediction option rows for comprehensive World Cup coverage.
-- ============================================================================

-- ── 1. Expand market_group CHECK to accommodate all new categories ──────────

ALTER TABLE football.prediction_markets
  DROP CONSTRAINT IF EXISTS ck_prediction_markets_group;

ALTER TABLE football.prediction_markets
  ADD CONSTRAINT ck_prediction_markets_group CHECK (
    market_group IN (
      'match_result',
      'goals',
      'scorers',
      'specials',
      'outright',
      'match_betting',
      'handicap',
      'goalscorer',
      'match_props',
      'corners',
      'cards',
      'player_props',
      'match_events',
      'in_play',
      'combo'
    )
  );

-- ── 2. Add market_category and bet_type columns ────────────────────────────

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'football'
      AND table_name = 'prediction_markets'
      AND column_name = 'market_category'
  ) THEN
    ALTER TABLE football.prediction_markets
      ADD COLUMN market_category text NOT NULL DEFAULT '';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'football'
      AND table_name = 'prediction_markets'
      AND column_name = 'bet_type'
  ) THEN
    ALTER TABLE football.prediction_markets
      ADD COLUMN bet_type text NOT NULL DEFAULT 'Pre-Match';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'football'
      AND table_name = 'prediction_markets'
      AND column_name = 'base_fet'
  ) THEN
    ALTER TABLE football.prediction_markets
      ADD COLUMN base_fet integer NOT NULL DEFAULT 50;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'football'
      AND table_name = 'prediction_markets'
      AND column_name = 'example_selection'
  ) THEN
    ALTER TABLE football.prediction_markets
      ADD COLUMN example_selection text NOT NULL DEFAULT '';
  END IF;
END $$;

-- ── 3. Backfill existing rows with sensible defaults ───────────────────────

UPDATE football.prediction_markets
SET
  market_category = CASE slug
    WHEN '1x2' THEN 'Match Betting'
    WHEN 'btts' THEN 'Goals Betting'
    WHEN 'over-under-1-5' THEN 'Goals Betting'
    WHEN 'over-under-2-5' THEN 'Goals Betting'
    WHEN 'over-under-3-5' THEN 'Goals Betting'
    WHEN 'correct-score' THEN 'Goals Betting'
    WHEN 'half-time-result' THEN 'Match Betting'
    WHEN 'first-goalscorer' THEN 'Goalscorer Markets'
    ELSE 'Match Betting'
  END,
  bet_type = CASE slug
    WHEN 'first-goalscorer' THEN 'Pre-Match'
    ELSE 'Pre-Match'
  END,
  base_fet = default_fet_value,
  example_selection = CASE slug
    WHEN '1x2' THEN '1 (Home Team Win)'
    WHEN 'btts' THEN 'Yes'
    WHEN 'over-under-1-5' THEN 'Over 1.5'
    WHEN 'over-under-2-5' THEN 'Over 2.5'
    WHEN 'over-under-3-5' THEN 'Under 3.5'
    WHEN 'correct-score' THEN '2-1'
    WHEN 'half-time-result' THEN 'Draw'
    WHEN 'first-goalscorer' THEN 'Lionel Messi'
    ELSE ''
  END
WHERE market_category = '' OR market_category IS NULL;

-- ── 4. Seed all 2026 World Cup prediction markets ──────────────────────────

INSERT INTO football.prediction_markets (
  slug, name, short_name, market_group, market_category, bet_type,
  difficulty_tier, default_fet_value, base_fet, description,
  example_selection, outcome_template, sort_order, is_active
)
VALUES
  -- ═══════════════════════════════════════════════════════════════════════════
  -- OUTRIGHT / TOURNAMENT MARKETS
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'wc-tournament-winner',
    'Tournament Winner',
    'Winner',
    'outright',
    'Outright/Tournament',
    'Outright',
    'advanced',
    500,
    500,
    'Predict the overall winner of the 2026 World Cup.',
    'Brazil',
    '[]'::jsonb,
    1000,
    true
  ),
  (
    'wc-tournament-runner-up',
    'Tournament Runner-Up',
    'Runner-Up',
    'outright',
    'Outright/Tournament',
    'Outright',
    'advanced',
    375,
    375,
    'Predict the team that will lose in the final.',
    'England',
    '[]'::jsonb,
    1010,
    true
  ),
  (
    'wc-to-reach-final',
    'To Reach the Final',
    'Reach Final',
    'outright',
    'Outright/Tournament',
    'Outright',
    'hard',
    250,
    250,
    'Predict if a specific team will make it to the final match.',
    'France',
    '[]'::jsonb,
    1020,
    true
  ),
  (
    'wc-to-reach-semi-finals',
    'To Reach the Semi-Finals',
    'Reach SFs',
    'outright',
    'Outright/Tournament',
    'Outright',
    'hard',
    200,
    200,
    'Predict if a team will reach the final four.',
    'Argentina',
    '[]'::jsonb,
    1030,
    true
  ),
  (
    'wc-to-reach-quarter-finals',
    'To Reach the Quarter-Finals',
    'Reach QFs',
    'outright',
    'Outright/Tournament',
    'Outright',
    'mid',
    150,
    150,
    'Predict if a team will reach the final eight.',
    'USA',
    '[]'::jsonb,
    1040,
    true
  ),
  (
    'wc-golden-boot',
    'Golden Boot Winner',
    'Golden Boot',
    'outright',
    'Outright/Tournament',
    'Outright',
    'advanced',
    250,
    250,
    'Predict the top goalscorer of the tournament.',
    'Kylian Mbappe',
    '[]'::jsonb,
    1050,
    true
  ),
  (
    'wc-golden-ball',
    'Golden Ball Winner',
    'Golden Ball',
    'outright',
    'Outright/Tournament',
    'Outright',
    'advanced',
    250,
    250,
    'Predict the best player of the tournament.',
    'Lionel Messi',
    '[]'::jsonb,
    1060,
    true
  ),
  (
    'wc-golden-glove',
    'Golden Glove Winner',
    'Golden Glove',
    'outright',
    'Outright/Tournament',
    'Outright',
    'advanced',
    250,
    250,
    'Predict the best goalkeeper of the tournament.',
    'Emiliano Martinez',
    '[]'::jsonb,
    1070,
    true
  ),
  (
    'wc-best-young-player',
    'Best Young Player',
    'Best Young',
    'outright',
    'Outright/Tournament',
    'Outright',
    'advanced',
    250,
    250,
    'Predict the best young player of the tournament.',
    'Jude Bellingham',
    '[]'::jsonb,
    1080,
    true
  ),
  (
    'wc-group-a-winner',
    'Group A Winner',
    'Grp A',
    'outright',
    'Outright/Tournament',
    'Outright',
    'mid',
    125,
    125,
    'Predict the winner of Group A.',
    'Mexico',
    '[]'::jsonb,
    1090,
    true
  ),
  (
    'wc-group-b-winner',
    'Group B Winner',
    'Grp B',
    'outright',
    'Outright/Tournament',
    'Outright',
    'mid',
    125,
    125,
    'Predict the winner of Group B.',
    'Spain',
    '[]'::jsonb,
    1100,
    true
  ),
  (
    'wc-group-c-winner',
    'Group C Winner',
    'Grp C',
    'outright',
    'Outright/Tournament',
    'Outright',
    'mid',
    125,
    125,
    'Predict the winner of Group C.',
    'Germany',
    '[]'::jsonb,
    1110,
    true
  ),
  (
    'wc-group-to-qualify',
    'Group To Qualify (Yes/No)',
    'Qualify Y/N',
    'outright',
    'Outright/Tournament',
    'Outright',
    'entry',
    100,
    100,
    'Predict if a specific team will advance from their group.',
    'Canada - Yes',
    '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb,
    1120,
    true
  ),
  (
    'wc-total-tournament-goals',
    'Total Tournament Goals',
    'Total Goals',
    'outright',
    'Outright/Tournament',
    'Outright',
    'hard',
    250,
    250,
    'Predict if total goals in all matches will be over/under a line.',
    'Over 170.5',
    '[{"key":"over","label":"Over 170.5"},{"key":"under","label":"Under 170.5"}]'::jsonb,
    1130,
    true
  ),
  (
    'wc-total-tournament-red-cards',
    'Total Tournament Red Cards',
    'Total Reds',
    'outright',
    'Outright/Tournament',
    'Outright',
    'mid',
    150,
    150,
    'Predict total red cards shown in the entire tournament.',
    'Under 15.5',
    '[{"key":"over","label":"Over 15.5"},{"key":"under","label":"Under 15.5"}]'::jsonb,
    1140,
    true
  ),
  (
    'wc-winning-continent',
    'Winning Continent',
    'Win Continent',
    'outright',
    'Outright/Tournament',
    'Outright',
    'mid',
    200,
    200,
    'Predict which continent the winning team will be from.',
    'UEFA',
    '[{"key":"uefa","label":"UEFA (Europe)"},{"key":"conmebol","label":"CONMEBOL (S. America)"},{"key":"caf","label":"CAF (Africa)"},{"key":"concacaf","label":"CONCACAF (N. America)"},{"key":"afc","label":"AFC (Asia)"},{"key":"ofc","label":"OFC (Oceania)"}]'::jsonb,
    1150,
    true
  ),
  (
    'wc-highest-scoring-team',
    'Highest Scoring Team',
    'Most Goals',
    'outright',
    'Outright/Tournament',
    'Outright',
    'hard',
    200,
    200,
    'Predict the team that scores the most goals overall.',
    'Brazil',
    '[]'::jsonb,
    1160,
    true
  ),
  (
    'wc-lowest-scoring-team',
    'Lowest Scoring Team',
    'Fewest Goals',
    'outright',
    'Outright/Tournament',
    'Outright',
    'hard',
    200,
    200,
    'Predict the team that scores the fewest goals overall.',
    'Saudi Arabia',
    '[]'::jsonb,
    1170,
    true
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- MATCH BETTING MARKETS
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'wc-double-chance',
    'Double Chance',
    'DC',
    'match_betting',
    'Match Betting',
    'Pre-Match',
    'entry',
    50,
    50,
    'Bet on two of the three possible match outcomes.',
    '1X (Home Win or Draw)',
    '[{"key":"1x","label":"Home or Draw"},{"key":"12","label":"Home or Away"},{"key":"x2","label":"Draw or Away"}]'::jsonb,
    2010,
    true
  ),
  (
    'wc-draw-no-bet',
    'Draw No Bet',
    'DNB',
    'match_betting',
    'Match Betting',
    'Pre-Match',
    'entry',
    50,
    50,
    'Bet on a team to win but stakes are refunded if the match ends in a draw.',
    'Away Team',
    '[{"key":"home","label":"Home Win"},{"key":"away","label":"Away Win"}]'::jsonb,
    2020,
    true
  ),
  (
    'wc-ht-ft',
    'Half-Time/Full-Time (HT/FT)',
    'HT/FT',
    'match_betting',
    'Match Betting',
    'Pre-Match',
    'hard',
    100,
    100,
    'Predict the result at half-time and the result at full-time.',
    'Draw/Home Team',
    '[{"key":"home-home","label":"Home/Home"},{"key":"home-draw","label":"Home/Draw"},{"key":"home-away","label":"Home/Away"},{"key":"draw-home","label":"Draw/Home"},{"key":"draw-draw","label":"Draw/Draw"},{"key":"draw-away","label":"Draw/Away"},{"key":"away-home","label":"Away/Home"},{"key":"away-draw","label":"Away/Draw"},{"key":"away-away","label":"Away/Away"}]'::jsonb,
    2030,
    true
  ),
  (
    'wc-to-qualify',
    'To Qualify / Advance',
    'Qualify',
    'match_betting',
    'Match Betting',
    'Pre-Match',
    'entry',
    75,
    75,
    'Predict which team will advance to the next round (includes ET/Pens).',
    'Team B',
    '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"}]'::jsonb,
    2040,
    true
  ),
  (
    'wc-method-of-victory',
    'Method of Victory',
    'Method',
    'match_betting',
    'Match Betting',
    'Pre-Match',
    'hard',
    125,
    125,
    'Predict how a team will win a knockout match.',
    'Team A in Extra Time',
    '[{"key":"home-90","label":"Home in 90 mins"},{"key":"away-90","label":"Away in 90 mins"},{"key":"home-et","label":"Home in Extra Time"},{"key":"away-et","label":"Away in Extra Time"},{"key":"home-pens","label":"Home on Penalties"},{"key":"away-pens","label":"Away on Penalties"}]'::jsonb,
    2050,
    true
  ),
  (
    'wc-extra-time',
    'Match to Go to Extra Time',
    'Extra Time?',
    'match_betting',
    'Match Betting',
    'Pre-Match',
    'mid',
    100,
    100,
    'Predict if a knockout match will end in a draw after 90 mins.',
    'Yes',
    '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb,
    2060,
    true
  ),
  (
    'wc-penalties',
    'Match to Go to Penalties',
    'Penalties?',
    'match_betting',
    'Match Betting',
    'Pre-Match',
    'hard',
    150,
    150,
    'Predict if a knockout match will be decided by a penalty shootout.',
    'Yes',
    '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb,
    2070,
    true
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- GOALS BETTING MARKETS
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'wc-btts-first-half',
    'BTTS - First Half',
    'BTTS 1H',
    'goals',
    'Goals Betting',
    'Pre-Match',
    'mid',
    100,
    100,
    'Predict if both teams will score in the first half.',
    'Yes',
    '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb,
    3010,
    true
  ),
  (
    'wc-btts-second-half',
    'BTTS - Second Half',
    'BTTS 2H',
    'goals',
    'Goals Betting',
    'Pre-Match',
    'entry',
    75,
    75,
    'Predict if both teams will score in the second half.',
    'No',
    '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb,
    3020,
    true
  ),
  (
    'wc-btts-match-winner',
    'BTTS & Match Winner',
    'BTTS+Win',
    'goals',
    'Goals Betting',
    'Pre-Match',
    'hard',
    125,
    125,
    'Predict both teams to score AND the match winner.',
    'Yes & Home Team',
    '[{"key":"yes-home","label":"Yes & Home"},{"key":"yes-away","label":"Yes & Away"},{"key":"yes-draw","label":"Yes & Draw"},{"key":"no-home","label":"No & Home"},{"key":"no-away","label":"No & Away"},{"key":"no-draw","label":"No & Draw"}]'::jsonb,
    3030,
    true
  ),
  (
    'wc-over-under-0-5',
    'Over/Under 0.5 Goals',
    'O/U 0.5',
    'goals',
    'Goals Betting',
    'Pre-Match/Live',
    'entry',
    25,
    25,
    'Predict if total goals will be over or under 0.5.',
    'Over 0.5',
    '[{"key":"over","label":"Over 0.5"},{"key":"under","label":"Under 0.5"}]'::jsonb,
    3040,
    true
  ),
  (
    'wc-over-under-4-5',
    'Over/Under 4.5 Goals',
    'O/U 4.5',
    'goals',
    'Goals Betting',
    'Pre-Match/Live',
    'mid',
    75,
    75,
    'Predict if total goals will be over or under 4.5.',
    'Under 4.5',
    '[{"key":"over","label":"Over 4.5"},{"key":"under","label":"Under 4.5"}]'::jsonb,
    3050,
    true
  ),
  (
    'wc-home-team-total-goals',
    'Home Team Total Goals (O/U)',
    'Home O/U',
    'goals',
    'Goals Betting',
    'Pre-Match',
    'mid',
    50,
    50,
    'Predict total goals scored by the Home Team.',
    'Over 1.5',
    '[{"key":"over-0-5","label":"Over 0.5"},{"key":"under-0-5","label":"Under 0.5"},{"key":"over-1-5","label":"Over 1.5"},{"key":"under-1-5","label":"Under 1.5"},{"key":"over-2-5","label":"Over 2.5"},{"key":"under-2-5","label":"Under 2.5"}]'::jsonb,
    3060,
    true
  ),
  (
    'wc-away-team-total-goals',
    'Away Team Total Goals (O/U)',
    'Away O/U',
    'goals',
    'Goals Betting',
    'Pre-Match',
    'mid',
    50,
    50,
    'Predict total goals scored by the Away Team.',
    'Under 1.5',
    '[{"key":"over-0-5","label":"Over 0.5"},{"key":"under-0-5","label":"Under 0.5"},{"key":"over-1-5","label":"Over 1.5"},{"key":"under-1-5","label":"Under 1.5"},{"key":"over-2-5","label":"Over 2.5"},{"key":"under-2-5","label":"Under 2.5"}]'::jsonb,
    3070,
    true
  ),
  (
    'wc-exact-total-goals',
    'Exact Total Goals',
    'Exact Goals',
    'goals',
    'Goals Betting',
    'Pre-Match',
    'hard',
    100,
    100,
    'Predict the exact number of goals scored in the match.',
    '3 Goals',
    '[{"key":"0","label":"0 Goals"},{"key":"1","label":"1 Goal"},{"key":"2","label":"2 Goals"},{"key":"3","label":"3 Goals"},{"key":"4","label":"4 Goals"},{"key":"5","label":"5 Goals"},{"key":"6+","label":"6+ Goals"}]'::jsonb,
    3080,
    true
  ),
  (
    'wc-odd-even-goals',
    'Odd/Even Total Goals',
    'Odd/Even',
    'goals',
    'Goals Betting',
    'Pre-Match',
    'entry',
    50,
    50,
    'Predict if the total number of goals will be odd or even.',
    'Odd',
    '[{"key":"odd","label":"Odd"},{"key":"even","label":"Even"}]'::jsonb,
    3090,
    true
  ),
  (
    'wc-ht-correct-score',
    'Half-Time Correct Score',
    'HT CS',
    'goals',
    'Goals Betting',
    'Pre-Match',
    'hard',
    75,
    75,
    'Predict the exact score at half-time.',
    '0-0',
    '[{"key":"0-0","label":"0-0"},{"key":"1-0","label":"1-0"},{"key":"0-1","label":"0-1"},{"key":"1-1","label":"1-1"},{"key":"2-0","label":"2-0"},{"key":"0-2","label":"0-2"},{"key":"2-1","label":"2-1"},{"key":"1-2","label":"1-2"},{"key":"other","label":"Other"}]'::jsonb,
    3100,
    true
  ),
  (
    'wc-time-of-first-goal',
    'Time of First Goal',
    '1st Goal Time',
    'goals',
    'Goals Betting',
    'Pre-Match',
    'mid',
    75,
    75,
    'Predict the 15-minute bracket of the first goal.',
    '0-15 Minutes',
    '[{"key":"0-15","label":"0-15 mins"},{"key":"16-30","label":"16-30 mins"},{"key":"31-45","label":"31-45 mins"},{"key":"46-60","label":"46-60 mins"},{"key":"61-75","label":"61-75 mins"},{"key":"76-90","label":"76-90 mins"},{"key":"no-goal","label":"No Goal"}]'::jsonb,
    3110,
    true
  ),
  (
    'wc-team-to-score-first',
    'Team to Score First',
    '1st Scorer',
    'goals',
    'Goals Betting',
    'Pre-Match/Live',
    'entry',
    50,
    50,
    'Predict which team scores the first goal.',
    'Home Team',
    '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"},{"key":"none","label":"No Goal"}]'::jsonb,
    3120,
    true
  ),
  (
    'wc-team-to-score-last',
    'Team to Score Last',
    'Last Scorer',
    'goals',
    'Goals Betting',
    'Pre-Match/Live',
    'entry',
    50,
    50,
    'Predict which team scores the final goal of the match.',
    'Away Team',
    '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"},{"key":"none","label":"No Goal"}]'::jsonb,
    3130,
    true
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- HANDICAP BETTING MARKETS
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'wc-asian-handicap-0-5',
    'Asian Handicap -0.5',
    'AH -0.5',
    'handicap',
    'Handicap Betting',
    'Pre-Match/Live',
    'mid',
    50,
    50,
    'Team must win the match to win the bet.',
    'Home -0.5',
    '[{"key":"home","label":"Home -0.5"},{"key":"away","label":"Away +0.5"}]'::jsonb,
    4010,
    true
  ),
  (
    'wc-asian-handicap-1-5',
    'Asian Handicap -1.5',
    'AH -1.5',
    'handicap',
    'Handicap Betting',
    'Pre-Match/Live',
    'mid',
    75,
    75,
    'Team must win by 2 or more goals.',
    'Home -1.5',
    '[{"key":"home","label":"Home -1.5"},{"key":"away","label":"Away +1.5"}]'::jsonb,
    4020,
    true
  ),
  (
    'wc-asian-handicap-plus-1-5',
    'Asian Handicap +1.5',
    'AH +1.5',
    'handicap',
    'Handicap Betting',
    'Pre-Match/Live',
    'mid',
    75,
    75,
    'Team can win, draw, or lose by 1 goal.',
    'Away +1.5',
    '[{"key":"home","label":"Home -1.5"},{"key":"away","label":"Away +1.5"}]'::jsonb,
    4030,
    true
  ),
  (
    'wc-3way-handicap-minus-1',
    '3-Way Handicap -1',
    '3WH -1',
    'handicap',
    'Handicap Betting',
    'Pre-Match',
    'mid',
    75,
    75,
    'European handicap, predicting outcome after applying a -1 goal deficit.',
    'Home -1',
    '[{"key":"home","label":"Home -1"},{"key":"draw","label":"Tie (after -1)"},{"key":"away","label":"Away +1"}]'::jsonb,
    4040,
    true
  ),
  (
    'wc-3way-handicap-tie',
    '3-Way Handicap Tie',
    '3WH Tie',
    'handicap',
    'Handicap Betting',
    'Pre-Match',
    'hard',
    100,
    100,
    'Predicting a draw after a handicap is applied.',
    'Tie (Home -1)',
    '[{"key":"home-1-tie","label":"Tie (Home -1)"},{"key":"home-2-tie","label":"Tie (Home -2)"},{"key":"away-1-tie","label":"Tie (Away -1)"}]'::jsonb,
    4050,
    true
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- GOALSCORER MARKETS
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'wc-anytime-goalscorer',
    'Anytime Goalscorer',
    'AGS',
    'goalscorer',
    'Goalscorer Markets',
    'Pre-Match',
    'mid',
    75,
    75,
    'Predict a player to score at any point during normal time.',
    'Erling Haaland',
    '[]'::jsonb,
    5010,
    true
  ),
  (
    'wc-last-goalscorer',
    'Last Goalscorer',
    'LGS',
    'goalscorer',
    'Goalscorer Markets',
    'Pre-Match',
    'hard',
    100,
    100,
    'Predict which player will score the last goal.',
    'Vinicius Jr',
    '[]'::jsonb,
    5020,
    true
  ),
  (
    'wc-player-2-plus-goals',
    'Player to Score 2+ Goals',
    '2+ Goals',
    'goalscorer',
    'Goalscorer Markets',
    'Pre-Match',
    'hard',
    150,
    150,
    'Predict a player to score two or more goals.',
    'Harry Kane',
    '[]'::jsonb,
    5030,
    true
  ),
  (
    'wc-player-hat-trick',
    'Player to Score a Hat-Trick',
    'Hat-Trick',
    'goalscorer',
    'Goalscorer Markets',
    'Pre-Match',
    'advanced',
    250,
    250,
    'Predict a player to score three or more goals.',
    'Kylian Mbappe',
    '[]'::jsonb,
    5040,
    true
  ),
  (
    'wc-wincast',
    'Wincast',
    'Wincast',
    'goalscorer',
    'Goalscorer Markets',
    'Pre-Match',
    'hard',
    125,
    125,
    'Predict anytime goalscorer AND the match winner.',
    'Haaland & Norway',
    '[]'::jsonb,
    5050,
    true
  ),
  (
    'wc-scorecast',
    'Scorecast',
    'Scorecast',
    'goalscorer',
    'Goalscorer Markets',
    'Pre-Match',
    'advanced',
    250,
    250,
    'Predict first goalscorer AND correct match score.',
    'Messi & 2-0',
    '[]'::jsonb,
    5060,
    true
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- MATCH PROPS
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'wc-winning-margin',
    'Winning Margin',
    'Win Margin',
    'match_props',
    'Match Props',
    'Pre-Match',
    'hard',
    100,
    100,
    'Predict the exact goal margin a team will win by.',
    'Home Team by 2 Goals',
    '[{"key":"home-1","label":"Home by 1"},{"key":"home-2","label":"Home by 2"},{"key":"home-3+","label":"Home by 3+"},{"key":"draw","label":"Draw"},{"key":"away-1","label":"Away by 1"},{"key":"away-2","label":"Away by 2"},{"key":"away-3+","label":"Away by 3+"}]'::jsonb,
    6010,
    true
  ),
  (
    'wc-win-to-nil',
    'To Win to Nil',
    'Win to Nil',
    'match_props',
    'Match Props',
    'Pre-Match',
    'mid',
    100,
    100,
    'Predict a team to win without conceding a goal.',
    'Home Team',
    '[{"key":"home","label":"Home to Nil"},{"key":"away","label":"Away to Nil"},{"key":"no","label":"No"}]'::jsonb,
    6020,
    true
  ),
  (
    'wc-win-from-behind',
    'To Win from Behind',
    'Comeback',
    'match_props',
    'Match Props',
    'Pre-Match',
    'hard',
    150,
    150,
    'Predict a team to concede first but ultimately win.',
    'Away Team',
    '[{"key":"home","label":"Home Comeback"},{"key":"away","label":"Away Comeback"},{"key":"no","label":"No Comeback"}]'::jsonb,
    6030,
    true
  ),
  (
    'wc-btts-both-halves',
    'Both Teams to Score in Both Halves',
    'BTTS Both',
    'match_props',
    'Match Props',
    'Pre-Match',
    'advanced',
    200,
    200,
    'Predict BTTS to hit in both the 1st and 2nd half.',
    'Yes',
    '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb,
    6040,
    true
  ),
  (
    'wc-own-goal',
    'Own Goal in Match',
    'Own Goal?',
    'match_props',
    'Match Props',
    'Pre-Match',
    'hard',
    150,
    150,
    'Predict if an own goal will be scored.',
    'Yes',
    '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb,
    6050,
    true
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- CORNERS BETTING
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'wc-total-corners',
    'Total Corners (O/U)',
    'Corners O/U',
    'corners',
    'Corners Betting',
    'Pre-Match/Live',
    'entry',
    50,
    50,
    'Predict if total corners will be over/under a set line (e.g., 9.5).',
    'Over 9.5',
    '[{"key":"over","label":"Over 9.5"},{"key":"under","label":"Under 9.5"}]'::jsonb,
    7010,
    true
  ),
  (
    'wc-first-half-corners',
    'First Half Corners (O/U)',
    '1H Corners',
    'corners',
    'Corners Betting',
    'Pre-Match',
    'entry',
    50,
    50,
    'Predict if 1st half corners will be over/under a set line.',
    'Over 4.5',
    '[{"key":"over","label":"Over 4.5"},{"key":"under","label":"Under 4.5"}]'::jsonb,
    7020,
    true
  ),
  (
    'wc-most-corners',
    'Most Corners',
    'Most Corners',
    'corners',
    'Corners Betting',
    'Pre-Match',
    'entry',
    50,
    50,
    'Predict which team will be awarded the most corners.',
    'Home Team',
    '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"},{"key":"tie","label":"Same"}]'::jsonb,
    7030,
    true
  ),
  (
    'wc-corner-handicap',
    'Corner Handicap',
    'Corner HC',
    'corners',
    'Corners Betting',
    'Pre-Match',
    'mid',
    75,
    75,
    'Handicap applied to team corner totals.',
    'Home -2.5 Corners',
    '[{"key":"home","label":"Home"},{"key":"away","label":"Away"}]'::jsonb,
    7040,
    true
  ),
  (
    'wc-race-to-5-corners',
    'Race to 5 Corners',
    'Race 5 Corners',
    'corners',
    'Corners Betting',
    'Pre-Match/Live',
    'mid',
    75,
    75,
    'Predict which team will reach 5 corners first.',
    'Away Team',
    '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"},{"key":"neither","label":"Neither"}]'::jsonb,
    7050,
    true
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- CARDS BETTING
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'wc-total-match-cards',
    'Total Match Cards (O/U)',
    'Cards O/U',
    'cards',
    'Cards Betting',
    'Pre-Match/Live',
    'entry',
    50,
    50,
    'Predict total booking points/cards over or under a line.',
    'Over 4.5 Cards',
    '[{"key":"over","label":"Over 4.5"},{"key":"under","label":"Under 4.5"}]'::jsonb,
    8010,
    true
  ),
  (
    'wc-most-cards-team',
    'Team with Most Cards',
    'Most Cards',
    'cards',
    'Cards Betting',
    'Pre-Match',
    'entry',
    50,
    50,
    'Predict which team receives more cards.',
    'Away Team',
    '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"},{"key":"tie","label":"Same"}]'::jsonb,
    8020,
    true
  ),
  (
    'wc-red-card-in-match',
    'Red Card in Match',
    'Red Card?',
    'cards',
    'Cards Betting',
    'Pre-Match/Live',
    'hard',
    125,
    125,
    'Predict if any player will be sent off.',
    'Yes',
    '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb,
    8030,
    true
  ),
  (
    'wc-first-card-received',
    'First Card Received',
    '1st Card',
    'cards',
    'Cards Betting',
    'Pre-Match',
    'entry',
    50,
    50,
    'Predict which team gets the first yellow or red card.',
    'Home Team',
    '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"}]'::jsonb,
    8040,
    true
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- PLAYER PROPS
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'wc-player-to-be-carded',
    'Player to be Carded',
    'Carded?',
    'player_props',
    'Player Props',
    'Pre-Match/Live',
    'mid',
    75,
    75,
    'Predict if a specific player will receive a card.',
    'Player X',
    '[]'::jsonb,
    9010,
    true
  ),
  (
    'wc-player-sent-off',
    'Player to be Sent Off',
    'Sent Off?',
    'player_props',
    'Player Props',
    'Pre-Match',
    'advanced',
    200,
    200,
    'Predict if a specific player receives a red card.',
    'Player Y',
    '[]'::jsonb,
    9020,
    true
  ),
  (
    'wc-player-shots-on-target',
    'Player Shots on Target (O/U)',
    'SOT O/U',
    'player_props',
    'Player Props',
    'Pre-Match',
    'mid',
    75,
    75,
    'Predict over/under for a player''s shots on target.',
    'Over 1.5',
    '[{"key":"over","label":"Over 1.5"},{"key":"under","label":"Under 1.5"}]'::jsonb,
    9030,
    true
  ),
  (
    'wc-player-total-shots',
    'Player Total Shots (O/U)',
    'Shots O/U',
    'player_props',
    'Player Props',
    'Pre-Match',
    'mid',
    75,
    75,
    'Predict total shots (on or off target) by a player.',
    'Over 2.5',
    '[{"key":"over","label":"Over 2.5"},{"key":"under","label":"Under 2.5"}]'::jsonb,
    9040,
    true
  ),
  (
    'wc-player-assists',
    'Player Assists (O/U)',
    'Assists O/U',
    'player_props',
    'Player Props',
    'Pre-Match',
    'hard',
    100,
    100,
    'Predict if a player will register an assist.',
    'Over 0.5',
    '[{"key":"over","label":"Over 0.5"},{"key":"under","label":"Under 0.5"}]'::jsonb,
    9050,
    true
  ),
  (
    'wc-player-total-passes',
    'Player Total Passes (O/U)',
    'Passes O/U',
    'player_props',
    'Player Props',
    'Pre-Match',
    'mid',
    75,
    75,
    'Predict total passes completed by a specific player.',
    'Over 45.5',
    '[{"key":"over","label":"Over 45.5"},{"key":"under","label":"Under 45.5"}]'::jsonb,
    9060,
    true
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- MATCH EVENTS
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'wc-penalty-awarded',
    'Penalty Awarded',
    'Penalty?',
    'match_events',
    'Match Events',
    'Pre-Match/Live',
    'mid',
    100,
    100,
    'Predict if a penalty will be awarded in the match.',
    'Yes',
    '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb,
    10010,
    true
  ),
  (
    'wc-penalty-missed',
    'Penalty Missed',
    'Pen Missed?',
    'match_events',
    'Match Events',
    'Pre-Match/Live',
    'hard',
    175,
    175,
    'Predict if a penalty will be taken and missed.',
    'Yes',
    '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb,
    10020,
    true
  ),
  (
    'wc-var-goal-disallowed',
    'VAR Review - Goal Disallowed',
    'VAR Disallow?',
    'match_events',
    'Match Events',
    'Pre-Match/Live',
    'hard',
    125,
    125,
    'Predict if a goal will be ruled out by VAR.',
    'Yes',
    '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb,
    10030,
    true
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- IN-PLAY / LIVE MARKETS
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'wc-next-team-to-score',
    'Next Team to Score (Goal 1, 2, 3...)',
    'Next Goal',
    'in_play',
    'In-Play/Live',
    'Live',
    'entry',
    50,
    50,
    'Predict which team scores the next specific goal.',
    'Home Team',
    '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"},{"key":"none","label":"No More Goals"}]'::jsonb,
    11010,
    true
  ),
  (
    'wc-rest-of-match-winner',
    'Rest of the Match Winner',
    'Rest Winner',
    'in_play',
    'In-Play/Live',
    'Live',
    'entry',
    50,
    50,
    'Predict who wins the remainder of the match from current score.',
    'Away Team',
    '[{"key":"home","label":"Home Team"},{"key":"draw","label":"Draw"},{"key":"away","label":"Away Team"}]'::jsonb,
    11020,
    true
  ),
  (
    'wc-next-corner',
    'Next Team to get a Corner',
    'Next Corner',
    'in_play',
    'In-Play/Live',
    'Live',
    'entry',
    25,
    25,
    'Predict who gets the next corner kick.',
    'Home Team',
    '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"}]'::jsonb,
    11030,
    true
  ),
  (
    'wc-next-card',
    'Next Team to get a Card',
    'Next Card',
    'in_play',
    'In-Play/Live',
    'Live',
    'entry',
    50,
    50,
    'Predict who gets the next yellow or red card.',
    'Away Team',
    '[{"key":"home","label":"Home Team"},{"key":"away","label":"Away Team"}]'::jsonb,
    11040,
    true
  ),

  -- ═══════════════════════════════════════════════════════════════════════════
  -- COMBO MARKETS
  -- ═══════════════════════════════════════════════════════════════════════════
  (
    'wc-winner-over-under-2-5',
    'Match Winner + O/U 2.5 Goals',
    'Win+O/U 2.5',
    'combo',
    'Combo Markets',
    'Pre-Match',
    'mid',
    75,
    75,
    'Combine match winner and total goals over/under 2.5.',
    'Home + Over 2.5',
    '[{"key":"home-over","label":"Home + Over 2.5"},{"key":"home-under","label":"Home + Under 2.5"},{"key":"draw-over","label":"Draw + Over 2.5"},{"key":"draw-under","label":"Draw + Under 2.5"},{"key":"away-over","label":"Away + Over 2.5"},{"key":"away-under","label":"Away + Under 2.5"}]'::jsonb,
    12010,
    true
  ),
  (
    'wc-double-chance-btts',
    'Double Chance + BTTS',
    'DC+BTTS',
    'combo',
    'Combo Markets',
    'Pre-Match',
    'mid',
    75,
    75,
    'Combine double chance with both teams to score.',
    '1X + Yes',
    '[{"key":"1x-yes","label":"1X + Yes"},{"key":"1x-no","label":"1X + No"},{"key":"12-yes","label":"12 + Yes"},{"key":"12-no","label":"12 + No"},{"key":"x2-yes","label":"X2 + Yes"},{"key":"x2-no","label":"X2 + No"}]'::jsonb,
    12020,
    true
  ),
  (
    'wc-winner-most-corners',
    'Match Winner + Most Corners',
    'Win+Corners',
    'combo',
    'Combo Markets',
    'Pre-Match',
    'hard',
    100,
    100,
    'Combine match winner with who gets the most corners.',
    'Home + Home',
    '[{"key":"home-home","label":"Home Win + Home Corners"},{"key":"home-away","label":"Home Win + Away Corners"},{"key":"draw-home","label":"Draw + Home Corners"},{"key":"draw-away","label":"Draw + Away Corners"},{"key":"away-home","label":"Away Win + Home Corners"},{"key":"away-away","label":"Away Win + Away Corners"}]'::jsonb,
    12030,
    true
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
  is_active = true;

-- ── 5. Update existing markets with new metadata ───────────────────────────

-- Set market_category and bet_type for pre-existing MVP markets
UPDATE football.prediction_markets SET
  market_category = 'Match Betting',
  market_group = 'match_result',
  bet_type = 'Pre-Match',
  base_fet = 50,
  example_selection = '1 (Home Team Win)'
WHERE slug = '1x2' AND market_category = '';

UPDATE football.prediction_markets SET
  market_category = 'Goals Betting',
  bet_type = 'Pre-Match/Live',
  base_fet = 50,
  example_selection = 'Yes'
WHERE slug = 'btts' AND market_category = '';

UPDATE football.prediction_markets SET
  market_category = 'Goals Betting',
  bet_type = 'Pre-Match/Live',
  base_fet = 50,
  example_selection = 'Over 1.5'
WHERE slug = 'over-under-1-5' AND market_category = '';

UPDATE football.prediction_markets SET
  market_category = 'Goals Betting',
  bet_type = 'Pre-Match/Live',
  base_fet = 50,
  example_selection = 'Over 2.5'
WHERE slug = 'over-under-2-5' AND market_category = '';

UPDATE football.prediction_markets SET
  market_category = 'Goals Betting',
  bet_type = 'Pre-Match/Live',
  base_fet = 50,
  example_selection = 'Under 3.5'
WHERE slug = 'over-under-3-5' AND market_category = '';

UPDATE football.prediction_markets SET
  market_category = 'Goals Betting',
  bet_type = 'Pre-Match',
  base_fet = 125,
  example_selection = '2-1'
WHERE slug = 'correct-score' AND market_category = '';

UPDATE football.prediction_markets SET
  market_category = 'Match Betting',
  bet_type = 'Pre-Match',
  base_fet = 50,
  example_selection = 'Draw'
WHERE slug = 'half-time-result' AND market_category = '';

UPDATE football.prediction_markets SET
  market_category = 'Goalscorer Markets',
  bet_type = 'Pre-Match',
  base_fet = 100,
  example_selection = 'Lionel Messi'
WHERE slug = 'first-goalscorer' AND market_category = '';

-- ── 6. Refresh the public catalog view to expose new columns ───────────────
-- Must DROP + CREATE (not REPLACE) because we are adding new columns
-- in different positions than the original view definition.

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
  pm.metadata,
  pm.created_at
FROM football.prediction_markets pm
WHERE pm.is_active = true;

GRANT SELECT ON public.prediction_markets_catalog TO anon, authenticated, service_role;

-- ── 7. Update seed_outcomes helper to handle new market types ──────────────

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
    WHEN '1x2' THEN
      '[{"key":"home","label":"Home Win"},{"key":"draw","label":"Draw"},{"key":"away","label":"Away Win"}]'::jsonb
    WHEN 'btts' THEN
      '[{"key":"yes","label":"Yes"},{"key":"no","label":"No"}]'::jsonb
    WHEN 'over-under-1-5' THEN
      '[{"key":"over","label":"Over 1.5"},{"key":"under","label":"Under 1.5"}]'::jsonb
    WHEN 'over-under-2-5' THEN
      '[{"key":"over","label":"Over 2.5"},{"key":"under","label":"Under 2.5"}]'::jsonb
    WHEN 'over-under-3-5' THEN
      '[{"key":"over","label":"Over 3.5"},{"key":"under","label":"Under 3.5"}]'::jsonb
    WHEN 'half-time-result' THEN
      '[{"key":"home","label":"Home Win"},{"key":"draw","label":"Draw"},{"key":"away","label":"Away Win"}]'::jsonb
    -- Outright / tournament markets have dynamic outcomes (team lists), skip auto-seed
    ELSE '[]'::jsonb
  END;
END;
$$;
