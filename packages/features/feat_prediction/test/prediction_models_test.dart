import 'package:feat_prediction/src/models/prediction_models.dart';
import 'package:feat_prediction/src/models/prediction_stats_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PredictionModels', () {
    group('PredictionMarket', () {
      test('parses valid JSON correctly', () {
        final json = <String, dynamic>{
          'id': 'abc-123',
          'slug': '1x2',
          'name': 'Match Result',
          'short_name': '1X2',
          'market_group': 'match_result',
          'difficulty_tier': 'entry',
          'default_fet_value': 100,
          'description': 'Predict the match result.',
          'outcome_template': [
            {'key': 'home', 'label': 'Home Win'},
            {'key': 'draw', 'label': 'Draw'},
            {'key': 'away', 'label': 'Away Win'},
          ],
          'sort_order': 10,
        };

        final market = PredictionMarket.fromJson(json);
        expect(market.slug, '1x2');
        expect(market.name, 'Match Result');
        expect(market.marketGroup, MarketGroup.matchResult);
        expect(market.difficultyTier, DifficultyTier.entry);
        expect(market.defaultFetValue, 100);
        expect(market.outcomeTemplate.length, 3);
        expect(market.outcomeTemplate[0].key, 'home');
        expect(market.outcomeTemplate[2].label, 'Away Win');
      });

      test('handles null/missing fields defensively', () {
        final json = <String, dynamic>{};
        final market = PredictionMarket.fromJson(json);
        expect(market.id, '');
        expect(market.slug, '');
        expect(market.marketGroup, MarketGroup.matchResult);
        expect(market.difficultyTier, DifficultyTier.entry);
        expect(market.defaultFetValue, 100);
        expect(market.outcomeTemplate, isEmpty);
      });
    });

    group('FixtureMarket', () {
      test('parses with user prediction', () {
        final json = <String, dynamic>{
          'fixture_market_id': 'fm-1',
          'market_id': 'm-1',
          'market_slug': 'btts',
          'market_name': 'Both Teams to Score',
          'market_short_name': 'BTTS',
          'market_group': 'goals',
          'difficulty_tier': 'entry',
          'description': 'Both teams to score.',
          'fet_value': 100,
          'outcomes': [
            {'key': 'yes', 'label': 'Yes'},
            {'key': 'no', 'label': 'No'},
          ],
          'is_locked': false,
          'user_prediction': {
            'prediction_id': 'pred-1',
            'selected_outcome': 'yes',
            'status': 'pending',
          },
        };

        final fm = FixtureMarket.fromJson(json);
        expect(fm.marketSlug, 'btts');
        expect(fm.marketGroup, MarketGroup.goals);
        expect(fm.outcomes.length, 2);
        expect(fm.userPrediction, isNotNull);
        expect(fm.userPrediction!.selectedOutcome, 'yes');
        expect(fm.userPrediction!.status, PredictionStatus.pending);
      });

      test('parses without user prediction', () {
        final json = <String, dynamic>{
          'fixture_market_id': 'fm-2',
          'market_id': 'm-2',
          'market_slug': '1x2',
          'market_name': 'Match Result',
          'market_short_name': '1X2',
          'market_group': 'match_result',
          'difficulty_tier': 'mid',
          'description': 'Match result.',
          'fet_value': 150,
          'outcomes': [],
          'is_locked': false,
          'user_prediction': null,
        };

        final fm = FixtureMarket.fromJson(json);
        expect(fm.userPrediction, isNull);
        expect(fm.difficultyTier, DifficultyTier.mid);
      });
    });

    group('UserPrediction', () {
      test('parses active prediction JSON', () {
        final json = <String, dynamic>{
          'id': 'pred-1',
          'fixture_id': 'fix-1',
          'market_slug': '1x2',
          'market_name': '1X2',
          'market_group': 'match_result',
          'home_team': 'Rayon Sports',
          'home_team_short': 'RSP',
          'away_team': 'APR FC',
          'away_team_short': 'APR',
          'kickoff_at': '2026-04-20T15:00:00Z',
          'fixture_status': 'scheduled',
          'competition_name': 'RPL',
          'selected_outcome': 'home',
          'status': 'pending',
          'fet_potential': 100,
          'fet_earned': 0,
          'placed_at': '2026-04-14T12:00:00Z',
          'settled_at': null,
          'slip_id': 'slip-1',
        };

        final pred = UserPrediction.fromJson(json);
        expect(pred.isPending, isTrue);
        expect(pred.isSettled, isFalse);
        expect(pred.homeTeam, 'Rayon Sports');
        expect(pred.selectedOutcome, 'home');
        expect(pred.fetPotential, 100);
      });

      test('parses settled won prediction', () {
        final json = <String, dynamic>{
          'id': 'pred-2',
          'fixture_id': 'fix-2',
          'market_slug': 'btts',
          'market_name': 'BTTS',
          'market_group': 'goals',
          'home_team': 'Liverpool',
          'home_team_short': 'LIV',
          'away_team': 'Arsenal',
          'away_team_short': 'ARS',
          'kickoff_at': '2026-04-19T14:30:00Z',
          'fixture_status': 'finished',
          'competition_name': 'EPL',
          'selected_outcome': 'yes',
          'status': 'won',
          'fet_potential': 0,
          'fet_earned': 100,
          'placed_at': '2026-04-18T09:00:00Z',
          'settled_at': '2026-04-19T16:45:00Z',
          'home_score': 2,
          'away_score': 1,
        };

        final pred = UserPrediction.fromJson(json);
        expect(pred.isWon, isTrue);
        expect(pred.isSettled, isTrue);
        expect(pred.fetEarned, 100);
        expect(pred.homeScore, 2);
        expect(pred.awayScore, 1);
      });
    });

    group('PredictionPlaceResult', () {
      test('parses success response', () {
        final json = <String, dynamic>{
          'status': 'placed',
          'prediction_id': 'pred-99',
          'selected_outcome': 'over',
          'fet_potential': 100,
          'message': 'Prediction placed successfully.',
          'slip_id': 'slip-55',
        };

        final result = PredictionPlaceResult.fromJson(json);
        expect(result.isSuccess, isTrue);
        expect(result.isError, isFalse);
        expect(result.fetPotential, 100);
      });

      test('parses error response', () {
        final json = <String, dynamic>{
          'status': 'error',
          'prediction_id': '',
          'selected_outcome': '',
          'fet_potential': 0,
          'message': 'This market is locked.',
        };

        final result = PredictionPlaceResult.fromJson(json);
        expect(result.isError, isTrue);
        expect(result.isSuccess, isFalse);
      });
    });

    group('FixtureSummary', () {
      test('correctly derives predictable state', () {
        final scheduled = FixtureSummary.fromJson(<String, dynamic>{
          'id': 'f-1',
          'status': 'scheduled',
          'competition_slug': 'rwanda-premier-league',
          'competition_name': 'RPL',
          'season_label': '2026',
          'home_team_name': 'Rayon',
          'home_team_short_name': 'RSP',
          'away_team_name': 'APR',
          'away_team_short_name': 'APR',
        });
        expect(scheduled.isPredictable, isTrue);
        expect(scheduled.isLive, isFalse);

        final live = FixtureSummary.fromJson(<String, dynamic>{
          'id': 'f-2',
          'status': 'live',
          'competition_slug': 'epl',
          'competition_name': 'EPL',
          'season_label': '2025/2026',
          'home_team_name': 'Liverpool',
          'home_team_short_name': 'LIV',
          'away_team_name': 'Arsenal',
          'away_team_short_name': 'ARS',
        });
        expect(live.isPredictable, isFalse);
        expect(live.isLive, isTrue);
      });
    });

    group('PredictionStats', () {
      test('empty() returns zero values', () {
        final stats = PredictionStats.empty();
        expect(stats.totalPredictions, 0);
        expect(stats.totalWon, 0);
        expect(stats.totalLost, 0);
        expect(stats.hasHistory, isFalse);
        expect(stats.isOnWinStreak, isFalse);
        expect(stats.isOnLoseStreak, isFalse);
      });

      test('parses full JSON with win streak', () {
        final json = <String, dynamic>{
          'total_predictions': 25,
          'total_won': 15,
          'total_lost': 10,
          'total_pending': 3,
          'total_fet_earned': 2500,
          'win_rate': 60.0,
          'current_streak': 5,
          'streak_type': 'won',
        };

        final stats = PredictionStats.fromJson(json);
        expect(stats.totalPredictions, 25);
        expect(stats.totalWon, 15);
        expect(stats.winRate, 60.0);
        expect(stats.hasHistory, isTrue);
        expect(stats.isOnWinStreak, isTrue);
        expect(stats.isOnLoseStreak, isFalse);
      });

      test('detects lose streak at 3+', () {
        final json = <String, dynamic>{
          'total_predictions': 10,
          'total_won': 4,
          'total_lost': 6,
          'total_pending': 0,
          'total_fet_earned': 400,
          'win_rate': 40.0,
          'current_streak': 3,
          'streak_type': 'lost',
        };

        final stats = PredictionStats.fromJson(json);
        expect(stats.isOnLoseStreak, isTrue);
        expect(stats.isOnWinStreak, isFalse);
      });

      test('handles missing/null fields defensively', () {
        final stats = PredictionStats.fromJson(<String, dynamic>{});
        expect(stats.totalPredictions, 0);
        expect(stats.winRate, 0);
        expect(stats.currentStreak, 0);
        expect(stats.streakType, isNull);
        expect(stats.hasHistory, isFalse);
      });
    });

    group('PredictionLeaderboardRow', () {
      test('parses valid JSON', () {
        final json = <String, dynamic>{
          'user_id': 'user-abc',
          'display_name': 'Kagame Fan',
          'wins': 12,
          'total_settled': 20,
          'total_fet_earned': 1800,
          'win_rate': 60.0,
        };

        final row = PredictionLeaderboardRow.fromJson(json);
        expect(row.userId, 'user-abc');
        expect(row.displayName, 'Kagame Fan');
        expect(row.wins, 12);
        expect(row.totalSettled, 20);
        expect(row.totalFetEarned, 1800);
        expect(row.winRate, 60.0);
      });

      test('handles missing fields with defaults', () {
        final row = PredictionLeaderboardRow.fromJson(<String, dynamic>{});
        expect(row.userId, '');
        expect(row.displayName, 'Supporter');
        expect(row.wins, 0);
        expect(row.totalFetEarned, 0);
      });
    });

    group('PredictionPlaceResult acca compat', () {
      test('constructs with only status and message', () {
        const result = PredictionPlaceResult(
          status: 'error',
          message: 'Acca requires 2+ legs.',
        );
        expect(result.isError, isTrue);
        expect(result.predictionId, '');
        expect(result.selectedOutcome, '');
        expect(result.fetPotential, 0);
      });

      test('parses acca success response', () {
        final json = <String, dynamic>{
          'status': 'placed',
          'slip_id': 'slip-acca-1',
          'prediction_id': '',
          'selected_outcome': '',
          'fet_potential': 450,
          'message': '3-leg acca placed successfully.',
        };

        final result = PredictionPlaceResult.fromJson(json);
        expect(result.isSuccess, isTrue);
        expect(result.slipId, 'slip-acca-1');
        expect(result.fetPotential, 450);
      });
    });
  });
}
