import 'dart:ui' as ui;

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'caps large-phone and tablet content without affecting compact widths',
    () {
      expect(AfriResponsive.maxContentWidthForWidth(320), 320);
      expect(AfriResponsive.maxContentWidthForWidth(430), 430);
      expect(AfriResponsive.maxContentWidthForWidth(599), 480);
      expect(AfriResponsive.sideRailMinWidth, 720);
      expect(AfriResponsive.maxContentWidthForWidth(720), 680);
      expect(AfriResponsive.maxContentWidthForWidth(1200), 960);
    },
  );

  testWidgets(
    'adds navigation clearance to scroll content without view inset',
    (tester) async {
      tester.view.viewPadding = const FakeViewPadding(bottom: 18);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        const MaterialApp(
          home: AfriScreenScaffold(
            showBackButton: false,
            bottomNavigationAware: true,
            padding: EdgeInsets.all(12),
            child: Text('Content'),
          ),
        ),
      );

      final scroll = tester.widget<SingleChildScrollView>(
        find.byKey(const ValueKey('afri-screen-scroll')),
      );
      final bottom = scroll.padding!.resolve(TextDirection.ltr).bottom;
      expect(
        bottom,
        12 +
            AfriClubBottomNav.regularHeight +
            AfriClubBottomNav.bottomMargin +
            AfriClubBottomNav.contentClearance,
      );
      expect(bottom, lessThan(220));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('supports non-scroll route bodies and restoration metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        restorationScopeId: 'app',
        home: AfriScreenScaffold(
          restorationId: 'settings-route',
          showAppBar: false,
          scrollable: false,
          constrainContent: false,
          bottomNavigationAware: true,
          bottomNavigationBar: SizedBox(
            key: ValueKey('route-bottom-navigation'),
            height: 56,
          ),
          child: ColoredBox(key: ValueKey('route-body'), color: Colors.blue),
        ),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.restorationId, 'settings-route');
    expect(find.byKey(const ValueKey('route-body')), findsOneWidget);
    expect(
      scaffold.bottomNavigationBar,
      isA<SizedBox>().having(
        (widget) => widget.key,
        'key',
        const ValueKey('route-bottom-navigation'),
      ),
    );
    expect(
      find.byKey(const ValueKey('afri-screen-bottom-inset')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('gives titled non-scroll content the remaining route height', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AfriScreenScaffold(
          title: 'Club news',
          showBackButton: false,
          scrollable: false,
          child: ColoredBox(
            key: ValueKey('remaining-route-body'),
            color: Colors.blue,
          ),
        ),
      ),
    );

    final bodySize = tester.getSize(
      find.byKey(const ValueKey('remaining-route-body')),
    );
    expect(bodySize.height, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('matches light route chrome to dark status-bar icons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ClubTheme.from(
          ClubConfig.fallback(),
          brightness: Brightness.light,
        ),
        home: const AfriScreenScaffold(
          title: 'Team',
          showBackButton: false,
          child: Text('Content'),
        ),
      ),
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.systemOverlayStyle?.statusBarIconBrightness, Brightness.dark);
    expect(appBar.systemOverlayStyle?.statusBarBrightness, Brightness.light);
    expect(tester.takeException(), isNull);
  });

  testWidgets('caps constrained content on tablet width', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: AfriScreenScaffold(
          showBackButton: false,
          scrollable: false,
          child: SizedBox(
            key: ValueKey('constrained-content'),
            width: double.infinity,
            height: 100,
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('constrained-content'))).width,
      AfriResponsive.desktopContentMax,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the governed compact headline token at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: ClubTheme.from(ClubConfig.fallback()),
        home: const AfriScreenScaffold(
          title: 'Search',
          showBackButton: false,
          child: Text('Content'),
        ),
      ),
    );

    final title = find.text('Search');
    expect(title, findsOneWidget);
    expect(
      tester.widget<Text>(title).style?.fontSize,
      TypographyTokens.semanticSizes['headlineMedium'],
    );
    expect(tester.getSize(title).height, lessThan(80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps full-body treatments outside the responsive content cap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AfriScreenScaffold(
          showAppBar: false,
          scrollable: false,
          bodyWrapper: (child) => ColoredBox(
            key: const ValueKey('full-body-treatment'),
            color: Colors.black,
            child: child,
          ),
          child: const SizedBox(
            key: ValueKey('wrapped-constrained-content'),
            width: double.infinity,
            height: 100,
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('full-body-treatment'))).width,
      1200,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('wrapped-constrained-content')))
          .width,
      AfriResponsive.desktopContentMax,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps task content out of a separating foldable hinge', (
    tester,
  ) async {
    const surface = Size(850, 900);
    const hingeBounds = Rect.fromLTWH(417, 0, 16, 900);
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: surface,
            displayFeatures: [
              ui.DisplayFeature(
                bounds: hingeBounds,
                type: ui.DisplayFeatureType.hinge,
                state: ui.DisplayFeatureState.postureHalfOpened,
              ),
            ],
          ),
          child: AfriScreenScaffold(
            showAppBar: false,
            scrollable: false,
            child: ColoredBox(
              key: ValueKey('hinge-safe-task-content'),
              color: Colors.blue,
            ),
          ),
        ),
      ),
    );

    final contentRect = tester.getRect(
      find.byKey(const ValueKey('hinge-safe-task-content')),
    );
    expect(contentRect.overlaps(hingeBounds), isFalse);
    expect(contentRect.right, lessThanOrEqualTo(hingeBounds.left));
    expect(contentRect.width, lessThanOrEqualTo(417));
    expect(tester.takeException(), isNull);
  });

  testWidgets('removes floating-nav clearance under a side-rail shell', (
    tester,
  ) async {
    late double bottomInset;

    await tester.pumpWidget(
      MaterialApp(
        home: AfriShellNavigationScope(
          usesBottomNavigation: false,
          child: Builder(
            builder: (context) {
              bottomInset = AfriClubBottomNav.contentBottomInset(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(bottomInset, 0);
  });
}
