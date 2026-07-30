// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'afri_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AfriLocalizationsEn extends AfriLocalizations {
  AfriLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AfriClub';

  @override
  String get genericError => 'Something went wrong. Try again.';

  @override
  String get retry => 'Retry';

  @override
  String get connectionRequired => 'Connection required';

  @override
  String get onboardingBelongTitle => 'Your club.\nYour matchday.';

  @override
  String onboardingBelongBody(String clubName) {
    return 'Follow $clubName wherever the blue family gathers.';
  }

  @override
  String get onboardingKnowTitle => 'Every moment.\nOne blue family.';

  @override
  String onboardingKnowBody(String appName) {
    return 'Get official $appName news, fixtures, tickets, and membership.';
  }

  @override
  String get onboardingLiveTitle => 'Closer to\nGikundiro.';

  @override
  String get onboardingLiveBody =>
      'Meet the squad and carry your club with you every day.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get onboardingContinueWhatsApp => 'Continue with WhatsApp';

  @override
  String get onboardingContinueWithoutSignIn => 'Continue without sign-in';

  @override
  String onboardingWelcomeImage(int current, int total) {
    return 'Welcome image $current of $total';
  }

  @override
  String get supportUnavailable => 'Support is unavailable in this build.';

  @override
  String get fanZoneLoading =>
      'Picks, league, points, fans, and rewards are loading.';

  @override
  String get fanZoneJoinSession =>
      'Join a live session and use this phone to play.';

  @override
  String get fanZoneVenueCode => 'Enter the venue code after you arrive.';

  @override
  String get fanZoneRoundsEmpty =>
      'Matchday rounds will appear when they open.';

  @override
  String get fanZoneRankingsEmpty =>
      'Rankings will appear after updates resume.';

  @override
  String get fanZoneClubsMoved =>
      'Fan clubs and chapters are under Supporters.';

  @override
  String get fanZoneRegistryMoved =>
      'The supporter list is under Fan Zone Supporters.';

  @override
  String get fanZoneContributionMode => 'Choose how to contribute.';

  @override
  String get fanZoneRewardsSummary => 'Badges, streaks, and rewards.';

  @override
  String get fanZoneLineupsEmpty => 'Lineups will appear before kickoff.';

  @override
  String get fanZoneStatsEmpty => 'Stats will appear when the match starts.';

  @override
  String get fanIdVerifyPrompt =>
      'Verify your Fan ID to make picks and earn points.';

  @override
  String get fanIdPrivacyTrust =>
      'Verification uses your Fan ID. No personal details are shared.';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Fans, fixtures, tickets, shop, wallet, help';

  @override
  String get searchClearTooltip => 'Clear search';

  @override
  String get searchCategoryAll => 'All';

  @override
  String get searchCategorySupporters => 'Supporters';

  @override
  String get searchCategoryFixtures => 'Fixtures';

  @override
  String get searchCategoryCommerce => 'Tickets & shop';

  @override
  String get searchCategoryServices => 'Services';

  @override
  String get searchKeepTypingTitle => 'Keep typing';

  @override
  String get searchKeepTypingMessage =>
      'Enter at least two characters before search can start.';

  @override
  String get searchUpdatingTitle => 'Updating results';

  @override
  String get searchSearchingTitle => 'Searching';

  @override
  String get searchUpdatingMessage =>
      'Refreshing sections and public supporter content.';

  @override
  String get searchSearchingMessage =>
      'Searching sections and supporter content.';

  @override
  String get searchPermissionTitle => 'Search not permitted';

  @override
  String get searchPermissionMessage =>
      'Live search is off for this account. Your query and app sections remain. Contact club support.';

  @override
  String get searchConflictTitle => 'Search changed';

  @override
  String get searchConflictMessage =>
      'Available content changed during this search. Review the current query and try again.';

  @override
  String get searchTimeoutTitle => 'Search timed out';

  @override
  String get searchTimeoutMessage =>
      'The search window expired. Your query is still here. Try again when ready.';

  @override
  String get searchUnavailableTitle => 'Search is unavailable';

  @override
  String get searchUnavailableMessage =>
      'Try again. Your query has not been sent elsewhere.';

  @override
  String get searchStartTitle => 'Find what you need';

  @override
  String get searchStartMessage =>
      'Enter at least two characters. Search covers app sections and public supporter content.';

  @override
  String get searchRecentTitle => 'Recent searches';

  @override
  String get searchClear => 'Clear';

  @override
  String searchForTooltip(String query) {
    return 'Search for $query';
  }

  @override
  String get searchNoResultsTitle => 'No results';

  @override
  String searchNoResultsMessage(String query) {
    return 'No result matches “$query”.';
  }

  @override
  String get searchShowAllCategories => 'Show all categories';

  @override
  String get searchOfflineTitle => 'Offline results';

  @override
  String get searchOfflineMessage =>
      'Showing results stored on this device. Live content may be out of date.';

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
      zero: 'No results',
    );
    return '$_temp0';
  }

  @override
  String get searchSupporterDirectoryTitle => 'Find supporters';

  @override
  String get searchSupporterDirectoryDescription =>
      'Search public supporter aliases and manage friends.';

  @override
  String get searchFanZoneTitle => 'Fan Zone';

  @override
  String get searchFanZoneDescription =>
      'Predictions, community, rewards, and matchday activity.';

  @override
  String get searchFanRegistryTitle => 'Fan registry';

  @override
  String get searchFanRegistryDescription =>
      'Browse the club supporter registry.';

  @override
  String get searchFixturesTitle => 'Fixtures';

  @override
  String get searchFixturesDescription =>
      'Upcoming and recent Rayon Sports matches.';

  @override
  String get searchLiveMatchTitle => 'Live match';

  @override
  String get searchLiveMatchDescription =>
      'Open the current match centre when live coverage exists.';

  @override
  String get searchStandingsTitle => 'League standings';

  @override
  String get searchStandingsDescription =>
      'View the current table and competition position.';

  @override
  String get searchTicketsTitle => 'Match tickets';

  @override
  String get searchTicketsDescription =>
      'Find available tickets and continue to checkout.';

  @override
  String get searchMyTicketsTitle => 'My tickets';

  @override
  String get searchMyTicketsDescription =>
      'Open purchased tickets and match entry details.';

  @override
  String get searchShopTitle => 'Club shop';

  @override
  String get searchShopDescription => 'Browse official club products.';

  @override
  String get searchCartTitle => 'Shopping cart';

  @override
  String get searchCartDescription => 'Review products before checkout.';

  @override
  String get searchWalletTitle => 'FET wallet';

  @override
  String get searchWalletDescription =>
      'View token balance, history, transfer, and redemption.';

  @override
  String get searchMembershipTitle => 'Membership';

  @override
  String get searchMembershipDescription =>
      'View membership status and club benefits.';

  @override
  String get searchContributionsTitle => 'Support the club';

  @override
  String get searchContributionsDescription =>
      'Open contributions and supporter projects.';

  @override
  String get searchNotificationsTitle => 'Notifications';

  @override
  String get searchNotificationsDescription =>
      'Review and update notification preferences.';

  @override
  String get searchPrivacyTitle => 'Privacy settings';

  @override
  String get searchPrivacyDescription => 'Review consent and privacy controls.';

  @override
  String get searchHelpTitle => 'Help and support';

  @override
  String get searchHelpDescription => 'Open support options from Settings.';

  @override
  String get searchPublicSupporterDescription =>
      'Public supporter profile in the club registry.';

  @override
  String searchMatchTitle(String home, String away) {
    return '$home vs $away';
  }

  @override
  String searchFixtureOnSaleDescription(String competition) {
    return '$competition fixture with ticket sales available.';
  }

  @override
  String searchFixtureDescription(String competition) {
    return '$competition fixture.';
  }

  @override
  String searchProductDescription(String category) {
    return 'Official club shop item in $category.';
  }

  @override
  String get searchHomeTeamFallback => 'Home';

  @override
  String get searchAwayTeamFallback => 'Away';

  @override
  String get searchClubFixtureFallback => 'Club fixture';

  @override
  String get searchClubProductFallback => 'Club product';

  @override
  String get searchMerchandiseFallback => 'Merchandise';

  @override
  String get tvPairingUnavailable =>
      'Pairing unavailable. Check the connection and retry.';

  @override
  String get tvConfigurationMissing =>
      'Setup is incomplete. Contact the deployment owner.';

  @override
  String get tvCredentialRevoked =>
      'This device was revoked. Create a new pairing code.';

  @override
  String get tvEnterAdminCode => 'Enter the code from the admin device list.';

  @override
  String get tvJoinFromFanZone => 'Use this code to join from Fan Zone.';

  @override
  String get tvConnectionLostRetry => 'Connection lost — retry';

  @override
  String tvAppTitle(String appName) {
    return '$appName TV';
  }

  @override
  String tvBrandMarkSemantic(String clubName) {
    return '$clubName TV brand mark';
  }

  @override
  String get tvPairThisDisplay => 'Pair this TV';

  @override
  String get tvPairingCodeLabel => 'One-time pairing code';

  @override
  String get tvPairingCodeHelper => '6–12 characters';

  @override
  String get tvPairingInProgress => 'Pairing…';

  @override
  String get tvPairDisplayAction => 'Pair display';

  @override
  String get tvSessionCodeInstruction => 'Enter this code in Fan Zone';

  @override
  String tvSessionCodeSemantic(String code) {
    return 'TV session code $code';
  }

  @override
  String tvFetRewardLabel(int reward) {
    return '$reward FET reward';
  }

  @override
  String tvExpiresLabel(String expiry) {
    return 'Expires $expiry';
  }

  @override
  String get tvExpired => 'expired';

  @override
  String get tvExpiresLessThanOneMinute => 'in less than 1 min';

  @override
  String tvExpiresMinutes(int minutes) {
    return 'in $minutes min';
  }

  @override
  String tvExpiresHoursMinutes(int hours, int minutes) {
    return 'in ${hours}h ${minutes}m';
  }

  @override
  String get tvVenueSessionDetails => 'Venue session details';

  @override
  String get tvVenueSessionOnly => 'Venue session only';

  @override
  String get tvNoSupporterDetails => 'No supporter details shown';

  @override
  String get tvPairingStatusAndExpiry => 'Pairing status and expiry';

  @override
  String get tvDefaultPairingPrompt =>
      'Pair this TV display from the admin panel.';

  @override
  String get tvOfflinePhase => 'Offline';

  @override
  String get membershipTitle => 'Membership';

  @override
  String get membershipSavedDetails => 'Saved membership details';

  @override
  String get membershipDigitalCard => 'Digital card';

  @override
  String get share => 'Share';

  @override
  String get membershipReviewTitle => 'Membership review';

  @override
  String membershipReviewSubtitle(String tier) {
    return '$tier request is awaiting payment verification.';
  }

  @override
  String membershipRenewsOn(String date) {
    return 'Renews on $date';
  }

  @override
  String get fanRegistryTitle => 'Fan registry';

  @override
  String get fanRegistryBrowseAll => 'Browse all supporters';

  @override
  String get membershipPackagesTitle => 'Packages';

  @override
  String get membershipOfflineTitle => 'Membership unavailable';

  @override
  String get membershipOfflineMessage =>
      'Connect to load current membership details.';

  @override
  String get membershipSetupPending => 'Membership setup pending';

  @override
  String get membershipChangeDeniedTitle => 'Membership change not permitted';

  @override
  String get membershipChangeDeniedMessage =>
      'Your account cannot change membership right now. Your current membership remains unchanged.';

  @override
  String get membershipChangedTitle => 'Membership details changed';

  @override
  String get membershipChangedMessage =>
      'The club updated these details while you were reviewing them. Refresh before choosing a package.';

  @override
  String get membershipTimeoutTitle => 'Membership request timed out';

  @override
  String get membershipTimeoutMessage =>
      'The secure request window expired. Refresh membership status before trying again.';

  @override
  String get membershipUnavailableMessage =>
      'Membership details are temporarily unavailable.';

  @override
  String get membershipPaymentSent => 'Payment sent';

  @override
  String get membershipPaymentVerifying => 'Verifying payment';

  @override
  String get membershipConfirmed => 'Membership confirmed';

  @override
  String membershipRequestTitle(String tier) {
    return '$tier membership request';
  }

  @override
  String membershipAmount(String currency, String amount) {
    return 'Amount: $currency $amount';
  }

  @override
  String get membershipVerificationTime =>
      'Verification typically takes 1–24 hours. You will be notified once confirmed.';

  @override
  String membershipRequestedOn(String date) {
    return 'Requested: $date';
  }

  @override
  String get contactSupport => 'Contact support';

  @override
  String get membershipPackageEmpty =>
      'Membership packages will appear once the club publishes them.';

  @override
  String get fanRegistrySearchHint => 'Search fans by name';

  @override
  String get fanRegistryUnavailable => 'Registry unavailable';

  @override
  String get fanRegistryUnavailableMessage =>
      'Fan registry is temporarily unavailable.';

  @override
  String fanRegistryLoaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fans loaded',
      one: '1 fan loaded',
      zero: 'No fans loaded',
    );
    return '$_temp0';
  }

  @override
  String get fanRegistrySummary =>
      'This registry mirrors the club membership roster.';

  @override
  String fanRegistryFiltered(String query) {
    return 'Filtered results for “$query”.';
  }

  @override
  String get fanRegistryLoadMoreFailure =>
      'Could not load more fans right now.';

  @override
  String get fanRegistryPending => 'Pending';

  @override
  String fanRegistryActivity(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count activity',
      one: '1 activity',
      zero: 'No activity',
    );
    return '$_temp0';
  }

  @override
  String fanRegistryJoined(String date) {
    return 'Joined $date';
  }

  @override
  String fanRegistryJoinedRenews(String joined, String renews) {
    return 'Joined $joined • Renews $renews';
  }

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileLoadingMembership => 'Loading membership…';

  @override
  String get profileMembershipReviewPending => 'Membership review pending';

  @override
  String get profileMyClub => 'My club';

  @override
  String get profileMatchday => 'Matchday';

  @override
  String get profileMyPicks => 'My picks';

  @override
  String get profileClubBenefits => 'Club benefits';

  @override
  String get profileContributions => 'Contributions';

  @override
  String get profileShop => 'Shop';

  @override
  String get profileApp => 'App';

  @override
  String get profileNotifications => 'Notifications';

  @override
  String get profileActivityHistory => 'Activity history';

  @override
  String profileActivityPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count activity points',
      one: '1 activity point',
      zero: 'No activity points',
    );
    return '$_temp0';
  }

  @override
  String get tierTitle => 'Membership tier';

  @override
  String get tierUnavailableTitle => 'Tier details unavailable';

  @override
  String get tierDisabledMessage =>
      'Membership tier details are disabled for this build. No membership request can be started here.';

  @override
  String get backToMembership => 'Back to membership';

  @override
  String get tierNotFoundTitle => 'Tier not found';

  @override
  String get tierNotFoundMessage =>
      'This membership tier is not available in the official category list.';

  @override
  String get tierOfflineTitle => 'Tier details offline';

  @override
  String get tierOfflineMessage =>
      'Reconnect to check this membership tier. No request is queued offline.';

  @override
  String get tierAccessDeniedTitle => 'Tier access denied';

  @override
  String get tierAccessDeniedMessage =>
      'This account cannot open the requested membership tier details.';

  @override
  String get tierTimeoutTitle => 'Tier check timed out';

  @override
  String get tierTimeoutMessage =>
      'The app could not confirm this membership tier in time. Try one bounded refresh.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get tierChangedTitle => 'Tier details changed';

  @override
  String get tierChangedMessage =>
      'The current tier could not be confirmed because its details changed elsewhere.';

  @override
  String get tierLoadUnavailableMessage =>
      'The membership tier could not be loaded. No private service details were shown.';

  @override
  String tierSelected(String tier) {
    return '$tier membership tier selected';
  }

  @override
  String get tierPerks => 'Tier perks';

  @override
  String get tierAccess => 'Membership access';

  @override
  String get tierShowingOfficialTitle => 'Showing official tier details';

  @override
  String get tierOfflineStatusMessage =>
      'Reconnect to check for updates. No membership request is queued offline.';

  @override
  String get tierRefreshingTitle => 'Refreshing tier details';

  @override
  String get tierRefreshingMessage =>
      'The official category details stay visible while updates load.';

  @override
  String get tierUpdateDeniedTitle => 'Update access denied';

  @override
  String get tierUpdateDeniedMessage =>
      'Official category details remain visible. This account cannot check remote updates.';

  @override
  String get tierChangedStatusMessage =>
      'Official category details remain visible. Refresh to confirm the latest version.';

  @override
  String get tierRefreshTimeoutTitle => 'Tier refresh timed out';

  @override
  String get tierRefreshTimeoutMessage =>
      'Official category details remain visible. Try one bounded refresh.';

  @override
  String get tierOutdatedTitle => 'Tier details may be out of date';

  @override
  String get tierOutdatedMessage =>
      'Official category details remain visible while the service is unavailable.';

  @override
  String get tierDegradedMessage =>
      'The last available category details remain visible until refresh succeeds.';

  @override
  String get contributionConfirmTitle => 'Confirm contribution';

  @override
  String contributionConfirmQuestion(String tier) {
    return 'Did you complete the MoMo USSD payment for the $tier tier?';
  }

  @override
  String get contributionSelectedTier => 'Selected tier';

  @override
  String get contributionPendingVerification => 'Pending verification';

  @override
  String get contributionNotYet => 'Not yet';

  @override
  String get contributionConfirming => 'Confirming…';

  @override
  String get contributionYesPaid => 'Yes, I paid';

  @override
  String get contributionPrivacy =>
      'Contributions are verified anonymously via Fan ID.';

  @override
  String get contributionHistory => 'Contribution history';

  @override
  String get shareMembershipCard => 'Share membership card';

  @override
  String get shareMembershipCardHint => 'Share your digital membership card';

  @override
  String membershipSince(String date) {
    return 'Since $date';
  }

  @override
  String get membershipFanCard => 'Fan card';

  @override
  String get membershipReviewPendingUpper => 'Review pending';

  @override
  String get membershipBrandWatermark => 'GIKUNDIRO';

  @override
  String get navHome => 'Home';

  @override
  String get navClub => 'Club';

  @override
  String get navFanZone => 'Fan Zone';

  @override
  String get navMembership => 'Membership';

  @override
  String get membershipConnectBeforeChange =>
      'Connect before changing membership.';

  @override
  String get membershipSignInFirst => 'Sign in first to activate membership.';

  @override
  String membershipRequestSubmitted(String tier) {
    return '$tier membership request submitted.';
  }

  @override
  String membershipAlreadyPending(String tier) {
    return '$tier membership is already pending payment verification.';
  }

  @override
  String membershipStarted(String tier) {
    return '$tier membership started.';
  }

  @override
  String get membershipPaymentSetupPending =>
      'Membership payment setup is pending club activation.';

  @override
  String membershipDialerFailed(String tier) {
    return '$tier request was saved, but the MoMo dialer could not open.';
  }

  @override
  String membershipSubmittedBackground(String tier) {
    return '$tier request submitted. Payment verification happens in the background.';
  }

  @override
  String get membershipPendingReviewAction => 'Pending review';

  @override
  String get membershipActivateAction => 'Activate';

  @override
  String get membershipRenewAction => 'Renew';

  @override
  String get membershipSwitchAction => 'Switch';

  @override
  String get membershipCopied => 'Membership details copied.';

  @override
  String membershipShareText(String club, String tier, String supporter) {
    return '$club membership\nTier: $tier\nSupporter ID: #$supporter';
  }

  @override
  String get membershipActivityPending =>
      'Membership activity appears after ticket, fanclub, and contribution reviews.';

  @override
  String membershipActivityRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count activity points recorded.',
      one: '1 activity point recorded.',
      zero: 'No activity points recorded.',
    );
    return '$_temp0';
  }

  @override
  String get membershipSupportMessage =>
      'Hi, I need help with my membership payment verification.';

  @override
  String get membershipWhatsAppUnavailable =>
      'Could not open WhatsApp. Please contact support.';

  @override
  String get membershipSupportNotConfigured =>
      'Support contact is not configured yet.';

  @override
  String get membershipSubmittingTitle => 'Submitting membership request';

  @override
  String get membershipUpdatingTitle => 'Updating membership';

  @override
  String get membershipSubmittingMessage =>
      'Keep this screen open while the club receives your request.';

  @override
  String get membershipUpdatingMessage =>
      'Refreshing packages and current membership details.';

  @override
  String get membershipRefreshAction => 'Refresh';

  @override
  String membershipCurrentStatus(String tier) {
    return '$tier · Current';
  }

  @override
  String get membershipRefreshRequired => 'Refresh required';

  @override
  String get membershipSubmittingAction => 'Submitting';

  @override
  String membershipPackageCurrentSemantic(String tier) {
    return '$tier membership package, current';
  }

  @override
  String get membershipPackageFallback => 'Package';

  @override
  String get membershipFanFallback => 'Fan';

  @override
  String get membershipDateNextYear => 'next year';

  @override
  String membershipDate(int day, String month, int year) {
    return '$day $month $year';
  }

  @override
  String get membershipMonthJan => 'Jan';

  @override
  String get membershipMonthFeb => 'Feb';

  @override
  String get membershipMonthMar => 'Mar';

  @override
  String get membershipMonthApr => 'Apr';

  @override
  String get membershipMonthMay => 'May';

  @override
  String get membershipMonthJun => 'Jun';

  @override
  String get membershipMonthJul => 'Jul';

  @override
  String get membershipMonthAug => 'Aug';

  @override
  String get membershipMonthSep => 'Sep';

  @override
  String get membershipMonthOct => 'Oct';

  @override
  String get membershipMonthNov => 'Nov';

  @override
  String get membershipMonthDec => 'Dec';

  @override
  String get clubTitle => 'Club';

  @override
  String clubOfficialOverviewSemantic(String club) {
    return '$club official club overview';
  }

  @override
  String get clubLiveIdentityUnavailable => 'Live club identity unavailable';

  @override
  String get clubIdentityFallbackMessage =>
      'Showing the verified app identity while the current club record cannot be refreshed.';

  @override
  String get clubOfficialSection => 'Official club';

  @override
  String get clubTeamTitle => 'Team';

  @override
  String get clubTeamSubtitle =>
      'First-team squad and official player profiles';

  @override
  String get clubTeamEmptyTitle => 'No squad published';

  @override
  String get clubTeamEmptyMessage =>
      'The club has not published its first-team squad for this app.';

  @override
  String get clubNewsTitle => 'Club news';

  @override
  String get clubNewsSubtitle => 'Published club reporting and announcements';

  @override
  String get clubNewsEmptyTitle => 'No news published';

  @override
  String get clubNewsEmptyMessage => 'Published club stories will appear here.';

  @override
  String get clubArticleUnavailableTitle => 'Article unavailable';

  @override
  String get clubArticleUnavailableMessage =>
      'This article is not published for the active club or the link is no longer current.';

  @override
  String get clubArticleBodyUnavailable =>
      'The full article content is not available.';

  @override
  String get clubFixturesTitle => 'Fixtures';

  @override
  String get clubFixturesSubtitle => 'Upcoming matches and ticket availability';

  @override
  String get clubFixturesEmptyTitle => 'No upcoming fixtures';

  @override
  String get clubFixturesEmptyMessage =>
      'The club has not published another fixture yet.';

  @override
  String clubFixtureTitle(String home, String away) {
    return '$home vs $away';
  }

  @override
  String get clubTicketsTitle => 'Tickets';

  @override
  String get clubResultsTitle => 'Results';

  @override
  String get clubResultsSubtitle => 'Completed match scores';

  @override
  String get clubResultsEmptyTitle => 'No results published';

  @override
  String get clubResultsEmptyMessage =>
      'Completed club matches will appear here.';

  @override
  String clubResultTitle(
    String home,
    int homeScore,
    int awayScore,
    String away,
  ) {
    return '$home $homeScore – $awayScore $away';
  }

  @override
  String get clubMatchTitle => 'Match';

  @override
  String get clubMatchUnavailableTitle => 'Match unavailable';

  @override
  String get clubMatchUnavailableMessage =>
      'This match is not published for the active club or the link is no longer current.';

  @override
  String clubScore(int homeScore, int awayScore) {
    return '$homeScore – $awayScore';
  }

  @override
  String get clubViewAvailableTickets => 'View available tickets';

  @override
  String get clubStandingsTitle => 'Standings';

  @override
  String get clubStandingsSubtitle => 'Current published league table';

  @override
  String get clubStandingsEmptyTitle => 'No standings published';

  @override
  String get clubStandingsEmptyMessage =>
      'The current league table has not been published.';

  @override
  String get clubPlayedShort => 'P';

  @override
  String get clubGoalDifferenceShort => 'GD';

  @override
  String get clubPointsShort => 'PTS';

  @override
  String get clubHistoryTitle => 'Club history';

  @override
  String get clubHistorySubtitle => 'The club record and milestones';

  @override
  String get clubHistoryEmptyTitle => 'History not published';

  @override
  String get clubHistoryEmptyMessage =>
      'The club history remains unavailable until reviewed content is published.';

  @override
  String get clubProjectsTitle => 'Club projects';

  @override
  String get clubProjectsSubtitle => 'Governed supporter projects and progress';

  @override
  String get clubProjectsEmptyTitle => 'No projects published';

  @override
  String get clubProjectsEmptyMessage =>
      'Governed supporter projects will appear after club approval.';

  @override
  String clubSupporters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count supporters',
      one: '1 supporter',
      zero: 'No supporters',
    );
    return '$_temp0';
  }

  @override
  String get clubProjectTitle => 'Club project';

  @override
  String get clubProjectUnavailableTitle => 'Project unavailable';

  @override
  String get clubProjectUnavailableMessage =>
      'This project is not active for the current club or the link is no longer current.';

  @override
  String clubSupportersParticipate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count supporters currently participate.',
      one: '1 supporter currently participates.',
      zero: 'No supporters currently participate.',
    );
    return '$_temp0';
  }

  @override
  String get clubOpenContribution => 'Open contribution workflow';

  @override
  String get clubInformationUnavailable => 'Club information unavailable';

  @override
  String get clubInformationLoadMessage =>
      'The current club data could not be loaded. Existing app content has not been replaced.';

  @override
  String get clubLinkedRecordLoadMessage =>
      'The linked club record could not be loaded.';

  @override
  String get clubRefresh => 'Refresh';

  @override
  String get clubTicketsSubtitle => 'Match tickets published for this club';

  @override
  String get clubShopTitle => 'Shop';

  @override
  String get clubShopSubtitle => 'Official products and availability';

  @override
  String onboardingBelongImageSemantic(String club) {
    return '$club players applauding supporters after a match';
  }

  @override
  String onboardingKnowImageSemantic(String club) {
    return '$club players celebrating together';
  }

  @override
  String onboardingLiveImageSemantic(String club) {
    return '$club player portrait';
  }

  @override
  String onboardingIdentitySemantic(String club) {
    return '$club identity';
  }

  @override
  String onboardingImageSemantic(String description, int index, int count) {
    return '$description. Image $index of $count';
  }

  @override
  String get onboardingAnonymousSessionUnavailable =>
      'Could not start a guest session. Try again.';

  @override
  String get onboardingRefreshingTitle => 'Refreshing welcome';

  @override
  String get onboardingRefreshingMessage =>
      'Keeping the current welcome and choices visible while updates are checked.';

  @override
  String get onboardingStatusTitle => 'Welcome status';

  @override
  String get onboardingWhatsAppUnavailable => 'WhatsApp sign-in unavailable';

  @override
  String get onboardingOfflineSavedMessage =>
      'Offline. Your saved welcome is available. Continue without signing in.';

  @override
  String get onboardingWhatsAppLaterMessage =>
      'Continue without signing in, or try WhatsApp later.';

  @override
  String get onboardingContentUnavailableTitle => 'Welcome content unavailable';

  @override
  String get onboardingContentUnavailableMessage =>
      'There is no welcome content to show yet. Refresh or continue without signing in.';

  @override
  String get onboardingPreparingTitle => 'Preparing your welcome';

  @override
  String get onboardingPreparingMessage =>
      'Loading the latest club welcome and sign-in choices.';

  @override
  String get onboardingAccessUnavailableTitle => 'Welcome access unavailable';

  @override
  String get onboardingAccessUnavailableMessage =>
      'This welcome cannot be opened for this account. WhatsApp sign-in and guest access remain available.';

  @override
  String get onboardingChangedTitle => 'Welcome changed';

  @override
  String get onboardingChangedMessage =>
      'The welcome changed while it was opening. Refresh to load the current version.';

  @override
  String get onboardingSecurityTimeoutTitle =>
      'Welcome security check timed out';

  @override
  String get onboardingSecurityTimeoutMessage =>
      'The welcome could not be verified in time. Check your connection and refresh.';

  @override
  String get onboardingUnavailableTitle => 'Welcome unavailable';

  @override
  String get onboardingUnavailableMessage =>
      'The welcome could not be loaded safely. Try again or continue without signing in.';

  @override
  String get onboardingRefresh => 'Refresh';

  @override
  String splashLoadingSemantic(String app) {
    return '$app loading';
  }

  @override
  String get authBack => 'Back';

  @override
  String get authCountryUnavailable =>
      'Country details are unavailable for this build.';

  @override
  String get authSendingCodeTitle => 'Sending code';

  @override
  String get authSendingCodeMessage =>
      'Keep this screen open while WhatsApp sign-in starts.';

  @override
  String get authSignInUnavailableTitle => 'Sign-in unavailable';

  @override
  String get authRequestTimeoutTitle => 'Request timed out';

  @override
  String get authNumberLinkedTitle => 'Number already linked';

  @override
  String get authCheckNumberTitle => 'Check the number';

  @override
  String get authCodeNotSentTitle => 'Code not sent';

  @override
  String get authEditNumber => 'Edit number';

  @override
  String get authPhonePermissionMessage =>
      'This account cannot request a sign-in code.';

  @override
  String get authPhoneTimeoutMessage =>
      'The code request timed out. Check your connection and try again.';

  @override
  String get authPhoneConflictMessage =>
      'This number is already linked. Review the number or use the existing account.';

  @override
  String get authPhoneInvalidMessage =>
      'Enter a valid phone number including the country code.';

  @override
  String get authPhoneUnknownMessage =>
      'The sign-in code could not be sent. Try again.';

  @override
  String get authPhoneOfflineMessage =>
      'Connect to the internet to send a WhatsApp code.';

  @override
  String get authWhatsAppEyebrow => 'WhatsApp';

  @override
  String get authEnterNumberTitle => 'Enter number';

  @override
  String get authEnterNumberBody => 'We will send a private sign-in code.';

  @override
  String get authPhoneLabel => 'Phone';

  @override
  String get authWhatsAppNumberLabel => 'WhatsApp number';

  @override
  String get authPhoneHint => '+250 7xx xxx xxx';

  @override
  String get authPhonePrivacy => 'Your number stays private.';

  @override
  String get authSendCode => 'Send code';

  @override
  String get authGuestSessionUnavailable =>
      'Could not start a guest session. Try again.';

  @override
  String get authOtpInvalidMessage => 'Check the code and try again.';

  @override
  String get authOtpExpiredMessage => 'Request a new code.';

  @override
  String get authNewCodeSent => 'New WhatsApp code sent.';

  @override
  String get authSendingNewCodeTitle => 'Sending new code';

  @override
  String get authCheckingCodeTitle => 'Checking code';

  @override
  String get authSendingNewCodeMessage =>
      'Keep this screen open while a new code is requested.';

  @override
  String get authCheckingCodeMessage =>
      'Keep this screen open while the code is verified.';

  @override
  String get authVerificationUnavailableTitle => 'Verification unavailable';

  @override
  String get authCodeExpiredTitle => 'Code expired';

  @override
  String get authCodeNotAcceptedTitle => 'Code not accepted';

  @override
  String get authVerificationFailedTitle => 'Verification failed';

  @override
  String get authCheckCode => 'Check code';

  @override
  String get authOtpPermissionMessage =>
      'This account cannot verify the requested code.';

  @override
  String get authOtpConflictMessage =>
      'This number is already linked to another sign-in.';

  @override
  String get authOtpUnknownMessage =>
      'The code could not be verified. Try again.';

  @override
  String get authOtpOfflineMessage =>
      'Connect to the internet to verify the WhatsApp code.';

  @override
  String get authPhoneMissingTitle => 'Phone number missing';

  @override
  String get authPhoneMissingMessage =>
      'Start again to request a WhatsApp code.';

  @override
  String get authChangeNumber => 'Change number';

  @override
  String authResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get authResendCode => 'Resend code';

  @override
  String get authCheckWhatsAppEyebrow => 'Check WhatsApp';

  @override
  String get authEnterCodeTitle => 'Enter code';

  @override
  String get authEnterCodeBody => 'Sent to your WhatsApp number.';

  @override
  String get authCodeLabel => 'Code';

  @override
  String get authWhatsAppCodeLabel => 'WhatsApp code';

  @override
  String get authCodeHint => '••••••';

  @override
  String get authCodePrivacy => 'Code hidden for privacy.';

  @override
  String get authVerifyCode => 'Verify code';

  @override
  String get authVerifyAndContinue => 'Verify and continue';

  @override
  String get homeRefreshingTitle => 'Refreshing Home';

  @override
  String get homeRefreshingMessage =>
      'Keeping the current matchday, points, and shortcuts visible while updates load.';

  @override
  String get homeUpdatesPausedTitle => 'Live updates paused';

  @override
  String get homeSavedContentNotice =>
      'Showing saved Home content. Reconnect and refresh for current club updates.';

  @override
  String get homeOfflineShortcutsNotice =>
      'Connect to refresh Home. Showing saved shortcuts.';

  @override
  String get homeLiveUnavailableNotice =>
      'Live club data is temporarily unavailable. Pull to refresh.';

  @override
  String get homePartialUnavailableNotice =>
      'Some live club data is temporarily unavailable. Pull to refresh.';

  @override
  String get homePartialShortcutsUnavailableNotice =>
      'Some live club data is temporarily unavailable. Home shortcuts are unavailable.';

  @override
  String get homeMatchdayPendingNotice =>
      'Matchday data will appear when published.';

  @override
  String get homeOpenMatchday => 'Open matchday';

  @override
  String get homeMatchdayUnavailable => 'Matchday unavailable';

  @override
  String get homeOpenMatchdaySemantic => 'Open matchday in Fan Zone';

  @override
  String get homeMatchdayUnavailableSemantic =>
      'Matchday in Fan Zone is unavailable';

  @override
  String get homeMatchdayTitle => 'Matchday';

  @override
  String get homeNextFixturePending =>
      'The next fixture will appear here when it is published.';

  @override
  String get homeFixturesUnavailable => 'Club fixtures are not available yet.';

  @override
  String get homeOpenFanZone => 'Open Fan Zone';

  @override
  String get homeSearchHint => 'Find';

  @override
  String get homeSearchSemantic => 'Search fans, fixtures, wallet';

  @override
  String get homeNotifications => 'Notifications';

  @override
  String get homeWallet => 'Wallet';

  @override
  String get homeAccessUnavailableTitle => 'Home access not available';

  @override
  String get homeAccessUnavailableMessage =>
      'Your account cannot load Home right now. Contact support if this should be available.';

  @override
  String get homeChangedTitle => 'Home changed';

  @override
  String get homeChangedMessage =>
      'Home data changed while you were viewing it. Refresh to load the current version.';

  @override
  String get homeSecurityTimeoutTitle => 'Home security check timed out';

  @override
  String get homeSecurityTimeoutMessage =>
      'We could not confirm current Home access. Refresh to retry.';

  @override
  String get homeUnavailableTitle => 'Home unavailable';

  @override
  String get homeUnavailableMessage =>
      'Live club data is temporarily unavailable.';

  @override
  String get homeSupportersTitle => 'Supporters';

  @override
  String get homeSupportersSubtitle => 'Top active';

  @override
  String homePoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pts',
      one: '1 pt',
      zero: '0 pts',
    );
    return '$_temp0';
  }

  @override
  String get homeNewsTitle => 'News';

  @override
  String get homeLatestUpdates => 'Latest club updates';

  @override
  String get homeLatestUnavailable =>
      'Latest Intel is temporarily unavailable. Pull to refresh.';

  @override
  String get homeOpenMatchDetails => 'Open match details';

  @override
  String homeMatchTitle(String home, String away) {
    return '$home vs $away';
  }

  @override
  String get homeShortcutsTitle => 'Shortcuts';

  @override
  String get homeLess => 'Less';

  @override
  String get homeMore => 'More';

  @override
  String get homeHideMoreShortcuts => 'Hide more shortcuts';

  @override
  String get homeShowMoreShortcuts => 'Show more shortcuts';

  @override
  String get homeMoreShortcuts => 'More shortcuts';

  @override
  String homeActionUnavailable(String action) {
    return '$action\nUnavailable';
  }

  @override
  String homeActionUnavailableInline(String action) {
    return '$action · Unavailable';
  }

  @override
  String homeActionOpensHint(String action) {
    return 'Opens $action';
  }

  @override
  String homeActionUnavailableHint(String action) {
    return '$action is unavailable';
  }

  @override
  String get homeTicketsAction => 'Tickets';

  @override
  String get homeMembershipAction => 'Join Gikundiro';

  @override
  String get homeFanZoneAction => 'Fan Zone';

  @override
  String get homeShopAction => 'Shop';

  @override
  String get homeFetLabel => 'FET';

  @override
  String get homeRankLabel => 'Rank';

  @override
  String get fanClubPreviewUnavailableTitle => 'Fan club preview unavailable';

  @override
  String get fanClubPreviewUnavailableMessage =>
      'Fan club details are not enabled for this build or club.';

  @override
  String get fanClubBackToSupporters => 'BACK TO SUPPORTERS';

  @override
  String get fanClubUnavailableTitle => 'Fan club unavailable';

  @override
  String get fanClubUnavailableMessage =>
      'This approved public fan club could not be found.';

  @override
  String get fanClubFallbackName => 'Fan club';

  @override
  String get fanClubUnknownRegion => 'Unknown';

  @override
  String get fanClubProtectedRequestPath => 'Protected request path';

  @override
  String get fanClubActive => 'ACTIVE';

  @override
  String get fanClubPendingReview => 'PENDING REVIEW';

  @override
  String fanClubCurrentSemantic(String name) {
    return 'Current fan club, $name';
  }

  @override
  String get fanClubAboutTitle => 'ABOUT THIS CLUB';

  @override
  String fanClubRegionValue(String region) {
    return 'Region: $region';
  }

  @override
  String get fanClubSnapshotTitle => 'GROUP SNAPSHOT';

  @override
  String get fanClubAwaitingApproval =>
      'This fan club is waiting for admin approval.';

  @override
  String get fanClubJoinRequestsReviewed =>
      'Join requests are reviewed in the Supporters area.';

  @override
  String fanClubRegionSentence(String region) {
    return 'Region: $region.';
  }

  @override
  String fanClubPublicSupporters(String members) {
    return '$members supporters listed publicly.';
  }

  @override
  String get fanClubUnavailableOfflineTitle => 'Fan club unavailable offline';

  @override
  String get fanClubUnavailableOfflineMessage =>
      'Connect to confirm the latest approved club details.';

  @override
  String get fanClubAccessDeniedTitle => 'Fan club access denied';

  @override
  String get fanClubAccessDeniedMessage =>
      'This club is not available for the current account.';

  @override
  String get fanClubDetailsChangedTitle => 'Fan club details changed';

  @override
  String get fanClubRefreshBeforeSupporters =>
      'Refresh before continuing to Supporters.';

  @override
  String get fanClubRefreshAction => 'REFRESH CLUB';

  @override
  String get fanClubTryAgainAction => 'TRY AGAIN';

  @override
  String get fanClubSecurityTimeoutTitle => 'Fan club security check timed out';

  @override
  String get fanClubSecurityTimeoutMessage =>
      'The approved club could not be confirmed safely. Try again.';

  @override
  String get fanClubLoadFailureTitle => 'Unable to load fan club';

  @override
  String get fanClubLoadFailureMessage =>
      'The approved club could not be confirmed. Try again.';

  @override
  String get fanClubShowingSavedTitle => 'Showing saved fan club';

  @override
  String get fanClubSavedDetailsMayChange =>
      'Membership and matchday details may have changed.';

  @override
  String get fanClubRefreshingTitle => 'Refreshing fan club';

  @override
  String get fanClubLastConfirmedVisible =>
      'The last confirmed club details remain visible.';

  @override
  String get fanClubLastConfirmedRefresh =>
      'These are the last confirmed details. Refresh before continuing.';

  @override
  String get fanClubCheckTimedOutTitle => 'Fan club check timed out';

  @override
  String get fanClubAccessChangedTitle => 'Fan club access changed';

  @override
  String get fanClubAccessChangedMessage =>
      'The saved details are read-only. Return to Supporters.';

  @override
  String get fanClubRefreshFailedTitle => 'Fan club refresh failed';

  @override
  String get fanClubMatchdayAgenda => 'MATCHDAY AGENDA';

  @override
  String fanClubMatchMeta(String competition, String venue) {
    return '$competition  •  $venue';
  }

  @override
  String fanClubMatchSchedule(String date, String time) {
    return '$date  •  $time';
  }

  @override
  String get fanClubMembersLabel => 'MEMBERS';

  @override
  String get fanClubStatusLabel => 'STATUS';

  @override
  String get fanClubRegionLabel => 'REGION';

  @override
  String get fanClubOpenSupportersSemantic => 'Open Supporters area';

  @override
  String get fanClubPendingReviewSemantic => 'Fan club pending review';

  @override
  String get fanClubSupportersAction => 'SUPPORTERS';

  @override
  String get fanClubOpenSupportersAction => 'OPEN SUPPORTERS';

  @override
  String get fanClubCopyLink => 'COPY LINK';

  @override
  String get fanClubCopyLinkSemantic => 'Copy fan club link';

  @override
  String fanClubShareFallback(String appName) {
    return 'Open $appName and visit the Fan Clubs section.';
  }

  @override
  String fanClubShareText(String appName, String target) {
    return 'Join this $appName fan club: $target';
  }

  @override
  String get fanClubLinkCopied => 'Fan club link copied.';

  @override
  String get fanClubsLoadError => 'Could not load fan clubs right now.';

  @override
  String get fanClubReviewRequestSent =>
      'Request sent for admin review. You are not joined until the club approves it.';

  @override
  String get fanClubsCommunityEyebrow => 'THE COMMUNITY';

  @override
  String get fanClubsTitle => 'FAN CLUBS';

  @override
  String get fanClubsSearchHint => 'Search clubs or locations';

  @override
  String get fanClubsFeaturedChapter => 'FEATURED CHAPTER';

  @override
  String get fanClubOfficialChapterFallback => 'Official supporter chapter.';

  @override
  String fanClubMembersValue(String members) {
    return '$members members';
  }

  @override
  String fanClubRegionMembers(String region, String members) {
    return '$region • $members';
  }

  @override
  String get fanClubReviewRequested => 'Review requested';

  @override
  String get fanClubRequestReview => 'Request review';

  @override
  String get fanClubDetailsAction => 'Details';

  @override
  String get liveMatchLoadError =>
      'Could not load the live match center right now.';

  @override
  String get liveStatusLive => 'LIVE';

  @override
  String get liveStatusHalfTime => 'HALF-TIME';

  @override
  String get liveStatusFullTime => 'FULL-TIME';

  @override
  String get liveStatusPostponed => 'POSTPONED';

  @override
  String get liveStatusCancelled => 'CANCELLED';

  @override
  String get liveStatusUpcoming => 'UPCOMING';

  @override
  String get liveStatusFinal => 'FINAL';

  @override
  String liveTimeVenue(String time, String venue) {
    return '$time  •  $venue';
  }

  @override
  String get liveMatchUpdate => 'Match update';

  @override
  String liveMatchTeamsUpper(String home, String away) {
    return '$home VS $away';
  }

  @override
  String get liveModeActive => 'Live mode active. Events appear in real time.';

  @override
  String get liveMatchReport => 'MATCH REPORT';

  @override
  String get liveMatchFinishedPending => 'Match finished. Summary pending.';

  @override
  String get liveMatchdayIntel => 'MATCHDAY INTEL';

  @override
  String get liveFixturePublished =>
      'Fixture published. Live updates start near kickoff.';

  @override
  String get liveStatPossession => 'Possession';

  @override
  String get liveStatShots => 'Shots';

  @override
  String get liveStatCorners => 'Corners';

  @override
  String get liveStatPending => 'TBD';

  @override
  String get liveMatchCenter => 'Match Center';

  @override
  String get liveMyPredictions => 'My Predictions';

  @override
  String liveScore(int homeScore, int awayScore) {
    return '$homeScore - $awayScore';
  }

  @override
  String get liveMatchIntel => 'Match Intel';

  @override
  String get liveBrowsePredictions => 'Browse predictions';

  @override
  String get liveShareMatch => 'Share match';

  @override
  String liveShareText(
    String appName,
    String homeTeam,
    int homeScore,
    int awayScore,
    String awayTeam,
    String status,
  ) {
    return '$appName: $homeTeam $homeScore-$awayScore $awayTeam ($status)';
  }

  @override
  String get liveMatchCopied => 'Match update copied to clipboard.';

  @override
  String get liveCenterUnavailable => 'LIVE CENTER UNAVAILABLE';

  @override
  String get liveRefresh => 'Refresh';

  @override
  String get newsArticleNotFoundTitle => 'Article not found';

  @override
  String get newsArticleNotFoundMessage =>
      'This story may have been removed or is no longer available.';

  @override
  String get newsBackToLiveMatch => 'Back to live match';

  @override
  String get newsClubNews => 'Club news';

  @override
  String newsArticleImageSemantic(String title) {
    return '$title article image';
  }

  @override
  String get newsRefreshingTitle => 'Refreshing article';

  @override
  String get newsRefreshingMessage =>
      'Keeping the confirmed story visible while the latest version is checked.';

  @override
  String get newsRelatedUnavailableTitle => 'Related stories unavailable';

  @override
  String get newsRelatedUnavailableMessage =>
      'You can read this article, but related-story navigation is disabled for this build.';

  @override
  String get newsShowingSavedTitle => 'Showing saved article';

  @override
  String get newsShowingSavedMessage =>
      'Reconnect and refresh before opening another story.';

  @override
  String newsSelectedSemantic(String title) {
    return 'Selected article $title';
  }

  @override
  String get newsToday => 'Today';

  @override
  String newsMetadata(String date) {
    return 'Club News  ·  $date  ·  Media Desk';
  }

  @override
  String get newsRelatedIntel => 'Related intel';

  @override
  String get newsRefreshArticle => 'REFRESH ARTICLE';

  @override
  String get newsConnectionRestored => 'Connection restored';

  @override
  String get newsArticleOffline => 'Article offline';

  @override
  String get newsRefreshLatest => 'Refresh to confirm the latest story.';

  @override
  String get newsReconnectLatest => 'Reconnect to load the latest story.';

  @override
  String get newsAccessUnavailableTitle => 'Article access unavailable';

  @override
  String get newsAccessUnavailableMessage =>
      'Your current account cannot review this story.';

  @override
  String get newsChangedTitle => 'Article changed';

  @override
  String get newsChangedMessage => 'Refresh before opening another story.';

  @override
  String get newsSecurityTimeoutTitle => 'Article security check timed out';

  @override
  String get newsSecurityTimeoutMessage =>
      'No updated story was confirmed. Refresh to try again.';

  @override
  String get newsUnavailableTitle => 'Article unavailable';

  @override
  String get newsUnavailableMessage =>
      'The latest story could not be confirmed. Refresh to try again.';

  @override
  String liveTeamLogoSemantic(String label) {
    return '$label team logo';
  }

  @override
  String get liveTeamFallback => 'Team';

  @override
  String liveMatchEventSemantic(String event) {
    return 'Match event: $event';
  }

  @override
  String get liveEventGoal => 'goal';

  @override
  String get liveEventCard => 'card';

  @override
  String get liveEventSubstitution => 'substitution';

  @override
  String get liveEventVarReview => 'VAR review';

  @override
  String get liveEventUpdate => 'update';

  @override
  String liveStatSemantic(String label, String value) {
    return '$label $value';
  }

  @override
  String get shopAllCategory => 'All';

  @override
  String get shopProductFallback => 'Product';

  @override
  String shopProductAdded(String name) {
    return '$name added to cart.';
  }

  @override
  String get shopStoreTitle => 'Store';

  @override
  String get shopTitle => 'Shop';

  @override
  String get shopSearch => 'Search';

  @override
  String get shopSearchProducts => 'Search products';

  @override
  String get shopViewCart => 'View cart';

  @override
  String get shopCart => 'Cart';

  @override
  String get shopBack => 'Back';

  @override
  String get shopNoProductsTitle => 'No products available';

  @override
  String shopNoProductsCategoryTitle(String category) {
    return 'No products in $category';
  }

  @override
  String get shopNoProductsMessage =>
      'Official merchandise will appear here when the club publishes store inventory.';

  @override
  String get shopNoProductsCategoryMessage =>
      'Try another category or clear the filter to see the full store.';

  @override
  String get shopRetry => 'Retry';

  @override
  String get shopRefresh => 'Refresh';

  @override
  String get shopShowAll => 'Show all';

  @override
  String get shopRefreshingTitle => 'Refreshing store';

  @override
  String get shopRefreshingMessage => 'Current inventory is being checked.';

  @override
  String get shopSavedTitle => 'Saved store content';

  @override
  String get shopSavedMessage =>
      'Inventory may be out of date. Reconnect to refresh before checkout.';

  @override
  String get shopRefreshingSemantic =>
      'Information status: Refreshing store. Current inventory is being checked.';

  @override
  String get shopSavedSemantic =>
      'Warning status: Saved store content. Inventory may be out of date. Reconnect to refresh before checkout.';

  @override
  String get shopClubStore => 'Club store';

  @override
  String shopItemsAvailable(int count) {
    return '$count items available now.';
  }

  @override
  String get shopOfflineTitle => 'Store offline';

  @override
  String get shopOfflineMessage => 'Connect to load current club merchandise.';

  @override
  String get shopAccessTitle => 'Store access not available';

  @override
  String get shopAccessMessage =>
      'This account cannot load club merchandise. Contact club support if access should be available.';

  @override
  String get shopInventoryChangedTitle => 'Store inventory changed';

  @override
  String get shopInventoryChangedMessage =>
      'Product availability changed while loading. Refresh before adding merchandise.';

  @override
  String get shopSecurityTimeoutTitle => 'Store security check timed out';

  @override
  String get shopSecurityTimeoutMessage =>
      'The secure inventory check took too long. Refresh to try the check again.';

  @override
  String get shopUnavailableTitle => 'Store unavailable';

  @override
  String get shopUnavailableMessage => 'Could not load merchandise right now.';

  @override
  String get shopOutOfStockUpper => 'OUT OF STOCK';

  @override
  String get shopOutOfStock => 'Out of stock';

  @override
  String get shopAddToCart => 'Add to cart';

  @override
  String shopProductImageSemantic(String name) {
    return '$name product image';
  }

  @override
  String shopProductUnavailableSemantic(String name) {
    return '$name, currently out of stock';
  }

  @override
  String get shopOpenProduct => 'Open product';

  @override
  String get shopSearchHint => 'Search kits, scarves, and drops';

  @override
  String get shopMerchFallback => 'Merch';

  @override
  String shopQuantityValue(int quantity) {
    return 'Qty $quantity';
  }

  @override
  String get shopDecreaseQuantity => 'Decrease quantity';

  @override
  String get shopIncreaseQuantity => 'Increase quantity';

  @override
  String get shopRemove => 'Remove';

  @override
  String get shopReadyToCheckout => 'Ready to checkout';

  @override
  String get shopCheckout => 'Checkout';

  @override
  String get shopItemOutOfStockToast => 'This item is currently out of stock.';

  @override
  String get shopSelectSizeToast => 'Select a size before adding to cart.';

  @override
  String get shopViewCartAction => 'View Cart';

  @override
  String get shopProductNotFoundTitle => 'Product not found';

  @override
  String get shopProductNotFoundMessage =>
      'This item is no longer available in the current club store.';

  @override
  String get shopBackToStore => 'Back to store';

  @override
  String get shopProductOfflineTitle => 'Product details offline';

  @override
  String get shopProductOfflineMessage =>
      'Reconnect to check the latest price, size, and availability.';

  @override
  String get shopProductAccessTitle => 'Product access not available';

  @override
  String get shopProductAccessMessage =>
      'This product cannot be opened with the current account.';

  @override
  String get shopProductChangedTitle => 'Product details changed';

  @override
  String get shopProductChangedMessage =>
      'Refresh to load the current price, sizes, and availability.';

  @override
  String get shopProductSecurityTitle => 'Product security check timed out';

  @override
  String get shopProductSecurityMessage =>
      'The secure product check took too long. Refresh before buying.';

  @override
  String get shopProductUnavailableTitle => 'Product unavailable';

  @override
  String get shopProductUnavailableMessage =>
      'The latest product details could not be loaded.';

  @override
  String get shopLoadingProductName => 'Official Jersey Loading';

  @override
  String get shopLoadingProductDescription =>
      'Loading official merchandise details from the armoury...';

  @override
  String get shopLoadingBadge => 'LOADING';

  @override
  String get shopOfficialMerchandise => 'Official club merchandise.';

  @override
  String get shopCloseProductDetails => 'Close product details';

  @override
  String get shopRefreshingProductTitle => 'Refreshing product details';

  @override
  String get shopRefreshingProductMessage =>
      'Current price, sizes, and availability are being checked.';

  @override
  String get shopSavedProductTitle => 'Saved product details';

  @override
  String get shopSavedProductMessage =>
      'Reconnect to refresh price, sizes, and availability before buying.';

  @override
  String get shopInStock => 'Available now';

  @override
  String shopStockAvailable(int count) {
    return '$count available now';
  }

  @override
  String get shopSelectSize => 'Select size';

  @override
  String shopSizeTooltip(String size) {
    return 'Size $size';
  }

  @override
  String get shopSizeSelectedHint => 'Selected';

  @override
  String get shopSizeAvailableHint => 'Available';

  @override
  String get shopQuantity => 'Quantity';

  @override
  String get shopTotal => 'Total';

  @override
  String get shopBuyNow => 'Buy now';

  @override
  String get shopConnectPaymentAvailability =>
      'Connect to verify current payment availability.';

  @override
  String get shopPaymentSetupPending =>
      'Checkout payment setup is pending club activation.';

  @override
  String get shopPaymentCheckError =>
      'Payment availability could not be checked. Your cart and address are still here.';

  @override
  String get shopConnectBeforeCheckout =>
      'Connect before checking out. Your cart and address are still here.';

  @override
  String get shopAddressRequired => 'Enter a delivery address first.';

  @override
  String get shopMomoSetupPending =>
      'MOMO checkout setup is pending club activation.';

  @override
  String shopOrderDialerFailure(String orderId) {
    return 'Order $orderId was saved, but the MOMO dialer could not open.';
  }

  @override
  String shopOrderCreated(String orderId) {
    return 'Order $orderId created. Payment verification is still pending.';
  }

  @override
  String get shopReviewOrder => 'Review order';

  @override
  String shopItemQuantitySummary(String name, int quantity) {
    return '$name x$quantity';
  }

  @override
  String shopMoreItems(int count) {
    return '+$count more items';
  }

  @override
  String get shopDeliverTo => 'Deliver to';

  @override
  String get shopPaymentInstructions =>
      'Approve the MOMO prompt on your device, then confirm here. Orders remain pending until verification is complete.';

  @override
  String get shopPaymentSubmitted => 'I submitted the payment';

  @override
  String get shopCartEmptyTitle => 'Cart is empty';

  @override
  String get shopCartEmptyMessage =>
      'Add items from the shop to start checkout.';

  @override
  String get shopBackToShop => 'Back to shop';

  @override
  String get shopDelivery => 'Delivery';

  @override
  String get shopAddressAndTotal => 'Address and total';

  @override
  String get shopDeliveryAddress => 'Delivery address';

  @override
  String get shopEnterDeliveryAddress => 'Enter your delivery address';

  @override
  String shopStreetCityCountry(String country) {
    return 'Street, city, $country';
  }

  @override
  String get shopSubtotal => 'Subtotal';

  @override
  String get shopCheckingPayment => 'Checking payment';

  @override
  String get shopCheckingPaymentMessage =>
      'Confirming the current MOMO route for this club.';

  @override
  String get shopPaymentCheckFailed => 'Payment check failed';

  @override
  String get shopCheckoutUnavailable => 'Checkout unavailable';

  @override
  String shopPayTo(String label) {
    return 'Pay to $label';
  }

  @override
  String get shopReviewCart => 'Review cart';

  @override
  String get shopConnectionRequired => 'Connection required';

  @override
  String get shopPaymentRouteNotReady => 'Payment route not ready';

  @override
  String get shopCheckoutNotPermitted => 'Checkout not permitted';

  @override
  String get shopStatusUncertain => 'Status uncertain';

  @override
  String get shopProcessing => 'Processing';

  @override
  String get shopPayWithMomo => 'Pay with MOMO';

  @override
  String get shopCheckoutViaMomo => 'Checkout via MOMO';

  @override
  String get shopOrderUncertainTitle => 'Order status is uncertain';

  @override
  String get shopOrderUncertainMessage =>
      'The secure checkout timed out. Your cart and address are still here. Do not submit again until club support confirms whether the order was saved.';

  @override
  String get shopOrderChangedTitle => 'Order details changed';

  @override
  String get shopOrderChangedMessage =>
      'The order changed while it was being submitted. Your cart and address are still here. Review them before trying again.';

  @override
  String get shopCheckoutDeniedMessage =>
      'Your account cannot place this order. Your cart and address are still here. Contact club support before trying again.';

  @override
  String get shopCheckoutFailureTitle => 'Checkout could not start';

  @override
  String get shopCheckoutFailureMessage =>
      'No order was confirmed. Your cart and address are still here. Review them and try again.';

  @override
  String get shopSampleProductName => 'Rayon Home Jersey';

  @override
  String get shopSampleProductDescription =>
      'Official matchday jersey with a premium woven club mark, breathable stadium fabric, and club-blue trim for everyday supporters.';

  @override
  String get shopOfficialBadge => 'OFFICIAL';

  @override
  String get shopSampleProductSummary =>
      'Official kit · S M L XL · 47 available';

  @override
  String get shopProductImageUnavailable => 'Product image unavailable';

  @override
  String get shopOfficialKit => 'Official Rayon kit';

  @override
  String get shopPremiumMerchandise => 'Premium matchday merchandise';

  @override
  String get ticketQrAccessUnavailableTitle => 'E-ticket access unavailable';

  @override
  String get ticketQrAccessUnavailableMessage =>
      'Entry codes are disabled for this build. Return to your ticket wallet for status updates.';

  @override
  String get ticketNotFoundTitle => 'Ticket not found';

  @override
  String get ticketUnavailableShort => 'E-ticket unavailable.';

  @override
  String get ticketPaymentPendingTitle => 'Payment verification pending';

  @override
  String get ticketPaymentPendingMessage =>
      'This ticket request was recorded, but the QR code will only unlock after payment verification completes.';

  @override
  String get ticketEntryCode => 'Ticket entry code';

  @override
  String get ticketScannerHelper =>
      'Present only to an authorized matchday scanner.';

  @override
  String get ticketDateLabel => 'DATE';

  @override
  String get ticketTimeLabel => 'TIME';

  @override
  String get ticketVenueLabel => 'VENUE';

  @override
  String get ticketAppleWallet => 'Apple Wallet';

  @override
  String get ticketGoogleWallet => 'Google Wallet';

  @override
  String get ticketWalletExportUnavailable =>
      'Wallet export is not available in this release yet.';

  @override
  String ticketSelectedSemantic(String match) {
    return 'Selected e-ticket $match';
  }

  @override
  String get ticketOfflineTitle => 'E-ticket unavailable offline';

  @override
  String get ticketOfflineMessage =>
      'Reconnect before loading this entry code.';

  @override
  String get ticketAccessDeniedTitle => 'E-ticket access denied';

  @override
  String get ticketAccessDeniedMessage =>
      'This ticket cannot be opened with the current account.';

  @override
  String get ticketChangedTitle => 'Ticket changed';

  @override
  String get ticketChangedMessage =>
      'Refresh your wallet before presenting this entry code.';

  @override
  String get ticketSecurityTimeoutTitle => 'Ticket security check timed out';

  @override
  String get ticketSecurityTimeoutMessage =>
      'The entry code was not confirmed. Refresh before match entry.';

  @override
  String get ticketUnavailableTitle => 'Ticket unavailable';

  @override
  String get ticketUnavailableMessage =>
      'This ticket could not be confirmed from your wallet.';

  @override
  String get ticketRefreshAction => 'Refresh ticket';

  @override
  String get ticketSavedCodeTitle => 'Showing saved entry code';

  @override
  String get ticketRefreshingTitle => 'Refreshing ticket';

  @override
  String get ticketAccessChangedTitle => 'Ticket access changed';

  @override
  String get ticketCheckTimedOutTitle => 'Ticket check timed out';

  @override
  String get ticketRefreshUnavailableTitle => 'Ticket refresh unavailable';

  @override
  String get ticketSavedCodeMessage =>
      'Reconnect and refresh before presenting this code at match entry.';

  @override
  String get ticketRefreshingMessage =>
      'The last confirmed code remains visible while wallet status is checked.';

  @override
  String get ticketRefreshBeforeUse =>
      'Refresh before relying on this entry code.';

  @override
  String get ticketRefreshUpper => 'REFRESH TICKET';

  @override
  String get ticketWalletUnavailableTitle => 'Ticket wallet unavailable';

  @override
  String get ticketWalletUnavailableMessage =>
      'We could not load your ticket wallet right now. Check your connection and try again.';

  @override
  String get ticketMyTickets => 'MY TICKETS';

  @override
  String get ticketRefreshTickets => 'Refresh tickets';

  @override
  String get ticketUpcoming => 'UPCOMING';

  @override
  String get ticketPast => 'PAST';

  @override
  String get ticketBrowseMatches => 'Browse matches';

  @override
  String get ticketOpenQr => 'Open ticket QR code';

  @override
  String ticketWalletSemantic(String match, String status, String seat) {
    return '$match, $status ticket, $seat';
  }

  @override
  String ticketSeatPrice(String seat, String price) {
    return '$seat • $price';
  }

  @override
  String get ticketPendingQrMessage =>
      'Payment received on your phone still needs verification before the QR unlocks.';

  @override
  String get ticketCheckoutSummary => 'CHECKOUT SUMMARY';

  @override
  String get ticketMatchLabel => 'Match';

  @override
  String get ticketSeatTypeLabel => 'Seat type';

  @override
  String get ticketQuantityLabel => 'Quantity';

  @override
  String get ticketSeatCodeLabel => 'Seat code';

  @override
  String get ticketTotalLabel => 'Total';

  @override
  String get ticketPaymentRouteLabel => 'Payment route';

  @override
  String ticketPayToDialer(String label) {
    return 'Pay to $label\nDialer will open USSD prompt.';
  }

  @override
  String get ticketSoldOut => 'Sold out';

  @override
  String get ticketPayViaMomo => 'Pay via MOMO';

  @override
  String get ticketConfirmAfterMomo =>
      'Confirm payment after completing the MOMO prompt.';

  @override
  String get ticketConfirmPurchase => 'CONFIRM PURCHASE';

  @override
  String get ticketMatchUpper => 'MATCH';

  @override
  String get ticketZoneUpper => 'ZONE';

  @override
  String get ticketSeatUpper => 'SEAT';

  @override
  String get ticketQuantityUpper => 'QUANTITY';

  @override
  String get ticketServiceFeeUpper => 'SERVICE FEE';

  @override
  String get ticketTotalUpper => 'TOTAL';

  @override
  String get ticketIncluded => 'Included';

  @override
  String ticketMomoValue(String label) {
    return 'MOMO: $label';
  }

  @override
  String get ticketConfirmPaymentWarning =>
      'Confirm only after completing the MoMo payment on your phone.';

  @override
  String get ticketCompletedPayment => 'I completed payment';

  @override
  String get ticketDidNotPay => 'I did not pay';

  @override
  String ticketMatchVersus(String home, String away) {
    return '$home vs $away';
  }

  @override
  String ticketCompetitionVenue(String competition, String venue) {
    return '$competition  •  $venue';
  }

  @override
  String ticketRemainingCapacity(int count) {
    return 'Remaining capacity: $count';
  }

  @override
  String get ticketChooseAccess => 'CHOOSE ACCESS';

  @override
  String get ticketGeneral => 'GENERAL';

  @override
  String get ticketGeneralSubtitle => 'Open stands / Bleachers area';

  @override
  String get ticketVip => 'VIP';

  @override
  String get ticketVipSubtitle => 'Premium lounge seating';

  @override
  String get ticketChooseSeat => 'CHOOSE SPECIFIC SEAT';

  @override
  String get ticketChangeSeat => 'CHANGE SELECTED SEAT';

  @override
  String get ticketReview => 'Review';

  @override
  String get ticketReviewReservation => 'Review reservation';

  @override
  String get ticketOfficialCategories => 'OFFICIAL CATEGORIES';

  @override
  String get ticketOfficialCategoriesMessage =>
      'Approved public ticket tiers. Sale-specific availability appears when the club activates an official sale.';

  @override
  String get ticketListTitle => 'TICKETS';

  @override
  String get ticketFilterMatches => 'Filter matches';

  @override
  String get ticketMatchFilters => 'Match Filters';

  @override
  String get ticketSortSoonest => 'Soonest';

  @override
  String get ticketSortLatest => 'Latest';

  @override
  String get ticketSortCheapest => 'Cheapest';

  @override
  String get ticketTypeAvailable => 'Available';

  @override
  String get ticketTypeSoldOut => 'Sold Out';

  @override
  String get ticketTypeVipZones => 'VIP Zones';

  @override
  String get ticketRefreshMatches => 'Refresh matches';

  @override
  String get ticketRefreshMatchesOffline =>
      'Connection required to refresh matches';

  @override
  String get ticketNext => 'NEXT';

  @override
  String get ticketMine => 'MINE';

  @override
  String get ticketUpcomingSemantic => 'Upcoming tickets';

  @override
  String get ticketPastSemantic => 'Past tickets';

  @override
  String get ticketMineSemantic => 'My tickets';

  @override
  String get ticketRefreshingInventoryTitle => 'Refreshing ticket inventory';

  @override
  String get ticketRefreshingInventoryMessage =>
      'Current fixtures and availability are being checked.';

  @override
  String get ticketSavedInventoryTitle => 'Saved ticket inventory';

  @override
  String get ticketSavedInventoryMessage =>
      'Availability may be out of date. Reconnect before purchasing.';

  @override
  String get ticketNoUpcomingTitle => 'No upcoming ticketed fixtures';

  @override
  String get ticketNoUpcomingMessage =>
      'Upcoming ticket inventory will appear here once the club publishes sales for the next fixture.';

  @override
  String get ticketNoPastTitle => 'No past ticketed fixtures';

  @override
  String get ticketNoPastMessage =>
      'Past ticketed fixtures will appear here after matchday sales are completed.';

  @override
  String get ticketRefresh => 'Refresh';

  @override
  String get ticketStatusSoldOut => 'SOLD OUT';

  @override
  String get ticketStatusAvailable => 'AVAILABLE';

  @override
  String get ticketFrom => 'FROM';

  @override
  String get ticketBuyAction => 'Buy ticket';

  @override
  String get ticketSalesNotOpen => 'Sales not open';

  @override
  String get ticketVersusUpper => 'VS';

  @override
  String get ticketListOfflineTitle => 'Connect to view tickets';

  @override
  String get ticketListOfflineMessage =>
      'Reconnect to load current fixtures and ticket availability.';

  @override
  String get ticketConnectionRequired => 'Connection required';

  @override
  String get ticketListAccessTitle => 'Ticket access not available';

  @override
  String get ticketListAccessMessage =>
      'This account cannot load the club ticket inventory. Contact club support if access should be available.';

  @override
  String get ticketAccessRequired => 'Access required';

  @override
  String get ticketInventoryChangedTitle => 'Ticket inventory changed';

  @override
  String get ticketInventoryChangedMessage =>
      'Fixture or availability details changed while loading. Refresh before choosing a ticket.';

  @override
  String get ticketInventorySecurityTitle => 'Ticket security check timed out';

  @override
  String get ticketInventorySecurityMessage =>
      'The secure inventory check took too long. Refresh to try the check again.';

  @override
  String get ticketFixturesUnavailableTitle => 'Unable to load fixtures';

  @override
  String get ticketFixturesUnavailableMessage =>
      'Ticket inventory is unavailable right now. Check your connection and try again.';

  @override
  String get ticketRetry => 'Retry';

  @override
  String get ticketPaymentAvailabilityOffline =>
      'Connect to verify current ticket payment availability.';

  @override
  String get ticketPaymentSetupPending =>
      'Ticket payment setup is pending club activation.';

  @override
  String get ticketPaymentVerificationUnavailable =>
      'Payment route verification is unavailable. Try again.';

  @override
  String get ticketConnectBeforePurchase =>
      'Connect before purchasing. Your seat and quantity are still selected.';

  @override
  String get ticketSignInBeforePurchase => 'Sign in first to buy tickets.';

  @override
  String get ticketMomoSetupPending =>
      'MOMO ticketing setup is pending club activation.';

  @override
  String get ticketReservationFailed =>
      'Ticket reservation failed. Please try again from the match screen.';

  @override
  String get ticketDialerOpenFailed =>
      'Ticket request was saved, but the MOMO dialer could not open.';

  @override
  String ticketRequestsSubmitted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ticket requests submitted — pending verification.',
      one: 'Ticket request submitted — pending payment verification.',
    );
    return '$_temp0';
  }

  @override
  String get ticketConfirmationTimedOut =>
      'Ticket confirmation timed out. Check My Tickets before trying again.';

  @override
  String get ticketRequestFailed =>
      'Ticket request failed. Your selection is still available.';

  @override
  String get ticketMatchDay => 'MATCH DAY';

  @override
  String get ticketSalesUnavailableTitle => 'Ticket sales unavailable';

  @override
  String get ticketSalesUnavailableMessage =>
      'Ticket selection is not enabled for this build or club.';

  @override
  String get ticketBackToTickets => 'Back to Tickets';

  @override
  String get ticketFixtureNotFoundTitle => 'Fixture not found';

  @override
  String get ticketFixtureNotFoundMessage => 'This fixture is unavailable.';

  @override
  String get ticketDetailOfflineTitle => 'Ticket details unavailable offline';

  @override
  String get ticketDetailOfflineMessage =>
      'Connect to load this fixture and current ticket availability.';

  @override
  String get ticketDetailAccessTitle => 'Ticket access denied';

  @override
  String get ticketDetailAccessMessage =>
      'This fixture is not available for the current club account.';

  @override
  String get ticketDetailSecurityTitle => 'Ticket security check timed out';

  @override
  String get ticketDetailSecurityMessage =>
      'The fixture could not be confirmed safely. Try again.';

  @override
  String get ticketDetailChangedTitle => 'Fixture details changed';

  @override
  String get ticketDetailChangedMessage =>
      'Refresh the fixture before selecting ticket access.';

  @override
  String get ticketDetailUnavailableTitle => 'Unable to load this fixture';

  @override
  String get ticketDetailUnavailableMessage =>
      'The fixture could not be confirmed. Try again.';

  @override
  String get ticketTryAgainUpper => 'TRY AGAIN';

  @override
  String get ticketRefreshFixtureUpper => 'REFRESH FIXTURE';

  @override
  String get ticketSavedFixtureTitle => 'Showing saved fixture';

  @override
  String get ticketSavedFixtureMessage =>
      'Ticket prices may have changed. Reconnect before reviewing or purchasing.';

  @override
  String get ticketRefreshingFixtureTitle => 'Refreshing fixture';

  @override
  String get ticketRefreshingFixtureMessage =>
      'The last confirmed ticket options remain visible.';

  @override
  String get ticketFixtureChangedTitle => 'Fixture changed';

  @override
  String get ticketLastConfirmedOptionsMessage =>
      'These are the last confirmed options. Refresh before continuing.';

  @override
  String get ticketFixtureCheckTimedOutTitle => 'Fixture check timed out';

  @override
  String get ticketSavedFixtureReadOnlyMessage =>
      'The saved fixture is read-only. Return to Tickets to continue safely.';

  @override
  String get ticketFixtureRefreshFailedTitle => 'Fixture refresh failed';

  @override
  String get ticketSeatMapTitle => 'SELECT SEAT';

  @override
  String get ticketConfirm => 'Confirm';

  @override
  String get ticketSeatSelectionUnavailableTitle =>
      'Seat selection unavailable';

  @override
  String get ticketSeatSelectionUnavailableMessage =>
      'Seat selection is not enabled for this build or club.';

  @override
  String get ticketBackToTicketUpper => 'BACK TO TICKET';

  @override
  String get ticketSeatMapUnavailableTitle => 'Seat map unavailable';

  @override
  String get ticketSeatMapUnavailableMessage =>
      'This fixture could not be found.';

  @override
  String get ticketSeatMapOfflineTitle => 'Seat map unavailable offline';

  @override
  String get ticketSeatMapOfflineMessage =>
      'Connect to confirm current seat availability.';

  @override
  String get ticketSeatMapAccessTitle => 'Seat map access denied';

  @override
  String get ticketSeatMapAccessMessage =>
      'This fixture is not available for the current club account.';

  @override
  String get ticketSeatMapSecurityTitle => 'Seat map security check timed out';

  @override
  String get ticketSeatMapSecurityMessage =>
      'The fixture could not be confirmed safely. Try again.';

  @override
  String get ticketSeatMapChangedTitle => 'Seat map changed';

  @override
  String get ticketSeatMapChangedMessage =>
      'Refresh the fixture before selecting a seat.';

  @override
  String get ticketRefreshSeatMapUpper => 'REFRESH SEAT MAP';

  @override
  String get ticketSeatMapLoadFailedTitle => 'Unable to load seat map';

  @override
  String get ticketSeatMapLoadFailedMessage =>
      'The fixture could not be confirmed. Try again.';

  @override
  String get ticketSavedSeatMapTitle => 'Showing saved seat map';

  @override
  String get ticketSavedSeatMapMessage =>
      'Seat availability may have changed. Reconnect before confirming.';

  @override
  String get ticketRefreshingSeatMapTitle => 'Refreshing seat map';

  @override
  String get ticketRefreshingSeatMapMessage =>
      'The last confirmed fixture remains visible.';

  @override
  String get ticketLastConfirmedStandsMessage =>
      'These are the last confirmed stands. Refresh before selecting.';

  @override
  String get ticketSeatMapCheckTimedOutTitle => 'Seat map check timed out';

  @override
  String get ticketSeatAccessChangedTitle => 'Seat access changed';

  @override
  String get ticketSavedSeatMapReadOnlyMessage =>
      'The saved map is read-only. Return to the ticket to continue.';

  @override
  String get ticketSeatMapRefreshFailedTitle => 'Seat map refresh failed';

  @override
  String get ticketSelectedSeatUpper => 'SELECTED SEAT';

  @override
  String get ticketSeatMapSemantic => 'Interactive stadium seat map';

  @override
  String ticketSeatMapSelectedSemantic(String seat) {
    return 'Interactive stadium seat map, selected $seat';
  }

  @override
  String get ticketSeatMapHint => 'Tap a stand to select a seat';

  @override
  String ticketSelectedStandSemantic(String stand) {
    return 'Selected $stand stand';
  }

  @override
  String ticketSelectStandSemantic(String stand) {
    return 'Select $stand stand';
  }

  @override
  String ticketSeatCode(String stand, int number) {
    return '$stand, Seat $number';
  }

  @override
  String get ticketStandVipGold => 'VIP Gold';

  @override
  String get ticketStandEast => 'East Stand';

  @override
  String get ticketStandTribuneRed => 'Tribune Red';

  @override
  String get ticketStandStanding => 'Standing';

  @override
  String get ticketLegendVip => 'VIP';

  @override
  String get ticketLegendTribune => 'Tribune';

  @override
  String get contributionsClubProjectsTitle => 'CLUB PROJECTS';

  @override
  String get contributionsProjectsUnavailableTitle => 'Projects unavailable';

  @override
  String get contributionsProjectsUnavailableMessage =>
      'Club projects are temporarily unavailable.';

  @override
  String get contributionsProjectFallback => 'Project';

  @override
  String contributionsFundingProgress(String current, String target) {
    return '$current / $target';
  }

  @override
  String contributionsSupporters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count supporters',
      one: '1 supporter',
      zero: 'No supporters',
    );
    return '$_temp0';
  }

  @override
  String get contributionsContributeAction => 'Contribute';

  @override
  String get contributionsCommunitiesTitle => 'Communities';

  @override
  String get contributionsCommunitiesLoadError =>
      'Could not load public communities right now.';

  @override
  String get contributionsInitiatives => 'Initiatives';

  @override
  String get contributionsContributed => 'Contributed';

  @override
  String get contributionsActiveInitiatives => 'Active initiatives';

  @override
  String get contributionsCommunitiesUnavailableTitle =>
      'Communities unavailable';

  @override
  String get contributionsCommunityQuietTitle => 'Community board is quiet';

  @override
  String get contributionsCommunityQuietMessage =>
      'Public contribution communities will appear here when the club opens the next supporter initiative.';

  @override
  String get contributionsPublicGroupFallback => 'Public group';

  @override
  String contributionsContributors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contributors',
      one: '1 contributor',
      zero: 'No contributors',
    );
    return '$_temp0';
  }

  @override
  String contributionsGoalPercent(int percent) {
    return '$percent% of goal';
  }

  @override
  String get contributionsConnectToLoad =>
      'Connect to load contribution initiatives.';

  @override
  String get contributionsInitiativesUnavailableMessage =>
      'Contribution initiatives are temporarily unavailable.';

  @override
  String get contributionsSmsEnabled =>
      'MoMo SMS sync enabled for this device.';

  @override
  String get contributionsSmsPermissionDenied =>
      'SMS access was not granted. Sync remains off.';

  @override
  String get contributionsSmsEnableFailed =>
      'Could not enable SMS sync. Check your permissions and try again.';

  @override
  String get contributionsSmsDisabled => 'MoMo SMS sync disabled.';

  @override
  String get contributionsConnectBeforeSmsSync =>
      'Connect before syncing MoMo messages.';

  @override
  String contributionsSmsSyncComplete(int uploaded, int duplicates) {
    return 'SMS sync complete: $uploaded uploaded, $duplicates duplicates.';
  }

  @override
  String get contributionsSmsSyncFailed =>
      'SMS sync failed. Check your connection and try again.';

  @override
  String get contributionsHubTitle => 'CONTRIBUTE';

  @override
  String get contributionsRefreshingTitle => 'Refreshing contributions';

  @override
  String get contributionsRefreshingMessage =>
      'Current totals and initiatives are being checked.';

  @override
  String get contributionsSavedTitle => 'Saved contribution data';

  @override
  String get contributionsSavedMessage =>
      'Totals may be out of date. Reconnect before making or syncing a contribution.';

  @override
  String get contributionsTeamProjects => 'TEAM PROJECTS';

  @override
  String contributionsRaised(String current, String target) {
    return '$current of $target raised.';
  }

  @override
  String contributionsOpenMetric(int count) {
    return '$count OPEN';
  }

  @override
  String get contributionsCommunitiesUpper => 'COMMUNITIES';

  @override
  String contributionsInitiativesActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count initiatives are active.',
      one: '1 initiative is active.',
    );
    return '$_temp0';
  }

  @override
  String contributionsLiveMetric(int count) {
    return '$count LIVE';
  }

  @override
  String get contributionsCommunityUpper => 'COMMUNITY';

  @override
  String get contributionsFanClubsChapters => 'Fan clubs & local chapters.';

  @override
  String get contributionsLive => 'LIVE';

  @override
  String get contributionsMomoSmsSync => 'MoMo SMS sync';

  @override
  String get contributionsUnavailableBuild => 'Unavailable in this build.';

  @override
  String get contributionsActiveUpper => 'ACTIVE';

  @override
  String get contributionsSyncing => 'Syncing…';

  @override
  String get contributionsSyncNow => 'Sync now';

  @override
  String get contributionsDisable => 'Disable';

  @override
  String get contributionsEnabling => 'Enabling…';

  @override
  String get contributionsEnableSmsSync => 'Enable SMS sync';

  @override
  String get contributionsLiveCampaigns => 'Live campaigns';

  @override
  String get contributionsGroupsUnavailableTitle => 'Groups unavailable';

  @override
  String get contributionsGroupFallback => 'Group';

  @override
  String contributionsAmountOfTarget(String current, String target) {
    return '$current of $target';
  }

  @override
  String get contributionsSeeAllGroups => 'See all contribution groups';

  @override
  String contributionsSeeAllGroupsSemantic(int count) {
    return 'See all $count contribution groups';
  }

  @override
  String get contributionsOpenGroupsHint => 'Open contribution groups';

  @override
  String contributionsSeeAll(int count) {
    return 'See all $count';
  }

  @override
  String get contributionsInitiativeTitle => 'PUBLIC INITIATIVE';

  @override
  String get contributionsInitiativeLoadingTitle => 'Loading public initiative';

  @override
  String get contributionsInitiativeLoadingMessage =>
      'Checking the confirmed total and public contribution ledger.';

  @override
  String get contributionsRefresh => 'Refresh';

  @override
  String get contributionsBackToCommunities => 'Back to communities';

  @override
  String get contributionsInitiativeRefreshingTitle => 'Refreshing initiative';

  @override
  String get contributionsInitiativeRefreshingMessage =>
      'Keeping the last confirmed total and ledger visible while new activity is checked.';

  @override
  String get contributionsReadOnlyTitle => 'Contributions are read-only';

  @override
  String get contributionsReadOnlyMessage =>
      'Confirmed public activity remains visible, but starting a payment is disabled for this build.';

  @override
  String get contributionsSavedInitiativeTitle =>
      'Showing saved initiative data';

  @override
  String get contributionsSavedInitiativeMessage =>
      'Reconnect and refresh before starting a payment or relying on the latest total.';

  @override
  String get contributionsRefreshInitiativeUpper => 'REFRESH INITIATIVE';

  @override
  String get contributionsClosedTitle => 'Contributions are closed';

  @override
  String get contributionsClosedMessage =>
      'The confirmed total and public ledger remain available for review.';

  @override
  String get contributionsPaymentRouteUnavailableTitle =>
      'Payment route unavailable';

  @override
  String get contributionsPaymentRouteUnavailableMessage =>
      'No payment will start until the club publishes a verified recipient.';

  @override
  String get contributionsDisabled => 'Contributions disabled';

  @override
  String get contributionsClosed => 'Contributions closed';

  @override
  String get contributionsPaymentUnavailable => 'Payment unavailable';

  @override
  String get contributionsCheckingLatestTotal => 'Checking latest total';

  @override
  String get contributionsRefreshBeforeContributing =>
      'Refresh before contributing';

  @override
  String get contributionsContributeNow => 'Contribute now';

  @override
  String get contributionsConfirmedTotal => 'Confirmed total';

  @override
  String contributionsTargetProgress(String target, int percent) {
    return 'Target $target · $percent%';
  }

  @override
  String contributionsProgressSemantic(int percent) {
    return '$percent percent of the contribution target confirmed';
  }

  @override
  String get contributionsTypeUpper => 'TYPE';

  @override
  String get contributionsContributorsUpper => 'CONTRIBUTORS';

  @override
  String contributionsContributeToSemantic(String group) {
    return 'Contribute to $group';
  }

  @override
  String contributionsPaymentUnavailableSemantic(String action) {
    return '$action. Payment is unavailable.';
  }

  @override
  String get contributionsPublicLedgerTitle => 'PUBLIC LEDGER';

  @override
  String get contributionsPublicLedgerPrivacy =>
      'Public supporter aliases only. Payment references and account details are never shown.';

  @override
  String get contributionsLedgerEmptyTitle => 'No contributions yet';

  @override
  String get contributionsLedgerEmptyMessage =>
      'Confirmed public activity will appear here without exposing payment details.';

  @override
  String contributionsMetaSemantic(String label, String value) {
    return '$label, $value';
  }

  @override
  String contributionsLedgerEntrySemantic(
    String alias,
    String amount,
    String status,
    String date,
  ) {
    return '$alias, $amount, $status, $date';
  }

  @override
  String get contributionsStatusConfirmed => 'CONFIRMED';

  @override
  String get contributionsStatusProcessing => 'PROCESSING';

  @override
  String get contributionsStatusFailed => 'FAILED';

  @override
  String get contributionsTypeProject => 'TEAM PROJECT';

  @override
  String get contributionsTypeCommunity => 'COMMUNITY';

  @override
  String get contributionsConnectionRestoredTitle => 'Connection restored';

  @override
  String get contributionsInitiativeOfflineTitle => 'Initiative offline';

  @override
  String get contributionsConnectionRestoredMessage =>
      'Refresh to check the latest confirmed total and public ledger.';

  @override
  String get contributionsInitiativeOfflineMessage =>
      'Reconnect to load this public initiative.';

  @override
  String get contributionsInitiativeNotFoundTitle => 'Initiative not found';

  @override
  String get contributionsInitiativeNotFoundMessage =>
      'This contribution initiative may have closed or the link may no longer be valid.';

  @override
  String get contributionsInitiativeUnavailableTitle =>
      'Initiative unavailable';

  @override
  String get contributionsInitiativeAccessMessage =>
      'Your current club access does not allow this contribution initiative.';

  @override
  String get contributionsInitiativeChangedTitle => 'Initiative changed';

  @override
  String get contributionsInitiativeChangedMessage =>
      'Refresh and review the latest total before starting a contribution.';

  @override
  String get contributionsInitiativeTimeoutTitle =>
      'Initiative check timed out';

  @override
  String get contributionsInitiativeTimeoutMessage =>
      'No total was confirmed. Refresh before starting a contribution.';

  @override
  String get contributionsInitiativeUnavailableMessage =>
      'Refresh and try again when the public ledger is available.';

  @override
  String get contributionsEmptyCsvCopied => 'Empty CSV copied to clipboard.';

  @override
  String get contributionsCsvCopied => 'Privacy-safe CSV copied to clipboard.';

  @override
  String get contributionsStatementTitle => 'PUBLIC STATEMENT';

  @override
  String get contributionsStatementLoadingTitle => 'Loading public statement';

  @override
  String get contributionsStatementLoadingMessage =>
      'Checking confirmed contributions and privacy-safe supporter aliases.';

  @override
  String get contributionsBackToInitiative => 'Back to initiative';

  @override
  String get contributionsStatementRefreshingTitle => 'Refreshing statement';

  @override
  String get contributionsStatementRefreshingMessage =>
      'Keeping the last confirmed statement visible while new activity is checked.';

  @override
  String get contributionsStatementReadOnlyTitle =>
      'Statement export is read-only';

  @override
  String get contributionsStatementReadOnlyMessage =>
      'You can review confirmed public entries, but copying a statement is disabled for this build.';

  @override
  String get contributionsSavedStatementTitle => 'Showing saved statement data';

  @override
  String get contributionsSavedStatementMessage =>
      'Reconnect and refresh before exporting or relying on the latest total.';

  @override
  String get contributionsRefreshStatementUpper => 'REFRESH STATEMENT';

  @override
  String get contributionsCopyCsvSemantic => 'Copy privacy-safe CSV statement';

  @override
  String contributionsExportUnavailableSemantic(String reason) {
    return 'Statement export unavailable. $reason';
  }

  @override
  String get contributionsFromUpper => 'FROM';

  @override
  String get contributionsToUpper => 'TO';

  @override
  String get contributionsAllTime => 'All time';

  @override
  String get contributionsNow => 'Now';

  @override
  String get contributionsSortUpper => 'SORT';

  @override
  String get contributionsSortDate => 'BY DATE';

  @override
  String get contributionsSortAmount => 'BY AMOUNT';

  @override
  String get contributionsSortAlias => 'BY ALIAS';

  @override
  String get contributionsPdf => 'PDF';

  @override
  String get contributionsCsv => 'CSV';

  @override
  String get contributionsComingSoon => 'Coming soon';

  @override
  String get contributionsClipboard => 'Clipboard';

  @override
  String get contributionsCopyingCsv => 'Copying CSV…';

  @override
  String get contributionsExportDisabled => 'Export disabled';

  @override
  String get contributionsCheckingLatestEntries => 'Checking latest entries';

  @override
  String get contributionsRefreshBeforeExporting => 'Refresh before exporting';

  @override
  String get contributionsCopyCsvStatement => 'Copy CSV statement';

  @override
  String contributionsStatementSummarySemantic(
    String group,
    int count,
    String total,
  ) {
    return '$group public statement, $count entries, confirmed total $total';
  }

  @override
  String get contributionsConfirmedTotalUpper => 'CONFIRMED TOTAL';

  @override
  String contributionsPublicEntriesInRange(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count public entries in this range',
      one: '1 public entry in this range',
    );
    return '$_temp0';
  }

  @override
  String get contributionsStatementPrivacy =>
      'Public supporter aliases only. Names, phone numbers, payment references, and account identifiers are excluded.';

  @override
  String contributionsFormatSemantic(String label, String helper) {
    return '$label export format, $helper';
  }

  @override
  String get contributionsPreviewUpper => 'PREVIEW';

  @override
  String contributionsPreviewShowing(int count) {
    return 'Showing 5 of $count entries. The CSV includes the full bounded range.';
  }

  @override
  String get contributionsPreviewPublicFields =>
      'The CSV includes only the public fields shown below.';

  @override
  String get contributionsNoStatementEntriesTitle => 'No statement entries';

  @override
  String get contributionsNoStatementEntriesMessage =>
      'No public contributions match this date range. Choose another range and refresh.';

  @override
  String get contributionsStatementOfflineTitle => 'Statement offline';

  @override
  String get contributionsStatementRestoredMessage =>
      'Refresh to check the latest confirmed public entries.';

  @override
  String get contributionsStatementOfflineMessage =>
      'Reconnect to load this public statement.';

  @override
  String get contributionsStatementNotFoundTitle => 'Statement not found';

  @override
  String get contributionsStatementNotFoundMessage =>
      'This initiative may have closed or the statement link may no longer be valid.';

  @override
  String get contributionsStatementUnavailableTitle => 'Statement unavailable';

  @override
  String get contributionsStatementAccessMessage =>
      'Your current club access does not allow this contribution statement.';

  @override
  String get contributionsStatementChangedTitle => 'Statement changed';

  @override
  String get contributionsStatementChangedMessage =>
      'Refresh and review the latest confirmed entries before exporting.';

  @override
  String get contributionsStatementTimeoutTitle => 'Statement check timed out';

  @override
  String get contributionsStatementTimeoutMessage =>
      'No current statement was confirmed. Refresh before exporting.';

  @override
  String get contributionsStatementUnavailableMessage =>
      'Refresh and try again when the public contribution ledger is available.';

  @override
  String get contributionsConnectBeforeContributing =>
      'Connect before contributing. No payment or contribution was submitted.';

  @override
  String get contributionsDialerFailed =>
      'Could not open the MOMO dialer. Contribution was not submitted.';

  @override
  String contributionsStatusAnnouncement(String heading, String message) {
    return '$heading. $message';
  }

  @override
  String get contributionsAmountPrompt => 'HOW MUCH TO CONTRIBUTE?';

  @override
  String contributionsQuickAmount(int thousands) {
    return '+${thousands}K';
  }

  @override
  String get contributionsLaunchMomoDialer => 'Launch MOMO dialer';

  @override
  String get contributionsLaunchingMomo => 'LAUNCHING MOMO';

  @override
  String get contributionsChangeAmount => 'Change amount';

  @override
  String get contributionsDialNow => 'Dial now';

  @override
  String get contributionsCancel => 'Cancel contribution';

  @override
  String get contributionsPaymentConfirmedTitle => 'PAYMENT CONFIRMED';

  @override
  String contributionsPaymentConfirmedMessage(String amount) {
    return 'Your contribution of $amount has been verified and recorded.';
  }

  @override
  String get contributionsPaymentFailedTitle => 'PAYMENT FAILED';

  @override
  String get contributionsPaymentFailedMessage =>
      'The payment could not be verified. Check your MoMo balance and try again, or contact support.';

  @override
  String get contributionsPaymentProcessingTitle => 'STILL PROCESSING';

  @override
  String get contributionsPaymentProcessingMessage =>
      'Your payment is taking longer than usual. Check the Group ledger for your updated status. If you completed the MoMo transfer, it will appear shortly.';

  @override
  String get contributionsRecordFailedTitle => 'COULD NOT RECORD';

  @override
  String get contributionsRecordFailedMessage =>
      'The MoMo dialer was launched but the contribution could not be saved. Return to the Group and try again.';

  @override
  String get contributionsAwaitingPaymentTitle => 'AWAITING PAYMENT';

  @override
  String get contributionsAwaitingPaymentMessage =>
      'Complete the MoMo payment on your phone. Your contribution appears as \"Processing\" until we receive confirmation.';

  @override
  String get contributionsCheckingPaymentStatus => 'Checking payment status…';

  @override
  String get contributionsVerifiedUpper => 'VERIFIED';

  @override
  String get contributionsDone => 'Done';

  @override
  String get contributionsBackToGroup => 'Back to group';

  @override
  String get contributionsEnableMomoSmsTitle => 'ENABLE MOMO SMS SYNC';

  @override
  String contributionsSmsPrivacyMessage(String app) {
    return '$app reads only MoMo confirmations to auto-log receipts. Other messages are not accessed.';
  }

  @override
  String get contributionsAllowSmsReading => 'Allow SMS reading';

  @override
  String get contributionsEnable => 'Enable';

  @override
  String get contributionsNotNowUpper => 'NOT NOW';
}
