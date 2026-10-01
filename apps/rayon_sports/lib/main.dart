import 'package:app_registry/app_registry.dart';
import 'package:club_rayon_sports/club_rayon_sports.dart';
import 'package:core_app/bootstrap.dart';

import 'firebase_options.dart';

Future<void> startRayonSportsApp({
  AfriClubBootstrapOptions? options,
  NativeSupporterJourney? nativeSupporterJourney,
  AppStartupOptions startupOptions = const AppStartupOptions(),
}) async {
  const config = RayonSportsConfig();
  if (options != null && nativeSupporterJourney != null) {
    throw ArgumentError('Supply bootstrap options or a native journey.');
  }
  await bootstrap(
    config,
    options:
        options ??
        clubBootstrapOptions(
          config,
          nativeSupporterJourney: nativeSupporterJourney,
          startupOptions: startupOptions,
        ),
  );
}

void main() async {
  await startRayonSportsApp(
    startupOptions: AppStartupOptions(
      firebaseOptions: DefaultFirebaseOptions.currentPlatform,
    ),
  );
}
