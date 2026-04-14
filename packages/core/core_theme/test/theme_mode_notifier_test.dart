import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeModeNotifier', () {
    test('defaults to the original dark theme', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(ColorTokens.isDark, isTrue);
    });

    test('ignores light and system theme requests', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(themeModeProvider.notifier);

      notifier.setThemeMode(
        ThemeMode.light,
        systemBrightness: Brightness.light,
      );
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(ColorTokens.isDark, isTrue);

      notifier.setThemeMode(
        ThemeMode.system,
        systemBrightness: Brightness.light,
      );
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(ColorTokens.isDark, isTrue);
    });
  });
}
