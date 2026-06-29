import 'package:feat_home/src/repositories/home_content_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('homeHeroRouteForStatus', () {
    test('routes live statuses to the live match screen', () {
      expect(homeHeroRouteForStatus('LIVE'), '/live');
      expect(homeHeroRouteForStatus('HALF-TIME'), '/live');
      expect(homeHeroRouteForStatus('FULL-TIME'), '/live');
    });

    test('routes non-live statuses to predictions', () {
      expect(homeHeroRouteForStatus('UPCOMING'), '/fanzone/fixtures');
      expect(homeHeroRouteForStatus('SCHEDULED'), '/fanzone/fixtures');
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
        containsAll(<String>[
          'Tickets',
          'Join Gikundiro',
          'Fanclubs',
          'Shop',
          'Matchday',
          'Contribute',
        ]),
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
