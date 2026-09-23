import 'package:core_auth/core_auth.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_ticketing/src/screens/match_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('missing fixture uses the responsive scaffold on tablet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1024);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeReleasePolicyProvider.overrideWithValue(
            const StoreReleasePolicy.unenforced(),
          ),
          currentUserProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(
          home: MatchDetailScreen(matchId: 'fixture-missing'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AfriScreenScaffold), findsOneWidget);
    expect(find.text('Fixture not found'), findsOneWidget);
    expect(
      tester.getSize(find.text('Fixture not found')).width,
      lessThanOrEqualTo(AfriResponsive.tabletContentMax),
    );
    expect(tester.takeException(), isNull);
  });
}
