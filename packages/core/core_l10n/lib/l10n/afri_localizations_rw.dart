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
  String get searchTitle => 'Shakisha';

  @override
  String get searchHint => 'Abafana, imikino, amatike, iduka, ikofi, ubufasha';

  @override
  String get searchClearTooltip => 'Siba ibyo washakaga';

  @override
  String get searchCategoryAll => 'Byose';

  @override
  String get searchCategorySupporters => 'Abafana';

  @override
  String get searchCategoryFixtures => 'Imikino';

  @override
  String get searchCategoryCommerce => 'Amatike n’iduka';

  @override
  String get searchCategoryServices => 'Serivisi';

  @override
  String get searchKeepTypingTitle => 'Komeza wandike';

  @override
  String get searchKeepTypingMessage =>
      'Andika nibura inyuguti ebyiri kugira ngo gushakisha bitangire.';

  @override
  String get searchUpdatingTitle => 'Ibisubizo biri kuvugururwa';

  @override
  String get searchSearchingTitle => 'Biri gushakishwa';

  @override
  String get searchUpdatingMessage =>
      'Ibice n’amakuru rusange y’abafana biri kuvugururwa.';

  @override
  String get searchSearchingMessage =>
      'Biri gushakishwa mu bice no mu makuru y’abafana.';

  @override
  String get searchPermissionTitle => 'Ntibyemewe gushakisha';

  @override
  String get searchPermissionMessage =>
      'Konti yawe ntiyemerewe gushakisha ako kanya. Ibyo wanditse birahari. Menyesha ikipe.';

  @override
  String get searchConflictTitle => 'Amakuru yo gushakisha yahindutse';

  @override
  String get searchConflictMessage =>
      'Amakuru yabonekaga yahindutse ugishakisha. Reba ibyo wanditse wongere ugerageze.';

  @override
  String get searchTimeoutTitle => 'Igihe cyo gushakisha cyarangiye';

  @override
  String get searchTimeoutMessage =>
      'Igihe cyo gushakisha cyarangiye. Ibyo wanditse biracyahari. Ongera ugerageze witeguye.';

  @override
  String get searchUnavailableTitle => 'Gushakisha ntibikunda';

  @override
  String get searchUnavailableMessage =>
      'Ongera ugerageze. Ibyo wanditse nta handi byoherejwe.';

  @override
  String get searchStartTitle => 'Shaka icyo ukeneye';

  @override
  String get searchStartMessage =>
      'Andika inyuguti ebyiri. Shaka mu bice bya porogaramu no mu makuru rusange y’abafana.';

  @override
  String get searchRecentTitle => 'Ibyashakishijwe vuba';

  @override
  String get searchClear => 'Siba';

  @override
  String searchForTooltip(String query) {
    return 'Shakisha $query';
  }

  @override
  String get searchNoResultsTitle => 'Nta bisubizo';

  @override
  String searchNoResultsMessage(String query) {
    return 'Nta gisubizo gihuye na “$query”.';
  }

  @override
  String get searchShowAllCategories => 'Erekana ibyiciro byose';

  @override
  String get searchOfflineTitle => 'Ibisubizo byo kuri telefoni';

  @override
  String get searchOfflineMessage =>
      'Dore ibyabitswe kuri iki gikoresho. Amakuru mashya ashobora kuba atarimo.';

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ibisubizo $count',
      one: 'Igisubizo 1',
      zero: 'Nta bisubizo',
    );
    return '$_temp0';
  }

  @override
  String get searchSupporterDirectoryTitle => 'Shaka abafana';

  @override
  String get searchSupporterDirectoryDescription =>
      'Shaka amazina rusange y’abafana kandi ucunge inshuti.';

  @override
  String get searchFanZoneTitle => 'Fan Zone';

  @override
  String get searchFanZoneDescription =>
      'Amahitamo, umuryango, ibihembo n’ibikorwa by’umunsi w’umukino.';

  @override
  String get searchFanRegistryTitle => 'Urutonde rw’abafana';

  @override
  String get searchFanRegistryDescription =>
      'Reba urutonde rw’abafana b’ikipe.';

  @override
  String get searchFixturesTitle => 'Imikino';

  @override
  String get searchFixturesDescription =>
      'Imikino ya Rayon Sports iheruka n’iteganyijwe.';

  @override
  String get searchLiveMatchTitle => 'Umukino uri kuba';

  @override
  String get searchLiveMatchDescription =>
      'Fungura amakuru y’umukino iyo ari gutangwa ako kanya.';

  @override
  String get searchStandingsTitle => 'Urutonde rwa shampiyona';

  @override
  String get searchStandingsDescription =>
      'Reba urutonde n’umwanya ikipe iriho mu irushanwa.';

  @override
  String get searchTicketsTitle => 'Amatike y’umukino';

  @override
  String get searchTicketsDescription =>
      'Shaka amatike aboneka ukomeze kwishyura.';

  @override
  String get searchMyTicketsTitle => 'Amatike yanjye';

  @override
  String get searchMyTicketsDescription =>
      'Fungura amatike waguze n’amakuru yo kwinjira ku mukino.';

  @override
  String get searchShopTitle => 'Iduka ry’ikipe';

  @override
  String get searchShopDescription => 'Reba ibicuruzwa byemewe by’ikipe.';

  @override
  String get searchCartTitle => 'Igitebo cy’ibicuruzwa';

  @override
  String get searchCartDescription => 'Reba ibicuruzwa mbere yo kwishyura.';

  @override
  String get searchWalletTitle => 'Ikofi ya FET';

  @override
  String get searchWalletDescription =>
      'Reba amafaranga, amateka, kohereza no guhinduranya amanota.';

  @override
  String get searchMembershipTitle => 'Ubunyamuryango';

  @override
  String get searchMembershipDescription =>
      'Reba uko ubunyamuryango bwawe buhagaze n’inyungu z’ikipe.';

  @override
  String get searchContributionsTitle => 'Shyigikira ikipe';

  @override
  String get searchContributionsDescription =>
      'Fungura imisanzu n’imishinga y’abafana.';

  @override
  String get searchNotificationsTitle => 'Amatangazo';

  @override
  String get searchNotificationsDescription =>
      'Reba kandi uhindure uko ushaka kwakira amatangazo.';

  @override
  String get searchPrivacyTitle => 'Igenamiterere ry’ibanga';

  @override
  String get searchPrivacyDescription =>
      'Reba uburenganzira watanze n’uburyo amakuru arindwa.';

  @override
  String get searchHelpTitle => 'Ubufasha';

  @override
  String get searchHelpDescription =>
      'Fungura uburyo bw’ubufasha muri Igenamiterere.';

  @override
  String get searchPublicSupporterDescription =>
      'Umwirondoro rusange w’umufana mu rutonde rw’ikipe.';

  @override
  String searchMatchTitle(String home, String away) {
    return '$home na $away';
  }

  @override
  String searchFixtureOnSaleDescription(String competition) {
    return 'Umukino wa $competition ufite amatike aboneka.';
  }

  @override
  String searchFixtureDescription(String competition) {
    return 'Umukino wa $competition.';
  }

  @override
  String searchProductDescription(String category) {
    return 'Igicuruzwa cyemewe cy’ikipe mu cyiciro cya $category.';
  }

  @override
  String get searchHomeTeamFallback => 'Ikipe yakiriye';

  @override
  String get searchAwayTeamFallback => 'Ikipe yasuye';

  @override
  String get searchClubFixtureFallback => 'Umukino w’ikipe';

  @override
  String get searchClubProductFallback => 'Igicuruzwa cy’ikipe';

  @override
  String get searchMerchandiseFallback => 'Ibicuruzwa';

  @override
  String get membershipTitle => 'Ubunyamuryango';

  @override
  String get membershipSavedDetails => 'Amakuru y’ubunyamuryango yabitswe';

  @override
  String get membershipDigitalCard => 'Ikarita y’ikoranabuhanga';

  @override
  String get share => 'Sangiza';

  @override
  String get membershipReviewTitle => 'Isuzuma ry’ubunyamuryango';

  @override
  String membershipReviewSubtitle(String tier) {
    return 'Ubunyamuryango bwa $tier butegereje kugenzura ubwishyu.';
  }

  @override
  String membershipRenewsOn(String date) {
    return 'Buzavugururwa ku wa $date';
  }

  @override
  String get fanRegistryTitle => 'Urutonde rw’abafana';

  @override
  String get fanRegistryBrowseAll => 'Reba abafana bose';

  @override
  String get membershipPackagesTitle => 'Ibyiciro';

  @override
  String get membershipOfflineTitle => 'Ubunyamuryango ntibuboneka';

  @override
  String get membershipOfflineMessage =>
      'Jya ku murongo kugira ngo ubone amakuru y’ubunyamuryango.';

  @override
  String get membershipSetupPending => 'Gutunganya ubunyamuryango birategereje';

  @override
  String get membershipChangeDeniedTitle =>
      'Guhindura ubunyamuryango ntibyemewe';

  @override
  String get membershipChangeDeniedMessage =>
      'Konti yawe ntishobora guhindura ubunyamuryango ubu. Ubunyamuryango bwawe burakomeza uko buri.';

  @override
  String get membershipChangedTitle => 'Amakuru y’ubunyamuryango yahindutse';

  @override
  String get membershipChangedMessage =>
      'Ikipe yahinduye aya makuru ukireba. Vugurura mbere yo guhitamo icyiciro.';

  @override
  String get membershipTimeoutTitle =>
      'Igihe cyo gusaba ubunyamuryango cyarangiye';

  @override
  String get membershipTimeoutMessage =>
      'Igihe cy’umutekano cyarangiye. Vugurura imimerere mbere yo kongera kugerageza.';

  @override
  String get membershipUnavailableMessage =>
      'Amakuru y’ubunyamuryango ntabonetse by’agateganyo.';

  @override
  String get membershipPaymentSent => 'Ubwishyu bwoherejwe';

  @override
  String get membershipPaymentVerifying => 'Ubwishyu buragenzurwa';

  @override
  String get membershipConfirmed => 'Ubunyamuryango bwemejwe';

  @override
  String membershipRequestTitle(String tier) {
    return 'Gusaba ubunyamuryango bwa $tier';
  }

  @override
  String membershipAmount(String currency, String amount) {
    return 'Amafaranga: $currency $amount';
  }

  @override
  String get membershipVerificationTime =>
      'Kugenzura bikunze gufata amasaha 1–24.';

  @override
  String membershipRequestedOn(String date) {
    return 'Byasabwe ku wa: $date';
  }

  @override
  String get contactSupport => 'Vugana n’ubufasha';

  @override
  String get membershipPackageEmpty =>
      'Ibyiciro by’ubunyamuryango bizagaragara ikipe imaze kubitangaza.';

  @override
  String get fanRegistrySearchHint => 'Shakisha abafana ku izina';

  @override
  String get fanRegistryUnavailable => 'Urutonde ntiruboneka';

  @override
  String get fanRegistryUnavailableMessage =>
      'Urutonde rw’abafana ntiruboneka by’agateganyo.';

  @override
  String fanRegistryLoaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Abafana $count babonetse',
      one: 'Umufana 1 yabonetse',
      zero: 'Nta mufana wabonetse',
    );
    return '$_temp0';
  }

  @override
  String get fanRegistrySummary =>
      'Uru rutonde rwerekana abanyamuryango b’ikipe.';

  @override
  String fanRegistryFiltered(String query) {
    return 'Ibyabonetse kuri “$query”.';
  }

  @override
  String get fanRegistryLoadMoreFailure =>
      'Ntibyashobotse kubona abandi bafana ubu.';

  @override
  String get fanRegistryPending => 'Birategereje';

  @override
  String fanRegistryActivity(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ibikorwa $count',
      one: 'Igikorwa 1',
      zero: 'Nta gikorwa',
    );
    return '$_temp0';
  }

  @override
  String fanRegistryJoined(String date) {
    return 'Yinjiye ku wa $date';
  }

  @override
  String fanRegistryJoinedRenews(String joined, String renews) {
    return 'Yinjiye ku wa $joined • Azavugurura ku wa $renews';
  }

  @override
  String get profileTitle => 'Umwirondoro';

  @override
  String get profileLoadingMembership => 'Ubunyamuryango burimo gupakirwa…';

  @override
  String get profileMembershipReviewPending =>
      'Isuzuma ry’ubunyamuryango rirategereje';

  @override
  String get profileMyClub => 'Ikipe yanjye';

  @override
  String get profileMatchday => 'Umunsi w’umukino';

  @override
  String get profileMyPicks => 'Ibyo nahisemo';

  @override
  String get profileClubBenefits => 'Inyungu z’ikipe';

  @override
  String get profileContributions => 'Inkunga';

  @override
  String get profileShop => 'Iduka';

  @override
  String get profileApp => 'Porogaramu';

  @override
  String get profileNotifications => 'Imenyesha';

  @override
  String get profileActivityHistory => 'Amateka y’ibikorwa';

  @override
  String profileActivityPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Amanota $count y’ibikorwa',
      one: 'Inota 1 ry’igikorwa',
      zero: 'Nta manota y’ibikorwa',
    );
    return '$_temp0';
  }

  @override
  String get tierTitle => 'Icyiciro cy’ubunyamuryango';

  @override
  String get tierUnavailableTitle => 'Amakuru y’icyiciro ntabonetse';

  @override
  String get tierDisabledMessage =>
      'Amakuru y’ibyiciro yafunzwe muri iyi porogaramu. Nta busabe bushobora gutangirwa hano.';

  @override
  String get backToMembership => 'Subira ku bunyamuryango';

  @override
  String get tierNotFoundTitle => 'Icyiciro nticyabonetse';

  @override
  String get tierNotFoundMessage =>
      'Iki cyiciro cy’ubunyamuryango ntikiri ku rutonde rwemewe.';

  @override
  String get tierOfflineTitle => 'Amakuru y’icyiciro ari hanze y’umurongo';

  @override
  String get tierOfflineMessage =>
      'Subira ku murongo urebe iki cyiciro. Nta busabe bubikwa hanze y’umurongo.';

  @override
  String get tierAccessDeniedTitle => 'Kwinjira ku cyiciro byanzwe';

  @override
  String get tierAccessDeniedMessage =>
      'Iyi konti ntishobora gufungura amakuru y’iki cyiciro.';

  @override
  String get tierTimeoutTitle => 'Igihe cyo kugenzura cyarangiye';

  @override
  String get tierTimeoutMessage =>
      'Porogaramu ntiyashoboye kwemeza iki cyiciro ku gihe. Gerageza kuvugurura rimwe.';

  @override
  String get tryAgain => 'Ongera ugerageze';

  @override
  String get tierChangedTitle => 'Amakuru y’icyiciro yahindutse';

  @override
  String get tierChangedMessage =>
      'Icyiciro nticyemejwe kuko amakuru yacyo yahindutse ahandi.';

  @override
  String get tierLoadUnavailableMessage =>
      'Icyiciro nticyapakiwe. Nta makuru yihariye ya serivisi yerekanwe.';

  @override
  String tierSelected(String tier) {
    return 'Icyiciro cy’ubunyamuryango $tier cyahiswemo';
  }

  @override
  String get tierPerks => 'Inyungu z’icyiciro';

  @override
  String get tierAccess => 'Ibyinjirwamo n’umunyamuryango';

  @override
  String get tierShowingOfficialTitle =>
      'Amakuru yemewe y’icyiciro aragaragara';

  @override
  String get tierOfflineStatusMessage =>
      'Subira ku murongo ushakishe ibishya. Nta busabe bubikwa hanze y’umurongo.';

  @override
  String get tierRefreshingTitle => 'Amakuru y’icyiciro aravugururwa';

  @override
  String get tierRefreshingMessage =>
      'Amakuru yemewe arakomeza kugaragara mu gihe ibishya bipakirwa.';

  @override
  String get tierUpdateDeniedTitle => 'Kuvugurura byanzwe';

  @override
  String get tierUpdateDeniedMessage =>
      'Amakuru yemewe arakomeza kugaragara. Iyi konti ntishobora gushaka ibishya.';

  @override
  String get tierChangedStatusMessage =>
      'Amakuru yemewe arakomeza kugaragara. Vugurura wemeze amakuru mashya.';

  @override
  String get tierRefreshTimeoutTitle => 'Igihe cyo kuvugurura cyarangiye';

  @override
  String get tierRefreshTimeoutMessage =>
      'Amakuru yemewe arakomeza kugaragara. Gerageza kuvugurura rimwe.';

  @override
  String get tierOutdatedTitle => 'Amakuru y’icyiciro ashobora kuba ashaje';

  @override
  String get tierOutdatedMessage =>
      'Amakuru yemewe arakomeza kugaragara mu gihe serivisi itaboneka.';

  @override
  String get tierDegradedMessage =>
      'Amakuru ya nyuma arakomeza kugaragara kugeza kuvugurura bikunze.';

  @override
  String get contributionConfirmTitle => 'Emeza inkunga';

  @override
  String contributionConfirmQuestion(String tier) {
    return 'Warangije kwishyura kuri MoMo USSD icyiciro cya $tier?';
  }

  @override
  String get contributionSelectedTier => 'Icyiciro cyahiswemo';

  @override
  String get contributionPendingVerification => 'Birategereje kugenzurwa';

  @override
  String get contributionNotYet => 'Ntabwo ndarangiza';

  @override
  String get contributionConfirming => 'Birimo kwemezwa…';

  @override
  String get contributionYesPaid => 'Yego, narishyuye';

  @override
  String get contributionPrivacy =>
      'Inkunga igenzurwa mu ibanga hakoreshejwe Fan ID.';

  @override
  String get contributionHistory => 'Amateka y’inkunga';

  @override
  String get shareMembershipCard => 'Sangiza ikarita y’ubunyamuryango';

  @override
  String get shareMembershipCardHint =>
      'Sangiza ikarita yawe y’ubunyamuryango y’ikoranabuhanga';

  @override
  String membershipSince(String date) {
    return 'Kuva $date';
  }

  @override
  String get membershipFanCard => 'Ikarita y’umufana';

  @override
  String get membershipReviewPendingUpper => 'Isuzuma rirategereje';

  @override
  String get membershipBrandWatermark => 'GIKUNDIRO';

  @override
  String get navHome => 'Ahabanza';

  @override
  String get navClub => 'Ikipe';

  @override
  String get navFanZone => 'Fan Zone';

  @override
  String get navMembership => 'Ubunyamuryango';

  @override
  String get membershipConnectBeforeChange =>
      'Jya ku murongo mbere yo guhindura ubunyamuryango.';

  @override
  String get membershipSignInFirst =>
      'Banza winjire kugira ngo utangire ubunyamuryango.';

  @override
  String membershipRequestSubmitted(String tier) {
    return 'Ubusabe bw’ubunyamuryango bwa $tier bwoherejwe.';
  }

  @override
  String membershipAlreadyPending(String tier) {
    return 'Ubunyamuryango bwa $tier busanzwe butegereje kugenzura ubwishyu.';
  }

  @override
  String membershipStarted(String tier) {
    return 'Ubunyamuryango bwa $tier bwatangiye.';
  }

  @override
  String get membershipPaymentSetupPending =>
      'Gutunganya ubwishyu bitegereje ko ikipe ibyemeza.';

  @override
  String membershipDialerFailed(String tier) {
    return 'Ubusabe bwa $tier bwabitswe, ariko MoMo ntiyafungutse.';
  }

  @override
  String membershipSubmittedBackground(String tier) {
    return 'Ubusabe bwa $tier bwoherejwe. Ubwishyu buzagenzurwa mu buryo bwikora.';
  }

  @override
  String get membershipPendingReviewAction => 'Isuzuma rirategereje';

  @override
  String get membershipActivateAction => 'Tangira';

  @override
  String get membershipRenewAction => 'Vugurura';

  @override
  String get membershipSwitchAction => 'Hindura';

  @override
  String get membershipCopied => 'Amakuru y’ubunyamuryango yakoporowe.';

  @override
  String membershipShareText(String club, String tier, String supporter) {
    return 'Ubunyamuryango bwa $club\nIcyiciro: $tier\nFan ID: #$supporter';
  }

  @override
  String get membershipActivityPending =>
      'Ibikorwa bizagaragara nyuma y’isuzuma ry’amatike, amatsinda y’abafana n’inkunga.';

  @override
  String membershipActivityRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Amanota $count y’ibikorwa yabitswe.',
      one: 'Inota 1 ry’igikorwa ryabitswe.',
      zero: 'Nta manota y’ibikorwa yabitswe.',
    );
    return '$_temp0';
  }

  @override
  String get membershipSupportMessage =>
      'Muraho, ndakeneye ubufasha mu kugenzura ubwishyu bw’ubunyamuryango.';

  @override
  String get membershipWhatsAppUnavailable =>
      'WhatsApp ntiyafungutse. Vugana n’ubufasha.';

  @override
  String get membershipSupportNotConfigured =>
      'Aho kuvugana n’ubufasha ntiharategurwa.';

  @override
  String get membershipSubmittingTitle =>
      'Ubusabe bw’ubunyamuryango burimo koherezwa';

  @override
  String get membershipUpdatingTitle => 'Ubunyamuryango burimo kuvugururwa';

  @override
  String get membershipSubmittingMessage =>
      'Guma kuri iyi paji mu gihe ikipe yakira ubusabe bwawe.';

  @override
  String get membershipUpdatingMessage =>
      'Ibyiciro n’amakuru y’ubunyamuryango birimo kuvugururwa.';

  @override
  String get membershipRefreshAction => 'Vugurura';

  @override
  String membershipCurrentStatus(String tier) {
    return '$tier · Icyiciro cyawe';
  }

  @override
  String get membershipRefreshRequired => 'Vugurura mbere';

  @override
  String get membershipSubmittingAction => 'Birimo koherezwa';

  @override
  String membershipPackageCurrentSemantic(String tier) {
    return 'Icyiciro cy’ubunyamuryango $tier, cyahiswemo';
  }

  @override
  String get membershipPackageFallback => 'Icyiciro';

  @override
  String get membershipFanFallback => 'Umufana';

  @override
  String get membershipDateNextYear => 'umwaka utaha';

  @override
  String membershipDate(int day, String month, int year) {
    return '$day $month $year';
  }

  @override
  String get membershipMonthJan => 'Mut.';

  @override
  String get membershipMonthFeb => 'Gash.';

  @override
  String get membershipMonthMar => 'Wer.';

  @override
  String get membershipMonthApr => 'Mata';

  @override
  String get membershipMonthMay => 'Gic.';

  @override
  String get membershipMonthJun => 'Kam.';

  @override
  String get membershipMonthJul => 'Nyak.';

  @override
  String get membershipMonthAug => 'Kan.';

  @override
  String get membershipMonthSep => 'Nze.';

  @override
  String get membershipMonthOct => 'Ukw.';

  @override
  String get membershipMonthNov => 'Ugu.';

  @override
  String get membershipMonthDec => 'Ukub.';

  @override
  String get clubTitle => 'Ikipe';

  @override
  String clubOfficialOverviewSemantic(String club) {
    return 'Incamake yemewe ya $club';
  }

  @override
  String get clubLiveIdentityUnavailable => 'Amakuru mashya y’ikipe ntaboneka';

  @override
  String get clubIdentityFallbackMessage =>
      'Amakuru yemewe ari muri porogaramu arakomeza kugaragara mu gihe amakuru mashya y’ikipe atavugururwa.';

  @override
  String get clubOfficialSection => 'Ikipe yemewe';

  @override
  String get clubTeamTitle => 'Abakinnyi';

  @override
  String get clubTeamSubtitle =>
      'Abakinnyi b’ikipe ya mbere n’imyirondoro yabo yemewe';

  @override
  String get clubTeamEmptyTitle => 'Nta bakinnyi batangajwe';

  @override
  String get clubTeamEmptyMessage =>
      'Ikipe ntiratangaza abakinnyi bayo ba mbere muri iyi porogaramu.';

  @override
  String get clubNewsTitle => 'Amakuru y’ikipe';

  @override
  String get clubNewsSubtitle => 'Amakuru n’amatangazo byatangajwe n’ikipe';

  @override
  String get clubNewsEmptyTitle => 'Nta makuru yatangajwe';

  @override
  String get clubNewsEmptyMessage =>
      'Amakuru ikipe yatangaje azagaragara hano.';

  @override
  String get clubArticleUnavailableTitle => 'Inkuru ntiboneka';

  @override
  String get clubArticleUnavailableMessage =>
      'Iyi nkuru ntiyatangajwe ku ikipe iriho cyangwa ihuza ryayo ntirikiri rishya.';

  @override
  String get clubArticleBodyUnavailable => 'Inkuru yuzuye ntiboneka.';

  @override
  String get clubFixturesTitle => 'Imikino itaha';

  @override
  String get clubFixturesSubtitle => 'Imikino itaha n’amatike aboneka';

  @override
  String get clubFixturesEmptyTitle => 'Nta mukino utaha watangajwe';

  @override
  String get clubFixturesEmptyMessage => 'Ikipe ntiratangaza undi mukino.';

  @override
  String clubFixtureTitle(String home, String away) {
    return '$home na $away';
  }

  @override
  String get clubTicketsTitle => 'Amatike';

  @override
  String get clubResultsTitle => 'Ibyavuye mu mikino';

  @override
  String get clubResultsSubtitle => 'Amanota y’imikino yarangiye';

  @override
  String get clubResultsEmptyTitle => 'Nta byavuye mu mikino byatangajwe';

  @override
  String get clubResultsEmptyMessage =>
      'Imikino y’ikipe yarangiye izagaragara hano.';

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
  String get clubMatchTitle => 'Umukino';

  @override
  String get clubMatchUnavailableTitle => 'Umukino ntuboneka';

  @override
  String get clubMatchUnavailableMessage =>
      'Uyu mukino ntiwatangajwe ku ikipe iriho cyangwa ihuza ryawo ntirikiri rishya.';

  @override
  String clubScore(int homeScore, int awayScore) {
    return '$homeScore – $awayScore';
  }

  @override
  String get clubViewAvailableTickets => 'Reba amatike aboneka';

  @override
  String get clubStandingsTitle => 'Urutonde';

  @override
  String get clubStandingsSubtitle => 'Urutonde rwa shampiyona rwatangajwe';

  @override
  String get clubStandingsEmptyTitle => 'Nta rutonde rwatangajwe';

  @override
  String get clubStandingsEmptyMessage =>
      'Urutonde rwa shampiyona ruriho ntiruratangazwa.';

  @override
  String get clubPlayedShort => 'MK';

  @override
  String get clubGoalDifferenceShort => 'IT';

  @override
  String get clubPointsShort => 'AMN';

  @override
  String get clubHistoryTitle => 'Amateka y’ikipe';

  @override
  String get clubHistorySubtitle => 'Amateka y’ikipe n’ibihe by’ingenzi';

  @override
  String get clubHistoryEmptyTitle => 'Amateka ntaratangazwa';

  @override
  String get clubHistoryEmptyMessage =>
      'Amateka y’ikipe ntaraboneka kugeza amakuru yasuzumwe atangajwe.';

  @override
  String get clubProjectsTitle => 'Imishinga y’ikipe';

  @override
  String get clubProjectsSubtitle =>
      'Imishinga y’abafana igenzurwa n’aho igeze';

  @override
  String get clubProjectsEmptyTitle => 'Nta mushinga watangajwe';

  @override
  String get clubProjectsEmptyMessage =>
      'Imishinga y’abafana igenzurwa izagaragara ikipe imaze kuyemeza.';

  @override
  String clubSupporters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Abafana $count',
      one: 'Umufana 1',
      zero: 'Nta mufana',
    );
    return '$_temp0';
  }

  @override
  String get clubProjectTitle => 'Umushinga w’ikipe';

  @override
  String get clubProjectUnavailableTitle => 'Umushinga ntuboneka';

  @override
  String get clubProjectUnavailableMessage =>
      'Uyu mushinga ntukorera ikipe iriho cyangwa ihuza ryawo ntirikiri rishya.';

  @override
  String clubSupportersParticipate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Abafana $count bawugiramo uruhare ubu.',
      one: 'Umufana 1 awugiramo uruhare ubu.',
      zero: 'Nta bafana bawugiramo uruhare ubu.',
    );
    return '$_temp0';
  }

  @override
  String get clubOpenContribution => 'Fungura uburyo bwo gutanga inkunga';

  @override
  String get clubInformationUnavailable => 'Amakuru y’ikipe ntaboneka';

  @override
  String get clubInformationLoadMessage =>
      'Amakuru mashya y’ikipe ntiyapakiwe. Amakuru asanzwe muri porogaramu ntiyasimbujwe.';

  @override
  String get clubLinkedRecordLoadMessage =>
      'Amakuru y’ikipe ahujwe ntiyapakiwe.';

  @override
  String get clubOfflineTitle => 'Amakuru ya klabu ntaboneka nta murongo';

  @override
  String get clubOfflineMessage =>
      'Jya ku murongo kugira ngo ubone amakuru mashya yemewe ya klabu.';

  @override
  String get clubAccessDeniedTitle => 'Ntiwemerewe kubona amakuru ya klabu';

  @override
  String get clubAccessDeniedMessage =>
      'Iyi konti ntishobora kubona amakuru ya klabu yasabwe.';

  @override
  String get clubChangedTitle => 'Amakuru ya klabu yahindutse';

  @override
  String get clubChangedMessage =>
      'Amakuru yemewe ya klabu yahindutse mu gihe yarimo aza. Vugurura kugira ngo wemeze amakuru mashya.';

  @override
  String get clubSecurityTimeoutTitle =>
      'Igihe cyo kugenzura umutekano w’amakuru ya klabu cyarangiye';

  @override
  String get clubSecurityTimeoutMessage =>
      'Serivisi y’amakuru ya klabu ntiyasubije ku gihe. Vugurura wongere ugerageze.';

  @override
  String get clubRefreshingTitle => 'Kuvugurura amakuru ya klabu';

  @override
  String get clubRefreshingMessage =>
      'Amakuru ya klabu aheruka kwemezwa akomeza kugaragara mu gihe amakuru mashya aza.';

  @override
  String get clubRefresh => 'Vugurura';

  @override
  String get clubTicketsSubtitle =>
      'Amatike y’imikino yatangajwe kuri iyi kipe';

  @override
  String get clubShopTitle => 'Iduka';

  @override
  String get clubShopSubtitle => 'Ibicuruzwa byemewe n’uko biboneka';

  @override
  String onboardingBelongImageSemantic(String club) {
    return 'Abakinnyi ba $club bashimira abafana nyuma y’umukino';
  }

  @override
  String onboardingKnowImageSemantic(String club) {
    return 'Abakinnyi ba $club bishimira hamwe';
  }

  @override
  String onboardingLiveImageSemantic(String club) {
    return 'Ifoto y’umukinnyi wa $club';
  }

  @override
  String onboardingIdentitySemantic(String club) {
    return 'Umwirondoro wa $club';
  }

  @override
  String onboardingImageSemantic(String description, int index, int count) {
    return '$description. Ifoto ya $index muri $count';
  }

  @override
  String get onboardingAnonymousSessionUnavailable =>
      'Ntibyashobotse gufungura nk’umushyitsi. Ongera ugerageze.';

  @override
  String get onboardingRefreshingTitle => 'Ikaze ririmo kuvugururwa';

  @override
  String get onboardingRefreshingMessage =>
      'Ikaze n’amahitamo biriho birakomeza kugaragara mu gihe ibishya bishakishwa.';

  @override
  String get onboardingStatusTitle => 'Imiterere y’ikaze';

  @override
  String get onboardingWhatsAppUnavailable =>
      'Kwinjira na WhatsApp ntibiboneka';

  @override
  String get onboardingOfflineSavedMessage =>
      'Nta murongo uhari. Ikaze ryabitswe riraboneka. Komeza utinjiye.';

  @override
  String get onboardingWhatsAppLaterMessage =>
      'Komeza utinjiye cyangwa wongere ugerageze WhatsApp nyuma.';

  @override
  String get onboardingContentUnavailableTitle => 'Amakuru y’ikaze ntaboneka';

  @override
  String get onboardingContentUnavailableMessage =>
      'Nta makuru y’ikaze arajya ahari. Vugurura cyangwa ukomeze utinjiye.';

  @override
  String get onboardingPreparingTitle => 'Ikaze ryawe ririmo gutegurwa';

  @override
  String get onboardingPreparingMessage =>
      'Amakuru mashya y’ikaze ry’ikipe n’amahitamo yo kwinjira arimo gupakirwa.';

  @override
  String get onboardingAccessUnavailableTitle => 'Ikaze ntirifunguka';

  @override
  String get onboardingAccessUnavailableMessage =>
      'Iyi konti ntishobora gufungura iri kaze. Kwinjira na WhatsApp no gukomeza nk’umushyitsi biracyaboneka.';

  @override
  String get onboardingChangedTitle => 'Ikaze ryahindutse';

  @override
  String get onboardingChangedMessage =>
      'Ikaze ryahindutse mu gihe ryafungurwaga. Vugurura upakire iririho.';

  @override
  String get onboardingSecurityTimeoutTitle =>
      'Igihe cyo kugenzura umutekano cyarangiye';

  @override
  String get onboardingSecurityTimeoutMessage =>
      'Ikaze ntiryagenzuwe ku gihe. Reba umurongo wawe maze uvugurure.';

  @override
  String get onboardingUnavailableTitle => 'Ikaze ntiriboneka';

  @override
  String get onboardingUnavailableMessage =>
      'Ikaze ntiryapakiwe mu buryo bwizewe. Ongera ugerageze cyangwa ukomeze utinjiye.';

  @override
  String get onboardingRefresh => 'Vugurura';

  @override
  String splashLoadingSemantic(String app) {
    return '$app irimo gupakirwa';
  }

  @override
  String get authBack => 'Subira inyuma';

  @override
  String get authCountryUnavailable =>
      'Amakuru y’igihugu ntaboneka muri iyi verisiyo.';

  @override
  String get authSendingCodeTitle => 'Kode irimo koherezwa';

  @override
  String get authSendingCodeMessage =>
      'Guma kuri iyi paji mu gihe kwinjira na WhatsApp bitangira.';

  @override
  String get authSignInUnavailableTitle => 'Kwinjira ntibiboneka';

  @override
  String get authRequestTimeoutTitle => 'Igihe cy’ubusabe cyarangiye';

  @override
  String get authNumberLinkedTitle => 'Nomero isanzwe ihujwe';

  @override
  String get authCheckNumberTitle => 'Reba nomero';

  @override
  String get authCodeNotSentTitle => 'Kode ntiyoherejwe';

  @override
  String get authEditNumber => 'Hindura nomero';

  @override
  String get authPhonePermissionMessage =>
      'Iyi konti ntishobora gusaba kode yo kwinjira.';

  @override
  String get authPhoneTimeoutMessage =>
      'Igihe cyo gusaba kode cyarangiye. Reba umurongo wongere ugerageze.';

  @override
  String get authPhoneConflictMessage =>
      'Iyi nomero isanzwe ihujwe. Yisuzume cyangwa ukoreshe konti isanzwe.';

  @override
  String get authPhoneInvalidMessage =>
      'Andika nomero ya telefone nyayo irimo kode y’igihugu.';

  @override
  String get authPhoneUnknownMessage =>
      'Kode yo kwinjira ntiyoherejwe. Ongera ugerageze.';

  @override
  String get authPhoneOfflineMessage =>
      'Jya ku murongo kugira ngo wohereze kode ya WhatsApp.';

  @override
  String get authWhatsAppEyebrow => 'WhatsApp';

  @override
  String get authEnterNumberTitle => 'Andika nomero';

  @override
  String get authEnterNumberBody => 'Turakoherereza kode y’ibanga yo kwinjira.';

  @override
  String get authPhoneLabel => 'Telefone';

  @override
  String get authWhatsAppNumberLabel => 'Nomero ya WhatsApp';

  @override
  String get authPhoneHint => 'Nomero ya telefoni';

  @override
  String get authPhonePrivacy => 'Nomero yawe iguma mu ibanga.';

  @override
  String get authSendCode => 'Ohereza kode';

  @override
  String get authGuestSessionUnavailable =>
      'Ntibyashobotse gufungura nk’umushyitsi. Ongera ugerageze.';

  @override
  String get authOtpInvalidMessage => 'Reba kode wongere ugerageze.';

  @override
  String get authOtpExpiredMessage => 'Saba kode nshya.';

  @override
  String get authNewCodeSent => 'Kode nshya ya WhatsApp yoherejwe.';

  @override
  String get authSendingNewCodeTitle => 'Kode nshya irimo koherezwa';

  @override
  String get authCheckingCodeTitle => 'Kode irimo kugenzurwa';

  @override
  String get authSendingNewCodeMessage =>
      'Guma kuri iyi paji mu gihe kode nshya isabwa.';

  @override
  String get authCheckingCodeMessage =>
      'Guma kuri iyi paji mu gihe kode igenzurwa.';

  @override
  String get authVerificationUnavailableTitle => 'Kugenzura ntibiboneka';

  @override
  String get authCodeExpiredTitle => 'Kode yarangije igihe';

  @override
  String get authCodeNotAcceptedTitle => 'Kode ntiyemewe';

  @override
  String get authVerificationFailedTitle => 'Kugenzura ntibyakunze';

  @override
  String get authCheckCode => 'Reba kode';

  @override
  String get authOtpPermissionMessage =>
      'Iyi konti ntishobora kugenzura kode yasabwe.';

  @override
  String get authOtpConflictMessage =>
      'Iyi nomero isanzwe ihujwe n’ubundi buryo bwo kwinjira.';

  @override
  String get authOtpUnknownMessage => 'Kode ntiyagenzuwe. Ongera ugerageze.';

  @override
  String get authOtpOfflineMessage =>
      'Jya ku murongo kugira ngo ugenzure kode ya WhatsApp.';

  @override
  String get authPhoneMissingTitle => 'Nomero ya telefone ntihari';

  @override
  String get authPhoneMissingMessage =>
      'Subira ku ntangiriro usabe kode ya WhatsApp.';

  @override
  String get authChangeNumber => 'Hindura nomero';

  @override
  String authResendIn(int seconds) {
    return 'Ongera wohereze mu masegonda $seconds';
  }

  @override
  String get authResendCode => 'Ongera wohereze kode';

  @override
  String get authCheckWhatsAppEyebrow => 'Reba WhatsApp';

  @override
  String get authEnterCodeTitle => 'Andika kode';

  @override
  String get authEnterCodeBody => 'Yoherejwe kuri nomero yawe ya WhatsApp.';

  @override
  String get authCodeLabel => 'Kode';

  @override
  String get authWhatsAppCodeLabel => 'Kode ya WhatsApp';

  @override
  String get authCodeHint => '••••••';

  @override
  String get authCodePrivacy => 'Kode ihishwe kugira ngo igume mu ibanga.';

  @override
  String get authVerifyCode => 'Emeza kode';

  @override
  String get authVerifyAndContinue => 'Emeza ukomeze';

  @override
  String get homeRefreshingTitle => 'Kuvugurura Ahabanza';

  @override
  String get homeRefreshingMessage =>
      'Amakuru y’umukino, amanota n’inzira zihuse bikomeza kugaragara mu gihe amakuru mashya aza.';

  @override
  String get homeUpdatesPausedTitle => 'Amakuru mashya yahagaze';

  @override
  String get homeSavedContentNotice =>
      'Harerekanwa amakuru yo ku Ahabanza yabitswe. Subira ku murongo uvugurure kugira ngo ubone amakuru mashya ya klabu.';

  @override
  String get homeOfflineShortcutsNotice =>
      'Jya ku murongo uvugurure Ahabanza. Harerekanwa inzira zihuse zabitswe.';

  @override
  String get homeLiveUnavailableNotice =>
      'Amakuru ya klabu ntari kuboneka ubu. Kurura hasi uvugurure.';

  @override
  String get homePartialUnavailableNotice =>
      'Amwe mu makuru ya klabu ntari kuboneka ubu. Kurura hasi uvugurure.';

  @override
  String get homePartialShortcutsUnavailableNotice =>
      'Amwe mu makuru ya klabu ntari kuboneka ubu. Inzira zihuse zo ku Ahabanza ntiziboneka.';

  @override
  String get homeMatchdayPendingNotice =>
      'Amakuru y’umukino azagaragara namara gutangazwa.';

  @override
  String get homeOpenMatchday => 'Fungura umukino';

  @override
  String get homeMatchdayUnavailable => 'Umukino ntuboneka';

  @override
  String get homeOpenMatchdaySemantic => 'Fungura umukino muri Fan Zone';

  @override
  String get homeMatchdayUnavailableSemantic =>
      'Umukino wo muri Fan Zone ntuboneka';

  @override
  String get homeMatchdayTitle => 'Umunsi w’umukino';

  @override
  String get homeNextFixturePending =>
      'Umukino ukurikira uzagaragara hano umaze gutangazwa.';

  @override
  String get homeFixturesUnavailable => 'Imikino ya klabu ntiraboneka.';

  @override
  String get homeOpenFanZone => 'Fungura Fan Zone';

  @override
  String get homeSearchHint => 'Shakisha';

  @override
  String get homeSearchSemantic => 'Shakisha abafana, imikino n’ikofi';

  @override
  String get homeNotifications => 'Amatangazo';

  @override
  String get homeWallet => 'Ikofi';

  @override
  String get homeAccessUnavailableTitle => 'Ahabanza ntihaboneka';

  @override
  String get homeAccessUnavailableMessage =>
      'Konti yawe ntishobora gufungura Ahabanza ubu. Vugana n’ubufasha niba wari ukwiriye kuhagera.';

  @override
  String get homeChangedTitle => 'Ahabanza hahindutse';

  @override
  String get homeChangedMessage =>
      'Amakuru yo ku Ahabanza yahindutse ukiyareba. Vugurura kugira ngo ubone amakuru agezweho.';

  @override
  String get homeSecurityTimeoutTitle =>
      'Igenzura ry’umutekano wo ku Ahabanza ryarengeje igihe';

  @override
  String get homeSecurityTimeoutMessage =>
      'Ntitwashoboye kwemeza uburenganzira bwo ku Ahabanza. Vugurura wongere ugerageze.';

  @override
  String get homeUnavailableTitle => 'Ahabanza ntihaboneka';

  @override
  String get homeUnavailableMessage => 'Amakuru ya klabu ntari kuboneka ubu.';

  @override
  String get homeSupportersTitle => 'Abafana';

  @override
  String get homeSupportersSubtitle => 'Abakora cyane';

  @override
  String homePoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Amanota $count',
      one: 'Inota 1',
      zero: 'Amanota 0',
    );
    return '$_temp0';
  }

  @override
  String get homeNewsTitle => 'Amakuru';

  @override
  String get homeLatestUpdates => 'Amakuru mashya ya klabu';

  @override
  String get homeLatestUnavailable =>
      'Amakuru mashya ya klabu ntari kuboneka ubu. Kurura hasi uvugurure.';

  @override
  String get homeOpenMatchDetails => 'Fungura ibisobanuro by’umukino';

  @override
  String homeMatchTitle(String home, String away) {
    return '$home na $away';
  }

  @override
  String get homeShortcutsTitle => 'Inzira zihuse';

  @override
  String get homeLess => 'Bike';

  @override
  String get homeMore => 'Byinshi';

  @override
  String get homeHideMoreShortcuts => 'Hisha izindi nzira zihuse';

  @override
  String get homeShowMoreShortcuts => 'Erekana izindi nzira zihuse';

  @override
  String get homeMoreShortcuts => 'Izindi nzira zihuse';

  @override
  String homeActionUnavailable(String action) {
    return '$action\nNtiboneka';
  }

  @override
  String homeActionUnavailableInline(String action) {
    return '$action · Ntiboneka';
  }

  @override
  String homeActionOpensHint(String action) {
    return 'Fungura $action';
  }

  @override
  String homeActionUnavailableHint(String action) {
    return '$action ntiboneka';
  }

  @override
  String get homeTicketsAction => 'Amatike';

  @override
  String get homeMembershipAction => 'Injira muri Gikundiro';

  @override
  String get homeFanZoneAction => 'Fan Zone';

  @override
  String get homeShopAction => 'Iduka';

  @override
  String get homeFetLabel => 'FET';

  @override
  String get homeRankLabel => 'Umwanya';

  @override
  String get fanClubPreviewUnavailableTitle =>
      'Ibanza rya fan club ntiriboneka';

  @override
  String get fanClubPreviewUnavailableMessage =>
      'Ibisobanuro bya fan club ntibyafunguwe muri iyi verisiyo cyangwa kuri iyi club.';

  @override
  String get fanClubBackToSupporters => 'Subira ku bafana';

  @override
  String get fanClubUnavailableTitle => 'Fan club ntiboneka';

  @override
  String get fanClubUnavailableMessage =>
      'Iyi fan club yemewe kandi igaragara ku mugaragaro ntiyabonetse.';

  @override
  String get fanClubFallbackName => 'Fan club';

  @override
  String get fanClubUnknownRegion => 'Ntihazwi';

  @override
  String get fanClubProtectedRequestPath => 'Inzira irinzwe';

  @override
  String get fanClubActive => 'Irakora';

  @override
  String get fanClubPendingReview => 'Itegereje kwemezwa';

  @override
  String fanClubCurrentSemantic(String name) {
    return 'Fan club uri kureba, $name';
  }

  @override
  String get fanClubAboutTitle => 'Ibyerekeye iyi club';

  @override
  String fanClubRegionValue(String region) {
    return 'Akarere: $region';
  }

  @override
  String get fanClubSnapshotTitle => 'Incamake y’itsinda';

  @override
  String get fanClubAwaitingApproval =>
      'Iyi fan club itegereje kwemezwa n’umuyobozi.';

  @override
  String get fanClubJoinRequestsReviewed =>
      'Ubusabe bwo kwinjira busuzumirwa mu gice cy’Abafana.';

  @override
  String fanClubRegionSentence(String region) {
    return 'Akarere: $region.';
  }

  @override
  String fanClubPublicSupporters(String members) {
    return 'Abafana $members bagaragara ku mugaragaro.';
  }

  @override
  String get fanClubUnavailableOfflineTitle =>
      'Fan club ntiboneka nta murandasi';

  @override
  String get fanClubUnavailableOfflineMessage =>
      'Jya kuri murandasi wemeze amakuru mashya ya club yemewe.';

  @override
  String get fanClubAccessDeniedTitle => 'Ntiwemerewe kureba fan club';

  @override
  String get fanClubAccessDeniedMessage =>
      'Iyi club ntiboneka kuri konti ukoresha.';

  @override
  String get fanClubDetailsChangedTitle => 'Amakuru ya fan club yahindutse';

  @override
  String get fanClubRefreshBeforeSupporters =>
      'Vugurura mbere yo gukomeza ku Bafana.';

  @override
  String get fanClubRefreshAction => 'Vugurura club';

  @override
  String get fanClubTryAgainAction => 'Ongera ugerageze';

  @override
  String get fanClubSecurityTimeoutTitle =>
      'Igenzura ry’umutekano rya fan club ryarengeje igihe';

  @override
  String get fanClubSecurityTimeoutMessage =>
      'Fan club yemewe ntiyashoboye kwemezwa mu mutekano. Ongera ugerageze.';

  @override
  String get fanClubLoadFailureTitle => 'Ntitwashoboye gufungura fan club';

  @override
  String get fanClubLoadFailureMessage =>
      'Fan club yemewe ntiyashoboye kwemezwa. Ongera ugerageze.';

  @override
  String get fanClubShowingSavedTitle => 'Hari kwerekanwa fan club yabitswe';

  @override
  String get fanClubSavedDetailsMayChange =>
      'Amakuru y’abanyamuryango n’ay’umunsi w’umukino ashobora kuba yarahindutse.';

  @override
  String get fanClubRefreshingTitle => 'Fan club iri kuvugururwa';

  @override
  String get fanClubLastConfirmedVisible =>
      'Amakuru ya nyuma yemejwe ya club aracyagaragara.';

  @override
  String get fanClubLastConfirmedRefresh =>
      'Aya ni amakuru ya nyuma yemejwe. Vugurura mbere yo gukomeza.';

  @override
  String get fanClubCheckTimedOutTitle =>
      'Igenzura rya fan club ryarengeje igihe';

  @override
  String get fanClubAccessChangedTitle =>
      'Uburenganzira kuri fan club bwahindutse';

  @override
  String get fanClubAccessChangedMessage =>
      'Amakuru yabitswe arasomeka gusa. Subira ku Bafana.';

  @override
  String get fanClubRefreshFailedTitle => 'Kuvugurura fan club byanze';

  @override
  String get fanClubMatchdayAgenda => 'Gahunda y’umunsi w’umukino';

  @override
  String fanClubMatchMeta(String competition, String venue) {
    return '$competition  •  $venue';
  }

  @override
  String fanClubMatchSchedule(String date, String time) {
    return '$date  •  $time';
  }

  @override
  String get fanClubMembersLabel => 'Abanyamuryango';

  @override
  String get fanClubStatusLabel => 'Imiterere';

  @override
  String get fanClubRegionLabel => 'Akarere';

  @override
  String get fanClubOpenSupportersSemantic => 'Fungura igice cy’Abafana';

  @override
  String get fanClubPendingReviewSemantic => 'Fan club itegereje kwemezwa';

  @override
  String get fanClubSupportersAction => 'Abafana';

  @override
  String get fanClubOpenSupportersAction => 'Fungura abafana';

  @override
  String get fanClubCopyLink => 'Koporora ihuza';

  @override
  String get fanClubCopyLinkSemantic => 'Koporora ihuza rya fan club';

  @override
  String fanClubShareFallback(String appName) {
    return 'Fungura $appName ujye mu gice cya Fan Clubs.';
  }

  @override
  String fanClubShareText(String appName, String target) {
    return 'Injira muri iyi fan club ya $appName: $target';
  }

  @override
  String get fanClubLinkCopied => 'Ihuza rya fan club ryakoporowe.';

  @override
  String get fanClubsLoadError => 'Fan clubs ntizashoboye gufunguka ubu.';

  @override
  String get fanClubReviewRequestSent =>
      'Ubusabe bwo kwemezwa bwoherejwe. Ntuba winjiye club itarabwemeza.';

  @override
  String get fanClubsCommunityEyebrow => 'Umuryango';

  @override
  String get fanClubsTitle => 'Amakipe y’abafana';

  @override
  String get fanClubsSearchHint => 'Shakisha clubs cyangwa ahantu';

  @override
  String get fanClubsFeaturedChapter => 'Itsinda ryatoranyijwe';

  @override
  String get fanClubOfficialChapterFallback => 'Itsinda ryemewe ry’abafana.';

  @override
  String fanClubMembersValue(String members) {
    return 'Abanyamuryango $members';
  }

  @override
  String fanClubRegionMembers(String region, String members) {
    return '$region • $members';
  }

  @override
  String get fanClubReviewRequested => 'Kwemeza byasabwe';

  @override
  String get fanClubRequestReview => 'Saba kwemezwa';

  @override
  String get fanClubDetailsAction => 'Ibisobanuro';

  @override
  String get liveMatchLoadError =>
      'Ntitwashoboye gufungura amakuru y’umukino uri kuba ubu.';

  @override
  String get liveStatusLive => 'Uri kuba';

  @override
  String get liveStatusHalfTime => 'Akaruhuko';

  @override
  String get liveStatusFullTime => 'Warangiye';

  @override
  String get liveStatusPostponed => 'Wasubitswe';

  @override
  String get liveStatusCancelled => 'Wahagaritswe';

  @override
  String get liveStatusUpcoming => 'Uteganyijwe';

  @override
  String get liveStatusFinal => 'Warangiye';

  @override
  String liveTimeVenue(String time, String venue) {
    return '$time  •  $venue';
  }

  @override
  String get liveMatchUpdate => 'Amakuru y’umukino';

  @override
  String liveMatchTeamsUpper(String home, String away) {
    return '$home NA $away';
  }

  @override
  String get liveModeActive =>
      'Amakuru y’umukino uri kuba arakora. Ibiba bigaragara ako kanya.';

  @override
  String get liveMatchReport => 'Raporo y’umukino';

  @override
  String get liveMatchFinishedPending =>
      'Umukino warangiye. Incamake irategerejwe.';

  @override
  String get liveMatchdayIntel => 'Amakuru y’umunsi w’umukino';

  @override
  String get liveFixturePublished =>
      'Umukino watangajwe. Amakuru ako kanya azatangira hafi yo gutangira.';

  @override
  String get liveStatPossession => 'Kugumana umupira';

  @override
  String get liveStatShots => 'Amashoti';

  @override
  String get liveStatCorners => 'Koruneri';

  @override
  String get liveStatPending => 'Birategerejwe';

  @override
  String get liveMatchCenter => 'Amakuru y’umukino';

  @override
  String get liveMyPredictions => 'Ibyo nategetse';

  @override
  String liveScore(int homeScore, int awayScore) {
    return '$homeScore - $awayScore';
  }

  @override
  String get liveMatchIntel => 'Amakuru y’umukino';

  @override
  String get liveBrowsePredictions => 'Reba ibyo abantu bategetse';

  @override
  String get liveShareMatch => 'Sangiza umukino';

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
  String get liveMatchCopied => 'Amakuru y’umukino yakoporowe.';

  @override
  String get liveCenterUnavailable => 'Amakuru y’umukino ntaboneka';

  @override
  String get liveRefresh => 'Vugurura';

  @override
  String get newsArticleNotFoundTitle => 'Inkuru ntiyabonetse';

  @override
  String get newsArticleNotFoundMessage =>
      'Iyi nkuru ishobora kuba yarakuweho cyangwa itakiboneka.';

  @override
  String get newsBackToLiveMatch => 'Subira ku mukino uri kuba';

  @override
  String get newsClubNews => 'Amakuru ya club';

  @override
  String newsArticleImageSemantic(String title) {
    return 'Ifoto y’inkuru $title';
  }

  @override
  String get newsRefreshingTitle => 'Inkuru iri kuvugururwa';

  @override
  String get newsRefreshingMessage =>
      'Inkuru ya nyuma yemejwe irakomeza kugaragara mu gihe verisiyo nshya igenzurwa.';

  @override
  String get newsRelatedUnavailableTitle => 'Izindi nkuru zijyanye ntiziboneka';

  @override
  String get newsRelatedUnavailableMessage =>
      'Ushobora gusoma iyi nkuru, ariko gufungura izindi zijyanye ntibyafunguwe muri iyi verisiyo.';

  @override
  String get newsShowingSavedTitle => 'Hari kwerekanwa inkuru yabitswe';

  @override
  String get newsShowingSavedMessage =>
      'Jya kuri murandasi uvugurure mbere yo gufungura indi nkuru.';

  @override
  String newsSelectedSemantic(String title) {
    return 'Inkuru watoranyije $title';
  }

  @override
  String get newsToday => 'Uyu munsi';

  @override
  String newsMetadata(String date) {
    return 'Amakuru ya club  ·  $date  ·  Ishami ry’itangazamakuru';
  }

  @override
  String get newsRelatedIntel => 'Izindi nkuru zijyanye';

  @override
  String get newsRefreshArticle => 'Vugurura inkuru';

  @override
  String get newsConnectionRestored => 'Murandasi yagarutse';

  @override
  String get newsArticleOffline => 'Inkuru ntiboneka nta murandasi';

  @override
  String get newsRefreshLatest => 'Vugurura wemeze inkuru nshya.';

  @override
  String get newsReconnectLatest => 'Jya kuri murandasi ufungure inkuru nshya.';

  @override
  String get newsAccessUnavailableTitle => 'Ntiwemerewe kureba inkuru';

  @override
  String get newsAccessUnavailableMessage =>
      'Konti ukoresha ntiyemerewe kureba iyi nkuru.';

  @override
  String get newsChangedTitle => 'Inkuru yahindutse';

  @override
  String get newsChangedMessage => 'Vugurura mbere yo gufungura indi nkuru.';

  @override
  String get newsSecurityTimeoutTitle =>
      'Igenzura ry’umutekano ry’inkuru ryarengeje igihe';

  @override
  String get newsSecurityTimeoutMessage =>
      'Nta nkuru nshya yemejwe. Vugurura wongere ugerageze.';

  @override
  String get newsUnavailableTitle => 'Inkuru ntiboneka';

  @override
  String get newsUnavailableMessage =>
      'Inkuru nshya ntiyashoboye kwemezwa. Vugurura wongere ugerageze.';

  @override
  String liveTeamLogoSemantic(String label) {
    return 'Ikirango cy’ikipe $label';
  }

  @override
  String get liveTeamFallback => 'Ikipe';

  @override
  String liveMatchEventSemantic(String event) {
    return 'Icyabaye mu mukino: $event';
  }

  @override
  String get liveEventGoal => 'igitego';

  @override
  String get liveEventCard => 'ikarita';

  @override
  String get liveEventSubstitution => 'gusimbuza';

  @override
  String get liveEventVarReview => 'igenzura rya VAR';

  @override
  String get liveEventUpdate => 'amakuru mashya';

  @override
  String liveStatSemantic(String label, String value) {
    return '$label $value';
  }

  @override
  String get shopAllCategory => 'Byose';

  @override
  String get shopProductFallback => 'Igicuruzwa';

  @override
  String shopProductAdded(String name) {
    return '$name cyongewe mu gatebo.';
  }

  @override
  String get shopStoreTitle => 'Iduka';

  @override
  String get shopTitle => 'Iduka';

  @override
  String get shopSearch => 'Shakisha';

  @override
  String get shopSearchProducts => 'Shakisha ibicuruzwa';

  @override
  String get shopViewCart => 'Reba agatebo';

  @override
  String get shopCart => 'Agatebo';

  @override
  String get shopBack => 'Subira inyuma';

  @override
  String get shopNoProductsTitle => 'Nta bicuruzwa bihari';

  @override
  String shopNoProductsCategoryTitle(String category) {
    return 'Nta bicuruzwa muri $category';
  }

  @override
  String get shopNoProductsMessage =>
      'Ibicuruzwa byemewe bizagaragara hano ikipe nibishyira mu bubiko.';

  @override
  String get shopNoProductsCategoryMessage =>
      'Gerageza ikindi cyiciro cyangwa ukureho akayunguruzo urebe iduka ryose.';

  @override
  String get shopRetry => 'Ongera ugerageze';

  @override
  String get shopRefresh => 'Vugurura';

  @override
  String get shopShowAll => 'Erekana byose';

  @override
  String get shopRefreshingTitle => 'Kuvugurura iduka';

  @override
  String get shopRefreshingMessage => 'Ububiko buri kugenzurwa.';

  @override
  String get shopSavedTitle => 'Ibyabitswe by’iduka';

  @override
  String get shopSavedMessage =>
      'Ububiko bushobora kuba butagihuje n’igihe. Ongera uhuze mbere yo kwishyura.';

  @override
  String get shopRefreshingSemantic =>
      'Amakuru: iduka riravugururwa. Ububiko buri kugenzurwa.';

  @override
  String get shopSavedSemantic =>
      'Iburira: ibyabitswe by’iduka. Ububiko bushobora kuba butagihuje n’igihe.';

  @override
  String get shopClubStore => 'Iduka ry’ikipe';

  @override
  String shopItemsAvailable(int count) {
    return 'Ibicuruzwa $count birahari.';
  }

  @override
  String get shopOfflineTitle => 'Iduka ntiriri kuri interineti';

  @override
  String get shopOfflineMessage =>
      'Huza interineti kugira ngo ubone ibicuruzwa by’ikipe.';

  @override
  String get shopAccessTitle => 'Nta burenganzira bwo kugera ku iduka';

  @override
  String get shopAccessMessage =>
      'Iyi konti ntishobora kubona ibicuruzwa by’ikipe. Vugana n’ubufasha niba wari ukwiye kubigeraho.';

  @override
  String get shopInventoryChangedTitle => 'Ububiko bw’iduka bwahindutse';

  @override
  String get shopInventoryChangedMessage =>
      'Ibicuruzwa bihari byahindutse mu gihe cyo kubifungura. Vugurura mbere yo kongeramo.';

  @override
  String get shopSecurityTimeoutTitle =>
      'Igenzura ry’umutekano w’iduka ryarengeje igihe';

  @override
  String get shopSecurityTimeoutMessage =>
      'Igenzura ry’ububiko ryatinze cyane. Vugurura wongere ugerageze.';

  @override
  String get shopUnavailableTitle => 'Iduka ntiriboneka';

  @override
  String get shopUnavailableMessage =>
      'Ntibishobotse gufungura ibicuruzwa ubu.';

  @override
  String get shopOutOfStockUpper => 'Cyashize mu bubiko';

  @override
  String get shopOutOfStock => 'Cyashize mu bubiko';

  @override
  String get shopAddToCart => 'Ongeraho mu gatebo';

  @override
  String shopProductImageSemantic(String name) {
    return 'Ifoto y’igicuruzwa $name';
  }

  @override
  String shopProductUnavailableSemantic(String name) {
    return '$name, cyashize mu bubiko';
  }

  @override
  String get shopOpenProduct => 'Fungura igicuruzwa';

  @override
  String get shopSearchHint => 'Shakisha imyambaro, ibitambaro n’ibishya';

  @override
  String get shopMerchFallback => 'Ibicuruzwa';

  @override
  String shopQuantityValue(int quantity) {
    return 'Umubare $quantity';
  }

  @override
  String get shopDecreaseQuantity => 'Gabanya umubare';

  @override
  String get shopIncreaseQuantity => 'Ongera umubare';

  @override
  String get shopRemove => 'Kuramo';

  @override
  String get shopReadyToCheckout => 'Byiteguye kwishyurwa';

  @override
  String get shopCheckout => 'Ishyura';

  @override
  String get shopItemOutOfStockToast => 'Iki gicuruzwa cyashize mu bubiko.';

  @override
  String get shopSelectSizeToast => 'Hitamo ingano mbere yo kongera mu gatebo.';

  @override
  String get shopViewCartAction => 'Reba agatebo';

  @override
  String get shopProductNotFoundTitle => 'Igicuruzwa ntikibonetse';

  @override
  String get shopProductNotFoundMessage =>
      'Iki gicuruzwa ntikikiboneka mu iduka ry’iyi kipe.';

  @override
  String get shopBackToStore => 'Subira mu iduka';

  @override
  String get shopProductOfflineTitle =>
      'Amakuru y’igicuruzwa ntari kuri interineti';

  @override
  String get shopProductOfflineMessage =>
      'Ongera uhuze urebe igiciro, ingano n’uko gihari.';

  @override
  String get shopProductAccessTitle => 'Nta burenganzira kuri iki gicuruzwa';

  @override
  String get shopProductAccessMessage =>
      'Iki gicuruzwa ntigishobora gufungurwa n’iyi konti.';

  @override
  String get shopProductChangedTitle => 'Amakuru y’igicuruzwa yahindutse';

  @override
  String get shopProductChangedMessage =>
      'Vugurura urebe igiciro, ingano n’uko gihari ubu.';

  @override
  String get shopProductSecurityTitle =>
      'Igenzura ry’umutekano ryarengeje igihe';

  @override
  String get shopProductSecurityMessage =>
      'Igenzura ry’igicuruzwa ryatinze cyane. Vugurura mbere yo kugura.';

  @override
  String get shopProductUnavailableTitle => 'Igicuruzwa ntikiboneka';

  @override
  String get shopProductUnavailableMessage =>
      'Amakuru mashya y’igicuruzwa ntiyabonetse.';

  @override
  String get shopLoadingProductName => 'Imyambaro yemewe iri gufungurwa';

  @override
  String get shopLoadingProductDescription =>
      'Amakuru y’ibicuruzwa byemewe ari gufungurwa...';

  @override
  String get shopLoadingBadge => 'Birafungurwa';

  @override
  String get shopOfficialMerchandise => 'Igicuruzwa cyemewe cy’ikipe.';

  @override
  String get shopCloseProductDetails => 'Funga amakuru y’igicuruzwa';

  @override
  String get shopRefreshingProductTitle => 'Kuvugurura igicuruzwa';

  @override
  String get shopRefreshingProductMessage =>
      'Igiciro, ingano n’uko gihari biri kugenzurwa.';

  @override
  String get shopSavedProductTitle => 'Amakuru y’igicuruzwa yabitswe';

  @override
  String get shopSavedProductMessage =>
      'Ongera uhuze uvugurure igiciro, ingano n’uko gihari mbere yo kugura.';

  @override
  String get shopInStock => 'Kirahari';

  @override
  String shopStockAvailable(int count) {
    return 'HASIGAYE $count';
  }

  @override
  String get shopSelectSize => 'Hitamo ingano';

  @override
  String shopSizeTooltip(String size) {
    return 'Ingano $size';
  }

  @override
  String get shopSizeSelectedHint => 'Yatoranyijwe';

  @override
  String get shopSizeAvailableHint => 'Irahari';

  @override
  String get shopQuantity => 'Umubare';

  @override
  String get shopTotal => 'Igiteranyo';

  @override
  String get shopBuyNow => 'Gura ubu';

  @override
  String get shopConnectPaymentAvailability =>
      'Huza interineti kugira ngo ugenzure uburyo bwo kwishyura.';

  @override
  String get shopPaymentSetupPending =>
      'Uburyo bwo kwishyura butegereje kwemezwa n’ikipe.';

  @override
  String get shopPaymentCheckError =>
      'Uburyo bwo kwishyura ntibwagenzuwe. Agatebo na aderesi byawe biracyahari.';

  @override
  String get shopConnectBeforeCheckout =>
      'Huza interineti mbere yo kwishyura. Agatebo na aderesi biracyahari.';

  @override
  String get shopAddressRequired =>
      'Banza wandike aderesi yo kugeza ibicuruzwa.';

  @override
  String get shopMomoSetupPending =>
      'Kwishyura na MOMO bitegereje kwemezwa n’ikipe.';

  @override
  String shopOrderDialerFailure(String orderId) {
    return 'Komande $orderId yabitswe, ariko MOMO ntiyafungutse.';
  }

  @override
  String shopOrderCreated(String orderId) {
    return 'Komande $orderId yakozwe. Kwemeza ubwishyu biracyategerejwe.';
  }

  @override
  String get shopReviewOrder => 'Suzuma komande';

  @override
  String shopItemQuantitySummary(String name, int quantity) {
    return '$name x$quantity';
  }

  @override
  String shopMoreItems(int count) {
    return '+ibindi bicuruzwa $count';
  }

  @override
  String get shopDeliverTo => 'Gezwa kuri';

  @override
  String get shopPaymentInstructions =>
      'Emeza ubusabe bwa MOMO kuri telefoni yawe, hanyuma wemeze hano. Komande itegereza kugeza ubwishyu bugenzuwe.';

  @override
  String get shopPaymentSubmitted => 'Nohereje ubwishyu';

  @override
  String get shopCartEmptyTitle => 'Agatebo karimo ubusa';

  @override
  String get shopCartEmptyMessage =>
      'Ongeramo ibicuruzwa byo mu iduka kugira ngo utangire kwishyura.';

  @override
  String get shopBackToShop => 'Subira mu iduka';

  @override
  String get shopDelivery => 'Kugeza ibicuruzwa';

  @override
  String get shopAddressAndTotal => 'Aderesi n’igiteranyo';

  @override
  String get shopDeliveryAddress => 'Aderesi yo kugeza ibicuruzwa';

  @override
  String get shopEnterDeliveryAddress => 'Andika aderesi yo kugeza ibicuruzwa';

  @override
  String shopStreetCityCountry(String country) {
    return 'Umuhanda, umujyi, $country';
  }

  @override
  String get shopSubtotal => 'Igiteranyo gito';

  @override
  String get shopCheckingPayment => 'Kugenzura ubwishyu';

  @override
  String get shopCheckingPaymentMessage =>
      'Kugenzura uburyo bwa MOMO bw’iyi kipe.';

  @override
  String get shopPaymentCheckFailed => 'Kugenzura ubwishyu ntibyashobotse';

  @override
  String get shopCheckoutUnavailable => 'Kwishyura ntibishoboka';

  @override
  String shopPayTo(String label) {
    return 'Ishyura kuri $label';
  }

  @override
  String get shopReviewCart => 'Suzuma agatebo';

  @override
  String get shopConnectionRequired => 'Interineti irakenewe';

  @override
  String get shopPaymentRouteNotReady => 'Uburyo bwo kwishyura ntiburiteguye';

  @override
  String get shopCheckoutNotPermitted => 'Kwishyura ntibyemewe';

  @override
  String get shopStatusUncertain => 'Imimerere ntizwi neza';

  @override
  String get shopProcessing => 'Birakorwa';

  @override
  String get shopPayWithMomo => 'Ishyura na MOMO';

  @override
  String get shopCheckoutViaMomo => 'Ishyura ukoresheje MOMO';

  @override
  String get shopOrderUncertainTitle => 'Imimerere ya komande ntizwi neza';

  @override
  String get shopOrderUncertainMessage =>
      'Igihe cyo kwishyura cyarangiye. Agatebo na aderesi biracyahari. Ntukongere kugeza ikipe yemeje ko komande yabitswe.';

  @override
  String get shopOrderChangedTitle => 'Amakuru ya komande yahindutse';

  @override
  String get shopOrderChangedMessage =>
      'Komande yahindutse mu gihe yoherezwaga. Agatebo na aderesi biracyahari. Banza ubisuzume.';

  @override
  String get shopCheckoutDeniedMessage =>
      'Konti yawe ntishobora gutanga iyi komande. Agatebo na aderesi biracyahari. Vugana n’ubufasha bw’ikipe.';

  @override
  String get shopCheckoutFailureTitle => 'Kwishyura ntibyatangiye';

  @override
  String get shopCheckoutFailureMessage =>
      'Nta komande yemejwe. Agatebo na aderesi biracyahari. Bisuzume wongere ugerageze.';

  @override
  String get shopSampleProductName => 'Umwenda wa Rayon wo mu rugo';

  @override
  String get shopSampleProductDescription =>
      'Umwenda wemewe w’umunsi w’umukino ufite ikirango cy’ikipe, umwenda uhumesha n’umurimbo w’ubururu.';

  @override
  String get shopOfficialBadge => 'Byemewe';

  @override
  String get shopSampleProductSummary =>
      'Imyambaro yemewe · S M L XL · 47 irahari';

  @override
  String get shopProductImageUnavailable => 'Ifoto y’igicuruzwa ntiboneka';

  @override
  String get shopOfficialKit => 'Imyambaro yemewe ya Rayon';

  @override
  String get shopPremiumMerchandise => 'Igicuruzwa cyiza cy’umunsi w’umukino';

  @override
  String get ticketQrAccessUnavailableTitle =>
      'Kugera kuri e-tike ntibishoboka';

  @override
  String get ticketQrAccessUnavailableMessage =>
      'Kode zo kwinjira ntizikora muri iyi verisiyo. Subira mu bubiko bwa tike urebe imimerere.';

  @override
  String get ticketNotFoundTitle => 'Tike ntiyabonetse';

  @override
  String get ticketUnavailableShort => 'E-tike ntiboneka.';

  @override
  String get ticketPaymentPendingTitle => 'Kwemeza ubwishyu birategerejwe';

  @override
  String get ticketPaymentPendingMessage =>
      'Ubusabe bwa tike bwanditswe, ariko kode ya QR izafunguka ubwishyu bumaze kwemezwa.';

  @override
  String get ticketEntryCode => 'Kode yo kwinjira ya tike';

  @override
  String get ticketScannerHelper =>
      'Yereke gusa umusomyi wemewe ku munsi w’umukino.';

  @override
  String get ticketDateLabel => 'Itariki';

  @override
  String get ticketTimeLabel => 'Isaha';

  @override
  String get ticketVenueLabel => 'Ahabera';

  @override
  String get ticketAppleWallet => 'Apple Wallet';

  @override
  String get ticketGoogleWallet => 'Google Wallet';

  @override
  String get ticketWalletExportUnavailable =>
      'Kohereza tike muri wallet ntibiraboneka muri iyi verisiyo.';

  @override
  String get ticketGoogleWalletChecking => 'Kureba niba Google Wallet iboneka…';

  @override
  String get ticketGoogleWalletReady =>
      'Tike yawe yemejwe ishobora kongerwa muri Google Wallet.';

  @override
  String get ticketGoogleWalletAdding => 'Iri kongerwa muri Google Wallet…';

  @override
  String get ticketGoogleWalletAdded => 'Yongewe muri Google Wallet';

  @override
  String get ticketGoogleWalletAddingMessage =>
      'Tike itekanye iri gutegurwa kandi Google Wallet iri gufungurwa.';

  @override
  String get ticketGoogleWalletAddedMessage =>
      'Google Wallet yemeje ko tike yabitswe.';

  @override
  String get ticketGoogleWalletCancelled =>
      'Kubika muri Google Wallet byahagaritswe. Tike yawe iracyaboneka hano.';

  @override
  String get ticketGoogleWalletUnavailable =>
      'Google Wallet ntiboneka kuri iki gikoresho cyangwa kuri iyi konti.';

  @override
  String get ticketGoogleWalletOnlineRequired =>
      'Ongera uhuze mbere yo kongera iyi tike muri Google Wallet.';

  @override
  String get ticketGoogleWalletPaymentPending =>
      'Ubwishyu bugomba kwemezwa mbere yo kongera iyi tike muri Google Wallet.';

  @override
  String get ticketGoogleWalletPermissionDenied =>
      'Iyi konti ntishobora kongera tike yatoranyijwe muri Google Wallet.';

  @override
  String get ticketGoogleWalletTimeout =>
      'Ubusabe butekanye bwarengeje igihe. Nta kubika kwemejwe; ongera ugerageze.';

  @override
  String get ticketGoogleWalletFailed =>
      'Tike ntiyashoboye kongerwa muri Google Wallet. Ongera ugerageze nyuma.';

  @override
  String ticketSelectedSemantic(String match) {
    return 'E-tike yatoranyijwe $match';
  }

  @override
  String get ticketOfflineTitle => 'E-tike ntiboneka nta interineti';

  @override
  String get ticketOfflineMessage =>
      'Ongera uhuze mbere yo gufungura kode yo kwinjira.';

  @override
  String get ticketAccessDeniedTitle => 'Kugera kuri e-tike byanzwe';

  @override
  String get ticketAccessDeniedMessage =>
      'Iyi tike ntishobora gufungurwa n’iyi konti.';

  @override
  String get ticketChangedTitle => 'Tike yahindutse';

  @override
  String get ticketChangedMessage =>
      'Vugurura ububiko bwa tike mbere yo kwerekana iyi kode.';

  @override
  String get ticketSecurityTimeoutTitle =>
      'Igenzura ry’umutekano wa tike ryarengeje igihe';

  @override
  String get ticketSecurityTimeoutMessage =>
      'Kode yo kwinjira ntiyemejwe. Vugurura mbere yo kwinjira.';

  @override
  String get ticketUnavailableTitle => 'Tike ntiboneka';

  @override
  String get ticketUnavailableMessage =>
      'Iyi tike ntiyashoboye kwemezwa mu bubiko bwawe.';

  @override
  String get ticketRefreshAction => 'Vugurura tike';

  @override
  String get ticketSavedCodeTitle => 'Kode yabitswe irerekanwa';

  @override
  String get ticketRefreshingTitle => 'Kuvugurura tike';

  @override
  String get ticketEntryCodeAccessChangedTitle =>
      'Uburenganzira kuri tike bwahindutse';

  @override
  String get ticketCheckTimedOutTitle => 'Igenzura rya tike ryarengeje igihe';

  @override
  String get ticketRefreshUnavailableTitle => 'Kuvugurura tike ntibishoboka';

  @override
  String get ticketSavedCodeMessage =>
      'Ongera uhuze kandi uvugurure mbere yo kwerekana kode ku muryango.';

  @override
  String get ticketRefreshingMessage =>
      'Kode ya nyuma yemejwe iracyagaragara mu gihe ububiko bugenzurwa.';

  @override
  String get ticketRefreshBeforeUse =>
      'Vugurura mbere yo gukoresha iyi kode yo kwinjira.';

  @override
  String get ticketRefreshUpper => 'Vugurura tike';

  @override
  String get ticketWalletUnavailableTitle => 'Ububiko bwa tike ntibuboneka';

  @override
  String get ticketWalletUnavailableMessage =>
      'Ububiko bwa tike ntibwashoboye gufunguka. Reba interineti wongere ugerageze.';

  @override
  String get ticketMyTickets => 'Tike zanjye';

  @override
  String get ticketRefreshTickets => 'Vugurura tike';

  @override
  String get ticketUpcoming => 'Izaza';

  @override
  String get ticketPast => 'Izahise';

  @override
  String get ticketBrowseMatches => 'Shakisha imikino';

  @override
  String get ticketOpenQr => 'Fungura kode ya QR ya tike';

  @override
  String ticketWalletSemantic(String match, String status, String seat) {
    return '$match, tike $status, $seat';
  }

  @override
  String ticketSeatPrice(String seat, String price) {
    return '$seat • $price';
  }

  @override
  String get ticketPendingQrMessage =>
      'Ubwishyu bwakiriwe kuri telefoni bugomba kwemezwa mbere y’uko QR ifunguka.';

  @override
  String get ticketCheckoutSummary => 'Incamake yo kwishyura';

  @override
  String get ticketMatchLabel => 'Umukino';

  @override
  String get ticketSeatTypeLabel => 'Ubwoko bw’icyicaro';

  @override
  String get ticketQuantityLabel => 'Umubare';

  @override
  String get ticketSeatCodeLabel => 'Kode y’icyicaro';

  @override
  String get ticketTotalLabel => 'Igiteranyo';

  @override
  String get ticketPaymentRouteLabel => 'Uburyo bwo kwishyura';

  @override
  String ticketPayToDialer(String label) {
    return 'Ishyura kuri $label\nTelefoni irafungura ubusabe bwa USSD.';
  }

  @override
  String get ticketSoldOut => 'Byashize';

  @override
  String get ticketPayViaMomo => 'Ishyura na MOMO';

  @override
  String get ticketConfirmAfterMomo =>
      'Emeza ubwishyu nyuma yo kurangiza ubusabe bwa MOMO.';

  @override
  String get ticketConfirmPurchase => 'Emeza ubuguzi';

  @override
  String get ticketMatchUpper => 'Umukino';

  @override
  String get ticketZoneUpper => 'Agace';

  @override
  String get ticketSeatUpper => 'Icyicaro';

  @override
  String get ticketQuantityUpper => 'Umubare';

  @override
  String get ticketServiceFeeUpper => 'Amafaranga ya serivisi';

  @override
  String get ticketTotalUpper => 'Igiteranyo';

  @override
  String get ticketIncluded => 'Arimo';

  @override
  String ticketMomoValue(String label) {
    return 'MOMO: $label';
  }

  @override
  String get ticketConfirmPaymentWarning =>
      'Emeza gusa umaze kwishyura MoMo kuri telefoni yawe.';

  @override
  String get ticketCompletedPayment => 'Narangije kwishyura';

  @override
  String get ticketDidNotPay => 'Ntabwo nishyuye';

  @override
  String ticketMatchVersus(String home, String away) {
    return '$home na $away';
  }

  @override
  String ticketCompetitionVenue(String competition, String venue) {
    return '$competition  •  $venue';
  }

  @override
  String ticketRemainingCapacity(int count) {
    return 'Imyanya isigaye: $count';
  }

  @override
  String get ticketChooseAccess => 'Hitamo ahantu';

  @override
  String get ticketGeneral => 'Rusange';

  @override
  String get ticketGeneralSubtitle => 'Imyanya rusange';

  @override
  String get ticketVip => 'VIP';

  @override
  String get ticketVipSubtitle => 'Imyanya myiza ya VIP';

  @override
  String get ticketChooseSeat => 'Hitamo icyicaro';

  @override
  String get ticketChangeSeat => 'Hindura icyicaro';

  @override
  String get ticketReview => 'Suzuma';

  @override
  String get ticketReviewReservation => 'Suzuma ubusabe';

  @override
  String get ticketOfficialCategories => 'Ibyiciro byemewe';

  @override
  String get ticketOfficialCategoriesMessage =>
      'Ibyiciro bya tike byemewe. Imyanya igaragara ikipe ifunguye igurisha ryemewe.';

  @override
  String get ticketListTitle => 'Amatike';

  @override
  String get ticketFilterMatches => 'Shungura imikino';

  @override
  String get ticketMatchFilters => 'Akayunguruzo k\'imikino';

  @override
  String get ticketSortSoonest => 'Ibegereye';

  @override
  String get ticketSortLatest => 'Iheruka';

  @override
  String get ticketSortCheapest => 'Ihendutse';

  @override
  String get ticketTypeAvailable => 'Arahaboneka';

  @override
  String get ticketTypeSoldOut => 'Yagurishijwe yose';

  @override
  String get ticketTypeVipZones => 'Ahantu VIP';

  @override
  String get ticketRefreshMatches => 'Vugurura imikino';

  @override
  String get ticketRefreshMatchesOffline =>
      'Internet irakenewe kugira ngo uvugurure imikino';

  @override
  String get ticketNext => 'Ikurikira';

  @override
  String get ticketMine => 'Ayanjye';

  @override
  String get ticketUpcomingSemantic => 'Amatike y\'imikino iri imbere';

  @override
  String get ticketPastSemantic => 'Amatike y\'imikino yarangiye';

  @override
  String get ticketMineSemantic => 'Amatike yanjye';

  @override
  String get ticketRefreshingInventoryTitle => 'Kuvugurura amakuru y\'amatike';

  @override
  String get ticketRefreshingInventoryMessage =>
      'Imikino n\'amatike ahari biri kugenzurwa.';

  @override
  String get ticketSavedInventoryTitle => 'Amakuru y\'amatike yabitswe';

  @override
  String get ticketSavedInventoryMessage =>
      'Amakuru y\'amatike ashobora kuba ashaje. Ongera uhuze internet mbere yo kugura.';

  @override
  String get ticketNoUpcomingTitle => 'Nta mukino uri imbere ufite amatike';

  @override
  String get ticketNoUpcomingMessage =>
      'Amatike y\'imikino iri imbere azagaragara hano ikipe nimara gutangira kuyagurisha.';

  @override
  String get ticketNoPastTitle => 'Nta mukino warangiye wari ufite amatike';

  @override
  String get ticketNoPastMessage =>
      'Imikino yarangiye izagaragara hano nyuma y\'uko igurishwa ry\'amatike risozwa.';

  @override
  String get ticketRefresh => 'Vugurura';

  @override
  String get ticketStatusSoldOut => 'Yagurishijwe yose';

  @override
  String get ticketStatusAvailable => 'Arahari';

  @override
  String get ticketFrom => 'Guhera ku';

  @override
  String get ticketBuyAction => 'Gura itike';

  @override
  String get ticketSalesNotOpen => 'Igurisha ntirirafungurwa';

  @override
  String get ticketVersusUpper => 'Na';

  @override
  String get ticketListOfflineTitle => 'Huza internet urebe amatike';

  @override
  String get ticketListOfflineMessage =>
      'Ongera uhuze internet kugira ngo ubone imikino n\'amatike ahari.';

  @override
  String get ticketConnectionRequired => 'Internet irakenewe';

  @override
  String get ticketListAccessTitle => 'Nta burenganzira bwo kubona amatike';

  @override
  String get ticketListAccessMessage =>
      'Iyi konti ntishobora kubona ububiko bw\'amatike bw\'ikipe. Vugana n\'abafasha b\'ikipe niba wagombye kubugeraho.';

  @override
  String get ticketAccessRequired => 'Uburenganzira burakenewe';

  @override
  String get ticketInventoryChangedTitle => 'Amakuru y\'amatike yahindutse';

  @override
  String get ticketInventoryChangedMessage =>
      'Amakuru y\'umukino cyangwa amatike yahindutse mu gihe yari ari gufungurwa. Vugurura mbere yo guhitamo itike.';

  @override
  String get ticketInventorySecurityTitle =>
      'Igenzura ry\'umutekano ryarengeje igihe';

  @override
  String get ticketInventorySecurityMessage =>
      'Igenzura ryizewe ryatinze cyane. Vugurura wongere ugerageze.';

  @override
  String get ticketFixturesUnavailableTitle => 'Imikino ntiyafungutse';

  @override
  String get ticketFixturesUnavailableMessage =>
      'Amakuru y\'amatike ntari kuboneka ubu. Reba internet wongere ugerageze.';

  @override
  String get ticketRetry => 'Ongera ugerageze';

  @override
  String get ticketPaymentAvailabilityOffline =>
      'Huza internet kugira ngo ugenzure uburyo bwo kwishyura itike buriho.';

  @override
  String get ticketPaymentSetupPending =>
      'Kwishyura amatike bitegereje kwemezwa n\'ikipe.';

  @override
  String get ticketPaymentVerificationUnavailable =>
      'Kugenzura inzira yo kwishyura ntibikunda ubu. Ongera ugerageze.';

  @override
  String get ticketConnectBeforePurchase =>
      'Huza internet mbere yo kugura. Icyicaro n\'umubare wahisemo biracyabitswe.';

  @override
  String get ticketSignInBeforePurchase =>
      'Banza winjire kugira ngo ugure amatike.';

  @override
  String get ticketMomoSetupPending =>
      'Kwishyura amatike kuri MOMO bitegereje kwemezwa n\'ikipe.';

  @override
  String get ticketReservationFailed =>
      'Kubika itike ntibyakunze. Ongera ugerageze ku rupapuro rw\'umukino.';

  @override
  String get ticketDialerOpenFailed =>
      'Ubusabe bw\'itike bwabitswe, ariko telefoni ntiyafunguye uburyo bwa MOMO.';

  @override
  String ticketRequestsSubmitted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ubusabe bw\'amatike $count bwoherejwe — buracyagenzurwa.',
      one: 'Ubusabe bw\'itike bwoherejwe — kwishyura kuracyagenzurwa.',
    );
    return '$_temp0';
  }

  @override
  String get ticketConfirmationTimedOut =>
      'Kwemeza itike byarengeje igihe. Banza urebe Amatike Yanjye mbere yo kongera kugerageza.';

  @override
  String get ticketRequestFailed =>
      'Ubusabe bw\'itike ntibwakunze. Ibyo wahisemo biracyabitswe.';

  @override
  String get ticketMatchDay => 'Umunsi w\'umukino';

  @override
  String get ticketSalesUnavailableTitle => 'Igurishwa ry\'amatike ntirihari';

  @override
  String get ticketSalesUnavailableMessage =>
      'Guhitamo amatike ntibifunguye kuri iyi porogaramu cyangwa iyi kipe.';

  @override
  String get ticketBackToTickets => 'Subira ku matike';

  @override
  String get ticketFixtureNotFoundTitle => 'Umukino ntiwabonetse';

  @override
  String get ticketFixtureNotFoundMessage => 'Uyu mukino nturi kuboneka.';

  @override
  String get ticketDetailOfflineTitle =>
      'Amakuru y\'itike ntari kuboneka nta internet';

  @override
  String get ticketDetailOfflineMessage =>
      'Huza internet kugira ngo ubone uyu mukino n\'amatike ahari.';

  @override
  String get ticketDetailAccessTitle => 'Nta burenganzira bwo kubona itike';

  @override
  String get ticketDetailAccessMessage =>
      'Uyu mukino ntushobora kurebwa kuri konti y\'iyi kipe.';

  @override
  String get ticketDetailSecurityTitle =>
      'Igenzura ry\'umutekano ryarengeje igihe';

  @override
  String get ticketDetailSecurityMessage =>
      'Umukino ntiwashoboye kwemezwa mu buryo bwizewe. Ongera ugerageze.';

  @override
  String get ticketDetailChangedTitle => 'Amakuru y\'umukino yahindutse';

  @override
  String get ticketDetailChangedMessage =>
      'Vugurura umukino mbere yo guhitamo itike.';

  @override
  String get ticketDetailUnavailableTitle => 'Uyu mukino ntiwafungutse';

  @override
  String get ticketDetailUnavailableMessage =>
      'Umukino ntiwashoboye kwemezwa. Ongera ugerageze.';

  @override
  String get ticketTryAgainUpper => 'Ongera ugerageze';

  @override
  String get ticketRefreshFixtureUpper => 'Vugurura umukino';

  @override
  String get ticketSavedFixtureTitle => 'Kwerekana umukino wabitswe';

  @override
  String get ticketSavedFixtureMessage =>
      'Ibiciro by\'amatike bishobora kuba byahindutse. Ongera uhuze internet mbere yo gusuzuma cyangwa kugura.';

  @override
  String get ticketRefreshingFixtureTitle => 'Kuvugurura umukino';

  @override
  String get ticketRefreshingFixtureMessage =>
      'Amatike aheruka kwemezwa aracyagaragara.';

  @override
  String get ticketFixtureChangedTitle => 'Umukino wahindutse';

  @override
  String get ticketLastConfirmedOptionsMessage =>
      'Aya ni amatike aheruka kwemezwa. Vugurura mbere yo gukomeza.';

  @override
  String get ticketFixtureCheckTimedOutTitle =>
      'Igenzura ry\'umukino ryarengeje igihe';

  @override
  String get ticketAccessChangedTitle => 'Uburenganzira ku matike bwahindutse';

  @override
  String get ticketSavedFixtureReadOnlyMessage =>
      'Umukino wabitswe ushobora gusomwa gusa. Subira ku Matike kugira ngo ukomeze neza.';

  @override
  String get ticketFixtureRefreshFailedTitle =>
      'Kuvugurura umukino ntibyakunze';

  @override
  String get ticketSeatMapTitle => 'Hitamo icyicaro';

  @override
  String get ticketConfirm => 'Emeza';

  @override
  String get ticketSeatSelectionUnavailableTitle =>
      'Guhitamo icyicaro ntibishoboka';

  @override
  String get ticketSeatSelectionUnavailableMessage =>
      'Guhitamo icyicaro ntibifunguye kuri iyi porogaramu cyangwa iyi kipe.';

  @override
  String get ticketBackToTicketUpper => 'Subira ku itike';

  @override
  String get ticketSeatMapUnavailableTitle =>
      'Ikarita y\'imyanya ntiri kuboneka';

  @override
  String get ticketSeatMapUnavailableMessage => 'Uyu mukino ntiwabonetse.';

  @override
  String get ticketSeatMapOfflineTitle =>
      'Ikarita y\'imyanya ntiboneka nta internet';

  @override
  String get ticketSeatMapOfflineMessage =>
      'Huza internet kugira ngo wemeze imyanya ihari.';

  @override
  String get ticketSeatMapAccessTitle =>
      'Nta burenganzira ku ikarita y\'imyanya';

  @override
  String get ticketSeatMapAccessMessage =>
      'Uyu mukino ntushobora kurebwa kuri konti y\'iyi kipe.';

  @override
  String get ticketSeatMapSecurityTitle =>
      'Igenzura ry\'ikarita ryarengeje igihe';

  @override
  String get ticketSeatMapSecurityMessage =>
      'Umukino ntiwashoboye kwemezwa mu buryo bwizewe. Ongera ugerageze.';

  @override
  String get ticketSeatMapChangedTitle => 'Ikarita y\'imyanya yahindutse';

  @override
  String get ticketSeatMapChangedMessage =>
      'Vugurura umukino mbere yo guhitamo icyicaro.';

  @override
  String get ticketRefreshSeatMapUpper => 'Vugurura ikarita';

  @override
  String get ticketSeatMapLoadFailedTitle => 'Ikarita y\'imyanya ntiyafungutse';

  @override
  String get ticketSeatMapLoadFailedMessage =>
      'Umukino ntiwashoboye kwemezwa. Ongera ugerageze.';

  @override
  String get ticketSavedSeatMapTitle => 'Kwerekana ikarita yabitswe';

  @override
  String get ticketSavedSeatMapMessage =>
      'Imyanya ihari ishobora kuba yarahindutse. Ongera uhuze internet mbere yo kwemeza.';

  @override
  String get ticketRefreshingSeatMapTitle => 'Kuvugurura ikarita y\'imyanya';

  @override
  String get ticketRefreshingSeatMapMessage =>
      'Umukino uheruka kwemezwa uracyagaragara.';

  @override
  String get ticketLastConfirmedStandsMessage =>
      'Ibi ni bice biheruka kwemezwa. Vugurura mbere yo guhitamo.';

  @override
  String get ticketSeatMapCheckTimedOutTitle =>
      'Igenzura ry\'ikarita ryarengeje igihe';

  @override
  String get ticketSeatAccessChangedTitle =>
      'Uburenganzira ku myanya bwahindutse';

  @override
  String get ticketSavedSeatMapReadOnlyMessage =>
      'Ikarita yabitswe ishobora gusomwa gusa. Subira ku itike kugira ngo ukomeze.';

  @override
  String get ticketSeatMapRefreshFailedTitle =>
      'Kuvugurura ikarita ntibyakunze';

  @override
  String get ticketSelectedSeatUpper => 'Icyicaro cyahiswemo';

  @override
  String get ticketSeatMapSemantic =>
      'Ikarita y\'imyanya ya sitade ikorana n\'uyikoresha';

  @override
  String ticketSeatMapSelectedSemantic(String seat) {
    return 'Ikarita y\'imyanya ya sitade, wahisemo $seat';
  }

  @override
  String get ticketSeatMapHint => 'Kanda ku gice cya sitade uhitemo icyicaro';

  @override
  String ticketSelectedStandSemantic(String stand) {
    return 'Igice $stand cyahiswemo';
  }

  @override
  String ticketSelectStandSemantic(String stand) {
    return 'Hitamo igice $stand';
  }

  @override
  String ticketSeatCode(String stand, int number) {
    return '$stand, icyicaro $number';
  }

  @override
  String get ticketStandVipGold => 'VIP Zahabu';

  @override
  String get ticketStandEast => 'Igice cy\'Iburasirazuba';

  @override
  String get ticketStandTribuneRed => 'Igice Gitukura';

  @override
  String get ticketStandStanding => 'Ahahagararwa';

  @override
  String get ticketLegendVip => 'VIP';

  @override
  String get ticketLegendTribune => 'Igice';

  @override
  String get contributionsClubProjectsTitle => 'Imishinga y\'ikipe';

  @override
  String get contributionsProjectsUnavailableTitle =>
      'Imishinga ntiri kuboneka';

  @override
  String get contributionsProjectsUnavailableMessage =>
      'Imishinga y\'ikipe ntiri kuboneka by\'agateganyo.';

  @override
  String get contributionsProjectFallback => 'Umushinga';

  @override
  String contributionsFundingProgress(String current, String target) {
    return '$current / $target';
  }

  @override
  String contributionsSupporters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Abafana $count',
      one: 'Umufana 1',
      zero: 'Nta bafana',
    );
    return '$_temp0';
  }

  @override
  String get contributionsContributeAction => 'Tanga inkunga';

  @override
  String get contributionsCommunitiesTitle => 'Imiryango';

  @override
  String get contributionsCommunitiesLoadError =>
      'Imiryango itanga inkunga ntiyafungutse ubu.';

  @override
  String get contributionsInitiatives => 'Ibikorwa';

  @override
  String get contributionsContributed => 'Inkunga yatanzwe';

  @override
  String get contributionsActiveInitiatives => 'Ibikorwa biri gukorwa';

  @override
  String get contributionsCommunitiesUnavailableTitle =>
      'Imiryango ntiri kuboneka';

  @override
  String get contributionsCommunityQuietTitle => 'Nta gikorwa kiri mu muryango';

  @override
  String get contributionsCommunityQuietMessage =>
      'Imiryango itanga inkunga izagaragara hano ikipe nitangiza igikorwa gikurikira.';

  @override
  String get contributionsPublicGroupFallback => 'Itsinda rusange';

  @override
  String contributionsContributors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Abatanze inkunga $count',
      one: 'Uwatanze inkunga 1',
      zero: 'Nta watanze inkunga',
    );
    return '$_temp0';
  }

  @override
  String contributionsGoalPercent(int percent) {
    return '$percent% by\'intego';
  }

  @override
  String get contributionsConnectToLoad =>
      'Huza internet kugira ngo ubone ibikorwa by\'inkunga.';

  @override
  String get contributionsInitiativesUnavailableMessage =>
      'Ibikorwa by\'inkunga ntibiri kuboneka by\'agateganyo.';

  @override
  String get contributionsSmsEnabled =>
      'Guhuza SMS za MoMo byafunguwe kuri iki gikoresho.';

  @override
  String get contributionsSmsPermissionDenied =>
      'Uburenganzira bwo gusoma SMS ntibwatanzwe. Guhuza biracyafunze.';

  @override
  String get contributionsSmsEnableFailed =>
      'Gufungura ihuzwa rya SMS ntibyakunze. Reba uburenganzira wongere ugerageze.';

  @override
  String get contributionsSmsDisabled => 'Guhuza SMS za MoMo byafunzwe.';

  @override
  String get contributionsConnectBeforeSmsSync =>
      'Huza internet mbere yo guhuza ubutumwa bwa MoMo.';

  @override
  String contributionsSmsSyncComplete(int uploaded, int duplicates) {
    return 'Guhuza SMS byarangiye: $uploaded zoherejwe, $duplicates zari zisanzweho.';
  }

  @override
  String get contributionsSmsSyncFailed =>
      'Guhuza SMS ntibyakunze. Reba internet wongere ugerageze.';

  @override
  String get contributionsHubTitle => 'Tanga inkunga';

  @override
  String get contributionsRefreshingTitle => 'Kuvugurura inkunga';

  @override
  String get contributionsRefreshingMessage =>
      'Amafaranga yose n\'ibikorwa biri kugenzurwa.';

  @override
  String get contributionsSavedTitle => 'Amakuru y\'inkunga yabitswe';

  @override
  String get contributionsSavedMessage =>
      'Amafaranga yose ashobora kuba ashaje. Ongera uhuze internet mbere yo gutanga cyangwa guhuza inkunga.';

  @override
  String get contributionsTeamProjects => 'Imishinga y\'ikipe';

  @override
  String contributionsRaised(String current, String target) {
    return '$current kuri $target yakusanyijwe.';
  }

  @override
  String contributionsOpenMetric(int count) {
    return '$count IFUNGUYE';
  }

  @override
  String get contributionsCommunitiesUpper => 'Imiryango';

  @override
  String contributionsInitiativesActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ibikorwa $count birakora.',
      one: 'Igikorwa 1 kirakora.',
    );
    return '$_temp0';
  }

  @override
  String contributionsLiveMetric(int count) {
    return '$count BIRAKORA';
  }

  @override
  String get contributionsCommunityUpper => 'Umuryango';

  @override
  String get contributionsFanClubsChapters =>
      'Amatsinda y\'abafana n\'amashami yo hafi.';

  @override
  String get contributionsLive => 'Birakora';

  @override
  String get contributionsMomoSmsSync => 'Guhuza SMS za MoMo';

  @override
  String get contributionsUnavailableBuild =>
      'Ntibiboneka muri iyi porogaramu.';

  @override
  String get contributionsActiveUpper => 'Birakora';

  @override
  String get contributionsSyncing => 'Birimo guhuzwa…';

  @override
  String get contributionsSyncNow => 'Huza ubu';

  @override
  String get contributionsDisable => 'Funga';

  @override
  String get contributionsEnabling => 'Birimo gufungurwa…';

  @override
  String get contributionsEnableSmsSync => 'Fungura guhuza SMS';

  @override
  String get contributionsLiveCampaigns => 'Ibikorwa biri gukorwa';

  @override
  String get contributionsGroupsUnavailableTitle => 'Amatsinda ntari kuboneka';

  @override
  String get contributionsGroupFallback => 'Itsinda';

  @override
  String contributionsAmountOfTarget(String current, String target) {
    return '$current kuri $target';
  }

  @override
  String get contributionsSeeAllGroups => 'Reba amatsinda yose atanga inkunga';

  @override
  String contributionsSeeAllGroupsSemantic(int count) {
    return 'Reba amatsinda $count yose atanga inkunga';
  }

  @override
  String get contributionsOpenGroupsHint => 'Fungura amatsinda atanga inkunga';

  @override
  String contributionsSeeAll(int count) {
    return 'Reba yose $count';
  }

  @override
  String get contributionsInitiativeTitle => 'Igikorwa rusange';

  @override
  String get contributionsInitiativeLoadingTitle =>
      'Gufungura igikorwa rusange';

  @override
  String get contributionsInitiativeLoadingMessage =>
      'Kugenzura amafaranga yemejwe n\'urutonde rusange rw\'inkunga.';

  @override
  String get contributionsRefresh => 'Vugurura';

  @override
  String get contributionsBackToCommunities => 'Subira ku miryango';

  @override
  String get contributionsInitiativeRefreshingTitle => 'Kuvugurura igikorwa';

  @override
  String get contributionsInitiativeRefreshingMessage =>
      'Amafaranga n\'urutonde biheruka kwemezwa biracyagaragara mu gihe ibishya bigenzurwa.';

  @override
  String get contributionsReadOnlyTitle => 'Inkunga ishobora kurebwa gusa';

  @override
  String get contributionsReadOnlyMessage =>
      'Ibikorwa rusange byemejwe biracyagaragara, ariko gutangira kwishyura byafunzwe muri iyi porogaramu.';

  @override
  String get contributionsSavedInitiativeTitle =>
      'Kwerekana amakuru y\'igikorwa yabitswe';

  @override
  String get contributionsSavedInitiativeMessage =>
      'Ongera uhuze internet uvugurure mbere yo kwishyura cyangwa kwizera amafaranga aheruka.';

  @override
  String get contributionsRefreshInitiativeUpper => 'Vugurura igikorwa';

  @override
  String get contributionsClosedTitle => 'Gutanga inkunga byarafunzwe';

  @override
  String get contributionsClosedMessage =>
      'Amafaranga yemejwe n\'urutonde rusange biracyaboneka kugira ngo bisuzumwe.';

  @override
  String get contributionsPaymentRouteUnavailableTitle =>
      'Inzira yo kwishyura ntiboneka';

  @override
  String get contributionsPaymentRouteUnavailableMessage =>
      'Nta bwishyu buzatangira ikipe itaratangaza uwakira wemejwe.';

  @override
  String get contributionsDisabled => 'Gutanga inkunga byafunzwe';

  @override
  String get contributionsClosed => 'Inkunga zarafunzwe';

  @override
  String get contributionsPaymentUnavailable => 'Kwishyura ntibishoboka';

  @override
  String get contributionsCheckingLatestTotal => 'Kugenzura amafaranga aheruka';

  @override
  String get contributionsRefreshBeforeContributing =>
      'Vugurura mbere yo gutanga inkunga';

  @override
  String get contributionsContributeNow => 'Tanga inkunga ubu';

  @override
  String get contributionsConfirmedTotal => 'Amafaranga yemejwe';

  @override
  String contributionsTargetProgress(String target, int percent) {
    return 'Intego $target · $percent%';
  }

  @override
  String contributionsProgressSemantic(int percent) {
    return '$percent ku ijana by\'intego y\'inkunga byemejwe';
  }

  @override
  String get contributionsTypeUpper => 'Ubwoko';

  @override
  String get contributionsContributorsUpper => 'Abatanze inkunga';

  @override
  String contributionsContributeToSemantic(String group) {
    return 'Tanga inkunga kuri $group';
  }

  @override
  String contributionsPaymentUnavailableSemantic(String action) {
    return '$action. Kwishyura ntibishoboka.';
  }

  @override
  String get contributionsPublicLedgerTitle => 'Urutonde rusange';

  @override
  String get contributionsPublicLedgerPrivacy =>
      'Hagaragara amazina rusange gusa. Kode zo kwishyura n\'amakuru ya konti ntibyerekanwa.';

  @override
  String get contributionsLedgerEmptyTitle => 'Nta nkunga iratangwa';

  @override
  String get contributionsLedgerEmptyMessage =>
      'Ibikorwa rusange byemejwe bizagaragara hano bitagaragaza amakuru yo kwishyura.';

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
  String get contributionsStatusConfirmed => 'Byemejwe';

  @override
  String get contributionsStatusProcessing => 'Biracyakorwa';

  @override
  String get contributionsStatusFailed => 'Ntibyakunze';

  @override
  String get contributionsTypeProject => 'Umushinga w\'ikipe';

  @override
  String get contributionsTypeCommunity => 'Umuryango';

  @override
  String get contributionsConnectionRestoredTitle => 'Internet yagarutse';

  @override
  String get contributionsInitiativeOfflineTitle =>
      'Igikorwa ntikiri kuri internet';

  @override
  String get contributionsConnectionRestoredMessage =>
      'Vugurura ugenzure amafaranga aheruka kwemezwa n\'urutonde rusange.';

  @override
  String get contributionsInitiativeOfflineMessage =>
      'Ongera uhuze internet kugira ngo ufungure iki gikorwa rusange.';

  @override
  String get contributionsInitiativeNotFoundTitle => 'Igikorwa nticyabonetse';

  @override
  String get contributionsInitiativeNotFoundMessage =>
      'Iki gikorwa gishobora kuba cyarafunzwe cyangwa ihuza ritagikora.';

  @override
  String get contributionsInitiativeUnavailableTitle => 'Igikorwa ntikiboneka';

  @override
  String get contributionsInitiativeAccessMessage =>
      'Uburenganzira bwawe bw\'ikipe ntibukwemerera kubona iki gikorwa.';

  @override
  String get contributionsInitiativeChangedTitle => 'Igikorwa cyahindutse';

  @override
  String get contributionsInitiativeChangedMessage =>
      'Vugurura urebe amafaranga aheruka mbere yo gutanga inkunga.';

  @override
  String get contributionsInitiativeTimeoutTitle =>
      'Igenzura ry\'igikorwa ryarengeje igihe';

  @override
  String get contributionsInitiativeTimeoutMessage =>
      'Nta mafaranga yemejwe. Vugurura mbere yo gutanga inkunga.';

  @override
  String get contributionsInitiativeUnavailableMessage =>
      'Vugurura wongere ugerageze urutonde rusange niruboneka.';

  @override
  String get contributionsEmptyCsvCopied => 'CSV irimo ubusa yakoporowe.';

  @override
  String get contributionsCsvCopied => 'CSV irinda ibanga yakoporowe.';

  @override
  String get contributionsStatementTitle => 'Raporo rusange';

  @override
  String get contributionsStatementLoadingTitle => 'Gufungura raporo rusange';

  @override
  String get contributionsStatementLoadingMessage =>
      'Kugenzura inkunga zemejwe n\'amazina rusange arinda ibanga.';

  @override
  String get contributionsBackToInitiative => 'Subira ku gikorwa';

  @override
  String get contributionsStatementRefreshingTitle => 'Kuvugurura raporo';

  @override
  String get contributionsStatementRefreshingMessage =>
      'Raporo iheruka kwemezwa iracyagaragara mu gihe ibishya bigenzurwa.';

  @override
  String get contributionsStatementReadOnlyTitle =>
      'Raporo ishobora kurebwa gusa';

  @override
  String get contributionsStatementReadOnlyMessage =>
      'Ushobora kureba inkunga rusange zemejwe, ariko gukoporora raporo byafunzwe muri iyi porogaramu.';

  @override
  String get contributionsSavedStatementTitle => 'Kwerekana raporo yabitswe';

  @override
  String get contributionsSavedStatementMessage =>
      'Ongera uhuze internet uvugurure mbere yo kohereza cyangwa kwizera amafaranga aheruka.';

  @override
  String get contributionsRefreshStatementUpper => 'Vugurura raporo';

  @override
  String get contributionsCopyCsvSemantic =>
      'Koporora raporo ya CSV irinda ibanga';

  @override
  String contributionsExportUnavailableSemantic(String reason) {
    return 'Kohereza raporo ntibishoboka. $reason';
  }

  @override
  String get contributionsFromUpper => 'Kuva';

  @override
  String get contributionsToUpper => 'Kugeza';

  @override
  String get contributionsAllTime => 'Igihe cyose';

  @override
  String get contributionsNow => 'Ubu';

  @override
  String get contributionsSortUpper => 'Tondeka';

  @override
  String get contributionsSortDate => 'Ku itariki';

  @override
  String get contributionsSortAmount => 'Ku mafaranga';

  @override
  String get contributionsSortAlias => 'Ku izina rusange';

  @override
  String get contributionsPdf => 'Pdf';

  @override
  String get contributionsCsv => 'Csv';

  @override
  String get contributionsComingSoon => 'Biraza vuba';

  @override
  String get contributionsClipboard => 'Ahakopororwa';

  @override
  String get contributionsCopyingCsv => 'Gukoporora CSV…';

  @override
  String get contributionsExportDisabled => 'Kohereza byafunzwe';

  @override
  String get contributionsCheckingLatestEntries => 'Kugenzura inkunga ziheruka';

  @override
  String get contributionsRefreshBeforeExporting =>
      'Vugurura mbere yo kohereza';

  @override
  String get contributionsCopyCsvStatement => 'Koporora raporo ya CSV';

  @override
  String contributionsStatementSummarySemantic(
    String group,
    int count,
    String total,
  ) {
    return 'Raporo rusange ya $group, inkunga $count, amafaranga yemejwe $total';
  }

  @override
  String get contributionsConfirmedTotalUpper => 'Amafaranga yemejwe';

  @override
  String contributionsPublicEntriesInRange(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Inkunga rusange $count muri iki gihe',
      one: 'Inkunga rusange 1 muri iki gihe',
    );
    return '$_temp0';
  }

  @override
  String get contributionsStatementPrivacy =>
      'Hagaragara amazina rusange gusa. Amazina bwite, telefoni, kode zo kwishyura n\'ibiranga konti ntibishyirwamo.';

  @override
  String contributionsFormatSemantic(String label, String helper) {
    return 'Ubwoko bwo kohereza $label, $helper';
  }

  @override
  String get contributionsPreviewUpper => 'Ibizagaragara';

  @override
  String contributionsPreviewShowing(int count) {
    return 'Kwerekana inkunga 5 kuri $count. CSV irimo igihe cyose cyatoranyijwe.';
  }

  @override
  String get contributionsPreviewPublicFields =>
      'CSV irimo gusa amakuru rusange agaragara hasi.';

  @override
  String get contributionsNoStatementEntriesTitle =>
      'Nta nkunga iri muri raporo';

  @override
  String get contributionsNoStatementEntriesMessage =>
      'Nta nkunga rusange ihuye n\'iki gihe. Hitamo ikindi gihe uvugurure.';

  @override
  String get contributionsStatementOfflineTitle => 'Raporo ntiri kuri internet';

  @override
  String get contributionsStatementRestoredMessage =>
      'Vugurura urebe inkunga rusange ziheruka kwemezwa.';

  @override
  String get contributionsStatementOfflineMessage =>
      'Ongera uhuze internet kugira ngo ufungure iyi raporo rusange.';

  @override
  String get contributionsStatementNotFoundTitle => 'Raporo ntiyabonetse';

  @override
  String get contributionsStatementNotFoundMessage =>
      'Igikorwa gishobora kuba cyarafunzwe cyangwa ihuza rya raporo ritagikora.';

  @override
  String get contributionsStatementUnavailableTitle => 'Raporo ntiboneka';

  @override
  String get contributionsStatementAccessMessage =>
      'Uburenganzira bwawe bw\'ikipe ntibukwemerera kubona iyi raporo.';

  @override
  String get contributionsStatementChangedTitle => 'Raporo yahindutse';

  @override
  String get contributionsStatementChangedMessage =>
      'Vugurura urebe inkunga ziheruka kwemezwa mbere yo kohereza.';

  @override
  String get contributionsStatementTimeoutTitle =>
      'Igenzura rya raporo ryarengeje igihe';

  @override
  String get contributionsStatementTimeoutMessage =>
      'Nta raporo iriho yemejwe. Vugurura mbere yo kohereza.';

  @override
  String get contributionsStatementUnavailableMessage =>
      'Vugurura wongere ugerageze urutonde rusange rw\'inkunga niruboneka.';

  @override
  String get contributionsConnectBeforeContributing =>
      'Huza internet mbere yo gutanga inkunga. Nta bwishyu cyangwa nkunga byoherejwe.';

  @override
  String get contributionsDialerFailed =>
      'Telefoni ntiyashoboye gufungura MOMO. Inkunga ntiyoherejwe.';

  @override
  String contributionsStatusAnnouncement(String heading, String message) {
    return '$heading. $message';
  }

  @override
  String get contributionsAmountPrompt => 'Urashaka gutanga angahe?';

  @override
  String contributionsQuickAmount(int thousands) {
    return '+${thousands}K';
  }

  @override
  String get contributionsLaunchMomoDialer => 'Fungura MOMO kuri telefoni';

  @override
  String get contributionsLaunchingMomo => 'Gufungura MoMo';

  @override
  String get contributionsChangeAmount => 'Hindura amafaranga';

  @override
  String get contributionsDialNow => 'Hamagara ubu';

  @override
  String get contributionsCancel => 'Hagarika inkunga';

  @override
  String get contributionsPaymentConfirmedTitle => 'Kwishyura byemejwe';

  @override
  String contributionsPaymentConfirmedMessage(String amount) {
    return 'Inkunga yawe ya $amount yemejwe kandi yabitswe.';
  }

  @override
  String get contributionsPaymentFailedTitle => 'Kwishyura ntibyakunze';

  @override
  String get contributionsPaymentFailedMessage =>
      'Kwishyura ntikwashoboye kwemezwa. Reba amafaranga ya MoMo wongere ugerageze cyangwa uvugane n\'abafasha.';

  @override
  String get contributionsPaymentProcessingTitle => 'Biracyakorwa';

  @override
  String get contributionsPaymentProcessingMessage =>
      'Kwishyura biratinze. Reba urutonde rw\'itsinda kugira ngo ubone uko bimeze. Niba wohereje kuri MoMo, biraza kugaragara.';

  @override
  String get contributionsRecordFailedTitle => 'Ntibyashoboye kubikwa';

  @override
  String get contributionsRecordFailedMessage =>
      'MOMO yafungutse ariko inkunga ntiyabitswe. Subira ku itsinda wongere ugerageze.';

  @override
  String get contributionsAwaitingPaymentTitle => 'Gutegereza kwishyura';

  @override
  String get contributionsAwaitingPaymentMessage =>
      'Rangiza kwishyura kuri MoMo muri telefoni. Inkunga irakomeza kugaragara ko igikorwa kugeza yemejwe.';

  @override
  String get contributionsCheckingPaymentStatus =>
      'Kugenzura uko kwishyura kumeze…';

  @override
  String get contributionsVerifiedUpper => 'Byemejwe';

  @override
  String get contributionsDone => 'Byarangiye';

  @override
  String get contributionsBackToGroup => 'Subira ku itsinda';

  @override
  String get contributionsEnableMomoSmsTitle => 'Fungura guhuza SMS za MoMo';

  @override
  String contributionsSmsPrivacyMessage(String app) {
    return '$app isoma gusa ubutumwa bwa MoMo bwemeza ubwishyu kugira ngo ibike inyemezabwishyu. Ubundi butumwa ntibusomwa.';
  }

  @override
  String get contributionsAllowSmsReading => 'Emerera gusoma SMS';

  @override
  String get contributionsEnable => 'Fungura';

  @override
  String get contributionsNotNowUpper => 'Si ubu';

  @override
  String get settingsTitle => 'Igenamiterere';

  @override
  String get settingsRoleAdmin => 'Umuyobozi';

  @override
  String get settingsRoleSupporter => 'Umufana';

  @override
  String get settingsMembershipDetails => 'Ibisobanuro by’ubunyamuryango';

  @override
  String get settingsSectionAccount => 'Konti';

  @override
  String get settingsSectionPreferences => 'Ibyifuzo';

  @override
  String get settingsSectionSupport => 'Ubufasha';

  @override
  String get settingsEditProfile => 'Hindura umwirondoro';

  @override
  String get settingsAppearance => 'Imigaragarire';

  @override
  String get settingsNotifications => 'Amatangazo';

  @override
  String get settingsPrivacy => 'Ubwirinzi bw’amakuru';

  @override
  String get settingsHelpSupport => 'Ubufasha';

  @override
  String get settingsSignOut => 'Sohoka';

  @override
  String get settingsRefreshingTitle => 'Kuvugurura igenamiterere';

  @override
  String get settingsRefreshingMessage =>
      'Igenamiterere rya konti n’imigaragarire riracyaboneka.';

  @override
  String get settingsOfflineTitle => 'Igenamiterere ritari kuri interineti';

  @override
  String get settingsOfflineMessage =>
      'Nta interineti. Igenamiterere rya konti n’imigaragarire riracyaboneka. Ongera uhuze kugira ngo ubone ubufasha.';

  @override
  String get settingsHelpUnavailableTitle => 'Ubufasha ntibuboneka';

  @override
  String get settingsSupportContactUnavailableTitle =>
      'Aho wabonera ubufasha ntihaboneka';

  @override
  String get settingsSupportContactUnavailableMessage =>
      'Andi magenamiterere aracyakora. Vugurura wongere ugenzure.';

  @override
  String get settingsLoadingTitle => 'Gufungura igenamiterere';

  @override
  String get settingsLoadingMessage => 'Kugenzura niba ubufasha buboneka.';

  @override
  String get settingsAccessLimitedTitle => 'Igenamiterere rifite imipaka';

  @override
  String get settingsAccessLimitedMessage =>
      'Ubufasha ntibwashoboye kwemezwa. Andi magenamiterere aracyakora.';

  @override
  String get settingsChangedTitle => 'Igenamiterere ryahindutse';

  @override
  String get settingsChangedMessage =>
      'Vugurura kugira ngo ubone igenamiterere ry’ubufasha rigezweho.';

  @override
  String get settingsSecurityTimeoutTitle =>
      'Igenzura ry’umutekano ryarengeje igihe';

  @override
  String get settingsSecurityTimeoutMessage =>
      'Reba interineti yawe wongere uvugurure.';

  @override
  String get settingsSupportLoadFailedTitle =>
      'Ubufasha ntibwashoboye gufunguka';

  @override
  String get settingsSupportLoadFailedMessage =>
      'Igenamiterere rya konti n’imigaragarire riracyaboneka.';

  @override
  String get settingsChecking => 'Kugenzura…';

  @override
  String get settingsConnectionRequired => 'Interineti irakenewe';

  @override
  String get settingsUnavailable => 'Ntibiboneka';

  @override
  String get settingsNotConfigured => 'Ntibyashyizweho';

  @override
  String get settingsStatusUnavailable => 'Imiterere ntiboneka';

  @override
  String get settingsThemeUseDevice => 'Koresha igenamiterere rya telefoni';

  @override
  String get settingsThemeLight => 'Urumuri';

  @override
  String get settingsThemeDark => 'Umwijima';

  @override
  String get settingsAppearanceMessage =>
      'Hitamo insanganyamatsiko cyangwa ukoreshe igenamiterere rya telefoni.';

  @override
  String get settingsThemeSystem => 'Sisitemu';

  @override
  String get settingsSupportNotConfigured =>
      'Aho wabonera ubufasha ntihashyizweho.';

  @override
  String settingsSupportGreeting(String app) {
    return 'Muraho, nkeneye ubufasha kuri $app.';
  }

  @override
  String get settingsWhatsAppFailed => 'WhatsApp ntiyashoboye gufunguka.';

  @override
  String get settingsDeleteAccountTitle => 'Ushaka gusiba konti yawe?';

  @override
  String get settingsDeleteAccountMessage =>
      'Bisiba burundu umwirondoro, FET, imidari n’amateka byawe. Ntibisubirwaho.';

  @override
  String get settingsDeleteAccountConfirmPrompt =>
      'Andika DELETE kugira ngo wemeze';

  @override
  String get settingsDeleteAccountConfirmValue => 'DELETE';

  @override
  String get settingsCancelUpper => 'REKA';

  @override
  String get settingsDeletePermanently => 'Siba burundu';

  @override
  String get settingsNotificationPermissionTitle => 'Guma hamwe n\'ikipe';

  @override
  String get settingsNotificationPermissionMessage =>
      'Menyeshwa imikino, inkunga, intambwe za FET n’amakuru y’ikipe.';

  @override
  String get settingsMatchAlerts => 'Amatangazo mbere y’uko umukino utangira';

  @override
  String get settingsContributionUpdates => 'Amakuru y’inkunga n’amatike';

  @override
  String get settingsFetMilestones => 'Intambwe za FET n’ibibazo bishya';

  @override
  String get settingsEnableNotifications => 'Fungura amatangazo';

  @override
  String get settingsMaybeLaterUpper => 'Nyuma';

  @override
  String get settingsSignOutTitle => 'Ushaka gusohoka?';

  @override
  String get settingsSignOutMessage =>
      'Umwirondoro na FET byawe byabitswe. Ushobora kongera kwinjira igihe cyose.';

  @override
  String get settingsStay => 'Guma hano';

  @override
  String get settingsSignOutOthersTitle => 'Ushaka gusohora izindi telefoni?';

  @override
  String get settingsSignOutOthersMessage =>
      'Iyi telefoni irakomeza kwinjiyemo. Izindi sesiyo zirafungwa.';

  @override
  String get settingsSignOutOthersAction => 'Sohora izindi';

  @override
  String get settingsCancel => 'Reka';

  @override
  String get editProfileUpdated => 'Umwirondoro wavuguruwe.';

  @override
  String get editProfileServiceUnavailable =>
      'Serivisi y’umwirondoro ntiboneka by’akanya.';

  @override
  String get editProfileLoadingTitle => 'Gufungura umwirondoro';

  @override
  String get editProfileLoadingMessage =>
      'Kugenzura umwirondoro wawe wabitswe.';

  @override
  String get editProfileAccessLimitedTitle => 'Umwirondoro ufite imipaka';

  @override
  String get editProfileAccessLimitedMessage =>
      'Umwirondoro wawe ntiwashoboye kwemezwa. Ongera winjire.';

  @override
  String get editProfileSignInAgain => 'Ongera winjire';

  @override
  String get editProfileChangedTitle => 'Umwirondoro wahindutse';

  @override
  String get editProfileChangedMessage =>
      'Vugurura kugira ngo ubone umwirondoro ugezweho mbere yo kuwuhindura.';

  @override
  String get editProfileRefresh => 'Vugurura';

  @override
  String get editProfileSecurityTimeoutTitle =>
      'Igenzura ry’umutekano ryarengeje igihe';

  @override
  String get editProfileSecurityTimeoutMessage =>
      'Reba interineti yawe wongere uvugurure.';

  @override
  String get editProfileLoadFailedTitle => 'Umwirondoro ntiwashoboye gufunguka';

  @override
  String get editProfileLoadFailedMessage =>
      'Umwirondoro wawe uracyarinzwe. Ongera ugerageze.';

  @override
  String get editProfileTryAgain => 'Ongera ugerageze';

  @override
  String get editProfileTitle => 'Umwirondoro';

  @override
  String get editProfileSavingTitle => 'Kubika umwirondoro';

  @override
  String get editProfileSavingMessage =>
      'Izina ryawe rirakomeza kugaragara mu gihe kubika byemezwa.';

  @override
  String get editProfileRefreshingTitle => 'Kuvugurura umwirondoro';

  @override
  String get editProfileRefreshingMessage =>
      'Umwirondoro wawe wabitswe uracyagaragara.';

  @override
  String get editProfileEditingUnavailableTitle =>
      'Guhindura umwirondoro ntibiboneka';

  @override
  String get editProfileEditingUnavailableMessage =>
      'Umwirondoro wawe wabitswe uracyagaragara.';

  @override
  String get editProfileChangedElsewhereTitle =>
      'Umwirondoro wahinduriwe ahandi';

  @override
  String get editProfileChangedElsewhereMessage =>
      'Izina rigezweho ryafunguwe. Risuzume mbere yo kubika.';

  @override
  String get editProfileSaveUnconfirmedTitle =>
      'Kubika umwirondoro ntibyemejwe';

  @override
  String get editProfileSaveUnconfirmedMessage =>
      'Vugurura umwirondoro mbere yo kongera kugerageza.';

  @override
  String get editProfileSaveFailedTitle => 'Umwirondoro ntiwashoboye kubikwa';

  @override
  String get editProfileSaveFailedMessage => 'Izina wanditse riracyahari.';

  @override
  String get editProfileOfflineTitle => 'Umwirondoro utari kuri interineti';

  @override
  String get editProfileOfflineMessage =>
      'Nta interineti. Umwirondoro wawe wabitswe uracyagaragara. Ongera uhuze kugira ngo uwuhindure.';

  @override
  String get editProfileUnavailableTitle => 'Umwirondoro ntuboneka';

  @override
  String get editProfileUnavailableMessage =>
      'Umwirondoro wawe ntuboneka. Ongera winjire kugira ngo ugarure konti.';

  @override
  String editProfileAlias(String alias) {
    return '#$alias';
  }

  @override
  String get editProfileNicknameLabel => 'Izina ry’umufana';

  @override
  String get editProfileNicknameHint => 'Izina ry’umufana ritari ngombwa';

  @override
  String get editProfileSaving => 'Kubika…';

  @override
  String get editProfileSaveChanges => 'Bika impinduka';

  @override
  String get editProfileDeleteAccount => 'Siba konti';

  @override
  String get editProfileDeleteHint => 'Siba burundu iyi konti y’umufana';

  @override
  String get editProfileDeleteFailed =>
      'Konti ntiyashoboye gusibwa. Ongera ugerageze.';

  @override
  String get editProfileLanguageEnglish => 'Icyongereza';

  @override
  String get editProfileLanguageFrench => 'Igifaransa';

  @override
  String get editProfileLanguageKinyarwanda => 'Ikinyarwanda';

  @override
  String get notificationPreferencesConnectionRestoredReview =>
      'Interineti yagarutse. Suzuma impinduka zabitswe, hanyuma ubike.';

  @override
  String get notificationPreferencesConnectionRestoredRefreshing =>
      'Interineti yagarutse. Ibyifuzo biri kuvugururwa.';

  @override
  String get notificationPreferencesConnectBeforeChanging =>
      'Banza uhuze interineti mbere yo guhindura uko iki gikoresho cyakira amatangazo.';

  @override
  String get notificationPreferencesDeviceTurnedOff =>
      'Amatangazo yo kuri iki gikoresho yahagaritswe. Bika kugira ngo uvugurure icyifuzo cya konti yawe.';

  @override
  String get notificationPreferencesPermissionGranted =>
      'Uruhushya rwatanzwe kuri iki gikoresho. Bika kugira ngo amatangazo atangire kuri konti yawe.';

  @override
  String get notificationPreferencesBlocked =>
      'Amatangazo yarafunzwe. Yemerere mu igenamiterere ry’igikoresho.';

  @override
  String get notificationPreferencesPermissionPending =>
      'Uruhushya rw’amatangazo ntiruremezwa.';

  @override
  String get notificationPreferencesPushUnavailable =>
      'Amatangazo ya push ntaboneka muri iyi verisiyo.';

  @override
  String get notificationPreferencesDraftKeptConnect =>
      'Impinduka zawe zabitswe. Huza interineti mbere yo kubika.';

  @override
  String get notificationPreferencesSaved =>
      'Ibyifuzo by’amatangazo byabitswe.';

  @override
  String get notificationPreferencesChangedElsewhereLoading =>
      'Ibyifuzo byahinduriwe ahandi. Verisiyo nshya iri kwinjizwa; yisuzume mbere yo kongera kubika.';

  @override
  String get notificationPreferencesChangeNotPermitted =>
      'Iyi konti ntiyemerewe guhindura amatangazo.';

  @override
  String get notificationPreferencesChangedRefresh =>
      'Ibyifuzo byahinduriwe ahandi. Banza uvugurure mbere yo kongera kubika.';

  @override
  String get notificationPreferencesSaveUnconfirmed =>
      'Kubika amatangazo ntibyemejwe. Vugurura mbere yo kongera kugerageza.';

  @override
  String get notificationPreferencesSaveFailedDraftKept =>
      'Ibyifuzo by’amatangazo ntibyashoboye kubikwa. Umushinga wawe wakomeje kubikwa.';

  @override
  String get notificationPreferencesRefreshing =>
      'Ibyifuzo by’amatangazo biri kuvugururwa.';

  @override
  String get notificationPreferencesLoadingTitle => 'Amatangazo ari kwinjizwa';

  @override
  String get notificationPreferencesLoadingMessage =>
      'Icyifuzo cyawe cy’uko wakira amatangazo kiri kugenzurwa.';

  @override
  String get notificationPreferencesOfflineTitle =>
      'Amatangazo ntari kuri interineti';

  @override
  String get notificationPreferencesOfflineMessage =>
      'Huza interineti kugira ngo ubone icyifuzo cyawe cyabitswe.';

  @override
  String get notificationPreferencesUnavailableTitle =>
      'Ibyifuzo by’amatangazo ntibiboneka';

  @override
  String get notificationPreferencesUnavailableMessage =>
      'Injira kugira ngo ucunge uko wakira amatangazo.';

  @override
  String get notificationPreferencesAccessLimitedTitle =>
      'Uburenganzira ku matangazo buragabanyijwe';

  @override
  String get notificationPreferencesAccessLimitedMessage =>
      'Ibyifuzo byawe ntibyashoboye kugenzurwa. Ongera winjire.';

  @override
  String get notificationPreferencesChangedTitle =>
      'Igenamiterere ry’amatangazo ryahindutse';

  @override
  String get notificationPreferencesChangedMessage =>
      'Vugurura kugira ngo ubone icyifuzo kiriho mbere yo kugihindura.';

  @override
  String get notificationPreferencesSecurityTimeoutTitle =>
      'Igihe cyo kugenzura umutekano w’amatangazo cyarangiye';

  @override
  String get notificationPreferencesSecurityTimeoutMessage =>
      'Genzura interineti hanyuma uvugurure.';

  @override
  String get notificationPreferencesLoadFailedTitle =>
      'Igenamiterere ry’amatangazo ntiryashoboye kwinjizwa.';

  @override
  String get notificationPreferencesLoadFailedMessage =>
      'Icyifuzo cyawe cyabitswe kiracyarinzwe. Ongera ugerageze.';

  @override
  String get notificationPreferencesSavingTitle =>
      'Ibyifuzo by’amatangazo biri kubikwa';

  @override
  String get notificationPreferencesSavingMessage =>
      'Amahitamo yawe akomeza kugaragara mu gihe kubika biri kwemezwa.';

  @override
  String get notificationPreferencesRefreshingTitle =>
      'Ibyifuzo by’amatangazo biri kuvugururwa';

  @override
  String get notificationPreferencesRefreshingMessage =>
      'Icyifuzo cyawe cyabitswe gikomeza kugaragara.';

  @override
  String get notificationPreferencesEditingUnavailableTitle =>
      'Guhindura amatangazo ntibiboneka';

  @override
  String get notificationPreferencesEditingUnavailableMessage =>
      'Icyifuzo cyawe cyabitswe gikomeza kugaragara.';

  @override
  String get notificationPreferencesChangedElsewhereTitle =>
      'Igenamiterere ry’amatangazo ryahinduriwe ahandi';

  @override
  String get notificationPreferencesChangedElsewhereMessage =>
      'Vugurura kandi usuzume icyifuzo gishya.';

  @override
  String get notificationPreferencesSaveNotConfirmedTitle =>
      'Kubika amatangazo ntibyemejwe';

  @override
  String get notificationPreferencesSaveNotConfirmedMessage =>
      'Vugurura mbere yo kongera kugerageza. Umushinga wawe warabitswe.';

  @override
  String get notificationPreferencesSaveFailedTitle =>
      'Ibyifuzo by’amatangazo ntibyashoboye kubikwa';

  @override
  String get notificationPreferencesSaveFailedMessage =>
      'Umushinga wawe uracyahari.';

  @override
  String get notificationPreferencesSavedSettingsTitle =>
      'Igenamiterere ry’amatangazo ryabitswe';

  @override
  String get notificationPreferencesSavedSettingsMessage =>
      'Amakuru ashobora kuba ashaje. Ongera uhuze interineti mbere yo guhindura cyangwa kubika.';

  @override
  String get notificationPreferencesCheckingPermissionsTitle =>
      'Uruhushya rw’igikoresho ruri kugenzurwa';

  @override
  String get notificationPreferencesCheckingPermissionsMessage =>
      'Igenzura ry’uko wakira amatangazo riraboneka nyuma y’iri genzura.';

  @override
  String get notificationPreferencesDeviceAlertsUnavailableTitle =>
      'Amatangazo y’igikoresho ntaboneka';

  @override
  String get notificationPreferencesDeviceAlertsUnavailableMessage =>
      'Kwakira push ntibyashyizwe muri iyi verisiyo.';

  @override
  String get notificationPreferencesPermissionEnabled =>
      'Amatangazo ya sisitemu yemerewe kuri iki gikoresho.';

  @override
  String get notificationPreferencesPermissionBlocked =>
      'Amatangazo ya sisitemu yafunzwe kuri iki gikoresho.';

  @override
  String get notificationPreferencesPermissionNotRequested =>
      'Uruhushya ntirurasabwa.';

  @override
  String get notificationPreferencesPermissionNotConfigured =>
      'Push ntashyizwe muri iyi verisiyo.';

  @override
  String get notificationPreferencesPermissionChecking =>
      'Uruhushya rw’amatangazo rw’igikoresho ruri kugenzurwa…';

  @override
  String get notificationPreferencesTitle => 'Amatangazo';

  @override
  String get notificationPreferencesDeliverySection => 'Kwakira amatangazo';

  @override
  String get notificationPreferencesAlertsEnabled => 'Amatangazo yemerewe.';

  @override
  String get notificationPreferencesEnableAlertsDescription =>
      'Emerera amatangazo y’imikino, inyemezabwishyu n’amakuru.';

  @override
  String get notificationPreferencesDeviceDelivery =>
      'Kwakira amatangazo ku gikoresho';

  @override
  String get notificationPreferencesConnectionRequiredUpper =>
      'Interineti irasabwa';

  @override
  String get notificationPreferencesDisableAlerts => 'Hagarika amatangazo';

  @override
  String get notificationPreferencesEnableAlerts => 'Emerera amatangazo';

  @override
  String get notificationPreferencesDeliveryModel => 'Uburyo bwo kwakira';

  @override
  String notificationPreferencesFullStream(String app) {
    return 'Iyo amatangazo yemerewe, iyi verisiyo ikugezaho amatangazo yose ya $app aboneka kuri konti yawe.';
  }

  @override
  String get notificationPreferencesPerCategory =>
      'Guhitamo buri cyiciro ntibirashyirwa muri iyi verisiyo, bityo iri hinduranya rikagenzura amatangazo yose yo kuri iki gikoresho.';

  @override
  String get notificationPreferencesSave => 'Bika';

  @override
  String get privacySettingsConnectionRestoredReview =>
      'Interineti yagarutse. Suzuma impinduka zabitswe, hanyuma ubike.';

  @override
  String get privacySettingsConnectionRestoredRefreshing =>
      'Interineti yagarutse. Igenamiterere ry’ibanga riri kuvugururwa.';

  @override
  String get privacySettingsChangeReady =>
      'Impinduka y’ibanga yiteguye kubikwa.';

  @override
  String get privacySettingsDraftKeptConnect =>
      'Impinduka zawe zabitswe. Huza interineti mbere yo kubika.';

  @override
  String get privacySettingsSaved => 'Igenamiterere ry’ibanga ryabitswe.';

  @override
  String get privacySettingsChangedElsewhereLoading =>
      'Igenamiterere ry’ibanga ryahinduriwe ahandi. Verisiyo nshya iri kwinjizwa; yisuzume mbere yo kongera kubika.';

  @override
  String get privacySettingsChangeNotPermitted =>
      'Iyi konti ntiyemerewe guhindura igenamiterere ry’ibanga.';

  @override
  String get privacySettingsChangedRefresh =>
      'Igenamiterere ry’ibanga ryahinduriwe ahandi. Banza uvugurure mbere yo kongera kubika.';

  @override
  String get privacySettingsSaveUnconfirmed =>
      'Kubika igenamiterere ry’ibanga ntibyemejwe. Vugurura mbere yo kongera kugerageza.';

  @override
  String get privacySettingsSaveFailedDraftKept =>
      'Igenamiterere ry’ibanga ntiryashoboye kubikwa. Umushinga wawe wakomeje kubikwa.';

  @override
  String get privacySettingsRefreshing =>
      'Igenamiterere ry’ibanga riri kuvugururwa.';

  @override
  String get privacySettingsConnectBeforeSigningOut =>
      'Huza interineti mbere yo gusohora ibindi bikoresho.';

  @override
  String get privacySettingsSessionsSignedOut => 'Izindi sesiyo zasohowe.';

  @override
  String get privacySettingsSessionsSignOutFailed =>
      'Ibindi bikoresho ntibyashoboye gusohorwa. Ongera ugerageze.';

  @override
  String get privacySettingsSessionSecurityTimeout =>
      'Igihe cyo kugenzura umutekano wa sesiyo cyarangiye. Ongera ugerageze.';

  @override
  String get privacySettingsSmsAccessRequired =>
      'Guhuza SMS bikomeza kuzimye kugeza wemereye Android gusoma SMS zo kugenzura MoMo.';

  @override
  String get privacySettingsEnableMomoSmsTitle => 'Emerera guhuza SMS za MoMo';

  @override
  String get privacySettingsMomoSmsDisclosure =>
      'Porogaramu isoma gusa SMS zemewe zo kugenzura Mobile Money kuri iki gikoresho kugira ngo ihuze ubwishyu bw’imisanzu. Ntishobora kubona ubundi butumwa.';

  @override
  String get privacySettingsNotNow => 'Si ubu';

  @override
  String get privacySettingsContinue => 'Komeza';

  @override
  String get privacySettingsLoadingTitle =>
      'Igenamiterere ry’ibanga riri kwinjizwa';

  @override
  String get privacySettingsLoadingMessage =>
      'Amahitamo yawe y’ibanga yabitswe ari kugenzurwa.';

  @override
  String get privacySettingsOfflineTitle =>
      'Igenamiterere ry’ibanga ntiri kuri interineti';

  @override
  String get privacySettingsOfflineMessage =>
      'Huza interineti kugira ngo ubone amahitamo yawe y’ibanga yabitswe.';

  @override
  String get privacySettingsUnavailableTitle =>
      'Igenamiterere ry’ibanga ntiriboneka';

  @override
  String get privacySettingsUnavailableMessage =>
      'Injira kugira ngo usuzume kandi ucunge amahitamo yawe y’ibanga.';

  @override
  String get privacySettingsAccessLimitedTitle =>
      'Uburenganzira ku ibanga buragabanyijwe';

  @override
  String get privacySettingsAccessLimitedMessage =>
      'Igenamiterere ryawe ry’ibanga ntiryashoboye kugenzurwa. Ongera winjire.';

  @override
  String get privacySettingsChangedTitle =>
      'Igenamiterere ry’ibanga ryahindutse';

  @override
  String get privacySettingsChangedMessage =>
      'Vugurura kugira ngo ubone amahitamo ariho mbere yo kuyahindura.';

  @override
  String get privacySettingsSecurityTimeoutTitle =>
      'Igihe cyo kugenzura umutekano w’ibanga cyarangiye';

  @override
  String get privacySettingsSecurityTimeoutMessage =>
      'Genzura interineti hanyuma uvugurure.';

  @override
  String get privacySettingsLoadFailedTitle =>
      'Igenamiterere ry’ibanga ntiryashoboye kwinjizwa.';

  @override
  String get privacySettingsLoadFailedMessage =>
      'Amahitamo yawe yabitswe aracyarinzwe. Ongera ugerageze.';

  @override
  String get privacySettingsSavingTitle =>
      'Igenamiterere ry’ibanga riri kubikwa';

  @override
  String get privacySettingsSavingMessage =>
      'Amahitamo yawe akomeza kugaragara mu gihe kubika biri kwemezwa.';

  @override
  String get privacySettingsRefreshingTitle =>
      'Igenamiterere ry’ibanga riri kuvugururwa';

  @override
  String get privacySettingsRefreshingMessage =>
      'Amahitamo yawe yabitswe akomeza kugaragara.';

  @override
  String get privacySettingsEditingUnavailableTitle =>
      'Guhindura igenamiterere ry’ibanga ntibiboneka';

  @override
  String get privacySettingsEditingUnavailableMessage =>
      'Amahitamo yawe yabitswe akomeza kugaragara.';

  @override
  String get privacySettingsChangedElsewhereTitle =>
      'Igenamiterere ry’ibanga ryahinduriwe ahandi';

  @override
  String get privacySettingsChangedElsewhereMessage =>
      'Vugurura kandi usuzume amahitamo mashya.';

  @override
  String get privacySettingsSaveNotConfirmedTitle =>
      'Kubika igenamiterere ry’ibanga ntibyemejwe';

  @override
  String get privacySettingsSaveNotConfirmedMessage =>
      'Vugurura mbere yo kongera kugerageza. Umushinga wawe warabitswe.';

  @override
  String get privacySettingsSaveFailedTitle =>
      'Igenamiterere ry’ibanga ntiryashoboye kubikwa';

  @override
  String get privacySettingsSaveFailedMessage => 'Umushinga wawe uracyahari.';

  @override
  String get privacySettingsSavedSettingsTitle =>
      'Igenamiterere ry’ibanga ryabitswe';

  @override
  String get privacySettingsSavedSettingsMessage =>
      'Amakuru ashobora kuba ashaje. Ongera uhuze interineti mbere yo guhindura cyangwa kubika.';

  @override
  String get privacySettingsEditingUnavailableBuildMessage =>
      'Amahitamo yawe yabitswe akomeza kugaragara muri iyi verisiyo.';

  @override
  String get privacySettingsTitle => 'Ibanga';

  @override
  String get privacySettingsControls => 'Igenzura ry’ibanga';

  @override
  String get privacySettingsControlsDescription =>
      'Hitamo niba ushaka gusangira ibikorwa rusange kandi bitakumenyekanisha. Ibyashakishijwe, abo uvugana na bo, nimero za konti, kode, ubutumwa n’agaciro nyako k’ubwishyu ntibyoherezwa.';

  @override
  String get privacySettingsMomoSmsSync => 'Guhuza SMS za MoMo';

  @override
  String get privacySettingsMomoSmsSyncDescription =>
      'Huza SMS zemewe zo kugenzura Mobile Money kugira ngo imisanzu igenzurwe vuba.';

  @override
  String get privacySettingsShareAnalytics =>
      'Sangiza imibare y’imikoreshereze itakumenyekanisha';

  @override
  String get privacySettingsShareAnalyticsDescription =>
      'Fasha kunoza gushakisha, amatike, imisanzu, Fan Zone n’inzira zo kugarura serivisi.';

  @override
  String get privacySettingsAnalyticsFailClosed =>
      'Imibare ikomeza kuzimye keretse uyemeye kandi verisiyo yashyizweho umukono ifite igenamiterere ryemewe.';

  @override
  String get privacySettingsNoChanges => 'Nta mpinduka zo kubika';

  @override
  String get privacySettingsSave => 'Bika igenamiterere ry’ibanga';

  @override
  String get privacySettingsYourData => 'Amakuru yawe';

  @override
  String get privacySettingsExportDescription =>
      'Saba kopi y’amakuru ya konti unyuze ku muyoboro w’ubufasha washyizweho.';

  @override
  String get privacySettingsExportAction => 'Saba kopi y’amakuru';

  @override
  String privacySettingsExportWhatsAppMessage(String app) {
    return 'Gusaba kopi y’amakuru ya $app. Nyohereza kopi y’amakuru ya konti yanjye.';
  }

  @override
  String privacySettingsExportEmailSubject(String app) {
    return 'Gusaba kopi y’amakuru ya $app';
  }

  @override
  String get privacySettingsExportEmailBody =>
      'Nyohereza kopi y’amakuru ya konti yanjye.';

  @override
  String get privacySettingsMailFailed =>
      'Porogaramu ya imeyili ntiyashoboye gufunguka.';

  @override
  String get privacySettingsOpenPolicy => 'Fungura politiki y’ibanga';

  @override
  String get privacySettingsPolicyUnavailable => 'Politiki y’ibanga ntiboneka';

  @override
  String get privacySettingsPolicyNotAvailableYet =>
      'Politiki y’ibanga ntiraboneka.';

  @override
  String get privacySettingsActiveSessions => 'Sesiyo zikora';

  @override
  String get privacySettingsActiveSessionsDescription =>
      'Hagarika izindi sesiyo zikora zihujwe na konti yawe.';

  @override
  String get privacySettingsSignOutOtherDevices => 'Sohora ibindi bikoresho';

  @override
  String get adminLoadingTitle => 'Ahantu h’ubuyobozi hari kwinjizwa';

  @override
  String get adminLoadingMessage => 'Ibikorwa bya klabu biri kugenzurwa.';

  @override
  String get adminClubAdmin => 'Ubuyobozi bwa klabu';

  @override
  String get adminExit => 'Sohoka mu buyobozi';

  @override
  String get adminCommandCenter => 'Ikigo cy’ubuyobozi';

  @override
  String get adminTotalUsers => 'Abakoresha bose';

  @override
  String get adminActiveGroups => 'Amatsinda akora';

  @override
  String get adminTransactionsToday => 'Ibikorwa by’uyu munsi';

  @override
  String get adminTicketsSold => 'Amatike yagurishijwe';

  @override
  String get adminQuickActions => 'Ibikorwa byihuse';

  @override
  String get adminManageCms => 'Cunga CMS';

  @override
  String get adminManageCmsDescription =>
      'Inkuru, amatangazo n’ahagaragara ibikubiyemo';

  @override
  String get adminCreateMatch => 'Kora umukino';

  @override
  String get adminCreateMatchDescription =>
      'Tegura umukino, uduce n’igenzura ry’amatike';

  @override
  String get adminViewContributions => 'Reba imisanzu';

  @override
  String get adminViewContributionsDescription =>
      'Kurikirana ikusanya ry’amafaranga rya klabu n’amatsinda';

  @override
  String get adminSendNotification => 'Ohereza itangazo';

  @override
  String get adminSendNotificationDescription =>
      'Ohereza push ku byiciro, amatsinda cyangwa abafana bose';

  @override
  String get adminSettleFixtures => 'Emeza imikino';

  @override
  String get adminSettleFixturesDescription =>
      'Andika ibisubizo kandi ugenzure amasoko y’amahitamo';

  @override
  String get adminManageCompetitions => 'Cunga amarushanwa';

  @override
  String get adminManageCompetitionsDescription =>
      'Ongeraho, hindura kandi wemerere shampiyona n’ibikombe';

  @override
  String get adminSmsSyncMonitor => 'Igenzura ryo guhuza SMS';

  @override
  String get adminSmsSyncMonitorDescription =>
      'Ubuzima bw’inzira yo kwakira SMS za MoMo';

  @override
  String get adminFeatureManager => 'Igenzura ry’ibiranga';

  @override
  String get adminFeatureManagerDashboardDescription =>
      'Emerera ibiranga, uko bigaragara n’igihe bikorera';

  @override
  String get adminRecentActivity => 'Ibikorwa biheruka';

  @override
  String get adminRecentActivityUnavailable => 'Ibikorwa biheruka ntibiboneka';

  @override
  String get adminRecentActivityUnavailableMessage =>
      'Imibare y’ikibaho ni mishya. Vugurura kugira ngo wongere ugerageze urutonde rw’ibikorwa.';

  @override
  String get adminNoRecentActivity => 'Nta bikorwa biheruka';

  @override
  String get adminNoRecentActivityMessage =>
      'Imibare iriho yemejwe. Ibikorwa bishya bya klabu bizagaragara hano.';

  @override
  String get adminWorkspaceUnavailable => 'Ahantu h’ubuyobozi ntihaboneka';

  @override
  String get adminMobileDisabledMessage =>
      'Ubuyobozi bwo kuri telefoni bwahagaritswe muri iyi verisiyo igenzurwa.';

  @override
  String get adminBackToSettings => 'Subira mu igenamiterere';

  @override
  String get adminWorkspaceOffline =>
      'Ahantu h’ubuyobozi ntihari kuri interineti';

  @override
  String get adminWorkspaceOfflineMessage =>
      'Ongera uhuze interineti mbere yo kwinjiza ibikorwa byihariye bya klabu.';

  @override
  String get adminAccessUnavailable => 'Uburenganzira bw’ubuyobozi ntibuboneka';

  @override
  String get adminAccessUnavailableMessage =>
      'Iyi konti ntishobora kureba ahantu h’ubuyobozi bwa klabu.';

  @override
  String get adminDataChanged => 'Amakuru y’ubuyobozi yahindutse';

  @override
  String get adminDataChangedMessage =>
      'Vugurura mbere yo gukomeza ibikorwa bya klabu.';

  @override
  String get adminSecurityTimeout => 'Igihe cyo kugenzura umutekano cyarangiye';

  @override
  String get adminSecurityTimeoutMessage =>
      'Nta makuru y’ubuyobozi yerekanwe. Genzura interineti wongere ugerageze.';

  @override
  String get adminPrivateDataHiddenMessage =>
      'Amakuru yihariye ya klabu akomeje guhishwa. Ongera ugerageze.';

  @override
  String get adminRefreshingTitle => 'Ahantu h’ubuyobozi hari kuvugururwa';

  @override
  String get adminRefreshingMessage =>
      'Ikibaho giheruka kwemezwa kiracyagaragara mu gihe amakuru ariho agenzurwa.';

  @override
  String get adminRefreshTimedOut => 'Igihe cyo kuvugurura cyarangiye';

  @override
  String get adminCurrentRefreshUnavailable => 'Kuvugurura ntibiboneka ubu';

  @override
  String get adminLastConfirmedMessage =>
      'Ikibaho giheruka kwemezwa kiracyagaragara. Ibikorwa byahagaze kugeza kuvugurura bikunze.';

  @override
  String get adminAccessRequired => 'Uburenganzira bw’ubuyobozi burasabwa';

  @override
  String get adminAccessRequiredMessage =>
      'Aha hantu ni ah’abayobozi ba klabu bemejwe gusa kuri klabu ikora.';

  @override
  String get adminBack => 'Subira inyuma';

  @override
  String get adminCancelUpper => 'Reka';

  @override
  String get adminBackToAdmin => 'Subira mu buyobozi';

  @override
  String adminVersus(String home, String away) {
    return '$home na $away';
  }

  @override
  String adminMetricSemantic(String label, String value) {
    return '$label $value';
  }

  @override
  String get adminSettlementConfirmTitle => 'Emeza uyu mukino?';

  @override
  String adminSettlementConfirmMessage(
    String home,
    int homeScore,
    int awayScore,
    String away,
  ) {
    return '$home $homeScore – $awayScore $away\n\nIbi bigenzura amasoko y’amahitamo kandi bishobora gutanga ibihembo. Emeza ukoresheje igisubizo cyemewe gusa.';
  }

  @override
  String get adminSettlementSettleUpper => 'Emeza';

  @override
  String adminSettlementReceipt(String score, int markets, int won, int lost) {
    return 'Byemejwe $score • amasoko $markets • $won batsinze • $lost batsinzwe';
  }

  @override
  String get adminSettlementReviewOfficialResult =>
      'Suzuma igisubizo cyemewe wongere ugerageze.';

  @override
  String get adminSettlementNotConfirmed => 'Kwemeza umukino ntibyemejwe.';

  @override
  String get adminSettlementTitle => 'Emeza imikino';

  @override
  String get adminSettlementLoadingTitle => 'Ahantu ho kwemeza hari kwinjizwa';

  @override
  String get adminSettlementLoadingMessage =>
      'Amakuru y’umukino agenzurwa ari kugenzurwa.';

  @override
  String get adminSettlementFilterScheduled => 'Iteganyijwe';

  @override
  String get adminSettlementFilterFinished => 'Yarangiye';

  @override
  String get adminSettlementFilterAll => 'Yose';

  @override
  String get adminSettlementControlTitle => 'Igenzura ry’igisubizo cyemewe';

  @override
  String get adminSettlementControlMessage =>
      'Kwemeza bigenzura amasoko y’amahitamo kandi bishobora gutanga ibihembo. Koresha gusa amanota ya nyuma yemewe.';

  @override
  String get adminSettlementEmptyTitle => 'Nta mikino muri uru rutonde';

  @override
  String get adminSettlementEmptyMessage =>
      'Hindura muyunguruzi cyangwa utegereze amakuru y’umukino agenzurwa.';

  @override
  String get adminSettlementVersusShort => 'Na';

  @override
  String get adminSettlementOpenHint => 'Fungura kwemeza igisubizo cyemewe';

  @override
  String get adminSettlementUnavailableHint => 'Kwemeza ntibiboneka';

  @override
  String get adminSettlementEnterOfficialResult => 'Andika igisubizo cyemewe';

  @override
  String get adminSettlementPaused => 'Kwemeza byahagaze';

  @override
  String get adminSettlementSettled => 'Byemejwe';

  @override
  String get adminSettlementNotSettleable => 'Ntibishobora kwemezwa';

  @override
  String get adminSettlementManagementUnavailable =>
      'Gucunga kwemeza ntibiboneka';

  @override
  String get adminSettlementDisabledMessage =>
      'Igenzura ryo kwemeza ryahagaritswe muri iyi verisiyo igenzurwa.';

  @override
  String get adminSettlementWorkspaceOffline =>
      'Ahantu ho kwemeza ntihari kuri interineti';

  @override
  String get adminSettlementWorkspaceOfflineMessage =>
      'Ongera uhuze interineti mbere yo kwinjiza amakuru yihariye y’umukino.';

  @override
  String get adminSettlementAccessUnavailable =>
      'Uburenganzira bwo kwemeza ntibuboneka';

  @override
  String get adminSettlementAccessUnavailableMessage =>
      'Iyi konti ntishobora kureba cyangwa kwemeza imikino y’amahitamo.';

  @override
  String get adminSettlementResultChanged => 'Igisubizo cy’umukino cyahindutse';

  @override
  String get adminSettlementResultChangedMessage =>
      'Vugurura mbere yo kwemeza undi mukino.';

  @override
  String get adminSettlementSecurityTimeoutMessage =>
      'Nta makuru y’umukino yerekanwe. Genzura interineti.';

  @override
  String get adminSettlementWorkspaceUnavailable =>
      'Ahantu ho kwemeza ntihaboneka';

  @override
  String get adminSettlementPrivateDataHidden =>
      'Amakuru yihariye y’umukino akomeje guhishwa. Ongera ugerageze.';

  @override
  String get adminSettlementCheckingResults =>
      'Ibisubizo by’imikino biri kugenzurwa';

  @override
  String get adminSettlementCheckingResultsMessage =>
      'Imiterere iheruka kwemezwa iracyagaragara mu gihe amakuru ariho agenzurwa.';

  @override
  String get adminSettlementOutcomeUnconfirmed =>
      'Kwemeza guheruka ntibyemejwe. Igenzura rikomeza guhagarara kugeza kuvugurura bikunze.';

  @override
  String get adminSettlementLastConfirmedMessage =>
      'Amakuru y’umukino aheruka kwemezwa aracyagaragara. Igenzura ryahagaze.';

  @override
  String get adminSettlementFinalScoreValidation =>
      'Andika amanota ya nyuma kuva kuri 0 kugeza kuri 99.';

  @override
  String get adminSettlementHalfTimeValidation =>
      'Andika amanota yombi yo mu kiruhuko atarenze amanota ya nyuma.';

  @override
  String get adminSettlementHalfTimeScore => 'Amanota yo mu kiruhuko';

  @override
  String get adminSettlementHideHalfTime =>
      'Hisha imyanya y’amanota yo mu kiruhuko';

  @override
  String get adminSettlementShowHalfTime =>
      'Erekana imyanya y’amanota yo mu kiruhuko';

  @override
  String get adminSettlementHalfTimeOptional =>
      'Amanota yo mu kiruhuko (si ngombwa)';

  @override
  String adminSettlementHalfTimeLabel(String team) {
    return '$team IK';
  }

  @override
  String get adminSettlementReviewAction => 'Suzuma kwemeza';

  @override
  String get adminStatusFinished => 'Yarangiye';

  @override
  String get adminStatusScheduled => 'Iteganyijwe';

  @override
  String get adminStatusLive => 'Imbonankubone';

  @override
  String get adminStatusCancelled => 'Yahagaritswe';

  @override
  String get adminStatusPostponed => 'Yasubitswe';

  @override
  String adminScore(int home, int away) {
    return '$home – $away';
  }

  @override
  String get adminFeatureDetailTitle => 'Ibirambuye by’ikiranga';

  @override
  String get adminFeatureLoadingTitle =>
      'Igenamiterere ry’ikiranga riri kwinjizwa';

  @override
  String get adminFeatureLoadingMessage =>
      'Imiyoboro igenzurwa n’amategeko y’uburenganzira biri kugenzurwa.';

  @override
  String get adminFeatureNotFound => 'Ikiranga nticyabonetse';

  @override
  String get adminFeatureNotFoundMessage =>
      'Nta kiranga cyemejwe gihuye n’iyi nzira igenzurwa.';

  @override
  String get adminBackToFeatures => 'Subira ku biranga';

  @override
  String get adminFeatureGlobalState => 'Imiterere rusange';

  @override
  String adminFeatureDisableTooltip(String feature) {
    return 'Hagarika $feature';
  }

  @override
  String adminFeatureEnableTooltip(String feature) {
    return 'Emerera $feature';
  }

  @override
  String adminFeatureStateSemantic(String feature, String state) {
    return '$feature ni $state';
  }

  @override
  String get adminFeatureChangesGlobalState =>
      'Guhindura imiterere rusange y’ikiranga';

  @override
  String get adminFeatureEnabled => 'Cyemerewe';

  @override
  String get adminFeatureDisabled => 'Cyahagaritswe';

  @override
  String get adminFeatureTapDisable =>
      'Kanda kugira ngo uhagarike iki kiranga hose';

  @override
  String get adminFeatureTapEnable =>
      'Kanda kugira ngo wemerere iki kiranga hose';

  @override
  String get adminFeatureVisibility => 'Uko kigaragara';

  @override
  String get adminFeatureVisibilityVisible => 'Kiragaragara';

  @override
  String get adminFeatureVisibilityHidden => 'Gihishwe';

  @override
  String get adminFeatureVisibilityMaintenance => 'Kiri gusanwa';

  @override
  String get adminFeatureChannelConfig => 'Igenamiterere ry’imiyoboro';

  @override
  String get adminFeatureNoChannelOverrides => 'Nta mpinduka z’umuyoboro';

  @override
  String get adminFeatureNoChannelOverridesMessage =>
      'Iki kiranga gikoresha imiterere rusange yemejwe.';

  @override
  String get adminFeatureScheduling => 'Gahunda';

  @override
  String get adminFeatureAccessRules => 'Amategeko y’uburenganzira';

  @override
  String get adminFeatureAuthRequired => 'Kwinjira birasabwa';

  @override
  String get adminFeatureAuthRequiredMessage =>
      'Abakoresha bagomba kwinjira mbere yo gukoresha iki kiranga.';

  @override
  String get adminFeatureSettingsUnavailable =>
      'Igenamiterere ry’ikiranga ntiriboneka';

  @override
  String get adminFeatureEditingDisabled =>
      'Guhindura ibiranga byahagaritswe muri iyi verisiyo igenzurwa.';

  @override
  String get adminFeatureSettingsOffline =>
      'Igenamiterere ry’ikiranga ntiri kuri interineti';

  @override
  String get adminFeatureSettingsOfflineMessage =>
      'Ongera uhuze interineti mbere yo kwinjiza igenamiterere ryihariye.';

  @override
  String get adminFeatureAccessUnavailable =>
      'Uburenganzira ku kiranga ntibuboneka';

  @override
  String get adminFeatureAccessUnavailableMessage =>
      'Iyi konti ntishobora kureba cyangwa guhindura igenamiterere ry’ikiranga.';

  @override
  String get adminFeatureSettingsChanged =>
      'Igenamiterere ry’ikiranga ryahindutse';

  @override
  String get adminFeatureSettingsChangedMessage =>
      'Vugurura mbere yo gukora indi mpinduka.';

  @override
  String get adminFeatureSecurityTimeoutMessage =>
      'Nta genamiterere ry’ikiranga ryerekanwe. Genzura interineti.';

  @override
  String get adminFeaturePrivateDataHidden =>
      'Igenamiterere ryihariye rikomeje guhishwa. Ongera ugerageze.';

  @override
  String get adminFeatureCheckingTitle =>
      'Igenamiterere ry’ikiranga riri kugenzurwa';

  @override
  String get adminFeatureCheckingMessage =>
      'Imiterere iheruka kwemezwa iracyagaragara mu gihe amakuru ariho agenzurwa.';

  @override
  String get adminFeatureOutcomeUnconfirmed =>
      'Impinduka iheruka ntiremezwa. Igenzura rikomeza guhagarara kugeza kuvugurura bikunze.';

  @override
  String get adminFeatureLastConfirmed =>
      'Igenamiterere riheruka kwemezwa rikomeza kugaragara. Igenzura ryahagaze.';

  @override
  String get adminFeatureChannelMobile => 'Telefoni';

  @override
  String get adminFeatureChannelWeb => 'Urubuga';

  @override
  String get adminFeatureChannelEnabled => 'Cyemerewe';

  @override
  String get adminFeatureChannelEnabledMessage =>
      'Ikiranga gikora kuri uyu muyoboro.';

  @override
  String get adminFeatureChannelVisible => 'Kiragaragara';

  @override
  String get adminFeatureChannelVisibleMessage =>
      'Ikiranga gishobora kugaragara kuri uyu muyoboro.';

  @override
  String get adminFeatureShowInNavigation => 'Erekana mu kugendana';

  @override
  String get adminFeatureShowInNavigationMessage =>
      'Shyira iki kiranga mu kugendana k’umuyoboro.';

  @override
  String get adminFeatureShowOnHome => 'Erekana ahabanza';

  @override
  String get adminFeatureShowOnHomeMessage =>
      'Shyira iki kiranga ku rupapuro rw’ibanze rw’umuyoboro.';

  @override
  String get adminFeatureAvailableFrom => 'Kiboneka kuva';

  @override
  String get adminFeatureAvailableUntil => 'Kiboneka kugeza';

  @override
  String get adminFeatureClearSchedule => 'Siba gahunda';

  @override
  String get adminFeatureNotSet => 'Ntibyashyizweho';

  @override
  String adminFeatureSetTooltip(String label) {
    return 'Shyiraho $label';
  }

  @override
  String adminFeatureDateSemantic(String label, String value) {
    return '$label: $value';
  }

  @override
  String get adminFeatureOpenDateTime => 'Fungura guhitamo itariki n’isaha';

  @override
  String get adminMatchesTitle => 'Imikino';

  @override
  String get adminMatchesLoadingTitle => 'Ahantu h’imikino hari kwinjizwa';

  @override
  String get adminMatchesLoadingMessage =>
      'Amakuru y’imikino agenzurwa ari kugenzurwa.';

  @override
  String get adminMatchesDescription =>
      'Cunga imikino, uko amatike agurishwa, itangwa ry’amatike n’amanota imbonankubone ukoresheje amakuru yemejwe.';

  @override
  String get adminMatchesFixtures => 'Imikino';

  @override
  String get adminMatchesOnSale => 'Iri kugurishwa';

  @override
  String get adminMatchesStatus => 'Imiterere';

  @override
  String get adminMatchesFilterAll => 'Yose';

  @override
  String get adminMatchesFilterLive => 'Imbonankubone';

  @override
  String get adminMatchesFilterUpcoming => 'Iteganyijwe';

  @override
  String get adminMatchesFilterOnSale => 'Iri kugurishwa';

  @override
  String get adminMatchesFilterCompleted => 'Yarangiye';

  @override
  String get adminMatchesNoneConfigured => 'Nta mikino yashyizweho';

  @override
  String get adminMatchesNoneMatch => 'Nta mikino ihuye';

  @override
  String get adminMatchesNoneConfiguredMessage =>
      'Umukino wa klabu wemejwe ugomba kubaho mbere y’uko aha hantu hamenya umufatanyabikorwa.';

  @override
  String get adminMatchesNoneMatchMessage =>
      'Hitamo indi muyunguruzi y’imiterere.';

  @override
  String get adminMatchesCreate => 'Kora umukino';

  @override
  String get adminMatchesCreationPaused =>
      'Gukora umukino byahagaze kugeza umufatanyabikorwa wemejwe abonetse.';

  @override
  String get adminMatchesCreated => 'Umukino wakozwe neza.';

  @override
  String get adminMatchesUpdated => 'Umukino wavuguruwe neza.';

  @override
  String get adminMatchesManagementUnavailable => 'Gucunga imikino ntibiboneka';

  @override
  String get adminMatchesDisabledMessage =>
      'Igenzura ry’imikino ryahagaritswe muri iyi verisiyo igenzurwa.';

  @override
  String get adminMatchesWorkspaceOffline =>
      'Ahantu h’imikino ntihari kuri interineti';

  @override
  String get adminMatchesWorkspaceOfflineMessage =>
      'Ongera uhuze interineti mbere yo kwinjiza amakuru yihariye y’imikino.';

  @override
  String get adminMatchesAccessUnavailable =>
      'Uburenganzira ku mikino ntibuboneka';

  @override
  String get adminMatchesAccessUnavailableMessage =>
      'Iyi konti ntishobora kureba cyangwa guhindura amakuru y’imikino.';

  @override
  String get adminMatchesInformationChanged => 'Amakuru y’umukino yahindutse';

  @override
  String get adminMatchesInformationChangedMessage =>
      'Vugurura mbere yo gukora indi mpinduka y’umukino.';

  @override
  String get adminMatchesSecurityTimeoutMessage =>
      'Nta makuru y’umukino yerekanwe. Genzura interineti.';

  @override
  String get adminMatchesWorkspaceUnavailable => 'Ahantu h’imikino ntihaboneka';

  @override
  String get adminMatchesPrivateDataHidden =>
      'Amakuru yihariye y’umukino akomeje guhishwa. Ongera ugerageze.';

  @override
  String get adminMatchesCheckingTitle => 'Amakuru y’umukino ari kugenzurwa';

  @override
  String get adminMatchesCheckingMessage =>
      'Imiterere iheruka kwemezwa iracyagaragara mu gihe amakuru ariho agenzurwa.';

  @override
  String get adminMatchesOutcomeUnconfirmed =>
      'Impinduka iheruka ntiremezwa. Igenzura rikomeza guhagarara kugeza kuvugurura bikunze.';

  @override
  String get adminMatchesLastConfirmed =>
      'Amakuru y’umukino aheruka kwemezwa aracyagaragara. Igenzura ryahagaze.';

  @override
  String adminMatchesOpenTooltip(String home, String away) {
    return 'Fungura $home na $away';
  }

  @override
  String adminMatchesFixtureSemantic(String home, String away) {
    return 'Umukino wa $home na $away';
  }

  @override
  String get adminMatchesOpenHint =>
      'Fungura igenamiterere ry’umukino rigenzurwa';

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
    return 'Rusange $symbol $general • VIP $symbol $vip';
  }

  @override
  String adminMatchesScore(int home, int away, String minute) {
    return 'Amanota $home-$away$minute';
  }

  @override
  String adminMatchesAllocation(int percent, int sold, int capacity) {
    return '$percent% byatanzwe • amatike $sold / $capacity';
  }

  @override
  String get adminMatchesEditOnSale => 'Hindura umukino uri kugurishwa';

  @override
  String get adminMatchesEdit => 'Hindura umukino';

  @override
  String get adminStatusHalfTime => 'Ikiruhuko';

  @override
  String get adminStatusFullTime => 'Warangiye';

  @override
  String get adminStatusUpcoming => 'Uteganyijwe';

  @override
  String adminMatchesLiveMinute(int minute) {
    return ' • umunota $minute';
  }

  @override
  String get adminMatchSaveNotConfirmed =>
      'Umukino ntiwabitswe. Suzuma imiterere yemejwe y’ahantu h’imirimo.';

  @override
  String get adminMatchReviewFields =>
      'Suzuma imyanya yose y’umukino kandi wandike agaciro kaboneye.';

  @override
  String get adminMatchSaveFailedRefresh =>
      'Umukino ntiwabitswe. Vugurura wongere ugerageze.';

  @override
  String get adminMatchCreateTitle => 'Kora umukino';

  @override
  String get adminMatchUpdateTitle => 'Vugurura umukino';

  @override
  String get adminMatchHomeTeam => 'Ikipe yo mu rugo';

  @override
  String get adminMatchAwayTeam => 'Ikipe y’umushyitsi';

  @override
  String get adminMatchCompetition => 'Irushanwa';

  @override
  String get adminMatchVenue => 'Ahabera umukino';

  @override
  String adminMatchGeneralPrice(String symbol) {
    return 'Rusange $symbol';
  }

  @override
  String adminMatchVipPrice(String symbol) {
    return 'VIP $symbol';
  }

  @override
  String get adminMatchCapacity => 'Ubushobozi';

  @override
  String get adminMatchTicketsOnSale => 'Amatike ari kugurishwa';

  @override
  String get adminMatchStatus => 'Imiterere y’umukino';

  @override
  String get adminMatchStatusScheduled => 'Uteganyijwe';

  @override
  String get adminMatchStatusLive => 'Imbonankubone';

  @override
  String get adminMatchStatusHalfTime => 'Ikiruhuko';

  @override
  String get adminMatchStatusFullTime => 'Warangiye';

  @override
  String get adminMatchStatusPostponed => 'Wasubitswe';

  @override
  String get adminMatchStatusCancelled => 'Wahagaritswe';

  @override
  String get adminMatchHomeScore => 'Amanota yo mu rugo';

  @override
  String get adminMatchAwayScore => 'Amanota y’umushyitsi';

  @override
  String get adminMatchLiveMinute => 'Umunota w’umukino';

  @override
  String get adminMatchSummary => 'Incamake y’umukino / amakuru imbonankubone';

  @override
  String get adminMatchSave => 'Bika umukino';

  @override
  String get adminMatchUpdate => 'Vugurura umukino';

  @override
  String get adminFeatureManagerTitle => 'Igenzura ry’ibiranga';

  @override
  String get adminFeatureRegistryLoading =>
      'Urutonde rw’ibiranga ruri kwinjizwa';

  @override
  String get adminFeatureRegistryLoadingMessage =>
      'Igenamiterere ry’ibiranga rigenzurwa riri kugenzurwa.';

  @override
  String get adminFeatureManagerDescription =>
      'Cunga uko ibiranga bya klabu biboneka ukoresheje igenamiterere ryemejwe kandi rigarukira.';

  @override
  String get adminFeatureRegistered => 'Byanditswe';

  @override
  String get adminFeatureEnabledUpper => 'Byemewe';

  @override
  String get adminFeatureDisabledUpper => 'Byahagaritswe';

  @override
  String get adminFeatureStatus => 'Imiterere';

  @override
  String get adminFeatureFilterAll => 'Byose';

  @override
  String get adminFeatureNoneConfigured => 'Nta biranga byashyizweho';

  @override
  String get adminFeatureNoneMatch => 'Nta biranga bihuye';

  @override
  String get adminFeatureNoneConfiguredMessage =>
      'Igenamiterere ry’ibiranga ryemejwe rizagaragara hano.';

  @override
  String get adminFeatureNoneMatchMessage =>
      'Hitamo indi muyunguruzi y’imiterere.';

  @override
  String get adminFeatureManagementUnavailable =>
      'Gucunga ibiranga ntibiboneka';

  @override
  String get adminFeatureControlsDisabled =>
      'Igenzura ry’ibiranga ryahagaritswe muri iyi verisiyo igenzurwa.';

  @override
  String get adminFeatureRegistryOffline =>
      'Urutonde rw’ibiranga ntiruri kuri interineti';

  @override
  String get adminFeatureConfigurationAccessMessage =>
      'Iyi konti ntishobora kureba cyangwa guhindura igenamiterere ry’ibiranga.';

  @override
  String get adminFeatureConfigurationChanged =>
      'Igenamiterere ry’ibiranga ryahindutse';

  @override
  String get adminFeatureConfigurationChangedMessage =>
      'Vugurura mbere yo gukora indi mpinduka.';

  @override
  String get adminFeatureConfigurationSecurityMessage =>
      'Nta genamiterere ry’ibiranga ryerekanwe. Genzura interineti.';

  @override
  String get adminFeatureRegistryUnavailable =>
      'Urutonde rw’ibiranga ntiruboneka';

  @override
  String get adminFeatureConfigurationHidden =>
      'Igenamiterere ryihariye rikomeje guhishwa. Ongera ugerageze.';

  @override
  String get adminFeatureConfigurationChecking =>
      'Igenamiterere ry’ibiranga riri kugenzurwa';

  @override
  String get adminFeatureConfigurationLastConfirmed =>
      'Igenamiterere riheruka kwemezwa ruracyagaragara. Igenzura ryahagaze.';

  @override
  String adminFeatureOpenTooltip(String feature) {
    return 'Fungura $feature';
  }

  @override
  String adminFeatureSettingsSemantic(String feature) {
    return 'Igenamiterere ry’ikiranga $feature';
  }

  @override
  String get adminFeatureOpenSettingsHint =>
      'Fungura igenamiterere ry’ikiranga rigenzurwa';

  @override
  String adminFeatureChangeVisibilityTooltip(String feature) {
    return 'Hindura uko $feature kigaragara';
  }

  @override
  String get adminFeatureChangeVisibility => 'Hindura uko kigaragara';

  @override
  String get adminCompetitionsTitle => 'Amarushanwa';

  @override
  String get adminCompetitionsAdd => 'Ongeraho irushanwa';

  @override
  String get adminCompetitionsActionsUnavailable =>
      'Ibikorwa by’amarushanwa ntibiboneka';

  @override
  String get adminCompetitionsLoading => 'Amarushanwa ari kwinjizwa';

  @override
  String get adminCompetitionsLoadingMessage =>
      'Ahagenzurirwa amarushanwa hari kugenzurwa.';

  @override
  String get adminCompetitionsDescription =>
      'Genzura amarushanwa n’ibihembwe bikoreshwa mu guhanura.';

  @override
  String get adminCompetitionsNoneConfigured => 'Nta marushanwa yagenwe';

  @override
  String get adminCompetitionsNoneMatch => 'Nta marushanwa ahuye';

  @override
  String get adminCompetitionsNoneConfiguredMessage =>
      'Shyiraho irushanwa rya mbere igihe uburenganzira buboneka.';

  @override
  String get adminCompetitionsNoneMatchMessage =>
      'Hitamo akandi karere cyangwa ubwoko bw’irushanwa.';

  @override
  String get adminCompetitionsManagementUnavailable =>
      'Kugenzura amarushanwa ntibiboneka';

  @override
  String get adminCompetitionsControlsDisabled =>
      'Igenzura ry’amarushanwa ryahagaritswe muri iyi verisiyo igenzurwa.';

  @override
  String get adminCompetitionsOffline =>
      'Ahagenzurirwa amarushanwa ntihari kuri interineti';

  @override
  String get adminCompetitionsOfflineMessage =>
      'Ongera uhuze interineti mbere yo kwinjiza amakuru yihariye y’amarushanwa.';

  @override
  String get adminCompetitionsAccessUnavailable =>
      'Uburenganzira ku marushanwa ntibuboneka';

  @override
  String get adminCompetitionsAccessMessage =>
      'Iyi konti ntishobora kureba cyangwa guhindura igenamiterere ry’amarushanwa.';

  @override
  String get adminCompetitionsDataChanged => 'Amakuru y’irushanwa yahindutse';

  @override
  String get adminCompetitionsDataChangedMessage =>
      'Vugurura mbere yo gukomeza imirimo y’amarushanwa.';

  @override
  String get adminCompetitionsSecurityMessage =>
      'Nta makuru y’irushanwa yagaragajwe. Genzura interineti.';

  @override
  String get adminCompetitionsWorkspaceUnavailable =>
      'Ahagenzurirwa amarushanwa ntihaboneka';

  @override
  String get adminCompetitionsHiddenMessage =>
      'Amakuru yihariye y’amarushanwa akomeje guhishwa. Ongera ugerageze.';

  @override
  String get adminCompetitionsUpdating =>
      'Ahagenzurirwa amarushanwa hari kuvugururwa';

  @override
  String get adminCompetitionsUpdatingMessage =>
      'Igenzura ryahagaze kugeza igisubizo cyemejwe.';

  @override
  String get adminCompetitionsRefreshing => 'Amarushanwa ari kuvugururwa';

  @override
  String get adminCompetitionsRefreshingMessage =>
      'Amakuru aheruka kwemezwa aracyagaragara mu gihe hari kugenzurwa.';

  @override
  String get adminCompetitionsCurrentRefreshUnavailable =>
      'Kuvugurura ubu ntibishoboka';

  @override
  String get adminCompetitionsOutcomeUnconfirmed =>
      'Igisubizo cy’ivugurura ntikiramenyekana. Vugurura mbere y’ikindi gikorwa.';

  @override
  String get adminCompetitionsLastConfirmed =>
      'Amakuru aheruka kwemezwa aragaragara. Ibikorwa byahagaze kugeza ivugurura rishobotse.';

  @override
  String get adminCompetitionCreated => 'Irushanwa ryakozwe';

  @override
  String get adminCompetitionUpdated => 'Irushanwa ryavuguruwe';

  @override
  String get adminCompetitionActivateQuestion => 'Irushanwa rikoreshe?';

  @override
  String get adminCompetitionDeactivateQuestion => 'Irushanwa rihagarare?';

  @override
  String adminCompetitionActivateMessage(String competition) {
    return '$competition rizaboneka mu nzira zateguwe zo guhanura.';
  }

  @override
  String adminCompetitionDeactivateMessage(String competition) {
    return '$competition ntirizongera kuboneka mu nzira zateguwe zo guhanura.';
  }

  @override
  String get adminActivateUpper => 'Kora';

  @override
  String get adminDeactivateUpper => 'Hagarika';

  @override
  String get adminCompetitionActivated => 'Irushanwa ryatangiye gukoreshwa';

  @override
  String get adminCompetitionDeactivated => 'Irushanwa ryahagaritswe';

  @override
  String get adminCompetitionsTotal => 'Yose';

  @override
  String get adminCompetitionsActive => 'Akora';

  @override
  String get adminCompetitionsInactive => 'Ntakora';

  @override
  String get adminCompetitionFilters => 'Muyungurura w’amarushanwa';

  @override
  String get adminCompetitionRegion => 'Akarere';

  @override
  String get adminCompetitionKind => 'Ubwoko';

  @override
  String get adminCompetitionSeasons => 'Ibihembwe';

  @override
  String get adminEditUpper => 'Hindura';

  @override
  String get adminCompetitionFilterAll => 'Yose';

  @override
  String get adminCompetitionRegionAfrica => 'Afurika';

  @override
  String get adminCompetitionRegionEurope => 'Uburayi';

  @override
  String get adminCompetitionRegionInternational => 'Mpuzamahanga';

  @override
  String get adminCompetitionRegionGlobal => 'Isi yose';

  @override
  String get adminCompetitionKindLeague => 'Shampiyona';

  @override
  String get adminCompetitionKindCup => 'Igikombe';

  @override
  String get adminCompetitionKindTournament => 'Irushanwa';

  @override
  String get adminCompetitionEdit => 'Hindura irushanwa';

  @override
  String get adminCompetitionAdd => 'Ongeraho irushanwa';

  @override
  String get adminCompetitionName => 'Izina';

  @override
  String get adminCompetitionShortName => 'Izina rigufi';

  @override
  String get adminCompetitionSlug => 'Ikiranga';

  @override
  String get adminCompetitionSlugHint => 'urugero: shampiyona-y-igihugu';

  @override
  String get adminCompetitionOrganizer => 'Utegura';

  @override
  String get adminOptional => 'Si ngombwa';

  @override
  String get adminCompetitionCountryCode => 'Kode y’igihugu';

  @override
  String get adminCompetitionCountryCodeHint => 'Rw';

  @override
  String get adminCompetitionCountryName => 'Izina ry’igihugu';

  @override
  String get adminCompetitionCountryNameHint => 'Rwanda';

  @override
  String get adminCompetitionFormatNotes => 'Ibisobanuro by’imiterere';

  @override
  String get adminCompetitionValidationMessage =>
      'Genzura amazina asabwa, ikiranga na kode y’igihugu.';

  @override
  String get adminCompetitionAvailable =>
      'Riboneka mu nzira zateguwe zo guhanura';

  @override
  String get adminCompetitionUnavailable => 'Ntiriboneka mu nzira zo guhanura';

  @override
  String get adminSaveChanges => 'Bika impinduka';

  @override
  String get adminCreateCompetition => 'Kora irushanwa';

  @override
  String get adminSeasonAdd => 'Ongeraho igihembwe';

  @override
  String get adminSeasonActionsUnavailable =>
      'Ibikorwa by’igihembwe ntibiboneka';

  @override
  String get adminSeasonNoneConfigured => 'Nta bihembwe byagenwe';

  @override
  String get adminSeasonNoneConfiguredMessage =>
      'Ongeraho igihembwe cya mbere igihe uburenganzira buboneka.';

  @override
  String get adminSeasonCreated => 'Igihembwe cyakozwe';

  @override
  String get adminSeasonActivateQuestion => 'Igihembwe gikoreshe?';

  @override
  String get adminSeasonDeactivateQuestion => 'Igihembwe gihagarare?';

  @override
  String adminSeasonAvailabilityMessage(String season, String availability) {
    return '$season kizaba $availability mu nzira zateguwe z’amarushanwa.';
  }

  @override
  String get adminAvailable => 'kiboneka';

  @override
  String get adminUnavailable => 'kitaboneka';

  @override
  String get adminSeasonActivated => 'Igihembwe cyatangiye gukoreshwa';

  @override
  String get adminSeasonDeactivated => 'Igihembwe cyahagaritswe';

  @override
  String get adminSeasonActivate => 'Koresha igihembwe';

  @override
  String get adminSeasonDeactivate => 'Hagarika igihembwe';

  @override
  String get adminSeasonValidationMessage =>
      'Genzura ikiranga, izina n’imyaka by’igihembwe.';

  @override
  String get adminSeasonAddUpper => 'Ongeraho igihembwe';

  @override
  String get adminSeasonSlugHint => 'urugero: shampiyona-2026';

  @override
  String get adminSeasonLabel => 'Izina';

  @override
  String get adminSeasonLabelHint => 'urugero: 2025/2026';

  @override
  String get adminSeasonYearStart => 'Umwaka wo gutangira';

  @override
  String get adminSeasonYearEnd => 'Umwaka wo kurangira';

  @override
  String get adminCreateUpper => 'Kora';

  @override
  String get adminSeasonStatusPlanned => 'Cyateguwe';

  @override
  String get adminSeasonStatusActive => 'Gikora';

  @override
  String get adminSeasonStatusFinished => 'Cyarangiye';

  @override
  String get adminSeasonStatusArchived => 'Cyabitswe';

  @override
  String get adminNotificationSendTitle => 'Ohereza ubutumwa';

  @override
  String get adminNotificationLoading =>
      'Ahagenzurirwa ubutumwa hari kwinjizwa';

  @override
  String get adminNotificationLoadingMessage =>
      'Amakuru agenzurwa y’iyohereza ari kugenzurwa.';

  @override
  String get adminNotificationDeliveryStatus => 'Uko byoherejwe';

  @override
  String get adminNotificationDeliveryStatusMessage =>
      'Ubutumwa bwoherezwa na Edge Functions. Ubwateguwe bwoherezwa ku gihe.';

  @override
  String get adminNotificationAudience => 'Abakira';

  @override
  String get adminNotificationAudienceAllFans => 'Abafana bose';

  @override
  String get adminNotificationAudienceByTier => 'Ku rwego';

  @override
  String get adminNotificationAudienceByGroup => 'Ku itsinda';

  @override
  String get adminNotificationTierFan => 'Umufana';

  @override
  String get adminNotificationTierBronze => 'Umuringa';

  @override
  String get adminNotificationTierGold => 'Zahabu';

  @override
  String get adminNotificationTierPlatinum => 'Platinum';

  @override
  String get adminNotificationSelectGroup => 'Hitamo itsinda';

  @override
  String get adminNotificationTitleLabel => 'Umutwe w’ubutumwa';

  @override
  String get adminNotificationBodyLabel => 'Ubutumwa';

  @override
  String adminNotificationCharacterCount(int count) {
    return 'Inyuguti $count';
  }

  @override
  String get adminNotificationImageUrl => 'URL y’ishusho si ngombwa';

  @override
  String get adminNotificationSchedule => 'Teganya';

  @override
  String get adminNotificationSendNow => 'Ohereza nonaha';

  @override
  String get adminNotificationPickDateTime => 'Hitamo itariki n’isaha';

  @override
  String get adminNotificationScheduleAction => 'Teganya ubutumwa';

  @override
  String get adminNotificationSendAction => 'Ohereza ubutumwa';

  @override
  String get adminNotificationCopyPayload => 'Koporora amakuru';

  @override
  String get adminNotificationSendHistory => 'Amateka y’iyohereza';

  @override
  String get adminNotificationHistoryEmpty => 'Nta mateka y’ubutumwa';

  @override
  String get adminNotificationHistoryEmptyMessage =>
      'Amakuru yemejwe y’iyohereza azagaragara hano nyuma y’ubusabe.';

  @override
  String get adminNotificationManagementUnavailable =>
      'Kugenzura ubutumwa ntibiboneka';

  @override
  String get adminNotificationControlsDisabled =>
      'Igenzura ry’ubutumwa ryahagaritswe muri iyi verisiyo igenzurwa.';

  @override
  String get adminNotificationWorkspaceOffline =>
      'Ahagenzurirwa ubutumwa ntihari kuri interineti';

  @override
  String get adminNotificationOfflineMessage =>
      'Ongera uhuze interineti mbere yo kwinjiza amakuru yihariye y’iyohereza.';

  @override
  String get adminNotificationAccessUnavailable =>
      'Uburenganzira ku butumwa ntibuboneka';

  @override
  String get adminNotificationAccessMessage =>
      'Iyi konti ntishobora kureba cyangwa kohereza ubutumwa.';

  @override
  String get adminNotificationDataChanged => 'Amakuru y’iyohereza yahindutse';

  @override
  String get adminNotificationDataChangedMessage =>
      'Vugurura mbere y’ubundi busabe bw’ubutumwa.';

  @override
  String get adminNotificationSecurityMessage =>
      'Nta makuru y’iyohereza yagaragajwe. Genzura interineti.';

  @override
  String get adminNotificationWorkspaceUnavailable =>
      'Ahagenzurirwa ubutumwa ntihaboneka';

  @override
  String get adminNotificationHiddenMessage =>
      'Amakuru yihariye y’iyohereza akomeje guhishwa. Ongera ugerageze.';

  @override
  String get adminNotificationChecking => 'Amakuru y’iyohereza ari kugenzurwa';

  @override
  String get adminNotificationCheckingMessage =>
      'Amakuru aheruka kwemezwa aracyagaragara mu gihe hari kugenzurwa.';

  @override
  String get adminNotificationOutcomeUnconfirmed =>
      'Ubusabe buheruka ntiburamenyekana. Igenzura rirahagaze kugeza ivugurura rishobotse.';

  @override
  String get adminNotificationLastConfirmed =>
      'Amakuru aheruka kwemezwa aracyagaragara. Igenzura ryahagaze.';

  @override
  String get adminNotificationValidationTitleBody =>
      'Banza wongeremo umutwe n’ubutumwa.';

  @override
  String get adminNotificationValidationTier =>
      'Banza uhitemo urwego rugenewe.';

  @override
  String get adminNotificationValidationGroup =>
      'Banza uhitemo itsinda rigenewe.';

  @override
  String get adminNotificationValidationSchedule =>
      'Banza uhitemo itariki n’isaha yo kohereza.';

  @override
  String get adminNotificationQueued =>
      'Ubutumwa bwashyizwe ku murongo wo koherezwa ku gihe.';

  @override
  String adminNotificationScheduledFor(String date) {
    return 'Ubutumwa bwateganyijwe $date.';
  }

  @override
  String adminNotificationSentSummary(int requested, int sent) {
    return 'Byoherejwe ku bafana $requested. $sent babwakiriye.';
  }

  @override
  String adminNotificationPartialSummary(int sent, int failed) {
    return 'Bimwe: $sent byageze, $failed byanze.';
  }

  @override
  String get adminNotificationDeliveryFailed => 'Kohereza ubutumwa byanze.';

  @override
  String get adminNotificationRequestRecorded =>
      'Ubusabe bw’ubutumwa bwanditswe.';

  @override
  String adminNotificationHistoryMetrics(int requested, int sent, int failed) {
    return ' • Abagenewe $requested • Byoherejwe $sent • Byanze $failed';
  }

  @override
  String get adminNotificationFieldsInvalid =>
      'Genzura imyanya y’ubutumwa wongere ugerageze.';

  @override
  String get adminNotificationRequestUnconfirmed =>
      'Ubusabe bw’ubutumwa ntibwemejwe.';

  @override
  String get adminNotificationPayloadCopied => 'Amakuru yakoporowe.';

  @override
  String get adminNotificationTierNotSelected => 'Nta rwego rwahiswemo';

  @override
  String adminNotificationTierPreview(String tier) {
    return 'Urwego • $tier';
  }

  @override
  String get adminNotificationGroupNotSelected => 'Nta tsinda ryahiswemo';

  @override
  String adminNotificationGroupPreview(String group) {
    return 'Itsinda • $group';
  }

  @override
  String get adminNotificationAllSupporters => 'Abafana bose';

  @override
  String get adminNotificationPreview => 'Uko bizagaragara';

  @override
  String get adminNotificationPreviewBody =>
      'Uko ubutumwa buzagaragara biri hano.';

  @override
  String get adminNotificationStatusScheduled => 'Bwateganyijwe';

  @override
  String get adminNotificationStatusSent => 'Bwoherejwe';

  @override
  String get adminNotificationStatusPartial => 'Bwageze kuri bamwe';

  @override
  String get adminNotificationStatusFailed => 'Bwanze';

  @override
  String get adminContributionsTitle => 'Imisanzu';

  @override
  String get adminContributionsLoading => 'Imisanzu iri kwinjizwa';

  @override
  String get adminContributionsLoadingMessage =>
      'Ahagenzurirwa imisanzu hari kugenzurwa.';

  @override
  String get adminContributionsDescription =>
      'Reba igiteranyo cy’amatsinda ya klabu utagaragaje ibiranga abafana cyangwa ubwishyu.';

  @override
  String get adminContributionsMonthlyTotal =>
      'Igiteranyo cyanditswe uku kwezi';

  @override
  String adminContributionsSummary(int groups, int records) {
    return 'Amatsinda $groups • Inyandiko zigenzuwe $records';
  }

  @override
  String get adminContributionsNoGroups => 'Nta matsinda y’imisanzu';

  @override
  String get adminContributionsNoMatch => 'Nta matsinda ahuye';

  @override
  String get adminContributionsNoGroupsMessage =>
      'Amatsinda y’imisanzu ya klabu yemejwe azagaragara hano.';

  @override
  String get adminContributionsNoMatchMessage =>
      'Hitamo undi muyungurura w’amatsinda y’imisanzu.';

  @override
  String get adminContributionsExport => 'Sohora raporo irinda amakuru bwite';

  @override
  String get adminContributionsReportCopied =>
      'Raporo y’imisanzu irinda amakuru bwite yakoporowe.';

  @override
  String get adminContributionsUnavailable =>
      'Ahagenzurirwa imisanzu ntihaboneka';

  @override
  String get adminContributionsDisabled =>
      'Kugenzura imisanzu byahagaritswe muri iyi verisiyo igenzurwa.';

  @override
  String get adminContributionsOffline =>
      'Ahagenzurirwa imisanzu ntihari kuri interineti';

  @override
  String get adminContributionsOfflineMessage =>
      'Ongera uhuze interineti mbere yo kwinjiza amakuru yihariye y’imisanzu.';

  @override
  String get adminContributionsAccessUnavailable =>
      'Uburenganzira ku misanzu ntibuboneka';

  @override
  String get adminContributionsAccessMessage =>
      'Iyi konti ntishobora kureba ibikorwa byihariye by’imisanzu.';

  @override
  String get adminContributionsDataChanged => 'Amakuru y’imisanzu yahindutse';

  @override
  String get adminContributionsDataChangedMessage =>
      'Vugurura mbere yo kwishingikiriza ku giteranyo cy’imisanzu.';

  @override
  String get adminContributionsSecurityMessage =>
      'Nta makuru y’imisanzu yagaragajwe. Genzura interineti.';

  @override
  String get adminContributionsHiddenMessage =>
      'Amakuru yihariye y’imisanzu akomeje guhishwa. Ongera ugerageze.';

  @override
  String get adminContributionsRefreshing => 'Imisanzu iri kuvugururwa';

  @override
  String get adminContributionsRefreshingMessage =>
      'Ibiteranyo biheruka kwemezwa biracyagaragara mu gihe hari kugenzurwa.';

  @override
  String get adminContributionsLastConfirmed =>
      'Ibiteranyo biheruka kwemezwa biracyagaragara. Igenzura ryahagaze kugeza ivugurura rishobotse.';

  @override
  String get adminContributionsGroupType => 'Ubwoko bw’itsinda';

  @override
  String get adminContributionsSort => 'Tondeka';

  @override
  String get adminContributionsFilterAll => 'Yose';

  @override
  String get adminContributionsTeamProjects => 'Imishinga y’itsinda';

  @override
  String get adminContributionsCommunity => 'Umuryango';

  @override
  String get adminContributionsRecent => 'Ibya vuba';

  @override
  String get adminContributionsTotal => 'Igiteranyo';

  @override
  String get adminContributionsClosed => 'Ryafunzwe';

  @override
  String get adminContributionsActive => 'Rikora';

  @override
  String get adminContributionsTeamProject => 'Umushinga w’itsinda';

  @override
  String adminContributionsRecordMembers(int records, int members) {
    return 'Inyandiko zigenzuwe $records • Abanyamuryango banditswe $members';
  }

  @override
  String get adminContributionsActivityPending =>
      'Igikorwa cy’ubwishyu kirategerejwe';

  @override
  String adminContributionsLastActivity(String date) {
    return 'Igikorwa giheruka $date';
  }

  @override
  String get adminSmsTitle => 'Ibikorwa bya SMS';

  @override
  String get adminSmsLoading => 'Ibikorwa bya SMS biri kwinjizwa';

  @override
  String get adminSmsLoadingMessage =>
      'Amakuru agenzurwa y’imikorere y’inzira ari kugenzurwa.';

  @override
  String get adminSmsNoHistory => 'Nta mateka y’ibikorwa bya SMS';

  @override
  String get adminSmsNoHistoryMessage =>
      'Nta bimenyetso by’imikorere cyangwa iyoherezanya ryagenzuwe biraboneka.';

  @override
  String get adminSmsControlledHealth => 'Imikorere igenzurwa';

  @override
  String get adminSmsControlledHealthMessage =>
      'Reba iyoherezanya ry’ibikoresho, igenzura ry’ubutumwa, guhuza imisanzu, ihinduka ry’abohereza, kongera kugerageza no gusukura amakuru bwite utagaragaje ubutumwa cyangwa ibiranga abafana.';

  @override
  String get adminSmsPipelineHealth => 'Imikorere y’inzira';

  @override
  String get adminSmsRecentSync => 'Iyoherezanya rya vuba ry’ibikoresho';

  @override
  String get adminSmsNoRecentRuns => 'Nta yoherezanya rya vuba';

  @override
  String get adminSmsNoRecentRunsMessage =>
      'Incamake y’imikorere iracyaboneka hejuru.';

  @override
  String adminSmsMetricSemantics(String label, String status) {
    return '$label, $status';
  }

  @override
  String get adminSmsCollapseDetails => 'Hisha ibisobanuro by’imikorere';

  @override
  String get adminSmsExpandDetails => 'Garagaza ibisobanuro by’imikorere';

  @override
  String adminSmsLastSignal(String date) {
    return 'Ikimenyetso giheruka kwemezwa $date';
  }

  @override
  String get adminSmsUnavailable => 'Ibikorwa bya SMS ntibiboneka';

  @override
  String get adminSmsDisabled =>
      'Kugenzura ibikorwa bya SMS byahagaritswe muri iyi verisiyo.';

  @override
  String get adminSmsOffline => 'Ibikorwa bya SMS ntibiri kuri interineti';

  @override
  String get adminSmsOfflineMessage =>
      'Ongera uhuze interineti mbere yo kwinjiza amakuru yihariye y’ibikorwa.';

  @override
  String get adminSmsAccessUnavailable =>
      'Uburenganzira ku bikorwa bya SMS ntibuboneka';

  @override
  String get adminSmsAccessMessage =>
      'Uburenganzira bw’umuyobozi wa pulatifomu burakenewe.';

  @override
  String get adminSmsChanged => 'Ibikorwa bya SMS byahindutse';

  @override
  String get adminSmsChangedMessage =>
      'Vugurura mbere yo gukoresha aya makuru y’ibikorwa.';

  @override
  String get adminSmsSecurityMessage =>
      'Nta makuru y’ibikorwa yagaragajwe. Genzura interineti.';

  @override
  String get adminSmsHiddenMessage =>
      'Amakuru yihariye y’ibikorwa akomeje guhishwa. Ongera ugerageze.';

  @override
  String get adminSmsChecking => 'Ibikorwa bya SMS biri kugenzurwa';

  @override
  String get adminSmsCheckingMessage =>
      'Amakuru aheruka kwemezwa aracyagaragara mu gihe hari kugenzurwa.';

  @override
  String get adminSmsLastConfirmed =>
      'Amakuru y’ibikorwa aheruka kwemezwa aracyagaragara. Igenzura ryahagaze.';

  @override
  String get adminSmsStatusHealthy => 'Birakora neza';

  @override
  String get adminSmsStatusSucceeded => 'Byagenze neza';

  @override
  String get adminSmsStatusDegraded => 'Biragabanyirijwe';

  @override
  String get adminSmsStatusRunning => 'Biri gukora';

  @override
  String get adminSmsStatusRateLimited => 'Umuvuduko wagabanyijwe';

  @override
  String get adminSmsStatusFailing => 'Biri kwanga';

  @override
  String get adminSmsStatusFailed => 'Byanze';

  @override
  String get adminSmsTriggerInitial => 'Amateka ya mbere';

  @override
  String get adminSmsTriggerManual => 'Byakozwe n’umuntu';

  @override
  String get adminSmsTriggerControlled => 'Bigenzurwa';

  @override
  String adminSmsRunTitle(String status, String trigger) {
    return '$status • $trigger';
  }

  @override
  String adminSmsRunMetrics(int scanned, int uploaded, int duplicates) {
    return 'Byagenzuwe $scanned • Byoherejwe $uploaded • Ibisubiramo $duplicates';
  }

  @override
  String get adminCmsTitle => 'Ahagenzurirwa ibirimo';

  @override
  String get adminCmsDescription =>
      'Genzura ibikorwa byihuse byo ku ntangiriro, urutonde rw’abafatanyabikorwa n’amarushanwa yo guhanura yemewe.';

  @override
  String get adminCmsLoading => 'Ahagenzurirwa ibirimo hari kwinjizwa';

  @override
  String get adminCmsLoadingMessage =>
      'Imirimo iriho yo gutangaza iri kugenzurwa.';

  @override
  String get adminCmsNoContent => 'Nta birimo bigenzurwa';

  @override
  String get adminCmsNoContentMessage =>
      'Hitamo igice ukore ikintu cya mbere kigenzurwa.';

  @override
  String get adminCmsUnavailable => 'Ahagenzurirwa ibirimo ntihaboneka';

  @override
  String get adminCmsDisabled =>
      'Igenzura ryo gutangaza ryahagaritswe muri iyi verisiyo igenzurwa.';

  @override
  String get adminCmsOffline => 'Ahagenzurirwa ibirimo ntihari kuri interineti';

  @override
  String get adminCmsOfflineMessage =>
      'Ongera uhuze interineti mbere yo kwinjiza igenzura ryihariye ryo gutangaza.';

  @override
  String get adminCmsAccessUnavailable => 'Uburenganzira ku birimo ntibuboneka';

  @override
  String get adminCmsAccessMessage =>
      'Iyi konti ntishobora kureba cyangwa guhindura amakuru ya klabu yo gutangaza.';

  @override
  String get adminCmsChanged => 'Ibirimo byahindutse';

  @override
  String get adminCmsChangedMessage =>
      'Vugurura ahakorera mbere y’indi mpinduka.';

  @override
  String get adminCmsSecurityMessage =>
      'Nta birimo byihariye byagaragajwe. Genzura interineti wongere ugerageze.';

  @override
  String get adminCmsHiddenMessage =>
      'Amakuru yihariye yo gutangaza akomeje guhishwa. Ongera ugerageze.';

  @override
  String get adminCmsSaving => 'Ibirimo biri kubikwa';

  @override
  String get adminCmsSavingMessage =>
      'Igenzura ryo gutangaza ryahagaze kugeza igisubizo cyemejwe.';

  @override
  String get adminCmsRefreshing => 'Ibirimo biri kuvugururwa';

  @override
  String get adminCmsRefreshingMessage =>
      'Ahakorera haheruka kwemezwa haracyagaragara mu gihe hari kugenzurwa.';

  @override
  String get adminCmsCurrentRefreshUnavailable => 'Kuvugurura ubu ntibishoboka';

  @override
  String get adminCmsOutcomeUnconfirmed =>
      'Impinduka iheruka ntiyemejwe. Vugurura mbere y’ikindi gikorwa.';

  @override
  String get adminCmsLastConfirmed =>
      'Ahakorera haheruka kwemezwa haracyagaragara. Ibikorwa byahagaze kugeza ivugurura rishobotse.';

  @override
  String get adminCmsChangeOffline =>
      'Impinduka za CMS zisaba interineti. Nta gikorwa cyongeye kugeragezwa.';

  @override
  String get adminCmsChangeAccess =>
      'Uburenganzira kuri CMS ntibukiboneka kuri iyi konti.';

  @override
  String get adminCmsChangeConflict =>
      'Ibirimo bya CMS byahindutse. Vugurura mbere y’ikindi gikorwa.';

  @override
  String get adminCmsChangeUnconfirmed =>
      'Igisubizo nticyemejwe. Vugurura mbere y’ikindi gikorwa.';

  @override
  String get adminCmsChangeFailed =>
      'Impinduka ya CMS ntiyarangiye. Genzura wongere ugerageze.';

  @override
  String get adminCmsAddContentBlock => 'Ongeraho igice cy’ibirimo';

  @override
  String get adminCmsEditContentBlock => 'Hindura igice cy’ibirimo';

  @override
  String get adminCmsBlockKey => 'Ikiranga igice (urugero: home_hero_1)';

  @override
  String get adminCmsBlockType => 'Ubwoko bw’igice (urugero: banner)';

  @override
  String get adminCmsTargetChannel => 'Umuyoboro ugenewe';

  @override
  String get adminCmsPlacementKey => 'Aho bishyirwa';

  @override
  String get adminCmsTitleField => 'Umutwe';

  @override
  String get adminCmsSubtitleField => 'Umutwe wungirije';

  @override
  String get adminCmsContentComponent => 'Izina ry’igice cy’ibirimo';

  @override
  String get adminCmsFeatureField => 'Ikiranga';

  @override
  String get adminCmsNone => 'Nta na kimwe';

  @override
  String get adminCmsSortOrder => 'Uko bikurikirana';

  @override
  String get adminCmsActive => 'Gikora';

  @override
  String get adminCmsCreate => 'Kora';

  @override
  String get adminCmsSave => 'Bika';

  @override
  String get adminCmsNewArticle => 'Inkuru nshya';

  @override
  String get adminCmsArticleTitle => 'Umutwe w’inkuru';

  @override
  String get adminCmsArticleBody => 'Ibirimo by’inkuru';

  @override
  String get adminCmsAddQuickAction => 'Ongeraho igikorwa cyihuse';

  @override
  String get adminCmsEditQuickAction => 'Hindura igikorwa cyihuse';

  @override
  String get adminCmsActionKey => 'Ikiranga igikorwa';

  @override
  String get adminCmsRoute => 'Inzira';

  @override
  String get adminCmsIconKey => 'Ikiranga akamenyetso';

  @override
  String get adminCmsEmoji => 'Emoji';

  @override
  String get adminCmsCountry => 'Igihugu';

  @override
  String get adminCmsAddPartner => 'Ongeraho umufatanyabikorwa';

  @override
  String get adminCmsEditPartner => 'Hindura umufatanyabikorwa';

  @override
  String get adminCmsName => 'Izina';

  @override
  String get adminCmsSlug => 'Ikiranga';

  @override
  String get adminCmsCategory => 'Icyiciro';

  @override
  String get adminCmsDescriptionField => 'Ibisobanuro';

  @override
  String get adminCmsGamificationLinked => 'Bihujwe n’imikino';

  @override
  String get adminCmsCreatePartnerFirst => 'Banza ukore umufatanyabikorwa.';

  @override
  String get adminCmsAddPartnerService =>
      'Ongeraho serivisi y’umufatanyabikorwa';

  @override
  String get adminCmsEditPartnerService =>
      'Hindura serivisi y’umufatanyabikorwa';

  @override
  String get adminCmsPartner => 'Umufatanyabikorwa';

  @override
  String get adminCmsServiceSlug => 'Ikiranga serivisi';

  @override
  String get adminCmsCtaLabel => 'Izina ry’igikorwa';

  @override
  String get adminCmsCtaAction => 'Igikorwa';

  @override
  String get adminCmsAllCompetitionsAdded =>
      'Amarushanwa yose akora yamaze gushyirwa mu rutonde rwo guhanura.';

  @override
  String get adminCmsAddPredictionCompetition =>
      'Ongeraho irushanwa ryo guhanura';

  @override
  String get adminCmsEditPredictionCompetition =>
      'Hindura irushanwa ryo guhanura';

  @override
  String get adminCmsCompetition => 'Irushanwa';

  @override
  String get adminCmsHighlightLabel => 'Izina rishyizwe imbere';

  @override
  String get adminCmsChannelMobile => 'Telefoni';

  @override
  String get adminCmsChannelWeb => 'Urubuga';

  @override
  String get adminCmsChannelBoth => 'Telefoni n’urubuga';

  @override
  String get adminCmsCategoryOrganization => 'Umuryango';

  @override
  String get adminCmsCategoryBank => 'Banki';

  @override
  String get adminCmsCategoryFootball => 'Umupira w’amaguru';

  @override
  String get adminCmsCategoryGeneral => 'Rusange';

  @override
  String get adminCmsCategoryCommunity => 'Umuryango mugari';

  @override
  String get adminCmsCategoryInsurance => 'Ubwishingizi';

  @override
  String get adminCmsCategoryMobility => 'Ubwikorezi';

  @override
  String get adminCmsSectionNews => 'Amakuru';

  @override
  String get adminCmsSectionQuickActions => 'Ibikorwa byihuse';

  @override
  String get adminCmsSectionPartners => 'Abafatanyabikorwa';

  @override
  String get adminCmsSectionServices => 'Serivisi';

  @override
  String get adminCmsSectionPredictions => 'Guhanura';

  @override
  String get adminCmsSectionPlacements => 'Aho bishyirwa';

  @override
  String get adminCmsSectionAuditLogs => 'Amateka y’igenzura';

  @override
  String get adminCmsNewsArticles => 'Inkuru z’amakuru';

  @override
  String get adminCmsAddArticle => 'Ongeraho inkuru';

  @override
  String get adminCmsHomeQuickActions => 'Ibikorwa byihuse byo ku ntangiriro';

  @override
  String get adminCmsAddAction => 'Ongeraho igikorwa';

  @override
  String get adminCmsPartners => 'Abafatanyabikorwa';

  @override
  String get adminCmsAddPartnerAction => 'Ongeraho umufatanyabikorwa';

  @override
  String get adminCmsPartnerServices => 'Serivisi z’abafatanyabikorwa';

  @override
  String get adminCmsAddService => 'Ongeraho serivisi';

  @override
  String get adminCmsPredictionCompetitions => 'Amarushanwa yo guhanura';

  @override
  String get adminCmsAddCompetition => 'Ongeraho irushanwa';

  @override
  String get adminCmsContentBlocks => 'Ibice by’ibirimo bya pulatifomu';

  @override
  String get adminCmsAddBlock => 'Ongeraho igice';

  @override
  String get adminCmsAuditLogs => 'Amateka y’igenzura ry’ibiranga';

  @override
  String get adminCmsQuickActionFallback => 'Igikorwa cyihuse';

  @override
  String get adminCmsServiceFallback => 'Serivisi';

  @override
  String get adminCmsCompetitionFallback => 'Irushanwa';

  @override
  String get adminCmsContentBlockFallback => 'Igice cy’ibirimo';

  @override
  String get adminCmsActiveUpper => 'Gikora';

  @override
  String get adminCmsInactiveUpper => 'Ntigikora';

  @override
  String get adminCmsGamificationUpper => 'Imikino';

  @override
  String get adminCmsDirectUpper => 'Bitaziguye';

  @override
  String get adminCmsStandardUpper => 'Bisanzwe';

  @override
  String get adminCmsDeactivate => 'Hagarika';

  @override
  String get adminCmsActivate => 'Kora';

  @override
  String get adminCmsCtaPending => 'Igikorwa kirategerejwe';

  @override
  String get adminCmsNotAvailable => 'ntibiboneka';

  @override
  String adminCmsCompetitionSummary(String kind, int count) {
    return '$kind • Imikino $count';
  }

  @override
  String get adminCmsCatalog => 'Urutonde';

  @override
  String get adminCmsSupported => 'Ryemewe';

  @override
  String get adminCmsUnknown => 'ntibizwi';

  @override
  String get adminCmsUnknownFeature => 'Ikiranga kitazwi';

  @override
  String get adminCmsUnknownDate => 'Itariki itazwi';

  @override
  String get adminCmsActionFallback => 'Igikorwa';

  @override
  String adminCmsFeatureName(String feature) {
    return 'Ikiranga: $feature';
  }

  @override
  String get adminCmsActorWithheld =>
      'Amakuru y’uwakoze igikorwa arahishwa muri telefoni.';

  @override
  String get adminCmsEdit => 'Hindura';

  @override
  String get adminCmsUntitled => 'Nta mutwe';

  @override
  String get adminCmsNewsFallback => 'Amakuru';

  @override
  String get adminCmsLive => 'Yatangajwe';

  @override
  String get adminCmsDraft => 'Inyandiko';

  @override
  String get adminCmsNotPublished => 'Ntiyatangajwe';

  @override
  String get adminCmsFeatured => 'Yashyizwe imbere';

  @override
  String adminCmsArticleMeta(String category, String date, String featured) {
    return '$category • $date$featured';
  }

  @override
  String get adminCmsUnpublish => 'Kuraho';

  @override
  String get adminCmsPublish => 'Tangaza';

  @override
  String adminCmsPair(String first, String second) {
    return '$first • $second';
  }

  @override
  String get gameCommunityPicks => 'Amahitamo y’abafana';

  @override
  String get gameFetProgress => 'Aho FET igeze';

  @override
  String get gameFet => 'FET';

  @override
  String get gameLevelUp => 'Urwego rushya!';

  @override
  String get gameAwesome => 'Ni byiza';

  @override
  String get gameKeepGoing => 'Komeza';

  @override
  String get gameLive => 'Imbonankubone';

  @override
  String gameOutcomePick(String outcome) {
    return 'Guhitamo $outcome';
  }

  @override
  String gamePoints(int count) {
    return '+$count amanota';
  }

  @override
  String get gameDaysShort => 'Iminsi';

  @override
  String get gameHoursShort => 'Mas';

  @override
  String get gameMinutesShort => 'Min';

  @override
  String get gameSecondsShort => 'Seg';

  @override
  String get gameDismissNotification => 'Funga itangazo';

  @override
  String get gamePredictions => 'Guhanura';

  @override
  String get gameAccuracy => 'Ukuri';

  @override
  String get gamePointsEarned => 'Amanota yabonetse';

  @override
  String get gameRank => 'Umwanya';

  @override
  String get gameTopScorers => 'Abatsinze ibitego byinshi';

  @override
  String get gameGoals => 'Ibitego';

  @override
  String get gameEntriesClosed => 'Kwiyandikisha byarafunzwe';

  @override
  String get gameEntriesCloseIn => 'Kwiyandikisha birafungwa mu';

  @override
  String gameFetProgressValue(int current, int maximum, String tier) {
    return '$current kuri $maximum, urwego $tier';
  }

  @override
  String gamePickForTeams(String outcome, String home, String away) {
    return 'Guhitamo $outcome kuri $home na $away';
  }

  @override
  String get gameSelectedPick => 'Ihitamo ryatoranyijwe';

  @override
  String get gameAddPickToRound => 'Ongeraho ihitamo muri iki cyiciro';

  @override
  String gameNotificationSemantics(String title, String message) {
    return 'Itangazo: $title. $message';
  }

  @override
  String get gameDismissNotificationHint =>
      'Kanda cyangwa uzamure ukuboko kugira ngo urifunge';

  @override
  String get gameClubContextRequired => 'Amakuru ya klabu arakenewe.';

  @override
  String get gameUnexpectedResponse =>
      'Seriveri yasubije mu buryo butateganyijwe.';

  @override
  String get gameBack => 'Subira inyuma';

  @override
  String get gameRetry => 'Ongera ugerageze';

  @override
  String get gameOpenPredictionAlert => 'Fungura';

  @override
  String get gameBadgesTitle => 'Imidari yawe';

  @override
  String get gameBadgesUnavailable => 'Imidari ntiboneka';

  @override
  String get gameBadgesTemporarilyUnavailable =>
      'Imidari ntiboneka muri aka kanya.';

  @override
  String gameBadgeSemantics(String name) {
    return 'Umudari $name';
  }

  @override
  String get gameOpenBadgeDetails => 'Fungura ibisobanuro by’umudari';

  @override
  String get gamePredictionAlertsTitle => 'Amatangazo yo guhanura';

  @override
  String get gameAlertsUnavailable => 'Amatangazo ntaboneka';

  @override
  String get gamePredictionAlertsTemporarilyUnavailable =>
      'Amatangazo yo guhanura ntaboneka muri aka kanya.';

  @override
  String gamePredictionAlertSemantics(
    String title,
    String message,
    String date,
    String reward,
  ) {
    return 'Itangazo ryo guhanura, $title, $message, $date$reward';
  }

  @override
  String gameRewardPointsSemantics(int count) {
    return ', ibihembo by’amanota $count';
  }

  @override
  String get gameJustNow => 'Ubu';

  @override
  String get gameStreakTitle => 'Urukurikirane rwawe';

  @override
  String gameStreakDays(int count) {
    return 'IMINSI $count';
  }

  @override
  String get gameStreakActive => 'Urukurikirane rurakomeje.';

  @override
  String get gameCurrent => 'Urugezeho';

  @override
  String get gameBest => 'Urusumba ayandi';

  @override
  String get gameNextBonus => 'Igihembo gikurikira';

  @override
  String gameWins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Intsinzi $count',
      one: 'Intsinzi 1',
    );
    return '$_temp0';
  }

  @override
  String gameStreakDaySemantics(int day, String wins) {
    return 'Umunsi wa $day w’urukurikirane: $wins';
  }

  @override
  String get gameVerifyToPredict => 'Emeza kugira ngo uhanure';

  @override
  String get gameMakePicks => 'Hitamo';

  @override
  String get gameMakePicksDescription => 'Hitamo imikino yo mu marushanwa yose';

  @override
  String get gameEarnPoints => 'Bona amanota';

  @override
  String get gameEarnPointsDescription => 'Bona amanota ku mahitamo nyayo';

  @override
  String get gameClimbLeaderboards => 'Zamuka ku rutonde';

  @override
  String get gameClimbLeaderboardsDescription => 'Higanwa n’inshuti n’abafana';

  @override
  String get gameVerifyNow => 'Emeza ubu';

  @override
  String get gameJustBrowsing => 'Ndareba gusa';

  @override
  String get gameOffersTitle => 'Amaturo';

  @override
  String get gameOffersUnavailable => 'Amaturo ntaboneka';

  @override
  String get gameOffersTemporarilyUnavailable =>
      'Amaturo y’abafatanyabikorwa ntaboneka muri aka kanya.';

  @override
  String get gameWaysToEarn => 'Uburyo bwo kubona amanota';

  @override
  String get gameWaysToEarnDescription =>
      'Jya mu bikorwa no mu bukangurambaga kugira ngo ubone amanota.';

  @override
  String get gameBalance => 'Amafaranga asigaye';

  @override
  String get gameAvailable => 'Aboneka';

  @override
  String gameActiveOffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Amaturo $count akora',
      one: 'Ituro 1 rikora',
    );
    return '$_temp0';
  }

  @override
  String get gameFeatured => 'Ay’ingenzi';

  @override
  String get gameMatchDay => 'Umunsi w’umukino';

  @override
  String get gameAlwaysOn => 'Ahora ahari';

  @override
  String get gameReward => 'Igihembo';

  @override
  String get gameActivation => 'Gukoresha';

  @override
  String get gameVerification => 'Kwemeza';

  @override
  String get gameCondition => 'Ibisabwa';

  @override
  String get gameClose => 'Funga';

  @override
  String get gameDetails => 'Ibisobanuro';

  @override
  String gamePointBalance(int count) {
    return 'Amanota $count';
  }

  @override
  String gameFormattedPoints(String amount) {
    return 'Amanota $amount';
  }

  @override
  String get gameVerificationApi => 'Kwemezwa na API y’umufatanyabikorwa';

  @override
  String get gameVerificationRenewal => 'Kwemeza kongera serivisi';

  @override
  String get gameVerificationReferral => 'Kwemeza uwasabwe';

  @override
  String get gameVerificationReceipt => 'Gusikana inyemezabwishyu cyangwa POS';

  @override
  String get gameVerificationGeo => 'Kwemeza GPS cyangwa aho igikorwa kiri';

  @override
  String get gameVerificationSocial => 'Kwemeza icyatangajwe ku mbuga';

  @override
  String get gameVerificationSavings => 'Kwemeza intambwe yo kuzigama';

  @override
  String get gameVerificationEcommerce => 'Kwemeza icyaguzwe mu iduka';

  @override
  String get gameVerificationMobility => 'Kwemeza ko urugendo rwarangiye';

  @override
  String get gameVerificationEventQr => 'Kwemeza QR y’igikorwa';

  @override
  String get gameVerificationManual => 'Kugenzurwa n’umufatanyabikorwa';

  @override
  String get gameSettingsUpper => 'Igenamiterere';

  @override
  String get gamePrivacyUpper => 'Ubuzima bwite';

  @override
  String get gameCoreGuarantees => 'Ibyemezo by’ingenzi';

  @override
  String get gamePhoneNumberHidden => 'Nomero ya telefoni irahishwa';

  @override
  String get gamePhoneNumberHiddenDescription =>
      'Nomero ya WhatsApp cyangwa telefoni yawe irabikwa mu ibanga kuri seriveri gusa. Ntabwo igaragarizwa abandi bakoresha, abayobozi ba klabu cyangwa ku rutonde rusange.';

  @override
  String get gameAnonymousContributions => 'Imisanzu itagaragaza nyirayo';

  @override
  String get gameAnonymousContributionsDescription =>
      'Imisanzu ya MoMo yo mu matsinda y’abafana ibikwa hakoreshejwe Fan ID yawe n’icyiciro cy’amafaranga gusa. Umubare nyawo na nomero ya telefoni ntibibikwa.';

  @override
  String get gameVisibilityControls => 'Kugena ibigaragara';

  @override
  String get gameShowRealName => 'Erekana amazina nyayo';

  @override
  String get gameShowRealNameDescription =>
      'Iyo bizimijwe, Fan ID yawe ni yo igaragara ku rutonde aho kugaragaza amazina yawe.';

  @override
  String get gameFindableByPhone => 'Kuboneka hakoreshejwe telefoni';

  @override
  String get gameFindableByPhoneDescription =>
      'Bituma inshuti zikubona zikoresheje nomero ya telefoni. Nomero yawe ikomeza kuba ibanga.';

  @override
  String get gamePrivacyFirst => 'Ubuzima bwite mbere';

  @override
  String gamePrivacyFirstDescription(String appName) {
    return '$appName ntigurisha, ntisangira kandi ntigaragaza amakuru yawe bwite. Ibiranga byose kuri pulatifomu ntibigaragaza nyirabyo.';
  }

  @override
  String get gameRewardsStoreTitle => 'Iduka ry’ibihembo';

  @override
  String get gameRewardsUnavailable => 'Ibihembo ntibiboneka';

  @override
  String get gameRewardsTemporarilyUnavailable =>
      'Ibihembo ntibiboneka muri aka kanya.';

  @override
  String get gameAvailableBalance => 'Amanota asigaye';

  @override
  String gameRewardsStoreDescription(String appName) {
    return 'Gurana ibihembo bya $appName utavuye mu gikapo kimwe.';
  }

  @override
  String gameRewardMeta(String category, String notes) {
    return '$category · $notes';
  }

  @override
  String gameRedeemCost(String cost) {
    return 'Gurana $cost';
  }

  @override
  String gameNeedCost(String cost) {
    return 'Bisaba $cost';
  }

  @override
  String get gameRewardConfigurationMissing =>
      'Igenamiterere ry’igihembo ntirihari. Ongera ugerageze nyuma.';

  @override
  String get gameRewardAlreadyRedeemed => 'Iki gihembo cyamaze kuguranwa.';

  @override
  String gameRewardRedeemed(String reward, String cost) {
    return '$reward yaguranwe $cost.';
  }

  @override
  String get gameRewardCouldNotRedeem => 'Ntibyashobotse kugurana iki gihembo.';

  @override
  String get gameFriendsTitle => 'Inshuti';

  @override
  String get gameSupportersUnavailable => 'Abafana ntibaboneka';

  @override
  String get gameSupportersTemporarilyUnavailable =>
      'Abafana ntibaboneka muri aka kanya.';

  @override
  String get gameSearchSupporterHint => 'Shaka izina cyangwa ID y’umufana';

  @override
  String get gameDone => 'Byakozwe.';

  @override
  String get gameResults => 'Ibisubizo';

  @override
  String get gameYourFriends => 'Inshuti zawe';

  @override
  String get gameChallenge => 'Higanwa';

  @override
  String get gameAccept => 'Emera';

  @override
  String get gamePending => 'Birategerejwe';

  @override
  String get gameAdd => 'Ongeraho';

  @override
  String get gameOnline => 'Arahari';

  @override
  String get gameFixturesTitle => 'Imikino';

  @override
  String get gameFixturesUnavailable => 'Imikino ntiboneka';

  @override
  String get gameFixturesCouldNotLoad =>
      'Ntibyashobotse kuzana imikino muri aka kanya.';

  @override
  String get gameAll => 'Yose';

  @override
  String get gameToday => 'Uyu munsi';

  @override
  String get gameTomorrow => 'Ejo';

  @override
  String get gameYesterday => 'Ejo hashize';

  @override
  String gameRelativeDate(String relative, String date) {
    return '$relative · $date';
  }

  @override
  String gameMatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imikino $count',
      one: 'Umukino 1',
    );
    return '$_temp0';
  }

  @override
  String get gameMyActivity => 'Ibikorwa byanjye';

  @override
  String gameActiveCount(int count) {
    return 'IBIKORA ($count)';
  }

  @override
  String gameSettledTabCount(int count) {
    return 'IBYARANGIYE ($count)';
  }

  @override
  String gameHistoryCount(int count) {
    return 'AMATEKA ($count)';
  }

  @override
  String get gameActivityUnavailable => 'Ibikorwa ntibiboneka';

  @override
  String get gameActivityCouldNotLoad =>
      'Ntibyashobotse kuzana ibikorwa byawe muri aka kanya.';

  @override
  String get gameCouldNotCancelPick => 'Ntibyashobotse guhagarika iri hitamo.';

  @override
  String get gameWon => 'Yatsinze';

  @override
  String get gameLost => 'Yatsinzwe';

  @override
  String get gameCancelled => 'Yahagaritswe';

  @override
  String get gameVoid => 'Yavanyweho';

  @override
  String get gamePendingUpper => 'Irategerejwe';

  @override
  String get gameTbd => 'Birategerejwe';

  @override
  String gameVersusShort(String home, String away) {
    return '$home na $away';
  }

  @override
  String get gameRound => 'Icyiciro';

  @override
  String gameCompetitionTime(String competition, String time) {
    return '$competition • $time';
  }

  @override
  String get gameCancel => 'Hagarika';

  @override
  String gameActivitySemantics(String home, String away) {
    return 'Igikorwa cya $home na $away';
  }

  @override
  String get gameOpenActivityDetail => 'Fungura ibisobanuro by’igikorwa';

  @override
  String get gameNotificationsUpper => 'Amatangazo';

  @override
  String get gameKickoffAlerts => 'Amatangazo yo gutangira umukino';

  @override
  String get gameRoundResults => 'Ibisubizo by’icyiciro';

  @override
  String get gameFriendChallenges => 'Guhiganwa n’inshuti';

  @override
  String get gameLineupsUpper => 'Abakinnyi';

  @override
  String get gameSubstitutes => 'Abasimbura';

  @override
  String get gameActiveUpper => 'Ibikora';

  @override
  String get gameWinRate => 'Igipimo cy’intsinzi';

  @override
  String get gameYouUpper => 'Wowe';

  @override
  String gameWalletSignedPoints(String sign, String amount) {
    return '$sign$amount amanota';
  }

  @override
  String gameWalletBalance(String amount) {
    return 'Asigaye $amount amanota';
  }

  @override
  String get gameOpenUpper => 'Irafunguye';

  @override
  String get gamePointsShare => 'Igabana ry’amanota';

  @override
  String get gamePointsShareDescription =>
      'Amategeko y’urwego agena uko amanota wabonye agufasha n’uko afasha ibihembo rusange bya klabu.';

  @override
  String gamePersonalPercentage(int count) {
    return '$count% ayawe';
  }

  @override
  String gameClubPercentage(int count) {
    return '$count% aya klabu';
  }

  @override
  String gameTierSplit(int personal, int club) {
    return '$personal/$club';
  }

  @override
  String get gamePointsShareExplanation =>
      'Amanota yawe agabanywa hakurikijwe urwego: umugabane wawe uguma kuri wowe, uwa klabu ugafasha ibihembo rusange.';

  @override
  String get gameTierSupporter => 'Umufana';

  @override
  String get gameTierMember => 'Umunyamuryango';

  @override
  String get gameTierUltra => 'Ultra';

  @override
  String get gameTierLegend => 'Ikirangirire';

  @override
  String get gameFree => 'Ubuntu';

  @override
  String gameMonthlyPrice(String amount) {
    return '$amount RWF / ukwezi';
  }

  @override
  String gameShareTitle(String appName) {
    return 'Ihitamo rya $appName';
  }

  @override
  String get gameShareCopied => 'Inyandiko yo gusangiza yashyizwe mu bubiko.';

  @override
  String gameShareStatusLine(String status, String home, String away) {
    return '$status: $home na $away';
  }

  @override
  String gameFinalScore(int home, int away) {
    return 'Amanota ya nyuma: $home-$away';
  }

  @override
  String gameMarketSelection(String market, String selection) {
    return '$market: $selection';
  }

  @override
  String gameEarnedShare(int count) {
    return 'Wabonye: +$count amanota';
  }

  @override
  String gamePotentialShare(int count) {
    return 'Ushobora kubona: +$count amanota';
  }

  @override
  String get gameMarketUpper => 'Ubwoko';

  @override
  String get gamePickUpper => 'Ihitamo';

  @override
  String get gameEarnedUpper => 'Wabonye';

  @override
  String get gamePotentialUpper => 'Ashoboka';

  @override
  String gameShareTagline(String appName) {
    return '$appName · KINA. HITAMO. BONA.';
  }

  @override
  String gamePickTypeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ubwoko $count bw’amahitamo',
      one: 'Ubwoko 1 bw’ihitamo',
    );
    return '$_temp0';
  }

  @override
  String get gameSearchPickTypes => 'Shaka ubwoko bw’amahitamo';

  @override
  String get gameClearSearch => 'Siba ibyo washakaga';

  @override
  String get gameAddPicksToUnlock =>
      'Ongeraho amahitamo kugira ngo ufungure icyiciro';

  @override
  String gameOpenRoundSummary(int count, int points) {
    return 'Fungura icyiciro · Amahitamo $count · Amanota $points';
  }

  @override
  String get gameLiveOnly => 'Imbonankubone gusa';

  @override
  String gameOutcomeAddedToRound(String outcome) {
    return '$outcome yongewe mu cyiciro cyawe.';
  }

  @override
  String get gameMarkets => 'Ubwoko bw’amahitamo';

  @override
  String gameMarketCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ubwoko $count',
      one: 'Ubwoko 1',
    );
    return '$_temp0';
  }

  @override
  String get gameStatsNotAvailableYet => 'Imibare ntiraboneka';

  @override
  String get gameLiveStatsUpdating =>
      'Imibare y’imbonankubone yivugurura umukino ukina.';

  @override
  String get gameLiveMatchDataUpdating =>
      'Amakuru y’umukino arimo kuvugururwa kuri uyu mukino.';

  @override
  String get gameStructuredMatchStats => 'Imibare yateguwe y’uyu mukino.';

  @override
  String get gameTotalGoals => 'Ibitego byose';

  @override
  String get gameFinalMatchStats => 'Imibare ya nyuma y’umukino.';

  @override
  String gameFixtureMarketTitle(String home, String away, String market) {
    return '$home na $away · $market';
  }

  @override
  String get gamePickTypeLocked =>
      'Ubu bwoko bw’ihitamo burafunze kuri uyu mukino.';

  @override
  String get gameLeaderboardTitle => 'Urutonde';

  @override
  String get gameFetRanking => 'Urutonde rwa FET';

  @override
  String get gameSupporters => 'Abafana';

  @override
  String get gameAllTime => 'Ibihe byose';

  @override
  String get gameWeekly => 'Buri cyumweru';

  @override
  String get gameMonthly => 'Buri kwezi';

  @override
  String get gameLeaderboardUnavailable => 'Urutonde ntiruboneka';

  @override
  String get gameLeaderboardTemporarilyUnavailable =>
      'Urutonde ntiruboneka muri aka kanya.';

  @override
  String get gameRankingsUnavailable => 'Intonde ntiziboneka';

  @override
  String get gameSupporterRankingsTemporarilyUnavailable =>
      'Intonde z’abafana ntiziboneka muri aka kanya.';

  @override
  String get gameNotSignedIn => 'Ntiwinjiye';

  @override
  String get gameTierFan => 'Umufana';

  @override
  String get gameDisplayNameOn => 'Amazina aragaragara';

  @override
  String get gameAliasOnly => 'Izina ry’irihimbano gusa';

  @override
  String gameDisplayNameOnDescription(String name) {
    return 'Intonde zishobora kwerekana $name aho kwerekana Fan ID gusa.';
  }

  @override
  String get gameAliasOnlyDescription =>
      'Intonde zerekana Fan ID cyangwa izina ry’irihimbano aho kwerekana amazina nyayo.';

  @override
  String get gamePhoneHidden => 'Telefoni irahishwa';

  @override
  String get gamePhoneHiddenDescription =>
      'Nomero ya telefoni yawe iguma kuri seriveri kandi ntigaragarizwa abandi bafana cyangwa abayobozi ba klabu.';

  @override
  String get gamePhoneDiscoveryOn => 'Gushakwa na telefoni birakora';

  @override
  String get gamePhoneDiscoveryOff => 'Gushakwa na telefoni birazimye';

  @override
  String get gamePhoneDiscoveryOnDescription =>
      'Inshuti zisanzwe zizi nomero yawe zishobora kubona umwirondoro wawe.';

  @override
  String get gamePhoneDiscoveryOffDescription =>
      'Gushakwa hakoreshejwe telefoni byazimijwe ku mwirondoro wawe.';

  @override
  String get gameVerified => 'Byemejwe';

  @override
  String get gameVerificationPending => 'Kwemeza birategerejwe';

  @override
  String gameVerifiedDescription(String appName) {
    return 'Umwirondoro wawe wa telefoni wemejwe ku bikorwa byo kubona amanota no gusabana bya $appName.';
  }

  @override
  String gameVerificationPendingDescription(String appName) {
    return 'Emeza telefoni yawe kugira ngo ufungure ibikorwa byose byo gusabana bya $appName.';
  }

  @override
  String get gameFanIdPersistentRule =>
      'Fan ID yawe iva ku mwirondoro wawe kandi ntihinduka iyo ugarutse.';

  @override
  String gameDisplayNameVisibleRule(String name) {
    return 'Amazina agaragara “$name” ashobora kujya ku rutonde kugeza ubizimije.';
  }

  @override
  String get gameRealNameHiddenRule =>
      'Amazina yawe nyayo aguma ahishwe ku rutonde kugeza wemeye ko agaragara.';

  @override
  String get gamePhoneEncryptedRule =>
      'Nomero ya telefoni yawe ibikwa mu ibanga kuri seriveri gusa.';

  @override
  String get gamePhoneDiscoveryEnabledRule =>
      'Gushaka inshuti hakoreshejwe telefoni birakora kuri konti yawe.';

  @override
  String get gamePhoneDiscoveryDisabledRule =>
      'Gushaka inshuti hakoreshejwe telefoni byazimijwe kuri konti yawe.';

  @override
  String gamePhoneVerifiedRule(String appName) {
    return 'Umwirondoro wawe wa telefoni wemejwe ku biranga n’ibihembo bya $appName.';
  }

  @override
  String gamePhonePendingRule(String appName) {
    return 'Kwemeza telefoni biracyategerejwe ku mwirondoro wawe wa $appName.';
  }

  @override
  String gameTeamLinkedRule(String team) {
    return 'Umwirondoro wawe uhujwe na $team kugira ngo ibikwerekwa bikubere.';
  }

  @override
  String get gameLinkTeamRule =>
      'Ushobora guhuza ikipe ukunda mu ntangiriro cyangwa mu igenamiterere ry’umwirondoro.';

  @override
  String get gameDeleteAccountRule =>
      'Gusiba konti yawe bikuraho amakuru bwite n’ihuriro rya Fan ID ku mwirondoro ukora.';

  @override
  String get gameFanIdTitle => 'Fan id';

  @override
  String get gameYourFanId => 'Fan id yawe';

  @override
  String get gameAliasOnlyProfile => 'Umwirondoro w’izina ry’irihimbano gusa';

  @override
  String get gameFanIdCopied => 'Fan ID yashyizwe mu bubiko.';

  @override
  String get gameCopyToClipboard => 'Shyira mu bubiko';

  @override
  String get gamePrivacyBadges => 'Ibimenyetso by’ubuzima bwite';

  @override
  String get gameIdentityRules => 'Amategeko y’umwirondoro';

  @override
  String get gameIdentityRulesDescription =>
      'Uko Fan ID yawe ikora hakurikijwe igenamiterere ry’umwirondoro wawe.';

  @override
  String get gameStandingsTitle => 'Urutonde';

  @override
  String get gameCompetitionNotFound => 'Irushanwa ntiryabonetse.';

  @override
  String get gameStandingsTemporarilyUnavailable =>
      'Urutonde ntiruboneka muri aka kanya.';

  @override
  String get gameStandingsUnavailable => 'Urutonde ntiruboneka';

  @override
  String get gamePositionShort => 'Umw';

  @override
  String get gameTeamUpper => 'Ikipe';

  @override
  String get gamePointsShort => 'Amn';

  @override
  String get gamePointsUpper => 'Amanota';

  @override
  String gameStandingRecord(
    int played,
    int goalsFor,
    int goalsAgainst,
    int difference,
  ) {
    return '${played}M · $goalsFor:$goalsAgainst · IB $difference';
  }

  @override
  String get gameHeadToHead => 'Uko bahuranye';

  @override
  String gameHeadToHeadEmpty(String home, String away) {
    return 'Amateka y’imikino ya $home na $away azagaragara hano.';
  }

  @override
  String get gameWinDistribution => 'Igabana ry’intsinzi';

  @override
  String get gameDraws => 'Banganyije';

  @override
  String gameTeamGoals(String team) {
    return 'IBITEGO BYA $team';
  }

  @override
  String get gameRecentEncounters => 'Imikino iheruka';

  @override
  String gameScore(int home, int away) {
    return '$home - $away';
  }

  @override
  String get gameTokenHistoryTitle => 'Amateka y’amanota';

  @override
  String get gameTokenHistoryTemporarilyUnavailable =>
      'Amateka y’amanota ntaboneka muri aka kanya.';

  @override
  String get gameHistoryUnavailable => 'Amateka ntaboneka';

  @override
  String get gameEarned => 'Yabonetse';

  @override
  String get gameSpent => 'Yakoreshejwe';

  @override
  String get gameAllUpper => 'Byose';

  @override
  String get gameEarnedUpperFilter => 'Yabonetse';

  @override
  String get gameSpentUpper => 'Yakoreshejwe';

  @override
  String get gameCredit => 'Yinjiye';

  @override
  String get gameDebit => 'Yasohotse';

  @override
  String get gameLedgerUpdate => 'Ivugurura ry’igitabo';

  @override
  String gameTransactionSemantics(
    String direction,
    String headline,
    String detail,
    int amount,
    int balance,
    String date,
  ) {
    return 'Igikorwa cya $direction, $headline, $detail, amanota $amount, asigaye $balance, $date';
  }

  @override
  String get gameUnknownTime => 'Igihe ntikizwi';

  @override
  String get gameClubFanZoneTitle => 'Aho abafana ba klabu bahurira';

  @override
  String get gameClubFanZoneTemporarilyUnavailable =>
      'Aho abafana ba klabu bahurira ntihaboneka muri aka kanya.';

  @override
  String get gameFanZoneUnavailable => 'Aho abafana bahurira ntihaboneka';

  @override
  String get gameSupporterPulse => 'Imbaraga z’abafana';

  @override
  String get gameSupporterPulseDescription =>
      'Imbaraga nyazo z’abafana mu marushanwa akora, amahitamo y’imikino n’amakipe ayoboye.';

  @override
  String get gameTopClubs => 'Amakipe ayobora';

  @override
  String gameRankHash(int rank) {
    return 'Nº $rank';
  }

  @override
  String get gameSupporterLeans => 'Ibyo abafana bahitamo';

  @override
  String gameSupporterLeansEmpty(String appName) {
    return 'Igabana ry’amahitamo y’abafana rizagaragara iri rushanwa rimaze kugira guhanura kwa $appName gukora.';
  }

  @override
  String gamePair(String first, String second) {
    return '$first · $second';
  }

  @override
  String gameSupporterLeanPercentage(String percentage) {
    return '$percentage% by’abafana bahitamo gutya ubu.';
  }

  @override
  String get gameLeagueHubTitle => 'Amakuru y’irushanwa';

  @override
  String get gameLeagueDataTemporarilyUnavailable =>
      'Amakuru y’irushanwa ntaboneka muri aka kanya.';

  @override
  String get gameLeagueUnavailable => 'Irushanwa ntiriboneka';

  @override
  String get gameCompetition => 'Irushanwa';

  @override
  String get gameRegion => 'Akarere';

  @override
  String get gameLeague => 'Shampiyona';

  @override
  String get gameTeams => 'Amakipe';

  @override
  String get gameFixtures => 'Imikino';

  @override
  String get gameLeader => 'Iyoboye';

  @override
  String get gameTopTable => 'Abayoboye urutonde';

  @override
  String get gameFullStandings => 'Urutonde rwose';

  @override
  String gameLeagueStandingRecord(int played, int won, int drawn, int lost) {
    return '${played}M · ${won}T ${drawn}B ${lost}Y';
  }

  @override
  String get gameEntrySubmitted => 'Ihitamo ryoherejwe';

  @override
  String get gameBonusEntryLive => 'Ihitamo ryawe ry’inyongera rirakora ubu.';

  @override
  String get gameCouldNotSubmitBonus =>
      'Ntibyashobotse kohereza ihitamo ry’inyongera ubu.';

  @override
  String get gameKickoffTbd => 'Gutangira ntibiragenwa';

  @override
  String get gameBonusRound => 'Icyiciro cy’inyongera';

  @override
  String get gameSubmitting => 'Birimo koherezwa…';

  @override
  String get gameEntriesClosedSentence => 'Amahitamo yarafunzwe';

  @override
  String get gameSubmitEntry => 'Ohereza ihitamo';

  @override
  String get gameBonusRoundActivationPending =>
      'Gufungura icyiciro cy’inyongera birategerejwe.';

  @override
  String get gameBonusRoundTemporarilyUnavailable =>
      'Icyiciro cy’inyongera ntikiboneka muri aka kanya.';

  @override
  String get gameBonusRoundUnavailable => 'Icyiciro cy’inyongera ntikiboneka';

  @override
  String get gamePointsPool => 'Ikigega cy’amanota';

  @override
  String get gamePickAllFeatured =>
      'Hitamo buri mukino w’ingenzi mbere y’uko icyiciro gifungwa.';

  @override
  String gamePicksComplete(int selected, int total) {
    return 'Amahitamo $selected kuri $total yarangiye';
  }

  @override
  String gameEntriesRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hasigaye amahitamo $count',
      one: 'Hasigaye ihitamo 1',
    );
    return '$_temp0';
  }

  @override
  String get gameLeaders => 'Abayoboye';

  @override
  String get gameSocialHub => 'Aho gusabana';

  @override
  String get gameClub => 'Klabu';

  @override
  String get gameSearchYourFriends => 'Shaka inshuti zawe';

  @override
  String get gameBrowse => 'Shakisha';

  @override
  String get gameViewAll => 'Reba byose';

  @override
  String get gameClubStandingsTemporarilyUnavailable =>
      'Urutonde rwa klabu ntiruboneka muri aka kanya.';

  @override
  String get gameClubStandingsUnavailable => 'Urutonde rwa klabu ntiruboneka';

  @override
  String get gameClubStanding => 'Umwanya muri klabu';

  @override
  String get gameUnranked => 'Nta mwanya';

  @override
  String get gameEarnPointsForClubTable =>
      'Bona amanota kugira ngo ugaragare ku rutonde rwa klabu.';

  @override
  String gamePointsEarnedSoFar(int count) {
    return 'Amanota $count amaze kuboneka.';
  }

  @override
  String gameNameYou(String name) {
    return '$name (Wowe)';
  }

  @override
  String get gameChallengeFlowTemporarilyUnavailable =>
      'Uburyo bwo guhiganwa ntibuboneka muri aka kanya.';

  @override
  String gameHeadToHeadMessage(String appName, String home, String away) {
    return 'Guhangana kwa $appName kuri $home na $away';
  }

  @override
  String get gameChallengeSent => 'Guhiganwa byoherejwe';

  @override
  String get gameChallengeWaiting => 'Guhiganwa kwawe gutegereje igisubizo.';

  @override
  String get gameCouldNotSendChallenge =>
      'Ntibyashobotse kohereza uguhiganwa ubu.';

  @override
  String get gameSending => 'Birimo koherezwa…';

  @override
  String get gameSendChallenge => 'Ohereza uguhiganwa';

  @override
  String get gameChallengeUnavailable => 'Guhiganwa ntibiboneka';

  @override
  String get gameSupporter => 'Umufana';

  @override
  String get gameAddFriendsBeforeChallenge =>
      'Ongeraho inshuti mbere yo kohereza uguhiganwa.';

  @override
  String get gameFindFriends => 'Shaka inshuti';

  @override
  String get gameFixture => 'Umukino';

  @override
  String get gamePick => 'Ihitamo';

  @override
  String get gameSelected => 'Byatoranyijwe';

  @override
  String get gameChoose => 'Hitamo';

  @override
  String get gameTeamNotFound => 'Ikipe ntiyabonetse.';

  @override
  String get gameTeamProfileTemporarilyUnavailable =>
      'Umwirondoro w’ikipe ntuboneka muri aka kanya.';

  @override
  String get gameSupporterActivityActiveClubOnly =>
      'Ibikorwa by’abafana biboneka kuri klabu ikora gusa.';

  @override
  String get gameSupporterRoutingCurrentClubOnly =>
      'Urutonde rw’abafana n’inzira z’imisanzu biboneka kuri klabu ikoreshwa na porogaramu gusa.';

  @override
  String get gameContributionRouteNotPublished =>
      'Iyi klabu ntiratangaza inzira ikora yo gutanga umusanzu.';

  @override
  String get gameClubSupporterDataUnavailable =>
      'Amakuru y’abafana ba klabu ntaboneka muri aka kanya.';

  @override
  String get gameContributionsActiveClubOnly =>
      'Imisanzu iboneka kuri klabu ikora gusa.';

  @override
  String get gameContributionRouteUnavailable => 'Inzira y’umusanzu ntiboneka.';

  @override
  String get gameCouldNotOpenDialer => 'Ntibyashobotse gufungura ahamagazwa.';

  @override
  String get gameDialerLaunchFailed => 'Gufungura ahamagazwa byanze.';

  @override
  String get gameEnterContributionAmount => 'Andika umubare w’umusanzu';

  @override
  String gamePaymentRouteDescription(String recipient, String provider) {
    return 'Uri bwishyure $recipient ukoresheje $provider.';
  }

  @override
  String gameAmountCurrency(String currency) {
    return 'Umubare ($currency)';
  }

  @override
  String get gameDialNow => 'Hamagara ubu';

  @override
  String get gameEnterValidAmount => 'Andika umubare wemewe.';

  @override
  String get gameTeamProfileTitle => 'Umwirondoro w’ikipe';

  @override
  String get gameTeamUnavailable => 'Ikipe ntiboneka';

  @override
  String gameFoundedYear(int year) {
    return 'Yashinzwe mu $year';
  }

  @override
  String get gameTable => 'Urutonde';

  @override
  String get gameSquad => 'Abakinnyi';

  @override
  String get gameOverview => 'Incamake';

  @override
  String get gameMembers => 'Abanyamuryango';

  @override
  String get gameContribute => 'Tanga umusanzu';

  @override
  String get gameAbout => 'Ibyerekeye';

  @override
  String get gameLeaguePosition => 'Umwanya muri shampiyona';

  @override
  String get gamePlayedShort => 'M';

  @override
  String get gameWonShort => 'T';

  @override
  String get gameDrawnShort => 'B';

  @override
  String get gameLostShort => 'Y';

  @override
  String get gameGoalDifferenceShort => 'Ib';

  @override
  String get gameMomoContributionRoute => 'Inzira y’umusanzu MoMo';

  @override
  String gameUseProviderForClub(String provider, String club) {
    return 'Koresha $provider kugira ngo utange umusanzu kuri $club.';
  }

  @override
  String get gameThisClub => 'iyi klabu';

  @override
  String get gameSupporterRegistryCurrentClubOnly =>
      'Urutonde rw’abafana ruboneka kuri klabu ikoreshwa na porogaramu gusa.';

  @override
  String get gameMembersUnavailable => 'Abanyamuryango ntibaboneka';

  @override
  String get gameClubMembers => 'Abanyamuryango ba klabu';

  @override
  String get gameTierGold => 'Zahabu';

  @override
  String get gameTierSilver => 'Feza';

  @override
  String get gameTierBronze => 'Umuringa';

  @override
  String get gameTierImena => 'Imena';

  @override
  String get gameTopContributors => 'Abatanze imisanzu myinshi';

  @override
  String get gameMomoContribution => 'Umusanzu MoMo';

  @override
  String gameUseProviderInCountry(String provider, String country) {
    return 'Koresha $provider muri $country kugira ngo utange umusanzu kuri iyi klabu.';
  }

  @override
  String get gameEnterAmount => 'Andika umubare';

  @override
  String gameEnterAmountDescription(String provider) {
    return 'Hitamo umubare ushaka kohereza ukoresheje $provider.';
  }

  @override
  String get gameConfirmInDialer => 'Emeza aho bahamagara';

  @override
  String gameConfirmInDialerDescription(String code) {
    return 'Turafungura ahamagazwa rya mobile money kuri kode $code.';
  }

  @override
  String get gameReconciliation => 'Guhuza umusanzu';

  @override
  String get gameReconciliationDescription =>
      'Umusanzu wawe uhuzwa n’ibikorwa bya klabu iyo kwishyura byemejwe.';

  @override
  String get gameOpeningDialer => 'Birimo gufungura ahamagazwa…';

  @override
  String get gameEnterAmountAndDial => 'Andika umubare maze uhamagare';

  @override
  String gameAboutTeam(String team) {
    return 'IBYEREKEYE $team';
  }

  @override
  String get gameThisClubUpper => 'Iyi klabu';

  @override
  String get gameLocation => 'Aho iherereye';

  @override
  String get gameCountry => 'Igihugu';

  @override
  String get gameFounded => 'Yashinzwe';

  @override
  String get gameType => 'Ubwoko';

  @override
  String get gameAffiliatedClub => 'Klabu ifitanye isano';

  @override
  String get gameSelectedLeaderboardPeriod => 'Igihe cy’urutonde cyatoranyijwe';

  @override
  String get gameSelectPeriod => 'Hitamo igihe';

  @override
  String gameRankLabel(String rank) {
    return 'Nº $rank';
  }

  @override
  String get gameRankPending => 'Umwanya urategerejwe';

  @override
  String gameAccuracyWins(String accuracy, int wins) {
    String _temp0 = intl.Intl.pluralLogic(
      wins,
      locale: localeName,
      other: 'Intsinzi $wins',
      one: 'Intsinzi 1',
    );
    return 'Ukuri $accuracy% · $_temp0';
  }

  @override
  String gameSettledCount(int count) {
    return '$count byarangiye';
  }

  @override
  String gameTierAlias(String tier, String alias) {
    return 'Urwego $tier · $alias';
  }

  @override
  String gamePodiumRank(int rank) {
    return 'Umwanya $rank ku ruhimbi';
  }

  @override
  String get gamePickRound => 'Icyiciro cy’amahitamo';

  @override
  String gameActivePicks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Amahitamo $count arakora',
      one: 'Ihitamo 1 rirakora',
    );
    return '$_temp0';
  }

  @override
  String gameEarnUpToPoints(int count) {
    return 'Bona amanota agera kuri $count';
  }

  @override
  String get gamePickRoundEmpty => 'Icyiciro cy’amahitamo kirimo ubusa';

  @override
  String get gamePickRoundEmptyDescription =>
      'Ongeramo amahitamo avuye ku mukino uwo ari wo wose maze uyemeze hano.';

  @override
  String get gamePickRoundUpper => 'Icyiciro cy’amahitamo';

  @override
  String get gameAcca => 'Urwunge';

  @override
  String gamePotentialPoints(int count) {
    return 'Amanota ashoboka: $count';
  }

  @override
  String get gameLockInPicks => 'Emeza amahitamo';

  @override
  String get gameSomeSelectionsFailed => 'Hari amahitamo atashoboye koherezwa.';

  @override
  String get gameCouldNotSubmitPicks =>
      'Ntibyashobotse kohereza amahitamo yawe.';

  @override
  String get gameConfirmPicks => 'Emeza amahitamo';

  @override
  String gameLockingCombo(int count) {
    return 'Uri kwemeza amahitamo $count nk’urwunge.';
  }

  @override
  String gameLockingPicks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Uri kwemeza amahitamo $count.',
      one: 'Uri kwemeza ihitamo 1.',
    );
    return '$_temp0';
  }

  @override
  String gameOutcomePotential(String outcome, int count) {
    return '$outcome · +$count amanota';
  }

  @override
  String get gameTotalPotential => 'Amanota yose ashoboka';

  @override
  String get gameGoBack => 'Subira inyuma';

  @override
  String gamePredictionsLocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Amahanura $count yemejwe',
      one: 'Ihanura ryemejwe',
    );
    return '$_temp0';
  }

  @override
  String gameRoundId(String id) {
    return 'ID y’icyiciro: $id';
  }

  @override
  String get gameShareUpper => 'Sangiza';

  @override
  String get gameCopyUpper => 'Kopi';

  @override
  String get gameViewMyPredictions => 'Reba amahanura yanjye';

  @override
  String get gameKeepBrowsing => 'Komeza gushakisha';

  @override
  String get gameRemovePick => 'Kuraho ihitamo';

  @override
  String get gameFans => 'Abafana';

  @override
  String get gameWallet => 'Igikapo';

  @override
  String get gameMore => 'Ibindi';

  @override
  String get gameRoundUpper => 'Icyiciro';

  @override
  String gameAccuracyRounds(String accuracy, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ibyiciro $count',
      one: 'Icyiciro 1',
    );
    return '$accuracy% · $_temp0';
  }

  @override
  String gamePointsRound(int count) {
    return 'Icyiciro cy’amanota $count';
  }

  @override
  String get gamePointsRoundLabel => 'amanota y’icyiciro';

  @override
  String gamePointEntry(int count) {
    return 'Kwinjira n’inota $count';
  }

  @override
  String gameFansCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Abafana $count',
      one: 'Umufana 1',
    );
    return '$_temp0';
  }

  @override
  String get gameChooseWdw => 'Hitamo T/B/T';

  @override
  String get gameJoinRound => 'Injira mu cyiciro';

  @override
  String gameSelectedOutcome(String outcome) {
    return '$outcome byatoranyijwe';
  }

  @override
  String get gameChallengesTitle => 'Guhiganwa';

  @override
  String get gameChallengesTemporarilyUnavailable =>
      'Guhiganwa ntibiboneka muri aka kanya.';

  @override
  String get gameChallengesUnavailable => 'Guhiganwa ntibiboneka';

  @override
  String get gameDaily => 'Buri munsi';

  @override
  String get gameWeeklyUpper => 'Buri cyumweru';

  @override
  String get gameSeasonal => 'Buri gihembwe';

  @override
  String get gameCompleted => 'Byarangiye';

  @override
  String get gameChallengesRequireProfile =>
      'Guhiganwa bigaragara umwirondoro wawe w’umufana umaze gukora.';

  @override
  String get gameWhatIsFet => 'FET ni iki?';

  @override
  String get gameWhatIsFetBody =>
      'FET ni amanota y’imikoranire y’abafana. Uyabona witabira ibikorwa bya klabu, ujya ku mikino, urangiza uguhiganwa, uhanura kandi ugafasha umuryango.';

  @override
  String get gameHowPredictionsWork => 'Uko guhanura bikora';

  @override
  String get gameHowPredictionsWorkBody =>
      'Reba imikino iri imbere, hitamo ubwoko bwo guhanura, maze wemeze amahitamo mbere y’umukino. Amahitamo nyayo atanga amanota hakurikijwe uburemere.';

  @override
  String get gameEarnLevelRedeem => 'Bona, zamuka kandi ugurane';

  @override
  String get gameEarnLevelRedeemBody =>
      'Amanota yawe yiyongera uko witabira. Zamuka ku rutonde, fungura ibyiciro by’ubunyamuryango kandi ugurane ibihembo mu iduka rya klabu.';

  @override
  String get gameBackUpper => 'Subira inyuma';

  @override
  String get gameGetStarted => 'Tangira';

  @override
  String get gameNext => 'Bikurikira';

  @override
  String get gameOpen => 'Birafunguye';

  @override
  String get gameRefresh => 'Vugurura';

  @override
  String get gameMoreOptions => 'Andi mahitamo';

  @override
  String get gameConnectToFanZone =>
      'Huza interineti kugira ngo ufungure Fan Zone.';

  @override
  String get gameOpeningFanZone => 'Gufungura Fan Zone';

  @override
  String get gameRefreshingFanZone => 'Kuvugurura Fan Zone';

  @override
  String get gameRefreshingFanZoneDescription =>
      'Amanota, ibyiciro n’amahitamo byawe birakomeza kugaragara mu gihe amakuru avugururwa.';

  @override
  String get gameMatchdayRounds => 'Ibyiciro by’umunsi w’umukino';

  @override
  String get gameNoMatchdayRounds => 'Nta byiciro by’umunsi w’umukino bihari';

  @override
  String get gameReviewJoinedRounds =>
      'Reba ibyiciro witabiriye, amakarita n’ibisubizo';

  @override
  String get gameVenueCheckIn => 'Kwiyandikisha aho umukino uri';

  @override
  String get gameVenueOrder => 'Gutumiza aho umukino uri';

  @override
  String get gameVenueOrderDescription =>
      'Tumiza ibinyobwa byemewe kandi ukurikirane aho kubifatira';

  @override
  String get gameLiveNow => 'Birimo kuba ubu';

  @override
  String get gameThisWeek => 'Muri iki cyumweru';

  @override
  String get gamePointsBalanceTitle => 'Amanota usigaranye';

  @override
  String get gamePointsBalanceDescription =>
      'Amanota, uko wayabonye, ibihembo n’ibikorwa';

  @override
  String get gameActivity => 'Ibikorwa';

  @override
  String get gameOpenPointsActivity => 'Reba uko amanota aheruka guhinduka';

  @override
  String get gameSupporterClubs => 'Amatsinda y’abafana';

  @override
  String get gameSupporterClubsDescription =>
      'Amakipe y’abafana, amashami n’amatsinda y’abaturage';

  @override
  String get gameMemberFans => 'Abafana b’abanyamuryango';

  @override
  String get gameMemberFansDescription =>
      'Fungura urutonde rw’abafana mu rupapuro';

  @override
  String get gameSupportClubDescription =>
      'Imishinga n’amatsinda y’inkunga y’abafana';

  @override
  String get gameRedeemRewards => 'Fata ibihembo';

  @override
  String get gameRedeemRewardsDescription =>
      'Koresha amanota ku bihembo n’ibyo abafatanyabikorwa batanga';

  @override
  String get gameAchievements => 'Ibyagezweho';

  @override
  String get gameAchievementsDescription => 'Imidari n’iminsi wikurikiranya';

  @override
  String get gameShareCard => 'Ikarita yo gusangiza';

  @override
  String get gameShareCardDescription =>
      'Kora ikarita y’umufana yo gusangiza abandi';

  @override
  String get gameConnectBeforeJoiningRound =>
      'Huza interineti mbere yo kwinjira muri iki cyiciro.';

  @override
  String get gamePoolEntryFailed =>
      'Kwinjira muri iki cyiciro ntibyashoboye kwandikwa.';

  @override
  String gameOutcomeJoined(String outcome) {
    return '$outcome byinjiyemo.';
  }

  @override
  String gamePartnerSponsorsRound(String partner) {
    return '$partner atereye inkunga iki cyiciro. Hitamo rimwe mbere y’uko gifungwa.';
  }

  @override
  String get gameProjects => 'Imishinga';

  @override
  String get gameProjectsDescription =>
      'Ibikorwa bya kipe n’ibikenewe mu bukangurambaga';

  @override
  String get gameGroups => 'Amatsinda';

  @override
  String get gameGroupsDescription => 'Injira mu matsinda y’inkunga y’abafana';

  @override
  String get gameQrSheetDescription =>
      'Kwerekana no gusangiza QR biguma muri uru rupapuro.';

  @override
  String get gameFanIdQrDisplay => 'Fan ID no kwerekana QR';

  @override
  String get gameQr => 'QR';

  @override
  String get gameBadgesEarnedDescription =>
      'Yabonetse mu guhitamo, kwitabira no gushyigikira';

  @override
  String get gameStartStreak =>
      'Injira mu cyiciro gikurikira utangire iminsi ikurikirana';

  @override
  String gameActivePlayDays(int count) {
    return 'Iminsi $count yo gukina';
  }

  @override
  String gameActionUnavailable(String description) {
    return '$description. Ntibihari.';
  }

  @override
  String get gameFanZoneAccessUnavailable =>
      'Ntabwo wemerewe kugera muri Fan Zone';

  @override
  String get gameFanZoneAccessUnavailableDescription =>
      'Konti yawe ntishobora gufungura Fan Zone ubu. Hamagara ubufasha niba wagombye kubyemererwa.';

  @override
  String get gameFanZoneChanged => 'Fan Zone yahindutse';

  @override
  String get gameFanZoneChangedDescription =>
      'Amakuru ya Fan Zone yahindutse uyareba. Vugurura kugira ngo ubone agezweho.';

  @override
  String get gameFanZoneSecurityTimedOut =>
      'Kugenzura umutekano wa Fan Zone byarengeje igihe';

  @override
  String get gameFanZoneSecurityTimedOutDescription =>
      'Ntitwashoboye kwemeza ko ushobora kugera muri Fan Zone. Vugurura mbere yo gukomeza.';

  @override
  String get gameFanZoneTemporarilyUnavailable =>
      'Fan Zone ntiboneka by’agateganyo.';

  @override
  String get gameSavedFanZoneContent =>
      'Harerekanwa amakuru yabitswe. Ongera uhuze maze uvugurure kugira ngo ubone imikino n’amanota bigezweho.';

  @override
  String get gamePickSectionLabel => 'Hitamo';

  @override
  String get gamePicksLabel => 'Hitamo';

  @override
  String get gameRewardsLabel => 'Ibihembo';

  @override
  String get gameStreakLabel => 'Iminsi ikurikirana';

  @override
  String get gameBadgesLabel => 'Imidari';

  @override
  String get gamePointsLabel => 'Amanota';

  @override
  String get gameAccuracyLabel => 'Ukuri';

  @override
  String get gameFanZoneUnavailableTitle => 'Fan Zone ntiboneka';

  @override
  String get venueOrderConfirmedToast =>
      'Aho uri hemeje komande. Wishyure gusa aho uri.';

  @override
  String get venueOrderingUnavailable => 'Gutumiza aho uri ntibihari';

  @override
  String get venueFeatureDisabled =>
      'Iyi serivisi igenzurwa yahagaritswe kuri iyi kipe cyangwa iyi verisiyo.';

  @override
  String get venueBackToFanZone => 'Subira muri fan zone';

  @override
  String get venueOrderAccessDenied => 'Ntiwemerewe gutumiza';

  @override
  String get venueOrderAccessDeniedBody =>
      'Iyi konti ntishobora gukoresha inzira yo gutumiza y’abafana.';

  @override
  String get venueOrderAccessDeniedLoadBody =>
      'Iyi konti ntishobora gufungura inzira yo gutumiza y’abafana.';

  @override
  String get venueCheckInBeforeOrdering =>
      'Banza wiyandikishe mbere yo gutumiza';

  @override
  String get venueCheckInRequiredBody =>
      'Kwiyandikisha byemejwe birakenewe mbere yo gufungura urutonde rw’ibinyobwa byemewe.';

  @override
  String get venueCheckInFirst => 'Banza wiyandikishe';

  @override
  String get venueNoDrinksAvailable => 'Nta binyobwa bihari';

  @override
  String get venueNoDrinksBody =>
      'Aho wiyandikishije nta binyobwa byemewe bihari ubu.';

  @override
  String get venueRefreshMenu => 'Vugurura urutonde';

  @override
  String get venueMenuUnavailableOffline =>
      'Urutonde ntiruboneka nta interineti';

  @override
  String get venueMenuOfflineBody =>
      'Ongera uhuze mbere yo gufungura urutonde. Nta komande ibikwa ngo izoherezwe nyuma.';

  @override
  String get venueTryAgain => 'Ongera ugerageze';

  @override
  String get venueMenuCheckTimedOut => 'Kugenzura urutonde byarengeje igihe';

  @override
  String get venueMenuCheckTimedOutBody =>
      'Porogaramu ntiyashoboye gutegura uburyo butekanye bwo gutumiza ku gihe. Vugurura rimwe gusa.';

  @override
  String get venueMenuUnavailableBody =>
      'Aho wiyandikishije n’urutonde rwemewe ntibyashoboye gufungurwa mu buryo butekanye.';

  @override
  String get venueOrderHero => 'Tumiza ibinyobwa aho uri';

  @override
  String get venueOrderHeroBody =>
      'Hitamo mu binyobwa byemewe gusa. Ibikorwa by’abakozi biguma ku rubuga rw’aho uri.';

  @override
  String get venueApprovedDrinks => 'Ibinyobwa byemewe';

  @override
  String get venueOrderReview => 'Suzuma komande';

  @override
  String venueOrderReviewValue(int count, String total) {
    return 'Ibintu $count, $total';
  }

  @override
  String get venueLegalAgeConfirmation => 'Kwemeza imyaka yemewe';

  @override
  String get venueNotSelected => 'Ntibyatoranyijwe';

  @override
  String get venueAgeConfirmationRequired => 'Ugomba kwemeza imyaka';

  @override
  String get venueAgeConfirmationBody =>
      'Emeza gusa niba wujuje imyaka yemewe aho uri. Abakozi bashobora kongera kubigenzura.';

  @override
  String get venueRemoveConfirmation => 'Kuraho kwemeza';

  @override
  String get venueConfirmLegalAge => 'Emeza imyaka yemewe';

  @override
  String get venuePayAtVenue => 'Ishyura aho uri';

  @override
  String get venuePaymentDisclaimer =>
      'Iyi porogaramu ikora komande gusa. Ntiyakira ubwishyu kandi ntiyemeza ko bwakozwe.';

  @override
  String get venueCreatingOrderUpper => 'Kohereza komande';

  @override
  String get venueOrderConfirmedUpper => 'Komande yemejwe';

  @override
  String get venueReviewCreateOrder => 'Suzuma maze utumize';

  @override
  String get venueOrderProtections => 'Umutekano wa komande';

  @override
  String get venueDuplicateSubmission => 'Kohereza kabiri';

  @override
  String get venueDuplicateSubmissionBody =>
      'Kode imwe yihariye kuri buri kugerageza';

  @override
  String get venueOfflineBehavior => 'Iyo nta interineti';

  @override
  String get venueOfflineBehaviorBody =>
      'Nta kubika cyangwa kongera kohereza byikora';

  @override
  String get venueStaffControls => 'Igenzura ry’abakozi';

  @override
  String get venueStaffControlsBody => 'Ku rubuga rw’aho uri gusa';

  @override
  String venueItemsSelected(int count) {
    return 'Ibintu $count byatoranyijwe';
  }

  @override
  String get venueShowingSavedMenu => 'Harerekanwa urutonde rwabitswe';

  @override
  String get venueShowingSavedMenuBody =>
      'Ongera uhuze mbere yo gukora komande. Nta kibikwa cyangwa cyoherezwa nyuma.';

  @override
  String get venueCreatingOrder => 'Gukora komande';

  @override
  String get venueCreatingOrderBody =>
      'Tegereza ko seriveri ibyemeza. Ntukongere kohereza iyi komande.';

  @override
  String get venueOrderCreated => 'Komande yakozwe';

  @override
  String venueOrderCreatedSummary(String status, String total) {
    return '$status · $total. Ubwishyu bukorerwa aho uri.';
  }

  @override
  String get venueChooseDrink => 'Hitamo nibura ikinyobwa kimwe';

  @override
  String get venueChooseDrinkBody =>
      'Komande ntishobora gukorwa nta kintu cyatoranyijwe.';

  @override
  String get venueCheckInRequired => 'Kwiyandikisha birakenewe';

  @override
  String get venueCheckInRejectedBody =>
      'Aho uri ntihemera ko kwiyandikisha gukoreshwa mu gutumiza. Ongera wiyandikishe mbere yo kugerageza.';

  @override
  String get venueAgeSubmitBody =>
      'Emeza imyaka yemewe mbere yo kohereza ikinyobwa kirimo alukolo.';

  @override
  String get venueDrinkChanged => 'Ikinyobwa wahisemo cyahindutse';

  @override
  String get venueDrinkChangedBody =>
      'Vugurura urutonde rwemewe mbere yo kongera kugerageza.';

  @override
  String get venueOrderAttemptPaused => 'Kugerageza gutumiza byahagaze';

  @override
  String get venueOrderAttemptPausedBody =>
      'Hari ikindi gisabwa gishobora kuba kirimo gukorwa. Reba komande iheruka mbere yo kugerageza.';

  @override
  String get venueOrderConfirmationUncertain => 'Kwemeza komande ntibizwi neza';

  @override
  String get venueOrderConfirmationUncertainBody =>
      'Ntukongere kuyohereza. Reba komande iheruka mbere yo gufunga.';

  @override
  String get venueOrderNotConfirmed => 'Komande ntiyemejwe';

  @override
  String get venueOrderNotConfirmedBody =>
      'Seriveri ntiyemeje iyi komande. Funga umuburo mbere yo kongera kugerageza.';

  @override
  String venueLatestOrder(String status) {
    return 'Komande iheruka: $status';
  }

  @override
  String venueLatestOrderSummary(String total, String payment) {
    return '$total · $payment.';
  }

  @override
  String get venueReadyToOrder => 'Witeguye gutumiza';

  @override
  String get venueReadyToOrderBody =>
      'Hitamo ibinyobwa byemewe, suzuma igiteranyo, hanyuma wohereze rimwe.';

  @override
  String venueRemoveItem(String item) {
    return 'Kuraho $item';
  }

  @override
  String venueAddItem(String item) {
    return 'Ongeraho $item';
  }

  @override
  String venueDrinkSemantics(int count, String price) {
    return '$count byatoranyijwe, kimwe ni $price';
  }

  @override
  String get venueAgeRestricted => 'Kigenewe abafite imyaka yemewe';

  @override
  String get venueWaitingForVenue => 'Gutegereza aho uri';

  @override
  String get venueAccepted => 'Yemewe';

  @override
  String get venuePreparing => 'Irategurwa';

  @override
  String get venueReadyForPickup => 'Yiteguye gufatwa';

  @override
  String get venueServed => 'Yatanzwe';

  @override
  String get venueStatusPending => 'Imiterere irategerejwe';

  @override
  String get venuePaidAtVenue => 'Yishyuriwe aho uri';

  @override
  String get venuePaymentWaived => 'Ubwishyu bwakuweho';

  @override
  String get venueRefundedExternally => 'Yasubijwe ahandi';

  @override
  String get venuePaymentPending => 'Ubwishyu burategerejwe aho uri';

  @override
  String get venueCheckinTitle => 'Kwiyandikisha aho uri';

  @override
  String get venueCheckinUnavailable => 'Kwiyandikisha aho uri ntibihari';

  @override
  String get venueCheckinAccessDenied => 'Ntiwemerewe kwiyandikisha';

  @override
  String get venueCheckinAccessDeniedBody =>
      'Iyi konti ntishobora gukoresha inzira yo kwiyandikisha y’abafana.';

  @override
  String get venueCheckinSafeStateBody =>
      'Inzira ntiyashoboye gutegura uburyo butekanye bwo kwiyandikisha.';

  @override
  String get venueCheckinHero => 'Iyandikishe ahantu hemewe';

  @override
  String get venueCheckinHeroBody =>
      'Injiza kode ihinduka y’aho uri cyangwa QR umaze kuhagera. Kwiyandikisha kw’abafana ntikwerekana igenzura ry’abakozi cyangwa abayobozi.';

  @override
  String get venueCheckinCodeLabel => 'Kode y’aho uri';

  @override
  String get venueCheckinInputLabel => 'Kode y’aho uri cyangwa QR';

  @override
  String get venueCheckinInputHint => 'Injiza nibura inyuguti 4';

  @override
  String get venueCheckinCheckingCodeUpper => 'Kugenzura kode';

  @override
  String get venueCheckinActionUpper => 'Iyandikishe';

  @override
  String get venueCheckinLocationConsentSemantics =>
      'Kwemera ko aho uri hasuzumwa';

  @override
  String get venueCheckinOptionalLocationReview =>
      'Gusuzuma aho uri bitari itegeko';

  @override
  String get venueCheckinConsentMarkedBody =>
      'Kwemera byashyizwe kuri uku kugerageza. Iyi verisiyo nta biranga aho uri yohereza; kampanye zisaba aho uri ziracyategereje gusuzumwa.';

  @override
  String get venueCheckinNoLocationBody =>
      'Aho uri nyakuri ntihakusanywa muri iyi verisiyo. Ushobora kwemera, ariko kampanye zisaba aho uri ziracyategereje gusuzumwa.';

  @override
  String get venueCheckinRemoveConsentUpper => 'Kuraho kwemera';

  @override
  String get venueCheckinMarkConsentUpper => 'Emera';

  @override
  String get venueCheckinPrivacyBoundary => 'Imbibi z’ibanga';

  @override
  String get venueCheckinPrivacyBoundaryBody =>
      'Kode zihinduka zihishwa mbere yo koherezwa kandi porogaramu ntizibika. Aho uri nyakuri ntihakusanywa.';

  @override
  String get venueCheckinPausedOffline =>
      'Kwiyandikisha byahagaze nta interineti';

  @override
  String get venueCheckinPausedOfflineBody =>
      'Ongera uhuze mbere yo kohereza. Nta kwiyandikisha kubikwa cyangwa kongera koherezwa.';

  @override
  String get venueCheckinCheckingCode => 'Kugenzura kode y’aho uri';

  @override
  String get venueCheckinCheckingCodeBody =>
      'Tegereza igisubizo cya seriveri. Ntukongere kwiyandikisha.';

  @override
  String get venueCheckinPendingReview => 'Kwiyandikisha gutegereje gusuzumwa';

  @override
  String get venueCheckinConfirmed => 'Kwiyandikisha byemejwe';

  @override
  String get venueCheckinPendingReviewBody =>
      'Kode y’aho uri yemewe, ariko igenzura ry’aho uri cyangwa rya kampanye riracyakenewe.';

  @override
  String venueCheckinFetRecorded(int count) {
    return 'FET +$count zanditswe kuri uku kwiyandikisha.';
  }

  @override
  String get venueCheckinConfirmedNoReward =>
      'Aho uri hemeje kwiyandikisha. Nta gihembo cyari cyasezeranywe.';

  @override
  String get venueCheckinReady => 'Witeguye kwiyandikisha aho uri';

  @override
  String get venueCheckinReadyBody => 'Koresha kode iriho gusa umaze kuhagera.';

  @override
  String get venueCheckinInvalidCode => 'Kode ntiyemewe';

  @override
  String get venueCheckinInvalidCodeBody =>
      'Injiza kode iriho y’aho uri cyangwa QR yerekanwa aho uri.';

  @override
  String get venueCheckinExpiredCode => 'Kode y’aho uri yararengeje igihe';

  @override
  String get venueCheckinExpiredCodeBody =>
      'Reba kuri ekara y’aho uri kode ihinduka iriho.';

  @override
  String get venueCheckinAlreadyCheckedIn => 'Wamaze kwiyandikisha';

  @override
  String get venueCheckinAlreadyCheckedInBody =>
      'Seriveri yabonye ko wamaze kwiyandikisha. Nta gihembo cyikubye kabiri cyakozwe.';

  @override
  String get venueCheckinCampaignUnavailable =>
      'Kampanye yo kwiyandikisha ntiboneka';

  @override
  String get venueCheckinCampaignUnavailableBody =>
      'Kampanye yarahagaze, ntikora cyangwa yageze ku ngengo y’imari yagenwe.';

  @override
  String get venueCheckinConflict => 'Kwiyandikisha kurimo kwivuguruza';

  @override
  String get venueCheckinConflictBody =>
      'Hari ukundi kugerageza gushobora kuba gukorwa. Emeza uko aho uri hameze mbere yo kongera kugerageza.';

  @override
  String get venueCheckinConfirmationUncertain =>
      'Kwemeza kwiyandikisha ntibizwi neza';

  @override
  String get venueCheckinConfirmationUncertainBody =>
      'Ntukongere kode ubu. Reba ibikorwa byawe by’aho uri, hanyuma ufunge uyu muburo.';

  @override
  String get venueCheckinUnavailableShort => 'Kwiyandikisha ntibihari';

  @override
  String get venueCheckinUnavailableBody =>
      'Seriveri ntiyemeje uku kugerageza. Funga umuburo mbere yo kongera kugerageza.';

  @override
  String get walletRewardsUnavailable => 'Ibihembo ntibiboneka';

  @override
  String get walletDisabledBody =>
      'Amanota n’ibikorwa by’ibihembo byahagaritswe kuri iyi verisiyo.';

  @override
  String get walletNoActivity => 'Nta bikorwa by’amanota birabaho';

  @override
  String get walletNoActivityBody =>
      'Amanota yawe yemejwe n’ibikorwa by’ibihembo bizagaragara hano.';

  @override
  String get walletOffline => 'Ibihembo nta interineti';

  @override
  String get walletOfflineBody =>
      'Ongera uhuze ufungure amanota yemejwe. Nta kibikwa ngo kizoherezwe nyuma.';

  @override
  String get walletAccessDenied => 'Ntiwemerewe kugera ku bihembo';

  @override
  String get walletAccessDeniedBody =>
      'Iyi konti ntishobora gufungura igitabo cyihariye cy’amanota.';

  @override
  String get walletCheckTimedOut => 'Kugenzura amanota byarengeje igihe';

  @override
  String get walletCheckTimedOutBody =>
      'Porogaramu ntiyashoboye kwemeza igitabo cyawe cy’amanota ku gihe. Vugurura rimwe gusa.';

  @override
  String get walletUnavailableBody =>
      'Igitabo cy’amanota nticyashoboye gufungurwa. Nta bikorwa byihariye byerekanwe.';

  @override
  String walletBalanceValue(String points) {
    return 'Amanota $points';
  }

  @override
  String get walletUsed => 'Yakoreshejwe';

  @override
  String walletHistoricalPoints(String points) {
    return 'Amanota $points yavuye mu bihembo bya mbere amateka y’ibikorwa atarafungurwa.';
  }

  @override
  String get walletEarn => 'Kubona';

  @override
  String get walletEarnBody =>
      'Bona amanota mu bikorwa no kwamamaza by’abafatanyabikorwa.';

  @override
  String get walletUseBody =>
      'Koresha amanota ku bihembo, ibikorwa by’umunsi w’umukino no guhiganwa muri Fan Zone.';

  @override
  String get walletRewardsBody =>
      'Koresha amanota ku nyungu z’umunsi w’umukino n’ibihembo by’abafatanyabikorwa.';

  @override
  String get walletRewardsEmptyBody =>
      'Ibihembo biboneka bizagaragara hano kipe cyangwa abafatanyabikorwa babishyizeho.';

  @override
  String get walletActivityEmptyBody =>
      'Ibikorwa by’amanota bigaragara nyuma y’ibihembo cyangwa ibikorwa by’umukino.';

  @override
  String get walletShowingSaved => 'Harerekanwa amanota yabitswe';

  @override
  String get walletShowingSavedBody =>
      'Ongera uhuze urebe amanota n’ibikorwa bigezweho. Nta gikorwa kibikwa.';

  @override
  String get walletRefreshing => 'Kuvugurura amanota';

  @override
  String get walletRefreshingBody =>
      'Amanota yemejwe akomeza kugaragara mu gihe igitabo kivugururwa.';

  @override
  String get walletChangedElsewhere => 'Amanota yahindutse ahandi';

  @override
  String get walletChangedElsewhereBody =>
      'Amanota yabitswe arakomeza kugaragara. Vugurura wemeze igitabo gishya.';

  @override
  String get walletRefreshTimedOut => 'Kuvugurura amanota byarengeje igihe';

  @override
  String get walletRefreshTimedOutBody =>
      'Amanota yabitswe aracyagaragara. Vugurura rimwe gusa.';

  @override
  String get walletMayBeOutdated => 'Amanota ashobora kuba atakigezweho';

  @override
  String get walletMayBeOutdatedBody =>
      'Amanota aheruka kwemezwa arakomeza kugaragara serivisi itaboneka.';

  @override
  String get walletSavedUntilRefresh =>
      'Amanota aheruka kwemezwa arakomeza kugaragara kugeza kuvugurura bikunze.';

  @override
  String get gameShareOptionsClosed =>
      'Amahitamo yo gusangiza yafunzwe. Emeza aho wohereza mbere yo gutangaza.';

  @override
  String get gameShareActionsUnavailable => 'Gusangiza ntibishoboka';

  @override
  String get gameShareActionsUnavailableDescription =>
      'Ushobora gusubira muri Fan Zone, ariko gusangiza ntibikora muri iyi verisiyo.';

  @override
  String get gameBackToFanZoneUpper => 'Subira muri fan zone';

  @override
  String get gamePredictionAccessDenied => 'Ntiwemerewe kureba ibyo wahisemo';

  @override
  String get gamePredictionAccessDeniedDescription =>
      'Iyi konti ntishobora gufungura amateka y’ibyo wahisemo kugira ngo bisangizwe.';

  @override
  String get gameMakePickFirst => 'Banza uhitemo';

  @override
  String get gameShareCardsUnlock =>
      'Amakarita yo gusangiza aboneka nyuma yo guhitamo umukino w’umunsi.';

  @override
  String get gameBackToPicksUpper => 'Subira ku byo wahisemo';

  @override
  String get gameShareCardsOffline => 'Amakarita yo gusangiza nta interineti';

  @override
  String get gameShareCardsOfflineDescription =>
      'Ongera uhuze kugira ngo ubone amateka y’ibyo wahisemo byemejwe. Nta kintu gitegereza koherezwa nta interineti.';

  @override
  String get gameHistoryCheckTimedOut => 'Kugenzura amateka byarengeje igihe';

  @override
  String get gameHistoryCheckTimedOutDescription =>
      'Porogaramu ntiyashoboye kwemeza amateka yizewe y’ibyo wahisemo ku gihe. Gerageza kuvugurura rimwe.';

  @override
  String get gameTryAgainUpper => 'Ongera ugerageze';

  @override
  String get gameShareCardsUnavailable => 'Amakarita yo gusangiza ntaboneka';

  @override
  String get gameShareCardsUnavailableDescription =>
      'Amateka y’ibyo wahisemo ntiyashoboye gufunguka. Nta makuru y’ibikorwa byawe yerekanwe.';

  @override
  String get gameShowingSavedShareCard => 'Harerekanwa ikarita yabitswe';

  @override
  String get gameShowingSavedShareCardDescription =>
      'Ongera uhuze mbere yo gusangiza cyangwa gukoporora. Nta gikorwa gitegereza gukorwa nta interineti.';

  @override
  String get gameCopyingShareText => 'Harakopororwa amagambo yo gusangiza';

  @override
  String get gameOpeningShareOptions => 'Harafungurwa amahitamo yo gusangiza';

  @override
  String get gameShareAwaitPlatformConfirmation =>
      'Tegereza ko urubuga rwemeza. Ntusubiremo iki gikorwa.';

  @override
  String get gameShareActionPaused => 'Gusangiza byahagaritswe';

  @override
  String get gameShareActionPausedDescription =>
      'Hari ikindi gikorwa cyari gisanzwe gikora. Banza urebe aho urubuga rugeze mbere yo gukomeza.';

  @override
  String get gameShareConfirmationUncertain =>
      'Kwemeza gusangiza ntibisobanutse';

  @override
  String get gameShareConfirmationUncertainDescription =>
      'Reba urupapuro rwo gusangiza cyangwa ububiko bw’ibyakoporowe, hanyuma ufunge iri burira mbere yo kongera kugerageza.';

  @override
  String get gameShareActionUnavailable => 'Igikorwa cyo gusangiza ntikiboneka';

  @override
  String get gameShareActionUnavailableDescription =>
      'Urubuga ntirwarangije igikorwa. Funga iri burira mbere yo kongera kugerageza.';

  @override
  String get gameUsingSavedPredictionHistory =>
      'Harakoreshwa amateka yabitswe y’ibyo wahisemo';

  @override
  String get gameUsingSavedPredictionHistoryDescription =>
      'Vugurura iyi paji mbere yo gufungura ikindi gikorwa cyo gusangiza.';

  @override
  String get gameBackToPicks => 'Subira ku byo wahisemo';

  @override
  String get gameChoosePick => 'Hitamo';

  @override
  String gameSharePredictionSemantics(
    String home,
    String away,
    String market,
    String outcome,
  ) {
    return '$home na $away, $market, $outcome';
  }

  @override
  String gameShareMarketSelection(String market, String selection) {
    return '$market · $selection';
  }

  @override
  String get gameCurrentlySelectedShareCard =>
      'Ikarita yo gusangiza yatoranyijwe ubu';

  @override
  String get gameSelectThisShareCard => 'Hitamo iyi karita yo gusangiza';

  @override
  String get gamePredictionPickCancelled => 'Ihanura ryahagaritswe.';

  @override
  String get gamePredictionSummaryCopied => 'Incamake y’igikorwa yakoporowe.';

  @override
  String get gamePredictionScorePending => 'itegerejwe';

  @override
  String gamePredictionSummaryClipboard(
    String home,
    String away,
    String market,
    String outcome,
    String score,
  ) {
    return '$home na $away · $market · $outcome · $score';
  }

  @override
  String get gamePredictionStatusWon => 'Watsinze';

  @override
  String get gamePredictionStatusLost => 'Watsinzwe';

  @override
  String get gamePredictionStatusCancelled => 'Ryahagaritswe';

  @override
  String get gamePredictionStatusVoid => 'Ryateshejwe agaciro';

  @override
  String get gamePredictionStatusPending => 'Rirategereje';

  @override
  String get gamePredictionDateTbd => 'Birategerejwe';

  @override
  String gamePredictionDateTime(String date, String time) {
    return '$date • $time';
  }

  @override
  String gamePredictionWonSettlement(int count) {
    return 'Iri hanura ryemejwe kandi wongerewe amanota $count.';
  }

  @override
  String get gamePredictionLostSettlement =>
      'Iri hanura ntiryemejwe ku ruhande rwawe.';

  @override
  String gamePredictionOfficialOutcomeMessage(String outcome) {
    return 'Igisubizo cyemewe: $outcome.';
  }

  @override
  String get gamePredictionCancelledSettlement =>
      'Iri hanura ryahagaritswe umukino utarafungwa.';

  @override
  String get gamePredictionVoidSettlement =>
      'Iri hanura ryateshejwe agaciro kandi nta manota yatanzwe.';

  @override
  String get gamePredictionPendingSettlement =>
      'Iri hanura ryarafunzwe kandi rizemezwa ibisubizo byemewe nibiboneka.';

  @override
  String get gamePredictionActivityNotFound => 'Igikorwa nticyabonetse';

  @override
  String get gamePredictionActivityNotFoundDescription =>
      'Iri hanura rishobora kuba ryarangiye, ryarakuweho cyangwa ritakiboneka kuri konti yawe.';

  @override
  String get gamePredictionBackToPredictions => 'Subira ku ihanura';

  @override
  String get gamePredictionCancellingPick => 'Guhagarika ihanura';

  @override
  String get gamePredictionRefreshingActivity => 'Kuvugurura igikorwa';

  @override
  String get gamePredictionConfirmedPickVisible =>
      'Ihanura ryemejwe rirakomeza kugaragara mu gihe imiterere mishya igenzurwa.';

  @override
  String get gamePredictionActionsUnavailable => 'Ibikorwa ntibiboneka';

  @override
  String get gamePredictionCancellationDisabled =>
      'Ushobora kureba iri hanura, ariko kurihagarika ntibyemewe muri iyi verisiyo.';

  @override
  String get gamePredictionShowingSavedActivity =>
      'Kwerekana igikorwa cyabitswe';

  @override
  String get gamePredictionReconnectBeforeCancelling =>
      'Ongera uhuze kandi uvugurure mbere yo guhagarika iri hanura.';

  @override
  String get gamePredictionActivityDetailTitle => 'Ibisobanuro by’igikorwa';

  @override
  String gamePredictionShortTeams(String home, String away) {
    return '$home  •  $away';
  }

  @override
  String get gamePredictionVenueTbc => 'Ahabera umukino harategerejwe';

  @override
  String get gamePredictionPickType => 'Ubwoko bw’ihanura';

  @override
  String get gamePredictionSelection => 'Icyahiswemo';

  @override
  String get gamePredictionEarned => 'Yabonetse';

  @override
  String get gamePredictionPotential => 'Ashoboka';

  @override
  String gamePredictionPositiveValue(int count) {
    return '+$count';
  }

  @override
  String get gamePredictionSettlement => 'Kwemeza';

  @override
  String get gamePredictionPlaced => 'Ryashyizweho';

  @override
  String get gamePredictionKickoff => 'Gutangira';

  @override
  String get gamePredictionSettled => 'Ryemejwe';

  @override
  String get gamePredictionOfficialOutcome => 'Igisubizo cyemewe';

  @override
  String get gamePredictionCancelPick => 'Hagarika ihanura';

  @override
  String get gamePredictionCopyResult => 'Koporora igisubizo';

  @override
  String get gamePredictionCopySummary => 'Koporora incamake';

  @override
  String get gamePredictionShareCard => 'Sangiza ikarita';

  @override
  String get gamePredictionBrowseFixtures => 'Reba imikino';

  @override
  String get gamePredictionRefreshActivity => 'Vugurura igikorwa';

  @override
  String get gamePredictionConnectionRestored => 'Umuyoboro wongeye kuboneka';

  @override
  String get gamePredictionDetailsOffline =>
      'Ibisobanuro ntibiri kuri interineti';

  @override
  String get gamePredictionRefreshBeforeCancelling =>
      'Vugurura kugira ngo wemeze ihanura mbere yo kurihagarika.';

  @override
  String get gamePredictionReconnectToConfirm =>
      'Ongera uhuze kugira ngo wemeze ihanura mbere yo kurihagarika.';

  @override
  String get gamePredictionAccessUnavailable => 'Kugera ku gikorwa ntibiboneka';

  @override
  String get gamePredictionAccessUnavailableDescription =>
      'Konti yawe ntishobora kureba cyangwa guhindura iki gikorwa.';

  @override
  String get gamePredictionDataChanged => 'Amakuru y’igikorwa yarahindutse';

  @override
  String get gamePredictionDataChangedDescription =>
      'Vugurura mbere yo kureba igisubizo cyangwa guhagarika iri hanura.';

  @override
  String get gamePredictionSecurityTimeout =>
      'Igenzura ry’umutekano ryarengeje igihe';

  @override
  String get gamePredictionSecurityTimeoutDescription =>
      'Nta guhagarika kwemejwe. Vugurura mbere yo kongera kugerageza.';

  @override
  String get gamePredictionUnavailable => 'Igikorwa ntikiboneka';

  @override
  String get gamePredictionUnavailableDescription =>
      'Ibisobanuro bishya by’ihanura ntibyemejwe. Vugurura wongere ugerageze.';

  @override
  String gamePredictionSelectedMetricSemantics(String label, String value) {
    return '$label $value, byatoranyijwe';
  }

  @override
  String gamePredictionMetricSemantics(String label, String value) {
    return '$label $value';
  }

  @override
  String get gameMatchTitle => 'Umukino';

  @override
  String get gameBackToFanZoneTitleCase => 'Subira muri Fan Zone';

  @override
  String get gameMatchNotFound => 'Umukino ntiwabonetse';

  @override
  String get gameMatchNotFoundDescription =>
      'Uyu mukino ushobora kuba wararangiye, warakuweho cyangwa utakiboneka.';

  @override
  String get gameWeekdayMon => 'Mbe';

  @override
  String get gameWeekdayTue => 'Kab';

  @override
  String get gameWeekdayWed => 'Gat';

  @override
  String get gameWeekdayThu => 'Kan';

  @override
  String get gameWeekdayFri => 'Gat';

  @override
  String get gameWeekdaySat => 'Gat';

  @override
  String get gameWeekdaySun => 'Cya';

  @override
  String get gameMonthJan => 'Mut';

  @override
  String get gameMonthFeb => 'Gas';

  @override
  String get gameMonthMar => 'Wer';

  @override
  String get gameMonthApr => 'Mat';

  @override
  String get gameMonthMay => 'Gic';

  @override
  String get gameMonthJun => 'Kam';

  @override
  String get gameMonthJul => 'Nya';

  @override
  String get gameMonthAug => 'Kan';

  @override
  String get gameMonthSep => 'Nze';

  @override
  String get gameMonthOct => 'Ukw';

  @override
  String get gameMonthNov => 'Ugu';

  @override
  String get gameMonthDec => 'Uku';

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
  String get gamePoolsTab => 'Ibigega';

  @override
  String get gameStatsTab => 'Imibare';

  @override
  String get gameH2hTab => 'Guhura';

  @override
  String get gameLineupsTab => 'Abakinnyi';

  @override
  String gameMatchTeamsVs(String home, String away) {
    return '$home na $away';
  }

  @override
  String get gamePartnerPoolsTooltip => 'Ibigega by’abafatanyabikorwa';

  @override
  String get gameJoiningPartnerPool =>
      'Kwinjira mu kigega cy’umufatanyabikorwa';

  @override
  String get gameRefreshingMatch => 'Kuvugurura umukino';

  @override
  String get gameConfirmedMatchVisible =>
      'Umukino wemejwe urakomeza kugaragara mu gihe imiterere mishya igenzurwa.';

  @override
  String get gameMatchActionsUnavailable => 'Ibikorwa by’umukino ntibiboneka';

  @override
  String get gameMatchActionsUnavailableDescription =>
      'Ushobora kureba uyu mukino, ariko kwinjira mu bigega by’abafatanyabikorwa ntibyemewe muri iyi verisiyo.';

  @override
  String get gameShowingSavedMatch => 'Kwerekana umukino wabitswe';

  @override
  String get gameReconnectBeforePartnerPool =>
      'Ongera uhuze kandi uvugurure mbere yo kwinjira mu kigega cy’umufatanyabikorwa.';

  @override
  String get gameVsUpper => 'VS';

  @override
  String get gamePartnerOutcomeHomeWin => 'Abakiriye baratsinda';

  @override
  String get gamePartnerOutcomeDraw => 'Kunganya';

  @override
  String get gamePartnerOutcomeAwayWin => 'Abasuye baratsinda';

  @override
  String get gamePartnerOutcomeUnknown => 'Ntibizwi';

  @override
  String get gamePartnerEarnRequired =>
      'Gukorera ku mufatanyabikorwa birakenewe';

  @override
  String get gamePromotionEarnRequired => 'Gukorera muri poromosiyo birakenewe';

  @override
  String get gameOpenToAllFans => 'Bifunguye ku bafana bose';

  @override
  String get gamePoolJoinOffline =>
      'Ongera uhuze kandi uvugurure mbere yo kwinjira muri iki kigega.';

  @override
  String get gamePoolJoinPermissionDenied =>
      'Konti yawe ntishobora kwinjira mu kigega cy’umufatanyabikorwa.';

  @override
  String get gamePoolJoinConflict =>
      'Iki kigega cyarahindutse cyangwa cyarafunzwe. Vugurura mbere yo kongera kugerageza.';

  @override
  String get gamePoolJoinTimeout =>
      'Nta kwinjira kwemejwe. Vugurura mbere yo kongera kugerageza.';

  @override
  String get gamePoolJoinUnavailable =>
      'Kwinjira mu kigega ntikwashoboye kwemezwa.';

  @override
  String get gameRefreshMatch => 'Vugurura umukino';

  @override
  String get gameMatchConnectionRestored => 'Umuyoboro wongeye kuboneka';

  @override
  String get gameMatchDetailsOffline =>
      'Ibisobanuro by’umukino ntibiri kuri interineti';

  @override
  String get gameRefreshBeforeJoiningPool =>
      'Vugurura kugira ngo wemeze umukino mbere yo kwinjira mu kigega.';

  @override
  String get gameReconnectBeforeJoiningPool =>
      'Ongera uhuze kugira ngo wemeze umukino mbere yo kwinjira mu kigega.';

  @override
  String get gameMatchAccessUnavailable => 'Kugera ku mukino ntibiboneka';

  @override
  String get gameMatchAccessUnavailableDescription =>
      'Konti yawe ntishobora kureba uyu mukino.';

  @override
  String get gameMatchDataChanged => 'Amakuru y’umukino yarahindutse';

  @override
  String get gameMatchDataChangedDescription =>
      'Vugurura mbere yo kwinjira mu kigega cyangwa kureba imiterere iriho.';

  @override
  String get gameMatchSecurityTimeout =>
      'Igenzura ry’umutekano w’umukino ryarengeje igihe';

  @override
  String get gameMatchSecurityTimeoutDescription =>
      'Nta kwinjira mu kigega kwemejwe. Vugurura mbere yo kongera kugerageza.';

  @override
  String get gameMatchUnavailable => 'Umukino ntuboneka';

  @override
  String get gameMatchUnavailableDescription =>
      'Ibisobanuro bishya by’umukino ntibyashoboye kwemezwa. Vugurura wongere ugerageze.';

  @override
  String get gamePartnerWdwPools => 'Ibigega WDW by’abafatanyabikorwa';

  @override
  String get gameNoPartnerPool =>
      'Nta kigega cy’umufatanyabikorwa kuri uyu mukino';

  @override
  String get gameNoPartnerPoolDescription =>
      'Guhanura umupira bifunguka gusa iyo umufatanyabikorwa yashyizeho ikigega WDW gifite igiciro gihamye kuri uyu mukino.';

  @override
  String get gameViewFanZone => 'Reba Fan Zone';

  @override
  String gamePartnerPoolsOnly(String home, String away) {
    return '$home na $away bakoresha gusa ibigega WDW byatewe inkunga n’abafatanyabikorwa.';
  }

  @override
  String get settingsThemePreview => 'Reba insanganyamatsiko';

  @override
  String get settingsApplyTheme => 'Koresha';

  @override
  String get predictTitle => 'Predict';

  @override
  String get predictIntro => 'Hitamo uko umukino urangira. Uhitamo rimwe gusa.';

  @override
  String get predictFixtures => 'Imikino';

  @override
  String get predictHistory => 'Ibyo nahisemo';

  @override
  String get predictWallet => 'Ibyakozwe na FET';

  @override
  String get predictDraw => 'Kunganya';

  @override
  String get predictAll => 'Amarushanwa yose';

  @override
  String get predictEmpty => 'Nta mikino ifunguye';

  @override
  String get predictEmptyBody =>
      'Imikino yateguwe igaragara hano mbere yo gutangira.';

  @override
  String get predictNoHistory => 'Ibyo wahisemo bizagaragara hano';

  @override
  String get predictNoActivity => 'Nta bikorwa bya FET birabaho';

  @override
  String get predictUnavailable => 'Predict ntiyabashije kuvugururwa';

  @override
  String get predictRefresh => 'Vugurura';

  @override
  String get predictLoading => 'Imikino irimo gutegurwa';

  @override
  String get predictDisabled => 'Predict ntirafungurwa';

  @override
  String get predictSignIn => 'Injira kugira ngo uhitemo';

  @override
  String get predictOffline =>
      'Jya kuri interineti kugira ngo uvugurure cyangwa uhitemo.';

  @override
  String get predictClosed => 'Uyu mukino warafunzwe. Vugurura urutonde.';

  @override
  String get predictAlreadyEntered =>
      'Wamaze guhitamo kuri uyu mukino. Vugurura ubone ibyo wahisemo.';

  @override
  String get predictInsufficient => 'Nta FET zihagije ufite zo kwitabira.';

  @override
  String get predictUncertain =>
      'Kwitabira kwawe ntikwemejwe. Vugurura mbere yo kongera kugerageza.';

  @override
  String get predictPending => 'Ibyo wahisemo birimo kwemezwa…';

  @override
  String get predictPicked => 'Byahiswemo';

  @override
  String get predictWon => 'Watsinze';

  @override
  String get predictLost => 'Byarangiye';

  @override
  String get predictRefunded => 'Byasubijwe';

  @override
  String get predictLocked => 'Byafunzwe';

  @override
  String get predictRules =>
      'Kwitabira birangira umukino utangiye. Abahisemo neza bagabana FET zose. Iyo nta watsinze cyangwa umukino uhagaritswe, FET zirasubizwa. FET si amafaranga.';

  @override
  String get predictWelcome => 'FET zo gutangira';

  @override
  String get predictEntry => 'Kwitabira Predict';

  @override
  String get predictPayout => 'FET watsindiye';

  @override
  String get predictRefund => 'FET zasubijwe';

  @override
  String get predictActivity => 'Igikorwa cya FET';

  @override
  String get predictAdminTitle => 'Ubuyobozi bwa Predict';

  @override
  String get predictAdminIntro =>
      'Tegura imikino, wemeze ibyavuyemo, utange cyangwa usubize FET.';

  @override
  String get predictAdminSettings => 'Igenamiterere';

  @override
  String get predictAdminEnabled => 'Fungura Predict';

  @override
  String get predictAdminEntryPrice => 'FET zo kwitabira';

  @override
  String get predictAdminSave => 'Bika igenamiterere';

  @override
  String get predictAdminAll => 'Imikino yose';

  @override
  String get predictAdminNoPool => 'Ntirategurwa';

  @override
  String get predictAdminOpen => 'Ifunguye';

  @override
  String get predictAdminLocked => 'Yafunzwe';

  @override
  String get predictAdminSettled => 'Yishyuwe';

  @override
  String get predictAdminRefunded => 'Yasubijwe';

  @override
  String get predictAdminPrepare => 'Tegura umukino';

  @override
  String get predictAdminConfirm => 'Emeza ibyavuyemo';

  @override
  String get predictAdminSettle => 'Tanga FET';

  @override
  String get predictAdminRefund => 'Hagarika usubize FET';

  @override
  String get predictAdminSource => 'Urubuga rwemewe rw’amakuru';

  @override
  String get predictAdminReason => 'Impamvu yo gusubiza FET';

  @override
  String get predictAdminCancel => 'Reka';

  @override
  String get predictAdminFailed =>
      'Impinduka ntizemejwe. Vugurura urutonde mbere yo kongera kugerageza.';

  @override
  String get predictAdminDenied => 'Uburenganzira bw’ubuyobozi burakenewe';

  @override
  String get predictAdminEmpty => 'Nta mikino yo gucunga';

  @override
  String get predictAdminPriceNote =>
      'Igiciro gishya kireba imikino izategurwa. Kwitabira bifungwa umukino utangiye.';

  @override
  String get predictAdminTotals => 'Abitabiriye / FET zinjiye / Izatanzwe';

  @override
  String get predictAdminConfirmBody =>
      'Banza ugenzure ibitego byemewe mbere yo kubyemeza.';

  @override
  String get predictAdminSettleBody =>
      'Gabanganya FET zose abahisemo neza. Niba ntawe, zisubize abitabiriye bose.';
}
