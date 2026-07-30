import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controllers/venue_order_controller.dart';

final venueOrderGatewayProvider = Provider<VenueOrderGateway>(
  (ref) => RepositoryVenueOrderGateway(ref.watch(supabaseClientProvider)),
);

final venueOrderLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final venueOrderMutationTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final venueOrderAccessEnabledProvider = Provider<bool>((ref) => true);

final venueOrderControllerProvider =
    StateNotifierProvider<
      VenueOrderController,
      AsyncValue<VenueOrderRouteState>
    >(
      (ref) => VenueOrderController(
        ref.watch(venueOrderGatewayProvider),
        loadTimeout: ref.watch(venueOrderLoadTimeoutProvider),
        mutationTimeout: ref.watch(venueOrderMutationTimeoutProvider),
      ),
    );
