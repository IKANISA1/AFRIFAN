import 'dart:io';

import 'package:feat_sms_ledger/feat_sms_ledger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('contribution conflict requires refresh and review', () {
    const error = ContributionConflictException();
    expect(error.toString(), contains('changed during reconciliation'));
    expect(error.toString(), contains('Refresh the queue'));
  });

  test('released client reconciliation remains fail closed', () {
    final packageSource = File(
      'lib/src/services/ledger_reconciliation_service.dart',
    );
    final source = (packageSource.existsSync()
            ? packageSource
            : File(
                'packages/features/feat_sms_ledger/lib/src/services/'
                'ledger_reconciliation_service.dart',
              ))
        .readAsStringSync();

    expect(
      source,
      contains('throw const ClientReconciliationDisabledException()'),
    );
    expect(source, contains('reconcile_group_contribution_from_sms'));
    expect(source, isNot(contains(".from('group_contributions')")));
    expect(source, isNot(contains(".from('momo_ledger_entries')")));
    expect(source, isNot(contains(".from('momo_reconciliations')")));
    expect(source, isNot(contains('.update(')));
    expect(source, isNot(contains('.upsert(')));
  });
}
