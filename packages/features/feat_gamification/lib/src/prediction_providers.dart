import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/prediction_repository.dart';
export 'repositories/prediction_repository.dart';

final predictionRepositoryProvider = Provider<PredictionRepository>(
  (ref) => PredictionRepository(client: ref.watch(supabaseClientProvider)),
);
