import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/fet_repository.dart';

final fetRepositoryProvider = Provider<FetRepository>(
  (ref) => FetRepository(client: ref.watch(supabaseClientProvider)),
);
