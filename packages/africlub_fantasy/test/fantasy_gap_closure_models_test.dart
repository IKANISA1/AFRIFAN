import 'package:africlub_fantasy/models/fantasy_notification_topic.dart';
import 'package:africlub_fantasy/models/league_h2h_fixture.dart';
import 'package:africlub_fantasy/models/world_cup_bracket_match.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification topic parses booleans with sensible defaults', () {
    final topic = FantasyNotificationTopic.fromJson(<String, dynamic>{
      'competition_id': 'comp-1',
      'slug': 'wc-2026',
      'topic': 'fantasy_wc_2026',
      'enabled': false,
    });

    expect(topic.competitionId, 'comp-1');
    expect(topic.enabled, isFalse);
    expect(topic.deadlineAlerts, isTrue);
    expect(topic.gameplayAlerts, isTrue);
    expect(topic.leagueAlerts, isTrue);
  });

  test('head-to-head fixture exposes score and participation helpers', () {
    final fixture = LeagueH2HFixture.fromJson(<String, dynamic>{
      'id': 'fix-1',
      'league_id': 'league-1',
      'gameweek_id': 'gw-1',
      'gameweek_number': 3,
      'gameweek_name': 'Gameweek 3',
      'round_number': 2,
      'home_entry_id': 'entry-a',
      'home_team_name': 'Alpha FC',
      'away_entry_id': 'entry-b',
      'away_team_name': 'Bravo FC',
      'home_points': 61,
      'away_points': 54,
      'winner_entry_id': 'entry-a',
      'status': 'finished',
    });

    expect(fixture.scoreLabel(), '61 - 54');
    expect(fixture.involvesEntry('entry-a'), isTrue);
    expect(fixture.involvesEntry('entry-z'), isFalse);
    expect(fixture.isFinished, isTrue);
  });

  test('world cup bracket match derives live and finished states', () {
    final liveMatch = WorldCupBracketMatch.fromJson(<String, dynamic>{
      'stage': 'QF',
      'stage_order': 4,
      'label': 'Quarter-final 1',
      'fixture_id': 'fixture-1',
      'status_short': '1H',
      'home_team_name': 'Rwanda',
      'away_team_name': 'Ghana',
      'home_goals': 1,
      'away_goals': 0,
    });
    final finalMatch = WorldCupBracketMatch.fromJson(<String, dynamic>{
      'stage': 'Final',
      'stage_order': 6,
      'label': 'Final',
      'fixture_id': 'fixture-2',
      'status_short': 'FT',
      'home_team_name': 'Nigeria',
      'away_team_name': 'Senegal',
      'home_goals': 2,
      'away_goals': 1,
    });

    expect(liveMatch.isLive, isTrue);
    expect(liveMatch.isFinished, isFalse);
    expect(finalMatch.isFinished, isTrue);
    expect(finalMatch.scoreLabel, '2 - 1');
  });
}
