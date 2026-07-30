import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/club_content_models.dart';
import '../repositories/club_content_gateway.dart';

final clubContentGatewayProvider = Provider<ClubContentGateway>(
  (ref) => SupabaseClubContentGateway(ref.watch(supabaseClientProvider)),
);

final clubOverviewProvider = FutureProvider<ClubOverview?>(
  (ref) => ref.watch(clubContentGatewayProvider).loadOverview(),
);

final clubNewsProvider = FutureProvider<List<ClubNewsItem>>(
  (ref) => ref.watch(clubContentGatewayProvider).loadNews(),
);

final clubSquadProvider = FutureProvider<List<ClubSquadMember>>(
  (ref) => ref.watch(clubContentGatewayProvider).loadSquad(),
);

final clubMatchesProvider = FutureProvider<List<ClubFixtureItem>>(
  (ref) => ref.watch(clubContentGatewayProvider).loadMatches(),
);

final clubStandingsProvider = FutureProvider<List<ClubStandingItem>>(
  (ref) => ref.watch(clubContentGatewayProvider).loadStandings(),
);

final clubHistoryProvider = FutureProvider<List<ClubHistoryItem>>(
  (ref) => ref.watch(clubContentGatewayProvider).loadHistory(),
);

final clubProjectsProvider = FutureProvider<List<ClubProjectItem>>(
  (ref) => ref.watch(clubContentGatewayProvider).loadProjects(),
);
