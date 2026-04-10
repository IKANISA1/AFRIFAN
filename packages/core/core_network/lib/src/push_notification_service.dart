import 'dart:async';

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
  debugPrint(
    '[Push] Background message received: ${message.messageId ?? 'unknown'}',
  );
}

class PushNotificationService {
  PushNotificationService._();

  static bool _initialized = false;
  static String? _clubId;
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
    } catch (error) {
      debugPrint('[Push] Auto-init enable skipped: $error');
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
      } catch (error) {
        debugPrint('[Push] Foreground presentation setup failed: $error');
      }
    }

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        '[Push] Foreground message received: ${message.messageId ?? 'unknown'}',
      );
    });

    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
        .listen(
          (token) async {
            await _upsertToken(token: token);
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('[Push] Token refresh stream error: $error');
          },
        );

    _authSubscription = SupabaseClientFactory.authStateChanges.listen((auth) {
      switch (auth.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
          syncToken();
          break;
        case AuthChangeEvent.signedOut:
          unregisterCurrentDevice();
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
    } catch (error) {
      debugPrint('[Push] Notification settings unavailable: $error');
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
    } catch (error) {
      debugPrint('[Push] Permission request failed: $error');
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

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return;
      await _upsertToken(token: token);
    } catch (error) {
      debugPrint('[Push] Token sync failed: $error');
    }
  }

  static Future<void> unregisterCurrentDevice() async {
    if (!_isSupported) return;

    final user = SupabaseClientFactory.currentUser;
    if (user == null) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return;
      await SupabaseClientFactory.client
          .from('user_fcm_tokens')
          .delete()
          .eq('user_id', user.id)
          .eq('token', token);
    } catch (error) {
      debugPrint('[Push] Token unregister failed: $error');
    }
  }

  static bool get _isSupported => !kIsWeb && Firebase.apps.isNotEmpty;

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
      debugPrint(
        '[Push] Falling back to legacy token sync path while token uniqueness is repaired.',
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
