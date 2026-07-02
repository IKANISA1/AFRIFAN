import 'package:app_registry/app_registry.dart';
import 'package:club_maranatha/club_maranatha.dart';
import 'package:core_app/bootstrap.dart';

void main() async {
  const config = MaranathaConfig();
  await bootstrap(
    config,
    options: AfriClubBootstrapOptions(
      moduleBuilder: (snapshot) =>
          AppModuleRegistry.build(config, configSnapshot: snapshot),
    ),
  );
}
