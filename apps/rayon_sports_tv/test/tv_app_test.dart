import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayon_sports_tv/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders native TV-safe code state without private data', (
    tester,
  ) async {
    _setTvSurface(tester, const Size(1280, 720));

    await tester.pumpWidget(
      const RayonSportsTvApp(
        state: TvDisplayState(
          venueName: 'Kigali Arena',
          sessionCode: 'SCREEN24',
          expiresAt: '21:45',
          fetReward: 25,
          prompt: 'Join from the supporter app.',
          phase: 'Open',
        ),
      ),
    );

    expect(find.text('Gikundiro TV'), findsOneWidget);
    expect(find.text('Kigali Arena'), findsOneWidget);
    expect(find.text('SCREEN24'), findsOneWidget);
    expect(find.text('25 FET reward'), findsOneWidget);
    expect(find.text('Expires 21:45'), findsOneWidget);

    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
        .join('\n')
        .toLowerCase();

    expect(visibleText, isNot(contains('phone')));
    expect(visibleText, isNot(contains('email')));
    expect(visibleText, isNot(contains('order queue')));
    expect(visibleText, isNot(contains('wallet')));
  });

  testWidgets('renders without overflow on 1080p TV surface', (tester) async {
    _setTvSurface(tester, const Size(1920, 1080));

    await tester.pumpWidget(const RayonSportsTvApp());
    await tester.pumpAndSettle();

    expect(find.text('Gikundiro TV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Android manifest declares native TV launch contract', () {
    final manifest = File(
      '${_packageRootPrefix()}android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.software.leanback'));
    expect(manifest, contains('android.intent.category.LEANBACK_LAUNCHER'));
    expect(manifest, contains('android.hardware.touchscreen'));
    final forbiddenIconRef =
        '@mipmap/'
        'ic_'
        'launcher';
    expect(manifest, isNot(contains(forbiddenIconRef)));
  });
}

void _setTvSurface(WidgetTester tester, Size logicalSize) {
  tester.view.physicalSize = logicalSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

String _packageRootPrefix() {
  final current = Directory.current.path.replaceAll('\\', '/');
  return current.endsWith('/apps/rayon_sports_tv')
      ? ''
      : 'apps/rayon_sports_tv/';
}
