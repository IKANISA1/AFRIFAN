/**
 * ============================================================================
 * Liability Engine — TypeScript port of multiplier_engine.py
 * ============================================================================
 * Converts ML probabilities into FET multipliers with:
 *  - Overround (house edge) to protect the virtual economy
 *  - Dynamic liability adjustment based on user voting volume
 * ============================================================================
 */

export interface MultiplierSet {
  [outcomeKey: string]: MultiplierResult;
}

export interface MultiplierResult {
  baseMultiplier: number;
  adjustedMultiplier: number;
  userPoolPct: number | null;
  adjustmentApplied: number;
  adjustmentReason: string;
}

export interface OutcomeProbabilities {
  [outcomeKey: string]: number; // key -> probability (0.0 - 1.0)
}

export interface UserVotingVolume {
  [outcomeKey: string]: number; // key -> percentage (0.0 - 1.0)
}

// ─── Configuration Constants ────────────────────────────────────────────

/** Default house edge: 7% overround */
export const DEFAULT_OVERROUND = 0.07;

/** Above this %, multiplier gets depressed */
export const DEFAULT_VOLUME_THRESHOLD = 0.60;

/** How much to reduce over-picked outcomes */
const DEPRESSION_FACTOR = 0.05;

/** How much to boost under-picked outcomes */
const BOOST_FACTOR = 0.08;

/** Floor — never go below this */
const MIN_MULTIPLIER = 1.01;

/** Ceiling — prevents absurd payouts */
const MAX_MULTIPLIER = 50.0;

// ─── Task 2: Base Multiplier Generation ─────────────────────────────────

/**
 * Converts predicted probabilities into decimal multipliers with house edge.
 *
 * Formula:
 *   fair_multiplier = 1 / probability
 *   adjusted_multiplier = fair_multiplier × (1 - overround)
 *
 * @param probabilities Dict of outcome key -> probability (must sum to ~1.0)
 * @param overround House edge as decimal (0.07 = 7%)
 * @returns Dict of outcome key -> decimal multiplier
 */
export function computeBaseMultipliers(
  probabilities: OutcomeProbabilities,
  overround: number = DEFAULT_OVERROUND,
): Record<string, number> {
  const multipliers: Record<string, number> = {};

  for (const [outcome, prob] of Object.entries(probabilities)) {
    if (prob <= 0) {
      multipliers[outcome] = MAX_MULTIPLIER;
      continue;
    }

    // Step 1: Fair multiplier
    const fairMultiplier = 1.0 / prob;

    // Step 2: Apply overround
    let adjusted = fairMultiplier * (1.0 - overround);

    // Step 3: Enforce bounds
    adjusted = Math.max(MIN_MULTIPLIER, Math.min(MAX_MULTIPLIER, adjusted));

    // Step 4: Round to 2 decimals
    multipliers[outcome] = Math.round(adjusted * 100) / 100;
  }

  return multipliers;
}

/**
 * Calculates the actual margin embedded in a set of multipliers.
 * Sum of 1/multiplier for all outcomes should exceed 1.0.
 */
export function computeImpliedMargin(
  multipliers: Record<string, number>,
): number {
  const totalImplied = Object.values(multipliers).reduce(
    (sum, mult) => sum + 1.0 / mult,
    0,
  );
  return Math.round((totalImplied - 1.0) * 10000) / 10000;
}

// ─── Task 3: Dynamic Liability Adjustment ───────────────────────────────

/**
 * Adjusts multipliers based on user voting patterns to protect the FET economy.
 *
 * If an outcome has > threshold % of user volume:
 *   - DEPRESS that outcome's multiplier (less attractive)
 *   - BOOST underpicked outcomes' multipliers (more attractive)
 *
 * @param baseMultipliers Output from computeBaseMultipliers
 * @param userVolume Dict of outcome key -> vote percentage (0.0 - 1.0)
 * @param volumeThreshold Above this %, depression kicks in (default 60%)
 */
export function adjustForUserVolume(
  baseMultipliers: Record<string, number>,
  userVolume: UserVotingVolume,
  volumeThreshold: number = DEFAULT_VOLUME_THRESHOLD,
): MultiplierSet {
  const outcomes = Object.keys(baseMultipliers);
  const overloaded = new Set<string>();

  // Identify overloaded outcomes
  for (const outcome of outcomes) {
    if ((userVolume[outcome] ?? 0) > volumeThreshold) {
      overloaded.add(outcome);
    }
  }

  const results: MultiplierSet = {};

  for (const outcome of outcomes) {
    const baseMult = baseMultipliers[outcome];
    const userPct = userVolume[outcome] ?? 0;

    if (overloaded.has(outcome)) {
      // --- DEPRESS: Heavy user volume → reduce multiplier ---
      const excess = userPct - volumeThreshold;
      const severity = Math.min(excess / (1.0 - volumeThreshold), 1.0);
      const depression = DEPRESSION_FACTOR * (1.0 + severity * 2.0);
      let adjusted = baseMult * (1.0 - depression);
      adjusted = clamp(adjusted, MIN_MULTIPLIER, MAX_MULTIPLIER);
      adjusted = round2(adjusted);

      results[outcome] = {
        baseMultiplier: baseMult,
        adjustedMultiplier: adjusted,
        userPoolPct: round4(userPct),
        adjustmentApplied: round4(adjusted - baseMult),
        adjustmentReason: 'depressed_heavy_volume',
      };
    } else if (overloaded.size > 0) {
      // --- BOOST: Underpicked → increase multiplier ---
      const underpickFactor =
        Math.max(0, volumeThreshold - userPct) / volumeThreshold;
      const boost = BOOST_FACTOR * (1.0 + underpickFactor);
      let adjusted = baseMult * (1.0 + boost);
      adjusted = clamp(adjusted, MIN_MULTIPLIER, MAX_MULTIPLIER);
      adjusted = round2(adjusted);

      results[outcome] = {
        baseMultiplier: baseMult,
        adjustedMultiplier: adjusted,
        userPoolPct: round4(userPct),
        adjustmentApplied: round4(adjusted - baseMult),
        adjustmentReason: 'boosted_underpicked',
      };
    } else {
      // No adjustment needed
      results[outcome] = {
        baseMultiplier: baseMult,
        adjustedMultiplier: baseMult,
        userPoolPct: round4(userPct),
        adjustmentApplied: 0,
        adjustmentReason: 'no_adjustment',
      };
    }
  }

  return results;
}

// ─── Full Pipeline ──────────────────────────────────────────────────────

/**
 * End-to-end: probabilities → multipliers → liability adjustment.
 *
 * This is the main function called by the edge function handler.
 */
export function generateMarketMultipliers(
  probabilities: OutcomeProbabilities,
  userVolume?: UserVotingVolume | null,
  overround: number = DEFAULT_OVERROUND,
  volumeThreshold: number = DEFAULT_VOLUME_THRESHOLD,
): MultiplierSet {
  // Step 1: Base multipliers with overround
  const baseMultipliers = computeBaseMultipliers(probabilities, overround);

  // Step 2: Volume adjustment (if user data available)
  if (userVolume && Object.keys(userVolume).length > 0) {
    return adjustForUserVolume(baseMultipliers, userVolume, volumeThreshold);
  }

  // No user data → return base multipliers with metadata
  const results: MultiplierSet = {};
  for (const [outcome, mult] of Object.entries(baseMultipliers)) {
    results[outcome] = {
      baseMultiplier: mult,
      adjustedMultiplier: mult,
      userPoolPct: null,
      adjustmentApplied: 0,
      adjustmentReason: 'no_user_data',
    };
  }
  return results;
}

/**
 * Converts MultiplierSet into the JSONB outcomes format stored in fixture_markets.
 *
 * Input:  { home: { adjustedMultiplier: 1.84, ... }, draw: { ... }, away: { ... } }
 * Output: [{ key: "home", label: "Home Win", odds: 1.84 }, ...]
 */
export function toOutcomesJsonb(
  multipliers: MultiplierSet,
  templateOutcomes: Array<{ key: string; label: string }>,
): Array<{ key: string; label: string; odds: number }> {
  return templateOutcomes.map((template) => ({
    key: template.key,
    label: template.label,
    odds: multipliers[template.key]?.adjustedMultiplier ?? 1.0,
  }));
}

// ─── Helpers ────────────────────────────────────────────────────────────

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

function round4(value: number): number {
  return Math.round(value * 10000) / 10000;
}
