import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final repoRoot = _findRepoRoot();
  final inventory = File('${repoRoot.path}/docs/screen_inventory.md');
  final manifest = File(
    '${repoRoot.path}/docs/rayon_mobile_visual_evidence_manifest_2026-07-01.md',
  );
  final shellNavigationTest = File(
    '${repoRoot.path}/apps/rayon_sports/test/rayon_sports_shell_navigation_test.dart',
  );

  group('Rayon mobile visual coverage contract', () {
    test('keeps launch route evidence mapped to the screen inventory', () {
      final inventoryText = inventory.readAsStringSync();
      final manifestText = manifest.readAsStringSync();

      expectLaunchRouteEvidence(
        inventoryText: inventoryText,
        manifestText: manifestText,
      );
    });

    test('tracks required launch states and evidence source', () {
      final manifestText = manifest.readAsStringSync();

      expectRequiredStateEvidence(manifestText);
    });

    test('tracks app shell navigation evidence', () {
      expect(shellNavigationTest.existsSync(), isTrue);

      final shellNavigationText = shellNavigationTest.readAsStringSync();
      for (final tab in const ['Home', 'Fan Zone', 'Settings']) {
        expect(shellNavigationText, contains(tab), reason: tab);
      }
      expect(shellNavigationText, isNot(contains("label: 'Admin'")));
      expect(shellNavigationText, isNot(contains('Admin Screen')));
    });

    test('fails when a launch route mapping is removed', () {
      final inventoryText = inventory.readAsStringSync();
      final manifestText = manifest.readAsStringSync();
      final mutatedManifest = manifestText.replaceFirst(
        RegExp(r'^\| `/shop` \|.*$', multiLine: true),
        '| `/_removed_shop` | Shop | `21_shop.png` | data, empty, error |',
      );

      expect(
        () => expectLaunchRouteEvidence(
          inventoryText: inventoryText,
          manifestText: mutatedManifest,
        ),
        throwsA(isA<TestFailure>()),
      );
    });

    test('fails when required state evidence is removed', () {
      final manifestText = manifest.readAsStringSync();
      final mutatedManifest = manifestText.replaceAll('large text', '');

      expect(
        () => expectRequiredStateEvidence(mutatedManifest),
        throwsA(isA<TestFailure>()),
      );
    });
  });
}

@visibleForTesting
void expectLaunchRouteEvidence({
  required String inventoryText,
  required String manifestText,
}) {
  for (final route in launchRoutes) {
    expect(inventoryText, contains(route), reason: route);
    expect(manifestText, contains('| `$route` |'), reason: route);
  }
}

@visibleForTesting
void expectRequiredStateEvidence(String manifestText) {
  for (final state in requiredLaunchStates) {
    expect(manifestText, contains(state), reason: state);
  }

  expect(
    manifestText,
    contains(
      'output/product_design_screen_report/20260701T051146Z/screenshots_53_device_actual',
    ),
  );
  expect(manifestText, contains('Admin/internal routes'));
  expect(manifestText, contains('supporter launch routes'));
}

const launchRoutes = <String>[
  '/splash',
  '/onboarding',
  '/auth/phone',
  '/auth/otp',
  '/home',
  '/fanzone',
  '/settings',
  '/tickets',
  '/membership',
  '/shop',
];

const requiredLaunchStates = <String>[
  'data',
  'loading',
  'empty',
  'error',
  'large text',
];

Directory _findRepoRoot() {
  var current = Directory.current;
  while (true) {
    if (File('${current.path}/pubspec.yaml').existsSync() &&
        Directory('${current.path}/docs').existsSync()) {
      return current;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      throw StateError('Could not find AFRICLUB repo root.');
    }
    current = parent;
  }
}
