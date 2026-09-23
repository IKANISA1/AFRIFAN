import 'package:feat_club/feat_club.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ClubModule remains registered as core club identity', () {
    final module = ClubModule();

    expect(module.tabRoute.path, '/club');
    expect(module.tabRoute.label, 'Club');
    expect(module.isEnabled(const <String, bool>{'club': false}), isTrue);
    expect(
      module.isEnabledForConfig(
        configSnapshot: <String, dynamic>{
          'features': <Map<String, dynamic>>[
            <String, dynamic>{
              'feature_key': 'club',
              'is_enabled': false,
              'visibility_state': 'maintenance',
            },
          ],
        },
      ),
      isTrue,
    );
  });

  test('ClubOverview maps only published identity fields', () {
    final overview = ClubOverview.fromJson(<String, dynamic>{
      'id': 24,
      'club_name': 'Rayon Sports FC',
      'country_name': 'Rwanda',
      'league': 'Rwanda Premier League',
      'club_slug': 'rayon_sports_rw',
      'nickname_brand_identity': 'Gikundiro',
      'official_logo_url': 'https://example.test/logo.png',
      'club_profile': {
        'full_name': 'Rayon Sports Football Club',
        'origin': 'Nyanza',
        'current_base': 'Kigali',
        'colours': 'Blue and white',
      },
    });

    expect(overview.id, 24);
    expect(overview.name, 'Rayon Sports FC');
    expect(overview.slug, 'rayon_sports_rw');
    expect(overview.nickname, 'Gikundiro');
    expect(overview.logoUrl, 'https://example.test/logo.png');
    expect(overview.hasProfile, isTrue);
    expect(overview.origin, 'Nyanza');
    expect(overview.currentBase, 'Kigali');
  });

  test('ClubFixtureItem distinguishes completed results from fixtures', () {
    final result = ClubFixtureItem.fromJson(<String, dynamic>{
      'id': 'match-1',
      'home_team': 'Rayon Sports',
      'away_team': 'APR',
      'match_date': '2026-07-30T15:00:00Z',
      'match_status': 'finished',
      'home_score': 2,
      'away_score': 1,
    });
    final fixture = ClubFixtureItem.fromJson(<String, dynamic>{
      'id': 'match-2',
      'home_team': 'Rayon Sports',
      'away_team': 'Police',
      'match_status': 'scheduled',
      'is_on_sale': true,
    });

    expect(result.isCompleted, isTrue);
    expect(result.homeScore, 2);
    expect(fixture.isCompleted, isFalse);
    expect(fixture.isOnSale, isTrue);
  });
}
