import 'package:club_asko_kara/club_asko_kara.dart';
import 'package:app_registry/app_registry.dart';
import 'package:core_app/bootstrap.dart';

void main() async {
  const config = AskoKaraConfig();
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
