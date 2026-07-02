import 'package:app_registry/app_registry.dart';
import 'package:club_mogas_90/club_mogas_90.dart';
import 'package:core_app/bootstrap.dart';

void main() async {
  const config = Mogas90Config();
  await bootstrap(
    config,
    options: AfriClubBootstrapOptions(
      moduleBuilder: (snapshot) =>
          AppModuleRegistry.build(config, configSnapshot: snapshot),
    ),
  );
}
