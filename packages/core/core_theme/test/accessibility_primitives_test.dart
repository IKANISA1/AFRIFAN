import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reduced-motion media settings resolve shared motion to zero', (
    tester,
  ) async {
    Duration? resolved;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            accessibleNavigation: true,
          ),
          child: Builder(
            builder: (context) {
              resolved = AfriMotion.resolve(context, AfriMotion.emphasized);
              return AfriSegmentedControl(
                items: const <AfriSegment>[
                  AfriSegment(label: 'First'),
                  AfriSegment(label: 'Second'),
                ],
                selectedIndex: 0,
                onChanged: (_) {},
              );
            },
          ),
        ),
      ),
    );

    expect(resolved, Duration.zero);
    expect(
      tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .every((widget) => widget.duration == Duration.zero),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'accessible navigation stops shimmer and modal-sheet transitions',
    (tester) async {
      final observer = _RouteObserver();

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: <NavigatorObserver>[observer],
          home: MediaQuery(
            data: const MediaQueryData(accessibleNavigation: true),
            child: Builder(
              builder: (context) => Column(
                children: [
                  const AfriSkeleton.line(),
                  TextButton(
                    onPressed: () => showAfriBottomSheet<void>(
                      context: context,
                      builder: (_) => const Text('Reduced sheet'),
                    ),
                    child: const Text('Open sheet'),
                  ),
                  TextButton(
                    onPressed: () => showAfriActionSheet(
                      context: context,
                      title: 'Reduced actions',
                      actions: [
                        AfriSheetAction(
                          icon: AfriIcons.more,
                          label: 'Action',
                          onTap: () {},
                        ),
                      ],
                    ),
                    child: const Text('Open actions'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(AfriSkeleton),
          matching: find.byType(AnimatedBuilder),
        ),
        findsNothing,
      );

      await tester.tap(find.text('Open sheet'));
      await tester.pump();
      expect(find.text('Reduced sheet'), findsOneWidget);
      expect(observer.lastRoute?.transitionDuration, Duration.zero);
      Navigator.of(tester.element(find.text('Reduced sheet'))).pop();
      await tester.pump();

      await tester.tap(find.text('Open actions'));
      await tester.pump();
      expect(find.text('Reduced actions'), findsOneWidget);
      expect(observer.lastRoute?.transitionDuration, Duration.zero);
    },
  );

  testWidgets(
    'third-party effect chains render their final state without a delay',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(accessibleNavigation: true),
            child: Builder(
              builder: (context) => const Text('Immediate task content')
                  .afriAnimate(context, delay: AfriMotion.staggerStandard)
                  .fadeIn(duration: AfriMotion.contentReveal),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text('Immediate task content'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  testWidgets(
    'high contrast strengthens shared card boundaries and list hierarchy',
    (tester) async {
      final theme = ClubTheme.from(
        ClubConfig.fallback(),
        brightness: Brightness.light,
        highContrast: true,
      );
      final colors = theme.extension<AfriSemanticColors>()!;

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const MediaQuery(
            data: MediaQueryData(highContrast: true),
            child: Scaffold(
              body: Column(
                children: <Widget>[
                  AfriSurfaceCard(
                    key: ValueKey<String>('high-contrast-card'),
                    child: Text('Card content'),
                  ),
                  AfriListRow(
                    icon: AfriIcons.profile,
                    title: 'Account',
                    subtitle: 'Secondary detail',
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final cardContainer = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('high-contrast-card')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final decoration = cardContainer.decoration! as BoxDecoration;
      final border = decoration.border! as Border;
      expect(border.top.color, colors.border);
      expect(border.top.width, BorderTokens.strong);
      expect(
        tester.widget<Text>(find.text('Secondary detail')).style!.color,
        colors.secondaryText,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'segmented controls expose selected state and keyboard activation',
    (tester) async {
      var selectedIndex = -1;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AfriSegmentedControl(
              items: const <AfriSegment>[
                AfriSegment(label: 'First'),
                AfriSegment(label: 'Second'),
              ],
              selectedIndex: 0,
              onChanged: (index) => selectedIndex = index,
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('First'), findsOneWidget);
      expect(find.bySemanticsLabel('Second'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(selectedIndex, 1);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'scrolling segmented controls keep labels intact at 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AfriSegmentedControl(
              items: const <AfriSegment>[
                AfriSegment(label: 'Pick', icon: Icons.sports_soccer),
                AfriSegment(label: 'League', icon: Icons.table_chart),
                AfriSegment(
                  label: 'Points',
                  icon: Icons.account_balance_wallet,
                ),
                AfriSegment(label: 'Fans', icon: Icons.groups),
                AfriSegment(label: 'Rewards', icon: Icons.card_giftcard),
              ],
              selectedIndex: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      for (final label in const <String>[
        'Pick',
        'League',
        'Points',
        'Fans',
        'Rewards',
      ]) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: '$label should not be ellipsized at 200 percent text.',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stat rows reflow and retain labels at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(24),
            child: AfriStatRow(
              stats: <AfriStat>[
                AfriStat(
                  label: 'Active',
                  value: '4',
                  icon: Icons.event_available,
                ),
                AfriStat(
                  label: 'Accuracy',
                  value: '63%',
                  icon: Icons.sports_soccer,
                ),
                AfriStat(
                  label: 'Points',
                  value: '1250',
                  icon: Icons.account_balance_wallet,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final activeTop = tester.getTopLeft(find.text('ACTIVE')).dy;
    final accuracyTop = tester.getTopLeft(find.text('ACCURACY')).dy;
    final pointsTop = tester.getTopLeft(find.text('POINTS')).dy;
    expect(accuracyTop, greaterThan(activeTop));
    expect(pointsTop, greaterThan(accuracyTop));
    for (final label in const <String>['ACTIVE', 'ACCURACY', 'POINTS']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: '$label should not be ellipsized at 200 percent text.',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('status tones are announced independently of color', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AfriStatusChip(
            label: 'Payment pending',
            tone: AfriStatusTone.warning,
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Warning status: Payment pending'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets(
    'async field errors are live invalid semantics and retain autofill',
    (tester) async {
      final controller = TextEditingController(text: 'supporter@example.com');
      addTearDown(controller.dispose);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AfriInputField(
              controller: controller,
              label: 'Email',
              errorText: 'This address is already registered',
              autofillHints: const <String>[AutofillHints.email],
            ),
          ),
        ),
      );

      final errorNode = tester.getSemantics(
        find.bySemanticsLabel(
          'Email. Error: This address is already registered',
        ),
      );
      expect(
        errorNode,
        matchesSemantics(
          label: 'Email. Error: This address is already registered',
          isLiveRegion: true,
          validationResult: SemanticsValidationResult.invalid,
        ),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).autofillHints,
        contains(AutofillHints.email),
      );
      expect(controller.text, 'supporter@example.com');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}

class _RouteObserver extends NavigatorObserver {
  TransitionRoute<dynamic>? lastRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is TransitionRoute<dynamic>) {
      lastRoute = route;
    }
  }
}
