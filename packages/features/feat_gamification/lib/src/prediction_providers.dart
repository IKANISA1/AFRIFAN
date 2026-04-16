import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/challenge_repository.dart';
import 'repositories/prediction_repository.dart';
export 'repositories/challenge_repository.dart';
export 'repositories/prediction_repository.dart';

final predictionRepositoryProvider = Provider<PredictionRepository>(
  (ref) => PredictionRepository(client: ref.watch(supabaseClientProvider)),
);

final challengeRepositoryProvider = Provider<ChallengeRepository>(
  (ref) => ChallengeRepository(client: ref.watch(supabaseClientProvider)),
);
