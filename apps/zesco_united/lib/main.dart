import 'package:app_registry/app_registry.dart';
import 'package:club_zesco_united/club_zesco_united.dart';
import 'package:core_app/bootstrap.dart';

void main() async {
  const config = ZescoUnitedConfig();
  await bootstrap(
    config,
    options: AfriClubBootstrapOptions(
      moduleBuilder: (snapshot) =>
          AppModuleRegistry.build(config, configSnapshot: snapshot),
    ),
  );
}
