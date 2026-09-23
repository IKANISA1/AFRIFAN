import 'package:core_app/src/shell.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const locales = <Locale>[Locale('en')];

  for (final locale in locales) {
    test('primary shell consumes ${locale.languageCode} navigation labels', () {
      final l10n = lookupAfriLocalizations(locale);

      expect(localizedPrimaryLabel(l10n, 'home', 'fallback'), l10n.navHome);
      expect(localizedPrimaryLabel(l10n, 'club', 'fallback'), l10n.navClub);
      expect(
        localizedPrimaryLabel(l10n, 'predict', 'fallback'),
        l10n.predictTitle,
      );
      expect(
        localizedPrimaryLabel(l10n, 'membership', 'fallback'),
        l10n.navMembership,
      );
      expect(localizedPrimaryLabel(l10n, 'settings', 'fallback'), 'fallback');
    });
  }
}
