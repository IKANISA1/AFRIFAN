/**
 * ============================================================================
 * Probability Engine — TypeScript port of match_predictor.py
 * ============================================================================
 * Feature-based probability estimation for 1X2 (Home/Draw/Away) outcomes.
 * Uses team strength, form, goals, positioning, and head-to-head data
 * sourced from the football.fixture_features DB view.
 * ============================================================================
 */

export interface FixtureFeatures {
  fixture_id: string;
  home_team_win_rate: number | null;
  away_team_win_rate: number | null;
  home_team_draw_rate: number | null;
  home_goals_scored_avg: number | null;
  home_goals_conceded_avg: number | null;
  away_goals_scored_avg: number | null;
  away_goals_conceded_avg: number | null;
  h2h_home_wins: number | null;
  h2h_away_wins: number | null;
  h2h_draws: number | null;
  home_league_position: number | null;
  away_league_position: number | null;
}

export interface ThreeWayProbability {
  home: number; // 0.0 - 1.0
  draw: number; // 0.0 - 1.0
  away: number; // 0.0 - 1.0
}

/**
 * Estimates 3-way match outcome probabilities from historical features.
 *
 * This mirrors the Python ML model's logic but uses direct feature weighting
 * instead of a trained model — suitable for runtime in an edge function
 * without numpy/sklearn dependency.
 *
 * Falls back to balanced defaults when data is sparse.
 */
export function estimateProbabilities(
  features: FixtureFeatures,
): ThreeWayProbability {
  // Safe defaults for null/missing data
  const homeWinRate = clamp(features.home_team_win_rate ?? 0.45, 0.1, 0.9);
  const awayWinRate = clamp(features.away_team_win_rate ?? 0.35, 0.1, 0.9);
  const homeDrawRate = clamp(features.home_team_draw_rate ?? 0.25, 0.05, 0.5);
  const homeGoalsAvg = clamp(features.home_goals_scored_avg ?? 1.3, 0.1, 4.0);
  const homeConcededAvg = clamp(
    features.home_goals_conceded_avg ?? 1.0,
    0.1,
    4.0,
  );
  const awayGoalsAvg = clamp(features.away_goals_scored_avg ?? 1.1, 0.1, 4.0);
  const awayConcededAvg = clamp(
    features.away_goals_conceded_avg ?? 1.2,
    0.1,
    4.0,
  );
  const h2hHome = features.h2h_home_wins ?? 0;
  const h2hAway = features.h2h_away_wins ?? 0;
  const homePos = features.home_league_position ?? 10;
  const awayPos = features.away_league_position ?? 10;

  // Goal difference advantage
  const goalDiffAdv =
    homeGoalsAvg - awayConcededAvg - (awayGoalsAvg - homeConcededAvg);

  // Position advantage (positive = home is better)
  const posAdv = awayPos - homePos;

  // --- Strength calculations (mirrors Python model weights) ---
  const homeStrength =
    0.3 * homeWinRate +
    0.15 * (homeGoalsAvg / 4.0) +
    0.1 * (clamp(posAdv, -20, 20) + 20) / 40.0 +
    0.1 * (clamp(goalDiffAdv, -2, 2) + 2) / 4.0 +
    0.05 * (h2hHome / Math.max(h2hHome + h2hAway + 1, 1)) +
    0.2; // Home advantage base

  const awayStrength =
    0.3 * awayWinRate +
    0.15 * (awayGoalsAvg / 4.0) +
    0.05 * (h2hAway / Math.max(h2hHome + h2hAway + 1, 1)) +
    0.1; // Slight away disadvantage

  const drawTendency =
    0.15 +
    0.2 * homeDrawRate +
    0.15 * (1.0 - Math.abs(homeStrength - awayStrength));

  // Normalize to probabilities
  const total = homeStrength + awayStrength + drawTendency;
  const pHome = homeStrength / total;
  const pDraw = drawTendency / total;
  const pAway = awayStrength / total;

  // Apply floor/ceiling (no outcome below 5% or above 90%)
  return normalizeProbabilities({
    home: clamp(pHome, 0.05, 0.90),
    draw: clamp(pDraw, 0.05, 0.50),
    away: clamp(pAway, 0.05, 0.90),
  });
}

/**
 * Returns default equal probabilities when no historical data is available.
 */
export function defaultProbabilities(): ThreeWayProbability {
  return { home: 0.4, draw: 0.25, away: 0.35 };
}

/**
 * BTTS (Both Teams to Score) probability estimation.
 */
export function estimateBTTS(features: FixtureFeatures): {
  yes: number;
  no: number;
} {
  const homeGoals = features.home_goals_scored_avg ?? 1.3;
  const awayGoals = features.away_goals_scored_avg ?? 1.1;
  const homeConceded = features.home_goals_conceded_avg ?? 1.0;
  const awayConceded = features.away_goals_conceded_avg ?? 1.2;

  // Higher scoring teams → more likely BTTS
  const scoreIndex = (homeGoals + awayGoals + homeConceded + awayConceded) / 4;
  const bttsProb = clamp(0.2 + scoreIndex * 0.2, 0.25, 0.80);

  return { yes: bttsProb, no: 1 - bttsProb };
}

/**
 * Over/Under total goals probability estimation.
 */
export function estimateOverUnder(
  features: FixtureFeatures,
  line: number,
): { over: number; under: number } {
  const homeGoals = features.home_goals_scored_avg ?? 1.3;
  const awayGoals = features.away_goals_scored_avg ?? 1.1;
  const expectedGoals = homeGoals + awayGoals;

  // Poisson-inspired: P(total > line) ≈ based on expected goals vs line
  const diff = expectedGoals - line;
  const overProb = clamp(0.5 + diff * 0.2, 0.10, 0.90);

  return { over: overProb, under: 1 - overProb };
}

// --- Helpers ---

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function normalizeProbabilities(p: ThreeWayProbability): ThreeWayProbability {
  const total = p.home + p.draw + p.away;
  return {
    home: p.home / total,
    draw: p.draw / total,
    away: p.away / total,
  };
}
