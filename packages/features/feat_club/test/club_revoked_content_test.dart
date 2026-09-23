import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a permission failure removes previously visible club content', (
    tester,
  ) async {
    TypographyTokens.debugUseFallbackFonts = true;
    addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
    const published = AsyncData<List<String>>(['Previously published record']);

    Future<void> show(AsyncValue<List<String>> state) => tester.pumpWidget(
      AfriLocalizationsScope(
        locale: const Locale('en'),
        child: MaterialApp(
          theme: ClubTheme.from(ClubConfig.fallback()),
          home: ClubCollectionScaffold<String>(
            title: 'Club',
            state: state,
            emptyTitle: 'Nothing published',
            emptyMessage: 'Check again later.',
            onRetry: () {},
            itemBuilder: (_, value) => Text(value),
          ),
        ),
      ),
    );

    await show(published);
    expect(find.text('Previously published record'), findsOneWidget);
    await show(
      AsyncError<List<String>>(
        StateError('RLS permission denied'),
        StackTrace.current,
      ).copyWithPrevious(published),
    );
    expect(find.text('Previously published record'), findsNothing);
    expect(find.text('RLS permission denied'), findsNothing);
    expect(tester.takeException(), isNull);
    await show(const AsyncData<List<String>>(['Fresh published record']));
    expect(find.text('Fresh published record'), findsOneWidget);
  });
}
