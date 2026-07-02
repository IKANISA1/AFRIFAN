import 'package:app_registry/app_registry.dart';
import 'package:club_ac_leopards/club_ac_leopards.dart';
import 'package:core_app/bootstrap.dart';

void main() async {
  const config = AcLeopardsConfig();
  await bootstrap(
    config,
    options: AfriClubBootstrapOptions(
      moduleBuilder: (snapshot) =>
          AppModuleRegistry.build(config, configSnapshot: snapshot),
    ),
  );
}
