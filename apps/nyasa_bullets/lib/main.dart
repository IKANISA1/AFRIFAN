import 'package:club_nyasa_bullets/club_nyasa_bullets.dart';
import 'package:app_registry/app_registry.dart';
import 'package:core_app/bootstrap.dart';

void main() async {
  const config = NyasaBulletsConfig();
  await bootstrap(
    config,
    options: AfriClubBootstrapOptions(
      moduleBuilder: (snapshot) => AppModuleRegistry.build(
        config,
        configSnapshot: snapshot,
      ),
    ),
  );
}
