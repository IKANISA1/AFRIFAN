"""
=============================================================================
TASK 2 & 3: Multiplier Engine (Business Logic)
=============================================================================
Converts ML-predicted probabilities into FET multipliers for the Africlub
prediction economy.

Task 2: Base multiplier generation with overround (house edge)
Task 3: Dynamic liability adjustment based on user voting volume

Separated from the ML model so you can integrate these functions directly
into your Supabase Edge Functions or Python backend.
=============================================================================
"""

from typing import Dict, Tuple, Optional
import math


# ===========================================================================
# TASK 2: Multiplier Generation with Overround
# ===========================================================================

def compute_base_multipliers(
    probabilities: Dict[str, float],
    overround: float = 0.07,
) -> Dict[str, float]:
    """
    Converts predicted probabilities into decimal multipliers with house edge.

    The core formula:
        fair_multiplier = 1 / probability
        adjusted_multiplier = fair_multiplier × (1 - overround)

    A 7% overround means the sum of implied probabilities exceeds 100% by 7%,
    protecting the FET economy from long-term losses.

    Args:
        probabilities: Dict with keys '1', 'X', '2' and values summing to ~1.0
                       Example: {'1': 0.55, 'X': 0.22, '2': 0.23}

        overround:     House edge as a decimal (0.07 = 7%)
                       This is the "vig" or "juice" in traditional betting.
                       Higher = more protection, lower multipliers for users.

    Returns:
        Dict with keys '1', 'X', '2' and decimal multiplier values
        Example: {'1': 1.69, 'X': 4.23, '2': 4.04}

    Business context:
        - A user betting 100 FET on Home Win at 1.69x would win 169 FET
        - The fair multiplier would be 1/0.55 = 1.82x (182 FET)
        - The 7% overround saves the economy 13 FET per 100 wagered
    """
    # --- Validate inputs ---
    _validate_probabilities(probabilities)

    if not 0.0 <= overround < 0.50:
        raise ValueError(f"Overround must be between 0.0 and 0.50, got {overround}")

    multipliers = {}
    for outcome, prob in probabilities.items():
        # Step 1: Fair multiplier (no edge)
        fair_multiplier = 1.0 / prob

        # Step 2: Apply overround — reduces payout to protect FET economy
        adjusted_multiplier = fair_multiplier * (1.0 - overround)

        # Step 3: Floor at 1.01 — a multiplier below 1.0 means guaranteed loss
        adjusted_multiplier = max(adjusted_multiplier, 1.01)

        # Step 4: Round to 2 decimal places for display
        multipliers[outcome] = round(adjusted_multiplier, 2)

    return multipliers


def compute_implied_margin(multipliers: Dict[str, float]) -> float:
    """
    Calculates the actual margin (overround) embedded in a set of multipliers.

    The sum of 1/multiplier for all outcomes should exceed 1.0.
    The excess is the house edge.

    Example:
        multipliers = {'1': 1.69, 'X': 4.23, '2': 4.04}
        implied = 1/1.69 + 1/4.23 + 1/4.04 = 0.592 + 0.237 + 0.248 = 1.076
        margin = 1.076 - 1.0 = 7.6%

    Returns:
        Margin as a decimal (0.076 = 7.6%)
    """
    total_implied = sum(1.0 / mult for mult in multipliers.values())
    return round(total_implied - 1.0, 4)


# ===========================================================================
# TASK 3: Dynamic Liability Adjustment
# ===========================================================================

def adjust_for_user_volume(
    base_multipliers: Dict[str, float],
    user_pool_percentages: Dict[str, float],
    volume_threshold: float = 0.60,
    depression_factor: float = 0.05,
    boost_factor: float = 0.08,
    min_multiplier: float = 1.01,
    max_multiplier: float = 50.0,
) -> Dict[str, dict]:
    """
    Dynamically adjusts multipliers based on user voting patterns to protect
    the FET economy from one-sided liability.

    THE PROBLEM:
        If 80% of users bet on Home Win, a home win pays out massive FET.
        This creates an imbalanced liability that can drain the virtual economy.

    THE SOLUTION:
        1. If outcome X has >60% of user volume → DEPRESS its multiplier
           (less attractive, fewer users pile on)
        2. BOOST underpicked outcomes' multipliers
           (more attractive, incentivizes balanced distribution)

    This mimics how real bookmakers "move the line" based on action.

    Args:
        base_multipliers:       Dict {'1': 1.69, 'X': 4.23, '2': 4.04}
        user_pool_percentages:  Dict {'1': 0.80, 'X': 0.10, '2': 0.10}
                                (must sum to ~1.0)
        volume_threshold:       Above this %, multiplier gets depressed (default 60%)
        depression_factor:      How much to reduce (0.05 = 5% per threshold breach)
        boost_factor:           How much to increase underpicked outcomes (0.08 = 8%)
        min_multiplier:         Floor — never go below this
        max_multiplier:         Ceiling — prevents absurd payouts on extreme underdogs

    Returns:
        Dict with keys '1', 'X', '2', each containing:
        {
            'base_multiplier': 1.69,        # Before adjustment
            'adjusted_multiplier': 1.61,    # After volume adjustment
            'user_pool_pct': 0.80,          # User voting share
            'adjustment_applied': -0.08,    # Multiplier delta
            'adjustment_reason': 'depressed_heavy_volume'
        }
    """
    # --- Validate ---
    _validate_probabilities(user_pool_percentages)

    results = {}
    outcomes = list(base_multipliers.keys())

    # Identify which outcomes are overloaded vs underloaded
    overloaded = {k for k, v in user_pool_percentages.items() if v > volume_threshold}
    underloaded = {k for k in outcomes if k not in overloaded}

    # Calculate overload severity for graduated adjustment
    for outcome in outcomes:
        base_mult = base_multipliers[outcome]
        user_pct = user_pool_percentages.get(outcome, 0.0)

        if outcome in overloaded:
            # --- DEPRESS: Heavy user volume → reduce multiplier ---
            # The more extreme the overload, the bigger the depression
            excess = user_pct - volume_threshold  # e.g., 0.80 - 0.60 = 0.20
            severity = min(excess / (1.0 - volume_threshold), 1.0)  # Normalize 0-1

            # Graduated depression: stronger as volume increases
            depression = depression_factor * (1.0 + severity * 2.0)
            adjusted = base_mult * (1.0 - depression)

            adjustment = adjusted - base_mult
            reason = 'depressed_heavy_volume'

        else:
            # --- BOOST: Underpicked outcome → increase multiplier ---
            # Boost proportional to how underpicked this outcome is
            if len(overloaded) > 0:
                # Calculate boost: more boost if fewer users picked this
                underpick_factor = max(0, volume_threshold - user_pct) / volume_threshold
                boost = boost_factor * (1.0 + underpick_factor)
                adjusted = base_mult * (1.0 + boost)

                adjustment = adjusted - base_mult
                reason = 'boosted_underpicked'
            else:
                # No overloaded outcomes → no adjustment needed
                adjusted = base_mult
                adjustment = 0.0
                reason = 'no_adjustment'

        # Enforce bounds
        adjusted = max(min_multiplier, min(adjusted, max_multiplier))
        adjusted = round(adjusted, 2)

        results[outcome] = {
            'base_multiplier': base_mult,
            'adjusted_multiplier': adjusted,
            'user_pool_pct': round(user_pct, 4),
            'adjustment_applied': round(adjusted - base_mult, 4),
            'adjustment_reason': reason,
        }

    return results


# ===========================================================================
# Convenience: Full Pipeline (Predict → Multiplier → Adjust)
# ===========================================================================

def generate_market_multipliers(
    probabilities: Dict[str, float],
    user_pool_percentages: Optional[Dict[str, float]] = None,
    overround: float = 0.07,
    volume_threshold: float = 0.60,
) -> Dict[str, dict]:
    """
    End-to-end: takes ML probabilities and returns production-ready multipliers.

    This is the function you'd call from your Supabase Edge Function or API
    endpoint to generate fixture_markets data.

    Args:
        probabilities:          ML model output {'1': 0.55, 'X': 0.22, '2': 0.23}
        user_pool_percentages:  Current user bets {'1': 0.80, 'X': 0.10, '2': 0.10}
                                None = no volume adjustment (pre-match, no bets yet)
        overround:              House edge (default 7%)
        volume_threshold:       Volume % above which depression kicks in

    Returns:
        Dict per outcome with base/adjusted multipliers + reasoning
    """
    # Step 1: Base multipliers with overround
    base_multipliers = compute_base_multipliers(probabilities, overround)

    # Step 2: Volume adjustment (if user data available)
    if user_pool_percentages is not None:
        return adjust_for_user_volume(
            base_multipliers,
            user_pool_percentages,
            volume_threshold=volume_threshold,
        )

    # No user data → return base multipliers with metadata
    return {
        outcome: {
            'base_multiplier': mult,
            'adjusted_multiplier': mult,
            'user_pool_pct': None,
            'adjustment_applied': 0.0,
            'adjustment_reason': 'no_user_data',
        }
        for outcome, mult in base_multipliers.items()
    }


# ===========================================================================
# Helpers
# ===========================================================================

def _validate_probabilities(probs: Dict[str, float]) -> None:
    """Validates that a probability dict is well-formed."""
    required_keys = {'1', 'X', '2'}
    missing = required_keys - set(probs.keys())
    if missing:
        raise ValueError(f"Missing outcome keys: {missing}")

    for key, val in probs.items():
        if not isinstance(val, (int, float)) or val < 0:
            raise ValueError(f"Invalid probability for '{key}': {val}")

    total = sum(probs.values())
    if not (0.95 <= total <= 1.05):
        raise ValueError(
            f"Probabilities must sum to ~1.0, got {total:.4f}. "
            f"Values: {probs}"
        )


# ===========================================================================
# Demo / Self-test
# ===========================================================================

if __name__ == '__main__':
    print("=" * 70)
    print("TASK 2: Multiplier Generation with 7% Overround")
    print("=" * 70)

    # Example ML output
    probs = {'1': 0.55, 'X': 0.22, '2': 0.23}
    print(f"\nML Probabilities: {probs}")

    # Base multipliers
    base = compute_base_multipliers(probs, overround=0.07)
    margin = compute_implied_margin(base)
    print(f"Base Multipliers (7% overround): {base}")
    print(f"Implied Margin: {margin:.1%}")

    # Show the math
    print("\n--- The Math ---")
    for outcome, prob in probs.items():
        fair = round(1.0 / prob, 2)
        adj = base[outcome]
        print(f"  {outcome}: fair={fair}x → adjusted={adj}x "
              f"(user wins {adj}x FET per wager)")

    print("\n" + "=" * 70)
    print("TASK 3: Dynamic Liability Adjustment")
    print("=" * 70)

    # Scenario: 80% of users picked Home Win
    user_pools = {'1': 0.80, 'X': 0.10, '2': 0.10}
    print(f"\nUser Pool: {user_pools}")

    adjusted = adjust_for_user_volume(base, user_pools)
    print(f"\nAdjusted Multipliers:")
    for outcome, data in adjusted.items():
        base_m = data['base_multiplier']
        adj_m = data['adjusted_multiplier']
        delta = data['adjustment_applied']
        reason = data['adjustment_reason']
        user_pct = data['user_pool_pct']
        direction = "↓" if delta < 0 else "↑" if delta > 0 else "="
        print(f"  {outcome}: {base_m}x → {adj_m}x ({direction}{abs(delta):.2f}) "
              f"[{user_pct:.0%} users] ({reason})")

    # Full pipeline
    print("\n" + "=" * 70)
    print("FULL PIPELINE: generate_market_multipliers()")
    print("=" * 70)

    result = generate_market_multipliers(
        probabilities={'1': 0.55, 'X': 0.22, '2': 0.23},
        user_pool_percentages={'1': 0.80, 'X': 0.10, '2': 0.10},
        overround=0.07,
    )

    print("\nProduction-ready output:")
    for outcome, data in result.items():
        print(f"  {outcome}: {data}")

    # Edge case: balanced pool (no adjustment needed)
    print("\n--- Balanced pool (no adjustment) ---")
    balanced = generate_market_multipliers(
        probabilities={'1': 0.55, 'X': 0.22, '2': 0.23},
        user_pool_percentages={'1': 0.40, 'X': 0.30, '2': 0.30},
        overround=0.07,
    )
    for outcome, data in balanced.items():
        print(f"  {outcome}: {data['base_multiplier']}x → "
              f"{data['adjusted_multiplier']}x ({data['adjustment_reason']})")

    # Edge case: extreme underdog scenario
    print("\n--- Extreme underdog ---")
    extreme = generate_market_multipliers(
        probabilities={'1': 0.08, 'X': 0.12, '2': 0.80},
        user_pool_percentages={'1': 0.05, 'X': 0.10, '2': 0.85},
        overround=0.07,
    )
    for outcome, data in extreme.items():
        print(f"  {outcome}: {data['base_multiplier']}x → "
              f"{data['adjusted_multiplier']}x ({data['adjustment_reason']})")
