import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'native_route_registration.dart';

/// Test-only registration scope. Original suites keep their golden comparison.
/// Five-club suites reuse the same controlled state preparation and behavioral
/// checks, then run automated guidelines instead of comparing another club to
/// the fallback club's golden image. No golden acceptance is claimed here.
ClubConfig? localRouteFixtureConfig;
String? localRouteFixtureClub;

ClubConfig localRouteConfigOrFallback() =>
    localRouteFixtureConfig ?? ClubConfig.fallback();

UserProfile? localRouteProfile(UserProfile? profile) =>
    profile?.copyWith(clubId: localRouteFixtureConfig?.clubId);

Map<String, Object> _registrationFields(String route, String kind) {
  final feature = nativeFeatureForRoute(route, kind);
  final registered =
      feature == null ||
      registeredNativeFeatures(localRouteFixtureConfig!).contains(feature);
  return registered
      ? {'localRouteAssertion': 1}
      : {
          'localUnregisteredModuleAssertion': 1,
          'product_route_admitted': false,
          'feature_key': feature,
          'rationale':
              'Actual compiled club capability excludes this module; isolated widget or admission checks are diagnostic only.',
        };
}

/// Actual GoRouter admission or bounded link-resolution outcome. A redirect
/// owns no widget/a11y tree; the complete destination route bank stays required.
void emitLocalNavigationAssertion({
  required String route,
  required String state,
  String surface = 'mobile',
}) {
  debugPrintSynchronously(
    jsonEncode(<String, Object>{
      ..._registrationFields(route, 'redirect'),
      'surface': surface,
      'route': route,
      'kind': 'redirect',
      'state': state,
      'club': localRouteFixtureClub!,
      'assertions': ['finite controlled navigation outcome'],
    }),
  );
}

const _states = <String>[
  'permission_denied',
  'security_timeout',
  'reduced_motion',
  'large_text',
  'loading',
  'empty',
  'error',
  'offline',
  'disabled',
  'focused',
  'pressed',
  'selected',
  'dark',
  'light',
  'syncing',
  'conflict',
];

Future<void> expectGoldenOrClubAssertions(
  WidgetTester tester,
  Finder finder,
  Object image, {
  required String route,
  required String kind,
  String surface = 'mobile',
}) async {
  if (localRouteFixtureConfig == null) {
    await expectLater(finder, matchesGoldenFile(image));
    return;
  }
  expect(finder, findsWidgets, reason: 'Actual state boundary is rendered');
  expect(
    tester.takeException(),
    isNull,
    reason: 'No render exception for $route under $localRouteFixtureClub',
  );
  final semantics = tester.ensureSemantics();
  try {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  } catch (_) {
    const failureOutput = String.fromEnvironment('LOCAL_A11Y_FAILURE_OUTPUT');
    if (failureOutput.isNotEmpty) {
      final boundary = tester.renderObject(finder);
      if (boundary is RenderRepaintBoundary) {
        await tester.runAsync(() async {
          final pixels = await boundary.toImage();
          try {
            final bytes = await pixels.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final directory = Directory('$failureOutput/$localRouteFixtureClub')
              ..createSync(recursive: true);
            File(
              '${directory.path}/${image.toString().split('/').last}',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
          } finally {
            pixels.dispose();
          }
        });
      }
    }
    rethrow;
  } finally {
    semantics.dispose();
  }
  // Only an explicit state prefix is mapped. File existence or an arbitrary
  // filename/brightness suffix cannot manufacture a state assertion.
  final name = image
      .toString()
      .split('/')
      .last
      .split('_state_')
      .skip(1)
      .join('_state_')
      .replaceFirst(RegExp(r'\.png$'), '');
  final namedStates = _states.where(
    (s) => name == s || name.startsWith('${s}_'),
  );
  final evidenced = <String, List<String>>{};
  if (namedStates.length == 1) evidenced[namedStates.single] = const [];
  // Brightness and reduced motion are independent rendered dimensions. Prove
  // them from the actual content context, never from an arbitrary image name.
  final text = find.descendant(of: finder, matching: find.byType(Text));
  if (kind != 'redirect' && text.evaluate().isNotEmpty) {
    final context = tester.element(text.first);
    final brightness = Theme.of(context).brightness;
    expect(ColorTokens.brightness, brightness);
    evidenced.putIfAbsent(
      brightness.name,
      () => ['actual rendered theme brightness'],
    );
    if (MediaQuery.of(context).disableAnimations) {
      expect(AfriMotion.resolve(context, AfriMotion.standard), Duration.zero);
      evidenced.putIfAbsent(
        'reduced_motion',
        () => [
          'actual rendered MediaQuery disables animations',
          'shared motion resolver returns zero duration',
        ],
      );
    }
  }
  for (final state in evidenced.entries) {
    debugPrintSynchronously(
      jsonEncode(<String, Object>{
        ..._registrationFields(route, kind),
        'surface': surface,
        'route': route.split('?').first,
        'kind': kind,
        'state': state.key,
        'club': localRouteFixtureClub!,
        'assertions': <String>[
          'existing controlled state preparation and behavioral checks',
          'actual rendered state boundary',
          'no uncaught render exception',
          'android tap targets',
          'ios tap targets',
          'tap target labels',
          'text contrast',
          ...state.value,
        ],
      }),
    );
  }
}
