import 'package:local_auth/local_auth.dart';

/// Actions that require device authentication before proceeding.
enum BiopayAuthAction { enrollment, revocation, paymentHandoff }

/// Gate result status.
enum BiopayAuthGateStatus {
  authorized,
  unavailable,
  canceled,
  lockedOut,
  failed,
}

/// Result of a device authentication attempt.
class BiopayAuthGateResult {
  const BiopayAuthGateResult._({required this.status, required this.message});

  const BiopayAuthGateResult.authorized()
    : this._(status: BiopayAuthGateStatus.authorized, message: '');

  const BiopayAuthGateResult.unavailable(String message)
    : this._(status: BiopayAuthGateStatus.unavailable, message: message);

  const BiopayAuthGateResult.canceled(String message)
    : this._(status: BiopayAuthGateStatus.canceled, message: message);

  const BiopayAuthGateResult.lockedOut(String message)
    : this._(status: BiopayAuthGateStatus.lockedOut, message: message);

  const BiopayAuthGateResult.failed(String message)
    : this._(status: BiopayAuthGateStatus.failed, message: message);

  final BiopayAuthGateStatus status;
  final String message;

  bool get isAuthorized => status == BiopayAuthGateStatus.authorized;
}

/// Abstract adapter for testability.
abstract class BiopayAuthAdapter {
  Future<bool> isDeviceSupported();

  Future<bool> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  });
}

/// Default adapter using the `local_auth` package.
class LocalAuthBiopayAuthAdapter implements BiopayAuthAdapter {
  LocalAuthBiopayAuthAdapter({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  @override
  Future<bool> isDeviceSupported() => _localAuthentication.isDeviceSupported();

  @override
  Future<bool> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) {
    return _localAuthentication.authenticate(
      localizedReason: localizedReason,
      options: AuthenticationOptions(
        biometricOnly: biometricOnly,
        sensitiveTransaction: sensitiveTransaction,
        useErrorDialogs: true,
      ),
    );
  }
}

/// Gate that requires device biometric/passcode authentication
/// before performing sensitive BioPay operations.
class BiopayAuthGateService {
  BiopayAuthGateService({BiopayAuthAdapter? adapter})
    : _adapter = adapter ?? LocalAuthBiopayAuthAdapter();

  final BiopayAuthAdapter _adapter;

  Future<BiopayAuthGateResult> authorize(BiopayAuthAction action) async {
    try {
      final supported = await _adapter.isDeviceSupported();
      if (!supported) {
        return const BiopayAuthGateResult.unavailable(
          'Set up device security before using BioPay.',
        );
      }

      final authenticated = await _adapter.authenticate(
        localizedReason: action.localizedReason,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
      if (authenticated) {
        return const BiopayAuthGateResult.authorized();
      }

      return BiopayAuthGateResult.canceled(action.canceledMessage);
    } catch (error) {
      if (error.toString().contains('LockedOut') ||
          error.toString().contains('lockout')) {
        return const BiopayAuthGateResult.lockedOut(
          'Device auth locked. Unlock and try again.',
        );
      }
      return BiopayAuthGateResult.failed(action.failureMessage);
    }
  }
}

extension on BiopayAuthAction {
  String get localizedReason => switch (this) {
    BiopayAuthAction.enrollment =>
      'Confirm your identity before BioPay saves this face enrollment.',
    BiopayAuthAction.revocation =>
      'Confirm your identity before BioPay revokes this face enrollment.',
    BiopayAuthAction.paymentHandoff =>
      'Confirm your identity before BioPay opens the payment dialer.',
  };

  String get canceledMessage => switch (this) {
    BiopayAuthAction.enrollment => 'Enrollment canceled.',
    BiopayAuthAction.revocation => 'Revocation canceled.',
    BiopayAuthAction.paymentHandoff => 'Payment canceled.',
  };

  String get failureMessage => switch (this) {
    BiopayAuthAction.enrollment =>
      'BioPay could not verify your identity for enrollment. Try again.',
    BiopayAuthAction.revocation =>
      'BioPay could not verify your identity for revocation. Try again.',
    BiopayAuthAction.paymentHandoff =>
      'Identity verification failed. Try again.',
  };
}
