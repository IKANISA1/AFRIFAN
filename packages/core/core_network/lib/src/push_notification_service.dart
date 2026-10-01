import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client_factory.dart';
import 'supabase_session_authority.dart';

enum PushPermissionStatus {
  unavailable,
  notDetermined,
  denied,
  authorized,
  provisional,
}

@visibleForTesting
bool resolvePushDeliveryPreference(
  Map<String, dynamic>? row, {
  bool lookupFailed = false,
}) {
  if (lookupFailed) return false;
  // No saved row retains the documented opt-out default. A failed lookup is
  // deliberately different: an unknown preference must fail closed.
  if (row == null) return true;
  return row['push_enabled'] == true;
}

@pragma('vm:entry-point')
Future<void> afriClubFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  AfriLogger.info(
    'Push',
    'Background message received: ${message.messageId ?? 'unknown'}',
  );
}

/// Platform boundary used by the service; tests supply controlled native calls
/// and actual SDK clients without contacting providers.
@visibleForTesting
class PushNotificationRuntime {
  bool get isSupported => !kIsWeb && Firebase.apps.isNotEmpty;
  SupabaseClient get client => SupabaseClientFactory.client;
  FirebaseMessaging get messaging => FirebaseMessaging.instance;
}

class PushNotificationService {
  PushNotificationService._();

  static PushNotificationRuntime _runtime = PushNotificationRuntime();
  static int _deviceGeneration = 0;
  static int _scopeGeneration = 0;
  static Future<void> _deviceOperationTail = Future<void>.value();
  static StreamSubscription<RemoteMessage>? _messageSubscription;
  static SupabaseClient? _authClient;
  static bool _initialized = false;
  static String? _clubId;
  static String? _lastKnownUserId;
  static String? _lastKnownToken;
  static bool _messagingRuntimeRegistered = false;
  static StreamSubscription<AuthState>? _authSubscription;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static Future<void> initialize({required String clubId}) async {
    if (_clubId != clubId) {
      _scopeGeneration++;
      _deviceGeneration++;
    }
    _clubId = clubId;
    if (!_isSupported ||
        (_initialized && identical(_authClient, _runtime.client))) {
      return;
    }

    final client = _runtime.client;
    final scope = _scopeGeneration;
    final generation = _deviceGeneration;
    bool current() =>
        scope == _scopeGeneration &&
        generation == _deviceGeneration &&
        identical(client, _runtime.client);
    try {
      await _authSubscription?.cancel();
      if (scope != _scopeGeneration || !identical(client, _runtime.client)) {
        return;
      }

      await _setAutoInitEnabled(false, reason: 'startup', isCurrent: current);
      if (!current()) return;

      final permissionStatus = await getPermissionStatus();
      if (!current()) return;
      if (permissionStatus == PushPermissionStatus.authorized ||
          permissionStatus == PushPermissionStatus.provisional) {
        await _ensureMessagingRuntimeRegistered();
        if (!current()) return;
        await _setAutoInitEnabled(
          true,
          reason: 'existing permission',
          isCurrent: current,
        );
        if (!current()) return;
        unawaited(syncToken());
      }

      if (scope != _scopeGeneration || !identical(client, _runtime.client)) {
        return;
      }
      _authClient = client;
      _authSubscription = client.auth.onAuthStateChange.listen((auth) {
        final sessionUserId = auth.session?.user.id;
        if (sessionUserId != null && sessionUserId.trim().isNotEmpty) {
          _lastKnownUserId = sessionUserId;
        }
        switch (auth.event) {
          case AuthChangeEvent.signedIn:
          case AuthChangeEvent.tokenRefreshed:
          case AuthChangeEvent.userUpdated:
            if (_lastKnownToken != null) {
              unawaited(syncToken());
            }
            break;
          case AuthChangeEvent.signedOut:
            final signedOutUserId = _lastKnownUserId;
            final signedOutToken = _lastKnownToken;
            if (signedOutUserId != null && signedOutToken != null) {
              unawaited(
                unregisterCurrentDevice(
                  userId: signedOutUserId,
                  token: signedOutToken,
                ),
              );
            }
            _lastKnownUserId = null;
            _lastKnownToken = null;
            break;
          default:
            break;
        }
      });

      _initialized = true;
    } on SupabaseSessionChangedException {
      return;
    }
  }

  static Future<PushPermissionStatus> getPermissionStatus() async {
    if (!_isSupported) {
      return PushPermissionStatus.unavailable;
    }

    try {
      final settings = await _runtime.messaging.getNotificationSettings();
      return _mapAuthorizationStatus(settings.authorizationStatus);
    } catch (error, stackTrace) {
      AfriLogger.error(
        'Push',
        'Notification settings unavailable.',
        error,
        stackTrace,
      );
      return PushPermissionStatus.unavailable;
    }
  }

  static Future<PushPermissionStatus> requestPermission() async {
    if (!_isSupported) return PushPermissionStatus.unavailable;
    final runtime = _runtime;
    final authority = SupabaseSessionAuthority.capture(
      clientProvider: () => _runtime.client,
    );
    final scope = _scopeGeneration;
    final generation = _deviceGeneration;
    bool current() =>
        identical(runtime, _runtime) &&
        scope == _scopeGeneration &&
        generation == _deviceGeneration &&
        authority.isCurrent;
    var status = PushPermissionStatus.unavailable;
    try {
      final settings = await runtime.messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      status = _mapAuthorizationStatus(settings.authorizationStatus);
      if (current() &&
          (status == PushPermissionStatus.authorized ||
              status == PushPermissionStatus.provisional)) {
        await _ensureMessagingRuntimeRegistered();
        if (!current()) return status;
        await _setAutoInitEnabled(
          true,
          reason: 'permission granted',
          isCurrent: current,
        );
        if (current()) await syncToken();
      }
      return status;
    } on SupabaseSessionChangedException {
      return status;
    } catch (error, stackTrace) {
      AfriLogger.error('Push', 'Permission request failed.', error, stackTrace);
      return PushPermissionStatus.unavailable;
    } finally {
      await authority.dispose();
    }
  }

  static Future<void> syncToken() async {
    if (!_isSupported) return;
    final runtime = _runtime;
    final authority = SupabaseSessionAuthority.capture(
      clientProvider: () => _runtime.client,
    );
    final scope = _scopeGeneration;
    final generation = ++_deviceGeneration;
    final clubId = _clubId;
    bool current() =>
        identical(runtime, _runtime) &&
        scope == _scopeGeneration &&
        generation == _deviceGeneration &&
        authority.isCurrent;
    try {
      final user = authority.session?.user;
      if (user == null) return;
      final permissionStatus = await getPermissionStatus();
      if (!current() ||
          (permissionStatus != PushPermissionStatus.authorized &&
              permissionStatus != PushPermissionStatus.provisional)) {
        return;
      }
      final enabled = await _isPushEnabledForUser(
        user.id,
        authority: authority,
      );
      if (!current()) return;
      if (!enabled) {
        await unregisterCurrentDevice(userId: user.id, token: _lastKnownToken);
        return;
      }
      await _ensureMessagingRuntimeRegistered();
      if (!current()) return;
      await _setAutoInitEnabled(true, reason: 'token sync', isCurrent: current);
      if (!current()) return;
      final token = await _deviceOperation(
        runtime.messaging.getToken,
        isCurrent: current,
      );
      if (!current() || token == null || token.trim().isEmpty) return;
      _lastKnownUserId = user.id;
      _lastKnownToken = token;
      await _upsertToken(token: token, clubId: clubId, authority: authority);
    } on SupabaseSessionChangedException {
      // An obsolete device operation has no ownership of the new session.
    } catch (error, stackTrace) {
      AfriLogger.error('Push', 'Token sync failed.', error, stackTrace);
    } finally {
      await authority.dispose();
    }
  }

  static Future<void> unregisterCurrentDevice({
    String? userId,
    String? token,
  }) async {
    if (!_isSupported) return;
    final runtime = _runtime;
    final authority = SupabaseSessionAuthority.capture(
      clientProvider: () => _runtime.client,
    );
    final resolvedUserId = userId?.trim().isNotEmpty == true
        ? userId!.trim()
        : authority.session?.user.id;
    final resolvedToken = token?.trim().isNotEmpty == true
        ? token!.trim()
        : _lastKnownToken;
    if (resolvedUserId == null ||
        resolvedUserId.isEmpty ||
        (authority.session != null &&
            authority.session!.user.id != resolvedUserId) ||
        (_lastKnownUserId != null && _lastKnownUserId != resolvedUserId) ||
        (_lastKnownToken != null && _lastKnownToken != resolvedToken)) {
      await authority.dispose();
      return;
    }
    final scope = _scopeGeneration;
    final generation = ++_deviceGeneration;
    bool current() =>
        identical(runtime, _runtime) &&
        scope == _scopeGeneration &&
        generation == _deviceGeneration &&
        authority.isCurrent &&
        (_lastKnownUserId == null || _lastKnownUserId == resolvedUserId) &&
        (_lastKnownToken == null || _lastKnownToken == resolvedToken);
    try {
      if (resolvedUserId.isEmpty ||
          (authority.session != null &&
              authority.session!.user.id != resolvedUserId) ||
          !current()) {
        return;
      }
      await _setAutoInitEnabled(
        false,
        reason: 'token unregister',
        isCurrent: current,
      );
      if (!current()) return;
      if (resolvedToken != null && resolvedToken.trim().isNotEmpty) {
        var delete = authority.client
            .from('user_fcm_tokens')
            .delete()
            .eq('user_id', resolvedUserId)
            .eq('token', resolvedToken)
            .retry(enabled: false);
        final bearer = authority.client.auth.currentSession?.accessToken;
        if (bearer != null) {
          delete = delete.setHeader('Authorization', 'Bearer $bearer');
        }
        await delete;
      }
      if (!current()) return;
      try {
        await _deviceOperation(
          runtime.messaging.deleteToken,
          isCurrent: current,
        );
      } on SupabaseSessionChangedException {
        return;
      } catch (error, stackTrace) {
        AfriLogger.error(
          'Push',
          'Token deletion failed during unregister.',
          error,
          stackTrace,
        );
      }
      if (!current()) return;
      if (_lastKnownUserId == resolvedUserId) _lastKnownUserId = null;
      if (resolvedToken != null && _lastKnownToken == resolvedToken) {
        _lastKnownToken = null;
      }
    } on SupabaseSessionChangedException {
      // A newer registration owns the native token and service fields.
    } catch (error, stackTrace) {
      AfriLogger.error('Push', 'Token unregister failed.', error, stackTrace);
    } finally {
      await authority.dispose();
    }
  }

  static bool get _isSupported => _runtime.isSupported;

  /// Reset only through tests; normal app code uses the Firebase/SDK runtime.
  @visibleForTesting
  static Future<void> configureRuntimeForTesting(
    PushNotificationRuntime? runtime,
  ) async {
    _scopeGeneration++;
    _deviceGeneration++;
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _deviceOperationTail;
    _runtime = runtime ?? PushNotificationRuntime();
    _authSubscription = null;
    _tokenRefreshSubscription = null;
    _messageSubscription = null;
    _authClient = null;
    _initialized = false;
    _messagingRuntimeRegistered = false;
    _clubId = null;
    _lastKnownUserId = null;
    _lastKnownToken = null;
  }

  static Future<T> _deviceOperation<T>(
    Future<T> Function() operation, {
    bool Function()? isCurrent,
  }) {
    final result = _deviceOperationTail.then<T>((_) {
      if (isCurrent != null && !isCurrent()) {
        throw const SupabaseSessionChangedException();
      }
      return operation();
    });
    _deviceOperationTail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }

  static Future<void> _ensureMessagingRuntimeRegistered() async {
    if (!_isSupported || _messagingRuntimeRegistered) return;

    FirebaseMessaging.onBackgroundMessage(
      afriClubFirebaseMessagingBackgroundHandler,
    );

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      try {
        await _runtime.messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (error, stackTrace) {
        AfriLogger.error(
          'Push',
          'Foreground presentation setup failed.',
          error,
          stackTrace,
        );
      }
    }

    await _messageSubscription?.cancel();
    _messageSubscription = FirebaseMessaging.onMessage.listen((message) {
      AfriLogger.info(
        'Push',
        'Foreground message received: ${message.messageId ?? 'unknown'}',
      );
    });

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _runtime.messaging.onTokenRefresh.listen(
      (token) async {
        _lastKnownToken = token;
        await syncToken();
      },
      onError: (Object error, StackTrace stackTrace) {
        AfriLogger.error(
          'Push',
          'Token refresh stream error.',
          error,
          stackTrace,
        );
      },
    );

    _messagingRuntimeRegistered = true;
  }

  static Future<void> _setAutoInitEnabled(
    bool enabled, {
    required String reason,
    bool Function()? isCurrent,
  }) async {
    if (!_isSupported) return;

    try {
      final messaging = _runtime.messaging;
      await _deviceOperation(
        () => messaging.setAutoInitEnabled(enabled),
        isCurrent: isCurrent,
      );
      AfriLogger.info(
        'Push',
        'FCM auto-init ${enabled ? 'enabled' : 'disabled'} ($reason).',
      );
    } on SupabaseSessionChangedException {
      rethrow;
    } catch (error, stackTrace) {
      AfriLogger.error(
        'Push',
        'FCM auto-init ${enabled ? 'enable' : 'disable'} failed ($reason).',
        error,
        stackTrace,
      );
    }
  }

  static Future<bool> _isPushEnabledForUser(
    String userId, {
    required SupabaseSessionAuthority authority,
  }) async {
    try {
      authority.requireCurrent();
      final bearer = authority.client.auth.currentSession!.accessToken;
      final row = await authority.client
          .from('user_notification_settings')
          .select('push_enabled')
          .eq('user_id', userId)
          .maybeSingle()
          .retry(enabled: false)
          .setHeader('Authorization', 'Bearer $bearer');
      return resolvePushDeliveryPreference(
        row == null ? null : Map<String, dynamic>.from(row),
      );
    } catch (error, stackTrace) {
      AfriLogger.error(
        'Push',
        'Push preference lookup failed.',
        error,
        stackTrace,
      );
      // A database failure is not consent to deliver. The caller may retry
      // after settings are available, but must not subscribe on an unknown
      // preference state.
      return resolvePushDeliveryPreference(null, lookupFailed: true);
    }
  }

  static Future<void> subscribeToTopic(String topic) async {
    if (!_isSupported || topic.trim().isEmpty) return;
    final runtime = _runtime;
    final authority = SupabaseSessionAuthority.capture(
      clientProvider: () => _runtime.client,
    );
    final scope = _scopeGeneration;
    final generation = _deviceGeneration;
    bool current() =>
        identical(runtime, _runtime) &&
        scope == _scopeGeneration &&
        generation == _deviceGeneration &&
        authority.isCurrent;
    try {
      final user = authority.session?.user;
      if (user == null ||
          !await _isPushEnabledForUser(user.id, authority: authority) ||
          !current()) {
        return;
      }
      await _deviceOperation(() async {
        await runtime.messaging.subscribeToTopic(topic.trim());
        // A native call already in flight cannot be cancelled. Revoke its
        // obsolete subscription before the next queued owner can subscribe.
        if (!current()) {
          await runtime.messaging.unsubscribeFromTopic(topic.trim());
        }
      }, isCurrent: current);
    } on SupabaseSessionChangedException {
      return;
    } catch (error, stackTrace) {
      AfriLogger.error('Push', 'Topic subscription failed.', error, stackTrace);
    } finally {
      await authority.dispose();
    }
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    if (!_isSupported || topic.trim().isEmpty) return;

    try {
      final messaging = _runtime.messaging;
      await _deviceOperation(
        () => messaging.unsubscribeFromTopic(topic.trim()),
      );
    } catch (error, stackTrace) {
      AfriLogger.error(
        'Push',
        'Topic unsubscribe failed for $topic.',
        error,
        stackTrace,
      );
    }
  }

  static PushPermissionStatus _mapAuthorizationStatus(
    AuthorizationStatus status,
  ) {
    return switch (status) {
      AuthorizationStatus.authorized => PushPermissionStatus.authorized,
      AuthorizationStatus.provisional => PushPermissionStatus.provisional,
      AuthorizationStatus.denied => PushPermissionStatus.denied,
      AuthorizationStatus.notDetermined => PushPermissionStatus.notDetermined,
    };
  }

  static String _platformLabel() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'android';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ios';
    }
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return 'macos';
    }
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return 'windows';
    }
    if (defaultTargetPlatform == TargetPlatform.linux) {
      return 'linux';
    }
    return 'unknown';
  }

  static Future<void> _upsertToken({
    required String token,
    required String? clubId,
    required SupabaseSessionAuthority authority,
  }) async {
    authority.requireCurrent();
    final user = authority.session!.user;
    final payload = <String, dynamic>{
      'user_id': user.id,
      if (clubId != null && int.tryParse(clubId) != null)
        'club_id': int.parse(clubId),
      'token': token,
      'device_platform': _platformLabel(),
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    };
    await authority.client
        .from('user_fcm_tokens')
        .upsert(payload, onConflict: 'token')
        .retry(enabled: false)
        .setHeader(
          'Authorization',
          'Bearer ${authority.client.auth.currentSession!.accessToken}',
        );
  }
}
