import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tokens/color_tokens.dart';

/// Manages the application theme mode and its device-local preference.
///
/// The system setting is the safe first-run default. Explicit user choices are
/// persisted locally and restored without requiring an account or network.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const preferenceKey = 'africlub_theme_mode_v1';

  bool _hasLocalSelection = false;
  Future<void> _persistenceQueue = Future<void>.value();

  @override
  ThemeMode build() {
    scheduleMicrotask(_restore);
    return ThemeMode.system;
  }

  Future<void> setThemeMode(
    ThemeMode mode, {
    required Brightness systemBrightness,
  }) {
    _hasLocalSelection = true;
    state = mode;
    ColorTokens.setBrightness(_resolveBrightness(mode, systemBrightness));
    _persistenceQueue = _persistenceQueue.then((_) => _persist(mode));
    return _persistenceQueue;
  }

  Future<void> _restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_hasLocalSelection) {
        return;
      }
      final restored = themeModeFromStorage(
        preferences.getString(preferenceKey),
      );
      if (restored != null) {
        state = restored;
      }
    } on Object {
      // Local preference storage is best-effort. The system theme remains a
      // usable default when a platform plugin is unavailable or initializing.
    }
  }

  Future<void> _persist(ThemeMode mode) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(preferenceKey, themeModeToStorage(mode));
    } on Object {
      // Keep the in-memory selection active even when device-local persistence
      // is unavailable. A later user selection can retry without a failed
      // persistence queue poisoning subsequent writes.
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

Brightness _resolveBrightness(ThemeMode mode, Brightness systemBrightness) {
  return switch (mode) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    ThemeMode.system => systemBrightness,
  };
}

String themeModeToStorage(ThemeMode mode) => mode.name;

ThemeMode? themeModeFromStorage(String? stored) {
  return switch (stored) {
    'system' => ThemeMode.system,
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => null,
  };
}
