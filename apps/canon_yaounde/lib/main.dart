import 'package:club_canon_yaounde/club_canon_yaounde.dart';
import 'package:app_registry/app_registry.dart';
import 'package:core_app/bootstrap.dart';

void main() async {
  const config = CanonYaoundeConfig();
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
