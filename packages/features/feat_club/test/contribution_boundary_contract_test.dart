import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('supporter contribution uses the server-owned pending RPC', () {
    final packageSource = File('lib/src/repositories/club_repository.dart');
    final source =
        (packageSource.existsSync()
                ? packageSource
                : File(
                    'packages/features/feat_club/lib/src/repositories/'
                    'club_repository.dart',
                  ))
            .readAsStringSync();
    final contributionMethod = source.substring(
      source.indexOf('Future<String> contribute({'),
      source.indexOf('Future<String> getContributionPaymentStatus'),
    );

    expect(contributionMethod, contains("'create_pending_group_contribution'"));
    expect(contributionMethod, contains("'p_group_id': groupId"));
    expect(contributionMethod, contains("'p_amount': amount"));
    expect(
      contributionMethod,
      contains(
        "'p_client_request_reference': normalizedClientRequestReference",
      ),
    );
    expect(
      contributionMethod,
      contains("'p_idempotency_key': normalizedIdempotencyKey"),
    );
    expect(contributionMethod, isNot(contains("'user_id': userId")));
    expect(contributionMethod, isNot(contains('.insert(')));
    expect(contributionMethod, contains('authenticatedUserId != userId'));
  });

  test('contribution reads use explicit projections', () {
    final packageSource = File('lib/src/repositories/club_repository.dart');
    final source =
        (packageSource.existsSync()
                ? packageSource
                : File(
                    'packages/features/feat_club/lib/src/repositories/'
                    'club_repository.dart',
                  ))
            .readAsStringSync();

    expect(source, contains('_contributionGroupProjection'));
    expect(
      source,
      contains(
        "'id, group_id, user_id, display_name, is_admin, is_anonymous, '",
      ),
    );
    expect(source, isNot(contains(".select('*, profile:profiles")));
  });

  test('failed payment launch cancellation uses the exact owner RPC', () {
    final packageSource = File('lib/src/repositories/club_repository.dart');
    final source =
        (packageSource.existsSync()
                ? packageSource
                : File(
                    'packages/features/feat_club/lib/src/repositories/'
                    'club_repository.dart',
                  ))
            .readAsStringSync();
    final cancellationMethod = source.substring(
      source.indexOf('Future<void> cancelPendingContributionPaymentLaunch('),
      source.indexOf('Future<String> getContributionPaymentStatus'),
    );

    expect(
      cancellationMethod,
      contains("'cancel_pending_group_contribution_payment_launch'"),
    );
    expect(
      cancellationMethod,
      contains("'p_contribution_id': normalizedContributionId"),
    );
    expect(cancellationMethod, contains('if (result != true)'));
    expect(cancellationMethod, isNot(contains(".from('group_contributions')")));
    expect(cancellationMethod, isNot(contains('.update(')));
  });
}
