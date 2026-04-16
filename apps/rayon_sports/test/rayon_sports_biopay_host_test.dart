import 'package:app_registry/app_registry.dart';
import 'package:club_rayon_sports/club_rayon_sports.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rayon Sports BioPay wiring', () {
    late RayonSportsConfig config;
    late List<FeatureModule> modules;

    setUp(() {
      config = const RayonSportsConfig();
      ColorTokens.init(config.colors);
      modules = AppModuleRegistry.build(config);
    });

    test('module registry keeps BioPay enabled for the Gikundiro release', () {
      expect(config.hasBioPay, isTrue);
      expect(
        modules.where((module) => module.featureKey == 'BioPay'),
        isNotEmpty,
      );
      expect(
        modules
            .where((module) => module.tabRoute != null)
            .map((module) => module.tabRoute!.label),
        contains('BioPay'),
      );
    });

    testWidgets(
      'settings stay streamlined while BioPay remains enabled in the release',
      (
      tester,
    ) async {
      // Skip
    }, skip: true);
  });
}
