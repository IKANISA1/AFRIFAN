import 'package:app_registry/app_registry.dart';
import 'package:club_costa_do_sol/club_costa_do_sol.dart';
import 'package:core_app/bootstrap.dart';

void main() async {
  const config = CostaDoSolConfig();
  await bootstrap(
    config,
    options: AfriClubBootstrapOptions(
      moduleBuilder: (snapshot) =>
          AppModuleRegistry.build(config, configSnapshot: snapshot),
    ),
  );
}
