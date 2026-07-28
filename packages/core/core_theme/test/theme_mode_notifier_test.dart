import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeModeNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      ColorTokens.setBrightness(Brightness.dark);
    });

    test('defaults to the system theme', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);
      expect(ColorTokens.isDark, isTrue);
    });

    test('accepts and persists light, dark, and system requests', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(themeModeProvider.notifier);

      await notifier.setThemeMode(
        ThemeMode.light,
        systemBrightness: Brightness.light,
      );
      expect(container.read(themeModeProvider), ThemeMode.light);
      expect(ColorTokens.isDark, isFalse);

      await notifier.setThemeMode(
        ThemeMode.system,
        systemBrightness: Brightness.light,
      );
      expect(container.read(themeModeProvider), ThemeMode.system);
      expect(ColorTokens.isDark, isFalse);

      await notifier.setThemeMode(
        ThemeMode.dark,
        systemBrightness: Brightness.light,
      );
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(ColorTokens.isDark, isTrue);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(ThemeModeNotifier.preferenceKey), 'dark');
    });

    test('restores a persisted theme mode', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        ThemeModeNotifier.preferenceKey: 'light',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(themeModeProvider), ThemeMode.light);
    });
  });
}
