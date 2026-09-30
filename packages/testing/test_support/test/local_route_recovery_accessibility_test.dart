import 'dart:convert';
import 'dart:io';

import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/foundation.dart' show debugPrintSynchronously;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/app_font_loader.dart';

import '../../../app_registry/tool/generate_route_inventory.dart';
import 'fixtures/five_club_configs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  final workspace = resolveRouteInventoryWorkspace(Directory.current);
  final clubs = fiveClubFixtures(workspace);
  for (final club in clubs.entries) {
    for (final kind in RouteRecoveryKind.values) {
      for (final state in RouteRecoveryVisualState.values) {
        final name = '${club.key}|${kind.name}|${state.name}';
        testWidgets('route recovery behavioral and automated accessibility $name', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          try {
            tester.view.physicalSize = const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final large = state == RouteRecoveryVisualState.largeText;
            final motion = state == RouteRecoveryVisualState.reducedMotion;
            final light = state == RouteRecoveryVisualState.light;
            await tester.pumpWidget(
              MaterialApp(
                theme: ClubTheme.from(
                  club.value,
                  brightness: light ? Brightness.light : Brightness.dark,
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(large ? 2 : 1),
                    disableAnimations: motion,
                    accessibleNavigation: motion,
                  ),
                  child: ClubConfigScope(config: club.value, child: child!),
                ),
                home: RouteRecoveryScreen(
                  kind: kind,
                  visualState: state,
                  requestedPath:
                      '/membership/SENSITIVE_PERSON?token=SENSITIVE_TOKEN',
                  fallbackLocation: '/home',
                ),
              ),
            );
            // Loading animations deliberately remain active: do not settle them.
            await tester.pump(const Duration(milliseconds: 250));
            expect(find.byType(RouteRecoveryScreen), findsOneWidget);
            expect(find.textContaining('SENSITIVE'), findsNothing);
            final title = switch (state) {
              RouteRecoveryVisualState.loading => 'Checking feature access',
              RouteRecoveryVisualState.empty => 'No destination details',
              RouteRecoveryVisualState.offline =>
                'This route needs a connection.',
              RouteRecoveryVisualState.permissionDenied =>
                'You do not have access.',
              RouteRecoveryVisualState.syncing => 'Refreshing route access',
              RouteRecoveryVisualState.conflict => 'Route access changed.',
              RouteRecoveryVisualState.securityTimeout =>
                'The route check timed out.',
              RouteRecoveryVisualState.error =>
                kind == RouteRecoveryKind.featureUnavailable
                    ? 'We could not check this feature.'
                    : 'We could not open that page.',
              _ =>
                kind == RouteRecoveryKind.featureUnavailable
                    ? 'This feature is currently unavailable.'
                    : 'We could not open that page.',
            };
            expect(find.text(title), findsOneWidget);
            final destination = find.bySemanticsLabel(
              RegExp(
                kind == RouteRecoveryKind.featureUnavailable
                    ? 'Requested section requested'
                    : 'Membership requested',
              ),
            );
            expect(destination, findsOneWidget);
            expect(
              tester
                      .getSemantics(destination)
                      .flagsCollection
                      .isSelected
                      .toBoolOrNull() ??
                  false,
              state == RouteRecoveryVisualState.selected,
            );
            if (state == RouteRecoveryVisualState.focused) {
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
              await tester.pump();
              expect(FocusManager.instance.primaryFocus, isNotNull);
              expect(FocusManager.instance.primaryFocus!.context, isNotNull);
              expect(
                FocusManager.instance.primaryFocus!.context!.widget,
                isA<Focus>(),
              );
            }
            TestGesture? heldGesture;
            if (state == RouteRecoveryVisualState.pressed) {
              final action = find
                  .text(
                    kind == RouteRecoveryKind.featureUnavailable
                        ? 'Go back'
                        : 'Go home',
                  )
                  .first;
              final detector = find.ancestor(
                of: action,
                matching: find.byType(GestureDetector),
              );
              expect(detector, findsOneWidget);
              heldGesture = await tester.startGesture(
                tester.getCenter(detector),
              );
              // The first frame delivers delayed tapDown; advance the
              // press ticker separately while the pointer remains held.
              await tester.pump(const Duration(milliseconds: 160));
              await tester.pump(AfriMotion.press);
              expect(
                tester
                    .widgetList<ScaleTransition>(
                      find.descendant(
                        of: detector,
                        matching: find.byType(ScaleTransition),
                      ),
                    )
                    .any((transition) => transition.scale.value < 1),
                isTrue,
              );
            }
            if (motion) {
              expect(
                tester
                    .widget<AnimatedContainer>(
                      find.byKey(
                        const ValueKey<String>('route-recovery-destination'),
                      ),
                    )
                    .duration,
                Duration.zero,
              );
            }
            expect(tester.takeException(), isNull);
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            await heldGesture?.cancel();
            // Bind the asserted route/state/club to this real test's print/test ID.
            // This is automated fixture evidence, not a human or device review.
            debugPrintSynchronously(
              jsonEncode(<String, Object>{
                'localRouteAssertion': 1,
                'surface': 'mobile',
                'route': kind == RouteRecoveryKind.featureUnavailable
                    ? '/feature-unavailable'
                    : '<router-error>',
                'kind': kind == RouteRecoveryKind.featureUnavailable
                    ? 'system_state'
                    : 'error_path',
                'state': state.name.replaceAllMapped(
                  RegExp('[A-Z]'),
                  (match) => '_${match[0]!.toLowerCase()}',
                ),
                'club': club.key,
                'assertions': <String>[
                  'state-specific visible title',
                  'sanitized private destination',
                  'selected semantics matches state',
                  'no uncaught render exception',
                  'android tap targets',
                  'ios tap targets',
                  'tap target labels',
                  'text contrast',
                  if (motion) 'motion disabled',
                  if (state == RouteRecoveryVisualState.focused)
                    'keyboard focus',
                  if (state == RouteRecoveryVisualState.pressed)
                    'held press scale',
                ],
              }),
            );
          } finally {
            semantics.dispose();
          }
        });
      }
    }
  }
}
