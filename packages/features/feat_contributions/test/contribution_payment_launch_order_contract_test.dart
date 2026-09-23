import 'dart:io';

import 'package:feat_contributions/src/widgets/overlays/momo_contribution_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'pending contribution is persisted before the external dialer launches',
    () {
      final packageSource = File(
        'lib/src/widgets/overlays/momo_contribution_sheet.dart',
      );
      final source =
          (packageSource.existsSync()
                  ? packageSource
                  : File(
                      'packages/features/feat_contributions/lib/src/widgets/'
                      'overlays/momo_contribution_sheet.dart',
                    ))
              .readAsStringSync();
      final flow = source.substring(
        source.indexOf('Future<void> showMomoAmountEntrySheet('),
        source.indexOf('class ContributionPaymentStatusAnnouncement'),
      );

      final persistence = flow.indexOf('await repo.contribute(');
      final paymentLaunch = flow.indexOf('MomoDialerService.launchMomoUssd(');

      expect(persistence, greaterThan(-1));
      expect(paymentLaunch, greaterThan(persistence));
      final cancellation = flow.indexOf(
        'repo.cancelPendingContributionPaymentLaunch(contributionId)',
      );
      expect(cancellation, greaterThan(paymentLaunch));
      expect(
        flow.substring(0, paymentLaunch),
        contains('return;'),
        reason: 'failed persistence must abort before payment launch',
      );
      expect(flow, contains('normalizedGroupId.isEmpty || recipient.isEmpty'));
      expect(flow, contains('recordedPending: true'));
      expect(
        flow,
        contains('launchResult == ContributionPaymentLaunchResult.launched'),
      );
      final launchedBranch = flow.indexOf(
        'if (launchResult == ContributionPaymentLaunchResult.launched)',
      );
      final awaitingDialog = flow.indexOf('_ContributionSuccessDialog(');
      final failedLaunchBranch = flow.indexOf('var cancellationFailed =');
      expect(awaitingDialog, greaterThan(launchedBranch));
      expect(awaitingDialog, lessThan(failedLaunchBranch));
      expect(flow, contains('_ContributionDialerRecoveryDialog'));
      expect(flow, isNot(contains('Failed to record contribution:')));
    },
  );

  test('successful launch does not cancel the pending contribution', () async {
    final calls = <String>[];

    final result = await launchContributionPaymentWithRecovery(
      launchPayment: () async {
        calls.add('launch');
        return true;
      },
      cancelPendingContribution: () async {
        calls.add('cancel');
      },
    );

    expect(result, ContributionPaymentLaunchResult.launched);
    expect(calls, <String>['launch']);
  });

  test('failed launch cancels the exact pending attempt in order', () async {
    final calls = <String>[];

    final result = await launchContributionPaymentWithRecovery(
      launchPayment: () async {
        calls.add('launch');
        return false;
      },
      cancelPendingContribution: () async {
        calls.add('cancel');
      },
    );

    expect(result, ContributionPaymentLaunchResult.cancelledAfterLaunchFailure);
    expect(calls, <String>['launch', 'cancel']);
  });

  test('cancellation failure remains a controlled recovery result', () async {
    final calls = <String>[];
    Object? reportedError;

    final result = await launchContributionPaymentWithRecovery(
      launchPayment: () async {
        calls.add('launch');
        return false;
      },
      cancelPendingContribution: () async {
        calls.add('cancel');
        throw StateError('cleanup unavailable');
      },
      onCancellationError: (error, _) {
        calls.add('report');
        reportedError = error;
      },
    );

    expect(result, ContributionPaymentLaunchResult.cancellationFailed);
    expect(calls, <String>['launch', 'cancel', 'report']);
    expect(reportedError, isA<StateError>());
  });
}
