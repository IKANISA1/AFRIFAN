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
  String get searchFanZoneTitle => 'Predict';

  @override
  String get searchFanZoneDescription =>
      'Match picks, prediction history and FET activity.';

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
  String get navFanZone => 'Predict';

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
  String get clubOfflineTitle => 'Club information offline';

  @override
  String get clubOfflineMessage =>
      'Connect to load the latest official club information.';

  @override
  String get clubAccessDeniedTitle => 'Club information access denied';

  @override
  String get clubAccessDeniedMessage =>
      'This account cannot access the requested club information.';

  @override
  String get clubChangedTitle => 'Club information changed';

  @override
  String get clubChangedMessage =>
      'Official club information changed while loading. Refresh to confirm the latest version.';

  @override
  String get clubSecurityTimeoutTitle =>
      'Club information security check timed out';

  @override
  String get clubSecurityTimeoutMessage =>
      'The club information service did not respond in time. Refresh to try again.';

  @override
  String get clubRefreshingTitle => 'Refreshing club information';

  @override
  String get clubRefreshingMessage =>
      'Keeping the last confirmed club information visible while updates load.';

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
  String get authPhoneHint => 'Phone number';

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
  String get homeOpenFanZone => 'Open Predict';

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
  String get homeFanZoneAction => 'Predict';

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
  String get fanClubBackToSupporters => 'Back to supporters';

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
  String get fanClubActive => 'Active';

  @override
  String get fanClubPendingReview => 'Pending review';

  @override
  String fanClubCurrentSemantic(String name) {
    return 'Current fan club, $name';
  }

  @override
  String get fanClubAboutTitle => 'About this club';

  @override
  String fanClubRegionValue(String region) {
    return 'Region: $region';
  }

  @override
  String get fanClubSnapshotTitle => 'Group snapshot';

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
  String get fanClubRefreshAction => 'Refresh club';

  @override
  String get fanClubTryAgainAction => 'Try again';

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
  String get fanClubMatchdayAgenda => 'Matchday agenda';

  @override
  String fanClubMatchMeta(String competition, String venue) {
    return '$competition  •  $venue';
  }

  @override
  String fanClubMatchSchedule(String date, String time) {
    return '$date  •  $time';
  }

  @override
  String get fanClubMembersLabel => 'Members';

  @override
  String get fanClubStatusLabel => 'Status';

  @override
  String get fanClubRegionLabel => 'Region';

  @override
  String get fanClubOpenSupportersSemantic => 'Open Supporters area';

  @override
  String get fanClubPendingReviewSemantic => 'Fan club pending review';

  @override
  String get fanClubSupportersAction => 'Supporters';

  @override
  String get fanClubOpenSupportersAction => 'Open supporters';

  @override
  String get fanClubCopyLink => 'Copy link';

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
  String get fanClubsCommunityEyebrow => 'The community';

  @override
  String get fanClubsTitle => 'Fan clubs';

  @override
  String get fanClubsSearchHint => 'Search clubs or locations';

  @override
  String get fanClubsFeaturedChapter => 'Featured chapter';

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
  String get liveStatusHalfTime => 'Half-time';

  @override
  String get liveStatusFullTime => 'Full-time';

  @override
  String get liveStatusPostponed => 'Postponed';

  @override
  String get liveStatusCancelled => 'Cancelled';

  @override
  String get liveStatusUpcoming => 'Upcoming';

  @override
  String get liveStatusFinal => 'Final';

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
  String get liveMatchReport => 'Match report';

  @override
  String get liveMatchFinishedPending => 'Match finished. Summary pending.';

  @override
  String get liveMatchdayIntel => 'Matchday intel';

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
  String get liveCenterUnavailable => 'Live center unavailable';

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
  String get newsRefreshArticle => 'Refresh article';

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
  String get shopOutOfStockUpper => 'Out of stock';

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
  String get shopLoadingBadge => 'Loading';

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
  String get shopOfficialBadge => 'Official';

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
  String get ticketDateLabel => 'Date';

  @override
  String get ticketTimeLabel => 'Time';

  @override
  String get ticketVenueLabel => 'Venue';

  @override
  String get ticketAppleWallet => 'Apple Wallet';

  @override
  String get ticketGoogleWallet => 'Google Wallet';

  @override
  String get ticketWalletExportUnavailable =>
      'Wallet export is not available in this release yet.';

  @override
  String get ticketGoogleWalletChecking =>
      'Checking Google Wallet availability…';

  @override
  String get ticketGoogleWalletReady =>
      'Your confirmed ticket can be added to Google Wallet.';

  @override
  String get ticketGoogleWalletAdding => 'Adding to Google Wallet…';

  @override
  String get ticketGoogleWalletAdded => 'Added to Google Wallet';

  @override
  String get ticketGoogleWalletAddingMessage =>
      'Preparing the secure Wallet pass and opening Google Wallet.';

  @override
  String get ticketGoogleWalletAddedMessage =>
      'Google Wallet confirmed that the pass was saved.';

  @override
  String get ticketGoogleWalletCancelled =>
      'The Google Wallet save was cancelled. Your ticket remains available here.';

  @override
  String get ticketGoogleWalletUnavailable =>
      'Google Wallet is not available on this device or account.';

  @override
  String get ticketGoogleWalletOnlineRequired =>
      'Reconnect before adding this ticket to Google Wallet.';

  @override
  String get ticketGoogleWalletPaymentPending =>
      'Payment must be confirmed before this ticket can be added to Google Wallet.';

  @override
  String get ticketGoogleWalletPermissionDenied =>
      'This account cannot add the selected ticket to Google Wallet.';

  @override
  String get ticketGoogleWalletTimeout =>
      'The secure Wallet request timed out. No save is confirmed; try again.';

  @override
  String get ticketGoogleWalletFailed =>
      'The ticket could not be added to Google Wallet. Try again later.';

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
  String get ticketEntryCodeAccessChangedTitle => 'Ticket access changed';

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
  String get ticketRefreshUpper => 'Refresh ticket';

  @override
  String get ticketWalletUnavailableTitle => 'Ticket wallet unavailable';

  @override
  String get ticketWalletUnavailableMessage =>
      'We could not load your ticket wallet right now. Check your connection and try again.';

  @override
  String get ticketMyTickets => 'My tickets';

  @override
  String get ticketRefreshTickets => 'Refresh tickets';

  @override
  String get ticketUpcoming => 'Upcoming';

  @override
  String get ticketPast => 'Past';

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
  String get ticketCheckoutSummary => 'Checkout summary';

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
  String get ticketConfirmPurchase => 'Confirm purchase';

  @override
  String get ticketMatchUpper => 'Match';

  @override
  String get ticketZoneUpper => 'Zone';

  @override
  String get ticketSeatUpper => 'Seat';

  @override
  String get ticketQuantityUpper => 'Quantity';

  @override
  String get ticketServiceFeeUpper => 'Service fee';

  @override
  String get ticketTotalUpper => 'Total';

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
  String get ticketChooseAccess => 'Choose access';

  @override
  String get ticketGeneral => 'General';

  @override
  String get ticketGeneralSubtitle => 'Open stands / Bleachers area';

  @override
  String get ticketVip => 'VIP';

  @override
  String get ticketVipSubtitle => 'Premium lounge seating';

  @override
  String get ticketChooseSeat => 'Choose specific seat';

  @override
  String get ticketChangeSeat => 'Change selected seat';

  @override
  String get ticketReview => 'Review';

  @override
  String get ticketReviewReservation => 'Review reservation';

  @override
  String get ticketOfficialCategories => 'Official categories';

  @override
  String get ticketOfficialCategoriesMessage =>
      'Approved public ticket tiers. Sale-specific availability appears when the club activates an official sale.';

  @override
  String get ticketListTitle => 'Tickets';

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
  String get ticketNext => 'Next';

  @override
  String get ticketMine => 'Mine';

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
  String get ticketStatusSoldOut => 'Sold out';

  @override
  String get ticketStatusAvailable => 'Available';

  @override
  String get ticketFrom => 'From';

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
  String get ticketMatchDay => 'Match day';

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
  String get ticketTryAgainUpper => 'Try again';

  @override
  String get ticketRefreshFixtureUpper => 'Refresh fixture';

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
  String get ticketAccessChangedTitle => 'Ticket access changed';

  @override
  String get ticketSavedFixtureReadOnlyMessage =>
      'The saved fixture is read-only. Return to Tickets to continue safely.';

  @override
  String get ticketFixtureRefreshFailedTitle => 'Fixture refresh failed';

  @override
  String get ticketSeatMapTitle => 'Select seat';

  @override
  String get ticketConfirm => 'Confirm';

  @override
  String get ticketSeatSelectionUnavailableTitle =>
      'Seat selection unavailable';

  @override
  String get ticketSeatSelectionUnavailableMessage =>
      'Seat selection is not enabled for this build or club.';

  @override
  String get ticketBackToTicketUpper => 'Back to ticket';

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
  String get ticketRefreshSeatMapUpper => 'Refresh seat map';

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
  String get ticketSelectedSeatUpper => 'Selected seat';

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
  String get contributionsClubProjectsTitle => 'Club projects';

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
  String get contributionsHubTitle => 'Contribute';

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
  String get contributionsTeamProjects => 'Team projects';

  @override
  String contributionsRaised(String current, String target) {
    return '$current of $target raised.';
  }

  @override
  String contributionsOpenMetric(int count) {
    return '$count OPEN';
  }

  @override
  String get contributionsCommunitiesUpper => 'Communities';

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
  String get contributionsCommunityUpper => 'Community';

  @override
  String get contributionsFanClubsChapters => 'Fan clubs & local chapters.';

  @override
  String get contributionsLive => 'LIVE';

  @override
  String get contributionsMomoSmsSync => 'MoMo SMS sync';

  @override
  String get contributionsUnavailableBuild => 'Unavailable in this build.';

  @override
  String get contributionsActiveUpper => 'Active';

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
  String get contributionsInitiativeTitle => 'Public initiative';

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
  String get contributionsRefreshInitiativeUpper => 'Refresh initiative';

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
  String get contributionsTypeUpper => 'Type';

  @override
  String get contributionsContributorsUpper => 'Contributors';

  @override
  String contributionsContributeToSemantic(String group) {
    return 'Contribute to $group';
  }

  @override
  String contributionsPaymentUnavailableSemantic(String action) {
    return '$action. Payment is unavailable.';
  }

  @override
  String get contributionsPublicLedgerTitle => 'Public ledger';

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
  String get contributionsStatusConfirmed => 'Confirmed';

  @override
  String get contributionsStatusProcessing => 'Processing';

  @override
  String get contributionsStatusFailed => 'Failed';

  @override
  String get contributionsTypeProject => 'Team project';

  @override
  String get contributionsTypeCommunity => 'Community';

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
  String get contributionsStatementTitle => 'Public statement';

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
  String get contributionsRefreshStatementUpper => 'Refresh statement';

  @override
  String get contributionsCopyCsvSemantic => 'Copy privacy-safe CSV statement';

  @override
  String contributionsExportUnavailableSemantic(String reason) {
    return 'Statement export unavailable. $reason';
  }

  @override
  String get contributionsFromUpper => 'From';

  @override
  String get contributionsToUpper => 'To';

  @override
  String get contributionsAllTime => 'All time';

  @override
  String get contributionsNow => 'Now';

  @override
  String get contributionsSortUpper => 'Sort';

  @override
  String get contributionsSortDate => 'By date';

  @override
  String get contributionsSortAmount => 'By amount';

  @override
  String get contributionsSortAlias => 'By alias';

  @override
  String get contributionsPdf => 'Pdf';

  @override
  String get contributionsCsv => 'Csv';

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
  String get contributionsConfirmedTotalUpper => 'Confirmed total';

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
  String get contributionsPreviewUpper => 'Preview';

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
  String get contributionsAmountPrompt => 'How much to contribute?';

  @override
  String contributionsQuickAmount(int thousands) {
    return '+${thousands}K';
  }

  @override
  String get contributionsLaunchMomoDialer => 'Launch MOMO dialer';

  @override
  String get contributionsLaunchingMomo => 'Launching MoMo';

  @override
  String get contributionsChangeAmount => 'Change amount';

  @override
  String get contributionsDialNow => 'Dial now';

  @override
  String get contributionsCancel => 'Cancel contribution';

  @override
  String get contributionsPaymentConfirmedTitle => 'Payment confirmed';

  @override
  String contributionsPaymentConfirmedMessage(String amount) {
    return 'Your contribution of $amount has been verified and recorded.';
  }

  @override
  String get contributionsPaymentFailedTitle => 'Payment failed';

  @override
  String get contributionsPaymentFailedMessage =>
      'The payment could not be verified. Check your MoMo balance and try again, or contact support.';

  @override
  String get contributionsPaymentProcessingTitle => 'Still processing';

  @override
  String get contributionsPaymentProcessingMessage =>
      'Your payment is taking longer than usual. Check the Group ledger for your updated status. If you completed the MoMo transfer, it will appear shortly.';

  @override
  String get contributionsRecordFailedTitle => 'Could not record';

  @override
  String get contributionsRecordFailedMessage =>
      'The MoMo dialer was launched but the contribution could not be saved. Return to the Group and try again.';

  @override
  String get contributionsAwaitingPaymentTitle => 'Awaiting payment';

  @override
  String get contributionsAwaitingPaymentMessage =>
      'Complete the MoMo payment on your phone. Your contribution appears as \"Processing\" until we receive confirmation.';

  @override
  String get contributionsCheckingPaymentStatus => 'Checking payment status…';

  @override
  String get contributionsVerifiedUpper => 'Verified';

  @override
  String get contributionsDone => 'Done';

  @override
  String get contributionsBackToGroup => 'Back to group';

  @override
  String get contributionsEnableMomoSmsTitle => 'Enable MoMo SMS sync';

  @override
  String contributionsSmsPrivacyMessage(String app) {
    return '$app reads only MoMo confirmations to auto-log receipts. Other messages are not accessed.';
  }

  @override
  String get contributionsAllowSmsReading => 'Allow SMS reading';

  @override
  String get contributionsEnable => 'Enable';

  @override
  String get contributionsNotNowUpper => 'Not now';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsRoleAdmin => 'Admin';

  @override
  String get settingsRoleSupporter => 'Supporter';

  @override
  String get settingsMembershipDetails => 'Membership details';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsSectionPreferences => 'Preferences';

  @override
  String get settingsSectionSupport => 'Support';

  @override
  String get settingsEditProfile => 'Edit profile';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsHelpSupport => 'Help & support';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsRefreshingTitle => 'Refreshing settings';

  @override
  String get settingsRefreshingMessage =>
      'Current account and appearance settings stay available.';

  @override
  String get settingsOfflineTitle => 'Offline settings';

  @override
  String get settingsOfflineMessage =>
      'Offline. Account and appearance settings remain available. Reconnect for support.';

  @override
  String get settingsHelpUnavailableTitle => 'Help and support unavailable';

  @override
  String get settingsSupportContactUnavailableTitle =>
      'Support contact unavailable';

  @override
  String get settingsSupportContactUnavailableMessage =>
      'Other settings still work. Refresh to check again.';

  @override
  String get settingsLoadingTitle => 'Loading settings';

  @override
  String get settingsLoadingMessage => 'Checking support availability.';

  @override
  String get settingsAccessLimitedTitle => 'Settings access limited';

  @override
  String get settingsAccessLimitedMessage =>
      'Support could not be verified. Other settings still work.';

  @override
  String get settingsChangedTitle => 'Settings changed';

  @override
  String get settingsChangedMessage =>
      'Refresh to load the current support settings.';

  @override
  String get settingsSecurityTimeoutTitle =>
      'Settings security check timed out';

  @override
  String get settingsSecurityTimeoutMessage =>
      'Check your connection and refresh.';

  @override
  String get settingsSupportLoadFailedTitle =>
      'Could not load support settings';

  @override
  String get settingsSupportLoadFailedMessage =>
      'Account and appearance settings remain available.';

  @override
  String get settingsChecking => 'Checking…';

  @override
  String get settingsConnectionRequired => 'Connection required';

  @override
  String get settingsUnavailable => 'Unavailable';

  @override
  String get settingsNotConfigured => 'Not configured';

  @override
  String get settingsStatusUnavailable => 'Status unavailable';

  @override
  String get settingsThemeUseDevice => 'Use device setting';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsAppearanceMessage =>
      'Choose a theme or follow your device setting.';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsSupportNotConfigured =>
      'Support contact is not configured.';

  @override
  String settingsSupportGreeting(String app) {
    return 'Hi, I need help with $app.';
  }

  @override
  String get settingsWhatsAppFailed => 'Could not open WhatsApp.';

  @override
  String get settingsDeleteAccountTitle => 'DELETE your account?';

  @override
  String get settingsDeleteAccountMessage =>
      'Permanently deletes your profile, FET, badges, and history. Cannot be undone.';

  @override
  String get settingsDeleteAccountConfirmPrompt => 'Type DELETE to confirm';

  @override
  String get settingsDeleteAccountConfirmValue => 'DELETE';

  @override
  String get settingsCancelUpper => 'Cancel';

  @override
  String get settingsDeletePermanently => 'Delete permanently';

  @override
  String get settingsNotificationPermissionTitle => 'Stay with the club';

  @override
  String get settingsNotificationPermissionMessage =>
      'Get notified for matches, contributions, FET milestones, and club news.';

  @override
  String get settingsMatchAlerts => 'Match alerts before kickoff';

  @override
  String get settingsContributionUpdates => 'Contribution and ticket updates';

  @override
  String get settingsFetMilestones => 'FET milestones and challenge drops';

  @override
  String get settingsEnableNotifications => 'Enable notifications';

  @override
  String get settingsMaybeLaterUpper => 'Maybe later';

  @override
  String get settingsSignOutTitle => 'Sign out?';

  @override
  String get settingsSignOutMessage =>
      'Your profile and FET are saved. Sign back in anytime.';

  @override
  String get settingsStay => 'Stay';

  @override
  String get settingsSignOutOthersTitle => 'Sign out other devices?';

  @override
  String get settingsSignOutOthersMessage =>
      'This device stays signed in. Other sessions are revoked.';

  @override
  String get settingsSignOutOthersAction => 'Sign out others';

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get editProfileUpdated => 'Profile updated.';

  @override
  String get editProfileServiceUnavailable =>
      'Profile service is temporarily unavailable.';

  @override
  String get editProfileLoadingTitle => 'Loading profile';

  @override
  String get editProfileLoadingMessage => 'Checking your saved profile.';

  @override
  String get editProfileAccessLimitedTitle => 'Profile access limited';

  @override
  String get editProfileAccessLimitedMessage =>
      'Your profile could not be verified. Sign in again.';

  @override
  String get editProfileSignInAgain => 'Sign in again';

  @override
  String get editProfileChangedTitle => 'Profile changed';

  @override
  String get editProfileChangedMessage =>
      'Refresh to load the current profile before editing.';

  @override
  String get editProfileRefresh => 'Refresh';

  @override
  String get editProfileSecurityTimeoutTitle =>
      'Profile security check timed out';

  @override
  String get editProfileSecurityTimeoutMessage =>
      'Check your connection and refresh.';

  @override
  String get editProfileLoadFailedTitle => 'Could not load profile';

  @override
  String get editProfileLoadFailedMessage =>
      'Your profile is still safe. Try again.';

  @override
  String get editProfileTryAgain => 'Try again';

  @override
  String get editProfileTitle => 'Profile';

  @override
  String get editProfileSavingTitle => 'Saving profile';

  @override
  String get editProfileSavingMessage =>
      'Your nickname stays visible while the save is confirmed.';

  @override
  String get editProfileRefreshingTitle => 'Refreshing profile';

  @override
  String get editProfileRefreshingMessage =>
      'Your saved profile stays visible.';

  @override
  String get editProfileEditingUnavailableTitle =>
      'Profile editing unavailable';

  @override
  String get editProfileEditingUnavailableMessage =>
      'Your saved profile stays visible.';

  @override
  String get editProfileChangedElsewhereTitle => 'Profile changed elsewhere';

  @override
  String get editProfileChangedElsewhereMessage =>
      'Latest nickname loaded. Review before saving.';

  @override
  String get editProfileSaveUnconfirmedTitle => 'Profile save not confirmed';

  @override
  String get editProfileSaveUnconfirmedMessage =>
      'Refresh your profile before trying again.';

  @override
  String get editProfileSaveFailedTitle => 'Profile could not be saved';

  @override
  String get editProfileSaveFailedMessage =>
      'Your nickname draft is still here.';

  @override
  String get editProfileOfflineTitle => 'Offline profile';

  @override
  String get editProfileOfflineMessage =>
      'Offline. Your saved profile stays visible. Reconnect to edit.';

  @override
  String get editProfileUnavailableTitle => 'Profile unavailable';

  @override
  String get editProfileUnavailableMessage =>
      'Your profile is unavailable. Sign in again to recover your account.';

  @override
  String editProfileAlias(String alias) {
    return '#$alias';
  }

  @override
  String get editProfileNicknameLabel => 'Nickname';

  @override
  String get editProfileNicknameHint => 'Optional supporter nickname';

  @override
  String get editProfileSaving => 'Saving…';

  @override
  String get editProfileSaveChanges => 'Save changes';

  @override
  String get editProfileDeleteAccount => 'Delete account';

  @override
  String get editProfileDeleteHint =>
      'Permanently delete this supporter account';

  @override
  String get editProfileDeleteFailed =>
      'Account could not be deleted. Try again.';

  @override
  String get editProfileLanguageEnglish => 'English';

  @override
  String get notificationPreferencesConnectionRestoredReview =>
      'Connection restored. Review your kept changes, then save.';

  @override
  String get notificationPreferencesConnectionRestoredRefreshing =>
      'Connection restored. Refreshing preferences.';

  @override
  String get notificationPreferencesConnectBeforeChanging =>
      'Connect before changing notification delivery on this device.';

  @override
  String get notificationPreferencesDeviceTurnedOff =>
      'Device notifications were turned off. Save to update your account preference.';

  @override
  String get notificationPreferencesPermissionGranted =>
      'Permission granted on this device. Save to enable alerts on your account.';

  @override
  String get notificationPreferencesBlocked =>
      'Notifications blocked. Enable in device settings.';

  @override
  String get notificationPreferencesPermissionPending =>
      'Notification permission is still pending.';

  @override
  String get notificationPreferencesPushUnavailable =>
      'Push unavailable in this build.';

  @override
  String get notificationPreferencesDraftKeptConnect =>
      'Your changes are kept. Connect before saving.';

  @override
  String get notificationPreferencesSaved => 'Notification preferences saved.';

  @override
  String get notificationPreferencesChangedElsewhereLoading =>
      'Preferences changed elsewhere. The latest version is loading; review it before saving again.';

  @override
  String get notificationPreferencesChangeNotPermitted =>
      'Notification changes are not permitted for this account.';

  @override
  String get notificationPreferencesChangedRefresh =>
      'Preferences changed elsewhere. Refresh before saving again.';

  @override
  String get notificationPreferencesSaveUnconfirmed =>
      'Notification save was not confirmed. Refresh before trying again.';

  @override
  String get notificationPreferencesSaveFailedDraftKept =>
      'Notification preferences could not be saved. Your draft is kept.';

  @override
  String get notificationPreferencesRefreshing =>
      'Refreshing notification preferences.';

  @override
  String get notificationPreferencesLoadingTitle => 'Loading notifications';

  @override
  String get notificationPreferencesLoadingMessage =>
      'Checking your saved delivery preference.';

  @override
  String get notificationPreferencesOfflineTitle => 'Notifications are offline';

  @override
  String get notificationPreferencesOfflineMessage =>
      'Connect to load your saved notification preference.';

  @override
  String get notificationPreferencesUnavailableTitle =>
      'Notification preferences unavailable';

  @override
  String get notificationPreferencesUnavailableMessage =>
      'Sign in to manage notification delivery.';

  @override
  String get notificationPreferencesAccessLimitedTitle =>
      'Notification access limited';

  @override
  String get notificationPreferencesAccessLimitedMessage =>
      'Your preferences could not be verified. Sign in again.';

  @override
  String get notificationPreferencesChangedTitle =>
      'Notification settings changed';

  @override
  String get notificationPreferencesChangedMessage =>
      'Refresh to load the current preference before editing.';

  @override
  String get notificationPreferencesSecurityTimeoutTitle =>
      'Notification security check timed out';

  @override
  String get notificationPreferencesSecurityTimeoutMessage =>
      'Check your connection and refresh.';

  @override
  String get notificationPreferencesLoadFailedTitle =>
      'Could not load notification settings.';

  @override
  String get notificationPreferencesLoadFailedMessage =>
      'Your saved preference is still safe. Try again.';

  @override
  String get notificationPreferencesSavingTitle =>
      'Saving notification preferences';

  @override
  String get notificationPreferencesSavingMessage =>
      'Your choices stay visible while the save is confirmed.';

  @override
  String get notificationPreferencesRefreshingTitle =>
      'Refreshing notification preferences';

  @override
  String get notificationPreferencesRefreshingMessage =>
      'Your saved delivery preference stays visible.';

  @override
  String get notificationPreferencesEditingUnavailableTitle =>
      'Notification editing unavailable';

  @override
  String get notificationPreferencesEditingUnavailableMessage =>
      'Your saved preference stays visible.';

  @override
  String get notificationPreferencesChangedElsewhereTitle =>
      'Notification settings changed elsewhere';

  @override
  String get notificationPreferencesChangedElsewhereMessage =>
      'Refresh and review the latest preference.';

  @override
  String get notificationPreferencesSaveNotConfirmedTitle =>
      'Notification save not confirmed';

  @override
  String get notificationPreferencesSaveNotConfirmedMessage =>
      'Refresh before trying again. Your draft is kept.';

  @override
  String get notificationPreferencesSaveFailedTitle =>
      'Notification preferences could not be saved';

  @override
  String get notificationPreferencesSaveFailedMessage =>
      'Your draft is still here.';

  @override
  String get notificationPreferencesSavedSettingsTitle =>
      'Saved notification settings';

  @override
  String get notificationPreferencesSavedSettingsMessage =>
      'Values may be out of date. Reconnect before changing or saving.';

  @override
  String get notificationPreferencesCheckingPermissionsTitle =>
      'Checking device permissions';

  @override
  String get notificationPreferencesCheckingPermissionsMessage =>
      'Delivery controls will be available after this check.';

  @override
  String get notificationPreferencesDeviceAlertsUnavailableTitle =>
      'Device alerts unavailable';

  @override
  String get notificationPreferencesDeviceAlertsUnavailableMessage =>
      'Push delivery is not configured in this build.';

  @override
  String get notificationPreferencesPermissionEnabled =>
      'System notifications are enabled on this device.';

  @override
  String get notificationPreferencesPermissionBlocked =>
      'System notifications are blocked at the device level.';

  @override
  String get notificationPreferencesPermissionNotRequested =>
      'Permission not yet requested.';

  @override
  String get notificationPreferencesPermissionNotConfigured =>
      'Push not configured in this build.';

  @override
  String get notificationPreferencesPermissionChecking =>
      'Checking device notification permissions…';

  @override
  String get notificationPreferencesTitle => 'Notifications';

  @override
  String get notificationPreferencesDeliverySection => 'Notification delivery';

  @override
  String get notificationPreferencesAlertsEnabled => 'Alerts enabled.';

  @override
  String get notificationPreferencesEnableAlertsDescription =>
      'Enable alerts for matches, receipts & updates.';

  @override
  String get notificationPreferencesDeviceDelivery => 'Device alert delivery';

  @override
  String get notificationPreferencesConnectionRequiredUpper =>
      'Connection required';

  @override
  String get notificationPreferencesDisableAlerts => 'Disable alerts';

  @override
  String get notificationPreferencesEnableAlerts => 'Enable alerts';

  @override
  String get notificationPreferencesDeliveryModel => 'Delivery model';

  @override
  String notificationPreferencesFullStream(String app) {
    return 'When alerts are enabled, this release delivers the full $app notification stream available for your account.';
  }

  @override
  String get notificationPreferencesPerCategory =>
      'Per-category tuning is not configurable on this build yet, so this switch controls the entire device delivery state.';

  @override
  String get notificationPreferencesSave => 'Save';

  @override
  String get privacySettingsConnectionRestoredReview =>
      'Connection restored. Review your kept changes, then save.';

  @override
  String get privacySettingsConnectionRestoredRefreshing =>
      'Connection restored. Refreshing privacy settings.';

  @override
  String get privacySettingsChangeReady => 'Privacy change ready to save.';

  @override
  String get privacySettingsDraftKeptConnect =>
      'Your changes are kept. Connect before saving.';

  @override
  String get privacySettingsSaved => 'Privacy settings saved.';

  @override
  String get privacySettingsChangedElsewhereLoading =>
      'Privacy settings changed elsewhere. The latest version is loading; review it before saving again.';

  @override
  String get privacySettingsChangeNotPermitted =>
      'Privacy changes are not permitted for this account.';

  @override
  String get privacySettingsChangedRefresh =>
      'Privacy settings changed elsewhere. Refresh before saving again.';

  @override
  String get privacySettingsSaveUnconfirmed =>
      'Privacy save was not confirmed. Refresh before trying again.';

  @override
  String get privacySettingsSaveFailedDraftKept =>
      'Privacy settings could not be saved. Your draft is kept.';

  @override
  String get privacySettingsRefreshing => 'Refreshing privacy settings.';

  @override
  String get privacySettingsConnectBeforeSigningOut =>
      'Connect before signing out other devices.';

  @override
  String get privacySettingsSessionsSignedOut =>
      'Other sessions were signed out.';

  @override
  String get privacySettingsSessionsSignOutFailed =>
      'Could not sign out other devices. Try again.';

  @override
  String get privacySettingsSessionSecurityTimeout =>
      'Session security check timed out. Try again.';

  @override
  String get privacySettingsSmsAccessRequired =>
      'SMS sync stays off until you grant Android SMS access for MoMo verification.';

  @override
  String get privacySettingsEnableMomoSmsTitle => 'Enable MoMo SMS sync';

  @override
  String get privacySettingsMomoSmsDisclosure =>
      'The app reads only approved Mobile Money verification SMS on this device to match contribution payments. It cannot access other messages.';

  @override
  String get privacySettingsNotNow => 'Not now';

  @override
  String get privacySettingsContinue => 'Continue';

  @override
  String get privacySettingsLoadingTitle => 'Loading privacy settings';

  @override
  String get privacySettingsLoadingMessage =>
      'Checking your saved privacy choices.';

  @override
  String get privacySettingsOfflineTitle => 'Privacy settings are offline';

  @override
  String get privacySettingsOfflineMessage =>
      'Connect to load your saved privacy choices.';

  @override
  String get privacySettingsUnavailableTitle => 'Privacy settings unavailable';

  @override
  String get privacySettingsUnavailableMessage =>
      'Sign in to review and manage your privacy choices.';

  @override
  String get privacySettingsAccessLimitedTitle => 'Privacy access limited';

  @override
  String get privacySettingsAccessLimitedMessage =>
      'Your privacy settings could not be verified. Sign in again.';

  @override
  String get privacySettingsChangedTitle => 'Privacy settings changed';

  @override
  String get privacySettingsChangedMessage =>
      'Refresh to load the current choices before editing.';

  @override
  String get privacySettingsSecurityTimeoutTitle =>
      'Privacy security check timed out';

  @override
  String get privacySettingsSecurityTimeoutMessage =>
      'Check your connection and refresh.';

  @override
  String get privacySettingsLoadFailedTitle =>
      'Could not load privacy settings.';

  @override
  String get privacySettingsLoadFailedMessage =>
      'Your saved choices are still safe. Try again.';

  @override
  String get privacySettingsSavingTitle => 'Saving privacy settings';

  @override
  String get privacySettingsSavingMessage =>
      'Your choices stay visible while the save is confirmed.';

  @override
  String get privacySettingsRefreshingTitle => 'Refreshing privacy settings';

  @override
  String get privacySettingsRefreshingMessage =>
      'Your saved choices stay visible.';

  @override
  String get privacySettingsEditingUnavailableTitle =>
      'Privacy editing unavailable';

  @override
  String get privacySettingsEditingUnavailableMessage =>
      'Your saved choices stay visible.';

  @override
  String get privacySettingsChangedElsewhereTitle =>
      'Privacy settings changed elsewhere';

  @override
  String get privacySettingsChangedElsewhereMessage =>
      'Refresh and review the latest choices.';

  @override
  String get privacySettingsSaveNotConfirmedTitle =>
      'Privacy save not confirmed';

  @override
  String get privacySettingsSaveNotConfirmedMessage =>
      'Refresh before trying again. Your draft is kept.';

  @override
  String get privacySettingsSaveFailedTitle =>
      'Privacy settings could not be saved';

  @override
  String get privacySettingsSaveFailedMessage => 'Your draft is still here.';

  @override
  String get privacySettingsSavedSettingsTitle => 'Saved privacy settings';

  @override
  String get privacySettingsSavedSettingsMessage =>
      'Values may be out of date. Reconnect before changing or saving.';

  @override
  String get privacySettingsEditingUnavailableBuildMessage =>
      'Your saved choices remain visible in this build.';

  @override
  String get privacySettingsTitle => 'Privacy';

  @override
  String get privacySettingsControls => 'Privacy controls';

  @override
  String get privacySettingsControlsDescription =>
      'Choose whether to share coarse, anonymous task events. Queries, contacts, account IDs, codes, messages, and exact payment values are never included.';

  @override
  String get privacySettingsMomoSmsSync => 'MoMo SMS sync';

  @override
  String get privacySettingsMomoSmsSyncDescription =>
      'Match approved Mobile Money verification SMS for faster contribution checks.';

  @override
  String get privacySettingsShareAnalytics => 'Share anonymous usage analytics';

  @override
  String get privacySettingsShareAnalyticsDescription =>
      'Help improve search, tickets, contributions, Fan Zone, and recovery flows.';

  @override
  String get privacySettingsAnalyticsFailClosed =>
      'Analytics stays off unless you opt in and the signed release has an approved analytics configuration.';

  @override
  String get privacySettingsNoChanges => 'No changes to save';

  @override
  String get privacySettingsSave => 'Save privacy settings';

  @override
  String get privacySettingsYourData => 'Your data';

  @override
  String get privacySettingsExportDescription =>
      'Request an account export through a configured support channel.';

  @override
  String get privacySettingsExportAction => 'Request data export';

  @override
  String privacySettingsExportWhatsAppMessage(String app) {
    return 'Data export request for $app. Please send me a copy of my account data.';
  }

  @override
  String privacySettingsExportEmailSubject(String app) {
    return '$app data export request';
  }

  @override
  String get privacySettingsExportEmailBody =>
      'Please send me a copy of my account data.';

  @override
  String get privacySettingsMailFailed => 'Could not open your mail app.';

  @override
  String get privacySettingsOpenPolicy => 'Open privacy policy';

  @override
  String get privacySettingsPolicyUnavailable => 'Privacy policy unavailable';

  @override
  String get privacySettingsPolicyNotAvailableYet =>
      'Privacy policy is not available yet.';

  @override
  String get privacySettingsActiveSessions => 'Active sessions';

  @override
  String get privacySettingsActiveSessionsDescription =>
      'Revoke other active sessions linked to your account.';

  @override
  String get privacySettingsSignOutOtherDevices => 'Sign out other devices';

  @override
  String get adminLoadingTitle => 'Loading admin workspace';

  @override
  String get adminLoadingMessage => 'Checking current club operations.';

  @override
  String get adminClubAdmin => 'Club admin';

  @override
  String get adminExit => 'Exit admin';

  @override
  String get adminCommandCenter => 'Command center';

  @override
  String get adminTotalUsers => 'Total users';

  @override
  String get adminActiveGroups => 'Active groups';

  @override
  String get adminTransactionsToday => 'Tx today';

  @override
  String get adminTicketsSold => 'Tickets sold';

  @override
  String get adminQuickActions => 'Quick actions';

  @override
  String get adminManageCms => 'Manage CMS';

  @override
  String get adminManageCmsDescription =>
      'News articles, banners, and content surfaces';

  @override
  String get adminCreateMatch => 'Create match';

  @override
  String get adminCreateMatchDescription =>
      'Fixture setup, zoning, and ticket controls';

  @override
  String get adminViewContributions => 'View contributions';

  @override
  String get adminViewContributionsDescription =>
      'Monitor club and community fundraising';

  @override
  String get adminSendNotification => 'Send notification';

  @override
  String get adminSendNotificationDescription =>
      'Tier, group, and all-fan push delivery';

  @override
  String get adminSettleFixtures => 'Settle fixtures';

  @override
  String get adminSettleFixturesDescription =>
      'Enter results and grade prediction markets';

  @override
  String get adminManageCompetitions => 'Manage competitions';

  @override
  String get adminManageCompetitionsDescription =>
      'Add, edit, and toggle supported leagues and cups';

  @override
  String get adminSmsSyncMonitor => 'SMS sync monitor';

  @override
  String get adminSmsSyncMonitorDescription =>
      'MoMo SMS ingestion pipeline health';

  @override
  String get adminFeatureManager => 'Feature manager';

  @override
  String get adminFeatureManagerDashboardDescription =>
      'Toggle features, visibility, and scheduling';

  @override
  String get adminRecentActivity => 'Recent activity';

  @override
  String get adminRecentActivityUnavailable => 'Recent activity unavailable';

  @override
  String get adminRecentActivityUnavailableMessage =>
      'Dashboard totals are current. Refresh to retry the activity feed.';

  @override
  String get adminNoRecentActivity => 'No recent activity';

  @override
  String get adminNoRecentActivityMessage =>
      'Current totals are confirmed. New club activity will appear here.';

  @override
  String get adminWorkspaceUnavailable => 'Admin workspace unavailable';

  @override
  String get adminMobileDisabledMessage =>
      'Mobile administration is disabled for this controlled build.';

  @override
  String get adminBackToSettings => 'Back to settings';

  @override
  String get adminWorkspaceOffline => 'Admin workspace offline';

  @override
  String get adminWorkspaceOfflineMessage =>
      'Reconnect before loading private club operations.';

  @override
  String get adminAccessUnavailable => 'Admin access unavailable';

  @override
  String get adminAccessUnavailableMessage =>
      'This account cannot view the current club administration workspace.';

  @override
  String get adminDataChanged => 'Admin data changed';

  @override
  String get adminDataChangedMessage =>
      'Refresh before continuing with current club operations.';

  @override
  String get adminSecurityTimeout => 'Security check timed out';

  @override
  String get adminSecurityTimeoutMessage =>
      'No admin data was shown. Check your connection and retry.';

  @override
  String get adminPrivateDataHiddenMessage =>
      'Private club data remains hidden. Try again.';

  @override
  String get adminRefreshingTitle => 'Refreshing admin workspace';

  @override
  String get adminRefreshingMessage =>
      'Showing the last confirmed dashboard while current data is checked.';

  @override
  String get adminRefreshTimedOut => 'Refresh timed out';

  @override
  String get adminCurrentRefreshUnavailable => 'Current refresh unavailable';

  @override
  String get adminLastConfirmedMessage =>
      'Showing the last confirmed dashboard. Actions are paused until refresh succeeds.';

  @override
  String get adminAccessRequired => 'Admin access required';

  @override
  String get adminAccessRequiredMessage =>
      'This workspace is limited to verified club administrators for the active club.';

  @override
  String get adminBack => 'Back';

  @override
  String get adminCancelUpper => 'Cancel';

  @override
  String get adminBackToAdmin => 'Back to admin';

  @override
  String adminVersus(String home, String away) {
    return '$home vs $away';
  }

  @override
  String adminMetricSemantic(String label, String value) {
    return '$label $value';
  }

  @override
  String get adminSettlementConfirmTitle => 'Settle this fixture?';

  @override
  String adminSettlementConfirmMessage(
    String home,
    int homeScore,
    int awayScore,
    String away,
  ) {
    return '$home $homeScore – $awayScore $away\n\nThis grades prediction markets and may trigger supporter rewards. Confirm only from the official result.';
  }

  @override
  String get adminSettlementSettleUpper => 'Settle';

  @override
  String adminSettlementReceipt(String score, int markets, int won, int lost) {
    return 'Settled $score • $markets markets • $won won • $lost lost';
  }

  @override
  String get adminSettlementReviewOfficialResult =>
      'Review the official result and try again.';

  @override
  String get adminSettlementNotConfirmed =>
      'Fixture settlement was not confirmed.';

  @override
  String get adminSettlementTitle => 'Settle fixtures';

  @override
  String get adminSettlementLoadingTitle => 'Loading settlement workspace';

  @override
  String get adminSettlementLoadingMessage =>
      'Checking controlled fixture information.';

  @override
  String get adminSettlementFilterScheduled => 'Scheduled';

  @override
  String get adminSettlementFilterFinished => 'Finished';

  @override
  String get adminSettlementFilterAll => 'All';

  @override
  String get adminSettlementControlTitle => 'Official result control';

  @override
  String get adminSettlementControlMessage =>
      'Settlement grades prediction markets and may trigger rewards. Use only an official, confirmed final score.';

  @override
  String get adminSettlementEmptyTitle => 'No fixtures in this view';

  @override
  String get adminSettlementEmptyMessage =>
      'Switch filters or wait for controlled fixture information.';

  @override
  String get adminSettlementVersusShort => 'Vs';

  @override
  String get adminSettlementOpenHint => 'Open official result confirmation';

  @override
  String get adminSettlementUnavailableHint => 'Settlement unavailable';

  @override
  String get adminSettlementEnterOfficialResult => 'Enter official result';

  @override
  String get adminSettlementPaused => 'Settlement paused';

  @override
  String get adminSettlementSettled => 'Settled';

  @override
  String get adminSettlementNotSettleable => 'Not settleable';

  @override
  String get adminSettlementManagementUnavailable =>
      'Settlement management unavailable';

  @override
  String get adminSettlementDisabledMessage =>
      'Settlement controls are disabled for this controlled build.';

  @override
  String get adminSettlementWorkspaceOffline => 'Settlement workspace offline';

  @override
  String get adminSettlementWorkspaceOfflineMessage =>
      'Reconnect before loading private fixture information.';

  @override
  String get adminSettlementAccessUnavailable =>
      'Settlement access unavailable';

  @override
  String get adminSettlementAccessUnavailableMessage =>
      'This account cannot view or settle prediction fixtures.';

  @override
  String get adminSettlementResultChanged => 'Fixture result changed';

  @override
  String get adminSettlementResultChangedMessage =>
      'Refresh before confirming another settlement.';

  @override
  String get adminSettlementSecurityTimeoutMessage =>
      'No fixture information was shown. Check your connection.';

  @override
  String get adminSettlementWorkspaceUnavailable =>
      'Settlement workspace unavailable';

  @override
  String get adminSettlementPrivateDataHidden =>
      'Private fixture information remains hidden. Try again.';

  @override
  String get adminSettlementCheckingResults => 'Checking fixture results';

  @override
  String get adminSettlementCheckingResultsMessage =>
      'Showing the last confirmed state while current data is checked.';

  @override
  String get adminSettlementOutcomeUnconfirmed =>
      'The last settlement is unconfirmed. Controls stay paused until refresh succeeds.';

  @override
  String get adminSettlementLastConfirmedMessage =>
      'Last confirmed fixture information remains visible. Controls are paused.';

  @override
  String get adminSettlementFinalScoreValidation =>
      'Enter final scores from 0 to 99.';

  @override
  String get adminSettlementHalfTimeValidation =>
      'Enter both half-time scores without exceeding the final score.';

  @override
  String get adminSettlementHalfTimeScore => 'Half-time score';

  @override
  String get adminSettlementHideHalfTime => 'Hide half-time score fields';

  @override
  String get adminSettlementShowHalfTime => 'Show half-time score fields';

  @override
  String get adminSettlementHalfTimeOptional => 'Half-time score (optional)';

  @override
  String adminSettlementHalfTimeLabel(String team) {
    return '$team HT';
  }

  @override
  String get adminSettlementReviewAction => 'Review settlement';

  @override
  String get adminStatusFinished => 'Finished';

  @override
  String get adminStatusScheduled => 'Scheduled';

  @override
  String get adminStatusLive => 'Live';

  @override
  String get adminStatusCancelled => 'Cancelled';

  @override
  String get adminStatusPostponed => 'Postponed';

  @override
  String adminScore(int home, int away) {
    return '$home – $away';
  }

  @override
  String get adminFeatureDetailTitle => 'Feature detail';

  @override
  String get adminFeatureLoadingTitle => 'Loading feature settings';

  @override
  String get adminFeatureLoadingMessage =>
      'Checking controlled channel and access rules.';

  @override
  String get adminFeatureNotFound => 'Feature not found';

  @override
  String get adminFeatureNotFoundMessage =>
      'No confirmed feature matches this controlled route.';

  @override
  String get adminBackToFeatures => 'Back to features';

  @override
  String get adminFeatureGlobalState => 'Global state';

  @override
  String adminFeatureDisableTooltip(String feature) {
    return 'Disable $feature';
  }

  @override
  String adminFeatureEnableTooltip(String feature) {
    return 'Enable $feature';
  }

  @override
  String adminFeatureStateSemantic(String feature, String state) {
    return '$feature is $state';
  }

  @override
  String get adminFeatureChangesGlobalState =>
      'Changes the global feature state';

  @override
  String get adminFeatureEnabled => 'Enabled';

  @override
  String get adminFeatureDisabled => 'Disabled';

  @override
  String get adminFeatureTapDisable => 'Tap to disable this feature globally';

  @override
  String get adminFeatureTapEnable => 'Tap to enable this feature globally';

  @override
  String get adminFeatureVisibility => 'Visibility';

  @override
  String get adminFeatureVisibilityVisible => 'Visible';

  @override
  String get adminFeatureVisibilityHidden => 'Hidden';

  @override
  String get adminFeatureVisibilityMaintenance => 'Maintenance';

  @override
  String get adminFeatureChannelConfig => 'Channel config';

  @override
  String get adminFeatureNoChannelOverrides => 'No channel overrides';

  @override
  String get adminFeatureNoChannelOverridesMessage =>
      'This feature uses its confirmed global state.';

  @override
  String get adminFeatureScheduling => 'Scheduling';

  @override
  String get adminFeatureAccessRules => 'Access rules';

  @override
  String get adminFeatureAuthRequired => 'Authentication required';

  @override
  String get adminFeatureAuthRequiredMessage =>
      'Users must sign in before accessing this feature.';

  @override
  String get adminFeatureSettingsUnavailable => 'Feature settings unavailable';

  @override
  String get adminFeatureEditingDisabled =>
      'Feature editing is disabled for this controlled build.';

  @override
  String get adminFeatureSettingsOffline => 'Feature settings offline';

  @override
  String get adminFeatureSettingsOfflineMessage =>
      'Reconnect before loading private feature configuration.';

  @override
  String get adminFeatureAccessUnavailable => 'Feature access unavailable';

  @override
  String get adminFeatureAccessUnavailableMessage =>
      'This account cannot view or change feature settings.';

  @override
  String get adminFeatureSettingsChanged => 'Feature settings changed';

  @override
  String get adminFeatureSettingsChangedMessage =>
      'Refresh before making another feature change.';

  @override
  String get adminFeatureSecurityTimeoutMessage =>
      'No feature settings were shown. Check your connection.';

  @override
  String get adminFeaturePrivateDataHidden =>
      'Private feature settings remain hidden. Try again.';

  @override
  String get adminFeatureCheckingTitle => 'Checking feature settings';

  @override
  String get adminFeatureCheckingMessage =>
      'Showing the last confirmed state while current data is checked.';

  @override
  String get adminFeatureOutcomeUnconfirmed =>
      'The last change is unconfirmed. Controls stay paused until refresh succeeds.';

  @override
  String get adminFeatureLastConfirmed =>
      'Last confirmed settings remain visible. Controls are paused.';

  @override
  String get adminFeatureChannelMobile => 'Mobile';

  @override
  String get adminFeatureChannelWeb => 'Web';

  @override
  String get adminFeatureChannelEnabled => 'Enabled';

  @override
  String get adminFeatureChannelEnabledMessage =>
      'Feature is active on this channel.';

  @override
  String get adminFeatureChannelVisible => 'Visible';

  @override
  String get adminFeatureChannelVisibleMessage =>
      'Feature can be shown on this channel.';

  @override
  String get adminFeatureShowInNavigation => 'Show in navigation';

  @override
  String get adminFeatureShowInNavigationMessage =>
      'Include this feature in channel navigation.';

  @override
  String get adminFeatureShowOnHome => 'Show on home';

  @override
  String get adminFeatureShowOnHomeMessage =>
      'Include this feature on the channel home screen.';

  @override
  String get adminFeatureAvailableFrom => 'Available from';

  @override
  String get adminFeatureAvailableUntil => 'Available until';

  @override
  String get adminFeatureClearSchedule => 'Clear schedule';

  @override
  String get adminFeatureNotSet => 'Not set';

  @override
  String adminFeatureSetTooltip(String label) {
    return 'Set $label';
  }

  @override
  String adminFeatureDateSemantic(String label, String value) {
    return '$label: $value';
  }

  @override
  String get adminFeatureOpenDateTime => 'Opens date and time selection';

  @override
  String get adminMatchesTitle => 'Matches';

  @override
  String get adminMatchesLoadingTitle => 'Loading match workspace';

  @override
  String get adminMatchesLoadingMessage =>
      'Checking controlled fixture information.';

  @override
  String get adminMatchesDescription =>
      'Manage fixtures, sale status, ticket allocation, and live scores from confirmed data.';

  @override
  String get adminMatchesFixtures => 'Fixtures';

  @override
  String get adminMatchesOnSale => 'On sale';

  @override
  String get adminMatchesStatus => 'Status';

  @override
  String get adminMatchesFilterAll => 'All';

  @override
  String get adminMatchesFilterLive => 'Live';

  @override
  String get adminMatchesFilterUpcoming => 'Upcoming';

  @override
  String get adminMatchesFilterOnSale => 'On sale';

  @override
  String get adminMatchesFilterCompleted => 'Completed';

  @override
  String get adminMatchesNoneConfigured => 'No fixtures configured';

  @override
  String get adminMatchesNoneMatch => 'No fixtures match';

  @override
  String get adminMatchesNoneConfiguredMessage =>
      'A confirmed club fixture must exist before this workspace can infer its partner scope.';

  @override
  String get adminMatchesNoneMatchMessage => 'Choose another status filter.';

  @override
  String get adminMatchesCreate => 'Create match';

  @override
  String get adminMatchesCreationPaused =>
      'Creation stays paused until a confirmed partner scope is available.';

  @override
  String get adminMatchesCreated => 'Match created successfully.';

  @override
  String get adminMatchesUpdated => 'Match updated successfully.';

  @override
  String get adminMatchesManagementUnavailable =>
      'Match management unavailable';

  @override
  String get adminMatchesDisabledMessage =>
      'Match controls are disabled for this controlled build.';

  @override
  String get adminMatchesWorkspaceOffline => 'Match workspace offline';

  @override
  String get adminMatchesWorkspaceOfflineMessage =>
      'Reconnect before loading private fixture information.';

  @override
  String get adminMatchesAccessUnavailable => 'Match access unavailable';

  @override
  String get adminMatchesAccessUnavailableMessage =>
      'This account cannot view or change fixture information.';

  @override
  String get adminMatchesInformationChanged => 'Fixture information changed';

  @override
  String get adminMatchesInformationChangedMessage =>
      'Refresh before making another fixture change.';

  @override
  String get adminMatchesSecurityTimeoutMessage =>
      'No fixture information was shown. Check your connection.';

  @override
  String get adminMatchesWorkspaceUnavailable => 'Match workspace unavailable';

  @override
  String get adminMatchesPrivateDataHidden =>
      'Private fixture information remains hidden. Try again.';

  @override
  String get adminMatchesCheckingTitle => 'Checking fixture information';

  @override
  String get adminMatchesCheckingMessage =>
      'Showing the last confirmed state while current data is checked.';

  @override
  String get adminMatchesOutcomeUnconfirmed =>
      'The last change is unconfirmed. Controls stay paused until refresh succeeds.';

  @override
  String get adminMatchesLastConfirmed =>
      'Last confirmed fixture information remains visible. Controls are paused.';

  @override
  String adminMatchesOpenTooltip(String home, String away) {
    return 'Open $home versus $away';
  }

  @override
  String adminMatchesFixtureSemantic(String home, String away) {
    return '$home versus $away fixture';
  }

  @override
  String get adminMatchesOpenHint => 'Opens controlled fixture settings';

  @override
  String adminMatchesCompetitionVenue(String competition, String venue) {
    return '$competition • $venue';
  }

  @override
  String adminMatchesDateKickoff(String date, String time) {
    return '$date • $time';
  }

  @override
  String adminMatchesPrices(String symbol, String general, String vip) {
    return 'General $symbol $general • VIP $symbol $vip';
  }

  @override
  String adminMatchesScore(int home, int away, String minute) {
    return 'Score $home-$away$minute';
  }

  @override
  String adminMatchesAllocation(int percent, int sold, int capacity) {
    return '$percent% allocation • $sold / $capacity tickets';
  }

  @override
  String get adminMatchesEditOnSale => 'Edit on-sale fixture';

  @override
  String get adminMatchesEdit => 'Edit fixture';

  @override
  String get adminStatusHalfTime => 'Half-time';

  @override
  String get adminStatusFullTime => 'Full-time';

  @override
  String get adminStatusUpcoming => 'Upcoming';

  @override
  String adminMatchesLiveMinute(int minute) {
    return ' • $minute\'';
  }

  @override
  String get adminMatchSaveNotConfirmed =>
      'The match was not saved. Review the confirmed workspace state.';

  @override
  String get adminMatchReviewFields =>
      'Review every match field and enter valid values.';

  @override
  String get adminMatchSaveFailedRefresh =>
      'The match was not saved. Try again after refreshing.';

  @override
  String get adminMatchCreateTitle => 'Create match';

  @override
  String get adminMatchUpdateTitle => 'Update match';

  @override
  String get adminMatchHomeTeam => 'Home team';

  @override
  String get adminMatchAwayTeam => 'Away team';

  @override
  String get adminMatchCompetition => 'Competition';

  @override
  String get adminMatchVenue => 'Venue';

  @override
  String adminMatchGeneralPrice(String symbol) {
    return 'General $symbol';
  }

  @override
  String adminMatchVipPrice(String symbol) {
    return 'VIP $symbol';
  }

  @override
  String get adminMatchCapacity => 'Capacity';

  @override
  String get adminMatchTicketsOnSale => 'Tickets on sale';

  @override
  String get adminMatchStatus => 'Match status';

  @override
  String get adminMatchStatusScheduled => 'Scheduled';

  @override
  String get adminMatchStatusLive => 'Live';

  @override
  String get adminMatchStatusHalfTime => 'Half-time';

  @override
  String get adminMatchStatusFullTime => 'Full-time';

  @override
  String get adminMatchStatusPostponed => 'Postponed';

  @override
  String get adminMatchStatusCancelled => 'Cancelled';

  @override
  String get adminMatchHomeScore => 'Home score';

  @override
  String get adminMatchAwayScore => 'Away score';

  @override
  String get adminMatchLiveMinute => 'Live minute';

  @override
  String get adminMatchSummary => 'Match summary / live note';

  @override
  String get adminMatchSave => 'Save match';

  @override
  String get adminMatchUpdate => 'Update match';

  @override
  String get adminFeatureManagerTitle => 'Feature manager';

  @override
  String get adminFeatureRegistryLoading => 'Loading feature registry';

  @override
  String get adminFeatureRegistryLoadingMessage =>
      'Checking controlled feature configuration.';

  @override
  String get adminFeatureManagerDescription =>
      'Control club-scoped feature availability with confirmed, bounded configuration.';

  @override
  String get adminFeatureRegistered => 'Registered';

  @override
  String get adminFeatureEnabledUpper => 'Enabled';

  @override
  String get adminFeatureDisabledUpper => 'Disabled';

  @override
  String get adminFeatureStatus => 'Status';

  @override
  String get adminFeatureFilterAll => 'All';

  @override
  String get adminFeatureNoneConfigured => 'No features configured';

  @override
  String get adminFeatureNoneMatch => 'No features match';

  @override
  String get adminFeatureNoneConfiguredMessage =>
      'Confirmed feature configuration will appear here.';

  @override
  String get adminFeatureNoneMatchMessage => 'Choose another status filter.';

  @override
  String get adminFeatureManagementUnavailable =>
      'Feature management unavailable';

  @override
  String get adminFeatureControlsDisabled =>
      'Feature controls are disabled for this controlled build.';

  @override
  String get adminFeatureRegistryOffline => 'Feature registry offline';

  @override
  String get adminFeatureConfigurationAccessMessage =>
      'This account cannot view or change feature configuration.';

  @override
  String get adminFeatureConfigurationChanged =>
      'Feature configuration changed';

  @override
  String get adminFeatureConfigurationChangedMessage =>
      'Refresh before making another feature change.';

  @override
  String get adminFeatureConfigurationSecurityMessage =>
      'No feature configuration was shown. Check your connection.';

  @override
  String get adminFeatureRegistryUnavailable => 'Feature registry unavailable';

  @override
  String get adminFeatureConfigurationHidden =>
      'Private feature configuration remains hidden. Try again.';

  @override
  String get adminFeatureConfigurationChecking =>
      'Checking feature configuration';

  @override
  String get adminFeatureConfigurationLastConfirmed =>
      'Last confirmed configuration remains visible. Controls are paused.';

  @override
  String adminFeatureOpenTooltip(String feature) {
    return 'Open $feature';
  }

  @override
  String adminFeatureSettingsSemantic(String feature) {
    return '$feature feature settings';
  }

  @override
  String get adminFeatureOpenSettingsHint =>
      'Opens controlled feature settings';

  @override
  String adminFeatureChangeVisibilityTooltip(String feature) {
    return 'Change $feature visibility';
  }

  @override
  String get adminFeatureChangeVisibility => 'Change visibility';

  @override
  String get adminCompetitionsTitle => 'Competitions';

  @override
  String get adminCompetitionsAdd => 'Add competition';

  @override
  String get adminCompetitionsActionsUnavailable =>
      'Competition actions unavailable';

  @override
  String get adminCompetitionsLoading => 'Loading competitions';

  @override
  String get adminCompetitionsLoadingMessage =>
      'Checking the controlled competition workspace.';

  @override
  String get adminCompetitionsDescription =>
      'Manage the competitions and seasons available to the prediction engine.';

  @override
  String get adminCompetitionsNoneConfigured => 'No competitions configured';

  @override
  String get adminCompetitionsNoneMatch => 'No competitions match';

  @override
  String get adminCompetitionsNoneConfiguredMessage =>
      'Create the first controlled competition when access is available.';

  @override
  String get adminCompetitionsNoneMatchMessage =>
      'Choose another region or competition kind.';

  @override
  String get adminCompetitionsManagementUnavailable =>
      'Competition management unavailable';

  @override
  String get adminCompetitionsControlsDisabled =>
      'Competition controls are disabled for this controlled build.';

  @override
  String get adminCompetitionsOffline => 'Competition workspace offline';

  @override
  String get adminCompetitionsOfflineMessage =>
      'Reconnect before loading private competition records.';

  @override
  String get adminCompetitionsAccessUnavailable =>
      'Competition access unavailable';

  @override
  String get adminCompetitionsAccessMessage =>
      'This account cannot view or change competition configuration.';

  @override
  String get adminCompetitionsDataChanged => 'Competition data changed';

  @override
  String get adminCompetitionsDataChangedMessage =>
      'Refresh before continuing with competition work.';

  @override
  String get adminCompetitionsSecurityMessage =>
      'No competition data was shown. Check your connection.';

  @override
  String get adminCompetitionsWorkspaceUnavailable =>
      'Competition workspace unavailable';

  @override
  String get adminCompetitionsHiddenMessage =>
      'Private competition records remain hidden. Try again.';

  @override
  String get adminCompetitionsUpdating => 'Updating competition workspace';

  @override
  String get adminCompetitionsUpdatingMessage =>
      'Controls are paused until the current result is confirmed.';

  @override
  String get adminCompetitionsRefreshing => 'Refreshing competitions';

  @override
  String get adminCompetitionsRefreshingMessage =>
      'Showing the last confirmed records while current data is checked.';

  @override
  String get adminCompetitionsCurrentRefreshUnavailable =>
      'Current refresh unavailable';

  @override
  String get adminCompetitionsOutcomeUnconfirmed =>
      'The update outcome is not confirmed. Refresh before taking another action.';

  @override
  String get adminCompetitionsLastConfirmed =>
      'Showing the last confirmed records. Actions are paused until refresh succeeds.';

  @override
  String get adminCompetitionCreated => 'Competition created';

  @override
  String get adminCompetitionUpdated => 'Competition updated';

  @override
  String get adminCompetitionActivateQuestion => 'Activate competition?';

  @override
  String get adminCompetitionDeactivateQuestion => 'Deactivate?';

  @override
  String adminCompetitionActivateMessage(String competition) {
    return '$competition will become available to configured prediction journeys.';
  }

  @override
  String adminCompetitionDeactivateMessage(String competition) {
    return '$competition will stop being available to configured prediction journeys.';
  }

  @override
  String get adminActivateUpper => 'Activate';

  @override
  String get adminDeactivateUpper => 'Deactivate';

  @override
  String get adminCompetitionActivated => 'Competition activated';

  @override
  String get adminCompetitionDeactivated => 'Competition deactivated';

  @override
  String get adminCompetitionsTotal => 'Total';

  @override
  String get adminCompetitionsActive => 'Active';

  @override
  String get adminCompetitionsInactive => 'Inactive';

  @override
  String get adminCompetitionFilters => 'Competition filters';

  @override
  String get adminCompetitionRegion => 'Region';

  @override
  String get adminCompetitionKind => 'Kind';

  @override
  String get adminCompetitionSeasons => 'Seasons';

  @override
  String get adminEditUpper => 'Edit';

  @override
  String get adminCompetitionFilterAll => 'All';

  @override
  String get adminCompetitionRegionAfrica => 'Africa';

  @override
  String get adminCompetitionRegionEurope => 'Europe';

  @override
  String get adminCompetitionRegionInternational => 'Intl';

  @override
  String get adminCompetitionRegionGlobal => 'Global';

  @override
  String get adminCompetitionKindLeague => 'League';

  @override
  String get adminCompetitionKindCup => 'Cup';

  @override
  String get adminCompetitionKindTournament => 'Tournament';

  @override
  String get adminCompetitionEdit => 'Edit competition';

  @override
  String get adminCompetitionAdd => 'Add competition';

  @override
  String get adminCompetitionName => 'Name';

  @override
  String get adminCompetitionShortName => 'Short name';

  @override
  String get adminCompetitionSlug => 'Slug';

  @override
  String get adminCompetitionSlugHint => 'e.g. national-league';

  @override
  String get adminCompetitionOrganizer => 'Organizer';

  @override
  String get adminOptional => 'Optional';

  @override
  String get adminCompetitionCountryCode => 'Country code';

  @override
  String get adminCompetitionCountryCodeHint => 'Rw';

  @override
  String get adminCompetitionCountryName => 'Country name';

  @override
  String get adminCompetitionCountryNameHint => 'Rwanda';

  @override
  String get adminCompetitionFormatNotes => 'Format notes';

  @override
  String get adminCompetitionValidationMessage =>
      'Check the required names, slug, and country code.';

  @override
  String get adminCompetitionAvailable =>
      'Available to configured prediction journeys';

  @override
  String get adminCompetitionUnavailable =>
      'Unavailable to prediction journeys';

  @override
  String get adminSaveChanges => 'Save changes';

  @override
  String get adminCreateCompetition => 'Create competition';

  @override
  String get adminSeasonAdd => 'Add season';

  @override
  String get adminSeasonActionsUnavailable => 'Season actions unavailable';

  @override
  String get adminSeasonNoneConfigured => 'No seasons configured';

  @override
  String get adminSeasonNoneConfiguredMessage =>
      'Add the first controlled season when access is available.';

  @override
  String get adminSeasonCreated => 'Season created';

  @override
  String get adminSeasonActivateQuestion => 'Activate season?';

  @override
  String get adminSeasonDeactivateQuestion => 'Deactivate season?';

  @override
  String adminSeasonAvailabilityMessage(String season, String availability) {
    return '$season will be $availability to configured competition journeys.';
  }

  @override
  String get adminAvailable => 'available';

  @override
  String get adminUnavailable => 'unavailable';

  @override
  String get adminSeasonActivated => 'Season activated';

  @override
  String get adminSeasonDeactivated => 'Season deactivated';

  @override
  String get adminSeasonActivate => 'Activate season';

  @override
  String get adminSeasonDeactivate => 'Deactivate season';

  @override
  String get adminSeasonValidationMessage =>
      'Check the season slug, label, and years.';

  @override
  String get adminSeasonAddUpper => 'Add season';

  @override
  String get adminSeasonSlugHint => 'e.g. league-2026';

  @override
  String get adminSeasonLabel => 'Label';

  @override
  String get adminSeasonLabelHint => 'e.g. 2025/2026';

  @override
  String get adminSeasonYearStart => 'Year start';

  @override
  String get adminSeasonYearEnd => 'Year end';

  @override
  String get adminCreateUpper => 'Create';

  @override
  String get adminSeasonStatusPlanned => 'Planned';

  @override
  String get adminSeasonStatusActive => 'Active';

  @override
  String get adminSeasonStatusFinished => 'Finished';

  @override
  String get adminSeasonStatusArchived => 'Archived';

  @override
  String get adminNotificationSendTitle => 'Send notification';

  @override
  String get adminNotificationLoading => 'Loading notification workspace';

  @override
  String get adminNotificationLoadingMessage =>
      'Checking controlled delivery information.';

  @override
  String get adminNotificationDeliveryStatus => 'Delivery status';

  @override
  String get adminNotificationDeliveryStatusMessage =>
      'Delivery via Edge Functions. Scheduled sends dispatch on cron.';

  @override
  String get adminNotificationAudience => 'Audience';

  @override
  String get adminNotificationAudienceAllFans => 'All fans';

  @override
  String get adminNotificationAudienceByTier => 'By tier';

  @override
  String get adminNotificationAudienceByGroup => 'By group';

  @override
  String get adminNotificationTierFan => 'Fan';

  @override
  String get adminNotificationTierBronze => 'Bronze';

  @override
  String get adminNotificationTierGold => 'Gold';

  @override
  String get adminNotificationTierPlatinum => 'Platinum';

  @override
  String get adminNotificationSelectGroup => 'Select group';

  @override
  String get adminNotificationTitleLabel => 'Notification title';

  @override
  String get adminNotificationBodyLabel => 'Message body';

  @override
  String adminNotificationCharacterCount(int count) {
    return '$count characters';
  }

  @override
  String get adminNotificationImageUrl => 'Optional image URL';

  @override
  String get adminNotificationSchedule => 'Schedule';

  @override
  String get adminNotificationSendNow => 'Send now';

  @override
  String get adminNotificationPickDateTime => 'Pick date & time';

  @override
  String get adminNotificationScheduleAction => 'Schedule notification';

  @override
  String get adminNotificationSendAction => 'Send notification';

  @override
  String get adminNotificationCopyPayload => 'Copy payload';

  @override
  String get adminNotificationSendHistory => 'Send history';

  @override
  String get adminNotificationHistoryEmpty => 'No notification history';

  @override
  String get adminNotificationHistoryEmptyMessage =>
      'Confirmed delivery records will appear here after a request.';

  @override
  String get adminNotificationManagementUnavailable =>
      'Notification management unavailable';

  @override
  String get adminNotificationControlsDisabled =>
      'Notification controls are disabled for this controlled build.';

  @override
  String get adminNotificationWorkspaceOffline =>
      'Notification workspace offline';

  @override
  String get adminNotificationOfflineMessage =>
      'Reconnect before loading private delivery information.';

  @override
  String get adminNotificationAccessUnavailable =>
      'Notification access unavailable';

  @override
  String get adminNotificationAccessMessage =>
      'This account cannot view or send notifications.';

  @override
  String get adminNotificationDataChanged => 'Delivery information changed';

  @override
  String get adminNotificationDataChangedMessage =>
      'Refresh before making another notification request.';

  @override
  String get adminNotificationSecurityMessage =>
      'No delivery information was shown. Check your connection.';

  @override
  String get adminNotificationWorkspaceUnavailable =>
      'Notification workspace unavailable';

  @override
  String get adminNotificationHiddenMessage =>
      'Private delivery information remains hidden. Try again.';

  @override
  String get adminNotificationChecking => 'Checking delivery information';

  @override
  String get adminNotificationCheckingMessage =>
      'Showing the last confirmed state while current data is checked.';

  @override
  String get adminNotificationOutcomeUnconfirmed =>
      'The last request is unconfirmed. Controls stay paused until refresh succeeds.';

  @override
  String get adminNotificationLastConfirmed =>
      'Last confirmed delivery information remains visible. Controls are paused.';

  @override
  String get adminNotificationValidationTitleBody =>
      'Add a title and message body first.';

  @override
  String get adminNotificationValidationTier => 'Choose the target tier first.';

  @override
  String get adminNotificationValidationGroup =>
      'Choose the target group first.';

  @override
  String get adminNotificationValidationSchedule =>
      'Pick the delivery date and time first.';

  @override
  String get adminNotificationQueued =>
      'Notification queued for scheduled delivery.';

  @override
  String adminNotificationScheduledFor(String date) {
    return 'Notification scheduled for $date.';
  }

  @override
  String adminNotificationSentSummary(int requested, int sent) {
    return 'Sent to $requested supporters. $sent delivered.';
  }

  @override
  String adminNotificationPartialSummary(int sent, int failed) {
    return 'Partial: $sent delivered, $failed failed.';
  }

  @override
  String get adminNotificationDeliveryFailed => 'Notification delivery failed.';

  @override
  String get adminNotificationRequestRecorded =>
      'Notification request recorded.';

  @override
  String adminNotificationHistoryMetrics(int requested, int sent, int failed) {
    return ' • $requested targets • $sent sent • $failed failed';
  }

  @override
  String get adminNotificationFieldsInvalid =>
      'Review the notification fields and try again.';

  @override
  String get adminNotificationRequestUnconfirmed =>
      'Notification request was not confirmed.';

  @override
  String get adminNotificationPayloadCopied => 'Payload copied to clipboard.';

  @override
  String get adminNotificationTierNotSelected => 'Tier not selected';

  @override
  String adminNotificationTierPreview(String tier) {
    return 'Tier • $tier';
  }

  @override
  String get adminNotificationGroupNotSelected => 'Group not selected';

  @override
  String adminNotificationGroupPreview(String group) {
    return 'Group • $group';
  }

  @override
  String get adminNotificationAllSupporters => 'All supporters';

  @override
  String get adminNotificationPreview => 'Preview';

  @override
  String get adminNotificationPreviewBody =>
      'Your message preview appears here.';

  @override
  String get adminNotificationStatusScheduled => 'Scheduled';

  @override
  String get adminNotificationStatusSent => 'Sent';

  @override
  String get adminNotificationStatusPartial => 'Partial';

  @override
  String get adminNotificationStatusFailed => 'Failed';

  @override
  String get adminContributionsTitle => 'Contributions';

  @override
  String get adminContributionsLoading => 'Loading contributions';

  @override
  String get adminContributionsLoadingMessage =>
      'Checking the controlled contribution monitor.';

  @override
  String get adminContributionsDescription =>
      'Review club-scoped group totals without exposing supporter or payment identifiers.';

  @override
  String get adminContributionsMonthlyTotal => 'Total recorded this month';

  @override
  String adminContributionsSummary(int groups, int records) {
    return '$groups groups • $records bounded records';
  }

  @override
  String get adminContributionsNoGroups => 'No contribution groups';

  @override
  String get adminContributionsNoMatch => 'No groups match';

  @override
  String get adminContributionsNoGroupsMessage =>
      'Confirmed club-scoped contribution groups will appear here.';

  @override
  String get adminContributionsNoMatchMessage =>
      'Choose another contribution group filter.';

  @override
  String get adminContributionsExport => 'Export privacy-safe report';

  @override
  String get adminContributionsReportCopied =>
      'Privacy-safe contribution report copied.';

  @override
  String get adminContributionsUnavailable =>
      'Contribution monitor unavailable';

  @override
  String get adminContributionsDisabled =>
      'Contribution monitoring is disabled for this controlled build.';

  @override
  String get adminContributionsOffline => 'Contribution monitor offline';

  @override
  String get adminContributionsOfflineMessage =>
      'Reconnect before loading private contribution records.';

  @override
  String get adminContributionsAccessUnavailable =>
      'Contribution access unavailable';

  @override
  String get adminContributionsAccessMessage =>
      'This account cannot view private contribution operations.';

  @override
  String get adminContributionsDataChanged => 'Contribution data changed';

  @override
  String get adminContributionsDataChangedMessage =>
      'Refresh before relying on contribution totals.';

  @override
  String get adminContributionsSecurityMessage =>
      'No contribution records were shown. Check your connection.';

  @override
  String get adminContributionsHiddenMessage =>
      'Private contribution records remain hidden. Try again.';

  @override
  String get adminContributionsRefreshing => 'Refreshing contributions';

  @override
  String get adminContributionsRefreshingMessage =>
      'Showing the last confirmed totals while current data is checked.';

  @override
  String get adminContributionsLastConfirmed =>
      'Last confirmed totals remain visible. Controls are paused until refresh succeeds.';

  @override
  String get adminContributionsGroupType => 'Group type';

  @override
  String get adminContributionsSort => 'Sort';

  @override
  String get adminContributionsFilterAll => 'All';

  @override
  String get adminContributionsTeamProjects => 'Team projects';

  @override
  String get adminContributionsCommunity => 'Community';

  @override
  String get adminContributionsRecent => 'Recent';

  @override
  String get adminContributionsTotal => 'Total';

  @override
  String get adminContributionsClosed => 'Closed';

  @override
  String get adminContributionsActive => 'Active';

  @override
  String get adminContributionsTeamProject => 'Team project';

  @override
  String adminContributionsRecordMembers(int records, int members) {
    return '$records bounded records • $members registered members';
  }

  @override
  String get adminContributionsActivityPending => 'Payment activity pending';

  @override
  String adminContributionsLastActivity(String date) {
    return 'Last activity $date';
  }

  @override
  String get adminSmsTitle => 'SMS operations';

  @override
  String get adminSmsLoading => 'Loading SMS operations';

  @override
  String get adminSmsLoadingMessage =>
      'Checking controlled pipeline health information.';

  @override
  String get adminSmsNoHistory => 'No SMS operations history';

  @override
  String get adminSmsNoHistoryMessage =>
      'No controlled health signals or synchronization runs are available yet.';

  @override
  String get adminSmsControlledHealth => 'Controlled health view';

  @override
  String get adminSmsControlledHealthMessage =>
      'Review device synchronization, message checks, contribution matching, sender drift, retries, and privacy cleanup without displaying message bodies or supporter identifiers.';

  @override
  String get adminSmsPipelineHealth => 'Pipeline health';

  @override
  String get adminSmsRecentSync => 'Recent device synchronization';

  @override
  String get adminSmsNoRecentRuns => 'No recent synchronization runs';

  @override
  String get adminSmsNoRecentRunsMessage =>
      'The health summary remains available above.';

  @override
  String adminSmsMetricSemantics(String label, String status) {
    return '$label, $status';
  }

  @override
  String get adminSmsCollapseDetails => 'Collapse health details';

  @override
  String get adminSmsExpandDetails => 'Expand health details';

  @override
  String adminSmsLastSignal(String date) {
    return 'Last confirmed signal $date';
  }

  @override
  String get adminSmsUnavailable => 'SMS operations unavailable';

  @override
  String get adminSmsDisabled =>
      'SMS operations monitoring is disabled for this build.';

  @override
  String get adminSmsOffline => 'SMS operations offline';

  @override
  String get adminSmsOfflineMessage =>
      'Reconnect before loading private operational information.';

  @override
  String get adminSmsAccessUnavailable => 'SMS operations access unavailable';

  @override
  String get adminSmsAccessMessage =>
      'Platform administrator access is required for this view.';

  @override
  String get adminSmsChanged => 'SMS operations changed';

  @override
  String get adminSmsChangedMessage =>
      'Refresh before using this operational information.';

  @override
  String get adminSmsSecurityMessage =>
      'No operational information was shown. Check your connection.';

  @override
  String get adminSmsHiddenMessage =>
      'Private operational information remains hidden. Try again.';

  @override
  String get adminSmsChecking => 'Checking SMS operations';

  @override
  String get adminSmsCheckingMessage =>
      'Showing the last confirmed state while current data is checked.';

  @override
  String get adminSmsLastConfirmed =>
      'Last confirmed operational information remains visible. Controls are paused.';

  @override
  String get adminSmsStatusHealthy => 'Healthy';

  @override
  String get adminSmsStatusSucceeded => 'Succeeded';

  @override
  String get adminSmsStatusDegraded => 'Degraded';

  @override
  String get adminSmsStatusRunning => 'Running';

  @override
  String get adminSmsStatusRateLimited => 'Rate limited';

  @override
  String get adminSmsStatusFailing => 'Failing';

  @override
  String get adminSmsStatusFailed => 'Failed';

  @override
  String get adminSmsTriggerInitial => 'Initial history';

  @override
  String get adminSmsTriggerManual => 'Manual';

  @override
  String get adminSmsTriggerControlled => 'Controlled';

  @override
  String adminSmsRunTitle(String status, String trigger) {
    return '$status • $trigger';
  }

  @override
  String adminSmsRunMetrics(int scanned, int uploaded, int duplicates) {
    return '$scanned scanned • $uploaded uploaded • $duplicates duplicates';
  }

  @override
  String get adminCmsTitle => 'Content manager';

  @override
  String get adminCmsDescription =>
      'Manage home shortcuts, partner catalogs, and supported prediction competitions.';

  @override
  String get adminCmsLoading => 'Loading content manager';

  @override
  String get adminCmsLoadingMessage => 'Checking current publishing work.';

  @override
  String get adminCmsNoContent => 'No managed content';

  @override
  String get adminCmsNoContentMessage =>
      'Choose a section to create the first controlled item.';

  @override
  String get adminCmsUnavailable => 'Content manager unavailable';

  @override
  String get adminCmsDisabled =>
      'Publishing controls are disabled for this controlled build.';

  @override
  String get adminCmsOffline => 'Content manager offline';

  @override
  String get adminCmsOfflineMessage =>
      'Reconnect before loading private publishing controls.';

  @override
  String get adminCmsAccessUnavailable => 'Content access unavailable';

  @override
  String get adminCmsAccessMessage =>
      'This account cannot view or change club publishing data.';

  @override
  String get adminCmsChanged => 'Content changed';

  @override
  String get adminCmsChangedMessage =>
      'Refresh the workspace before making another change.';

  @override
  String get adminCmsSecurityMessage =>
      'No private content was shown. Check your connection and retry.';

  @override
  String get adminCmsHiddenMessage =>
      'Private publishing data remains hidden. Try again.';

  @override
  String get adminCmsSaving => 'Saving content';

  @override
  String get adminCmsSavingMessage =>
      'Publishing controls are paused until the result is confirmed.';

  @override
  String get adminCmsRefreshing => 'Refreshing content';

  @override
  String get adminCmsRefreshingMessage =>
      'Showing the last confirmed workspace while status is checked.';

  @override
  String get adminCmsCurrentRefreshUnavailable => 'Current refresh unavailable';

  @override
  String get adminCmsOutcomeUnconfirmed =>
      'The last change is not confirmed. Refresh before taking another action.';

  @override
  String get adminCmsLastConfirmed =>
      'Showing the last confirmed workspace. Actions are paused until refresh succeeds.';

  @override
  String get adminCmsChangeOffline =>
      'CMS changes need a connection. Nothing was retried.';

  @override
  String get adminCmsChangeAccess =>
      'CMS access is no longer available for this account.';

  @override
  String get adminCmsChangeConflict =>
      'CMS content changed. Refresh before trying another action.';

  @override
  String get adminCmsChangeUnconfirmed =>
      'The result is not confirmed. Refresh before trying another action.';

  @override
  String get adminCmsChangeFailed =>
      'The CMS change could not be completed. Review and try again.';

  @override
  String get adminCmsAddContentBlock => 'Add content block';

  @override
  String get adminCmsEditContentBlock => 'Edit content block';

  @override
  String get adminCmsBlockKey => 'Block key (e.g. home_hero_1)';

  @override
  String get adminCmsBlockType => 'Block type (e.g. banner)';

  @override
  String get adminCmsTargetChannel => 'Target channel';

  @override
  String get adminCmsPlacementKey => 'Placement key';

  @override
  String get adminCmsTitleField => 'Title';

  @override
  String get adminCmsSubtitleField => 'Subtitle';

  @override
  String get adminCmsContentComponent => 'Content component name';

  @override
  String get adminCmsFeatureField => 'Feature';

  @override
  String get adminCmsNone => 'None';

  @override
  String get adminCmsSortOrder => 'Sort order';

  @override
  String get adminCmsActive => 'Active';

  @override
  String get adminCmsCreate => 'Create';

  @override
  String get adminCmsSave => 'Save';

  @override
  String get adminCmsNewArticle => 'New article';

  @override
  String get adminCmsArticleTitle => 'Article title';

  @override
  String get adminCmsArticleBody => 'Article body';

  @override
  String get adminCmsAddQuickAction => 'Add quick action';

  @override
  String get adminCmsEditQuickAction => 'Edit quick action';

  @override
  String get adminCmsActionKey => 'Action key';

  @override
  String get adminCmsRoute => 'Route';

  @override
  String get adminCmsIconKey => 'Icon key';

  @override
  String get adminCmsEmoji => 'Emoji';

  @override
  String get adminCmsCountry => 'Country';

  @override
  String get adminCmsAddPartner => 'Add partner';

  @override
  String get adminCmsEditPartner => 'Edit partner';

  @override
  String get adminCmsName => 'Name';

  @override
  String get adminCmsSlug => 'Slug';

  @override
  String get adminCmsCategory => 'Category';

  @override
  String get adminCmsDescriptionField => 'Description';

  @override
  String get adminCmsGamificationLinked => 'Linked to gamification';

  @override
  String get adminCmsCreatePartnerFirst => 'Create a partner first.';

  @override
  String get adminCmsAddPartnerService => 'Add partner service';

  @override
  String get adminCmsEditPartnerService => 'Edit partner service';

  @override
  String get adminCmsPartner => 'Partner';

  @override
  String get adminCmsServiceSlug => 'Service slug';

  @override
  String get adminCmsCtaLabel => 'CTA label';

  @override
  String get adminCmsCtaAction => 'CTA action';

  @override
  String get adminCmsAllCompetitionsAdded =>
      'All active competitions are already in the prediction catalog.';

  @override
  String get adminCmsAddPredictionCompetition => 'Add prediction competition';

  @override
  String get adminCmsEditPredictionCompetition => 'Edit prediction competition';

  @override
  String get adminCmsCompetition => 'Competition';

  @override
  String get adminCmsHighlightLabel => 'Highlight label';

  @override
  String get adminCmsChannelMobile => 'Mobile';

  @override
  String get adminCmsChannelWeb => 'Web';

  @override
  String get adminCmsChannelBoth => 'Mobile and web';

  @override
  String get adminCmsCategoryOrganization => 'Organization';

  @override
  String get adminCmsCategoryBank => 'Bank';

  @override
  String get adminCmsCategoryFootball => 'Football';

  @override
  String get adminCmsCategoryGeneral => 'General';

  @override
  String get adminCmsCategoryCommunity => 'Community';

  @override
  String get adminCmsCategoryInsurance => 'Insurance';

  @override
  String get adminCmsCategoryMobility => 'Mobility';

  @override
  String get adminCmsSectionNews => 'News';

  @override
  String get adminCmsSectionQuickActions => 'Quick actions';

  @override
  String get adminCmsSectionPartners => 'Partners';

  @override
  String get adminCmsSectionServices => 'Services';

  @override
  String get adminCmsSectionPredictions => 'Predictions';

  @override
  String get adminCmsSectionPlacements => 'Placements';

  @override
  String get adminCmsSectionAuditLogs => 'Audit logs';

  @override
  String get adminCmsNewsArticles => 'News articles';

  @override
  String get adminCmsAddArticle => 'Add article';

  @override
  String get adminCmsHomeQuickActions => 'Home quick actions';

  @override
  String get adminCmsAddAction => 'Add action';

  @override
  String get adminCmsPartners => 'Partners';

  @override
  String get adminCmsAddPartnerAction => 'Add partner';

  @override
  String get adminCmsPartnerServices => 'Partner services';

  @override
  String get adminCmsAddService => 'Add service';

  @override
  String get adminCmsPredictionCompetitions => 'Prediction competitions';

  @override
  String get adminCmsAddCompetition => 'Add competition';

  @override
  String get adminCmsContentBlocks => 'Platform content blocks';

  @override
  String get adminCmsAddBlock => 'Add block';

  @override
  String get adminCmsAuditLogs => 'Feature management audit logs';

  @override
  String get adminCmsQuickActionFallback => 'Quick action';

  @override
  String get adminCmsServiceFallback => 'Service';

  @override
  String get adminCmsCompetitionFallback => 'Competition';

  @override
  String get adminCmsContentBlockFallback => 'Content block';

  @override
  String get adminCmsActiveUpper => 'Active';

  @override
  String get adminCmsInactiveUpper => 'Inactive';

  @override
  String get adminCmsGamificationUpper => 'Gamification';

  @override
  String get adminCmsDirectUpper => 'Direct';

  @override
  String get adminCmsStandardUpper => 'Standard';

  @override
  String get adminCmsDeactivate => 'Deactivate';

  @override
  String get adminCmsActivate => 'Activate';

  @override
  String get adminCmsCtaPending => 'CTA pending';

  @override
  String get adminCmsNotAvailable => 'n/a';

  @override
  String adminCmsCompetitionSummary(String kind, int count) {
    return '$kind • $count fixtures';
  }

  @override
  String get adminCmsCatalog => 'Catalog';

  @override
  String get adminCmsSupported => 'Supported';

  @override
  String get adminCmsUnknown => 'unknown';

  @override
  String get adminCmsUnknownFeature => 'Unknown feature';

  @override
  String get adminCmsUnknownDate => 'Unknown date';

  @override
  String get adminCmsActionFallback => 'Action';

  @override
  String adminCmsFeatureName(String feature) {
    return 'Feature: $feature';
  }

  @override
  String get adminCmsActorWithheld =>
      'Actor details are withheld in the mobile workspace.';

  @override
  String get adminCmsEdit => 'Edit';

  @override
  String get adminCmsUntitled => 'Untitled';

  @override
  String get adminCmsNewsFallback => 'News';

  @override
  String get adminCmsLive => 'Live';

  @override
  String get adminCmsDraft => 'Draft';

  @override
  String get adminCmsNotPublished => 'Not published';

  @override
  String get adminCmsFeatured => 'Featured';

  @override
  String adminCmsArticleMeta(String category, String date, String featured) {
    return '$category • $date$featured';
  }

  @override
  String get adminCmsUnpublish => 'Unpublish';

  @override
  String get adminCmsPublish => 'Publish';

  @override
  String adminCmsPair(String first, String second) {
    return '$first • $second';
  }

  @override
  String get gameCommunityPicks => 'Community picks';

  @override
  String get gameFetProgress => 'FET progress';

  @override
  String get gameFet => 'FET';

  @override
  String get gameLevelUp => 'Level up!';

  @override
  String get gameAwesome => 'Awesome';

  @override
  String get gameKeepGoing => 'Keep going';

  @override
  String get gameLive => 'LIVE';

  @override
  String gameOutcomePick(String outcome) {
    return '$outcome pick';
  }

  @override
  String gamePoints(int count) {
    return '+$count pts';
  }

  @override
  String get gameDaysShort => 'Days';

  @override
  String get gameHoursShort => 'Hrs';

  @override
  String get gameMinutesShort => 'Min';

  @override
  String get gameSecondsShort => 'Sec';

  @override
  String get gameDismissNotification => 'Dismiss notification';

  @override
  String get gamePredictions => 'Predictions';

  @override
  String get gameAccuracy => 'Accuracy';

  @override
  String get gamePointsEarned => 'Points earned';

  @override
  String get gameRank => 'Rank';

  @override
  String get gameTopScorers => 'Top scorers';

  @override
  String get gameGoals => 'Goals';

  @override
  String get gameEntriesClosed => 'Entries closed';

  @override
  String get gameEntriesCloseIn => 'Entries close in';

  @override
  String gameFetProgressValue(int current, int maximum, String tier) {
    return '$current of $maximum, $tier tier';
  }

  @override
  String gamePickForTeams(String outcome, String home, String away) {
    return '$outcome pick for $home versus $away';
  }

  @override
  String get gameSelectedPick => 'Selected pick';

  @override
  String get gameAddPickToRound => 'Add pick to round';

  @override
  String gameNotificationSemantics(String title, String message) {
    return 'Notification: $title. $message';
  }

  @override
  String get gameDismissNotificationHint => 'Tap or swipe up to dismiss';

  @override
  String get gameClubContextRequired => 'Club context is required.';

  @override
  String get gameUnexpectedResponse => 'Unexpected response from server.';

  @override
  String get gameBack => 'Back';

  @override
  String get gameRetry => 'Retry';

  @override
  String get gameOpenPredictionAlert => 'Open';

  @override
  String get gameBadgesTitle => 'Your badges';

  @override
  String get gameBadgesUnavailable => 'Badges unavailable';

  @override
  String get gameBadgesTemporarilyUnavailable =>
      'Badges are temporarily unavailable.';

  @override
  String gameBadgeSemantics(String name) {
    return '$name badge';
  }

  @override
  String get gameOpenBadgeDetails => 'Open badge details';

  @override
  String get gamePredictionAlertsTitle => 'Prediction alerts';

  @override
  String get gameAlertsUnavailable => 'Alerts unavailable';

  @override
  String get gamePredictionAlertsTemporarilyUnavailable =>
      'Prediction alerts are temporarily unavailable.';

  @override
  String gamePredictionAlertSemantics(
    String title,
    String message,
    String date,
    String reward,
  ) {
    return 'Prediction alert, $title, $message, $date$reward';
  }

  @override
  String gameRewardPointsSemantics(int count) {
    return ', reward $count points';
  }

  @override
  String get gameJustNow => 'Just now';

  @override
  String get gameStreakTitle => 'Your streak';

  @override
  String gameStreakDays(int count) {
    return '$count DAYS';
  }

  @override
  String get gameStreakActive => 'Streak active.';

  @override
  String get gameCurrent => 'Current';

  @override
  String get gameBest => 'Best';

  @override
  String get gameNextBonus => 'Next bonus';

  @override
  String gameWins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wins',
      one: '1 win',
    );
    return '$_temp0';
  }

  @override
  String gameStreakDaySemantics(int day, String wins) {
    return 'Streak day $day: $wins';
  }

  @override
  String get gameVerifyToPredict => 'Verify to predict';

  @override
  String get gameMakePicks => 'Make Picks';

  @override
  String get gameMakePicksDescription => 'Pick matches across all leagues';

  @override
  String get gameEarnPoints => 'Earn Points';

  @override
  String get gameEarnPointsDescription => 'Earn points for correct picks';

  @override
  String get gameClimbLeaderboards => 'Climb Leaderboards';

  @override
  String get gameClimbLeaderboardsDescription =>
      'Compete against friends and fans';

  @override
  String get gameVerifyNow => 'Verify now';

  @override
  String get gameJustBrowsing => 'Just browsing';

  @override
  String get gameOffersTitle => 'Offers';

  @override
  String get gameOffersUnavailable => 'Offers unavailable';

  @override
  String get gameOffersTemporarilyUnavailable =>
      'Partner offers are temporarily unavailable.';

  @override
  String get gameWaysToEarn => 'Ways to earn';

  @override
  String get gameWaysToEarnDescription =>
      'Join campaigns and activations to earn points.';

  @override
  String get gameBalance => 'Balance';

  @override
  String get gameAvailable => 'Available';

  @override
  String gameActiveOffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active offers',
      one: '1 active offer',
    );
    return '$_temp0';
  }

  @override
  String get gameFeatured => 'Featured';

  @override
  String get gameMatchDay => 'Match Day';

  @override
  String get gameAlwaysOn => 'Always On';

  @override
  String get gameReward => 'Reward';

  @override
  String get gameActivation => 'Activation';

  @override
  String get gameVerification => 'Verification';

  @override
  String get gameCondition => 'Condition';

  @override
  String get gameClose => 'Close';

  @override
  String get gameDetails => 'Details';

  @override
  String gamePointBalance(int count) {
    return '$count pts';
  }

  @override
  String gameFormattedPoints(String amount) {
    return '$amount pts';
  }

  @override
  String get gameVerificationApi => 'Partner API confirmation';

  @override
  String get gameVerificationRenewal => 'Renewal confirmation';

  @override
  String get gameVerificationReferral => 'Referral conversion';

  @override
  String get gameVerificationReceipt => 'Receipt or POS scan';

  @override
  String get gameVerificationGeo => 'GPS or venue check-in';

  @override
  String get gameVerificationSocial => 'Social post verification';

  @override
  String get gameVerificationSavings => 'Savings milestone confirmation';

  @override
  String get gameVerificationEcommerce => 'Store purchase confirmation';

  @override
  String get gameVerificationMobility => 'Ride completion confirmation';

  @override
  String get gameVerificationEventQr => 'Event QR validation';

  @override
  String get gameVerificationManual => 'Manual partner review';

  @override
  String get gameSettingsUpper => 'Settings';

  @override
  String get gamePrivacyUpper => 'Privacy';

  @override
  String get gameCoreGuarantees => 'Core guarantees';

  @override
  String get gamePhoneNumberHidden => 'Phone Number Hidden';

  @override
  String get gamePhoneNumberHiddenDescription =>
      'Your WhatsApp or phone number is encrypted and stored only on the server. It is never exposed to other users, club administrators, or public leaderboards.';

  @override
  String get gameAnonymousContributions => 'Anonymous Contributions';

  @override
  String get gameAnonymousContributionsDescription =>
      'MoMo contributions to fan clubs are logged using only your Fan ID and amount bracket. Exact amounts and phone numbers are not recorded.';

  @override
  String get gameVisibilityControls => 'Visibility controls';

  @override
  String get gameShowRealName => 'Show Real Name';

  @override
  String get gameShowRealNameDescription =>
      'When off, your Fan ID appears on leaderboards instead of your real name.';

  @override
  String get gameFindableByPhone => 'Findable by Phone';

  @override
  String get gameFindableByPhoneDescription =>
      'Allows friends to find you by phone number. Your number stays private.';

  @override
  String get gamePrivacyFirst => 'Privacy First';

  @override
  String gamePrivacyFirstDescription(String appName) {
    return '$appName does not sell, share, or expose your personal data. All identifiers on the platform are anonymized.';
  }

  @override
  String get gameRewardsStoreTitle => 'Rewards store';

  @override
  String get gameRewardsUnavailable => 'Rewards unavailable';

  @override
  String get gameRewardsTemporarilyUnavailable =>
      'Rewards are temporarily unavailable.';

  @override
  String get gameAvailableBalance => 'Available balance';

  @override
  String gameRewardsStoreDescription(String appName) {
    return 'Redeem $appName rewards without leaving the consolidated wallet flow.';
  }

  @override
  String gameRewardMeta(String category, String notes) {
    return '$category · $notes';
  }

  @override
  String gameRedeemCost(String cost) {
    return 'Redeem $cost';
  }

  @override
  String gameNeedCost(String cost) {
    return 'Need $cost';
  }

  @override
  String get gameRewardConfigurationMissing =>
      'Reward configuration is missing. Try again later.';

  @override
  String get gameRewardAlreadyRedeemed =>
      'That reward redemption already completed.';

  @override
  String gameRewardRedeemed(String reward, String cost) {
    return 'Redeemed $reward for $cost.';
  }

  @override
  String get gameRewardCouldNotRedeem => 'Could not redeem this reward.';

  @override
  String get gameFriendsTitle => 'Friends';

  @override
  String get gameSupportersUnavailable => 'Supporters unavailable';

  @override
  String get gameSupportersTemporarilyUnavailable =>
      'Supporters are temporarily unavailable.';

  @override
  String get gameSearchSupporterHint => 'Search supporter alias or ID';

  @override
  String get gameDone => 'Done.';

  @override
  String get gameResults => 'Results';

  @override
  String get gameYourFriends => 'Your friends';

  @override
  String get gameChallenge => 'Challenge';

  @override
  String get gameAccept => 'Accept';

  @override
  String get gamePending => 'Pending';

  @override
  String get gameAdd => 'Add';

  @override
  String get gameOnline => 'Online';

  @override
  String get gameFixturesTitle => 'Fixtures';

  @override
  String get gameFixturesUnavailable => 'Fixtures unavailable';

  @override
  String get gameFixturesCouldNotLoad => 'Could not load fixtures right now.';

  @override
  String get gameAll => 'All';

  @override
  String get gameToday => 'Today';

  @override
  String get gameTomorrow => 'Tomorrow';

  @override
  String get gameYesterday => 'Yesterday';

  @override
  String gameRelativeDate(String relative, String date) {
    return '$relative · $date';
  }

  @override
  String gameMatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches',
      one: '1 match',
    );
    return '$_temp0';
  }

  @override
  String get gameMyActivity => 'My activity';

  @override
  String gameActiveCount(int count) {
    return 'ACTIVE ($count)';
  }

  @override
  String gameSettledTabCount(int count) {
    return 'SETTLED ($count)';
  }

  @override
  String gameHistoryCount(int count) {
    return 'HISTORY ($count)';
  }

  @override
  String get gameActivityUnavailable => 'Activity unavailable';

  @override
  String get gameActivityCouldNotLoad =>
      'Could not load your activity right now.';

  @override
  String get gameCouldNotCancelPick => 'Could not cancel this pick.';

  @override
  String get gameWon => 'Won';

  @override
  String get gameLost => 'Lost';

  @override
  String get gameCancelled => 'Cancelled';

  @override
  String get gameVoid => 'Void';

  @override
  String get gamePendingUpper => 'Pending';

  @override
  String get gameTbd => 'Tbd';

  @override
  String gameVersusShort(String home, String away) {
    return '$home vs $away';
  }

  @override
  String get gameRound => 'Round';

  @override
  String gameCompetitionTime(String competition, String time) {
    return '$competition • $time';
  }

  @override
  String get gameCancel => 'Cancel';

  @override
  String gameActivitySemantics(String home, String away) {
    return '$home versus $away activity';
  }

  @override
  String get gameOpenActivityDetail => 'Open activity detail';

  @override
  String get gameNotificationsUpper => 'Notifications';

  @override
  String get gameKickoffAlerts => 'Match Kick-off Alerts';

  @override
  String get gameRoundResults => 'Round Results';

  @override
  String get gameFriendChallenges => 'Friend Challenges';

  @override
  String get gameLineupsUpper => 'Lineups';

  @override
  String get gameSubstitutes => 'Subs';

  @override
  String get gameActiveUpper => 'Active';

  @override
  String get gameWinRate => 'Win rate';

  @override
  String get gameYouUpper => 'You';

  @override
  String gameWalletSignedPoints(String sign, String amount) {
    return '$sign$amount pts';
  }

  @override
  String gameWalletBalance(String amount) {
    return 'Bal. $amount pts';
  }

  @override
  String get gameOpenUpper => 'Open';

  @override
  String get gamePointsShare => 'Points share';

  @override
  String get gamePointsShareDescription =>
      'Tier rules decide how earned points support you and collective club rewards.';

  @override
  String gamePersonalPercentage(int count) {
    return '$count% you';
  }

  @override
  String gameClubPercentage(int count) {
    return '$count% club';
  }

  @override
  String gameTierSplit(int personal, int club) {
    return '$personal/$club';
  }

  @override
  String get gamePointsShareExplanation =>
      'Your points are shared by tier: the personal share stays with you and the club share supports collective rewards.';

  @override
  String get gameTierSupporter => 'Supporter';

  @override
  String get gameTierMember => 'Member';

  @override
  String get gameTierUltra => 'Ultra';

  @override
  String get gameTierLegend => 'Legend';

  @override
  String get gameFree => 'Free';

  @override
  String gameMonthlyPrice(String amount) {
    return '$amount RWF / month';
  }

  @override
  String gameShareTitle(String appName) {
    return '$appName Pick';
  }

  @override
  String get gameShareCopied => 'Share text copied to clipboard.';

  @override
  String gameShareStatusLine(String status, String home, String away) {
    return '$status: $home vs $away';
  }

  @override
  String gameFinalScore(int home, int away) {
    return 'Final score: $home-$away';
  }

  @override
  String gameMarketSelection(String market, String selection) {
    return '$market: $selection';
  }

  @override
  String gameEarnedShare(int count) {
    return 'Earned: +$count pts';
  }

  @override
  String gamePotentialShare(int count) {
    return 'Potential: +$count pts';
  }

  @override
  String get gameMarketUpper => 'Market';

  @override
  String get gamePickUpper => 'Pick';

  @override
  String get gameEarnedUpper => 'Earned';

  @override
  String get gamePotentialUpper => 'Potential';

  @override
  String gameShareTagline(String appName) {
    return '$appName · PLAY. PICK. EARN.';
  }

  @override
  String gamePickTypeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pick types',
      one: '1 pick type',
    );
    return '$_temp0';
  }

  @override
  String get gameSearchPickTypes => 'Search pick types';

  @override
  String get gameClearSearch => 'Clear search';

  @override
  String get gameAddPicksToUnlock => 'Add picks to unlock round';

  @override
  String gameOpenRoundSummary(int count, int points) {
    return 'Open Round · $count picks · $points pts';
  }

  @override
  String get gameLiveOnly => 'Live only';

  @override
  String gameOutcomeAddedToRound(String outcome) {
    return '$outcome added to your round.';
  }

  @override
  String get gameMarkets => 'Markets';

  @override
  String gameMarketCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count markets',
      one: '1 market',
    );
    return '$_temp0';
  }

  @override
  String get gameStatsNotAvailableYet => 'Stats not yet available';

  @override
  String get gameLiveStatsUpdating =>
      'Live stats update automatically during the match.';

  @override
  String get gameLiveMatchDataUpdating =>
      'Live match-center data is updating for this fixture.';

  @override
  String get gameStructuredMatchStats =>
      'Structured match-center statistics for this fixture.';

  @override
  String get gameTotalGoals => 'Total Goals';

  @override
  String get gameFinalMatchStats => 'Final match statistics.';

  @override
  String gameFixtureMarketTitle(String home, String away, String market) {
    return '$home vs $away · $market';
  }

  @override
  String get gamePickTypeLocked => 'Pick type locked for this fixture state.';

  @override
  String get gameLeaderboardTitle => 'Leaderboard';

  @override
  String get gameFetRanking => 'FET Ranking';

  @override
  String get gameSupporters => 'Supporters';

  @override
  String get gameAllTime => 'All time';

  @override
  String get gameWeekly => 'Weekly';

  @override
  String get gameMonthly => 'Monthly';

  @override
  String get gameLeaderboardUnavailable => 'Leaderboard unavailable';

  @override
  String get gameLeaderboardTemporarilyUnavailable =>
      'Leaderboard is temporarily unavailable.';

  @override
  String get gameRankingsUnavailable => 'Rankings unavailable';

  @override
  String get gameSupporterRankingsTemporarilyUnavailable =>
      'Supporter rankings are temporarily unavailable.';

  @override
  String get gameNotSignedIn => 'Not signed in';

  @override
  String get gameTierFan => 'Fan';

  @override
  String get gameDisplayNameOn => 'Display Name On';

  @override
  String get gameAliasOnly => 'Alias Only';

  @override
  String gameDisplayNameOnDescription(String name) {
    return 'Leaderboards can show $name instead of only your Fan ID.';
  }

  @override
  String get gameAliasOnlyDescription =>
      'Leaderboards show your Fan ID or alias instead of your real name.';

  @override
  String get gamePhoneHidden => 'Phone Hidden';

  @override
  String get gamePhoneHiddenDescription =>
      'Your phone number stays on the server and is never shown to other supporters or club administrators.';

  @override
  String get gamePhoneDiscoveryOn => 'Phone Discovery On';

  @override
  String get gamePhoneDiscoveryOff => 'Phone Discovery Off';

  @override
  String get gamePhoneDiscoveryOnDescription =>
      'Friends who already know your phone number can find your profile.';

  @override
  String get gamePhoneDiscoveryOffDescription =>
      'Phone-based discovery is currently disabled on your profile.';

  @override
  String get gameVerified => 'Verified';

  @override
  String get gameVerificationPending => 'Verification Pending';

  @override
  String gameVerifiedDescription(String appName) {
    return 'Your phone identity is verified for $appName earning and social flows.';
  }

  @override
  String gameVerificationPendingDescription(String appName) {
    return 'Verify your phone to unlock the full $appName social experience.';
  }

  @override
  String get gameFanIdPersistentRule =>
      'Your Fan ID comes from your profile and remains the same when you return.';

  @override
  String gameDisplayNameVisibleRule(String name) {
    return 'Your display name “$name” can appear on leaderboards until you turn that off.';
  }

  @override
  String get gameRealNameHiddenRule =>
      'Your real name stays hidden on leaderboards until you explicitly enable display-name visibility.';

  @override
  String get gamePhoneEncryptedRule =>
      'Your phone number is encrypted and stored only on the server.';

  @override
  String get gamePhoneDiscoveryEnabledRule =>
      'Phone-based friend discovery is enabled on your account right now.';

  @override
  String get gamePhoneDiscoveryDisabledRule =>
      'Phone-based friend discovery is disabled on your account right now.';

  @override
  String gamePhoneVerifiedRule(String appName) {
    return 'Your phone identity is verified for $appName features and rewards.';
  }

  @override
  String gamePhonePendingRule(String appName) {
    return 'Phone verification is still pending for your $appName profile.';
  }

  @override
  String gameTeamLinkedRule(String team) {
    return 'Your profile is linked to $team for personalization.';
  }

  @override
  String get gameLinkTeamRule =>
      'You can link a favorite team from onboarding or profile setup for personalization.';

  @override
  String get gameDeleteAccountRule =>
      'Deleting your account removes your personal data and Fan ID mapping from the active profile.';

  @override
  String get gameFanIdTitle => 'Fan id';

  @override
  String get gameYourFanId => 'Your fan id';

  @override
  String get gameAliasOnlyProfile => 'Alias-only profile';

  @override
  String get gameFanIdCopied => 'Fan ID copied to clipboard.';

  @override
  String get gameCopyToClipboard => 'Copy to clipboard';

  @override
  String get gamePrivacyBadges => 'Privacy badges';

  @override
  String get gameIdentityRules => 'Identity rules';

  @override
  String get gameIdentityRulesDescription =>
      'How your Fan ID works based on your current profile settings.';

  @override
  String get gameStandingsTitle => 'Standings';

  @override
  String get gameCompetitionNotFound => 'Competition not found.';

  @override
  String get gameStandingsTemporarilyUnavailable =>
      'Standings are temporarily unavailable.';

  @override
  String get gameStandingsUnavailable => 'Standings unavailable';

  @override
  String get gamePositionShort => 'Pos';

  @override
  String get gameTeamUpper => 'Team';

  @override
  String get gamePointsShort => 'Pts';

  @override
  String get gamePointsUpper => 'Points';

  @override
  String gameStandingRecord(
    int played,
    int goalsFor,
    int goalsAgainst,
    int difference,
  ) {
    return '${played}P · $goalsFor:$goalsAgainst · GD $difference';
  }

  @override
  String get gameHeadToHead => 'Head to head';

  @override
  String gameHeadToHeadEmpty(String home, String away) {
    return 'Historical head-to-head records between $home and $away will appear here.';
  }

  @override
  String get gameWinDistribution => 'Win distribution';

  @override
  String get gameDraws => 'Draws';

  @override
  String gameTeamGoals(String team) {
    return '$team GOALS';
  }

  @override
  String get gameRecentEncounters => 'Recent encounters';

  @override
  String gameScore(int home, int away) {
    return '$home - $away';
  }

  @override
  String get gameTokenHistoryTitle => 'Token history';

  @override
  String get gameTokenHistoryTemporarilyUnavailable =>
      'Token history is temporarily unavailable.';

  @override
  String get gameHistoryUnavailable => 'History unavailable';

  @override
  String get gameEarned => 'Earned';

  @override
  String get gameSpent => 'Spent';

  @override
  String get gameAllUpper => 'All';

  @override
  String get gameEarnedUpperFilter => 'Earned';

  @override
  String get gameSpentUpper => 'Spent';

  @override
  String get gameCredit => 'Credit';

  @override
  String get gameDebit => 'Debit';

  @override
  String get gameLedgerUpdate => 'Ledger update';

  @override
  String gameTransactionSemantics(
    String direction,
    String headline,
    String detail,
    int amount,
    int balance,
    String date,
  ) {
    return '$direction transaction, $headline, $detail, $amount points, balance $balance points, $date';
  }

  @override
  String get gameUnknownTime => 'Unknown time';

  @override
  String get gameClubFanZoneTitle => 'Club fan zone';

  @override
  String get gameClubFanZoneTemporarilyUnavailable =>
      'Club fan zone is temporarily unavailable.';

  @override
  String get gameFanZoneUnavailable => 'Fan zone unavailable';

  @override
  String get gameSupporterPulse => 'Supporter pulse';

  @override
  String get gameSupporterPulseDescription =>
      'Real supporter momentum around active competitions, fixture picks, and top clubs.';

  @override
  String get gameTopClubs => 'Top clubs';

  @override
  String gameRankHash(int rank) {
    return '#$rank';
  }

  @override
  String get gameSupporterLeans => 'Supporter leans';

  @override
  String gameSupporterLeansEmpty(String appName) {
    return 'Community pick distribution will appear once this competition has active $appName predictions.';
  }

  @override
  String gamePair(String first, String second) {
    return '$first · $second';
  }

  @override
  String gameSupporterLeanPercentage(String percentage) {
    return '$percentage% of supporters currently lean this way.';
  }

  @override
  String get gameLeagueHubTitle => 'League hub';

  @override
  String get gameLeagueDataTemporarilyUnavailable =>
      'League data is temporarily unavailable.';

  @override
  String get gameLeagueUnavailable => 'League unavailable';

  @override
  String get gameCompetition => 'Competition';

  @override
  String get gameRegion => 'Region';

  @override
  String get gameLeague => 'League';

  @override
  String get gameTeams => 'Teams';

  @override
  String get gameFixtures => 'Fixtures';

  @override
  String get gameLeader => 'Leader';

  @override
  String get gameTopTable => 'Top table';

  @override
  String get gameFullStandings => 'Full standings';

  @override
  String gameLeagueStandingRecord(int played, int won, int drawn, int lost) {
    return '${played}P · ${won}W ${drawn}D ${lost}L';
  }

  @override
  String get gameEntrySubmitted => 'Entry submitted';

  @override
  String get gameBonusEntryLive => 'Your bonus entry is now live.';

  @override
  String get gameCouldNotSubmitBonus =>
      'Could not submit the bonus entry right now.';

  @override
  String get gameKickoffTbd => 'Kick-off TBD';

  @override
  String get gameBonusRound => 'Bonus Round';

  @override
  String get gameSubmitting => 'Submitting…';

  @override
  String get gameEntriesClosedSentence => 'Entries closed';

  @override
  String get gameSubmitEntry => 'Submit entry';

  @override
  String get gameBonusRoundActivationPending =>
      'Bonus round activation is pending.';

  @override
  String get gameBonusRoundTemporarilyUnavailable =>
      'Bonus round is temporarily unavailable.';

  @override
  String get gameBonusRoundUnavailable => 'Bonus round unavailable';

  @override
  String get gamePointsPool => 'Points pool';

  @override
  String get gamePickAllFeatured =>
      'Pick every featured fixture before the round locks.';

  @override
  String gamePicksComplete(int selected, int total) {
    return '$selected of $total picks complete';
  }

  @override
  String gameEntriesRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries remaining',
      one: '1 entry remaining',
    );
    return '$_temp0';
  }

  @override
  String get gameLeaders => 'Leaders';

  @override
  String get gameSocialHub => 'Social Hub';

  @override
  String get gameClub => 'Club';

  @override
  String get gameSearchYourFriends => 'Search your friends';

  @override
  String get gameBrowse => 'Browse';

  @override
  String get gameViewAll => 'View all';

  @override
  String get gameClubStandingsTemporarilyUnavailable =>
      'Club standings are temporarily unavailable.';

  @override
  String get gameClubStandingsUnavailable => 'Club standings unavailable';

  @override
  String get gameClubStanding => 'Club standing';

  @override
  String get gameUnranked => 'Unranked';

  @override
  String get gameEarnPointsForClubTable =>
      'Earn points to appear in the club table.';

  @override
  String gamePointsEarnedSoFar(int count) {
    return '$count pts earned so far.';
  }

  @override
  String gameNameYou(String name) {
    return '$name (You)';
  }

  @override
  String get gameChallengeFlowTemporarilyUnavailable =>
      'Challenge flow is temporarily unavailable.';

  @override
  String gameHeadToHeadMessage(String appName, String home, String away) {
    return '$appName head-to-head on $home vs $away';
  }

  @override
  String get gameChallengeSent => 'Challenge sent';

  @override
  String get gameChallengeWaiting =>
      'Your challenge is waiting for a response.';

  @override
  String get gameCouldNotSendChallenge =>
      'Could not send the challenge right now.';

  @override
  String get gameSending => 'Sending…';

  @override
  String get gameSendChallenge => 'Send challenge';

  @override
  String get gameChallengeUnavailable => 'Challenge unavailable';

  @override
  String get gameSupporter => 'Supporter';

  @override
  String get gameAddFriendsBeforeChallenge =>
      'Add friends before sending a challenge.';

  @override
  String get gameFindFriends => 'Find friends';

  @override
  String get gameFixture => 'Fixture';

  @override
  String get gamePick => 'Pick';

  @override
  String get gameSelected => 'Selected';

  @override
  String get gameChoose => 'Choose';

  @override
  String get gameTeamNotFound => 'Team not found.';

  @override
  String get gameTeamProfileTemporarilyUnavailable =>
      'Team profile is temporarily unavailable.';

  @override
  String get gameSupporterActivityActiveClubOnly =>
      'Supporter activity is only available for the active club.';

  @override
  String get gameSupporterRoutingCurrentClubOnly =>
      'Supporter registry and contribution routing are available for the current app club only.';

  @override
  String get gameContributionRouteNotPublished =>
      'This club has not published an active contribution route yet.';

  @override
  String get gameClubSupporterDataUnavailable =>
      'Club supporter data is temporarily unavailable.';

  @override
  String get gameContributionsActiveClubOnly =>
      'Contributions are available only for the active club.';

  @override
  String get gameContributionRouteUnavailable =>
      'Contribution route unavailable.';

  @override
  String get gameCouldNotOpenDialer => 'Could not open the phone dialer.';

  @override
  String get gameDialerLaunchFailed => 'Dialer launch failed.';

  @override
  String get gameEnterContributionAmount => 'Enter contribution amount';

  @override
  String gamePaymentRouteDescription(String recipient, String provider) {
    return 'You will pay $recipient via $provider.';
  }

  @override
  String gameAmountCurrency(String currency) {
    return 'Amount ($currency)';
  }

  @override
  String get gameDialNow => 'Dial now';

  @override
  String get gameEnterValidAmount => 'Enter a valid amount.';

  @override
  String get gameTeamProfileTitle => 'Team profile';

  @override
  String get gameTeamUnavailable => 'Team unavailable';

  @override
  String gameFoundedYear(int year) {
    return 'Founded $year';
  }

  @override
  String get gameTable => 'Table';

  @override
  String get gameSquad => 'Squad';

  @override
  String get gameOverview => 'Overview';

  @override
  String get gameMembers => 'Members';

  @override
  String get gameContribute => 'Contribute';

  @override
  String get gameAbout => 'About';

  @override
  String get gameLeaguePosition => 'League position';

  @override
  String get gamePlayedShort => 'P';

  @override
  String get gameWonShort => 'W';

  @override
  String get gameDrawnShort => 'D';

  @override
  String get gameLostShort => 'L';

  @override
  String get gameGoalDifferenceShort => 'Gd';

  @override
  String get gameMomoContributionRoute => 'MoMo contribution route';

  @override
  String gameUseProviderForClub(String provider, String club) {
    return 'Use $provider to contribute to $club.';
  }

  @override
  String get gameThisClub => 'this club';

  @override
  String get gameSupporterRegistryCurrentClubOnly =>
      'Supporter registry is available only for the current app club.';

  @override
  String get gameMembersUnavailable => 'Members unavailable';

  @override
  String get gameClubMembers => 'Club members';

  @override
  String get gameTierGold => 'Gold';

  @override
  String get gameTierSilver => 'Silver';

  @override
  String get gameTierBronze => 'Bronze';

  @override
  String get gameTierImena => 'Imena';

  @override
  String get gameTopContributors => 'Top contributors';

  @override
  String get gameMomoContribution => 'MoMo contribution';

  @override
  String gameUseProviderInCountry(String provider, String country) {
    return 'Use $provider in $country to contribute to this club.';
  }

  @override
  String get gameEnterAmount => 'Enter amount';

  @override
  String gameEnterAmountDescription(String provider) {
    return 'Choose how much you want to send through $provider.';
  }

  @override
  String get gameConfirmInDialer => 'Confirm in dialer';

  @override
  String gameConfirmInDialerDescription(String code) {
    return 'We will open the mobile money dialer for code $code.';
  }

  @override
  String get gameReconciliation => 'Reconciliation';

  @override
  String get gameReconciliationDescription =>
      'Your contribution is matched back to your club activity once payment is confirmed.';

  @override
  String get gameOpeningDialer => 'Opening dialer…';

  @override
  String get gameEnterAmountAndDial => 'Enter amount & dial';

  @override
  String gameAboutTeam(String team) {
    return 'ABOUT $team';
  }

  @override
  String get gameThisClubUpper => 'This club';

  @override
  String get gameLocation => 'Location';

  @override
  String get gameCountry => 'Country';

  @override
  String get gameFounded => 'Founded';

  @override
  String get gameType => 'Type';

  @override
  String get gameAffiliatedClub => 'Affiliated Club';

  @override
  String get gameSelectedLeaderboardPeriod => 'Selected leaderboard period';

  @override
  String get gameSelectPeriod => 'Select period';

  @override
  String gameRankLabel(String rank) {
    return '#$rank';
  }

  @override
  String get gameRankPending => 'Rank pending';

  @override
  String gameAccuracyWins(String accuracy, int wins) {
    String _temp0 = intl.Intl.pluralLogic(
      wins,
      locale: localeName,
      other: '$wins wins',
      one: '1 win',
    );
    return '$accuracy% accuracy · $_temp0';
  }

  @override
  String gameSettledCount(int count) {
    return '$count settled';
  }

  @override
  String gameTierAlias(String tier, String alias) {
    return '$tier tier · $alias';
  }

  @override
  String gamePodiumRank(int rank) {
    return 'Podium rank $rank';
  }

  @override
  String get gamePickRound => 'Pick round';

  @override
  String gameActivePicks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count picks active',
      one: '1 pick active',
    );
    return '$_temp0';
  }

  @override
  String gameEarnUpToPoints(int count) {
    return 'Earn up to $count pts';
  }

  @override
  String get gamePickRoundEmpty => 'Pick round is empty';

  @override
  String get gamePickRoundEmptyDescription =>
      'Add picks from any fixture and lock them in from here.';

  @override
  String get gamePickRoundUpper => 'Pick round';

  @override
  String get gameAcca => 'Acca';

  @override
  String gamePotentialPoints(int count) {
    return 'Potential points: $count pts';
  }

  @override
  String get gameLockInPicks => 'Lock In Picks';

  @override
  String get gameSomeSelectionsFailed =>
      'Some selections could not be submitted.';

  @override
  String get gameCouldNotSubmitPicks => 'Could not submit your picks.';

  @override
  String get gameConfirmPicks => 'Confirm picks';

  @override
  String gameLockingCombo(int count) {
    return 'You are locking $count picks as a combo.';
  }

  @override
  String gameLockingPicks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You are locking $count picks.',
      one: 'You are locking 1 pick.',
    );
    return '$_temp0';
  }

  @override
  String gameOutcomePotential(String outcome, int count) {
    return '$outcome · +$count pts';
  }

  @override
  String get gameTotalPotential => 'Total potential';

  @override
  String get gameGoBack => 'Go back';

  @override
  String gamePredictionsLocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Predictions Locked',
      one: 'Prediction Locked',
    );
    return '$_temp0';
  }

  @override
  String gameRoundId(String id) {
    return 'Round ID: $id';
  }

  @override
  String get gameShareUpper => 'Share';

  @override
  String get gameCopyUpper => 'Copy';

  @override
  String get gameViewMyPredictions => 'View my predictions';

  @override
  String get gameKeepBrowsing => 'Keep browsing';

  @override
  String get gameRemovePick => 'Remove pick';

  @override
  String get gameFans => 'Fans';

  @override
  String get gameWallet => 'Wallet';

  @override
  String get gameMore => 'More';

  @override
  String get gameRoundUpper => 'Round';

  @override
  String gameAccuracyRounds(String accuracy, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rounds',
      one: '1 round',
    );
    return '$accuracy% · $_temp0';
  }

  @override
  String gamePointsRound(int count) {
    return '$count points round';
  }

  @override
  String get gamePointsRoundLabel => 'points round';

  @override
  String gamePointEntry(int count) {
    return '$count point entry';
  }

  @override
  String gameFansCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fans',
      one: '1 fan',
    );
    return '$_temp0';
  }

  @override
  String get gameChooseWdw => 'Choose W/D/W';

  @override
  String get gameJoinRound => 'Join round';

  @override
  String gameSelectedOutcome(String outcome) {
    return 'Selected $outcome';
  }

  @override
  String get gameChallengesTitle => 'Challenges';

  @override
  String get gameChallengesTemporarilyUnavailable =>
      'Challenges are temporarily unavailable.';

  @override
  String get gameChallengesUnavailable => 'Challenges unavailable';

  @override
  String get gameDaily => 'Daily';

  @override
  String get gameWeeklyUpper => 'Weekly';

  @override
  String get gameSeasonal => 'Seasonal';

  @override
  String get gameCompleted => 'Completed';

  @override
  String get gameChallengesRequireProfile =>
      'Challenges appear once your supporter profile is active.';

  @override
  String get gameWhatIsFet => 'What is FET?';

  @override
  String get gameWhatIsFetBody =>
      'FET (Fan Engagement Tokens) are your supporter currency. Earn them by engaging with your club—attending matches, completing challenges, making predictions, and supporting the community.';

  @override
  String get gameHowPredictionsWork => 'How predictions work';

  @override
  String get gameHowPredictionsWorkBody =>
      'Browse upcoming fixtures, choose pick types such as Match Result, Goals, and Scorers, then lock in picks before kick-off. Correct picks earn points based on difficulty.';

  @override
  String get gameEarnLevelRedeem => 'Earn, level up & redeem';

  @override
  String get gameEarnLevelRedeemBody =>
      'Your points balance grows as you engage. Climb the leaderboard, unlock membership tiers, and redeem rewards from the club store. Every action counts.';

  @override
  String get gameBackUpper => 'Back';

  @override
  String get gameGetStarted => 'Get started';

  @override
  String get gameNext => 'Next';

  @override
  String get gameOpen => 'Open';

  @override
  String get gameRefresh => 'Refresh';

  @override
  String get gameMoreOptions => 'More options';

  @override
  String get gameConnectToFanZone => 'Connect to load Fan Zone.';

  @override
  String get gameOpeningFanZone => 'Opening Fan Zone';

  @override
  String get gameRefreshingFanZone => 'Refreshing Fan Zone';

  @override
  String get gameRefreshingFanZoneDescription =>
      'Keeping your current points, rounds, and picks visible while updates load.';

  @override
  String get gameMatchdayRounds => 'Matchday rounds';

  @override
  String get gameNoMatchdayRounds => 'No matchday rounds';

  @override
  String get gameReviewJoinedRounds =>
      'Review joined rounds, cards, and results';

  @override
  String get gameVenueCheckIn => 'Venue check-in';

  @override
  String get gameVenueOrder => 'Venue order';

  @override
  String get gameVenueOrderDescription =>
      'Order approved drinks and track pickup status';

  @override
  String get gameLiveNow => 'Live Now';

  @override
  String get gameThisWeek => 'This Week';

  @override
  String get gamePointsBalanceTitle => 'Points balance';

  @override
  String get gamePointsBalanceDescription =>
      'Balance, earning, rewards, and activity';

  @override
  String get gameActivity => 'Activity';

  @override
  String get gameOpenPointsActivity => 'Open recent points movement';

  @override
  String get gameSupporterClubs => 'Supporter clubs';

  @override
  String get gameSupporterClubsDescription =>
      'Fan clubs, chapters, and community groups';

  @override
  String get gameMemberFans => 'Member fans';

  @override
  String get gameMemberFansDescription =>
      'Open the supporter registry as a sheet';

  @override
  String get gameSupportClubDescription =>
      'Projects and supporter contribution groups';

  @override
  String get gameRedeemRewards => 'Redeem rewards';

  @override
  String get gameRedeemRewardsDescription =>
      'Use points for rewards and partner offers';

  @override
  String get gameAchievements => 'Achievements';

  @override
  String get gameAchievementsDescription => 'Badges and streak status';

  @override
  String get gameShareCard => 'Share card';

  @override
  String get gameShareCardDescription => 'Create a supporter card to share';

  @override
  String get gameConnectBeforeJoiningRound =>
      'Connect before joining this round.';

  @override
  String get gamePoolEntryFailed => 'Pool entry could not be recorded.';

  @override
  String gameOutcomeJoined(String outcome) {
    return '$outcome joined.';
  }

  @override
  String gamePartnerSponsorsRound(String partner) {
    return '$partner sponsors this matchday round. Pick once before the round locks.';
  }

  @override
  String get gameProjects => 'Projects';

  @override
  String get gameProjectsDescription => 'Club initiatives and campaign needs';

  @override
  String get gameGroups => 'Groups';

  @override
  String get gameGroupsDescription => 'Join supporter contribution groups';

  @override
  String get gameQrSheetDescription =>
      'QR display and sharing stay inside this sheet.';

  @override
  String get gameFanIdQrDisplay => 'Fan ID and QR display';

  @override
  String get gameQr => 'QR';

  @override
  String get gameBadgesEarnedDescription =>
      'Earned from picks, attendance, and support actions';

  @override
  String get gameStartStreak => 'Join your next round to start a streak';

  @override
  String gameActivePlayDays(int count) {
    return '$count active play days';
  }

  @override
  String gameActionUnavailable(String description) {
    return '$description. Unavailable.';
  }

  @override
  String get gameFanZoneAccessUnavailable => 'Fan Zone access not available';

  @override
  String get gameFanZoneAccessUnavailableDescription =>
      'Your account cannot open Fan Zone right now. Contact support if this should be available.';

  @override
  String get gameFanZoneChanged => 'Fan Zone changed';

  @override
  String get gameFanZoneChangedDescription =>
      'Fan Zone data changed while you were viewing it. Refresh to load the current version.';

  @override
  String get gameFanZoneSecurityTimedOut => 'Fan Zone security check timed out';

  @override
  String get gameFanZoneSecurityTimedOutDescription =>
      'We could not confirm current Fan Zone access. Refresh before continuing.';

  @override
  String get gameFanZoneTemporarilyUnavailable =>
      'Fan Zone is temporarily unavailable.';

  @override
  String get gameSavedFanZoneContent =>
      'Showing saved Fan Zone content. Reconnect and refresh for current fixtures and balances.';

  @override
  String get gamePickSectionLabel => 'Pick';

  @override
  String get gamePicksLabel => 'Picks';

  @override
  String get gameRewardsLabel => 'Rewards';

  @override
  String get gameStreakLabel => 'Streak';

  @override
  String get gameBadgesLabel => 'Badges';

  @override
  String get gamePointsLabel => 'Points';

  @override
  String get gameAccuracyLabel => 'Accuracy';

  @override
  String get gameFanZoneUnavailableTitle => 'Fan Zone unavailable';

  @override
  String get venueOrderConfirmedToast =>
      'Order confirmed by the venue service. Pay only at the venue.';

  @override
  String get venueOrderingUnavailable => 'Venue ordering unavailable';

  @override
  String get venueFeatureDisabled =>
      'This governed feature is disabled for the current club or build.';

  @override
  String get venueBackToFanZone => 'Back to fan zone';

  @override
  String get venueOrderAccessDenied => 'Venue order access denied';

  @override
  String get venueOrderAccessDeniedBody =>
      'This account cannot use the supporter venue-order route.';

  @override
  String get venueOrderAccessDeniedLoadBody =>
      'This account cannot load the supporter venue-order route.';

  @override
  String get venueCheckInBeforeOrdering => 'Check in before ordering';

  @override
  String get venueCheckInRequiredBody =>
      'A confirmed venue check-in is required before the approved drinks menu can be loaded.';

  @override
  String get venueCheckInFirst => 'Check in first';

  @override
  String get venueNoDrinksAvailable => 'No drinks available';

  @override
  String get venueNoDrinksBody =>
      'The checked-in venue has no approved active drinks right now.';

  @override
  String get venueRefreshMenu => 'Refresh menu';

  @override
  String get venueMenuUnavailableOffline => 'Venue menu unavailable offline';

  @override
  String get venueMenuOfflineBody =>
      'Reconnect before loading the venue menu. No order is queued offline.';

  @override
  String get venueTryAgain => 'Try again';

  @override
  String get venueMenuCheckTimedOut => 'Venue menu check timed out';

  @override
  String get venueMenuCheckTimedOutBody =>
      'The app could not establish a safe order context in time. Try one bounded refresh.';

  @override
  String get venueMenuUnavailableBody =>
      'The checked-in venue and approved menu could not be loaded safely.';

  @override
  String get venueOrderHero => 'Order drinks at this venue';

  @override
  String get venueOrderHeroBody =>
      'Choose from the approved drinks-only menu. Staff queue actions remain in the venue portal.';

  @override
  String get venueApprovedDrinks => 'Approved drinks';

  @override
  String get venueOrderReview => 'Order review';

  @override
  String venueOrderReviewValue(int count, String total) {
    return '$count items, $total';
  }

  @override
  String get venueLegalAgeConfirmation => 'Legal age confirmation';

  @override
  String get venueNotSelected => 'Not selected';

  @override
  String get venueAgeConfirmationRequired => 'Age confirmation required';

  @override
  String get venueAgeConfirmationBody =>
      'Confirm only if you meet the venueʼs legal age requirement. Venue staff may still verify eligibility.';

  @override
  String get venueRemoveConfirmation => 'Remove confirmation';

  @override
  String get venueConfirmLegalAge => 'Confirm legal age';

  @override
  String get venuePayAtVenue => 'Pay at the venue';

  @override
  String get venuePaymentDisclaimer =>
      'This app creates the drinks order only. It does not take payment or claim that payment succeeded.';

  @override
  String get venueCreatingOrderUpper => 'Creating order';

  @override
  String get venueOrderConfirmedUpper => 'Order confirmed';

  @override
  String get venueReviewCreateOrder => 'Review and create order';

  @override
  String get venueOrderProtections => 'Order protections';

  @override
  String get venueDuplicateSubmission => 'Duplicate submission';

  @override
  String get venueDuplicateSubmissionBody => 'One idempotency key per attempt';

  @override
  String get venueOfflineBehavior => 'Offline behavior';

  @override
  String get venueOfflineBehaviorBody => 'No queued or automatic replay';

  @override
  String get venueStaffControls => 'Staff controls';

  @override
  String get venueStaffControlsBody => 'Venue portal only';

  @override
  String venueItemsSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items selected',
      one: '1 item selected',
    );
    return '$_temp0';
  }

  @override
  String get venueShowingSavedMenu => 'Showing saved venue menu';

  @override
  String get venueShowingSavedMenuBody =>
      'Reconnect before creating the order. Nothing is queued or replayed offline.';

  @override
  String get venueCreatingOrder => 'Creating venue order';

  @override
  String get venueCreatingOrderBody =>
      'Wait for server confirmation. Do not repeat this order attempt.';

  @override
  String get venueOrderCreated => 'Order created';

  @override
  String venueOrderCreatedSummary(String status, String total) {
    return '$status · $total. Payment remains external at the venue.';
  }

  @override
  String get venueChooseDrink => 'Choose at least one drink';

  @override
  String get venueChooseDrinkBody =>
      'The order cannot be created with an empty selection.';

  @override
  String get venueCheckInRequired => 'Check-in required';

  @override
  String get venueCheckInRejectedBody =>
      'The venue did not accept this check-in for ordering. Check in again before retrying.';

  @override
  String get venueAgeSubmitBody =>
      'Confirm legal age before submitting an alcohol item.';

  @override
  String get venueDrinkChanged => 'A selected drink changed';

  @override
  String get venueDrinkChangedBody =>
      'Refresh the approved menu before retrying.';

  @override
  String get venueOrderAttemptPaused => 'Order attempt paused';

  @override
  String get venueOrderAttemptPausedBody =>
      'Another request may be active. Check the latest order before retrying.';

  @override
  String get venueOrderConfirmationUncertain => 'Order confirmation uncertain';

  @override
  String get venueOrderConfirmationUncertainBody =>
      'Do not resubmit. Check the latest venue order before dismissing.';

  @override
  String get venueOrderNotConfirmed => 'Order not confirmed';

  @override
  String get venueOrderNotConfirmedBody =>
      'The server did not confirm this order. Dismiss the warning before retrying.';

  @override
  String venueLatestOrder(String status) {
    return 'Latest order: $status';
  }

  @override
  String venueLatestOrderSummary(String total, String payment) {
    return '$total · $payment.';
  }

  @override
  String get venueReadyToOrder => 'Ready to order';

  @override
  String get venueReadyToOrderBody =>
      'Choose approved drinks, review the total, then create once.';

  @override
  String venueRemoveItem(String item) {
    return 'Remove $item';
  }

  @override
  String venueAddItem(String item) {
    return 'Add $item';
  }

  @override
  String venueDrinkSemantics(int count, String price) {
    return '$count selected, $price each';
  }

  @override
  String get venueAgeRestricted => 'Age restricted';

  @override
  String get venueWaitingForVenue => 'Waiting for venue';

  @override
  String get venueAccepted => 'Accepted';

  @override
  String get venuePreparing => 'Preparing';

  @override
  String get venueReadyForPickup => 'Ready for pickup';

  @override
  String get venueServed => 'Served';

  @override
  String get venueStatusPending => 'Status pending';

  @override
  String get venuePaidAtVenue => 'Paid at venue';

  @override
  String get venuePaymentWaived => 'Payment waived';

  @override
  String get venueRefundedExternally => 'Refunded externally';

  @override
  String get venuePaymentPending => 'Payment pending at venue';

  @override
  String get venueCheckinTitle => 'Venue check-in';

  @override
  String get venueCheckinUnavailable => 'Venue check-in unavailable';

  @override
  String get venueCheckinAccessDenied => 'Check-in access denied';

  @override
  String get venueCheckinAccessDeniedBody =>
      'This account cannot use the supporter check-in route.';

  @override
  String get venueCheckinSafeStateBody =>
      'The route could not establish a safe check-in state.';

  @override
  String get venueCheckinHero => 'Check in at an approved venue';

  @override
  String get venueCheckinHeroBody =>
      'Enter the rotating venue or QR code after you arrive. Supporter check-in never exposes staff or admin controls.';

  @override
  String get venueCheckinCodeLabel => 'Venue code';

  @override
  String get venueCheckinInputLabel => 'Venue or QR code';

  @override
  String get venueCheckinInputHint => 'Enter at least 4 characters';

  @override
  String get venueCheckinCheckingCodeUpper => 'Checking code';

  @override
  String get venueCheckinActionUpper => 'Check in';

  @override
  String get venueCheckinLocationConsentSemantics => 'Location review consent';

  @override
  String get venueCheckinOptionalLocationReview => 'Optional location review';

  @override
  String get venueCheckinConsentMarkedBody =>
      'Consent is marked for this attempt. This build still sends no coordinates; location-required campaigns remain pending review.';

  @override
  String get venueCheckinNoLocationBody =>
      'Precise location is not collected in this build. You may mark consent, but location-required campaigns remain pending review.';

  @override
  String get venueCheckinRemoveConsentUpper => 'Remove consent';

  @override
  String get venueCheckinMarkConsentUpper => 'Mark consent';

  @override
  String get venueCheckinPrivacyBoundary => 'Privacy boundary';

  @override
  String get venueCheckinPrivacyBoundaryBody =>
      'Raw rotating codes are hashed before submission and are not persisted by the app. No precise location is collected.';

  @override
  String get venueCheckinPausedOffline => 'Check-in paused offline';

  @override
  String get venueCheckinPausedOfflineBody =>
      'Reconnect before submitting. No check-in is queued or replayed.';

  @override
  String get venueCheckinCheckingCode => 'Checking venue code';

  @override
  String get venueCheckinCheckingCodeBody =>
      'Wait for the server result. Do not repeat this check-in.';

  @override
  String get venueCheckinPendingReview => 'Check-in pending review';

  @override
  String get venueCheckinConfirmed => 'Check-in confirmed';

  @override
  String get venueCheckinPendingReviewBody =>
      'The venue code was accepted, but a governed location or campaign check still needs review.';

  @override
  String venueCheckinFetRecorded(int count) {
    return '+$count FET recorded for this check-in.';
  }

  @override
  String get venueCheckinConfirmedNoReward =>
      'The venue accepted this check-in. No reward was promised.';

  @override
  String get venueCheckinReady => 'Ready for venue check-in';

  @override
  String get venueCheckinReadyBody =>
      'Use the current code only after you arrive on site.';

  @override
  String get venueCheckinInvalidCode => 'Code not accepted';

  @override
  String get venueCheckinInvalidCodeBody =>
      'Enter the current venue or QR code shown at the venue.';

  @override
  String get venueCheckinExpiredCode => 'Venue code expired';

  @override
  String get venueCheckinExpiredCodeBody =>
      'Ask the venue display for the current rotating code.';

  @override
  String get venueCheckinAlreadyCheckedIn => 'Already checked in';

  @override
  String get venueCheckinAlreadyCheckedInBody =>
      'The server found an existing check-in. No duplicate reward was created.';

  @override
  String get venueCheckinCampaignUnavailable => 'Check-in campaign unavailable';

  @override
  String get venueCheckinCampaignUnavailableBody =>
      'The campaign is paused, inactive, or has reached its governed budget.';

  @override
  String get venueCheckinConflict => 'Check-in conflict';

  @override
  String get venueCheckinConflictBody =>
      'Another attempt may already be active. Confirm the venue state before retrying.';

  @override
  String get venueCheckinConfirmationUncertain =>
      'Check-in confirmation uncertain';

  @override
  String get venueCheckinConfirmationUncertainBody =>
      'Do not repeat the code yet. Check your venue activity, then dismiss this warning.';

  @override
  String get venueCheckinUnavailableShort => 'Check-in unavailable';

  @override
  String get venueCheckinUnavailableBody =>
      'The server did not confirm the attempt. Dismiss this warning before retrying.';

  @override
  String get walletRewardsUnavailable => 'Rewards unavailable';

  @override
  String get walletDisabledBody =>
      'Points and reward activity are disabled for this build.';

  @override
  String get walletNoActivity => 'No points activity yet';

  @override
  String get walletNoActivityBody =>
      'Your confirmed points balance and reward activity will appear here.';

  @override
  String get walletOffline => 'Rewards offline';

  @override
  String get walletOfflineBody =>
      'Reconnect to load your confirmed points balance. Nothing is queued offline.';

  @override
  String get walletAccessDenied => 'Rewards access denied';

  @override
  String get walletAccessDeniedBody =>
      'This account cannot open the private points ledger.';

  @override
  String get walletCheckTimedOut => 'Points check timed out';

  @override
  String get walletCheckTimedOutBody =>
      'The app could not confirm your private points ledger in time. Try one bounded refresh.';

  @override
  String get walletUnavailableBody =>
      'Your points ledger could not be loaded. No private activity details were shown.';

  @override
  String walletBalanceValue(String points) {
    return '$points pts';
  }

  @override
  String get walletUsed => 'Used';

  @override
  String walletHistoricalPoints(String points) {
    return '$points points come from earlier rewards before activity history was enabled.';
  }

  @override
  String get walletEarn => 'Earn';

  @override
  String get walletEarnBody =>
      'Earn points from partner initiatives and promotions.';

  @override
  String get walletUseBody =>
      'Use points in rewards, matchday activities, and fan-zone challenges.';

  @override
  String get walletRewardsBody =>
      'Use points for matchday perks and partner rewards.';

  @override
  String get walletRewardsEmptyBody =>
      'Available rewards appear here when the club or partners publish them.';

  @override
  String get walletActivityEmptyBody =>
      'Points activity appears after partner rewards or matchday actions.';

  @override
  String get walletShowingSaved => 'Showing saved points';

  @override
  String get walletShowingSavedBody =>
      'Reconnect for the latest balance and activity. No action is queued offline.';

  @override
  String get walletRefreshing => 'Refreshing points';

  @override
  String get walletRefreshingBody =>
      'The confirmed balance stays visible while the latest ledger loads.';

  @override
  String get walletChangedElsewhere => 'Points changed elsewhere';

  @override
  String get walletChangedElsewhereBody =>
      'The saved balance stays visible. Refresh to confirm the latest ledger.';

  @override
  String get walletRefreshTimedOut => 'Points refresh timed out';

  @override
  String get walletRefreshTimedOutBody =>
      'The saved balance is still shown. Try one bounded refresh.';

  @override
  String get walletMayBeOutdated => 'Points may be out of date';

  @override
  String get walletMayBeOutdatedBody =>
      'The last confirmed balance stays visible while service is unavailable.';

  @override
  String get walletSavedUntilRefresh =>
      'The last confirmed balance stays visible until refresh succeeds.';

  @override
  String get gameShareOptionsClosed =>
      'Share options closed. Confirm the destination before publishing.';

  @override
  String get gameShareActionsUnavailable => 'Share actions unavailable';

  @override
  String get gameShareActionsUnavailableDescription =>
      'You can return to Fan Zone, but sharing is disabled for this build.';

  @override
  String get gameBackToFanZoneUpper => 'Back to fan zone';

  @override
  String get gamePredictionAccessDenied => 'Prediction access denied';

  @override
  String get gamePredictionAccessDeniedDescription =>
      'This account cannot open prediction history for sharing.';

  @override
  String get gameMakePickFirst => 'Make a pick first';

  @override
  String get gameShareCardsUnlock =>
      'Share cards unlock after a matchday pick.';

  @override
  String get gameBackToPicksUpper => 'Back to picks';

  @override
  String get gameShareCardsOffline => 'Share cards offline';

  @override
  String get gameShareCardsOfflineDescription =>
      'Reconnect to load your confirmed prediction history. Nothing is queued offline.';

  @override
  String get gameHistoryCheckTimedOut => 'History check timed out';

  @override
  String get gameHistoryCheckTimedOutDescription =>
      'The app could not confirm a safe prediction history in time. Try one bounded refresh.';

  @override
  String get gameTryAgainUpper => 'Try again';

  @override
  String get gameShareCardsUnavailable => 'Share cards unavailable';

  @override
  String get gameShareCardsUnavailableDescription =>
      'Prediction history could not be loaded. No private activity details were shown.';

  @override
  String get gameShowingSavedShareCard => 'Showing saved share card';

  @override
  String get gameShowingSavedShareCardDescription =>
      'Reconnect before sharing or copying. No action is queued offline.';

  @override
  String get gameCopyingShareText => 'Copying share text';

  @override
  String get gameOpeningShareOptions => 'Opening share options';

  @override
  String get gameShareAwaitPlatformConfirmation =>
      'Wait for the platform confirmation. Do not repeat this action.';

  @override
  String get gameShareActionPaused => 'Share action paused';

  @override
  String get gameShareActionPausedDescription =>
      'Another action was already active. Check the current platform view before continuing.';

  @override
  String get gameShareConfirmationUncertain => 'Share confirmation uncertain';

  @override
  String get gameShareConfirmationUncertainDescription =>
      'Check the share sheet or clipboard, then dismiss this warning before trying again.';

  @override
  String get gameShareActionUnavailable => 'Share action unavailable';

  @override
  String get gameShareActionUnavailableDescription =>
      'The platform did not complete the action. Dismiss this warning before retrying.';

  @override
  String get gameUsingSavedPredictionHistory =>
      'Using saved prediction history';

  @override
  String get gameUsingSavedPredictionHistoryDescription =>
      'Refresh the route before opening another platform share action.';

  @override
  String get gameBackToPicks => 'Back to picks';

  @override
  String get gameChoosePick => 'Choose pick';

  @override
  String gameSharePredictionSemantics(
    String home,
    String away,
    String market,
    String outcome,
  ) {
    return '$home versus $away, $market, $outcome';
  }

  @override
  String gameShareMarketSelection(String market, String selection) {
    return '$market · $selection';
  }

  @override
  String get gameCurrentlySelectedShareCard => 'Currently selected share card';

  @override
  String get gameSelectThisShareCard => 'Select this share card';

  @override
  String get gamePredictionPickCancelled => 'Pick cancelled.';

  @override
  String get gamePredictionSummaryCopied =>
      'Activity summary copied to clipboard.';

  @override
  String get gamePredictionScorePending => 'pending';

  @override
  String gamePredictionSummaryClipboard(
    String home,
    String away,
    String market,
    String outcome,
    String score,
  ) {
    return '$home vs $away · $market · $outcome · $score';
  }

  @override
  String get gamePredictionStatusWon => 'Won';

  @override
  String get gamePredictionStatusLost => 'Lost';

  @override
  String get gamePredictionStatusCancelled => 'Cancelled';

  @override
  String get gamePredictionStatusVoid => 'Void';

  @override
  String get gamePredictionStatusPending => 'Pending';

  @override
  String get gamePredictionDateTbd => 'Tbd';

  @override
  String gamePredictionDateTime(String date, String time) {
    return '$date • $time';
  }

  @override
  String gamePredictionWonSettlement(int count) {
    return 'This pick settled successfully and credited $count points.';
  }

  @override
  String get gamePredictionLostSettlement =>
      'This pick did not settle in your favour.';

  @override
  String gamePredictionOfficialOutcomeMessage(String outcome) {
    return 'Official outcome: $outcome.';
  }

  @override
  String get gamePredictionCancelledSettlement =>
      'This pick was cancelled before the fixture locked.';

  @override
  String get gamePredictionVoidSettlement =>
      'This pick was voided and no points were awarded.';

  @override
  String get gamePredictionPendingSettlement =>
      'This pick is locked and will settle when official results arrive.';

  @override
  String get gamePredictionActivityNotFound => 'Activity not found';

  @override
  String get gamePredictionActivityNotFoundDescription =>
      'This pick may have ended, been removed, or no longer be available to your account.';

  @override
  String get gamePredictionBackToPredictions => 'Back to predictions';

  @override
  String get gamePredictionCancellingPick => 'Cancelling pick';

  @override
  String get gamePredictionRefreshingActivity => 'Refreshing activity';

  @override
  String get gamePredictionConfirmedPickVisible =>
      'Keeping the confirmed pick visible while the latest status is checked.';

  @override
  String get gamePredictionActionsUnavailable => 'Activity actions unavailable';

  @override
  String get gamePredictionCancellationDisabled =>
      'You can review this pick, but cancellation is disabled for this build.';

  @override
  String get gamePredictionShowingSavedActivity => 'Showing saved activity';

  @override
  String get gamePredictionReconnectBeforeCancelling =>
      'Reconnect and refresh before cancelling this pick.';

  @override
  String get gamePredictionActivityDetailTitle => 'Activity detail';

  @override
  String gamePredictionShortTeams(String home, String away) {
    return '$home  •  $away';
  }

  @override
  String get gamePredictionVenueTbc => 'Venue tbc';

  @override
  String get gamePredictionPickType => 'Pick type';

  @override
  String get gamePredictionSelection => 'Selection';

  @override
  String get gamePredictionEarned => 'Earned';

  @override
  String get gamePredictionPotential => 'Potential';

  @override
  String gamePredictionPositiveValue(int count) {
    return '+$count';
  }

  @override
  String get gamePredictionSettlement => 'Settlement';

  @override
  String get gamePredictionPlaced => 'Placed';

  @override
  String get gamePredictionKickoff => 'Kickoff';

  @override
  String get gamePredictionSettled => 'Settled';

  @override
  String get gamePredictionOfficialOutcome => 'Official outcome';

  @override
  String get gamePredictionCancelPick => 'Cancel pick';

  @override
  String get gamePredictionCopyResult => 'Copy result';

  @override
  String get gamePredictionCopySummary => 'Copy summary';

  @override
  String get gamePredictionShareCard => 'Share card';

  @override
  String get gamePredictionBrowseFixtures => 'Browse fixtures';

  @override
  String get gamePredictionRefreshActivity => 'Refresh activity';

  @override
  String get gamePredictionConnectionRestored => 'Connection restored';

  @override
  String get gamePredictionDetailsOffline => 'Activity details offline';

  @override
  String get gamePredictionRefreshBeforeCancelling =>
      'Refresh to confirm the current pick before cancelling it.';

  @override
  String get gamePredictionReconnectToConfirm =>
      'Reconnect to confirm the current pick before cancelling it.';

  @override
  String get gamePredictionAccessUnavailable => 'Activity access unavailable';

  @override
  String get gamePredictionAccessUnavailableDescription =>
      'Your current account cannot review or change this activity.';

  @override
  String get gamePredictionDataChanged => 'Activity data changed';

  @override
  String get gamePredictionDataChangedDescription =>
      'Refresh before reviewing the result or cancelling this pick.';

  @override
  String get gamePredictionSecurityTimeout =>
      'Activity security check timed out';

  @override
  String get gamePredictionSecurityTimeoutDescription =>
      'No cancellation was confirmed. Refresh before trying again.';

  @override
  String get gamePredictionUnavailable => 'Activity unavailable';

  @override
  String get gamePredictionUnavailableDescription =>
      'The latest pick details could not be confirmed. Refresh to try again.';

  @override
  String gamePredictionSelectedMetricSemantics(String label, String value) {
    return 'Selected $label $value';
  }

  @override
  String gamePredictionMetricSemantics(String label, String value) {
    return '$label $value';
  }

  @override
  String get gameMatchTitle => 'Match';

  @override
  String get gameBackToFanZoneTitleCase => 'Back to Fan Zone';

  @override
  String get gameMatchNotFound => 'Match not found';

  @override
  String get gameMatchNotFoundDescription =>
      'This fixture may have ended, been removed, or no longer be available.';

  @override
  String get gameWeekdayMon => 'Mon';

  @override
  String get gameWeekdayTue => 'Tue';

  @override
  String get gameWeekdayWed => 'Wed';

  @override
  String get gameWeekdayThu => 'Thu';

  @override
  String get gameWeekdayFri => 'Fri';

  @override
  String get gameWeekdaySat => 'Sat';

  @override
  String get gameWeekdaySun => 'Sun';

  @override
  String get gameMonthJan => 'Jan';

  @override
  String get gameMonthFeb => 'Feb';

  @override
  String get gameMonthMar => 'Mar';

  @override
  String get gameMonthApr => 'Apr';

  @override
  String get gameMonthMay => 'May';

  @override
  String get gameMonthJun => 'Jun';

  @override
  String get gameMonthJul => 'Jul';

  @override
  String get gameMonthAug => 'Aug';

  @override
  String get gameMonthSep => 'Sep';

  @override
  String get gameMonthOct => 'Oct';

  @override
  String get gameMonthNov => 'Nov';

  @override
  String get gameMonthDec => 'Dec';

  @override
  String gameMatchKickoffDateTime(
    String weekday,
    int day,
    String month,
    String time,
  ) {
    return '$weekday $day $month · $time';
  }

  @override
  String get gamePoolsTab => 'Pools';

  @override
  String get gameStatsTab => 'Stats';

  @override
  String get gameH2hTab => 'H2h';

  @override
  String get gameLineupsTab => 'Lineups';

  @override
  String gameMatchTeamsVs(String home, String away) {
    return '$home vs $away';
  }

  @override
  String get gamePartnerPoolsTooltip => 'Partner pools';

  @override
  String get gameJoiningPartnerPool => 'Joining partner pool';

  @override
  String get gameRefreshingMatch => 'Refreshing match';

  @override
  String get gameConfirmedMatchVisible =>
      'Keeping the confirmed match visible while the latest state is checked.';

  @override
  String get gameMatchActionsUnavailable => 'Match actions unavailable';

  @override
  String get gameMatchActionsUnavailableDescription =>
      'You can review this match, but joining partner pools is disabled for this build.';

  @override
  String get gameShowingSavedMatch => 'Showing saved match';

  @override
  String get gameReconnectBeforePartnerPool =>
      'Reconnect and refresh before joining a partner pool.';

  @override
  String get gameVsUpper => 'VS';

  @override
  String get gamePartnerOutcomeHomeWin => 'Home win';

  @override
  String get gamePartnerOutcomeDraw => 'Draw';

  @override
  String get gamePartnerOutcomeAwayWin => 'Away win';

  @override
  String get gamePartnerOutcomeUnknown => 'Unknown';

  @override
  String get gamePartnerEarnRequired => 'Partner earn required';

  @override
  String get gamePromotionEarnRequired => 'Promotion earn required';

  @override
  String get gameOpenToAllFans => 'Open to all fans';

  @override
  String get gamePoolJoinOffline =>
      'Reconnect and refresh before joining this pool.';

  @override
  String get gamePoolJoinPermissionDenied =>
      'Your account cannot join this partner pool.';

  @override
  String get gamePoolJoinConflict =>
      'This pool changed or locked. Refresh before trying again.';

  @override
  String get gamePoolJoinTimeout =>
      'No entry was confirmed. Refresh before trying again.';

  @override
  String get gamePoolJoinUnavailable => 'Pool entry could not be confirmed.';

  @override
  String get gameRefreshMatch => 'Refresh match';

  @override
  String get gameMatchConnectionRestored => 'Connection restored';

  @override
  String get gameMatchDetailsOffline => 'Match details offline';

  @override
  String get gameRefreshBeforeJoiningPool =>
      'Refresh to confirm the current match before joining a pool.';

  @override
  String get gameReconnectBeforeJoiningPool =>
      'Reconnect to confirm the current match before joining a pool.';

  @override
  String get gameMatchAccessUnavailable => 'Match access unavailable';

  @override
  String get gameMatchAccessUnavailableDescription =>
      'Your current account cannot review this match.';

  @override
  String get gameMatchDataChanged => 'Match data changed';

  @override
  String get gameMatchDataChangedDescription =>
      'Refresh before joining a pool or reviewing current status.';

  @override
  String get gameMatchSecurityTimeout => 'Match security check timed out';

  @override
  String get gameMatchSecurityTimeoutDescription =>
      'No pool entry was confirmed. Refresh before trying again.';

  @override
  String get gameMatchUnavailable => 'Match unavailable';

  @override
  String get gameMatchUnavailableDescription =>
      'The latest match details could not be confirmed. Refresh to try again.';

  @override
  String get gamePartnerWdwPools => 'Partner WDW Pools';

  @override
  String get gameNoPartnerPool => 'No partner pool for this match';

  @override
  String get gameNoPartnerPoolDescription =>
      'Football predictions open only when a partner creates a fixed-entry WDW pool for this fixture.';

  @override
  String get gameViewFanZone => 'View Fan Zone';

  @override
  String gamePartnerPoolsOnly(String home, String away) {
    return '$home vs $away uses partner-funded WDW pools only.';
  }

  @override
  String get settingsThemePreview => 'Theme preview';

  @override
  String get settingsApplyTheme => 'Apply';

  @override
  String get predictTitle => 'Predict';

  @override
  String get predictIntro => 'Pick the result. One entry per match.';

  @override
  String get predictFixtures => 'Fixtures';

  @override
  String get predictHistory => 'My picks';

  @override
  String get predictWallet => 'FET activity';

  @override
  String get predictDraw => 'Draw';

  @override
  String get predictAll => 'All competitions';

  @override
  String get predictEmpty => 'No open fixtures';

  @override
  String get predictEmptyBody => 'Prepared matches appear here before kickoff.';

  @override
  String get predictNoHistory => 'Your picks will appear here';

  @override
  String get predictNoActivity => 'No FET activity yet';

  @override
  String get predictUnavailable => 'Couldn’t refresh Predict';

  @override
  String get predictRefresh => 'Refresh';

  @override
  String get predictLoading => 'Loading fixtures';

  @override
  String get predictDisabled => 'Predict is not open yet';

  @override
  String get predictSignIn => 'Sign in to pick';

  @override
  String get predictOffline => 'Connect to refresh or pick a result.';

  @override
  String get predictClosed =>
      'This match is now closed. Refresh for current fixtures.';

  @override
  String get predictAlreadyEntered =>
      'You already picked this match. Refresh to see your choice.';

  @override
  String get predictInsufficient => 'You don’t have enough FET for this entry.';

  @override
  String get predictUncertain =>
      'Your entry hasn’t been confirmed. Refresh before trying again.';

  @override
  String get predictPending => 'Confirming your pick…';

  @override
  String get predictPicked => 'Picked';

  @override
  String get predictWon => 'Won';

  @override
  String get predictLost => 'Settled';

  @override
  String get predictRefunded => 'Refunded';

  @override
  String get predictLocked => 'Closed';

  @override
  String get predictRules =>
      'Entries close at kickoff. Correct picks share the pool. If no one is correct, or the match is voided, entries are refunded. FET is not cash.';

  @override
  String get predictWelcome => 'Welcome FET';

  @override
  String get predictEntry => 'Predict entry';

  @override
  String get predictPayout => 'Predict payout';

  @override
  String get predictRefund => 'Predict refund';

  @override
  String get predictActivity => 'FET activity';

  @override
  String get predictAdminTitle => 'Predict operations';

  @override
  String get predictAdminIntro =>
      'Prepare fixtures. Confirm official results. Settle or refund entries.';

  @override
  String get predictAdminSettings => 'Settings';

  @override
  String get predictAdminEnabled => 'Open Predict';

  @override
  String get predictAdminEntryPrice => 'Entry price (FET)';

  @override
  String get predictAdminSave => 'Save settings';

  @override
  String get predictAdminAll => 'All fixtures';

  @override
  String get predictAdminNoPool => 'No pool';

  @override
  String get predictAdminOpen => 'Open';

  @override
  String get predictAdminLocked => 'Locked';

  @override
  String get predictAdminSettled => 'Settled';

  @override
  String get predictAdminRefunded => 'Refunded';

  @override
  String get predictAdminPrepare => 'Prepare fixture';

  @override
  String get predictAdminConfirm => 'Confirm result';

  @override
  String get predictAdminSettle => 'Settle pool';

  @override
  String get predictAdminRefund => 'Void and refund';

  @override
  String get predictAdminSource => 'Official source URL';

  @override
  String get predictAdminReason => 'Reason for refund';

  @override
  String get predictAdminCancel => 'Cancel';

  @override
  String get predictAdminFailed =>
      'Changes could not be confirmed. Refresh the ledger before trying again.';

  @override
  String get predictAdminDenied => 'Admin access required';

  @override
  String get predictAdminEmpty => 'No fixtures to manage';

  @override
  String get predictAdminPriceNote =>
      'New price applies to newly prepared fixtures. Entries close automatically at kickoff.';

  @override
  String get predictAdminTotals => 'Entries / Staked / Paid';

  @override
  String get predictAdminConfirmBody =>
      'Review the official final score before confirming.';

  @override
  String get predictAdminSettleBody =>
      'Distribute the whole pool to correct entries. If none are correct, refund every entry.';

  @override
  String get clubAboutTitle => 'About the club';

  @override
  String get clubOriginLabel => 'Roots';

  @override
  String get clubBaseLabel => 'Based in';

  @override
  String get clubColoursLabel => 'Colours';

  @override
  String get clubRootsSubtitle => 'Our story';

  @override
  String get clubExploreTitle => 'Explore the club';

  @override
  String get clubMembershipAction => 'Membership';

  @override
  String get membershipStatusUnconfirmed => 'Not confirmed';

  @override
  String get membershipDateUnconfirmed => 'Not provided';

  @override
  String get membershipProgrammeTitle => 'Your membership';

  @override
  String get membershipProgrammeBody =>
      'Your category is based on confirmed club contributions. FET activity is separate and does not determine your membership tier.';

  @override
  String get predictReviewTitle => 'Review your pick';

  @override
  String get predictConfirmPick => 'Confirm pick';

  @override
  String get predictReviewRule =>
      'One pick per fixture. Your pick cannot be changed after confirmation. The fixture closes at kickoff.';

  @override
  String get predictEntryCost => 'Entry cost';

  @override
  String get predictBalanceAfter => 'Balance after entry';

  @override
  String get predictCancelPick => 'Cancel';

  @override
  String get fanClubViewJoiningOptions => 'View joining options';

  @override
  String get clubAllPlayers => 'All players';

  @override
  String get clubPlayerProfile => 'Player profile';

  @override
  String get clubPlayerBioPending =>
      'A player biography has not been published yet.';

  @override
  String get clubNextMatch => 'Next match';

  @override
  String get clubLatestNews => 'Latest news';

  @override
  String get clubPartners => 'Partners';

  @override
  String get clubPartnersSubtitle => 'The organisations supporting your club';

  @override
  String get clubPartnersEmpty =>
      'Club partners will appear when their details are published.';

  @override
  String get clubPartnerWebsite => 'Visit partner website';

  @override
  String get clubArticleOriginal => 'Read original article';

  @override
  String get clubSourceLabel => 'Source';

  @override
  String get predictEarnUse => 'Earn and use FET';

  @override
  String get predictEarnUseBody =>
      'FET is your supporter activity balance. Eligible members receive the published welcome grant once. You can use available FET to enter enabled fixtures; confirmed payouts and refunds appear in FET activity. FET cannot be bought or withdrawn as cash.';

  @override
  String get predictNoRedemptions =>
      'Partner recognition does not create a FET offer. Only published, eligible offers can be redeemed.';

  @override
  String get searchPartialTitle => 'Some results are unavailable';

  @override
  String get searchPartialMessage =>
      'Available results are shown. Refresh to try the remaining sources.';

  @override
  String get clubLinkUnavailable => 'Continue on the club website';

  @override
  String get clubLinkUnavailableBody =>
      'This website record is not available in the app yet. You can open the original page or browse the club.';

  @override
  String get clubOpenWebsite => 'Open website';

  @override
  String get clubLinkLoading => 'Opening club content';

  @override
  String get clubLinkRetry => 'Try again';

  @override
  String get clubPartnersTitle => 'Partners';

  @override
  String get clubPartnersIntro =>
      'The organisations supporting our club. Partner recognition does not include a FET reward or redemption offer.';

  @override
  String get clubPartnersUnavailable =>
      'Partner details are temporarily unavailable.';

  @override
  String get clubPartnerDetails => 'View partner';

  @override
  String get clubFootballNow => 'Football now';

  @override
  String get clubFootballUpcoming => 'Next fixture';

  @override
  String get clubFootballRecent => 'Latest result';

  @override
  String get membershipQualificationUnavailable =>
      'Contribution qualification is not yet available for this club.';

  @override
  String get membershipQualificationWindow =>
      'Rolling 12 months · membership contributions only';

  @override
  String get predictInsufficientReview =>
      'Insufficient FET. No charge will be made.';

  @override
  String get shopEnquire => 'Enquire on WhatsApp';

  @override
  String get shopEnquiryExplanation =>
      'Confirm size, availability and delivery with the club. Opening WhatsApp does not place an order or make a payment.';

  @override
  String clubFixtureTeams(String homeTeam, String awayTeam) {
    return '$homeTeam · $awayTeam';
  }

  @override
  String predictFetAmount(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString FET';
  }

  @override
  String membershipConfirmedTotal(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString RWF confirmed';
  }

  @override
  String membershipRemainingTotal(int amount, String tier) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString RWF to $tier';
  }

  @override
  String shopEnquiryMessage(
    String productName,
    String productId,
    String size,
    int quantity,
  ) {
    return 'Hello, I would like to enquire about $productName (product $productId), size $size, quantity $quantity.';
  }

  @override
  String get fanClubsSavedRetry => 'Showing saved fan clubs. Tap to retry.';

  @override
  String get shopSizeNotSelected => 'Not selected';

  @override
  String get clubSquadFirstTeam => 'First team';

  @override
  String get clubSquadWomen => 'Women';

  @override
  String get clubSquadAcademy => 'Academy';

  @override
  String get clubSquadStaff => 'Staff';

  @override
  String get clubSquadAllTeams => 'All teams';

  @override
  String get shopEnquiryOptions => 'View enquiry options';
}
