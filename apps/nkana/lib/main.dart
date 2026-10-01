import 'package:app_registry/app_registry.dart';
import 'package:club_nkana/club_nkana.dart';
import 'package:core_app/bootstrap.dart';

Future<void> startNkanaApp({
  NativeSupporterJourney? nativeSupporterJourney,
}) async {
  const config = NkanaConfig();
  await bootstrap(
    config,
    options: clubBootstrapOptions(
      config,
      nativeSupporterJourney: nativeSupporterJourney,
    ),
  );
}

void main() async {
  await startNkanaApp();
}
