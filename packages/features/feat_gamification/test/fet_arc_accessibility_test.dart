import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/widgets/fet_arc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    ColorTokens.init(
      const ClubColors(
        primary: ColorTokens.referenceAccountBlue,
        secondary: ColorTokens.referenceAccountNavy,
        accent: ColorTokens.referenceTrophyGold,
        gradient: <Color>[
          ColorTokens.referenceAccountNavy,
          ColorTokens.referenceAccountBlue,
        ],
      ),
    );
  });

  tearDown(() => ColorTokens.setBrightness(Brightness.dark));

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} FET arc exposes progress without color alone',
      (tester) async {
        final semantics = tester.ensureSemantics();
        ColorTokens.setBrightness(brightness);

        await tester.pumpWidget(
          MaterialApp(
            theme: ClubTheme.from(
              ClubConfig.fallback(),
              brightness: brightness,
            ),
            home: const Scaffold(
              body: Center(
                child: FetArc(
                  currentFet: 275,
                  maxFet: 500,
                  tier: 'silver',
                  nextTier: 'gold',
                ),
              ),
            ),
          ),
        );

        final node = tester.getSemantics(find.byType(FetArc));
        expect(node.label, 'FET progress');
        expect(node.value, '275 of 500, silver tier');

        final value = tester.widget<Text>(find.text('275'));
        final foreground = value.style!.color!;
        expect(
          _contrastRatio(foreground, ColorTokens.surfaceContainerHigh),
          greaterThanOrEqualTo(4.5),
        );
        semantics.dispose();
      },
    );
  }
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
