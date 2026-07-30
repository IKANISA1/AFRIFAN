import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controllers/venue_checkin_controller.dart';

final venueCheckinGatewayProvider = Provider<VenueCheckinGateway>(
  (ref) => RepositoryVenueCheckinGateway(ref.watch(supabaseClientProvider)),
);

final venueCheckinTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final venueCheckinAccessEnabledProvider = Provider<bool>((ref) => true);

final venueCheckinControllerProvider =
    StateNotifierProvider<
      VenueCheckinController,
      AsyncValue<VenueCheckinRouteState>
    >(
      (ref) => VenueCheckinController(
        ref.watch(venueCheckinGatewayProvider),
        timeout: ref.watch(venueCheckinTimeoutProvider),
      ),
    );
