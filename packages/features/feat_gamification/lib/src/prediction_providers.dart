import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/fanzone_models.dart';
import 'models/prediction_models.dart';
import 'repositories/challenge_repository.dart';
import 'repositories/partner_pool_repository.dart';
import 'repositories/prediction_repository.dart';
export 'repositories/challenge_repository.dart';
export 'repositories/partner_pool_repository.dart';
export 'repositories/prediction_repository.dart';

final predictionRepositoryProvider = Provider<PredictionRepository>(
  (ref) => PredictionRepository(client: ref.watch(supabaseClientProvider)),
);

typedef PredictionNotificationsLoader =
    Future<List<PredictionNotification>> Function();

final predictionNotificationsLoaderProvider =
    Provider<PredictionNotificationsLoader>(
      (ref) =>
          () => ref.read(predictionRepositoryProvider).loadNotifications(),
    );

final challengeRepositoryProvider = Provider<ChallengeRepository>(
  (ref) => ChallengeRepository(client: ref.watch(supabaseClientProvider)),
);

final partnerPoolRepositoryProvider = Provider<PartnerPoolRepository>(
  (ref) => PartnerPoolRepository(client: ref.watch(supabaseClientProvider)),
);

class ChallengeFixturesGateway {
  const ChallengeFixturesGateway(this._repository);

  final PredictionRepository _repository;

  Future<List<FixtureSummary>> loadFixtures({
    String? competitionSlug,
    String? status,
    int limit = 50,
    int offset = 0,
  }) {
    return _repository.loadFixtures(
      competitionSlug: competitionSlug,
      status: status,
      limit: limit,
      offset: offset,
    );
  }
}

final challengeFixturesGatewayProvider = Provider<ChallengeFixturesGateway>(
  (ref) => ChallengeFixturesGateway(ref.watch(predictionRepositoryProvider)),
);
