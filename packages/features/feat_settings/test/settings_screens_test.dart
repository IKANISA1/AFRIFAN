import 'package:feat_settings/src/screens/about_screen.dart';
import 'package:feat_settings/src/screens/help_support_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('about screen shows actionable policy and support actions', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Terms of Use'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Club Website'), findsOneWidget);
    expect(find.text('Open Source Licenses'), findsOneWidget);
    expect(find.text('CONTACT SUPPORT'), findsOneWidget);
    expect(find.text('RATE THIS APP'), findsOneWidget);
  });

  testWidgets('help screen shows website, whatsapp, and export request', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HelpSupportScreen()));
    await tester.pumpAndSettle();

    expect(find.text('OFFICIAL WEBSITE'), findsOneWidget);
    expect(find.text('WHATSAPP SUPPORT'), findsOneWidget);

    final returnButton = find.text('RETURN TO SETTINGS');
    await tester.scrollUntilVisible(returnButton, 200);
    expect(returnButton, findsOneWidget);
    expect(find.text('REQUEST DATA EXPORT'), findsOneWidget);
  });
}
