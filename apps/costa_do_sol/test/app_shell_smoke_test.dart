import 'package:app_registry/app_registry.dart';
import 'package:club_costa_do_sol/club_costa_do_sol.dart';
import 'package:core_router/core_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a valid production route graph', () {
    const config = CostaDoSolConfig();
    final modules = AppModuleRegistry.build(config);
    final router = AppRouter(
      modules: modules,
      initialLocation: '/home',
      shellBuilder: (_, __) => const SizedBox.shrink(),
    );

    expect(config.appName, 'Costa do Sol');
    expect(config.clubName, 'CD Costa do Sol');
    expect(config.clubId, '1001');
    expect(config.countryCode, 'MZ');
    expect(config.currency, 'MZN');
    expect(config.momo.ussdTemplate, isEmpty);
    expect(config.features.values, everyElement(isFalse));
    expect(
      modules.where((module) => module.tabRoute != null).length,
      greaterThanOrEqualTo(2),
    );
    expect(modules.any((module) => module.tabRoute?.path == '/home'), isTrue);
    expect(
      modules.any((module) => module.tabRoute?.path == '/settings'),
      isTrue,
    );
    expect(router.initialLocation, '/home');
  });
}
