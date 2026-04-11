import 'package:core_auth/core_auth.dart';
import 'package:feat_settings/src/screens/language_region_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('language selector only offers supported locales', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => const UserProfile(
              id: 'user-1',
              clubId: '24',
              languageCode: 'rw',
            ),
          ),
        ],
        child: const MaterialApp(home: LanguageRegionScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('English and French are currently supported in this build.'),
      findsOneWidget,
    );
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Français'), findsOneWidget);
    expect(find.text('Kinyarwanda'), findsNothing);
  });
}
