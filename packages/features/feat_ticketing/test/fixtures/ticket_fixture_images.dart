import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden captures must include the actual published crests, even on a cold
/// image cache. Pumping animations alone does not await filesystem decoding.
Future<void> settleTicketFixtureImages(WidgetTester tester) async {
  final images = find.descendant(
    of: find.byType(AfriTeamCrest),
    matching: find.byType(Image),
  );
  final errors = <Object>[];
  await tester.runAsync(() async {
    await Future.wait(
      images.evaluate().map(
        (element) => precacheImage(
          (element.widget as Image).image,
          element,
          onError: (error, stack) => errors.add(error),
        ),
      ),
    ).timeout(const Duration(seconds: 3));
  });
  expect(errors, isEmpty, reason: 'Published ticket crests must decode.');
  await tester.pump();
}
