import 'package:club_nkana/club_nkana.dart';
import 'package:app_registry/app_registry.dart';
import 'package:core_app/bootstrap.dart';

void main() async {
  const config = NkanaConfig();
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
