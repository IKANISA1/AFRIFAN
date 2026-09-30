import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bounded decoding preserves the photograph aspect ratio', (
    tester,
  ) async {
    final bytes = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 200, 100),
        ui.Paint()..color = Colors.blue,
      );
      final picture = recorder.endRecording();
      final source = await picture.toImage(200, 100);
      final encoded = await source.toByteData(format: ui.ImageByteFormat.png);
      source.dispose();
      picture.dispose();
      return encoded!.buffer.asUint8List();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: AfriGovernedImage(
            image: MemoryImage(bytes!),
            width: 80,
            height: 80,
            cacheWidth: 80,
            cacheHeight: 80,
            semanticLabel: 'Rectangular photograph',
            provenanceId: 'test-generated-shape',
            rightsApproved: true,
          ),
        ),
      ),
    );
    // The production Image provider owns the actual bounded decode. Await its
    // first frame/error on the real event loop before inspecting rendered pixels.
    final imageWidget = tester.widget<Image>(find.byType(Image));
    final configuration = createLocalImageConfiguration(
      tester.element(find.byType(Image)),
    );
    await tester.runAsync(
      () => _awaitFirstImageFrame(imageWidget.image.resolve(configuration)),
    );
    await tester.pump();
    final decoded = tester.widget<RawImage>(find.byType(RawImage)).image;
    expect(decoded, isNotNull);
    expect(decoded!.width / decoded.height, 2);
    expect(decoded.width, lessThanOrEqualTo(80));
    expect(decoded.height, lessThanOrEqualTo(80));
    expect(
      tester.getSize(find.byKey(const ValueKey('afri-governed-image-surface'))),
      const Size(80, 80),
    );
  });
  test(
    'decode completion wait fails on an actual image stream error',
    () async {
      final stream = ImageStream()
        ..setCompleter(
          OneFrameImageStreamCompleter(
            Future<ImageInfo>.error(StateError('synthetic decode failure')),
          ),
        );
      await expectLater(
        _awaitFirstImageFrame(stream),
        throwsA(isA<StateError>()),
      );
      expect(stream.completer!.hasListeners, isFalse);
    },
  );

  test('decode completion wait has a real bounded deadline', () async {
    final stream = ImageStream()
      ..setCompleter(
        OneFrameImageStreamCompleter(Completer<ImageInfo>().future),
      );
    await expectLater(
      _awaitFirstImageFrame(stream, timeout: const Duration(milliseconds: 20)),
      throwsA(isA<TimeoutException>()),
    );
    expect(stream.completer!.hasListeners, isFalse);
  });

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

Future<void> _awaitFirstImageFrame(
  ImageStream stream, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final completed = Completer<void>();
  final listener = ImageStreamListener(
    (info, synchronousCall) {
      if (!completed.isCompleted) completed.complete();
      // ImageStream gives each listener an owned clone. The production widget
      // retains its own frame; this observation must not leak a native image.
      info.dispose();
    },
    onError: (Object error, StackTrace? stackTrace) {
      if (!completed.isCompleted) completed.completeError(error, stackTrace);
    },
  );
  stream.addListener(listener);
  try {
    await completed.future.timeout(timeout);
  } finally {
    stream.removeListener(listener);
  }
}
