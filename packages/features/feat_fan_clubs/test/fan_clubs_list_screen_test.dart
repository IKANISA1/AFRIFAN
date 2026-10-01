import 'dart:async';
import 'dart:io';

import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_fan_clubs/feat_fan_clubs.dart';
import 'package:feat_fan_clubs/src/screens/fan_clubs_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:test_support/app_font_loader.dart';
import 'package:test_support/predict_fixture_images.dart';

import '../../../testing/test_support/test/fixtures/local_route_state_assertions.dart';

void main({bool localStateCoverage = false}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  for (final state in [
    'dark',
    'light',
    'large_text',
    'loading',
    'empty',
    'error',
    if (localStateCoverage) ...[
      'offline',
      'permission_denied',
      'disabled',
      'focused',
      'pressed',
      'selected',
      'reduced_motion',
      'syncing',
      'conflict',
      'security_timeout',
    ],
  ]) {
    testWidgets('community discovery $state and safe direct-entry back', (
      tester,
    ) async {
      await installPredictFixtureImages();
      final large = state == 'large_text';
      final brightness = state == 'light' ? Brightness.light : Brightness.dark;
      final pending = Completer<List<Map<String, dynamic>>>();
      var calls = 0;
      addTearDown(() {
        if (!pending.isCompleted) pending.complete([]);
      });
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
      final router = state == 'disabled'
          ? AppRouter(
              modules: [FanClubsModule()],
              initialLocation: '/fan-clubs',
              shellBuilder: (_, shell) => Scaffold(body: shell),
              isFeatureEnabled: (path) => path != '/fan-clubs',
            ).router
          : GoRouter(
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
              calls++;
              if (state == 'loading') {
                return pending.future;
              }
              if (state == 'offline') {
                return Future.error(
                  const SocketException('private query details'),
                );
              }
              if (state == 'permission_denied' || state == 'conflict') {
                return Future.error(
                  PostgrestException(
                    message: 'private query details',
                    code: state == 'conflict' ? '40001' : '42501',
                  ),
                );
              }
              if (state == 'security_timeout') {
                return pending.future.timeout(
                  const Duration(milliseconds: 100),
                );
              }
              if (state == 'syncing' && calls > 1) return pending.future;
              if (state == 'error') {
                return Future.error(StateError('private query details'));
              }
              return Future.value(
                state == 'empty'
                    ? []
                    : [
                        {
                          'id': 'sample-FanClubs',
                          'name': 'Kigali supporters',
                          'region': 'Kigali',
                          'description':
                              'A community for matchday and club activities.',
                          'member_count': 42,
                          'banner_image_url':
                              'https://fixture.test/fanclub.webp',
                          'is_active': true,
                          'is_official': true,
                          'is_featured': true,
                        },
                        if (state == 'selected' || state == 'pressed')
                          {
                            'id': 'second-local-community',
                            'name': 'Away supporters',
                            'region': 'Away',
                            'member_count': 12,
                            'is_active': true,
                          },
                      ],
              );
            }),
          ],
          child: MaterialApp.router(
            theme: ClubTheme.from(
              localRouteConfigOrFallback(),
              brightness: brightness,
            ),
            builder: (_, child) => MediaQuery(
              data: MediaQueryData(
                size: tester.view.physicalSize,
                textScaler: TextScaler.linear(large ? 2 : 1),
                disableAnimations: state == 'reduced_motion',
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
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage((element.widget as Image).image, element);
        }
      });
      await tester.pump();
      expect(
        router.routeInformationProvider.value.uri.path,
        state == 'disabled' ? '/feature-unavailable' : '/fan-clubs',
      );
      if ([
        'error',
        'offline',
        'permission_denied',
        'conflict',
        'security_timeout',
      ].contains(state)) {
        expect(calls, 1);
        expect(find.byType(AfriErrorView), findsOneWidget);
        expect(find.text('Kigali supporters'), findsNothing);
      }
      if (state == 'disabled') {
        expect(calls, 0);
        expect(
          tester
              .widget<RouteRecoveryScreen>(find.byType(RouteRecoveryScreen))
              .visualState,
          RouteRecoveryVisualState.disabled,
        );
      }
      if (state == 'focused') {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.context, isNotNull);
      }
      if (state == 'selected') {
        await tester.tap(find.widgetWithText(AfriChoiceChip, 'Kigali'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AfriChoiceChip>(
                find.widgetWithText(AfriChoiceChip, 'Kigali'),
              )
              .selected,
          isTrue,
        );
      }
      TestGesture? held;
      if (state == 'pressed') {
        held = await tester.startGesture(
          tester.getCenter(find.widgetWithText(AfriChoiceChip, 'All')),
        );
        await tester.pump(const Duration(milliseconds: 120));
      }
      if (state == 'syncing') {
        unawaited(
          tester
              .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
              .show(),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(calls, 2);
        expect(pending.isCompleted, isFalse);
        expect(find.text('Kigali supporters'), findsWidgets);
        expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      }
      expect(find.textContaining('private query details'), findsNothing);
      expect(tester.takeException(), isNull);
      await expectGoldenOrClubAssertions(
        tester,
        find.byKey(const ValueKey('community-capture')),

        'goldens/fan_clubs_list_state_${state}_${brightness.name}_${large ? '320x720' : '390x844'}.png',
        route: '/fan-clubs',
        kind: 'route',
        surface: 'mobile',
      );
      await held?.cancel();
      if (!pending.isCompleted) pending.complete([]);
      if (state != 'disabled') {
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(find.text('Membership destination'), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      debugNetworkImageHttpClientProvider = null;
    });
  }
}
