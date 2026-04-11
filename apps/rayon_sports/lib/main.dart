import 'package:club_rayon_sports/club_rayon_sports.dart';
import 'package:core_app/bootstrap.dart';
import 'firebase_options.dart';

Future<void> startRayonSportsApp({
  AfriClubBootstrapOptions options = const AfriClubBootstrapOptions(),
}) async {
  await bootstrap(const RayonSportsConfig(), options: options);
}

void main() async {
  await startRayonSportsApp(
    options: AfriClubBootstrapOptions(
      startupOptions: AppStartupOptions(
        firebaseOptions: DefaultFirebaseOptions.currentPlatform,
      ),
    ),
  );
}
