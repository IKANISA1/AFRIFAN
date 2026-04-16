import 'package:local_auth/local_auth.dart';

/// Actions that require device authentication before proceeding.
enum BioPayAuthAction { enrollment, revocation, paymentHandoff }

/// Gate result status.
enum BioPayAuthGateStatus {
  authorized,
  unavailable,
  canceled,
  lockedOut,
  failed,
}

/// Result of a device authentication attempt.
class BioPayAuthGateResult {
  const BioPayAuthGateResult._({required this.status, required this.message});

  const BioPayAuthGateResult.authorized()
    : this._(status: BioPayAuthGateStatus.authorized, message: '');

  const BioPayAuthGateResult.unavailable(String message)
    : this._(status: BioPayAuthGateStatus.unavailable, message: message);

  const BioPayAuthGateResult.canceled(String message)
    : this._(status: BioPayAuthGateStatus.canceled, message: message);

  const BioPayAuthGateResult.lockedOut(String message)
    : this._(status: BioPayAuthGateStatus.lockedOut, message: message);

  const BioPayAuthGateResult.failed(String message)
    : this._(status: BioPayAuthGateStatus.failed, message: message);

  final BioPayAuthGateStatus status;
  final String message;

  bool get isAuthorized => status == BioPayAuthGateStatus.authorized;
}

/// Abstract adapter for testability.
abstract class BioPayAuthAdapter {
  Future<bool> isDeviceSupported();

  Future<bool> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  });
}

/// Default adapter using the `local_auth` package.
class LocalAuthBioPayAuthAdapter implements BioPayAuthAdapter {
  LocalAuthBioPayAuthAdapter({LocalAuthentication? localAuthentication})
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
class BioPayAuthGateService {
  BioPayAuthGateService({BioPayAuthAdapter? adapter})
    : _adapter = adapter ?? LocalAuthBioPayAuthAdapter();

  final BioPayAuthAdapter _adapter;

  Future<BioPayAuthGateResult> authorize(BioPayAuthAction action) async {
    try {
      final supported = await _adapter.isDeviceSupported();
      if (!supported) {
        return const BioPayAuthGateResult.unavailable(
          'Set up device security before using BioPay.',
        );
      }

      final authenticated = await _adapter.authenticate(
        localizedReason: action.localizedReason,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
      if (authenticated) {
        return const BioPayAuthGateResult.authorized();
      }

      return BioPayAuthGateResult.canceled(action.canceledMessage);
    } catch (error) {
      if (error.toString().contains('LockedOut') ||
          error.toString().contains('lockout')) {
        return const BioPayAuthGateResult.lockedOut(
          'Device auth locked. Unlock and try again.',
        );
      }
      return BioPayAuthGateResult.failed(action.failureMessage);
    }
  }
}

extension on BioPayAuthAction {
  String get localizedReason => switch (this) {
    BioPayAuthAction.enrollment =>
      'Confirm your identity before BioPay saves this face enrollment.',
    BioPayAuthAction.revocation =>
      'Confirm your identity before BioPay revokes this face enrollment.',
    BioPayAuthAction.paymentHandoff =>
      'Confirm your identity before BioPay opens the payment dialer.',
  };

  String get canceledMessage => switch (this) {
    BioPayAuthAction.enrollment => 'Enrollment canceled.',
    BioPayAuthAction.revocation => 'Revocation canceled.',
    BioPayAuthAction.paymentHandoff => 'Payment canceled.',
  };

  String get failureMessage => switch (this) {
    BioPayAuthAction.enrollment =>
      'BioPay could not verify your identity for enrollment. Try again.',
    BioPayAuthAction.revocation =>
      'BioPay could not verify your identity for revocation. Try again.',
    BioPayAuthAction.paymentHandoff =>
      'Identity verification failed. Try again.',
  };
}
