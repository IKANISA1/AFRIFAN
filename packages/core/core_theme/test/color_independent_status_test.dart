import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('color-independent status contract', () {
    testWidgets('every compact status tone exposes its meaning in semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final expected = <AfriStatusTone, String>{
        AfriStatusTone.neutral: 'Status',
        AfriStatusTone.info: 'Information',
        AfriStatusTone.success: 'Success',
        AfriStatusTone.warning: 'Warning',
        AfriStatusTone.error: 'Error',
        AfriStatusTone.live: 'Live',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                for (final tone in AfriStatusTone.values)
                  AfriStatusChip(label: tone.name, tone: tone),
              ],
            ),
          ),
        ),
      );

      for (final entry in expected.entries) {
        expect(
          find.bySemanticsLabel('${entry.value} status: ${entry.key.name}'),
          findsOneWidget,
        );
        expect(find.text(entry.key.name), findsOneWidget);
      }
      semantics.dispose();
    });

    testWidgets('every banner tone keeps icon, text, and semantic state', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final expected = <AfriStateBannerTone, String>{
        AfriStateBannerTone.neutral: 'Status',
        AfriStateBannerTone.brand: 'Highlighted',
        AfriStateBannerTone.info: 'Information',
        AfriStateBannerTone.success: 'Success',
        AfriStateBannerTone.warning: 'Warning',
        AfriStateBannerTone.danger: 'Danger',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                for (final tone in AfriStateBannerTone.values)
                  AfriStateBanner(
                    icon: AfriIcons.statusInfo,
                    title: tone.name,
                    tone: tone,
                  ),
              ],
            ),
          ),
        ),
      );

      for (final entry in expected.entries) {
        expect(
          find.bySemanticsLabel('${entry.value} status: ${entry.key.name}'),
          findsOneWidget,
        );
        expect(find.text(entry.key.name), findsOneWidget);
      }
      expect(
        find.byIcon(AfriIcons.statusInfo),
        findsNWidgets(AfriStateBannerTone.values.length),
      );
      semantics.dispose();
    });

    test('color-vision simulations retain multiple visual values', () {
      const palette = <Color>[
        Color(0xFF4AC789),
        Color(0xFFF0BF63),
        Color(0xFFFF6B6B),
        Color(0xFF69A8FF),
        Color(0xFF176B45),
        Color(0xFF7A4F00),
        Color(0xFFB42318),
        Color(0xFF0057B8),
      ];

      for (final matrix in _colorVisionMatrices) {
        final simulated = palette.map((color) => _simulate(color, matrix));
        expect(
          simulated.map((color) => color.toARGB32()).toSet().length,
          greaterThanOrEqualTo(3),
          reason:
              'The palette may compress, but it must not collapse to one '
              'visual value; text, icon, shape, and semantics remain primary.',
        );
      }
    });
  });
}

const _colorVisionMatrices = <List<double>>[
  <double>[0.56667, 0.43333, 0, 0.55833, 0.44167, 0, 0, 0.24167, 0.75833],
  <double>[0.625, 0.375, 0, 0.7, 0.3, 0, 0, 0.3, 0.7],
  <double>[0.95, 0.05, 0, 0, 0.43333, 0.56667, 0, 0.475, 0.525],
];

Color _simulate(Color color, List<double> matrix) {
  final red = color.r * 255;
  final green = color.g * 255;
  final blue = color.b * 255;
  int channel(int offset) =>
      (matrix[offset] * red +
              matrix[offset + 1] * green +
              matrix[offset + 2] * blue)
          .round()
          .clamp(0, 255);
  return Color.fromARGB(255, channel(0), channel(3), channel(6));
}
