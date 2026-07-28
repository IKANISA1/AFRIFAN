import 'package:feat_home/src/repositories/home_content_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('homeHeroRouteForStatus', () {
    test('routes live statuses to Match Center inside Fan Zone', () {
      expect(homeHeroRouteForStatus('LIVE'), '/fanzone/match/live');
      expect(homeHeroRouteForStatus('HALF-TIME'), '/fanzone/match/live');
      expect(homeHeroRouteForStatus('FULL-TIME'), '/fanzone/match/live');
    });

    test('routes non-live statuses to predictions', () {
      expect(homeHeroRouteForStatus('UPCOMING'), '/fanzone?section=league');
      expect(homeHeroRouteForStatus('SCHEDULED'), '/fanzone?section=league');
    });
  });

  group('localHomeFeedFallbackSnapshot', () {
    test('keeps Home actionable when active club scope cannot resolve', () {
      final snapshot = localHomeFeedFallbackSnapshot();

      expect(snapshot.status, HomeFeedStatus.degraded);
      expect(snapshot.message, homeFeedLocalFallbackMessage);
      expect(snapshot.message, isNot(contains('Could not resolve')));
      expect(snapshot.hasQuickActions, isTrue);
      expect(snapshot.showFixturePlaceholder, isTrue);
      expect(
        snapshot.quickActions.map((action) => action.title),
        orderedEquals(<String>[
          'Tickets',
          'Join Gikundiro',
          'Fan Zone',
          'Shop',
        ]),
      );
      expect(
        snapshot.quickActions
            .firstWhere((action) => action.actionKey == 'fan_zone')
            .route,
        '/fanzone?section=supporters',
      );
    });
  });

  group('localLatestIntelFallbackSnapshot', () {
    test('hides news when local club scope is unresolved', () {
      final snapshot = localLatestIntelFallbackSnapshot();

      expect(snapshot.status, LatestIntelStatus.empty);
      expect(snapshot.articles, isEmpty);
      expect(snapshot.message, 'Club updates will appear when published.');
    });
  });
}
