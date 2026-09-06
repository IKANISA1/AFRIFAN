library;

import 'package:flutter/widgets.dart';

import 'l10n/afri_localizations.dart';

export 'l10n/afri_localizations.dart';

/// Supplies the English catalog throughout the app, including isolated features.
/// Persisted preferences and device locales never change the product language.
class AfriLocalizationsScope extends InheritedWidget {
  AfriLocalizationsScope({
    required Locale locale,
    required super.child,
    super.key,
  }) : locale = const Locale('en'),
       localizations = lookupAfriLocalizations(const Locale('en'));

  final Locale locale;
  final AfriLocalizations localizations;

  static AfriLocalizationsScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AfriLocalizationsScope>();
  }

  @override
  bool updateShouldNotify(AfriLocalizationsScope oldWidget) {
    return locale != oldWidget.locale;
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

    return lookupAfriLocalizations(const Locale('en'));
  }
}
