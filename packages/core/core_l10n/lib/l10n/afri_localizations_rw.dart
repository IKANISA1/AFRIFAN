// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'afri_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kinyarwanda (`rw`).
class AfriLocalizationsRw extends AfriLocalizations {
  AfriLocalizationsRw([String locale = 'rw']) : super(locale);

  @override
  String get appTitle => 'AfriClub';

  @override
  String get genericError => 'Habaye ikibazo. Ongera ugerageze.';

  @override
  String get retry => 'Ongera ugerageze';

  @override
  String get connectionRequired => 'Interineti irakenewe';

  @override
  String get onboardingBelongTitle => 'Ikipe yawe.\nUmunsi w’umukino wawe.';

  @override
  String onboardingBelongBody(String clubName) {
    return 'Kurikira $clubName aho umuryango w’ubururu uteranira hose.';
  }

  @override
  String get onboardingKnowTitle => 'Buri mwanya.\nUmuryango umwe w’ubururu.';

  @override
  String onboardingKnowBody(String appName) {
    return 'Menya amakuru yemewe ya $appName, imikino, amatike n’ubunyamuryango.';
  }

  @override
  String get onboardingLiveTitle => 'Hafi ya\nGikundiro.';

  @override
  String get onboardingLiveBody =>
      'Menya abakinnyi kandi ugendane n’ikipe yawe buri munsi.';

  @override
  String get onboardingSkip => 'Simbuka';

  @override
  String get onboardingNext => 'Komeza';

  @override
  String get onboardingStart => 'Tangira';

  @override
  String get onboardingContinueWhatsApp => 'Komeza ukoresheje WhatsApp';

  @override
  String get onboardingContinueWithoutSignIn => 'Komeza utinjiye';

  @override
  String onboardingWelcomeImage(int current, int total) {
    return 'Ifoto y’ikaze $current kuri $total';
  }

  @override
  String get supportUnavailable => 'Ubufasha ntibuboneka muri iyi verisiyo.';

  @override
  String get fanZoneLoading =>
      'Amahitamo, shampiyona, amanota, abafana n’ibihembo biri gutangira.';

  @override
  String get fanZoneJoinSession =>
      'Injira mu mukino uri kuba ukoreshe iyi telefoni gukina.';

  @override
  String get fanZoneVenueCode => 'Andika kode y’aho uri nyuma yo kuhagera.';

  @override
  String get fanZoneRoundsEmpty =>
      'Amarushanwa y’umunsi w’umukino azagaragara afunguwe.';

  @override
  String get fanZoneRankingsEmpty =>
      'Urutonde ruzagaragara amakuru yongeye kuvugururwa.';

  @override
  String get fanZoneClubsMoved => 'Fan clubs n’amashami biri muri Supporters.';

  @override
  String get fanZoneRegistryMoved =>
      'Urutonde rw’abafana ruri muri Fan Zone Supporters.';

  @override
  String get fanZoneContributionMode => 'Hitamo uburyo bwo gutanga umusanzu.';

  @override
  String get fanZoneRewardsSummary => 'Ibirango, uruhererekane n’ibihembo.';

  @override
  String get fanZoneLineupsEmpty =>
      'Abakinnyi bazagaragara mbere y’uko umukino utangira.';

  @override
  String get fanZoneStatsEmpty => 'Imibare izagaragara umukino utangiye.';

  @override
  String get fanIdVerifyPrompt =>
      'Emeza Fan ID yawe kugira ngo utore kandi ubone amanota.';

  @override
  String get fanIdPrivacyTrust =>
      'Kwemeza bikoresha Fan ID yawe. Nta makuru bwite asangizwa abandi.';

  @override
  String get tvPairingUnavailable =>
      'Guhuza ntibikunda. Reba interineti wongere ugerageze.';

  @override
  String get tvConfigurationMissing =>
      'Igenamiterere ntiryuzuye. Menyesha ushinzwe gushyira sisitemu ku murongo.';

  @override
  String get tvCredentialRevoked =>
      'Iki gikoresho cyahagaritswe. Kora kode nshya yo kugihuza.';

  @override
  String get tvEnterAdminCode =>
      'Andika kode iri ku rutonde rw’ibikoresho rwa admin.';

  @override
  String get tvJoinFromFanZone =>
      'Koresha iyi kode winjire unyuze muri Fan Zone.';

  @override
  String get tvConnectionLostRetry => 'Interineti yabuze — ongera ugerageze';
}
