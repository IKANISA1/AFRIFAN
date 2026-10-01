import 'package:app_registry/app_registry.dart';
import 'package:club_costa_do_sol/club_costa_do_sol.dart';
import 'package:core_app/bootstrap.dart';

Future<void> startCostaDoSolApp({
  NativeSupporterJourney? nativeSupporterJourney,
}) async {
  const config = CostaDoSolConfig();
  await bootstrap(
    config,
    options: clubBootstrapOptions(
      config,
      nativeSupporterJourney: nativeSupporterJourney,
    ),
  );
}

void main() async {
  await startCostaDoSolApp();
}
