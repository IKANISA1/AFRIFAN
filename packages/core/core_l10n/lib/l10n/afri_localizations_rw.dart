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

  @override
  String tvAppTitle(String appName) {
    return '$appName TV';
  }

  @override
  String tvBrandMarkSemantic(String clubName) {
    return 'Ikirango cya TV cya $clubName';
  }

  @override
  String get tvPairThisDisplay => 'Huza iyi televiziyo';

  @override
  String get tvPairingCodeLabel => 'Kode yo guhuza ikoreshwa rimwe';

  @override
  String get tvPairingCodeHelper => 'Inyuguti 6–12';

  @override
  String get tvPairingInProgress => 'Birimo guhuzwa…';

  @override
  String get tvPairDisplayAction => 'Huza televiziyo';

  @override
  String get tvSessionCodeInstruction => 'Shyira iyi kode muri Fan Zone';

  @override
  String tvSessionCodeSemantic(String code) {
    return 'Kode y’icyicaro cya TV: $code';
  }

  @override
  String tvFetRewardLabel(int reward) {
    return 'Igihembo cya FET $reward';
  }

  @override
  String tvExpiresLabel(String expiry) {
    return 'Birarangira $expiry';
  }

  @override
  String get tvExpired => 'byararangiye';

  @override
  String get tvExpiresLessThanOneMinute => 'mu gihe kiri munsi y’umunota';

  @override
  String tvExpiresMinutes(int minutes) {
    return 'mu minota $minutes';
  }

  @override
  String tvExpiresHoursMinutes(int hours, int minutes) {
    return 'mu masaha $hours n’iminota $minutes';
  }

  @override
  String get tvVenueSessionDetails => 'Amakuru y’icyicaro cy’ahabera';

  @override
  String get tvVenueSessionOnly => 'Icyicaro cy’ahabera gusa';

  @override
  String get tvNoSupporterDetails => 'Nta makuru y’umufana agaragazwa';

  @override
  String get tvPairingStatusAndExpiry =>
      'Imimerere yo guhuza n’igihe birangirira';

  @override
  String get tvDefaultPairingPrompt =>
      'Huza iyi televiziyo ukoresheje urutonde rw’ubuyobozi.';

  @override
  String get tvOfflinePhase => 'Nta murongo';

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
  String get authPhoneHint => '+250 7xx xxx xxx';

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
  String get fanClubBackToSupporters => 'SUBIRA KU BAFANA';

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
  String get fanClubActive => 'IRAKORA';

  @override
  String get fanClubPendingReview => 'ITEGEREJE KWEMEZWA';

  @override
  String fanClubCurrentSemantic(String name) {
    return 'Fan club uri kureba, $name';
  }

  @override
  String get fanClubAboutTitle => 'IBYEREKEYE IYI CLUB';

  @override
  String fanClubRegionValue(String region) {
    return 'Akarere: $region';
  }

  @override
  String get fanClubSnapshotTitle => 'INCAMAKE Y’ITSINDA';

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
  String get fanClubRefreshAction => 'VUGURURA CLUB';

  @override
  String get fanClubTryAgainAction => 'ONGERA UGERAGEZE';

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
  String get fanClubMatchdayAgenda => 'GAHUNDA Y’UMUNSI W’UMUKINO';

  @override
  String fanClubMatchMeta(String competition, String venue) {
    return '$competition  •  $venue';
  }

  @override
  String fanClubMatchSchedule(String date, String time) {
    return '$date  •  $time';
  }

  @override
  String get fanClubMembersLabel => 'ABANYAMURYANGO';

  @override
  String get fanClubStatusLabel => 'IMITERERE';

  @override
  String get fanClubRegionLabel => 'AKARERE';

  @override
  String get fanClubOpenSupportersSemantic => 'Fungura igice cy’Abafana';

  @override
  String get fanClubPendingReviewSemantic => 'Fan club itegereje kwemezwa';

  @override
  String get fanClubSupportersAction => 'ABAFANA';

  @override
  String get fanClubOpenSupportersAction => 'FUNGURA ABAFANA';

  @override
  String get fanClubCopyLink => 'KOPORORA IHUZA';

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
  String get fanClubsCommunityEyebrow => 'UMURYANGO';

  @override
  String get fanClubsTitle => 'AMAKIPE Y’ABAFANA';

  @override
  String get fanClubsSearchHint => 'Shakisha clubs cyangwa ahantu';

  @override
  String get fanClubsFeaturedChapter => 'ITSINDA RYATORANYIJWE';

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
}
