/// Stable, user-safe failure categories for phone and OTP authentication.
enum AuthActionFailureKind {
  offline,
  permissionDenied,
  securityTimeout,
  conflict,
  invalidInput,
  unknown,
}

/// A sanitized authentication failure that UI can render without exposing
/// backend messages, identifiers, or implementation details.
class AuthActionFailure {
  const AuthActionFailure({required this.kind, required this.message});

  final AuthActionFailureKind kind;
  final String message;

  factory AuthActionFailure.fromRequestError(Object error) {
    final normalized = _normalized(error);

    if (_matchesOffline(normalized)) {
      return const AuthActionFailure(
        kind: AuthActionFailureKind.offline,
        message: 'Connect to the internet to send a WhatsApp code.',
      );
    }
    if (_matchesPermission(normalized)) {
      return const AuthActionFailure(
        kind: AuthActionFailureKind.permissionDenied,
        message:
            'WhatsApp sign-in is unavailable for this account. Use another option or contact support.',
      );
    }
    if (_matchesConflict(normalized)) {
      return const AuthActionFailure(
        kind: AuthActionFailureKind.conflict,
        message:
            'This number is already linked to another account. Use that account or contact support.',
      );
    }
    if (_matchesTimeout(normalized)) {
      return const AuthActionFailure(
        kind: AuthActionFailureKind.securityTimeout,
        message: 'The request timed out. Check your connection and try again.',
      );
    }
    if (_matchesInvalidInput(normalized)) {
      return const AuthActionFailure(
        kind: AuthActionFailureKind.invalidInput,
        message: 'Check the WhatsApp number and try again.',
      );
    }
    return const AuthActionFailure(
      kind: AuthActionFailureKind.unknown,
      message: 'Could not send the WhatsApp code. Try again.',
    );
  }

  factory AuthActionFailure.fromVerificationError(Object error) {
    final normalized = _normalized(error);

    if (_matchesOffline(normalized)) {
      return const AuthActionFailure(
        kind: AuthActionFailureKind.offline,
        message: 'Connect to the internet to verify the WhatsApp code.',
      );
    }
    if (_matchesPermission(normalized)) {
      return const AuthActionFailure(
        kind: AuthActionFailureKind.permissionDenied,
        message:
            'Verification is unavailable for this account. Request help or change the number.',
      );
    }
    if (_matchesConflict(normalized)) {
      return const AuthActionFailure(
        kind: AuthActionFailureKind.conflict,
        message:
            'This number belongs to another account. Change the number or contact support.',
      );
    }
    if (_matchesTimeout(normalized)) {
      return const AuthActionFailure(
        kind: AuthActionFailureKind.securityTimeout,
        message: 'This code expired. Request a new WhatsApp code.',
      );
    }
    if (_matchesInvalidInput(normalized)) {
      return const AuthActionFailure(
        kind: AuthActionFailureKind.invalidInput,
        message: 'That code is not valid. Check it or request a new one.',
      );
    }
    return const AuthActionFailure(
      kind: AuthActionFailureKind.unknown,
      message: 'Could not verify the WhatsApp code. Try again.',
    );
  }

  static String _normalized(Object error) => error.toString().toLowerCase();

  static bool _matchesOffline(String value) {
    return value.contains('socketexception') ||
        value.contains('failed host lookup') ||
        value.contains('network is unreachable') ||
        value.contains('unable to connect') ||
        value.contains('internet connection') ||
        value.contains('authretryablefetchexception');
  }

  static bool _matchesPermission(String value) {
    return value.contains('permission denied') ||
        value.contains('not authorized') ||
        value.contains('unauthorized') ||
        value.contains('forbidden') ||
        value.contains('row-level security') ||
        value.contains('statuscode: 401') ||
        value.contains('statuscode: 403');
  }

  static bool _matchesConflict(String value) {
    return value.contains('already registered') ||
        value.contains('already exists') ||
        value.contains('already linked') ||
        value.contains('another account') ||
        value.contains('conflict');
  }

  static bool _matchesTimeout(String value) {
    return value.contains('expired') ||
        value.contains('timed out') ||
        value.contains('timeout');
  }

  static bool _matchesInvalidInput(String value) {
    return value.contains('invalid phone') ||
        value.contains('invalid otp') ||
        value.contains('invalid token') ||
        value.contains('invalid code') ||
        value.contains('malformed');
  }
}
