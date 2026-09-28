import 'package:feat_club/src/repositories/gikundiro_public_club_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'news uses the attributed external story and rejects incomplete rows',
    () {
      final published = DateTime.now().toUtc().subtract(
        const Duration(days: 1),
      );
      final row = <String, dynamic>{
        'id': 'story-1',
        'title': 'Rayon Sports update',
        'excerpt': 'A verified source summary.',
        'category': 'Matchday',
        'source_label': 'Umuseke',
        'source_url': 'https://umuseke.rw/story',
        'published_at': published.toIso8601String(),
      };
      final story = mapGikundiroNews(row);
      expect(story?.id, 'gikundiro-story-1');
      expect(story?.sourceUrl, 'https://umuseke.rw/story');
      expect(story?.imageUrl, isNull);
      expect(mapGikundiroNews({...row, 'excerpt': ''}), isNull);
      expect(
        mapGikundiroNews({...row, 'source_url': 'http://bad.test'}),
        isNull,
      );
    },
  );

  test('player portraits require approved squad-scoped media', () {
    final row = <String, dynamic>{
      'id': 'player-1',
      'display_name': 'Rayon Player',
      'squad_number': 7,
      'specific_position': 'Forward',
      'nationality': 'Rwanda',
    };
    final asset = <String, dynamic>{
      'asset_url': 'https://gikundiro.com/player.jpg',
      'usage_rights': 'official-owned-channel-media',
      'usage_scopes': ['squad', 'player-profile'],
    };
    expect(
      mapGikundiroPlayer(row, asset)?.imageUrl,
      'https://gikundiro.com/player.jpg',
    );
    expect(
      mapGikundiroPlayer(row, {
        ...asset,
        'usage_scopes': ['shop'],
      })?.imageUrl,
      isNull,
    );
  });

  test('fixtures require confirmed sourced Rayon participation', () {
    final now = DateTime.utc(2026, 9, 23, 12);
    final row = <String, dynamic>{
      'id': 'fixture-1',
      'home_team_id': 'rayon',
      'away_team_id': 'apr',
      'competition_id': 'league',
      'starts_at': '2026-09-23T22:30:00Z',
      'schedule_status': 'confirmed',
      'source_publication_id': 'official-1',
      'source_url': 'https://rwandapremierleague.rw/fixtures/1',
    };
    final teams = <String?, Map<String, dynamic>>{
      'rayon': {'name': 'Rayon Sports FC', 'is_rayon_sports': true},
      'apr': {'name': 'APR FC', 'is_rayon_sports': false},
    };
    final competitions = <String?, Map<String, dynamic>>{
      'league': {'name': 'Rwanda Premier League'},
    };
    final fixture = mapGikundiroFixture(row, teams, competitions, now);
    expect(fixture?.id, 'gikundiro-fixture-1');
    final local = DateTime.parse('2026-09-23T22:30:00Z').toLocal();
    expect(fixture?.kickoffTime,
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}');
    expect(fixture?.isOnSale, false);
    expect(
      mapGikundiroFixture(
        {...row, 'schedule_status': 'date_only'},
        teams,
        competitions,
        now,
      ),
      isNull,
    );
    expect(
      mapGikundiroFixture(
        {...row, 'source_publication_id': null},
        teams,
        competitions,
        now,
      ),
      isNull,
    );
  });
}
