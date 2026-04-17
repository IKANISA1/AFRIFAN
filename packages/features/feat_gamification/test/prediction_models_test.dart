import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────────────────────
  // Helper: parsers
  // ─────────────────────────────────────────────────────────────

  group('PredictionStatus parsing', () {
    test('returns correct status for all known values', () {
      final json = <String, dynamic>{'status': 'won'};
      final result = UserPredictionSummary.fromJson({
        ...json,
        'prediction_id': 'p1',
        'selected_outcome': 'home',
      });
      expect(result.status, PredictionStatus.won);
    });

    test('returns pending for unknown status', () {
      final result = UserPredictionSummary.fromJson({
        'prediction_id': 'p1',
        'selected_outcome': 'home',
        'status': 'unknown_status',
      });
      expect(result.status, PredictionStatus.pending);
    });

    test('returns pending for null status', () {
      final result = UserPredictionSummary.fromJson({
        'prediction_id': 'p1',
        'selected_outcome': 'home',
      });
      expect(result.status, PredictionStatus.pending);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // PredictionDashboard
  // ─────────────────────────────────────────────────────────────

  group('PredictionDashboard', () {
    test('fromJson parses all fields correctly', () {
      final dashboard = PredictionDashboard.fromJson({
        'total_predictions': 42,
        'total_won': 20,
        'total_lost': 15,
        'total_pending': 7,
        'total_fet_earned': 3500,
        'current_streak': 3,
        'win_rate': 0.571,
        'streak_type': 'win',
      });

      expect(dashboard.totalPredictions, 42);
      expect(dashboard.wonCount, 20);
      expect(dashboard.lostCount, 15);
      expect(dashboard.settledCount, 35); // won + lost
      expect(dashboard.activeCount, 7);
      expect(dashboard.totalFetEarned, 3500);
      expect(dashboard.currentStreak, 3);
      expect(dashboard.winRate, 0.571);
      expect(dashboard.streakType, 'win');
    });

    test('fromJson handles missing fields with safe defaults', () {
      final dashboard = PredictionDashboard.fromJson({});

      expect(dashboard.totalPredictions, 0);
      expect(dashboard.wonCount, 0);
      expect(dashboard.lostCount, 0);
      expect(dashboard.settledCount, 0);
      expect(dashboard.activeCount, 0);
      expect(dashboard.totalFetEarned, 0);
      expect(dashboard.currentStreak, 0);
      expect(dashboard.winRate, 0);
      expect(dashboard.streakType, isNull);
    });

    test('empty factory returns all zeros', () {
      final dashboard = PredictionDashboard.empty();
      expect(dashboard.totalPredictions, 0);
      expect(dashboard.totalFetEarned, 0);
      expect(dashboard.winRate, 0);
    });

    test('handles numeric types (int and double) gracefully', () {
      final dashboard = PredictionDashboard.fromJson({
        'total_predictions': 10.0, // double instead of int
        'total_won': 5,
        'total_lost': 3,
        'win_rate': 62, // int instead of double
      });

      expect(dashboard.totalPredictions, 10);
      expect(dashboard.wonCount, 5);
      expect(dashboard.winRate, 62.0);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // PredictionLeaderboardEntry
  // ─────────────────────────────────────────────────────────────

  group('PredictionLeaderboardEntry', () {
    test('fromJson parses all fields', () {
      final entry = PredictionLeaderboardEntry.fromJson({
        'user_id': 'user-123',
        'display_name': 'Jean',
        'wins': 15,
        'total_settled': 20,
        'total_fet_earned': 1500,
        'win_rate': 0.75,
        'trend': 'up',
      }, rank: 1);

      expect(entry.rank, 1);
      expect(entry.userId, 'user-123');
      expect(entry.displayName, 'Jean');
      expect(entry.wins, 15);
      expect(entry.totalSettled, 20);
      expect(entry.totalFetEarned, 1500);
      expect(entry.winRate, 0.75);
      expect(entry.trend, 'up');
    });

    test('fromJson defaults missing fields', () {
      final entry = PredictionLeaderboardEntry.fromJson({}, rank: 5);

      expect(entry.rank, 5);
      expect(entry.userId, '');
      expect(entry.displayName, 'Supporter');
      expect(entry.wins, 0);
      expect(entry.trend, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // MarketOutcomeOption
  // ─────────────────────────────────────────────────────────────

  group('MarketOutcomeOption', () {
    test('fromJson parses correctly', () {
      final option = MarketOutcomeOption.fromJson({
        'key': 'home',
        'label': 'Home Win',
        'odds': 2.5,
      });

      expect(option.key, 'home');
      expect(option.label, 'Home Win');
      expect(option.odds, 2.5);
    });

    test('defaults odds to 1.0', () {
      final option = MarketOutcomeOption.fromJson({
        'key': 'draw',
        'label': 'Draw',
      });

      expect(option.odds, 1.0);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // PredictionMarket
  // ─────────────────────────────────────────────────────────────

  group('PredictionMarket', () {
    test('fromJson parses market group and difficulty tier', () {
      final market = PredictionMarket.fromJson({
        'id': 'm1',
        'slug': 'match_result',
        'name': 'Match Result',
        'short_name': '1X2',
        'market_group': 'match_result',
        'market_category': 'core',
        'bet_type': 'single',
        'difficulty_tier': 'entry',
        'default_fet_value': 100,
        'base_fet': 50,
        'description': 'Predict the match result',
        'outcome_template': [
          {'key': 'home', 'label': 'Home', 'odds': 1.5},
          {'key': 'draw', 'label': 'Draw', 'odds': 3.0},
          {'key': 'away', 'label': 'Away', 'odds': 2.5},
        ],
        'sort_order': 1,
        'league_availability': ['rpl', 'epl'],
      });

      expect(market.id, 'm1');
      expect(market.slug, 'match_result');
      expect(market.marketGroup, MarketGroup.matchResult);
      expect(market.difficultyTier, DifficultyTier.entry);
      expect(market.outcomeTemplate, hasLength(3));
      expect(market.leagueAvailability, ['rpl', 'epl']);
    });

    test('parses all market group values', () {
      for (final entry in {
        'goals': MarketGroup.goals,
        'scorers': MarketGroup.scorers,
        'specials': MarketGroup.specials,
        'outright': MarketGroup.outright,
        'match_betting': MarketGroup.matchBetting,
        'handicap': MarketGroup.handicap,
        'goalscorer': MarketGroup.goalscorer,
        'match_props': MarketGroup.matchProps,
        'corners': MarketGroup.corners,
        'cards': MarketGroup.cards,
        'player_props': MarketGroup.playerProps,
        'match_events': MarketGroup.matchEvents,
        'in_play': MarketGroup.inPlay,
        'combo': MarketGroup.combo,
      }.entries) {
        final market = PredictionMarket.fromJson({
          'market_group': entry.key,
        });
        expect(market.marketGroup, entry.value,
            reason: '${entry.key} should map to ${entry.value}');
      }
    });

    test('unknown market group defaults to matchResult', () {
      final market = PredictionMarket.fromJson({
        'market_group': 'unknown_group',
      });
      expect(market.marketGroup, MarketGroup.matchResult);
    });

    test('parses all difficulty tiers', () {
      for (final entry in {
        'entry': DifficultyTier.entry,
        'mid': DifficultyTier.mid,
        'hard': DifficultyTier.hard,
        'advanced': DifficultyTier.advanced,
      }.entries) {
        final market = PredictionMarket.fromJson({
          'difficulty_tier': entry.key,
        });
        expect(market.difficultyTier, entry.value);
      }
    });
  });

  // ─────────────────────────────────────────────────────────────
  // FixtureMarket
  // ─────────────────────────────────────────────────────────────

  group('FixtureMarket', () {
    test('fromJson with user prediction', () {
      final fm = FixtureMarket.fromJson({
        'fixture_market_id': 'fm1',
        'market_id': 'm1',
        'market_slug': 'match_result',
        'market_name': 'Match Result',
        'market_short_name': '1X2',
        'market_group': 'match_result',
        'market_category': 'core',
        'bet_type': 'single',
        'difficulty_tier': 'entry',
        'description': 'Predict the result',
        'fet_value': 150,
        'outcomes': [
          {'key': 'home', 'label': 'Home'},
        ],
        'is_locked': false,
        'user_prediction': {
          'prediction_id': 'pred-1',
          'selected_outcome': 'home',
          'status': 'pending',
        },
      });

      expect(fm.fixtureMarketId, 'fm1');
      expect(fm.fetValue, 150);
      expect(fm.isLocked, false);
      expect(fm.userPrediction, isNotNull);
      expect(fm.userPrediction!.predictionId, 'pred-1');
      expect(fm.userPrediction!.status, PredictionStatus.pending);
    });

    test('fromJson without user prediction', () {
      final fm = FixtureMarket.fromJson({
        'fixture_market_id': 'fm1',
        'is_locked': true,
      });

      expect(fm.isLocked, true);
      expect(fm.userPrediction, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // UserPrediction
  // ─────────────────────────────────────────────────────────────

  group('UserPrediction', () {
    test('fromJson parses complete prediction', () {
      final pred = UserPrediction.fromJson({
        'id': 'pred-1',
        'fixture_id': 'fix-1',
        'market_slug': 'match_result',
        'market_name': 'Match Result',
        'market_group': 'match_result',
        'home_team': 'Rayon Sports',
        'home_team_short': 'RSP',
        'away_team': 'APR FC',
        'away_team_short': 'APR',
        'kickoff_at': '2026-04-20T15:00:00Z',
        'fixture_status': 'finished',
        'competition_name': 'Rwanda Premier League',
        'selected_outcome': 'home',
        'odds': 1.8,
        'status': 'won',
        'fet_potential': 180,
        'fet_earned': 180,
        'placed_at': '2026-04-19T10:00:00Z',
        'settled_at': '2026-04-20T17:00:00Z',
        'home_score': 2,
        'away_score': 1,
        'slip_id': 'slip-1',
      });

      expect(pred.id, 'pred-1');
      expect(pred.homeTeam, 'Rayon Sports');
      expect(pred.awayTeamShort, 'APR');
      expect(pred.kickoffAt, isNotNull);
      expect(pred.status, PredictionStatus.won);
      expect(pred.fetPotential, 180);
      expect(pred.fetEarned, 180);
      expect(pred.homeScore, 2);
      expect(pred.awayScore, 1);
      expect(pred.slipId, 'slip-1');
      expect(pred.isWon, true);
      expect(pred.isPending, false);
      expect(pred.isSettled, true);
    });

    test('computed getters for status', () {
      final pending = UserPrediction.fromJson({'status': 'pending'});
      expect(pending.isPending, true);
      expect(pending.isWon, false);
      expect(pending.isLost, false);
      expect(pending.isSettled, false);

      final lost = UserPrediction.fromJson({'status': 'lost'});
      expect(lost.isLost, true);
      expect(lost.isSettled, true);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // PredictionPlaceResult
  // ─────────────────────────────────────────────────────────────

  group('PredictionPlaceResult', () {
    test('fromJson recognizes success statuses', () {
      for (final status in ['placed', 'updated', 'created', 'submitted']) {
        final result = PredictionPlaceResult.fromJson({
          'status': status,
          'prediction_id': 'p1',
          'message': 'ok',
        });
        expect(result.isSuccess, true,
            reason: '$status should be treated as success');
        expect(result.isError, false);
      }
    });

    test('fromJson recognizes error status', () {
      final result = PredictionPlaceResult.fromJson({
        'status': 'error',
        'message': 'Market is locked',
      });
      expect(result.isSuccess, false);
      expect(result.isError, true);
      expect(result.message, 'Market is locked');
    });

    test('defaults to error on missing status', () {
      final result = PredictionPlaceResult.fromJson({});
      expect(result.status, 'error');
      expect(result.isError, true);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // PredictionDetail
  // ─────────────────────────────────────────────────────────────

  group('PredictionDetail', () {
    test('isSettled includes void status', () {
      final detail = PredictionDetail.fromJson({'status': 'void'});
      expect(detail.status, PredictionStatus.void_);
      expect(detail.isSettled, true);
    });

    test('hasScoreline requires both scores', () {
      final withBoth = PredictionDetail.fromJson({
        'home_score': 1,
        'away_score': 0,
      });
      expect(withBoth.hasScoreline, true);

      final withNone = PredictionDetail.fromJson({});
      expect(withNone.hasScoreline, false);

      final withOnlyHome = PredictionDetail.fromJson({'home_score': 1});
      expect(withOnlyHome.hasScoreline, false);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // FixtureSummary
  // ─────────────────────────────────────────────────────────────

  group('FixtureSummary', () {
    test('fromJson parses complete fixture', () {
      final fixture = FixtureSummary.fromJson({
        'id': 'f1',
        'competition_slug': 'rpl',
        'competition_name': 'Rwanda Premier League',
        'season_label': '2025-26',
        'matchday': 12,
        'home_team_slug': 'rayon-sports',
        'home_team_name': 'Rayon Sports FC',
        'home_team_short_name': 'RSP',
        'away_team_slug': 'apr-fc',
        'away_team_name': 'APR FC',
        'away_team_short_name': 'APR',
        'kickoff_at': '2026-04-20T15:00:00Z',
        'venue_name': 'Amahoro Stadium',
        'status': 'scheduled',
        'home_team_logo_url': 'https://cdn.example.com/rsp.png',
        'away_team_logo_url': 'https://cdn.example.com/apr.png',
      });

      expect(fixture.competitionSlug, 'rpl');
      expect(fixture.homeTeamName, 'Rayon Sports FC');
      expect(fixture.awayTeamShort, 'APR');
      expect(fixture.matchday, 12);
      expect(fixture.isScheduled, true);
      expect(fixture.isPredictable, true);
      expect(fixture.isLive, false);
      expect(fixture.isFinished, false);
      expect(fixture.fixtureLabel, 'RSP vs APR');
    });

    test('status helpers', () {
      expect(
        FixtureSummary.fromJson({'status': 'live'}).isLive,
        true,
      );
      expect(
        FixtureSummary.fromJson({'status': 'finished'}).isFinished,
        true,
      );
      expect(
        FixtureSummary.fromJson({'status': 'finished'}).isPredictable,
        false,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────
  // MatchCenterStat
  // ─────────────────────────────────────────────────────────────

  group('MatchCenterStat', () {
    test('fromJson parses stat correctly', () {
      final stat = MatchCenterStat.fromJson({
        'label': 'Possession',
        'left_value': 58.5,
        'right_value': 41.5,
        'left_display': '58%',
        'right_display': '42%',
      });

      expect(stat.label, 'Possession');
      expect(stat.leftValue, 58.5);
      expect(stat.rightDisplay, '42%');
    });
  });

  // ─────────────────────────────────────────────────────────────
  // MatchCenterLineup
  // ─────────────────────────────────────────────────────────────

  group('MatchCenterLineup', () {
    test('fromJson parses lineup with players', () {
      final lineup = MatchCenterLineup.fromJson({
        'formation': '4-3-3',
        'coach_name': 'Coach Carlos',
        'is_confirmed': true,
        'source': 'api-football',
        'starters': [
          {'name': 'Fiston', 'number': 1, 'position': 'GK'},
          {'name': 'Jean', 'number': 7, 'position': 'FW'},
        ],
        'substitutes': [
          {'name': 'Eric', 'number': 12, 'position': 'GK', 'is_starter': false},
        ],
      });

      expect(lineup.formation, '4-3-3');
      expect(lineup.coachName, 'Coach Carlos');
      expect(lineup.isConfirmed, true);
      expect(lineup.starters, hasLength(2));
      expect(lineup.substitutes, hasLength(1));
      expect(lineup.starters.first.name, 'Fiston');
      expect(lineup.substitutes.first.isStarter, false);
    });

    test('fromJson handles empty/missing player lists', () {
      final lineup = MatchCenterLineup.fromJson({});
      expect(lineup.starters, isEmpty);
      expect(lineup.substitutes, isEmpty);
      expect(lineup.isConfirmed, false);
      expect(lineup.source, 'manual');
    });
  });

  // ─────────────────────────────────────────────────────────────
  // JackpotRoundFixture & PredictionJackpotRound
  // ─────────────────────────────────────────────────────────────

  group('PredictionJackpotRound', () {
    test('fromJson parses round with fixtures', () {
      final round = PredictionJackpotRound.fromJson({
        'id': 'jr1',
        'club_id': 24,
        'slug': 'weekly-12',
        'title': 'Weekly Jackpot',
        'description': 'Predict all 5 matches',
        'status': 'open',
        'prize_pool_fet': 50000,
        'max_legs': 5,
        'max_entries_per_user': 3,
        'user_entry_count': 1,
        'bonus_entry_count': 0,
        'remaining_entries': 2,
        'can_enter': true,
        'fixtures': [
          {
            'fixture_market_id': 'fm1',
            'fixture_id': 'f1',
            'competition_name': 'RPL',
            'competition_slug': 'rpl',
            'home_team_name': 'Rayon Sports',
            'home_team_short_name': 'RSP',
            'away_team_name': 'APR FC',
            'away_team_short_name': 'APR',
            'market_name': 'Match Result',
            'market_short_name': '1X2',
            'outcomes': [
              {'key': 'home', 'label': '1'},
              {'key': 'draw', 'label': 'X'},
              {'key': 'away', 'label': '2'},
            ],
          },
        ],
      });

      expect(round.id, 'jr1');
      expect(round.clubId, 24);
      expect(round.prizePoolFet, 50000);
      expect(round.maxLegs, 5);
      expect(round.canEnter, true);
      expect(round.remainingEntries, 2);
      expect(round.fixtures, hasLength(1));
      expect(round.fixtures.first.fixtureLabel, 'RSP vs APR');
      expect(round.fixtures.first.outcomes, hasLength(3));
    });

    test('fromJson handles missing fixtures list', () {
      final round = PredictionJackpotRound.fromJson({'id': 'jr2'});
      expect(round.fixtures, isEmpty);
      expect(round.canEnter, false);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // FriendChallengeSummary
  // ─────────────────────────────────────────────────────────────

  group('FriendChallengeSummary', () {
    test('fromJson parses challenge', () {
      final challenge = FriendChallengeSummary.fromJson({
        'id': 'ch1',
        'status': 'accepted',
        'fixture_id': 'f1',
        'fixture_market_id': 'fm1',
        'competition_name': 'RPL',
        'home_team_name': 'Rayon Sports',
        'away_team_name': 'APR FC',
        'market_name': 'Match Result',
        'market_short_name': '1X2',
        'challenger_user_id': 'u1',
        'challenger_display_name': 'Jean',
        'challenger_outcome': 'home',
        'opponent_user_id': 'u2',
        'opponent_display_name': 'Eric',
        'opponent_outcome': 'away',
        'is_challenger': true,
        'challenge_note': 'No way APR wins!',
      });

      expect(challenge.status, 'accepted');
      expect(challenge.challengerDisplayName, 'Jean');
      expect(challenge.opponentOutcome, 'away');
      expect(challenge.isChallenger, true);
      expect(challenge.challengeNote, 'No way APR wins!');
    });
  });
}
