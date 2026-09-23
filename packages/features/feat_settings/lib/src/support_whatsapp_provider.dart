import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_actions.dart';

final supportWhatsAppProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  final repository = AppConfigRepository(
    client: ref.watch(supabaseClientProvider),
  );
  final configured = (await repository.getValue(
    AppConfigKeys.supportWhatsApp,
  ))?.trim();
  if (configured != null && configured.isNotEmpty) {
    return configured;
  }

  final fallback = AppLinks.supportWhatsApp.trim();
  return fallback.isEmpty ? null : fallback;
});
