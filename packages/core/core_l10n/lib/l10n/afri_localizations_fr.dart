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

  @override
  String get liveMatchLoadError =>
      'Impossible de charger le centre du match en direct pour le moment.';

  @override
  String get liveStatusLive => 'EN DIRECT';

  @override
  String get liveStatusHalfTime => 'MI-TEMPS';

  @override
  String get liveStatusFullTime => 'TERMINÉ';

  @override
  String get liveStatusPostponed => 'REPORTÉ';

  @override
  String get liveStatusCancelled => 'ANNULÉ';

  @override
  String get liveStatusUpcoming => 'À VENIR';

  @override
  String get liveStatusFinal => 'FINAL';

  @override
  String liveTimeVenue(String time, String venue) {
    return '$time  •  $venue';
  }

  @override
  String get liveMatchUpdate => 'Mise à jour du match';

  @override
  String liveMatchTeamsUpper(String home, String away) {
    return '$home CONTRE $away';
  }

  @override
  String get liveModeActive =>
      'Le direct est actif. Les événements apparaissent en temps réel.';

  @override
  String get liveMatchReport => 'RAPPORT DU MATCH';

  @override
  String get liveMatchFinishedPending => 'Match terminé. Résumé en attente.';

  @override
  String get liveMatchdayIntel => 'INFOS DU JOUR DE MATCH';

  @override
  String get liveFixturePublished =>
      'Match publié. Les mises à jour commenceront peu avant le coup d’envoi.';

  @override
  String get liveStatPossession => 'Possession';

  @override
  String get liveStatShots => 'Tirs';

  @override
  String get liveStatCorners => 'Corners';

  @override
  String get liveStatPending => 'À CONFIRMER';

  @override
  String get liveMatchCenter => 'Centre du match';

  @override
  String get liveMyPredictions => 'Mes pronostics';

  @override
  String liveScore(int homeScore, int awayScore) {
    return '$homeScore - $awayScore';
  }

  @override
  String get liveMatchIntel => 'Infos du match';

  @override
  String get liveBrowsePredictions => 'Voir les pronostics';

  @override
  String get liveShareMatch => 'Partager le match';

  @override
  String liveShareText(
    String appName,
    String homeTeam,
    int homeScore,
    int awayScore,
    String awayTeam,
    String status,
  ) {
    return '$appName : $homeTeam $homeScore-$awayScore $awayTeam ($status)';
  }

  @override
  String get liveMatchCopied => 'Mise à jour du match copiée.';

  @override
  String get liveCenterUnavailable => 'CENTRE DU DIRECT INDISPONIBLE';

  @override
  String get liveRefresh => 'Actualiser';

  @override
  String get newsArticleNotFoundTitle => 'Article introuvable';

  @override
  String get newsArticleNotFoundMessage =>
      'Cette actualité a peut-être été supprimée ou n’est plus disponible.';

  @override
  String get newsBackToLiveMatch => 'Retour au match en direct';

  @override
  String get newsClubNews => 'Actualités du club';

  @override
  String newsArticleImageSemantic(String title) {
    return 'Image de l’article $title';
  }

  @override
  String get newsRefreshingTitle => 'Actualisation de l’article';

  @override
  String get newsRefreshingMessage =>
      'L’article confirmé reste affiché pendant la vérification de la dernière version.';

  @override
  String get newsRelatedUnavailableTitle => 'Actualités liées indisponibles';

  @override
  String get newsRelatedUnavailableMessage =>
      'Vous pouvez lire cet article, mais la navigation vers les actualités liées est désactivée pour cette version.';

  @override
  String get newsShowingSavedTitle => 'Article enregistré affiché';

  @override
  String get newsShowingSavedMessage =>
      'Reconnectez-vous et actualisez avant d’ouvrir une autre actualité.';

  @override
  String newsSelectedSemantic(String title) {
    return 'Article sélectionné $title';
  }

  @override
  String get newsToday => 'Aujourd’hui';

  @override
  String newsMetadata(String date) {
    return 'Actualités du club  ·  $date  ·  Service médias';
  }

  @override
  String get newsRelatedIntel => 'Actualités liées';

  @override
  String get newsRefreshArticle => 'ACTUALISER L’ARTICLE';

  @override
  String get newsConnectionRestored => 'Connexion rétablie';

  @override
  String get newsArticleOffline => 'Article hors ligne';

  @override
  String get newsRefreshLatest =>
      'Actualisez pour confirmer la dernière version.';

  @override
  String get newsReconnectLatest =>
      'Reconnectez-vous pour charger la dernière version.';

  @override
  String get newsAccessUnavailableTitle => 'Accès à l’article indisponible';

  @override
  String get newsAccessUnavailableMessage =>
      'Le compte actuel ne peut pas consulter cette actualité.';

  @override
  String get newsChangedTitle => 'L’article a changé';

  @override
  String get newsChangedMessage =>
      'Actualisez avant d’ouvrir une autre actualité.';

  @override
  String get newsSecurityTimeoutTitle =>
      'La vérification de sécurité de l’article a expiré';

  @override
  String get newsSecurityTimeoutMessage =>
      'Aucune nouvelle version n’a été confirmée. Actualisez pour réessayer.';

  @override
  String get newsUnavailableTitle => 'Article indisponible';

  @override
  String get newsUnavailableMessage =>
      'La dernière version n’a pas pu être confirmée. Actualisez pour réessayer.';

  @override
  String liveTeamLogoSemantic(String label) {
    return 'Logo de l’équipe $label';
  }

  @override
  String get liveTeamFallback => 'Équipe';

  @override
  String liveMatchEventSemantic(String event) {
    return 'Événement du match : $event';
  }

  @override
  String get liveEventGoal => 'but';

  @override
  String get liveEventCard => 'carton';

  @override
  String get liveEventSubstitution => 'remplacement';

  @override
  String get liveEventVarReview => 'vérification VAR';

  @override
  String get liveEventUpdate => 'mise à jour';

  @override
  String liveStatSemantic(String label, String value) {
    return '$label $value';
  }

  @override
  String get shopAllCategory => 'Tous';

  @override
  String get shopProductFallback => 'Produit';

  @override
  String shopProductAdded(String name) {
    return '$name ajouté au panier.';
  }

  @override
  String get shopStoreTitle => 'Boutique';

  @override
  String get shopTitle => 'Boutique';

  @override
  String get shopSearch => 'Rechercher';

  @override
  String get shopSearchProducts => 'Rechercher des produits';

  @override
  String get shopViewCart => 'Voir le panier';

  @override
  String get shopCart => 'Panier';

  @override
  String get shopBack => 'Retour';

  @override
  String get shopNoProductsTitle => 'Aucun produit disponible';

  @override
  String shopNoProductsCategoryTitle(String category) {
    return 'Aucun produit dans $category';
  }

  @override
  String get shopNoProductsMessage =>
      'Les produits officiels apparaîtront ici lorsque le club publiera son stock.';

  @override
  String get shopNoProductsCategoryMessage =>
      'Essayez une autre catégorie ou effacez le filtre pour voir toute la boutique.';

  @override
  String get shopRetry => 'Réessayer';

  @override
  String get shopRefresh => 'Actualiser';

  @override
  String get shopShowAll => 'Tout afficher';

  @override
  String get shopRefreshingTitle => 'Actualisation de la boutique';

  @override
  String get shopRefreshingMessage =>
      'Le stock actuel est en cours de vérification.';

  @override
  String get shopSavedTitle => 'Contenu enregistré de la boutique';

  @override
  String get shopSavedMessage =>
      'Le stock peut être obsolète. Reconnectez-vous et actualisez avant de payer.';

  @override
  String get shopRefreshingSemantic =>
      'Information : actualisation de la boutique. Le stock actuel est en cours de vérification.';

  @override
  String get shopSavedSemantic =>
      'Avertissement : contenu enregistré. Le stock peut être obsolète. Reconnectez-vous avant de payer.';

  @override
  String get shopClubStore => 'Boutique du club';

  @override
  String shopItemsAvailable(int count) {
    return '$count articles disponibles.';
  }

  @override
  String get shopOfflineTitle => 'Boutique hors ligne';

  @override
  String get shopOfflineMessage =>
      'Connectez-vous pour charger les produits actuels du club.';

  @override
  String get shopAccessTitle => 'Accès à la boutique indisponible';

  @override
  String get shopAccessMessage =>
      'Ce compte ne peut pas charger les produits du club. Contactez l’assistance si cet accès devrait être disponible.';

  @override
  String get shopInventoryChangedTitle => 'Le stock de la boutique a changé';

  @override
  String get shopInventoryChangedMessage =>
      'La disponibilité des produits a changé pendant le chargement. Actualisez avant d’ajouter un produit.';

  @override
  String get shopSecurityTimeoutTitle =>
      'Délai de sécurité de la boutique dépassé';

  @override
  String get shopSecurityTimeoutMessage =>
      'La vérification sécurisée du stock a pris trop de temps. Actualisez pour réessayer.';

  @override
  String get shopUnavailableTitle => 'Boutique indisponible';

  @override
  String get shopUnavailableMessage =>
      'Impossible de charger les produits pour le moment.';

  @override
  String get shopOutOfStockUpper => 'RUPTURE DE STOCK';

  @override
  String get shopOutOfStock => 'Rupture de stock';

  @override
  String get shopAddToCart => 'Ajouter au panier';

  @override
  String shopProductImageSemantic(String name) {
    return 'Image du produit $name';
  }

  @override
  String shopProductUnavailableSemantic(String name) {
    return '$name, actuellement en rupture de stock';
  }

  @override
  String get shopOpenProduct => 'Ouvrir le produit';

  @override
  String get shopSearchHint => 'Rechercher maillots, écharpes et nouveautés';

  @override
  String get shopMerchFallback => 'Produits';

  @override
  String shopQuantityValue(int quantity) {
    return 'Qté $quantity';
  }

  @override
  String get shopDecreaseQuantity => 'Diminuer la quantité';

  @override
  String get shopIncreaseQuantity => 'Augmenter la quantité';

  @override
  String get shopRemove => 'Retirer';

  @override
  String get shopReadyToCheckout => 'Prêt à payer';

  @override
  String get shopCheckout => 'Payer';

  @override
  String get shopItemOutOfStockToast =>
      'Cet article est actuellement en rupture de stock.';

  @override
  String get shopSelectSizeToast =>
      'Sélectionnez une taille avant d’ajouter au panier.';

  @override
  String get shopViewCartAction => 'Voir le panier';

  @override
  String get shopProductNotFoundTitle => 'Produit introuvable';

  @override
  String get shopProductNotFoundMessage =>
      'Cet article n’est plus disponible dans la boutique actuelle du club.';

  @override
  String get shopBackToStore => 'Retour à la boutique';

  @override
  String get shopProductOfflineTitle => 'Détails du produit hors ligne';

  @override
  String get shopProductOfflineMessage =>
      'Reconnectez-vous pour vérifier le prix, la taille et la disponibilité.';

  @override
  String get shopProductAccessTitle => 'Accès au produit indisponible';

  @override
  String get shopProductAccessMessage =>
      'Ce produit ne peut pas être ouvert avec le compte actuel.';

  @override
  String get shopProductChangedTitle => 'Les détails du produit ont changé';

  @override
  String get shopProductChangedMessage =>
      'Actualisez pour charger le prix, les tailles et la disponibilité actuels.';

  @override
  String get shopProductSecurityTitle => 'Délai de sécurité du produit dépassé';

  @override
  String get shopProductSecurityMessage =>
      'La vérification sécurisée du produit a pris trop de temps. Actualisez avant d’acheter.';

  @override
  String get shopProductUnavailableTitle => 'Produit indisponible';

  @override
  String get shopProductUnavailableMessage =>
      'Impossible de charger les derniers détails du produit.';

  @override
  String get shopLoadingProductName => 'Chargement du maillot officiel';

  @override
  String get shopLoadingProductDescription =>
      'Chargement des détails des produits officiels...';

  @override
  String get shopLoadingBadge => 'CHARGEMENT';

  @override
  String get shopOfficialMerchandise => 'Produit officiel du club.';

  @override
  String get shopCloseProductDetails => 'Fermer les détails du produit';

  @override
  String get shopRefreshingProductTitle => 'Actualisation du produit';

  @override
  String get shopRefreshingProductMessage =>
      'Le prix, les tailles et la disponibilité sont en cours de vérification.';

  @override
  String get shopSavedProductTitle => 'Détails du produit enregistrés';

  @override
  String get shopSavedProductMessage =>
      'Reconnectez-vous pour actualiser le prix, les tailles et la disponibilité avant d’acheter.';

  @override
  String get shopInStock => 'EN STOCK';

  @override
  String shopStockAvailable(int count) {
    return '$count DISPONIBLES';
  }

  @override
  String get shopSelectSize => 'Choisir une taille';

  @override
  String shopSizeTooltip(String size) {
    return 'Taille $size';
  }

  @override
  String get shopSizeSelectedHint => 'Sélectionnée';

  @override
  String get shopSizeAvailableHint => 'Disponible';

  @override
  String get shopQuantity => 'Quantité';

  @override
  String get shopTotal => 'Total';

  @override
  String get shopBuyNow => 'Acheter maintenant';

  @override
  String get shopConnectPaymentAvailability =>
      'Connectez-vous pour vérifier les moyens de paiement actuels.';

  @override
  String get shopPaymentSetupPending =>
      'La configuration du paiement attend l’activation du club.';

  @override
  String get shopPaymentCheckError =>
      'Impossible de vérifier les paiements. Votre panier et votre adresse sont conservés.';

  @override
  String get shopConnectBeforeCheckout =>
      'Connectez-vous avant de payer. Votre panier et votre adresse sont conservés.';

  @override
  String get shopAddressRequired =>
      'Saisissez d’abord une adresse de livraison.';

  @override
  String get shopMomoSetupPending =>
      'La configuration du paiement MOMO attend l’activation du club.';

  @override
  String shopOrderDialerFailure(String orderId) {
    return 'La commande $orderId a été enregistrée, mais le composeur MOMO n’a pas pu s’ouvrir.';
  }

  @override
  String shopOrderCreated(String orderId) {
    return 'Commande $orderId créée. La vérification du paiement est toujours en attente.';
  }

  @override
  String get shopReviewOrder => 'Vérifier la commande';

  @override
  String shopItemQuantitySummary(String name, int quantity) {
    return '$name x$quantity';
  }

  @override
  String shopMoreItems(int count) {
    return '+$count autres articles';
  }

  @override
  String get shopDeliverTo => 'Livrer à';

  @override
  String get shopPaymentInstructions =>
      'Approuvez la demande MOMO sur votre appareil, puis confirmez ici. La commande reste en attente jusqu’à la vérification.';

  @override
  String get shopPaymentSubmitted => 'J’ai soumis le paiement';

  @override
  String get shopCartEmptyTitle => 'Le panier est vide';

  @override
  String get shopCartEmptyMessage =>
      'Ajoutez des articles depuis la boutique pour commencer.';

  @override
  String get shopBackToShop => 'Retour à la boutique';

  @override
  String get shopDelivery => 'Livraison';

  @override
  String get shopAddressAndTotal => 'Adresse et total';

  @override
  String get shopDeliveryAddress => 'Adresse de livraison';

  @override
  String get shopEnterDeliveryAddress => 'Saisissez votre adresse de livraison';

  @override
  String shopStreetCityCountry(String country) {
    return 'Rue, ville, $country';
  }

  @override
  String get shopSubtotal => 'Sous-total';

  @override
  String get shopCheckingPayment => 'Vérification du paiement';

  @override
  String get shopCheckingPaymentMessage =>
      'Confirmation du moyen de paiement MOMO actuel de ce club.';

  @override
  String get shopPaymentCheckFailed => 'Échec de la vérification du paiement';

  @override
  String get shopCheckoutUnavailable => 'Paiement indisponible';

  @override
  String shopPayTo(String label) {
    return 'Payer à $label';
  }

  @override
  String get shopReviewCart => 'Vérifier le panier';

  @override
  String get shopConnectionRequired => 'Connexion requise';

  @override
  String get shopPaymentRouteNotReady => 'Moyen de paiement non prêt';

  @override
  String get shopCheckoutNotPermitted => 'Paiement non autorisé';

  @override
  String get shopStatusUncertain => 'Statut incertain';

  @override
  String get shopProcessing => 'Traitement';

  @override
  String get shopPayWithMomo => 'Payer avec MOMO';

  @override
  String get shopCheckoutViaMomo => 'Payer via MOMO';

  @override
  String get shopOrderUncertainTitle =>
      'Le statut de la commande est incertain';

  @override
  String get shopOrderUncertainMessage =>
      'Le paiement sécurisé a expiré. Votre panier et votre adresse sont conservés. Ne recommencez pas avant confirmation du club.';

  @override
  String get shopOrderChangedTitle => 'Les détails de la commande ont changé';

  @override
  String get shopOrderChangedMessage =>
      'La commande a changé pendant l’envoi. Votre panier et votre adresse sont conservés. Vérifiez-les avant de réessayer.';

  @override
  String get shopCheckoutDeniedMessage =>
      'Votre compte ne peut pas passer cette commande. Votre panier et votre adresse sont conservés. Contactez l’assistance du club.';

  @override
  String get shopCheckoutFailureTitle => 'Le paiement n’a pas pu démarrer';

  @override
  String get shopCheckoutFailureMessage =>
      'Aucune commande n’a été confirmée. Votre panier et votre adresse sont conservés. Vérifiez-les puis réessayez.';

  @override
  String get shopSampleProductName => 'Maillot domicile Rayon';

  @override
  String get shopSampleProductDescription =>
      'Maillot officiel de match avec écusson tissé, tissu respirant et finitions bleues pour tous les supporters.';

  @override
  String get shopOfficialBadge => 'OFFICIEL';

  @override
  String get shopSampleProductSummary =>
      'Tenue officielle · S M L XL · 47 disponibles';

  @override
  String get shopProductImageUnavailable => 'Image du produit indisponible';

  @override
  String get shopOfficialKit => 'Tenue officielle Rayon';

  @override
  String get shopPremiumMerchandise => 'Produit premium de jour de match';

  @override
  String get ticketQrAccessUnavailableTitle =>
      'Accès au billet électronique indisponible';

  @override
  String get ticketQrAccessUnavailableMessage =>
      'Les codes d’entrée sont désactivés dans cette version. Consultez votre portefeuille de billets pour le statut.';

  @override
  String get ticketNotFoundTitle => 'Billet introuvable';

  @override
  String get ticketUnavailableShort => 'Billet électronique indisponible.';

  @override
  String get ticketPaymentPendingTitle => 'Vérification du paiement en attente';

  @override
  String get ticketPaymentPendingMessage =>
      'La demande a été enregistrée, mais le code QR sera débloqué après vérification du paiement.';

  @override
  String get ticketEntryCode => 'Code d’entrée du billet';

  @override
  String get ticketScannerHelper =>
      'Présentez-le uniquement à un scanner officiel le jour du match.';

  @override
  String get ticketDateLabel => 'DATE';

  @override
  String get ticketTimeLabel => 'HEURE';

  @override
  String get ticketVenueLabel => 'LIEU';

  @override
  String get ticketAppleWallet => 'Apple Wallet';

  @override
  String get ticketGoogleWallet => 'Google Wallet';

  @override
  String get ticketWalletExportUnavailable =>
      'L’export vers un portefeuille n’est pas encore disponible dans cette version.';

  @override
  String ticketSelectedSemantic(String match) {
    return 'Billet électronique sélectionné : $match';
  }

  @override
  String get ticketOfflineTitle => 'Billet électronique hors ligne';

  @override
  String get ticketOfflineMessage =>
      'Reconnectez-vous avant de charger ce code d’entrée.';

  @override
  String get ticketAccessDeniedTitle => 'Accès au billet refusé';

  @override
  String get ticketAccessDeniedMessage =>
      'Ce billet ne peut pas être ouvert avec le compte actuel.';

  @override
  String get ticketChangedTitle => 'Le billet a changé';

  @override
  String get ticketChangedMessage =>
      'Actualisez votre portefeuille avant de présenter ce code.';

  @override
  String get ticketSecurityTimeoutTitle =>
      'Délai de sécurité du billet dépassé';

  @override
  String get ticketSecurityTimeoutMessage =>
      'Le code d’entrée n’a pas été confirmé. Actualisez avant l’entrée au match.';

  @override
  String get ticketUnavailableTitle => 'Billet indisponible';

  @override
  String get ticketUnavailableMessage =>
      'Ce billet n’a pas pu être confirmé depuis votre portefeuille.';

  @override
  String get ticketRefreshAction => 'Actualiser le billet';

  @override
  String get ticketSavedCodeTitle => 'Code d’entrée enregistré affiché';

  @override
  String get ticketRefreshingTitle => 'Actualisation du billet';

  @override
  String get ticketAccessChangedTitle => 'L’accès aux billets a changé';

  @override
  String get ticketCheckTimedOutTitle => 'La vérification du billet a expiré';

  @override
  String get ticketRefreshUnavailableTitle =>
      'Actualisation du billet indisponible';

  @override
  String get ticketSavedCodeMessage =>
      'Reconnectez-vous et actualisez avant de présenter ce code à l’entrée.';

  @override
  String get ticketRefreshingMessage =>
      'Le dernier code confirmé reste visible pendant la vérification du portefeuille.';

  @override
  String get ticketRefreshBeforeUse =>
      'Actualisez avant de vous fier à ce code d’entrée.';

  @override
  String get ticketRefreshUpper => 'ACTUALISER LE BILLET';

  @override
  String get ticketWalletUnavailableTitle =>
      'Portefeuille de billets indisponible';

  @override
  String get ticketWalletUnavailableMessage =>
      'Impossible de charger votre portefeuille. Vérifiez votre connexion et réessayez.';

  @override
  String get ticketMyTickets => 'MES BILLETS';

  @override
  String get ticketRefreshTickets => 'Actualiser les billets';

  @override
  String get ticketUpcoming => 'À VENIR';

  @override
  String get ticketPast => 'PASSÉS';

  @override
  String get ticketBrowseMatches => 'Parcourir les matchs';

  @override
  String get ticketOpenQr => 'Ouvrir le code QR du billet';

  @override
  String ticketWalletSemantic(String match, String status, String seat) {
    return '$match, billet $status, $seat';
  }

  @override
  String ticketSeatPrice(String seat, String price) {
    return '$seat • $price';
  }

  @override
  String get ticketPendingQrMessage =>
      'Le paiement reçu sur votre téléphone doit encore être vérifié avant le déblocage du QR.';

  @override
  String get ticketCheckoutSummary => 'RÉCAPITULATIF';

  @override
  String get ticketMatchLabel => 'Match';

  @override
  String get ticketSeatTypeLabel => 'Type de place';

  @override
  String get ticketQuantityLabel => 'Quantité';

  @override
  String get ticketSeatCodeLabel => 'Code de place';

  @override
  String get ticketTotalLabel => 'Total';

  @override
  String get ticketPaymentRouteLabel => 'Moyen de paiement';

  @override
  String ticketPayToDialer(String label) {
    return 'Payer à $label\nLe composeur ouvrira la demande USSD.';
  }

  @override
  String get ticketSoldOut => 'Complet';

  @override
  String get ticketPayViaMomo => 'Payer via MOMO';

  @override
  String get ticketConfirmAfterMomo =>
      'Confirmez après avoir terminé la demande MOMO.';

  @override
  String get ticketConfirmPurchase => 'CONFIRMER L’ACHAT';

  @override
  String get ticketMatchUpper => 'MATCH';

  @override
  String get ticketZoneUpper => 'ZONE';

  @override
  String get ticketSeatUpper => 'PLACE';

  @override
  String get ticketQuantityUpper => 'QUANTITÉ';

  @override
  String get ticketServiceFeeUpper => 'FRAIS DE SERVICE';

  @override
  String get ticketTotalUpper => 'TOTAL';

  @override
  String get ticketIncluded => 'Inclus';

  @override
  String ticketMomoValue(String label) {
    return 'MOMO : $label';
  }

  @override
  String get ticketConfirmPaymentWarning =>
      'Confirmez uniquement après le paiement MoMo sur votre téléphone.';

  @override
  String get ticketCompletedPayment => 'J’ai effectué le paiement';

  @override
  String get ticketDidNotPay => 'Je n’ai pas payé';

  @override
  String ticketMatchVersus(String home, String away) {
    return '$home contre $away';
  }

  @override
  String ticketCompetitionVenue(String competition, String venue) {
    return '$competition  •  $venue';
  }

  @override
  String ticketRemainingCapacity(int count) {
    return 'Capacité restante : $count';
  }

  @override
  String get ticketChooseAccess => 'CHOISIR L’ACCÈS';

  @override
  String get ticketGeneral => 'GÉNÉRAL';

  @override
  String get ticketGeneralSubtitle => 'Tribunes ouvertes';

  @override
  String get ticketVip => 'VIP';

  @override
  String get ticketVipSubtitle => 'Places premium en salon';

  @override
  String get ticketChooseSeat => 'CHOISIR UNE PLACE';

  @override
  String get ticketChangeSeat => 'CHANGER LA PLACE';

  @override
  String get ticketReview => 'Vérifier';

  @override
  String get ticketReviewReservation => 'Vérifier la réservation';

  @override
  String get ticketOfficialCategories => 'CATÉGORIES OFFICIELLES';

  @override
  String get ticketOfficialCategoriesMessage =>
      'Tarifs publics approuvés. La disponibilité apparaît lorsque le club active une vente officielle.';

  @override
  String get ticketListTitle => 'BILLETS';

  @override
  String get ticketFilterMatches => 'Filtrer les matchs';

  @override
  String get ticketMatchFilters => 'Filtres des matchs';

  @override
  String get ticketSortSoonest => 'Le plus proche';

  @override
  String get ticketSortLatest => 'Le plus récent';

  @override
  String get ticketSortCheapest => 'Le moins cher';

  @override
  String get ticketTypeAvailable => 'Disponible';

  @override
  String get ticketTypeSoldOut => 'Épuisé';

  @override
  String get ticketTypeVipZones => 'Zones VIP';

  @override
  String get ticketRefreshMatches => 'Actualiser les matchs';

  @override
  String get ticketRefreshMatchesOffline =>
      'Connexion requise pour actualiser les matchs';

  @override
  String get ticketNext => 'SUIVANT';

  @override
  String get ticketMine => 'MES BILLETS';

  @override
  String get ticketUpcomingSemantic => 'Billets à venir';

  @override
  String get ticketPastSemantic => 'Billets passés';

  @override
  String get ticketMineSemantic => 'Mes billets';

  @override
  String get ticketRefreshingInventoryTitle => 'Actualisation des billets';

  @override
  String get ticketRefreshingInventoryMessage =>
      'Les matchs et leur disponibilité sont en cours de vérification.';

  @override
  String get ticketSavedInventoryTitle => 'Billets enregistrés';

  @override
  String get ticketSavedInventoryMessage =>
      'La disponibilité peut être obsolète. Reconnectez-vous avant l’achat.';

  @override
  String get ticketNoUpcomingTitle => 'Aucun match avec billetterie à venir';

  @override
  String get ticketNoUpcomingMessage =>
      'Les billets à venir apparaîtront ici lorsque le club ouvrira les ventes du prochain match.';

  @override
  String get ticketNoPastTitle => 'Aucun ancien match avec billetterie';

  @override
  String get ticketNoPastMessage =>
      'Les anciens matchs apparaîtront ici après la clôture des ventes du jour de match.';

  @override
  String get ticketRefresh => 'Actualiser';

  @override
  String get ticketStatusSoldOut => 'ÉPUISÉ';

  @override
  String get ticketStatusAvailable => 'DISPONIBLE';

  @override
  String get ticketFrom => 'À PARTIR DE';

  @override
  String get ticketBuyAction => 'Acheter un billet';

  @override
  String get ticketSalesNotOpen => 'Ventes non ouvertes';

  @override
  String get ticketVersusUpper => 'CONTRE';

  @override
  String get ticketListOfflineTitle => 'Connectez-vous pour voir les billets';

  @override
  String get ticketListOfflineMessage =>
      'Reconnectez-vous pour charger les matchs et la disponibilité des billets.';

  @override
  String get ticketConnectionRequired => 'Connexion requise';

  @override
  String get ticketListAccessTitle => 'Accès aux billets indisponible';

  @override
  String get ticketListAccessMessage =>
      'Ce compte ne peut pas charger la billetterie du club. Contactez le support du club si l’accès devrait être disponible.';

  @override
  String get ticketAccessRequired => 'Accès requis';

  @override
  String get ticketInventoryChangedTitle => 'La billetterie a changé';

  @override
  String get ticketInventoryChangedMessage =>
      'Le match ou la disponibilité a changé pendant le chargement. Actualisez avant de choisir un billet.';

  @override
  String get ticketInventorySecurityTitle =>
      'Délai de sécurité des billets dépassé';

  @override
  String get ticketInventorySecurityMessage =>
      'La vérification sécurisée a pris trop de temps. Actualisez pour réessayer.';

  @override
  String get ticketFixturesUnavailableTitle =>
      'Impossible de charger les matchs';

  @override
  String get ticketFixturesUnavailableMessage =>
      'La billetterie est indisponible pour le moment. Vérifiez votre connexion et réessayez.';

  @override
  String get ticketRetry => 'Réessayer';

  @override
  String get ticketPaymentAvailabilityOffline =>
      'Connectez-vous pour vérifier la disponibilité actuelle du paiement des billets.';

  @override
  String get ticketPaymentSetupPending =>
      'La configuration du paiement attend l’activation du club.';

  @override
  String get ticketPaymentVerificationUnavailable =>
      'La vérification du mode de paiement est indisponible. Réessayez.';

  @override
  String get ticketConnectBeforePurchase =>
      'Connectez-vous avant l’achat. Votre place et votre quantité restent sélectionnées.';

  @override
  String get ticketSignInBeforePurchase =>
      'Connectez-vous d’abord pour acheter des billets.';

  @override
  String get ticketMomoSetupPending =>
      'La billetterie MOMO attend l’activation du club.';

  @override
  String get ticketReservationFailed =>
      'La réservation du billet a échoué. Réessayez depuis l’écran du match.';

  @override
  String get ticketDialerOpenFailed =>
      'La demande de billet a été enregistrée, mais le composeur MOMO ne s’est pas ouvert.';

  @override
  String ticketRequestsSubmitted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count demandes de billets envoyées — vérification en attente.',
      one: 'Demande de billet envoyée — vérification du paiement en attente.',
    );
    return '$_temp0';
  }

  @override
  String get ticketConfirmationTimedOut =>
      'La confirmation du billet a expiré. Consultez Mes billets avant de réessayer.';

  @override
  String get ticketRequestFailed =>
      'La demande de billet a échoué. Votre sélection reste disponible.';

  @override
  String get ticketMatchDay => 'JOUR DE MATCH';

  @override
  String get ticketSalesUnavailableTitle => 'Vente de billets indisponible';

  @override
  String get ticketSalesUnavailableMessage =>
      'La sélection de billets n’est pas activée pour cette version ou ce club.';

  @override
  String get ticketBackToTickets => 'Retour aux billets';

  @override
  String get ticketFixtureNotFoundTitle => 'Match introuvable';

  @override
  String get ticketFixtureNotFoundMessage => 'Ce match est indisponible.';

  @override
  String get ticketDetailOfflineTitle =>
      'Détails des billets indisponibles hors ligne';

  @override
  String get ticketDetailOfflineMessage =>
      'Connectez-vous pour charger ce match et la disponibilité actuelle.';

  @override
  String get ticketDetailAccessTitle => 'Accès aux billets refusé';

  @override
  String get ticketDetailAccessMessage =>
      'Ce match n’est pas disponible pour le compte du club actuel.';

  @override
  String get ticketDetailSecurityTitle =>
      'Délai de sécurité des billets dépassé';

  @override
  String get ticketDetailSecurityMessage =>
      'Le match n’a pas pu être confirmé de façon sûre. Réessayez.';

  @override
  String get ticketDetailChangedTitle => 'Les détails du match ont changé';

  @override
  String get ticketDetailChangedMessage =>
      'Actualisez le match avant de choisir un accès.';

  @override
  String get ticketDetailUnavailableTitle => 'Impossible de charger ce match';

  @override
  String get ticketDetailUnavailableMessage =>
      'Le match n’a pas pu être confirmé. Réessayez.';

  @override
  String get ticketTryAgainUpper => 'RÉESSAYER';

  @override
  String get ticketRefreshFixtureUpper => 'ACTUALISER LE MATCH';

  @override
  String get ticketSavedFixtureTitle => 'Match enregistré affiché';

  @override
  String get ticketSavedFixtureMessage =>
      'Les prix peuvent avoir changé. Reconnectez-vous avant de vérifier ou d’acheter.';

  @override
  String get ticketRefreshingFixtureTitle => 'Actualisation du match';

  @override
  String get ticketRefreshingFixtureMessage =>
      'Les dernières options confirmées restent visibles.';

  @override
  String get ticketFixtureChangedTitle => 'Le match a changé';

  @override
  String get ticketLastConfirmedOptionsMessage =>
      'Voici les dernières options confirmées. Actualisez avant de continuer.';

  @override
  String get ticketFixtureCheckTimedOutTitle =>
      'La vérification du match a expiré';

  @override
  String get ticketSavedFixtureReadOnlyMessage =>
      'Le match enregistré est en lecture seule. Revenez aux billets pour continuer en sécurité.';

  @override
  String get ticketFixtureRefreshFailedTitle =>
      'Échec de l’actualisation du match';

  @override
  String get ticketSeatMapTitle => 'CHOISIR UNE PLACE';

  @override
  String get ticketConfirm => 'Confirmer';

  @override
  String get ticketSeatSelectionUnavailableTitle =>
      'Sélection de place indisponible';

  @override
  String get ticketSeatSelectionUnavailableMessage =>
      'La sélection de place n’est pas activée pour cette version ou ce club.';

  @override
  String get ticketBackToTicketUpper => 'RETOUR AU BILLET';

  @override
  String get ticketSeatMapUnavailableTitle => 'Plan des places indisponible';

  @override
  String get ticketSeatMapUnavailableMessage => 'Ce match est introuvable.';

  @override
  String get ticketSeatMapOfflineTitle =>
      'Plan des places indisponible hors ligne';

  @override
  String get ticketSeatMapOfflineMessage =>
      'Connectez-vous pour confirmer la disponibilité actuelle des places.';

  @override
  String get ticketSeatMapAccessTitle => 'Accès au plan des places refusé';

  @override
  String get ticketSeatMapAccessMessage =>
      'Ce match n’est pas disponible pour le compte du club actuel.';

  @override
  String get ticketSeatMapSecurityTitle => 'Délai de sécurité du plan dépassé';

  @override
  String get ticketSeatMapSecurityMessage =>
      'Le match n’a pas pu être confirmé de façon sûre. Réessayez.';

  @override
  String get ticketSeatMapChangedTitle => 'Le plan des places a changé';

  @override
  String get ticketSeatMapChangedMessage =>
      'Actualisez le match avant de choisir une place.';

  @override
  String get ticketRefreshSeatMapUpper => 'ACTUALISER LE PLAN';

  @override
  String get ticketSeatMapLoadFailedTitle => 'Impossible de charger le plan';

  @override
  String get ticketSeatMapLoadFailedMessage =>
      'Le match n’a pas pu être confirmé. Réessayez.';

  @override
  String get ticketSavedSeatMapTitle => 'Plan enregistré affiché';

  @override
  String get ticketSavedSeatMapMessage =>
      'La disponibilité peut avoir changé. Reconnectez-vous avant de confirmer.';

  @override
  String get ticketRefreshingSeatMapTitle => 'Actualisation du plan';

  @override
  String get ticketRefreshingSeatMapMessage =>
      'Le dernier match confirmé reste visible.';

  @override
  String get ticketLastConfirmedStandsMessage =>
      'Voici les dernières tribunes confirmées. Actualisez avant de choisir.';

  @override
  String get ticketSeatMapCheckTimedOutTitle =>
      'La vérification du plan a expiré';

  @override
  String get ticketSeatAccessChangedTitle => 'L’accès aux places a changé';

  @override
  String get ticketSavedSeatMapReadOnlyMessage =>
      'Le plan enregistré est en lecture seule. Revenez au billet pour continuer.';

  @override
  String get ticketSeatMapRefreshFailedTitle =>
      'Échec de l’actualisation du plan';

  @override
  String get ticketSelectedSeatUpper => 'PLACE SÉLECTIONNÉE';

  @override
  String get ticketSeatMapSemantic => 'Plan interactif des places du stade';

  @override
  String ticketSeatMapSelectedSemantic(String seat) {
    return 'Plan interactif des places, place sélectionnée : $seat';
  }

  @override
  String get ticketSeatMapHint => 'Touchez une tribune pour choisir une place';

  @override
  String ticketSelectedStandSemantic(String stand) {
    return 'Tribune $stand sélectionnée';
  }

  @override
  String ticketSelectStandSemantic(String stand) {
    return 'Choisir la tribune $stand';
  }

  @override
  String ticketSeatCode(String stand, int number) {
    return '$stand, place $number';
  }

  @override
  String get ticketStandVipGold => 'VIP Or';

  @override
  String get ticketStandEast => 'Tribune Est';

  @override
  String get ticketStandTribuneRed => 'Tribune Rouge';

  @override
  String get ticketStandStanding => 'Debout';

  @override
  String get ticketLegendVip => 'VIP';

  @override
  String get ticketLegendTribune => 'Tribune';

  @override
  String get contributionsClubProjectsTitle => 'PROJETS DU CLUB';

  @override
  String get contributionsProjectsUnavailableTitle => 'Projets indisponibles';

  @override
  String get contributionsProjectsUnavailableMessage =>
      'Les projets du club sont temporairement indisponibles.';

  @override
  String get contributionsProjectFallback => 'Projet';

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
      zero: 'Aucun supporter',
    );
    return '$_temp0';
  }

  @override
  String get contributionsContributeAction => 'Contribuer';

  @override
  String get contributionsCommunitiesTitle => 'Communautés';

  @override
  String get contributionsCommunitiesLoadError =>
      'Impossible de charger les communautés publiques pour le moment.';

  @override
  String get contributionsInitiatives => 'Initiatives';

  @override
  String get contributionsContributed => 'Contributions';

  @override
  String get contributionsActiveInitiatives => 'Initiatives actives';

  @override
  String get contributionsCommunitiesUnavailableTitle =>
      'Communautés indisponibles';

  @override
  String get contributionsCommunityQuietTitle => 'La communauté est calme';

  @override
  String get contributionsCommunityQuietMessage =>
      'Les communautés de contribution apparaîtront ici lorsque le club ouvrira la prochaine initiative.';

  @override
  String get contributionsPublicGroupFallback => 'Groupe public';

  @override
  String contributionsContributors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contributeurs',
      one: '1 contributeur',
      zero: 'Aucun contributeur',
    );
    return '$_temp0';
  }

  @override
  String contributionsGoalPercent(int percent) {
    return '$percent % de l’objectif';
  }

  @override
  String get contributionsConnectToLoad =>
      'Connectez-vous pour charger les initiatives de contribution.';

  @override
  String get contributionsInitiativesUnavailableMessage =>
      'Les initiatives sont temporairement indisponibles.';

  @override
  String get contributionsSmsEnabled =>
      'La synchronisation SMS MoMo est activée sur cet appareil.';

  @override
  String get contributionsSmsPermissionDenied =>
      'L’accès aux SMS n’a pas été accordé. La synchronisation reste désactivée.';

  @override
  String get contributionsSmsEnableFailed =>
      'Impossible d’activer la synchronisation SMS. Vérifiez les autorisations et réessayez.';

  @override
  String get contributionsSmsDisabled =>
      'La synchronisation SMS MoMo est désactivée.';

  @override
  String get contributionsConnectBeforeSmsSync =>
      'Connectez-vous avant de synchroniser les messages MoMo.';

  @override
  String contributionsSmsSyncComplete(int uploaded, int duplicates) {
    return 'Synchronisation terminée : $uploaded envoyés, $duplicates doublons.';
  }

  @override
  String get contributionsSmsSyncFailed =>
      'Échec de la synchronisation SMS. Vérifiez votre connexion et réessayez.';

  @override
  String get contributionsHubTitle => 'CONTRIBUER';

  @override
  String get contributionsRefreshingTitle => 'Actualisation des contributions';

  @override
  String get contributionsRefreshingMessage =>
      'Les totaux et les initiatives sont en cours de vérification.';

  @override
  String get contributionsSavedTitle => 'Données de contribution enregistrées';

  @override
  String get contributionsSavedMessage =>
      'Les totaux peuvent être obsolètes. Reconnectez-vous avant de contribuer ou synchroniser.';

  @override
  String get contributionsTeamProjects => 'PROJETS DE L’ÉQUIPE';

  @override
  String contributionsRaised(String current, String target) {
    return '$current sur $target collectés.';
  }

  @override
  String contributionsOpenMetric(int count) {
    return '$count OUVERTS';
  }

  @override
  String get contributionsCommunitiesUpper => 'COMMUNAUTÉS';

  @override
  String contributionsInitiativesActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count initiatives actives.',
      one: '1 initiative active.',
    );
    return '$_temp0';
  }

  @override
  String contributionsLiveMetric(int count) {
    return '$count EN DIRECT';
  }

  @override
  String get contributionsCommunityUpper => 'COMMUNAUTÉ';

  @override
  String get contributionsFanClubsChapters => 'Fan-clubs et sections locales.';

  @override
  String get contributionsLive => 'EN DIRECT';

  @override
  String get contributionsMomoSmsSync => 'Synchronisation SMS MoMo';

  @override
  String get contributionsUnavailableBuild =>
      'Indisponible dans cette version.';

  @override
  String get contributionsActiveUpper => 'ACTIF';

  @override
  String get contributionsSyncing => 'Synchronisation…';

  @override
  String get contributionsSyncNow => 'Synchroniser';

  @override
  String get contributionsDisable => 'Désactiver';

  @override
  String get contributionsEnabling => 'Activation…';

  @override
  String get contributionsEnableSmsSync => 'Activer la synchronisation SMS';

  @override
  String get contributionsLiveCampaigns => 'Campagnes actives';

  @override
  String get contributionsGroupsUnavailableTitle => 'Groupes indisponibles';

  @override
  String get contributionsGroupFallback => 'Groupe';

  @override
  String contributionsAmountOfTarget(String current, String target) {
    return '$current sur $target';
  }

  @override
  String get contributionsSeeAllGroups =>
      'Voir tous les groupes de contribution';

  @override
  String contributionsSeeAllGroupsSemantic(int count) {
    return 'Voir les $count groupes de contribution';
  }

  @override
  String get contributionsOpenGroupsHint =>
      'Ouvrir les groupes de contribution';

  @override
  String contributionsSeeAll(int count) {
    return 'Voir les $count';
  }

  @override
  String get contributionsInitiativeTitle => 'INITIATIVE PUBLIQUE';

  @override
  String get contributionsInitiativeLoadingTitle =>
      'Chargement de l’initiative publique';

  @override
  String get contributionsInitiativeLoadingMessage =>
      'Vérification du total confirmé et du registre public.';

  @override
  String get contributionsRefresh => 'Actualiser';

  @override
  String get contributionsBackToCommunities => 'Retour aux communautés';

  @override
  String get contributionsInitiativeRefreshingTitle =>
      'Actualisation de l’initiative';

  @override
  String get contributionsInitiativeRefreshingMessage =>
      'Le dernier total et le registre confirmés restent visibles pendant la vérification.';

  @override
  String get contributionsReadOnlyTitle => 'Contributions en lecture seule';

  @override
  String get contributionsReadOnlyMessage =>
      'L’activité publique confirmée reste visible, mais le paiement est désactivé dans cette version.';

  @override
  String get contributionsSavedInitiativeTitle =>
      'Données enregistrées affichées';

  @override
  String get contributionsSavedInitiativeMessage =>
      'Reconnectez-vous et actualisez avant un paiement ou avant de vous fier au dernier total.';

  @override
  String get contributionsRefreshInitiativeUpper => 'ACTUALISER L’INITIATIVE';

  @override
  String get contributionsClosedTitle => 'Contributions fermées';

  @override
  String get contributionsClosedMessage =>
      'Le total confirmé et le registre public restent disponibles pour consultation.';

  @override
  String get contributionsPaymentRouteUnavailableTitle =>
      'Mode de paiement indisponible';

  @override
  String get contributionsPaymentRouteUnavailableMessage =>
      'Aucun paiement ne commencera avant la publication d’un destinataire vérifié.';

  @override
  String get contributionsDisabled => 'Contributions désactivées';

  @override
  String get contributionsClosed => 'Contributions fermées';

  @override
  String get contributionsPaymentUnavailable => 'Paiement indisponible';

  @override
  String get contributionsCheckingLatestTotal =>
      'Vérification du dernier total';

  @override
  String get contributionsRefreshBeforeContributing =>
      'Actualisez avant de contribuer';

  @override
  String get contributionsContributeNow => 'Contribuer maintenant';

  @override
  String get contributionsConfirmedTotal => 'Total confirmé';

  @override
  String contributionsTargetProgress(String target, int percent) {
    return 'Objectif $target · $percent %';
  }

  @override
  String contributionsProgressSemantic(int percent) {
    return '$percent pour cent de l’objectif confirmé';
  }

  @override
  String get contributionsTypeUpper => 'TYPE';

  @override
  String get contributionsContributorsUpper => 'CONTRIBUTEURS';

  @override
  String contributionsContributeToSemantic(String group) {
    return 'Contribuer à $group';
  }

  @override
  String contributionsPaymentUnavailableSemantic(String action) {
    return '$action. Le paiement est indisponible.';
  }

  @override
  String get contributionsPublicLedgerTitle => 'REGISTRE PUBLIC';

  @override
  String get contributionsPublicLedgerPrivacy =>
      'Uniquement les alias publics. Les références de paiement et les comptes ne sont jamais affichés.';

  @override
  String get contributionsLedgerEmptyTitle => 'Aucune contribution';

  @override
  String get contributionsLedgerEmptyMessage =>
      'L’activité publique confirmée apparaîtra ici sans exposer les détails de paiement.';

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
  String get contributionsStatusConfirmed => 'CONFIRMÉ';

  @override
  String get contributionsStatusProcessing => 'EN TRAITEMENT';

  @override
  String get contributionsStatusFailed => 'ÉCHEC';

  @override
  String get contributionsTypeProject => 'PROJET D’ÉQUIPE';

  @override
  String get contributionsTypeCommunity => 'COMMUNAUTÉ';

  @override
  String get contributionsConnectionRestoredTitle => 'Connexion rétablie';

  @override
  String get contributionsInitiativeOfflineTitle => 'Initiative hors ligne';

  @override
  String get contributionsConnectionRestoredMessage =>
      'Actualisez pour vérifier le dernier total et le registre public.';

  @override
  String get contributionsInitiativeOfflineMessage =>
      'Reconnectez-vous pour charger cette initiative publique.';

  @override
  String get contributionsInitiativeNotFoundTitle => 'Initiative introuvable';

  @override
  String get contributionsInitiativeNotFoundMessage =>
      'Cette initiative peut être fermée ou le lien n’est peut-être plus valide.';

  @override
  String get contributionsInitiativeUnavailableTitle =>
      'Initiative indisponible';

  @override
  String get contributionsInitiativeAccessMessage =>
      'Votre accès actuel au club ne permet pas cette initiative.';

  @override
  String get contributionsInitiativeChangedTitle => 'L’initiative a changé';

  @override
  String get contributionsInitiativeChangedMessage =>
      'Actualisez et vérifiez le dernier total avant de contribuer.';

  @override
  String get contributionsInitiativeTimeoutTitle => 'La vérification a expiré';

  @override
  String get contributionsInitiativeTimeoutMessage =>
      'Aucun total n’a été confirmé. Actualisez avant de contribuer.';

  @override
  String get contributionsInitiativeUnavailableMessage =>
      'Actualisez et réessayez lorsque le registre public sera disponible.';

  @override
  String get contributionsEmptyCsvCopied =>
      'CSV vide copié dans le presse-papiers.';

  @override
  String get contributionsCsvCopied =>
      'CSV respectueux de la vie privée copié dans le presse-papiers.';

  @override
  String get contributionsStatementTitle => 'RELEVÉ PUBLIC';

  @override
  String get contributionsStatementLoadingTitle =>
      'Chargement du relevé public';

  @override
  String get contributionsStatementLoadingMessage =>
      'Vérification des contributions confirmées et des alias publics.';

  @override
  String get contributionsBackToInitiative => 'Retour à l’initiative';

  @override
  String get contributionsStatementRefreshingTitle => 'Actualisation du relevé';

  @override
  String get contributionsStatementRefreshingMessage =>
      'Le dernier relevé confirmé reste visible pendant la vérification.';

  @override
  String get contributionsStatementReadOnlyTitle =>
      'Export du relevé en lecture seule';

  @override
  String get contributionsStatementReadOnlyMessage =>
      'Vous pouvez consulter les entrées publiques, mais la copie est désactivée dans cette version.';

  @override
  String get contributionsSavedStatementTitle => 'Relevé enregistré affiché';

  @override
  String get contributionsSavedStatementMessage =>
      'Reconnectez-vous et actualisez avant d’exporter ou de vous fier au dernier total.';

  @override
  String get contributionsRefreshStatementUpper => 'ACTUALISER LE RELEVÉ';

  @override
  String get contributionsCopyCsvSemantic =>
      'Copier le relevé CSV respectueux de la vie privée';

  @override
  String contributionsExportUnavailableSemantic(String reason) {
    return 'Export indisponible. $reason';
  }

  @override
  String get contributionsFromUpper => 'DE';

  @override
  String get contributionsToUpper => 'À';

  @override
  String get contributionsAllTime => 'Depuis toujours';

  @override
  String get contributionsNow => 'Maintenant';

  @override
  String get contributionsSortUpper => 'TRIER';

  @override
  String get contributionsSortDate => 'PAR DATE';

  @override
  String get contributionsSortAmount => 'PAR MONTANT';

  @override
  String get contributionsSortAlias => 'PAR ALIAS';

  @override
  String get contributionsPdf => 'PDF';

  @override
  String get contributionsCsv => 'CSV';

  @override
  String get contributionsComingSoon => 'Bientôt disponible';

  @override
  String get contributionsClipboard => 'Presse-papiers';

  @override
  String get contributionsCopyingCsv => 'Copie du CSV…';

  @override
  String get contributionsExportDisabled => 'Export désactivé';

  @override
  String get contributionsCheckingLatestEntries =>
      'Vérification des dernières entrées';

  @override
  String get contributionsRefreshBeforeExporting =>
      'Actualisez avant d’exporter';

  @override
  String get contributionsCopyCsvStatement => 'Copier le relevé CSV';

  @override
  String contributionsStatementSummarySemantic(
    String group,
    int count,
    String total,
  ) {
    return 'Relevé public de $group, $count entrées, total confirmé $total';
  }

  @override
  String get contributionsConfirmedTotalUpper => 'TOTAL CONFIRMÉ';

  @override
  String contributionsPublicEntriesInRange(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrées publiques dans cette période',
      one: '1 entrée publique dans cette période',
    );
    return '$_temp0';
  }

  @override
  String get contributionsStatementPrivacy =>
      'Uniquement les alias publics. Les noms, téléphones, références de paiement et identifiants de compte sont exclus.';

  @override
  String contributionsFormatSemantic(String label, String helper) {
    return 'Format d’export $label, $helper';
  }

  @override
  String get contributionsPreviewUpper => 'APERÇU';

  @override
  String contributionsPreviewShowing(int count) {
    return 'Affichage de 5 entrées sur $count. Le CSV comprend toute la période limitée.';
  }

  @override
  String get contributionsPreviewPublicFields =>
      'Le CSV comprend uniquement les champs publics affichés ci-dessous.';

  @override
  String get contributionsNoStatementEntriesTitle => 'Aucune entrée de relevé';

  @override
  String get contributionsNoStatementEntriesMessage =>
      'Aucune contribution publique ne correspond à cette période. Choisissez-en une autre et actualisez.';

  @override
  String get contributionsStatementOfflineTitle => 'Relevé hors ligne';

  @override
  String get contributionsStatementRestoredMessage =>
      'Actualisez pour vérifier les dernières entrées publiques confirmées.';

  @override
  String get contributionsStatementOfflineMessage =>
      'Reconnectez-vous pour charger ce relevé public.';

  @override
  String get contributionsStatementNotFoundTitle => 'Relevé introuvable';

  @override
  String get contributionsStatementNotFoundMessage =>
      'L’initiative peut être fermée ou le lien du relevé n’est peut-être plus valide.';

  @override
  String get contributionsStatementUnavailableTitle => 'Relevé indisponible';

  @override
  String get contributionsStatementAccessMessage =>
      'Votre accès actuel au club ne permet pas ce relevé.';

  @override
  String get contributionsStatementChangedTitle => 'Le relevé a changé';

  @override
  String get contributionsStatementChangedMessage =>
      'Actualisez et vérifiez les dernières entrées avant d’exporter.';

  @override
  String get contributionsStatementTimeoutTitle =>
      'La vérification du relevé a expiré';

  @override
  String get contributionsStatementTimeoutMessage =>
      'Aucun relevé actuel n’a été confirmé. Actualisez avant d’exporter.';

  @override
  String get contributionsStatementUnavailableMessage =>
      'Actualisez et réessayez lorsque le registre public sera disponible.';

  @override
  String get contributionsConnectBeforeContributing =>
      'Connectez-vous avant de contribuer. Aucun paiement ni contribution n’a été envoyé.';

  @override
  String get contributionsDialerFailed =>
      'Impossible d’ouvrir le composeur MOMO. La contribution n’a pas été envoyée.';

  @override
  String contributionsStatusAnnouncement(String heading, String message) {
    return '$heading. $message';
  }

  @override
  String get contributionsAmountPrompt => 'COMBIEN VOULEZ-VOUS CONTRIBUER ?';

  @override
  String contributionsQuickAmount(int thousands) {
    return '+${thousands}K';
  }

  @override
  String get contributionsLaunchMomoDialer => 'Ouvrir le composeur MOMO';

  @override
  String get contributionsLaunchingMomo => 'OUVERTURE DE MOMO';

  @override
  String get contributionsChangeAmount => 'Changer le montant';

  @override
  String get contributionsDialNow => 'Composer maintenant';

  @override
  String get contributionsCancel => 'Annuler la contribution';

  @override
  String get contributionsPaymentConfirmedTitle => 'PAIEMENT CONFIRMÉ';

  @override
  String contributionsPaymentConfirmedMessage(String amount) {
    return 'Votre contribution de $amount a été vérifiée et enregistrée.';
  }

  @override
  String get contributionsPaymentFailedTitle => 'ÉCHEC DU PAIEMENT';

  @override
  String get contributionsPaymentFailedMessage =>
      'Le paiement n’a pas pu être vérifié. Vérifiez votre solde MoMo et réessayez, ou contactez le support.';

  @override
  String get contributionsPaymentProcessingTitle => 'TOUJOURS EN TRAITEMENT';

  @override
  String get contributionsPaymentProcessingMessage =>
      'Le paiement prend plus de temps que prévu. Consultez le registre du groupe. Si le transfert MoMo est terminé, il apparaîtra bientôt.';

  @override
  String get contributionsRecordFailedTitle => 'ENREGISTREMENT IMPOSSIBLE';

  @override
  String get contributionsRecordFailedMessage =>
      'Le composeur MoMo s’est ouvert, mais la contribution n’a pas été enregistrée. Revenez au groupe et réessayez.';

  @override
  String get contributionsAwaitingPaymentTitle => 'PAIEMENT EN ATTENTE';

  @override
  String get contributionsAwaitingPaymentMessage =>
      'Terminez le paiement MoMo sur votre téléphone. La contribution reste « En traitement » jusqu’à confirmation.';

  @override
  String get contributionsCheckingPaymentStatus => 'Vérification du paiement…';

  @override
  String get contributionsVerifiedUpper => 'VÉRIFIÉ';

  @override
  String get contributionsDone => 'Terminé';

  @override
  String get contributionsBackToGroup => 'Retour au groupe';

  @override
  String get contributionsEnableMomoSmsTitle =>
      'ACTIVER LA SYNCHRONISATION SMS MOMO';

  @override
  String contributionsSmsPrivacyMessage(String app) {
    return '$app lit uniquement les confirmations MoMo pour enregistrer automatiquement les reçus. Les autres messages ne sont pas consultés.';
  }

  @override
  String get contributionsAllowSmsReading => 'Autoriser la lecture des SMS';

  @override
  String get contributionsEnable => 'Activer';

  @override
  String get contributionsNotNowUpper => 'PAS MAINTENANT';
}
