import 'dart:io';

import 'package:feat_sms_ledger/feat_sms_ledger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('contribution conflict requires refresh and review', () {
    const error = ContributionConflictException();
    expect(error.toString(), contains('changed during reconciliation'));
    expect(error.toString(), contains('Refresh the queue'));
  });

  test('reconciliation compares the loaded updated_at token atomically', () {
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

    expect(source, contains("'updated_at', expectedUpdatedAt"));
    expect(source, contains(".eq('status', 'pending')"));
    expect(source, contains('.maybeSingle()'));
    expect(source, contains('throw const ContributionConflictException()'));
  });
}
