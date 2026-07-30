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
}
