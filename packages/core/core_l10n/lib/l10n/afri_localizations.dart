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

  /// No description provided for @liveMatchLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the live match center right now.'**
  String get liveMatchLoadError;

  /// No description provided for @liveStatusLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get liveStatusLive;

  /// No description provided for @liveStatusHalfTime.
  ///
  /// In en, this message translates to:
  /// **'HALF-TIME'**
  String get liveStatusHalfTime;

  /// No description provided for @liveStatusFullTime.
  ///
  /// In en, this message translates to:
  /// **'FULL-TIME'**
  String get liveStatusFullTime;

  /// No description provided for @liveStatusPostponed.
  ///
  /// In en, this message translates to:
  /// **'POSTPONED'**
  String get liveStatusPostponed;

  /// No description provided for @liveStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'CANCELLED'**
  String get liveStatusCancelled;

  /// No description provided for @liveStatusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'UPCOMING'**
  String get liveStatusUpcoming;

  /// No description provided for @liveStatusFinal.
  ///
  /// In en, this message translates to:
  /// **'FINAL'**
  String get liveStatusFinal;

  /// No description provided for @liveTimeVenue.
  ///
  /// In en, this message translates to:
  /// **'{time}  •  {venue}'**
  String liveTimeVenue(String time, String venue);

  /// No description provided for @liveMatchUpdate.
  ///
  /// In en, this message translates to:
  /// **'Match update'**
  String get liveMatchUpdate;

  /// No description provided for @liveMatchTeamsUpper.
  ///
  /// In en, this message translates to:
  /// **'{home} VS {away}'**
  String liveMatchTeamsUpper(String home, String away);

  /// No description provided for @liveModeActive.
  ///
  /// In en, this message translates to:
  /// **'Live mode active. Events appear in real time.'**
  String get liveModeActive;

  /// No description provided for @liveMatchReport.
  ///
  /// In en, this message translates to:
  /// **'MATCH REPORT'**
  String get liveMatchReport;

  /// No description provided for @liveMatchFinishedPending.
  ///
  /// In en, this message translates to:
  /// **'Match finished. Summary pending.'**
  String get liveMatchFinishedPending;

  /// No description provided for @liveMatchdayIntel.
  ///
  /// In en, this message translates to:
  /// **'MATCHDAY INTEL'**
  String get liveMatchdayIntel;

  /// No description provided for @liveFixturePublished.
  ///
  /// In en, this message translates to:
  /// **'Fixture published. Live updates start near kickoff.'**
  String get liveFixturePublished;

  /// No description provided for @liveStatPossession.
  ///
  /// In en, this message translates to:
  /// **'Possession'**
  String get liveStatPossession;

  /// No description provided for @liveStatShots.
  ///
  /// In en, this message translates to:
  /// **'Shots'**
  String get liveStatShots;

  /// No description provided for @liveStatCorners.
  ///
  /// In en, this message translates to:
  /// **'Corners'**
  String get liveStatCorners;

  /// No description provided for @liveStatPending.
  ///
  /// In en, this message translates to:
  /// **'TBD'**
  String get liveStatPending;

  /// No description provided for @liveMatchCenter.
  ///
  /// In en, this message translates to:
  /// **'Match Center'**
  String get liveMatchCenter;

  /// No description provided for @liveMyPredictions.
  ///
  /// In en, this message translates to:
  /// **'My Predictions'**
  String get liveMyPredictions;

  /// No description provided for @liveScore.
  ///
  /// In en, this message translates to:
  /// **'{homeScore} - {awayScore}'**
  String liveScore(int homeScore, int awayScore);

  /// No description provided for @liveMatchIntel.
  ///
  /// In en, this message translates to:
  /// **'Match Intel'**
  String get liveMatchIntel;

  /// No description provided for @liveBrowsePredictions.
  ///
  /// In en, this message translates to:
  /// **'Browse predictions'**
  String get liveBrowsePredictions;

  /// No description provided for @liveShareMatch.
  ///
  /// In en, this message translates to:
  /// **'Share match'**
  String get liveShareMatch;

  /// No description provided for @liveShareText.
  ///
  /// In en, this message translates to:
  /// **'{appName}: {homeTeam} {homeScore}-{awayScore} {awayTeam} ({status})'**
  String liveShareText(
    String appName,
    String homeTeam,
    int homeScore,
    int awayScore,
    String awayTeam,
    String status,
  );

  /// No description provided for @liveMatchCopied.
  ///
  /// In en, this message translates to:
  /// **'Match update copied to clipboard.'**
  String get liveMatchCopied;

  /// No description provided for @liveCenterUnavailable.
  ///
  /// In en, this message translates to:
  /// **'LIVE CENTER UNAVAILABLE'**
  String get liveCenterUnavailable;

  /// No description provided for @liveRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get liveRefresh;

  /// No description provided for @newsArticleNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Article not found'**
  String get newsArticleNotFoundTitle;

  /// No description provided for @newsArticleNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'This story may have been removed or is no longer available.'**
  String get newsArticleNotFoundMessage;

  /// No description provided for @newsBackToLiveMatch.
  ///
  /// In en, this message translates to:
  /// **'Back to live match'**
  String get newsBackToLiveMatch;

  /// No description provided for @newsClubNews.
  ///
  /// In en, this message translates to:
  /// **'Club news'**
  String get newsClubNews;

  /// No description provided for @newsArticleImageSemantic.
  ///
  /// In en, this message translates to:
  /// **'{title} article image'**
  String newsArticleImageSemantic(String title);

  /// No description provided for @newsRefreshingTitle.
  ///
  /// In en, this message translates to:
  /// **'Refreshing article'**
  String get newsRefreshingTitle;

  /// No description provided for @newsRefreshingMessage.
  ///
  /// In en, this message translates to:
  /// **'Keeping the confirmed story visible while the latest version is checked.'**
  String get newsRefreshingMessage;

  /// No description provided for @newsRelatedUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Related stories unavailable'**
  String get newsRelatedUnavailableTitle;

  /// No description provided for @newsRelatedUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'You can read this article, but related-story navigation is disabled for this build.'**
  String get newsRelatedUnavailableMessage;

  /// No description provided for @newsShowingSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Showing saved article'**
  String get newsShowingSavedTitle;

  /// No description provided for @newsShowingSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect and refresh before opening another story.'**
  String get newsShowingSavedMessage;

  /// No description provided for @newsSelectedSemantic.
  ///
  /// In en, this message translates to:
  /// **'Selected article {title}'**
  String newsSelectedSemantic(String title);

  /// No description provided for @newsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get newsToday;

  /// No description provided for @newsMetadata.
  ///
  /// In en, this message translates to:
  /// **'Club News  ·  {date}  ·  Media Desk'**
  String newsMetadata(String date);

  /// No description provided for @newsRelatedIntel.
  ///
  /// In en, this message translates to:
  /// **'Related intel'**
  String get newsRelatedIntel;

  /// No description provided for @newsRefreshArticle.
  ///
  /// In en, this message translates to:
  /// **'REFRESH ARTICLE'**
  String get newsRefreshArticle;

  /// No description provided for @newsConnectionRestored.
  ///
  /// In en, this message translates to:
  /// **'Connection restored'**
  String get newsConnectionRestored;

  /// No description provided for @newsArticleOffline.
  ///
  /// In en, this message translates to:
  /// **'Article offline'**
  String get newsArticleOffline;

  /// No description provided for @newsRefreshLatest.
  ///
  /// In en, this message translates to:
  /// **'Refresh to confirm the latest story.'**
  String get newsRefreshLatest;

  /// No description provided for @newsReconnectLatest.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to load the latest story.'**
  String get newsReconnectLatest;

  /// No description provided for @newsAccessUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Article access unavailable'**
  String get newsAccessUnavailableTitle;

  /// No description provided for @newsAccessUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Your current account cannot review this story.'**
  String get newsAccessUnavailableMessage;

  /// No description provided for @newsChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Article changed'**
  String get newsChangedTitle;

  /// No description provided for @newsChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh before opening another story.'**
  String get newsChangedMessage;

  /// No description provided for @newsSecurityTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Article security check timed out'**
  String get newsSecurityTimeoutTitle;

  /// No description provided for @newsSecurityTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'No updated story was confirmed. Refresh to try again.'**
  String get newsSecurityTimeoutMessage;

  /// No description provided for @newsUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Article unavailable'**
  String get newsUnavailableTitle;

  /// No description provided for @newsUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'The latest story could not be confirmed. Refresh to try again.'**
  String get newsUnavailableMessage;

  /// No description provided for @liveTeamLogoSemantic.
  ///
  /// In en, this message translates to:
  /// **'{label} team logo'**
  String liveTeamLogoSemantic(String label);

  /// No description provided for @liveTeamFallback.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get liveTeamFallback;

  /// No description provided for @liveMatchEventSemantic.
  ///
  /// In en, this message translates to:
  /// **'Match event: {event}'**
  String liveMatchEventSemantic(String event);

  /// No description provided for @liveEventGoal.
  ///
  /// In en, this message translates to:
  /// **'goal'**
  String get liveEventGoal;

  /// No description provided for @liveEventCard.
  ///
  /// In en, this message translates to:
  /// **'card'**
  String get liveEventCard;

  /// No description provided for @liveEventSubstitution.
  ///
  /// In en, this message translates to:
  /// **'substitution'**
  String get liveEventSubstitution;

  /// No description provided for @liveEventVarReview.
  ///
  /// In en, this message translates to:
  /// **'VAR review'**
  String get liveEventVarReview;

  /// No description provided for @liveEventUpdate.
  ///
  /// In en, this message translates to:
  /// **'update'**
  String get liveEventUpdate;

  /// No description provided for @liveStatSemantic.
  ///
  /// In en, this message translates to:
  /// **'{label} {value}'**
  String liveStatSemantic(String label, String value);

  /// No description provided for @shopAllCategory.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get shopAllCategory;

  /// No description provided for @shopProductFallback.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get shopProductFallback;

  /// No description provided for @shopProductAdded.
  ///
  /// In en, this message translates to:
  /// **'{name} added to cart.'**
  String shopProductAdded(String name);

  /// No description provided for @shopStoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get shopStoreTitle;

  /// No description provided for @shopTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shopTitle;

  /// No description provided for @shopSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get shopSearch;

  /// No description provided for @shopSearchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search products'**
  String get shopSearchProducts;

  /// No description provided for @shopViewCart.
  ///
  /// In en, this message translates to:
  /// **'View cart'**
  String get shopViewCart;

  /// No description provided for @shopCart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get shopCart;

  /// No description provided for @shopBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get shopBack;

  /// No description provided for @shopNoProductsTitle.
  ///
  /// In en, this message translates to:
  /// **'No products available'**
  String get shopNoProductsTitle;

  /// No description provided for @shopNoProductsCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'No products in {category}'**
  String shopNoProductsCategoryTitle(String category);

  /// No description provided for @shopNoProductsMessage.
  ///
  /// In en, this message translates to:
  /// **'Official merchandise will appear here when the club publishes store inventory.'**
  String get shopNoProductsMessage;

  /// No description provided for @shopNoProductsCategoryMessage.
  ///
  /// In en, this message translates to:
  /// **'Try another category or clear the filter to see the full store.'**
  String get shopNoProductsCategoryMessage;

  /// No description provided for @shopRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get shopRetry;

  /// No description provided for @shopRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get shopRefresh;

  /// No description provided for @shopShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get shopShowAll;

  /// No description provided for @shopRefreshingTitle.
  ///
  /// In en, this message translates to:
  /// **'Refreshing store'**
  String get shopRefreshingTitle;

  /// No description provided for @shopRefreshingMessage.
  ///
  /// In en, this message translates to:
  /// **'Current inventory is being checked.'**
  String get shopRefreshingMessage;

  /// No description provided for @shopSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved store content'**
  String get shopSavedTitle;

  /// No description provided for @shopSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Inventory may be out of date. Reconnect to refresh before checkout.'**
  String get shopSavedMessage;

  /// No description provided for @shopRefreshingSemantic.
  ///
  /// In en, this message translates to:
  /// **'Information status: Refreshing store. Current inventory is being checked.'**
  String get shopRefreshingSemantic;

  /// No description provided for @shopSavedSemantic.
  ///
  /// In en, this message translates to:
  /// **'Warning status: Saved store content. Inventory may be out of date. Reconnect to refresh before checkout.'**
  String get shopSavedSemantic;

  /// No description provided for @shopClubStore.
  ///
  /// In en, this message translates to:
  /// **'Club store'**
  String get shopClubStore;

  /// No description provided for @shopItemsAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count} items available now.'**
  String shopItemsAvailable(int count);

  /// No description provided for @shopOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Store offline'**
  String get shopOfflineTitle;

  /// No description provided for @shopOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Connect to load current club merchandise.'**
  String get shopOfflineMessage;

  /// No description provided for @shopAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Store access not available'**
  String get shopAccessTitle;

  /// No description provided for @shopAccessMessage.
  ///
  /// In en, this message translates to:
  /// **'This account cannot load club merchandise. Contact club support if access should be available.'**
  String get shopAccessMessage;

  /// No description provided for @shopInventoryChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Store inventory changed'**
  String get shopInventoryChangedTitle;

  /// No description provided for @shopInventoryChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Product availability changed while loading. Refresh before adding merchandise.'**
  String get shopInventoryChangedMessage;

  /// No description provided for @shopSecurityTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Store security check timed out'**
  String get shopSecurityTimeoutTitle;

  /// No description provided for @shopSecurityTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'The secure inventory check took too long. Refresh to try the check again.'**
  String get shopSecurityTimeoutMessage;

  /// No description provided for @shopUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Store unavailable'**
  String get shopUnavailableTitle;

  /// No description provided for @shopUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not load merchandise right now.'**
  String get shopUnavailableMessage;

  /// No description provided for @shopOutOfStockUpper.
  ///
  /// In en, this message translates to:
  /// **'OUT OF STOCK'**
  String get shopOutOfStockUpper;

  /// No description provided for @shopOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get shopOutOfStock;

  /// No description provided for @shopAddToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to cart'**
  String get shopAddToCart;

  /// No description provided for @shopProductImageSemantic.
  ///
  /// In en, this message translates to:
  /// **'{name} product image'**
  String shopProductImageSemantic(String name);

  /// No description provided for @shopProductUnavailableSemantic.
  ///
  /// In en, this message translates to:
  /// **'{name}, currently out of stock'**
  String shopProductUnavailableSemantic(String name);

  /// No description provided for @shopOpenProduct.
  ///
  /// In en, this message translates to:
  /// **'Open product'**
  String get shopOpenProduct;

  /// No description provided for @shopSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search kits, scarves, and drops'**
  String get shopSearchHint;

  /// No description provided for @shopMerchFallback.
  ///
  /// In en, this message translates to:
  /// **'Merch'**
  String get shopMerchFallback;

  /// No description provided for @shopQuantityValue.
  ///
  /// In en, this message translates to:
  /// **'Qty {quantity}'**
  String shopQuantityValue(int quantity);

  /// No description provided for @shopDecreaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Decrease quantity'**
  String get shopDecreaseQuantity;

  /// No description provided for @shopIncreaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Increase quantity'**
  String get shopIncreaseQuantity;

  /// No description provided for @shopRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get shopRemove;

  /// No description provided for @shopReadyToCheckout.
  ///
  /// In en, this message translates to:
  /// **'Ready to checkout'**
  String get shopReadyToCheckout;

  /// No description provided for @shopCheckout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get shopCheckout;

  /// No description provided for @shopItemOutOfStockToast.
  ///
  /// In en, this message translates to:
  /// **'This item is currently out of stock.'**
  String get shopItemOutOfStockToast;

  /// No description provided for @shopSelectSizeToast.
  ///
  /// In en, this message translates to:
  /// **'Select a size before adding to cart.'**
  String get shopSelectSizeToast;

  /// No description provided for @shopViewCartAction.
  ///
  /// In en, this message translates to:
  /// **'View Cart'**
  String get shopViewCartAction;

  /// No description provided for @shopProductNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Product not found'**
  String get shopProductNotFoundTitle;

  /// No description provided for @shopProductNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'This item is no longer available in the current club store.'**
  String get shopProductNotFoundMessage;

  /// No description provided for @shopBackToStore.
  ///
  /// In en, this message translates to:
  /// **'Back to store'**
  String get shopBackToStore;

  /// No description provided for @shopProductOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Product details offline'**
  String get shopProductOfflineTitle;

  /// No description provided for @shopProductOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to check the latest price, size, and availability.'**
  String get shopProductOfflineMessage;

  /// No description provided for @shopProductAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Product access not available'**
  String get shopProductAccessTitle;

  /// No description provided for @shopProductAccessMessage.
  ///
  /// In en, this message translates to:
  /// **'This product cannot be opened with the current account.'**
  String get shopProductAccessMessage;

  /// No description provided for @shopProductChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Product details changed'**
  String get shopProductChangedTitle;

  /// No description provided for @shopProductChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh to load the current price, sizes, and availability.'**
  String get shopProductChangedMessage;

  /// No description provided for @shopProductSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Product security check timed out'**
  String get shopProductSecurityTitle;

  /// No description provided for @shopProductSecurityMessage.
  ///
  /// In en, this message translates to:
  /// **'The secure product check took too long. Refresh before buying.'**
  String get shopProductSecurityMessage;

  /// No description provided for @shopProductUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Product unavailable'**
  String get shopProductUnavailableTitle;

  /// No description provided for @shopProductUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'The latest product details could not be loaded.'**
  String get shopProductUnavailableMessage;

  /// No description provided for @shopLoadingProductName.
  ///
  /// In en, this message translates to:
  /// **'Official Jersey Loading'**
  String get shopLoadingProductName;

  /// No description provided for @shopLoadingProductDescription.
  ///
  /// In en, this message translates to:
  /// **'Loading official merchandise details from the armoury...'**
  String get shopLoadingProductDescription;

  /// No description provided for @shopLoadingBadge.
  ///
  /// In en, this message translates to:
  /// **'LOADING'**
  String get shopLoadingBadge;

  /// No description provided for @shopOfficialMerchandise.
  ///
  /// In en, this message translates to:
  /// **'Official club merchandise.'**
  String get shopOfficialMerchandise;

  /// No description provided for @shopCloseProductDetails.
  ///
  /// In en, this message translates to:
  /// **'Close product details'**
  String get shopCloseProductDetails;

  /// No description provided for @shopRefreshingProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Refreshing product details'**
  String get shopRefreshingProductTitle;

  /// No description provided for @shopRefreshingProductMessage.
  ///
  /// In en, this message translates to:
  /// **'Current price, sizes, and availability are being checked.'**
  String get shopRefreshingProductMessage;

  /// No description provided for @shopSavedProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved product details'**
  String get shopSavedProductTitle;

  /// No description provided for @shopSavedProductMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to refresh price, sizes, and availability before buying.'**
  String get shopSavedProductMessage;

  /// No description provided for @shopInStock.
  ///
  /// In en, this message translates to:
  /// **'Available now'**
  String get shopInStock;

  /// No description provided for @shopStockAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count} available now'**
  String shopStockAvailable(int count);

  /// No description provided for @shopSelectSize.
  ///
  /// In en, this message translates to:
  /// **'Select size'**
  String get shopSelectSize;

  /// No description provided for @shopSizeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Size {size}'**
  String shopSizeTooltip(String size);

  /// No description provided for @shopSizeSelectedHint.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get shopSizeSelectedHint;

  /// No description provided for @shopSizeAvailableHint.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get shopSizeAvailableHint;

  /// No description provided for @shopQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get shopQuantity;

  /// No description provided for @shopTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get shopTotal;

  /// No description provided for @shopBuyNow.
  ///
  /// In en, this message translates to:
  /// **'Buy now'**
  String get shopBuyNow;

  /// No description provided for @shopConnectPaymentAvailability.
  ///
  /// In en, this message translates to:
  /// **'Connect to verify current payment availability.'**
  String get shopConnectPaymentAvailability;

  /// No description provided for @shopPaymentSetupPending.
  ///
  /// In en, this message translates to:
  /// **'Checkout payment setup is pending club activation.'**
  String get shopPaymentSetupPending;

  /// No description provided for @shopPaymentCheckError.
  ///
  /// In en, this message translates to:
  /// **'Payment availability could not be checked. Your cart and address are still here.'**
  String get shopPaymentCheckError;

  /// No description provided for @shopConnectBeforeCheckout.
  ///
  /// In en, this message translates to:
  /// **'Connect before checking out. Your cart and address are still here.'**
  String get shopConnectBeforeCheckout;

  /// No description provided for @shopAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a delivery address first.'**
  String get shopAddressRequired;

  /// No description provided for @shopMomoSetupPending.
  ///
  /// In en, this message translates to:
  /// **'MOMO checkout setup is pending club activation.'**
  String get shopMomoSetupPending;

  /// No description provided for @shopOrderDialerFailure.
  ///
  /// In en, this message translates to:
  /// **'Order {orderId} was saved, but the MOMO dialer could not open.'**
  String shopOrderDialerFailure(String orderId);

  /// No description provided for @shopOrderCreated.
  ///
  /// In en, this message translates to:
  /// **'Order {orderId} created. Payment verification is still pending.'**
  String shopOrderCreated(String orderId);

  /// No description provided for @shopReviewOrder.
  ///
  /// In en, this message translates to:
  /// **'Review order'**
  String get shopReviewOrder;

  /// No description provided for @shopItemQuantitySummary.
  ///
  /// In en, this message translates to:
  /// **'{name} x{quantity}'**
  String shopItemQuantitySummary(String name, int quantity);

  /// No description provided for @shopMoreItems.
  ///
  /// In en, this message translates to:
  /// **'+{count} more items'**
  String shopMoreItems(int count);

  /// No description provided for @shopDeliverTo.
  ///
  /// In en, this message translates to:
  /// **'Deliver to'**
  String get shopDeliverTo;

  /// No description provided for @shopPaymentInstructions.
  ///
  /// In en, this message translates to:
  /// **'Approve the MOMO prompt on your device, then confirm here. Orders remain pending until verification is complete.'**
  String get shopPaymentInstructions;

  /// No description provided for @shopPaymentSubmitted.
  ///
  /// In en, this message translates to:
  /// **'I submitted the payment'**
  String get shopPaymentSubmitted;

  /// No description provided for @shopCartEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Cart is empty'**
  String get shopCartEmptyTitle;

  /// No description provided for @shopCartEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add items from the shop to start checkout.'**
  String get shopCartEmptyMessage;

  /// No description provided for @shopBackToShop.
  ///
  /// In en, this message translates to:
  /// **'Back to shop'**
  String get shopBackToShop;

  /// No description provided for @shopDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get shopDelivery;

  /// No description provided for @shopAddressAndTotal.
  ///
  /// In en, this message translates to:
  /// **'Address and total'**
  String get shopAddressAndTotal;

  /// No description provided for @shopDeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery address'**
  String get shopDeliveryAddress;

  /// No description provided for @shopEnterDeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter your delivery address'**
  String get shopEnterDeliveryAddress;

  /// No description provided for @shopStreetCityCountry.
  ///
  /// In en, this message translates to:
  /// **'Street, city, {country}'**
  String shopStreetCityCountry(String country);

  /// No description provided for @shopSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get shopSubtotal;

  /// No description provided for @shopCheckingPayment.
  ///
  /// In en, this message translates to:
  /// **'Checking payment'**
  String get shopCheckingPayment;

  /// No description provided for @shopCheckingPaymentMessage.
  ///
  /// In en, this message translates to:
  /// **'Confirming the current MOMO route for this club.'**
  String get shopCheckingPaymentMessage;

  /// No description provided for @shopPaymentCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment check failed'**
  String get shopPaymentCheckFailed;

  /// No description provided for @shopCheckoutUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Checkout unavailable'**
  String get shopCheckoutUnavailable;

  /// No description provided for @shopPayTo.
  ///
  /// In en, this message translates to:
  /// **'Pay to {label}'**
  String shopPayTo(String label);

  /// No description provided for @shopReviewCart.
  ///
  /// In en, this message translates to:
  /// **'Review cart'**
  String get shopReviewCart;

  /// No description provided for @shopConnectionRequired.
  ///
  /// In en, this message translates to:
  /// **'Connection required'**
  String get shopConnectionRequired;

  /// No description provided for @shopPaymentRouteNotReady.
  ///
  /// In en, this message translates to:
  /// **'Payment route not ready'**
  String get shopPaymentRouteNotReady;

  /// No description provided for @shopCheckoutNotPermitted.
  ///
  /// In en, this message translates to:
  /// **'Checkout not permitted'**
  String get shopCheckoutNotPermitted;

  /// No description provided for @shopStatusUncertain.
  ///
  /// In en, this message translates to:
  /// **'Status uncertain'**
  String get shopStatusUncertain;

  /// No description provided for @shopProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get shopProcessing;

  /// No description provided for @shopPayWithMomo.
  ///
  /// In en, this message translates to:
  /// **'Pay with MOMO'**
  String get shopPayWithMomo;

  /// No description provided for @shopCheckoutViaMomo.
  ///
  /// In en, this message translates to:
  /// **'Checkout via MOMO'**
  String get shopCheckoutViaMomo;

  /// No description provided for @shopOrderUncertainTitle.
  ///
  /// In en, this message translates to:
  /// **'Order status is uncertain'**
  String get shopOrderUncertainTitle;

  /// No description provided for @shopOrderUncertainMessage.
  ///
  /// In en, this message translates to:
  /// **'The secure checkout timed out. Your cart and address are still here. Do not submit again until club support confirms whether the order was saved.'**
  String get shopOrderUncertainMessage;

  /// No description provided for @shopOrderChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Order details changed'**
  String get shopOrderChangedTitle;

  /// No description provided for @shopOrderChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'The order changed while it was being submitted. Your cart and address are still here. Review them before trying again.'**
  String get shopOrderChangedMessage;

  /// No description provided for @shopCheckoutDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account cannot place this order. Your cart and address are still here. Contact club support before trying again.'**
  String get shopCheckoutDeniedMessage;

  /// No description provided for @shopCheckoutFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Checkout could not start'**
  String get shopCheckoutFailureTitle;

  /// No description provided for @shopCheckoutFailureMessage.
  ///
  /// In en, this message translates to:
  /// **'No order was confirmed. Your cart and address are still here. Review them and try again.'**
  String get shopCheckoutFailureMessage;

  /// No description provided for @shopSampleProductName.
  ///
  /// In en, this message translates to:
  /// **'Rayon Home Jersey'**
  String get shopSampleProductName;

  /// No description provided for @shopSampleProductDescription.
  ///
  /// In en, this message translates to:
  /// **'Official matchday jersey with a premium woven club mark, breathable stadium fabric, and club-blue trim for everyday supporters.'**
  String get shopSampleProductDescription;

  /// No description provided for @shopOfficialBadge.
  ///
  /// In en, this message translates to:
  /// **'OFFICIAL'**
  String get shopOfficialBadge;

  /// No description provided for @shopSampleProductSummary.
  ///
  /// In en, this message translates to:
  /// **'Official kit · S M L XL · 47 available'**
  String get shopSampleProductSummary;

  /// No description provided for @shopProductImageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Product image unavailable'**
  String get shopProductImageUnavailable;

  /// No description provided for @shopOfficialKit.
  ///
  /// In en, this message translates to:
  /// **'Official Rayon kit'**
  String get shopOfficialKit;

  /// No description provided for @shopPremiumMerchandise.
  ///
  /// In en, this message translates to:
  /// **'Premium matchday merchandise'**
  String get shopPremiumMerchandise;

  /// No description provided for @ticketQrAccessUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'E-ticket access unavailable'**
  String get ticketQrAccessUnavailableTitle;

  /// No description provided for @ticketQrAccessUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Entry codes are disabled for this build. Return to your ticket wallet for status updates.'**
  String get ticketQrAccessUnavailableMessage;

  /// No description provided for @ticketNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Ticket not found'**
  String get ticketNotFoundTitle;

  /// No description provided for @ticketUnavailableShort.
  ///
  /// In en, this message translates to:
  /// **'E-ticket unavailable.'**
  String get ticketUnavailableShort;

  /// No description provided for @ticketPaymentPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment verification pending'**
  String get ticketPaymentPendingTitle;

  /// No description provided for @ticketPaymentPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'This ticket request was recorded, but the QR code will only unlock after payment verification completes.'**
  String get ticketPaymentPendingMessage;

  /// No description provided for @ticketEntryCode.
  ///
  /// In en, this message translates to:
  /// **'Ticket entry code'**
  String get ticketEntryCode;

  /// No description provided for @ticketScannerHelper.
  ///
  /// In en, this message translates to:
  /// **'Present only to an authorized matchday scanner.'**
  String get ticketScannerHelper;

  /// No description provided for @ticketDateLabel.
  ///
  /// In en, this message translates to:
  /// **'DATE'**
  String get ticketDateLabel;

  /// No description provided for @ticketTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'TIME'**
  String get ticketTimeLabel;

  /// No description provided for @ticketVenueLabel.
  ///
  /// In en, this message translates to:
  /// **'VENUE'**
  String get ticketVenueLabel;

  /// No description provided for @ticketAppleWallet.
  ///
  /// In en, this message translates to:
  /// **'Apple Wallet'**
  String get ticketAppleWallet;

  /// No description provided for @ticketGoogleWallet.
  ///
  /// In en, this message translates to:
  /// **'Google Wallet'**
  String get ticketGoogleWallet;

  /// No description provided for @ticketWalletExportUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Wallet export is not available in this release yet.'**
  String get ticketWalletExportUnavailable;

  /// No description provided for @ticketSelectedSemantic.
  ///
  /// In en, this message translates to:
  /// **'Selected e-ticket {match}'**
  String ticketSelectedSemantic(String match);

  /// No description provided for @ticketOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'E-ticket unavailable offline'**
  String get ticketOfflineTitle;

  /// No description provided for @ticketOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect before loading this entry code.'**
  String get ticketOfflineMessage;

  /// No description provided for @ticketAccessDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'E-ticket access denied'**
  String get ticketAccessDeniedTitle;

  /// No description provided for @ticketAccessDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'This ticket cannot be opened with the current account.'**
  String get ticketAccessDeniedMessage;

  /// No description provided for @ticketChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Ticket changed'**
  String get ticketChangedTitle;

  /// No description provided for @ticketChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh your wallet before presenting this entry code.'**
  String get ticketChangedMessage;

  /// No description provided for @ticketSecurityTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Ticket security check timed out'**
  String get ticketSecurityTimeoutTitle;

  /// No description provided for @ticketSecurityTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'The entry code was not confirmed. Refresh before match entry.'**
  String get ticketSecurityTimeoutMessage;

  /// No description provided for @ticketUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Ticket unavailable'**
  String get ticketUnavailableTitle;

  /// No description provided for @ticketUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This ticket could not be confirmed from your wallet.'**
  String get ticketUnavailableMessage;

  /// No description provided for @ticketRefreshAction.
  ///
  /// In en, this message translates to:
  /// **'Refresh ticket'**
  String get ticketRefreshAction;

  /// No description provided for @ticketSavedCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Showing saved entry code'**
  String get ticketSavedCodeTitle;

  /// No description provided for @ticketRefreshingTitle.
  ///
  /// In en, this message translates to:
  /// **'Refreshing ticket'**
  String get ticketRefreshingTitle;

  /// No description provided for @ticketAccessChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Ticket access changed'**
  String get ticketAccessChangedTitle;

  /// No description provided for @ticketCheckTimedOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Ticket check timed out'**
  String get ticketCheckTimedOutTitle;

  /// No description provided for @ticketRefreshUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Ticket refresh unavailable'**
  String get ticketRefreshUnavailableTitle;

  /// No description provided for @ticketSavedCodeMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect and refresh before presenting this code at match entry.'**
  String get ticketSavedCodeMessage;

  /// No description provided for @ticketRefreshingMessage.
  ///
  /// In en, this message translates to:
  /// **'The last confirmed code remains visible while wallet status is checked.'**
  String get ticketRefreshingMessage;

  /// No description provided for @ticketRefreshBeforeUse.
  ///
  /// In en, this message translates to:
  /// **'Refresh before relying on this entry code.'**
  String get ticketRefreshBeforeUse;

  /// No description provided for @ticketRefreshUpper.
  ///
  /// In en, this message translates to:
  /// **'REFRESH TICKET'**
  String get ticketRefreshUpper;

  /// No description provided for @ticketWalletUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Ticket wallet unavailable'**
  String get ticketWalletUnavailableTitle;

  /// No description provided for @ticketWalletUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'We could not load your ticket wallet right now. Check your connection and try again.'**
  String get ticketWalletUnavailableMessage;

  /// No description provided for @ticketMyTickets.
  ///
  /// In en, this message translates to:
  /// **'MY TICKETS'**
  String get ticketMyTickets;

  /// No description provided for @ticketRefreshTickets.
  ///
  /// In en, this message translates to:
  /// **'Refresh tickets'**
  String get ticketRefreshTickets;

  /// No description provided for @ticketUpcoming.
  ///
  /// In en, this message translates to:
  /// **'UPCOMING'**
  String get ticketUpcoming;

  /// No description provided for @ticketPast.
  ///
  /// In en, this message translates to:
  /// **'PAST'**
  String get ticketPast;

  /// No description provided for @ticketBrowseMatches.
  ///
  /// In en, this message translates to:
  /// **'Browse matches'**
  String get ticketBrowseMatches;

  /// No description provided for @ticketOpenQr.
  ///
  /// In en, this message translates to:
  /// **'Open ticket QR code'**
  String get ticketOpenQr;

  /// No description provided for @ticketWalletSemantic.
  ///
  /// In en, this message translates to:
  /// **'{match}, {status} ticket, {seat}'**
  String ticketWalletSemantic(String match, String status, String seat);

  /// No description provided for @ticketSeatPrice.
  ///
  /// In en, this message translates to:
  /// **'{seat} • {price}'**
  String ticketSeatPrice(String seat, String price);

  /// No description provided for @ticketPendingQrMessage.
  ///
  /// In en, this message translates to:
  /// **'Payment received on your phone still needs verification before the QR unlocks.'**
  String get ticketPendingQrMessage;

  /// No description provided for @ticketCheckoutSummary.
  ///
  /// In en, this message translates to:
  /// **'CHECKOUT SUMMARY'**
  String get ticketCheckoutSummary;

  /// No description provided for @ticketMatchLabel.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get ticketMatchLabel;

  /// No description provided for @ticketSeatTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Seat type'**
  String get ticketSeatTypeLabel;

  /// No description provided for @ticketQuantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get ticketQuantityLabel;

  /// No description provided for @ticketSeatCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Seat code'**
  String get ticketSeatCodeLabel;

  /// No description provided for @ticketTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get ticketTotalLabel;

  /// No description provided for @ticketPaymentRouteLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment route'**
  String get ticketPaymentRouteLabel;

  /// No description provided for @ticketPayToDialer.
  ///
  /// In en, this message translates to:
  /// **'Pay to {label}\nDialer will open USSD prompt.'**
  String ticketPayToDialer(String label);

  /// No description provided for @ticketSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get ticketSoldOut;

  /// No description provided for @ticketPayViaMomo.
  ///
  /// In en, this message translates to:
  /// **'Pay via MOMO'**
  String get ticketPayViaMomo;

  /// No description provided for @ticketConfirmAfterMomo.
  ///
  /// In en, this message translates to:
  /// **'Confirm payment after completing the MOMO prompt.'**
  String get ticketConfirmAfterMomo;

  /// No description provided for @ticketConfirmPurchase.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM PURCHASE'**
  String get ticketConfirmPurchase;

  /// No description provided for @ticketMatchUpper.
  ///
  /// In en, this message translates to:
  /// **'MATCH'**
  String get ticketMatchUpper;

  /// No description provided for @ticketZoneUpper.
  ///
  /// In en, this message translates to:
  /// **'ZONE'**
  String get ticketZoneUpper;

  /// No description provided for @ticketSeatUpper.
  ///
  /// In en, this message translates to:
  /// **'SEAT'**
  String get ticketSeatUpper;

  /// No description provided for @ticketQuantityUpper.
  ///
  /// In en, this message translates to:
  /// **'QUANTITY'**
  String get ticketQuantityUpper;

  /// No description provided for @ticketServiceFeeUpper.
  ///
  /// In en, this message translates to:
  /// **'SERVICE FEE'**
  String get ticketServiceFeeUpper;

  /// No description provided for @ticketTotalUpper.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get ticketTotalUpper;

  /// No description provided for @ticketIncluded.
  ///
  /// In en, this message translates to:
  /// **'Included'**
  String get ticketIncluded;

  /// No description provided for @ticketMomoValue.
  ///
  /// In en, this message translates to:
  /// **'MOMO: {label}'**
  String ticketMomoValue(String label);

  /// No description provided for @ticketConfirmPaymentWarning.
  ///
  /// In en, this message translates to:
  /// **'Confirm only after completing the MoMo payment on your phone.'**
  String get ticketConfirmPaymentWarning;

  /// No description provided for @ticketCompletedPayment.
  ///
  /// In en, this message translates to:
  /// **'I completed payment'**
  String get ticketCompletedPayment;

  /// No description provided for @ticketDidNotPay.
  ///
  /// In en, this message translates to:
  /// **'I did not pay'**
  String get ticketDidNotPay;

  /// No description provided for @ticketMatchVersus.
  ///
  /// In en, this message translates to:
  /// **'{home} vs {away}'**
  String ticketMatchVersus(String home, String away);

  /// No description provided for @ticketCompetitionVenue.
  ///
  /// In en, this message translates to:
  /// **'{competition}  •  {venue}'**
  String ticketCompetitionVenue(String competition, String venue);

  /// No description provided for @ticketRemainingCapacity.
  ///
  /// In en, this message translates to:
  /// **'Remaining capacity: {count}'**
  String ticketRemainingCapacity(int count);

  /// No description provided for @ticketChooseAccess.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE ACCESS'**
  String get ticketChooseAccess;

  /// No description provided for @ticketGeneral.
  ///
  /// In en, this message translates to:
  /// **'GENERAL'**
  String get ticketGeneral;

  /// No description provided for @ticketGeneralSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open stands / Bleachers area'**
  String get ticketGeneralSubtitle;

  /// No description provided for @ticketVip.
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get ticketVip;

  /// No description provided for @ticketVipSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Premium lounge seating'**
  String get ticketVipSubtitle;

  /// No description provided for @ticketChooseSeat.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE SPECIFIC SEAT'**
  String get ticketChooseSeat;

  /// No description provided for @ticketChangeSeat.
  ///
  /// In en, this message translates to:
  /// **'CHANGE SELECTED SEAT'**
  String get ticketChangeSeat;

  /// No description provided for @ticketReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get ticketReview;

  /// No description provided for @ticketReviewReservation.
  ///
  /// In en, this message translates to:
  /// **'Review reservation'**
  String get ticketReviewReservation;

  /// No description provided for @ticketOfficialCategories.
  ///
  /// In en, this message translates to:
  /// **'OFFICIAL CATEGORIES'**
  String get ticketOfficialCategories;

  /// No description provided for @ticketOfficialCategoriesMessage.
  ///
  /// In en, this message translates to:
  /// **'Approved public ticket tiers. Sale-specific availability appears when the club activates an official sale.'**
  String get ticketOfficialCategoriesMessage;

  /// No description provided for @ticketListTitle.
  ///
  /// In en, this message translates to:
  /// **'TICKETS'**
  String get ticketListTitle;

  /// No description provided for @ticketFilterMatches.
  ///
  /// In en, this message translates to:
  /// **'Filter matches'**
  String get ticketFilterMatches;

  /// No description provided for @ticketMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'Match Filters'**
  String get ticketMatchFilters;

  /// No description provided for @ticketSortSoonest.
  ///
  /// In en, this message translates to:
  /// **'Soonest'**
  String get ticketSortSoonest;

  /// No description provided for @ticketSortLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get ticketSortLatest;

  /// No description provided for @ticketSortCheapest.
  ///
  /// In en, this message translates to:
  /// **'Cheapest'**
  String get ticketSortCheapest;

  /// No description provided for @ticketTypeAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get ticketTypeAvailable;

  /// No description provided for @ticketTypeSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold Out'**
  String get ticketTypeSoldOut;

  /// No description provided for @ticketTypeVipZones.
  ///
  /// In en, this message translates to:
  /// **'VIP Zones'**
  String get ticketTypeVipZones;

  /// No description provided for @ticketRefreshMatches.
  ///
  /// In en, this message translates to:
  /// **'Refresh matches'**
  String get ticketRefreshMatches;

  /// No description provided for @ticketRefreshMatchesOffline.
  ///
  /// In en, this message translates to:
  /// **'Connection required to refresh matches'**
  String get ticketRefreshMatchesOffline;

  /// No description provided for @ticketNext.
  ///
  /// In en, this message translates to:
  /// **'NEXT'**
  String get ticketNext;

  /// No description provided for @ticketMine.
  ///
  /// In en, this message translates to:
  /// **'MINE'**
  String get ticketMine;

  /// No description provided for @ticketUpcomingSemantic.
  ///
  /// In en, this message translates to:
  /// **'Upcoming tickets'**
  String get ticketUpcomingSemantic;

  /// No description provided for @ticketPastSemantic.
  ///
  /// In en, this message translates to:
  /// **'Past tickets'**
  String get ticketPastSemantic;

  /// No description provided for @ticketMineSemantic.
  ///
  /// In en, this message translates to:
  /// **'My tickets'**
  String get ticketMineSemantic;

  /// No description provided for @ticketRefreshingInventoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Refreshing ticket inventory'**
  String get ticketRefreshingInventoryTitle;

  /// No description provided for @ticketRefreshingInventoryMessage.
  ///
  /// In en, this message translates to:
  /// **'Current fixtures and availability are being checked.'**
  String get ticketRefreshingInventoryMessage;

  /// No description provided for @ticketSavedInventoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved ticket inventory'**
  String get ticketSavedInventoryTitle;

  /// No description provided for @ticketSavedInventoryMessage.
  ///
  /// In en, this message translates to:
  /// **'Availability may be out of date. Reconnect before purchasing.'**
  String get ticketSavedInventoryMessage;

  /// No description provided for @ticketNoUpcomingTitle.
  ///
  /// In en, this message translates to:
  /// **'No upcoming ticketed fixtures'**
  String get ticketNoUpcomingTitle;

  /// No description provided for @ticketNoUpcomingMessage.
  ///
  /// In en, this message translates to:
  /// **'Upcoming ticket inventory will appear here once the club publishes sales for the next fixture.'**
  String get ticketNoUpcomingMessage;

  /// No description provided for @ticketNoPastTitle.
  ///
  /// In en, this message translates to:
  /// **'No past ticketed fixtures'**
  String get ticketNoPastTitle;

  /// No description provided for @ticketNoPastMessage.
  ///
  /// In en, this message translates to:
  /// **'Past ticketed fixtures will appear here after matchday sales are completed.'**
  String get ticketNoPastMessage;

  /// No description provided for @ticketRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get ticketRefresh;

  /// No description provided for @ticketStatusSoldOut.
  ///
  /// In en, this message translates to:
  /// **'SOLD OUT'**
  String get ticketStatusSoldOut;

  /// No description provided for @ticketStatusAvailable.
  ///
  /// In en, this message translates to:
  /// **'AVAILABLE'**
  String get ticketStatusAvailable;

  /// No description provided for @ticketFrom.
  ///
  /// In en, this message translates to:
  /// **'FROM'**
  String get ticketFrom;

  /// No description provided for @ticketBuyAction.
  ///
  /// In en, this message translates to:
  /// **'Buy ticket'**
  String get ticketBuyAction;

  /// No description provided for @ticketSalesNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Sales not open'**
  String get ticketSalesNotOpen;

  /// No description provided for @ticketVersusUpper.
  ///
  /// In en, this message translates to:
  /// **'VS'**
  String get ticketVersusUpper;

  /// No description provided for @ticketListOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to view tickets'**
  String get ticketListOfflineTitle;

  /// No description provided for @ticketListOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to load current fixtures and ticket availability.'**
  String get ticketListOfflineMessage;

  /// No description provided for @ticketConnectionRequired.
  ///
  /// In en, this message translates to:
  /// **'Connection required'**
  String get ticketConnectionRequired;

  /// No description provided for @ticketListAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Ticket access not available'**
  String get ticketListAccessTitle;

  /// No description provided for @ticketListAccessMessage.
  ///
  /// In en, this message translates to:
  /// **'This account cannot load the club ticket inventory. Contact club support if access should be available.'**
  String get ticketListAccessMessage;

  /// No description provided for @ticketAccessRequired.
  ///
  /// In en, this message translates to:
  /// **'Access required'**
  String get ticketAccessRequired;

  /// No description provided for @ticketInventoryChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Ticket inventory changed'**
  String get ticketInventoryChangedTitle;

  /// No description provided for @ticketInventoryChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Fixture or availability details changed while loading. Refresh before choosing a ticket.'**
  String get ticketInventoryChangedMessage;

  /// No description provided for @ticketInventorySecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Ticket security check timed out'**
  String get ticketInventorySecurityTitle;

  /// No description provided for @ticketInventorySecurityMessage.
  ///
  /// In en, this message translates to:
  /// **'The secure inventory check took too long. Refresh to try the check again.'**
  String get ticketInventorySecurityMessage;

  /// No description provided for @ticketFixturesUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Unable to load fixtures'**
  String get ticketFixturesUnavailableTitle;

  /// No description provided for @ticketFixturesUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Ticket inventory is unavailable right now. Check your connection and try again.'**
  String get ticketFixturesUnavailableMessage;

  /// No description provided for @ticketRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get ticketRetry;

  /// No description provided for @ticketPaymentAvailabilityOffline.
  ///
  /// In en, this message translates to:
  /// **'Connect to verify current ticket payment availability.'**
  String get ticketPaymentAvailabilityOffline;

  /// No description provided for @ticketPaymentSetupPending.
  ///
  /// In en, this message translates to:
  /// **'Ticket payment setup is pending club activation.'**
  String get ticketPaymentSetupPending;

  /// No description provided for @ticketPaymentVerificationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Payment route verification is unavailable. Try again.'**
  String get ticketPaymentVerificationUnavailable;

  /// No description provided for @ticketConnectBeforePurchase.
  ///
  /// In en, this message translates to:
  /// **'Connect before purchasing. Your seat and quantity are still selected.'**
  String get ticketConnectBeforePurchase;

  /// No description provided for @ticketSignInBeforePurchase.
  ///
  /// In en, this message translates to:
  /// **'Sign in first to buy tickets.'**
  String get ticketSignInBeforePurchase;

  /// No description provided for @ticketMomoSetupPending.
  ///
  /// In en, this message translates to:
  /// **'MOMO ticketing setup is pending club activation.'**
  String get ticketMomoSetupPending;

  /// No description provided for @ticketReservationFailed.
  ///
  /// In en, this message translates to:
  /// **'Ticket reservation failed. Please try again from the match screen.'**
  String get ticketReservationFailed;

  /// No description provided for @ticketDialerOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Ticket request was saved, but the MOMO dialer could not open.'**
  String get ticketDialerOpenFailed;

  /// No description provided for @ticketRequestsSubmitted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Ticket request submitted — pending payment verification.} other{{count} ticket requests submitted — pending verification.}}'**
  String ticketRequestsSubmitted(int count);

  /// No description provided for @ticketConfirmationTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Ticket confirmation timed out. Check My Tickets before trying again.'**
  String get ticketConfirmationTimedOut;

  /// No description provided for @ticketRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Ticket request failed. Your selection is still available.'**
  String get ticketRequestFailed;

  /// No description provided for @ticketMatchDay.
  ///
  /// In en, this message translates to:
  /// **'MATCH DAY'**
  String get ticketMatchDay;

  /// No description provided for @ticketSalesUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Ticket sales unavailable'**
  String get ticketSalesUnavailableTitle;

  /// No description provided for @ticketSalesUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Ticket selection is not enabled for this build or club.'**
  String get ticketSalesUnavailableMessage;

  /// No description provided for @ticketBackToTickets.
  ///
  /// In en, this message translates to:
  /// **'Back to Tickets'**
  String get ticketBackToTickets;

  /// No description provided for @ticketFixtureNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Fixture not found'**
  String get ticketFixtureNotFoundTitle;

  /// No description provided for @ticketFixtureNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'This fixture is unavailable.'**
  String get ticketFixtureNotFoundMessage;

  /// No description provided for @ticketDetailOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Ticket details unavailable offline'**
  String get ticketDetailOfflineTitle;

  /// No description provided for @ticketDetailOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Connect to load this fixture and current ticket availability.'**
  String get ticketDetailOfflineMessage;

  /// No description provided for @ticketDetailAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Ticket access denied'**
  String get ticketDetailAccessTitle;

  /// No description provided for @ticketDetailAccessMessage.
  ///
  /// In en, this message translates to:
  /// **'This fixture is not available for the current club account.'**
  String get ticketDetailAccessMessage;

  /// No description provided for @ticketDetailSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Ticket security check timed out'**
  String get ticketDetailSecurityTitle;

  /// No description provided for @ticketDetailSecurityMessage.
  ///
  /// In en, this message translates to:
  /// **'The fixture could not be confirmed safely. Try again.'**
  String get ticketDetailSecurityMessage;

  /// No description provided for @ticketDetailChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Fixture details changed'**
  String get ticketDetailChangedTitle;

  /// No description provided for @ticketDetailChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh the fixture before selecting ticket access.'**
  String get ticketDetailChangedMessage;

  /// No description provided for @ticketDetailUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Unable to load this fixture'**
  String get ticketDetailUnavailableTitle;

  /// No description provided for @ticketDetailUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'The fixture could not be confirmed. Try again.'**
  String get ticketDetailUnavailableMessage;

  /// No description provided for @ticketTryAgainUpper.
  ///
  /// In en, this message translates to:
  /// **'TRY AGAIN'**
  String get ticketTryAgainUpper;

  /// No description provided for @ticketRefreshFixtureUpper.
  ///
  /// In en, this message translates to:
  /// **'REFRESH FIXTURE'**
  String get ticketRefreshFixtureUpper;

  /// No description provided for @ticketSavedFixtureTitle.
  ///
  /// In en, this message translates to:
  /// **'Showing saved fixture'**
  String get ticketSavedFixtureTitle;

  /// No description provided for @ticketSavedFixtureMessage.
  ///
  /// In en, this message translates to:
  /// **'Ticket prices may have changed. Reconnect before reviewing or purchasing.'**
  String get ticketSavedFixtureMessage;

  /// No description provided for @ticketRefreshingFixtureTitle.
  ///
  /// In en, this message translates to:
  /// **'Refreshing fixture'**
  String get ticketRefreshingFixtureTitle;

  /// No description provided for @ticketRefreshingFixtureMessage.
  ///
  /// In en, this message translates to:
  /// **'The last confirmed ticket options remain visible.'**
  String get ticketRefreshingFixtureMessage;

  /// No description provided for @ticketFixtureChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Fixture changed'**
  String get ticketFixtureChangedTitle;

  /// No description provided for @ticketLastConfirmedOptionsMessage.
  ///
  /// In en, this message translates to:
  /// **'These are the last confirmed options. Refresh before continuing.'**
  String get ticketLastConfirmedOptionsMessage;

  /// No description provided for @ticketFixtureCheckTimedOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Fixture check timed out'**
  String get ticketFixtureCheckTimedOutTitle;

  /// No description provided for @ticketSavedFixtureReadOnlyMessage.
  ///
  /// In en, this message translates to:
  /// **'The saved fixture is read-only. Return to Tickets to continue safely.'**
  String get ticketSavedFixtureReadOnlyMessage;

  /// No description provided for @ticketFixtureRefreshFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Fixture refresh failed'**
  String get ticketFixtureRefreshFailedTitle;

  /// No description provided for @ticketSeatMapTitle.
  ///
  /// In en, this message translates to:
  /// **'SELECT SEAT'**
  String get ticketSeatMapTitle;

  /// No description provided for @ticketConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get ticketConfirm;

  /// No description provided for @ticketSeatSelectionUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Seat selection unavailable'**
  String get ticketSeatSelectionUnavailableTitle;

  /// No description provided for @ticketSeatSelectionUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Seat selection is not enabled for this build or club.'**
  String get ticketSeatSelectionUnavailableMessage;

  /// No description provided for @ticketBackToTicketUpper.
  ///
  /// In en, this message translates to:
  /// **'BACK TO TICKET'**
  String get ticketBackToTicketUpper;

  /// No description provided for @ticketSeatMapUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Seat map unavailable'**
  String get ticketSeatMapUnavailableTitle;

  /// No description provided for @ticketSeatMapUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This fixture could not be found.'**
  String get ticketSeatMapUnavailableMessage;

  /// No description provided for @ticketSeatMapOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Seat map unavailable offline'**
  String get ticketSeatMapOfflineTitle;

  /// No description provided for @ticketSeatMapOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Connect to confirm current seat availability.'**
  String get ticketSeatMapOfflineMessage;

  /// No description provided for @ticketSeatMapAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Seat map access denied'**
  String get ticketSeatMapAccessTitle;

  /// No description provided for @ticketSeatMapAccessMessage.
  ///
  /// In en, this message translates to:
  /// **'This fixture is not available for the current club account.'**
  String get ticketSeatMapAccessMessage;

  /// No description provided for @ticketSeatMapSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Seat map security check timed out'**
  String get ticketSeatMapSecurityTitle;

  /// No description provided for @ticketSeatMapSecurityMessage.
  ///
  /// In en, this message translates to:
  /// **'The fixture could not be confirmed safely. Try again.'**
  String get ticketSeatMapSecurityMessage;

  /// No description provided for @ticketSeatMapChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Seat map changed'**
  String get ticketSeatMapChangedTitle;

  /// No description provided for @ticketSeatMapChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh the fixture before selecting a seat.'**
  String get ticketSeatMapChangedMessage;

  /// No description provided for @ticketRefreshSeatMapUpper.
  ///
  /// In en, this message translates to:
  /// **'REFRESH SEAT MAP'**
  String get ticketRefreshSeatMapUpper;

  /// No description provided for @ticketSeatMapLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unable to load seat map'**
  String get ticketSeatMapLoadFailedTitle;

  /// No description provided for @ticketSeatMapLoadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'The fixture could not be confirmed. Try again.'**
  String get ticketSeatMapLoadFailedMessage;

  /// No description provided for @ticketSavedSeatMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Showing saved seat map'**
  String get ticketSavedSeatMapTitle;

  /// No description provided for @ticketSavedSeatMapMessage.
  ///
  /// In en, this message translates to:
  /// **'Seat availability may have changed. Reconnect before confirming.'**
  String get ticketSavedSeatMapMessage;

  /// No description provided for @ticketRefreshingSeatMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Refreshing seat map'**
  String get ticketRefreshingSeatMapTitle;

  /// No description provided for @ticketRefreshingSeatMapMessage.
  ///
  /// In en, this message translates to:
  /// **'The last confirmed fixture remains visible.'**
  String get ticketRefreshingSeatMapMessage;

  /// No description provided for @ticketLastConfirmedStandsMessage.
  ///
  /// In en, this message translates to:
  /// **'These are the last confirmed stands. Refresh before selecting.'**
  String get ticketLastConfirmedStandsMessage;

  /// No description provided for @ticketSeatMapCheckTimedOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Seat map check timed out'**
  String get ticketSeatMapCheckTimedOutTitle;

  /// No description provided for @ticketSeatAccessChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Seat access changed'**
  String get ticketSeatAccessChangedTitle;

  /// No description provided for @ticketSavedSeatMapReadOnlyMessage.
  ///
  /// In en, this message translates to:
  /// **'The saved map is read-only. Return to the ticket to continue.'**
  String get ticketSavedSeatMapReadOnlyMessage;

  /// No description provided for @ticketSeatMapRefreshFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Seat map refresh failed'**
  String get ticketSeatMapRefreshFailedTitle;

  /// No description provided for @ticketSelectedSeatUpper.
  ///
  /// In en, this message translates to:
  /// **'SELECTED SEAT'**
  String get ticketSelectedSeatUpper;

  /// No description provided for @ticketSeatMapSemantic.
  ///
  /// In en, this message translates to:
  /// **'Interactive stadium seat map'**
  String get ticketSeatMapSemantic;

  /// No description provided for @ticketSeatMapSelectedSemantic.
  ///
  /// In en, this message translates to:
  /// **'Interactive stadium seat map, selected {seat}'**
  String ticketSeatMapSelectedSemantic(String seat);

  /// No description provided for @ticketSeatMapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a stand to select a seat'**
  String get ticketSeatMapHint;

  /// No description provided for @ticketSelectedStandSemantic.
  ///
  /// In en, this message translates to:
  /// **'Selected {stand} stand'**
  String ticketSelectedStandSemantic(String stand);

  /// No description provided for @ticketSelectStandSemantic.
  ///
  /// In en, this message translates to:
  /// **'Select {stand} stand'**
  String ticketSelectStandSemantic(String stand);

  /// No description provided for @ticketSeatCode.
  ///
  /// In en, this message translates to:
  /// **'{stand}, Seat {number}'**
  String ticketSeatCode(String stand, int number);

  /// No description provided for @ticketStandVipGold.
  ///
  /// In en, this message translates to:
  /// **'VIP Gold'**
  String get ticketStandVipGold;

  /// No description provided for @ticketStandEast.
  ///
  /// In en, this message translates to:
  /// **'East Stand'**
  String get ticketStandEast;

  /// No description provided for @ticketStandTribuneRed.
  ///
  /// In en, this message translates to:
  /// **'Tribune Red'**
  String get ticketStandTribuneRed;

  /// No description provided for @ticketStandStanding.
  ///
  /// In en, this message translates to:
  /// **'Standing'**
  String get ticketStandStanding;

  /// No description provided for @ticketLegendVip.
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get ticketLegendVip;

  /// No description provided for @ticketLegendTribune.
  ///
  /// In en, this message translates to:
  /// **'Tribune'**
  String get ticketLegendTribune;

  /// No description provided for @contributionsClubProjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'CLUB PROJECTS'**
  String get contributionsClubProjectsTitle;

  /// No description provided for @contributionsProjectsUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Projects unavailable'**
  String get contributionsProjectsUnavailableTitle;

  /// No description provided for @contributionsProjectsUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Club projects are temporarily unavailable.'**
  String get contributionsProjectsUnavailableMessage;

  /// No description provided for @contributionsProjectFallback.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get contributionsProjectFallback;

  /// No description provided for @contributionsFundingProgress.
  ///
  /// In en, this message translates to:
  /// **'{current} / {target}'**
  String contributionsFundingProgress(String current, String target);

  /// No description provided for @contributionsSupporters.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No supporters} =1{1 supporter} other{{count} supporters}}'**
  String contributionsSupporters(int count);

  /// No description provided for @contributionsContributeAction.
  ///
  /// In en, this message translates to:
  /// **'Contribute'**
  String get contributionsContributeAction;

  /// No description provided for @contributionsCommunitiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Communities'**
  String get contributionsCommunitiesTitle;

  /// No description provided for @contributionsCommunitiesLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load public communities right now.'**
  String get contributionsCommunitiesLoadError;

  /// No description provided for @contributionsInitiatives.
  ///
  /// In en, this message translates to:
  /// **'Initiatives'**
  String get contributionsInitiatives;

  /// No description provided for @contributionsContributed.
  ///
  /// In en, this message translates to:
  /// **'Contributed'**
  String get contributionsContributed;

  /// No description provided for @contributionsActiveInitiatives.
  ///
  /// In en, this message translates to:
  /// **'Active initiatives'**
  String get contributionsActiveInitiatives;

  /// No description provided for @contributionsCommunitiesUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Communities unavailable'**
  String get contributionsCommunitiesUnavailableTitle;

  /// No description provided for @contributionsCommunityQuietTitle.
  ///
  /// In en, this message translates to:
  /// **'Community board is quiet'**
  String get contributionsCommunityQuietTitle;

  /// No description provided for @contributionsCommunityQuietMessage.
  ///
  /// In en, this message translates to:
  /// **'Public contribution communities will appear here when the club opens the next supporter initiative.'**
  String get contributionsCommunityQuietMessage;

  /// No description provided for @contributionsPublicGroupFallback.
  ///
  /// In en, this message translates to:
  /// **'Public group'**
  String get contributionsPublicGroupFallback;

  /// No description provided for @contributionsContributors.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No contributors} =1{1 contributor} other{{count} contributors}}'**
  String contributionsContributors(int count);

  /// No description provided for @contributionsGoalPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of goal'**
  String contributionsGoalPercent(int percent);

  /// No description provided for @contributionsConnectToLoad.
  ///
  /// In en, this message translates to:
  /// **'Connect to load contribution initiatives.'**
  String get contributionsConnectToLoad;

  /// No description provided for @contributionsInitiativesUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Contribution initiatives are temporarily unavailable.'**
  String get contributionsInitiativesUnavailableMessage;

  /// No description provided for @contributionsSmsEnabled.
  ///
  /// In en, this message translates to:
  /// **'MoMo SMS sync enabled for this device.'**
  String get contributionsSmsEnabled;

  /// No description provided for @contributionsSmsPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'SMS access was not granted. Sync remains off.'**
  String get contributionsSmsPermissionDenied;

  /// No description provided for @contributionsSmsEnableFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not enable SMS sync. Check your permissions and try again.'**
  String get contributionsSmsEnableFailed;

  /// No description provided for @contributionsSmsDisabled.
  ///
  /// In en, this message translates to:
  /// **'MoMo SMS sync disabled.'**
  String get contributionsSmsDisabled;

  /// No description provided for @contributionsConnectBeforeSmsSync.
  ///
  /// In en, this message translates to:
  /// **'Connect before syncing MoMo messages.'**
  String get contributionsConnectBeforeSmsSync;

  /// No description provided for @contributionsSmsSyncComplete.
  ///
  /// In en, this message translates to:
  /// **'SMS sync complete: {uploaded} uploaded, {duplicates} duplicates.'**
  String contributionsSmsSyncComplete(int uploaded, int duplicates);

  /// No description provided for @contributionsSmsSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'SMS sync failed. Check your connection and try again.'**
  String get contributionsSmsSyncFailed;

  /// No description provided for @contributionsHubTitle.
  ///
  /// In en, this message translates to:
  /// **'CONTRIBUTE'**
  String get contributionsHubTitle;

  /// No description provided for @contributionsRefreshingTitle.
  ///
  /// In en, this message translates to:
  /// **'Refreshing contributions'**
  String get contributionsRefreshingTitle;

  /// No description provided for @contributionsRefreshingMessage.
  ///
  /// In en, this message translates to:
  /// **'Current totals and initiatives are being checked.'**
  String get contributionsRefreshingMessage;

  /// No description provided for @contributionsSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved contribution data'**
  String get contributionsSavedTitle;

  /// No description provided for @contributionsSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Totals may be out of date. Reconnect before making or syncing a contribution.'**
  String get contributionsSavedMessage;

  /// No description provided for @contributionsTeamProjects.
  ///
  /// In en, this message translates to:
  /// **'TEAM PROJECTS'**
  String get contributionsTeamProjects;

  /// No description provided for @contributionsRaised.
  ///
  /// In en, this message translates to:
  /// **'{current} of {target} raised.'**
  String contributionsRaised(String current, String target);

  /// No description provided for @contributionsOpenMetric.
  ///
  /// In en, this message translates to:
  /// **'{count} OPEN'**
  String contributionsOpenMetric(int count);

  /// No description provided for @contributionsCommunitiesUpper.
  ///
  /// In en, this message translates to:
  /// **'COMMUNITIES'**
  String get contributionsCommunitiesUpper;

  /// No description provided for @contributionsInitiativesActive.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 initiative is active.} other{{count} initiatives are active.}}'**
  String contributionsInitiativesActive(int count);

  /// No description provided for @contributionsLiveMetric.
  ///
  /// In en, this message translates to:
  /// **'{count} LIVE'**
  String contributionsLiveMetric(int count);

  /// No description provided for @contributionsCommunityUpper.
  ///
  /// In en, this message translates to:
  /// **'COMMUNITY'**
  String get contributionsCommunityUpper;

  /// No description provided for @contributionsFanClubsChapters.
  ///
  /// In en, this message translates to:
  /// **'Fan clubs & local chapters.'**
  String get contributionsFanClubsChapters;

  /// No description provided for @contributionsLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get contributionsLive;

  /// No description provided for @contributionsMomoSmsSync.
  ///
  /// In en, this message translates to:
  /// **'MoMo SMS sync'**
  String get contributionsMomoSmsSync;

  /// No description provided for @contributionsUnavailableBuild.
  ///
  /// In en, this message translates to:
  /// **'Unavailable in this build.'**
  String get contributionsUnavailableBuild;

  /// No description provided for @contributionsActiveUpper.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get contributionsActiveUpper;

  /// No description provided for @contributionsSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get contributionsSyncing;

  /// No description provided for @contributionsSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get contributionsSyncNow;

  /// No description provided for @contributionsDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get contributionsDisable;

  /// No description provided for @contributionsEnabling.
  ///
  /// In en, this message translates to:
  /// **'Enabling…'**
  String get contributionsEnabling;

  /// No description provided for @contributionsEnableSmsSync.
  ///
  /// In en, this message translates to:
  /// **'Enable SMS sync'**
  String get contributionsEnableSmsSync;

  /// No description provided for @contributionsLiveCampaigns.
  ///
  /// In en, this message translates to:
  /// **'Live campaigns'**
  String get contributionsLiveCampaigns;

  /// No description provided for @contributionsGroupsUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Groups unavailable'**
  String get contributionsGroupsUnavailableTitle;

  /// No description provided for @contributionsGroupFallback.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get contributionsGroupFallback;

  /// No description provided for @contributionsAmountOfTarget.
  ///
  /// In en, this message translates to:
  /// **'{current} of {target}'**
  String contributionsAmountOfTarget(String current, String target);

  /// No description provided for @contributionsSeeAllGroups.
  ///
  /// In en, this message translates to:
  /// **'See all contribution groups'**
  String get contributionsSeeAllGroups;

  /// No description provided for @contributionsSeeAllGroupsSemantic.
  ///
  /// In en, this message translates to:
  /// **'See all {count} contribution groups'**
  String contributionsSeeAllGroupsSemantic(int count);

  /// No description provided for @contributionsOpenGroupsHint.
  ///
  /// In en, this message translates to:
  /// **'Open contribution groups'**
  String get contributionsOpenGroupsHint;

  /// No description provided for @contributionsSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all {count}'**
  String contributionsSeeAll(int count);

  /// No description provided for @contributionsInitiativeTitle.
  ///
  /// In en, this message translates to:
  /// **'PUBLIC INITIATIVE'**
  String get contributionsInitiativeTitle;

  /// No description provided for @contributionsInitiativeLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading public initiative'**
  String get contributionsInitiativeLoadingTitle;

  /// No description provided for @contributionsInitiativeLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Checking the confirmed total and public contribution ledger.'**
  String get contributionsInitiativeLoadingMessage;

  /// No description provided for @contributionsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get contributionsRefresh;

  /// No description provided for @contributionsBackToCommunities.
  ///
  /// In en, this message translates to:
  /// **'Back to communities'**
  String get contributionsBackToCommunities;

  /// No description provided for @contributionsInitiativeRefreshingTitle.
  ///
  /// In en, this message translates to:
  /// **'Refreshing initiative'**
  String get contributionsInitiativeRefreshingTitle;

  /// No description provided for @contributionsInitiativeRefreshingMessage.
  ///
  /// In en, this message translates to:
  /// **'Keeping the last confirmed total and ledger visible while new activity is checked.'**
  String get contributionsInitiativeRefreshingMessage;

  /// No description provided for @contributionsReadOnlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Contributions are read-only'**
  String get contributionsReadOnlyTitle;

  /// No description provided for @contributionsReadOnlyMessage.
  ///
  /// In en, this message translates to:
  /// **'Confirmed public activity remains visible, but starting a payment is disabled for this build.'**
  String get contributionsReadOnlyMessage;

  /// No description provided for @contributionsSavedInitiativeTitle.
  ///
  /// In en, this message translates to:
  /// **'Showing saved initiative data'**
  String get contributionsSavedInitiativeTitle;

  /// No description provided for @contributionsSavedInitiativeMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect and refresh before starting a payment or relying on the latest total.'**
  String get contributionsSavedInitiativeMessage;

  /// No description provided for @contributionsRefreshInitiativeUpper.
  ///
  /// In en, this message translates to:
  /// **'REFRESH INITIATIVE'**
  String get contributionsRefreshInitiativeUpper;

  /// No description provided for @contributionsClosedTitle.
  ///
  /// In en, this message translates to:
  /// **'Contributions are closed'**
  String get contributionsClosedTitle;

  /// No description provided for @contributionsClosedMessage.
  ///
  /// In en, this message translates to:
  /// **'The confirmed total and public ledger remain available for review.'**
  String get contributionsClosedMessage;

  /// No description provided for @contributionsPaymentRouteUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment route unavailable'**
  String get contributionsPaymentRouteUnavailableTitle;

  /// No description provided for @contributionsPaymentRouteUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'No payment will start until the club publishes a verified recipient.'**
  String get contributionsPaymentRouteUnavailableMessage;

  /// No description provided for @contributionsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Contributions disabled'**
  String get contributionsDisabled;

  /// No description provided for @contributionsClosed.
  ///
  /// In en, this message translates to:
  /// **'Contributions closed'**
  String get contributionsClosed;

  /// No description provided for @contributionsPaymentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Payment unavailable'**
  String get contributionsPaymentUnavailable;

  /// No description provided for @contributionsCheckingLatestTotal.
  ///
  /// In en, this message translates to:
  /// **'Checking latest total'**
  String get contributionsCheckingLatestTotal;

  /// No description provided for @contributionsRefreshBeforeContributing.
  ///
  /// In en, this message translates to:
  /// **'Refresh before contributing'**
  String get contributionsRefreshBeforeContributing;

  /// No description provided for @contributionsContributeNow.
  ///
  /// In en, this message translates to:
  /// **'Contribute now'**
  String get contributionsContributeNow;

  /// No description provided for @contributionsConfirmedTotal.
  ///
  /// In en, this message translates to:
  /// **'Confirmed total'**
  String get contributionsConfirmedTotal;

  /// No description provided for @contributionsTargetProgress.
  ///
  /// In en, this message translates to:
  /// **'Target {target} · {percent}%'**
  String contributionsTargetProgress(String target, int percent);

  /// No description provided for @contributionsProgressSemantic.
  ///
  /// In en, this message translates to:
  /// **'{percent} percent of the contribution target confirmed'**
  String contributionsProgressSemantic(int percent);

  /// No description provided for @contributionsTypeUpper.
  ///
  /// In en, this message translates to:
  /// **'TYPE'**
  String get contributionsTypeUpper;

  /// No description provided for @contributionsContributorsUpper.
  ///
  /// In en, this message translates to:
  /// **'CONTRIBUTORS'**
  String get contributionsContributorsUpper;

  /// No description provided for @contributionsContributeToSemantic.
  ///
  /// In en, this message translates to:
  /// **'Contribute to {group}'**
  String contributionsContributeToSemantic(String group);

  /// No description provided for @contributionsPaymentUnavailableSemantic.
  ///
  /// In en, this message translates to:
  /// **'{action}. Payment is unavailable.'**
  String contributionsPaymentUnavailableSemantic(String action);

  /// No description provided for @contributionsPublicLedgerTitle.
  ///
  /// In en, this message translates to:
  /// **'PUBLIC LEDGER'**
  String get contributionsPublicLedgerTitle;

  /// No description provided for @contributionsPublicLedgerPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Public supporter aliases only. Payment references and account details are never shown.'**
  String get contributionsPublicLedgerPrivacy;

  /// No description provided for @contributionsLedgerEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No contributions yet'**
  String get contributionsLedgerEmptyTitle;

  /// No description provided for @contributionsLedgerEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Confirmed public activity will appear here without exposing payment details.'**
  String get contributionsLedgerEmptyMessage;

  /// No description provided for @contributionsMetaSemantic.
  ///
  /// In en, this message translates to:
  /// **'{label}, {value}'**
  String contributionsMetaSemantic(String label, String value);

  /// No description provided for @contributionsLedgerEntrySemantic.
  ///
  /// In en, this message translates to:
  /// **'{alias}, {amount}, {status}, {date}'**
  String contributionsLedgerEntrySemantic(
    String alias,
    String amount,
    String status,
    String date,
  );

  /// No description provided for @contributionsStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'CONFIRMED'**
  String get contributionsStatusConfirmed;

  /// No description provided for @contributionsStatusProcessing.
  ///
  /// In en, this message translates to:
  /// **'PROCESSING'**
  String get contributionsStatusProcessing;

  /// No description provided for @contributionsStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'FAILED'**
  String get contributionsStatusFailed;

  /// No description provided for @contributionsTypeProject.
  ///
  /// In en, this message translates to:
  /// **'TEAM PROJECT'**
  String get contributionsTypeProject;

  /// No description provided for @contributionsTypeCommunity.
  ///
  /// In en, this message translates to:
  /// **'COMMUNITY'**
  String get contributionsTypeCommunity;

  /// No description provided for @contributionsConnectionRestoredTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection restored'**
  String get contributionsConnectionRestoredTitle;

  /// No description provided for @contributionsInitiativeOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Initiative offline'**
  String get contributionsInitiativeOfflineTitle;

  /// No description provided for @contributionsConnectionRestoredMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh to check the latest confirmed total and public ledger.'**
  String get contributionsConnectionRestoredMessage;

  /// No description provided for @contributionsInitiativeOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to load this public initiative.'**
  String get contributionsInitiativeOfflineMessage;

  /// No description provided for @contributionsInitiativeNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Initiative not found'**
  String get contributionsInitiativeNotFoundTitle;

  /// No description provided for @contributionsInitiativeNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'This contribution initiative may have closed or the link may no longer be valid.'**
  String get contributionsInitiativeNotFoundMessage;

  /// No description provided for @contributionsInitiativeUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Initiative unavailable'**
  String get contributionsInitiativeUnavailableTitle;

  /// No description provided for @contributionsInitiativeAccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your current club access does not allow this contribution initiative.'**
  String get contributionsInitiativeAccessMessage;

  /// No description provided for @contributionsInitiativeChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Initiative changed'**
  String get contributionsInitiativeChangedTitle;

  /// No description provided for @contributionsInitiativeChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh and review the latest total before starting a contribution.'**
  String get contributionsInitiativeChangedMessage;

  /// No description provided for @contributionsInitiativeTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Initiative check timed out'**
  String get contributionsInitiativeTimeoutTitle;

  /// No description provided for @contributionsInitiativeTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'No total was confirmed. Refresh before starting a contribution.'**
  String get contributionsInitiativeTimeoutMessage;

  /// No description provided for @contributionsInitiativeUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh and try again when the public ledger is available.'**
  String get contributionsInitiativeUnavailableMessage;

  /// No description provided for @contributionsEmptyCsvCopied.
  ///
  /// In en, this message translates to:
  /// **'Empty CSV copied to clipboard.'**
  String get contributionsEmptyCsvCopied;

  /// No description provided for @contributionsCsvCopied.
  ///
  /// In en, this message translates to:
  /// **'Privacy-safe CSV copied to clipboard.'**
  String get contributionsCsvCopied;

  /// No description provided for @contributionsStatementTitle.
  ///
  /// In en, this message translates to:
  /// **'PUBLIC STATEMENT'**
  String get contributionsStatementTitle;

  /// No description provided for @contributionsStatementLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading public statement'**
  String get contributionsStatementLoadingTitle;

  /// No description provided for @contributionsStatementLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Checking confirmed contributions and privacy-safe supporter aliases.'**
  String get contributionsStatementLoadingMessage;

  /// No description provided for @contributionsBackToInitiative.
  ///
  /// In en, this message translates to:
  /// **'Back to initiative'**
  String get contributionsBackToInitiative;

  /// No description provided for @contributionsStatementRefreshingTitle.
  ///
  /// In en, this message translates to:
  /// **'Refreshing statement'**
  String get contributionsStatementRefreshingTitle;

  /// No description provided for @contributionsStatementRefreshingMessage.
  ///
  /// In en, this message translates to:
  /// **'Keeping the last confirmed statement visible while new activity is checked.'**
  String get contributionsStatementRefreshingMessage;

  /// No description provided for @contributionsStatementReadOnlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Statement export is read-only'**
  String get contributionsStatementReadOnlyTitle;

  /// No description provided for @contributionsStatementReadOnlyMessage.
  ///
  /// In en, this message translates to:
  /// **'You can review confirmed public entries, but copying a statement is disabled for this build.'**
  String get contributionsStatementReadOnlyMessage;

  /// No description provided for @contributionsSavedStatementTitle.
  ///
  /// In en, this message translates to:
  /// **'Showing saved statement data'**
  String get contributionsSavedStatementTitle;

  /// No description provided for @contributionsSavedStatementMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect and refresh before exporting or relying on the latest total.'**
  String get contributionsSavedStatementMessage;

  /// No description provided for @contributionsRefreshStatementUpper.
  ///
  /// In en, this message translates to:
  /// **'REFRESH STATEMENT'**
  String get contributionsRefreshStatementUpper;

  /// No description provided for @contributionsCopyCsvSemantic.
  ///
  /// In en, this message translates to:
  /// **'Copy privacy-safe CSV statement'**
  String get contributionsCopyCsvSemantic;

  /// No description provided for @contributionsExportUnavailableSemantic.
  ///
  /// In en, this message translates to:
  /// **'Statement export unavailable. {reason}'**
  String contributionsExportUnavailableSemantic(String reason);

  /// No description provided for @contributionsFromUpper.
  ///
  /// In en, this message translates to:
  /// **'FROM'**
  String get contributionsFromUpper;

  /// No description provided for @contributionsToUpper.
  ///
  /// In en, this message translates to:
  /// **'TO'**
  String get contributionsToUpper;

  /// No description provided for @contributionsAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get contributionsAllTime;

  /// No description provided for @contributionsNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get contributionsNow;

  /// No description provided for @contributionsSortUpper.
  ///
  /// In en, this message translates to:
  /// **'SORT'**
  String get contributionsSortUpper;

  /// No description provided for @contributionsSortDate.
  ///
  /// In en, this message translates to:
  /// **'BY DATE'**
  String get contributionsSortDate;

  /// No description provided for @contributionsSortAmount.
  ///
  /// In en, this message translates to:
  /// **'BY AMOUNT'**
  String get contributionsSortAmount;

  /// No description provided for @contributionsSortAlias.
  ///
  /// In en, this message translates to:
  /// **'BY ALIAS'**
  String get contributionsSortAlias;

  /// No description provided for @contributionsPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get contributionsPdf;

  /// No description provided for @contributionsCsv.
  ///
  /// In en, this message translates to:
  /// **'CSV'**
  String get contributionsCsv;

  /// No description provided for @contributionsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get contributionsComingSoon;

  /// No description provided for @contributionsClipboard.
  ///
  /// In en, this message translates to:
  /// **'Clipboard'**
  String get contributionsClipboard;

  /// No description provided for @contributionsCopyingCsv.
  ///
  /// In en, this message translates to:
  /// **'Copying CSV…'**
  String get contributionsCopyingCsv;

  /// No description provided for @contributionsExportDisabled.
  ///
  /// In en, this message translates to:
  /// **'Export disabled'**
  String get contributionsExportDisabled;

  /// No description provided for @contributionsCheckingLatestEntries.
  ///
  /// In en, this message translates to:
  /// **'Checking latest entries'**
  String get contributionsCheckingLatestEntries;

  /// No description provided for @contributionsRefreshBeforeExporting.
  ///
  /// In en, this message translates to:
  /// **'Refresh before exporting'**
  String get contributionsRefreshBeforeExporting;

  /// No description provided for @contributionsCopyCsvStatement.
  ///
  /// In en, this message translates to:
  /// **'Copy CSV statement'**
  String get contributionsCopyCsvStatement;

  /// No description provided for @contributionsStatementSummarySemantic.
  ///
  /// In en, this message translates to:
  /// **'{group} public statement, {count} entries, confirmed total {total}'**
  String contributionsStatementSummarySemantic(
    String group,
    int count,
    String total,
  );

  /// No description provided for @contributionsConfirmedTotalUpper.
  ///
  /// In en, this message translates to:
  /// **'CONFIRMED TOTAL'**
  String get contributionsConfirmedTotalUpper;

  /// No description provided for @contributionsPublicEntriesInRange.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 public entry in this range} other{{count} public entries in this range}}'**
  String contributionsPublicEntriesInRange(int count);

  /// No description provided for @contributionsStatementPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Public supporter aliases only. Names, phone numbers, payment references, and account identifiers are excluded.'**
  String get contributionsStatementPrivacy;

  /// No description provided for @contributionsFormatSemantic.
  ///
  /// In en, this message translates to:
  /// **'{label} export format, {helper}'**
  String contributionsFormatSemantic(String label, String helper);

  /// No description provided for @contributionsPreviewUpper.
  ///
  /// In en, this message translates to:
  /// **'PREVIEW'**
  String get contributionsPreviewUpper;

  /// No description provided for @contributionsPreviewShowing.
  ///
  /// In en, this message translates to:
  /// **'Showing 5 of {count} entries. The CSV includes the full bounded range.'**
  String contributionsPreviewShowing(int count);

  /// No description provided for @contributionsPreviewPublicFields.
  ///
  /// In en, this message translates to:
  /// **'The CSV includes only the public fields shown below.'**
  String get contributionsPreviewPublicFields;

  /// No description provided for @contributionsNoStatementEntriesTitle.
  ///
  /// In en, this message translates to:
  /// **'No statement entries'**
  String get contributionsNoStatementEntriesTitle;

  /// No description provided for @contributionsNoStatementEntriesMessage.
  ///
  /// In en, this message translates to:
  /// **'No public contributions match this date range. Choose another range and refresh.'**
  String get contributionsNoStatementEntriesMessage;

  /// No description provided for @contributionsStatementOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Statement offline'**
  String get contributionsStatementOfflineTitle;

  /// No description provided for @contributionsStatementRestoredMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh to check the latest confirmed public entries.'**
  String get contributionsStatementRestoredMessage;

  /// No description provided for @contributionsStatementOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to load this public statement.'**
  String get contributionsStatementOfflineMessage;

  /// No description provided for @contributionsStatementNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Statement not found'**
  String get contributionsStatementNotFoundTitle;

  /// No description provided for @contributionsStatementNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'This initiative may have closed or the statement link may no longer be valid.'**
  String get contributionsStatementNotFoundMessage;

  /// No description provided for @contributionsStatementUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Statement unavailable'**
  String get contributionsStatementUnavailableTitle;

  /// No description provided for @contributionsStatementAccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your current club access does not allow this contribution statement.'**
  String get contributionsStatementAccessMessage;

  /// No description provided for @contributionsStatementChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Statement changed'**
  String get contributionsStatementChangedTitle;

  /// No description provided for @contributionsStatementChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh and review the latest confirmed entries before exporting.'**
  String get contributionsStatementChangedMessage;

  /// No description provided for @contributionsStatementTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Statement check timed out'**
  String get contributionsStatementTimeoutTitle;

  /// No description provided for @contributionsStatementTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'No current statement was confirmed. Refresh before exporting.'**
  String get contributionsStatementTimeoutMessage;

  /// No description provided for @contributionsStatementUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh and try again when the public contribution ledger is available.'**
  String get contributionsStatementUnavailableMessage;

  /// No description provided for @contributionsConnectBeforeContributing.
  ///
  /// In en, this message translates to:
  /// **'Connect before contributing. No payment or contribution was submitted.'**
  String get contributionsConnectBeforeContributing;

  /// No description provided for @contributionsDialerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the MOMO dialer. Contribution was not submitted.'**
  String get contributionsDialerFailed;

  /// No description provided for @contributionsStatusAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'{heading}. {message}'**
  String contributionsStatusAnnouncement(String heading, String message);

  /// No description provided for @contributionsAmountPrompt.
  ///
  /// In en, this message translates to:
  /// **'HOW MUCH TO CONTRIBUTE?'**
  String get contributionsAmountPrompt;

  /// No description provided for @contributionsQuickAmount.
  ///
  /// In en, this message translates to:
  /// **'+{thousands}K'**
  String contributionsQuickAmount(int thousands);

  /// No description provided for @contributionsLaunchMomoDialer.
  ///
  /// In en, this message translates to:
  /// **'Launch MOMO dialer'**
  String get contributionsLaunchMomoDialer;

  /// No description provided for @contributionsLaunchingMomo.
  ///
  /// In en, this message translates to:
  /// **'LAUNCHING MOMO'**
  String get contributionsLaunchingMomo;

  /// No description provided for @contributionsChangeAmount.
  ///
  /// In en, this message translates to:
  /// **'Change amount'**
  String get contributionsChangeAmount;

  /// No description provided for @contributionsDialNow.
  ///
  /// In en, this message translates to:
  /// **'Dial now'**
  String get contributionsDialNow;

  /// No description provided for @contributionsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel contribution'**
  String get contributionsCancel;

  /// No description provided for @contributionsPaymentConfirmedTitle.
  ///
  /// In en, this message translates to:
  /// **'PAYMENT CONFIRMED'**
  String get contributionsPaymentConfirmedTitle;

  /// No description provided for @contributionsPaymentConfirmedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your contribution of {amount} has been verified and recorded.'**
  String contributionsPaymentConfirmedMessage(String amount);

  /// No description provided for @contributionsPaymentFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'PAYMENT FAILED'**
  String get contributionsPaymentFailedTitle;

  /// No description provided for @contributionsPaymentFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'The payment could not be verified. Check your MoMo balance and try again, or contact support.'**
  String get contributionsPaymentFailedMessage;

  /// No description provided for @contributionsPaymentProcessingTitle.
  ///
  /// In en, this message translates to:
  /// **'STILL PROCESSING'**
  String get contributionsPaymentProcessingTitle;

  /// No description provided for @contributionsPaymentProcessingMessage.
  ///
  /// In en, this message translates to:
  /// **'Your payment is taking longer than usual. Check the Group ledger for your updated status. If you completed the MoMo transfer, it will appear shortly.'**
  String get contributionsPaymentProcessingMessage;

  /// No description provided for @contributionsRecordFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'COULD NOT RECORD'**
  String get contributionsRecordFailedTitle;

  /// No description provided for @contributionsRecordFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'The MoMo dialer was launched but the contribution could not be saved. Return to the Group and try again.'**
  String get contributionsRecordFailedMessage;

  /// No description provided for @contributionsAwaitingPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'AWAITING PAYMENT'**
  String get contributionsAwaitingPaymentTitle;

  /// No description provided for @contributionsAwaitingPaymentMessage.
  ///
  /// In en, this message translates to:
  /// **'Complete the MoMo payment on your phone. Your contribution appears as \"Processing\" until we receive confirmation.'**
  String get contributionsAwaitingPaymentMessage;

  /// No description provided for @contributionsCheckingPaymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Checking payment status…'**
  String get contributionsCheckingPaymentStatus;

  /// No description provided for @contributionsVerifiedUpper.
  ///
  /// In en, this message translates to:
  /// **'VERIFIED'**
  String get contributionsVerifiedUpper;

  /// No description provided for @contributionsDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get contributionsDone;

  /// No description provided for @contributionsBackToGroup.
  ///
  /// In en, this message translates to:
  /// **'Back to group'**
  String get contributionsBackToGroup;

  /// No description provided for @contributionsEnableMomoSmsTitle.
  ///
  /// In en, this message translates to:
  /// **'ENABLE MOMO SMS SYNC'**
  String get contributionsEnableMomoSmsTitle;

  /// No description provided for @contributionsSmsPrivacyMessage.
  ///
  /// In en, this message translates to:
  /// **'{app} reads only MoMo confirmations to auto-log receipts. Other messages are not accessed.'**
  String contributionsSmsPrivacyMessage(String app);

  /// No description provided for @contributionsAllowSmsReading.
  ///
  /// In en, this message translates to:
  /// **'Allow SMS reading'**
  String get contributionsAllowSmsReading;

  /// No description provided for @contributionsEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get contributionsEnable;

  /// No description provided for @contributionsNotNowUpper.
  ///
  /// In en, this message translates to:
  /// **'NOT NOW'**
  String get contributionsNotNowUpper;
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
