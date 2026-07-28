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
}
