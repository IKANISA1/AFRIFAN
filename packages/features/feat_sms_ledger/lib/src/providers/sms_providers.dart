import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/momo_sms_ingestion_repository.dart';
import '../services/momo_sms_autoread_service.dart';
import '../services/momo_sms_deps.dart';
import '../services/momo_sms_sync_support.dart';

final momoSmsAppAccessServiceProvider = Provider<AppAccessService>((ref) {
  return AppAccessService(openBox: openHiveBox<bool>);
});

final momoSmsSyncEnabledProvider = FutureProvider<bool>((ref) async {
  return ref
      .watch(momoSmsAppAccessServiceProvider)
      .isEnabled(AppAccessPermission.sms);
});

/// Provides the singleton [MomoSmsAutoreadService] instance.
///
/// This service listens for incoming MoMo SMS on Android,
/// ingests them via the `sms-ingest` Edge Function,
/// and manages the retry queue / inbox sync.
final momoSmsAutoreadServiceProvider = Provider<MomoSmsAutoreadService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final service = MomoSmsAutoreadService(
    client: client,
    appAccessService: ref.watch(momoSmsAppAccessServiceProvider),
    countryCode: EnvConfig.countryCode,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Provides the [MomoSmsIngestionRepository] for direct ingestion calls.
final momoSmsIngestionRepositoryProvider =
    Provider<MomoSmsIngestionRepository>((ref) {
  return MomoSmsIngestionRepository(client: ref.watch(supabaseClientProvider));
});

/// Provides the [MomoSmsSyncStateStore] for reading sync state.
final momoSmsSyncStateStoreProvider = Provider<MomoSmsSyncStateStore>((ref) {
  return const MomoSmsSyncStateStore(openBox: openHiveBox<String>);
});
