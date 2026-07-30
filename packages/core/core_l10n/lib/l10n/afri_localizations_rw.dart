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

  @override
  String get liveMatchLoadError =>
      'Ntitwashoboye gufungura amakuru y’umukino uri kuba ubu.';

  @override
  String get liveStatusLive => 'URI KUBA';

  @override
  String get liveStatusHalfTime => 'AKARUHUKO';

  @override
  String get liveStatusFullTime => 'WARANGIYE';

  @override
  String get liveStatusPostponed => 'WASUBITSWE';

  @override
  String get liveStatusCancelled => 'WAHAGARITSWE';

  @override
  String get liveStatusUpcoming => 'UTEGANYIJWE';

  @override
  String get liveStatusFinal => 'WARANGIYE';

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
  String get liveMatchReport => 'RAPORO Y’UMUKINO';

  @override
  String get liveMatchFinishedPending =>
      'Umukino warangiye. Incamake irategerejwe.';

  @override
  String get liveMatchdayIntel => 'AMAKURU Y’UMUNSI W’UMUKINO';

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
  String get liveStatPending => 'BIRATEGEREJWE';

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
  String get liveCenterUnavailable => 'AMAKURU Y’UMUKINO NTABONEKA';

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
  String get newsRefreshArticle => 'VUGURURA INKURU';

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
  String get shopOutOfStockUpper => 'CYASHIZE MU BUBIKO';

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
  String get shopLoadingBadge => 'BIRAFUNGURWA';

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
  String get shopInStock => 'KIRAHARI';

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
  String get shopOfficialBadge => 'BYEMEWE';

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
  String get ticketDateLabel => 'ITARIKI';

  @override
  String get ticketTimeLabel => 'ISAHA';

  @override
  String get ticketVenueLabel => 'AHABERA';

  @override
  String get ticketAppleWallet => 'Apple Wallet';

  @override
  String get ticketGoogleWallet => 'Google Wallet';

  @override
  String get ticketWalletExportUnavailable =>
      'Kohereza tike muri wallet ntibiraboneka muri iyi verisiyo.';

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
  String get ticketAccessChangedTitle => 'Uburenganzira ku matike bwahindutse';

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
  String get ticketRefreshUpper => 'VUGURURA TIKE';

  @override
  String get ticketWalletUnavailableTitle => 'Ububiko bwa tike ntibuboneka';

  @override
  String get ticketWalletUnavailableMessage =>
      'Ububiko bwa tike ntibwashoboye gufunguka. Reba interineti wongere ugerageze.';

  @override
  String get ticketMyTickets => 'TIKE ZANJYE';

  @override
  String get ticketRefreshTickets => 'Vugurura tike';

  @override
  String get ticketUpcoming => 'IZAZA';

  @override
  String get ticketPast => 'IZAHISE';

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
  String get ticketCheckoutSummary => 'INCAMAKE YO KWISHYURA';

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
  String get ticketConfirmPurchase => 'EMEZA UBUGUZI';

  @override
  String get ticketMatchUpper => 'UMUKINO';

  @override
  String get ticketZoneUpper => 'AGACE';

  @override
  String get ticketSeatUpper => 'ICYICARO';

  @override
  String get ticketQuantityUpper => 'UMUBARE';

  @override
  String get ticketServiceFeeUpper => 'AMAFARANGA YA SERIVISI';

  @override
  String get ticketTotalUpper => 'IGITERANYO';

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
  String get ticketChooseAccess => 'HITAMO AHANTU';

  @override
  String get ticketGeneral => 'RUSANGE';

  @override
  String get ticketGeneralSubtitle => 'Imyanya rusange';

  @override
  String get ticketVip => 'VIP';

  @override
  String get ticketVipSubtitle => 'Imyanya myiza ya VIP';

  @override
  String get ticketChooseSeat => 'HITAMO ICYICARO';

  @override
  String get ticketChangeSeat => 'HINDURA ICYICARO';

  @override
  String get ticketReview => 'Suzuma';

  @override
  String get ticketReviewReservation => 'Suzuma ubusabe';

  @override
  String get ticketOfficialCategories => 'IBYICIRO BYEMEWE';

  @override
  String get ticketOfficialCategoriesMessage =>
      'Ibyiciro bya tike byemewe. Imyanya igaragara ikipe ifunguye igurisha ryemewe.';

  @override
  String get ticketListTitle => 'AMATIKE';

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
  String get ticketNext => 'IKURIKIRA';

  @override
  String get ticketMine => 'AYANJYE';

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
  String get ticketStatusSoldOut => 'YAGURISHIJWE YOSE';

  @override
  String get ticketStatusAvailable => 'ARAHARI';

  @override
  String get ticketFrom => 'GUHERA KU';

  @override
  String get ticketBuyAction => 'Gura itike';

  @override
  String get ticketSalesNotOpen => 'Igurisha ntirirafungurwa';

  @override
  String get ticketVersusUpper => 'NA';

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
  String get ticketMatchDay => 'UMUNSI W\'UMUKINO';

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
  String get ticketTryAgainUpper => 'ONGERA UGERAGEZE';

  @override
  String get ticketRefreshFixtureUpper => 'VUGURURA UMUKINO';

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
  String get ticketSavedFixtureReadOnlyMessage =>
      'Umukino wabitswe ushobora gusomwa gusa. Subira ku Matike kugira ngo ukomeze neza.';

  @override
  String get ticketFixtureRefreshFailedTitle =>
      'Kuvugurura umukino ntibyakunze';

  @override
  String get ticketSeatMapTitle => 'HITAMO ICYICARO';

  @override
  String get ticketConfirm => 'Emeza';

  @override
  String get ticketSeatSelectionUnavailableTitle =>
      'Guhitamo icyicaro ntibishoboka';

  @override
  String get ticketSeatSelectionUnavailableMessage =>
      'Guhitamo icyicaro ntibifunguye kuri iyi porogaramu cyangwa iyi kipe.';

  @override
  String get ticketBackToTicketUpper => 'SUBIRA KU ITIKE';

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
  String get ticketRefreshSeatMapUpper => 'VUGURURA IKARITA';

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
  String get ticketSelectedSeatUpper => 'ICYICARO CYAHISWEMO';

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
  String get contributionsClubProjectsTitle => 'IMISHINGA Y\'IKIPE';

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
  String get contributionsHubTitle => 'TANGA INKUNGA';

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
  String get contributionsTeamProjects => 'IMISHINGA Y\'IKIPE';

  @override
  String contributionsRaised(String current, String target) {
    return '$current kuri $target yakusanyijwe.';
  }

  @override
  String contributionsOpenMetric(int count) {
    return '$count IFUNGUYE';
  }

  @override
  String get contributionsCommunitiesUpper => 'IMIRYANGO';

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
  String get contributionsCommunityUpper => 'UMURYANGO';

  @override
  String get contributionsFanClubsChapters =>
      'Amatsinda y\'abafana n\'amashami yo hafi.';

  @override
  String get contributionsLive => 'BIRAKORA';

  @override
  String get contributionsMomoSmsSync => 'Guhuza SMS za MoMo';

  @override
  String get contributionsUnavailableBuild =>
      'Ntibiboneka muri iyi porogaramu.';

  @override
  String get contributionsActiveUpper => 'BIRAKORA';

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
  String get contributionsInitiativeTitle => 'IGIKORWA RUSANGE';

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
  String get contributionsRefreshInitiativeUpper => 'VUGURURA IGIKORWA';

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
  String get contributionsTypeUpper => 'UBWOKO';

  @override
  String get contributionsContributorsUpper => 'ABATANZE INKUNGA';

  @override
  String contributionsContributeToSemantic(String group) {
    return 'Tanga inkunga kuri $group';
  }

  @override
  String contributionsPaymentUnavailableSemantic(String action) {
    return '$action. Kwishyura ntibishoboka.';
  }

  @override
  String get contributionsPublicLedgerTitle => 'URUTONDE RUSANGE';

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
  String get contributionsStatusConfirmed => 'BYEMEJWE';

  @override
  String get contributionsStatusProcessing => 'BIRACYAKORWA';

  @override
  String get contributionsStatusFailed => 'NTIBYAKUNZE';

  @override
  String get contributionsTypeProject => 'UMUSHINGA W\'IKIPE';

  @override
  String get contributionsTypeCommunity => 'UMURYANGO';

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
  String get contributionsStatementTitle => 'RAPORO RUSANGE';

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
  String get contributionsRefreshStatementUpper => 'VUGURURA RAPORO';

  @override
  String get contributionsCopyCsvSemantic =>
      'Koporora raporo ya CSV irinda ibanga';

  @override
  String contributionsExportUnavailableSemantic(String reason) {
    return 'Kohereza raporo ntibishoboka. $reason';
  }

  @override
  String get contributionsFromUpper => 'KUVA';

  @override
  String get contributionsToUpper => 'KUGEZA';

  @override
  String get contributionsAllTime => 'Igihe cyose';

  @override
  String get contributionsNow => 'Ubu';

  @override
  String get contributionsSortUpper => 'TONDEKA';

  @override
  String get contributionsSortDate => 'KU ITARIKI';

  @override
  String get contributionsSortAmount => 'KU MAFARANGA';

  @override
  String get contributionsSortAlias => 'KU IZINA RUSANGE';

  @override
  String get contributionsPdf => 'PDF';

  @override
  String get contributionsCsv => 'CSV';

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
  String get contributionsConfirmedTotalUpper => 'AMAFARANGA YEMEJWE';

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
  String get contributionsPreviewUpper => 'IBIZAGARAGARA';

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
  String get contributionsAmountPrompt => 'URASHAKA GUTANGA ANGAHE?';

  @override
  String contributionsQuickAmount(int thousands) {
    return '+${thousands}K';
  }

  @override
  String get contributionsLaunchMomoDialer => 'Fungura MOMO kuri telefoni';

  @override
  String get contributionsLaunchingMomo => 'GUFUNGURA MOMO';

  @override
  String get contributionsChangeAmount => 'Hindura amafaranga';

  @override
  String get contributionsDialNow => 'Hamagara ubu';

  @override
  String get contributionsCancel => 'Hagarika inkunga';

  @override
  String get contributionsPaymentConfirmedTitle => 'KWISHYURA BYEMEJWE';

  @override
  String contributionsPaymentConfirmedMessage(String amount) {
    return 'Inkunga yawe ya $amount yemejwe kandi yabitswe.';
  }

  @override
  String get contributionsPaymentFailedTitle => 'KWISHYURA NTIBYAKUNZE';

  @override
  String get contributionsPaymentFailedMessage =>
      'Kwishyura ntikwashoboye kwemezwa. Reba amafaranga ya MoMo wongere ugerageze cyangwa uvugane n\'abafasha.';

  @override
  String get contributionsPaymentProcessingTitle => 'BIRACYAKORWA';

  @override
  String get contributionsPaymentProcessingMessage =>
      'Kwishyura biratinze. Reba urutonde rw\'itsinda kugira ngo ubone uko bimeze. Niba wohereje kuri MoMo, biraza kugaragara.';

  @override
  String get contributionsRecordFailedTitle => 'NTIBYASHOBOYE KUBIKWA';

  @override
  String get contributionsRecordFailedMessage =>
      'MOMO yafungutse ariko inkunga ntiyabitswe. Subira ku itsinda wongere ugerageze.';

  @override
  String get contributionsAwaitingPaymentTitle => 'GUTEGEREZA KWISHYURA';

  @override
  String get contributionsAwaitingPaymentMessage =>
      'Rangiza kwishyura kuri MoMo muri telefoni. Inkunga irakomeza kugaragara ko igikorwa kugeza yemejwe.';

  @override
  String get contributionsCheckingPaymentStatus =>
      'Kugenzura uko kwishyura kumeze…';

  @override
  String get contributionsVerifiedUpper => 'BYEMEJWE';

  @override
  String get contributionsDone => 'Byarangiye';

  @override
  String get contributionsBackToGroup => 'Subira ku itsinda';

  @override
  String get contributionsEnableMomoSmsTitle => 'FUNGURA GUHUZA SMS ZA MOMO';

  @override
  String contributionsSmsPrivacyMessage(String app) {
    return '$app isoma gusa ubutumwa bwa MoMo bwemeza ubwishyu kugira ngo ibike inyemezabwishyu. Ubundi butumwa ntibusomwa.';
  }

  @override
  String get contributionsAllowSmsReading => 'Emerera gusoma SMS';

  @override
  String get contributionsEnable => 'Fungura';

  @override
  String get contributionsNotNowUpper => 'SI UBU';
}
