import 'package:app_registry/app_registry.dart';
import 'package:club_rayon_sports/club_rayon_sports.dart';
import 'package:core_app/bootstrap.dart';

import 'firebase_options.dart';

Future<void> startRayonSportsApp({
  AfriClubBootstrapOptions? options,
}) async {
  const config = RayonSportsConfig();
  await bootstrap(
    config,
    options: options ??
        AfriClubBootstrapOptions(
          moduleBuilder: (snapshot) => AppModuleRegistry.build(
            config,
            configSnapshot: snapshot,
          ),
        ),
  );
}

void main() async {
  const config = RayonSportsConfig();
  await startRayonSportsApp(
    options: AfriClubBootstrapOptions(
      moduleBuilder: (snapshot) => AppModuleRegistry.build(
        config,
        configSnapshot: snapshot,
      ),
      startupOptions: AppStartupOptions(
        firebaseOptions: DefaultFirebaseOptions.currentPlatform,
      ),
    ),
  );
}
