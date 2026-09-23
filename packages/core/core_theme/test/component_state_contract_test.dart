import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  return MaterialApp(
    theme: ClubTheme.from(ClubConfig.fallback()),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('search field exposes bounded clear and disabled behavior', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'supporters');
    addTearDown(controller.dispose);
    var clearCalls = 0;

    await tester.pumpWidget(
      _app(
        AfriSearchInputField(
          controller: controller,
          onClear: () => clearCalls += 1,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Clear Search'));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(clearCalls, 1);
    expect(find.byTooltip('Clear Search'), findsNothing);

    controller.text = 'locked query';
    await tester.pumpWidget(
      _app(AfriSearchInputField(controller: controller, enabled: false)),
    );
    await tester.tap(find.byTooltip('Clear Search'), warnIfMissed: false);
    await tester.pump();
    expect(controller.text, 'locked query');
  });

  testWidgets('inline validation communicates every tone without color alone', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _app(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AfriInlineValidation(message: 'Helpful guidance'),
            AfriInlineValidation(
              message: 'Value accepted',
              tone: AfriInlineValidationTone.success,
            ),
            AfriInlineValidation(
              message: 'Review this value',
              tone: AfriInlineValidationTone.warning,
            ),
            AfriInlineValidation(
              message: 'Value is required',
              tone: AfriInlineValidationTone.error,
            ),
          ],
        ),
      ),
    );

    expect(find.byIcon(AfriIcons.statusInfo), findsOneWidget);
    expect(find.byIcon(AfriIcons.statusSuccess), findsOneWidget);
    expect(find.byIcon(AfriIcons.statusWarning), findsOneWidget);
    expect(find.byIcon(AfriIcons.statusError), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Value is required')),
      matchesSemantics(
        label: 'Error: Value is required',
        isLiveRegion: true,
        isTextField: false,
        isReadOnly: false,
        isFocusable: false,
        hasEnabledState: false,
        hasCheckedState: false,
        hasSelectedState: false,
        validationResult: SemanticsValidationResult.invalid,
      ),
    );
    semantics.dispose();
  });

  testWidgets('toast warning renders an explicit warning treatment', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => AfriToast.warning(context, 'Review required'),
            child: const Text('Show warning'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show warning'));
    await tester.pump();
    expect(find.text('Review required'), findsOneWidget);
    expect(find.byIcon(AfriIcons.statusWarning), findsOneWidget);
  });

  testWidgets('command menu renders selected and disabled items', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => AfriCommandMenu.show<String>(
              context,
              title: 'Commands',
              selectedValue: 'selected',
              items: const [
                AfriCommandItem(
                  value: 'selected',
                  label: 'Selected command',
                  icon: AfriIcons.check,
                ),
                AfriCommandItem(
                  value: 'disabled',
                  label: 'Disabled command',
                  icon: AfriIcons.lock,
                  enabled: false,
                ),
              ],
            ),
            child: const Text('Open commands'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open commands'));
    await tester.pumpAndSettle();
    final selectedTile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Selected command'),
        matching: find.byType(ListTile),
      ),
    );
    final disabledTile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Disabled command'),
        matching: find.byType(ListTile),
      ),
    );
    expect(selectedTile.selected, isTrue);
    expect(disabledTile.enabled, isFalse);
  });

  for (final state in <AfriCommandMenuState>[
    AfriCommandMenuState.loading,
    AfriCommandMenuState.error,
  ]) {
    testWidgets('command menu renders ${state.name} recovery state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => AfriCommandMenu.show<String>(
                context,
                title: 'Commands',
                state: state,
                items: const [],
              ),
              child: const Text('Open commands'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open commands'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          state == AfriCommandMenuState.loading
              ? 'Loading commands'
              : 'Commands unavailable',
        ),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });
  }

  testWidgets('disabled action-sheet rows cannot invoke their callback', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAfriActionSheet(
              context: context,
              actions: [
                AfriSheetAction(
                  icon: AfriIcons.delete,
                  label: 'Unavailable action',
                  enabled: false,
                  onTap: () => taps += 1,
                ),
              ],
            ),
            child: const Text('Open actions'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unavailable action'));
    await tester.pump();
    expect(taps, 0);
    expect(find.text('Unavailable action'), findsOneWidget);
  });

  testWidgets('disabled bottom-nav and side-rail destinations stay inactive', (
    tester,
  ) async {
    var bottomSelections = 0;
    var railSelections = 0;
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            AfriClubBottomNav(
              currentIndex: 0,
              onTap: (_) => bottomSelections += 1,
              items: const [
                AfriClubNavItem(icon: AfriIcons.home, label: 'Home'),
                AfriClubNavItem(
                  icon: AfriIcons.wallet,
                  label: 'Wallet unavailable',
                  enabled: false,
                ),
              ],
            ),
            Expanded(
              child: AfriSideRail(
                selectedIndex: 0,
                onDestinationSelected: (_) => railSelections += 1,
                destinations: const [
                  AfriSideRailDestination(
                    label: 'Home rail',
                    icon: AfriIcons.home,
                    selectedIcon: AfriIcons.home,
                  ),
                  AfriSideRailDestination(
                    label: 'Settings unavailable',
                    icon: AfriIcons.settings,
                    selectedIcon: AfriIcons.settings,
                    enabled: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    await tester.tap(
      find.bySemanticsLabel('Wallet unavailable'),
      warnIfMissed: false,
    );
    await tester.tap(find.text('Settings unavailable'), warnIfMissed: false);
    await tester.pump();
    expect(bottomSelections, 0);
    expect(railSelections, 0);
  });

  testWidgets('disabled tabs cannot replace the selected destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const DefaultTabController(
          length: 3,
          child: AfriTabBar.segmented(
            disabledIndices: {2},
            tabs: [
              Tab(text: 'Live'),
              Tab(text: 'Upcoming'),
              Tab(text: 'Locked'),
            ],
          ),
        ),
      ),
    );

    final controller = DefaultTabController.of(
      tester.element(find.byType(AfriTabBar)),
    );
    expect(controller.index, 0);
    await tester.tap(find.text('Locked'));
    await tester.pumpAndSettle();
    expect(controller.index, 0);
  });
}
