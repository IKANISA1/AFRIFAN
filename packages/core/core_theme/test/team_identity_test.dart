import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'club aliases resolve to the published crest, including duplicate feed names',
    () {
      const expected = {
        'Rayon Sports FC': ['RAY', 'rayon-sports.png'],
        'rayon_sports_rw': ['RAY', 'rayon-sports.png'],
        '24': ['RAY', 'rayon-sports.png'],
        'Nkana FC': ['NKA', 'nkana.png'],
        'as_vita': ['VIT', 'as-vita.png'],
        'Vital’O FC': ['VFC', 'vitalo.png'],
        'Marine FC': ['MAR', 'marine-fc.png'],
        'APR FC': ['APR', 'apr-fc.png'],
      };
      for (final entry in expected.entries) {
        expect(teamInitials(entry.key), entry.value.first, reason: entry.key);
        expect(
          teamAssetFor(entry.key)?.asset,
          endsWith(entry.value.last),
          reason: entry.key,
        );
      }
      expect(teamAssetFor('Another Rayon Sports'), isNull);
    },
  );

  testWidgets('narrow enlarged cards preserve official artwork and side order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: AfriFixtureCard(
                homeTeam: 'Rayon Sports FC',
                awayTeam: 'APR FC',
                score: '12–10',
                subtitle:
                    'Rwanda Premier League\n8 Aug 2026 · 17:00\nKigali Pele Stadium',
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Rayon Sports FC'), findsNothing);
    expect(
      tester.getCenter(find.text('RAY')).dx,
      lessThan(tester.getCenter(find.text('APR')).dx),
    );
    final images = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<AssetImage>();
    expect(
      images.map((image) => image.assetName),
      containsAll([
        'packages/core_theme/assets/crests/rayon-sports.png',
        'packages/core_theme/assets/crests/apr-fc.png',
      ]),
    );
  });

  testWidgets(
    'team picker returns the full stored name and cancels without changes',
    (tester) async {
      var storedName = 'Rayon Sports FC';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => AfriTeamField(
                value: storedName,
                semanticLabel: 'First team',
                onChanged: (value) => setState(() => storedName = value),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(AfriTeamField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'APR FC');
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Use APR FC'));
      await tester.pumpAndSettle();
      expect(storedName, 'APR FC');
      expect(find.text('APR'), findsOneWidget);
      await tester.tap(find.byType(AfriTeamField));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(TextField))).pop();
      await tester.pumpAndSettle();
      expect(storedName, 'APR FC');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unknown teams never receive a fabricated badge', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AfriTeamCard(name: 'Unknown United')),
      ),
    );
    expect(find.text('UU'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Icon), findsNothing);
    expect(find.byType(AfriTeamCrest), findsNothing);
    expect(
      tester.getSize(find.byType(AfriTeamCard)).height,
      lessThanOrEqualTo(48),
    );
  });
}
