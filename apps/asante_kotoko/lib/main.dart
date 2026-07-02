import 'package:app_registry/app_registry.dart';
import 'package:club_asante_kotoko/club_asante_kotoko.dart';
import 'package:core_app/bootstrap.dart';

void main() async {
  const config = AsanteKotokoConfig();
  await bootstrap(
    config,
    options: AfriClubBootstrapOptions(
      moduleBuilder: (snapshot) =>
          AppModuleRegistry.build(config, configSnapshot: snapshot),
    ),
  );
}
