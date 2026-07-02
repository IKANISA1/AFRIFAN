import 'package:app_registry/app_registry.dart';
import 'package:club_as_vita/club_as_vita.dart';
import 'package:core_app/bootstrap.dart';

void main() async {
  const config = AsVitaConfig();
  await bootstrap(
    config,
    options: AfriClubBootstrapOptions(
      moduleBuilder: (snapshot) =>
          AppModuleRegistry.build(config, configSnapshot: snapshot),
    ),
  );
}
