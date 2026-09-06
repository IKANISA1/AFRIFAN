import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/predict/predict_models.dart';
import 'package:feat_gamification/src/predict/predict_review_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  final fixture = PredictFixture(
    id: 'fixture',
    poolId: 'pool',
    competitionId: 'league',
    competition: 'League',
    homeTeam: 'Home FC',
    awayTeam: 'Away FC',
    homeCrest: '',
    awayCrest: '',
    kickoffAt: DateTime(2030),
    locksAt: DateTime(2030),
    stakeFet: 100,
  );
  for (final mode in ['cancel', 'confirm', 'insufficient', 'large_text']) {
    testWidgets('review $mode preserves a deliberate commitment boundary', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ClubTheme.from(
            ClubConfig.fallback(),
            brightness: Brightness.dark,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(mode == 'large_text' ? 2 : 1),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: AfriTextButton(
                onPressed: () async {
                  result = await showPredictReview(
                    context,
                    fixture: fixture,
                    selection: PredictSelection.draw,
                    balanceFet: mode == 'insufficient' ? 20 : 500,
                  );
                },
                child: const Text('Open review'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open review'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('100 FET'), findsOneWidget);
      final confirm = find.byKey(const ValueKey('predict-confirm-pick'));
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      if (mode == 'insufficient') {
        expect(tester.widget<AfriButton>(confirm).enabled, isFalse);
        expect(find.textContaining('-80'), findsNothing);
      } else if (mode == 'confirm') {
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(result, isTrue);
      } else {
        await tester.ensureVisible(find.text('Cancel'));
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(result, isFalse);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
