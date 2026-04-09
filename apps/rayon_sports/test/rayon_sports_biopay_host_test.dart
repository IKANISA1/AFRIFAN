import 'package:club_rayon_sports/club_rayon_sports.dart';
import 'package:core_app/core_app.dart';
import 'package:core_app/src/module_registry.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      expect(config.hasBiopay, isTrue);
      expect(
        modules.where((module) => module.featureKey == 'biopay'),
        isNotEmpty,
      );
      expect(
        modules
            .where((module) => module.tabRoute != null)
            .map((module) => module.tabRoute!.label),
        contains('BIOPAY'),
      );
    });

    testWidgets('settings expose BioPay entries when the feature is enabled', (
      tester,
    ) async {
      final router = AppRouter(
        modules: modules,
        initialLocation: '/settings',
        shellBuilder: (context, shell) =>
            AppShell(shell: shell, config: config, modules: modules),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith(
              (ref) => const UserProfile(
                id: 'user-1',
                clubId: 'rayon_sports_rw',
                publicUserId: '483912',
                phone: '0788123456',
                momoNumber: '0788123456',
                momoProvider: 'MoMo',
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: ClubTheme.from(config),
            routerConfig: router.router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('BIOPAY & PRIVACY'), findsOneWidget);
      expect(find.text('Privacy Controls'), findsOneWidget);
      expect(find.text('BioPay Home'), findsOneWidget);
      expect(find.text('Face ID & Enrollment'), findsOneWidget);
    });
  });
}
