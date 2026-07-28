library;

import 'package:flutter/widgets.dart';

import 'l10n/afri_localizations.dart';

export 'l10n/afri_localizations.dart';

/// Supplies app-specific copy independently from Flutter framework locales.
///
/// Flutter does not currently ship Material/Cupertino localizations for every
/// AFRICLUB language (notably Kinyarwanda). Keeping the app-copy catalog in a
/// dedicated scope allows task, help, trust, and recovery messages to use `rw`
/// while framework widgets retain a supported locale.
class AfriLocalizationsScope extends InheritedWidget {
  AfriLocalizationsScope({
    required Locale locale,
    required super.child,
    super.key,
  }) : locale = _supportedLocale(locale),
       localizations = lookupAfriLocalizations(_supportedLocale(locale));

  final Locale locale;
  final AfriLocalizations localizations;

  static AfriLocalizationsScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AfriLocalizationsScope>();
  }

  @override
  bool updateShouldNotify(AfriLocalizationsScope oldWidget) {
    return locale != oldWidget.locale;
  }

  static Locale _supportedLocale(Locale locale) {
    final languageCode =
        AfriLocalizations.supportedLocales.any(
          (supported) => supported.languageCode == locale.languageCode,
        )
        ? locale.languageCode
        : 'en';
    return Locale(languageCode);
  }
}

extension AfriLocalizationsContext on BuildContext {
  /// Returns the generated app-copy catalog for this subtree.
  ///
  /// Feature-level widget tests often mount a small [MaterialApp] without the
  /// production delegates. Falling back to the current locale keeps those
  /// tests deterministic while the real app always supplies the delegate.
  AfriLocalizations get afriL10n {
    final scoped = AfriLocalizationsScope.maybeOf(this);
    if (scoped != null) return scoped.localizations;

    final localized = Localizations.of<AfriLocalizations>(
      this,
      AfriLocalizations,
    );
    if (localized != null) return localized;

    final locale = Localizations.maybeLocaleOf(this) ?? const Locale('en');
    final languageCode =
        AfriLocalizations.supportedLocales.any(
          (supported) => supported.languageCode == locale.languageCode,
        )
        ? locale.languageCode
        : 'en';
    return lookupAfriLocalizations(Locale(languageCode));
  }
}
