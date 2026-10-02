import 'dart:async';

import 'package:club_data/club_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline connectivity takes precedence over backend error text', () {
    final failure = ClubContentFailure.fromError(
      StateError('permission denied for secret record'),
      isOnline: false,
    );

    expect(failure.kind, ClubContentFailureKind.offline);
  });

  test('classifies bounded timeouts without exposing source exceptions', () {
    final failure = ClubContentFailure.fromError(
      TimeoutException('token=private-value'),
      isOnline: true,
    );

    expect(failure.kind, ClubContentFailureKind.securityTimeout);
    expect(failure.toString(), 'ClubContentFailure(securityTimeout)');
    expect(failure.toString(), isNot(contains('private-value')));
  });

  test('classifies authorization, conflict, and unknown failures', () {
    expect(
      ClubContentFailure.fromError(
        StateError('RLS forbidden'),
        isOnline: true,
      ).kind,
      ClubContentFailureKind.permissionDenied,
    );
    expect(
      ClubContentFailure.fromError(
        StateError('stale revision conflict'),
        isOnline: true,
      ).kind,
      ClubContentFailureKind.conflict,
    );
    expect(
      ClubContentFailure.fromError(
        StateError('unexpected backend response'),
        isOnline: true,
      ).kind,
      ClubContentFailureKind.unknown,
    );
  });
}
