import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client_factory.dart';

/// A finite failure when an operation outlives its authenticated owner.
class SupabaseSessionChangedException implements Exception {
  const SupabaseSessionChangedException();

  @override
  String toString() => 'The active session changed. Review the action again.';
}

/// Captures the SDK client and session that authorized a delayed operation.
///
/// A JWT session identifier is only a continuity check between two sessions
/// already held by the same SDK client. It never grants authentication or role
/// authority. Ordinary token refresh may retain that identifier; a new login,
/// logout, SDK client or account invalidates this operation permanently.
class SupabaseSessionAuthority {
  SupabaseSessionAuthority.capture({
    SupabaseClient Function()? clientProvider,
    bool Function()? isOwnerCurrent,
  }) : _isOwnerCurrent = isOwnerCurrent,
       _clientProvider =
           clientProvider ?? (() => SupabaseClientFactory.client) {
    client = _clientProvider();
    session = client.auth.currentSession;
    _subscription = client.auth.onAuthStateChange.listen(
      (auth) {
        if ((auth.event == AuthChangeEvent.signedIn ||
                auth.event == AuthChangeEvent.signedOut ||
                auth.event == AuthChangeEvent.initialSession ||
                auth.event == AuthChangeEvent.passwordRecovery ||
                auth.event == AuthChangeEvent.mfaChallengeVerified) &&
            !identical(auth.session, session)) {
          // A queued notification for the exact session captured just before
          // subscription is its initial owner, not a later replacement.
          _invalidated = true;
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _invalidated = true;
      },
    );
  }

  final SupabaseClient Function() _clientProvider;
  final bool Function()? _isOwnerCurrent;
  late final SupabaseClient client;
  late final Session? session;
  late final StreamSubscription<AuthState> _subscription;
  bool _invalidated = false;

  bool get isCurrent {
    if (_invalidated) return false;
    try {
      final current = _clientProvider();
      if (_isOwnerCurrent?.call() == false ||
          !identical(current, client) ||
          !_sameSession(session, current.auth.currentSession)) {
        _invalidated = true;
      }
    } catch (_) {
      _invalidated = true;
    }
    return !_invalidated;
  }

  void requireCurrent() {
    if (!isCurrent) throw const SupabaseSessionChangedException();
  }

  Future<void> dispose() async {
    _invalidated = true;
    await _subscription.cancel();
  }

  static bool _sameSession(Session? expected, Session? current) {
    if (expected == null || current == null) {
      return expected == null && current == null;
    }
    if (expected.user.id != current.user.id) return false;
    if (expected.accessToken == current.accessToken) return true;
    final expectedId = _sessionId(expected.accessToken);
    final currentId = _sessionId(current.accessToken);
    return expectedId != null && expectedId == currentId;
  }

  static String? _sessionId(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map<String, dynamic>) return null;
      final id = payload['session_id'];
      return id is String && id.trim().isNotEmpty ? id : null;
    } catch (_) {
      return null;
    }
  }
}
