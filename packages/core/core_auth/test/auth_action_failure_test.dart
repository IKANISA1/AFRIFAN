import 'package:core_auth/core_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthActionFailure', () {
    test('maps request failures to safe, stable categories', () {
      expect(
        AuthActionFailure.fromRequestError(
          const FormatException('SocketException: failed host lookup'),
        ).kind,
        AuthActionFailureKind.offline,
      );
      expect(
        AuthActionFailure.fromRequestError(
          StateError('permission denied by policy'),
        ).kind,
        AuthActionFailureKind.permissionDenied,
      );
      expect(
        AuthActionFailure.fromRequestError(
          StateError('phone already registered'),
        ).kind,
        AuthActionFailureKind.conflict,
      );
    });

    test('maps verification expiry and invalid-code failures separately', () {
      final expired = AuthActionFailure.fromVerificationError(
        StateError('verification code expired'),
      );
      final invalid = AuthActionFailure.fromVerificationError(
        StateError('invalid otp'),
      );

      expect(expired.kind, AuthActionFailureKind.securityTimeout);
      expect(expired.message, isNot(contains('StateError')));
      expect(invalid.kind, AuthActionFailureKind.invalidInput);
    });

    test('does not expose unknown backend messages', () {
      final failure = AuthActionFailure.fromRequestError(
        StateError('internal tenant 42 secret diagnostic'),
      );

      expect(failure.kind, AuthActionFailureKind.unknown);
      expect(failure.message, isNot(contains('tenant')));
      expect(failure.message, isNot(contains('diagnostic')));
    });
  });
}
