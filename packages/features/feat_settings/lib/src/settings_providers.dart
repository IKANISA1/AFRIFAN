import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/user_notification_settings.dart';
import 'models/user_privacy_settings.dart';
import 'notification_permission_gateway.dart';
import 'settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(client: ref.watch(supabaseClientProvider)),
);

final notificationPermissionGatewayProvider =
    Provider<NotificationPermissionGateway>(
      (ref) => const FirebaseNotificationPermissionGateway(),
    );

final notificationSettingsLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final privacySettingsLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final privacySettingsEditingEnabledProvider = Provider<bool>((ref) => true);

abstract interface class PrivacySettingsReader {
  Future<UserPrivacySettings?> load({
    required String userId,
    required String clubId,
  });
}

class RepositoryPrivacySettingsReader implements PrivacySettingsReader {
  RepositoryPrivacySettingsReader(this._repository);

  final SettingsRepository _repository;

  @override
  Future<UserPrivacySettings?> load({
    required String userId,
    required String clubId,
  }) {
    return _repository.getPrivacySettings(userId: userId, clubId: clubId);
  }
}

final privacySettingsReaderProvider = Provider<PrivacySettingsReader>((ref) {
  return RepositoryPrivacySettingsReader(ref.watch(settingsRepositoryProvider));
});

abstract interface class PrivacySettingsWriter {
  Future<UserPrivacySettings> save(UserPrivacySettings settings);
}

class RepositoryPrivacySettingsWriter implements PrivacySettingsWriter {
  RepositoryPrivacySettingsWriter(this._repository);

  final SettingsRepository _repository;

  @override
  Future<UserPrivacySettings> save(UserPrivacySettings settings) {
    return _repository.updatePrivacySettings(settings);
  }
}

final privacySettingsWriterProvider = Provider<PrivacySettingsWriter>((ref) {
  return RepositoryPrivacySettingsWriter(ref.watch(settingsRepositoryProvider));
});

abstract interface class NotificationSettingsReader {
  Future<UserNotificationSettings?> load({
    required String userId,
    required String clubId,
  });
}

class RepositoryNotificationSettingsReader
    implements NotificationSettingsReader {
  RepositoryNotificationSettingsReader(this._repository);

  final SettingsRepository _repository;

  @override
  Future<UserNotificationSettings?> load({
    required String userId,
    required String clubId,
  }) {
    return _repository.getNotificationSettings(userId: userId, clubId: clubId);
  }
}

final notificationSettingsReaderProvider = Provider<NotificationSettingsReader>(
  (ref) {
    return RepositoryNotificationSettingsReader(
      ref.watch(settingsRepositoryProvider),
    );
  },
);

abstract interface class NotificationSettingsWriter {
  Future<UserNotificationSettings> save(UserNotificationSettings settings);
}

class RepositoryNotificationSettingsWriter
    implements NotificationSettingsWriter {
  RepositoryNotificationSettingsWriter(this._repository);

  final SettingsRepository _repository;

  @override
  Future<UserNotificationSettings> save(UserNotificationSettings settings) {
    return _repository.updateNotificationSettings(settings);
  }
}

final notificationSettingsWriterProvider = Provider<NotificationSettingsWriter>(
  (ref) {
    return RepositoryNotificationSettingsWriter(
      ref.watch(settingsRepositoryProvider),
    );
  },
);

final privacySettingsProvider = FutureProvider<UserPrivacySettings?>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final reader = ref.watch(privacySettingsReaderProvider);
  return reader
      .load(userId: user.id, clubId: user.clubId)
      .timeout(ref.watch(privacySettingsLoadTimeoutProvider));
});

final notificationSettingsProvider = FutureProvider<UserNotificationSettings?>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final reader = ref.watch(notificationSettingsReaderProvider);
  return reader
      .load(userId: user.id, clubId: user.clubId)
      .timeout(ref.watch(notificationSettingsLoadTimeoutProvider));
});
