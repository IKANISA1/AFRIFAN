import 'dart:convert';
import 'dart:typed_data';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final onePixelPng = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
    ),
  );

  testWidgets('fails closed when rights approval is absent', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: AfriGovernedImage(
            image: MemoryImage(onePixelPng),
            width: 160,
            height: 90,
            semanticLabel: 'Supporters in the stadium',
            provenanceId: 'media-register-001',
            rightsApproved: false,
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.text('Media unavailable'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('afri-governed-image-surface'))),
      const Size(160, 90),
    );
    expect(
      find.bySemanticsLabel(RegExp('Supporters in the stadium unavailable')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets(
    'renders approved media with stable dimensions and cache bounds',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: AfriGovernedImage(
              image: MemoryImage(onePixelPng),
              width: 160,
              height: 90,
              cacheWidth: 320,
              cacheHeight: 180,
              semanticLabel: 'Club crest',
              provenanceId: 'official-club-crest',
              rightsApproved: true,
            ),
          ),
        ),
      );
      await tester.pump();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 160);
      expect(image.height, 90);
      expect(image.semanticLabel, 'Club crest');
      expect(image.image, isA<ResizeImage>());
      expect((image.image as ResizeImage).width, 320);
      expect((image.image as ResizeImage).height, 180);
      expect(find.text('Media unavailable'), findsNothing);
    },
  );

  for (final entry in <AfriGovernedImageState, String>{
    AfriGovernedImageState.empty: 'No media available',
    AfriGovernedImageState.offline: 'Media unavailable offline',
    AfriGovernedImageState.permissionDenied: 'Permission required',
  }.entries) {
    testWidgets('renders explicit ${entry.key.name} recovery state', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: AfriGovernedImage(
              width: 160,
              height: 90,
              semanticLabel: 'Supporter media',
              provenanceId: 'synthetic-state-proof',
              rightsApproved: true,
              state: entry.key,
            ),
          ),
        ),
      );

      expect(find.text(entry.value), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  }

  for (final state in <AfriGovernedImageState>[
    AfriGovernedImageState.loading,
    AfriGovernedImageState.skeleton,
  ]) {
    testWidgets('renders bounded ${state.name} placeholder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: AfriGovernedImage(
              width: 160,
              height: 90,
              semanticLabel: 'Supporter media',
              provenanceId: 'synthetic-state-proof',
              rightsApproved: true,
              state: state,
            ),
          ),
        ),
      );

      expect(find.byType(AfriSkeleton), findsOneWidget);
      expect(
        tester.getSize(
          find.byKey(const ValueKey('afri-governed-image-surface')),
        ),
        const Size(160, 90),
      );
    });
  }
}
