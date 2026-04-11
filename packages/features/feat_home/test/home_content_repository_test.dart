import 'package:feat_home/src/repositories/home_content_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('homeHeroRouteForStatus', () {
    test('routes live statuses to the live match screen', () {
      expect(homeHeroRouteForStatus('LIVE'), '/live-match');
      expect(homeHeroRouteForStatus('HALF-TIME'), '/live-match');
      expect(homeHeroRouteForStatus('FULL-TIME'), '/live-match');
    });

    test('routes non-live statuses to tickets', () {
      expect(homeHeroRouteForStatus('UPCOMING'), '/tickets');
      expect(homeHeroRouteForStatus('SCHEDULED'), '/tickets');
    });
  });
}
