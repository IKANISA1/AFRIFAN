import 'package:app_registry/app_registry.dart';
import 'package:club_simba/club_simba.dart';
import 'package:core_app/bootstrap.dart';

void main() async {
  const config = SimbaConfig();
  await bootstrap(
    config,
    options: AfriClubBootstrapOptions(
      moduleBuilder: (snapshot) =>
          AppModuleRegistry.build(config, configSnapshot: snapshot),
    ),
  );
}
