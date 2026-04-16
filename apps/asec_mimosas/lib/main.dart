import 'package:club_asec_mimosas/club_asec_mimosas.dart';
import 'package:app_registry/app_registry.dart';
import 'package:core_app/bootstrap.dart';

void main() async {
  const config = AsecMimosasConfig();
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
