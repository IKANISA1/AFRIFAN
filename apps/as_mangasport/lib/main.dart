import 'package:app_registry/app_registry.dart';
import 'package:club_as_mangasport/club_as_mangasport.dart';
import 'package:core_app/bootstrap.dart';

void main() async {
  const config = AsMangasportConfig();
  await bootstrap(
    config,
    options: AfriClubBootstrapOptions(
      moduleBuilder: (snapshot) =>
          AppModuleRegistry.build(config, configSnapshot: snapshot),
    ),
  );
}
