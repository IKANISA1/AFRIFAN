import 'package:feat_home/src/repositories/home_content_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('homeHeroRouteForStatus', () {
    test('routes live statuses to Match Center inside Fan Zone', () {
      expect(homeHeroRouteForStatus('LIVE'), '/predict/match/live');
      expect(homeHeroRouteForStatus('HALF-TIME'), '/predict/match/live');
      expect(homeHeroRouteForStatus('FULL-TIME'), '/predict/match/live');
    });

    test('routes non-live statuses to predictions', () {
      expect(homeHeroRouteForStatus('UPCOMING'), '/club/fixtures');
      expect(homeHeroRouteForStatus('SCHEDULED'), '/club/fixtures');
    });
  });

  group('localHomeFeedFallbackSnapshot', () {
    test('keeps Home actionable when active club scope cannot resolve', () {
      final snapshot = localHomeFeedFallbackSnapshot();

      expect(snapshot.status, HomeFeedStatus.degraded);
      expect(snapshot.notice, HomeFeedNotice.liveUnavailable);
      expect(snapshot.hasQuickActions, isTrue);
      expect(snapshot.showFixturePlaceholder, isTrue);
      expect(
        snapshot.quickActions.map((action) => action.actionKey),
        orderedEquals(<String>['tickets', 'membership', 'predict', 'shop']),
      );
      expect(
        snapshot.quickActions
            .firstWhere((action) => action.actionKey == 'predict')
            .route,
        '/predict',
      );
    });
  });

  test('only a paid current membership displays its selected tier', () {
    final row = <String, dynamic>{
      'tier': 'silver',
      'payment_status': 'verified',
      'status': 'active',
      'expires_at': '2099-01-01T00:00:00Z',
      'points': 999999,
    };
    expect(paidHomeMembershipTier(row), 'silver');
    expect(
      paidHomeMembershipTier({...row, 'expires_at': '2000-01-01T00:00:00Z'}),
      isNull,
    );
    expect(
      paidHomeMembershipTier({...row, 'payment_status': 'pending'}),
      isNull,
    );
    expect(paidHomeMembershipTier({...row, 'tier': 'fan'}), isNull);
  });

  group('projectHomeMembershipRows', () {
    test(
      'owner-only store mode retains self state without inventing rank one',
      () {
        final projection = projectHomeMembershipRows(
          memberships: const <Map<String, dynamic>>[
            <String, dynamic>{
              'user_id': 'current-user',
              'points': 2140,
              'tier': 'gold',
              'payment_status': 'verified',
              'status': 'active',
              'expires_at': '2099-01-01T00:00:00Z',
            },
          ],
          currentUserId: 'current-user',
          allowsCrossUserLeaderboard: false,
        );

        expect(projection.leaderboard, isEmpty);
        expect(projection.fanRank, 0);
        expect(projection.hasCurrentMembership, isTrue);
        expect(projection.userFet, 2140);
        expect(projection.membershipTier, 'gold');
        expect(projection.membershipPaymentStatus, 'verified');
      },
    );

    test('suppressed mode never exposes rows even if several are returned', () {
      final projection = projectHomeMembershipRows(
        memberships: const <Map<String, dynamic>>[
          <String, dynamic>{'user_id': 'other-user', 'points': 3000},
          <String, dynamic>{
            'user_id': 'current-user',
            'points': 2140,
            'tier': 'silver',
          },
        ],
        currentUserId: 'current-user',
        allowsCrossUserLeaderboard: false,
      );

      expect(projection.leaderboard, isEmpty);
      expect(projection.fanRank, 0);
      expect(projection.userFet, 2140);
      expect(projection.membershipTier, isNull);
    });

    test('authorized development mode preserves ranked projection', () {
      final projection = projectHomeMembershipRows(
        memberships: const <Map<String, dynamic>>[
          <String, dynamic>{'user_id': 'leader', 'points': 3000},
          <String, dynamic>{'user_id': 'current-user', 'points': 2140},
        ],
        currentUserId: 'current-user',
        allowsCrossUserLeaderboard: true,
        publicAliases: const <String, String>{
          'leader': '123456',
          'current-user': '654321',
        },
      );

      expect(projection.leaderboard, hasLength(2));
      expect(projection.leaderboard.first.alias, '123456');
      expect(projection.fanRank, 2);
      expect(projection.userFet, 2140);
    });
  });

  group('localLatestIntelFallbackSnapshot', () {
    test('hides news when local club scope is unresolved', () {
      final snapshot = localLatestIntelFallbackSnapshot();

      expect(snapshot.status, LatestIntelStatus.empty);
      expect(snapshot.articles, isEmpty);
      expect(snapshot.notice, LatestIntelNotice.unpublished);
    });
  });
}
