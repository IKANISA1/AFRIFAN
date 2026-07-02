import 'package:app_registry/app_registry.dart';
import 'package:club_union_douala/club_union_douala.dart';
import 'package:core_app/bootstrap.dart';

void main() async {
  const config = UnionDoualaConfig();
  await bootstrap(
    config,
    options: AfriClubBootstrapOptions(
      moduleBuilder: (snapshot) =>
          AppModuleRegistry.build(config, configSnapshot: snapshot),
    ),
  );
}
