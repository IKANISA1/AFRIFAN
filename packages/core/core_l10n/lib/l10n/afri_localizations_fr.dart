// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'afri_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AfriLocalizationsFr extends AfriLocalizations {
  AfriLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'AfriClub';

  @override
  String get genericError => 'Un problème est survenu. Réessayez.';

  @override
  String get retry => 'Réessayer';

  @override
  String get connectionRequired => 'Connexion requise';

  @override
  String get onboardingBelongTitle => 'Votre club.\nVotre jour de match.';

  @override
  String onboardingBelongBody(String clubName) {
    return 'Suivez $clubName partout où la famille bleue se retrouve.';
  }

  @override
  String get onboardingKnowTitle => 'Chaque instant.\nUne seule famille bleue.';

  @override
  String onboardingKnowBody(String appName) {
    return 'Retrouvez les actualités officielles de $appName, les matchs, les billets et l’adhésion.';
  }

  @override
  String get onboardingLiveTitle => 'Plus proche de\nGikundiro.';

  @override
  String get onboardingLiveBody =>
      'Découvrez l’équipe et gardez votre club avec vous chaque jour.';

  @override
  String get onboardingSkip => 'Passer';

  @override
  String get onboardingNext => 'Suivant';

  @override
  String get onboardingStart => 'Commencer';

  @override
  String get onboardingContinueWhatsApp => 'Continuer avec WhatsApp';

  @override
  String get onboardingContinueWithoutSignIn => 'Continuer sans connexion';

  @override
  String onboardingWelcomeImage(int current, int total) {
    return 'Image d’accueil $current sur $total';
  }

  @override
  String get supportUnavailable =>
      'L’assistance n’est pas disponible dans cette version.';

  @override
  String get fanZoneLoading =>
      'Pronostics, ligue, points, fans et récompenses se chargent.';

  @override
  String get fanZoneJoinSession =>
      'Rejoignez une session en direct et jouez avec ce téléphone.';

  @override
  String get fanZoneVenueCode =>
      'Saisissez le code du lieu après votre arrivée.';

  @override
  String get fanZoneRoundsEmpty =>
      'Les manches du jour de match apparaîtront à leur ouverture.';

  @override
  String get fanZoneRankingsEmpty =>
      'Les classements apparaîtront à la reprise des mises à jour.';

  @override
  String get fanZoneClubsMoved =>
      'Les fan-clubs et sections se trouvent dans Supporters.';

  @override
  String get fanZoneRegistryMoved =>
      'La liste des supporters se trouve dans Fan Zone Supporters.';

  @override
  String get fanZoneContributionMode => 'Choisissez comment contribuer.';

  @override
  String get fanZoneRewardsSummary => 'Badges, séries et récompenses.';

  @override
  String get fanZoneLineupsEmpty =>
      'Les compositions apparaîtront avant le coup d’envoi.';

  @override
  String get fanZoneStatsEmpty =>
      'Les statistiques apparaîtront au début du match.';

  @override
  String get fanIdVerifyPrompt =>
      'Vérifiez votre Fan ID pour pronostiquer et gagner des points.';

  @override
  String get fanIdPrivacyTrust =>
      'La vérification utilise votre Fan ID. Aucune donnée personnelle n’est partagée.';

  @override
  String get searchTitle => 'Chercher';

  @override
  String get searchHint =>
      'Fans, matchs, billets, boutique, portefeuille, aide';

  @override
  String get searchClearTooltip => 'Effacer la recherche';

  @override
  String get searchCategoryAll => 'Tout';

  @override
  String get searchCategorySupporters => 'Supporters';

  @override
  String get searchCategoryFixtures => 'Matchs';

  @override
  String get searchCategoryCommerce => 'Billets et boutique';

  @override
  String get searchCategoryServices => 'Services';

  @override
  String get searchKeepTypingTitle => 'Continuez à saisir';

  @override
  String get searchKeepTypingMessage =>
      'Saisissez au moins deux caractères pour lancer la recherche.';

  @override
  String get searchUpdatingTitle => 'Mise à jour des résultats';

  @override
  String get searchSearchingTitle => 'Recherche en cours';

  @override
  String get searchUpdatingMessage =>
      'Actualisation des rubriques et du contenu public des supporters.';

  @override
  String get searchSearchingMessage =>
      'Recherche dans les rubriques et le contenu des supporters.';

  @override
  String get searchPermissionTitle => 'Recherche non autorisée';

  @override
  String get searchPermissionMessage =>
      'Recherche en direct interdite pour ce compte. La requête reste. Contactez l’assistance du club.';

  @override
  String get searchConflictTitle => 'La recherche a changé';

  @override
  String get searchConflictMessage =>
      'Le contenu disponible a changé pendant la recherche. Vérifiez la requête et réessayez.';

  @override
  String get searchTimeoutTitle => 'Délai de recherche dépassé';

  @override
  String get searchTimeoutMessage =>
      'Le délai de recherche a expiré. Votre requête est conservée. Réessayez quand vous êtes prêt.';

  @override
  String get searchUnavailableTitle => 'Recherche indisponible';

  @override
  String get searchUnavailableMessage =>
      'Réessayez. Votre requête n’a pas été envoyée ailleurs.';

  @override
  String get searchStartTitle => 'Trouvez ce qu’il vous faut';

  @override
  String get searchStartMessage =>
      'Saisissez deux caractères. Recherchez dans l’app et le contenu public des supporters.';

  @override
  String get searchRecentTitle => 'Recherches récentes';

  @override
  String get searchClear => 'Effacer';

  @override
  String searchForTooltip(String query) {
    return 'Rechercher $query';
  }

  @override
  String get searchNoResultsTitle => 'Aucun résultat';

  @override
  String searchNoResultsMessage(String query) {
    return 'Aucun résultat ne correspond à « $query ».';
  }

  @override
  String get searchShowAllCategories => 'Afficher toutes les catégories';

  @override
  String get searchOfflineTitle => 'Résultats hors ligne';

  @override
  String get searchOfflineMessage =>
      'Résultats enregistrés sur cet appareil. Le contenu en direct peut être ancien.';

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count résultats',
      one: '1 résultat',
      zero: 'Aucun résultat',
    );
    return '$_temp0';
  }

  @override
  String get searchSupporterDirectoryTitle => 'Trouver des supporters';

  @override
  String get searchSupporterDirectoryDescription =>
      'Recherchez des alias publics de supporters et gérez vos amis.';

  @override
  String get searchFanZoneTitle => 'Fan Zone';

  @override
  String get searchFanZoneDescription =>
      'Pronostics, communauté, récompenses et activités de match.';

  @override
  String get searchFanRegistryTitle => 'Registre des fans';

  @override
  String get searchFanRegistryDescription =>
      'Consultez le registre des supporters du club.';

  @override
  String get searchFixturesTitle => 'Matchs';

  @override
  String get searchFixturesDescription =>
      'Matchs récents et à venir du Rayon Sports.';

  @override
  String get searchLiveMatchTitle => 'Match en direct';

  @override
  String get searchLiveMatchDescription =>
      'Ouvrez le centre du match quand une couverture en direct existe.';

  @override
  String get searchStandingsTitle => 'Classement du championnat';

  @override
  String get searchStandingsDescription =>
      'Consultez le classement actuel et la position en compétition.';

  @override
  String get searchTicketsTitle => 'Billets de match';

  @override
  String get searchTicketsDescription =>
      'Trouvez les billets disponibles et poursuivez vers le paiement.';

  @override
  String get searchMyTicketsTitle => 'Mes billets';

  @override
  String get searchMyTicketsDescription =>
      'Ouvrez vos billets achetés et les détails d’accès au match.';

  @override
  String get searchShopTitle => 'Boutique du club';

  @override
  String get searchShopDescription =>
      'Parcourez les produits officiels du club.';

  @override
  String get searchCartTitle => 'Panier';

  @override
  String get searchCartDescription =>
      'Vérifiez les produits avant le paiement.';

  @override
  String get searchWalletTitle => 'Portefeuille FET';

  @override
  String get searchWalletDescription =>
      'Consultez le solde, l’historique, les transferts et les échanges.';

  @override
  String get searchMembershipTitle => 'Adhésion';

  @override
  String get searchMembershipDescription =>
      'Consultez votre adhésion et les avantages du club.';

  @override
  String get searchContributionsTitle => 'Soutenir le club';

  @override
  String get searchContributionsDescription =>
      'Ouvrez les contributions et les projets des supporters.';

  @override
  String get searchNotificationsTitle => 'Notifications';

  @override
  String get searchNotificationsDescription =>
      'Consultez et modifiez les préférences de notification.';

  @override
  String get searchPrivacyTitle => 'Paramètres de confidentialité';

  @override
  String get searchPrivacyDescription =>
      'Consultez le consentement et les contrôles de confidentialité.';

  @override
  String get searchHelpTitle => 'Aide et assistance';

  @override
  String get searchHelpDescription =>
      'Ouvrez les options d’assistance depuis Paramètres.';

  @override
  String get searchPublicSupporterDescription =>
      'Profil public d’un supporter dans le registre du club.';

  @override
  String searchMatchTitle(String home, String away) {
    return '$home contre $away';
  }

  @override
  String searchFixtureOnSaleDescription(String competition) {
    return 'Match de $competition avec billets disponibles.';
  }

  @override
  String searchFixtureDescription(String competition) {
    return 'Match de $competition.';
  }

  @override
  String searchProductDescription(String category) {
    return 'Article officiel de la boutique dans $category.';
  }

  @override
  String get searchHomeTeamFallback => 'Domicile';

  @override
  String get searchAwayTeamFallback => 'Extérieur';

  @override
  String get searchClubFixtureFallback => 'Match du club';

  @override
  String get searchClubProductFallback => 'Produit du club';

  @override
  String get searchMerchandiseFallback => 'Articles du club';

  @override
  String get tvPairingUnavailable =>
      'Appairage indisponible. Vérifiez la connexion et réessayez.';

  @override
  String get tvConfigurationMissing =>
      'La configuration est incomplète. Contactez le responsable du déploiement.';

  @override
  String get tvCredentialRevoked =>
      'Cet appareil a été révoqué. Créez un nouveau code d’appairage.';

  @override
  String get tvEnterAdminCode =>
      'Saisissez le code de la liste des appareils admin.';

  @override
  String get tvJoinFromFanZone =>
      'Utilisez ce code pour rejoindre depuis la Fan Zone.';

  @override
  String get tvConnectionLostRetry => 'Connexion perdue — réessayer';

  @override
  String tvAppTitle(String appName) {
    return '$appName TV';
  }

  @override
  String tvBrandMarkSemantic(String clubName) {
    return 'Logo TV de $clubName';
  }

  @override
  String get tvPairThisDisplay => 'Associer ce téléviseur';

  @override
  String get tvPairingCodeLabel => 'Code d’association à usage unique';

  @override
  String get tvPairingCodeHelper => '6 à 12 caractères';

  @override
  String get tvPairingInProgress => 'Association…';

  @override
  String get tvPairDisplayAction => 'Associer l’écran';

  @override
  String get tvSessionCodeInstruction => 'Entrez ce code dans Fan Zone';

  @override
  String tvSessionCodeSemantic(String code) {
    return 'Code de session TV : $code';
  }

  @override
  String tvFetRewardLabel(int reward) {
    return 'Récompense : $reward FET';
  }

  @override
  String tvExpiresLabel(String expiry) {
    return 'Expire $expiry';
  }

  @override
  String get tvExpired => 'expiré';

  @override
  String get tvExpiresLessThanOneMinute => 'dans moins d’une minute';

  @override
  String tvExpiresMinutes(int minutes) {
    return 'dans $minutes min';
  }

  @override
  String tvExpiresHoursMinutes(int hours, int minutes) {
    return 'dans $hours h $minutes min';
  }

  @override
  String get tvVenueSessionDetails => 'Détails de la session du lieu';

  @override
  String get tvVenueSessionOnly => 'Session du lieu uniquement';

  @override
  String get tvNoSupporterDetails => 'Aucune donnée de supporter affichée';

  @override
  String get tvPairingStatusAndExpiry => 'État de l’association et expiration';

  @override
  String get tvDefaultPairingPrompt =>
      'Associez cet écran TV depuis le panneau d’administration.';

  @override
  String get tvOfflinePhase => 'Hors ligne';

  @override
  String get membershipTitle => 'Adhésion';

  @override
  String get membershipSavedDetails => 'Détails d’adhésion enregistrés';

  @override
  String get membershipDigitalCard => 'Carte numérique';

  @override
  String get share => 'Partager';

  @override
  String get membershipReviewTitle => 'Vérification de l’adhésion';

  @override
  String membershipReviewSubtitle(String tier) {
    return 'L’adhésion $tier attend la vérification du paiement.';
  }

  @override
  String membershipRenewsOn(String date) {
    return 'Renouvellement le $date';
  }

  @override
  String get fanRegistryTitle => 'Registre des supporters';

  @override
  String get fanRegistryBrowseAll => 'Parcourir tous les supporters';

  @override
  String get membershipPackagesTitle => 'Formules';

  @override
  String get membershipOfflineTitle => 'Adhésion indisponible';

  @override
  String get membershipOfflineMessage =>
      'Connectez-vous pour charger les détails actuels de l’adhésion.';

  @override
  String get membershipSetupPending => 'Configuration de l’adhésion en attente';

  @override
  String get membershipChangeDeniedTitle =>
      'Modification de l’adhésion non autorisée';

  @override
  String get membershipChangeDeniedMessage =>
      'Votre compte ne peut pas modifier l’adhésion maintenant. Votre adhésion actuelle reste inchangée.';

  @override
  String get membershipChangedTitle => 'Les détails de l’adhésion ont changé';

  @override
  String get membershipChangedMessage =>
      'Le club a modifié ces détails pendant votre consultation. Actualisez avant de choisir une formule.';

  @override
  String get membershipTimeoutTitle => 'La demande d’adhésion a expiré';

  @override
  String get membershipTimeoutMessage =>
      'La fenêtre sécurisée a expiré. Actualisez le statut avant de réessayer.';

  @override
  String get membershipUnavailableMessage =>
      'Les détails de l’adhésion sont temporairement indisponibles.';

  @override
  String get membershipPaymentSent => 'Paiement envoyé';

  @override
  String get membershipPaymentVerifying => 'Vérification du paiement';

  @override
  String get membershipConfirmed => 'Adhésion confirmée';

  @override
  String membershipRequestTitle(String tier) {
    return 'Demande d’adhésion $tier';
  }

  @override
  String membershipAmount(String currency, String amount) {
    return 'Montant : $currency $amount';
  }

  @override
  String get membershipVerificationTime =>
      'La vérification prend généralement de 1 à 24 heures.';

  @override
  String membershipRequestedOn(String date) {
    return 'Demandé le : $date';
  }

  @override
  String get contactSupport => 'Contacter l’assistance';

  @override
  String get membershipPackageEmpty =>
      'Les formules d’adhésion apparaîtront après leur publication par le club.';

  @override
  String get fanRegistrySearchHint => 'Rechercher un supporter par nom';

  @override
  String get fanRegistryUnavailable => 'Registre indisponible';

  @override
  String get fanRegistryUnavailableMessage =>
      'Le registre des supporters est temporairement indisponible.';

  @override
  String fanRegistryLoaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count supporters chargés',
      one: '1 supporter chargé',
      zero: 'Aucun supporter chargé',
    );
    return '$_temp0';
  }

  @override
  String get fanRegistrySummary =>
      'Ce registre reflète la liste des adhérents du club.';

  @override
  String fanRegistryFiltered(String query) {
    return 'Résultats filtrés pour « $query ».';
  }

  @override
  String get fanRegistryLoadMoreFailure =>
      'Impossible de charger plus de supporters pour le moment.';

  @override
  String get fanRegistryPending => 'En attente';

  @override
  String fanRegistryActivity(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count activités',
      one: '1 activité',
      zero: 'Aucune activité',
    );
    return '$_temp0';
  }

  @override
  String fanRegistryJoined(String date) {
    return 'Adhésion le $date';
  }

  @override
  String fanRegistryJoinedRenews(String joined, String renews) {
    return 'Adhésion le $joined • Renouvellement le $renews';
  }

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileLoadingMembership => 'Chargement de l’adhésion…';

  @override
  String get profileMembershipReviewPending =>
      'Vérification de l’adhésion en attente';

  @override
  String get profileMyClub => 'Mon club';

  @override
  String get profileMatchday => 'Jour de match';

  @override
  String get profileMyPicks => 'Mes pronostics';

  @override
  String get profileClubBenefits => 'Avantages du club';

  @override
  String get profileContributions => 'Contributions';

  @override
  String get profileShop => 'Boutique';

  @override
  String get profileApp => 'Application';

  @override
  String get profileNotifications => 'Notifications';

  @override
  String get profileActivityHistory => 'Historique d’activité';

  @override
  String profileActivityPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points d’activité',
      one: '1 point d’activité',
      zero: 'Aucun point d’activité',
    );
    return '$_temp0';
  }

  @override
  String get tierTitle => 'Catégorie d’adhésion';

  @override
  String get tierUnavailableTitle => 'Détails de la catégorie indisponibles';

  @override
  String get tierDisabledMessage =>
      'Les détails des catégories sont désactivés dans cette version. Aucune demande ne peut être lancée ici.';

  @override
  String get backToMembership => 'Retour à l’adhésion';

  @override
  String get tierNotFoundTitle => 'Catégorie introuvable';

  @override
  String get tierNotFoundMessage =>
      'Cette catégorie d’adhésion ne figure pas dans la liste officielle.';

  @override
  String get tierOfflineTitle => 'Détails de la catégorie hors ligne';

  @override
  String get tierOfflineMessage =>
      'Reconnectez-vous pour vérifier cette catégorie. Aucune demande n’est mise en attente hors ligne.';

  @override
  String get tierAccessDeniedTitle => 'Accès à la catégorie refusé';

  @override
  String get tierAccessDeniedMessage =>
      'Ce compte ne peut pas ouvrir les détails de cette catégorie.';

  @override
  String get tierTimeoutTitle => 'La vérification a expiré';

  @override
  String get tierTimeoutMessage =>
      'L’application n’a pas pu confirmer cette catégorie à temps. Essayez une actualisation limitée.';

  @override
  String get tryAgain => 'Réessayer';

  @override
  String get tierChangedTitle => 'Les détails de la catégorie ont changé';

  @override
  String get tierChangedMessage =>
      'La catégorie actuelle n’a pas pu être confirmée car ses détails ont changé ailleurs.';

  @override
  String get tierLoadUnavailableMessage =>
      'La catégorie n’a pas pu être chargée. Aucun détail de service privé n’a été affiché.';

  @override
  String tierSelected(String tier) {
    return 'Catégorie d’adhésion $tier sélectionnée';
  }

  @override
  String get tierPerks => 'Avantages de la catégorie';

  @override
  String get tierAccess => 'Accès de l’adhésion';

  @override
  String get tierShowingOfficialTitle =>
      'Détails officiels de la catégorie affichés';

  @override
  String get tierOfflineStatusMessage =>
      'Reconnectez-vous pour rechercher des mises à jour. Aucune demande n’est mise en attente hors ligne.';

  @override
  String get tierRefreshingTitle => 'Actualisation de la catégorie';

  @override
  String get tierRefreshingMessage =>
      'Les détails officiels restent visibles pendant le chargement.';

  @override
  String get tierUpdateDeniedTitle => 'Mise à jour non autorisée';

  @override
  String get tierUpdateDeniedMessage =>
      'Les détails officiels restent visibles. Ce compte ne peut pas rechercher les mises à jour.';

  @override
  String get tierChangedStatusMessage =>
      'Les détails officiels restent visibles. Actualisez pour confirmer la dernière version.';

  @override
  String get tierRefreshTimeoutTitle => 'L’actualisation a expiré';

  @override
  String get tierRefreshTimeoutMessage =>
      'Les détails officiels restent visibles. Essayez une actualisation limitée.';

  @override
  String get tierOutdatedTitle => 'Les détails peuvent être obsolètes';

  @override
  String get tierOutdatedMessage =>
      'Les détails officiels restent visibles pendant l’indisponibilité du service.';

  @override
  String get tierDegradedMessage =>
      'Les derniers détails disponibles restent visibles jusqu’à la réussite de l’actualisation.';

  @override
  String get contributionConfirmTitle => 'Confirmer la contribution';

  @override
  String contributionConfirmQuestion(String tier) {
    return 'Avez-vous effectué le paiement MoMo USSD pour la catégorie $tier ?';
  }

  @override
  String get contributionSelectedTier => 'Catégorie sélectionnée';

  @override
  String get contributionPendingVerification => 'Vérification en attente';

  @override
  String get contributionNotYet => 'Pas encore';

  @override
  String get contributionConfirming => 'Confirmation…';

  @override
  String get contributionYesPaid => 'Oui, j’ai payé';

  @override
  String get contributionPrivacy =>
      'Les contributions sont vérifiées anonymement avec le Fan ID.';

  @override
  String get contributionHistory => 'Historique des contributions';

  @override
  String get shareMembershipCard => 'Partager la carte d’adhésion';

  @override
  String get shareMembershipCardHint =>
      'Partager votre carte d’adhésion numérique';

  @override
  String membershipSince(String date) {
    return 'Depuis $date';
  }

  @override
  String get membershipFanCard => 'Carte de supporter';

  @override
  String get membershipReviewPendingUpper => 'Vérification en attente';

  @override
  String get membershipBrandWatermark => 'GIKUNDIRO';

  @override
  String get navHome => 'Accueil';

  @override
  String get navClub => 'Club';

  @override
  String get navFanZone => 'Espace supporters';

  @override
  String get navMembership => 'Adhésion';

  @override
  String get membershipConnectBeforeChange =>
      'Connectez-vous avant de modifier l’adhésion.';

  @override
  String get membershipSignInFirst =>
      'Connectez-vous d’abord pour activer l’adhésion.';

  @override
  String membershipRequestSubmitted(String tier) {
    return 'Demande d’adhésion $tier envoyée.';
  }

  @override
  String membershipAlreadyPending(String tier) {
    return 'L’adhésion $tier attend déjà la vérification du paiement.';
  }

  @override
  String membershipStarted(String tier) {
    return 'Adhésion $tier commencée.';
  }

  @override
  String get membershipPaymentSetupPending =>
      'La configuration du paiement attend l’activation du club.';

  @override
  String membershipDialerFailed(String tier) {
    return 'La demande $tier a été enregistrée, mais le composeur MoMo ne s’est pas ouvert.';
  }

  @override
  String membershipSubmittedBackground(String tier) {
    return 'Demande $tier envoyée. Le paiement sera vérifié en arrière-plan.';
  }

  @override
  String get membershipPendingReviewAction => 'Vérification en attente';

  @override
  String get membershipActivateAction => 'Activer';

  @override
  String get membershipRenewAction => 'Renouveler';

  @override
  String get membershipSwitchAction => 'Changer';

  @override
  String get membershipCopied => 'Détails de l’adhésion copiés.';

  @override
  String membershipShareText(String club, String tier, String supporter) {
    return 'Adhésion $club\nCatégorie : $tier\nID supporter : #$supporter';
  }

  @override
  String get membershipActivityPending =>
      'L’activité apparaîtra après la vérification des billets, groupes de supporters et contributions.';

  @override
  String membershipActivityRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points d’activité enregistrés.',
      one: '1 point d’activité enregistré.',
      zero: 'Aucun point d’activité enregistré.',
    );
    return '$_temp0';
  }

  @override
  String get membershipSupportMessage =>
      'Bonjour, j’ai besoin d’aide pour la vérification de mon paiement d’adhésion.';

  @override
  String get membershipWhatsAppUnavailable =>
      'Impossible d’ouvrir WhatsApp. Contactez l’assistance.';

  @override
  String get membershipSupportNotConfigured =>
      'Le contact d’assistance n’est pas encore configuré.';

  @override
  String get membershipSubmittingTitle => 'Envoi de la demande d’adhésion';

  @override
  String get membershipUpdatingTitle => 'Mise à jour de l’adhésion';

  @override
  String get membershipSubmittingMessage =>
      'Gardez cet écran ouvert pendant la réception de votre demande par le club.';

  @override
  String get membershipUpdatingMessage =>
      'Actualisation des formules et des détails actuels.';

  @override
  String get membershipRefreshAction => 'Actualiser';

  @override
  String membershipCurrentStatus(String tier) {
    return '$tier · Actuelle';
  }

  @override
  String get membershipRefreshRequired => 'Actualisation requise';

  @override
  String get membershipSubmittingAction => 'Envoi…';

  @override
  String membershipPackageCurrentSemantic(String tier) {
    return 'Formule d’adhésion $tier, actuelle';
  }

  @override
  String get membershipPackageFallback => 'Formule';

  @override
  String get membershipFanFallback => 'Supporter';

  @override
  String get membershipDateNextYear => 'l’année prochaine';

  @override
  String membershipDate(int day, String month, int year) {
    return '$day $month $year';
  }

  @override
  String get membershipMonthJan => 'janv.';

  @override
  String get membershipMonthFeb => 'févr.';

  @override
  String get membershipMonthMar => 'mars';

  @override
  String get membershipMonthApr => 'avr.';

  @override
  String get membershipMonthMay => 'mai';

  @override
  String get membershipMonthJun => 'juin';

  @override
  String get membershipMonthJul => 'juil.';

  @override
  String get membershipMonthAug => 'août';

  @override
  String get membershipMonthSep => 'sept.';

  @override
  String get membershipMonthOct => 'oct.';

  @override
  String get membershipMonthNov => 'nov.';

  @override
  String get membershipMonthDec => 'déc.';

  @override
  String get clubTitle => 'Club';

  @override
  String clubOfficialOverviewSemantic(String club) {
    return 'Présentation officielle de $club';
  }

  @override
  String get clubLiveIdentityUnavailable =>
      'Identité actuelle du club indisponible';

  @override
  String get clubIdentityFallbackMessage =>
      'L’identité vérifiée de l’application reste affichée pendant que la fiche actuelle du club ne peut pas être actualisée.';

  @override
  String get clubOfficialSection => 'Club officiel';

  @override
  String get clubTeamTitle => 'Équipe';

  @override
  String get clubTeamSubtitle =>
      'Équipe première et profils officiels des joueurs';

  @override
  String get clubTeamEmptyTitle => 'Aucune équipe publiée';

  @override
  String get clubTeamEmptyMessage =>
      'Le club n’a pas publié son équipe première dans cette application.';

  @override
  String get clubNewsTitle => 'Actualités du club';

  @override
  String get clubNewsSubtitle => 'Actualités et annonces publiées par le club';

  @override
  String get clubNewsEmptyTitle => 'Aucune actualité publiée';

  @override
  String get clubNewsEmptyMessage =>
      'Les actualités publiées par le club apparaîtront ici.';

  @override
  String get clubArticleUnavailableTitle => 'Article indisponible';

  @override
  String get clubArticleUnavailableMessage =>
      'Cet article n’est pas publié pour le club actif ou le lien n’est plus actuel.';

  @override
  String get clubArticleBodyUnavailable =>
      'Le contenu complet de l’article n’est pas disponible.';

  @override
  String get clubFixturesTitle => 'Matchs à venir';

  @override
  String get clubFixturesSubtitle =>
      'Prochains matchs et disponibilité des billets';

  @override
  String get clubFixturesEmptyTitle => 'Aucun match à venir';

  @override
  String get clubFixturesEmptyMessage =>
      'Le club n’a pas encore publié d’autre match.';

  @override
  String clubFixtureTitle(String home, String away) {
    return '$home contre $away';
  }

  @override
  String get clubTicketsTitle => 'Billets';

  @override
  String get clubResultsTitle => 'Résultats';

  @override
  String get clubResultsSubtitle => 'Scores des matchs terminés';

  @override
  String get clubResultsEmptyTitle => 'Aucun résultat publié';

  @override
  String get clubResultsEmptyMessage =>
      'Les matchs terminés du club apparaîtront ici.';

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
  String get clubMatchUnavailableTitle => 'Match indisponible';

  @override
  String get clubMatchUnavailableMessage =>
      'Ce match n’est pas publié pour le club actif ou le lien n’est plus actuel.';

  @override
  String clubScore(int homeScore, int awayScore) {
    return '$homeScore – $awayScore';
  }

  @override
  String get clubViewAvailableTickets => 'Voir les billets disponibles';

  @override
  String get clubStandingsTitle => 'Classement';

  @override
  String get clubStandingsSubtitle => 'Classement actuel publié';

  @override
  String get clubStandingsEmptyTitle => 'Aucun classement publié';

  @override
  String get clubStandingsEmptyMessage =>
      'Le classement actuel n’a pas été publié.';

  @override
  String get clubPlayedShort => 'J';

  @override
  String get clubGoalDifferenceShort => 'DB';

  @override
  String get clubPointsShort => 'PTS';

  @override
  String get clubHistoryTitle => 'Histoire du club';

  @override
  String get clubHistorySubtitle => 'Histoire et moments marquants du club';

  @override
  String get clubHistoryEmptyTitle => 'Histoire non publiée';

  @override
  String get clubHistoryEmptyMessage =>
      'L’histoire du club reste indisponible jusqu’à la publication du contenu validé.';

  @override
  String get clubProjectsTitle => 'Projets du club';

  @override
  String get clubProjectsSubtitle =>
      'Projets encadrés des supporters et leur progression';

  @override
  String get clubProjectsEmptyTitle => 'Aucun projet publié';

  @override
  String get clubProjectsEmptyMessage =>
      'Les projets encadrés des supporters apparaîtront après l’approbation du club.';

  @override
  String clubSupporters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count supporters',
      one: '1 supporter',
      zero: 'Aucun supporter',
    );
    return '$_temp0';
  }

  @override
  String get clubProjectTitle => 'Projet du club';

  @override
  String get clubProjectUnavailableTitle => 'Projet indisponible';

  @override
  String get clubProjectUnavailableMessage =>
      'Ce projet n’est pas actif pour le club actuel ou le lien n’est plus actuel.';

  @override
  String clubSupportersParticipate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count supporters participent actuellement.',
      one: '1 supporter participe actuellement.',
      zero: 'Aucun supporter ne participe actuellement.',
    );
    return '$_temp0';
  }

  @override
  String get clubOpenContribution => 'Ouvrir le parcours de contribution';

  @override
  String get clubInformationUnavailable => 'Informations du club indisponibles';

  @override
  String get clubInformationLoadMessage =>
      'Les données actuelles du club n’ont pas pu être chargées. Le contenu existant de l’application n’a pas été remplacé.';

  @override
  String get clubLinkedRecordLoadMessage =>
      'La fiche du club liée n’a pas pu être chargée.';

  @override
  String get clubRefresh => 'Actualiser';

  @override
  String get clubTicketsSubtitle => 'Billets de match publiés pour ce club';

  @override
  String get clubShopTitle => 'Boutique';

  @override
  String get clubShopSubtitle => 'Produits officiels et disponibilité';

  @override
  String onboardingBelongImageSemantic(String club) {
    return 'Les joueurs de $club applaudissent les supporters après un match';
  }

  @override
  String onboardingKnowImageSemantic(String club) {
    return 'Les joueurs de $club célèbrent ensemble';
  }

  @override
  String onboardingLiveImageSemantic(String club) {
    return 'Portrait d’un joueur de $club';
  }

  @override
  String onboardingIdentitySemantic(String club) {
    return 'Identité de $club';
  }

  @override
  String onboardingImageSemantic(String description, int index, int count) {
    return '$description. Image $index sur $count';
  }

  @override
  String get onboardingAnonymousSessionUnavailable =>
      'Impossible d’ouvrir une session invité. Réessayez.';

  @override
  String get onboardingRefreshingTitle => 'Actualisation de l’accueil';

  @override
  String get onboardingRefreshingMessage =>
      'L’accueil et les choix actuels restent visibles pendant la recherche des mises à jour.';

  @override
  String get onboardingStatusTitle => 'État de l’accueil';

  @override
  String get onboardingWhatsAppUnavailable => 'Connexion WhatsApp indisponible';

  @override
  String get onboardingOfflineSavedMessage =>
      'Hors ligne. Votre accueil enregistré est disponible. Continuez sans vous connecter.';

  @override
  String get onboardingWhatsAppLaterMessage =>
      'Continuez sans vous connecter ou réessayez WhatsApp plus tard.';

  @override
  String get onboardingContentUnavailableTitle =>
      'Contenu d’accueil indisponible';

  @override
  String get onboardingContentUnavailableMessage =>
      'Aucun contenu d’accueil n’est encore disponible. Actualisez ou continuez sans vous connecter.';

  @override
  String get onboardingPreparingTitle => 'Préparation de votre accueil';

  @override
  String get onboardingPreparingMessage =>
      'Chargement du dernier accueil du club et des choix de connexion.';

  @override
  String get onboardingAccessUnavailableTitle =>
      'Accès à l’accueil indisponible';

  @override
  String get onboardingAccessUnavailableMessage =>
      'Cet accueil ne peut pas être ouvert pour ce compte. La connexion WhatsApp et l’accès invité restent disponibles.';

  @override
  String get onboardingChangedTitle => 'L’accueil a changé';

  @override
  String get onboardingChangedMessage =>
      'L’accueil a changé pendant son ouverture. Actualisez pour charger la version actuelle.';

  @override
  String get onboardingSecurityTimeoutTitle =>
      'Le contrôle de sécurité a expiré';

  @override
  String get onboardingSecurityTimeoutMessage =>
      'L’accueil n’a pas pu être vérifié à temps. Vérifiez votre connexion et actualisez.';

  @override
  String get onboardingUnavailableTitle => 'Accueil indisponible';

  @override
  String get onboardingUnavailableMessage =>
      'L’accueil n’a pas pu être chargé en toute sécurité. Réessayez ou continuez sans vous connecter.';

  @override
  String get onboardingRefresh => 'Actualiser';

  @override
  String splashLoadingSemantic(String app) {
    return 'Chargement de $app';
  }

  @override
  String get authBack => 'Retour';

  @override
  String get authCountryUnavailable =>
      'Les informations du pays sont indisponibles pour cette version.';

  @override
  String get authSendingCodeTitle => 'Envoi du code';

  @override
  String get authSendingCodeMessage =>
      'Gardez cet écran ouvert pendant le démarrage de la connexion WhatsApp.';

  @override
  String get authSignInUnavailableTitle => 'Connexion indisponible';

  @override
  String get authRequestTimeoutTitle => 'La demande a expiré';

  @override
  String get authNumberLinkedTitle => 'Numéro déjà associé';

  @override
  String get authCheckNumberTitle => 'Vérifiez le numéro';

  @override
  String get authCodeNotSentTitle => 'Code non envoyé';

  @override
  String get authEditNumber => 'Modifier le numéro';

  @override
  String get authPhonePermissionMessage =>
      'Ce compte ne peut pas demander de code de connexion.';

  @override
  String get authPhoneTimeoutMessage =>
      'La demande de code a expiré. Vérifiez votre connexion et réessayez.';

  @override
  String get authPhoneConflictMessage =>
      'Ce numéro est déjà associé. Vérifiez-le ou utilisez le compte existant.';

  @override
  String get authPhoneInvalidMessage =>
      'Saisissez un numéro valide avec l’indicatif du pays.';

  @override
  String get authPhoneUnknownMessage =>
      'Le code de connexion n’a pas pu être envoyé. Réessayez.';

  @override
  String get authPhoneOfflineMessage =>
      'Connectez-vous à Internet pour envoyer un code WhatsApp.';

  @override
  String get authWhatsAppEyebrow => 'WhatsApp';

  @override
  String get authEnterNumberTitle => 'Saisissez le numéro';

  @override
  String get authEnterNumberBody =>
      'Nous enverrons un code de connexion privé.';

  @override
  String get authPhoneLabel => 'Téléphone';

  @override
  String get authWhatsAppNumberLabel => 'Numéro WhatsApp';

  @override
  String get authPhoneHint => '+250 7xx xxx xxx';

  @override
  String get authPhonePrivacy => 'Votre numéro reste privé.';

  @override
  String get authSendCode => 'Envoyer le code';

  @override
  String get authGuestSessionUnavailable =>
      'Impossible d’ouvrir une session invité. Réessayez.';

  @override
  String get authOtpInvalidMessage => 'Vérifiez le code et réessayez.';

  @override
  String get authOtpExpiredMessage => 'Demandez un nouveau code.';

  @override
  String get authNewCodeSent => 'Nouveau code WhatsApp envoyé.';

  @override
  String get authSendingNewCodeTitle => 'Envoi du nouveau code';

  @override
  String get authCheckingCodeTitle => 'Vérification du code';

  @override
  String get authSendingNewCodeMessage =>
      'Gardez cet écran ouvert pendant la demande d’un nouveau code.';

  @override
  String get authCheckingCodeMessage =>
      'Gardez cet écran ouvert pendant la vérification du code.';

  @override
  String get authVerificationUnavailableTitle => 'Vérification indisponible';

  @override
  String get authCodeExpiredTitle => 'Code expiré';

  @override
  String get authCodeNotAcceptedTitle => 'Code refusé';

  @override
  String get authVerificationFailedTitle => 'Échec de la vérification';

  @override
  String get authCheckCode => 'Vérifier le code';

  @override
  String get authOtpPermissionMessage =>
      'Ce compte ne peut pas vérifier le code demandé.';

  @override
  String get authOtpConflictMessage =>
      'Ce numéro est déjà associé à une autre connexion.';

  @override
  String get authOtpUnknownMessage =>
      'Le code n’a pas pu être vérifié. Réessayez.';

  @override
  String get authOtpOfflineMessage =>
      'Connectez-vous à Internet pour vérifier le code WhatsApp.';

  @override
  String get authPhoneMissingTitle => 'Numéro de téléphone manquant';

  @override
  String get authPhoneMissingMessage =>
      'Recommencez pour demander un code WhatsApp.';

  @override
  String get authChangeNumber => 'Changer de numéro';

  @override
  String authResendIn(int seconds) {
    return 'Renvoyer dans $seconds s';
  }

  @override
  String get authResendCode => 'Renvoyer le code';

  @override
  String get authCheckWhatsAppEyebrow => 'Vérifiez WhatsApp';

  @override
  String get authEnterCodeTitle => 'Saisissez le code';

  @override
  String get authEnterCodeBody => 'Envoyé à votre numéro WhatsApp.';

  @override
  String get authCodeLabel => 'Code';

  @override
  String get authWhatsAppCodeLabel => 'Code WhatsApp';

  @override
  String get authCodeHint => '••••••';

  @override
  String get authCodePrivacy => 'Code masqué pour protéger votre vie privée.';

  @override
  String get authVerifyCode => 'Vérifier le code';

  @override
  String get authVerifyAndContinue => 'Vérifier et continuer';

  @override
  String get homeRefreshingTitle => 'Actualisation de l’accueil';

  @override
  String get homeRefreshingMessage =>
      'Les informations du match, les points et les raccourcis restent visibles pendant le chargement.';

  @override
  String get homeUpdatesPausedTitle => 'Mises à jour en pause';

  @override
  String get homeSavedContentNotice =>
      'Le contenu enregistré de l’accueil est affiché. Reconnectez-vous et actualisez pour obtenir les nouvelles du club.';

  @override
  String get homeOfflineShortcutsNotice =>
      'Connectez-vous pour actualiser l’accueil. Les raccourcis enregistrés sont affichés.';

  @override
  String get homeLiveUnavailableNotice =>
      'Les données du club sont temporairement indisponibles. Tirez pour actualiser.';

  @override
  String get homePartialUnavailableNotice =>
      'Certaines données du club sont temporairement indisponibles. Tirez pour actualiser.';

  @override
  String get homePartialShortcutsUnavailableNotice =>
      'Certaines données du club sont temporairement indisponibles. Les raccourcis de l’accueil ne sont pas disponibles.';

  @override
  String get homeMatchdayPendingNotice =>
      'Les informations du match apparaîtront après leur publication.';

  @override
  String get homeOpenMatchday => 'Ouvrir le match';

  @override
  String get homeMatchdayUnavailable => 'Match indisponible';

  @override
  String get homeOpenMatchdaySemantic =>
      'Ouvrir le match dans la Zone supporters';

  @override
  String get homeMatchdayUnavailableSemantic =>
      'Le match est indisponible dans la Zone supporters';

  @override
  String get homeMatchdayTitle => 'Jour de match';

  @override
  String get homeNextFixturePending =>
      'Le prochain match apparaîtra ici après sa publication.';

  @override
  String get homeFixturesUnavailable =>
      'Les matchs du club ne sont pas encore disponibles.';

  @override
  String get homeOpenFanZone => 'Ouvrir la Zone supporters';

  @override
  String get homeSearchHint => 'Rechercher';

  @override
  String get homeSearchSemantic =>
      'Rechercher des supporters, matchs et portefeuille';

  @override
  String get homeNotifications => 'Notifications';

  @override
  String get homeWallet => 'Portefeuille';

  @override
  String get homeAccessUnavailableTitle => 'Accueil inaccessible';

  @override
  String get homeAccessUnavailableMessage =>
      'Votre compte ne peut pas charger l’accueil actuellement. Contactez l’assistance si vous devriez y avoir accès.';

  @override
  String get homeChangedTitle => 'Accueil modifié';

  @override
  String get homeChangedMessage =>
      'Les données de l’accueil ont changé pendant votre consultation. Actualisez pour charger la version actuelle.';

  @override
  String get homeSecurityTimeoutTitle => 'Vérification de l’accueil expirée';

  @override
  String get homeSecurityTimeoutMessage =>
      'L’accès actuel à l’accueil n’a pas pu être confirmé. Actualisez pour réessayer.';

  @override
  String get homeUnavailableTitle => 'Accueil indisponible';

  @override
  String get homeUnavailableMessage =>
      'Les données du club sont temporairement indisponibles.';

  @override
  String get homeSupportersTitle => 'Supporters';

  @override
  String get homeSupportersSubtitle => 'Les plus actifs';

  @override
  String homePoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pts',
      one: '1 pt',
      zero: '0 pt',
    );
    return '$_temp0';
  }

  @override
  String get homeNewsTitle => 'Actualités';

  @override
  String get homeLatestUpdates => 'Dernières nouvelles du club';

  @override
  String get homeLatestUnavailable =>
      'Les dernières nouvelles sont temporairement indisponibles. Tirez pour actualiser.';

  @override
  String get homeOpenMatchDetails => 'Ouvrir les détails du match';

  @override
  String homeMatchTitle(String home, String away) {
    return '$home contre $away';
  }

  @override
  String get homeShortcutsTitle => 'Raccourcis';

  @override
  String get homeLess => 'Moins';

  @override
  String get homeMore => 'Plus';

  @override
  String get homeHideMoreShortcuts => 'Masquer les autres raccourcis';

  @override
  String get homeShowMoreShortcuts => 'Afficher les autres raccourcis';

  @override
  String get homeMoreShortcuts => 'Autres raccourcis';

  @override
  String homeActionUnavailable(String action) {
    return '$action\nIndisponible';
  }

  @override
  String homeActionUnavailableInline(String action) {
    return '$action · Indisponible';
  }

  @override
  String homeActionOpensHint(String action) {
    return 'Ouvre $action';
  }

  @override
  String homeActionUnavailableHint(String action) {
    return '$action est indisponible';
  }

  @override
  String get homeTicketsAction => 'Billets';

  @override
  String get homeMembershipAction => 'Rejoindre Gikundiro';

  @override
  String get homeFanZoneAction => 'Zone supporters';

  @override
  String get homeShopAction => 'Boutique';

  @override
  String get homeFetLabel => 'FET';

  @override
  String get homeRankLabel => 'Classement';

  @override
  String get fanClubPreviewUnavailableTitle =>
      'Aperçu du fan-club indisponible';

  @override
  String get fanClubPreviewUnavailableMessage =>
      'Les détails du fan-club ne sont pas activés pour cette version ou ce club.';

  @override
  String get fanClubBackToSupporters => 'RETOUR AUX SUPPORTERS';

  @override
  String get fanClubUnavailableTitle => 'Fan-club indisponible';

  @override
  String get fanClubUnavailableMessage =>
      'Ce fan-club public approuvé est introuvable.';

  @override
  String get fanClubFallbackName => 'Fan-club';

  @override
  String get fanClubUnknownRegion => 'Inconnue';

  @override
  String get fanClubProtectedRequestPath => 'Accès protégé';

  @override
  String get fanClubActive => 'ACTIF';

  @override
  String get fanClubPendingReview => 'EN ATTENTE DE VALIDATION';

  @override
  String fanClubCurrentSemantic(String name) {
    return 'Fan-club actuel, $name';
  }

  @override
  String get fanClubAboutTitle => 'À PROPOS DE CE CLUB';

  @override
  String fanClubRegionValue(String region) {
    return 'Région : $region';
  }

  @override
  String get fanClubSnapshotTitle => 'APERÇU DU GROUPE';

  @override
  String get fanClubAwaitingApproval =>
      'Ce fan-club attend la validation d’un administrateur.';

  @override
  String get fanClubJoinRequestsReviewed =>
      'Les demandes d’adhésion sont examinées dans l’espace Supporters.';

  @override
  String fanClubRegionSentence(String region) {
    return 'Région : $region.';
  }

  @override
  String fanClubPublicSupporters(String members) {
    return '$members supporters affichés publiquement.';
  }

  @override
  String get fanClubUnavailableOfflineTitle =>
      'Fan-club indisponible hors ligne';

  @override
  String get fanClubUnavailableOfflineMessage =>
      'Connectez-vous pour confirmer les derniers détails approuvés.';

  @override
  String get fanClubAccessDeniedTitle => 'Accès au fan-club refusé';

  @override
  String get fanClubAccessDeniedMessage =>
      'Ce club n’est pas disponible pour le compte actuel.';

  @override
  String get fanClubDetailsChangedTitle => 'Les détails du fan-club ont changé';

  @override
  String get fanClubRefreshBeforeSupporters =>
      'Actualisez avant de continuer vers Supporters.';

  @override
  String get fanClubRefreshAction => 'ACTUALISER LE CLUB';

  @override
  String get fanClubTryAgainAction => 'RÉESSAYER';

  @override
  String get fanClubSecurityTimeoutTitle =>
      'La vérification de sécurité du fan-club a expiré';

  @override
  String get fanClubSecurityTimeoutMessage =>
      'Le club approuvé n’a pas pu être confirmé en toute sécurité. Réessayez.';

  @override
  String get fanClubLoadFailureTitle => 'Impossible de charger le fan-club';

  @override
  String get fanClubLoadFailureMessage =>
      'Le club approuvé n’a pas pu être confirmé. Réessayez.';

  @override
  String get fanClubShowingSavedTitle => 'Fan-club enregistré affiché';

  @override
  String get fanClubSavedDetailsMayChange =>
      'Les informations d’adhésion et de match peuvent avoir changé.';

  @override
  String get fanClubRefreshingTitle => 'Actualisation du fan-club';

  @override
  String get fanClubLastConfirmedVisible =>
      'Les derniers détails confirmés restent affichés.';

  @override
  String get fanClubLastConfirmedRefresh =>
      'Voici les derniers détails confirmés. Actualisez avant de continuer.';

  @override
  String get fanClubCheckTimedOutTitle =>
      'La vérification du fan-club a expiré';

  @override
  String get fanClubAccessChangedTitle => 'L’accès au fan-club a changé';

  @override
  String get fanClubAccessChangedMessage =>
      'Les détails enregistrés sont en lecture seule. Retournez à Supporters.';

  @override
  String get fanClubRefreshFailedTitle =>
      'Échec de l’actualisation du fan-club';

  @override
  String get fanClubMatchdayAgenda => 'PROGRAMME DU JOUR DE MATCH';

  @override
  String fanClubMatchMeta(String competition, String venue) {
    return '$competition  •  $venue';
  }

  @override
  String fanClubMatchSchedule(String date, String time) {
    return '$date  •  $time';
  }

  @override
  String get fanClubMembersLabel => 'MEMBRES';

  @override
  String get fanClubStatusLabel => 'STATUT';

  @override
  String get fanClubRegionLabel => 'RÉGION';

  @override
  String get fanClubOpenSupportersSemantic => 'Ouvrir l’espace Supporters';

  @override
  String get fanClubPendingReviewSemantic =>
      'Fan-club en attente de validation';

  @override
  String get fanClubSupportersAction => 'SUPPORTERS';

  @override
  String get fanClubOpenSupportersAction => 'OUVRIR SUPPORTERS';

  @override
  String get fanClubCopyLink => 'COPIER LE LIEN';

  @override
  String get fanClubCopyLinkSemantic => 'Copier le lien du fan-club';

  @override
  String fanClubShareFallback(String appName) {
    return 'Ouvrez $appName et consultez la section Fan-clubs.';
  }

  @override
  String fanClubShareText(String appName, String target) {
    return 'Rejoignez ce fan-club $appName : $target';
  }

  @override
  String get fanClubLinkCopied => 'Lien du fan-club copié.';

  @override
  String get fanClubsLoadError =>
      'Impossible de charger les fan-clubs pour le moment.';

  @override
  String get fanClubReviewRequestSent =>
      'Demande envoyée pour validation. Vous ne serez membre qu’après l’approbation du club.';

  @override
  String get fanClubsCommunityEyebrow => 'LA COMMUNAUTÉ';

  @override
  String get fanClubsTitle => 'FAN-CLUBS';

  @override
  String get fanClubsSearchHint => 'Rechercher des clubs ou des lieux';

  @override
  String get fanClubsFeaturedChapter => 'SECTION À LA UNE';

  @override
  String get fanClubOfficialChapterFallback =>
      'Section officielle de supporters.';

  @override
  String fanClubMembersValue(String members) {
    return '$members membres';
  }

  @override
  String fanClubRegionMembers(String region, String members) {
    return '$region • $members';
  }

  @override
  String get fanClubReviewRequested => 'Validation demandée';

  @override
  String get fanClubRequestReview => 'Demander la validation';

  @override
  String get fanClubDetailsAction => 'Détails';
}
