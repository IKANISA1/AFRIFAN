import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../core_theme/test/support/golden_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadCoreThemeGoldenFonts();
    TypographyTokens.debugUseFallbackFonts = true;
  });
  tearDownAll(() {
    TypographyTokens.debugUseFallbackFonts = false;
  });

  for (final brightness in <Brightness>[Brightness.dark, Brightness.light]) {
    testWidgets('route transition midpoint ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ColorTokens.setBrightness(brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const _RouteSurface(
              title: 'Origin route',
              message: 'Stable content remains behind the transition.',
              icon: AfriIcons.home,
            ),
          ),
          GoRoute(
            path: '/detail',
            pageBuilder: (context, state) => afriRoutePage<void>(
              state,
              const _RouteSurface(
                title: 'Destination route',
                message: 'The pushed route enters with shared motion.',
                icon: AfriIcons.check,
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      final config = ClubConfig.fallback();

      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('route-transition-midpoint'),
          child: ClubConfigScope(
            config: config,
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: ClubTheme.from(config, brightness: brightness),
              routerConfig: router,
            ),
          ),
        ),
      );
      router.go('/detail');
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 110),
        EnginePhase.sendSemanticsUpdate,
      );

      await expectLater(
        find.byKey(const ValueKey('route-transition-midpoint')),
        matchesGoldenFile(
          'goldens/route_transition_midpoint_800x600'
          '${brightness == Brightness.light ? '_light' : ''}.png',
        ),
      );
    });
  }
}

class _RouteSurface extends StatelessWidget {
  const _RouteSurface({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AfriScreenScaffold(
      showAppBar: false,
      scrollable: false,
      child: Center(
        child: AfriStateBanner(
          icon: icon,
          title: title,
          subtitle: message,
          tone: AfriStateBannerTone.brand,
        ),
      ),
    );
  }
}
