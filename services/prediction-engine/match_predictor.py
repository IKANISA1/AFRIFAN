"""
=============================================================================
TASK 1: Match Outcome Prediction Model
=============================================================================
Trains a classifier on historical match data (API-Football features) to
predict the probability of Home Win (1), Draw (X), and Away Win (2).

Designed for the Africlub FET prediction economy.
Uses scikit-learn's predict_proba for calibrated 3-way probability output.
=============================================================================
"""

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.calibration import CalibratedClassifierCV
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import classification_report, log_loss
import joblib
from typing import Dict, Tuple
import os

# ---------------------------------------------------------------------------
# 1. Mock Dataset Generator
# ---------------------------------------------------------------------------
# Simulates the feature set you'd extract from API-Football's /fixtures and
# /standings endpoints after the sync pipeline populates your DB.
# ---------------------------------------------------------------------------

def generate_mock_dataset(n_matches: int = 5000, seed: int = 42) -> pd.DataFrame:
    """
    Generates a realistic mock dataset of historical football matches.

    Features are designed to mirror what API-Football provides after
    aggregation (rolling averages, form, etc.).

    Returns:
        DataFrame with features and Match_Outcome column ('1', 'X', '2')
    """
    rng = np.random.default_rng(seed)

    # --- Team strength features (derived from standings/history) ---
    home_team_win_rate       = rng.beta(5, 3, n_matches)       # Skewed toward ~0.6 (home advantage)
    away_team_win_rate       = rng.beta(3, 4, n_matches)       # Skewed toward ~0.4
    home_team_draw_rate      = rng.beta(2, 5, n_matches)       # Typically ~0.25
    away_team_draw_rate      = rng.beta(2, 5, n_matches)

    # --- Goals features (from fixtures history) ---
    home_goals_scored_avg    = rng.normal(1.5, 0.5, n_matches).clip(0.2, 4.0)
    home_goals_conceded_avg  = rng.normal(1.0, 0.4, n_matches).clip(0.1, 3.5)
    away_goals_scored_avg    = rng.normal(1.2, 0.5, n_matches).clip(0.1, 3.5)
    away_goals_conceded_avg  = rng.normal(1.3, 0.5, n_matches).clip(0.2, 4.0)

    # --- Form features (last 5 matches: W=3, D=1, L=0 -> max 15) ---
    home_form_points         = rng.integers(0, 16, n_matches)
    away_form_points         = rng.integers(0, 16, n_matches)

    # --- Standings features ---
    home_league_position     = rng.integers(1, 21, n_matches)  # 1-20 for a 20-team league
    away_league_position     = rng.integers(1, 21, n_matches)
    home_points_per_game     = rng.normal(1.8, 0.5, n_matches).clip(0.3, 3.0)
    away_points_per_game     = rng.normal(1.5, 0.5, n_matches).clip(0.2, 3.0)

    # --- Head-to-head features ---
    h2h_home_wins            = rng.integers(0, 6, n_matches)
    h2h_away_wins            = rng.integers(0, 6, n_matches)
    h2h_draws                = rng.integers(0, 4, n_matches)

    # --- Derived features ---
    goal_diff_advantage      = (home_goals_scored_avg - away_goals_conceded_avg) - \
                               (away_goals_scored_avg - home_goals_conceded_avg)
    position_advantage       = away_league_position - home_league_position  # Positive = home is better
    form_advantage           = home_form_points - away_form_points

    # --- Generate realistic outcomes based on features ---
    # Home win probability increases with: higher win rate, better form, better position
    home_strength = (
        0.30 * home_team_win_rate +
        0.15 * (home_goals_scored_avg / 4.0) +
        0.10 * (home_form_points / 15.0) +
        0.10 * ((21 - home_league_position) / 20.0) +
        0.10 * (goal_diff_advantage.clip(-2, 2) + 2) / 4.0 +
        0.05 * (h2h_home_wins / 5.0) +
        0.20  # Home advantage base
    )

    away_strength = (
        0.30 * away_team_win_rate +
        0.15 * (away_goals_scored_avg / 4.0) +
        0.10 * (away_form_points / 15.0) +
        0.10 * ((21 - away_league_position) / 20.0) +
        0.05 * (h2h_away_wins / 5.0) +
        0.10  # Slight away disadvantage
    )

    draw_tendency = (
        0.15 +
        0.20 * home_team_draw_rate +
        0.20 * away_team_draw_rate +
        0.15 * (1.0 - abs(home_strength - away_strength))  # More likely when teams are even
    )

    # Normalize to probabilities
    total = home_strength + away_strength + draw_tendency
    p_home = home_strength / total
    p_draw = draw_tendency / total
    p_away = away_strength / total

    # Sample outcomes from the probability distributions
    outcomes = []
    for ph, pd_, pa in zip(p_home, p_draw, p_away):
        outcome = rng.choice(['1', 'X', '2'], p=[ph, pd_, pa])
        outcomes.append(outcome)

    # --- Assemble DataFrame ---
    df = pd.DataFrame({
        # Raw features (what the model sees)
        'home_team_win_rate':       home_team_win_rate,
        'away_team_win_rate':       away_team_win_rate,
        'home_team_draw_rate':      home_team_draw_rate,
        'away_team_draw_rate':      away_team_draw_rate,
        'home_goals_scored_avg':    home_goals_scored_avg,
        'home_goals_conceded_avg':  home_goals_conceded_avg,
        'away_goals_scored_avg':    away_goals_scored_avg,
        'away_goals_conceded_avg':  away_goals_conceded_avg,
        'home_form_points':         home_form_points,
        'away_form_points':         away_form_points,
        'home_league_position':     home_league_position,
        'away_league_position':     away_league_position,
        'home_points_per_game':     home_points_per_game,
        'away_points_per_game':     away_points_per_game,
        'h2h_home_wins':            h2h_home_wins,
        'h2h_away_wins':            h2h_away_wins,
        'h2h_draws':                h2h_draws,
        # Engineered features
        'goal_diff_advantage':      goal_diff_advantage,
        'position_advantage':       position_advantage,
        'form_advantage':           form_advantage,
        # Target
        'match_outcome':            outcomes,
    })

    return df


# ---------------------------------------------------------------------------
# 2. Feature Engineering Pipeline
# ---------------------------------------------------------------------------

FEATURE_COLUMNS = [
    'home_team_win_rate',
    'away_team_win_rate',
    'home_team_draw_rate',
    'away_team_draw_rate',
    'home_goals_scored_avg',
    'home_goals_conceded_avg',
    'away_goals_scored_avg',
    'away_goals_conceded_avg',
    'home_form_points',
    'away_form_points',
    'home_league_position',
    'away_league_position',
    'home_points_per_game',
    'away_points_per_game',
    'h2h_home_wins',
    'h2h_away_wins',
    'h2h_draws',
    'goal_diff_advantage',
    'position_advantage',
    'form_advantage',
]

TARGET_COLUMN = 'match_outcome'

# Canonical outcome order — always [1, X, 2]
OUTCOME_LABELS = ['1', 'X', '2']


# ---------------------------------------------------------------------------
# 3. Model Training
# ---------------------------------------------------------------------------

class MatchOutcomePredictor:
    """
    Trains a calibrated classifier to predict match outcome probabilities.

    Uses Platt scaling (CalibratedClassifierCV) on top of a Random Forest
    to ensure predict_proba outputs are well-calibrated — critical for
    converting probabilities to fair multipliers.
    """

    def __init__(self):
        self.scaler = StandardScaler()
        self.model = None
        self._is_fitted = False

    def train(
        self,
        df: pd.DataFrame,
        test_size: float = 0.2,
        n_estimators: int = 200,
        calibrate: bool = True,
    ) -> Dict:
        """
        Trains and evaluates the prediction model.

        Args:
            df: DataFrame with FEATURE_COLUMNS and TARGET_COLUMN
            test_size: Fraction held out for evaluation
            n_estimators: Number of trees in the Random Forest
            calibrate: Whether to apply probability calibration

        Returns:
            Dict with evaluation metrics
        """
        X = df[FEATURE_COLUMNS].values
        y = df[TARGET_COLUMN].values

        # Split
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=test_size, random_state=42, stratify=y
        )

        # Scale features
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)

        # Base classifier: Random Forest with balanced class weights
        # (handles the natural imbalance where home wins are more common)
        base_model = RandomForestClassifier(
            n_estimators=n_estimators,
            max_depth=12,
            min_samples_leaf=20,
            class_weight='balanced',
            random_state=42,
            n_jobs=-1,
        )

        if calibrate:
            # Calibrate probabilities using isotonic regression
            # This ensures predict_proba outputs are reliable for multiplier math
            self.model = CalibratedClassifierCV(
                estimator=base_model,
                method='isotonic',
                cv=5,
            )
        else:
            self.model = base_model

        # Fit
        self.model.fit(X_train_scaled, y_train)
        self._is_fitted = True

        # Evaluate
        y_pred = self.model.predict(X_test_scaled)
        y_proba = self.model.predict_proba(X_test_scaled)

        # Ensure class order matches OUTCOME_LABELS
        class_order = list(self.model.classes_)

        metrics = {
            'classification_report': classification_report(
                y_test, y_pred, target_names=OUTCOME_LABELS, output_dict=True
            ),
            'log_loss': log_loss(y_test, y_proba, labels=OUTCOME_LABELS),
            'class_distribution': {
                label: int((y == label).sum()) for label in OUTCOME_LABELS
            },
            'class_order': class_order,
            'test_size': len(y_test),
            'train_size': len(y_train),
        }

        # Cross-validation score on full training set
        cv_scores = cross_val_score(
            base_model, X_train_scaled, y_train, cv=5, scoring='accuracy'
        )
        metrics['cv_accuracy_mean'] = float(cv_scores.mean())
        metrics['cv_accuracy_std'] = float(cv_scores.std())

        return metrics

    def predict(self, features: Dict[str, float]) -> Dict[str, float]:
        """
        Predicts outcome probabilities for a single fixture.

        Args:
            features: Dict mapping feature names to values
                      (must contain all FEATURE_COLUMNS keys)

        Returns:
            Dict with keys '1', 'X', '2' and probability values (0.0 - 1.0)
            Example: {'1': 0.55, 'X': 0.22, '2': 0.23}
        """
        if not self._is_fitted:
            raise RuntimeError("Model not trained. Call train() first.")

        # Build feature vector in canonical column order
        feature_vector = np.array(
            [[features[col] for col in FEATURE_COLUMNS]]
        )
        feature_vector_scaled = self.scaler.transform(feature_vector)

        # Get calibrated probabilities
        proba = self.model.predict_proba(feature_vector_scaled)[0]

        # Map to canonical outcome labels
        class_order = list(self.model.classes_)
        result = {}
        for label in OUTCOME_LABELS:
            idx = class_order.index(label)
            result[label] = float(proba[idx])

        return result

    def predict_batch(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Predicts outcome probabilities for multiple fixtures.

        Args:
            df: DataFrame with FEATURE_COLUMNS

        Returns:
            DataFrame with columns 'prob_home', 'prob_draw', 'prob_away'
        """
        if not self._is_fitted:
            raise RuntimeError("Model not trained. Call train() first.")

        X = df[FEATURE_COLUMNS].values
        X_scaled = self.scaler.transform(X)
        proba = self.model.predict_proba(X_scaled)

        class_order = list(self.model.classes_)
        result_df = pd.DataFrame({
            'prob_home': proba[:, class_order.index('1')],
            'prob_draw': proba[:, class_order.index('X')],
            'prob_away': proba[:, class_order.index('2')],
        })

        return result_df

    def save(self, path: str = 'model_artifacts') -> None:
        """Persists model + scaler to disk."""
        os.makedirs(path, exist_ok=True)
        joblib.dump(self.model, os.path.join(path, 'match_outcome_model.joblib'))
        joblib.dump(self.scaler, os.path.join(path, 'feature_scaler.joblib'))

    def load(self, path: str = 'model_artifacts') -> None:
        """Loads model + scaler from disk."""
        self.model = joblib.load(os.path.join(path, 'match_outcome_model.joblib'))
        self.scaler = joblib.load(os.path.join(path, 'feature_scaler.joblib'))
        self._is_fitted = True


# ---------------------------------------------------------------------------
# Entry point: Train and evaluate
# ---------------------------------------------------------------------------

if __name__ == '__main__':
    print("=" * 70)
    print("TASK 1: Training Match Outcome Prediction Model")
    print("=" * 70)

    # Generate data
    df = generate_mock_dataset(n_matches=8000)
    print(f"\nDataset: {len(df)} matches")
    print(f"Outcome distribution:\n{df['match_outcome'].value_counts().to_string()}\n")

    # Train
    predictor = MatchOutcomePredictor()
    metrics = predictor.train(df, calibrate=True)

    print(f"Cross-validation accuracy: {metrics['cv_accuracy_mean']:.3f} "
          f"(±{metrics['cv_accuracy_std']:.3f})")
    print(f"Log loss (calibration quality): {metrics['log_loss']:.4f}")
    print(f"\nClassification Report:")
    report_df = pd.DataFrame(metrics['classification_report']).T
    print(report_df.to_string())

    # Example prediction
    print("\n" + "-" * 70)
    print("Example: Strong home team vs weak away team")
    print("-" * 70)

    example_features = {
        'home_team_win_rate':       0.70,
        'away_team_win_rate':       0.30,
        'home_team_draw_rate':      0.15,
        'away_team_draw_rate':      0.20,
        'home_goals_scored_avg':    2.1,
        'home_goals_conceded_avg':  0.8,
        'away_goals_scored_avg':    0.9,
        'away_goals_conceded_avg':  1.7,
        'home_form_points':         12,
        'away_form_points':         5,
        'home_league_position':     3,
        'away_league_position':     16,
        'home_points_per_game':     2.3,
        'away_points_per_game':     1.0,
        'h2h_home_wins':            3,
        'h2h_away_wins':            1,
        'h2h_draws':                1,
        'goal_diff_advantage':      1.5,
        'position_advantage':       13,
        'form_advantage':           7,
    }

    probs = predictor.predict(example_features)
    print(f"  Home Win (1): {probs['1']:.1%}")
    print(f"  Draw    (X): {probs['X']:.1%}")
    print(f"  Away Win (2): {probs['2']:.1%}")

    # Save model
    predictor.save()
    print(f"\nModel saved to ./model_artifacts/")
