"""
=============================================================================
Full Pipeline Demo: ML Prediction → Multiplier Generation → Liability Adj
=============================================================================
Run this file to see the complete end-to-end pipeline in action.

Usage:
    cd services/prediction-engine
    pip install -r requirements.txt
    python run_pipeline.py
=============================================================================
"""

from match_predictor import (
    generate_mock_dataset,
    MatchOutcomePredictor,
    FEATURE_COLUMNS,
)
from multiplier_engine import (
    generate_market_multipliers,
    compute_implied_margin,
    compute_base_multipliers,
)
import pandas as pd


def main():
    # =======================================================================
    # PHASE 1: Train the ML Model
    # =======================================================================
    print("=" * 70)
    print("PHASE 1: Training Match Outcome Prediction Model")
    print("=" * 70)

    df = generate_mock_dataset(n_matches=8000)
    predictor = MatchOutcomePredictor()
    metrics = predictor.train(df, calibrate=True)

    print(f"  Dataset:   {len(df)} matches")
    print(f"  CV Acc:    {metrics['cv_accuracy_mean']:.3f} (±{metrics['cv_accuracy_std']:.3f})")
    print(f"  Log Loss:  {metrics['log_loss']:.4f}")
    print(f"  Class Dist: {metrics['class_distribution']}")

    # =======================================================================
    # PHASE 2: Generate Predictions for Sample Fixtures
    # =======================================================================
    print("\n" + "=" * 70)
    print("PHASE 2: Predict Probabilities for 5 Sample Fixtures")
    print("=" * 70)

    fixtures = [
        {
            'name': 'Rayon Sports vs APR FC (Rwanda Derby)',
            'features': {
                'home_team_win_rate': 0.55, 'away_team_win_rate': 0.65,
                'home_team_draw_rate': 0.20, 'away_team_draw_rate': 0.15,
                'home_goals_scored_avg': 1.6, 'home_goals_conceded_avg': 1.0,
                'away_goals_scored_avg': 2.0, 'away_goals_conceded_avg': 0.8,
                'home_form_points': 10, 'away_form_points': 13,
                'home_league_position': 3, 'away_league_position': 1,
                'home_points_per_game': 2.0, 'away_points_per_game': 2.5,
                'h2h_home_wins': 2, 'h2h_away_wins': 3, 'h2h_draws': 2,
                'goal_diff_advantage': -0.6, 'position_advantage': -2, 'form_advantage': -3,
            },
        },
        {
            'name': 'Liverpool vs Nottingham Forest (EPL)',
            'features': {
                'home_team_win_rate': 0.72, 'away_team_win_rate': 0.35,
                'home_team_draw_rate': 0.14, 'away_team_draw_rate': 0.22,
                'home_goals_scored_avg': 2.3, 'home_goals_conceded_avg': 0.7,
                'away_goals_scored_avg': 1.1, 'away_goals_conceded_avg': 1.4,
                'home_form_points': 13, 'away_form_points': 6,
                'home_league_position': 1, 'away_league_position': 12,
                'home_points_per_game': 2.6, 'away_points_per_game': 1.3,
                'h2h_home_wins': 4, 'h2h_away_wins': 1, 'h2h_draws': 0,
                'goal_diff_advantage': 2.0, 'position_advantage': 11, 'form_advantage': 7,
            },
        },
        {
            'name': 'Real Madrid vs Barcelona (El Clásico)',
            'features': {
                'home_team_win_rate': 0.60, 'away_team_win_rate': 0.58,
                'home_team_draw_rate': 0.18, 'away_team_draw_rate': 0.17,
                'home_goals_scored_avg': 2.1, 'home_goals_conceded_avg': 0.9,
                'away_goals_scored_avg': 2.3, 'away_goals_conceded_avg': 0.8,
                'home_form_points': 11, 'away_form_points': 12,
                'home_league_position': 2, 'away_league_position': 1,
                'home_points_per_game': 2.3, 'away_points_per_game': 2.4,
                'h2h_home_wins': 3, 'h2h_away_wins': 3, 'h2h_draws': 2,
                'goal_diff_advantage': -0.1, 'position_advantage': -1, 'form_advantage': -1,
            },
        },
        {
            'name': 'TP Mazembe vs AS Vita (Linafoot DRC)',
            'features': {
                'home_team_win_rate': 0.68, 'away_team_win_rate': 0.42,
                'home_team_draw_rate': 0.16, 'away_team_draw_rate': 0.23,
                'home_goals_scored_avg': 1.8, 'home_goals_conceded_avg': 0.6,
                'away_goals_scored_avg': 1.2, 'away_goals_conceded_avg': 1.3,
                'home_form_points': 14, 'away_form_points': 8,
                'home_league_position': 1, 'away_league_position': 5,
                'home_points_per_game': 2.5, 'away_points_per_game': 1.6,
                'h2h_home_wins': 4, 'h2h_away_wins': 1, 'h2h_draws': 1,
                'goal_diff_advantage': 1.3, 'position_advantage': 4, 'form_advantage': 6,
            },
        },
        {
            'name': 'ZESCO United vs Red Arrows (ZSL)',
            'features': {
                'home_team_win_rate': 0.50, 'away_team_win_rate': 0.45,
                'home_team_draw_rate': 0.25, 'away_team_draw_rate': 0.25,
                'home_goals_scored_avg': 1.3, 'home_goals_conceded_avg': 1.1,
                'away_goals_scored_avg': 1.2, 'away_goals_conceded_avg': 1.2,
                'home_form_points': 8, 'away_form_points': 7,
                'home_league_position': 6, 'away_league_position': 8,
                'home_points_per_game': 1.7, 'away_points_per_game': 1.5,
                'h2h_home_wins': 2, 'h2h_away_wins': 2, 'h2h_draws': 3,
                'goal_diff_advantage': 0.1, 'position_advantage': 2, 'form_advantage': 1,
            },
        },
    ]

    for fixture in fixtures:
        probs = predictor.predict(fixture['features'])
        print(f"\n  📌 {fixture['name']}")
        print(f"     Home(1): {probs['1']:.1%}  |  Draw(X): {probs['X']:.1%}  |  Away(2): {probs['2']:.1%}")

    # =======================================================================
    # PHASE 3: Generate FET Multipliers
    # =======================================================================
    print("\n" + "=" * 70)
    print("PHASE 3: FET Multiplier Generation (7% Overround)")
    print("=" * 70)

    for fixture in fixtures:
        probs = predictor.predict(fixture['features'])
        base_mults = compute_base_multipliers(probs, overround=0.07)
        margin = compute_implied_margin(base_mults)

        print(f"\n  📌 {fixture['name']}")
        print(f"     Probabilities: 1={probs['1']:.1%} X={probs['X']:.1%} 2={probs['2']:.1%}")
        print(f"     Multipliers:   1={base_mults['1']}x  X={base_mults['X']}x  2={base_mults['2']}x")
        print(f"     House Margin:  {margin:.1%}")

    # =======================================================================
    # PHASE 4: Dynamic Liability Adjustment
    # =======================================================================
    print("\n" + "=" * 70)
    print("PHASE 4: Dynamic Liability Adjustment Scenarios")
    print("=" * 70)

    # Scenario A: Heavy home bias (common for prem teams)
    print("\n  📊 Scenario A: Liverpool vs Forest — 75% picked Home")
    probs_a = predictor.predict(fixtures[1]['features'])
    result_a = generate_market_multipliers(
        probabilities=probs_a,
        user_pool_percentages={'1': 0.75, 'X': 0.15, '2': 0.10},
        overround=0.07,
    )
    _print_adjustment(result_a)

    # Scenario B: Balanced pool (no adjustment needed)
    print("\n  📊 Scenario B: El Clásico — balanced 40/30/30")
    probs_b = predictor.predict(fixtures[2]['features'])
    result_b = generate_market_multipliers(
        probabilities=probs_b,
        user_pool_percentages={'1': 0.40, 'X': 0.30, '2': 0.30},
        overround=0.07,
    )
    _print_adjustment(result_b)

    # Scenario C: Extreme overload on underdog
    print("\n  📊 Scenario C: ZESCO vs Red Arrows — 85% picked Away upset")
    probs_c = predictor.predict(fixtures[4]['features'])
    result_c = generate_market_multipliers(
        probabilities=probs_c,
        user_pool_percentages={'1': 0.08, 'X': 0.07, '2': 0.85},
        overround=0.07,
    )
    _print_adjustment(result_c)

    # Scenario D: No user data yet (pre-match)
    print("\n  📊 Scenario D: TP Mazembe vs AS Vita — No bets yet")
    probs_d = predictor.predict(fixtures[3]['features'])
    result_d = generate_market_multipliers(
        probabilities=probs_d,
        user_pool_percentages=None,
        overround=0.07,
    )
    _print_adjustment(result_d)

    # =======================================================================
    # PHASE 5: Economy Simulation — 1000 wagers
    # =======================================================================
    print("\n" + "=" * 70)
    print("PHASE 5: FET Economy Simulation (1000 wagers)")
    print("=" * 70)

    import numpy as np
    rng = np.random.default_rng(42)

    probs_sim = predictor.predict(fixtures[1]['features'])  # Liverpool vs Forest
    mults = generate_market_multipliers(
        probs_sim,
        user_pool_percentages={'1': 0.70, 'X': 0.15, '2': 0.15},
        overround=0.07,
    )

    n_wagers = 1000
    wager_amount = 100  # FET per wager

    total_wagered = 0
    total_paid_out = 0
    outcome_counts = {'1': 0, 'X': 0, '2': 0}

    for _ in range(n_wagers):
        # Random user picks an outcome (weighted toward home like the pool)
        user_pick = rng.choice(['1', 'X', '2'], p=[0.70, 0.15, 0.15])
        total_wagered += wager_amount
        outcome_counts[user_pick] += 1

        # Simulate the actual match result (based on ML probabilities)
        actual = rng.choice(['1', 'X', '2'], p=[probs_sim['1'], probs_sim['X'], probs_sim['2']])

        if user_pick == actual:
            # Win: pay out wager × adjusted multiplier
            payout = wager_amount * mults[user_pick]['adjusted_multiplier']
            total_paid_out += payout

    house_profit = total_wagered - total_paid_out
    margin_pct = (house_profit / total_wagered) * 100

    print(f"\n  Fixture: Liverpool vs Forest")
    print(f"  ML Probs: 1={probs_sim['1']:.1%} X={probs_sim['X']:.1%} 2={probs_sim['2']:.1%}")
    print(f"  Wagers: {n_wagers}")
    print(f"  Amount per wager: {wager_amount} FET")
    print(f"  Total wagered: {total_wagered:,.0f} FET")
    print(f"  Total paid out: {total_paid_out:,.0f} FET")
    print(f"  House profit: {house_profit:,.0f} FET")
    print(f"  House margin: {margin_pct:.1f}%")
    print(f"  Outcome distribution: {outcome_counts}")
    print(f"\n  ✅ Economy {'PROFITABLE' if house_profit > 0 else '⚠️  LOSS'}")

    # Save model for deployment
    predictor.save()
    print(f"\n  Model artifacts saved to ./model_artifacts/")
    print("\n" + "=" * 70)
    print("Pipeline complete. Ready for integration.")
    print("=" * 70)


def _print_adjustment(result: dict):
    """Pretty-prints a market multiplier result."""
    for outcome, data in result.items():
        base = data['base_multiplier']
        adj = data['adjusted_multiplier']
        delta = data['adjustment_applied']
        pct = data['user_pool_pct']
        reason = data['adjustment_reason']

        direction = "↓" if delta < 0 else "↑" if delta > 0 else "="
        pct_str = f"{pct:.0%}" if pct is not None else "N/A"

        print(f"     {outcome}: {base}x → {adj}x "
              f"({direction}{abs(delta):.2f}) "
              f"[{pct_str} users] ({reason})")


if __name__ == '__main__':
    main()
