import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'afri_localizations_en.dart';
import 'afri_localizations_fr.dart';
import 'afri_localizations_rw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AfriLocalizations
/// returned by `AfriLocalizations.of(context)`.
///
/// Applications need to include `AfriLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/afri_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AfriLocalizations.localizationsDelegates,
///   supportedLocales: AfriLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AfriLocalizations.supportedLocales
/// property.
abstract class AfriLocalizations {
  AfriLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AfriLocalizations of(BuildContext context) {
    return Localizations.of<AfriLocalizations>(context, AfriLocalizations)!;
  }

  static const LocalizationsDelegate<AfriLocalizations> delegate =
      _AfriLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('rw'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'AfriClub'**
  String get appTitle;

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get genericError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @connectionRequired.
  ///
  /// In en, this message translates to:
  /// **'Connection required'**
  String get connectionRequired;

  /// No description provided for @onboardingBelongTitle.
  ///
  /// In en, this message translates to:
  /// **'Your club.\nYour matchday.'**
  String get onboardingBelongTitle;

  /// No description provided for @onboardingBelongBody.
  ///
  /// In en, this message translates to:
  /// **'Follow {clubName} wherever the blue family gathers.'**
  String onboardingBelongBody(String clubName);

  /// No description provided for @onboardingKnowTitle.
  ///
  /// In en, this message translates to:
  /// **'Every moment.\nOne blue family.'**
  String get onboardingKnowTitle;

  /// No description provided for @onboardingKnowBody.
  ///
  /// In en, this message translates to:
  /// **'Get official {appName} news, fixtures, tickets, and membership.'**
  String onboardingKnowBody(String appName);

  /// No description provided for @onboardingLiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Closer to\nGikundiro.'**
  String get onboardingLiveTitle;

  /// No description provided for @onboardingLiveBody.
  ///
  /// In en, this message translates to:
  /// **'Meet the squad and carry your club with you every day.'**
  String get onboardingLiveBody;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingStart;

  /// No description provided for @onboardingContinueWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Continue with WhatsApp'**
  String get onboardingContinueWhatsApp;

  /// No description provided for @onboardingContinueWithoutSignIn.
  ///
  /// In en, this message translates to:
  /// **'Continue without sign-in'**
  String get onboardingContinueWithoutSignIn;

  /// No description provided for @onboardingWelcomeImage.
  ///
  /// In en, this message translates to:
  /// **'Welcome image {current} of {total}'**
  String onboardingWelcomeImage(int current, int total);

  /// No description provided for @supportUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Support is unavailable in this build.'**
  String get supportUnavailable;

  /// No description provided for @fanZoneLoading.
  ///
  /// In en, this message translates to:
  /// **'Picks, league, points, fans, and rewards are loading.'**
  String get fanZoneLoading;

  /// No description provided for @fanZoneJoinSession.
  ///
  /// In en, this message translates to:
  /// **'Join a live session and use this phone to play.'**
  String get fanZoneJoinSession;

  /// No description provided for @fanZoneVenueCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the venue code after you arrive.'**
  String get fanZoneVenueCode;

  /// No description provided for @fanZoneRoundsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Matchday rounds will appear when they open.'**
  String get fanZoneRoundsEmpty;

  /// No description provided for @fanZoneRankingsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Rankings will appear after updates resume.'**
  String get fanZoneRankingsEmpty;

  /// No description provided for @fanZoneClubsMoved.
  ///
  /// In en, this message translates to:
  /// **'Fan clubs and chapters are under Supporters.'**
  String get fanZoneClubsMoved;

  /// No description provided for @fanZoneRegistryMoved.
  ///
  /// In en, this message translates to:
  /// **'The supporter list is under Fan Zone Supporters.'**
  String get fanZoneRegistryMoved;

  /// No description provided for @fanZoneContributionMode.
  ///
  /// In en, this message translates to:
  /// **'Choose how to contribute.'**
  String get fanZoneContributionMode;

  /// No description provided for @fanZoneRewardsSummary.
  ///
  /// In en, this message translates to:
  /// **'Badges, streaks, and rewards.'**
  String get fanZoneRewardsSummary;

  /// No description provided for @fanZoneLineupsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Lineups will appear before kickoff.'**
  String get fanZoneLineupsEmpty;

  /// No description provided for @fanZoneStatsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Stats will appear when the match starts.'**
  String get fanZoneStatsEmpty;

  /// No description provided for @fanIdVerifyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Verify your Fan ID to make picks and earn points.'**
  String get fanIdVerifyPrompt;

  /// No description provided for @fanIdPrivacyTrust.
  ///
  /// In en, this message translates to:
  /// **'Verification uses your Fan ID. No personal details are shared.'**
  String get fanIdPrivacyTrust;

  /// No description provided for @tvPairingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Pairing unavailable. Check the connection and retry.'**
  String get tvPairingUnavailable;

  /// No description provided for @tvConfigurationMissing.
  ///
  /// In en, this message translates to:
  /// **'Setup is incomplete. Contact the deployment owner.'**
  String get tvConfigurationMissing;

  /// No description provided for @tvCredentialRevoked.
  ///
  /// In en, this message translates to:
  /// **'This device was revoked. Create a new pairing code.'**
  String get tvCredentialRevoked;

  /// No description provided for @tvEnterAdminCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from the admin device list.'**
  String get tvEnterAdminCode;

  /// No description provided for @tvJoinFromFanZone.
  ///
  /// In en, this message translates to:
  /// **'Use this code to join from Fan Zone.'**
  String get tvJoinFromFanZone;

  /// No description provided for @tvConnectionLostRetry.
  ///
  /// In en, this message translates to:
  /// **'Connection lost — retry'**
  String get tvConnectionLostRetry;
}

class _AfriLocalizationsDelegate
    extends LocalizationsDelegate<AfriLocalizations> {
  const _AfriLocalizationsDelegate();

  @override
  Future<AfriLocalizations> load(Locale locale) {
    return SynchronousFuture<AfriLocalizations>(
      lookupAfriLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr', 'rw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AfriLocalizationsDelegate old) => false;
}

AfriLocalizations lookupAfriLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AfriLocalizationsEn();
    case 'fr':
      return AfriLocalizationsFr();
    case 'rw':
      return AfriLocalizationsRw();
  }

  throw FlutterError(
    'AfriLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
