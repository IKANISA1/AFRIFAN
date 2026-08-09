import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/club_repository.dart';

/// Operational health service provider.
final clubHealthServiceProvider = Provider<OperationalHealthService>(
  (ref) => OperationalHealthService(client: ref.watch(supabaseClientProvider)),
);

/// Club repository provider.
final clubRepositoryProvider = Provider<ClubRepository>(
  (ref) => ClubRepository(
    client: ref.watch(supabaseClientProvider),
    healthService: ref.watch(clubHealthServiceProvider),
    storeReleasePolicy: ref.watch(storeReleasePolicyProvider),
  ),
);
