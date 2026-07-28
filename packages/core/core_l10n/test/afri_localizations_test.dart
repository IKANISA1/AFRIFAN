import 'package:core_l10n/core_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const locales = <Locale>[Locale('en'), Locale('fr'), Locale('rw')];

  test('ships complete EN, FR, and RW task-copy catalogs', () {
    for (final locale in locales) {
      final l10n = lookupAfriLocalizations(locale);
      final taskMessages = <String>[
        l10n.genericError,
        l10n.retry,
        l10n.connectionRequired,
        l10n.onboardingBelongTitle,
        l10n.onboardingBelongBody('Rayon Sports FC'),
        l10n.onboardingKnowTitle,
        l10n.onboardingKnowBody('Gikundiro'),
        l10n.onboardingLiveTitle,
        l10n.onboardingLiveBody,
        l10n.onboardingContinueWhatsApp,
        l10n.onboardingContinueWithoutSignIn,
        l10n.onboardingWelcomeImage(1, 3),
        l10n.supportUnavailable,
        l10n.fanZoneLoading,
        l10n.fanZoneJoinSession,
        l10n.fanZoneVenueCode,
        l10n.fanZoneRoundsEmpty,
        l10n.fanZoneRankingsEmpty,
        l10n.fanZoneClubsMoved,
        l10n.fanZoneRegistryMoved,
        l10n.fanZoneContributionMode,
        l10n.fanZoneRewardsSummary,
        l10n.fanZoneLineupsEmpty,
        l10n.fanZoneStatsEmpty,
        l10n.fanIdVerifyPrompt,
        l10n.fanIdPrivacyTrust,
        l10n.tvPairingUnavailable,
        l10n.tvConfigurationMissing,
        l10n.tvCredentialRevoked,
        l10n.tvEnterAdminCode,
        l10n.tvJoinFromFanZone,
        l10n.tvConnectionLostRetry,
      ];

      expect(
        taskMessages,
        everyElement(isNot(isEmpty)),
        reason: 'Every ${locale.languageCode} task message must be populated.',
      );
    }
  });

  test('RW and FR are real catalogs rather than English fallbacks', () {
    final en = lookupAfriLocalizations(const Locale('en'));
    final fr = lookupAfriLocalizations(const Locale('fr'));
    final rw = lookupAfriLocalizations(const Locale('rw'));

    expect(fr.onboardingContinueWhatsApp, isNot(en.onboardingContinueWhatsApp));
    expect(rw.onboardingContinueWhatsApp, isNot(en.onboardingContinueWhatsApp));
    expect(fr.tvPairingUnavailable, isNot(en.tvPairingUnavailable));
    expect(rw.tvPairingUnavailable, isNot(en.tvPairingUnavailable));
    expect(
      rw.onboardingBelongBody('Rayon Sports FC'),
      contains('Rayon Sports FC'),
    );
  });

  test('task and TV recovery messages stay within governed copy bounds', () {
    for (final locale in locales) {
      final l10n = lookupAfriLocalizations(locale);
      final compactMessages = <String>[
        l10n.onboardingContinueWhatsApp,
        l10n.onboardingContinueWithoutSignIn,
        l10n.fanZoneJoinSession,
        l10n.fanZoneVenueCode,
        l10n.fanZoneRoundsEmpty,
        l10n.fanZoneRankingsEmpty,
        l10n.fanIdVerifyPrompt,
        l10n.fanIdPrivacyTrust,
      ];
      final tvMessages = <String>[
        l10n.tvPairingUnavailable,
        l10n.tvConfigurationMissing,
        l10n.tvCredentialRevoked,
        l10n.tvEnterAdminCode,
        l10n.tvJoinFromFanZone,
        l10n.tvConnectionLostRetry,
      ];

      expect(
        compactMessages,
        everyElement(hasLength(lessThanOrEqualTo(100))),
        reason: '${locale.languageCode} compact copy exceeded 100 characters.',
      );
      expect(
        tvMessages,
        everyElement(hasLength(lessThanOrEqualTo(90))),
        reason: '${locale.languageCode} TV copy exceeded 90 characters.',
      );
    }
  });

  testWidgets(
    'app-copy locale can be RW while Flutter framework strings remain supported',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const <Locale>[Locale('en')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AfriLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => AfriLocalizationsScope(
            locale: const Locale('rw'),
            child: child ?? const SizedBox.shrink(),
          ),
          home: Builder(
            builder: (context) => Text(
              '${Localizations.localeOf(context).languageCode}:'
              '${context.afriL10n.onboardingContinueWhatsApp}:'
              '${MaterialLocalizations.of(context).okButtonLabel}',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('en:Komeza ukoresheje WhatsApp:'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
