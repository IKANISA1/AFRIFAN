import 'package:app_registry/app_registry.dart';
import 'package:club_yanga/club_yanga.dart';
import 'package:core_app/bootstrap.dart';

void main() async {
  const config = YangaConfig();
  await bootstrap(
    config,
    options: AfriClubBootstrapOptions(
      moduleBuilder: (snapshot) =>
          AppModuleRegistry.build(config, configSnapshot: snapshot),
    ),
  );
}
