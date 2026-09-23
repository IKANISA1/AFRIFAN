import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/feat_gamification.dart';
import 'package:feat_gamification/src/predict/predict_controller.dart';
import 'package:feat_gamification/src/predict/predict_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';
import 'package:test_support/predict_fixture_images.dart';
import 'package:test_support/touch_target_audit.dart';
import 'predict_controller_test.dart' show fixture;
import 'predict_screen_test.dart' show ScreenController;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() async {
    ConnectivityService.setOnlineForTest(true);
    await installPredictFixtureImages();
  });
  tearDown(() => debugNetworkImageHttpClientProvider = null);

  for (final entry in {
    '/predict': '/predict',
    '/predict?section=wallet': '/predict?section=wallet',
    '/predict?section=history': '/predict?section=history',
  }.entries) {
    testWidgets('${entry.key} uses the single Predict experience', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TypographyTokens.debugUseFallbackFonts = true;
      addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
      final controller = ScreenController(
        PredictState(
          dashboard: PredictDashboard(
            enabled: true,
            memberSession: true,
            balanceFet: 500,
            fixtures: [fixture()],
            history: [fixture()],
          ),
        ),
      );
      final module = PredictModule();
      final router = GoRouter(
        initialLocation: entry.key,
        routes: [
          ShellRoute(
            builder: (context, state, child) => RepaintBoundary(
              key: const ValueKey('predict-shell-capture'),
              child: Scaffold(
                body: Stack(
                  children: [
                    Positioned.fill(child: child),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: AfriClubBottomNav(
                        currentIndex: 2,
                        onTap: (index) => context.go(
                          ['/home', '/club', '/predict', '/membership'][index],
                        ),
                        items: const [
                          AfriClubNavItem(label: 'Home', icon: AfriIcons.home),
                          AfriClubNavItem(
                            label: 'Club',
                            icon: AfriIcons.stadium,
                          ),
                          AfriClubNavItem(
                            label: 'Predict',
                            icon: AfriIcons.predict,
                          ),
                          AfriClubNavItem(
                            label: 'Membership',
                            icon: AfriIcons.membership,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            routes: [
              GoRoute(
                path: module.tabRoute.path,
                builder: module.tabRoute.builder,
              ),
              for (final path in ['/home', '/club', '/membership'])
                GoRoute(
                  path: path,
                  builder: (_, __) => const SizedBox.shrink(),
                ),
            ],
          ),
          ...module.standaloneRoutes,
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            predictControllerProvider.overrideWith((_) => controller),
          ],
          child: MaterialApp.router(
            theme: ClubTheme.from(ClubConfig.fallback()),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        final context = tester.element(find.byType(PredictScreen));
        await Future.wait([
          precacheImage(
            const NetworkImage('https://example.com/home.png'),
            context,
          ),
          precacheImage(
            const NetworkImage('https://example.com/away.png'),
            context,
          ),
        ]);
      });
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.toString(), entry.value);
      expect(find.byType(PredictScreen), findsOneWidget);
      expect(find.text('Predict'), findsNWidgets(2));
      expect(find.text('500 FET'), findsOneWidget);
      expect(find.text('Fixtures'), findsOneWidget);
      expect(find.text('My picks'), findsOneWidget);
      expect(find.text('FET activity'), findsOneWidget);
      expect(find.text('Fans'), findsNothing);
      expect(find.text('League'), findsNothing);
      expect(find.text('Create challenge'), findsNothing);
      expectTapTargetsMeetMinimum(tester);
      expect(tester.takeException(), isNull);
      if (entry.key == '/predict') {
        await expectLater(
          find.byKey(const ValueKey('predict-shell-capture')),
          matchesGoldenFile('goldens/predict_shell_dark_390x844.png'),
        );
        await tester.tap(find.text('My picks'));
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.toString(),
          '/predict?section=history',
        );
        expect(find.byType(AfriClubBottomNav), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      debugNetworkImageHttpClientProvider = null;
    });
  }
}
