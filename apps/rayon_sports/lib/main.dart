import 'package:app_registry/app_registry.dart';
import 'package:club_rayon_sports/club_rayon_sports.dart';
import 'package:core_app/bootstrap.dart';

import 'firebase_options.dart';

Future<void> startRayonSportsApp({
  AfriClubBootstrapOptions? options,
}) async {
  await bootstrap(const RayonSportsConfig(), options: options ?? AfriClubBootstrapOptions(modules: AppModuleRegistry.build(const RayonSportsConfig())));
}

void main() async {
  await startRayonSportsApp(
    options: AfriClubBootstrapOptions(
      modules: AppModuleRegistry.build(const RayonSportsConfig()),
      startupOptions: AppStartupOptions(
        firebaseOptions: DefaultFirebaseOptions.currentPlatform,
      ),
    ),
  );
}
