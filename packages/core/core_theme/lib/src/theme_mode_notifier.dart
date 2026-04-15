import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A notifier that manages the application's current ThemeMode.
///
/// AFRICLUB is intentionally locked to the original dark theme.
///
/// The notifier remains in place so existing call sites stay compatible, but
/// all requests collapse to [ThemeMode.dark].
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ThemeMode.dark;
  }

  void setThemeMode(ThemeMode mode, {required Brightness systemBrightness}) {
    state = ThemeMode.dark;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
