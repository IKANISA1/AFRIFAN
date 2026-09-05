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

  /// No description provided for @clubOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Club information offline'**
  String get clubOfflineTitle;

  /// No description provided for @clubOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Connect to load the latest official club information.'**
  String get clubOfflineMessage;

  /// No description provided for @clubAccessDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Club information access denied'**
  String get clubAccessDeniedTitle;

  /// No description provided for @clubAccessDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'This account cannot access the requested club information.'**
  String get clubAccessDeniedMessage;

  /// No description provided for @clubChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Club information changed'**
  String get clubChangedTitle;

  /// No description provided for @clubChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Official club information changed while loading. Refresh to confirm the latest version.'**
  String get clubChangedMessage;

  /// No description provided for @clubSecurityTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Club information security check timed out'**
  String get clubSecurityTimeoutTitle;

  /// No description provided for @clubSecurityTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'The club information service did not respond in time. Refresh to try again.'**
  String get clubSecurityTimeoutMessage;

  /// No description provided for @clubRefreshingTitle.
  ///
  /// In en, this message translates to:
  /// **'Refreshing club information'**
  String get clubRefreshingTitle;

  /// No description provided for @clubRefreshingMessage.
  ///
  /// In en, this message translates to:
  /// **'Keeping the last confirmed club information visible while updates load.'**
  String get clubRefreshingMessage;

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
  /// **'Back to supporters'**
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
  /// **'Active'**
  String get fanClubActive;

  /// No description provided for @fanClubPendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get fanClubPendingReview;

  /// No description provided for @fanClubCurrentSemantic.
  ///
  /// In en, this message translates to:
  /// **'Current fan club, {name}'**
  String fanClubCurrentSemantic(String name);

  /// No description provided for @fanClubAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About this club'**
  String get fanClubAboutTitle;

  /// No description provided for @fanClubRegionValue.
  ///
  /// In en, this message translates to:
  /// **'Region: {region}'**
  String fanClubRegionValue(String region);

  /// No description provided for @fanClubSnapshotTitle.
  ///
  /// In en, this message translates to:
  /// **'Group snapshot'**
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
  /// **'Refresh club'**
  String get fanClubRefreshAction;

  /// No description provided for @fanClubTryAgainAction.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
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
  /// **'Matchday agenda'**
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
  /// **'Members'**
  String get fanClubMembersLabel;

  /// No description provided for @fanClubStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get fanClubStatusLabel;

  /// No description provided for @fanClubRegionLabel.
  ///
  /// In en, this message translates to:
  /// **'Region'**
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
  /// **'Supporters'**
  String get fanClubSupportersAction;

  /// No description provided for @fanClubOpenSupportersAction.
  ///
  /// In en, this message translates to:
  /// **'Open supporters'**
  String get fanClubOpenSupportersAction;

  /// No description provided for @fanClubCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
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
  /// **'The community'**
  String get fanClubsCommunityEyebrow;

  /// No description provided for @fanClubsTitle.
  ///
  /// In en, this message translates to:
  /// **'Fan clubs'**
  String get fanClubsTitle;

  /// No description provided for @fanClubsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search clubs or locations'**
  String get fanClubsSearchHint;

  /// No description provided for @fanClubsFeaturedChapter.
  ///
  /// In en, this message translates to:
  /// **'Featured chapter'**
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
  /// **'Half-time'**
  String get liveStatusHalfTime;

  /// No description provided for @liveStatusFullTime.
  ///
  /// In en, this message translates to:
  /// **'Full-time'**
  String get liveStatusFullTime;

  /// No description provided for @liveStatusPostponed.
  ///
  /// In en, this message translates to:
  /// **'Postponed'**
  String get liveStatusPostponed;

  /// No description provided for @liveStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get liveStatusCancelled;

  /// No description provided for @liveStatusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get liveStatusUpcoming;

  /// No description provided for @liveStatusFinal.
  ///
  /// In en, this message translates to:
  /// **'Final'**
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
  /// **'Match report'**
  String get liveMatchReport;

  /// No description provided for @liveMatchFinishedPending.
  ///
  /// In en, this message translates to:
  /// **'Match finished. Summary pending.'**
  String get liveMatchFinishedPending;

  /// No description provided for @liveMatchdayIntel.
  ///
  /// In en, this message translates to:
  /// **'Matchday intel'**
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
  /// **'Live center unavailable'**
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
  /// **'Refresh article'**
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
  /// **'Out of stock'**
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
  /// **'Loading'**
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
  /// **'Official'**
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
  /// **'Date'**
  String get ticketDateLabel;

  /// No description provided for @ticketTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get ticketTimeLabel;

  /// No description provided for @ticketVenueLabel.
  ///
  /// In en, this message translates to:
  /// **'Venue'**
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

  /// No description provided for @ticketGoogleWalletChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking Google Wallet availability…'**
  String get ticketGoogleWalletChecking;

  /// No description provided for @ticketGoogleWalletReady.
  ///
  /// In en, this message translates to:
  /// **'Your confirmed ticket can be added to Google Wallet.'**
  String get ticketGoogleWalletReady;

  /// No description provided for @ticketGoogleWalletAdding.
  ///
  /// In en, this message translates to:
  /// **'Adding to Google Wallet…'**
  String get ticketGoogleWalletAdding;

  /// No description provided for @ticketGoogleWalletAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to Google Wallet'**
  String get ticketGoogleWalletAdded;

  /// No description provided for @ticketGoogleWalletAddingMessage.
  ///
  /// In en, this message translates to:
  /// **'Preparing the secure Wallet pass and opening Google Wallet.'**
  String get ticketGoogleWalletAddingMessage;

  /// No description provided for @ticketGoogleWalletAddedMessage.
  ///
  /// In en, this message translates to:
  /// **'Google Wallet confirmed that the pass was saved.'**
  String get ticketGoogleWalletAddedMessage;

  /// No description provided for @ticketGoogleWalletCancelled.
  ///
  /// In en, this message translates to:
  /// **'The Google Wallet save was cancelled. Your ticket remains available here.'**
  String get ticketGoogleWalletCancelled;

  /// No description provided for @ticketGoogleWalletUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Google Wallet is not available on this device or account.'**
  String get ticketGoogleWalletUnavailable;

  /// No description provided for @ticketGoogleWalletOnlineRequired.
  ///
  /// In en, this message translates to:
  /// **'Reconnect before adding this ticket to Google Wallet.'**
  String get ticketGoogleWalletOnlineRequired;

  /// No description provided for @ticketGoogleWalletPaymentPending.
  ///
  /// In en, this message translates to:
  /// **'Payment must be confirmed before this ticket can be added to Google Wallet.'**
  String get ticketGoogleWalletPaymentPending;

  /// No description provided for @ticketGoogleWalletPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'This account cannot add the selected ticket to Google Wallet.'**
  String get ticketGoogleWalletPermissionDenied;

  /// No description provided for @ticketGoogleWalletTimeout.
  ///
  /// In en, this message translates to:
  /// **'The secure Wallet request timed out. No save is confirmed; try again.'**
  String get ticketGoogleWalletTimeout;

  /// No description provided for @ticketGoogleWalletFailed.
  ///
  /// In en, this message translates to:
  /// **'The ticket could not be added to Google Wallet. Try again later.'**
  String get ticketGoogleWalletFailed;

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

  /// No description provided for @ticketEntryCodeAccessChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Ticket access changed'**
  String get ticketEntryCodeAccessChangedTitle;

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
  /// **'Refresh ticket'**
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
  /// **'My tickets'**
  String get ticketMyTickets;

  /// No description provided for @ticketRefreshTickets.
  ///
  /// In en, this message translates to:
  /// **'Refresh tickets'**
  String get ticketRefreshTickets;

  /// No description provided for @ticketUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get ticketUpcoming;

  /// No description provided for @ticketPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
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
  /// **'Checkout summary'**
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
  /// **'Confirm purchase'**
  String get ticketConfirmPurchase;

  /// No description provided for @ticketMatchUpper.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get ticketMatchUpper;

  /// No description provided for @ticketZoneUpper.
  ///
  /// In en, this message translates to:
  /// **'Zone'**
  String get ticketZoneUpper;

  /// No description provided for @ticketSeatUpper.
  ///
  /// In en, this message translates to:
  /// **'Seat'**
  String get ticketSeatUpper;

  /// No description provided for @ticketQuantityUpper.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get ticketQuantityUpper;

  /// No description provided for @ticketServiceFeeUpper.
  ///
  /// In en, this message translates to:
  /// **'Service fee'**
  String get ticketServiceFeeUpper;

  /// No description provided for @ticketTotalUpper.
  ///
  /// In en, this message translates to:
  /// **'Total'**
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
  /// **'Choose access'**
  String get ticketChooseAccess;

  /// No description provided for @ticketGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
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
  /// **'Choose specific seat'**
  String get ticketChooseSeat;

  /// No description provided for @ticketChangeSeat.
  ///
  /// In en, this message translates to:
  /// **'Change selected seat'**
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
  /// **'Official categories'**
  String get ticketOfficialCategories;

  /// No description provided for @ticketOfficialCategoriesMessage.
  ///
  /// In en, this message translates to:
  /// **'Approved public ticket tiers. Sale-specific availability appears when the club activates an official sale.'**
  String get ticketOfficialCategoriesMessage;

  /// No description provided for @ticketListTitle.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
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
  /// **'Next'**
  String get ticketNext;

  /// No description provided for @ticketMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
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
  /// **'Sold out'**
  String get ticketStatusSoldOut;

  /// No description provided for @ticketStatusAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get ticketStatusAvailable;

  /// No description provided for @ticketFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
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
  /// **'Match day'**
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
  /// **'Try again'**
  String get ticketTryAgainUpper;

  /// No description provided for @ticketRefreshFixtureUpper.
  ///
  /// In en, this message translates to:
  /// **'Refresh fixture'**
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

  /// No description provided for @ticketAccessChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Ticket access changed'**
  String get ticketAccessChangedTitle;

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
  /// **'Select seat'**
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
  /// **'Back to ticket'**
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
  /// **'Refresh seat map'**
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
  /// **'Selected seat'**
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
  /// **'Club projects'**
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
  /// **'Contribute'**
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
  /// **'Team projects'**
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
  /// **'Communities'**
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
  /// **'Community'**
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
  /// **'Active'**
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
  /// **'Public initiative'**
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
  /// **'Refresh initiative'**
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
  /// **'Type'**
  String get contributionsTypeUpper;

  /// No description provided for @contributionsContributorsUpper.
  ///
  /// In en, this message translates to:
  /// **'Contributors'**
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
  /// **'Public ledger'**
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
  /// **'Confirmed'**
  String get contributionsStatusConfirmed;

  /// No description provided for @contributionsStatusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get contributionsStatusProcessing;

  /// No description provided for @contributionsStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get contributionsStatusFailed;

  /// No description provided for @contributionsTypeProject.
  ///
  /// In en, this message translates to:
  /// **'Team project'**
  String get contributionsTypeProject;

  /// No description provided for @contributionsTypeCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
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
  /// **'Public statement'**
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
  /// **'Refresh statement'**
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
  /// **'From'**
  String get contributionsFromUpper;

  /// No description provided for @contributionsToUpper.
  ///
  /// In en, this message translates to:
  /// **'To'**
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
  /// **'Sort'**
  String get contributionsSortUpper;

  /// No description provided for @contributionsSortDate.
  ///
  /// In en, this message translates to:
  /// **'By date'**
  String get contributionsSortDate;

  /// No description provided for @contributionsSortAmount.
  ///
  /// In en, this message translates to:
  /// **'By amount'**
  String get contributionsSortAmount;

  /// No description provided for @contributionsSortAlias.
  ///
  /// In en, this message translates to:
  /// **'By alias'**
  String get contributionsSortAlias;

  /// No description provided for @contributionsPdf.
  ///
  /// In en, this message translates to:
  /// **'Pdf'**
  String get contributionsPdf;

  /// No description provided for @contributionsCsv.
  ///
  /// In en, this message translates to:
  /// **'Csv'**
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
  /// **'Confirmed total'**
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
  /// **'Preview'**
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
  /// **'How much to contribute?'**
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
  /// **'Launching MoMo'**
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
  /// **'Payment confirmed'**
  String get contributionsPaymentConfirmedTitle;

  /// No description provided for @contributionsPaymentConfirmedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your contribution of {amount} has been verified and recorded.'**
  String contributionsPaymentConfirmedMessage(String amount);

  /// No description provided for @contributionsPaymentFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get contributionsPaymentFailedTitle;

  /// No description provided for @contributionsPaymentFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'The payment could not be verified. Check your MoMo balance and try again, or contact support.'**
  String get contributionsPaymentFailedMessage;

  /// No description provided for @contributionsPaymentProcessingTitle.
  ///
  /// In en, this message translates to:
  /// **'Still processing'**
  String get contributionsPaymentProcessingTitle;

  /// No description provided for @contributionsPaymentProcessingMessage.
  ///
  /// In en, this message translates to:
  /// **'Your payment is taking longer than usual. Check the Group ledger for your updated status. If you completed the MoMo transfer, it will appear shortly.'**
  String get contributionsPaymentProcessingMessage;

  /// No description provided for @contributionsRecordFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not record'**
  String get contributionsRecordFailedTitle;

  /// No description provided for @contributionsRecordFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'The MoMo dialer was launched but the contribution could not be saved. Return to the Group and try again.'**
  String get contributionsRecordFailedMessage;

  /// No description provided for @contributionsAwaitingPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Awaiting payment'**
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
  /// **'Verified'**
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
  /// **'Enable MoMo SMS sync'**
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
  /// **'Not now'**
  String get contributionsNotNowUpper;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get settingsRoleAdmin;

  /// No description provided for @settingsRoleSupporter.
  ///
  /// In en, this message translates to:
  /// **'Supporter'**
  String get settingsRoleSupporter;

  /// No description provided for @settingsMembershipDetails.
  ///
  /// In en, this message translates to:
  /// **'Membership details'**
  String get settingsMembershipDetails;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsSectionPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsSectionPreferences;

  /// No description provided for @settingsSectionSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsSectionSupport;

  /// No description provided for @settingsEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get settingsEditProfile;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsHelpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & support'**
  String get settingsHelpSupport;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsRefreshingTitle.
  ///
  /// In en, this message translates to:
  /// **'Refreshing settings'**
  String get settingsRefreshingTitle;

  /// No description provided for @settingsRefreshingMessage.
  ///
  /// In en, this message translates to:
  /// **'Current account and appearance settings stay available.'**
  String get settingsRefreshingMessage;

  /// No description provided for @settingsOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline settings'**
  String get settingsOfflineTitle;

  /// No description provided for @settingsOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Offline. Account and appearance settings remain available. Reconnect for support.'**
  String get settingsOfflineMessage;

  /// No description provided for @settingsHelpUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Help and support unavailable'**
  String get settingsHelpUnavailableTitle;

  /// No description provided for @settingsSupportContactUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Support contact unavailable'**
  String get settingsSupportContactUnavailableTitle;

  /// No description provided for @settingsSupportContactUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Other settings still work. Refresh to check again.'**
  String get settingsSupportContactUnavailableMessage;

  /// No description provided for @settingsLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading settings'**
  String get settingsLoadingTitle;

  /// No description provided for @settingsLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Checking support availability.'**
  String get settingsLoadingMessage;

  /// No description provided for @settingsAccessLimitedTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings access limited'**
  String get settingsAccessLimitedTitle;

  /// No description provided for @settingsAccessLimitedMessage.
  ///
  /// In en, this message translates to:
  /// **'Support could not be verified. Other settings still work.'**
  String get settingsAccessLimitedMessage;

  /// No description provided for @settingsChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings changed'**
  String get settingsChangedTitle;

  /// No description provided for @settingsChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh to load the current support settings.'**
  String get settingsChangedMessage;

  /// No description provided for @settingsSecurityTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings security check timed out'**
  String get settingsSecurityTimeoutTitle;

  /// No description provided for @settingsSecurityTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and refresh.'**
  String get settingsSecurityTimeoutMessage;

  /// No description provided for @settingsSupportLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load support settings'**
  String get settingsSupportLoadFailedTitle;

  /// No description provided for @settingsSupportLoadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Account and appearance settings remain available.'**
  String get settingsSupportLoadFailedMessage;

  /// No description provided for @settingsChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get settingsChecking;

  /// No description provided for @settingsConnectionRequired.
  ///
  /// In en, this message translates to:
  /// **'Connection required'**
  String get settingsConnectionRequired;

  /// No description provided for @settingsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get settingsUnavailable;

  /// No description provided for @settingsNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get settingsNotConfigured;

  /// No description provided for @settingsStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Status unavailable'**
  String get settingsStatusUnavailable;

  /// No description provided for @settingsThemeUseDevice.
  ///
  /// In en, this message translates to:
  /// **'Use device setting'**
  String get settingsThemeUseDevice;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsAppearanceMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose a theme or follow your device setting.'**
  String get settingsAppearanceMessage;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsSupportNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Support contact is not configured.'**
  String get settingsSupportNotConfigured;

  /// No description provided for @settingsSupportGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, I need help with {app}.'**
  String settingsSupportGreeting(String app);

  /// No description provided for @settingsWhatsAppFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open WhatsApp.'**
  String get settingsWhatsAppFailed;

  /// No description provided for @settingsDeleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'DELETE your account?'**
  String get settingsDeleteAccountTitle;

  /// No description provided for @settingsDeleteAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'Permanently deletes your profile, FET, badges, and history. Cannot be undone.'**
  String get settingsDeleteAccountMessage;

  /// No description provided for @settingsDeleteAccountConfirmPrompt.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm'**
  String get settingsDeleteAccountConfirmPrompt;

  /// No description provided for @settingsDeleteAccountConfirmValue.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get settingsDeleteAccountConfirmValue;

  /// No description provided for @settingsCancelUpper.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsCancelUpper;

  /// No description provided for @settingsDeletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get settingsDeletePermanently;

  /// No description provided for @settingsNotificationPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Stay with the club'**
  String get settingsNotificationPermissionTitle;

  /// No description provided for @settingsNotificationPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Get notified for matches, contributions, FET milestones, and club news.'**
  String get settingsNotificationPermissionMessage;

  /// No description provided for @settingsMatchAlerts.
  ///
  /// In en, this message translates to:
  /// **'Match alerts before kickoff'**
  String get settingsMatchAlerts;

  /// No description provided for @settingsContributionUpdates.
  ///
  /// In en, this message translates to:
  /// **'Contribution and ticket updates'**
  String get settingsContributionUpdates;

  /// No description provided for @settingsFetMilestones.
  ///
  /// In en, this message translates to:
  /// **'FET milestones and challenge drops'**
  String get settingsFetMilestones;

  /// No description provided for @settingsEnableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get settingsEnableNotifications;

  /// No description provided for @settingsMaybeLaterUpper.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get settingsMaybeLaterUpper;

  /// No description provided for @settingsSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get settingsSignOutTitle;

  /// No description provided for @settingsSignOutMessage.
  ///
  /// In en, this message translates to:
  /// **'Your profile and FET are saved. Sign back in anytime.'**
  String get settingsSignOutMessage;

  /// No description provided for @settingsStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get settingsStay;

  /// No description provided for @settingsSignOutOthersTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out other devices?'**
  String get settingsSignOutOthersTitle;

  /// No description provided for @settingsSignOutOthersMessage.
  ///
  /// In en, this message translates to:
  /// **'This device stays signed in. Other sessions are revoked.'**
  String get settingsSignOutOthersMessage;

  /// No description provided for @settingsSignOutOthersAction.
  ///
  /// In en, this message translates to:
  /// **'Sign out others'**
  String get settingsSignOutOthersAction;

  /// No description provided for @settingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsCancel;

  /// No description provided for @editProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get editProfileUpdated;

  /// No description provided for @editProfileServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Profile service is temporarily unavailable.'**
  String get editProfileServiceUnavailable;

  /// No description provided for @editProfileLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading profile'**
  String get editProfileLoadingTitle;

  /// No description provided for @editProfileLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Checking your saved profile.'**
  String get editProfileLoadingMessage;

  /// No description provided for @editProfileAccessLimitedTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile access limited'**
  String get editProfileAccessLimitedTitle;

  /// No description provided for @editProfileAccessLimitedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your profile could not be verified. Sign in again.'**
  String get editProfileAccessLimitedMessage;

  /// No description provided for @editProfileSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get editProfileSignInAgain;

  /// No description provided for @editProfileChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile changed'**
  String get editProfileChangedTitle;

  /// No description provided for @editProfileChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh to load the current profile before editing.'**
  String get editProfileChangedMessage;

  /// No description provided for @editProfileRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get editProfileRefresh;

  /// No description provided for @editProfileSecurityTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile security check timed out'**
  String get editProfileSecurityTimeoutTitle;

  /// No description provided for @editProfileSecurityTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and refresh.'**
  String get editProfileSecurityTimeoutMessage;

  /// No description provided for @editProfileLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load profile'**
  String get editProfileLoadFailedTitle;

  /// No description provided for @editProfileLoadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your profile is still safe. Try again.'**
  String get editProfileLoadFailedMessage;

  /// No description provided for @editProfileTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get editProfileTryAgain;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get editProfileTitle;

  /// No description provided for @editProfileSavingTitle.
  ///
  /// In en, this message translates to:
  /// **'Saving profile'**
  String get editProfileSavingTitle;

  /// No description provided for @editProfileSavingMessage.
  ///
  /// In en, this message translates to:
  /// **'Your nickname stays visible while the save is confirmed.'**
  String get editProfileSavingMessage;

  /// No description provided for @editProfileRefreshingTitle.
  ///
  /// In en, this message translates to:
  /// **'Refreshing profile'**
  String get editProfileRefreshingTitle;

  /// No description provided for @editProfileRefreshingMessage.
  ///
  /// In en, this message translates to:
  /// **'Your saved profile stays visible.'**
  String get editProfileRefreshingMessage;

  /// No description provided for @editProfileEditingUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile editing unavailable'**
  String get editProfileEditingUnavailableTitle;

  /// No description provided for @editProfileEditingUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Your saved profile stays visible.'**
  String get editProfileEditingUnavailableMessage;

  /// No description provided for @editProfileChangedElsewhereTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile changed elsewhere'**
  String get editProfileChangedElsewhereTitle;

  /// No description provided for @editProfileChangedElsewhereMessage.
  ///
  /// In en, this message translates to:
  /// **'Latest nickname loaded. Review before saving.'**
  String get editProfileChangedElsewhereMessage;

  /// No description provided for @editProfileSaveUnconfirmedTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile save not confirmed'**
  String get editProfileSaveUnconfirmedTitle;

  /// No description provided for @editProfileSaveUnconfirmedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh your profile before trying again.'**
  String get editProfileSaveUnconfirmedMessage;

  /// No description provided for @editProfileSaveFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile could not be saved'**
  String get editProfileSaveFailedTitle;

  /// No description provided for @editProfileSaveFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your nickname draft is still here.'**
  String get editProfileSaveFailedMessage;

  /// No description provided for @editProfileOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline profile'**
  String get editProfileOfflineTitle;

  /// No description provided for @editProfileOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Offline. Your saved profile stays visible. Reconnect to edit.'**
  String get editProfileOfflineMessage;

  /// No description provided for @editProfileUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile unavailable'**
  String get editProfileUnavailableTitle;

  /// No description provided for @editProfileUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Your profile is unavailable. Sign in again to recover your account.'**
  String get editProfileUnavailableMessage;

  /// No description provided for @editProfileAlias.
  ///
  /// In en, this message translates to:
  /// **'#{alias}'**
  String editProfileAlias(String alias);

  /// No description provided for @editProfileNicknameLabel.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get editProfileNicknameLabel;

  /// No description provided for @editProfileNicknameHint.
  ///
  /// In en, this message translates to:
  /// **'Optional supporter nickname'**
  String get editProfileNicknameHint;

  /// No description provided for @editProfileSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get editProfileSaving;

  /// No description provided for @editProfileSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get editProfileSaveChanges;

  /// No description provided for @editProfileDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get editProfileDeleteAccount;

  /// No description provided for @editProfileDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete this supporter account'**
  String get editProfileDeleteHint;

  /// No description provided for @editProfileDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Account could not be deleted. Try again.'**
  String get editProfileDeleteFailed;

  /// No description provided for @editProfileLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get editProfileLanguageEnglish;

  /// No description provided for @editProfileLanguageFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get editProfileLanguageFrench;

  /// No description provided for @editProfileLanguageKinyarwanda.
  ///
  /// In en, this message translates to:
  /// **'Kinyarwanda'**
  String get editProfileLanguageKinyarwanda;

  /// No description provided for @notificationPreferencesConnectionRestoredReview.
  ///
  /// In en, this message translates to:
  /// **'Connection restored. Review your kept changes, then save.'**
  String get notificationPreferencesConnectionRestoredReview;

  /// No description provided for @notificationPreferencesConnectionRestoredRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Connection restored. Refreshing preferences.'**
  String get notificationPreferencesConnectionRestoredRefreshing;

  /// No description provided for @notificationPreferencesConnectBeforeChanging.
  ///
  /// In en, this message translates to:
  /// **'Connect before changing notification delivery on this device.'**
  String get notificationPreferencesConnectBeforeChanging;

  /// No description provided for @notificationPreferencesDeviceTurnedOff.
  ///
  /// In en, this message translates to:
  /// **'Device notifications were turned off. Save to update your account preference.'**
  String get notificationPreferencesDeviceTurnedOff;

  /// No description provided for @notificationPreferencesPermissionGranted.
  ///
  /// In en, this message translates to:
  /// **'Permission granted on this device. Save to enable alerts on your account.'**
  String get notificationPreferencesPermissionGranted;

  /// No description provided for @notificationPreferencesBlocked.
  ///
  /// In en, this message translates to:
  /// **'Notifications blocked. Enable in device settings.'**
  String get notificationPreferencesBlocked;

  /// No description provided for @notificationPreferencesPermissionPending.
  ///
  /// In en, this message translates to:
  /// **'Notification permission is still pending.'**
  String get notificationPreferencesPermissionPending;

  /// No description provided for @notificationPreferencesPushUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Push unavailable in this build.'**
  String get notificationPreferencesPushUnavailable;

  /// No description provided for @notificationPreferencesDraftKeptConnect.
  ///
  /// In en, this message translates to:
  /// **'Your changes are kept. Connect before saving.'**
  String get notificationPreferencesDraftKeptConnect;

  /// No description provided for @notificationPreferencesSaved.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences saved.'**
  String get notificationPreferencesSaved;

  /// No description provided for @notificationPreferencesChangedElsewhereLoading.
  ///
  /// In en, this message translates to:
  /// **'Preferences changed elsewhere. The latest version is loading; review it before saving again.'**
  String get notificationPreferencesChangedElsewhereLoading;

  /// No description provided for @notificationPreferencesChangeNotPermitted.
  ///
  /// In en, this message translates to:
  /// **'Notification changes are not permitted for this account.'**
  String get notificationPreferencesChangeNotPermitted;

  /// No description provided for @notificationPreferencesChangedRefresh.
  ///
  /// In en, this message translates to:
  /// **'Preferences changed elsewhere. Refresh before saving again.'**
  String get notificationPreferencesChangedRefresh;

  /// No description provided for @notificationPreferencesSaveUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Notification save was not confirmed. Refresh before trying again.'**
  String get notificationPreferencesSaveUnconfirmed;

  /// No description provided for @notificationPreferencesSaveFailedDraftKept.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences could not be saved. Your draft is kept.'**
  String get notificationPreferencesSaveFailedDraftKept;

  /// No description provided for @notificationPreferencesRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing notification preferences.'**
  String get notificationPreferencesRefreshing;

  /// No description provided for @notificationPreferencesLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading notifications'**
  String get notificationPreferencesLoadingTitle;

  /// No description provided for @notificationPreferencesLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Checking your saved delivery preference.'**
  String get notificationPreferencesLoadingMessage;

  /// No description provided for @notificationPreferencesOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications are offline'**
  String get notificationPreferencesOfflineTitle;

  /// No description provided for @notificationPreferencesOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Connect to load your saved notification preference.'**
  String get notificationPreferencesOfflineMessage;

  /// No description provided for @notificationPreferencesUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences unavailable'**
  String get notificationPreferencesUnavailableTitle;

  /// No description provided for @notificationPreferencesUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage notification delivery.'**
  String get notificationPreferencesUnavailableMessage;

  /// No description provided for @notificationPreferencesAccessLimitedTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification access limited'**
  String get notificationPreferencesAccessLimitedTitle;

  /// No description provided for @notificationPreferencesAccessLimitedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your preferences could not be verified. Sign in again.'**
  String get notificationPreferencesAccessLimitedMessage;

  /// No description provided for @notificationPreferencesChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification settings changed'**
  String get notificationPreferencesChangedTitle;

  /// No description provided for @notificationPreferencesChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh to load the current preference before editing.'**
  String get notificationPreferencesChangedMessage;

  /// No description provided for @notificationPreferencesSecurityTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification security check timed out'**
  String get notificationPreferencesSecurityTimeoutTitle;

  /// No description provided for @notificationPreferencesSecurityTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and refresh.'**
  String get notificationPreferencesSecurityTimeoutMessage;

  /// No description provided for @notificationPreferencesLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load notification settings.'**
  String get notificationPreferencesLoadFailedTitle;

  /// No description provided for @notificationPreferencesLoadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your saved preference is still safe. Try again.'**
  String get notificationPreferencesLoadFailedMessage;

  /// No description provided for @notificationPreferencesSavingTitle.
  ///
  /// In en, this message translates to:
  /// **'Saving notification preferences'**
  String get notificationPreferencesSavingTitle;

  /// No description provided for @notificationPreferencesSavingMessage.
  ///
  /// In en, this message translates to:
  /// **'Your choices stay visible while the save is confirmed.'**
  String get notificationPreferencesSavingMessage;

  /// No description provided for @notificationPreferencesRefreshingTitle.
  ///
  /// In en, this message translates to:
  /// **'Refreshing notification preferences'**
  String get notificationPreferencesRefreshingTitle;

  /// No description provided for @notificationPreferencesRefreshingMessage.
  ///
  /// In en, this message translates to:
  /// **'Your saved delivery preference stays visible.'**
  String get notificationPreferencesRefreshingMessage;

  /// No description provided for @notificationPreferencesEditingUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification editing unavailable'**
  String get notificationPreferencesEditingUnavailableTitle;

  /// No description provided for @notificationPreferencesEditingUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Your saved preference stays visible.'**
  String get notificationPreferencesEditingUnavailableMessage;

  /// No description provided for @notificationPreferencesChangedElsewhereTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification settings changed elsewhere'**
  String get notificationPreferencesChangedElsewhereTitle;

  /// No description provided for @notificationPreferencesChangedElsewhereMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh and review the latest preference.'**
  String get notificationPreferencesChangedElsewhereMessage;

  /// No description provided for @notificationPreferencesSaveNotConfirmedTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification save not confirmed'**
  String get notificationPreferencesSaveNotConfirmedTitle;

  /// No description provided for @notificationPreferencesSaveNotConfirmedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh before trying again. Your draft is kept.'**
  String get notificationPreferencesSaveNotConfirmedMessage;

  /// No description provided for @notificationPreferencesSaveFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences could not be saved'**
  String get notificationPreferencesSaveFailedTitle;

  /// No description provided for @notificationPreferencesSaveFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your draft is still here.'**
  String get notificationPreferencesSaveFailedMessage;

  /// No description provided for @notificationPreferencesSavedSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved notification settings'**
  String get notificationPreferencesSavedSettingsTitle;

  /// No description provided for @notificationPreferencesSavedSettingsMessage.
  ///
  /// In en, this message translates to:
  /// **'Values may be out of date. Reconnect before changing or saving.'**
  String get notificationPreferencesSavedSettingsMessage;

  /// No description provided for @notificationPreferencesCheckingPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Checking device permissions'**
  String get notificationPreferencesCheckingPermissionsTitle;

  /// No description provided for @notificationPreferencesCheckingPermissionsMessage.
  ///
  /// In en, this message translates to:
  /// **'Delivery controls will be available after this check.'**
  String get notificationPreferencesCheckingPermissionsMessage;

  /// No description provided for @notificationPreferencesDeviceAlertsUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Device alerts unavailable'**
  String get notificationPreferencesDeviceAlertsUnavailableTitle;

  /// No description provided for @notificationPreferencesDeviceAlertsUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Push delivery is not configured in this build.'**
  String get notificationPreferencesDeviceAlertsUnavailableMessage;

  /// No description provided for @notificationPreferencesPermissionEnabled.
  ///
  /// In en, this message translates to:
  /// **'System notifications are enabled on this device.'**
  String get notificationPreferencesPermissionEnabled;

  /// No description provided for @notificationPreferencesPermissionBlocked.
  ///
  /// In en, this message translates to:
  /// **'System notifications are blocked at the device level.'**
  String get notificationPreferencesPermissionBlocked;

  /// No description provided for @notificationPreferencesPermissionNotRequested.
  ///
  /// In en, this message translates to:
  /// **'Permission not yet requested.'**
  String get notificationPreferencesPermissionNotRequested;

  /// No description provided for @notificationPreferencesPermissionNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Push not configured in this build.'**
  String get notificationPreferencesPermissionNotConfigured;

  /// No description provided for @notificationPreferencesPermissionChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking device notification permissions…'**
  String get notificationPreferencesPermissionChecking;

  /// No description provided for @notificationPreferencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationPreferencesTitle;

  /// No description provided for @notificationPreferencesDeliverySection.
  ///
  /// In en, this message translates to:
  /// **'Notification delivery'**
  String get notificationPreferencesDeliverySection;

  /// No description provided for @notificationPreferencesAlertsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Alerts enabled.'**
  String get notificationPreferencesAlertsEnabled;

  /// No description provided for @notificationPreferencesEnableAlertsDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable alerts for matches, receipts & updates.'**
  String get notificationPreferencesEnableAlertsDescription;

  /// No description provided for @notificationPreferencesDeviceDelivery.
  ///
  /// In en, this message translates to:
  /// **'Device alert delivery'**
  String get notificationPreferencesDeviceDelivery;

  /// No description provided for @notificationPreferencesConnectionRequiredUpper.
  ///
  /// In en, this message translates to:
  /// **'Connection required'**
  String get notificationPreferencesConnectionRequiredUpper;

  /// No description provided for @notificationPreferencesDisableAlerts.
  ///
  /// In en, this message translates to:
  /// **'Disable alerts'**
  String get notificationPreferencesDisableAlerts;

  /// No description provided for @notificationPreferencesEnableAlerts.
  ///
  /// In en, this message translates to:
  /// **'Enable alerts'**
  String get notificationPreferencesEnableAlerts;

  /// No description provided for @notificationPreferencesDeliveryModel.
  ///
  /// In en, this message translates to:
  /// **'Delivery model'**
  String get notificationPreferencesDeliveryModel;

  /// No description provided for @notificationPreferencesFullStream.
  ///
  /// In en, this message translates to:
  /// **'When alerts are enabled, this release delivers the full {app} notification stream available for your account.'**
  String notificationPreferencesFullStream(String app);

  /// No description provided for @notificationPreferencesPerCategory.
  ///
  /// In en, this message translates to:
  /// **'Per-category tuning is not configurable on this build yet, so this switch controls the entire device delivery state.'**
  String get notificationPreferencesPerCategory;

  /// No description provided for @notificationPreferencesSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get notificationPreferencesSave;

  /// No description provided for @privacySettingsConnectionRestoredReview.
  ///
  /// In en, this message translates to:
  /// **'Connection restored. Review your kept changes, then save.'**
  String get privacySettingsConnectionRestoredReview;

  /// No description provided for @privacySettingsConnectionRestoredRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Connection restored. Refreshing privacy settings.'**
  String get privacySettingsConnectionRestoredRefreshing;

  /// No description provided for @privacySettingsChangeReady.
  ///
  /// In en, this message translates to:
  /// **'Privacy change ready to save.'**
  String get privacySettingsChangeReady;

  /// No description provided for @privacySettingsDraftKeptConnect.
  ///
  /// In en, this message translates to:
  /// **'Your changes are kept. Connect before saving.'**
  String get privacySettingsDraftKeptConnect;

  /// No description provided for @privacySettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Privacy settings saved.'**
  String get privacySettingsSaved;

  /// No description provided for @privacySettingsChangedElsewhereLoading.
  ///
  /// In en, this message translates to:
  /// **'Privacy settings changed elsewhere. The latest version is loading; review it before saving again.'**
  String get privacySettingsChangedElsewhereLoading;

  /// No description provided for @privacySettingsChangeNotPermitted.
  ///
  /// In en, this message translates to:
  /// **'Privacy changes are not permitted for this account.'**
  String get privacySettingsChangeNotPermitted;

  /// No description provided for @privacySettingsChangedRefresh.
  ///
  /// In en, this message translates to:
  /// **'Privacy settings changed elsewhere. Refresh before saving again.'**
  String get privacySettingsChangedRefresh;

  /// No description provided for @privacySettingsSaveUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Privacy save was not confirmed. Refresh before trying again.'**
  String get privacySettingsSaveUnconfirmed;

  /// No description provided for @privacySettingsSaveFailedDraftKept.
  ///
  /// In en, this message translates to:
  /// **'Privacy settings could not be saved. Your draft is kept.'**
  String get privacySettingsSaveFailedDraftKept;

  /// No description provided for @privacySettingsRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing privacy settings.'**
  String get privacySettingsRefreshing;

  /// No description provided for @privacySettingsConnectBeforeSigningOut.
  ///
  /// In en, this message translates to:
  /// **'Connect before signing out other devices.'**
  String get privacySettingsConnectBeforeSigningOut;

  /// No description provided for @privacySettingsSessionsSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Other sessions were signed out.'**
  String get privacySettingsSessionsSignedOut;

  /// No description provided for @privacySettingsSessionsSignOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sign out other devices. Try again.'**
  String get privacySettingsSessionsSignOutFailed;

  /// No description provided for @privacySettingsSessionSecurityTimeout.
  ///
  /// In en, this message translates to:
  /// **'Session security check timed out. Try again.'**
  String get privacySettingsSessionSecurityTimeout;

  /// No description provided for @privacySettingsSmsAccessRequired.
  ///
  /// In en, this message translates to:
  /// **'SMS sync stays off until you grant Android SMS access for MoMo verification.'**
  String get privacySettingsSmsAccessRequired;

  /// No description provided for @privacySettingsEnableMomoSmsTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable MoMo SMS sync'**
  String get privacySettingsEnableMomoSmsTitle;

  /// No description provided for @privacySettingsMomoSmsDisclosure.
  ///
  /// In en, this message translates to:
  /// **'The app reads only approved Mobile Money verification SMS on this device to match contribution payments. It cannot access other messages.'**
  String get privacySettingsMomoSmsDisclosure;

  /// No description provided for @privacySettingsNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get privacySettingsNotNow;

  /// No description provided for @privacySettingsContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get privacySettingsContinue;

  /// No description provided for @privacySettingsLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading privacy settings'**
  String get privacySettingsLoadingTitle;

  /// No description provided for @privacySettingsLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Checking your saved privacy choices.'**
  String get privacySettingsLoadingMessage;

  /// No description provided for @privacySettingsOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy settings are offline'**
  String get privacySettingsOfflineTitle;

  /// No description provided for @privacySettingsOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Connect to load your saved privacy choices.'**
  String get privacySettingsOfflineMessage;

  /// No description provided for @privacySettingsUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy settings unavailable'**
  String get privacySettingsUnavailableTitle;

  /// No description provided for @privacySettingsUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Sign in to review and manage your privacy choices.'**
  String get privacySettingsUnavailableMessage;

  /// No description provided for @privacySettingsAccessLimitedTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy access limited'**
  String get privacySettingsAccessLimitedTitle;

  /// No description provided for @privacySettingsAccessLimitedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your privacy settings could not be verified. Sign in again.'**
  String get privacySettingsAccessLimitedMessage;

  /// No description provided for @privacySettingsChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy settings changed'**
  String get privacySettingsChangedTitle;

  /// No description provided for @privacySettingsChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh to load the current choices before editing.'**
  String get privacySettingsChangedMessage;

  /// No description provided for @privacySettingsSecurityTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy security check timed out'**
  String get privacySettingsSecurityTimeoutTitle;

  /// No description provided for @privacySettingsSecurityTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and refresh.'**
  String get privacySettingsSecurityTimeoutMessage;

  /// No description provided for @privacySettingsLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load privacy settings.'**
  String get privacySettingsLoadFailedTitle;

  /// No description provided for @privacySettingsLoadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your saved choices are still safe. Try again.'**
  String get privacySettingsLoadFailedMessage;

  /// No description provided for @privacySettingsSavingTitle.
  ///
  /// In en, this message translates to:
  /// **'Saving privacy settings'**
  String get privacySettingsSavingTitle;

  /// No description provided for @privacySettingsSavingMessage.
  ///
  /// In en, this message translates to:
  /// **'Your choices stay visible while the save is confirmed.'**
  String get privacySettingsSavingMessage;

  /// No description provided for @privacySettingsRefreshingTitle.
  ///
  /// In en, this message translates to:
  /// **'Refreshing privacy settings'**
  String get privacySettingsRefreshingTitle;

  /// No description provided for @privacySettingsRefreshingMessage.
  ///
  /// In en, this message translates to:
  /// **'Your saved choices stay visible.'**
  String get privacySettingsRefreshingMessage;

  /// No description provided for @privacySettingsEditingUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy editing unavailable'**
  String get privacySettingsEditingUnavailableTitle;

  /// No description provided for @privacySettingsEditingUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Your saved choices stay visible.'**
  String get privacySettingsEditingUnavailableMessage;

  /// No description provided for @privacySettingsChangedElsewhereTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy settings changed elsewhere'**
  String get privacySettingsChangedElsewhereTitle;

  /// No description provided for @privacySettingsChangedElsewhereMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh and review the latest choices.'**
  String get privacySettingsChangedElsewhereMessage;

  /// No description provided for @privacySettingsSaveNotConfirmedTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy save not confirmed'**
  String get privacySettingsSaveNotConfirmedTitle;

  /// No description provided for @privacySettingsSaveNotConfirmedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh before trying again. Your draft is kept.'**
  String get privacySettingsSaveNotConfirmedMessage;

  /// No description provided for @privacySettingsSaveFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy settings could not be saved'**
  String get privacySettingsSaveFailedTitle;

  /// No description provided for @privacySettingsSaveFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your draft is still here.'**
  String get privacySettingsSaveFailedMessage;

  /// No description provided for @privacySettingsSavedSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved privacy settings'**
  String get privacySettingsSavedSettingsTitle;

  /// No description provided for @privacySettingsSavedSettingsMessage.
  ///
  /// In en, this message translates to:
  /// **'Values may be out of date. Reconnect before changing or saving.'**
  String get privacySettingsSavedSettingsMessage;

  /// No description provided for @privacySettingsEditingUnavailableBuildMessage.
  ///
  /// In en, this message translates to:
  /// **'Your saved choices remain visible in this build.'**
  String get privacySettingsEditingUnavailableBuildMessage;

  /// No description provided for @privacySettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacySettingsTitle;

  /// No description provided for @privacySettingsControls.
  ///
  /// In en, this message translates to:
  /// **'Privacy controls'**
  String get privacySettingsControls;

  /// No description provided for @privacySettingsControlsDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose whether to share coarse, anonymous task events. Queries, contacts, account IDs, codes, messages, and exact payment values are never included.'**
  String get privacySettingsControlsDescription;

  /// No description provided for @privacySettingsMomoSmsSync.
  ///
  /// In en, this message translates to:
  /// **'MoMo SMS sync'**
  String get privacySettingsMomoSmsSync;

  /// No description provided for @privacySettingsMomoSmsSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Match approved Mobile Money verification SMS for faster contribution checks.'**
  String get privacySettingsMomoSmsSyncDescription;

  /// No description provided for @privacySettingsShareAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Share anonymous usage analytics'**
  String get privacySettingsShareAnalytics;

  /// No description provided for @privacySettingsShareAnalyticsDescription.
  ///
  /// In en, this message translates to:
  /// **'Help improve search, tickets, contributions, Fan Zone, and recovery flows.'**
  String get privacySettingsShareAnalyticsDescription;

  /// No description provided for @privacySettingsAnalyticsFailClosed.
  ///
  /// In en, this message translates to:
  /// **'Analytics stays off unless you opt in and the signed release has an approved analytics configuration.'**
  String get privacySettingsAnalyticsFailClosed;

  /// No description provided for @privacySettingsNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No changes to save'**
  String get privacySettingsNoChanges;

  /// No description provided for @privacySettingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save privacy settings'**
  String get privacySettingsSave;

  /// No description provided for @privacySettingsYourData.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get privacySettingsYourData;

  /// No description provided for @privacySettingsExportDescription.
  ///
  /// In en, this message translates to:
  /// **'Request an account export through a configured support channel.'**
  String get privacySettingsExportDescription;

  /// No description provided for @privacySettingsExportAction.
  ///
  /// In en, this message translates to:
  /// **'Request data export'**
  String get privacySettingsExportAction;

  /// No description provided for @privacySettingsExportWhatsAppMessage.
  ///
  /// In en, this message translates to:
  /// **'Data export request for {app}. Please send me a copy of my account data.'**
  String privacySettingsExportWhatsAppMessage(String app);

  /// No description provided for @privacySettingsExportEmailSubject.
  ///
  /// In en, this message translates to:
  /// **'{app} data export request'**
  String privacySettingsExportEmailSubject(String app);

  /// No description provided for @privacySettingsExportEmailBody.
  ///
  /// In en, this message translates to:
  /// **'Please send me a copy of my account data.'**
  String get privacySettingsExportEmailBody;

  /// No description provided for @privacySettingsMailFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open your mail app.'**
  String get privacySettingsMailFailed;

  /// No description provided for @privacySettingsOpenPolicy.
  ///
  /// In en, this message translates to:
  /// **'Open privacy policy'**
  String get privacySettingsOpenPolicy;

  /// No description provided for @privacySettingsPolicyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy unavailable'**
  String get privacySettingsPolicyUnavailable;

  /// No description provided for @privacySettingsPolicyNotAvailableYet.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy is not available yet.'**
  String get privacySettingsPolicyNotAvailableYet;

  /// No description provided for @privacySettingsActiveSessions.
  ///
  /// In en, this message translates to:
  /// **'Active sessions'**
  String get privacySettingsActiveSessions;

  /// No description provided for @privacySettingsActiveSessionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Revoke other active sessions linked to your account.'**
  String get privacySettingsActiveSessionsDescription;

  /// No description provided for @privacySettingsSignOutOtherDevices.
  ///
  /// In en, this message translates to:
  /// **'Sign out other devices'**
  String get privacySettingsSignOutOtherDevices;

  /// No description provided for @adminLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading admin workspace'**
  String get adminLoadingTitle;

  /// No description provided for @adminLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Checking current club operations.'**
  String get adminLoadingMessage;

  /// No description provided for @adminClubAdmin.
  ///
  /// In en, this message translates to:
  /// **'Club admin'**
  String get adminClubAdmin;

  /// No description provided for @adminExit.
  ///
  /// In en, this message translates to:
  /// **'Exit admin'**
  String get adminExit;

  /// No description provided for @adminCommandCenter.
  ///
  /// In en, this message translates to:
  /// **'Command center'**
  String get adminCommandCenter;

  /// No description provided for @adminTotalUsers.
  ///
  /// In en, this message translates to:
  /// **'Total users'**
  String get adminTotalUsers;

  /// No description provided for @adminActiveGroups.
  ///
  /// In en, this message translates to:
  /// **'Active groups'**
  String get adminActiveGroups;

  /// No description provided for @adminTransactionsToday.
  ///
  /// In en, this message translates to:
  /// **'Tx today'**
  String get adminTransactionsToday;

  /// No description provided for @adminTicketsSold.
  ///
  /// In en, this message translates to:
  /// **'Tickets sold'**
  String get adminTicketsSold;

  /// No description provided for @adminQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get adminQuickActions;

  /// No description provided for @adminManageCms.
  ///
  /// In en, this message translates to:
  /// **'Manage CMS'**
  String get adminManageCms;

  /// No description provided for @adminManageCmsDescription.
  ///
  /// In en, this message translates to:
  /// **'News articles, banners, and content surfaces'**
  String get adminManageCmsDescription;

  /// No description provided for @adminCreateMatch.
  ///
  /// In en, this message translates to:
  /// **'Create match'**
  String get adminCreateMatch;

  /// No description provided for @adminCreateMatchDescription.
  ///
  /// In en, this message translates to:
  /// **'Fixture setup, zoning, and ticket controls'**
  String get adminCreateMatchDescription;

  /// No description provided for @adminViewContributions.
  ///
  /// In en, this message translates to:
  /// **'View contributions'**
  String get adminViewContributions;

  /// No description provided for @adminViewContributionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Monitor club and community fundraising'**
  String get adminViewContributionsDescription;

  /// No description provided for @adminSendNotification.
  ///
  /// In en, this message translates to:
  /// **'Send notification'**
  String get adminSendNotification;

  /// No description provided for @adminSendNotificationDescription.
  ///
  /// In en, this message translates to:
  /// **'Tier, group, and all-fan push delivery'**
  String get adminSendNotificationDescription;

  /// No description provided for @adminSettleFixtures.
  ///
  /// In en, this message translates to:
  /// **'Settle fixtures'**
  String get adminSettleFixtures;

  /// No description provided for @adminSettleFixturesDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter results and grade prediction markets'**
  String get adminSettleFixturesDescription;

  /// No description provided for @adminManageCompetitions.
  ///
  /// In en, this message translates to:
  /// **'Manage competitions'**
  String get adminManageCompetitions;

  /// No description provided for @adminManageCompetitionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Add, edit, and toggle supported leagues and cups'**
  String get adminManageCompetitionsDescription;

  /// No description provided for @adminSmsSyncMonitor.
  ///
  /// In en, this message translates to:
  /// **'SMS sync monitor'**
  String get adminSmsSyncMonitor;

  /// No description provided for @adminSmsSyncMonitorDescription.
  ///
  /// In en, this message translates to:
  /// **'MoMo SMS ingestion pipeline health'**
  String get adminSmsSyncMonitorDescription;

  /// No description provided for @adminFeatureManager.
  ///
  /// In en, this message translates to:
  /// **'Feature manager'**
  String get adminFeatureManager;

  /// No description provided for @adminFeatureManagerDashboardDescription.
  ///
  /// In en, this message translates to:
  /// **'Toggle features, visibility, and scheduling'**
  String get adminFeatureManagerDashboardDescription;

  /// No description provided for @adminRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get adminRecentActivity;

  /// No description provided for @adminRecentActivityUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Recent activity unavailable'**
  String get adminRecentActivityUnavailable;

  /// No description provided for @adminRecentActivityUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Dashboard totals are current. Refresh to retry the activity feed.'**
  String get adminRecentActivityUnavailableMessage;

  /// No description provided for @adminNoRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'No recent activity'**
  String get adminNoRecentActivity;

  /// No description provided for @adminNoRecentActivityMessage.
  ///
  /// In en, this message translates to:
  /// **'Current totals are confirmed. New club activity will appear here.'**
  String get adminNoRecentActivityMessage;

  /// No description provided for @adminWorkspaceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Admin workspace unavailable'**
  String get adminWorkspaceUnavailable;

  /// No description provided for @adminMobileDisabledMessage.
  ///
  /// In en, this message translates to:
  /// **'Mobile administration is disabled for this controlled build.'**
  String get adminMobileDisabledMessage;

  /// No description provided for @adminBackToSettings.
  ///
  /// In en, this message translates to:
  /// **'Back to settings'**
  String get adminBackToSettings;

  /// No description provided for @adminWorkspaceOffline.
  ///
  /// In en, this message translates to:
  /// **'Admin workspace offline'**
  String get adminWorkspaceOffline;

  /// No description provided for @adminWorkspaceOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect before loading private club operations.'**
  String get adminWorkspaceOfflineMessage;

  /// No description provided for @adminAccessUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Admin access unavailable'**
  String get adminAccessUnavailable;

  /// No description provided for @adminAccessUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This account cannot view the current club administration workspace.'**
  String get adminAccessUnavailableMessage;

  /// No description provided for @adminDataChanged.
  ///
  /// In en, this message translates to:
  /// **'Admin data changed'**
  String get adminDataChanged;

  /// No description provided for @adminDataChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh before continuing with current club operations.'**
  String get adminDataChangedMessage;

  /// No description provided for @adminSecurityTimeout.
  ///
  /// In en, this message translates to:
  /// **'Security check timed out'**
  String get adminSecurityTimeout;

  /// No description provided for @adminSecurityTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'No admin data was shown. Check your connection and retry.'**
  String get adminSecurityTimeoutMessage;

  /// No description provided for @adminPrivateDataHiddenMessage.
  ///
  /// In en, this message translates to:
  /// **'Private club data remains hidden. Try again.'**
  String get adminPrivateDataHiddenMessage;

  /// No description provided for @adminRefreshingTitle.
  ///
  /// In en, this message translates to:
  /// **'Refreshing admin workspace'**
  String get adminRefreshingTitle;

  /// No description provided for @adminRefreshingMessage.
  ///
  /// In en, this message translates to:
  /// **'Showing the last confirmed dashboard while current data is checked.'**
  String get adminRefreshingMessage;

  /// No description provided for @adminRefreshTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Refresh timed out'**
  String get adminRefreshTimedOut;

  /// No description provided for @adminCurrentRefreshUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Current refresh unavailable'**
  String get adminCurrentRefreshUnavailable;

  /// No description provided for @adminLastConfirmedMessage.
  ///
  /// In en, this message translates to:
  /// **'Showing the last confirmed dashboard. Actions are paused until refresh succeeds.'**
  String get adminLastConfirmedMessage;

  /// No description provided for @adminAccessRequired.
  ///
  /// In en, this message translates to:
  /// **'Admin access required'**
  String get adminAccessRequired;

  /// No description provided for @adminAccessRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'This workspace is limited to verified club administrators for the active club.'**
  String get adminAccessRequiredMessage;

  /// No description provided for @adminChallengesTitle.
  ///
  /// In en, this message translates to:
  /// **'Challenge ops'**
  String get adminChallengesTitle;

  /// No description provided for @adminBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get adminBack;

  /// No description provided for @adminChallengesLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading challenge operations'**
  String get adminChallengesLoadingTitle;

  /// No description provided for @adminChallengesLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Checking current settlement work.'**
  String get adminChallengesLoadingMessage;

  /// No description provided for @adminChallengesFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Challenge status filter'**
  String get adminChallengesFilterLabel;

  /// No description provided for @adminChallengesFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get adminChallengesFilterAll;

  /// No description provided for @adminChallengesFilterOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get adminChallengesFilterOpen;

  /// No description provided for @adminChallengesFilterLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get adminChallengesFilterLocked;

  /// No description provided for @adminChallengesFilterSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get adminChallengesFilterSettled;

  /// No description provided for @adminChallengesFilterVoid.
  ///
  /// In en, this message translates to:
  /// **'Void'**
  String get adminChallengesFilterVoid;

  /// No description provided for @adminChallengesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No challenge operations'**
  String get adminChallengesEmptyTitle;

  /// No description provided for @adminChallengesEmptyAllMessage.
  ///
  /// In en, this message translates to:
  /// **'No challenges are currently queued.'**
  String get adminChallengesEmptyAllMessage;

  /// No description provided for @adminChallengesEmptyFilteredMessage.
  ///
  /// In en, this message translates to:
  /// **'No {status} challenges are currently queued.'**
  String adminChallengesEmptyFilteredMessage(String status);

  /// No description provided for @adminChallengesRetryTitle.
  ///
  /// In en, this message translates to:
  /// **'Retry settlement?'**
  String get adminChallengesRetryTitle;

  /// No description provided for @adminChallengesRetryMessage.
  ///
  /// In en, this message translates to:
  /// **'Recheck {home} vs {away}. Do not retry again until the refreshed status is confirmed.'**
  String adminChallengesRetryMessage(String home, String away);

  /// No description provided for @adminCancelUpper.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get adminCancelUpper;

  /// No description provided for @adminRetryUpper.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get adminRetryUpper;

  /// No description provided for @adminChallengesSettlementPending.
  ///
  /// In en, this message translates to:
  /// **'Settlement remains pending. Review the refreshed status.'**
  String get adminChallengesSettlementPending;

  /// No description provided for @adminChallengesSettlementRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Settlement status refreshed.'**
  String get adminChallengesSettlementRefreshed;

  /// No description provided for @adminChallengesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Challenge operations unavailable'**
  String get adminChallengesUnavailable;

  /// No description provided for @adminChallengesDisabledMessage.
  ///
  /// In en, this message translates to:
  /// **'Challenge settlement controls are disabled for this controlled build.'**
  String get adminChallengesDisabledMessage;

  /// No description provided for @adminBackToAdmin.
  ///
  /// In en, this message translates to:
  /// **'Back to admin'**
  String get adminBackToAdmin;

  /// No description provided for @adminChallengesOffline.
  ///
  /// In en, this message translates to:
  /// **'Challenge operations offline'**
  String get adminChallengesOffline;

  /// No description provided for @adminChallengesOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect before loading private settlement work.'**
  String get adminChallengesOfflineMessage;

  /// No description provided for @adminChallengesAccessUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Challenge access unavailable'**
  String get adminChallengesAccessUnavailable;

  /// No description provided for @adminChallengesAccessUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This account cannot view or retry club challenge settlements.'**
  String get adminChallengesAccessUnavailableMessage;

  /// No description provided for @adminChallengesStatusChanged.
  ///
  /// In en, this message translates to:
  /// **'Challenge status changed'**
  String get adminChallengesStatusChanged;

  /// No description provided for @adminChallengesStatusChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh before continuing with settlement work.'**
  String get adminChallengesStatusChangedMessage;

  /// No description provided for @adminChallengesSecurityTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'No challenge data was shown. Check your connection and retry.'**
  String get adminChallengesSecurityTimeoutMessage;

  /// No description provided for @adminChallengesPrivateDataHidden.
  ///
  /// In en, this message translates to:
  /// **'Private settlement data remains hidden. Try again.'**
  String get adminChallengesPrivateDataHidden;

  /// No description provided for @adminChallengesRetryingTitle.
  ///
  /// In en, this message translates to:
  /// **'Retrying settlement'**
  String get adminChallengesRetryingTitle;

  /// No description provided for @adminChallengesRetryingMessage.
  ///
  /// In en, this message translates to:
  /// **'Controls are paused until the current result is confirmed.'**
  String get adminChallengesRetryingMessage;

  /// No description provided for @adminChallengesRefreshingTitle.
  ///
  /// In en, this message translates to:
  /// **'Refreshing challenge operations'**
  String get adminChallengesRefreshingTitle;

  /// No description provided for @adminChallengesRefreshingMessage.
  ///
  /// In en, this message translates to:
  /// **'Showing the last confirmed list while current status is checked.'**
  String get adminChallengesRefreshingMessage;

  /// No description provided for @adminChallengesOutcomeUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'The retry outcome is not confirmed. Refresh before taking another action.'**
  String get adminChallengesOutcomeUnconfirmed;

  /// No description provided for @adminChallengesLastConfirmedMessage.
  ///
  /// In en, this message translates to:
  /// **'Showing the last confirmed list. Actions are paused until refresh succeeds.'**
  String get adminChallengesLastConfirmedMessage;

  /// No description provided for @adminChallengesVoidReasonRecorded.
  ///
  /// In en, this message translates to:
  /// **'Void reason recorded'**
  String get adminChallengesVoidReasonRecorded;

  /// No description provided for @adminChallengesNoVoidReason.
  ///
  /// In en, this message translates to:
  /// **'No void reason'**
  String get adminChallengesNoVoidReason;

  /// No description provided for @adminChallengesSettlementMode.
  ///
  /// In en, this message translates to:
  /// **'Settlement {mode}'**
  String adminChallengesSettlementMode(String mode);

  /// No description provided for @adminChallengesAuditState.
  ///
  /// In en, this message translates to:
  /// **'Audit {state}'**
  String adminChallengesAuditState(String state);

  /// No description provided for @adminChallengesRetryingAction.
  ///
  /// In en, this message translates to:
  /// **'Retrying settlement'**
  String get adminChallengesRetryingAction;

  /// No description provided for @adminChallengesRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry settlement'**
  String get adminChallengesRetryAction;

  /// No description provided for @adminChallengesCreator.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get adminChallengesCreator;

  /// No description provided for @adminChallengesPool.
  ///
  /// In en, this message translates to:
  /// **'Pool'**
  String get adminChallengesPool;

  /// No description provided for @adminChallengesParticipants.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get adminChallengesParticipants;

  /// No description provided for @adminVersus.
  ///
  /// In en, this message translates to:
  /// **'{home} vs {away}'**
  String adminVersus(String home, String away);

  /// No description provided for @adminMetricSemantic.
  ///
  /// In en, this message translates to:
  /// **'{label} {value}'**
  String adminMetricSemantic(String label, String value);

  /// No description provided for @adminSettlementConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Settle this fixture?'**
  String get adminSettlementConfirmTitle;

  /// No description provided for @adminSettlementConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'{home} {homeScore} – {awayScore} {away}\n\nThis grades prediction markets and may trigger supporter rewards. Confirm only from the official result.'**
  String adminSettlementConfirmMessage(
    String home,
    int homeScore,
    int awayScore,
    String away,
  );

  /// No description provided for @adminSettlementSettleUpper.
  ///
  /// In en, this message translates to:
  /// **'Settle'**
  String get adminSettlementSettleUpper;

  /// No description provided for @adminSettlementReceipt.
  ///
  /// In en, this message translates to:
  /// **'Settled {score} • {markets} markets • {won} won • {lost} lost'**
  String adminSettlementReceipt(String score, int markets, int won, int lost);

  /// No description provided for @adminSettlementReviewOfficialResult.
  ///
  /// In en, this message translates to:
  /// **'Review the official result and try again.'**
  String get adminSettlementReviewOfficialResult;

  /// No description provided for @adminSettlementNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Fixture settlement was not confirmed.'**
  String get adminSettlementNotConfirmed;

  /// No description provided for @adminSettlementTitle.
  ///
  /// In en, this message translates to:
  /// **'Settle fixtures'**
  String get adminSettlementTitle;

  /// No description provided for @adminSettlementLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading settlement workspace'**
  String get adminSettlementLoadingTitle;

  /// No description provided for @adminSettlementLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Checking controlled fixture information.'**
  String get adminSettlementLoadingMessage;

  /// No description provided for @adminSettlementFilterScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get adminSettlementFilterScheduled;

  /// No description provided for @adminSettlementFilterFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get adminSettlementFilterFinished;

  /// No description provided for @adminSettlementFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get adminSettlementFilterAll;

  /// No description provided for @adminSettlementControlTitle.
  ///
  /// In en, this message translates to:
  /// **'Official result control'**
  String get adminSettlementControlTitle;

  /// No description provided for @adminSettlementControlMessage.
  ///
  /// In en, this message translates to:
  /// **'Settlement grades prediction markets and may trigger rewards. Use only an official, confirmed final score.'**
  String get adminSettlementControlMessage;

  /// No description provided for @adminSettlementEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No fixtures in this view'**
  String get adminSettlementEmptyTitle;

  /// No description provided for @adminSettlementEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Switch filters or wait for controlled fixture information.'**
  String get adminSettlementEmptyMessage;

  /// No description provided for @adminSettlementVersusShort.
  ///
  /// In en, this message translates to:
  /// **'Vs'**
  String get adminSettlementVersusShort;

  /// No description provided for @adminSettlementOpenHint.
  ///
  /// In en, this message translates to:
  /// **'Open official result confirmation'**
  String get adminSettlementOpenHint;

  /// No description provided for @adminSettlementUnavailableHint.
  ///
  /// In en, this message translates to:
  /// **'Settlement unavailable'**
  String get adminSettlementUnavailableHint;

  /// No description provided for @adminSettlementEnterOfficialResult.
  ///
  /// In en, this message translates to:
  /// **'Enter official result'**
  String get adminSettlementEnterOfficialResult;

  /// No description provided for @adminSettlementPaused.
  ///
  /// In en, this message translates to:
  /// **'Settlement paused'**
  String get adminSettlementPaused;

  /// No description provided for @adminSettlementSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get adminSettlementSettled;

  /// No description provided for @adminSettlementNotSettleable.
  ///
  /// In en, this message translates to:
  /// **'Not settleable'**
  String get adminSettlementNotSettleable;

  /// No description provided for @adminSettlementManagementUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Settlement management unavailable'**
  String get adminSettlementManagementUnavailable;

  /// No description provided for @adminSettlementDisabledMessage.
  ///
  /// In en, this message translates to:
  /// **'Settlement controls are disabled for this controlled build.'**
  String get adminSettlementDisabledMessage;

  /// No description provided for @adminSettlementWorkspaceOffline.
  ///
  /// In en, this message translates to:
  /// **'Settlement workspace offline'**
  String get adminSettlementWorkspaceOffline;

  /// No description provided for @adminSettlementWorkspaceOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect before loading private fixture information.'**
  String get adminSettlementWorkspaceOfflineMessage;

  /// No description provided for @adminSettlementAccessUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Settlement access unavailable'**
  String get adminSettlementAccessUnavailable;

  /// No description provided for @adminSettlementAccessUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This account cannot view or settle prediction fixtures.'**
  String get adminSettlementAccessUnavailableMessage;

  /// No description provided for @adminSettlementResultChanged.
  ///
  /// In en, this message translates to:
  /// **'Fixture result changed'**
  String get adminSettlementResultChanged;

  /// No description provided for @adminSettlementResultChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh before confirming another settlement.'**
  String get adminSettlementResultChangedMessage;

  /// No description provided for @adminSettlementSecurityTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'No fixture information was shown. Check your connection.'**
  String get adminSettlementSecurityTimeoutMessage;

  /// No description provided for @adminSettlementWorkspaceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Settlement workspace unavailable'**
  String get adminSettlementWorkspaceUnavailable;

  /// No description provided for @adminSettlementPrivateDataHidden.
  ///
  /// In en, this message translates to:
  /// **'Private fixture information remains hidden. Try again.'**
  String get adminSettlementPrivateDataHidden;

  /// No description provided for @adminSettlementCheckingResults.
  ///
  /// In en, this message translates to:
  /// **'Checking fixture results'**
  String get adminSettlementCheckingResults;

  /// No description provided for @adminSettlementCheckingResultsMessage.
  ///
  /// In en, this message translates to:
  /// **'Showing the last confirmed state while current data is checked.'**
  String get adminSettlementCheckingResultsMessage;

  /// No description provided for @adminSettlementOutcomeUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'The last settlement is unconfirmed. Controls stay paused until refresh succeeds.'**
  String get adminSettlementOutcomeUnconfirmed;

  /// No description provided for @adminSettlementLastConfirmedMessage.
  ///
  /// In en, this message translates to:
  /// **'Last confirmed fixture information remains visible. Controls are paused.'**
  String get adminSettlementLastConfirmedMessage;

  /// No description provided for @adminSettlementFinalScoreValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter final scores from 0 to 99.'**
  String get adminSettlementFinalScoreValidation;

  /// No description provided for @adminSettlementHalfTimeValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter both half-time scores without exceeding the final score.'**
  String get adminSettlementHalfTimeValidation;

  /// No description provided for @adminSettlementHalfTimeScore.
  ///
  /// In en, this message translates to:
  /// **'Half-time score'**
  String get adminSettlementHalfTimeScore;

  /// No description provided for @adminSettlementHideHalfTime.
  ///
  /// In en, this message translates to:
  /// **'Hide half-time score fields'**
  String get adminSettlementHideHalfTime;

  /// No description provided for @adminSettlementShowHalfTime.
  ///
  /// In en, this message translates to:
  /// **'Show half-time score fields'**
  String get adminSettlementShowHalfTime;

  /// No description provided for @adminSettlementHalfTimeOptional.
  ///
  /// In en, this message translates to:
  /// **'Half-time score (optional)'**
  String get adminSettlementHalfTimeOptional;

  /// No description provided for @adminSettlementHalfTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'{team} HT'**
  String adminSettlementHalfTimeLabel(String team);

  /// No description provided for @adminSettlementReviewAction.
  ///
  /// In en, this message translates to:
  /// **'Review settlement'**
  String get adminSettlementReviewAction;

  /// No description provided for @adminStatusFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get adminStatusFinished;

  /// No description provided for @adminStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get adminStatusScheduled;

  /// No description provided for @adminStatusLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get adminStatusLive;

  /// No description provided for @adminStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get adminStatusCancelled;

  /// No description provided for @adminStatusPostponed.
  ///
  /// In en, this message translates to:
  /// **'Postponed'**
  String get adminStatusPostponed;

  /// No description provided for @adminScore.
  ///
  /// In en, this message translates to:
  /// **'{home} – {away}'**
  String adminScore(int home, int away);

  /// No description provided for @adminFeatureDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Feature detail'**
  String get adminFeatureDetailTitle;

  /// No description provided for @adminFeatureLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading feature settings'**
  String get adminFeatureLoadingTitle;

  /// No description provided for @adminFeatureLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Checking controlled channel and access rules.'**
  String get adminFeatureLoadingMessage;

  /// No description provided for @adminFeatureNotFound.
  ///
  /// In en, this message translates to:
  /// **'Feature not found'**
  String get adminFeatureNotFound;

  /// No description provided for @adminFeatureNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'No confirmed feature matches this controlled route.'**
  String get adminFeatureNotFoundMessage;

  /// No description provided for @adminBackToFeatures.
  ///
  /// In en, this message translates to:
  /// **'Back to features'**
  String get adminBackToFeatures;

  /// No description provided for @adminFeatureGlobalState.
  ///
  /// In en, this message translates to:
  /// **'Global state'**
  String get adminFeatureGlobalState;

  /// No description provided for @adminFeatureDisableTooltip.
  ///
  /// In en, this message translates to:
  /// **'Disable {feature}'**
  String adminFeatureDisableTooltip(String feature);

  /// No description provided for @adminFeatureEnableTooltip.
  ///
  /// In en, this message translates to:
  /// **'Enable {feature}'**
  String adminFeatureEnableTooltip(String feature);

  /// No description provided for @adminFeatureStateSemantic.
  ///
  /// In en, this message translates to:
  /// **'{feature} is {state}'**
  String adminFeatureStateSemantic(String feature, String state);

  /// No description provided for @adminFeatureChangesGlobalState.
  ///
  /// In en, this message translates to:
  /// **'Changes the global feature state'**
  String get adminFeatureChangesGlobalState;

  /// No description provided for @adminFeatureEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get adminFeatureEnabled;

  /// No description provided for @adminFeatureDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get adminFeatureDisabled;

  /// No description provided for @adminFeatureTapDisable.
  ///
  /// In en, this message translates to:
  /// **'Tap to disable this feature globally'**
  String get adminFeatureTapDisable;

  /// No description provided for @adminFeatureTapEnable.
  ///
  /// In en, this message translates to:
  /// **'Tap to enable this feature globally'**
  String get adminFeatureTapEnable;

  /// No description provided for @adminFeatureVisibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get adminFeatureVisibility;

  /// No description provided for @adminFeatureVisibilityVisible.
  ///
  /// In en, this message translates to:
  /// **'Visible'**
  String get adminFeatureVisibilityVisible;

  /// No description provided for @adminFeatureVisibilityHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get adminFeatureVisibilityHidden;

  /// No description provided for @adminFeatureVisibilityMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get adminFeatureVisibilityMaintenance;

  /// No description provided for @adminFeatureChannelConfig.
  ///
  /// In en, this message translates to:
  /// **'Channel config'**
  String get adminFeatureChannelConfig;

  /// No description provided for @adminFeatureNoChannelOverrides.
  ///
  /// In en, this message translates to:
  /// **'No channel overrides'**
  String get adminFeatureNoChannelOverrides;

  /// No description provided for @adminFeatureNoChannelOverridesMessage.
  ///
  /// In en, this message translates to:
  /// **'This feature uses its confirmed global state.'**
  String get adminFeatureNoChannelOverridesMessage;

  /// No description provided for @adminFeatureScheduling.
  ///
  /// In en, this message translates to:
  /// **'Scheduling'**
  String get adminFeatureScheduling;

  /// No description provided for @adminFeatureAccessRules.
  ///
  /// In en, this message translates to:
  /// **'Access rules'**
  String get adminFeatureAccessRules;

  /// No description provided for @adminFeatureAuthRequired.
  ///
  /// In en, this message translates to:
  /// **'Authentication required'**
  String get adminFeatureAuthRequired;

  /// No description provided for @adminFeatureAuthRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Users must sign in before accessing this feature.'**
  String get adminFeatureAuthRequiredMessage;

  /// No description provided for @adminFeatureSettingsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Feature settings unavailable'**
  String get adminFeatureSettingsUnavailable;

  /// No description provided for @adminFeatureEditingDisabled.
  ///
  /// In en, this message translates to:
  /// **'Feature editing is disabled for this controlled build.'**
  String get adminFeatureEditingDisabled;

  /// No description provided for @adminFeatureSettingsOffline.
  ///
  /// In en, this message translates to:
  /// **'Feature settings offline'**
  String get adminFeatureSettingsOffline;

  /// No description provided for @adminFeatureSettingsOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect before loading private feature configuration.'**
  String get adminFeatureSettingsOfflineMessage;

  /// No description provided for @adminFeatureAccessUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Feature access unavailable'**
  String get adminFeatureAccessUnavailable;

  /// No description provided for @adminFeatureAccessUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This account cannot view or change feature settings.'**
  String get adminFeatureAccessUnavailableMessage;

  /// No description provided for @adminFeatureSettingsChanged.
  ///
  /// In en, this message translates to:
  /// **'Feature settings changed'**
  String get adminFeatureSettingsChanged;

  /// No description provided for @adminFeatureSettingsChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh before making another feature change.'**
  String get adminFeatureSettingsChangedMessage;

  /// No description provided for @adminFeatureSecurityTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'No feature settings were shown. Check your connection.'**
  String get adminFeatureSecurityTimeoutMessage;

  /// No description provided for @adminFeaturePrivateDataHidden.
  ///
  /// In en, this message translates to:
  /// **'Private feature settings remain hidden. Try again.'**
  String get adminFeaturePrivateDataHidden;

  /// No description provided for @adminFeatureCheckingTitle.
  ///
  /// In en, this message translates to:
  /// **'Checking feature settings'**
  String get adminFeatureCheckingTitle;

  /// No description provided for @adminFeatureCheckingMessage.
  ///
  /// In en, this message translates to:
  /// **'Showing the last confirmed state while current data is checked.'**
  String get adminFeatureCheckingMessage;

  /// No description provided for @adminFeatureOutcomeUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'The last change is unconfirmed. Controls stay paused until refresh succeeds.'**
  String get adminFeatureOutcomeUnconfirmed;

  /// No description provided for @adminFeatureLastConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Last confirmed settings remain visible. Controls are paused.'**
  String get adminFeatureLastConfirmed;

  /// No description provided for @adminFeatureChannelMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get adminFeatureChannelMobile;

  /// No description provided for @adminFeatureChannelWeb.
  ///
  /// In en, this message translates to:
  /// **'Web'**
  String get adminFeatureChannelWeb;

  /// No description provided for @adminFeatureChannelEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get adminFeatureChannelEnabled;

  /// No description provided for @adminFeatureChannelEnabledMessage.
  ///
  /// In en, this message translates to:
  /// **'Feature is active on this channel.'**
  String get adminFeatureChannelEnabledMessage;

  /// No description provided for @adminFeatureChannelVisible.
  ///
  /// In en, this message translates to:
  /// **'Visible'**
  String get adminFeatureChannelVisible;

  /// No description provided for @adminFeatureChannelVisibleMessage.
  ///
  /// In en, this message translates to:
  /// **'Feature can be shown on this channel.'**
  String get adminFeatureChannelVisibleMessage;

  /// No description provided for @adminFeatureShowInNavigation.
  ///
  /// In en, this message translates to:
  /// **'Show in navigation'**
  String get adminFeatureShowInNavigation;

  /// No description provided for @adminFeatureShowInNavigationMessage.
  ///
  /// In en, this message translates to:
  /// **'Include this feature in channel navigation.'**
  String get adminFeatureShowInNavigationMessage;

  /// No description provided for @adminFeatureShowOnHome.
  ///
  /// In en, this message translates to:
  /// **'Show on home'**
  String get adminFeatureShowOnHome;

  /// No description provided for @adminFeatureShowOnHomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Include this feature on the channel home screen.'**
  String get adminFeatureShowOnHomeMessage;

  /// No description provided for @adminFeatureAvailableFrom.
  ///
  /// In en, this message translates to:
  /// **'Available from'**
  String get adminFeatureAvailableFrom;

  /// No description provided for @adminFeatureAvailableUntil.
  ///
  /// In en, this message translates to:
  /// **'Available until'**
  String get adminFeatureAvailableUntil;

  /// No description provided for @adminFeatureClearSchedule.
  ///
  /// In en, this message translates to:
  /// **'Clear schedule'**
  String get adminFeatureClearSchedule;

  /// No description provided for @adminFeatureNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get adminFeatureNotSet;

  /// No description provided for @adminFeatureSetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Set {label}'**
  String adminFeatureSetTooltip(String label);

  /// No description provided for @adminFeatureDateSemantic.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String adminFeatureDateSemantic(String label, String value);

  /// No description provided for @adminFeatureOpenDateTime.
  ///
  /// In en, this message translates to:
  /// **'Opens date and time selection'**
  String get adminFeatureOpenDateTime;

  /// No description provided for @adminMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get adminMatchesTitle;

  /// No description provided for @adminMatchesLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading match workspace'**
  String get adminMatchesLoadingTitle;

  /// No description provided for @adminMatchesLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Checking controlled fixture information.'**
  String get adminMatchesLoadingMessage;

  /// No description provided for @adminMatchesDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage fixtures, sale status, ticket allocation, and live scores from confirmed data.'**
  String get adminMatchesDescription;

  /// No description provided for @adminMatchesFixtures.
  ///
  /// In en, this message translates to:
  /// **'Fixtures'**
  String get adminMatchesFixtures;

  /// No description provided for @adminMatchesOnSale.
  ///
  /// In en, this message translates to:
  /// **'On sale'**
  String get adminMatchesOnSale;

  /// No description provided for @adminMatchesStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get adminMatchesStatus;

  /// No description provided for @adminMatchesFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get adminMatchesFilterAll;

  /// No description provided for @adminMatchesFilterLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get adminMatchesFilterLive;

  /// No description provided for @adminMatchesFilterUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get adminMatchesFilterUpcoming;

  /// No description provided for @adminMatchesFilterOnSale.
  ///
  /// In en, this message translates to:
  /// **'On sale'**
  String get adminMatchesFilterOnSale;

  /// No description provided for @adminMatchesFilterCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get adminMatchesFilterCompleted;

  /// No description provided for @adminMatchesNoneConfigured.
  ///
  /// In en, this message translates to:
  /// **'No fixtures configured'**
  String get adminMatchesNoneConfigured;

  /// No description provided for @adminMatchesNoneMatch.
  ///
  /// In en, this message translates to:
  /// **'No fixtures match'**
  String get adminMatchesNoneMatch;

  /// No description provided for @adminMatchesNoneConfiguredMessage.
  ///
  /// In en, this message translates to:
  /// **'A confirmed club fixture must exist before this workspace can infer its partner scope.'**
  String get adminMatchesNoneConfiguredMessage;

  /// No description provided for @adminMatchesNoneMatchMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose another status filter.'**
  String get adminMatchesNoneMatchMessage;

  /// No description provided for @adminMatchesCreate.
  ///
  /// In en, this message translates to:
  /// **'Create match'**
  String get adminMatchesCreate;

  /// No description provided for @adminMatchesCreationPaused.
  ///
  /// In en, this message translates to:
  /// **'Creation stays paused until a confirmed partner scope is available.'**
  String get adminMatchesCreationPaused;

  /// No description provided for @adminMatchesCreated.
  ///
  /// In en, this message translates to:
  /// **'Match created successfully.'**
  String get adminMatchesCreated;

  /// No description provided for @adminMatchesUpdated.
  ///
  /// In en, this message translates to:
  /// **'Match updated successfully.'**
  String get adminMatchesUpdated;

  /// No description provided for @adminMatchesManagementUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Match management unavailable'**
  String get adminMatchesManagementUnavailable;

  /// No description provided for @adminMatchesDisabledMessage.
  ///
  /// In en, this message translates to:
  /// **'Match controls are disabled for this controlled build.'**
  String get adminMatchesDisabledMessage;

  /// No description provided for @adminMatchesWorkspaceOffline.
  ///
  /// In en, this message translates to:
  /// **'Match workspace offline'**
  String get adminMatchesWorkspaceOffline;

  /// No description provided for @adminMatchesWorkspaceOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect before loading private fixture information.'**
  String get adminMatchesWorkspaceOfflineMessage;

  /// No description provided for @adminMatchesAccessUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Match access unavailable'**
  String get adminMatchesAccessUnavailable;

  /// No description provided for @adminMatchesAccessUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This account cannot view or change fixture information.'**
  String get adminMatchesAccessUnavailableMessage;

  /// No description provided for @adminMatchesInformationChanged.
  ///
  /// In en, this message translates to:
  /// **'Fixture information changed'**
  String get adminMatchesInformationChanged;

  /// No description provided for @adminMatchesInformationChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh before making another fixture change.'**
  String get adminMatchesInformationChangedMessage;

  /// No description provided for @adminMatchesSecurityTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'No fixture information was shown. Check your connection.'**
  String get adminMatchesSecurityTimeoutMessage;

  /// No description provided for @adminMatchesWorkspaceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Match workspace unavailable'**
  String get adminMatchesWorkspaceUnavailable;

  /// No description provided for @adminMatchesPrivateDataHidden.
  ///
  /// In en, this message translates to:
  /// **'Private fixture information remains hidden. Try again.'**
  String get adminMatchesPrivateDataHidden;

  /// No description provided for @adminMatchesCheckingTitle.
  ///
  /// In en, this message translates to:
  /// **'Checking fixture information'**
  String get adminMatchesCheckingTitle;

  /// No description provided for @adminMatchesCheckingMessage.
  ///
  /// In en, this message translates to:
  /// **'Showing the last confirmed state while current data is checked.'**
  String get adminMatchesCheckingMessage;

  /// No description provided for @adminMatchesOutcomeUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'The last change is unconfirmed. Controls stay paused until refresh succeeds.'**
  String get adminMatchesOutcomeUnconfirmed;

  /// No description provided for @adminMatchesLastConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Last confirmed fixture information remains visible. Controls are paused.'**
  String get adminMatchesLastConfirmed;

  /// No description provided for @adminMatchesOpenTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open {home} versus {away}'**
  String adminMatchesOpenTooltip(String home, String away);

  /// No description provided for @adminMatchesFixtureSemantic.
  ///
  /// In en, this message translates to:
  /// **'{home} versus {away} fixture'**
  String adminMatchesFixtureSemantic(String home, String away);

  /// No description provided for @adminMatchesOpenHint.
  ///
  /// In en, this message translates to:
  /// **'Opens controlled fixture settings'**
  String get adminMatchesOpenHint;

  /// No description provided for @adminMatchesCompetitionVenue.
  ///
  /// In en, this message translates to:
  /// **'{competition} • {venue}'**
  String adminMatchesCompetitionVenue(String competition, String venue);

  /// No description provided for @adminMatchesDateKickoff.
  ///
  /// In en, this message translates to:
  /// **'{date} • {time}'**
  String adminMatchesDateKickoff(String date, String time);

  /// No description provided for @adminMatchesPrices.
  ///
  /// In en, this message translates to:
  /// **'General {symbol} {general} • VIP {symbol} {vip}'**
  String adminMatchesPrices(String symbol, String general, String vip);

  /// No description provided for @adminMatchesScore.
  ///
  /// In en, this message translates to:
  /// **'Score {home}-{away}{minute}'**
  String adminMatchesScore(int home, int away, String minute);

  /// No description provided for @adminMatchesAllocation.
  ///
  /// In en, this message translates to:
  /// **'{percent}% allocation • {sold} / {capacity} tickets'**
  String adminMatchesAllocation(int percent, int sold, int capacity);

  /// No description provided for @adminMatchesEditOnSale.
  ///
  /// In en, this message translates to:
  /// **'Edit on-sale fixture'**
  String get adminMatchesEditOnSale;

  /// No description provided for @adminMatchesEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit fixture'**
  String get adminMatchesEdit;

  /// No description provided for @adminStatusHalfTime.
  ///
  /// In en, this message translates to:
  /// **'Half-time'**
  String get adminStatusHalfTime;

  /// No description provided for @adminStatusFullTime.
  ///
  /// In en, this message translates to:
  /// **'Full-time'**
  String get adminStatusFullTime;

  /// No description provided for @adminStatusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get adminStatusUpcoming;

  /// No description provided for @adminMatchesLiveMinute.
  ///
  /// In en, this message translates to:
  /// **' • {minute}\''**
  String adminMatchesLiveMinute(int minute);

  /// No description provided for @adminMatchSaveNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'The match was not saved. Review the confirmed workspace state.'**
  String get adminMatchSaveNotConfirmed;

  /// No description provided for @adminMatchReviewFields.
  ///
  /// In en, this message translates to:
  /// **'Review every match field and enter valid values.'**
  String get adminMatchReviewFields;

  /// No description provided for @adminMatchSaveFailedRefresh.
  ///
  /// In en, this message translates to:
  /// **'The match was not saved. Try again after refreshing.'**
  String get adminMatchSaveFailedRefresh;

  /// No description provided for @adminMatchCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create match'**
  String get adminMatchCreateTitle;

  /// No description provided for @adminMatchUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Update match'**
  String get adminMatchUpdateTitle;

  /// No description provided for @adminMatchHomeTeam.
  ///
  /// In en, this message translates to:
  /// **'Home team'**
  String get adminMatchHomeTeam;

  /// No description provided for @adminMatchAwayTeam.
  ///
  /// In en, this message translates to:
  /// **'Away team'**
  String get adminMatchAwayTeam;

  /// No description provided for @adminMatchCompetition.
  ///
  /// In en, this message translates to:
  /// **'Competition'**
  String get adminMatchCompetition;

  /// No description provided for @adminMatchVenue.
  ///
  /// In en, this message translates to:
  /// **'Venue'**
  String get adminMatchVenue;

  /// No description provided for @adminMatchGeneralPrice.
  ///
  /// In en, this message translates to:
  /// **'General {symbol}'**
  String adminMatchGeneralPrice(String symbol);

  /// No description provided for @adminMatchVipPrice.
  ///
  /// In en, this message translates to:
  /// **'VIP {symbol}'**
  String adminMatchVipPrice(String symbol);

  /// No description provided for @adminMatchCapacity.
  ///
  /// In en, this message translates to:
  /// **'Capacity'**
  String get adminMatchCapacity;

  /// No description provided for @adminMatchTicketsOnSale.
  ///
  /// In en, this message translates to:
  /// **'Tickets on sale'**
  String get adminMatchTicketsOnSale;

  /// No description provided for @adminMatchStatus.
  ///
  /// In en, this message translates to:
  /// **'Match status'**
  String get adminMatchStatus;

  /// No description provided for @adminMatchStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get adminMatchStatusScheduled;

  /// No description provided for @adminMatchStatusLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get adminMatchStatusLive;

  /// No description provided for @adminMatchStatusHalfTime.
  ///
  /// In en, this message translates to:
  /// **'Half-time'**
  String get adminMatchStatusHalfTime;

  /// No description provided for @adminMatchStatusFullTime.
  ///
  /// In en, this message translates to:
  /// **'Full-time'**
  String get adminMatchStatusFullTime;

  /// No description provided for @adminMatchStatusPostponed.
  ///
  /// In en, this message translates to:
  /// **'Postponed'**
  String get adminMatchStatusPostponed;

  /// No description provided for @adminMatchStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get adminMatchStatusCancelled;

  /// No description provided for @adminMatchHomeScore.
  ///
  /// In en, this message translates to:
  /// **'Home score'**
  String get adminMatchHomeScore;

  /// No description provided for @adminMatchAwayScore.
  ///
  /// In en, this message translates to:
  /// **'Away score'**
  String get adminMatchAwayScore;

  /// No description provided for @adminMatchLiveMinute.
  ///
  /// In en, this message translates to:
  /// **'Live minute'**
  String get adminMatchLiveMinute;

  /// No description provided for @adminMatchSummary.
  ///
  /// In en, this message translates to:
  /// **'Match summary / live note'**
  String get adminMatchSummary;

  /// No description provided for @adminMatchSave.
  ///
  /// In en, this message translates to:
  /// **'Save match'**
  String get adminMatchSave;

  /// No description provided for @adminMatchUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update match'**
  String get adminMatchUpdate;

  /// No description provided for @adminFeatureManagerTitle.
  ///
  /// In en, this message translates to:
  /// **'Feature manager'**
  String get adminFeatureManagerTitle;

  /// No description provided for @adminFeatureRegistryLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading feature registry'**
  String get adminFeatureRegistryLoading;

  /// No description provided for @adminFeatureRegistryLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Checking controlled feature configuration.'**
  String get adminFeatureRegistryLoadingMessage;

  /// No description provided for @adminFeatureManagerDescription.
  ///
  /// In en, this message translates to:
  /// **'Control club-scoped feature availability with confirmed, bounded configuration.'**
  String get adminFeatureManagerDescription;

  /// No description provided for @adminFeatureRegistered.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get adminFeatureRegistered;

  /// No description provided for @adminFeatureEnabledUpper.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get adminFeatureEnabledUpper;

  /// No description provided for @adminFeatureDisabledUpper.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get adminFeatureDisabledUpper;

  /// No description provided for @adminFeatureStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get adminFeatureStatus;

  /// No description provided for @adminFeatureFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get adminFeatureFilterAll;

  /// No description provided for @adminFeatureNoneConfigured.
  ///
  /// In en, this message translates to:
  /// **'No features configured'**
  String get adminFeatureNoneConfigured;

  /// No description provided for @adminFeatureNoneMatch.
  ///
  /// In en, this message translates to:
  /// **'No features match'**
  String get adminFeatureNoneMatch;

  /// No description provided for @adminFeatureNoneConfiguredMessage.
  ///
  /// In en, this message translates to:
  /// **'Confirmed feature configuration will appear here.'**
  String get adminFeatureNoneConfiguredMessage;

  /// No description provided for @adminFeatureNoneMatchMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose another status filter.'**
  String get adminFeatureNoneMatchMessage;

  /// No description provided for @adminFeatureManagementUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Feature management unavailable'**
  String get adminFeatureManagementUnavailable;

  /// No description provided for @adminFeatureControlsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Feature controls are disabled for this controlled build.'**
  String get adminFeatureControlsDisabled;

  /// No description provided for @adminFeatureRegistryOffline.
  ///
  /// In en, this message translates to:
  /// **'Feature registry offline'**
  String get adminFeatureRegistryOffline;

  /// No description provided for @adminFeatureConfigurationAccessMessage.
  ///
  /// In en, this message translates to:
  /// **'This account cannot view or change feature configuration.'**
  String get adminFeatureConfigurationAccessMessage;

  /// No description provided for @adminFeatureConfigurationChanged.
  ///
  /// In en, this message translates to:
  /// **'Feature configuration changed'**
  String get adminFeatureConfigurationChanged;

  /// No description provided for @adminFeatureConfigurationChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh before making another feature change.'**
  String get adminFeatureConfigurationChangedMessage;

  /// No description provided for @adminFeatureConfigurationSecurityMessage.
  ///
  /// In en, this message translates to:
  /// **'No feature configuration was shown. Check your connection.'**
  String get adminFeatureConfigurationSecurityMessage;

  /// No description provided for @adminFeatureRegistryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Feature registry unavailable'**
  String get adminFeatureRegistryUnavailable;

  /// No description provided for @adminFeatureConfigurationHidden.
  ///
  /// In en, this message translates to:
  /// **'Private feature configuration remains hidden. Try again.'**
  String get adminFeatureConfigurationHidden;

  /// No description provided for @adminFeatureConfigurationChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking feature configuration'**
  String get adminFeatureConfigurationChecking;

  /// No description provided for @adminFeatureConfigurationLastConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Last confirmed configuration remains visible. Controls are paused.'**
  String get adminFeatureConfigurationLastConfirmed;

  /// No description provided for @adminFeatureOpenTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open {feature}'**
  String adminFeatureOpenTooltip(String feature);

  /// No description provided for @adminFeatureSettingsSemantic.
  ///
  /// In en, this message translates to:
  /// **'{feature} feature settings'**
  String adminFeatureSettingsSemantic(String feature);

  /// No description provided for @adminFeatureOpenSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Opens controlled feature settings'**
  String get adminFeatureOpenSettingsHint;

  /// No description provided for @adminFeatureChangeVisibilityTooltip.
  ///
  /// In en, this message translates to:
  /// **'Change {feature} visibility'**
  String adminFeatureChangeVisibilityTooltip(String feature);

  /// No description provided for @adminFeatureChangeVisibility.
  ///
  /// In en, this message translates to:
  /// **'Change visibility'**
  String get adminFeatureChangeVisibility;

  /// No description provided for @adminCompetitionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Competitions'**
  String get adminCompetitionsTitle;

  /// No description provided for @adminCompetitionsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add competition'**
  String get adminCompetitionsAdd;

  /// No description provided for @adminCompetitionsActionsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Competition actions unavailable'**
  String get adminCompetitionsActionsUnavailable;

  /// No description provided for @adminCompetitionsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading competitions'**
  String get adminCompetitionsLoading;

  /// No description provided for @adminCompetitionsLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Checking the controlled competition workspace.'**
  String get adminCompetitionsLoadingMessage;

  /// No description provided for @adminCompetitionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage the competitions and seasons available to the prediction engine.'**
  String get adminCompetitionsDescription;

  /// No description provided for @adminCompetitionsNoneConfigured.
  ///
  /// In en, this message translates to:
  /// **'No competitions configured'**
  String get adminCompetitionsNoneConfigured;

  /// No description provided for @adminCompetitionsNoneMatch.
  ///
  /// In en, this message translates to:
  /// **'No competitions match'**
  String get adminCompetitionsNoneMatch;

  /// No description provided for @adminCompetitionsNoneConfiguredMessage.
  ///
  /// In en, this message translates to:
  /// **'Create the first controlled competition when access is available.'**
  String get adminCompetitionsNoneConfiguredMessage;

  /// No description provided for @adminCompetitionsNoneMatchMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose another region or competition kind.'**
  String get adminCompetitionsNoneMatchMessage;

  /// No description provided for @adminCompetitionsManagementUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Competition management unavailable'**
  String get adminCompetitionsManagementUnavailable;

  /// No description provided for @adminCompetitionsControlsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Competition controls are disabled for this controlled build.'**
  String get adminCompetitionsControlsDisabled;

  /// No description provided for @adminCompetitionsOffline.
  ///
  /// In en, this message translates to:
  /// **'Competition workspace offline'**
  String get adminCompetitionsOffline;

  /// No description provided for @adminCompetitionsOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect before loading private competition records.'**
  String get adminCompetitionsOfflineMessage;

  /// No description provided for @adminCompetitionsAccessUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Competition access unavailable'**
  String get adminCompetitionsAccessUnavailable;

  /// No description provided for @adminCompetitionsAccessMessage.
  ///
  /// In en, this message translates to:
  /// **'This account cannot view or change competition configuration.'**
  String get adminCompetitionsAccessMessage;

  /// No description provided for @adminCompetitionsDataChanged.
  ///
  /// In en, this message translates to:
  /// **'Competition data changed'**
  String get adminCompetitionsDataChanged;

  /// No description provided for @adminCompetitionsDataChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh before continuing with competition work.'**
  String get adminCompetitionsDataChangedMessage;

  /// No description provided for @adminCompetitionsSecurityMessage.
  ///
  /// In en, this message translates to:
  /// **'No competition data was shown. Check your connection.'**
  String get adminCompetitionsSecurityMessage;

  /// No description provided for @adminCompetitionsWorkspaceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Competition workspace unavailable'**
  String get adminCompetitionsWorkspaceUnavailable;

  /// No description provided for @adminCompetitionsHiddenMessage.
  ///
  /// In en, this message translates to:
  /// **'Private competition records remain hidden. Try again.'**
  String get adminCompetitionsHiddenMessage;

  /// No description provided for @adminCompetitionsUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating competition workspace'**
  String get adminCompetitionsUpdating;

  /// No description provided for @adminCompetitionsUpdatingMessage.
  ///
  /// In en, this message translates to:
  /// **'Controls are paused until the current result is confirmed.'**
  String get adminCompetitionsUpdatingMessage;

  /// No description provided for @adminCompetitionsRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing competitions'**
  String get adminCompetitionsRefreshing;

  /// No description provided for @adminCompetitionsRefreshingMessage.
  ///
  /// In en, this message translates to:
  /// **'Showing the last confirmed records while current data is checked.'**
  String get adminCompetitionsRefreshingMessage;

  /// No description provided for @adminCompetitionsCurrentRefreshUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Current refresh unavailable'**
  String get adminCompetitionsCurrentRefreshUnavailable;

  /// No description provided for @adminCompetitionsOutcomeUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'The update outcome is not confirmed. Refresh before taking another action.'**
  String get adminCompetitionsOutcomeUnconfirmed;

  /// No description provided for @adminCompetitionsLastConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Showing the last confirmed records. Actions are paused until refresh succeeds.'**
  String get adminCompetitionsLastConfirmed;

  /// No description provided for @adminCompetitionCreated.
  ///
  /// In en, this message translates to:
  /// **'Competition created'**
  String get adminCompetitionCreated;

  /// No description provided for @adminCompetitionUpdated.
  ///
  /// In en, this message translates to:
  /// **'Competition updated'**
  String get adminCompetitionUpdated;

  /// No description provided for @adminCompetitionActivateQuestion.
  ///
  /// In en, this message translates to:
  /// **'Activate competition?'**
  String get adminCompetitionActivateQuestion;

  /// No description provided for @adminCompetitionDeactivateQuestion.
  ///
  /// In en, this message translates to:
  /// **'Deactivate?'**
  String get adminCompetitionDeactivateQuestion;

  /// No description provided for @adminCompetitionActivateMessage.
  ///
  /// In en, this message translates to:
  /// **'{competition} will become available to configured prediction journeys.'**
  String adminCompetitionActivateMessage(String competition);

  /// No description provided for @adminCompetitionDeactivateMessage.
  ///
  /// In en, this message translates to:
  /// **'{competition} will stop being available to configured prediction journeys.'**
  String adminCompetitionDeactivateMessage(String competition);

  /// No description provided for @adminActivateUpper.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get adminActivateUpper;

  /// No description provided for @adminDeactivateUpper.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get adminDeactivateUpper;

  /// No description provided for @adminCompetitionActivated.
  ///
  /// In en, this message translates to:
  /// **'Competition activated'**
  String get adminCompetitionActivated;

  /// No description provided for @adminCompetitionDeactivated.
  ///
  /// In en, this message translates to:
  /// **'Competition deactivated'**
  String get adminCompetitionDeactivated;

  /// No description provided for @adminCompetitionsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get adminCompetitionsTotal;

  /// No description provided for @adminCompetitionsActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminCompetitionsActive;

  /// No description provided for @adminCompetitionsInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get adminCompetitionsInactive;

  /// No description provided for @adminCompetitionFilters.
  ///
  /// In en, this message translates to:
  /// **'Competition filters'**
  String get adminCompetitionFilters;

  /// No description provided for @adminCompetitionRegion.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get adminCompetitionRegion;

  /// No description provided for @adminCompetitionKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get adminCompetitionKind;

  /// No description provided for @adminCompetitionSeasons.
  ///
  /// In en, this message translates to:
  /// **'Seasons'**
  String get adminCompetitionSeasons;

  /// No description provided for @adminEditUpper.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get adminEditUpper;

  /// No description provided for @adminCompetitionFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get adminCompetitionFilterAll;

  /// No description provided for @adminCompetitionRegionAfrica.
  ///
  /// In en, this message translates to:
  /// **'Africa'**
  String get adminCompetitionRegionAfrica;

  /// No description provided for @adminCompetitionRegionEurope.
  ///
  /// In en, this message translates to:
  /// **'Europe'**
  String get adminCompetitionRegionEurope;

  /// No description provided for @adminCompetitionRegionInternational.
  ///
  /// In en, this message translates to:
  /// **'Intl'**
  String get adminCompetitionRegionInternational;

  /// No description provided for @adminCompetitionRegionGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get adminCompetitionRegionGlobal;

  /// No description provided for @adminCompetitionKindLeague.
  ///
  /// In en, this message translates to:
  /// **'League'**
  String get adminCompetitionKindLeague;

  /// No description provided for @adminCompetitionKindCup.
  ///
  /// In en, this message translates to:
  /// **'Cup'**
  String get adminCompetitionKindCup;

  /// No description provided for @adminCompetitionKindTournament.
  ///
  /// In en, this message translates to:
  /// **'Tournament'**
  String get adminCompetitionKindTournament;

  /// No description provided for @adminCompetitionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit competition'**
  String get adminCompetitionEdit;

  /// No description provided for @adminCompetitionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add competition'**
  String get adminCompetitionAdd;

  /// No description provided for @adminCompetitionName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get adminCompetitionName;

  /// No description provided for @adminCompetitionShortName.
  ///
  /// In en, this message translates to:
  /// **'Short name'**
  String get adminCompetitionShortName;

  /// No description provided for @adminCompetitionSlug.
  ///
  /// In en, this message translates to:
  /// **'Slug'**
  String get adminCompetitionSlug;

  /// No description provided for @adminCompetitionSlugHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. national-league'**
  String get adminCompetitionSlugHint;

  /// No description provided for @adminCompetitionOrganizer.
  ///
  /// In en, this message translates to:
  /// **'Organizer'**
  String get adminCompetitionOrganizer;

  /// No description provided for @adminOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get adminOptional;

  /// No description provided for @adminCompetitionCountryCode.
  ///
  /// In en, this message translates to:
  /// **'Country code'**
  String get adminCompetitionCountryCode;

  /// No description provided for @adminCompetitionCountryCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Rw'**
  String get adminCompetitionCountryCodeHint;

  /// No description provided for @adminCompetitionCountryName.
  ///
  /// In en, this message translates to:
  /// **'Country name'**
  String get adminCompetitionCountryName;

  /// No description provided for @adminCompetitionCountryNameHint.
  ///
  /// In en, this message translates to:
  /// **'Rwanda'**
  String get adminCompetitionCountryNameHint;

  /// No description provided for @adminCompetitionFormatNotes.
  ///
  /// In en, this message translates to:
  /// **'Format notes'**
  String get adminCompetitionFormatNotes;

  /// No description provided for @adminCompetitionValidationMessage.
  ///
  /// In en, this message translates to:
  /// **'Check the required names, slug, and country code.'**
  String get adminCompetitionValidationMessage;

  /// No description provided for @adminCompetitionAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available to configured prediction journeys'**
  String get adminCompetitionAvailable;

  /// No description provided for @adminCompetitionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable to prediction journeys'**
  String get adminCompetitionUnavailable;

  /// No description provided for @adminSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get adminSaveChanges;

  /// No description provided for @adminCreateCompetition.
  ///
  /// In en, this message translates to:
  /// **'Create competition'**
  String get adminCreateCompetition;

  /// No description provided for @adminSeasonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add season'**
  String get adminSeasonAdd;

  /// No description provided for @adminSeasonActionsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Season actions unavailable'**
  String get adminSeasonActionsUnavailable;

  /// No description provided for @adminSeasonNoneConfigured.
  ///
  /// In en, this message translates to:
  /// **'No seasons configured'**
  String get adminSeasonNoneConfigured;

  /// No description provided for @adminSeasonNoneConfiguredMessage.
  ///
  /// In en, this message translates to:
  /// **'Add the first controlled season when access is available.'**
  String get adminSeasonNoneConfiguredMessage;

  /// No description provided for @adminSeasonCreated.
  ///
  /// In en, this message translates to:
  /// **'Season created'**
  String get adminSeasonCreated;

  /// No description provided for @adminSeasonActivateQuestion.
  ///
  /// In en, this message translates to:
  /// **'Activate season?'**
  String get adminSeasonActivateQuestion;

  /// No description provided for @adminSeasonDeactivateQuestion.
  ///
  /// In en, this message translates to:
  /// **'Deactivate season?'**
  String get adminSeasonDeactivateQuestion;

  /// No description provided for @adminSeasonAvailabilityMessage.
  ///
  /// In en, this message translates to:
  /// **'{season} will be {availability} to configured competition journeys.'**
  String adminSeasonAvailabilityMessage(String season, String availability);

  /// No description provided for @adminAvailable.
  ///
  /// In en, this message translates to:
  /// **'available'**
  String get adminAvailable;

  /// No description provided for @adminUnavailable.
  ///
  /// In en, this message translates to:
  /// **'unavailable'**
  String get adminUnavailable;

  /// No description provided for @adminSeasonActivated.
  ///
  /// In en, this message translates to:
  /// **'Season activated'**
  String get adminSeasonActivated;

  /// No description provided for @adminSeasonDeactivated.
  ///
  /// In en, this message translates to:
  /// **'Season deactivated'**
  String get adminSeasonDeactivated;

  /// No description provided for @adminSeasonActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate season'**
  String get adminSeasonActivate;

  /// No description provided for @adminSeasonDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate season'**
  String get adminSeasonDeactivate;

  /// No description provided for @adminSeasonValidationMessage.
  ///
  /// In en, this message translates to:
  /// **'Check the season slug, label, and years.'**
  String get adminSeasonValidationMessage;

  /// No description provided for @adminSeasonAddUpper.
  ///
  /// In en, this message translates to:
  /// **'Add season'**
  String get adminSeasonAddUpper;

  /// No description provided for @adminSeasonSlugHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. league-2026'**
  String get adminSeasonSlugHint;

  /// No description provided for @adminSeasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get adminSeasonLabel;

  /// No description provided for @adminSeasonLabelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2025/2026'**
  String get adminSeasonLabelHint;

  /// No description provided for @adminSeasonYearStart.
  ///
  /// In en, this message translates to:
  /// **'Year start'**
  String get adminSeasonYearStart;

  /// No description provided for @adminSeasonYearEnd.
  ///
  /// In en, this message translates to:
  /// **'Year end'**
  String get adminSeasonYearEnd;

  /// No description provided for @adminCreateUpper.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get adminCreateUpper;

  /// No description provided for @adminSeasonStatusPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get adminSeasonStatusPlanned;

  /// No description provided for @adminSeasonStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminSeasonStatusActive;

  /// No description provided for @adminSeasonStatusFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get adminSeasonStatusFinished;

  /// No description provided for @adminSeasonStatusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get adminSeasonStatusArchived;

  /// No description provided for @adminNotificationSendTitle.
  ///
  /// In en, this message translates to:
  /// **'Send notification'**
  String get adminNotificationSendTitle;

  /// No description provided for @adminNotificationLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading notification workspace'**
  String get adminNotificationLoading;

  /// No description provided for @adminNotificationLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Checking controlled delivery information.'**
  String get adminNotificationLoadingMessage;

  /// No description provided for @adminNotificationDeliveryStatus.
  ///
  /// In en, this message translates to:
  /// **'Delivery status'**
  String get adminNotificationDeliveryStatus;

  /// No description provided for @adminNotificationDeliveryStatusMessage.
  ///
  /// In en, this message translates to:
  /// **'Delivery via Edge Functions. Scheduled sends dispatch on cron.'**
  String get adminNotificationDeliveryStatusMessage;

  /// No description provided for @adminNotificationAudience.
  ///
  /// In en, this message translates to:
  /// **'Audience'**
  String get adminNotificationAudience;

  /// No description provided for @adminNotificationAudienceAllFans.
  ///
  /// In en, this message translates to:
  /// **'All fans'**
  String get adminNotificationAudienceAllFans;

  /// No description provided for @adminNotificationAudienceByTier.
  ///
  /// In en, this message translates to:
  /// **'By tier'**
  String get adminNotificationAudienceByTier;

  /// No description provided for @adminNotificationAudienceByGroup.
  ///
  /// In en, this message translates to:
  /// **'By group'**
  String get adminNotificationAudienceByGroup;

  /// No description provided for @adminNotificationTierFan.
  ///
  /// In en, this message translates to:
  /// **'Fan'**
  String get adminNotificationTierFan;

  /// No description provided for @adminNotificationTierBronze.
  ///
  /// In en, this message translates to:
  /// **'Bronze'**
  String get adminNotificationTierBronze;

  /// No description provided for @adminNotificationTierGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get adminNotificationTierGold;

  /// No description provided for @adminNotificationTierPlatinum.
  ///
  /// In en, this message translates to:
  /// **'Platinum'**
  String get adminNotificationTierPlatinum;

  /// No description provided for @adminNotificationSelectGroup.
  ///
  /// In en, this message translates to:
  /// **'Select group'**
  String get adminNotificationSelectGroup;

  /// No description provided for @adminNotificationTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Notification title'**
  String get adminNotificationTitleLabel;

  /// No description provided for @adminNotificationBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Message body'**
  String get adminNotificationBodyLabel;

  /// No description provided for @adminNotificationCharacterCount.
  ///
  /// In en, this message translates to:
  /// **'{count} characters'**
  String adminNotificationCharacterCount(int count);

  /// No description provided for @adminNotificationImageUrl.
  ///
  /// In en, this message translates to:
  /// **'Optional image URL'**
  String get adminNotificationImageUrl;

  /// No description provided for @adminNotificationSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get adminNotificationSchedule;

  /// No description provided for @adminNotificationSendNow.
  ///
  /// In en, this message translates to:
  /// **'Send now'**
  String get adminNotificationSendNow;

  /// No description provided for @adminNotificationPickDateTime.
  ///
  /// In en, this message translates to:
  /// **'Pick date & time'**
  String get adminNotificationPickDateTime;

  /// No description provided for @adminNotificationScheduleAction.
  ///
  /// In en, this message translates to:
  /// **'Schedule notification'**
  String get adminNotificationScheduleAction;

  /// No description provided for @adminNotificationSendAction.
  ///
  /// In en, this message translates to:
  /// **'Send notification'**
  String get adminNotificationSendAction;

  /// No description provided for @adminNotificationCopyPayload.
  ///
  /// In en, this message translates to:
  /// **'Copy payload'**
  String get adminNotificationCopyPayload;

  /// No description provided for @adminNotificationSendHistory.
  ///
  /// In en, this message translates to:
  /// **'Send history'**
  String get adminNotificationSendHistory;

  /// No description provided for @adminNotificationHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notification history'**
  String get adminNotificationHistoryEmpty;

  /// No description provided for @adminNotificationHistoryEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Confirmed delivery records will appear here after a request.'**
  String get adminNotificationHistoryEmptyMessage;

  /// No description provided for @adminNotificationManagementUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Notification management unavailable'**
  String get adminNotificationManagementUnavailable;

  /// No description provided for @adminNotificationControlsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Notification controls are disabled for this controlled build.'**
  String get adminNotificationControlsDisabled;

  /// No description provided for @adminNotificationWorkspaceOffline.
  ///
  /// In en, this message translates to:
  /// **'Notification workspace offline'**
  String get adminNotificationWorkspaceOffline;

  /// No description provided for @adminNotificationOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect before loading private delivery information.'**
  String get adminNotificationOfflineMessage;

  /// No description provided for @adminNotificationAccessUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Notification access unavailable'**
  String get adminNotificationAccessUnavailable;

  /// No description provided for @adminNotificationAccessMessage.
  ///
  /// In en, this message translates to:
  /// **'This account cannot view or send notifications.'**
  String get adminNotificationAccessMessage;

  /// No description provided for @adminNotificationDataChanged.
  ///
  /// In en, this message translates to:
  /// **'Delivery information changed'**
  String get adminNotificationDataChanged;

  /// No description provided for @adminNotificationDataChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh before making another notification request.'**
  String get adminNotificationDataChangedMessage;

  /// No description provided for @adminNotificationSecurityMessage.
  ///
  /// In en, this message translates to:
  /// **'No delivery information was shown. Check your connection.'**
  String get adminNotificationSecurityMessage;

  /// No description provided for @adminNotificationWorkspaceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Notification workspace unavailable'**
  String get adminNotificationWorkspaceUnavailable;

  /// No description provided for @adminNotificationHiddenMessage.
  ///
  /// In en, this message translates to:
  /// **'Private delivery information remains hidden. Try again.'**
  String get adminNotificationHiddenMessage;

  /// No description provided for @adminNotificationChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking delivery information'**
  String get adminNotificationChecking;

  /// No description provided for @adminNotificationCheckingMessage.
  ///
  /// In en, this message translates to:
  /// **'Showing the last confirmed state while current data is checked.'**
  String get adminNotificationCheckingMessage;

  /// No description provided for @adminNotificationOutcomeUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'The last request is unconfirmed. Controls stay paused until refresh succeeds.'**
  String get adminNotificationOutcomeUnconfirmed;

  /// No description provided for @adminNotificationLastConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Last confirmed delivery information remains visible. Controls are paused.'**
  String get adminNotificationLastConfirmed;

  /// No description provided for @adminNotificationValidationTitleBody.
  ///
  /// In en, this message translates to:
  /// **'Add a title and message body first.'**
  String get adminNotificationValidationTitleBody;

  /// No description provided for @adminNotificationValidationTier.
  ///
  /// In en, this message translates to:
  /// **'Choose the target tier first.'**
  String get adminNotificationValidationTier;

  /// No description provided for @adminNotificationValidationGroup.
  ///
  /// In en, this message translates to:
  /// **'Choose the target group first.'**
  String get adminNotificationValidationGroup;

  /// No description provided for @adminNotificationValidationSchedule.
  ///
  /// In en, this message translates to:
  /// **'Pick the delivery date and time first.'**
  String get adminNotificationValidationSchedule;

  /// No description provided for @adminNotificationQueued.
  ///
  /// In en, this message translates to:
  /// **'Notification queued for scheduled delivery.'**
  String get adminNotificationQueued;

  /// No description provided for @adminNotificationScheduledFor.
  ///
  /// In en, this message translates to:
  /// **'Notification scheduled for {date}.'**
  String adminNotificationScheduledFor(String date);

  /// No description provided for @adminNotificationSentSummary.
  ///
  /// In en, this message translates to:
  /// **'Sent to {requested} supporters. {sent} delivered.'**
  String adminNotificationSentSummary(int requested, int sent);

  /// No description provided for @adminNotificationPartialSummary.
  ///
  /// In en, this message translates to:
  /// **'Partial: {sent} delivered, {failed} failed.'**
  String adminNotificationPartialSummary(int sent, int failed);

  /// No description provided for @adminNotificationDeliveryFailed.
  ///
  /// In en, this message translates to:
  /// **'Notification delivery failed.'**
  String get adminNotificationDeliveryFailed;

  /// No description provided for @adminNotificationRequestRecorded.
  ///
  /// In en, this message translates to:
  /// **'Notification request recorded.'**
  String get adminNotificationRequestRecorded;

  /// No description provided for @adminNotificationHistoryMetrics.
  ///
  /// In en, this message translates to:
  /// **' • {requested} targets • {sent} sent • {failed} failed'**
  String adminNotificationHistoryMetrics(int requested, int sent, int failed);

  /// No description provided for @adminNotificationFieldsInvalid.
  ///
  /// In en, this message translates to:
  /// **'Review the notification fields and try again.'**
  String get adminNotificationFieldsInvalid;

  /// No description provided for @adminNotificationRequestUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Notification request was not confirmed.'**
  String get adminNotificationRequestUnconfirmed;

  /// No description provided for @adminNotificationPayloadCopied.
  ///
  /// In en, this message translates to:
  /// **'Payload copied to clipboard.'**
  String get adminNotificationPayloadCopied;

  /// No description provided for @adminNotificationTierNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Tier not selected'**
  String get adminNotificationTierNotSelected;

  /// No description provided for @adminNotificationTierPreview.
  ///
  /// In en, this message translates to:
  /// **'Tier • {tier}'**
  String adminNotificationTierPreview(String tier);

  /// No description provided for @adminNotificationGroupNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Group not selected'**
  String get adminNotificationGroupNotSelected;

  /// No description provided for @adminNotificationGroupPreview.
  ///
  /// In en, this message translates to:
  /// **'Group • {group}'**
  String adminNotificationGroupPreview(String group);

  /// No description provided for @adminNotificationAllSupporters.
  ///
  /// In en, this message translates to:
  /// **'All supporters'**
  String get adminNotificationAllSupporters;

  /// No description provided for @adminNotificationPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get adminNotificationPreview;

  /// No description provided for @adminNotificationPreviewBody.
  ///
  /// In en, this message translates to:
  /// **'Your message preview appears here.'**
  String get adminNotificationPreviewBody;

  /// No description provided for @adminNotificationStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get adminNotificationStatusScheduled;

  /// No description provided for @adminNotificationStatusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get adminNotificationStatusSent;

  /// No description provided for @adminNotificationStatusPartial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get adminNotificationStatusPartial;

  /// No description provided for @adminNotificationStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get adminNotificationStatusFailed;

  /// No description provided for @adminContributionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Contributions'**
  String get adminContributionsTitle;

  /// No description provided for @adminContributionsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading contributions'**
  String get adminContributionsLoading;

  /// No description provided for @adminContributionsLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Checking the controlled contribution monitor.'**
  String get adminContributionsLoadingMessage;

  /// No description provided for @adminContributionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Review club-scoped group totals without exposing supporter or payment identifiers.'**
  String get adminContributionsDescription;

  /// No description provided for @adminContributionsMonthlyTotal.
  ///
  /// In en, this message translates to:
  /// **'Total recorded this month'**
  String get adminContributionsMonthlyTotal;

  /// No description provided for @adminContributionsSummary.
  ///
  /// In en, this message translates to:
  /// **'{groups} groups • {records} bounded records'**
  String adminContributionsSummary(int groups, int records);

  /// No description provided for @adminContributionsNoGroups.
  ///
  /// In en, this message translates to:
  /// **'No contribution groups'**
  String get adminContributionsNoGroups;

  /// No description provided for @adminContributionsNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No groups match'**
  String get adminContributionsNoMatch;

  /// No description provided for @adminContributionsNoGroupsMessage.
  ///
  /// In en, this message translates to:
  /// **'Confirmed club-scoped contribution groups will appear here.'**
  String get adminContributionsNoGroupsMessage;

  /// No description provided for @adminContributionsNoMatchMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose another contribution group filter.'**
  String get adminContributionsNoMatchMessage;

  /// No description provided for @adminContributionsExport.
  ///
  /// In en, this message translates to:
  /// **'Export privacy-safe report'**
  String get adminContributionsExport;

  /// No description provided for @adminContributionsReportCopied.
  ///
  /// In en, this message translates to:
  /// **'Privacy-safe contribution report copied.'**
  String get adminContributionsReportCopied;

  /// No description provided for @adminContributionsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Contribution monitor unavailable'**
  String get adminContributionsUnavailable;

  /// No description provided for @adminContributionsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Contribution monitoring is disabled for this controlled build.'**
  String get adminContributionsDisabled;

  /// No description provided for @adminContributionsOffline.
  ///
  /// In en, this message translates to:
  /// **'Contribution monitor offline'**
  String get adminContributionsOffline;

  /// No description provided for @adminContributionsOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect before loading private contribution records.'**
  String get adminContributionsOfflineMessage;

  /// No description provided for @adminContributionsAccessUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Contribution access unavailable'**
  String get adminContributionsAccessUnavailable;

  /// No description provided for @adminContributionsAccessMessage.
  ///
  /// In en, this message translates to:
  /// **'This account cannot view private contribution operations.'**
  String get adminContributionsAccessMessage;

  /// No description provided for @adminContributionsDataChanged.
  ///
  /// In en, this message translates to:
  /// **'Contribution data changed'**
  String get adminContributionsDataChanged;

  /// No description provided for @adminContributionsDataChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh before relying on contribution totals.'**
  String get adminContributionsDataChangedMessage;

  /// No description provided for @adminContributionsSecurityMessage.
  ///
  /// In en, this message translates to:
  /// **'No contribution records were shown. Check your connection.'**
  String get adminContributionsSecurityMessage;

  /// No description provided for @adminContributionsHiddenMessage.
  ///
  /// In en, this message translates to:
  /// **'Private contribution records remain hidden. Try again.'**
  String get adminContributionsHiddenMessage;

  /// No description provided for @adminContributionsRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing contributions'**
  String get adminContributionsRefreshing;

  /// No description provided for @adminContributionsRefreshingMessage.
  ///
  /// In en, this message translates to:
  /// **'Showing the last confirmed totals while current data is checked.'**
  String get adminContributionsRefreshingMessage;

  /// No description provided for @adminContributionsLastConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Last confirmed totals remain visible. Controls are paused until refresh succeeds.'**
  String get adminContributionsLastConfirmed;

  /// No description provided for @adminContributionsGroupType.
  ///
  /// In en, this message translates to:
  /// **'Group type'**
  String get adminContributionsGroupType;

  /// No description provided for @adminContributionsSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get adminContributionsSort;

  /// No description provided for @adminContributionsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get adminContributionsFilterAll;

  /// No description provided for @adminContributionsTeamProjects.
  ///
  /// In en, this message translates to:
  /// **'Team projects'**
  String get adminContributionsTeamProjects;

  /// No description provided for @adminContributionsCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get adminContributionsCommunity;

  /// No description provided for @adminContributionsRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get adminContributionsRecent;

  /// No description provided for @adminContributionsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get adminContributionsTotal;

  /// No description provided for @adminContributionsClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get adminContributionsClosed;

  /// No description provided for @adminContributionsActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminContributionsActive;

  /// No description provided for @adminContributionsTeamProject.
  ///
  /// In en, this message translates to:
  /// **'Team project'**
  String get adminContributionsTeamProject;

  /// No description provided for @adminContributionsRecordMembers.
  ///
  /// In en, this message translates to:
  /// **'{records} bounded records • {members} registered members'**
  String adminContributionsRecordMembers(int records, int members);

  /// No description provided for @adminContributionsActivityPending.
  ///
  /// In en, this message translates to:
  /// **'Payment activity pending'**
  String get adminContributionsActivityPending;

  /// No description provided for @adminContributionsLastActivity.
  ///
  /// In en, this message translates to:
  /// **'Last activity {date}'**
  String adminContributionsLastActivity(String date);

  /// No description provided for @adminSmsTitle.
  ///
  /// In en, this message translates to:
  /// **'SMS operations'**
  String get adminSmsTitle;

  /// No description provided for @adminSmsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading SMS operations'**
  String get adminSmsLoading;

  /// No description provided for @adminSmsLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Checking controlled pipeline health information.'**
  String get adminSmsLoadingMessage;

  /// No description provided for @adminSmsNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No SMS operations history'**
  String get adminSmsNoHistory;

  /// No description provided for @adminSmsNoHistoryMessage.
  ///
  /// In en, this message translates to:
  /// **'No controlled health signals or synchronization runs are available yet.'**
  String get adminSmsNoHistoryMessage;

  /// No description provided for @adminSmsControlledHealth.
  ///
  /// In en, this message translates to:
  /// **'Controlled health view'**
  String get adminSmsControlledHealth;

  /// No description provided for @adminSmsControlledHealthMessage.
  ///
  /// In en, this message translates to:
  /// **'Review device synchronization, message checks, contribution matching, sender drift, retries, and privacy cleanup without displaying message bodies or supporter identifiers.'**
  String get adminSmsControlledHealthMessage;

  /// No description provided for @adminSmsPipelineHealth.
  ///
  /// In en, this message translates to:
  /// **'Pipeline health'**
  String get adminSmsPipelineHealth;

  /// No description provided for @adminSmsRecentSync.
  ///
  /// In en, this message translates to:
  /// **'Recent device synchronization'**
  String get adminSmsRecentSync;

  /// No description provided for @adminSmsNoRecentRuns.
  ///
  /// In en, this message translates to:
  /// **'No recent synchronization runs'**
  String get adminSmsNoRecentRuns;

  /// No description provided for @adminSmsNoRecentRunsMessage.
  ///
  /// In en, this message translates to:
  /// **'The health summary remains available above.'**
  String get adminSmsNoRecentRunsMessage;

  /// No description provided for @adminSmsMetricSemantics.
  ///
  /// In en, this message translates to:
  /// **'{label}, {status}'**
  String adminSmsMetricSemantics(String label, String status);

  /// No description provided for @adminSmsCollapseDetails.
  ///
  /// In en, this message translates to:
  /// **'Collapse health details'**
  String get adminSmsCollapseDetails;

  /// No description provided for @adminSmsExpandDetails.
  ///
  /// In en, this message translates to:
  /// **'Expand health details'**
  String get adminSmsExpandDetails;

  /// No description provided for @adminSmsLastSignal.
  ///
  /// In en, this message translates to:
  /// **'Last confirmed signal {date}'**
  String adminSmsLastSignal(String date);

  /// No description provided for @adminSmsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'SMS operations unavailable'**
  String get adminSmsUnavailable;

  /// No description provided for @adminSmsDisabled.
  ///
  /// In en, this message translates to:
  /// **'SMS operations monitoring is disabled for this build.'**
  String get adminSmsDisabled;

  /// No description provided for @adminSmsOffline.
  ///
  /// In en, this message translates to:
  /// **'SMS operations offline'**
  String get adminSmsOffline;

  /// No description provided for @adminSmsOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect before loading private operational information.'**
  String get adminSmsOfflineMessage;

  /// No description provided for @adminSmsAccessUnavailable.
  ///
  /// In en, this message translates to:
  /// **'SMS operations access unavailable'**
  String get adminSmsAccessUnavailable;

  /// No description provided for @adminSmsAccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Platform administrator access is required for this view.'**
  String get adminSmsAccessMessage;

  /// No description provided for @adminSmsChanged.
  ///
  /// In en, this message translates to:
  /// **'SMS operations changed'**
  String get adminSmsChanged;

  /// No description provided for @adminSmsChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh before using this operational information.'**
  String get adminSmsChangedMessage;

  /// No description provided for @adminSmsSecurityMessage.
  ///
  /// In en, this message translates to:
  /// **'No operational information was shown. Check your connection.'**
  String get adminSmsSecurityMessage;

  /// No description provided for @adminSmsHiddenMessage.
  ///
  /// In en, this message translates to:
  /// **'Private operational information remains hidden. Try again.'**
  String get adminSmsHiddenMessage;

  /// No description provided for @adminSmsChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking SMS operations'**
  String get adminSmsChecking;

  /// No description provided for @adminSmsCheckingMessage.
  ///
  /// In en, this message translates to:
  /// **'Showing the last confirmed state while current data is checked.'**
  String get adminSmsCheckingMessage;

  /// No description provided for @adminSmsLastConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Last confirmed operational information remains visible. Controls are paused.'**
  String get adminSmsLastConfirmed;

  /// No description provided for @adminSmsStatusHealthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get adminSmsStatusHealthy;

  /// No description provided for @adminSmsStatusSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Succeeded'**
  String get adminSmsStatusSucceeded;

  /// No description provided for @adminSmsStatusDegraded.
  ///
  /// In en, this message translates to:
  /// **'Degraded'**
  String get adminSmsStatusDegraded;

  /// No description provided for @adminSmsStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get adminSmsStatusRunning;

  /// No description provided for @adminSmsStatusRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Rate limited'**
  String get adminSmsStatusRateLimited;

  /// No description provided for @adminSmsStatusFailing.
  ///
  /// In en, this message translates to:
  /// **'Failing'**
  String get adminSmsStatusFailing;

  /// No description provided for @adminSmsStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get adminSmsStatusFailed;

  /// No description provided for @adminSmsTriggerInitial.
  ///
  /// In en, this message translates to:
  /// **'Initial history'**
  String get adminSmsTriggerInitial;

  /// No description provided for @adminSmsTriggerManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get adminSmsTriggerManual;

  /// No description provided for @adminSmsTriggerControlled.
  ///
  /// In en, this message translates to:
  /// **'Controlled'**
  String get adminSmsTriggerControlled;

  /// No description provided for @adminSmsRunTitle.
  ///
  /// In en, this message translates to:
  /// **'{status} • {trigger}'**
  String adminSmsRunTitle(String status, String trigger);

  /// No description provided for @adminSmsRunMetrics.
  ///
  /// In en, this message translates to:
  /// **'{scanned} scanned • {uploaded} uploaded • {duplicates} duplicates'**
  String adminSmsRunMetrics(int scanned, int uploaded, int duplicates);

  /// No description provided for @adminCmsTitle.
  ///
  /// In en, this message translates to:
  /// **'Content manager'**
  String get adminCmsTitle;

  /// No description provided for @adminCmsDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage home shortcuts, partner catalogs, and supported prediction competitions.'**
  String get adminCmsDescription;

  /// No description provided for @adminCmsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading content manager'**
  String get adminCmsLoading;

  /// No description provided for @adminCmsLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Checking current publishing work.'**
  String get adminCmsLoadingMessage;

  /// No description provided for @adminCmsNoContent.
  ///
  /// In en, this message translates to:
  /// **'No managed content'**
  String get adminCmsNoContent;

  /// No description provided for @adminCmsNoContentMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose a section to create the first controlled item.'**
  String get adminCmsNoContentMessage;

  /// No description provided for @adminCmsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Content manager unavailable'**
  String get adminCmsUnavailable;

  /// No description provided for @adminCmsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Publishing controls are disabled for this controlled build.'**
  String get adminCmsDisabled;

  /// No description provided for @adminCmsOffline.
  ///
  /// In en, this message translates to:
  /// **'Content manager offline'**
  String get adminCmsOffline;

  /// No description provided for @adminCmsOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect before loading private publishing controls.'**
  String get adminCmsOfflineMessage;

  /// No description provided for @adminCmsAccessUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Content access unavailable'**
  String get adminCmsAccessUnavailable;

  /// No description provided for @adminCmsAccessMessage.
  ///
  /// In en, this message translates to:
  /// **'This account cannot view or change club publishing data.'**
  String get adminCmsAccessMessage;

  /// No description provided for @adminCmsChanged.
  ///
  /// In en, this message translates to:
  /// **'Content changed'**
  String get adminCmsChanged;

  /// No description provided for @adminCmsChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh the workspace before making another change.'**
  String get adminCmsChangedMessage;

  /// No description provided for @adminCmsSecurityMessage.
  ///
  /// In en, this message translates to:
  /// **'No private content was shown. Check your connection and retry.'**
  String get adminCmsSecurityMessage;

  /// No description provided for @adminCmsHiddenMessage.
  ///
  /// In en, this message translates to:
  /// **'Private publishing data remains hidden. Try again.'**
  String get adminCmsHiddenMessage;

  /// No description provided for @adminCmsSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving content'**
  String get adminCmsSaving;

  /// No description provided for @adminCmsSavingMessage.
  ///
  /// In en, this message translates to:
  /// **'Publishing controls are paused until the result is confirmed.'**
  String get adminCmsSavingMessage;

  /// No description provided for @adminCmsRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing content'**
  String get adminCmsRefreshing;

  /// No description provided for @adminCmsRefreshingMessage.
  ///
  /// In en, this message translates to:
  /// **'Showing the last confirmed workspace while status is checked.'**
  String get adminCmsRefreshingMessage;

  /// No description provided for @adminCmsCurrentRefreshUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Current refresh unavailable'**
  String get adminCmsCurrentRefreshUnavailable;

  /// No description provided for @adminCmsOutcomeUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'The last change is not confirmed. Refresh before taking another action.'**
  String get adminCmsOutcomeUnconfirmed;

  /// No description provided for @adminCmsLastConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Showing the last confirmed workspace. Actions are paused until refresh succeeds.'**
  String get adminCmsLastConfirmed;

  /// No description provided for @adminCmsChangeOffline.
  ///
  /// In en, this message translates to:
  /// **'CMS changes need a connection. Nothing was retried.'**
  String get adminCmsChangeOffline;

  /// No description provided for @adminCmsChangeAccess.
  ///
  /// In en, this message translates to:
  /// **'CMS access is no longer available for this account.'**
  String get adminCmsChangeAccess;

  /// No description provided for @adminCmsChangeConflict.
  ///
  /// In en, this message translates to:
  /// **'CMS content changed. Refresh before trying another action.'**
  String get adminCmsChangeConflict;

  /// No description provided for @adminCmsChangeUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'The result is not confirmed. Refresh before trying another action.'**
  String get adminCmsChangeUnconfirmed;

  /// No description provided for @adminCmsChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'The CMS change could not be completed. Review and try again.'**
  String get adminCmsChangeFailed;

  /// No description provided for @adminCmsAddContentBlock.
  ///
  /// In en, this message translates to:
  /// **'Add content block'**
  String get adminCmsAddContentBlock;

  /// No description provided for @adminCmsEditContentBlock.
  ///
  /// In en, this message translates to:
  /// **'Edit content block'**
  String get adminCmsEditContentBlock;

  /// No description provided for @adminCmsBlockKey.
  ///
  /// In en, this message translates to:
  /// **'Block key (e.g. home_hero_1)'**
  String get adminCmsBlockKey;

  /// No description provided for @adminCmsBlockType.
  ///
  /// In en, this message translates to:
  /// **'Block type (e.g. banner)'**
  String get adminCmsBlockType;

  /// No description provided for @adminCmsTargetChannel.
  ///
  /// In en, this message translates to:
  /// **'Target channel'**
  String get adminCmsTargetChannel;

  /// No description provided for @adminCmsPlacementKey.
  ///
  /// In en, this message translates to:
  /// **'Placement key'**
  String get adminCmsPlacementKey;

  /// No description provided for @adminCmsTitleField.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get adminCmsTitleField;

  /// No description provided for @adminCmsSubtitleField.
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get adminCmsSubtitleField;

  /// No description provided for @adminCmsContentComponent.
  ///
  /// In en, this message translates to:
  /// **'Content component name'**
  String get adminCmsContentComponent;

  /// No description provided for @adminCmsFeatureField.
  ///
  /// In en, this message translates to:
  /// **'Feature'**
  String get adminCmsFeatureField;

  /// No description provided for @adminCmsNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get adminCmsNone;

  /// No description provided for @adminCmsSortOrder.
  ///
  /// In en, this message translates to:
  /// **'Sort order'**
  String get adminCmsSortOrder;

  /// No description provided for @adminCmsActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminCmsActive;

  /// No description provided for @adminCmsCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get adminCmsCreate;

  /// No description provided for @adminCmsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get adminCmsSave;

  /// No description provided for @adminCmsNewArticle.
  ///
  /// In en, this message translates to:
  /// **'New article'**
  String get adminCmsNewArticle;

  /// No description provided for @adminCmsArticleTitle.
  ///
  /// In en, this message translates to:
  /// **'Article title'**
  String get adminCmsArticleTitle;

  /// No description provided for @adminCmsArticleBody.
  ///
  /// In en, this message translates to:
  /// **'Article body'**
  String get adminCmsArticleBody;

  /// No description provided for @adminCmsAddQuickAction.
  ///
  /// In en, this message translates to:
  /// **'Add quick action'**
  String get adminCmsAddQuickAction;

  /// No description provided for @adminCmsEditQuickAction.
  ///
  /// In en, this message translates to:
  /// **'Edit quick action'**
  String get adminCmsEditQuickAction;

  /// No description provided for @adminCmsActionKey.
  ///
  /// In en, this message translates to:
  /// **'Action key'**
  String get adminCmsActionKey;

  /// No description provided for @adminCmsRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get adminCmsRoute;

  /// No description provided for @adminCmsIconKey.
  ///
  /// In en, this message translates to:
  /// **'Icon key'**
  String get adminCmsIconKey;

  /// No description provided for @adminCmsEmoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get adminCmsEmoji;

  /// No description provided for @adminCmsCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get adminCmsCountry;

  /// No description provided for @adminCmsAddPartner.
  ///
  /// In en, this message translates to:
  /// **'Add partner'**
  String get adminCmsAddPartner;

  /// No description provided for @adminCmsEditPartner.
  ///
  /// In en, this message translates to:
  /// **'Edit partner'**
  String get adminCmsEditPartner;

  /// No description provided for @adminCmsName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get adminCmsName;

  /// No description provided for @adminCmsSlug.
  ///
  /// In en, this message translates to:
  /// **'Slug'**
  String get adminCmsSlug;

  /// No description provided for @adminCmsCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get adminCmsCategory;

  /// No description provided for @adminCmsDescriptionField.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get adminCmsDescriptionField;

  /// No description provided for @adminCmsGamificationLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked to gamification'**
  String get adminCmsGamificationLinked;

  /// No description provided for @adminCmsCreatePartnerFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a partner first.'**
  String get adminCmsCreatePartnerFirst;

  /// No description provided for @adminCmsAddPartnerService.
  ///
  /// In en, this message translates to:
  /// **'Add partner service'**
  String get adminCmsAddPartnerService;

  /// No description provided for @adminCmsEditPartnerService.
  ///
  /// In en, this message translates to:
  /// **'Edit partner service'**
  String get adminCmsEditPartnerService;

  /// No description provided for @adminCmsPartner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get adminCmsPartner;

  /// No description provided for @adminCmsServiceSlug.
  ///
  /// In en, this message translates to:
  /// **'Service slug'**
  String get adminCmsServiceSlug;

  /// No description provided for @adminCmsCtaLabel.
  ///
  /// In en, this message translates to:
  /// **'CTA label'**
  String get adminCmsCtaLabel;

  /// No description provided for @adminCmsCtaAction.
  ///
  /// In en, this message translates to:
  /// **'CTA action'**
  String get adminCmsCtaAction;

  /// No description provided for @adminCmsAllCompetitionsAdded.
  ///
  /// In en, this message translates to:
  /// **'All active competitions are already in the prediction catalog.'**
  String get adminCmsAllCompetitionsAdded;

  /// No description provided for @adminCmsAddPredictionCompetition.
  ///
  /// In en, this message translates to:
  /// **'Add prediction competition'**
  String get adminCmsAddPredictionCompetition;

  /// No description provided for @adminCmsEditPredictionCompetition.
  ///
  /// In en, this message translates to:
  /// **'Edit prediction competition'**
  String get adminCmsEditPredictionCompetition;

  /// No description provided for @adminCmsCompetition.
  ///
  /// In en, this message translates to:
  /// **'Competition'**
  String get adminCmsCompetition;

  /// No description provided for @adminCmsHighlightLabel.
  ///
  /// In en, this message translates to:
  /// **'Highlight label'**
  String get adminCmsHighlightLabel;

  /// No description provided for @adminCmsChannelMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get adminCmsChannelMobile;

  /// No description provided for @adminCmsChannelWeb.
  ///
  /// In en, this message translates to:
  /// **'Web'**
  String get adminCmsChannelWeb;

  /// No description provided for @adminCmsChannelBoth.
  ///
  /// In en, this message translates to:
  /// **'Mobile and web'**
  String get adminCmsChannelBoth;

  /// No description provided for @adminCmsCategoryOrganization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get adminCmsCategoryOrganization;

  /// No description provided for @adminCmsCategoryBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get adminCmsCategoryBank;

  /// No description provided for @adminCmsCategoryFootball.
  ///
  /// In en, this message translates to:
  /// **'Football'**
  String get adminCmsCategoryFootball;

  /// No description provided for @adminCmsCategoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get adminCmsCategoryGeneral;

  /// No description provided for @adminCmsCategoryCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get adminCmsCategoryCommunity;

  /// No description provided for @adminCmsCategoryInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get adminCmsCategoryInsurance;

  /// No description provided for @adminCmsCategoryMobility.
  ///
  /// In en, this message translates to:
  /// **'Mobility'**
  String get adminCmsCategoryMobility;

  /// No description provided for @adminCmsSectionNews.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get adminCmsSectionNews;

  /// No description provided for @adminCmsSectionQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get adminCmsSectionQuickActions;

  /// No description provided for @adminCmsSectionPartners.
  ///
  /// In en, this message translates to:
  /// **'Partners'**
  String get adminCmsSectionPartners;

  /// No description provided for @adminCmsSectionServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get adminCmsSectionServices;

  /// No description provided for @adminCmsSectionPredictions.
  ///
  /// In en, this message translates to:
  /// **'Predictions'**
  String get adminCmsSectionPredictions;

  /// No description provided for @adminCmsSectionPlacements.
  ///
  /// In en, this message translates to:
  /// **'Placements'**
  String get adminCmsSectionPlacements;

  /// No description provided for @adminCmsSectionAuditLogs.
  ///
  /// In en, this message translates to:
  /// **'Audit logs'**
  String get adminCmsSectionAuditLogs;

  /// No description provided for @adminCmsNewsArticles.
  ///
  /// In en, this message translates to:
  /// **'News articles'**
  String get adminCmsNewsArticles;

  /// No description provided for @adminCmsAddArticle.
  ///
  /// In en, this message translates to:
  /// **'Add article'**
  String get adminCmsAddArticle;

  /// No description provided for @adminCmsHomeQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Home quick actions'**
  String get adminCmsHomeQuickActions;

  /// No description provided for @adminCmsAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add action'**
  String get adminCmsAddAction;

  /// No description provided for @adminCmsPartners.
  ///
  /// In en, this message translates to:
  /// **'Partners'**
  String get adminCmsPartners;

  /// No description provided for @adminCmsAddPartnerAction.
  ///
  /// In en, this message translates to:
  /// **'Add partner'**
  String get adminCmsAddPartnerAction;

  /// No description provided for @adminCmsPartnerServices.
  ///
  /// In en, this message translates to:
  /// **'Partner services'**
  String get adminCmsPartnerServices;

  /// No description provided for @adminCmsAddService.
  ///
  /// In en, this message translates to:
  /// **'Add service'**
  String get adminCmsAddService;

  /// No description provided for @adminCmsPredictionCompetitions.
  ///
  /// In en, this message translates to:
  /// **'Prediction competitions'**
  String get adminCmsPredictionCompetitions;

  /// No description provided for @adminCmsAddCompetition.
  ///
  /// In en, this message translates to:
  /// **'Add competition'**
  String get adminCmsAddCompetition;

  /// No description provided for @adminCmsContentBlocks.
  ///
  /// In en, this message translates to:
  /// **'Platform content blocks'**
  String get adminCmsContentBlocks;

  /// No description provided for @adminCmsAddBlock.
  ///
  /// In en, this message translates to:
  /// **'Add block'**
  String get adminCmsAddBlock;

  /// No description provided for @adminCmsAuditLogs.
  ///
  /// In en, this message translates to:
  /// **'Feature management audit logs'**
  String get adminCmsAuditLogs;

  /// No description provided for @adminCmsQuickActionFallback.
  ///
  /// In en, this message translates to:
  /// **'Quick action'**
  String get adminCmsQuickActionFallback;

  /// No description provided for @adminCmsServiceFallback.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get adminCmsServiceFallback;

  /// No description provided for @adminCmsCompetitionFallback.
  ///
  /// In en, this message translates to:
  /// **'Competition'**
  String get adminCmsCompetitionFallback;

  /// No description provided for @adminCmsContentBlockFallback.
  ///
  /// In en, this message translates to:
  /// **'Content block'**
  String get adminCmsContentBlockFallback;

  /// No description provided for @adminCmsActiveUpper.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminCmsActiveUpper;

  /// No description provided for @adminCmsInactiveUpper.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get adminCmsInactiveUpper;

  /// No description provided for @adminCmsGamificationUpper.
  ///
  /// In en, this message translates to:
  /// **'Gamification'**
  String get adminCmsGamificationUpper;

  /// No description provided for @adminCmsDirectUpper.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get adminCmsDirectUpper;

  /// No description provided for @adminCmsStandardUpper.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get adminCmsStandardUpper;

  /// No description provided for @adminCmsDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get adminCmsDeactivate;

  /// No description provided for @adminCmsActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get adminCmsActivate;

  /// No description provided for @adminCmsCtaPending.
  ///
  /// In en, this message translates to:
  /// **'CTA pending'**
  String get adminCmsCtaPending;

  /// No description provided for @adminCmsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'n/a'**
  String get adminCmsNotAvailable;

  /// No description provided for @adminCmsCompetitionSummary.
  ///
  /// In en, this message translates to:
  /// **'{kind} • {count} fixtures'**
  String adminCmsCompetitionSummary(String kind, int count);

  /// No description provided for @adminCmsCatalog.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get adminCmsCatalog;

  /// No description provided for @adminCmsSupported.
  ///
  /// In en, this message translates to:
  /// **'Supported'**
  String get adminCmsSupported;

  /// No description provided for @adminCmsUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get adminCmsUnknown;

  /// No description provided for @adminCmsUnknownFeature.
  ///
  /// In en, this message translates to:
  /// **'Unknown feature'**
  String get adminCmsUnknownFeature;

  /// No description provided for @adminCmsUnknownDate.
  ///
  /// In en, this message translates to:
  /// **'Unknown date'**
  String get adminCmsUnknownDate;

  /// No description provided for @adminCmsActionFallback.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get adminCmsActionFallback;

  /// No description provided for @adminCmsFeatureName.
  ///
  /// In en, this message translates to:
  /// **'Feature: {feature}'**
  String adminCmsFeatureName(String feature);

  /// No description provided for @adminCmsActorWithheld.
  ///
  /// In en, this message translates to:
  /// **'Actor details are withheld in the mobile workspace.'**
  String get adminCmsActorWithheld;

  /// No description provided for @adminCmsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get adminCmsEdit;

  /// No description provided for @adminCmsUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get adminCmsUntitled;

  /// No description provided for @adminCmsNewsFallback.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get adminCmsNewsFallback;

  /// No description provided for @adminCmsLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get adminCmsLive;

  /// No description provided for @adminCmsDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get adminCmsDraft;

  /// No description provided for @adminCmsNotPublished.
  ///
  /// In en, this message translates to:
  /// **'Not published'**
  String get adminCmsNotPublished;

  /// No description provided for @adminCmsFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get adminCmsFeatured;

  /// No description provided for @adminCmsArticleMeta.
  ///
  /// In en, this message translates to:
  /// **'{category} • {date}{featured}'**
  String adminCmsArticleMeta(String category, String date, String featured);

  /// No description provided for @adminCmsUnpublish.
  ///
  /// In en, this message translates to:
  /// **'Unpublish'**
  String get adminCmsUnpublish;

  /// No description provided for @adminCmsPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get adminCmsPublish;

  /// No description provided for @adminCmsPair.
  ///
  /// In en, this message translates to:
  /// **'{first} • {second}'**
  String adminCmsPair(String first, String second);

  /// No description provided for @gameCommunityPicks.
  ///
  /// In en, this message translates to:
  /// **'Community picks'**
  String get gameCommunityPicks;

  /// No description provided for @gameFetProgress.
  ///
  /// In en, this message translates to:
  /// **'FET progress'**
  String get gameFetProgress;

  /// No description provided for @gameFet.
  ///
  /// In en, this message translates to:
  /// **'FET'**
  String get gameFet;

  /// No description provided for @gameLevelUp.
  ///
  /// In en, this message translates to:
  /// **'Level up!'**
  String get gameLevelUp;

  /// No description provided for @gameAwesome.
  ///
  /// In en, this message translates to:
  /// **'Awesome'**
  String get gameAwesome;

  /// No description provided for @gameKeepGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get gameKeepGoing;

  /// No description provided for @gameLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get gameLive;

  /// No description provided for @gameOutcomePick.
  ///
  /// In en, this message translates to:
  /// **'{outcome} pick'**
  String gameOutcomePick(String outcome);

  /// No description provided for @gamePoints.
  ///
  /// In en, this message translates to:
  /// **'+{count} pts'**
  String gamePoints(int count);

  /// No description provided for @gameDaysShort.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get gameDaysShort;

  /// No description provided for @gameHoursShort.
  ///
  /// In en, this message translates to:
  /// **'Hrs'**
  String get gameHoursShort;

  /// No description provided for @gameMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get gameMinutesShort;

  /// No description provided for @gameSecondsShort.
  ///
  /// In en, this message translates to:
  /// **'Sec'**
  String get gameSecondsShort;

  /// No description provided for @gameDismissNotification.
  ///
  /// In en, this message translates to:
  /// **'Dismiss notification'**
  String get gameDismissNotification;

  /// No description provided for @gamePredictions.
  ///
  /// In en, this message translates to:
  /// **'Predictions'**
  String get gamePredictions;

  /// No description provided for @gameAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get gameAccuracy;

  /// No description provided for @gamePointsEarned.
  ///
  /// In en, this message translates to:
  /// **'Points earned'**
  String get gamePointsEarned;

  /// No description provided for @gameRank.
  ///
  /// In en, this message translates to:
  /// **'Rank'**
  String get gameRank;

  /// No description provided for @gameTopScorers.
  ///
  /// In en, this message translates to:
  /// **'Top scorers'**
  String get gameTopScorers;

  /// No description provided for @gameGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get gameGoals;

  /// No description provided for @gameEntriesClosed.
  ///
  /// In en, this message translates to:
  /// **'Entries closed'**
  String get gameEntriesClosed;

  /// No description provided for @gameEntriesCloseIn.
  ///
  /// In en, this message translates to:
  /// **'Entries close in'**
  String get gameEntriesCloseIn;

  /// No description provided for @gameFetProgressValue.
  ///
  /// In en, this message translates to:
  /// **'{current} of {maximum}, {tier} tier'**
  String gameFetProgressValue(int current, int maximum, String tier);

  /// No description provided for @gamePickForTeams.
  ///
  /// In en, this message translates to:
  /// **'{outcome} pick for {home} versus {away}'**
  String gamePickForTeams(String outcome, String home, String away);

  /// No description provided for @gameSelectedPick.
  ///
  /// In en, this message translates to:
  /// **'Selected pick'**
  String get gameSelectedPick;

  /// No description provided for @gameAddPickToRound.
  ///
  /// In en, this message translates to:
  /// **'Add pick to round'**
  String get gameAddPickToRound;

  /// No description provided for @gameNotificationSemantics.
  ///
  /// In en, this message translates to:
  /// **'Notification: {title}. {message}'**
  String gameNotificationSemantics(String title, String message);

  /// No description provided for @gameDismissNotificationHint.
  ///
  /// In en, this message translates to:
  /// **'Tap or swipe up to dismiss'**
  String get gameDismissNotificationHint;

  /// No description provided for @gameClubContextRequired.
  ///
  /// In en, this message translates to:
  /// **'Club context is required.'**
  String get gameClubContextRequired;

  /// No description provided for @gameUnexpectedResponse.
  ///
  /// In en, this message translates to:
  /// **'Unexpected response from server.'**
  String get gameUnexpectedResponse;

  /// No description provided for @gameBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get gameBack;

  /// No description provided for @gameRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get gameRetry;

  /// No description provided for @gameOpenPredictionAlert.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get gameOpenPredictionAlert;

  /// No description provided for @gameBadgesTitle.
  ///
  /// In en, this message translates to:
  /// **'Your badges'**
  String get gameBadgesTitle;

  /// No description provided for @gameBadgesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Badges unavailable'**
  String get gameBadgesUnavailable;

  /// No description provided for @gameBadgesTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Badges are temporarily unavailable.'**
  String get gameBadgesTemporarilyUnavailable;

  /// No description provided for @gameBadgeSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name} badge'**
  String gameBadgeSemantics(String name);

  /// No description provided for @gameOpenBadgeDetails.
  ///
  /// In en, this message translates to:
  /// **'Open badge details'**
  String get gameOpenBadgeDetails;

  /// No description provided for @gamePredictionAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Prediction alerts'**
  String get gamePredictionAlertsTitle;

  /// No description provided for @gameAlertsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Alerts unavailable'**
  String get gameAlertsUnavailable;

  /// No description provided for @gamePredictionAlertsTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Prediction alerts are temporarily unavailable.'**
  String get gamePredictionAlertsTemporarilyUnavailable;

  /// No description provided for @gamePredictionAlertSemantics.
  ///
  /// In en, this message translates to:
  /// **'Prediction alert, {title}, {message}, {date}{reward}'**
  String gamePredictionAlertSemantics(
    String title,
    String message,
    String date,
    String reward,
  );

  /// No description provided for @gameRewardPointsSemantics.
  ///
  /// In en, this message translates to:
  /// **', reward {count} points'**
  String gameRewardPointsSemantics(int count);

  /// No description provided for @gameJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get gameJustNow;

  /// No description provided for @gameStreakTitle.
  ///
  /// In en, this message translates to:
  /// **'Your streak'**
  String get gameStreakTitle;

  /// No description provided for @gameStreakDays.
  ///
  /// In en, this message translates to:
  /// **'{count} DAYS'**
  String gameStreakDays(int count);

  /// No description provided for @gameStreakActive.
  ///
  /// In en, this message translates to:
  /// **'Streak active.'**
  String get gameStreakActive;

  /// No description provided for @gameCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get gameCurrent;

  /// No description provided for @gameBest.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get gameBest;

  /// No description provided for @gameNextBonus.
  ///
  /// In en, this message translates to:
  /// **'Next bonus'**
  String get gameNextBonus;

  /// No description provided for @gameWins.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 win} other{{count} wins}}'**
  String gameWins(int count);

  /// No description provided for @gameStreakDaySemantics.
  ///
  /// In en, this message translates to:
  /// **'Streak day {day}: {wins}'**
  String gameStreakDaySemantics(int day, String wins);

  /// No description provided for @gameVerifyToPredict.
  ///
  /// In en, this message translates to:
  /// **'Verify to predict'**
  String get gameVerifyToPredict;

  /// No description provided for @gameMakePicks.
  ///
  /// In en, this message translates to:
  /// **'Make Picks'**
  String get gameMakePicks;

  /// No description provided for @gameMakePicksDescription.
  ///
  /// In en, this message translates to:
  /// **'Pick matches across all leagues'**
  String get gameMakePicksDescription;

  /// No description provided for @gameEarnPoints.
  ///
  /// In en, this message translates to:
  /// **'Earn Points'**
  String get gameEarnPoints;

  /// No description provided for @gameEarnPointsDescription.
  ///
  /// In en, this message translates to:
  /// **'Earn points for correct picks'**
  String get gameEarnPointsDescription;

  /// No description provided for @gameClimbLeaderboards.
  ///
  /// In en, this message translates to:
  /// **'Climb Leaderboards'**
  String get gameClimbLeaderboards;

  /// No description provided for @gameClimbLeaderboardsDescription.
  ///
  /// In en, this message translates to:
  /// **'Compete against friends and fans'**
  String get gameClimbLeaderboardsDescription;

  /// No description provided for @gameVerifyNow.
  ///
  /// In en, this message translates to:
  /// **'Verify now'**
  String get gameVerifyNow;

  /// No description provided for @gameJustBrowsing.
  ///
  /// In en, this message translates to:
  /// **'Just browsing'**
  String get gameJustBrowsing;

  /// No description provided for @gameOffersTitle.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get gameOffersTitle;

  /// No description provided for @gameOffersUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Offers unavailable'**
  String get gameOffersUnavailable;

  /// No description provided for @gameOffersTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Partner offers are temporarily unavailable.'**
  String get gameOffersTemporarilyUnavailable;

  /// No description provided for @gameWaysToEarn.
  ///
  /// In en, this message translates to:
  /// **'Ways to earn'**
  String get gameWaysToEarn;

  /// No description provided for @gameWaysToEarnDescription.
  ///
  /// In en, this message translates to:
  /// **'Join campaigns and activations to earn points.'**
  String get gameWaysToEarnDescription;

  /// No description provided for @gameBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get gameBalance;

  /// No description provided for @gameAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get gameAvailable;

  /// No description provided for @gameActiveOffers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 active offer} other{{count} active offers}}'**
  String gameActiveOffers(int count);

  /// No description provided for @gameFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get gameFeatured;

  /// No description provided for @gameMatchDay.
  ///
  /// In en, this message translates to:
  /// **'Match Day'**
  String get gameMatchDay;

  /// No description provided for @gameAlwaysOn.
  ///
  /// In en, this message translates to:
  /// **'Always On'**
  String get gameAlwaysOn;

  /// No description provided for @gameReward.
  ///
  /// In en, this message translates to:
  /// **'Reward'**
  String get gameReward;

  /// No description provided for @gameActivation.
  ///
  /// In en, this message translates to:
  /// **'Activation'**
  String get gameActivation;

  /// No description provided for @gameVerification.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get gameVerification;

  /// No description provided for @gameCondition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get gameCondition;

  /// No description provided for @gameClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get gameClose;

  /// No description provided for @gameDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get gameDetails;

  /// No description provided for @gamePointBalance.
  ///
  /// In en, this message translates to:
  /// **'{count} pts'**
  String gamePointBalance(int count);

  /// No description provided for @gameFormattedPoints.
  ///
  /// In en, this message translates to:
  /// **'{amount} pts'**
  String gameFormattedPoints(String amount);

  /// No description provided for @gameVerificationApi.
  ///
  /// In en, this message translates to:
  /// **'Partner API confirmation'**
  String get gameVerificationApi;

  /// No description provided for @gameVerificationRenewal.
  ///
  /// In en, this message translates to:
  /// **'Renewal confirmation'**
  String get gameVerificationRenewal;

  /// No description provided for @gameVerificationReferral.
  ///
  /// In en, this message translates to:
  /// **'Referral conversion'**
  String get gameVerificationReferral;

  /// No description provided for @gameVerificationReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt or POS scan'**
  String get gameVerificationReceipt;

  /// No description provided for @gameVerificationGeo.
  ///
  /// In en, this message translates to:
  /// **'GPS or venue check-in'**
  String get gameVerificationGeo;

  /// No description provided for @gameVerificationSocial.
  ///
  /// In en, this message translates to:
  /// **'Social post verification'**
  String get gameVerificationSocial;

  /// No description provided for @gameVerificationSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings milestone confirmation'**
  String get gameVerificationSavings;

  /// No description provided for @gameVerificationEcommerce.
  ///
  /// In en, this message translates to:
  /// **'Store purchase confirmation'**
  String get gameVerificationEcommerce;

  /// No description provided for @gameVerificationMobility.
  ///
  /// In en, this message translates to:
  /// **'Ride completion confirmation'**
  String get gameVerificationMobility;

  /// No description provided for @gameVerificationEventQr.
  ///
  /// In en, this message translates to:
  /// **'Event QR validation'**
  String get gameVerificationEventQr;

  /// No description provided for @gameVerificationManual.
  ///
  /// In en, this message translates to:
  /// **'Manual partner review'**
  String get gameVerificationManual;

  /// No description provided for @gameSettingsUpper.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get gameSettingsUpper;

  /// No description provided for @gamePrivacyUpper.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get gamePrivacyUpper;

  /// No description provided for @gameCoreGuarantees.
  ///
  /// In en, this message translates to:
  /// **'Core guarantees'**
  String get gameCoreGuarantees;

  /// No description provided for @gamePhoneNumberHidden.
  ///
  /// In en, this message translates to:
  /// **'Phone Number Hidden'**
  String get gamePhoneNumberHidden;

  /// No description provided for @gamePhoneNumberHiddenDescription.
  ///
  /// In en, this message translates to:
  /// **'Your WhatsApp or phone number is encrypted and stored only on the server. It is never exposed to other users, club administrators, or public leaderboards.'**
  String get gamePhoneNumberHiddenDescription;

  /// No description provided for @gameAnonymousContributions.
  ///
  /// In en, this message translates to:
  /// **'Anonymous Contributions'**
  String get gameAnonymousContributions;

  /// No description provided for @gameAnonymousContributionsDescription.
  ///
  /// In en, this message translates to:
  /// **'MoMo contributions to fan clubs are logged using only your Fan ID and amount bracket. Exact amounts and phone numbers are not recorded.'**
  String get gameAnonymousContributionsDescription;

  /// No description provided for @gameVisibilityControls.
  ///
  /// In en, this message translates to:
  /// **'Visibility controls'**
  String get gameVisibilityControls;

  /// No description provided for @gameShowRealName.
  ///
  /// In en, this message translates to:
  /// **'Show Real Name'**
  String get gameShowRealName;

  /// No description provided for @gameShowRealNameDescription.
  ///
  /// In en, this message translates to:
  /// **'When off, your Fan ID appears on leaderboards instead of your real name.'**
  String get gameShowRealNameDescription;

  /// No description provided for @gameFindableByPhone.
  ///
  /// In en, this message translates to:
  /// **'Findable by Phone'**
  String get gameFindableByPhone;

  /// No description provided for @gameFindableByPhoneDescription.
  ///
  /// In en, this message translates to:
  /// **'Allows friends to find you by phone number. Your number stays private.'**
  String get gameFindableByPhoneDescription;

  /// No description provided for @gamePrivacyFirst.
  ///
  /// In en, this message translates to:
  /// **'Privacy First'**
  String get gamePrivacyFirst;

  /// No description provided for @gamePrivacyFirstDescription.
  ///
  /// In en, this message translates to:
  /// **'{appName} does not sell, share, or expose your personal data. All identifiers on the platform are anonymized.'**
  String gamePrivacyFirstDescription(String appName);

  /// No description provided for @gameRewardsStoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Rewards store'**
  String get gameRewardsStoreTitle;

  /// No description provided for @gameRewardsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Rewards unavailable'**
  String get gameRewardsUnavailable;

  /// No description provided for @gameRewardsTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Rewards are temporarily unavailable.'**
  String get gameRewardsTemporarilyUnavailable;

  /// No description provided for @gameAvailableBalance.
  ///
  /// In en, this message translates to:
  /// **'Available balance'**
  String get gameAvailableBalance;

  /// No description provided for @gameRewardsStoreDescription.
  ///
  /// In en, this message translates to:
  /// **'Redeem {appName} rewards without leaving the consolidated wallet flow.'**
  String gameRewardsStoreDescription(String appName);

  /// No description provided for @gameRewardMeta.
  ///
  /// In en, this message translates to:
  /// **'{category} · {notes}'**
  String gameRewardMeta(String category, String notes);

  /// No description provided for @gameRedeemCost.
  ///
  /// In en, this message translates to:
  /// **'Redeem {cost}'**
  String gameRedeemCost(String cost);

  /// No description provided for @gameNeedCost.
  ///
  /// In en, this message translates to:
  /// **'Need {cost}'**
  String gameNeedCost(String cost);

  /// No description provided for @gameRewardConfigurationMissing.
  ///
  /// In en, this message translates to:
  /// **'Reward configuration is missing. Try again later.'**
  String get gameRewardConfigurationMissing;

  /// No description provided for @gameRewardAlreadyRedeemed.
  ///
  /// In en, this message translates to:
  /// **'That reward redemption already completed.'**
  String get gameRewardAlreadyRedeemed;

  /// No description provided for @gameRewardRedeemed.
  ///
  /// In en, this message translates to:
  /// **'Redeemed {reward} for {cost}.'**
  String gameRewardRedeemed(String reward, String cost);

  /// No description provided for @gameRewardCouldNotRedeem.
  ///
  /// In en, this message translates to:
  /// **'Could not redeem this reward.'**
  String get gameRewardCouldNotRedeem;

  /// No description provided for @gameFriendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get gameFriendsTitle;

  /// No description provided for @gameSupportersUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Supporters unavailable'**
  String get gameSupportersUnavailable;

  /// No description provided for @gameSupportersTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Supporters are temporarily unavailable.'**
  String get gameSupportersTemporarilyUnavailable;

  /// No description provided for @gameSearchSupporterHint.
  ///
  /// In en, this message translates to:
  /// **'Search supporter alias or ID'**
  String get gameSearchSupporterHint;

  /// No description provided for @gameDone.
  ///
  /// In en, this message translates to:
  /// **'Done.'**
  String get gameDone;

  /// No description provided for @gameResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get gameResults;

  /// No description provided for @gameYourFriends.
  ///
  /// In en, this message translates to:
  /// **'Your friends'**
  String get gameYourFriends;

  /// No description provided for @gameChallenge.
  ///
  /// In en, this message translates to:
  /// **'Challenge'**
  String get gameChallenge;

  /// No description provided for @gameAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get gameAccept;

  /// No description provided for @gamePending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get gamePending;

  /// No description provided for @gameAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get gameAdd;

  /// No description provided for @gameOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get gameOnline;

  /// No description provided for @gameFixturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Fixtures'**
  String get gameFixturesTitle;

  /// No description provided for @gameFixturesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Fixtures unavailable'**
  String get gameFixturesUnavailable;

  /// No description provided for @gameFixturesCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load fixtures right now.'**
  String get gameFixturesCouldNotLoad;

  /// No description provided for @gameAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get gameAll;

  /// No description provided for @gameToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get gameToday;

  /// No description provided for @gameTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get gameTomorrow;

  /// No description provided for @gameYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get gameYesterday;

  /// No description provided for @gameRelativeDate.
  ///
  /// In en, this message translates to:
  /// **'{relative} · {date}'**
  String gameRelativeDate(String relative, String date);

  /// No description provided for @gameMatchCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 match} other{{count} matches}}'**
  String gameMatchCount(int count);

  /// No description provided for @gameMyActivity.
  ///
  /// In en, this message translates to:
  /// **'My activity'**
  String get gameMyActivity;

  /// No description provided for @gameActiveCount.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE ({count})'**
  String gameActiveCount(int count);

  /// No description provided for @gameSettledTabCount.
  ///
  /// In en, this message translates to:
  /// **'SETTLED ({count})'**
  String gameSettledTabCount(int count);

  /// No description provided for @gameHistoryCount.
  ///
  /// In en, this message translates to:
  /// **'HISTORY ({count})'**
  String gameHistoryCount(int count);

  /// No description provided for @gameActivityUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Activity unavailable'**
  String get gameActivityUnavailable;

  /// No description provided for @gameActivityCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load your activity right now.'**
  String get gameActivityCouldNotLoad;

  /// No description provided for @gameCouldNotCancelPick.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel this pick.'**
  String get gameCouldNotCancelPick;

  /// No description provided for @gameWon.
  ///
  /// In en, this message translates to:
  /// **'Won'**
  String get gameWon;

  /// No description provided for @gameLost.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get gameLost;

  /// No description provided for @gameCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get gameCancelled;

  /// No description provided for @gameVoid.
  ///
  /// In en, this message translates to:
  /// **'Void'**
  String get gameVoid;

  /// No description provided for @gamePendingUpper.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get gamePendingUpper;

  /// No description provided for @gameTbd.
  ///
  /// In en, this message translates to:
  /// **'Tbd'**
  String get gameTbd;

  /// No description provided for @gameVersusShort.
  ///
  /// In en, this message translates to:
  /// **'{home} vs {away}'**
  String gameVersusShort(String home, String away);

  /// No description provided for @gameRound.
  ///
  /// In en, this message translates to:
  /// **'Round'**
  String get gameRound;

  /// No description provided for @gameCompetitionTime.
  ///
  /// In en, this message translates to:
  /// **'{competition} • {time}'**
  String gameCompetitionTime(String competition, String time);

  /// No description provided for @gameCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get gameCancel;

  /// No description provided for @gameActivitySemantics.
  ///
  /// In en, this message translates to:
  /// **'{home} versus {away} activity'**
  String gameActivitySemantics(String home, String away);

  /// No description provided for @gameOpenActivityDetail.
  ///
  /// In en, this message translates to:
  /// **'Open activity detail'**
  String get gameOpenActivityDetail;

  /// No description provided for @gameNotificationsUpper.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get gameNotificationsUpper;

  /// No description provided for @gameKickoffAlerts.
  ///
  /// In en, this message translates to:
  /// **'Match Kick-off Alerts'**
  String get gameKickoffAlerts;

  /// No description provided for @gameRoundResults.
  ///
  /// In en, this message translates to:
  /// **'Round Results'**
  String get gameRoundResults;

  /// No description provided for @gameFriendChallenges.
  ///
  /// In en, this message translates to:
  /// **'Friend Challenges'**
  String get gameFriendChallenges;

  /// No description provided for @gameLineupsUpper.
  ///
  /// In en, this message translates to:
  /// **'Lineups'**
  String get gameLineupsUpper;

  /// No description provided for @gameSubstitutes.
  ///
  /// In en, this message translates to:
  /// **'Subs'**
  String get gameSubstitutes;

  /// No description provided for @gameActiveUpper.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get gameActiveUpper;

  /// No description provided for @gameWinRate.
  ///
  /// In en, this message translates to:
  /// **'Win rate'**
  String get gameWinRate;

  /// No description provided for @gameYouUpper.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get gameYouUpper;

  /// No description provided for @gameWalletSignedPoints.
  ///
  /// In en, this message translates to:
  /// **'{sign}{amount} pts'**
  String gameWalletSignedPoints(String sign, String amount);

  /// No description provided for @gameWalletBalance.
  ///
  /// In en, this message translates to:
  /// **'Bal. {amount} pts'**
  String gameWalletBalance(String amount);

  /// No description provided for @gameVersus.
  ///
  /// In en, this message translates to:
  /// **'VS'**
  String get gameVersus;

  /// No description provided for @gameKickoffSoon.
  ///
  /// In en, this message translates to:
  /// **'Kick-off soon'**
  String get gameKickoffSoon;

  /// No description provided for @gameJoinedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 joined} other{{count} joined}}'**
  String gameJoinedCount(int count);

  /// No description provided for @gameTotalPoolPoints.
  ///
  /// In en, this message translates to:
  /// **'{count} pts total'**
  String gameTotalPoolPoints(int count);

  /// No description provided for @gameCreator.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get gameCreator;

  /// No description provided for @gameMyPick.
  ///
  /// In en, this message translates to:
  /// **'My pick'**
  String get gameMyPick;

  /// No description provided for @gameOpenUpper.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get gameOpenUpper;

  /// No description provided for @gameLockedUpper.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get gameLockedUpper;

  /// No description provided for @gameSettledUpper.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get gameSettledUpper;

  /// No description provided for @gameDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{count}d left'**
  String gameDaysLeft(int count);

  /// No description provided for @gameHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String gameHoursMinutes(int hours, int minutes);

  /// No description provided for @gameMinutesLeft.
  ///
  /// In en, this message translates to:
  /// **'{count}m left'**
  String gameMinutesLeft(int count);

  /// No description provided for @gameScorePrediction.
  ///
  /// In en, this message translates to:
  /// **'{label}  {home}-{away}'**
  String gameScorePrediction(String label, int home, int away);

  /// No description provided for @gamePointsShare.
  ///
  /// In en, this message translates to:
  /// **'Points share'**
  String get gamePointsShare;

  /// No description provided for @gamePointsShareDescription.
  ///
  /// In en, this message translates to:
  /// **'Tier rules decide how earned points support you and collective club rewards.'**
  String get gamePointsShareDescription;

  /// No description provided for @gamePersonalPercentage.
  ///
  /// In en, this message translates to:
  /// **'{count}% you'**
  String gamePersonalPercentage(int count);

  /// No description provided for @gameClubPercentage.
  ///
  /// In en, this message translates to:
  /// **'{count}% club'**
  String gameClubPercentage(int count);

  /// No description provided for @gameTierSplit.
  ///
  /// In en, this message translates to:
  /// **'{personal}/{club}'**
  String gameTierSplit(int personal, int club);

  /// No description provided for @gamePointsShareExplanation.
  ///
  /// In en, this message translates to:
  /// **'Your points are shared by tier: the personal share stays with you and the club share supports collective rewards.'**
  String get gamePointsShareExplanation;

  /// No description provided for @gameTierSupporter.
  ///
  /// In en, this message translates to:
  /// **'Supporter'**
  String get gameTierSupporter;

  /// No description provided for @gameTierMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get gameTierMember;

  /// No description provided for @gameTierUltra.
  ///
  /// In en, this message translates to:
  /// **'Ultra'**
  String get gameTierUltra;

  /// No description provided for @gameTierLegend.
  ///
  /// In en, this message translates to:
  /// **'Legend'**
  String get gameTierLegend;

  /// No description provided for @gameFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get gameFree;

  /// No description provided for @gameMonthlyPrice.
  ///
  /// In en, this message translates to:
  /// **'{amount} RWF / month'**
  String gameMonthlyPrice(String amount);

  /// No description provided for @gameShareTitle.
  ///
  /// In en, this message translates to:
  /// **'{appName} Pick'**
  String gameShareTitle(String appName);

  /// No description provided for @gameShareCopied.
  ///
  /// In en, this message translates to:
  /// **'Share text copied to clipboard.'**
  String get gameShareCopied;

  /// No description provided for @gameShareStatusLine.
  ///
  /// In en, this message translates to:
  /// **'{status}: {home} vs {away}'**
  String gameShareStatusLine(String status, String home, String away);

  /// No description provided for @gameFinalScore.
  ///
  /// In en, this message translates to:
  /// **'Final score: {home}-{away}'**
  String gameFinalScore(int home, int away);

  /// No description provided for @gameMarketSelection.
  ///
  /// In en, this message translates to:
  /// **'{market}: {selection}'**
  String gameMarketSelection(String market, String selection);

  /// No description provided for @gameEarnedShare.
  ///
  /// In en, this message translates to:
  /// **'Earned: +{count} pts'**
  String gameEarnedShare(int count);

  /// No description provided for @gamePotentialShare.
  ///
  /// In en, this message translates to:
  /// **'Potential: +{count} pts'**
  String gamePotentialShare(int count);

  /// No description provided for @gameMarketUpper.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get gameMarketUpper;

  /// No description provided for @gamePickUpper.
  ///
  /// In en, this message translates to:
  /// **'Pick'**
  String get gamePickUpper;

  /// No description provided for @gameEarnedUpper.
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get gameEarnedUpper;

  /// No description provided for @gamePotentialUpper.
  ///
  /// In en, this message translates to:
  /// **'Potential'**
  String get gamePotentialUpper;

  /// No description provided for @gameShareTagline.
  ///
  /// In en, this message translates to:
  /// **'{appName} · PLAY. PICK. EARN.'**
  String gameShareTagline(String appName);

  /// No description provided for @gamePickTypeCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pick type} other{{count} pick types}}'**
  String gamePickTypeCount(int count);

  /// No description provided for @gameSearchPickTypes.
  ///
  /// In en, this message translates to:
  /// **'Search pick types'**
  String get gameSearchPickTypes;

  /// No description provided for @gameClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get gameClearSearch;

  /// No description provided for @gameAddPicksToUnlock.
  ///
  /// In en, this message translates to:
  /// **'Add picks to unlock round'**
  String get gameAddPicksToUnlock;

  /// No description provided for @gameOpenRoundSummary.
  ///
  /// In en, this message translates to:
  /// **'Open Round · {count} picks · {points} pts'**
  String gameOpenRoundSummary(int count, int points);

  /// No description provided for @gameLiveOnly.
  ///
  /// In en, this message translates to:
  /// **'Live only'**
  String get gameLiveOnly;

  /// No description provided for @gameOutcomeAddedToRound.
  ///
  /// In en, this message translates to:
  /// **'{outcome} added to your round.'**
  String gameOutcomeAddedToRound(String outcome);

  /// No description provided for @gameMarkets.
  ///
  /// In en, this message translates to:
  /// **'Markets'**
  String get gameMarkets;

  /// No description provided for @gameMarketCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 market} other{{count} markets}}'**
  String gameMarketCount(int count);

  /// No description provided for @gameStatsNotAvailableYet.
  ///
  /// In en, this message translates to:
  /// **'Stats not yet available'**
  String get gameStatsNotAvailableYet;

  /// No description provided for @gameLiveStatsUpdating.
  ///
  /// In en, this message translates to:
  /// **'Live stats update automatically during the match.'**
  String get gameLiveStatsUpdating;

  /// No description provided for @gameLiveMatchDataUpdating.
  ///
  /// In en, this message translates to:
  /// **'Live match-center data is updating for this fixture.'**
  String get gameLiveMatchDataUpdating;

  /// No description provided for @gameStructuredMatchStats.
  ///
  /// In en, this message translates to:
  /// **'Structured match-center statistics for this fixture.'**
  String get gameStructuredMatchStats;

  /// No description provided for @gameTotalGoals.
  ///
  /// In en, this message translates to:
  /// **'Total Goals'**
  String get gameTotalGoals;

  /// No description provided for @gameFinalMatchStats.
  ///
  /// In en, this message translates to:
  /// **'Final match statistics.'**
  String get gameFinalMatchStats;

  /// No description provided for @gameFixtureMarketTitle.
  ///
  /// In en, this message translates to:
  /// **'{home} vs {away} · {market}'**
  String gameFixtureMarketTitle(String home, String away, String market);

  /// No description provided for @gamePickTypeLocked.
  ///
  /// In en, this message translates to:
  /// **'Pick type locked for this fixture state.'**
  String get gamePickTypeLocked;

  /// No description provided for @gameLeaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get gameLeaderboardTitle;

  /// No description provided for @gameFetRanking.
  ///
  /// In en, this message translates to:
  /// **'FET Ranking'**
  String get gameFetRanking;

  /// No description provided for @gameSupporters.
  ///
  /// In en, this message translates to:
  /// **'Supporters'**
  String get gameSupporters;

  /// No description provided for @gameAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get gameAllTime;

  /// No description provided for @gameWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get gameWeekly;

  /// No description provided for @gameMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get gameMonthly;

  /// No description provided for @gameLeaderboardUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard unavailable'**
  String get gameLeaderboardUnavailable;

  /// No description provided for @gameLeaderboardTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard is temporarily unavailable.'**
  String get gameLeaderboardTemporarilyUnavailable;

  /// No description provided for @gameRankingsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Rankings unavailable'**
  String get gameRankingsUnavailable;

  /// No description provided for @gameSupporterRankingsTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Supporter rankings are temporarily unavailable.'**
  String get gameSupporterRankingsTemporarilyUnavailable;

  /// No description provided for @gameNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get gameNotSignedIn;

  /// No description provided for @gameTierFan.
  ///
  /// In en, this message translates to:
  /// **'Fan'**
  String get gameTierFan;

  /// No description provided for @gameDisplayNameOn.
  ///
  /// In en, this message translates to:
  /// **'Display Name On'**
  String get gameDisplayNameOn;

  /// No description provided for @gameAliasOnly.
  ///
  /// In en, this message translates to:
  /// **'Alias Only'**
  String get gameAliasOnly;

  /// No description provided for @gameDisplayNameOnDescription.
  ///
  /// In en, this message translates to:
  /// **'Leaderboards can show {name} instead of only your Fan ID.'**
  String gameDisplayNameOnDescription(String name);

  /// No description provided for @gameAliasOnlyDescription.
  ///
  /// In en, this message translates to:
  /// **'Leaderboards show your Fan ID or alias instead of your real name.'**
  String get gameAliasOnlyDescription;

  /// No description provided for @gamePhoneHidden.
  ///
  /// In en, this message translates to:
  /// **'Phone Hidden'**
  String get gamePhoneHidden;

  /// No description provided for @gamePhoneHiddenDescription.
  ///
  /// In en, this message translates to:
  /// **'Your phone number stays on the server and is never shown to other supporters or club administrators.'**
  String get gamePhoneHiddenDescription;

  /// No description provided for @gamePhoneDiscoveryOn.
  ///
  /// In en, this message translates to:
  /// **'Phone Discovery On'**
  String get gamePhoneDiscoveryOn;

  /// No description provided for @gamePhoneDiscoveryOff.
  ///
  /// In en, this message translates to:
  /// **'Phone Discovery Off'**
  String get gamePhoneDiscoveryOff;

  /// No description provided for @gamePhoneDiscoveryOnDescription.
  ///
  /// In en, this message translates to:
  /// **'Friends who already know your phone number can find your profile.'**
  String get gamePhoneDiscoveryOnDescription;

  /// No description provided for @gamePhoneDiscoveryOffDescription.
  ///
  /// In en, this message translates to:
  /// **'Phone-based discovery is currently disabled on your profile.'**
  String get gamePhoneDiscoveryOffDescription;

  /// No description provided for @gameVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get gameVerified;

  /// No description provided for @gameVerificationPending.
  ///
  /// In en, this message translates to:
  /// **'Verification Pending'**
  String get gameVerificationPending;

  /// No description provided for @gameVerifiedDescription.
  ///
  /// In en, this message translates to:
  /// **'Your phone identity is verified for {appName} earning and social flows.'**
  String gameVerifiedDescription(String appName);

  /// No description provided for @gameVerificationPendingDescription.
  ///
  /// In en, this message translates to:
  /// **'Verify your phone to unlock the full {appName} social experience.'**
  String gameVerificationPendingDescription(String appName);

  /// No description provided for @gameFanIdPersistentRule.
  ///
  /// In en, this message translates to:
  /// **'Your Fan ID comes from your profile and remains the same when you return.'**
  String get gameFanIdPersistentRule;

  /// No description provided for @gameDisplayNameVisibleRule.
  ///
  /// In en, this message translates to:
  /// **'Your display name “{name}” can appear on leaderboards until you turn that off.'**
  String gameDisplayNameVisibleRule(String name);

  /// No description provided for @gameRealNameHiddenRule.
  ///
  /// In en, this message translates to:
  /// **'Your real name stays hidden on leaderboards until you explicitly enable display-name visibility.'**
  String get gameRealNameHiddenRule;

  /// No description provided for @gamePhoneEncryptedRule.
  ///
  /// In en, this message translates to:
  /// **'Your phone number is encrypted and stored only on the server.'**
  String get gamePhoneEncryptedRule;

  /// No description provided for @gamePhoneDiscoveryEnabledRule.
  ///
  /// In en, this message translates to:
  /// **'Phone-based friend discovery is enabled on your account right now.'**
  String get gamePhoneDiscoveryEnabledRule;

  /// No description provided for @gamePhoneDiscoveryDisabledRule.
  ///
  /// In en, this message translates to:
  /// **'Phone-based friend discovery is disabled on your account right now.'**
  String get gamePhoneDiscoveryDisabledRule;

  /// No description provided for @gamePhoneVerifiedRule.
  ///
  /// In en, this message translates to:
  /// **'Your phone identity is verified for {appName} features and rewards.'**
  String gamePhoneVerifiedRule(String appName);

  /// No description provided for @gamePhonePendingRule.
  ///
  /// In en, this message translates to:
  /// **'Phone verification is still pending for your {appName} profile.'**
  String gamePhonePendingRule(String appName);

  /// No description provided for @gameTeamLinkedRule.
  ///
  /// In en, this message translates to:
  /// **'Your profile is linked to {team} for personalization.'**
  String gameTeamLinkedRule(String team);

  /// No description provided for @gameLinkTeamRule.
  ///
  /// In en, this message translates to:
  /// **'You can link a favorite team from onboarding or profile setup for personalization.'**
  String get gameLinkTeamRule;

  /// No description provided for @gameDeleteAccountRule.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account removes your personal data and Fan ID mapping from the active profile.'**
  String get gameDeleteAccountRule;

  /// No description provided for @gameFanIdTitle.
  ///
  /// In en, this message translates to:
  /// **'Fan id'**
  String get gameFanIdTitle;

  /// No description provided for @gameYourFanId.
  ///
  /// In en, this message translates to:
  /// **'Your fan id'**
  String get gameYourFanId;

  /// No description provided for @gameAliasOnlyProfile.
  ///
  /// In en, this message translates to:
  /// **'Alias-only profile'**
  String get gameAliasOnlyProfile;

  /// No description provided for @gameFanIdCopied.
  ///
  /// In en, this message translates to:
  /// **'Fan ID copied to clipboard.'**
  String get gameFanIdCopied;

  /// No description provided for @gameCopyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get gameCopyToClipboard;

  /// No description provided for @gamePrivacyBadges.
  ///
  /// In en, this message translates to:
  /// **'Privacy badges'**
  String get gamePrivacyBadges;

  /// No description provided for @gameIdentityRules.
  ///
  /// In en, this message translates to:
  /// **'Identity rules'**
  String get gameIdentityRules;

  /// No description provided for @gameIdentityRulesDescription.
  ///
  /// In en, this message translates to:
  /// **'How your Fan ID works based on your current profile settings.'**
  String get gameIdentityRulesDescription;

  /// No description provided for @gameStandingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Standings'**
  String get gameStandingsTitle;

  /// No description provided for @gameCompetitionNotFound.
  ///
  /// In en, this message translates to:
  /// **'Competition not found.'**
  String get gameCompetitionNotFound;

  /// No description provided for @gameStandingsTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Standings are temporarily unavailable.'**
  String get gameStandingsTemporarilyUnavailable;

  /// No description provided for @gameStandingsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Standings unavailable'**
  String get gameStandingsUnavailable;

  /// No description provided for @gamePositionShort.
  ///
  /// In en, this message translates to:
  /// **'Pos'**
  String get gamePositionShort;

  /// No description provided for @gameTeamUpper.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get gameTeamUpper;

  /// No description provided for @gamePointsShort.
  ///
  /// In en, this message translates to:
  /// **'Pts'**
  String get gamePointsShort;

  /// No description provided for @gamePointsUpper.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get gamePointsUpper;

  /// No description provided for @gameStandingRecord.
  ///
  /// In en, this message translates to:
  /// **'{played}P · {goalsFor}:{goalsAgainst} · GD {difference}'**
  String gameStandingRecord(
    int played,
    int goalsFor,
    int goalsAgainst,
    int difference,
  );

  /// No description provided for @gameHeadToHead.
  ///
  /// In en, this message translates to:
  /// **'Head to head'**
  String get gameHeadToHead;

  /// No description provided for @gameHeadToHeadEmpty.
  ///
  /// In en, this message translates to:
  /// **'Historical head-to-head records between {home} and {away} will appear here.'**
  String gameHeadToHeadEmpty(String home, String away);

  /// No description provided for @gameWinDistribution.
  ///
  /// In en, this message translates to:
  /// **'Win distribution'**
  String get gameWinDistribution;

  /// No description provided for @gameDraws.
  ///
  /// In en, this message translates to:
  /// **'Draws'**
  String get gameDraws;

  /// No description provided for @gameTeamGoals.
  ///
  /// In en, this message translates to:
  /// **'{team} GOALS'**
  String gameTeamGoals(String team);

  /// No description provided for @gameRecentEncounters.
  ///
  /// In en, this message translates to:
  /// **'Recent encounters'**
  String get gameRecentEncounters;

  /// No description provided for @gameScore.
  ///
  /// In en, this message translates to:
  /// **'{home} - {away}'**
  String gameScore(int home, int away);

  /// No description provided for @gameTokenHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Token history'**
  String get gameTokenHistoryTitle;

  /// No description provided for @gameTokenHistoryTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Token history is temporarily unavailable.'**
  String get gameTokenHistoryTemporarilyUnavailable;

  /// No description provided for @gameHistoryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'History unavailable'**
  String get gameHistoryUnavailable;

  /// No description provided for @gameEarned.
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get gameEarned;

  /// No description provided for @gameSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get gameSpent;

  /// No description provided for @gameAllUpper.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get gameAllUpper;

  /// No description provided for @gameEarnedUpperFilter.
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get gameEarnedUpperFilter;

  /// No description provided for @gameSpentUpper.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get gameSpentUpper;

  /// No description provided for @gameCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get gameCredit;

  /// No description provided for @gameDebit.
  ///
  /// In en, this message translates to:
  /// **'Debit'**
  String get gameDebit;

  /// No description provided for @gameLedgerUpdate.
  ///
  /// In en, this message translates to:
  /// **'Ledger update'**
  String get gameLedgerUpdate;

  /// No description provided for @gameTransactionSemantics.
  ///
  /// In en, this message translates to:
  /// **'{direction} transaction, {headline}, {detail}, {amount} points, balance {balance} points, {date}'**
  String gameTransactionSemantics(
    String direction,
    String headline,
    String detail,
    int amount,
    int balance,
    String date,
  );

  /// No description provided for @gameUnknownTime.
  ///
  /// In en, this message translates to:
  /// **'Unknown time'**
  String get gameUnknownTime;

  /// No description provided for @gameClubFanZoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Club fan zone'**
  String get gameClubFanZoneTitle;

  /// No description provided for @gameClubFanZoneTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Club fan zone is temporarily unavailable.'**
  String get gameClubFanZoneTemporarilyUnavailable;

  /// No description provided for @gameFanZoneUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Fan zone unavailable'**
  String get gameFanZoneUnavailable;

  /// No description provided for @gameSupporterPulse.
  ///
  /// In en, this message translates to:
  /// **'Supporter pulse'**
  String get gameSupporterPulse;

  /// No description provided for @gameSupporterPulseDescription.
  ///
  /// In en, this message translates to:
  /// **'Real supporter momentum around active competitions, fixture picks, and top clubs.'**
  String get gameSupporterPulseDescription;

  /// No description provided for @gameTopClubs.
  ///
  /// In en, this message translates to:
  /// **'Top clubs'**
  String get gameTopClubs;

  /// No description provided for @gameRankHash.
  ///
  /// In en, this message translates to:
  /// **'#{rank}'**
  String gameRankHash(int rank);

  /// No description provided for @gameSupporterLeans.
  ///
  /// In en, this message translates to:
  /// **'Supporter leans'**
  String get gameSupporterLeans;

  /// No description provided for @gameSupporterLeansEmpty.
  ///
  /// In en, this message translates to:
  /// **'Community pick distribution will appear once this competition has active {appName} predictions.'**
  String gameSupporterLeansEmpty(String appName);

  /// No description provided for @gamePair.
  ///
  /// In en, this message translates to:
  /// **'{first} · {second}'**
  String gamePair(String first, String second);

  /// No description provided for @gameSupporterLeanPercentage.
  ///
  /// In en, this message translates to:
  /// **'{percentage}% of supporters currently lean this way.'**
  String gameSupporterLeanPercentage(String percentage);

  /// No description provided for @gameLeagueHubTitle.
  ///
  /// In en, this message translates to:
  /// **'League hub'**
  String get gameLeagueHubTitle;

  /// No description provided for @gameLeagueDataTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'League data is temporarily unavailable.'**
  String get gameLeagueDataTemporarilyUnavailable;

  /// No description provided for @gameLeagueUnavailable.
  ///
  /// In en, this message translates to:
  /// **'League unavailable'**
  String get gameLeagueUnavailable;

  /// No description provided for @gameCompetition.
  ///
  /// In en, this message translates to:
  /// **'Competition'**
  String get gameCompetition;

  /// No description provided for @gameRegion.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get gameRegion;

  /// No description provided for @gameLeague.
  ///
  /// In en, this message translates to:
  /// **'League'**
  String get gameLeague;

  /// No description provided for @gameTeams.
  ///
  /// In en, this message translates to:
  /// **'Teams'**
  String get gameTeams;

  /// No description provided for @gameFixtures.
  ///
  /// In en, this message translates to:
  /// **'Fixtures'**
  String get gameFixtures;

  /// No description provided for @gameLeader.
  ///
  /// In en, this message translates to:
  /// **'Leader'**
  String get gameLeader;

  /// No description provided for @gameTopTable.
  ///
  /// In en, this message translates to:
  /// **'Top table'**
  String get gameTopTable;

  /// No description provided for @gameFullStandings.
  ///
  /// In en, this message translates to:
  /// **'Full standings'**
  String get gameFullStandings;

  /// No description provided for @gameLeagueStandingRecord.
  ///
  /// In en, this message translates to:
  /// **'{played}P · {won}W {drawn}D {lost}L'**
  String gameLeagueStandingRecord(int played, int won, int drawn, int lost);

  /// No description provided for @gameEntrySubmitted.
  ///
  /// In en, this message translates to:
  /// **'Entry submitted'**
  String get gameEntrySubmitted;

  /// No description provided for @gameBonusEntryLive.
  ///
  /// In en, this message translates to:
  /// **'Your bonus entry is now live.'**
  String get gameBonusEntryLive;

  /// No description provided for @gameCouldNotSubmitBonus.
  ///
  /// In en, this message translates to:
  /// **'Could not submit the bonus entry right now.'**
  String get gameCouldNotSubmitBonus;

  /// No description provided for @gameKickoffTbd.
  ///
  /// In en, this message translates to:
  /// **'Kick-off TBD'**
  String get gameKickoffTbd;

  /// No description provided for @gameBonusRound.
  ///
  /// In en, this message translates to:
  /// **'Bonus Round'**
  String get gameBonusRound;

  /// No description provided for @gameSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get gameSubmitting;

  /// No description provided for @gameEntriesClosedSentence.
  ///
  /// In en, this message translates to:
  /// **'Entries closed'**
  String get gameEntriesClosedSentence;

  /// No description provided for @gameSubmitEntry.
  ///
  /// In en, this message translates to:
  /// **'Submit entry'**
  String get gameSubmitEntry;

  /// No description provided for @gameBonusRoundActivationPending.
  ///
  /// In en, this message translates to:
  /// **'Bonus round activation is pending.'**
  String get gameBonusRoundActivationPending;

  /// No description provided for @gameBonusRoundTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Bonus round is temporarily unavailable.'**
  String get gameBonusRoundTemporarilyUnavailable;

  /// No description provided for @gameBonusRoundUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Bonus round unavailable'**
  String get gameBonusRoundUnavailable;

  /// No description provided for @gamePointsPool.
  ///
  /// In en, this message translates to:
  /// **'Points pool'**
  String get gamePointsPool;

  /// No description provided for @gamePickAllFeatured.
  ///
  /// In en, this message translates to:
  /// **'Pick every featured fixture before the round locks.'**
  String get gamePickAllFeatured;

  /// No description provided for @gamePicksComplete.
  ///
  /// In en, this message translates to:
  /// **'{selected} of {total} picks complete'**
  String gamePicksComplete(int selected, int total);

  /// No description provided for @gameEntriesRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry remaining} other{{count} entries remaining}}'**
  String gameEntriesRemaining(int count);

  /// No description provided for @gameLeaders.
  ///
  /// In en, this message translates to:
  /// **'Leaders'**
  String get gameLeaders;

  /// No description provided for @gameSocialHub.
  ///
  /// In en, this message translates to:
  /// **'Social Hub'**
  String get gameSocialHub;

  /// No description provided for @gameClub.
  ///
  /// In en, this message translates to:
  /// **'Club'**
  String get gameClub;

  /// No description provided for @gameSearchYourFriends.
  ///
  /// In en, this message translates to:
  /// **'Search your friends'**
  String get gameSearchYourFriends;

  /// No description provided for @gameBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get gameBrowse;

  /// No description provided for @gameViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get gameViewAll;

  /// No description provided for @gameClubStandingsTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Club standings are temporarily unavailable.'**
  String get gameClubStandingsTemporarilyUnavailable;

  /// No description provided for @gameClubStandingsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Club standings unavailable'**
  String get gameClubStandingsUnavailable;

  /// No description provided for @gameClubStanding.
  ///
  /// In en, this message translates to:
  /// **'Club standing'**
  String get gameClubStanding;

  /// No description provided for @gameUnranked.
  ///
  /// In en, this message translates to:
  /// **'Unranked'**
  String get gameUnranked;

  /// No description provided for @gameEarnPointsForClubTable.
  ///
  /// In en, this message translates to:
  /// **'Earn points to appear in the club table.'**
  String get gameEarnPointsForClubTable;

  /// No description provided for @gamePointsEarnedSoFar.
  ///
  /// In en, this message translates to:
  /// **'{count} pts earned so far.'**
  String gamePointsEarnedSoFar(int count);

  /// No description provided for @gameNameYou.
  ///
  /// In en, this message translates to:
  /// **'{name} (You)'**
  String gameNameYou(String name);

  /// No description provided for @gameChallengeFlowTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Challenge flow is temporarily unavailable.'**
  String get gameChallengeFlowTemporarilyUnavailable;

  /// No description provided for @gameHeadToHeadMessage.
  ///
  /// In en, this message translates to:
  /// **'{appName} head-to-head on {home} vs {away}'**
  String gameHeadToHeadMessage(String appName, String home, String away);

  /// No description provided for @gameChallengeSent.
  ///
  /// In en, this message translates to:
  /// **'Challenge sent'**
  String get gameChallengeSent;

  /// No description provided for @gameChallengeWaiting.
  ///
  /// In en, this message translates to:
  /// **'Your challenge is waiting for a response.'**
  String get gameChallengeWaiting;

  /// No description provided for @gameCouldNotSendChallenge.
  ///
  /// In en, this message translates to:
  /// **'Could not send the challenge right now.'**
  String get gameCouldNotSendChallenge;

  /// No description provided for @gameSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get gameSending;

  /// No description provided for @gameSendChallenge.
  ///
  /// In en, this message translates to:
  /// **'Send challenge'**
  String get gameSendChallenge;

  /// No description provided for @gameChallengeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Challenge unavailable'**
  String get gameChallengeUnavailable;

  /// No description provided for @gameSupporter.
  ///
  /// In en, this message translates to:
  /// **'Supporter'**
  String get gameSupporter;

  /// No description provided for @gameAddFriendsBeforeChallenge.
  ///
  /// In en, this message translates to:
  /// **'Add friends before sending a challenge.'**
  String get gameAddFriendsBeforeChallenge;

  /// No description provided for @gameFindFriends.
  ///
  /// In en, this message translates to:
  /// **'Find friends'**
  String get gameFindFriends;

  /// No description provided for @gameFixture.
  ///
  /// In en, this message translates to:
  /// **'Fixture'**
  String get gameFixture;

  /// No description provided for @gamePick.
  ///
  /// In en, this message translates to:
  /// **'Pick'**
  String get gamePick;

  /// No description provided for @gameSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get gameSelected;

  /// No description provided for @gameChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get gameChoose;

  /// No description provided for @gameTeamNotFound.
  ///
  /// In en, this message translates to:
  /// **'Team not found.'**
  String get gameTeamNotFound;

  /// No description provided for @gameTeamProfileTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Team profile is temporarily unavailable.'**
  String get gameTeamProfileTemporarilyUnavailable;

  /// No description provided for @gameSupporterActivityActiveClubOnly.
  ///
  /// In en, this message translates to:
  /// **'Supporter activity is only available for the active club.'**
  String get gameSupporterActivityActiveClubOnly;

  /// No description provided for @gameSupporterRoutingCurrentClubOnly.
  ///
  /// In en, this message translates to:
  /// **'Supporter registry and contribution routing are available for the current app club only.'**
  String get gameSupporterRoutingCurrentClubOnly;

  /// No description provided for @gameContributionRouteNotPublished.
  ///
  /// In en, this message translates to:
  /// **'This club has not published an active contribution route yet.'**
  String get gameContributionRouteNotPublished;

  /// No description provided for @gameClubSupporterDataUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Club supporter data is temporarily unavailable.'**
  String get gameClubSupporterDataUnavailable;

  /// No description provided for @gameContributionsActiveClubOnly.
  ///
  /// In en, this message translates to:
  /// **'Contributions are available only for the active club.'**
  String get gameContributionsActiveClubOnly;

  /// No description provided for @gameContributionRouteUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Contribution route unavailable.'**
  String get gameContributionRouteUnavailable;

  /// No description provided for @gameCouldNotOpenDialer.
  ///
  /// In en, this message translates to:
  /// **'Could not open the phone dialer.'**
  String get gameCouldNotOpenDialer;

  /// No description provided for @gameDialerLaunchFailed.
  ///
  /// In en, this message translates to:
  /// **'Dialer launch failed.'**
  String get gameDialerLaunchFailed;

  /// No description provided for @gameEnterContributionAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter contribution amount'**
  String get gameEnterContributionAmount;

  /// No description provided for @gamePaymentRouteDescription.
  ///
  /// In en, this message translates to:
  /// **'You will pay {recipient} via {provider}.'**
  String gamePaymentRouteDescription(String recipient, String provider);

  /// No description provided for @gameAmountCurrency.
  ///
  /// In en, this message translates to:
  /// **'Amount ({currency})'**
  String gameAmountCurrency(String currency);

  /// No description provided for @gameDialNow.
  ///
  /// In en, this message translates to:
  /// **'Dial now'**
  String get gameDialNow;

  /// No description provided for @gameEnterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount.'**
  String get gameEnterValidAmount;

  /// No description provided for @gameTeamProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Team profile'**
  String get gameTeamProfileTitle;

  /// No description provided for @gameTeamUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Team unavailable'**
  String get gameTeamUnavailable;

  /// No description provided for @gameFoundedYear.
  ///
  /// In en, this message translates to:
  /// **'Founded {year}'**
  String gameFoundedYear(int year);

  /// No description provided for @gameTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get gameTable;

  /// No description provided for @gameSquad.
  ///
  /// In en, this message translates to:
  /// **'Squad'**
  String get gameSquad;

  /// No description provided for @gameOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get gameOverview;

  /// No description provided for @gameMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get gameMembers;

  /// No description provided for @gameContribute.
  ///
  /// In en, this message translates to:
  /// **'Contribute'**
  String get gameContribute;

  /// No description provided for @gameAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get gameAbout;

  /// No description provided for @gameLeaguePosition.
  ///
  /// In en, this message translates to:
  /// **'League position'**
  String get gameLeaguePosition;

  /// No description provided for @gamePlayedShort.
  ///
  /// In en, this message translates to:
  /// **'P'**
  String get gamePlayedShort;

  /// No description provided for @gameWonShort.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get gameWonShort;

  /// No description provided for @gameDrawnShort.
  ///
  /// In en, this message translates to:
  /// **'D'**
  String get gameDrawnShort;

  /// No description provided for @gameLostShort.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get gameLostShort;

  /// No description provided for @gameGoalDifferenceShort.
  ///
  /// In en, this message translates to:
  /// **'Gd'**
  String get gameGoalDifferenceShort;

  /// No description provided for @gameMomoContributionRoute.
  ///
  /// In en, this message translates to:
  /// **'MoMo contribution route'**
  String get gameMomoContributionRoute;

  /// No description provided for @gameUseProviderForClub.
  ///
  /// In en, this message translates to:
  /// **'Use {provider} to contribute to {club}.'**
  String gameUseProviderForClub(String provider, String club);

  /// No description provided for @gameThisClub.
  ///
  /// In en, this message translates to:
  /// **'this club'**
  String get gameThisClub;

  /// No description provided for @gameSupporterRegistryCurrentClubOnly.
  ///
  /// In en, this message translates to:
  /// **'Supporter registry is available only for the current app club.'**
  String get gameSupporterRegistryCurrentClubOnly;

  /// No description provided for @gameMembersUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Members unavailable'**
  String get gameMembersUnavailable;

  /// No description provided for @gameClubMembers.
  ///
  /// In en, this message translates to:
  /// **'Club members'**
  String get gameClubMembers;

  /// No description provided for @gameTierGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get gameTierGold;

  /// No description provided for @gameTierSilver.
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get gameTierSilver;

  /// No description provided for @gameTierBronze.
  ///
  /// In en, this message translates to:
  /// **'Bronze'**
  String get gameTierBronze;

  /// No description provided for @gameTierImena.
  ///
  /// In en, this message translates to:
  /// **'Imena'**
  String get gameTierImena;

  /// No description provided for @gameTopContributors.
  ///
  /// In en, this message translates to:
  /// **'Top contributors'**
  String get gameTopContributors;

  /// No description provided for @gameMomoContribution.
  ///
  /// In en, this message translates to:
  /// **'MoMo contribution'**
  String get gameMomoContribution;

  /// No description provided for @gameUseProviderInCountry.
  ///
  /// In en, this message translates to:
  /// **'Use {provider} in {country} to contribute to this club.'**
  String gameUseProviderInCountry(String provider, String country);

  /// No description provided for @gameEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get gameEnterAmount;

  /// No description provided for @gameEnterAmountDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose how much you want to send through {provider}.'**
  String gameEnterAmountDescription(String provider);

  /// No description provided for @gameConfirmInDialer.
  ///
  /// In en, this message translates to:
  /// **'Confirm in dialer'**
  String get gameConfirmInDialer;

  /// No description provided for @gameConfirmInDialerDescription.
  ///
  /// In en, this message translates to:
  /// **'We will open the mobile money dialer for code {code}.'**
  String gameConfirmInDialerDescription(String code);

  /// No description provided for @gameReconciliation.
  ///
  /// In en, this message translates to:
  /// **'Reconciliation'**
  String get gameReconciliation;

  /// No description provided for @gameReconciliationDescription.
  ///
  /// In en, this message translates to:
  /// **'Your contribution is matched back to your club activity once payment is confirmed.'**
  String get gameReconciliationDescription;

  /// No description provided for @gameOpeningDialer.
  ///
  /// In en, this message translates to:
  /// **'Opening dialer…'**
  String get gameOpeningDialer;

  /// No description provided for @gameEnterAmountAndDial.
  ///
  /// In en, this message translates to:
  /// **'Enter amount & dial'**
  String get gameEnterAmountAndDial;

  /// No description provided for @gameAboutTeam.
  ///
  /// In en, this message translates to:
  /// **'ABOUT {team}'**
  String gameAboutTeam(String team);

  /// No description provided for @gameThisClubUpper.
  ///
  /// In en, this message translates to:
  /// **'This club'**
  String get gameThisClubUpper;

  /// No description provided for @gameLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get gameLocation;

  /// No description provided for @gameCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get gameCountry;

  /// No description provided for @gameFounded.
  ///
  /// In en, this message translates to:
  /// **'Founded'**
  String get gameFounded;

  /// No description provided for @gameType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get gameType;

  /// No description provided for @gameAffiliatedClub.
  ///
  /// In en, this message translates to:
  /// **'Affiliated Club'**
  String get gameAffiliatedClub;

  /// No description provided for @gameSelectedLeaderboardPeriod.
  ///
  /// In en, this message translates to:
  /// **'Selected leaderboard period'**
  String get gameSelectedLeaderboardPeriod;

  /// No description provided for @gameSelectPeriod.
  ///
  /// In en, this message translates to:
  /// **'Select period'**
  String get gameSelectPeriod;

  /// No description provided for @gameRankLabel.
  ///
  /// In en, this message translates to:
  /// **'#{rank}'**
  String gameRankLabel(String rank);

  /// No description provided for @gameRankPending.
  ///
  /// In en, this message translates to:
  /// **'Rank pending'**
  String get gameRankPending;

  /// No description provided for @gameAccuracyWins.
  ///
  /// In en, this message translates to:
  /// **'{accuracy}% accuracy · {wins, plural, =1{1 win} other{{wins} wins}}'**
  String gameAccuracyWins(String accuracy, int wins);

  /// No description provided for @gameSettledCount.
  ///
  /// In en, this message translates to:
  /// **'{count} settled'**
  String gameSettledCount(int count);

  /// No description provided for @gameTierAlias.
  ///
  /// In en, this message translates to:
  /// **'{tier} tier · {alias}'**
  String gameTierAlias(String tier, String alias);

  /// No description provided for @gamePodiumRank.
  ///
  /// In en, this message translates to:
  /// **'Podium rank {rank}'**
  String gamePodiumRank(int rank);

  /// No description provided for @gamePickRound.
  ///
  /// In en, this message translates to:
  /// **'Pick round'**
  String get gamePickRound;

  /// No description provided for @gameActivePicks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pick active} other{{count} picks active}}'**
  String gameActivePicks(int count);

  /// No description provided for @gameEarnUpToPoints.
  ///
  /// In en, this message translates to:
  /// **'Earn up to {count} pts'**
  String gameEarnUpToPoints(int count);

  /// No description provided for @gamePickRoundEmpty.
  ///
  /// In en, this message translates to:
  /// **'Pick round is empty'**
  String get gamePickRoundEmpty;

  /// No description provided for @gamePickRoundEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Add picks from any fixture and lock them in from here.'**
  String get gamePickRoundEmptyDescription;

  /// No description provided for @gamePickRoundUpper.
  ///
  /// In en, this message translates to:
  /// **'Pick round'**
  String get gamePickRoundUpper;

  /// No description provided for @gameAcca.
  ///
  /// In en, this message translates to:
  /// **'Acca'**
  String get gameAcca;

  /// No description provided for @gamePotentialPoints.
  ///
  /// In en, this message translates to:
  /// **'Potential points: {count} pts'**
  String gamePotentialPoints(int count);

  /// No description provided for @gameLockInPicks.
  ///
  /// In en, this message translates to:
  /// **'Lock In Picks'**
  String get gameLockInPicks;

  /// No description provided for @gameSomeSelectionsFailed.
  ///
  /// In en, this message translates to:
  /// **'Some selections could not be submitted.'**
  String get gameSomeSelectionsFailed;

  /// No description provided for @gameCouldNotSubmitPicks.
  ///
  /// In en, this message translates to:
  /// **'Could not submit your picks.'**
  String get gameCouldNotSubmitPicks;

  /// No description provided for @gameConfirmPicks.
  ///
  /// In en, this message translates to:
  /// **'Confirm picks'**
  String get gameConfirmPicks;

  /// No description provided for @gameLockingCombo.
  ///
  /// In en, this message translates to:
  /// **'You are locking {count} picks as a combo.'**
  String gameLockingCombo(int count);

  /// No description provided for @gameLockingPicks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You are locking 1 pick.} other{You are locking {count} picks.}}'**
  String gameLockingPicks(int count);

  /// No description provided for @gameOutcomePotential.
  ///
  /// In en, this message translates to:
  /// **'{outcome} · +{count} pts'**
  String gameOutcomePotential(String outcome, int count);

  /// No description provided for @gameTotalPotential.
  ///
  /// In en, this message translates to:
  /// **'Total potential'**
  String get gameTotalPotential;

  /// No description provided for @gameGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get gameGoBack;

  /// No description provided for @gamePredictionsLocked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Prediction Locked} other{{count} Predictions Locked}}'**
  String gamePredictionsLocked(int count);

  /// No description provided for @gameRoundId.
  ///
  /// In en, this message translates to:
  /// **'Round ID: {id}'**
  String gameRoundId(String id);

  /// No description provided for @gameShareUpper.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get gameShareUpper;

  /// No description provided for @gameCopyUpper.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get gameCopyUpper;

  /// No description provided for @gameViewMyPredictions.
  ///
  /// In en, this message translates to:
  /// **'View my predictions'**
  String get gameViewMyPredictions;

  /// No description provided for @gameKeepBrowsing.
  ///
  /// In en, this message translates to:
  /// **'Keep browsing'**
  String get gameKeepBrowsing;

  /// No description provided for @gameRemovePick.
  ///
  /// In en, this message translates to:
  /// **'Remove pick'**
  String get gameRemovePick;

  /// No description provided for @gameFans.
  ///
  /// In en, this message translates to:
  /// **'Fans'**
  String get gameFans;

  /// No description provided for @gameWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get gameWallet;

  /// No description provided for @gameMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get gameMore;

  /// No description provided for @gameRoundUpper.
  ///
  /// In en, this message translates to:
  /// **'Round'**
  String get gameRoundUpper;

  /// No description provided for @gameAccuracyRounds.
  ///
  /// In en, this message translates to:
  /// **'{accuracy}% · {count, plural, =1{1 round} other{{count} rounds}}'**
  String gameAccuracyRounds(String accuracy, int count);

  /// No description provided for @gamePointsRound.
  ///
  /// In en, this message translates to:
  /// **'{count} points round'**
  String gamePointsRound(int count);

  /// No description provided for @gamePointsRoundLabel.
  ///
  /// In en, this message translates to:
  /// **'points round'**
  String get gamePointsRoundLabel;

  /// No description provided for @gamePointEntry.
  ///
  /// In en, this message translates to:
  /// **'{count} point entry'**
  String gamePointEntry(int count);

  /// No description provided for @gameFansCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 fan} other{{count} fans}}'**
  String gameFansCount(int count);

  /// No description provided for @gameChooseWdw.
  ///
  /// In en, this message translates to:
  /// **'Choose W/D/W'**
  String get gameChooseWdw;

  /// No description provided for @gameJoinRound.
  ///
  /// In en, this message translates to:
  /// **'Join round'**
  String get gameJoinRound;

  /// No description provided for @gameSelectedOutcome.
  ///
  /// In en, this message translates to:
  /// **'Selected {outcome}'**
  String gameSelectedOutcome(String outcome);

  /// No description provided for @gameChallengesTitle.
  ///
  /// In en, this message translates to:
  /// **'Challenges'**
  String get gameChallengesTitle;

  /// No description provided for @gameChallengesTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Challenges are temporarily unavailable.'**
  String get gameChallengesTemporarilyUnavailable;

  /// No description provided for @gameChallengesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Challenges unavailable'**
  String get gameChallengesUnavailable;

  /// No description provided for @gameDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get gameDaily;

  /// No description provided for @gameWeeklyUpper.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get gameWeeklyUpper;

  /// No description provided for @gameSeasonal.
  ///
  /// In en, this message translates to:
  /// **'Seasonal'**
  String get gameSeasonal;

  /// No description provided for @gameCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get gameCompleted;

  /// No description provided for @gameChallengesRequireProfile.
  ///
  /// In en, this message translates to:
  /// **'Challenges appear once your supporter profile is active.'**
  String get gameChallengesRequireProfile;

  /// No description provided for @gameWhatIsFet.
  ///
  /// In en, this message translates to:
  /// **'What is FET?'**
  String get gameWhatIsFet;

  /// No description provided for @gameWhatIsFetBody.
  ///
  /// In en, this message translates to:
  /// **'FET (Fan Engagement Tokens) are your supporter currency. Earn them by engaging with your club—attending matches, completing challenges, making predictions, and supporting the community.'**
  String get gameWhatIsFetBody;

  /// No description provided for @gameHowPredictionsWork.
  ///
  /// In en, this message translates to:
  /// **'How predictions work'**
  String get gameHowPredictionsWork;

  /// No description provided for @gameHowPredictionsWorkBody.
  ///
  /// In en, this message translates to:
  /// **'Browse upcoming fixtures, choose pick types such as Match Result, Goals, and Scorers, then lock in picks before kick-off. Correct picks earn points based on difficulty.'**
  String get gameHowPredictionsWorkBody;

  /// No description provided for @gameEarnLevelRedeem.
  ///
  /// In en, this message translates to:
  /// **'Earn, level up & redeem'**
  String get gameEarnLevelRedeem;

  /// No description provided for @gameEarnLevelRedeemBody.
  ///
  /// In en, this message translates to:
  /// **'Your points balance grows as you engage. Climb the leaderboard, unlock membership tiers, and redeem rewards from the club store. Every action counts.'**
  String get gameEarnLevelRedeemBody;

  /// No description provided for @gameBackUpper.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get gameBackUpper;

  /// No description provided for @gameGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get gameGetStarted;

  /// No description provided for @gameNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get gameNext;

  /// No description provided for @gameMyChallenges.
  ///
  /// In en, this message translates to:
  /// **'My challenges'**
  String get gameMyChallenges;

  /// No description provided for @gameOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get gameOpen;

  /// No description provided for @gameLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get gameLocked;

  /// No description provided for @gameSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get gameSettled;

  /// No description provided for @gameRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get gameRefunded;

  /// No description provided for @gameLoadingChallenges.
  ///
  /// In en, this message translates to:
  /// **'Loading your challenges'**
  String get gameLoadingChallenges;

  /// No description provided for @gameLoadingChallengesDescription.
  ///
  /// In en, this message translates to:
  /// **'Checking the pools you created or joined for this status.'**
  String get gameLoadingChallengesDescription;

  /// No description provided for @gameRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get gameRefresh;

  /// No description provided for @gameRefreshingChallengeHistory.
  ///
  /// In en, this message translates to:
  /// **'Refreshing challenge history'**
  String get gameRefreshingChallengeHistory;

  /// No description provided for @gameRefreshingChallengeHistoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Keeping your confirmed pools visible while the latest status is checked.'**
  String get gameRefreshingChallengeHistoryDescription;

  /// No description provided for @gameChallengeHistoryReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Challenge history is read-only'**
  String get gameChallengeHistoryReadOnly;

  /// No description provided for @gameChallengeHistoryReadOnlyDescription.
  ///
  /// In en, this message translates to:
  /// **'Your confirmed pools remain visible, but opening challenge details is disabled for this build.'**
  String get gameChallengeHistoryReadOnlyDescription;

  /// No description provided for @gameShowingSavedChallengeHistory.
  ///
  /// In en, this message translates to:
  /// **'Showing saved challenge history'**
  String get gameShowingSavedChallengeHistory;

  /// No description provided for @gameShowingSavedChallengeHistoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Reconnect and refresh before opening a pool or checking a newer status.'**
  String get gameShowingSavedChallengeHistoryDescription;

  /// No description provided for @gameRefreshHistory.
  ///
  /// In en, this message translates to:
  /// **'Refresh history'**
  String get gameRefreshHistory;

  /// No description provided for @gameNoFilteredChallenges.
  ///
  /// In en, this message translates to:
  /// **'No {filter} challenges'**
  String gameNoFilteredChallenges(String filter);

  /// No description provided for @gameCreateChallenge.
  ///
  /// In en, this message translates to:
  /// **'Create challenge'**
  String get gameCreateChallenge;

  /// No description provided for @gameChallengeCardSemantics.
  ///
  /// In en, this message translates to:
  /// **'{home} versus {away}. {summary}. Open challenge details.'**
  String gameChallengeCardSemantics(String home, String away, String summary);

  /// No description provided for @gameOpensChallenge.
  ///
  /// In en, this message translates to:
  /// **'Opens this challenge'**
  String get gameOpensChallenge;

  /// No description provided for @gameChallengeDetailsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Challenge details are unavailable'**
  String get gameChallengeDetailsUnavailable;

  /// No description provided for @gameTeamsVersusMultiline.
  ///
  /// In en, this message translates to:
  /// **'{home}\nversus\n{away}'**
  String gameTeamsVersusMultiline(String home, String away);

  /// No description provided for @gameConnectionRestored.
  ///
  /// In en, this message translates to:
  /// **'Connection restored'**
  String get gameConnectionRestored;

  /// No description provided for @gameChallengeHistoryOffline.
  ///
  /// In en, this message translates to:
  /// **'Challenge history offline'**
  String get gameChallengeHistoryOffline;

  /// No description provided for @gameRefreshLatestChallengeStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh to check the latest status of your challenges.'**
  String get gameRefreshLatestChallengeStatus;

  /// No description provided for @gameReconnectChallengePools.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to load the pools you created or joined.'**
  String get gameReconnectChallengePools;

  /// No description provided for @gameChallengeHistoryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Challenge history unavailable'**
  String get gameChallengeHistoryUnavailable;

  /// No description provided for @gameChallengeHistoryPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Your current club access does not allow this challenge history.'**
  String get gameChallengeHistoryPermissionDenied;

  /// No description provided for @gameChallengeHistoryChanged.
  ///
  /// In en, this message translates to:
  /// **'Challenge history changed'**
  String get gameChallengeHistoryChanged;

  /// No description provided for @gameChallengeHistoryChangedDescription.
  ///
  /// In en, this message translates to:
  /// **'Refresh and review the latest pool status before opening a challenge.'**
  String get gameChallengeHistoryChangedDescription;

  /// No description provided for @gameChallengeHistoryTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Challenge history check timed out'**
  String get gameChallengeHistoryTimedOut;

  /// No description provided for @gameChallengeHistoryTimedOutDescription.
  ///
  /// In en, this message translates to:
  /// **'No status was confirmed. Refresh before opening a challenge.'**
  String get gameChallengeHistoryTimedOutDescription;

  /// No description provided for @gameChallengeHistoryTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Refresh and try again when your challenge history is ready.'**
  String get gameChallengeHistoryTryAgain;

  /// No description provided for @gameOpenChallengesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Create or join a pool to see an active exact-score challenge here.'**
  String get gameOpenChallengesEmpty;

  /// No description provided for @gameLockedChallengesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No joined challenge is currently waiting for a final score.'**
  String get gameLockedChallengesEmpty;

  /// No description provided for @gameSettledChallengesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Completed challenge results and points will appear here.'**
  String get gameSettledChallengesEmpty;

  /// No description provided for @gameRefundedChallengesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Cancelled or refunded challenges will appear here.'**
  String get gameRefundedChallengesEmpty;

  /// No description provided for @gameEarnedPoints.
  ///
  /// In en, this message translates to:
  /// **'Earned {count} pts'**
  String gameEarnedPoints(int count);

  /// No description provided for @gameNoResultCredit.
  ///
  /// In en, this message translates to:
  /// **'No result credit'**
  String get gameNoResultCredit;

  /// No description provided for @gameReturnedPoints.
  ///
  /// In en, this message translates to:
  /// **'Returned {count} pts'**
  String gameReturnedPoints(int count);

  /// No description provided for @gameMyPickScore.
  ///
  /// In en, this message translates to:
  /// **'My pick {home}-{away}'**
  String gameMyPickScore(int home, int away);

  /// No description provided for @gameMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get gameMoreOptions;

  /// No description provided for @gameConnectToFanZone.
  ///
  /// In en, this message translates to:
  /// **'Connect to load Fan Zone.'**
  String get gameConnectToFanZone;

  /// No description provided for @gameOpeningFanZone.
  ///
  /// In en, this message translates to:
  /// **'Opening Fan Zone'**
  String get gameOpeningFanZone;

  /// No description provided for @gameRefreshingFanZone.
  ///
  /// In en, this message translates to:
  /// **'Refreshing Fan Zone'**
  String get gameRefreshingFanZone;

  /// No description provided for @gameRefreshingFanZoneDescription.
  ///
  /// In en, this message translates to:
  /// **'Keeping your current points, rounds, and picks visible while updates load.'**
  String get gameRefreshingFanZoneDescription;

  /// No description provided for @gameMatchdayRounds.
  ///
  /// In en, this message translates to:
  /// **'Matchday rounds'**
  String get gameMatchdayRounds;

  /// No description provided for @gameNoMatchdayRounds.
  ///
  /// In en, this message translates to:
  /// **'No matchday rounds'**
  String get gameNoMatchdayRounds;

  /// No description provided for @gameReviewJoinedRounds.
  ///
  /// In en, this message translates to:
  /// **'Review joined rounds, cards, and results'**
  String get gameReviewJoinedRounds;

  /// No description provided for @gameVenueCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Venue check-in'**
  String get gameVenueCheckIn;

  /// No description provided for @gameVenueOrder.
  ///
  /// In en, this message translates to:
  /// **'Venue order'**
  String get gameVenueOrder;

  /// No description provided for @gameVenueOrderDescription.
  ///
  /// In en, this message translates to:
  /// **'Order approved drinks and track pickup status'**
  String get gameVenueOrderDescription;

  /// No description provided for @gameLiveNow.
  ///
  /// In en, this message translates to:
  /// **'Live Now'**
  String get gameLiveNow;

  /// No description provided for @gameThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get gameThisWeek;

  /// No description provided for @gamePointsBalanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Points balance'**
  String get gamePointsBalanceTitle;

  /// No description provided for @gamePointsBalanceDescription.
  ///
  /// In en, this message translates to:
  /// **'Balance, earning, rewards, and activity'**
  String get gamePointsBalanceDescription;

  /// No description provided for @gameActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get gameActivity;

  /// No description provided for @gameOpenPointsActivity.
  ///
  /// In en, this message translates to:
  /// **'Open recent points movement'**
  String get gameOpenPointsActivity;

  /// No description provided for @gameSupporterClubs.
  ///
  /// In en, this message translates to:
  /// **'Supporter clubs'**
  String get gameSupporterClubs;

  /// No description provided for @gameSupporterClubsDescription.
  ///
  /// In en, this message translates to:
  /// **'Fan clubs, chapters, and community groups'**
  String get gameSupporterClubsDescription;

  /// No description provided for @gameMemberFans.
  ///
  /// In en, this message translates to:
  /// **'Member fans'**
  String get gameMemberFans;

  /// No description provided for @gameMemberFansDescription.
  ///
  /// In en, this message translates to:
  /// **'Open the supporter registry as a sheet'**
  String get gameMemberFansDescription;

  /// No description provided for @gameSupportClubDescription.
  ///
  /// In en, this message translates to:
  /// **'Projects and supporter contribution groups'**
  String get gameSupportClubDescription;

  /// No description provided for @gameRedeemRewards.
  ///
  /// In en, this message translates to:
  /// **'Redeem rewards'**
  String get gameRedeemRewards;

  /// No description provided for @gameRedeemRewardsDescription.
  ///
  /// In en, this message translates to:
  /// **'Use points for rewards and partner offers'**
  String get gameRedeemRewardsDescription;

  /// No description provided for @gameAchievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get gameAchievements;

  /// No description provided for @gameAchievementsDescription.
  ///
  /// In en, this message translates to:
  /// **'Badges and streak status'**
  String get gameAchievementsDescription;

  /// No description provided for @gameShareCard.
  ///
  /// In en, this message translates to:
  /// **'Share card'**
  String get gameShareCard;

  /// No description provided for @gameShareCardDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a supporter card to share'**
  String get gameShareCardDescription;

  /// No description provided for @gameConnectBeforeJoiningRound.
  ///
  /// In en, this message translates to:
  /// **'Connect before joining this round.'**
  String get gameConnectBeforeJoiningRound;

  /// No description provided for @gamePoolEntryFailed.
  ///
  /// In en, this message translates to:
  /// **'Pool entry could not be recorded.'**
  String get gamePoolEntryFailed;

  /// No description provided for @gameOutcomeJoined.
  ///
  /// In en, this message translates to:
  /// **'{outcome} joined.'**
  String gameOutcomeJoined(String outcome);

  /// No description provided for @gamePartnerSponsorsRound.
  ///
  /// In en, this message translates to:
  /// **'{partner} sponsors this matchday round. Pick once before the round locks.'**
  String gamePartnerSponsorsRound(String partner);

  /// No description provided for @gameProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get gameProjects;

  /// No description provided for @gameProjectsDescription.
  ///
  /// In en, this message translates to:
  /// **'Club initiatives and campaign needs'**
  String get gameProjectsDescription;

  /// No description provided for @gameGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get gameGroups;

  /// No description provided for @gameGroupsDescription.
  ///
  /// In en, this message translates to:
  /// **'Join supporter contribution groups'**
  String get gameGroupsDescription;

  /// No description provided for @gameQrSheetDescription.
  ///
  /// In en, this message translates to:
  /// **'QR display and sharing stay inside this sheet.'**
  String get gameQrSheetDescription;

  /// No description provided for @gameFanIdQrDisplay.
  ///
  /// In en, this message translates to:
  /// **'Fan ID and QR display'**
  String get gameFanIdQrDisplay;

  /// No description provided for @gameQr.
  ///
  /// In en, this message translates to:
  /// **'QR'**
  String get gameQr;

  /// No description provided for @gameBadgesEarnedDescription.
  ///
  /// In en, this message translates to:
  /// **'Earned from picks, attendance, and support actions'**
  String get gameBadgesEarnedDescription;

  /// No description provided for @gameStartStreak.
  ///
  /// In en, this message translates to:
  /// **'Join your next round to start a streak'**
  String get gameStartStreak;

  /// No description provided for @gameActivePlayDays.
  ///
  /// In en, this message translates to:
  /// **'{count} active play days'**
  String gameActivePlayDays(int count);

  /// No description provided for @gameActionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{description}. Unavailable.'**
  String gameActionUnavailable(String description);

  /// No description provided for @gameFanZoneAccessUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Fan Zone access not available'**
  String get gameFanZoneAccessUnavailable;

  /// No description provided for @gameFanZoneAccessUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'Your account cannot open Fan Zone right now. Contact support if this should be available.'**
  String get gameFanZoneAccessUnavailableDescription;

  /// No description provided for @gameFanZoneChanged.
  ///
  /// In en, this message translates to:
  /// **'Fan Zone changed'**
  String get gameFanZoneChanged;

  /// No description provided for @gameFanZoneChangedDescription.
  ///
  /// In en, this message translates to:
  /// **'Fan Zone data changed while you were viewing it. Refresh to load the current version.'**
  String get gameFanZoneChangedDescription;

  /// No description provided for @gameFanZoneSecurityTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Fan Zone security check timed out'**
  String get gameFanZoneSecurityTimedOut;

  /// No description provided for @gameFanZoneSecurityTimedOutDescription.
  ///
  /// In en, this message translates to:
  /// **'We could not confirm current Fan Zone access. Refresh before continuing.'**
  String get gameFanZoneSecurityTimedOutDescription;

  /// No description provided for @gameFanZoneTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Fan Zone is temporarily unavailable.'**
  String get gameFanZoneTemporarilyUnavailable;

  /// No description provided for @gameSavedFanZoneContent.
  ///
  /// In en, this message translates to:
  /// **'Showing saved Fan Zone content. Reconnect and refresh for current fixtures and balances.'**
  String get gameSavedFanZoneContent;

  /// No description provided for @gamePickSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Pick'**
  String get gamePickSectionLabel;

  /// No description provided for @gamePicksLabel.
  ///
  /// In en, this message translates to:
  /// **'Picks'**
  String get gamePicksLabel;

  /// No description provided for @gameRewardsLabel.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get gameRewardsLabel;

  /// No description provided for @gameStreakLabel.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get gameStreakLabel;

  /// No description provided for @gameBadgesLabel.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get gameBadgesLabel;

  /// No description provided for @gamePointsLabel.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get gamePointsLabel;

  /// No description provided for @gameAccuracyLabel.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get gameAccuracyLabel;

  /// No description provided for @gameFanZoneUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Fan Zone unavailable'**
  String get gameFanZoneUnavailableTitle;

  /// No description provided for @venueOrderConfirmedToast.
  ///
  /// In en, this message translates to:
  /// **'Order confirmed by the venue service. Pay only at the venue.'**
  String get venueOrderConfirmedToast;

  /// No description provided for @venueOrderingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Venue ordering unavailable'**
  String get venueOrderingUnavailable;

  /// No description provided for @venueFeatureDisabled.
  ///
  /// In en, this message translates to:
  /// **'This governed feature is disabled for the current club or build.'**
  String get venueFeatureDisabled;

  /// No description provided for @venueBackToFanZone.
  ///
  /// In en, this message translates to:
  /// **'Back to fan zone'**
  String get venueBackToFanZone;

  /// No description provided for @venueOrderAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Venue order access denied'**
  String get venueOrderAccessDenied;

  /// No description provided for @venueOrderAccessDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'This account cannot use the supporter venue-order route.'**
  String get venueOrderAccessDeniedBody;

  /// No description provided for @venueOrderAccessDeniedLoadBody.
  ///
  /// In en, this message translates to:
  /// **'This account cannot load the supporter venue-order route.'**
  String get venueOrderAccessDeniedLoadBody;

  /// No description provided for @venueCheckInBeforeOrdering.
  ///
  /// In en, this message translates to:
  /// **'Check in before ordering'**
  String get venueCheckInBeforeOrdering;

  /// No description provided for @venueCheckInRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'A confirmed venue check-in is required before the approved drinks menu can be loaded.'**
  String get venueCheckInRequiredBody;

  /// No description provided for @venueCheckInFirst.
  ///
  /// In en, this message translates to:
  /// **'Check in first'**
  String get venueCheckInFirst;

  /// No description provided for @venueNoDrinksAvailable.
  ///
  /// In en, this message translates to:
  /// **'No drinks available'**
  String get venueNoDrinksAvailable;

  /// No description provided for @venueNoDrinksBody.
  ///
  /// In en, this message translates to:
  /// **'The checked-in venue has no approved active drinks right now.'**
  String get venueNoDrinksBody;

  /// No description provided for @venueRefreshMenu.
  ///
  /// In en, this message translates to:
  /// **'Refresh menu'**
  String get venueRefreshMenu;

  /// No description provided for @venueMenuUnavailableOffline.
  ///
  /// In en, this message translates to:
  /// **'Venue menu unavailable offline'**
  String get venueMenuUnavailableOffline;

  /// No description provided for @venueMenuOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Reconnect before loading the venue menu. No order is queued offline.'**
  String get venueMenuOfflineBody;

  /// No description provided for @venueTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get venueTryAgain;

  /// No description provided for @venueMenuCheckTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Venue menu check timed out'**
  String get venueMenuCheckTimedOut;

  /// No description provided for @venueMenuCheckTimedOutBody.
  ///
  /// In en, this message translates to:
  /// **'The app could not establish a safe order context in time. Try one bounded refresh.'**
  String get venueMenuCheckTimedOutBody;

  /// No description provided for @venueMenuUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'The checked-in venue and approved menu could not be loaded safely.'**
  String get venueMenuUnavailableBody;

  /// No description provided for @venueOrderHero.
  ///
  /// In en, this message translates to:
  /// **'Order drinks at this venue'**
  String get venueOrderHero;

  /// No description provided for @venueOrderHeroBody.
  ///
  /// In en, this message translates to:
  /// **'Choose from the approved drinks-only menu. Staff queue actions remain in the venue portal.'**
  String get venueOrderHeroBody;

  /// No description provided for @venueApprovedDrinks.
  ///
  /// In en, this message translates to:
  /// **'Approved drinks'**
  String get venueApprovedDrinks;

  /// No description provided for @venueOrderReview.
  ///
  /// In en, this message translates to:
  /// **'Order review'**
  String get venueOrderReview;

  /// No description provided for @venueOrderReviewValue.
  ///
  /// In en, this message translates to:
  /// **'{count} items, {total}'**
  String venueOrderReviewValue(int count, String total);

  /// No description provided for @venueLegalAgeConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Legal age confirmation'**
  String get venueLegalAgeConfirmation;

  /// No description provided for @venueNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get venueNotSelected;

  /// No description provided for @venueAgeConfirmationRequired.
  ///
  /// In en, this message translates to:
  /// **'Age confirmation required'**
  String get venueAgeConfirmationRequired;

  /// No description provided for @venueAgeConfirmationBody.
  ///
  /// In en, this message translates to:
  /// **'Confirm only if you meet the venueʼs legal age requirement. Venue staff may still verify eligibility.'**
  String get venueAgeConfirmationBody;

  /// No description provided for @venueRemoveConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Remove confirmation'**
  String get venueRemoveConfirmation;

  /// No description provided for @venueConfirmLegalAge.
  ///
  /// In en, this message translates to:
  /// **'Confirm legal age'**
  String get venueConfirmLegalAge;

  /// No description provided for @venuePayAtVenue.
  ///
  /// In en, this message translates to:
  /// **'Pay at the venue'**
  String get venuePayAtVenue;

  /// No description provided for @venuePaymentDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This app creates the drinks order only. It does not take payment or claim that payment succeeded.'**
  String get venuePaymentDisclaimer;

  /// No description provided for @venueCreatingOrderUpper.
  ///
  /// In en, this message translates to:
  /// **'Creating order'**
  String get venueCreatingOrderUpper;

  /// No description provided for @venueOrderConfirmedUpper.
  ///
  /// In en, this message translates to:
  /// **'Order confirmed'**
  String get venueOrderConfirmedUpper;

  /// No description provided for @venueReviewCreateOrder.
  ///
  /// In en, this message translates to:
  /// **'Review and create order'**
  String get venueReviewCreateOrder;

  /// No description provided for @venueOrderProtections.
  ///
  /// In en, this message translates to:
  /// **'Order protections'**
  String get venueOrderProtections;

  /// No description provided for @venueDuplicateSubmission.
  ///
  /// In en, this message translates to:
  /// **'Duplicate submission'**
  String get venueDuplicateSubmission;

  /// No description provided for @venueDuplicateSubmissionBody.
  ///
  /// In en, this message translates to:
  /// **'One idempotency key per attempt'**
  String get venueDuplicateSubmissionBody;

  /// No description provided for @venueOfflineBehavior.
  ///
  /// In en, this message translates to:
  /// **'Offline behavior'**
  String get venueOfflineBehavior;

  /// No description provided for @venueOfflineBehaviorBody.
  ///
  /// In en, this message translates to:
  /// **'No queued or automatic replay'**
  String get venueOfflineBehaviorBody;

  /// No description provided for @venueStaffControls.
  ///
  /// In en, this message translates to:
  /// **'Staff controls'**
  String get venueStaffControls;

  /// No description provided for @venueStaffControlsBody.
  ///
  /// In en, this message translates to:
  /// **'Venue portal only'**
  String get venueStaffControlsBody;

  /// No description provided for @venueItemsSelected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item selected} other{{count} items selected}}'**
  String venueItemsSelected(int count);

  /// No description provided for @venueShowingSavedMenu.
  ///
  /// In en, this message translates to:
  /// **'Showing saved venue menu'**
  String get venueShowingSavedMenu;

  /// No description provided for @venueShowingSavedMenuBody.
  ///
  /// In en, this message translates to:
  /// **'Reconnect before creating the order. Nothing is queued or replayed offline.'**
  String get venueShowingSavedMenuBody;

  /// No description provided for @venueCreatingOrder.
  ///
  /// In en, this message translates to:
  /// **'Creating venue order'**
  String get venueCreatingOrder;

  /// No description provided for @venueCreatingOrderBody.
  ///
  /// In en, this message translates to:
  /// **'Wait for server confirmation. Do not repeat this order attempt.'**
  String get venueCreatingOrderBody;

  /// No description provided for @venueOrderCreated.
  ///
  /// In en, this message translates to:
  /// **'Order created'**
  String get venueOrderCreated;

  /// No description provided for @venueOrderCreatedSummary.
  ///
  /// In en, this message translates to:
  /// **'{status} · {total}. Payment remains external at the venue.'**
  String venueOrderCreatedSummary(String status, String total);

  /// No description provided for @venueChooseDrink.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one drink'**
  String get venueChooseDrink;

  /// No description provided for @venueChooseDrinkBody.
  ///
  /// In en, this message translates to:
  /// **'The order cannot be created with an empty selection.'**
  String get venueChooseDrinkBody;

  /// No description provided for @venueCheckInRequired.
  ///
  /// In en, this message translates to:
  /// **'Check-in required'**
  String get venueCheckInRequired;

  /// No description provided for @venueCheckInRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'The venue did not accept this check-in for ordering. Check in again before retrying.'**
  String get venueCheckInRejectedBody;

  /// No description provided for @venueAgeSubmitBody.
  ///
  /// In en, this message translates to:
  /// **'Confirm legal age before submitting an alcohol item.'**
  String get venueAgeSubmitBody;

  /// No description provided for @venueDrinkChanged.
  ///
  /// In en, this message translates to:
  /// **'A selected drink changed'**
  String get venueDrinkChanged;

  /// No description provided for @venueDrinkChangedBody.
  ///
  /// In en, this message translates to:
  /// **'Refresh the approved menu before retrying.'**
  String get venueDrinkChangedBody;

  /// No description provided for @venueOrderAttemptPaused.
  ///
  /// In en, this message translates to:
  /// **'Order attempt paused'**
  String get venueOrderAttemptPaused;

  /// No description provided for @venueOrderAttemptPausedBody.
  ///
  /// In en, this message translates to:
  /// **'Another request may be active. Check the latest order before retrying.'**
  String get venueOrderAttemptPausedBody;

  /// No description provided for @venueOrderConfirmationUncertain.
  ///
  /// In en, this message translates to:
  /// **'Order confirmation uncertain'**
  String get venueOrderConfirmationUncertain;

  /// No description provided for @venueOrderConfirmationUncertainBody.
  ///
  /// In en, this message translates to:
  /// **'Do not resubmit. Check the latest venue order before dismissing.'**
  String get venueOrderConfirmationUncertainBody;

  /// No description provided for @venueOrderNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Order not confirmed'**
  String get venueOrderNotConfirmed;

  /// No description provided for @venueOrderNotConfirmedBody.
  ///
  /// In en, this message translates to:
  /// **'The server did not confirm this order. Dismiss the warning before retrying.'**
  String get venueOrderNotConfirmedBody;

  /// No description provided for @venueLatestOrder.
  ///
  /// In en, this message translates to:
  /// **'Latest order: {status}'**
  String venueLatestOrder(String status);

  /// No description provided for @venueLatestOrderSummary.
  ///
  /// In en, this message translates to:
  /// **'{total} · {payment}.'**
  String venueLatestOrderSummary(String total, String payment);

  /// No description provided for @venueReadyToOrder.
  ///
  /// In en, this message translates to:
  /// **'Ready to order'**
  String get venueReadyToOrder;

  /// No description provided for @venueReadyToOrderBody.
  ///
  /// In en, this message translates to:
  /// **'Choose approved drinks, review the total, then create once.'**
  String get venueReadyToOrderBody;

  /// No description provided for @venueRemoveItem.
  ///
  /// In en, this message translates to:
  /// **'Remove {item}'**
  String venueRemoveItem(String item);

  /// No description provided for @venueAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add {item}'**
  String venueAddItem(String item);

  /// No description provided for @venueDrinkSemantics.
  ///
  /// In en, this message translates to:
  /// **'{count} selected, {price} each'**
  String venueDrinkSemantics(int count, String price);

  /// No description provided for @venueAgeRestricted.
  ///
  /// In en, this message translates to:
  /// **'Age restricted'**
  String get venueAgeRestricted;

  /// No description provided for @venueWaitingForVenue.
  ///
  /// In en, this message translates to:
  /// **'Waiting for venue'**
  String get venueWaitingForVenue;

  /// No description provided for @venueAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get venueAccepted;

  /// No description provided for @venuePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get venuePreparing;

  /// No description provided for @venueReadyForPickup.
  ///
  /// In en, this message translates to:
  /// **'Ready for pickup'**
  String get venueReadyForPickup;

  /// No description provided for @venueServed.
  ///
  /// In en, this message translates to:
  /// **'Served'**
  String get venueServed;

  /// No description provided for @venueStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Status pending'**
  String get venueStatusPending;

  /// No description provided for @venuePaidAtVenue.
  ///
  /// In en, this message translates to:
  /// **'Paid at venue'**
  String get venuePaidAtVenue;

  /// No description provided for @venuePaymentWaived.
  ///
  /// In en, this message translates to:
  /// **'Payment waived'**
  String get venuePaymentWaived;

  /// No description provided for @venueRefundedExternally.
  ///
  /// In en, this message translates to:
  /// **'Refunded externally'**
  String get venueRefundedExternally;

  /// No description provided for @venuePaymentPending.
  ///
  /// In en, this message translates to:
  /// **'Payment pending at venue'**
  String get venuePaymentPending;

  /// No description provided for @venueCheckinTitle.
  ///
  /// In en, this message translates to:
  /// **'Venue check-in'**
  String get venueCheckinTitle;

  /// No description provided for @venueCheckinUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Venue check-in unavailable'**
  String get venueCheckinUnavailable;

  /// No description provided for @venueCheckinAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Check-in access denied'**
  String get venueCheckinAccessDenied;

  /// No description provided for @venueCheckinAccessDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'This account cannot use the supporter check-in route.'**
  String get venueCheckinAccessDeniedBody;

  /// No description provided for @venueCheckinSafeStateBody.
  ///
  /// In en, this message translates to:
  /// **'The route could not establish a safe check-in state.'**
  String get venueCheckinSafeStateBody;

  /// No description provided for @venueCheckinHero.
  ///
  /// In en, this message translates to:
  /// **'Check in at an approved venue'**
  String get venueCheckinHero;

  /// No description provided for @venueCheckinHeroBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the rotating venue or QR code after you arrive. Supporter check-in never exposes staff or admin controls.'**
  String get venueCheckinHeroBody;

  /// No description provided for @venueCheckinCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Venue code'**
  String get venueCheckinCodeLabel;

  /// No description provided for @venueCheckinInputLabel.
  ///
  /// In en, this message translates to:
  /// **'Venue or QR code'**
  String get venueCheckinInputLabel;

  /// No description provided for @venueCheckinInputHint.
  ///
  /// In en, this message translates to:
  /// **'Enter at least 4 characters'**
  String get venueCheckinInputHint;

  /// No description provided for @venueCheckinCheckingCodeUpper.
  ///
  /// In en, this message translates to:
  /// **'Checking code'**
  String get venueCheckinCheckingCodeUpper;

  /// No description provided for @venueCheckinActionUpper.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get venueCheckinActionUpper;

  /// No description provided for @venueCheckinLocationConsentSemantics.
  ///
  /// In en, this message translates to:
  /// **'Location review consent'**
  String get venueCheckinLocationConsentSemantics;

  /// No description provided for @venueCheckinOptionalLocationReview.
  ///
  /// In en, this message translates to:
  /// **'Optional location review'**
  String get venueCheckinOptionalLocationReview;

  /// No description provided for @venueCheckinConsentMarkedBody.
  ///
  /// In en, this message translates to:
  /// **'Consent is marked for this attempt. This build still sends no coordinates; location-required campaigns remain pending review.'**
  String get venueCheckinConsentMarkedBody;

  /// No description provided for @venueCheckinNoLocationBody.
  ///
  /// In en, this message translates to:
  /// **'Precise location is not collected in this build. You may mark consent, but location-required campaigns remain pending review.'**
  String get venueCheckinNoLocationBody;

  /// No description provided for @venueCheckinRemoveConsentUpper.
  ///
  /// In en, this message translates to:
  /// **'Remove consent'**
  String get venueCheckinRemoveConsentUpper;

  /// No description provided for @venueCheckinMarkConsentUpper.
  ///
  /// In en, this message translates to:
  /// **'Mark consent'**
  String get venueCheckinMarkConsentUpper;

  /// No description provided for @venueCheckinPrivacyBoundary.
  ///
  /// In en, this message translates to:
  /// **'Privacy boundary'**
  String get venueCheckinPrivacyBoundary;

  /// No description provided for @venueCheckinPrivacyBoundaryBody.
  ///
  /// In en, this message translates to:
  /// **'Raw rotating codes are hashed before submission and are not persisted by the app. No precise location is collected.'**
  String get venueCheckinPrivacyBoundaryBody;

  /// No description provided for @venueCheckinPausedOffline.
  ///
  /// In en, this message translates to:
  /// **'Check-in paused offline'**
  String get venueCheckinPausedOffline;

  /// No description provided for @venueCheckinPausedOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Reconnect before submitting. No check-in is queued or replayed.'**
  String get venueCheckinPausedOfflineBody;

  /// No description provided for @venueCheckinCheckingCode.
  ///
  /// In en, this message translates to:
  /// **'Checking venue code'**
  String get venueCheckinCheckingCode;

  /// No description provided for @venueCheckinCheckingCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Wait for the server result. Do not repeat this check-in.'**
  String get venueCheckinCheckingCodeBody;

  /// No description provided for @venueCheckinPendingReview.
  ///
  /// In en, this message translates to:
  /// **'Check-in pending review'**
  String get venueCheckinPendingReview;

  /// No description provided for @venueCheckinConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Check-in confirmed'**
  String get venueCheckinConfirmed;

  /// No description provided for @venueCheckinPendingReviewBody.
  ///
  /// In en, this message translates to:
  /// **'The venue code was accepted, but a governed location or campaign check still needs review.'**
  String get venueCheckinPendingReviewBody;

  /// No description provided for @venueCheckinFetRecorded.
  ///
  /// In en, this message translates to:
  /// **'+{count} FET recorded for this check-in.'**
  String venueCheckinFetRecorded(int count);

  /// No description provided for @venueCheckinConfirmedNoReward.
  ///
  /// In en, this message translates to:
  /// **'The venue accepted this check-in. No reward was promised.'**
  String get venueCheckinConfirmedNoReward;

  /// No description provided for @venueCheckinReady.
  ///
  /// In en, this message translates to:
  /// **'Ready for venue check-in'**
  String get venueCheckinReady;

  /// No description provided for @venueCheckinReadyBody.
  ///
  /// In en, this message translates to:
  /// **'Use the current code only after you arrive on site.'**
  String get venueCheckinReadyBody;

  /// No description provided for @venueCheckinInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'Code not accepted'**
  String get venueCheckinInvalidCode;

  /// No description provided for @venueCheckinInvalidCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the current venue or QR code shown at the venue.'**
  String get venueCheckinInvalidCodeBody;

  /// No description provided for @venueCheckinExpiredCode.
  ///
  /// In en, this message translates to:
  /// **'Venue code expired'**
  String get venueCheckinExpiredCode;

  /// No description provided for @venueCheckinExpiredCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Ask the venue display for the current rotating code.'**
  String get venueCheckinExpiredCodeBody;

  /// No description provided for @venueCheckinAlreadyCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Already checked in'**
  String get venueCheckinAlreadyCheckedIn;

  /// No description provided for @venueCheckinAlreadyCheckedInBody.
  ///
  /// In en, this message translates to:
  /// **'The server found an existing check-in. No duplicate reward was created.'**
  String get venueCheckinAlreadyCheckedInBody;

  /// No description provided for @venueCheckinCampaignUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Check-in campaign unavailable'**
  String get venueCheckinCampaignUnavailable;

  /// No description provided for @venueCheckinCampaignUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'The campaign is paused, inactive, or has reached its governed budget.'**
  String get venueCheckinCampaignUnavailableBody;

  /// No description provided for @venueCheckinConflict.
  ///
  /// In en, this message translates to:
  /// **'Check-in conflict'**
  String get venueCheckinConflict;

  /// No description provided for @venueCheckinConflictBody.
  ///
  /// In en, this message translates to:
  /// **'Another attempt may already be active. Confirm the venue state before retrying.'**
  String get venueCheckinConflictBody;

  /// No description provided for @venueCheckinConfirmationUncertain.
  ///
  /// In en, this message translates to:
  /// **'Check-in confirmation uncertain'**
  String get venueCheckinConfirmationUncertain;

  /// No description provided for @venueCheckinConfirmationUncertainBody.
  ///
  /// In en, this message translates to:
  /// **'Do not repeat the code yet. Check your venue activity, then dismiss this warning.'**
  String get venueCheckinConfirmationUncertainBody;

  /// No description provided for @venueCheckinUnavailableShort.
  ///
  /// In en, this message translates to:
  /// **'Check-in unavailable'**
  String get venueCheckinUnavailableShort;

  /// No description provided for @venueCheckinUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'The server did not confirm the attempt. Dismiss this warning before retrying.'**
  String get venueCheckinUnavailableBody;

  /// No description provided for @challengeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm challenge'**
  String get challengeConfirmTitle;

  /// No description provided for @challengeConfirmPoints.
  ///
  /// In en, this message translates to:
  /// **'Confirm {count} pts'**
  String challengeConfirmPoints(int count);

  /// No description provided for @challengeCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create challenge'**
  String get challengeCreateTitle;

  /// No description provided for @challengeFindingFixtures.
  ///
  /// In en, this message translates to:
  /// **'Finding upcoming fixtures'**
  String get challengeFindingFixtures;

  /// No description provided for @challengeFindingFixturesBody.
  ///
  /// In en, this message translates to:
  /// **'Checking the matches that are still open for exact-score challenges.'**
  String get challengeFindingFixturesBody;

  /// No description provided for @challengeNoFixtures.
  ///
  /// In en, this message translates to:
  /// **'No fixtures available'**
  String get challengeNoFixtures;

  /// No description provided for @challengeNoFixturesBody.
  ///
  /// In en, this message translates to:
  /// **'There are no upcoming matches open for a new challenge yet.'**
  String get challengeNoFixturesBody;

  /// No description provided for @challengeRefreshFixtures.
  ///
  /// In en, this message translates to:
  /// **'Refresh fixtures'**
  String get challengeRefreshFixtures;

  /// No description provided for @challengeCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating challenge'**
  String get challengeCreating;

  /// No description provided for @challengeCreatingBody.
  ///
  /// In en, this message translates to:
  /// **'Keeping your fixture, score, and entry points visible while confirmation is pending.'**
  String get challengeCreatingBody;

  /// No description provided for @challengeCreationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Challenge creation unavailable'**
  String get challengeCreationUnavailable;

  /// No description provided for @challengeCreationDisabledBody.
  ///
  /// In en, this message translates to:
  /// **'You can review the form, but creating a pool is disabled for this build.'**
  String get challengeCreationDisabledBody;

  /// No description provided for @challengeShowingSavedFixtures.
  ///
  /// In en, this message translates to:
  /// **'Showing saved fixtures'**
  String get challengeShowingSavedFixtures;

  /// No description provided for @challengeShowingSavedFixturesBody.
  ///
  /// In en, this message translates to:
  /// **'Reconnect and refresh before changing the score or creating a challenge.'**
  String get challengeShowingSavedFixturesBody;

  /// No description provided for @challengeRefreshFixturesUpper.
  ///
  /// In en, this message translates to:
  /// **'Refresh fixtures'**
  String get challengeRefreshFixturesUpper;

  /// No description provided for @challengeExactScore.
  ///
  /// In en, this message translates to:
  /// **'Exact score'**
  String get challengeExactScore;

  /// No description provided for @challengeSelectedScore.
  ///
  /// In en, this message translates to:
  /// **'Selected exact score {home} to {away}'**
  String challengeSelectedScore(int home, int away);

  /// No description provided for @challengeVersusUpper.
  ///
  /// In en, this message translates to:
  /// **'Versus'**
  String get challengeVersusUpper;

  /// No description provided for @challengeEntryPoints.
  ///
  /// In en, this message translates to:
  /// **'Entry points'**
  String get challengeEntryPoints;

  /// No description provided for @challengeEntryOptionsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Challenge entry options are not available yet.'**
  String get challengeEntryOptionsUnavailable;

  /// No description provided for @challengeStakePoints.
  ///
  /// In en, this message translates to:
  /// **'{count} pts'**
  String challengeStakePoints(int count);

  /// No description provided for @challengeCheckingBalance.
  ///
  /// In en, this message translates to:
  /// **'Checking your points balance.'**
  String get challengeCheckingBalance;

  /// No description provided for @challengeBalanceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your points balance is unavailable. Refresh before creating this challenge.'**
  String get challengeBalanceUnavailable;

  /// No description provided for @challengeBalanceInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Your current points balance does not cover this entry.'**
  String get challengeBalanceInsufficient;

  /// No description provided for @challengeCreatingUpper.
  ///
  /// In en, this message translates to:
  /// **'Creating challenge'**
  String get challengeCreatingUpper;

  /// No description provided for @challengeCreationOffline.
  ///
  /// In en, this message translates to:
  /// **'Challenge creation offline'**
  String get challengeCreationOffline;

  /// No description provided for @challengeRefreshLatestFixtures.
  ///
  /// In en, this message translates to:
  /// **'Refresh to check the latest fixtures before creating a challenge.'**
  String get challengeRefreshLatestFixtures;

  /// No description provided for @challengeReconnectFixtures.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to load the fixtures available for a new challenge.'**
  String get challengeReconnectFixtures;

  /// No description provided for @challengeAccessDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'Your current club access does not allow a new challenge.'**
  String get challengeAccessDeniedBody;

  /// No description provided for @challengeDetailsChanged.
  ///
  /// In en, this message translates to:
  /// **'Challenge details changed'**
  String get challengeDetailsChanged;

  /// No description provided for @challengeDetailsChangedBody.
  ///
  /// In en, this message translates to:
  /// **'Refresh the fixtures and review your choice before trying again.'**
  String get challengeDetailsChangedBody;

  /// No description provided for @challengeSecurityTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Challenge security check timed out'**
  String get challengeSecurityTimedOut;

  /// No description provided for @challengeSecurityTimedOutBody.
  ///
  /// In en, this message translates to:
  /// **'No challenge was confirmed. Refresh before trying again.'**
  String get challengeSecurityTimedOutBody;

  /// No description provided for @challengeTryAgainBody.
  ///
  /// In en, this message translates to:
  /// **'Refresh and try again when the fixtures are available.'**
  String get challengeTryAgainBody;

  /// No description provided for @challengePreviewSemantics.
  ///
  /// In en, this message translates to:
  /// **'Challenge preview. {homeTeam} versus {awayTeam}. Your pick {homeScore} to {awayScore}. Entry {stake} points. Balance {balance} points.'**
  String challengePreviewSemantics(
    String homeTeam,
    String awayTeam,
    int homeScore,
    int awayScore,
    int stake,
    int balance,
  );

  /// No description provided for @challengePreview.
  ///
  /// In en, this message translates to:
  /// **'Challenge preview'**
  String get challengePreview;

  /// No description provided for @challengeYourPick.
  ///
  /// In en, this message translates to:
  /// **'Your pick'**
  String get challengeYourPick;

  /// No description provided for @challengeBalancePoints.
  ///
  /// In en, this message translates to:
  /// **'Balance {count} pts'**
  String challengeBalancePoints(int count);

  /// No description provided for @challengeLocksAtKickoff.
  ///
  /// In en, this message translates to:
  /// **'Locks at kickoff'**
  String get challengeLocksAtKickoff;

  /// No description provided for @challengeFixtureOption.
  ///
  /// In en, this message translates to:
  /// **'{home} vs {away} • {competition}'**
  String challengeFixtureOption(String home, String away, String competition);

  /// No description provided for @challengeDecrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease {label}'**
  String challengeDecrease(String label);

  /// No description provided for @challengeIncrease.
  ///
  /// In en, this message translates to:
  /// **'Increase {label}'**
  String challengeIncrease(String label);

  /// No description provided for @walletRewardsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Rewards unavailable'**
  String get walletRewardsUnavailable;

  /// No description provided for @walletDisabledBody.
  ///
  /// In en, this message translates to:
  /// **'Points and reward activity are disabled for this build.'**
  String get walletDisabledBody;

  /// No description provided for @walletNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No points activity yet'**
  String get walletNoActivity;

  /// No description provided for @walletNoActivityBody.
  ///
  /// In en, this message translates to:
  /// **'Your confirmed points balance and reward activity will appear here.'**
  String get walletNoActivityBody;

  /// No description provided for @walletOffline.
  ///
  /// In en, this message translates to:
  /// **'Rewards offline'**
  String get walletOffline;

  /// No description provided for @walletOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to load your confirmed points balance. Nothing is queued offline.'**
  String get walletOfflineBody;

  /// No description provided for @walletAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Rewards access denied'**
  String get walletAccessDenied;

  /// No description provided for @walletAccessDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'This account cannot open the private points ledger.'**
  String get walletAccessDeniedBody;

  /// No description provided for @walletCheckTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Points check timed out'**
  String get walletCheckTimedOut;

  /// No description provided for @walletCheckTimedOutBody.
  ///
  /// In en, this message translates to:
  /// **'The app could not confirm your private points ledger in time. Try one bounded refresh.'**
  String get walletCheckTimedOutBody;

  /// No description provided for @walletUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Your points ledger could not be loaded. No private activity details were shown.'**
  String get walletUnavailableBody;

  /// No description provided for @walletBalanceValue.
  ///
  /// In en, this message translates to:
  /// **'{points} pts'**
  String walletBalanceValue(String points);

  /// No description provided for @walletUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get walletUsed;

  /// No description provided for @walletHistoricalPoints.
  ///
  /// In en, this message translates to:
  /// **'{points} points come from earlier rewards before activity history was enabled.'**
  String walletHistoricalPoints(String points);

  /// No description provided for @walletEarn.
  ///
  /// In en, this message translates to:
  /// **'Earn'**
  String get walletEarn;

  /// No description provided for @walletEarnBody.
  ///
  /// In en, this message translates to:
  /// **'Earn points from partner initiatives and promotions.'**
  String get walletEarnBody;

  /// No description provided for @walletUseBody.
  ///
  /// In en, this message translates to:
  /// **'Use points in rewards, matchday activities, and fan-zone challenges.'**
  String get walletUseBody;

  /// No description provided for @walletRewardsBody.
  ///
  /// In en, this message translates to:
  /// **'Use points for matchday perks and partner rewards.'**
  String get walletRewardsBody;

  /// No description provided for @walletRewardsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Available rewards appear here when the club or partners publish them.'**
  String get walletRewardsEmptyBody;

  /// No description provided for @walletActivityEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Points activity appears after partner rewards or matchday actions.'**
  String get walletActivityEmptyBody;

  /// No description provided for @walletShowingSaved.
  ///
  /// In en, this message translates to:
  /// **'Showing saved points'**
  String get walletShowingSaved;

  /// No description provided for @walletShowingSavedBody.
  ///
  /// In en, this message translates to:
  /// **'Reconnect for the latest balance and activity. No action is queued offline.'**
  String get walletShowingSavedBody;

  /// No description provided for @walletRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing points'**
  String get walletRefreshing;

  /// No description provided for @walletRefreshingBody.
  ///
  /// In en, this message translates to:
  /// **'The confirmed balance stays visible while the latest ledger loads.'**
  String get walletRefreshingBody;

  /// No description provided for @walletChangedElsewhere.
  ///
  /// In en, this message translates to:
  /// **'Points changed elsewhere'**
  String get walletChangedElsewhere;

  /// No description provided for @walletChangedElsewhereBody.
  ///
  /// In en, this message translates to:
  /// **'The saved balance stays visible. Refresh to confirm the latest ledger.'**
  String get walletChangedElsewhereBody;

  /// No description provided for @walletRefreshTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Points refresh timed out'**
  String get walletRefreshTimedOut;

  /// No description provided for @walletRefreshTimedOutBody.
  ///
  /// In en, this message translates to:
  /// **'The saved balance is still shown. Try one bounded refresh.'**
  String get walletRefreshTimedOutBody;

  /// No description provided for @walletMayBeOutdated.
  ///
  /// In en, this message translates to:
  /// **'Points may be out of date'**
  String get walletMayBeOutdated;

  /// No description provided for @walletMayBeOutdatedBody.
  ///
  /// In en, this message translates to:
  /// **'The last confirmed balance stays visible while service is unavailable.'**
  String get walletMayBeOutdatedBody;

  /// No description provided for @walletSavedUntilRefresh.
  ///
  /// In en, this message translates to:
  /// **'The last confirmed balance stays visible until refresh succeeds.'**
  String get walletSavedUntilRefresh;

  /// No description provided for @feedChallengeTitle.
  ///
  /// In en, this message translates to:
  /// **'Challenge'**
  String get feedChallengeTitle;

  /// No description provided for @feedDescription.
  ///
  /// In en, this message translates to:
  /// **'Exact-score pools for real fixtures. Create one, join once, and settle automatically from the official final score.'**
  String get feedDescription;

  /// No description provided for @feedCreateNew.
  ///
  /// In en, this message translates to:
  /// **'Create a new challenge'**
  String get feedCreateNew;

  /// No description provided for @feedOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening challenges'**
  String get feedOpening;

  /// No description provided for @feedOpeningBody.
  ///
  /// In en, this message translates to:
  /// **'Checking current fixtures, pools, and your joined challenges.'**
  String get feedOpeningBody;

  /// No description provided for @feedRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing challenges'**
  String get feedRefreshing;

  /// No description provided for @feedRefreshingBody.
  ///
  /// In en, this message translates to:
  /// **'Keeping current fixtures, pools, and joined challenges visible.'**
  String get feedRefreshingBody;

  /// No description provided for @feedActionsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Challenge actions unavailable'**
  String get feedActionsUnavailable;

  /// No description provided for @feedActionsUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'You can review current pools, but creating and joining are disabled for this build.'**
  String get feedActionsUnavailableBody;

  /// No description provided for @feedShowingSaved.
  ///
  /// In en, this message translates to:
  /// **'Showing saved challenges'**
  String get feedShowingSaved;

  /// No description provided for @feedShowingSavedBody.
  ///
  /// In en, this message translates to:
  /// **'Reconnect before creating or joining a pool.'**
  String get feedShowingSavedBody;

  /// No description provided for @feedUpdatesPaused.
  ///
  /// In en, this message translates to:
  /// **'Live challenge updates paused'**
  String get feedUpdatesPaused;

  /// No description provided for @feedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No challenges available'**
  String get feedEmpty;

  /// No description provided for @feedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'New exact-score pools will appear when eligible fixtures open.'**
  String get feedEmptyBody;

  /// No description provided for @feedFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured / Popular Challenges'**
  String get feedFeatured;

  /// No description provided for @feedSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get feedSeeAll;

  /// No description provided for @feedOpenChallenges.
  ///
  /// In en, this message translates to:
  /// **'Open Challenges'**
  String get feedOpenChallenges;

  /// No description provided for @feedEndingSoon.
  ///
  /// In en, this message translates to:
  /// **'Ending Soon'**
  String get feedEndingSoon;

  /// No description provided for @feedEndingSoonAction.
  ///
  /// In en, this message translates to:
  /// **'Ending soon'**
  String get feedEndingSoonAction;

  /// No description provided for @feedMyChallenges.
  ///
  /// In en, this message translates to:
  /// **'My Challenges'**
  String get feedMyChallenges;

  /// No description provided for @feedSettledChallenges.
  ///
  /// In en, this message translates to:
  /// **'Settled Challenges'**
  String get feedSettledChallenges;

  /// No description provided for @feedResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get feedResults;

  /// No description provided for @feedNoFilterMatches.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches this filter'**
  String get feedNoFilterMatches;

  /// No description provided for @feedNoFilterMatchesBody.
  ///
  /// In en, this message translates to:
  /// **'Try another view or create a new pool.'**
  String get feedNoFilterMatchesBody;

  /// No description provided for @feedAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get feedAll;

  /// No description provided for @feedHighPool.
  ///
  /// In en, this message translates to:
  /// **'High Pool'**
  String get feedHighPool;

  /// No description provided for @feedMostParticipants.
  ///
  /// In en, this message translates to:
  /// **'Most Participants'**
  String get feedMostParticipants;

  /// No description provided for @feedMyJoined.
  ///
  /// In en, this message translates to:
  /// **'My Joined'**
  String get feedMyJoined;

  /// No description provided for @feedChallengesOffline.
  ///
  /// In en, this message translates to:
  /// **'Challenges unavailable offline'**
  String get feedChallengesOffline;

  /// No description provided for @feedChallengesOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to load current fixtures and challenge pools.'**
  String get feedChallengesOfflineBody;

  /// No description provided for @feedAccessUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Challenge access unavailable'**
  String get feedAccessUnavailable;

  /// No description provided for @feedAccessUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Your access does not currently allow these challenge pools.'**
  String get feedAccessUnavailableBody;

  /// No description provided for @feedDataChanged.
  ///
  /// In en, this message translates to:
  /// **'Challenge data changed'**
  String get feedDataChanged;

  /// No description provided for @feedDataChangedBody.
  ///
  /// In en, this message translates to:
  /// **'Refresh before reviewing or joining the latest pools.'**
  String get feedDataChangedBody;

  /// No description provided for @feedSecurityTimedOutBody.
  ///
  /// In en, this message translates to:
  /// **'No challenge action was completed. Refresh before trying again.'**
  String get feedSecurityTimedOutBody;

  /// No description provided for @feedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Challenge feed unavailable'**
  String get feedUnavailable;

  /// No description provided for @feedUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Current challenge pools could not be loaded safely.'**
  String get feedUnavailableBody;

  /// No description provided for @detailTitle.
  ///
  /// In en, this message translates to:
  /// **'Challenge detail'**
  String get detailTitle;

  /// No description provided for @detailOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening challenge'**
  String get detailOpening;

  /// No description provided for @detailOpeningBody.
  ///
  /// In en, this message translates to:
  /// **'Checking the current pool, entries, and official result status.'**
  String get detailOpeningBody;

  /// No description provided for @detailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Challenge not found'**
  String get detailNotFound;

  /// No description provided for @detailNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'This pool may have ended, been removed, or no longer be available to your club.'**
  String get detailNotFoundBody;

  /// No description provided for @detailBack.
  ///
  /// In en, this message translates to:
  /// **'Back to challenges'**
  String get detailBack;

  /// No description provided for @detailPendingBody.
  ///
  /// In en, this message translates to:
  /// **'Keeping the current pool and score choice visible while confirmation is pending.'**
  String get detailPendingBody;

  /// No description provided for @detailActionsUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'You can review this pool, but joining and cancellation are disabled for this build.'**
  String get detailActionsUnavailableBody;

  /// No description provided for @detailShowingSaved.
  ///
  /// In en, this message translates to:
  /// **'Showing saved challenge'**
  String get detailShowingSaved;

  /// No description provided for @detailShowingSavedBody.
  ///
  /// In en, this message translates to:
  /// **'Reconnect and refresh before joining, changing a score, or cancelling this pool.'**
  String get detailShowingSavedBody;

  /// No description provided for @detailRefreshUpper.
  ///
  /// In en, this message translates to:
  /// **'Refresh challenge'**
  String get detailRefreshUpper;

  /// No description provided for @detailMyPickUpper.
  ///
  /// In en, this message translates to:
  /// **'My pick'**
  String get detailMyPickUpper;

  /// No description provided for @detailMyEntry.
  ///
  /// In en, this message translates to:
  /// **'My entry'**
  String get detailMyEntry;

  /// No description provided for @detailJoinUpper.
  ///
  /// In en, this message translates to:
  /// **'Join this challenge'**
  String get detailJoinUpper;

  /// No description provided for @detailPickScoreBody.
  ///
  /// In en, this message translates to:
  /// **'Pick the exact score before the fixture locks.'**
  String get detailPickScoreBody;

  /// No description provided for @detailResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get detailResults;

  /// No description provided for @detailOfficialScore.
  ///
  /// In en, this message translates to:
  /// **'Official score'**
  String get detailOfficialScore;

  /// No description provided for @detailWinners.
  ///
  /// In en, this message translates to:
  /// **'Winners'**
  String get detailWinners;

  /// No description provided for @detailLosers.
  ///
  /// In en, this message translates to:
  /// **'Losers'**
  String get detailLosers;

  /// No description provided for @detailPointsPerWinner.
  ///
  /// In en, this message translates to:
  /// **'Points / winner'**
  String get detailPointsPerWinner;

  /// No description provided for @detailEntries.
  ///
  /// In en, this message translates to:
  /// **'Entries'**
  String get detailEntries;

  /// No description provided for @detailEntryCancelled.
  ///
  /// In en, this message translates to:
  /// **'Entry cancelled'**
  String get detailEntryCancelled;

  /// No description provided for @detailWaitingResult.
  ///
  /// In en, this message translates to:
  /// **'Waiting for official result review.'**
  String get detailWaitingResult;

  /// No description provided for @detailScoreSemantics.
  ///
  /// In en, this message translates to:
  /// **'{label} score {value}'**
  String detailScoreSemantics(String label, int value);

  /// No description provided for @detailAccessUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Challenge access unavailable'**
  String get detailAccessUnavailable;

  /// No description provided for @detailAccessUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Your current account cannot review or change this challenge.'**
  String get detailAccessUnavailableBody;

  /// No description provided for @detailDataChangedBody.
  ///
  /// In en, this message translates to:
  /// **'Refresh before reviewing entries or changing this challenge.'**
  String get detailDataChangedBody;

  /// No description provided for @detailSecurityTimedOutBody.
  ///
  /// In en, this message translates to:
  /// **'No challenge action was confirmed. Refresh before trying again.'**
  String get detailSecurityTimedOutBody;

  /// No description provided for @detailUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Challenge unavailable'**
  String get detailUnavailable;

  /// No description provided for @detailUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'The latest pool details could not be confirmed. Refresh to try again.'**
  String get detailUnavailableBody;

  /// No description provided for @detailJoinedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Challenge joined successfully.'**
  String get detailJoinedSuccess;

  /// No description provided for @detailCancelledSuccess.
  ///
  /// In en, this message translates to:
  /// **'Challenge cancelled.'**
  String get detailCancelledSuccess;

  /// No description provided for @detailJoining.
  ///
  /// In en, this message translates to:
  /// **'Joining challenge'**
  String get detailJoining;

  /// No description provided for @detailCancelling.
  ///
  /// In en, this message translates to:
  /// **'Cancelling challenge'**
  String get detailCancelling;

  /// No description provided for @detailRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing challenge'**
  String get detailRefreshing;

  /// No description provided for @detailJoiningUpper.
  ///
  /// In en, this message translates to:
  /// **'Joining challenge'**
  String get detailJoiningUpper;

  /// No description provided for @detailJoinWithPoints.
  ///
  /// In en, this message translates to:
  /// **'Join with {count} pts'**
  String detailJoinWithPoints(int count);

  /// No description provided for @detailCancellingUpper.
  ///
  /// In en, this message translates to:
  /// **'Cancelling challenge'**
  String get detailCancellingUpper;

  /// No description provided for @detailCancelUpper.
  ///
  /// In en, this message translates to:
  /// **'Cancel challenge'**
  String get detailCancelUpper;

  /// No description provided for @detailConnectionRestored.
  ///
  /// In en, this message translates to:
  /// **'Connection restored'**
  String get detailConnectionRestored;

  /// No description provided for @detailOffline.
  ///
  /// In en, this message translates to:
  /// **'Challenge details offline'**
  String get detailOffline;

  /// No description provided for @detailRefreshBeforeAction.
  ///
  /// In en, this message translates to:
  /// **'Refresh to check the current pool before joining or cancelling.'**
  String get detailRefreshBeforeAction;

  /// No description provided for @detailReconnectBeforeAction.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to check the current pool before joining or cancelling.'**
  String get detailReconnectBeforeAction;

  /// No description provided for @detailEntryActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get detailEntryActive;

  /// No description provided for @detailEntryWinner.
  ///
  /// In en, this message translates to:
  /// **'Winner'**
  String get detailEntryWinner;

  /// No description provided for @detailEntryLoser.
  ///
  /// In en, this message translates to:
  /// **'Loser'**
  String get detailEntryLoser;

  /// No description provided for @detailEntryRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get detailEntryRefunded;

  /// No description provided for @detailEntryCancelledStatus.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get detailEntryCancelledStatus;

  /// No description provided for @gameShareOptionsClosed.
  ///
  /// In en, this message translates to:
  /// **'Share options closed. Confirm the destination before publishing.'**
  String get gameShareOptionsClosed;

  /// No description provided for @gameShareActionsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Share actions unavailable'**
  String get gameShareActionsUnavailable;

  /// No description provided for @gameShareActionsUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'You can return to Fan Zone, but sharing is disabled for this build.'**
  String get gameShareActionsUnavailableDescription;

  /// No description provided for @gameBackToFanZoneUpper.
  ///
  /// In en, this message translates to:
  /// **'Back to fan zone'**
  String get gameBackToFanZoneUpper;

  /// No description provided for @gamePredictionAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Prediction access denied'**
  String get gamePredictionAccessDenied;

  /// No description provided for @gamePredictionAccessDeniedDescription.
  ///
  /// In en, this message translates to:
  /// **'This account cannot open prediction history for sharing.'**
  String get gamePredictionAccessDeniedDescription;

  /// No description provided for @gameMakePickFirst.
  ///
  /// In en, this message translates to:
  /// **'Make a pick first'**
  String get gameMakePickFirst;

  /// No description provided for @gameShareCardsUnlock.
  ///
  /// In en, this message translates to:
  /// **'Share cards unlock after a matchday pick.'**
  String get gameShareCardsUnlock;

  /// No description provided for @gameBackToPicksUpper.
  ///
  /// In en, this message translates to:
  /// **'Back to picks'**
  String get gameBackToPicksUpper;

  /// No description provided for @gameShareCardsOffline.
  ///
  /// In en, this message translates to:
  /// **'Share cards offline'**
  String get gameShareCardsOffline;

  /// No description provided for @gameShareCardsOfflineDescription.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to load your confirmed prediction history. Nothing is queued offline.'**
  String get gameShareCardsOfflineDescription;

  /// No description provided for @gameHistoryCheckTimedOut.
  ///
  /// In en, this message translates to:
  /// **'History check timed out'**
  String get gameHistoryCheckTimedOut;

  /// No description provided for @gameHistoryCheckTimedOutDescription.
  ///
  /// In en, this message translates to:
  /// **'The app could not confirm a safe prediction history in time. Try one bounded refresh.'**
  String get gameHistoryCheckTimedOutDescription;

  /// No description provided for @gameTryAgainUpper.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get gameTryAgainUpper;

  /// No description provided for @gameShareCardsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Share cards unavailable'**
  String get gameShareCardsUnavailable;

  /// No description provided for @gameShareCardsUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'Prediction history could not be loaded. No private activity details were shown.'**
  String get gameShareCardsUnavailableDescription;

  /// No description provided for @gameShowingSavedShareCard.
  ///
  /// In en, this message translates to:
  /// **'Showing saved share card'**
  String get gameShowingSavedShareCard;

  /// No description provided for @gameShowingSavedShareCardDescription.
  ///
  /// In en, this message translates to:
  /// **'Reconnect before sharing or copying. No action is queued offline.'**
  String get gameShowingSavedShareCardDescription;

  /// No description provided for @gameCopyingShareText.
  ///
  /// In en, this message translates to:
  /// **'Copying share text'**
  String get gameCopyingShareText;

  /// No description provided for @gameOpeningShareOptions.
  ///
  /// In en, this message translates to:
  /// **'Opening share options'**
  String get gameOpeningShareOptions;

  /// No description provided for @gameShareAwaitPlatformConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Wait for the platform confirmation. Do not repeat this action.'**
  String get gameShareAwaitPlatformConfirmation;

  /// No description provided for @gameShareActionPaused.
  ///
  /// In en, this message translates to:
  /// **'Share action paused'**
  String get gameShareActionPaused;

  /// No description provided for @gameShareActionPausedDescription.
  ///
  /// In en, this message translates to:
  /// **'Another action was already active. Check the current platform view before continuing.'**
  String get gameShareActionPausedDescription;

  /// No description provided for @gameShareConfirmationUncertain.
  ///
  /// In en, this message translates to:
  /// **'Share confirmation uncertain'**
  String get gameShareConfirmationUncertain;

  /// No description provided for @gameShareConfirmationUncertainDescription.
  ///
  /// In en, this message translates to:
  /// **'Check the share sheet or clipboard, then dismiss this warning before trying again.'**
  String get gameShareConfirmationUncertainDescription;

  /// No description provided for @gameShareActionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Share action unavailable'**
  String get gameShareActionUnavailable;

  /// No description provided for @gameShareActionUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'The platform did not complete the action. Dismiss this warning before retrying.'**
  String get gameShareActionUnavailableDescription;

  /// No description provided for @gameUsingSavedPredictionHistory.
  ///
  /// In en, this message translates to:
  /// **'Using saved prediction history'**
  String get gameUsingSavedPredictionHistory;

  /// No description provided for @gameUsingSavedPredictionHistoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Refresh the route before opening another platform share action.'**
  String get gameUsingSavedPredictionHistoryDescription;

  /// No description provided for @gameBackToPicks.
  ///
  /// In en, this message translates to:
  /// **'Back to picks'**
  String get gameBackToPicks;

  /// No description provided for @gameChoosePick.
  ///
  /// In en, this message translates to:
  /// **'Choose pick'**
  String get gameChoosePick;

  /// No description provided for @gameSharePredictionSemantics.
  ///
  /// In en, this message translates to:
  /// **'{home} versus {away}, {market}, {outcome}'**
  String gameSharePredictionSemantics(
    String home,
    String away,
    String market,
    String outcome,
  );

  /// No description provided for @gameShareMarketSelection.
  ///
  /// In en, this message translates to:
  /// **'{market} · {selection}'**
  String gameShareMarketSelection(String market, String selection);

  /// No description provided for @gameCurrentlySelectedShareCard.
  ///
  /// In en, this message translates to:
  /// **'Currently selected share card'**
  String get gameCurrentlySelectedShareCard;

  /// No description provided for @gameSelectThisShareCard.
  ///
  /// In en, this message translates to:
  /// **'Select this share card'**
  String get gameSelectThisShareCard;

  /// No description provided for @gamePredictionPickCancelled.
  ///
  /// In en, this message translates to:
  /// **'Pick cancelled.'**
  String get gamePredictionPickCancelled;

  /// No description provided for @gamePredictionSummaryCopied.
  ///
  /// In en, this message translates to:
  /// **'Activity summary copied to clipboard.'**
  String get gamePredictionSummaryCopied;

  /// No description provided for @gamePredictionScorePending.
  ///
  /// In en, this message translates to:
  /// **'pending'**
  String get gamePredictionScorePending;

  /// No description provided for @gamePredictionSummaryClipboard.
  ///
  /// In en, this message translates to:
  /// **'{home} vs {away} · {market} · {outcome} · {score}'**
  String gamePredictionSummaryClipboard(
    String home,
    String away,
    String market,
    String outcome,
    String score,
  );

  /// No description provided for @gamePredictionStatusWon.
  ///
  /// In en, this message translates to:
  /// **'Won'**
  String get gamePredictionStatusWon;

  /// No description provided for @gamePredictionStatusLost.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get gamePredictionStatusLost;

  /// No description provided for @gamePredictionStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get gamePredictionStatusCancelled;

  /// No description provided for @gamePredictionStatusVoid.
  ///
  /// In en, this message translates to:
  /// **'Void'**
  String get gamePredictionStatusVoid;

  /// No description provided for @gamePredictionStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get gamePredictionStatusPending;

  /// No description provided for @gamePredictionDateTbd.
  ///
  /// In en, this message translates to:
  /// **'Tbd'**
  String get gamePredictionDateTbd;

  /// No description provided for @gamePredictionDateTime.
  ///
  /// In en, this message translates to:
  /// **'{date} • {time}'**
  String gamePredictionDateTime(String date, String time);

  /// No description provided for @gamePredictionWonSettlement.
  ///
  /// In en, this message translates to:
  /// **'This pick settled successfully and credited {count} points.'**
  String gamePredictionWonSettlement(int count);

  /// No description provided for @gamePredictionLostSettlement.
  ///
  /// In en, this message translates to:
  /// **'This pick did not settle in your favour.'**
  String get gamePredictionLostSettlement;

  /// No description provided for @gamePredictionOfficialOutcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Official outcome: {outcome}.'**
  String gamePredictionOfficialOutcomeMessage(String outcome);

  /// No description provided for @gamePredictionCancelledSettlement.
  ///
  /// In en, this message translates to:
  /// **'This pick was cancelled before the fixture locked.'**
  String get gamePredictionCancelledSettlement;

  /// No description provided for @gamePredictionVoidSettlement.
  ///
  /// In en, this message translates to:
  /// **'This pick was voided and no points were awarded.'**
  String get gamePredictionVoidSettlement;

  /// No description provided for @gamePredictionPendingSettlement.
  ///
  /// In en, this message translates to:
  /// **'This pick is locked and will settle when official results arrive.'**
  String get gamePredictionPendingSettlement;

  /// No description provided for @gamePredictionActivityNotFound.
  ///
  /// In en, this message translates to:
  /// **'Activity not found'**
  String get gamePredictionActivityNotFound;

  /// No description provided for @gamePredictionActivityNotFoundDescription.
  ///
  /// In en, this message translates to:
  /// **'This pick may have ended, been removed, or no longer be available to your account.'**
  String get gamePredictionActivityNotFoundDescription;

  /// No description provided for @gamePredictionBackToPredictions.
  ///
  /// In en, this message translates to:
  /// **'Back to predictions'**
  String get gamePredictionBackToPredictions;

  /// No description provided for @gamePredictionCancellingPick.
  ///
  /// In en, this message translates to:
  /// **'Cancelling pick'**
  String get gamePredictionCancellingPick;

  /// No description provided for @gamePredictionRefreshingActivity.
  ///
  /// In en, this message translates to:
  /// **'Refreshing activity'**
  String get gamePredictionRefreshingActivity;

  /// No description provided for @gamePredictionConfirmedPickVisible.
  ///
  /// In en, this message translates to:
  /// **'Keeping the confirmed pick visible while the latest status is checked.'**
  String get gamePredictionConfirmedPickVisible;

  /// No description provided for @gamePredictionActionsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Activity actions unavailable'**
  String get gamePredictionActionsUnavailable;

  /// No description provided for @gamePredictionCancellationDisabled.
  ///
  /// In en, this message translates to:
  /// **'You can review this pick, but cancellation is disabled for this build.'**
  String get gamePredictionCancellationDisabled;

  /// No description provided for @gamePredictionShowingSavedActivity.
  ///
  /// In en, this message translates to:
  /// **'Showing saved activity'**
  String get gamePredictionShowingSavedActivity;

  /// No description provided for @gamePredictionReconnectBeforeCancelling.
  ///
  /// In en, this message translates to:
  /// **'Reconnect and refresh before cancelling this pick.'**
  String get gamePredictionReconnectBeforeCancelling;

  /// No description provided for @gamePredictionActivityDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity detail'**
  String get gamePredictionActivityDetailTitle;

  /// No description provided for @gamePredictionShortTeams.
  ///
  /// In en, this message translates to:
  /// **'{home}  •  {away}'**
  String gamePredictionShortTeams(String home, String away);

  /// No description provided for @gamePredictionVenueTbc.
  ///
  /// In en, this message translates to:
  /// **'Venue tbc'**
  String get gamePredictionVenueTbc;

  /// No description provided for @gamePredictionPickType.
  ///
  /// In en, this message translates to:
  /// **'Pick type'**
  String get gamePredictionPickType;

  /// No description provided for @gamePredictionSelection.
  ///
  /// In en, this message translates to:
  /// **'Selection'**
  String get gamePredictionSelection;

  /// No description provided for @gamePredictionEarned.
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get gamePredictionEarned;

  /// No description provided for @gamePredictionPotential.
  ///
  /// In en, this message translates to:
  /// **'Potential'**
  String get gamePredictionPotential;

  /// No description provided for @gamePredictionPositiveValue.
  ///
  /// In en, this message translates to:
  /// **'+{count}'**
  String gamePredictionPositiveValue(int count);

  /// No description provided for @gamePredictionSettlement.
  ///
  /// In en, this message translates to:
  /// **'Settlement'**
  String get gamePredictionSettlement;

  /// No description provided for @gamePredictionPlaced.
  ///
  /// In en, this message translates to:
  /// **'Placed'**
  String get gamePredictionPlaced;

  /// No description provided for @gamePredictionKickoff.
  ///
  /// In en, this message translates to:
  /// **'Kickoff'**
  String get gamePredictionKickoff;

  /// No description provided for @gamePredictionSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get gamePredictionSettled;

  /// No description provided for @gamePredictionOfficialOutcome.
  ///
  /// In en, this message translates to:
  /// **'Official outcome'**
  String get gamePredictionOfficialOutcome;

  /// No description provided for @gamePredictionCancelPick.
  ///
  /// In en, this message translates to:
  /// **'Cancel pick'**
  String get gamePredictionCancelPick;

  /// No description provided for @gamePredictionCopyResult.
  ///
  /// In en, this message translates to:
  /// **'Copy result'**
  String get gamePredictionCopyResult;

  /// No description provided for @gamePredictionCopySummary.
  ///
  /// In en, this message translates to:
  /// **'Copy summary'**
  String get gamePredictionCopySummary;

  /// No description provided for @gamePredictionShareCard.
  ///
  /// In en, this message translates to:
  /// **'Share card'**
  String get gamePredictionShareCard;

  /// No description provided for @gamePredictionBrowseFixtures.
  ///
  /// In en, this message translates to:
  /// **'Browse fixtures'**
  String get gamePredictionBrowseFixtures;

  /// No description provided for @gamePredictionRefreshActivity.
  ///
  /// In en, this message translates to:
  /// **'Refresh activity'**
  String get gamePredictionRefreshActivity;

  /// No description provided for @gamePredictionConnectionRestored.
  ///
  /// In en, this message translates to:
  /// **'Connection restored'**
  String get gamePredictionConnectionRestored;

  /// No description provided for @gamePredictionDetailsOffline.
  ///
  /// In en, this message translates to:
  /// **'Activity details offline'**
  String get gamePredictionDetailsOffline;

  /// No description provided for @gamePredictionRefreshBeforeCancelling.
  ///
  /// In en, this message translates to:
  /// **'Refresh to confirm the current pick before cancelling it.'**
  String get gamePredictionRefreshBeforeCancelling;

  /// No description provided for @gamePredictionReconnectToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to confirm the current pick before cancelling it.'**
  String get gamePredictionReconnectToConfirm;

  /// No description provided for @gamePredictionAccessUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Activity access unavailable'**
  String get gamePredictionAccessUnavailable;

  /// No description provided for @gamePredictionAccessUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'Your current account cannot review or change this activity.'**
  String get gamePredictionAccessUnavailableDescription;

  /// No description provided for @gamePredictionDataChanged.
  ///
  /// In en, this message translates to:
  /// **'Activity data changed'**
  String get gamePredictionDataChanged;

  /// No description provided for @gamePredictionDataChangedDescription.
  ///
  /// In en, this message translates to:
  /// **'Refresh before reviewing the result or cancelling this pick.'**
  String get gamePredictionDataChangedDescription;

  /// No description provided for @gamePredictionSecurityTimeout.
  ///
  /// In en, this message translates to:
  /// **'Activity security check timed out'**
  String get gamePredictionSecurityTimeout;

  /// No description provided for @gamePredictionSecurityTimeoutDescription.
  ///
  /// In en, this message translates to:
  /// **'No cancellation was confirmed. Refresh before trying again.'**
  String get gamePredictionSecurityTimeoutDescription;

  /// No description provided for @gamePredictionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Activity unavailable'**
  String get gamePredictionUnavailable;

  /// No description provided for @gamePredictionUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'The latest pick details could not be confirmed. Refresh to try again.'**
  String get gamePredictionUnavailableDescription;

  /// No description provided for @gamePredictionSelectedMetricSemantics.
  ///
  /// In en, this message translates to:
  /// **'Selected {label} {value}'**
  String gamePredictionSelectedMetricSemantics(String label, String value);

  /// No description provided for @gamePredictionMetricSemantics.
  ///
  /// In en, this message translates to:
  /// **'{label} {value}'**
  String gamePredictionMetricSemantics(String label, String value);

  /// No description provided for @gameMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get gameMatchTitle;

  /// No description provided for @gameBackToFanZoneTitleCase.
  ///
  /// In en, this message translates to:
  /// **'Back to Fan Zone'**
  String get gameBackToFanZoneTitleCase;

  /// No description provided for @gameMatchNotFound.
  ///
  /// In en, this message translates to:
  /// **'Match not found'**
  String get gameMatchNotFound;

  /// No description provided for @gameMatchNotFoundDescription.
  ///
  /// In en, this message translates to:
  /// **'This fixture may have ended, been removed, or no longer be available.'**
  String get gameMatchNotFoundDescription;

  /// No description provided for @gameWeekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get gameWeekdayMon;

  /// No description provided for @gameWeekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get gameWeekdayTue;

  /// No description provided for @gameWeekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get gameWeekdayWed;

  /// No description provided for @gameWeekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get gameWeekdayThu;

  /// No description provided for @gameWeekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get gameWeekdayFri;

  /// No description provided for @gameWeekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get gameWeekdaySat;

  /// No description provided for @gameWeekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get gameWeekdaySun;

  /// No description provided for @gameMonthJan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get gameMonthJan;

  /// No description provided for @gameMonthFeb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get gameMonthFeb;

  /// No description provided for @gameMonthMar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get gameMonthMar;

  /// No description provided for @gameMonthApr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get gameMonthApr;

  /// No description provided for @gameMonthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get gameMonthMay;

  /// No description provided for @gameMonthJun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get gameMonthJun;

  /// No description provided for @gameMonthJul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get gameMonthJul;

  /// No description provided for @gameMonthAug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get gameMonthAug;

  /// No description provided for @gameMonthSep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get gameMonthSep;

  /// No description provided for @gameMonthOct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get gameMonthOct;

  /// No description provided for @gameMonthNov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get gameMonthNov;

  /// No description provided for @gameMonthDec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get gameMonthDec;

  /// No description provided for @gameMatchKickoffDateTime.
  ///
  /// In en, this message translates to:
  /// **'{weekday} {day} {month} · {time}'**
  String gameMatchKickoffDateTime(
    String weekday,
    int day,
    String month,
    String time,
  );

  /// No description provided for @gamePoolsTab.
  ///
  /// In en, this message translates to:
  /// **'Pools'**
  String get gamePoolsTab;

  /// No description provided for @gameStatsTab.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get gameStatsTab;

  /// No description provided for @gameH2hTab.
  ///
  /// In en, this message translates to:
  /// **'H2h'**
  String get gameH2hTab;

  /// No description provided for @gameLineupsTab.
  ///
  /// In en, this message translates to:
  /// **'Lineups'**
  String get gameLineupsTab;

  /// No description provided for @gameMatchTeamsVs.
  ///
  /// In en, this message translates to:
  /// **'{home} vs {away}'**
  String gameMatchTeamsVs(String home, String away);

  /// No description provided for @gamePartnerPoolsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Partner pools'**
  String get gamePartnerPoolsTooltip;

  /// No description provided for @gameJoiningPartnerPool.
  ///
  /// In en, this message translates to:
  /// **'Joining partner pool'**
  String get gameJoiningPartnerPool;

  /// No description provided for @gameRefreshingMatch.
  ///
  /// In en, this message translates to:
  /// **'Refreshing match'**
  String get gameRefreshingMatch;

  /// No description provided for @gameConfirmedMatchVisible.
  ///
  /// In en, this message translates to:
  /// **'Keeping the confirmed match visible while the latest state is checked.'**
  String get gameConfirmedMatchVisible;

  /// No description provided for @gameMatchActionsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Match actions unavailable'**
  String get gameMatchActionsUnavailable;

  /// No description provided for @gameMatchActionsUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'You can review this match, but joining partner pools is disabled for this build.'**
  String get gameMatchActionsUnavailableDescription;

  /// No description provided for @gameShowingSavedMatch.
  ///
  /// In en, this message translates to:
  /// **'Showing saved match'**
  String get gameShowingSavedMatch;

  /// No description provided for @gameReconnectBeforePartnerPool.
  ///
  /// In en, this message translates to:
  /// **'Reconnect and refresh before joining a partner pool.'**
  String get gameReconnectBeforePartnerPool;

  /// No description provided for @gameVsUpper.
  ///
  /// In en, this message translates to:
  /// **'VS'**
  String get gameVsUpper;

  /// No description provided for @gamePartnerOutcomeHomeWin.
  ///
  /// In en, this message translates to:
  /// **'Home win'**
  String get gamePartnerOutcomeHomeWin;

  /// No description provided for @gamePartnerOutcomeDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get gamePartnerOutcomeDraw;

  /// No description provided for @gamePartnerOutcomeAwayWin.
  ///
  /// In en, this message translates to:
  /// **'Away win'**
  String get gamePartnerOutcomeAwayWin;

  /// No description provided for @gamePartnerOutcomeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get gamePartnerOutcomeUnknown;

  /// No description provided for @gamePartnerEarnRequired.
  ///
  /// In en, this message translates to:
  /// **'Partner earn required'**
  String get gamePartnerEarnRequired;

  /// No description provided for @gamePromotionEarnRequired.
  ///
  /// In en, this message translates to:
  /// **'Promotion earn required'**
  String get gamePromotionEarnRequired;

  /// No description provided for @gameOpenToAllFans.
  ///
  /// In en, this message translates to:
  /// **'Open to all fans'**
  String get gameOpenToAllFans;

  /// No description provided for @gamePoolJoinOffline.
  ///
  /// In en, this message translates to:
  /// **'Reconnect and refresh before joining this pool.'**
  String get gamePoolJoinOffline;

  /// No description provided for @gamePoolJoinPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Your account cannot join this partner pool.'**
  String get gamePoolJoinPermissionDenied;

  /// No description provided for @gamePoolJoinConflict.
  ///
  /// In en, this message translates to:
  /// **'This pool changed or locked. Refresh before trying again.'**
  String get gamePoolJoinConflict;

  /// No description provided for @gamePoolJoinTimeout.
  ///
  /// In en, this message translates to:
  /// **'No entry was confirmed. Refresh before trying again.'**
  String get gamePoolJoinTimeout;

  /// No description provided for @gamePoolJoinUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Pool entry could not be confirmed.'**
  String get gamePoolJoinUnavailable;

  /// No description provided for @gameRefreshMatch.
  ///
  /// In en, this message translates to:
  /// **'Refresh match'**
  String get gameRefreshMatch;

  /// No description provided for @gameMatchConnectionRestored.
  ///
  /// In en, this message translates to:
  /// **'Connection restored'**
  String get gameMatchConnectionRestored;

  /// No description provided for @gameMatchDetailsOffline.
  ///
  /// In en, this message translates to:
  /// **'Match details offline'**
  String get gameMatchDetailsOffline;

  /// No description provided for @gameRefreshBeforeJoiningPool.
  ///
  /// In en, this message translates to:
  /// **'Refresh to confirm the current match before joining a pool.'**
  String get gameRefreshBeforeJoiningPool;

  /// No description provided for @gameReconnectBeforeJoiningPool.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to confirm the current match before joining a pool.'**
  String get gameReconnectBeforeJoiningPool;

  /// No description provided for @gameMatchAccessUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Match access unavailable'**
  String get gameMatchAccessUnavailable;

  /// No description provided for @gameMatchAccessUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'Your current account cannot review this match.'**
  String get gameMatchAccessUnavailableDescription;

  /// No description provided for @gameMatchDataChanged.
  ///
  /// In en, this message translates to:
  /// **'Match data changed'**
  String get gameMatchDataChanged;

  /// No description provided for @gameMatchDataChangedDescription.
  ///
  /// In en, this message translates to:
  /// **'Refresh before joining a pool or reviewing current status.'**
  String get gameMatchDataChangedDescription;

  /// No description provided for @gameMatchSecurityTimeout.
  ///
  /// In en, this message translates to:
  /// **'Match security check timed out'**
  String get gameMatchSecurityTimeout;

  /// No description provided for @gameMatchSecurityTimeoutDescription.
  ///
  /// In en, this message translates to:
  /// **'No pool entry was confirmed. Refresh before trying again.'**
  String get gameMatchSecurityTimeoutDescription;

  /// No description provided for @gameMatchUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Match unavailable'**
  String get gameMatchUnavailable;

  /// No description provided for @gameMatchUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'The latest match details could not be confirmed. Refresh to try again.'**
  String get gameMatchUnavailableDescription;

  /// No description provided for @gamePartnerWdwPools.
  ///
  /// In en, this message translates to:
  /// **'Partner WDW Pools'**
  String get gamePartnerWdwPools;

  /// No description provided for @gameNoPartnerPool.
  ///
  /// In en, this message translates to:
  /// **'No partner pool for this match'**
  String get gameNoPartnerPool;

  /// No description provided for @gameNoPartnerPoolDescription.
  ///
  /// In en, this message translates to:
  /// **'Football predictions open only when a partner creates a fixed-entry WDW pool for this fixture.'**
  String get gameNoPartnerPoolDescription;

  /// No description provided for @gameViewFanZone.
  ///
  /// In en, this message translates to:
  /// **'View Fan Zone'**
  String get gameViewFanZone;

  /// No description provided for @gamePartnerPoolsOnly.
  ///
  /// In en, this message translates to:
  /// **'{home} vs {away} uses partner-funded WDW pools only.'**
  String gamePartnerPoolsOnly(String home, String away);

  /// No description provided for @settingsThemePreview.
  ///
  /// In en, this message translates to:
  /// **'Theme preview'**
  String get settingsThemePreview;

  /// No description provided for @settingsApplyTheme.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get settingsApplyTheme;
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
