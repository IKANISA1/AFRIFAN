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

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Fans, fixtures, tickets, shop, wallet, help'**
  String get searchHint;

  /// No description provided for @searchClearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get searchClearTooltip;

  /// No description provided for @searchCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get searchCategoryAll;

  /// No description provided for @searchCategorySupporters.
  ///
  /// In en, this message translates to:
  /// **'Supporters'**
  String get searchCategorySupporters;

  /// No description provided for @searchCategoryFixtures.
  ///
  /// In en, this message translates to:
  /// **'Fixtures'**
  String get searchCategoryFixtures;

  /// No description provided for @searchCategoryCommerce.
  ///
  /// In en, this message translates to:
  /// **'Tickets & shop'**
  String get searchCategoryCommerce;

  /// No description provided for @searchCategoryServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get searchCategoryServices;

  /// No description provided for @searchKeepTypingTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep typing'**
  String get searchKeepTypingTitle;

  /// No description provided for @searchKeepTypingMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter at least two characters before search can start.'**
  String get searchKeepTypingMessage;

  /// No description provided for @searchUpdatingTitle.
  ///
  /// In en, this message translates to:
  /// **'Updating results'**
  String get searchUpdatingTitle;

  /// No description provided for @searchSearchingTitle.
  ///
  /// In en, this message translates to:
  /// **'Searching'**
  String get searchSearchingTitle;

  /// No description provided for @searchUpdatingMessage.
  ///
  /// In en, this message translates to:
  /// **'Refreshing sections and public supporter content.'**
  String get searchUpdatingMessage;

  /// No description provided for @searchSearchingMessage.
  ///
  /// In en, this message translates to:
  /// **'Searching sections and supporter content.'**
  String get searchSearchingMessage;

  /// No description provided for @searchPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Search not permitted'**
  String get searchPermissionTitle;

  /// No description provided for @searchPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Live search is off for this account. Your query and app sections remain. Contact club support.'**
  String get searchPermissionMessage;

  /// No description provided for @searchConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Search changed'**
  String get searchConflictTitle;

  /// No description provided for @searchConflictMessage.
  ///
  /// In en, this message translates to:
  /// **'Available content changed during this search. Review the current query and try again.'**
  String get searchConflictMessage;

  /// No description provided for @searchTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Search timed out'**
  String get searchTimeoutTitle;

  /// No description provided for @searchTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'The search window expired. Your query is still here. Try again when ready.'**
  String get searchTimeoutMessage;

  /// No description provided for @searchUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Search is unavailable'**
  String get searchUnavailableTitle;

  /// No description provided for @searchUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Try again. Your query has not been sent elsewhere.'**
  String get searchUnavailableMessage;

  /// No description provided for @searchStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Find what you need'**
  String get searchStartTitle;

  /// No description provided for @searchStartMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter at least two characters. Search covers app sections and public supporter content.'**
  String get searchStartMessage;

  /// No description provided for @searchRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchRecentTitle;

  /// No description provided for @searchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchClear;

  /// No description provided for @searchForTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search for {query}'**
  String searchForTooltip(String query);

  /// No description provided for @searchNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get searchNoResultsTitle;

  /// No description provided for @searchNoResultsMessage.
  ///
  /// In en, this message translates to:
  /// **'No result matches “{query}”.'**
  String searchNoResultsMessage(String query);

  /// No description provided for @searchShowAllCategories.
  ///
  /// In en, this message translates to:
  /// **'Show all categories'**
  String get searchShowAllCategories;

  /// No description provided for @searchOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline results'**
  String get searchOfflineTitle;

  /// No description provided for @searchOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Showing results stored on this device. Live content may be out of date.'**
  String get searchOfflineMessage;

  /// No description provided for @searchResultCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No results} =1{1 result} other{{count} results}}'**
  String searchResultCount(int count);

  /// No description provided for @searchSupporterDirectoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Find supporters'**
  String get searchSupporterDirectoryTitle;

  /// No description provided for @searchSupporterDirectoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Search public supporter aliases and manage friends.'**
  String get searchSupporterDirectoryDescription;

  /// No description provided for @searchFanZoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Fan Zone'**
  String get searchFanZoneTitle;

  /// No description provided for @searchFanZoneDescription.
  ///
  /// In en, this message translates to:
  /// **'Predictions, community, rewards, and matchday activity.'**
  String get searchFanZoneDescription;

  /// No description provided for @searchFanRegistryTitle.
  ///
  /// In en, this message translates to:
  /// **'Fan registry'**
  String get searchFanRegistryTitle;

  /// No description provided for @searchFanRegistryDescription.
  ///
  /// In en, this message translates to:
  /// **'Browse the club supporter registry.'**
  String get searchFanRegistryDescription;

  /// No description provided for @searchFixturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Fixtures'**
  String get searchFixturesTitle;

  /// No description provided for @searchFixturesDescription.
  ///
  /// In en, this message translates to:
  /// **'Upcoming and recent Rayon Sports matches.'**
  String get searchFixturesDescription;

  /// No description provided for @searchLiveMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Live match'**
  String get searchLiveMatchTitle;

  /// No description provided for @searchLiveMatchDescription.
  ///
  /// In en, this message translates to:
  /// **'Open the current match centre when live coverage exists.'**
  String get searchLiveMatchDescription;

  /// No description provided for @searchStandingsTitle.
  ///
  /// In en, this message translates to:
  /// **'League standings'**
  String get searchStandingsTitle;

  /// No description provided for @searchStandingsDescription.
  ///
  /// In en, this message translates to:
  /// **'View the current table and competition position.'**
  String get searchStandingsDescription;

  /// No description provided for @searchTicketsTitle.
  ///
  /// In en, this message translates to:
  /// **'Match tickets'**
  String get searchTicketsTitle;

  /// No description provided for @searchTicketsDescription.
  ///
  /// In en, this message translates to:
  /// **'Find available tickets and continue to checkout.'**
  String get searchTicketsDescription;

  /// No description provided for @searchMyTicketsTitle.
  ///
  /// In en, this message translates to:
  /// **'My tickets'**
  String get searchMyTicketsTitle;

  /// No description provided for @searchMyTicketsDescription.
  ///
  /// In en, this message translates to:
  /// **'Open purchased tickets and match entry details.'**
  String get searchMyTicketsDescription;

  /// No description provided for @searchShopTitle.
  ///
  /// In en, this message translates to:
  /// **'Club shop'**
  String get searchShopTitle;

  /// No description provided for @searchShopDescription.
  ///
  /// In en, this message translates to:
  /// **'Browse official club products.'**
  String get searchShopDescription;

  /// No description provided for @searchCartTitle.
  ///
  /// In en, this message translates to:
  /// **'Shopping cart'**
  String get searchCartTitle;

  /// No description provided for @searchCartDescription.
  ///
  /// In en, this message translates to:
  /// **'Review products before checkout.'**
  String get searchCartDescription;

  /// No description provided for @searchWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'FET wallet'**
  String get searchWalletTitle;

  /// No description provided for @searchWalletDescription.
  ///
  /// In en, this message translates to:
  /// **'View token balance, history, transfer, and redemption.'**
  String get searchWalletDescription;

  /// No description provided for @searchMembershipTitle.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get searchMembershipTitle;

  /// No description provided for @searchMembershipDescription.
  ///
  /// In en, this message translates to:
  /// **'View membership status and club benefits.'**
  String get searchMembershipDescription;

  /// No description provided for @searchContributionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Support the club'**
  String get searchContributionsTitle;

  /// No description provided for @searchContributionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Open contributions and supporter projects.'**
  String get searchContributionsDescription;

  /// No description provided for @searchNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get searchNotificationsTitle;

  /// No description provided for @searchNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Review and update notification preferences.'**
  String get searchNotificationsDescription;

  /// No description provided for @searchPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy settings'**
  String get searchPrivacyTitle;

  /// No description provided for @searchPrivacyDescription.
  ///
  /// In en, this message translates to:
  /// **'Review consent and privacy controls.'**
  String get searchPrivacyDescription;

  /// No description provided for @searchHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help and support'**
  String get searchHelpTitle;

  /// No description provided for @searchHelpDescription.
  ///
  /// In en, this message translates to:
  /// **'Open support options from Settings.'**
  String get searchHelpDescription;

  /// No description provided for @searchPublicSupporterDescription.
  ///
  /// In en, this message translates to:
  /// **'Public supporter profile in the club registry.'**
  String get searchPublicSupporterDescription;

  /// No description provided for @searchMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'{home} vs {away}'**
  String searchMatchTitle(String home, String away);

  /// No description provided for @searchFixtureOnSaleDescription.
  ///
  /// In en, this message translates to:
  /// **'{competition} fixture with ticket sales available.'**
  String searchFixtureOnSaleDescription(String competition);

  /// No description provided for @searchFixtureDescription.
  ///
  /// In en, this message translates to:
  /// **'{competition} fixture.'**
  String searchFixtureDescription(String competition);

  /// No description provided for @searchProductDescription.
  ///
  /// In en, this message translates to:
  /// **'Official club shop item in {category}.'**
  String searchProductDescription(String category);

  /// No description provided for @searchHomeTeamFallback.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get searchHomeTeamFallback;

  /// No description provided for @searchAwayTeamFallback.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get searchAwayTeamFallback;

  /// No description provided for @searchClubFixtureFallback.
  ///
  /// In en, this message translates to:
  /// **'Club fixture'**
  String get searchClubFixtureFallback;

  /// No description provided for @searchClubProductFallback.
  ///
  /// In en, this message translates to:
  /// **'Club product'**
  String get searchClubProductFallback;

  /// No description provided for @searchMerchandiseFallback.
  ///
  /// In en, this message translates to:
  /// **'Merchandise'**
  String get searchMerchandiseFallback;

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

  /// No description provided for @tvAppTitle.
  ///
  /// In en, this message translates to:
  /// **'{appName} TV'**
  String tvAppTitle(String appName);

  /// No description provided for @tvBrandMarkSemantic.
  ///
  /// In en, this message translates to:
  /// **'{clubName} TV brand mark'**
  String tvBrandMarkSemantic(String clubName);

  /// No description provided for @tvPairThisDisplay.
  ///
  /// In en, this message translates to:
  /// **'Pair this TV'**
  String get tvPairThisDisplay;

  /// No description provided for @tvPairingCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'One-time pairing code'**
  String get tvPairingCodeLabel;

  /// No description provided for @tvPairingCodeHelper.
  ///
  /// In en, this message translates to:
  /// **'6–12 characters'**
  String get tvPairingCodeHelper;

  /// No description provided for @tvPairingInProgress.
  ///
  /// In en, this message translates to:
  /// **'Pairing…'**
  String get tvPairingInProgress;

  /// No description provided for @tvPairDisplayAction.
  ///
  /// In en, this message translates to:
  /// **'Pair display'**
  String get tvPairDisplayAction;

  /// No description provided for @tvSessionCodeInstruction.
  ///
  /// In en, this message translates to:
  /// **'Enter this code in Fan Zone'**
  String get tvSessionCodeInstruction;

  /// No description provided for @tvSessionCodeSemantic.
  ///
  /// In en, this message translates to:
  /// **'TV session code {code}'**
  String tvSessionCodeSemantic(String code);

  /// No description provided for @tvFetRewardLabel.
  ///
  /// In en, this message translates to:
  /// **'{reward} FET reward'**
  String tvFetRewardLabel(int reward);

  /// No description provided for @tvExpiresLabel.
  ///
  /// In en, this message translates to:
  /// **'Expires {expiry}'**
  String tvExpiresLabel(String expiry);

  /// No description provided for @tvExpired.
  ///
  /// In en, this message translates to:
  /// **'expired'**
  String get tvExpired;

  /// No description provided for @tvExpiresLessThanOneMinute.
  ///
  /// In en, this message translates to:
  /// **'in less than 1 min'**
  String get tvExpiresLessThanOneMinute;

  /// No description provided for @tvExpiresMinutes.
  ///
  /// In en, this message translates to:
  /// **'in {minutes} min'**
  String tvExpiresMinutes(int minutes);

  /// No description provided for @tvExpiresHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'in {hours}h {minutes}m'**
  String tvExpiresHoursMinutes(int hours, int minutes);

  /// No description provided for @tvVenueSessionDetails.
  ///
  /// In en, this message translates to:
  /// **'Venue session details'**
  String get tvVenueSessionDetails;

  /// No description provided for @tvVenueSessionOnly.
  ///
  /// In en, this message translates to:
  /// **'Venue session only'**
  String get tvVenueSessionOnly;

  /// No description provided for @tvNoSupporterDetails.
  ///
  /// In en, this message translates to:
  /// **'No supporter details shown'**
  String get tvNoSupporterDetails;

  /// No description provided for @tvPairingStatusAndExpiry.
  ///
  /// In en, this message translates to:
  /// **'Pairing status and expiry'**
  String get tvPairingStatusAndExpiry;

  /// No description provided for @tvDefaultPairingPrompt.
  ///
  /// In en, this message translates to:
  /// **'Pair this TV display from the admin panel.'**
  String get tvDefaultPairingPrompt;

  /// No description provided for @tvOfflinePhase.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get tvOfflinePhase;

  /// No description provided for @membershipTitle.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get membershipTitle;

  /// No description provided for @membershipSavedDetails.
  ///
  /// In en, this message translates to:
  /// **'Saved membership details'**
  String get membershipSavedDetails;

  /// No description provided for @membershipDigitalCard.
  ///
  /// In en, this message translates to:
  /// **'Digital card'**
  String get membershipDigitalCard;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @membershipReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Membership review'**
  String get membershipReviewTitle;

  /// No description provided for @membershipReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{tier} request is awaiting payment verification.'**
  String membershipReviewSubtitle(String tier);

  /// No description provided for @membershipRenewsOn.
  ///
  /// In en, this message translates to:
  /// **'Renews on {date}'**
  String membershipRenewsOn(String date);

  /// No description provided for @fanRegistryTitle.
  ///
  /// In en, this message translates to:
  /// **'Fan registry'**
  String get fanRegistryTitle;

  /// No description provided for @fanRegistryBrowseAll.
  ///
  /// In en, this message translates to:
  /// **'Browse all supporters'**
  String get fanRegistryBrowseAll;

  /// No description provided for @membershipPackagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Packages'**
  String get membershipPackagesTitle;

  /// No description provided for @membershipOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Membership unavailable'**
  String get membershipOfflineTitle;

  /// No description provided for @membershipOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Connect to load current membership details.'**
  String get membershipOfflineMessage;

  /// No description provided for @membershipSetupPending.
  ///
  /// In en, this message translates to:
  /// **'Membership setup pending'**
  String get membershipSetupPending;

  /// No description provided for @membershipChangeDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Membership change not permitted'**
  String get membershipChangeDeniedTitle;

  /// No description provided for @membershipChangeDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account cannot change membership right now. Your current membership remains unchanged.'**
  String get membershipChangeDeniedMessage;

  /// No description provided for @membershipChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Membership details changed'**
  String get membershipChangedTitle;

  /// No description provided for @membershipChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'The club updated these details while you were reviewing them. Refresh before choosing a package.'**
  String get membershipChangedMessage;

  /// No description provided for @membershipTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Membership request timed out'**
  String get membershipTimeoutTitle;

  /// No description provided for @membershipTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'The secure request window expired. Refresh membership status before trying again.'**
  String get membershipTimeoutMessage;

  /// No description provided for @membershipUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Membership details are temporarily unavailable.'**
  String get membershipUnavailableMessage;

  /// No description provided for @membershipPaymentSent.
  ///
  /// In en, this message translates to:
  /// **'Payment sent'**
  String get membershipPaymentSent;

  /// No description provided for @membershipPaymentVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying payment'**
  String get membershipPaymentVerifying;

  /// No description provided for @membershipConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Membership confirmed'**
  String get membershipConfirmed;

  /// No description provided for @membershipRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'{tier} membership request'**
  String membershipRequestTitle(String tier);

  /// No description provided for @membershipAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount: {currency} {amount}'**
  String membershipAmount(String currency, String amount);

  /// No description provided for @membershipVerificationTime.
  ///
  /// In en, this message translates to:
  /// **'Verification typically takes 1–24 hours. You will be notified once confirmed.'**
  String get membershipVerificationTime;

  /// No description provided for @membershipRequestedOn.
  ///
  /// In en, this message translates to:
  /// **'Requested: {date}'**
  String membershipRequestedOn(String date);

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get contactSupport;

  /// No description provided for @membershipPackageEmpty.
  ///
  /// In en, this message translates to:
  /// **'Membership packages will appear once the club publishes them.'**
  String get membershipPackageEmpty;

  /// No description provided for @fanRegistrySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search fans by name'**
  String get fanRegistrySearchHint;

  /// No description provided for @fanRegistryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Registry unavailable'**
  String get fanRegistryUnavailable;

  /// No description provided for @fanRegistryUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Fan registry is temporarily unavailable.'**
  String get fanRegistryUnavailableMessage;

  /// No description provided for @fanRegistryLoaded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No fans loaded} =1{1 fan loaded} other{{count} fans loaded}}'**
  String fanRegistryLoaded(int count);

  /// No description provided for @fanRegistrySummary.
  ///
  /// In en, this message translates to:
  /// **'This registry mirrors the club membership roster.'**
  String get fanRegistrySummary;

  /// No description provided for @fanRegistryFiltered.
  ///
  /// In en, this message translates to:
  /// **'Filtered results for “{query}”.'**
  String fanRegistryFiltered(String query);

  /// No description provided for @fanRegistryLoadMoreFailure.
  ///
  /// In en, this message translates to:
  /// **'Could not load more fans right now.'**
  String get fanRegistryLoadMoreFailure;

  /// No description provided for @fanRegistryPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get fanRegistryPending;

  /// No description provided for @fanRegistryActivity.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No activity} =1{1 activity} other{{count} activity}}'**
  String fanRegistryActivity(int count);

  /// No description provided for @fanRegistryJoined.
  ///
  /// In en, this message translates to:
  /// **'Joined {date}'**
  String fanRegistryJoined(String date);

  /// No description provided for @fanRegistryJoinedRenews.
  ///
  /// In en, this message translates to:
  /// **'Joined {joined} • Renews {renews}'**
  String fanRegistryJoinedRenews(String joined, String renews);

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileLoadingMembership.
  ///
  /// In en, this message translates to:
  /// **'Loading membership…'**
  String get profileLoadingMembership;

  /// No description provided for @profileMembershipReviewPending.
  ///
  /// In en, this message translates to:
  /// **'Membership review pending'**
  String get profileMembershipReviewPending;

  /// No description provided for @profileMyClub.
  ///
  /// In en, this message translates to:
  /// **'My club'**
  String get profileMyClub;

  /// No description provided for @profileMatchday.
  ///
  /// In en, this message translates to:
  /// **'Matchday'**
  String get profileMatchday;

  /// No description provided for @profileMyPicks.
  ///
  /// In en, this message translates to:
  /// **'My picks'**
  String get profileMyPicks;

  /// No description provided for @profileClubBenefits.
  ///
  /// In en, this message translates to:
  /// **'Club benefits'**
  String get profileClubBenefits;

  /// No description provided for @profileContributions.
  ///
  /// In en, this message translates to:
  /// **'Contributions'**
  String get profileContributions;

  /// No description provided for @profileShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get profileShop;

  /// No description provided for @profileApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get profileApp;

  /// No description provided for @profileNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profileNotifications;

  /// No description provided for @profileActivityHistory.
  ///
  /// In en, this message translates to:
  /// **'Activity history'**
  String get profileActivityHistory;

  /// No description provided for @profileActivityPoints.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No activity points} =1{1 activity point} other{{count} activity points}}'**
  String profileActivityPoints(int count);

  /// No description provided for @tierTitle.
  ///
  /// In en, this message translates to:
  /// **'Membership tier'**
  String get tierTitle;

  /// No description provided for @tierUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Tier details unavailable'**
  String get tierUnavailableTitle;

  /// No description provided for @tierDisabledMessage.
  ///
  /// In en, this message translates to:
  /// **'Membership tier details are disabled for this build. No membership request can be started here.'**
  String get tierDisabledMessage;

  /// No description provided for @backToMembership.
  ///
  /// In en, this message translates to:
  /// **'Back to membership'**
  String get backToMembership;

  /// No description provided for @tierNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Tier not found'**
  String get tierNotFoundTitle;

  /// No description provided for @tierNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'This membership tier is not available in the official category list.'**
  String get tierNotFoundMessage;

  /// No description provided for @tierOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Tier details offline'**
  String get tierOfflineTitle;

  /// No description provided for @tierOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to check this membership tier. No request is queued offline.'**
  String get tierOfflineMessage;

  /// No description provided for @tierAccessDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Tier access denied'**
  String get tierAccessDeniedTitle;

  /// No description provided for @tierAccessDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'This account cannot open the requested membership tier details.'**
  String get tierAccessDeniedMessage;

  /// No description provided for @tierTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Tier check timed out'**
  String get tierTimeoutTitle;

  /// No description provided for @tierTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'The app could not confirm this membership tier in time. Try one bounded refresh.'**
  String get tierTimeoutMessage;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @tierChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Tier details changed'**
  String get tierChangedTitle;

  /// No description provided for @tierChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'The current tier could not be confirmed because its details changed elsewhere.'**
  String get tierChangedMessage;

  /// No description provided for @tierLoadUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'The membership tier could not be loaded. No private service details were shown.'**
  String get tierLoadUnavailableMessage;

  /// No description provided for @tierSelected.
  ///
  /// In en, this message translates to:
  /// **'{tier} membership tier selected'**
  String tierSelected(String tier);

  /// No description provided for @tierPerks.
  ///
  /// In en, this message translates to:
  /// **'Tier perks'**
  String get tierPerks;

  /// No description provided for @tierAccess.
  ///
  /// In en, this message translates to:
  /// **'Membership access'**
  String get tierAccess;

  /// No description provided for @tierShowingOfficialTitle.
  ///
  /// In en, this message translates to:
  /// **'Showing official tier details'**
  String get tierShowingOfficialTitle;

  /// No description provided for @tierOfflineStatusMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to check for updates. No membership request is queued offline.'**
  String get tierOfflineStatusMessage;

  /// No description provided for @tierRefreshingTitle.
  ///
  /// In en, this message translates to:
  /// **'Refreshing tier details'**
  String get tierRefreshingTitle;

  /// No description provided for @tierRefreshingMessage.
  ///
  /// In en, this message translates to:
  /// **'The official category details stay visible while updates load.'**
  String get tierRefreshingMessage;

  /// No description provided for @tierUpdateDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Update access denied'**
  String get tierUpdateDeniedTitle;

  /// No description provided for @tierUpdateDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Official category details remain visible. This account cannot check remote updates.'**
  String get tierUpdateDeniedMessage;

  /// No description provided for @tierChangedStatusMessage.
  ///
  /// In en, this message translates to:
  /// **'Official category details remain visible. Refresh to confirm the latest version.'**
  String get tierChangedStatusMessage;

  /// No description provided for @tierRefreshTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Tier refresh timed out'**
  String get tierRefreshTimeoutTitle;

  /// No description provided for @tierRefreshTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'Official category details remain visible. Try one bounded refresh.'**
  String get tierRefreshTimeoutMessage;

  /// No description provided for @tierOutdatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Tier details may be out of date'**
  String get tierOutdatedTitle;

  /// No description provided for @tierOutdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Official category details remain visible while the service is unavailable.'**
  String get tierOutdatedMessage;

  /// No description provided for @tierDegradedMessage.
  ///
  /// In en, this message translates to:
  /// **'The last available category details remain visible until refresh succeeds.'**
  String get tierDegradedMessage;

  /// No description provided for @contributionConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm contribution'**
  String get contributionConfirmTitle;

  /// No description provided for @contributionConfirmQuestion.
  ///
  /// In en, this message translates to:
  /// **'Did you complete the MoMo USSD payment for the {tier} tier?'**
  String contributionConfirmQuestion(String tier);

  /// No description provided for @contributionSelectedTier.
  ///
  /// In en, this message translates to:
  /// **'Selected tier'**
  String get contributionSelectedTier;

  /// No description provided for @contributionPendingVerification.
  ///
  /// In en, this message translates to:
  /// **'Pending verification'**
  String get contributionPendingVerification;

  /// No description provided for @contributionNotYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get contributionNotYet;

  /// No description provided for @contributionConfirming.
  ///
  /// In en, this message translates to:
  /// **'Confirming…'**
  String get contributionConfirming;

  /// No description provided for @contributionYesPaid.
  ///
  /// In en, this message translates to:
  /// **'Yes, I paid'**
  String get contributionYesPaid;

  /// No description provided for @contributionPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Contributions are verified anonymously via Fan ID.'**
  String get contributionPrivacy;

  /// No description provided for @contributionHistory.
  ///
  /// In en, this message translates to:
  /// **'Contribution history'**
  String get contributionHistory;

  /// No description provided for @shareMembershipCard.
  ///
  /// In en, this message translates to:
  /// **'Share membership card'**
  String get shareMembershipCard;

  /// No description provided for @shareMembershipCardHint.
  ///
  /// In en, this message translates to:
  /// **'Share your digital membership card'**
  String get shareMembershipCardHint;

  /// No description provided for @membershipSince.
  ///
  /// In en, this message translates to:
  /// **'Since {date}'**
  String membershipSince(String date);

  /// No description provided for @membershipFanCard.
  ///
  /// In en, this message translates to:
  /// **'Fan card'**
  String get membershipFanCard;

  /// No description provided for @membershipReviewPendingUpper.
  ///
  /// In en, this message translates to:
  /// **'Review pending'**
  String get membershipReviewPendingUpper;

  /// No description provided for @membershipBrandWatermark.
  ///
  /// In en, this message translates to:
  /// **'GIKUNDIRO'**
  String get membershipBrandWatermark;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navClub.
  ///
  /// In en, this message translates to:
  /// **'Club'**
  String get navClub;

  /// No description provided for @navFanZone.
  ///
  /// In en, this message translates to:
  /// **'Fan Zone'**
  String get navFanZone;

  /// No description provided for @navMembership.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get navMembership;

  /// No description provided for @membershipConnectBeforeChange.
  ///
  /// In en, this message translates to:
  /// **'Connect before changing membership.'**
  String get membershipConnectBeforeChange;

  /// No description provided for @membershipSignInFirst.
  ///
  /// In en, this message translates to:
  /// **'Sign in first to activate membership.'**
  String get membershipSignInFirst;

  /// No description provided for @membershipRequestSubmitted.
  ///
  /// In en, this message translates to:
  /// **'{tier} membership request submitted.'**
  String membershipRequestSubmitted(String tier);

  /// No description provided for @membershipAlreadyPending.
  ///
  /// In en, this message translates to:
  /// **'{tier} membership is already pending payment verification.'**
  String membershipAlreadyPending(String tier);

  /// No description provided for @membershipStarted.
  ///
  /// In en, this message translates to:
  /// **'{tier} membership started.'**
  String membershipStarted(String tier);

  /// No description provided for @membershipPaymentSetupPending.
  ///
  /// In en, this message translates to:
  /// **'Membership payment setup is pending club activation.'**
  String get membershipPaymentSetupPending;

  /// No description provided for @membershipDialerFailed.
  ///
  /// In en, this message translates to:
  /// **'{tier} request was saved, but the MoMo dialer could not open.'**
  String membershipDialerFailed(String tier);

  /// No description provided for @membershipSubmittedBackground.
  ///
  /// In en, this message translates to:
  /// **'{tier} request submitted. Payment verification happens in the background.'**
  String membershipSubmittedBackground(String tier);

  /// No description provided for @membershipPendingReviewAction.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get membershipPendingReviewAction;

  /// No description provided for @membershipActivateAction.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get membershipActivateAction;

  /// No description provided for @membershipRenewAction.
  ///
  /// In en, this message translates to:
  /// **'Renew'**
  String get membershipRenewAction;

  /// No description provided for @membershipSwitchAction.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get membershipSwitchAction;

  /// No description provided for @membershipCopied.
  ///
  /// In en, this message translates to:
  /// **'Membership details copied.'**
  String get membershipCopied;

  /// No description provided for @membershipShareText.
  ///
  /// In en, this message translates to:
  /// **'{club} membership\nTier: {tier}\nSupporter ID: #{supporter}'**
  String membershipShareText(String club, String tier, String supporter);

  /// No description provided for @membershipActivityPending.
  ///
  /// In en, this message translates to:
  /// **'Membership activity appears after ticket, fanclub, and contribution reviews.'**
  String get membershipActivityPending;

  /// No description provided for @membershipActivityRecorded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No activity points recorded.} =1{1 activity point recorded.} other{{count} activity points recorded.}}'**
  String membershipActivityRecorded(int count);

  /// No description provided for @membershipSupportMessage.
  ///
  /// In en, this message translates to:
  /// **'Hi, I need help with my membership payment verification.'**
  String get membershipSupportMessage;

  /// No description provided for @membershipWhatsAppUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not open WhatsApp. Please contact support.'**
  String get membershipWhatsAppUnavailable;

  /// No description provided for @membershipSupportNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Support contact is not configured yet.'**
  String get membershipSupportNotConfigured;

  /// No description provided for @membershipSubmittingTitle.
  ///
  /// In en, this message translates to:
  /// **'Submitting membership request'**
  String get membershipSubmittingTitle;

  /// No description provided for @membershipUpdatingTitle.
  ///
  /// In en, this message translates to:
  /// **'Updating membership'**
  String get membershipUpdatingTitle;

  /// No description provided for @membershipSubmittingMessage.
  ///
  /// In en, this message translates to:
  /// **'Keep this screen open while the club receives your request.'**
  String get membershipSubmittingMessage;

  /// No description provided for @membershipUpdatingMessage.
  ///
  /// In en, this message translates to:
  /// **'Refreshing packages and current membership details.'**
  String get membershipUpdatingMessage;

  /// No description provided for @membershipRefreshAction.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get membershipRefreshAction;

  /// No description provided for @membershipCurrentStatus.
  ///
  /// In en, this message translates to:
  /// **'{tier} · Current'**
  String membershipCurrentStatus(String tier);

  /// No description provided for @membershipRefreshRequired.
  ///
  /// In en, this message translates to:
  /// **'Refresh required'**
  String get membershipRefreshRequired;

  /// No description provided for @membershipSubmittingAction.
  ///
  /// In en, this message translates to:
  /// **'Submitting'**
  String get membershipSubmittingAction;

  /// No description provided for @membershipPackageCurrentSemantic.
  ///
  /// In en, this message translates to:
  /// **'{tier} membership package, current'**
  String membershipPackageCurrentSemantic(String tier);

  /// No description provided for @membershipPackageFallback.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get membershipPackageFallback;

  /// No description provided for @membershipFanFallback.
  ///
  /// In en, this message translates to:
  /// **'Fan'**
  String get membershipFanFallback;

  /// No description provided for @membershipDateNextYear.
  ///
  /// In en, this message translates to:
  /// **'next year'**
  String get membershipDateNextYear;

  /// No description provided for @membershipDate.
  ///
  /// In en, this message translates to:
  /// **'{day} {month} {year}'**
  String membershipDate(int day, String month, int year);

  /// No description provided for @membershipMonthJan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get membershipMonthJan;

  /// No description provided for @membershipMonthFeb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get membershipMonthFeb;

  /// No description provided for @membershipMonthMar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get membershipMonthMar;

  /// No description provided for @membershipMonthApr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get membershipMonthApr;

  /// No description provided for @membershipMonthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get membershipMonthMay;

  /// No description provided for @membershipMonthJun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get membershipMonthJun;

  /// No description provided for @membershipMonthJul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get membershipMonthJul;

  /// No description provided for @membershipMonthAug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get membershipMonthAug;

  /// No description provided for @membershipMonthSep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get membershipMonthSep;

  /// No description provided for @membershipMonthOct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get membershipMonthOct;

  /// No description provided for @membershipMonthNov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get membershipMonthNov;

  /// No description provided for @membershipMonthDec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get membershipMonthDec;

  /// No description provided for @clubTitle.
  ///
  /// In en, this message translates to:
  /// **'Club'**
  String get clubTitle;

  /// No description provided for @clubOfficialOverviewSemantic.
  ///
  /// In en, this message translates to:
  /// **'{club} official club overview'**
  String clubOfficialOverviewSemantic(String club);

  /// No description provided for @clubLiveIdentityUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Live club identity unavailable'**
  String get clubLiveIdentityUnavailable;

  /// No description provided for @clubIdentityFallbackMessage.
  ///
  /// In en, this message translates to:
  /// **'Showing the verified app identity while the current club record cannot be refreshed.'**
  String get clubIdentityFallbackMessage;

  /// No description provided for @clubOfficialSection.
  ///
  /// In en, this message translates to:
  /// **'Official club'**
  String get clubOfficialSection;

  /// No description provided for @clubTeamTitle.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get clubTeamTitle;

  /// No description provided for @clubTeamSubtitle.
  ///
  /// In en, this message translates to:
  /// **'First-team squad and official player profiles'**
  String get clubTeamSubtitle;

  /// No description provided for @clubTeamEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No squad published'**
  String get clubTeamEmptyTitle;

  /// No description provided for @clubTeamEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'The club has not published its first-team squad for this app.'**
  String get clubTeamEmptyMessage;

  /// No description provided for @clubNewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Club news'**
  String get clubNewsTitle;

  /// No description provided for @clubNewsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Published club reporting and announcements'**
  String get clubNewsSubtitle;

  /// No description provided for @clubNewsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No news published'**
  String get clubNewsEmptyTitle;

  /// No description provided for @clubNewsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Published club stories will appear here.'**
  String get clubNewsEmptyMessage;

  /// No description provided for @clubArticleUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Article unavailable'**
  String get clubArticleUnavailableTitle;

  /// No description provided for @clubArticleUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This article is not published for the active club or the link is no longer current.'**
  String get clubArticleUnavailableMessage;

  /// No description provided for @clubArticleBodyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The full article content is not available.'**
  String get clubArticleBodyUnavailable;

  /// No description provided for @clubFixturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Fixtures'**
  String get clubFixturesTitle;

  /// No description provided for @clubFixturesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming matches and ticket availability'**
  String get clubFixturesSubtitle;

  /// No description provided for @clubFixturesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No upcoming fixtures'**
  String get clubFixturesEmptyTitle;

  /// No description provided for @clubFixturesEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'The club has not published another fixture yet.'**
  String get clubFixturesEmptyMessage;

  /// No description provided for @clubFixtureTitle.
  ///
  /// In en, this message translates to:
  /// **'{home} vs {away}'**
  String clubFixtureTitle(String home, String away);

  /// No description provided for @clubTicketsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get clubTicketsTitle;

  /// No description provided for @clubResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get clubResultsTitle;

  /// No description provided for @clubResultsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Completed match scores'**
  String get clubResultsSubtitle;

  /// No description provided for @clubResultsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No results published'**
  String get clubResultsEmptyTitle;

  /// No description provided for @clubResultsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Completed club matches will appear here.'**
  String get clubResultsEmptyMessage;

  /// No description provided for @clubResultTitle.
  ///
  /// In en, this message translates to:
  /// **'{home} {homeScore} – {awayScore} {away}'**
  String clubResultTitle(
    String home,
    int homeScore,
    int awayScore,
    String away,
  );

  /// No description provided for @clubMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get clubMatchTitle;

  /// No description provided for @clubMatchUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Match unavailable'**
  String get clubMatchUnavailableTitle;

  /// No description provided for @clubMatchUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This match is not published for the active club or the link is no longer current.'**
  String get clubMatchUnavailableMessage;

  /// No description provided for @clubScore.
  ///
  /// In en, this message translates to:
  /// **'{homeScore} – {awayScore}'**
  String clubScore(int homeScore, int awayScore);

  /// No description provided for @clubViewAvailableTickets.
  ///
  /// In en, this message translates to:
  /// **'View available tickets'**
  String get clubViewAvailableTickets;

  /// No description provided for @clubStandingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Standings'**
  String get clubStandingsTitle;

  /// No description provided for @clubStandingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Current published league table'**
  String get clubStandingsSubtitle;

  /// No description provided for @clubStandingsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No standings published'**
  String get clubStandingsEmptyTitle;

  /// No description provided for @clubStandingsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'The current league table has not been published.'**
  String get clubStandingsEmptyMessage;

  /// No description provided for @clubPlayedShort.
  ///
  /// In en, this message translates to:
  /// **'P'**
  String get clubPlayedShort;

  /// No description provided for @clubGoalDifferenceShort.
  ///
  /// In en, this message translates to:
  /// **'GD'**
  String get clubGoalDifferenceShort;

  /// No description provided for @clubPointsShort.
  ///
  /// In en, this message translates to:
  /// **'PTS'**
  String get clubPointsShort;

  /// No description provided for @clubHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Club history'**
  String get clubHistoryTitle;

  /// No description provided for @clubHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'The club record and milestones'**
  String get clubHistorySubtitle;

  /// No description provided for @clubHistoryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'History not published'**
  String get clubHistoryEmptyTitle;

  /// No description provided for @clubHistoryEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'The club history remains unavailable until reviewed content is published.'**
  String get clubHistoryEmptyMessage;

  /// No description provided for @clubProjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Club projects'**
  String get clubProjectsTitle;

  /// No description provided for @clubProjectsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Governed supporter projects and progress'**
  String get clubProjectsSubtitle;

  /// No description provided for @clubProjectsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No projects published'**
  String get clubProjectsEmptyTitle;

  /// No description provided for @clubProjectsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Governed supporter projects will appear after club approval.'**
  String get clubProjectsEmptyMessage;

  /// No description provided for @clubSupporters.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No supporters} =1{1 supporter} other{{count} supporters}}'**
  String clubSupporters(int count);

  /// No description provided for @clubProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Club project'**
  String get clubProjectTitle;

  /// No description provided for @clubProjectUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Project unavailable'**
  String get clubProjectUnavailableTitle;

  /// No description provided for @clubProjectUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This project is not active for the current club or the link is no longer current.'**
  String get clubProjectUnavailableMessage;

  /// No description provided for @clubSupportersParticipate.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No supporters currently participate.} =1{1 supporter currently participates.} other{{count} supporters currently participate.}}'**
  String clubSupportersParticipate(int count);

  /// No description provided for @clubOpenContribution.
  ///
  /// In en, this message translates to:
  /// **'Open contribution workflow'**
  String get clubOpenContribution;

  /// No description provided for @clubInformationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Club information unavailable'**
  String get clubInformationUnavailable;

  /// No description provided for @clubInformationLoadMessage.
  ///
  /// In en, this message translates to:
  /// **'The current club data could not be loaded. Existing app content has not been replaced.'**
  String get clubInformationLoadMessage;

  /// No description provided for @clubLinkedRecordLoadMessage.
  ///
  /// In en, this message translates to:
  /// **'The linked club record could not be loaded.'**
  String get clubLinkedRecordLoadMessage;

  /// No description provided for @clubRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get clubRefresh;

  /// No description provided for @clubTicketsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Match tickets published for this club'**
  String get clubTicketsSubtitle;

  /// No description provided for @clubShopTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get clubShopTitle;

  /// No description provided for @clubShopSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Official products and availability'**
  String get clubShopSubtitle;

  /// No description provided for @onboardingBelongImageSemantic.
  ///
  /// In en, this message translates to:
  /// **'{club} players applauding supporters after a match'**
  String onboardingBelongImageSemantic(String club);

  /// No description provided for @onboardingKnowImageSemantic.
  ///
  /// In en, this message translates to:
  /// **'{club} players celebrating together'**
  String onboardingKnowImageSemantic(String club);

  /// No description provided for @onboardingLiveImageSemantic.
  ///
  /// In en, this message translates to:
  /// **'{club} player portrait'**
  String onboardingLiveImageSemantic(String club);

  /// No description provided for @onboardingIdentitySemantic.
  ///
  /// In en, this message translates to:
  /// **'{club} identity'**
  String onboardingIdentitySemantic(String club);

  /// No description provided for @onboardingImageSemantic.
  ///
  /// In en, this message translates to:
  /// **'{description}. Image {index} of {count}'**
  String onboardingImageSemantic(String description, int index, int count);

  /// No description provided for @onboardingAnonymousSessionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not start a guest session. Try again.'**
  String get onboardingAnonymousSessionUnavailable;

  /// No description provided for @onboardingRefreshingTitle.
  ///
  /// In en, this message translates to:
  /// **'Refreshing welcome'**
  String get onboardingRefreshingTitle;

  /// No description provided for @onboardingRefreshingMessage.
  ///
  /// In en, this message translates to:
  /// **'Keeping the current welcome and choices visible while updates are checked.'**
  String get onboardingRefreshingMessage;

  /// No description provided for @onboardingStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome status'**
  String get onboardingStatusTitle;

  /// No description provided for @onboardingWhatsAppUnavailable.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp sign-in unavailable'**
  String get onboardingWhatsAppUnavailable;

  /// No description provided for @onboardingOfflineSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Offline. Your saved welcome is available. Continue without signing in.'**
  String get onboardingOfflineSavedMessage;

  /// No description provided for @onboardingWhatsAppLaterMessage.
  ///
  /// In en, this message translates to:
  /// **'Continue without signing in, or try WhatsApp later.'**
  String get onboardingWhatsAppLaterMessage;

  /// No description provided for @onboardingContentUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome content unavailable'**
  String get onboardingContentUnavailableTitle;

  /// No description provided for @onboardingContentUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'There is no welcome content to show yet. Refresh or continue without signing in.'**
  String get onboardingContentUnavailableMessage;

  /// No description provided for @onboardingPreparingTitle.
  ///
  /// In en, this message translates to:
  /// **'Preparing your welcome'**
  String get onboardingPreparingTitle;

  /// No description provided for @onboardingPreparingMessage.
  ///
  /// In en, this message translates to:
  /// **'Loading the latest club welcome and sign-in choices.'**
  String get onboardingPreparingMessage;

  /// No description provided for @onboardingAccessUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome access unavailable'**
  String get onboardingAccessUnavailableTitle;

  /// No description provided for @onboardingAccessUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This welcome cannot be opened for this account. WhatsApp sign-in and guest access remain available.'**
  String get onboardingAccessUnavailableMessage;

  /// No description provided for @onboardingChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome changed'**
  String get onboardingChangedTitle;

  /// No description provided for @onboardingChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'The welcome changed while it was opening. Refresh to load the current version.'**
  String get onboardingChangedMessage;

  /// No description provided for @onboardingSecurityTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome security check timed out'**
  String get onboardingSecurityTimeoutTitle;

  /// No description provided for @onboardingSecurityTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'The welcome could not be verified in time. Check your connection and refresh.'**
  String get onboardingSecurityTimeoutMessage;

  /// No description provided for @onboardingUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome unavailable'**
  String get onboardingUnavailableTitle;

  /// No description provided for @onboardingUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'The welcome could not be loaded safely. Try again or continue without signing in.'**
  String get onboardingUnavailableMessage;

  /// No description provided for @onboardingRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get onboardingRefresh;

  /// No description provided for @splashLoadingSemantic.
  ///
  /// In en, this message translates to:
  /// **'{app} loading'**
  String splashLoadingSemantic(String app);

  /// No description provided for @authBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get authBack;

  /// No description provided for @authCountryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Country details are unavailable for this build.'**
  String get authCountryUnavailable;

  /// No description provided for @authSendingCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Sending code'**
  String get authSendingCodeTitle;

  /// No description provided for @authSendingCodeMessage.
  ///
  /// In en, this message translates to:
  /// **'Keep this screen open while WhatsApp sign-in starts.'**
  String get authSendingCodeMessage;

  /// No description provided for @authSignInUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in unavailable'**
  String get authSignInUnavailableTitle;

  /// No description provided for @authRequestTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Request timed out'**
  String get authRequestTimeoutTitle;

  /// No description provided for @authNumberLinkedTitle.
  ///
  /// In en, this message translates to:
  /// **'Number already linked'**
  String get authNumberLinkedTitle;

  /// No description provided for @authCheckNumberTitle.
  ///
  /// In en, this message translates to:
  /// **'Check the number'**
  String get authCheckNumberTitle;

  /// No description provided for @authCodeNotSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Code not sent'**
  String get authCodeNotSentTitle;

  /// No description provided for @authEditNumber.
  ///
  /// In en, this message translates to:
  /// **'Edit number'**
  String get authEditNumber;

  /// No description provided for @authPhonePermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'This account cannot request a sign-in code.'**
  String get authPhonePermissionMessage;

  /// No description provided for @authPhoneTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'The code request timed out. Check your connection and try again.'**
  String get authPhoneTimeoutMessage;

  /// No description provided for @authPhoneConflictMessage.
  ///
  /// In en, this message translates to:
  /// **'This number is already linked. Review the number or use the existing account.'**
  String get authPhoneConflictMessage;

  /// No description provided for @authPhoneInvalidMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number including the country code.'**
  String get authPhoneInvalidMessage;

  /// No description provided for @authPhoneUnknownMessage.
  ///
  /// In en, this message translates to:
  /// **'The sign-in code could not be sent. Try again.'**
  String get authPhoneUnknownMessage;

  /// No description provided for @authPhoneOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet to send a WhatsApp code.'**
  String get authPhoneOfflineMessage;

  /// No description provided for @authWhatsAppEyebrow.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get authWhatsAppEyebrow;

  /// No description provided for @authEnterNumberTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter number'**
  String get authEnterNumberTitle;

  /// No description provided for @authEnterNumberBody.
  ///
  /// In en, this message translates to:
  /// **'We will send a private sign-in code.'**
  String get authEnterNumberBody;

  /// No description provided for @authPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get authPhoneLabel;

  /// No description provided for @authWhatsAppNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp number'**
  String get authWhatsAppNumberLabel;

  /// No description provided for @authPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'+250 7xx xxx xxx'**
  String get authPhoneHint;

  /// No description provided for @authPhonePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Your number stays private.'**
  String get authPhonePrivacy;

  /// No description provided for @authSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get authSendCode;

  /// No description provided for @authGuestSessionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not start a guest session. Try again.'**
  String get authGuestSessionUnavailable;

  /// No description provided for @authOtpInvalidMessage.
  ///
  /// In en, this message translates to:
  /// **'Check the code and try again.'**
  String get authOtpInvalidMessage;

  /// No description provided for @authOtpExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Request a new code.'**
  String get authOtpExpiredMessage;

  /// No description provided for @authNewCodeSent.
  ///
  /// In en, this message translates to:
  /// **'New WhatsApp code sent.'**
  String get authNewCodeSent;

  /// No description provided for @authSendingNewCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Sending new code'**
  String get authSendingNewCodeTitle;

  /// No description provided for @authCheckingCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Checking code'**
  String get authCheckingCodeTitle;

  /// No description provided for @authSendingNewCodeMessage.
  ///
  /// In en, this message translates to:
  /// **'Keep this screen open while a new code is requested.'**
  String get authSendingNewCodeMessage;

  /// No description provided for @authCheckingCodeMessage.
  ///
  /// In en, this message translates to:
  /// **'Keep this screen open while the code is verified.'**
  String get authCheckingCodeMessage;

  /// No description provided for @authVerificationUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification unavailable'**
  String get authVerificationUnavailableTitle;

  /// No description provided for @authCodeExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Code expired'**
  String get authCodeExpiredTitle;

  /// No description provided for @authCodeNotAcceptedTitle.
  ///
  /// In en, this message translates to:
  /// **'Code not accepted'**
  String get authCodeNotAcceptedTitle;

  /// No description provided for @authVerificationFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification failed'**
  String get authVerificationFailedTitle;

  /// No description provided for @authCheckCode.
  ///
  /// In en, this message translates to:
  /// **'Check code'**
  String get authCheckCode;

  /// No description provided for @authOtpPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'This account cannot verify the requested code.'**
  String get authOtpPermissionMessage;

  /// No description provided for @authOtpConflictMessage.
  ///
  /// In en, this message translates to:
  /// **'This number is already linked to another sign-in.'**
  String get authOtpConflictMessage;

  /// No description provided for @authOtpUnknownMessage.
  ///
  /// In en, this message translates to:
  /// **'The code could not be verified. Try again.'**
  String get authOtpUnknownMessage;

  /// No description provided for @authOtpOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet to verify the WhatsApp code.'**
  String get authOtpOfflineMessage;

  /// No description provided for @authPhoneMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone number missing'**
  String get authPhoneMissingTitle;

  /// No description provided for @authPhoneMissingMessage.
  ///
  /// In en, this message translates to:
  /// **'Start again to request a WhatsApp code.'**
  String get authPhoneMissingMessage;

  /// No description provided for @authChangeNumber.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get authChangeNumber;

  /// No description provided for @authResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String authResendIn(int seconds);

  /// No description provided for @authResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get authResendCode;

  /// No description provided for @authCheckWhatsAppEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Check WhatsApp'**
  String get authCheckWhatsAppEyebrow;

  /// No description provided for @authEnterCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter code'**
  String get authEnterCodeTitle;

  /// No description provided for @authEnterCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Sent to your WhatsApp number.'**
  String get authEnterCodeBody;

  /// No description provided for @authCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get authCodeLabel;

  /// No description provided for @authWhatsAppCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp code'**
  String get authWhatsAppCodeLabel;

  /// No description provided for @authCodeHint.
  ///
  /// In en, this message translates to:
  /// **'••••••'**
  String get authCodeHint;

  /// No description provided for @authCodePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Code hidden for privacy.'**
  String get authCodePrivacy;

  /// No description provided for @authVerifyCode.
  ///
  /// In en, this message translates to:
  /// **'Verify code'**
  String get authVerifyCode;

  /// No description provided for @authVerifyAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Verify and continue'**
  String get authVerifyAndContinue;

  /// No description provided for @homeRefreshingTitle.
  ///
  /// In en, this message translates to:
  /// **'Refreshing Home'**
  String get homeRefreshingTitle;

  /// No description provided for @homeRefreshingMessage.
  ///
  /// In en, this message translates to:
  /// **'Keeping the current matchday, points, and shortcuts visible while updates load.'**
  String get homeRefreshingMessage;

  /// No description provided for @homeUpdatesPausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Live updates paused'**
  String get homeUpdatesPausedTitle;

  /// No description provided for @homeSavedContentNotice.
  ///
  /// In en, this message translates to:
  /// **'Showing saved Home content. Reconnect and refresh for current club updates.'**
  String get homeSavedContentNotice;

  /// No description provided for @homeOfflineShortcutsNotice.
  ///
  /// In en, this message translates to:
  /// **'Connect to refresh Home. Showing saved shortcuts.'**
  String get homeOfflineShortcutsNotice;

  /// No description provided for @homeLiveUnavailableNotice.
  ///
  /// In en, this message translates to:
  /// **'Live club data is temporarily unavailable. Pull to refresh.'**
  String get homeLiveUnavailableNotice;

  /// No description provided for @homePartialUnavailableNotice.
  ///
  /// In en, this message translates to:
  /// **'Some live club data is temporarily unavailable. Pull to refresh.'**
  String get homePartialUnavailableNotice;

  /// No description provided for @homePartialShortcutsUnavailableNotice.
  ///
  /// In en, this message translates to:
  /// **'Some live club data is temporarily unavailable. Home shortcuts are unavailable.'**
  String get homePartialShortcutsUnavailableNotice;

  /// No description provided for @homeMatchdayPendingNotice.
  ///
  /// In en, this message translates to:
  /// **'Matchday data will appear when published.'**
  String get homeMatchdayPendingNotice;

  /// No description provided for @homeOpenMatchday.
  ///
  /// In en, this message translates to:
  /// **'Open matchday'**
  String get homeOpenMatchday;

  /// No description provided for @homeMatchdayUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Matchday unavailable'**
  String get homeMatchdayUnavailable;

  /// No description provided for @homeOpenMatchdaySemantic.
  ///
  /// In en, this message translates to:
  /// **'Open matchday in Fan Zone'**
  String get homeOpenMatchdaySemantic;

  /// No description provided for @homeMatchdayUnavailableSemantic.
  ///
  /// In en, this message translates to:
  /// **'Matchday in Fan Zone is unavailable'**
  String get homeMatchdayUnavailableSemantic;

  /// No description provided for @homeMatchdayTitle.
  ///
  /// In en, this message translates to:
  /// **'Matchday'**
  String get homeMatchdayTitle;

  /// No description provided for @homeNextFixturePending.
  ///
  /// In en, this message translates to:
  /// **'The next fixture will appear here when it is published.'**
  String get homeNextFixturePending;

  /// No description provided for @homeFixturesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Club fixtures are not available yet.'**
  String get homeFixturesUnavailable;

  /// No description provided for @homeOpenFanZone.
  ///
  /// In en, this message translates to:
  /// **'Open Fan Zone'**
  String get homeOpenFanZone;

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get homeSearchHint;

  /// No description provided for @homeSearchSemantic.
  ///
  /// In en, this message translates to:
  /// **'Search fans, fixtures, wallet'**
  String get homeSearchSemantic;

  /// No description provided for @homeNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get homeNotifications;

  /// No description provided for @homeWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get homeWallet;

  /// No description provided for @homeAccessUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Home access not available'**
  String get homeAccessUnavailableTitle;

  /// No description provided for @homeAccessUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account cannot load Home right now. Contact support if this should be available.'**
  String get homeAccessUnavailableMessage;

  /// No description provided for @homeChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Home changed'**
  String get homeChangedTitle;

  /// No description provided for @homeChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Home data changed while you were viewing it. Refresh to load the current version.'**
  String get homeChangedMessage;

  /// No description provided for @homeSecurityTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Home security check timed out'**
  String get homeSecurityTimeoutTitle;

  /// No description provided for @homeSecurityTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'We could not confirm current Home access. Refresh to retry.'**
  String get homeSecurityTimeoutMessage;

  /// No description provided for @homeUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Home unavailable'**
  String get homeUnavailableTitle;

  /// No description provided for @homeUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Live club data is temporarily unavailable.'**
  String get homeUnavailableMessage;

  /// No description provided for @homeSupportersTitle.
  ///
  /// In en, this message translates to:
  /// **'Supporters'**
  String get homeSupportersTitle;

  /// No description provided for @homeSupportersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Top active'**
  String get homeSupportersSubtitle;

  /// No description provided for @homePoints.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 pts} =1{1 pt} other{{count} pts}}'**
  String homePoints(int count);

  /// No description provided for @homeNewsTitle.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get homeNewsTitle;

  /// No description provided for @homeLatestUpdates.
  ///
  /// In en, this message translates to:
  /// **'Latest club updates'**
  String get homeLatestUpdates;

  /// No description provided for @homeLatestUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Latest Intel is temporarily unavailable. Pull to refresh.'**
  String get homeLatestUnavailable;

  /// No description provided for @homeOpenMatchDetails.
  ///
  /// In en, this message translates to:
  /// **'Open match details'**
  String get homeOpenMatchDetails;

  /// No description provided for @homeMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'{home} vs {away}'**
  String homeMatchTitle(String home, String away);

  /// No description provided for @homeShortcutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get homeShortcutsTitle;

  /// No description provided for @homeLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get homeLess;

  /// No description provided for @homeMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get homeMore;

  /// No description provided for @homeHideMoreShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Hide more shortcuts'**
  String get homeHideMoreShortcuts;

  /// No description provided for @homeShowMoreShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Show more shortcuts'**
  String get homeShowMoreShortcuts;

  /// No description provided for @homeMoreShortcuts.
  ///
  /// In en, this message translates to:
  /// **'More shortcuts'**
  String get homeMoreShortcuts;

  /// No description provided for @homeActionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{action}\nUnavailable'**
  String homeActionUnavailable(String action);

  /// No description provided for @homeActionUnavailableInline.
  ///
  /// In en, this message translates to:
  /// **'{action} · Unavailable'**
  String homeActionUnavailableInline(String action);

  /// No description provided for @homeActionOpensHint.
  ///
  /// In en, this message translates to:
  /// **'Opens {action}'**
  String homeActionOpensHint(String action);

  /// No description provided for @homeActionUnavailableHint.
  ///
  /// In en, this message translates to:
  /// **'{action} is unavailable'**
  String homeActionUnavailableHint(String action);

  /// No description provided for @homeTicketsAction.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get homeTicketsAction;

  /// No description provided for @homeMembershipAction.
  ///
  /// In en, this message translates to:
  /// **'Join Gikundiro'**
  String get homeMembershipAction;

  /// No description provided for @homeFanZoneAction.
  ///
  /// In en, this message translates to:
  /// **'Fan Zone'**
  String get homeFanZoneAction;

  /// No description provided for @homeShopAction.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get homeShopAction;

  /// No description provided for @homeFetLabel.
  ///
  /// In en, this message translates to:
  /// **'FET'**
  String get homeFetLabel;

  /// No description provided for @homeRankLabel.
  ///
  /// In en, this message translates to:
  /// **'Rank'**
  String get homeRankLabel;

  /// No description provided for @fanClubPreviewUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Fan club preview unavailable'**
  String get fanClubPreviewUnavailableTitle;

  /// No description provided for @fanClubPreviewUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Fan club details are not enabled for this build or club.'**
  String get fanClubPreviewUnavailableMessage;

  /// No description provided for @fanClubBackToSupporters.
  ///
  /// In en, this message translates to:
  /// **'BACK TO SUPPORTERS'**
  String get fanClubBackToSupporters;

  /// No description provided for @fanClubUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Fan club unavailable'**
  String get fanClubUnavailableTitle;

  /// No description provided for @fanClubUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This approved public fan club could not be found.'**
  String get fanClubUnavailableMessage;

  /// No description provided for @fanClubFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Fan club'**
  String get fanClubFallbackName;

  /// No description provided for @fanClubUnknownRegion.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get fanClubUnknownRegion;

  /// No description provided for @fanClubProtectedRequestPath.
  ///
  /// In en, this message translates to:
  /// **'Protected request path'**
  String get fanClubProtectedRequestPath;

  /// No description provided for @fanClubActive.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get fanClubActive;

  /// No description provided for @fanClubPendingReview.
  ///
  /// In en, this message translates to:
  /// **'PENDING REVIEW'**
  String get fanClubPendingReview;

  /// No description provided for @fanClubCurrentSemantic.
  ///
  /// In en, this message translates to:
  /// **'Current fan club, {name}'**
  String fanClubCurrentSemantic(String name);

  /// No description provided for @fanClubAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'ABOUT THIS CLUB'**
  String get fanClubAboutTitle;

  /// No description provided for @fanClubRegionValue.
  ///
  /// In en, this message translates to:
  /// **'Region: {region}'**
  String fanClubRegionValue(String region);

  /// No description provided for @fanClubSnapshotTitle.
  ///
  /// In en, this message translates to:
  /// **'GROUP SNAPSHOT'**
  String get fanClubSnapshotTitle;

  /// No description provided for @fanClubAwaitingApproval.
  ///
  /// In en, this message translates to:
  /// **'This fan club is waiting for admin approval.'**
  String get fanClubAwaitingApproval;

  /// No description provided for @fanClubJoinRequestsReviewed.
  ///
  /// In en, this message translates to:
  /// **'Join requests are reviewed in the Supporters area.'**
  String get fanClubJoinRequestsReviewed;

  /// No description provided for @fanClubRegionSentence.
  ///
  /// In en, this message translates to:
  /// **'Region: {region}.'**
  String fanClubRegionSentence(String region);

  /// No description provided for @fanClubPublicSupporters.
  ///
  /// In en, this message translates to:
  /// **'{members} supporters listed publicly.'**
  String fanClubPublicSupporters(String members);

  /// No description provided for @fanClubUnavailableOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Fan club unavailable offline'**
  String get fanClubUnavailableOfflineTitle;

  /// No description provided for @fanClubUnavailableOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Connect to confirm the latest approved club details.'**
  String get fanClubUnavailableOfflineMessage;

  /// No description provided for @fanClubAccessDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Fan club access denied'**
  String get fanClubAccessDeniedTitle;

  /// No description provided for @fanClubAccessDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'This club is not available for the current account.'**
  String get fanClubAccessDeniedMessage;

  /// No description provided for @fanClubDetailsChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Fan club details changed'**
  String get fanClubDetailsChangedTitle;

  /// No description provided for @fanClubRefreshBeforeSupporters.
  ///
  /// In en, this message translates to:
  /// **'Refresh before continuing to Supporters.'**
  String get fanClubRefreshBeforeSupporters;

  /// No description provided for @fanClubRefreshAction.
  ///
  /// In en, this message translates to:
  /// **'REFRESH CLUB'**
  String get fanClubRefreshAction;

  /// No description provided for @fanClubTryAgainAction.
  ///
  /// In en, this message translates to:
  /// **'TRY AGAIN'**
  String get fanClubTryAgainAction;

  /// No description provided for @fanClubSecurityTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Fan club security check timed out'**
  String get fanClubSecurityTimeoutTitle;

  /// No description provided for @fanClubSecurityTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'The approved club could not be confirmed safely. Try again.'**
  String get fanClubSecurityTimeoutMessage;

  /// No description provided for @fanClubLoadFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Unable to load fan club'**
  String get fanClubLoadFailureTitle;

  /// No description provided for @fanClubLoadFailureMessage.
  ///
  /// In en, this message translates to:
  /// **'The approved club could not be confirmed. Try again.'**
  String get fanClubLoadFailureMessage;

  /// No description provided for @fanClubShowingSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Showing saved fan club'**
  String get fanClubShowingSavedTitle;

  /// No description provided for @fanClubSavedDetailsMayChange.
  ///
  /// In en, this message translates to:
  /// **'Membership and matchday details may have changed.'**
  String get fanClubSavedDetailsMayChange;

  /// No description provided for @fanClubRefreshingTitle.
  ///
  /// In en, this message translates to:
  /// **'Refreshing fan club'**
  String get fanClubRefreshingTitle;

  /// No description provided for @fanClubLastConfirmedVisible.
  ///
  /// In en, this message translates to:
  /// **'The last confirmed club details remain visible.'**
  String get fanClubLastConfirmedVisible;

  /// No description provided for @fanClubLastConfirmedRefresh.
  ///
  /// In en, this message translates to:
  /// **'These are the last confirmed details. Refresh before continuing.'**
  String get fanClubLastConfirmedRefresh;

  /// No description provided for @fanClubCheckTimedOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Fan club check timed out'**
  String get fanClubCheckTimedOutTitle;

  /// No description provided for @fanClubAccessChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Fan club access changed'**
  String get fanClubAccessChangedTitle;

  /// No description provided for @fanClubAccessChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'The saved details are read-only. Return to Supporters.'**
  String get fanClubAccessChangedMessage;

  /// No description provided for @fanClubRefreshFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Fan club refresh failed'**
  String get fanClubRefreshFailedTitle;

  /// No description provided for @fanClubMatchdayAgenda.
  ///
  /// In en, this message translates to:
  /// **'MATCHDAY AGENDA'**
  String get fanClubMatchdayAgenda;

  /// No description provided for @fanClubMatchMeta.
  ///
  /// In en, this message translates to:
  /// **'{competition}  •  {venue}'**
  String fanClubMatchMeta(String competition, String venue);

  /// No description provided for @fanClubMatchSchedule.
  ///
  /// In en, this message translates to:
  /// **'{date}  •  {time}'**
  String fanClubMatchSchedule(String date, String time);

  /// No description provided for @fanClubMembersLabel.
  ///
  /// In en, this message translates to:
  /// **'MEMBERS'**
  String get fanClubMembersLabel;

  /// No description provided for @fanClubStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'STATUS'**
  String get fanClubStatusLabel;

  /// No description provided for @fanClubRegionLabel.
  ///
  /// In en, this message translates to:
  /// **'REGION'**
  String get fanClubRegionLabel;

  /// No description provided for @fanClubOpenSupportersSemantic.
  ///
  /// In en, this message translates to:
  /// **'Open Supporters area'**
  String get fanClubOpenSupportersSemantic;

  /// No description provided for @fanClubPendingReviewSemantic.
  ///
  /// In en, this message translates to:
  /// **'Fan club pending review'**
  String get fanClubPendingReviewSemantic;

  /// No description provided for @fanClubSupportersAction.
  ///
  /// In en, this message translates to:
  /// **'SUPPORTERS'**
  String get fanClubSupportersAction;

  /// No description provided for @fanClubOpenSupportersAction.
  ///
  /// In en, this message translates to:
  /// **'OPEN SUPPORTERS'**
  String get fanClubOpenSupportersAction;

  /// No description provided for @fanClubCopyLink.
  ///
  /// In en, this message translates to:
  /// **'COPY LINK'**
  String get fanClubCopyLink;

  /// No description provided for @fanClubCopyLinkSemantic.
  ///
  /// In en, this message translates to:
  /// **'Copy fan club link'**
  String get fanClubCopyLinkSemantic;

  /// No description provided for @fanClubShareFallback.
  ///
  /// In en, this message translates to:
  /// **'Open {appName} and visit the Fan Clubs section.'**
  String fanClubShareFallback(String appName);

  /// No description provided for @fanClubShareText.
  ///
  /// In en, this message translates to:
  /// **'Join this {appName} fan club: {target}'**
  String fanClubShareText(String appName, String target);

  /// No description provided for @fanClubLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Fan club link copied.'**
  String get fanClubLinkCopied;

  /// No description provided for @fanClubsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load fan clubs right now.'**
  String get fanClubsLoadError;

  /// No description provided for @fanClubReviewRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent for admin review. You are not joined until the club approves it.'**
  String get fanClubReviewRequestSent;

  /// No description provided for @fanClubsCommunityEyebrow.
  ///
  /// In en, this message translates to:
  /// **'THE COMMUNITY'**
  String get fanClubsCommunityEyebrow;

  /// No description provided for @fanClubsTitle.
  ///
  /// In en, this message translates to:
  /// **'FAN CLUBS'**
  String get fanClubsTitle;

  /// No description provided for @fanClubsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search clubs or locations'**
  String get fanClubsSearchHint;

  /// No description provided for @fanClubsFeaturedChapter.
  ///
  /// In en, this message translates to:
  /// **'FEATURED CHAPTER'**
  String get fanClubsFeaturedChapter;

  /// No description provided for @fanClubOfficialChapterFallback.
  ///
  /// In en, this message translates to:
  /// **'Official supporter chapter.'**
  String get fanClubOfficialChapterFallback;

  /// No description provided for @fanClubMembersValue.
  ///
  /// In en, this message translates to:
  /// **'{members} members'**
  String fanClubMembersValue(String members);

  /// No description provided for @fanClubRegionMembers.
  ///
  /// In en, this message translates to:
  /// **'{region} • {members}'**
  String fanClubRegionMembers(String region, String members);

  /// No description provided for @fanClubReviewRequested.
  ///
  /// In en, this message translates to:
  /// **'Review requested'**
  String get fanClubReviewRequested;

  /// No description provided for @fanClubRequestReview.
  ///
  /// In en, this message translates to:
  /// **'Request review'**
  String get fanClubRequestReview;

  /// No description provided for @fanClubDetailsAction.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get fanClubDetailsAction;
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
