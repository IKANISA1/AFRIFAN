import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/admin_repository.dart';
import 'repositories/feature_management_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(client: ref.watch(supabaseClientProvider));
});

final isAdminProvider = FutureProvider<bool>((ref) async {
  return ref.read(adminRepositoryProvider).isCurrentUserAdmin();
});

final featureManagementRepositoryProvider =
    Provider<FeatureManagementRepository>((ref) {
      return FeatureManagementRepository(
        client: ref.watch(supabaseClientProvider),
      );
    });
