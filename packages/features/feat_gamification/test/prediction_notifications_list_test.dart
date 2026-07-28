import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/models/fanzone_models.dart';
import 'package:feat_gamification/src/prediction_providers.dart';
import 'package:feat_gamification/src/screens/prediction_notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  Widget buildSubject({
    required List<PredictionNotification> notifications,
    void Function(PredictionNotification notification)? onOpenNotification,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PredictionNotificationsList(
          notifications: notifications,
          onOpenNotification: onOpenNotification,
        ),
      ),
    );
  }

  testWidgets('returns SizedBox.shrink when notifications list is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(notifications: const <PredictionNotification>[]),
    );

    expect(find.text('No prediction alerts yet'), findsNothing);
    expect(
      find.textContaining('Settlement and result notifications'),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('prediction-notifications-empty')),
      findsOne,
    );
  });

  testWidgets('renders notification cards with semantic summaries', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    try {
      const notification = PredictionNotification(
        id: 'notification-1',
        notificationType: 'settlement',
        title: 'Prediction settled',
        body: 'Your Rayon Sports result prediction won.',
        payload: <String, dynamic>{
          'route': '/fanzone/my/prediction-1',
          'earned': 120,
        },
        createdAt: null,
        isSent: true,
      );
      PredictionNotification? openedNotification;

      await tester.pumpWidget(
        buildSubject(
          notifications: const <PredictionNotification>[notification],
          onOpenNotification: (value) {
            openedNotification = value;
          },
        ),
      );

      expect(find.text('Prediction settled'), findsOneWidget);
      expect(
        find.text('Your Rayon Sports result prediction won.'),
        findsOneWidget,
      );
      expect(find.text('+120 pts'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Prediction alert, Prediction settled, '
          'Your Rayon Sports result prediction won., Just now, reward 120 points',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('OPEN'));
      await tester.pump();

      expect(openedNotification, notification);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'notification route uses the responsive scaffold at 200 percent',
    (tester) async {
      tester.view.physicalSize = const Size(720, 1024);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            predictionNotificationsLoaderProvider.overrideWithValue(
              () async => const <PredictionNotification>[],
            ),
          ],
          child: const MaterialApp(home: PredictionNotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AfriScreenScaffold), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('prediction-notifications-empty')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final profile in _compactGoldenProfiles) {
    testWidgets('golden compact prediction notifications route ${profile.id}', (
      tester,
    ) async {
      _setGoldenSurface(tester, profile.size);
      TypographyTokens.debugUseFallbackFonts = true;
      addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
      ColorTokens.setBrightness(profile.brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            predictionNotificationsLoaderProvider.overrideWithValue(
              () async => const <PredictionNotification>[
                PredictionNotification(
                  id: 'notification-1',
                  notificationType: 'settlement',
                  title: 'Prediction settled',
                  body: 'Your Rayon Sports result prediction won.',
                  payload: <String, dynamic>{
                    'route': '/fanzone/my/prediction-1',
                    'earned': 120,
                  },
                  createdAt: null,
                  isSent: true,
                ),
              ],
            ),
          ],
          child: MaterialApp(
            theme: ClubTheme.from(
              ClubConfig.fallback(),
              brightness: profile.brightness,
            ),
            home: const RepaintBoundary(
              key: ValueKey<String>('notifications-route-golden'),
              child: PredictionNotificationsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey<String>('notifications-route-golden')),
        matchesGoldenFile('goldens/notifications_${profile.id}.png'),
      );
    });
  }
}

const _compactGoldenProfiles =
    <({String id, Size size, Brightness brightness})>[
      (
        id: 'compact_dark_320x760',
        size: Size(320, 760),
        brightness: Brightness.dark,
      ),
      (
        id: 'compact_light_374x812',
        size: Size(374, 812),
        brightness: Brightness.light,
      ),
      (
        id: 'standard_dark_390x844',
        size: Size(390, 844),
        brightness: Brightness.dark,
      ),
      (
        id: 'large_light_430x900',
        size: Size(430, 900),
        brightness: Brightness.light,
      ),
      (
        id: 'wide_dark_599x900',
        size: Size(599, 900),
        brightness: Brightness.dark,
      ),
      (
        id: 'foldable_half_light_674x842',
        size: Size(674, 842),
        brightness: Brightness.light,
      ),
      (
        id: 'tablet_dark_834x1194',
        size: Size(834, 1194),
        brightness: Brightness.dark,
      ),
    ];

void _setGoldenSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(
        disableAnimations: true,
        accessibleNavigation: true,
      );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}
