import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tokens/color_tokens.dart';

/// A notifier that manages the application's current ThemeMode.
///
/// AFRICLUB is intentionally locked to the original dark theme.
///
/// The notifier remains in place so existing call sites stay compatible, but
/// all requests collapse to [ThemeMode.dark] and dark token brightness.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    ColorTokens.setBrightness(Brightness.dark);
    return ThemeMode.dark;
  }

  void setThemeMode(ThemeMode mode, {required Brightness systemBrightness}) {
    state = ThemeMode.dark;
    ColorTokens.setBrightness(Brightness.dark);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
