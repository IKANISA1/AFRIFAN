import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:feat_fan_clubs/feat_fan_clubs.dart';
import 'package:feat_fan_clubs/src/screens/fan_clubs_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  for (final state in [
    'dark',
    'light',
    'large_text',
    'loading',
    'empty',
    'error',
  ]) {
    testWidgets('community discovery $state and safe direct-entry back', (
      tester,
    ) async {
      final large = state == 'large_text';
      final brightness = state == 'light' ? Brightness.light : Brightness.dark;
      tester.view.physicalSize = large
          ? const Size(320, 720)
          : const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TypographyTokens.debugUseFallbackFonts = true;
      ColorTokens.setBrightness(brightness);
      addTearDown(() {
        TypographyTokens.debugUseFallbackFonts = false;
        ColorTokens.setBrightness(Brightness.dark);
      });
      final router = GoRouter(
        initialLocation: '/fan-clubs',
        routes: [
          ...FanClubsModule().routes,
          GoRoute(
            path: '/membership',
            builder: (_, __) => const Text('Membership destination'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fanClubsLoaderProvider.overrideWithValue(() {
              if (state == 'loading') {
                return Completer<List<Map<String, dynamic>>>().future;
              }
              if (state == 'error') {
                return Future.error(StateError('private query details'));
              }
              return Future.value(
                state == 'empty'
                    ? []
                    : [
                        {
                          'id': 'sample-chapter',
                          'name': 'Kigali supporters',
                          'region': 'Kigali',
                          'description':
                              'A community for matchday and club activities.',
                          'member_count': 42,
                          'is_active': true,
                          'is_official': true,
                          'is_featured': true,
                        },
                      ],
              );
            }),
          ],
          child: MaterialApp.router(
            theme: ClubTheme.from(
              ClubConfig.fallback(),
              brightness: brightness,
            ),
            builder: (_, child) => MediaQuery(
              data: MediaQueryData(
                size: tester.view.physicalSize,
                textScaler: TextScaler.linear(large ? 2 : 1),
              ),
              child: RepaintBoundary(
                key: const ValueKey('community-capture'),
                child: child!,
              ),
            ),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(router.routeInformationProvider.value.uri.path, '/fan-clubs');
      expect(find.textContaining('private query details'), findsNothing);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('community-capture')),
        matchesGoldenFile(
          'goldens/fan_clubs_list_state_${state}_${brightness.name}_${large ? '320x720' : '390x844'}.png',
        ),
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Membership destination'), findsOneWidget);
    });
  }
}
