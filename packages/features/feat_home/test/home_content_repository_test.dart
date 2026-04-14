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
}
