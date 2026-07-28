import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shared chrome keeps explicitly styled titles readable', (
    tester,
  ) async {
    ColorTokens.setBrightness(Brightness.light);
    addTearDown(() => ColorTokens.setBrightness(Brightness.dark));

    await tester.pumpWidget(
      MaterialApp(
        theme: ClubTheme.from(
          ClubConfig.fallback(),
          brightness: Brightness.light,
        ),
        home: Scaffold(
          appBar: AfriAppBar(
            title: Text('Membership', style: TypographyTokens.headlineSmall()),
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('Membership'));
    expect(title.style?.color, ColorTokens.chromeForeground);
    expect(tester.takeException(), isNull);
  });
}
