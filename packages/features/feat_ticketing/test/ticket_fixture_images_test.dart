import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/ticket_fixture_images.dart';

void main() {
  testWidgets('actual ticket crests decode with a cold image cache', (
    tester,
  ) async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    addTearDown(() {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AfriTeamCrest(name: 'Rayon Sports', size: 28),
              AfriTeamCrest(name: 'APR FC', size: 28),
              AfriTeamCrest(name: 'Police FC', size: 28),
              AfriTeamCrest(name: 'Kiyovu Sports', size: 28),
            ],
          ),
        ),
      ),
    );
    await settleTicketFixtureImages(tester);

    final decoded = tester.renderObjectList<RenderImage>(
      find.descendant(
        of: find.byType(AfriTeamCrest),
        matching: find.byType(RawImage),
      ),
    );
    expect(decoded, hasLength(4));
    for (final image in decoded) {
      expect(image.image, isNotNull);
      expect(image.image!.width, greaterThan(0));
      expect(image.image!.height, greaterThan(0));
    }
    expect(tester.takeException(), isNull);
  });
}
