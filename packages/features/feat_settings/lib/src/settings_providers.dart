import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/user_notification_settings.dart';
import 'models/user_privacy_settings.dart';
import 'settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(client: ref.watch(supabaseClientProvider)),
);

final privacySettingsProvider = FutureProvider<UserPrivacySettings?>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final repository = ref.watch(settingsRepositoryProvider);
  return repository.getPrivacySettings(userId: user.id, clubId: user.clubId);
});

final notificationSettingsProvider = FutureProvider<UserNotificationSettings?>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final repository = ref.watch(settingsRepositoryProvider);
  return repository.getNotificationSettings(
    userId: user.id,
    clubId: user.clubId,
  );
});
