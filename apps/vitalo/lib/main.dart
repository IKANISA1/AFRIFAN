import 'package:app_registry/app_registry.dart';
import 'package:club_vitalo/club_vitalo.dart';
import 'package:core_app/bootstrap.dart';

Future<void> startVitaloApp({
  NativeSupporterJourney? nativeSupporterJourney,
}) async {
  const config = VitaloConfig();
  await bootstrap(
    config,
    options: clubBootstrapOptions(
      config,
      nativeSupporterJourney: nativeSupporterJourney,
    ),
  );
}

void main() async {
  await startVitaloApp();
}
