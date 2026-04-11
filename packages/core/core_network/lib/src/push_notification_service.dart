import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client_factory.dart';

enum PushPermissionStatus {
  unavailable,
  notDetermined,
  denied,
  authorized,
  provisional,
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

class PushNotificationService {
  PushNotificationService._();

  static bool _initialized = false;
  static String? _clubId;
  static String? _lastKnownUserId;
  static String? _lastKnownToken;
  static StreamSubscription<AuthState>? _authSubscription;
  static StreamSubscription<String>? _tokenRefreshSubscription;

  static Future<void> initialize({required String clubId}) async {
    _clubId = clubId;
    if (_initialized || Firebase.apps.isEmpty || kIsWeb) {
      return;
    }

    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();

    FirebaseMessaging.onBackgroundMessage(
      afriClubFirebaseMessagingBackgroundHandler,
    );

    try {
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
    } catch (error, stackTrace) {
      AfriLogger.error('Push', 'Auto-init enable skipped.', error, stackTrace);
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      try {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
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

    FirebaseMessaging.onMessage.listen((message) {
      AfriLogger.info(
        'Push',
        'Foreground message received: ${message.messageId ?? 'unknown'}',
      );
    });

    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
        .listen(
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

    _authSubscription = SupabaseClientFactory.authStateChanges.listen((auth) {
      final sessionUserId = auth.session?.user.id;
      if (sessionUserId != null && sessionUserId.trim().isNotEmpty) {
        _lastKnownUserId = sessionUserId;
      }
      switch (auth.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
          unawaited(syncToken());
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
    await syncToken();
  }

  static Future<PushPermissionStatus> getPermissionStatus() async {
    if (!_isSupported) {
      return PushPermissionStatus.unavailable;
    }

    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
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
    if (!_isSupported) {
      return PushPermissionStatus.unavailable;
    }

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      final status = _mapAuthorizationStatus(settings.authorizationStatus);
      if (status == PushPermissionStatus.authorized ||
          status == PushPermissionStatus.provisional) {
        await syncToken();
      }
      return status;
    } catch (error, stackTrace) {
      AfriLogger.error('Push', 'Permission request failed.', error, stackTrace);
      return PushPermissionStatus.unavailable;
    }
  }

  static Future<void> syncToken() async {
    if (!_isSupported) return;

    final permissionStatus = await getPermissionStatus();
    if (permissionStatus != PushPermissionStatus.authorized &&
        permissionStatus != PushPermissionStatus.provisional) {
      return;
    }

    final user = SupabaseClientFactory.currentUser;
    if (user == null) {
      return;
    }
    if (!await _isPushEnabledForUser(user.id)) {
      await unregisterCurrentDevice(userId: user.id, token: _lastKnownToken);
      return;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return;
      _lastKnownToken = token;
      await _upsertToken(token: token);
    } catch (error, stackTrace) {
      AfriLogger.error('Push', 'Token sync failed.', error, stackTrace);
    }
  }

  static Future<void> unregisterCurrentDevice({
    String? userId,
    String? token,
  }) async {
    if (!_isSupported) return;

    final resolvedUserId = userId?.trim().isNotEmpty == true
        ? userId!.trim()
        : SupabaseClientFactory.currentUser?.id;
    if (resolvedUserId == null || resolvedUserId.isEmpty) return;

    try {
      final resolvedToken = token?.trim().isNotEmpty == true
          ? token!.trim()
          : (_lastKnownToken ?? await FirebaseMessaging.instance.getToken());
      if (resolvedToken != null && resolvedToken.trim().isNotEmpty) {
        await SupabaseClientFactory.client
            .from('user_fcm_tokens')
            .delete()
            .eq('user_id', resolvedUserId)
            .eq('token', resolvedToken);
      }
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (error, stackTrace) {
        AfriLogger.error(
          'Push',
          'Token deletion failed during unregister.',
          error,
          stackTrace,
        );
      }
      if (_lastKnownUserId == resolvedUserId) {
        _lastKnownUserId = null;
      }
      if (resolvedToken != null && _lastKnownToken == resolvedToken) {
        _lastKnownToken = null;
      }
    } catch (error, stackTrace) {
      AfriLogger.error('Push', 'Token unregister failed.', error, stackTrace);
    }
  }

  static bool get _isSupported => !kIsWeb && Firebase.apps.isNotEmpty;

  static Future<bool> _isPushEnabledForUser(String userId) async {
    try {
      final row = await SupabaseClientFactory.client
          .from('user_notification_settings')
          .select('push_enabled')
          .eq('user_id', userId)
          .maybeSingle();
      return row?['push_enabled'] == true;
    } catch (error, stackTrace) {
      AfriLogger.error(
        'Push',
        'Push preference lookup failed.',
        error,
        stackTrace,
      );
      return false;
    }
  }

  static Future<void> subscribeToTopic(String topic) async {
    if (!_isSupported || topic.trim().isEmpty) return;
    final user = SupabaseClientFactory.currentUser;
    if (user == null || !await _isPushEnabledForUser(user.id)) {
      return;
    }

    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic.trim());
    } catch (error, stackTrace) {
      AfriLogger.error(
        'Push',
        'Topic subscription failed for $topic.',
        error,
        stackTrace,
      );
    }
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    if (!_isSupported || topic.trim().isEmpty) return;

    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic.trim());
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

  static Future<void> _upsertToken({required String token}) async {
    final user = SupabaseClientFactory.currentUser;
    if (user == null) return;
    _lastKnownUserId = user.id;
    _lastKnownToken = token;

    final payload = <String, dynamic>{
      'user_id': user.id,
      if (_clubId != null && int.tryParse(_clubId!) != null)
        'club_id': int.parse(_clubId!),
      'token': token,
      'device_platform': _platformLabel(),
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await SupabaseClientFactory.client
          .from('user_fcm_tokens')
          .upsert(payload, onConflict: 'token');
    } on PostgrestException catch (error) {
      // Older environments can lack the unique index required by ON CONFLICT.
      if (error.code != '42P10') rethrow;
      AfriLogger.warn(
        'Push',
        'Falling back to legacy token sync path while token uniqueness is repaired.',
      );
      await _upsertTokenLegacy(userId: user.id, payload: payload);
    }
  }

  static Future<void> _upsertTokenLegacy({
    required String userId,
    required Map<String, dynamic> payload,
  }) async {
    final table = SupabaseClientFactory.client.from('user_fcm_tokens');
    final devicePlatform = payload['device_platform'];

    final updatedByToken = await table
        .update(payload)
        .eq('token', payload['token'])
        .select('id');
    if (updatedByToken.isNotEmpty) {
      return;
    }

    final updatedByDevice = await table
        .update(payload)
        .eq('user_id', userId)
        .eq('device_platform', devicePlatform)
        .select('id');
    if (updatedByDevice.isNotEmpty) {
      return;
    }

    await table.insert(payload);
  }
}
