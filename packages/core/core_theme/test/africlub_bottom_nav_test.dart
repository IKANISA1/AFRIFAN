import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the active label and semantic destinations', (
    tester,
  ) async {
    var tappedIndex = -1;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AfriClubBottomNav(
            currentIndex: 1,
            onTap: (index) => tappedIndex = index,
            items: const [
              AfriClubNavItem(icon: Icons.home_rounded, label: 'HOME'),
              AfriClubNavItem(
                icon: Icons.volunteer_activism_rounded,
                label: 'CONTRIBUTE',
              ),
              AfriClubNavItem(icon: Icons.settings_rounded, label: 'SETTINGS'),
            ],
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('CONTRIBUTE'), findsOneWidget);
    expect(find.bySemanticsLabel('HOME'), findsOneWidget);
    expect(find.bySemanticsLabel('SETTINGS'), findsOneWidget);

    await tester.tap(find.byType(AfriPressFeedback).at(2));
    await tester.pump(const Duration(milliseconds: 250));

    expect(tappedIndex, 2);
    semantics.dispose();
  });

  testWidgets('keeps semantic destinations at 200 percent text scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AfriClubBottomNav(
            currentIndex: 1,
            onTap: (_) {},
            items: const [
              AfriClubNavItem(icon: Icons.home_rounded, label: 'HOME'),
              AfriClubNavItem(icon: Icons.sports_soccer, label: 'FAN ZONE'),
              AfriClubNavItem(icon: Icons.settings_rounded, label: 'SETTINGS'),
            ],
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('HOME'), findsOneWidget);
    expect(find.bySemanticsLabel('FAN ZONE'), findsOneWidget);
    expect(find.bySemanticsLabel('SETTINGS'), findsOneWidget);
    semantics.dispose();
  });
}
