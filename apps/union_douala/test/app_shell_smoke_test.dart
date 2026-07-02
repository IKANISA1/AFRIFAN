import 'package:app_registry/app_registry.dart';
import 'package:club_union_douala/club_union_douala.dart';
import 'package:core_router/core_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a valid production route graph', () {
    const config = UnionDoualaConfig();
    final modules = AppModuleRegistry.build(config);
    final router = AppRouter(
      modules: modules,
      initialLocation: '/home',
      shellBuilder: (_, __) => const SizedBox.shrink(),
    );

    expect(config.appName, isNotEmpty);
    expect(config.clubId, isNotEmpty);
    expect(config.features, isNotEmpty);
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
