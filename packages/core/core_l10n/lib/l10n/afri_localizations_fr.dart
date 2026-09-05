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
  String get clubOfflineTitle => 'Informations du club hors ligne';

  @override
  String get clubOfflineMessage =>
      'Connectez-vous pour charger les dernières informations officielles du club.';

  @override
  String get clubAccessDeniedTitle => 'Accès aux informations du club refusé';

  @override
  String get clubAccessDeniedMessage =>
      'Ce compte ne peut pas accéder aux informations demandées du club.';

  @override
  String get clubChangedTitle => 'Informations du club modifiées';

  @override
  String get clubChangedMessage =>
      'Les informations officielles du club ont changé pendant le chargement. Actualisez pour confirmer la dernière version.';

  @override
  String get clubSecurityTimeoutTitle =>
      'Délai de sécurité des informations du club dépassé';

  @override
  String get clubSecurityTimeoutMessage =>
      'Le service d’informations du club n’a pas répondu à temps. Actualisez pour réessayer.';

  @override
  String get clubRefreshingTitle => 'Actualisation des informations du club';

  @override
  String get clubRefreshingMessage =>
      'Les dernières informations confirmées du club restent visibles pendant le chargement des mises à jour.';

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
  String get fanClubBackToSupporters => 'Retour aux supporters';

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
  String get fanClubActive => 'Actif';

  @override
  String get fanClubPendingReview => 'En attente de validation';

  @override
  String fanClubCurrentSemantic(String name) {
    return 'Fan-club actuel, $name';
  }

  @override
  String get fanClubAboutTitle => 'À propos de ce club';

  @override
  String fanClubRegionValue(String region) {
    return 'Région : $region';
  }

  @override
  String get fanClubSnapshotTitle => 'Aperçu du groupe';

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
  String get fanClubRefreshAction => 'Actualiser le club';

  @override
  String get fanClubTryAgainAction => 'Réessayer';

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
  String get fanClubMatchdayAgenda => 'Programme du jour de match';

  @override
  String fanClubMatchMeta(String competition, String venue) {
    return '$competition  •  $venue';
  }

  @override
  String fanClubMatchSchedule(String date, String time) {
    return '$date  •  $time';
  }

  @override
  String get fanClubMembersLabel => 'Membres';

  @override
  String get fanClubStatusLabel => 'Statut';

  @override
  String get fanClubRegionLabel => 'Région';

  @override
  String get fanClubOpenSupportersSemantic => 'Ouvrir l’espace Supporters';

  @override
  String get fanClubPendingReviewSemantic =>
      'Fan-club en attente de validation';

  @override
  String get fanClubSupportersAction => 'Supporters';

  @override
  String get fanClubOpenSupportersAction => 'Ouvrir supporters';

  @override
  String get fanClubCopyLink => 'Copier le lien';

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
  String get fanClubsCommunityEyebrow => 'La communauté';

  @override
  String get fanClubsTitle => 'Fan-clubs';

  @override
  String get fanClubsSearchHint => 'Rechercher des clubs ou des lieux';

  @override
  String get fanClubsFeaturedChapter => 'Section à la une';

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
  String get liveStatusLive => 'En direct';

  @override
  String get liveStatusHalfTime => 'Mi-temps';

  @override
  String get liveStatusFullTime => 'Terminé';

  @override
  String get liveStatusPostponed => 'Reporté';

  @override
  String get liveStatusCancelled => 'Annulé';

  @override
  String get liveStatusUpcoming => 'À venir';

  @override
  String get liveStatusFinal => 'Final';

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
  String get liveMatchReport => 'Rapport du match';

  @override
  String get liveMatchFinishedPending => 'Match terminé. Résumé en attente.';

  @override
  String get liveMatchdayIntel => 'Infos du jour de match';

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
  String get liveStatPending => 'À confirmer';

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
  String get liveCenterUnavailable => 'Centre du direct indisponible';

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
  String get newsRefreshArticle => 'Actualiser l’article';

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
  String get shopOutOfStockUpper => 'Rupture de stock';

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
  String get shopLoadingBadge => 'Chargement';

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
  String get shopInStock => 'En stock';

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
  String get shopOfficialBadge => 'Officiel';

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
  String get ticketDateLabel => 'Date';

  @override
  String get ticketTimeLabel => 'Heure';

  @override
  String get ticketVenueLabel => 'Lieu';

  @override
  String get ticketAppleWallet => 'Apple Wallet';

  @override
  String get ticketGoogleWallet => 'Google Wallet';

  @override
  String get ticketWalletExportUnavailable =>
      'L’export vers un portefeuille n’est pas encore disponible dans cette version.';

  @override
  String get ticketGoogleWalletChecking =>
      'Vérification de la disponibilité de Google Wallet…';

  @override
  String get ticketGoogleWalletReady =>
      'Votre billet confirmé peut être ajouté à Google Wallet.';

  @override
  String get ticketGoogleWalletAdding => 'Ajout à Google Wallet…';

  @override
  String get ticketGoogleWalletAdded => 'Ajouté à Google Wallet';

  @override
  String get ticketGoogleWalletAddingMessage =>
      'Préparation du billet sécurisé et ouverture de Google Wallet.';

  @override
  String get ticketGoogleWalletAddedMessage =>
      'Google Wallet a confirmé l’enregistrement du billet.';

  @override
  String get ticketGoogleWalletCancelled =>
      'L’enregistrement dans Google Wallet a été annulé. Votre billet reste disponible ici.';

  @override
  String get ticketGoogleWalletUnavailable =>
      'Google Wallet n’est pas disponible sur cet appareil ou ce compte.';

  @override
  String get ticketGoogleWalletOnlineRequired =>
      'Reconnectez-vous avant d’ajouter ce billet à Google Wallet.';

  @override
  String get ticketGoogleWalletPaymentPending =>
      'Le paiement doit être confirmé avant l’ajout de ce billet à Google Wallet.';

  @override
  String get ticketGoogleWalletPermissionDenied =>
      'Ce compte ne peut pas ajouter le billet sélectionné à Google Wallet.';

  @override
  String get ticketGoogleWalletTimeout =>
      'La demande sécurisée a expiré. Aucun enregistrement n’est confirmé ; réessayez.';

  @override
  String get ticketGoogleWalletFailed =>
      'Le billet n’a pas pu être ajouté à Google Wallet. Réessayez plus tard.';

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
  String get ticketEntryCodeAccessChangedTitle => 'L’accès au billet a changé';

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
  String get ticketRefreshUpper => 'Actualiser le billet';

  @override
  String get ticketWalletUnavailableTitle =>
      'Portefeuille de billets indisponible';

  @override
  String get ticketWalletUnavailableMessage =>
      'Impossible de charger votre portefeuille. Vérifiez votre connexion et réessayez.';

  @override
  String get ticketMyTickets => 'Mes billets';

  @override
  String get ticketRefreshTickets => 'Actualiser les billets';

  @override
  String get ticketUpcoming => 'À venir';

  @override
  String get ticketPast => 'Passés';

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
  String get ticketCheckoutSummary => 'Récapitulatif';

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
  String get ticketConfirmPurchase => 'Confirmer l’achat';

  @override
  String get ticketMatchUpper => 'Match';

  @override
  String get ticketZoneUpper => 'Zone';

  @override
  String get ticketSeatUpper => 'Place';

  @override
  String get ticketQuantityUpper => 'Quantité';

  @override
  String get ticketServiceFeeUpper => 'Frais de service';

  @override
  String get ticketTotalUpper => 'Total';

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
  String get ticketChooseAccess => 'Choisir l’accès';

  @override
  String get ticketGeneral => 'Général';

  @override
  String get ticketGeneralSubtitle => 'Tribunes ouvertes';

  @override
  String get ticketVip => 'VIP';

  @override
  String get ticketVipSubtitle => 'Places premium en salon';

  @override
  String get ticketChooseSeat => 'Choisir une place';

  @override
  String get ticketChangeSeat => 'Changer la place';

  @override
  String get ticketReview => 'Vérifier';

  @override
  String get ticketReviewReservation => 'Vérifier la réservation';

  @override
  String get ticketOfficialCategories => 'Catégories officielles';

  @override
  String get ticketOfficialCategoriesMessage =>
      'Tarifs publics approuvés. La disponibilité apparaît lorsque le club active une vente officielle.';

  @override
  String get ticketListTitle => 'Billets';

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
  String get ticketNext => 'Suivant';

  @override
  String get ticketMine => 'Mes billets';

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
  String get ticketStatusSoldOut => 'Épuisé';

  @override
  String get ticketStatusAvailable => 'Disponible';

  @override
  String get ticketFrom => 'À partir de';

  @override
  String get ticketBuyAction => 'Acheter un billet';

  @override
  String get ticketSalesNotOpen => 'Ventes non ouvertes';

  @override
  String get ticketVersusUpper => 'Contre';

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
  String get ticketMatchDay => 'Jour de match';

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
  String get ticketTryAgainUpper => 'Réessayer';

  @override
  String get ticketRefreshFixtureUpper => 'Actualiser le match';

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
  String get ticketAccessChangedTitle => 'L’accès aux billets a changé';

  @override
  String get ticketSavedFixtureReadOnlyMessage =>
      'Le match enregistré est en lecture seule. Revenez aux billets pour continuer en sécurité.';

  @override
  String get ticketFixtureRefreshFailedTitle =>
      'Échec de l’actualisation du match';

  @override
  String get ticketSeatMapTitle => 'Choisir une place';

  @override
  String get ticketConfirm => 'Confirmer';

  @override
  String get ticketSeatSelectionUnavailableTitle =>
      'Sélection de place indisponible';

  @override
  String get ticketSeatSelectionUnavailableMessage =>
      'La sélection de place n’est pas activée pour cette version ou ce club.';

  @override
  String get ticketBackToTicketUpper => 'Retour au billet';

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
  String get ticketRefreshSeatMapUpper => 'Actualiser le plan';

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
  String get ticketSelectedSeatUpper => 'Place sélectionnée';

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
  String get contributionsClubProjectsTitle => 'Projets du club';

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
  String get contributionsHubTitle => 'Contribuer';

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
  String get contributionsTeamProjects => 'Projets de l’équipe';

  @override
  String contributionsRaised(String current, String target) {
    return '$current sur $target collectés.';
  }

  @override
  String contributionsOpenMetric(int count) {
    return '$count OUVERTS';
  }

  @override
  String get contributionsCommunitiesUpper => 'Communautés';

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
  String get contributionsCommunityUpper => 'Communauté';

  @override
  String get contributionsFanClubsChapters => 'Fan-clubs et sections locales.';

  @override
  String get contributionsLive => 'En direct';

  @override
  String get contributionsMomoSmsSync => 'Synchronisation SMS MoMo';

  @override
  String get contributionsUnavailableBuild =>
      'Indisponible dans cette version.';

  @override
  String get contributionsActiveUpper => 'Actif';

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
  String get contributionsInitiativeTitle => 'Initiative publique';

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
  String get contributionsRefreshInitiativeUpper => 'Actualiser l’initiative';

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
  String get contributionsTypeUpper => 'Type';

  @override
  String get contributionsContributorsUpper => 'Contributeurs';

  @override
  String contributionsContributeToSemantic(String group) {
    return 'Contribuer à $group';
  }

  @override
  String contributionsPaymentUnavailableSemantic(String action) {
    return '$action. Le paiement est indisponible.';
  }

  @override
  String get contributionsPublicLedgerTitle => 'Registre public';

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
  String get contributionsStatusConfirmed => 'Confirmé';

  @override
  String get contributionsStatusProcessing => 'En traitement';

  @override
  String get contributionsStatusFailed => 'Échec';

  @override
  String get contributionsTypeProject => 'Projet d’équipe';

  @override
  String get contributionsTypeCommunity => 'Communauté';

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
  String get contributionsStatementTitle => 'Relevé public';

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
  String get contributionsRefreshStatementUpper => 'Actualiser le relevé';

  @override
  String get contributionsCopyCsvSemantic =>
      'Copier le relevé CSV respectueux de la vie privée';

  @override
  String contributionsExportUnavailableSemantic(String reason) {
    return 'Export indisponible. $reason';
  }

  @override
  String get contributionsFromUpper => 'De';

  @override
  String get contributionsToUpper => 'À';

  @override
  String get contributionsAllTime => 'Depuis toujours';

  @override
  String get contributionsNow => 'Maintenant';

  @override
  String get contributionsSortUpper => 'Trier';

  @override
  String get contributionsSortDate => 'Par date';

  @override
  String get contributionsSortAmount => 'Par montant';

  @override
  String get contributionsSortAlias => 'Par alias';

  @override
  String get contributionsPdf => 'Pdf';

  @override
  String get contributionsCsv => 'Csv';

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
  String get contributionsConfirmedTotalUpper => 'Total confirmé';

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
  String get contributionsPreviewUpper => 'Aperçu';

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
  String get contributionsAmountPrompt => 'Combien voulez-vous contribuer ?';

  @override
  String contributionsQuickAmount(int thousands) {
    return '+${thousands}K';
  }

  @override
  String get contributionsLaunchMomoDialer => 'Ouvrir le composeur MOMO';

  @override
  String get contributionsLaunchingMomo => 'Ouverture de MoMo';

  @override
  String get contributionsChangeAmount => 'Changer le montant';

  @override
  String get contributionsDialNow => 'Composer maintenant';

  @override
  String get contributionsCancel => 'Annuler la contribution';

  @override
  String get contributionsPaymentConfirmedTitle => 'Paiement confirmé';

  @override
  String contributionsPaymentConfirmedMessage(String amount) {
    return 'Votre contribution de $amount a été vérifiée et enregistrée.';
  }

  @override
  String get contributionsPaymentFailedTitle => 'Échec du paiement';

  @override
  String get contributionsPaymentFailedMessage =>
      'Le paiement n’a pas pu être vérifié. Vérifiez votre solde MoMo et réessayez, ou contactez le support.';

  @override
  String get contributionsPaymentProcessingTitle => 'Toujours en traitement';

  @override
  String get contributionsPaymentProcessingMessage =>
      'Le paiement prend plus de temps que prévu. Consultez le registre du groupe. Si le transfert MoMo est terminé, il apparaîtra bientôt.';

  @override
  String get contributionsRecordFailedTitle => 'Enregistrement impossible';

  @override
  String get contributionsRecordFailedMessage =>
      'Le composeur MoMo s’est ouvert, mais la contribution n’a pas été enregistrée. Revenez au groupe et réessayez.';

  @override
  String get contributionsAwaitingPaymentTitle => 'Paiement en attente';

  @override
  String get contributionsAwaitingPaymentMessage =>
      'Terminez le paiement MoMo sur votre téléphone. La contribution reste « En traitement » jusqu’à confirmation.';

  @override
  String get contributionsCheckingPaymentStatus => 'Vérification du paiement…';

  @override
  String get contributionsVerifiedUpper => 'Vérifié';

  @override
  String get contributionsDone => 'Terminé';

  @override
  String get contributionsBackToGroup => 'Retour au groupe';

  @override
  String get contributionsEnableMomoSmsTitle =>
      'Activer la synchronisation SMS MoMo';

  @override
  String contributionsSmsPrivacyMessage(String app) {
    return '$app lit uniquement les confirmations MoMo pour enregistrer automatiquement les reçus. Les autres messages ne sont pas consultés.';
  }

  @override
  String get contributionsAllowSmsReading => 'Autoriser la lecture des SMS';

  @override
  String get contributionsEnable => 'Activer';

  @override
  String get contributionsNotNowUpper => 'Pas maintenant';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsRoleAdmin => 'Administrateur';

  @override
  String get settingsRoleSupporter => 'Supporter';

  @override
  String get settingsMembershipDetails => 'Détails de l’adhésion';

  @override
  String get settingsSectionAccount => 'Compte';

  @override
  String get settingsSectionPreferences => 'Préférences';

  @override
  String get settingsSectionSupport => 'Assistance';

  @override
  String get settingsEditProfile => 'Modifier le profil';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsPrivacy => 'Confidentialité';

  @override
  String get settingsHelpSupport => 'Aide et assistance';

  @override
  String get settingsSignOut => 'Se déconnecter';

  @override
  String get settingsRefreshingTitle => 'Actualisation des paramètres';

  @override
  String get settingsRefreshingMessage =>
      'Les paramètres du compte et de l’apparence restent disponibles.';

  @override
  String get settingsOfflineTitle => 'Paramètres hors ligne';

  @override
  String get settingsOfflineMessage =>
      'Hors ligne. Les paramètres du compte et de l’apparence restent disponibles. Reconnectez-vous pour l’assistance.';

  @override
  String get settingsHelpUnavailableTitle => 'Aide et assistance indisponibles';

  @override
  String get settingsSupportContactUnavailableTitle =>
      'Contact d’assistance indisponible';

  @override
  String get settingsSupportContactUnavailableMessage =>
      'Les autres paramètres fonctionnent toujours. Actualisez pour vérifier.';

  @override
  String get settingsLoadingTitle => 'Chargement des paramètres';

  @override
  String get settingsLoadingMessage => 'Vérification de l’assistance.';

  @override
  String get settingsAccessLimitedTitle => 'Accès aux paramètres limité';

  @override
  String get settingsAccessLimitedMessage =>
      'L’assistance n’a pas pu être vérifiée. Les autres paramètres fonctionnent toujours.';

  @override
  String get settingsChangedTitle => 'Paramètres modifiés';

  @override
  String get settingsChangedMessage =>
      'Actualisez pour charger les paramètres d’assistance actuels.';

  @override
  String get settingsSecurityTimeoutTitle => 'Vérification de sécurité expirée';

  @override
  String get settingsSecurityTimeoutMessage =>
      'Vérifiez votre connexion et actualisez.';

  @override
  String get settingsSupportLoadFailedTitle =>
      'Impossible de charger l’assistance';

  @override
  String get settingsSupportLoadFailedMessage =>
      'Les paramètres du compte et de l’apparence restent disponibles.';

  @override
  String get settingsChecking => 'Vérification…';

  @override
  String get settingsConnectionRequired => 'Connexion requise';

  @override
  String get settingsUnavailable => 'Indisponible';

  @override
  String get settingsNotConfigured => 'Non configuré';

  @override
  String get settingsStatusUnavailable => 'État indisponible';

  @override
  String get settingsThemeUseDevice => 'Utiliser le réglage de l’appareil';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsAppearanceMessage =>
      'Choisissez un thème ou suivez le réglage de votre appareil.';

  @override
  String get settingsThemeSystem => 'Système';

  @override
  String get settingsSupportNotConfigured =>
      'Le contact d’assistance n’est pas configuré.';

  @override
  String settingsSupportGreeting(String app) {
    return 'Bonjour, j’ai besoin d’aide avec $app.';
  }

  @override
  String get settingsWhatsAppFailed => 'Impossible d’ouvrir WhatsApp.';

  @override
  String get settingsDeleteAccountTitle => 'Supprimer votre compte ?';

  @override
  String get settingsDeleteAccountMessage =>
      'Supprime définitivement votre profil, vos FET, badges et votre historique. Cette action est irréversible.';

  @override
  String get settingsDeleteAccountConfirmPrompt =>
      'Saisissez DELETE pour confirmer';

  @override
  String get settingsDeleteAccountConfirmValue => 'DELETE';

  @override
  String get settingsCancelUpper => 'Annuler';

  @override
  String get settingsDeletePermanently => 'Supprimer définitivement';

  @override
  String get settingsNotificationPermissionTitle => 'Restez avec le club';

  @override
  String get settingsNotificationPermissionMessage =>
      'Recevez les alertes de matchs, contributions, étapes FET et actualités du club.';

  @override
  String get settingsMatchAlerts => 'Alertes avant le coup d’envoi';

  @override
  String get settingsContributionUpdates =>
      'Actualités des contributions et billets';

  @override
  String get settingsFetMilestones => 'Étapes FET et nouveaux défis';

  @override
  String get settingsEnableNotifications => 'Activer les notifications';

  @override
  String get settingsMaybeLaterUpper => 'Plus tard';

  @override
  String get settingsSignOutTitle => 'Se déconnecter ?';

  @override
  String get settingsSignOutMessage =>
      'Votre profil et vos FET sont enregistrés. Reconnectez-vous à tout moment.';

  @override
  String get settingsStay => 'Rester';

  @override
  String get settingsSignOutOthersTitle => 'Déconnecter les autres appareils ?';

  @override
  String get settingsSignOutOthersMessage =>
      'Cet appareil reste connecté. Les autres sessions seront révoquées.';

  @override
  String get settingsSignOutOthersAction => 'Déconnecter les autres';

  @override
  String get settingsCancel => 'Annuler';

  @override
  String get editProfileUpdated => 'Profil mis à jour.';

  @override
  String get editProfileServiceUnavailable =>
      'Le service de profil est temporairement indisponible.';

  @override
  String get editProfileLoadingTitle => 'Chargement du profil';

  @override
  String get editProfileLoadingMessage =>
      'Vérification de votre profil enregistré.';

  @override
  String get editProfileAccessLimitedTitle => 'Accès au profil limité';

  @override
  String get editProfileAccessLimitedMessage =>
      'Votre profil n’a pas pu être vérifié. Reconnectez-vous.';

  @override
  String get editProfileSignInAgain => 'Se reconnecter';

  @override
  String get editProfileChangedTitle => 'Profil modifié';

  @override
  String get editProfileChangedMessage =>
      'Actualisez pour charger le profil actuel avant de le modifier.';

  @override
  String get editProfileRefresh => 'Actualiser';

  @override
  String get editProfileSecurityTimeoutTitle =>
      'Vérification de sécurité expirée';

  @override
  String get editProfileSecurityTimeoutMessage =>
      'Vérifiez votre connexion et actualisez.';

  @override
  String get editProfileLoadFailedTitle => 'Impossible de charger le profil';

  @override
  String get editProfileLoadFailedMessage =>
      'Votre profil est toujours protégé. Réessayez.';

  @override
  String get editProfileTryAgain => 'Réessayer';

  @override
  String get editProfileTitle => 'Profil';

  @override
  String get editProfileSavingTitle => 'Enregistrement du profil';

  @override
  String get editProfileSavingMessage =>
      'Votre surnom reste visible pendant la confirmation.';

  @override
  String get editProfileRefreshingTitle => 'Actualisation du profil';

  @override
  String get editProfileRefreshingMessage =>
      'Votre profil enregistré reste visible.';

  @override
  String get editProfileEditingUnavailableTitle =>
      'Modification du profil indisponible';

  @override
  String get editProfileEditingUnavailableMessage =>
      'Votre profil enregistré reste visible.';

  @override
  String get editProfileChangedElsewhereTitle => 'Profil modifié ailleurs';

  @override
  String get editProfileChangedElsewhereMessage =>
      'Le dernier surnom a été chargé. Vérifiez-le avant d’enregistrer.';

  @override
  String get editProfileSaveUnconfirmedTitle => 'Enregistrement non confirmé';

  @override
  String get editProfileSaveUnconfirmedMessage =>
      'Actualisez votre profil avant de réessayer.';

  @override
  String get editProfileSaveFailedTitle => 'Impossible d’enregistrer le profil';

  @override
  String get editProfileSaveFailedMessage =>
      'Votre brouillon de surnom est conservé.';

  @override
  String get editProfileOfflineTitle => 'Profil hors ligne';

  @override
  String get editProfileOfflineMessage =>
      'Hors ligne. Votre profil enregistré reste visible. Reconnectez-vous pour le modifier.';

  @override
  String get editProfileUnavailableTitle => 'Profil indisponible';

  @override
  String get editProfileUnavailableMessage =>
      'Votre profil est indisponible. Reconnectez-vous pour récupérer votre compte.';

  @override
  String editProfileAlias(String alias) {
    return '#$alias';
  }

  @override
  String get editProfileNicknameLabel => 'Surnom';

  @override
  String get editProfileNicknameHint => 'Surnom de supporter facultatif';

  @override
  String get editProfileSaving => 'Enregistrement…';

  @override
  String get editProfileSaveChanges => 'Enregistrer les modifications';

  @override
  String get editProfileDeleteAccount => 'Supprimer le compte';

  @override
  String get editProfileDeleteHint =>
      'Supprimer définitivement ce compte de supporter';

  @override
  String get editProfileDeleteFailed =>
      'Impossible de supprimer le compte. Réessayez.';

  @override
  String get editProfileLanguageEnglish => 'Anglais';

  @override
  String get editProfileLanguageFrench => 'Français';

  @override
  String get editProfileLanguageKinyarwanda => 'Kinyarwanda';

  @override
  String get notificationPreferencesConnectionRestoredReview =>
      'Connexion rétablie. Vérifiez vos modifications conservées, puis enregistrez.';

  @override
  String get notificationPreferencesConnectionRestoredRefreshing =>
      'Connexion rétablie. Actualisation des préférences.';

  @override
  String get notificationPreferencesConnectBeforeChanging =>
      'Connectez-vous avant de modifier la réception des notifications sur cet appareil.';

  @override
  String get notificationPreferencesDeviceTurnedOff =>
      'Les notifications de l’appareil ont été désactivées. Enregistrez pour mettre à jour la préférence de votre compte.';

  @override
  String get notificationPreferencesPermissionGranted =>
      'Autorisation accordée sur cet appareil. Enregistrez pour activer les alertes sur votre compte.';

  @override
  String get notificationPreferencesBlocked =>
      'Notifications bloquées. Activez-les dans les réglages de l’appareil.';

  @override
  String get notificationPreferencesPermissionPending =>
      'L’autorisation des notifications est toujours en attente.';

  @override
  String get notificationPreferencesPushUnavailable =>
      'Les notifications push ne sont pas disponibles dans cette version.';

  @override
  String get notificationPreferencesDraftKeptConnect =>
      'Vos modifications sont conservées. Connectez-vous avant d’enregistrer.';

  @override
  String get notificationPreferencesSaved =>
      'Préférences de notification enregistrées.';

  @override
  String get notificationPreferencesChangedElsewhereLoading =>
      'Les préférences ont été modifiées ailleurs. La dernière version est en cours de chargement ; vérifiez-la avant d’enregistrer à nouveau.';

  @override
  String get notificationPreferencesChangeNotPermitted =>
      'Les modifications de notification ne sont pas autorisées pour ce compte.';

  @override
  String get notificationPreferencesChangedRefresh =>
      'Les préférences ont été modifiées ailleurs. Actualisez avant d’enregistrer à nouveau.';

  @override
  String get notificationPreferencesSaveUnconfirmed =>
      'L’enregistrement des notifications n’a pas été confirmé. Actualisez avant de réessayer.';

  @override
  String get notificationPreferencesSaveFailedDraftKept =>
      'Les préférences de notification n’ont pas pu être enregistrées. Votre brouillon est conservé.';

  @override
  String get notificationPreferencesRefreshing =>
      'Actualisation des préférences de notification.';

  @override
  String get notificationPreferencesLoadingTitle =>
      'Chargement des notifications';

  @override
  String get notificationPreferencesLoadingMessage =>
      'Vérification de votre préférence de réception enregistrée.';

  @override
  String get notificationPreferencesOfflineTitle =>
      'Les notifications sont hors ligne';

  @override
  String get notificationPreferencesOfflineMessage =>
      'Connectez-vous pour charger votre préférence de notification enregistrée.';

  @override
  String get notificationPreferencesUnavailableTitle =>
      'Préférences de notification indisponibles';

  @override
  String get notificationPreferencesUnavailableMessage =>
      'Connectez-vous pour gérer la réception des notifications.';

  @override
  String get notificationPreferencesAccessLimitedTitle =>
      'Accès aux notifications limité';

  @override
  String get notificationPreferencesAccessLimitedMessage =>
      'Vos préférences n’ont pas pu être vérifiées. Reconnectez-vous.';

  @override
  String get notificationPreferencesChangedTitle =>
      'Paramètres de notification modifiés';

  @override
  String get notificationPreferencesChangedMessage =>
      'Actualisez pour charger la préférence actuelle avant de la modifier.';

  @override
  String get notificationPreferencesSecurityTimeoutTitle =>
      'Le contrôle de sécurité des notifications a expiré';

  @override
  String get notificationPreferencesSecurityTimeoutMessage =>
      'Vérifiez votre connexion et actualisez.';

  @override
  String get notificationPreferencesLoadFailedTitle =>
      'Impossible de charger les paramètres de notification.';

  @override
  String get notificationPreferencesLoadFailedMessage =>
      'Votre préférence enregistrée est toujours en sécurité. Réessayez.';

  @override
  String get notificationPreferencesSavingTitle =>
      'Enregistrement des préférences de notification';

  @override
  String get notificationPreferencesSavingMessage =>
      'Vos choix restent visibles pendant la confirmation de l’enregistrement.';

  @override
  String get notificationPreferencesRefreshingTitle =>
      'Actualisation des préférences de notification';

  @override
  String get notificationPreferencesRefreshingMessage =>
      'Votre préférence de réception enregistrée reste visible.';

  @override
  String get notificationPreferencesEditingUnavailableTitle =>
      'Modification des notifications indisponible';

  @override
  String get notificationPreferencesEditingUnavailableMessage =>
      'Votre préférence enregistrée reste visible.';

  @override
  String get notificationPreferencesChangedElsewhereTitle =>
      'Paramètres de notification modifiés ailleurs';

  @override
  String get notificationPreferencesChangedElsewhereMessage =>
      'Actualisez et vérifiez la dernière préférence.';

  @override
  String get notificationPreferencesSaveNotConfirmedTitle =>
      'Enregistrement des notifications non confirmé';

  @override
  String get notificationPreferencesSaveNotConfirmedMessage =>
      'Actualisez avant de réessayer. Votre brouillon est conservé.';

  @override
  String get notificationPreferencesSaveFailedTitle =>
      'Impossible d’enregistrer les préférences de notification';

  @override
  String get notificationPreferencesSaveFailedMessage =>
      'Votre brouillon est toujours disponible.';

  @override
  String get notificationPreferencesSavedSettingsTitle =>
      'Paramètres de notification enregistrés';

  @override
  String get notificationPreferencesSavedSettingsMessage =>
      'Les valeurs peuvent être obsolètes. Reconnectez-vous avant de les modifier ou de les enregistrer.';

  @override
  String get notificationPreferencesCheckingPermissionsTitle =>
      'Vérification des autorisations de l’appareil';

  @override
  String get notificationPreferencesCheckingPermissionsMessage =>
      'Les contrôles de réception seront disponibles après cette vérification.';

  @override
  String get notificationPreferencesDeviceAlertsUnavailableTitle =>
      'Alertes de l’appareil indisponibles';

  @override
  String get notificationPreferencesDeviceAlertsUnavailableMessage =>
      'La réception push n’est pas configurée dans cette version.';

  @override
  String get notificationPreferencesPermissionEnabled =>
      'Les notifications système sont activées sur cet appareil.';

  @override
  String get notificationPreferencesPermissionBlocked =>
      'Les notifications système sont bloquées au niveau de l’appareil.';

  @override
  String get notificationPreferencesPermissionNotRequested =>
      'Autorisation pas encore demandée.';

  @override
  String get notificationPreferencesPermissionNotConfigured =>
      'Les notifications push ne sont pas configurées dans cette version.';

  @override
  String get notificationPreferencesPermissionChecking =>
      'Vérification des autorisations de notification de l’appareil…';

  @override
  String get notificationPreferencesTitle => 'Notifications';

  @override
  String get notificationPreferencesDeliverySection =>
      'Réception des notifications';

  @override
  String get notificationPreferencesAlertsEnabled => 'Alertes activées.';

  @override
  String get notificationPreferencesEnableAlertsDescription =>
      'Activez les alertes pour les matchs, reçus et actualités.';

  @override
  String get notificationPreferencesDeviceDelivery =>
      'Réception des alertes sur l’appareil';

  @override
  String get notificationPreferencesConnectionRequiredUpper =>
      'Connexion requise';

  @override
  String get notificationPreferencesDisableAlerts => 'Désactiver les alertes';

  @override
  String get notificationPreferencesEnableAlerts => 'Activer les alertes';

  @override
  String get notificationPreferencesDeliveryModel => 'Modèle de réception';

  @override
  String notificationPreferencesFullStream(String app) {
    return 'Lorsque les alertes sont activées, cette version transmet tout le flux de notifications $app disponible pour votre compte.';
  }

  @override
  String get notificationPreferencesPerCategory =>
      'Le réglage par catégorie n’est pas encore disponible dans cette version ; ce bouton contrôle donc toute la réception sur l’appareil.';

  @override
  String get notificationPreferencesSave => 'Enregistrer';

  @override
  String get privacySettingsConnectionRestoredReview =>
      'Connexion rétablie. Vérifiez vos modifications conservées, puis enregistrez.';

  @override
  String get privacySettingsConnectionRestoredRefreshing =>
      'Connexion rétablie. Actualisation des paramètres de confidentialité.';

  @override
  String get privacySettingsChangeReady =>
      'Modification de confidentialité prête à être enregistrée.';

  @override
  String get privacySettingsDraftKeptConnect =>
      'Vos modifications sont conservées. Connectez-vous avant d’enregistrer.';

  @override
  String get privacySettingsSaved =>
      'Paramètres de confidentialité enregistrés.';

  @override
  String get privacySettingsChangedElsewhereLoading =>
      'Les paramètres de confidentialité ont été modifiés ailleurs. La dernière version est en cours de chargement ; vérifiez-la avant d’enregistrer à nouveau.';

  @override
  String get privacySettingsChangeNotPermitted =>
      'Les modifications de confidentialité ne sont pas autorisées pour ce compte.';

  @override
  String get privacySettingsChangedRefresh =>
      'Les paramètres de confidentialité ont été modifiés ailleurs. Actualisez avant d’enregistrer à nouveau.';

  @override
  String get privacySettingsSaveUnconfirmed =>
      'L’enregistrement de la confidentialité n’a pas été confirmé. Actualisez avant de réessayer.';

  @override
  String get privacySettingsSaveFailedDraftKept =>
      'Les paramètres de confidentialité n’ont pas pu être enregistrés. Votre brouillon est conservé.';

  @override
  String get privacySettingsRefreshing =>
      'Actualisation des paramètres de confidentialité.';

  @override
  String get privacySettingsConnectBeforeSigningOut =>
      'Connectez-vous avant de déconnecter les autres appareils.';

  @override
  String get privacySettingsSessionsSignedOut =>
      'Les autres sessions ont été déconnectées.';

  @override
  String get privacySettingsSessionsSignOutFailed =>
      'Impossible de déconnecter les autres appareils. Réessayez.';

  @override
  String get privacySettingsSessionSecurityTimeout =>
      'Le contrôle de sécurité de la session a expiré. Réessayez.';

  @override
  String get privacySettingsSmsAccessRequired =>
      'La synchronisation SMS reste désactivée jusqu’à ce que vous accordiez l’accès aux SMS Android pour la vérification MoMo.';

  @override
  String get privacySettingsEnableMomoSmsTitle =>
      'Activer la synchronisation SMS MoMo';

  @override
  String get privacySettingsMomoSmsDisclosure =>
      'L’application lit uniquement les SMS de vérification Mobile Money approuvés sur cet appareil afin de rapprocher les paiements de contribution. Elle ne peut pas accéder aux autres messages.';

  @override
  String get privacySettingsNotNow => 'Pas maintenant';

  @override
  String get privacySettingsContinue => 'Continuer';

  @override
  String get privacySettingsLoadingTitle =>
      'Chargement des paramètres de confidentialité';

  @override
  String get privacySettingsLoadingMessage =>
      'Vérification de vos choix de confidentialité enregistrés.';

  @override
  String get privacySettingsOfflineTitle =>
      'Les paramètres de confidentialité sont hors ligne';

  @override
  String get privacySettingsOfflineMessage =>
      'Connectez-vous pour charger vos choix de confidentialité enregistrés.';

  @override
  String get privacySettingsUnavailableTitle =>
      'Paramètres de confidentialité indisponibles';

  @override
  String get privacySettingsUnavailableMessage =>
      'Connectez-vous pour consulter et gérer vos choix de confidentialité.';

  @override
  String get privacySettingsAccessLimitedTitle =>
      'Accès à la confidentialité limité';

  @override
  String get privacySettingsAccessLimitedMessage =>
      'Vos paramètres de confidentialité n’ont pas pu être vérifiés. Reconnectez-vous.';

  @override
  String get privacySettingsChangedTitle =>
      'Paramètres de confidentialité modifiés';

  @override
  String get privacySettingsChangedMessage =>
      'Actualisez pour charger les choix actuels avant de les modifier.';

  @override
  String get privacySettingsSecurityTimeoutTitle =>
      'Le contrôle de sécurité de la confidentialité a expiré';

  @override
  String get privacySettingsSecurityTimeoutMessage =>
      'Vérifiez votre connexion et actualisez.';

  @override
  String get privacySettingsLoadFailedTitle =>
      'Impossible de charger les paramètres de confidentialité.';

  @override
  String get privacySettingsLoadFailedMessage =>
      'Vos choix enregistrés sont toujours en sécurité. Réessayez.';

  @override
  String get privacySettingsSavingTitle =>
      'Enregistrement des paramètres de confidentialité';

  @override
  String get privacySettingsSavingMessage =>
      'Vos choix restent visibles pendant la confirmation de l’enregistrement.';

  @override
  String get privacySettingsRefreshingTitle =>
      'Actualisation des paramètres de confidentialité';

  @override
  String get privacySettingsRefreshingMessage =>
      'Vos choix enregistrés restent visibles.';

  @override
  String get privacySettingsEditingUnavailableTitle =>
      'Modification de la confidentialité indisponible';

  @override
  String get privacySettingsEditingUnavailableMessage =>
      'Vos choix enregistrés restent visibles.';

  @override
  String get privacySettingsChangedElsewhereTitle =>
      'Paramètres de confidentialité modifiés ailleurs';

  @override
  String get privacySettingsChangedElsewhereMessage =>
      'Actualisez et vérifiez les derniers choix.';

  @override
  String get privacySettingsSaveNotConfirmedTitle =>
      'Enregistrement de la confidentialité non confirmé';

  @override
  String get privacySettingsSaveNotConfirmedMessage =>
      'Actualisez avant de réessayer. Votre brouillon est conservé.';

  @override
  String get privacySettingsSaveFailedTitle =>
      'Impossible d’enregistrer les paramètres de confidentialité';

  @override
  String get privacySettingsSaveFailedMessage =>
      'Votre brouillon est toujours disponible.';

  @override
  String get privacySettingsSavedSettingsTitle =>
      'Paramètres de confidentialité enregistrés';

  @override
  String get privacySettingsSavedSettingsMessage =>
      'Les valeurs peuvent être obsolètes. Reconnectez-vous avant de les modifier ou de les enregistrer.';

  @override
  String get privacySettingsEditingUnavailableBuildMessage =>
      'Vos choix enregistrés restent visibles dans cette version.';

  @override
  String get privacySettingsTitle => 'Confidentialité';

  @override
  String get privacySettingsControls => 'Contrôles de confidentialité';

  @override
  String get privacySettingsControlsDescription =>
      'Choisissez de partager ou non des événements de tâche généraux et anonymes. Les requêtes, contacts, identifiants de compte, codes, messages et montants exacts des paiements ne sont jamais inclus.';

  @override
  String get privacySettingsMomoSmsSync => 'Synchronisation SMS MoMo';

  @override
  String get privacySettingsMomoSmsSyncDescription =>
      'Rapprochez les SMS de vérification Mobile Money approuvés pour vérifier plus vite les contributions.';

  @override
  String get privacySettingsShareAnalytics =>
      'Partager des statistiques d’utilisation anonymes';

  @override
  String get privacySettingsShareAnalyticsDescription =>
      'Aidez à améliorer la recherche, les billets, les contributions, la Zone Fan et les parcours de récupération.';

  @override
  String get privacySettingsAnalyticsFailClosed =>
      'Les statistiques restent désactivées sauf si vous les acceptez et si la version signée dispose d’une configuration approuvée.';

  @override
  String get privacySettingsNoChanges => 'Aucune modification à enregistrer';

  @override
  String get privacySettingsSave => 'Enregistrer la confidentialité';

  @override
  String get privacySettingsYourData => 'Vos données';

  @override
  String get privacySettingsExportDescription =>
      'Demandez un export de compte via un canal d’assistance configuré.';

  @override
  String get privacySettingsExportAction => 'Demander l’export des données';

  @override
  String privacySettingsExportWhatsAppMessage(String app) {
    return 'Demande d’export des données pour $app. Veuillez m’envoyer une copie des données de mon compte.';
  }

  @override
  String privacySettingsExportEmailSubject(String app) {
    return 'Demande d’export des données $app';
  }

  @override
  String get privacySettingsExportEmailBody =>
      'Veuillez m’envoyer une copie des données de mon compte.';

  @override
  String get privacySettingsMailFailed =>
      'Impossible d’ouvrir votre application de messagerie.';

  @override
  String get privacySettingsOpenPolicy =>
      'Ouvrir la politique de confidentialité';

  @override
  String get privacySettingsPolicyUnavailable =>
      'Politique de confidentialité indisponible';

  @override
  String get privacySettingsPolicyNotAvailableYet =>
      'La politique de confidentialité n’est pas encore disponible.';

  @override
  String get privacySettingsActiveSessions => 'Sessions actives';

  @override
  String get privacySettingsActiveSessionsDescription =>
      'Révoquez les autres sessions actives liées à votre compte.';

  @override
  String get privacySettingsSignOutOtherDevices =>
      'Déconnecter les autres appareils';

  @override
  String get adminLoadingTitle => 'Chargement de l’espace d’administration';

  @override
  String get adminLoadingMessage =>
      'Vérification des opérations actuelles du club.';

  @override
  String get adminClubAdmin => 'Administration du club';

  @override
  String get adminExit => 'Quitter l’administration';

  @override
  String get adminCommandCenter => 'Centre de commande';

  @override
  String get adminTotalUsers => 'Utilisateurs totaux';

  @override
  String get adminActiveGroups => 'Groupes actifs';

  @override
  String get adminTransactionsToday => 'Transactions du jour';

  @override
  String get adminTicketsSold => 'Billets vendus';

  @override
  String get adminQuickActions => 'Actions rapides';

  @override
  String get adminManageCms => 'Gérer le CMS';

  @override
  String get adminManageCmsDescription =>
      'Articles, bannières et surfaces de contenu';

  @override
  String get adminCreateMatch => 'Créer un match';

  @override
  String get adminCreateMatchDescription =>
      'Configuration du match, zones et contrôles des billets';

  @override
  String get adminViewContributions => 'Voir les contributions';

  @override
  String get adminViewContributionsDescription =>
      'Suivre les collectes du club et des communautés';

  @override
  String get adminSendNotification => 'Envoyer une notification';

  @override
  String get adminSendNotificationDescription =>
      'Envoi push par niveau, groupe ou à tous les supporters';

  @override
  String get adminSettleFixtures => 'Régler les matchs';

  @override
  String get adminSettleFixturesDescription =>
      'Saisir les résultats et évaluer les marchés de pronostics';

  @override
  String get adminManageCompetitions => 'Gérer les compétitions';

  @override
  String get adminManageCompetitionsDescription =>
      'Ajouter, modifier et activer les ligues et coupes prises en charge';

  @override
  String get adminSmsSyncMonitor => 'Suivi de synchronisation SMS';

  @override
  String get adminSmsSyncMonitorDescription =>
      'État du pipeline d’ingestion des SMS MoMo';

  @override
  String get adminFeatureManager => 'Gestionnaire de fonctionnalités';

  @override
  String get adminFeatureManagerDashboardDescription =>
      'Activer les fonctionnalités, la visibilité et la planification';

  @override
  String get adminRecentActivity => 'Activité récente';

  @override
  String get adminRecentActivityUnavailable => 'Activité récente indisponible';

  @override
  String get adminRecentActivityUnavailableMessage =>
      'Les totaux du tableau de bord sont à jour. Actualisez pour réessayer le flux d’activité.';

  @override
  String get adminNoRecentActivity => 'Aucune activité récente';

  @override
  String get adminNoRecentActivityMessage =>
      'Les totaux actuels sont confirmés. Les nouvelles activités du club apparaîtront ici.';

  @override
  String get adminWorkspaceUnavailable =>
      'Espace d’administration indisponible';

  @override
  String get adminMobileDisabledMessage =>
      'L’administration mobile est désactivée dans cette version contrôlée.';

  @override
  String get adminBackToSettings => 'Retour aux paramètres';

  @override
  String get adminWorkspaceOffline => 'Espace d’administration hors ligne';

  @override
  String get adminWorkspaceOfflineMessage =>
      'Reconnectez-vous avant de charger les opérations privées du club.';

  @override
  String get adminAccessUnavailable => 'Accès administrateur indisponible';

  @override
  String get adminAccessUnavailableMessage =>
      'Ce compte ne peut pas consulter l’espace d’administration actuel du club.';

  @override
  String get adminDataChanged => 'Données administratives modifiées';

  @override
  String get adminDataChangedMessage =>
      'Actualisez avant de poursuivre les opérations actuelles du club.';

  @override
  String get adminSecurityTimeout => 'Le contrôle de sécurité a expiré';

  @override
  String get adminSecurityTimeoutMessage =>
      'Aucune donnée administrative n’a été affichée. Vérifiez votre connexion et réessayez.';

  @override
  String get adminPrivateDataHiddenMessage =>
      'Les données privées du club restent masquées. Réessayez.';

  @override
  String get adminRefreshingTitle =>
      'Actualisation de l’espace d’administration';

  @override
  String get adminRefreshingMessage =>
      'Le dernier tableau de bord confirmé reste affiché pendant la vérification des données actuelles.';

  @override
  String get adminRefreshTimedOut => 'L’actualisation a expiré';

  @override
  String get adminCurrentRefreshUnavailable =>
      'Actualisation actuelle indisponible';

  @override
  String get adminLastConfirmedMessage =>
      'Le dernier tableau de bord confirmé reste affiché. Les actions sont suspendues jusqu’à la réussite de l’actualisation.';

  @override
  String get adminAccessRequired => 'Accès administrateur requis';

  @override
  String get adminAccessRequiredMessage =>
      'Cet espace est réservé aux administrateurs de club vérifiés pour le club actif.';

  @override
  String get adminChallengesTitle => 'Opérations des défis';

  @override
  String get adminBack => 'Retour';

  @override
  String get adminChallengesLoadingTitle =>
      'Chargement des opérations de défis';

  @override
  String get adminChallengesLoadingMessage =>
      'Vérification des règlements en cours.';

  @override
  String get adminChallengesFilterLabel => 'Filtre d’état des défis';

  @override
  String get adminChallengesFilterAll => 'Tous';

  @override
  String get adminChallengesFilterOpen => 'Ouverts';

  @override
  String get adminChallengesFilterLocked => 'Verrouillés';

  @override
  String get adminChallengesFilterSettled => 'Réglés';

  @override
  String get adminChallengesFilterVoid => 'Annulés';

  @override
  String get adminChallengesEmptyTitle => 'Aucune opération de défi';

  @override
  String get adminChallengesEmptyAllMessage =>
      'Aucun défi n’est actuellement en attente.';

  @override
  String adminChallengesEmptyFilteredMessage(String status) {
    return 'Aucun défi $status n’est actuellement en attente.';
  }

  @override
  String get adminChallengesRetryTitle => 'Réessayer le règlement ?';

  @override
  String adminChallengesRetryMessage(String home, String away) {
    return 'Revérifiez $home contre $away. Ne réessayez pas avant la confirmation de l’état actualisé.';
  }

  @override
  String get adminCancelUpper => 'Annuler';

  @override
  String get adminRetryUpper => 'Réessayer';

  @override
  String get adminChallengesSettlementPending =>
      'Le règlement reste en attente. Vérifiez l’état actualisé.';

  @override
  String get adminChallengesSettlementRefreshed =>
      'État du règlement actualisé.';

  @override
  String get adminChallengesUnavailable => 'Opérations de défis indisponibles';

  @override
  String get adminChallengesDisabledMessage =>
      'Les contrôles de règlement des défis sont désactivés dans cette version contrôlée.';

  @override
  String get adminBackToAdmin => 'Retour à l’administration';

  @override
  String get adminChallengesOffline => 'Opérations de défis hors ligne';

  @override
  String get adminChallengesOfflineMessage =>
      'Reconnectez-vous avant de charger les règlements privés.';

  @override
  String get adminChallengesAccessUnavailable => 'Accès aux défis indisponible';

  @override
  String get adminChallengesAccessUnavailableMessage =>
      'Ce compte ne peut pas consulter ni relancer les règlements des défis du club.';

  @override
  String get adminChallengesStatusChanged => 'État du défi modifié';

  @override
  String get adminChallengesStatusChangedMessage =>
      'Actualisez avant de poursuivre le règlement.';

  @override
  String get adminChallengesSecurityTimeoutMessage =>
      'Aucune donnée de défi n’a été affichée. Vérifiez votre connexion et réessayez.';

  @override
  String get adminChallengesPrivateDataHidden =>
      'Les données privées de règlement restent masquées. Réessayez.';

  @override
  String get adminChallengesRetryingTitle => 'Nouvelle tentative de règlement';

  @override
  String get adminChallengesRetryingMessage =>
      'Les contrôles sont suspendus jusqu’à la confirmation du résultat actuel.';

  @override
  String get adminChallengesRefreshingTitle =>
      'Actualisation des opérations de défis';

  @override
  String get adminChallengesRefreshingMessage =>
      'La dernière liste confirmée reste affichée pendant la vérification de l’état actuel.';

  @override
  String get adminChallengesOutcomeUnconfirmed =>
      'Le résultat de la nouvelle tentative n’est pas confirmé. Actualisez avant toute autre action.';

  @override
  String get adminChallengesLastConfirmedMessage =>
      'La dernière liste confirmée reste affichée. Les actions sont suspendues jusqu’à la réussite de l’actualisation.';

  @override
  String get adminChallengesVoidReasonRecorded =>
      'Motif d’annulation enregistré';

  @override
  String get adminChallengesNoVoidReason => 'Aucun motif d’annulation';

  @override
  String adminChallengesSettlementMode(String mode) {
    return 'Règlement $mode';
  }

  @override
  String adminChallengesAuditState(String state) {
    return 'Audit $state';
  }

  @override
  String get adminChallengesRetryingAction => 'Règlement en cours';

  @override
  String get adminChallengesRetryAction => 'Relancer le règlement';

  @override
  String get adminChallengesCreator => 'Créateur';

  @override
  String get adminChallengesPool => 'Cagnotte';

  @override
  String get adminChallengesParticipants => 'Participants';

  @override
  String adminVersus(String home, String away) {
    return '$home contre $away';
  }

  @override
  String adminMetricSemantic(String label, String value) {
    return '$label $value';
  }

  @override
  String get adminSettlementConfirmTitle => 'Régler ce match ?';

  @override
  String adminSettlementConfirmMessage(
    String home,
    int homeScore,
    int awayScore,
    String away,
  ) {
    return '$home $homeScore – $awayScore $away\n\nCette action évalue les marchés de pronostics et peut déclencher des récompenses. Confirmez uniquement à partir du résultat officiel.';
  }

  @override
  String get adminSettlementSettleUpper => 'Régler';

  @override
  String adminSettlementReceipt(String score, int markets, int won, int lost) {
    return 'Réglé $score • $markets marchés • $won gagnés • $lost perdus';
  }

  @override
  String get adminSettlementReviewOfficialResult =>
      'Vérifiez le résultat officiel et réessayez.';

  @override
  String get adminSettlementNotConfirmed =>
      'Le règlement du match n’a pas été confirmé.';

  @override
  String get adminSettlementTitle => 'Régler les matchs';

  @override
  String get adminSettlementLoadingTitle =>
      'Chargement de l’espace de règlement';

  @override
  String get adminSettlementLoadingMessage =>
      'Vérification des informations contrôlées du match.';

  @override
  String get adminSettlementFilterScheduled => 'Programmés';

  @override
  String get adminSettlementFilterFinished => 'Terminés';

  @override
  String get adminSettlementFilterAll => 'Tous';

  @override
  String get adminSettlementControlTitle => 'Contrôle du résultat officiel';

  @override
  String get adminSettlementControlMessage =>
      'Le règlement évalue les marchés de pronostics et peut déclencher des récompenses. Utilisez uniquement un score final officiel et confirmé.';

  @override
  String get adminSettlementEmptyTitle => 'Aucun match dans cette vue';

  @override
  String get adminSettlementEmptyMessage =>
      'Changez de filtre ou attendez les informations contrôlées du match.';

  @override
  String get adminSettlementVersusShort => 'Contre';

  @override
  String get adminSettlementOpenHint =>
      'Ouvrir la confirmation du résultat officiel';

  @override
  String get adminSettlementUnavailableHint => 'Règlement indisponible';

  @override
  String get adminSettlementEnterOfficialResult =>
      'Saisir le résultat officiel';

  @override
  String get adminSettlementPaused => 'Règlement suspendu';

  @override
  String get adminSettlementSettled => 'Réglé';

  @override
  String get adminSettlementNotSettleable => 'Non réglable';

  @override
  String get adminSettlementManagementUnavailable =>
      'Gestion des règlements indisponible';

  @override
  String get adminSettlementDisabledMessage =>
      'Les contrôles de règlement sont désactivés dans cette version contrôlée.';

  @override
  String get adminSettlementWorkspaceOffline =>
      'Espace de règlement hors ligne';

  @override
  String get adminSettlementWorkspaceOfflineMessage =>
      'Reconnectez-vous avant de charger les informations privées du match.';

  @override
  String get adminSettlementAccessUnavailable =>
      'Accès au règlement indisponible';

  @override
  String get adminSettlementAccessUnavailableMessage =>
      'Ce compte ne peut pas consulter ni régler les matchs de pronostics.';

  @override
  String get adminSettlementResultChanged => 'Résultat du match modifié';

  @override
  String get adminSettlementResultChangedMessage =>
      'Actualisez avant de confirmer un autre règlement.';

  @override
  String get adminSettlementSecurityTimeoutMessage =>
      'Aucune information de match n’a été affichée. Vérifiez votre connexion.';

  @override
  String get adminSettlementWorkspaceUnavailable =>
      'Espace de règlement indisponible';

  @override
  String get adminSettlementPrivateDataHidden =>
      'Les informations privées du match restent masquées. Réessayez.';

  @override
  String get adminSettlementCheckingResults =>
      'Vérification des résultats des matchs';

  @override
  String get adminSettlementCheckingResultsMessage =>
      'Le dernier état confirmé reste affiché pendant la vérification des données actuelles.';

  @override
  String get adminSettlementOutcomeUnconfirmed =>
      'Le dernier règlement n’est pas confirmé. Les contrôles restent suspendus jusqu’à la réussite de l’actualisation.';

  @override
  String get adminSettlementLastConfirmedMessage =>
      'Les dernières informations de match confirmées restent visibles. Les contrôles sont suspendus.';

  @override
  String get adminSettlementFinalScoreValidation =>
      'Saisissez des scores finaux compris entre 0 et 99.';

  @override
  String get adminSettlementHalfTimeValidation =>
      'Saisissez les deux scores de mi-temps sans dépasser le score final.';

  @override
  String get adminSettlementHalfTimeScore => 'Score à la mi-temps';

  @override
  String get adminSettlementHideHalfTime =>
      'Masquer les champs du score à la mi-temps';

  @override
  String get adminSettlementShowHalfTime =>
      'Afficher les champs du score à la mi-temps';

  @override
  String get adminSettlementHalfTimeOptional =>
      'Score à la mi-temps (facultatif)';

  @override
  String adminSettlementHalfTimeLabel(String team) {
    return '$team MT';
  }

  @override
  String get adminSettlementReviewAction => 'Vérifier le règlement';

  @override
  String get adminStatusFinished => 'Terminé';

  @override
  String get adminStatusScheduled => 'Programmé';

  @override
  String get adminStatusLive => 'En direct';

  @override
  String get adminStatusCancelled => 'Annulé';

  @override
  String get adminStatusPostponed => 'Reporté';

  @override
  String adminScore(int home, int away) {
    return '$home – $away';
  }

  @override
  String get adminFeatureDetailTitle => 'Détail de la fonctionnalité';

  @override
  String get adminFeatureLoadingTitle =>
      'Chargement des paramètres de la fonctionnalité';

  @override
  String get adminFeatureLoadingMessage =>
      'Vérification des canaux contrôlés et des règles d’accès.';

  @override
  String get adminFeatureNotFound => 'Fonctionnalité introuvable';

  @override
  String get adminFeatureNotFoundMessage =>
      'Aucune fonctionnalité confirmée ne correspond à cette route contrôlée.';

  @override
  String get adminBackToFeatures => 'Retour aux fonctionnalités';

  @override
  String get adminFeatureGlobalState => 'État global';

  @override
  String adminFeatureDisableTooltip(String feature) {
    return 'Désactiver $feature';
  }

  @override
  String adminFeatureEnableTooltip(String feature) {
    return 'Activer $feature';
  }

  @override
  String adminFeatureStateSemantic(String feature, String state) {
    return '$feature est $state';
  }

  @override
  String get adminFeatureChangesGlobalState =>
      'Modifie l’état global de la fonctionnalité';

  @override
  String get adminFeatureEnabled => 'Activée';

  @override
  String get adminFeatureDisabled => 'Désactivée';

  @override
  String get adminFeatureTapDisable =>
      'Touchez pour désactiver cette fonctionnalité globalement';

  @override
  String get adminFeatureTapEnable =>
      'Touchez pour activer cette fonctionnalité globalement';

  @override
  String get adminFeatureVisibility => 'Visibilité';

  @override
  String get adminFeatureVisibilityVisible => 'Visible';

  @override
  String get adminFeatureVisibilityHidden => 'Masquée';

  @override
  String get adminFeatureVisibilityMaintenance => 'Maintenance';

  @override
  String get adminFeatureChannelConfig => 'Configuration des canaux';

  @override
  String get adminFeatureNoChannelOverrides => 'Aucune substitution de canal';

  @override
  String get adminFeatureNoChannelOverridesMessage =>
      'Cette fonctionnalité utilise son état global confirmé.';

  @override
  String get adminFeatureScheduling => 'Planification';

  @override
  String get adminFeatureAccessRules => 'Règles d’accès';

  @override
  String get adminFeatureAuthRequired => 'Authentification requise';

  @override
  String get adminFeatureAuthRequiredMessage =>
      'Les utilisateurs doivent se connecter avant d’accéder à cette fonctionnalité.';

  @override
  String get adminFeatureSettingsUnavailable =>
      'Paramètres de fonctionnalité indisponibles';

  @override
  String get adminFeatureEditingDisabled =>
      'La modification des fonctionnalités est désactivée dans cette version contrôlée.';

  @override
  String get adminFeatureSettingsOffline =>
      'Paramètres de fonctionnalité hors ligne';

  @override
  String get adminFeatureSettingsOfflineMessage =>
      'Reconnectez-vous avant de charger la configuration privée.';

  @override
  String get adminFeatureAccessUnavailable =>
      'Accès à la fonctionnalité indisponible';

  @override
  String get adminFeatureAccessUnavailableMessage =>
      'Ce compte ne peut pas consulter ni modifier les paramètres de la fonctionnalité.';

  @override
  String get adminFeatureSettingsChanged =>
      'Paramètres de fonctionnalité modifiés';

  @override
  String get adminFeatureSettingsChangedMessage =>
      'Actualisez avant d’effectuer une autre modification.';

  @override
  String get adminFeatureSecurityTimeoutMessage =>
      'Aucun paramètre de fonctionnalité n’a été affiché. Vérifiez votre connexion.';

  @override
  String get adminFeaturePrivateDataHidden =>
      'Les paramètres privés restent masqués. Réessayez.';

  @override
  String get adminFeatureCheckingTitle =>
      'Vérification des paramètres de fonctionnalité';

  @override
  String get adminFeatureCheckingMessage =>
      'Le dernier état confirmé reste affiché pendant la vérification des données actuelles.';

  @override
  String get adminFeatureOutcomeUnconfirmed =>
      'La dernière modification n’est pas confirmée. Les contrôles restent suspendus jusqu’à la réussite de l’actualisation.';

  @override
  String get adminFeatureLastConfirmed =>
      'Les derniers paramètres confirmés restent visibles. Les contrôles sont suspendus.';

  @override
  String get adminFeatureChannelMobile => 'Mobile';

  @override
  String get adminFeatureChannelWeb => 'Web';

  @override
  String get adminFeatureChannelEnabled => 'Activée';

  @override
  String get adminFeatureChannelEnabledMessage =>
      'La fonctionnalité est active sur ce canal.';

  @override
  String get adminFeatureChannelVisible => 'Visible';

  @override
  String get adminFeatureChannelVisibleMessage =>
      'La fonctionnalité peut être affichée sur ce canal.';

  @override
  String get adminFeatureShowInNavigation => 'Afficher dans la navigation';

  @override
  String get adminFeatureShowInNavigationMessage =>
      'Inclure cette fonctionnalité dans la navigation du canal.';

  @override
  String get adminFeatureShowOnHome => 'Afficher sur l’accueil';

  @override
  String get adminFeatureShowOnHomeMessage =>
      'Inclure cette fonctionnalité sur l’écran d’accueil du canal.';

  @override
  String get adminFeatureAvailableFrom => 'Disponible à partir de';

  @override
  String get adminFeatureAvailableUntil => 'Disponible jusqu’au';

  @override
  String get adminFeatureClearSchedule => 'Effacer la planification';

  @override
  String get adminFeatureNotSet => 'Non défini';

  @override
  String adminFeatureSetTooltip(String label) {
    return 'Définir $label';
  }

  @override
  String adminFeatureDateSemantic(String label, String value) {
    return '$label : $value';
  }

  @override
  String get adminFeatureOpenDateTime =>
      'Ouvre la sélection de la date et de l’heure';

  @override
  String get adminMatchesTitle => 'Matchs';

  @override
  String get adminMatchesLoadingTitle => 'Chargement de l’espace des matchs';

  @override
  String get adminMatchesLoadingMessage =>
      'Vérification des informations contrôlées des matchs.';

  @override
  String get adminMatchesDescription =>
      'Gérez les matchs, leur mise en vente, l’allocation des billets et les scores en direct à partir de données confirmées.';

  @override
  String get adminMatchesFixtures => 'Matchs';

  @override
  String get adminMatchesOnSale => 'En vente';

  @override
  String get adminMatchesStatus => 'État';

  @override
  String get adminMatchesFilterAll => 'Tous';

  @override
  String get adminMatchesFilterLive => 'En direct';

  @override
  String get adminMatchesFilterUpcoming => 'À venir';

  @override
  String get adminMatchesFilterOnSale => 'En vente';

  @override
  String get adminMatchesFilterCompleted => 'Terminés';

  @override
  String get adminMatchesNoneConfigured => 'Aucun match configuré';

  @override
  String get adminMatchesNoneMatch => 'Aucun match correspondant';

  @override
  String get adminMatchesNoneConfiguredMessage =>
      'Un match confirmé du club doit exister avant que cet espace puisse déterminer son périmètre partenaire.';

  @override
  String get adminMatchesNoneMatchMessage =>
      'Choisissez un autre filtre d’état.';

  @override
  String get adminMatchesCreate => 'Créer un match';

  @override
  String get adminMatchesCreationPaused =>
      'La création reste suspendue jusqu’à la disponibilité d’un périmètre partenaire confirmé.';

  @override
  String get adminMatchesCreated => 'Match créé avec succès.';

  @override
  String get adminMatchesUpdated => 'Match mis à jour avec succès.';

  @override
  String get adminMatchesManagementUnavailable =>
      'Gestion des matchs indisponible';

  @override
  String get adminMatchesDisabledMessage =>
      'Les contrôles des matchs sont désactivés dans cette version contrôlée.';

  @override
  String get adminMatchesWorkspaceOffline => 'Espace des matchs hors ligne';

  @override
  String get adminMatchesWorkspaceOfflineMessage =>
      'Reconnectez-vous avant de charger les informations privées des matchs.';

  @override
  String get adminMatchesAccessUnavailable => 'Accès aux matchs indisponible';

  @override
  String get adminMatchesAccessUnavailableMessage =>
      'Ce compte ne peut pas consulter ni modifier les informations des matchs.';

  @override
  String get adminMatchesInformationChanged =>
      'Informations du match modifiées';

  @override
  String get adminMatchesInformationChangedMessage =>
      'Actualisez avant d’effectuer une autre modification.';

  @override
  String get adminMatchesSecurityTimeoutMessage =>
      'Aucune information de match n’a été affichée. Vérifiez votre connexion.';

  @override
  String get adminMatchesWorkspaceUnavailable =>
      'Espace des matchs indisponible';

  @override
  String get adminMatchesPrivateDataHidden =>
      'Les informations privées du match restent masquées. Réessayez.';

  @override
  String get adminMatchesCheckingTitle =>
      'Vérification des informations du match';

  @override
  String get adminMatchesCheckingMessage =>
      'Le dernier état confirmé reste affiché pendant la vérification des données actuelles.';

  @override
  String get adminMatchesOutcomeUnconfirmed =>
      'La dernière modification n’est pas confirmée. Les contrôles restent suspendus jusqu’à la réussite de l’actualisation.';

  @override
  String get adminMatchesLastConfirmed =>
      'Les dernières informations confirmées du match restent visibles. Les contrôles sont suspendus.';

  @override
  String adminMatchesOpenTooltip(String home, String away) {
    return 'Ouvrir $home contre $away';
  }

  @override
  String adminMatchesFixtureSemantic(String home, String away) {
    return 'Match $home contre $away';
  }

  @override
  String get adminMatchesOpenHint => 'Ouvre les paramètres contrôlés du match';

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
    return 'Général $symbol $general • VIP $symbol $vip';
  }

  @override
  String adminMatchesScore(int home, int away, String minute) {
    return 'Score $home-$away$minute';
  }

  @override
  String adminMatchesAllocation(int percent, int sold, int capacity) {
    return '$percent % alloués • $sold / $capacity billets';
  }

  @override
  String get adminMatchesEditOnSale => 'Modifier le match en vente';

  @override
  String get adminMatchesEdit => 'Modifier le match';

  @override
  String get adminStatusHalfTime => 'Mi-temps';

  @override
  String get adminStatusFullTime => 'Terminé';

  @override
  String get adminStatusUpcoming => 'À venir';

  @override
  String adminMatchesLiveMinute(int minute) {
    return ' • ${minute}e';
  }

  @override
  String get adminMatchSaveNotConfirmed =>
      'Le match n’a pas été enregistré. Vérifiez l’état confirmé de l’espace.';

  @override
  String get adminMatchReviewFields =>
      'Vérifiez tous les champs du match et saisissez des valeurs valides.';

  @override
  String get adminMatchSaveFailedRefresh =>
      'Le match n’a pas été enregistré. Actualisez puis réessayez.';

  @override
  String get adminMatchCreateTitle => 'Créer un match';

  @override
  String get adminMatchUpdateTitle => 'Mettre à jour le match';

  @override
  String get adminMatchHomeTeam => 'Équipe à domicile';

  @override
  String get adminMatchAwayTeam => 'Équipe à l’extérieur';

  @override
  String get adminMatchCompetition => 'Compétition';

  @override
  String get adminMatchVenue => 'Lieu';

  @override
  String adminMatchGeneralPrice(String symbol) {
    return 'Général $symbol';
  }

  @override
  String adminMatchVipPrice(String symbol) {
    return 'VIP $symbol';
  }

  @override
  String get adminMatchCapacity => 'Capacité';

  @override
  String get adminMatchTicketsOnSale => 'Billets en vente';

  @override
  String get adminMatchStatus => 'État du match';

  @override
  String get adminMatchStatusScheduled => 'Programmé';

  @override
  String get adminMatchStatusLive => 'En direct';

  @override
  String get adminMatchStatusHalfTime => 'Mi-temps';

  @override
  String get adminMatchStatusFullTime => 'Terminé';

  @override
  String get adminMatchStatusPostponed => 'Reporté';

  @override
  String get adminMatchStatusCancelled => 'Annulé';

  @override
  String get adminMatchHomeScore => 'Score à domicile';

  @override
  String get adminMatchAwayScore => 'Score à l’extérieur';

  @override
  String get adminMatchLiveMinute => 'Minute de jeu';

  @override
  String get adminMatchSummary => 'Résumé du match / note en direct';

  @override
  String get adminMatchSave => 'Enregistrer le match';

  @override
  String get adminMatchUpdate => 'Mettre à jour le match';

  @override
  String get adminFeatureManagerTitle => 'Gestionnaire de fonctionnalités';

  @override
  String get adminFeatureRegistryLoading =>
      'Chargement du registre des fonctionnalités';

  @override
  String get adminFeatureRegistryLoadingMessage =>
      'Vérification de la configuration contrôlée des fonctionnalités.';

  @override
  String get adminFeatureManagerDescription =>
      'Contrôlez la disponibilité des fonctionnalités du club avec une configuration confirmée et bornée.';

  @override
  String get adminFeatureRegistered => 'Enregistrées';

  @override
  String get adminFeatureEnabledUpper => 'Activées';

  @override
  String get adminFeatureDisabledUpper => 'Désactivées';

  @override
  String get adminFeatureStatus => 'État';

  @override
  String get adminFeatureFilterAll => 'Toutes';

  @override
  String get adminFeatureNoneConfigured => 'Aucune fonctionnalité configurée';

  @override
  String get adminFeatureNoneMatch => 'Aucune fonctionnalité correspondante';

  @override
  String get adminFeatureNoneConfiguredMessage =>
      'La configuration confirmée des fonctionnalités apparaîtra ici.';

  @override
  String get adminFeatureNoneMatchMessage =>
      'Choisissez un autre filtre d’état.';

  @override
  String get adminFeatureManagementUnavailable =>
      'Gestion des fonctionnalités indisponible';

  @override
  String get adminFeatureControlsDisabled =>
      'Les contrôles de fonctionnalité sont désactivés dans cette version contrôlée.';

  @override
  String get adminFeatureRegistryOffline =>
      'Registre des fonctionnalités hors ligne';

  @override
  String get adminFeatureConfigurationAccessMessage =>
      'Ce compte ne peut pas consulter ni modifier la configuration des fonctionnalités.';

  @override
  String get adminFeatureConfigurationChanged =>
      'Configuration des fonctionnalités modifiée';

  @override
  String get adminFeatureConfigurationChangedMessage =>
      'Actualisez avant d’effectuer une autre modification.';

  @override
  String get adminFeatureConfigurationSecurityMessage =>
      'Aucune configuration de fonctionnalité n’a été affichée. Vérifiez votre connexion.';

  @override
  String get adminFeatureRegistryUnavailable =>
      'Registre des fonctionnalités indisponible';

  @override
  String get adminFeatureConfigurationHidden =>
      'La configuration privée reste masquée. Réessayez.';

  @override
  String get adminFeatureConfigurationChecking =>
      'Vérification de la configuration des fonctionnalités';

  @override
  String get adminFeatureConfigurationLastConfirmed =>
      'La dernière configuration confirmée reste visible. Les contrôles sont suspendus.';

  @override
  String adminFeatureOpenTooltip(String feature) {
    return 'Ouvrir $feature';
  }

  @override
  String adminFeatureSettingsSemantic(String feature) {
    return 'Paramètres de la fonctionnalité $feature';
  }

  @override
  String get adminFeatureOpenSettingsHint =>
      'Ouvre les paramètres contrôlés de la fonctionnalité';

  @override
  String adminFeatureChangeVisibilityTooltip(String feature) {
    return 'Modifier la visibilité de $feature';
  }

  @override
  String get adminFeatureChangeVisibility => 'Modifier la visibilité';

  @override
  String get adminCompetitionsTitle => 'Compétitions';

  @override
  String get adminCompetitionsAdd => 'Ajouter une compétition';

  @override
  String get adminCompetitionsActionsUnavailable =>
      'Actions de compétition indisponibles';

  @override
  String get adminCompetitionsLoading => 'Chargement des compétitions';

  @override
  String get adminCompetitionsLoadingMessage =>
      'Vérification de l’espace contrôlé des compétitions.';

  @override
  String get adminCompetitionsDescription =>
      'Gérez les compétitions et les saisons accessibles au moteur de pronostics.';

  @override
  String get adminCompetitionsNoneConfigured => 'Aucune compétition configurée';

  @override
  String get adminCompetitionsNoneMatch => 'Aucune compétition correspondante';

  @override
  String get adminCompetitionsNoneConfiguredMessage =>
      'Créez la première compétition contrôlée lorsque l’accès est disponible.';

  @override
  String get adminCompetitionsNoneMatchMessage =>
      'Choisissez une autre région ou un autre type de compétition.';

  @override
  String get adminCompetitionsManagementUnavailable =>
      'Gestion des compétitions indisponible';

  @override
  String get adminCompetitionsControlsDisabled =>
      'Les contrôles de compétition sont désactivés pour cette version contrôlée.';

  @override
  String get adminCompetitionsOffline => 'Espace des compétitions hors ligne';

  @override
  String get adminCompetitionsOfflineMessage =>
      'Reconnectez-vous avant de charger les données privées des compétitions.';

  @override
  String get adminCompetitionsAccessUnavailable =>
      'Accès aux compétitions indisponible';

  @override
  String get adminCompetitionsAccessMessage =>
      'Ce compte ne peut pas consulter ni modifier la configuration des compétitions.';

  @override
  String get adminCompetitionsDataChanged => 'Données de compétition modifiées';

  @override
  String get adminCompetitionsDataChangedMessage =>
      'Actualisez avant de poursuivre le travail sur les compétitions.';

  @override
  String get adminCompetitionsSecurityMessage =>
      'Aucune donnée de compétition n’a été affichée. Vérifiez votre connexion.';

  @override
  String get adminCompetitionsWorkspaceUnavailable =>
      'Espace des compétitions indisponible';

  @override
  String get adminCompetitionsHiddenMessage =>
      'Les données privées des compétitions restent masquées. Réessayez.';

  @override
  String get adminCompetitionsUpdating =>
      'Mise à jour de l’espace des compétitions';

  @override
  String get adminCompetitionsUpdatingMessage =>
      'Les contrôles sont suspendus jusqu’à la confirmation du résultat actuel.';

  @override
  String get adminCompetitionsRefreshing => 'Actualisation des compétitions';

  @override
  String get adminCompetitionsRefreshingMessage =>
      'Affichage des dernières données confirmées pendant la vérification.';

  @override
  String get adminCompetitionsCurrentRefreshUnavailable =>
      'Actualisation actuelle indisponible';

  @override
  String get adminCompetitionsOutcomeUnconfirmed =>
      'Le résultat de la mise à jour n’est pas confirmé. Actualisez avant une autre action.';

  @override
  String get adminCompetitionsLastConfirmed =>
      'Les dernières données confirmées sont affichées. Les actions sont suspendues jusqu’à l’actualisation.';

  @override
  String get adminCompetitionCreated => 'Compétition créée';

  @override
  String get adminCompetitionUpdated => 'Compétition mise à jour';

  @override
  String get adminCompetitionActivateQuestion => 'Activer la compétition ?';

  @override
  String get adminCompetitionDeactivateQuestion => 'Désactiver ?';

  @override
  String adminCompetitionActivateMessage(String competition) {
    return '$competition sera accessible aux parcours de pronostics configurés.';
  }

  @override
  String adminCompetitionDeactivateMessage(String competition) {
    return '$competition ne sera plus accessible aux parcours de pronostics configurés.';
  }

  @override
  String get adminActivateUpper => 'Activer';

  @override
  String get adminDeactivateUpper => 'Désactiver';

  @override
  String get adminCompetitionActivated => 'Compétition activée';

  @override
  String get adminCompetitionDeactivated => 'Compétition désactivée';

  @override
  String get adminCompetitionsTotal => 'Total';

  @override
  String get adminCompetitionsActive => 'Active';

  @override
  String get adminCompetitionsInactive => 'Inactive';

  @override
  String get adminCompetitionFilters => 'Filtres des compétitions';

  @override
  String get adminCompetitionRegion => 'Région';

  @override
  String get adminCompetitionKind => 'Type';

  @override
  String get adminCompetitionSeasons => 'Saisons';

  @override
  String get adminEditUpper => 'Modifier';

  @override
  String get adminCompetitionFilterAll => 'Toutes';

  @override
  String get adminCompetitionRegionAfrica => 'Afrique';

  @override
  String get adminCompetitionRegionEurope => 'Europe';

  @override
  String get adminCompetitionRegionInternational => 'International';

  @override
  String get adminCompetitionRegionGlobal => 'Mondial';

  @override
  String get adminCompetitionKindLeague => 'Championnat';

  @override
  String get adminCompetitionKindCup => 'Coupe';

  @override
  String get adminCompetitionKindTournament => 'Tournoi';

  @override
  String get adminCompetitionEdit => 'Modifier la compétition';

  @override
  String get adminCompetitionAdd => 'Ajouter une compétition';

  @override
  String get adminCompetitionName => 'Nom';

  @override
  String get adminCompetitionShortName => 'Nom court';

  @override
  String get adminCompetitionSlug => 'Identifiant';

  @override
  String get adminCompetitionSlugHint => 'ex. championnat-national';

  @override
  String get adminCompetitionOrganizer => 'Organisateur';

  @override
  String get adminOptional => 'Facultatif';

  @override
  String get adminCompetitionCountryCode => 'Code pays';

  @override
  String get adminCompetitionCountryCodeHint => 'Rw';

  @override
  String get adminCompetitionCountryName => 'Nom du pays';

  @override
  String get adminCompetitionCountryNameHint => 'Rwanda';

  @override
  String get adminCompetitionFormatNotes => 'Notes sur le format';

  @override
  String get adminCompetitionValidationMessage =>
      'Vérifiez les noms requis, l’identifiant et le code pays.';

  @override
  String get adminCompetitionAvailable =>
      'Accessible aux parcours de pronostics configurés';

  @override
  String get adminCompetitionUnavailable =>
      'Indisponible pour les parcours de pronostics';

  @override
  String get adminSaveChanges => 'Enregistrer les modifications';

  @override
  String get adminCreateCompetition => 'Créer la compétition';

  @override
  String get adminSeasonAdd => 'Ajouter une saison';

  @override
  String get adminSeasonActionsUnavailable => 'Actions de saison indisponibles';

  @override
  String get adminSeasonNoneConfigured => 'Aucune saison configurée';

  @override
  String get adminSeasonNoneConfiguredMessage =>
      'Ajoutez la première saison contrôlée lorsque l’accès est disponible.';

  @override
  String get adminSeasonCreated => 'Saison créée';

  @override
  String get adminSeasonActivateQuestion => 'Activer la saison ?';

  @override
  String get adminSeasonDeactivateQuestion => 'Désactiver la saison ?';

  @override
  String adminSeasonAvailabilityMessage(String season, String availability) {
    return '$season sera $availability pour les parcours de compétition configurés.';
  }

  @override
  String get adminAvailable => 'disponible';

  @override
  String get adminUnavailable => 'indisponible';

  @override
  String get adminSeasonActivated => 'Saison activée';

  @override
  String get adminSeasonDeactivated => 'Saison désactivée';

  @override
  String get adminSeasonActivate => 'Activer la saison';

  @override
  String get adminSeasonDeactivate => 'Désactiver la saison';

  @override
  String get adminSeasonValidationMessage =>
      'Vérifiez l’identifiant, le libellé et les années de la saison.';

  @override
  String get adminSeasonAddUpper => 'Ajouter une saison';

  @override
  String get adminSeasonSlugHint => 'ex. championnat-2026';

  @override
  String get adminSeasonLabel => 'Libellé';

  @override
  String get adminSeasonLabelHint => 'ex. 2025/2026';

  @override
  String get adminSeasonYearStart => 'Année de début';

  @override
  String get adminSeasonYearEnd => 'Année de fin';

  @override
  String get adminCreateUpper => 'Créer';

  @override
  String get adminSeasonStatusPlanned => 'Planifiée';

  @override
  String get adminSeasonStatusActive => 'Active';

  @override
  String get adminSeasonStatusFinished => 'Terminée';

  @override
  String get adminSeasonStatusArchived => 'Archivée';

  @override
  String get adminNotificationSendTitle => 'Envoyer une notification';

  @override
  String get adminNotificationLoading =>
      'Chargement de l’espace des notifications';

  @override
  String get adminNotificationLoadingMessage =>
      'Vérification des informations de livraison contrôlées.';

  @override
  String get adminNotificationDeliveryStatus => 'État de livraison';

  @override
  String get adminNotificationDeliveryStatusMessage =>
      'Livraison via les fonctions Edge. Les envois planifiés sont déclenchés automatiquement.';

  @override
  String get adminNotificationAudience => 'Public';

  @override
  String get adminNotificationAudienceAllFans => 'Tous les supporters';

  @override
  String get adminNotificationAudienceByTier => 'Par niveau';

  @override
  String get adminNotificationAudienceByGroup => 'Par groupe';

  @override
  String get adminNotificationTierFan => 'Fan';

  @override
  String get adminNotificationTierBronze => 'Bronze';

  @override
  String get adminNotificationTierGold => 'Or';

  @override
  String get adminNotificationTierPlatinum => 'Platine';

  @override
  String get adminNotificationSelectGroup => 'Sélectionner un groupe';

  @override
  String get adminNotificationTitleLabel => 'Titre de la notification';

  @override
  String get adminNotificationBodyLabel => 'Corps du message';

  @override
  String adminNotificationCharacterCount(int count) {
    return '$count caractères';
  }

  @override
  String get adminNotificationImageUrl => 'URL d’image facultative';

  @override
  String get adminNotificationSchedule => 'Planifier';

  @override
  String get adminNotificationSendNow => 'Envoyer maintenant';

  @override
  String get adminNotificationPickDateTime => 'Choisir la date et l’heure';

  @override
  String get adminNotificationScheduleAction => 'Planifier la notification';

  @override
  String get adminNotificationSendAction => 'Envoyer la notification';

  @override
  String get adminNotificationCopyPayload => 'Copier les données';

  @override
  String get adminNotificationSendHistory => 'Historique des envois';

  @override
  String get adminNotificationHistoryEmpty =>
      'Aucun historique de notification';

  @override
  String get adminNotificationHistoryEmptyMessage =>
      'Les livraisons confirmées apparaîtront ici après une demande.';

  @override
  String get adminNotificationManagementUnavailable =>
      'Gestion des notifications indisponible';

  @override
  String get adminNotificationControlsDisabled =>
      'Les contrôles de notification sont désactivés pour cette version contrôlée.';

  @override
  String get adminNotificationWorkspaceOffline =>
      'Espace des notifications hors ligne';

  @override
  String get adminNotificationOfflineMessage =>
      'Reconnectez-vous avant de charger les informations privées de livraison.';

  @override
  String get adminNotificationAccessUnavailable =>
      'Accès aux notifications indisponible';

  @override
  String get adminNotificationAccessMessage =>
      'Ce compte ne peut pas consulter ni envoyer de notifications.';

  @override
  String get adminNotificationDataChanged =>
      'Informations de livraison modifiées';

  @override
  String get adminNotificationDataChangedMessage =>
      'Actualisez avant une autre demande de notification.';

  @override
  String get adminNotificationSecurityMessage =>
      'Aucune information de livraison n’a été affichée. Vérifiez votre connexion.';

  @override
  String get adminNotificationWorkspaceUnavailable =>
      'Espace des notifications indisponible';

  @override
  String get adminNotificationHiddenMessage =>
      'Les informations privées de livraison restent masquées. Réessayez.';

  @override
  String get adminNotificationChecking =>
      'Vérification des informations de livraison';

  @override
  String get adminNotificationCheckingMessage =>
      'Le dernier état confirmé reste affiché pendant la vérification.';

  @override
  String get adminNotificationOutcomeUnconfirmed =>
      'La dernière demande n’est pas confirmée. Les contrôles restent suspendus jusqu’à l’actualisation.';

  @override
  String get adminNotificationLastConfirmed =>
      'Les dernières informations confirmées restent visibles. Les contrôles sont suspendus.';

  @override
  String get adminNotificationValidationTitleBody =>
      'Ajoutez d’abord un titre et un corps de message.';

  @override
  String get adminNotificationValidationTier =>
      'Choisissez d’abord le niveau cible.';

  @override
  String get adminNotificationValidationGroup =>
      'Choisissez d’abord le groupe cible.';

  @override
  String get adminNotificationValidationSchedule =>
      'Choisissez d’abord la date et l’heure de livraison.';

  @override
  String get adminNotificationQueued =>
      'Notification mise en file d’attente pour l’envoi planifié.';

  @override
  String adminNotificationScheduledFor(String date) {
    return 'Notification planifiée pour $date.';
  }

  @override
  String adminNotificationSentSummary(int requested, int sent) {
    return 'Envoyée à $requested supporters. $sent livrées.';
  }

  @override
  String adminNotificationPartialSummary(int sent, int failed) {
    return 'Partiel : $sent livrées, $failed échouées.';
  }

  @override
  String get adminNotificationDeliveryFailed =>
      'Échec de la livraison de la notification.';

  @override
  String get adminNotificationRequestRecorded =>
      'Demande de notification enregistrée.';

  @override
  String adminNotificationHistoryMetrics(int requested, int sent, int failed) {
    return ' • $requested cibles • $sent envoyées • $failed échouées';
  }

  @override
  String get adminNotificationFieldsInvalid =>
      'Vérifiez les champs de notification et réessayez.';

  @override
  String get adminNotificationRequestUnconfirmed =>
      'La demande de notification n’a pas été confirmée.';

  @override
  String get adminNotificationPayloadCopied =>
      'Données copiées dans le presse-papiers.';

  @override
  String get adminNotificationTierNotSelected => 'Niveau non sélectionné';

  @override
  String adminNotificationTierPreview(String tier) {
    return 'Niveau • $tier';
  }

  @override
  String get adminNotificationGroupNotSelected => 'Groupe non sélectionné';

  @override
  String adminNotificationGroupPreview(String group) {
    return 'Groupe • $group';
  }

  @override
  String get adminNotificationAllSupporters => 'Tous les supporters';

  @override
  String get adminNotificationPreview => 'Aperçu';

  @override
  String get adminNotificationPreviewBody =>
      'L’aperçu de votre message apparaît ici.';

  @override
  String get adminNotificationStatusScheduled => 'Planifiée';

  @override
  String get adminNotificationStatusSent => 'Envoyée';

  @override
  String get adminNotificationStatusPartial => 'Partielle';

  @override
  String get adminNotificationStatusFailed => 'Échec';

  @override
  String get adminContributionsTitle => 'Contributions';

  @override
  String get adminContributionsLoading => 'Chargement des contributions';

  @override
  String get adminContributionsLoadingMessage =>
      'Vérification du suivi contrôlé des contributions.';

  @override
  String get adminContributionsDescription =>
      'Consultez les totaux des groupes du club sans exposer les identifiants des supporters ou des paiements.';

  @override
  String get adminContributionsMonthlyTotal => 'Total enregistré ce mois';

  @override
  String adminContributionsSummary(int groups, int records) {
    return '$groups groupes • $records données limitées';
  }

  @override
  String get adminContributionsNoGroups => 'Aucun groupe de contribution';

  @override
  String get adminContributionsNoMatch => 'Aucun groupe correspondant';

  @override
  String get adminContributionsNoGroupsMessage =>
      'Les groupes de contribution confirmés du club apparaîtront ici.';

  @override
  String get adminContributionsNoMatchMessage =>
      'Choisissez un autre filtre de groupe.';

  @override
  String get adminContributionsExport =>
      'Exporter le rapport respectueux de la vie privée';

  @override
  String get adminContributionsReportCopied =>
      'Rapport de contribution respectueux de la vie privée copié.';

  @override
  String get adminContributionsUnavailable =>
      'Suivi des contributions indisponible';

  @override
  String get adminContributionsDisabled =>
      'Le suivi des contributions est désactivé pour cette version contrôlée.';

  @override
  String get adminContributionsOffline => 'Suivi des contributions hors ligne';

  @override
  String get adminContributionsOfflineMessage =>
      'Reconnectez-vous avant de charger les données privées des contributions.';

  @override
  String get adminContributionsAccessUnavailable =>
      'Accès aux contributions indisponible';

  @override
  String get adminContributionsAccessMessage =>
      'Ce compte ne peut pas consulter les opérations privées de contribution.';

  @override
  String get adminContributionsDataChanged =>
      'Données de contribution modifiées';

  @override
  String get adminContributionsDataChangedMessage =>
      'Actualisez avant de vous fier aux totaux de contribution.';

  @override
  String get adminContributionsSecurityMessage =>
      'Aucune donnée de contribution n’a été affichée. Vérifiez votre connexion.';

  @override
  String get adminContributionsHiddenMessage =>
      'Les données privées de contribution restent masquées. Réessayez.';

  @override
  String get adminContributionsRefreshing => 'Actualisation des contributions';

  @override
  String get adminContributionsRefreshingMessage =>
      'Les derniers totaux confirmés restent affichés pendant la vérification.';

  @override
  String get adminContributionsLastConfirmed =>
      'Les derniers totaux confirmés restent visibles. Les contrôles sont suspendus jusqu’à l’actualisation.';

  @override
  String get adminContributionsGroupType => 'Type de groupe';

  @override
  String get adminContributionsSort => 'Trier';

  @override
  String get adminContributionsFilterAll => 'Tous';

  @override
  String get adminContributionsTeamProjects => 'Projets d’équipe';

  @override
  String get adminContributionsCommunity => 'Communauté';

  @override
  String get adminContributionsRecent => 'Récent';

  @override
  String get adminContributionsTotal => 'Total';

  @override
  String get adminContributionsClosed => 'Fermé';

  @override
  String get adminContributionsActive => 'Actif';

  @override
  String get adminContributionsTeamProject => 'Projet d’équipe';

  @override
  String adminContributionsRecordMembers(int records, int members) {
    return '$records données limitées • $members membres inscrits';
  }

  @override
  String get adminContributionsActivityPending =>
      'Activité de paiement en attente';

  @override
  String adminContributionsLastActivity(String date) {
    return 'Dernière activité $date';
  }

  @override
  String get adminSmsTitle => 'Opérations SMS';

  @override
  String get adminSmsLoading => 'Chargement des opérations SMS';

  @override
  String get adminSmsLoadingMessage =>
      'Vérification des informations contrôlées sur l’état du pipeline.';

  @override
  String get adminSmsNoHistory => 'Aucun historique d’opérations SMS';

  @override
  String get adminSmsNoHistoryMessage =>
      'Aucun signal de santé contrôlé ni synchronisation n’est encore disponible.';

  @override
  String get adminSmsControlledHealth => 'Vue de santé contrôlée';

  @override
  String get adminSmsControlledHealthMessage =>
      'Examinez la synchronisation des appareils, les vérifications de messages, la correspondance des contributions, les changements d’expéditeur, les nouvelles tentatives et le nettoyage de confidentialité sans afficher le contenu des messages ni les identifiants des supporters.';

  @override
  String get adminSmsPipelineHealth => 'Santé du pipeline';

  @override
  String get adminSmsRecentSync => 'Synchronisation récente des appareils';

  @override
  String get adminSmsNoRecentRuns => 'Aucune synchronisation récente';

  @override
  String get adminSmsNoRecentRunsMessage =>
      'Le résumé de santé reste disponible ci-dessus.';

  @override
  String adminSmsMetricSemantics(String label, String status) {
    return '$label, $status';
  }

  @override
  String get adminSmsCollapseDetails => 'Réduire les détails de santé';

  @override
  String get adminSmsExpandDetails => 'Développer les détails de santé';

  @override
  String adminSmsLastSignal(String date) {
    return 'Dernier signal confirmé $date';
  }

  @override
  String get adminSmsUnavailable => 'Opérations SMS indisponibles';

  @override
  String get adminSmsDisabled =>
      'Le suivi des opérations SMS est désactivé pour cette version.';

  @override
  String get adminSmsOffline => 'Opérations SMS hors ligne';

  @override
  String get adminSmsOfflineMessage =>
      'Reconnectez-vous avant de charger les informations opérationnelles privées.';

  @override
  String get adminSmsAccessUnavailable =>
      'Accès aux opérations SMS indisponible';

  @override
  String get adminSmsAccessMessage =>
      'Un accès administrateur de plateforme est requis pour cette vue.';

  @override
  String get adminSmsChanged => 'Opérations SMS modifiées';

  @override
  String get adminSmsChangedMessage =>
      'Actualisez avant d’utiliser ces informations opérationnelles.';

  @override
  String get adminSmsSecurityMessage =>
      'Aucune information opérationnelle n’a été affichée. Vérifiez votre connexion.';

  @override
  String get adminSmsHiddenMessage =>
      'Les informations opérationnelles privées restent masquées. Réessayez.';

  @override
  String get adminSmsChecking => 'Vérification des opérations SMS';

  @override
  String get adminSmsCheckingMessage =>
      'Le dernier état confirmé reste affiché pendant la vérification.';

  @override
  String get adminSmsLastConfirmed =>
      'Les dernières informations opérationnelles confirmées restent visibles. Les contrôles sont suspendus.';

  @override
  String get adminSmsStatusHealthy => 'Sain';

  @override
  String get adminSmsStatusSucceeded => 'Réussi';

  @override
  String get adminSmsStatusDegraded => 'Dégradé';

  @override
  String get adminSmsStatusRunning => 'En cours';

  @override
  String get adminSmsStatusRateLimited => 'Débit limité';

  @override
  String get adminSmsStatusFailing => 'En échec';

  @override
  String get adminSmsStatusFailed => 'Échec';

  @override
  String get adminSmsTriggerInitial => 'Historique initial';

  @override
  String get adminSmsTriggerManual => 'Manuel';

  @override
  String get adminSmsTriggerControlled => 'Contrôlé';

  @override
  String adminSmsRunTitle(String status, String trigger) {
    return '$status • $trigger';
  }

  @override
  String adminSmsRunMetrics(int scanned, int uploaded, int duplicates) {
    return '$scanned analysés • $uploaded téléversés • $duplicates doublons';
  }

  @override
  String get adminCmsTitle => 'Gestionnaire de contenu';

  @override
  String get adminCmsDescription =>
      'Gérez les raccourcis d’accueil, les catalogues de partenaires et les compétitions de pronostics prises en charge.';

  @override
  String get adminCmsLoading => 'Chargement du gestionnaire de contenu';

  @override
  String get adminCmsLoadingMessage =>
      'Vérification des travaux de publication actuels.';

  @override
  String get adminCmsNoContent => 'Aucun contenu géré';

  @override
  String get adminCmsNoContentMessage =>
      'Choisissez une section pour créer le premier élément contrôlé.';

  @override
  String get adminCmsUnavailable => 'Gestionnaire de contenu indisponible';

  @override
  String get adminCmsDisabled =>
      'Les contrôles de publication sont désactivés pour cette version contrôlée.';

  @override
  String get adminCmsOffline => 'Gestionnaire de contenu hors ligne';

  @override
  String get adminCmsOfflineMessage =>
      'Reconnectez-vous avant de charger les contrôles de publication privés.';

  @override
  String get adminCmsAccessUnavailable => 'Accès au contenu indisponible';

  @override
  String get adminCmsAccessMessage =>
      'Ce compte ne peut pas consulter ni modifier les données de publication du club.';

  @override
  String get adminCmsChanged => 'Contenu modifié';

  @override
  String get adminCmsChangedMessage =>
      'Actualisez l’espace avant une autre modification.';

  @override
  String get adminCmsSecurityMessage =>
      'Aucun contenu privé n’a été affiché. Vérifiez votre connexion et réessayez.';

  @override
  String get adminCmsHiddenMessage =>
      'Les données privées de publication restent masquées. Réessayez.';

  @override
  String get adminCmsSaving => 'Enregistrement du contenu';

  @override
  String get adminCmsSavingMessage =>
      'Les contrôles de publication sont suspendus jusqu’à la confirmation du résultat.';

  @override
  String get adminCmsRefreshing => 'Actualisation du contenu';

  @override
  String get adminCmsRefreshingMessage =>
      'Le dernier espace confirmé reste affiché pendant la vérification.';

  @override
  String get adminCmsCurrentRefreshUnavailable =>
      'Actualisation actuelle indisponible';

  @override
  String get adminCmsOutcomeUnconfirmed =>
      'La dernière modification n’est pas confirmée. Actualisez avant une autre action.';

  @override
  String get adminCmsLastConfirmed =>
      'Le dernier espace confirmé reste affiché. Les actions sont suspendues jusqu’à l’actualisation.';

  @override
  String get adminCmsChangeOffline =>
      'Les modifications du CMS nécessitent une connexion. Aucune nouvelle tentative n’a été effectuée.';

  @override
  String get adminCmsChangeAccess =>
      'L’accès au CMS n’est plus disponible pour ce compte.';

  @override
  String get adminCmsChangeConflict =>
      'Le contenu du CMS a changé. Actualisez avant une autre action.';

  @override
  String get adminCmsChangeUnconfirmed =>
      'Le résultat n’est pas confirmé. Actualisez avant une autre action.';

  @override
  String get adminCmsChangeFailed =>
      'La modification du CMS n’a pas pu être effectuée. Vérifiez et réessayez.';

  @override
  String get adminCmsAddContentBlock => 'Ajouter un bloc de contenu';

  @override
  String get adminCmsEditContentBlock => 'Modifier le bloc de contenu';

  @override
  String get adminCmsBlockKey => 'Clé du bloc (ex. home_hero_1)';

  @override
  String get adminCmsBlockType => 'Type de bloc (ex. bannière)';

  @override
  String get adminCmsTargetChannel => 'Canal cible';

  @override
  String get adminCmsPlacementKey => 'Emplacement';

  @override
  String get adminCmsTitleField => 'Titre';

  @override
  String get adminCmsSubtitleField => 'Sous-titre';

  @override
  String get adminCmsContentComponent => 'Nom du composant de contenu';

  @override
  String get adminCmsFeatureField => 'Fonctionnalité';

  @override
  String get adminCmsNone => 'Aucune';

  @override
  String get adminCmsSortOrder => 'Ordre de tri';

  @override
  String get adminCmsActive => 'Actif';

  @override
  String get adminCmsCreate => 'Créer';

  @override
  String get adminCmsSave => 'Enregistrer';

  @override
  String get adminCmsNewArticle => 'Nouvel article';

  @override
  String get adminCmsArticleTitle => 'Titre de l’article';

  @override
  String get adminCmsArticleBody => 'Corps de l’article';

  @override
  String get adminCmsAddQuickAction => 'Ajouter une action rapide';

  @override
  String get adminCmsEditQuickAction => 'Modifier l’action rapide';

  @override
  String get adminCmsActionKey => 'Clé de l’action';

  @override
  String get adminCmsRoute => 'Route';

  @override
  String get adminCmsIconKey => 'Clé de l’icône';

  @override
  String get adminCmsEmoji => 'Emoji';

  @override
  String get adminCmsCountry => 'Pays';

  @override
  String get adminCmsAddPartner => 'Ajouter un partenaire';

  @override
  String get adminCmsEditPartner => 'Modifier le partenaire';

  @override
  String get adminCmsName => 'Nom';

  @override
  String get adminCmsSlug => 'Identifiant';

  @override
  String get adminCmsCategory => 'Catégorie';

  @override
  String get adminCmsDescriptionField => 'Description';

  @override
  String get adminCmsGamificationLinked => 'Lié à la ludification';

  @override
  String get adminCmsCreatePartnerFirst => 'Créez d’abord un partenaire.';

  @override
  String get adminCmsAddPartnerService => 'Ajouter un service partenaire';

  @override
  String get adminCmsEditPartnerService => 'Modifier le service partenaire';

  @override
  String get adminCmsPartner => 'Partenaire';

  @override
  String get adminCmsServiceSlug => 'Identifiant du service';

  @override
  String get adminCmsCtaLabel => 'Libellé de l’appel à l’action';

  @override
  String get adminCmsCtaAction => 'Action de l’appel à l’action';

  @override
  String get adminCmsAllCompetitionsAdded =>
      'Toutes les compétitions actives figurent déjà dans le catalogue de pronostics.';

  @override
  String get adminCmsAddPredictionCompetition =>
      'Ajouter une compétition de pronostics';

  @override
  String get adminCmsEditPredictionCompetition =>
      'Modifier la compétition de pronostics';

  @override
  String get adminCmsCompetition => 'Compétition';

  @override
  String get adminCmsHighlightLabel => 'Libellé en vedette';

  @override
  String get adminCmsChannelMobile => 'Mobile';

  @override
  String get adminCmsChannelWeb => 'Web';

  @override
  String get adminCmsChannelBoth => 'Mobile et web';

  @override
  String get adminCmsCategoryOrganization => 'Organisation';

  @override
  String get adminCmsCategoryBank => 'Banque';

  @override
  String get adminCmsCategoryFootball => 'Football';

  @override
  String get adminCmsCategoryGeneral => 'Général';

  @override
  String get adminCmsCategoryCommunity => 'Communauté';

  @override
  String get adminCmsCategoryInsurance => 'Assurance';

  @override
  String get adminCmsCategoryMobility => 'Mobilité';

  @override
  String get adminCmsSectionNews => 'Actualités';

  @override
  String get adminCmsSectionQuickActions => 'Actions rapides';

  @override
  String get adminCmsSectionPartners => 'Partenaires';

  @override
  String get adminCmsSectionServices => 'Services';

  @override
  String get adminCmsSectionPredictions => 'Pronostics';

  @override
  String get adminCmsSectionPlacements => 'Emplacements';

  @override
  String get adminCmsSectionAuditLogs => 'Journaux d’audit';

  @override
  String get adminCmsNewsArticles => 'Articles d’actualité';

  @override
  String get adminCmsAddArticle => 'Ajouter un article';

  @override
  String get adminCmsHomeQuickActions => 'Actions rapides d’accueil';

  @override
  String get adminCmsAddAction => 'Ajouter une action';

  @override
  String get adminCmsPartners => 'Partenaires';

  @override
  String get adminCmsAddPartnerAction => 'Ajouter un partenaire';

  @override
  String get adminCmsPartnerServices => 'Services partenaires';

  @override
  String get adminCmsAddService => 'Ajouter un service';

  @override
  String get adminCmsPredictionCompetitions => 'Compétitions de pronostics';

  @override
  String get adminCmsAddCompetition => 'Ajouter une compétition';

  @override
  String get adminCmsContentBlocks => 'Blocs de contenu de la plateforme';

  @override
  String get adminCmsAddBlock => 'Ajouter un bloc';

  @override
  String get adminCmsAuditLogs =>
      'Journaux d’audit de la gestion des fonctionnalités';

  @override
  String get adminCmsQuickActionFallback => 'Action rapide';

  @override
  String get adminCmsServiceFallback => 'Service';

  @override
  String get adminCmsCompetitionFallback => 'Compétition';

  @override
  String get adminCmsContentBlockFallback => 'Bloc de contenu';

  @override
  String get adminCmsActiveUpper => 'Actif';

  @override
  String get adminCmsInactiveUpper => 'Inactif';

  @override
  String get adminCmsGamificationUpper => 'Ludification';

  @override
  String get adminCmsDirectUpper => 'Direct';

  @override
  String get adminCmsStandardUpper => 'Standard';

  @override
  String get adminCmsDeactivate => 'Désactiver';

  @override
  String get adminCmsActivate => 'Activer';

  @override
  String get adminCmsCtaPending => 'Action en attente';

  @override
  String get adminCmsNotAvailable => 's.o.';

  @override
  String adminCmsCompetitionSummary(String kind, int count) {
    return '$kind • $count rencontres';
  }

  @override
  String get adminCmsCatalog => 'Catalogue';

  @override
  String get adminCmsSupported => 'Prise en charge';

  @override
  String get adminCmsUnknown => 'inconnu';

  @override
  String get adminCmsUnknownFeature => 'Fonctionnalité inconnue';

  @override
  String get adminCmsUnknownDate => 'Date inconnue';

  @override
  String get adminCmsActionFallback => 'Action';

  @override
  String adminCmsFeatureName(String feature) {
    return 'Fonctionnalité : $feature';
  }

  @override
  String get adminCmsActorWithheld =>
      'Les informations sur l’auteur sont masquées dans l’espace mobile.';

  @override
  String get adminCmsEdit => 'Modifier';

  @override
  String get adminCmsUntitled => 'Sans titre';

  @override
  String get adminCmsNewsFallback => 'Actualités';

  @override
  String get adminCmsLive => 'Publié';

  @override
  String get adminCmsDraft => 'Brouillon';

  @override
  String get adminCmsNotPublished => 'Non publié';

  @override
  String get adminCmsFeatured => 'En vedette';

  @override
  String adminCmsArticleMeta(String category, String date, String featured) {
    return '$category • $date$featured';
  }

  @override
  String get adminCmsUnpublish => 'Retirer';

  @override
  String get adminCmsPublish => 'Publier';

  @override
  String adminCmsPair(String first, String second) {
    return '$first • $second';
  }

  @override
  String get gameCommunityPicks => 'Choix de la communauté';

  @override
  String get gameFetProgress => 'Progression FET';

  @override
  String get gameFet => 'FET';

  @override
  String get gameLevelUp => 'Niveau supérieur !';

  @override
  String get gameAwesome => 'Génial';

  @override
  String get gameKeepGoing => 'Continuez';

  @override
  String get gameLive => 'En direct';

  @override
  String gameOutcomePick(String outcome) {
    return 'Choix $outcome';
  }

  @override
  String gamePoints(int count) {
    return '+$count pts';
  }

  @override
  String get gameDaysShort => 'Jours';

  @override
  String get gameHoursShort => 'H';

  @override
  String get gameMinutesShort => 'Min';

  @override
  String get gameSecondsShort => 'Sec';

  @override
  String get gameDismissNotification => 'Fermer la notification';

  @override
  String get gamePredictions => 'Pronostics';

  @override
  String get gameAccuracy => 'Précision';

  @override
  String get gamePointsEarned => 'Points gagnés';

  @override
  String get gameRank => 'Rang';

  @override
  String get gameTopScorers => 'Meilleurs buteurs';

  @override
  String get gameGoals => 'Buts';

  @override
  String get gameEntriesClosed => 'Inscriptions fermées';

  @override
  String get gameEntriesCloseIn => 'Fin des inscriptions dans';

  @override
  String gameFetProgressValue(int current, int maximum, String tier) {
    return '$current sur $maximum, niveau $tier';
  }

  @override
  String gamePickForTeams(String outcome, String home, String away) {
    return 'Choix $outcome pour $home contre $away';
  }

  @override
  String get gameSelectedPick => 'Choix sélectionné';

  @override
  String get gameAddPickToRound => 'Ajouter le choix à la manche';

  @override
  String gameNotificationSemantics(String title, String message) {
    return 'Notification : $title. $message';
  }

  @override
  String get gameDismissNotificationHint =>
      'Touchez ou balayez vers le haut pour fermer';

  @override
  String get gameClubContextRequired => 'Le contexte du club est requis.';

  @override
  String get gameUnexpectedResponse => 'Réponse inattendue du serveur.';

  @override
  String get gameBack => 'Retour';

  @override
  String get gameRetry => 'Réessayer';

  @override
  String get gameOpenPredictionAlert => 'Ouvrir';

  @override
  String get gameBadgesTitle => 'Vos badges';

  @override
  String get gameBadgesUnavailable => 'Badges indisponibles';

  @override
  String get gameBadgesTemporarilyUnavailable =>
      'Les badges sont temporairement indisponibles.';

  @override
  String gameBadgeSemantics(String name) {
    return 'Badge $name';
  }

  @override
  String get gameOpenBadgeDetails => 'Ouvrir les détails du badge';

  @override
  String get gamePredictionAlertsTitle => 'Alertes de pronostics';

  @override
  String get gameAlertsUnavailable => 'Alertes indisponibles';

  @override
  String get gamePredictionAlertsTemporarilyUnavailable =>
      'Les alertes de pronostics sont temporairement indisponibles.';

  @override
  String gamePredictionAlertSemantics(
    String title,
    String message,
    String date,
    String reward,
  ) {
    return 'Alerte de pronostic, $title, $message, $date$reward';
  }

  @override
  String gameRewardPointsSemantics(int count) {
    return ', récompense de $count points';
  }

  @override
  String get gameJustNow => 'À l’instant';

  @override
  String get gameStreakTitle => 'Votre série';

  @override
  String gameStreakDays(int count) {
    return '$count JOURS';
  }

  @override
  String get gameStreakActive => 'Série active.';

  @override
  String get gameCurrent => 'Actuelle';

  @override
  String get gameBest => 'Meilleure';

  @override
  String get gameNextBonus => 'Prochain bonus';

  @override
  String gameWins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count victoires',
      one: '1 victoire',
    );
    return '$_temp0';
  }

  @override
  String gameStreakDaySemantics(int day, String wins) {
    return 'Jour $day de la série : $wins';
  }

  @override
  String get gameVerifyToPredict => 'Vérifiez pour pronostiquer';

  @override
  String get gameMakePicks => 'Faites vos choix';

  @override
  String get gameMakePicksDescription =>
      'Choisissez des rencontres dans toutes les ligues';

  @override
  String get gameEarnPoints => 'Gagnez des points';

  @override
  String get gameEarnPointsDescription =>
      'Gagnez des points avec les bons choix';

  @override
  String get gameClimbLeaderboards => 'Grimpez au classement';

  @override
  String get gameClimbLeaderboardsDescription =>
      'Affrontez vos amis et les supporters';

  @override
  String get gameVerifyNow => 'Vérifier maintenant';

  @override
  String get gameJustBrowsing => 'Je regarde seulement';

  @override
  String get gameOffersTitle => 'Offres';

  @override
  String get gameOffersUnavailable => 'Offres indisponibles';

  @override
  String get gameOffersTemporarilyUnavailable =>
      'Les offres partenaires sont temporairement indisponibles.';

  @override
  String get gameWaysToEarn => 'Comment gagner';

  @override
  String get gameWaysToEarnDescription =>
      'Participez aux campagnes et activations pour gagner des points.';

  @override
  String get gameBalance => 'Solde';

  @override
  String get gameAvailable => 'Disponibles';

  @override
  String gameActiveOffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offres actives',
      one: '1 offre active',
    );
    return '$_temp0';
  }

  @override
  String get gameFeatured => 'En vedette';

  @override
  String get gameMatchDay => 'Jour de match';

  @override
  String get gameAlwaysOn => 'Toujours actives';

  @override
  String get gameReward => 'Récompense';

  @override
  String get gameActivation => 'Activation';

  @override
  String get gameVerification => 'Vérification';

  @override
  String get gameCondition => 'Condition';

  @override
  String get gameClose => 'Fermer';

  @override
  String get gameDetails => 'Détails';

  @override
  String gamePointBalance(int count) {
    return '$count pts';
  }

  @override
  String gameFormattedPoints(String amount) {
    return '$amount pts';
  }

  @override
  String get gameVerificationApi => 'Confirmation par l’API partenaire';

  @override
  String get gameVerificationRenewal => 'Confirmation du renouvellement';

  @override
  String get gameVerificationReferral => 'Conversion du parrainage';

  @override
  String get gameVerificationReceipt => 'Scan du reçu ou du terminal';

  @override
  String get gameVerificationGeo => 'Pointage GPS ou sur le site';

  @override
  String get gameVerificationSocial => 'Vérification de la publication sociale';

  @override
  String get gameVerificationSavings => 'Confirmation du palier d’épargne';

  @override
  String get gameVerificationEcommerce => 'Confirmation de l’achat en boutique';

  @override
  String get gameVerificationMobility => 'Confirmation de la course terminée';

  @override
  String get gameVerificationEventQr => 'Validation du code QR de l’événement';

  @override
  String get gameVerificationManual => 'Vérification manuelle du partenaire';

  @override
  String get gameSettingsUpper => 'Paramètres';

  @override
  String get gamePrivacyUpper => 'Confidentialité';

  @override
  String get gameCoreGuarantees => 'Garanties essentielles';

  @override
  String get gamePhoneNumberHidden => 'Numéro de téléphone masqué';

  @override
  String get gamePhoneNumberHiddenDescription =>
      'Votre numéro WhatsApp ou de téléphone est chiffré et stocké uniquement sur le serveur. Il n’est jamais révélé aux autres utilisateurs, aux administrateurs du club ou dans les classements publics.';

  @override
  String get gameAnonymousContributions => 'Contributions anonymes';

  @override
  String get gameAnonymousContributionsDescription =>
      'Les contributions MoMo aux fan-clubs sont enregistrées uniquement avec votre Fan ID et une tranche de montant. Les montants exacts et les numéros de téléphone ne sont pas enregistrés.';

  @override
  String get gameVisibilityControls => 'Contrôles de visibilité';

  @override
  String get gameShowRealName => 'Afficher le nom réel';

  @override
  String get gameShowRealNameDescription =>
      'Lorsque cette option est désactivée, votre Fan ID apparaît dans les classements à la place de votre vrai nom.';

  @override
  String get gameFindableByPhone => 'Recherche par téléphone';

  @override
  String get gameFindableByPhoneDescription =>
      'Permet à vos amis de vous trouver par numéro de téléphone. Votre numéro reste privé.';

  @override
  String get gamePrivacyFirst => 'Confidentialité prioritaire';

  @override
  String gamePrivacyFirstDescription(String appName) {
    return '$appName ne vend, ne partage et n’expose pas vos données personnelles. Tous les identifiants de la plateforme sont anonymisés.';
  }

  @override
  String get gameRewardsStoreTitle => 'Boutique de récompenses';

  @override
  String get gameRewardsUnavailable => 'Récompenses indisponibles';

  @override
  String get gameRewardsTemporarilyUnavailable =>
      'Les récompenses sont temporairement indisponibles.';

  @override
  String get gameAvailableBalance => 'Solde disponible';

  @override
  String gameRewardsStoreDescription(String appName) {
    return 'Échangez les récompenses $appName sans quitter le portefeuille unifié.';
  }

  @override
  String gameRewardMeta(String category, String notes) {
    return '$category · $notes';
  }

  @override
  String gameRedeemCost(String cost) {
    return 'Échanger $cost';
  }

  @override
  String gameNeedCost(String cost) {
    return 'Requiert $cost';
  }

  @override
  String get gameRewardConfigurationMissing =>
      'La configuration de la récompense est absente. Réessayez plus tard.';

  @override
  String get gameRewardAlreadyRedeemed =>
      'Cet échange de récompense a déjà été effectué.';

  @override
  String gameRewardRedeemed(String reward, String cost) {
    return '$reward échangé contre $cost.';
  }

  @override
  String get gameRewardCouldNotRedeem =>
      'Impossible d’échanger cette récompense.';

  @override
  String get gameFriendsTitle => 'Amis';

  @override
  String get gameSupportersUnavailable => 'Supporters indisponibles';

  @override
  String get gameSupportersTemporarilyUnavailable =>
      'Les supporters sont temporairement indisponibles.';

  @override
  String get gameSearchSupporterHint =>
      'Rechercher un pseudo ou un identifiant';

  @override
  String get gameDone => 'Terminé.';

  @override
  String get gameResults => 'Résultats';

  @override
  String get gameYourFriends => 'Vos amis';

  @override
  String get gameChallenge => 'Défier';

  @override
  String get gameAccept => 'Accepter';

  @override
  String get gamePending => 'En attente';

  @override
  String get gameAdd => 'Ajouter';

  @override
  String get gameOnline => 'En ligne';

  @override
  String get gameFixturesTitle => 'Rencontres';

  @override
  String get gameFixturesUnavailable => 'Rencontres indisponibles';

  @override
  String get gameFixturesCouldNotLoad =>
      'Impossible de charger les rencontres pour le moment.';

  @override
  String get gameAll => 'Toutes';

  @override
  String get gameToday => 'Aujourd’hui';

  @override
  String get gameTomorrow => 'Demain';

  @override
  String get gameYesterday => 'Hier';

  @override
  String gameRelativeDate(String relative, String date) {
    return '$relative · $date';
  }

  @override
  String gameMatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rencontres',
      one: '1 rencontre',
    );
    return '$_temp0';
  }

  @override
  String get gameMyActivity => 'Mon activité';

  @override
  String gameActiveCount(int count) {
    return 'ACTIFS ($count)';
  }

  @override
  String gameSettledTabCount(int count) {
    return 'RÉGLÉS ($count)';
  }

  @override
  String gameHistoryCount(int count) {
    return 'HISTORIQUE ($count)';
  }

  @override
  String get gameActivityUnavailable => 'Activité indisponible';

  @override
  String get gameActivityCouldNotLoad =>
      'Impossible de charger votre activité pour le moment.';

  @override
  String get gameCouldNotCancelPick => 'Impossible d’annuler ce choix.';

  @override
  String get gameWon => 'Gagné';

  @override
  String get gameLost => 'Perdu';

  @override
  String get gameCancelled => 'Annulé';

  @override
  String get gameVoid => 'Invalidé';

  @override
  String get gamePendingUpper => 'En attente';

  @override
  String get gameTbd => 'À définir';

  @override
  String gameVersusShort(String home, String away) {
    return '$home c. $away';
  }

  @override
  String get gameRound => 'Manche';

  @override
  String gameCompetitionTime(String competition, String time) {
    return '$competition • $time';
  }

  @override
  String get gameCancel => 'Annuler';

  @override
  String gameActivitySemantics(String home, String away) {
    return 'Activité $home contre $away';
  }

  @override
  String get gameOpenActivityDetail => 'Ouvrir le détail de l’activité';

  @override
  String get gameNotificationsUpper => 'Notifications';

  @override
  String get gameKickoffAlerts => 'Alertes de coup d’envoi';

  @override
  String get gameRoundResults => 'Résultats de la manche';

  @override
  String get gameFriendChallenges => 'Défis entre amis';

  @override
  String get gameLineupsUpper => 'Compositions';

  @override
  String get gameSubstitutes => 'Remplaçants';

  @override
  String get gameActiveUpper => 'Actifs';

  @override
  String get gameWinRate => 'Taux de victoire';

  @override
  String get gameYouUpper => 'Vous';

  @override
  String gameWalletSignedPoints(String sign, String amount) {
    return '$sign$amount pts';
  }

  @override
  String gameWalletBalance(String amount) {
    return 'Solde $amount pts';
  }

  @override
  String get gameVersus => 'Contre';

  @override
  String get gameKickoffSoon => 'Coup d’envoi imminent';

  @override
  String gameJoinedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '1 participant',
    );
    return '$_temp0';
  }

  @override
  String gameTotalPoolPoints(int count) {
    return '$count pts au total';
  }

  @override
  String get gameCreator => 'Créateur';

  @override
  String get gameMyPick => 'Mon choix';

  @override
  String get gameOpenUpper => 'Ouvert';

  @override
  String get gameLockedUpper => 'Verrouillé';

  @override
  String get gameSettledUpper => 'Réglé';

  @override
  String gameDaysLeft(int count) {
    return '$count j restants';
  }

  @override
  String gameHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String gameMinutesLeft(int count) {
    return '$count min restantes';
  }

  @override
  String gameScorePrediction(String label, int home, int away) {
    return '$label  $home-$away';
  }

  @override
  String get gamePointsShare => 'Répartition des points';

  @override
  String get gamePointsShareDescription =>
      'Les règles du niveau déterminent comment les points gagnés vous soutiennent et alimentent les récompenses collectives du club.';

  @override
  String gamePersonalPercentage(int count) {
    return '$count% pour vous';
  }

  @override
  String gameClubPercentage(int count) {
    return '$count% pour le club';
  }

  @override
  String gameTierSplit(int personal, int club) {
    return '$personal/$club';
  }

  @override
  String get gamePointsShareExplanation =>
      'Vos points sont répartis selon le niveau : la part personnelle vous revient et la part du club soutient les récompenses collectives.';

  @override
  String get gameTierSupporter => 'Supporter';

  @override
  String get gameTierMember => 'Membre';

  @override
  String get gameTierUltra => 'Ultra';

  @override
  String get gameTierLegend => 'Légende';

  @override
  String get gameFree => 'Gratuit';

  @override
  String gameMonthlyPrice(String amount) {
    return '$amount RWF / mois';
  }

  @override
  String gameShareTitle(String appName) {
    return 'Choix $appName';
  }

  @override
  String get gameShareCopied =>
      'Texte de partage copié dans le presse-papiers.';

  @override
  String gameShareStatusLine(String status, String home, String away) {
    return '$status : $home c. $away';
  }

  @override
  String gameFinalScore(int home, int away) {
    return 'Score final : $home-$away';
  }

  @override
  String gameMarketSelection(String market, String selection) {
    return '$market : $selection';
  }

  @override
  String gameEarnedShare(int count) {
    return 'Gagné : +$count pts';
  }

  @override
  String gamePotentialShare(int count) {
    return 'Potentiel : +$count pts';
  }

  @override
  String get gameMarketUpper => 'Marché';

  @override
  String get gamePickUpper => 'Choix';

  @override
  String get gameEarnedUpper => 'Gagné';

  @override
  String get gamePotentialUpper => 'Potentiel';

  @override
  String gameShareTagline(String appName) {
    return '$appName · JOUEZ. CHOISISSEZ. GAGNEZ.';
  }

  @override
  String gamePickTypeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count types de choix',
      one: '1 type de choix',
    );
    return '$_temp0';
  }

  @override
  String get gameSearchPickTypes => 'Rechercher des types de choix';

  @override
  String get gameClearSearch => 'Effacer la recherche';

  @override
  String get gameAddPicksToUnlock =>
      'Ajoutez des choix pour déverrouiller la manche';

  @override
  String gameOpenRoundSummary(int count, int points) {
    return 'Ouvrir la manche · $count choix · $points pts';
  }

  @override
  String get gameLiveOnly => 'En direct uniquement';

  @override
  String gameOutcomeAddedToRound(String outcome) {
    return '$outcome ajouté à votre manche.';
  }

  @override
  String get gameMarkets => 'Marchés';

  @override
  String gameMarketCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count marchés',
      one: '1 marché',
    );
    return '$_temp0';
  }

  @override
  String get gameStatsNotAvailableYet => 'Statistiques pas encore disponibles';

  @override
  String get gameLiveStatsUpdating =>
      'Les statistiques en direct se mettent à jour automatiquement pendant le match.';

  @override
  String get gameLiveMatchDataUpdating =>
      'Les données du centre de match se mettent à jour pour cette rencontre.';

  @override
  String get gameStructuredMatchStats =>
      'Statistiques structurées du centre de match pour cette rencontre.';

  @override
  String get gameTotalGoals => 'Total des buts';

  @override
  String get gameFinalMatchStats => 'Statistiques finales du match.';

  @override
  String gameFixtureMarketTitle(String home, String away, String market) {
    return '$home c. $away · $market';
  }

  @override
  String get gamePickTypeLocked =>
      'Type de choix verrouillé pour l’état actuel de cette rencontre.';

  @override
  String get gameLeaderboardTitle => 'Classement';

  @override
  String get gameFetRanking => 'Classement FET';

  @override
  String get gameSupporters => 'Supporters';

  @override
  String get gameAllTime => 'Depuis toujours';

  @override
  String get gameWeekly => 'Hebdomadaire';

  @override
  String get gameMonthly => 'Mensuel';

  @override
  String get gameLeaderboardUnavailable => 'Classement indisponible';

  @override
  String get gameLeaderboardTemporarilyUnavailable =>
      'Le classement est temporairement indisponible.';

  @override
  String get gameRankingsUnavailable => 'Classements indisponibles';

  @override
  String get gameSupporterRankingsTemporarilyUnavailable =>
      'Les classements des supporters sont temporairement indisponibles.';

  @override
  String get gameNotSignedIn => 'Non connecté';

  @override
  String get gameTierFan => 'Supporter';

  @override
  String get gameDisplayNameOn => 'Nom affiché';

  @override
  String get gameAliasOnly => 'Alias uniquement';

  @override
  String gameDisplayNameOnDescription(String name) {
    return 'Les classements peuvent afficher $name au lieu de votre seul Fan ID.';
  }

  @override
  String get gameAliasOnlyDescription =>
      'Les classements affichent votre Fan ID ou votre alias au lieu de votre vrai nom.';

  @override
  String get gamePhoneHidden => 'Téléphone masqué';

  @override
  String get gamePhoneHiddenDescription =>
      'Votre numéro de téléphone reste sur le serveur et n’est jamais montré aux autres supporters ou aux administrateurs du club.';

  @override
  String get gamePhoneDiscoveryOn => 'Recherche par téléphone active';

  @override
  String get gamePhoneDiscoveryOff => 'Recherche par téléphone inactive';

  @override
  String get gamePhoneDiscoveryOnDescription =>
      'Les amis qui connaissent déjà votre numéro peuvent trouver votre profil.';

  @override
  String get gamePhoneDiscoveryOffDescription =>
      'La recherche par téléphone est actuellement désactivée sur votre profil.';

  @override
  String get gameVerified => 'Vérifié';

  @override
  String get gameVerificationPending => 'Vérification en attente';

  @override
  String gameVerifiedDescription(String appName) {
    return 'Votre identité téléphonique est vérifiée pour les parcours sociaux et de gains de $appName.';
  }

  @override
  String gameVerificationPendingDescription(String appName) {
    return 'Vérifiez votre téléphone pour débloquer toute l’expérience sociale $appName.';
  }

  @override
  String get gameFanIdPersistentRule =>
      'Votre Fan ID provient de votre profil et reste identique à votre retour.';

  @override
  String gameDisplayNameVisibleRule(String name) {
    return 'Votre nom d’affichage « $name » peut apparaître dans les classements jusqu’à sa désactivation.';
  }

  @override
  String get gameRealNameHiddenRule =>
      'Votre vrai nom reste masqué dans les classements jusqu’à ce que vous activiez explicitement sa visibilité.';

  @override
  String get gamePhoneEncryptedRule =>
      'Votre numéro de téléphone est chiffré et stocké uniquement sur le serveur.';

  @override
  String get gamePhoneDiscoveryEnabledRule =>
      'La recherche d’amis par téléphone est actuellement activée sur votre compte.';

  @override
  String get gamePhoneDiscoveryDisabledRule =>
      'La recherche d’amis par téléphone est actuellement désactivée sur votre compte.';

  @override
  String gamePhoneVerifiedRule(String appName) {
    return 'Votre identité téléphonique est vérifiée pour les fonctionnalités et récompenses $appName.';
  }

  @override
  String gamePhonePendingRule(String appName) {
    return 'La vérification du téléphone est encore en attente pour votre profil $appName.';
  }

  @override
  String gameTeamLinkedRule(String team) {
    return 'Votre profil est associé à $team pour la personnalisation.';
  }

  @override
  String get gameLinkTeamRule =>
      'Vous pouvez associer une équipe favorite pendant l’accueil ou dans votre profil.';

  @override
  String get gameDeleteAccountRule =>
      'La suppression de votre compte efface vos données personnelles et l’association du Fan ID du profil actif.';

  @override
  String get gameFanIdTitle => 'Fan id';

  @override
  String get gameYourFanId => 'Votre fan id';

  @override
  String get gameAliasOnlyProfile => 'Profil avec alias uniquement';

  @override
  String get gameFanIdCopied => 'Fan ID copié dans le presse-papiers.';

  @override
  String get gameCopyToClipboard => 'Copier dans le presse-papiers';

  @override
  String get gamePrivacyBadges => 'Badges de confidentialité';

  @override
  String get gameIdentityRules => 'Règles d’identité';

  @override
  String get gameIdentityRulesDescription =>
      'Fonctionnement de votre Fan ID selon les paramètres actuels de votre profil.';

  @override
  String get gameStandingsTitle => 'Classement';

  @override
  String get gameCompetitionNotFound => 'Compétition introuvable.';

  @override
  String get gameStandingsTemporarilyUnavailable =>
      'Le classement est temporairement indisponible.';

  @override
  String get gameStandingsUnavailable => 'Classement indisponible';

  @override
  String get gamePositionShort => 'Pos';

  @override
  String get gameTeamUpper => 'Équipe';

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
    return '${played}J · $goalsFor:$goalsAgainst · DB $difference';
  }

  @override
  String get gameHeadToHead => 'Face à face';

  @override
  String gameHeadToHeadEmpty(String home, String away) {
    return 'L’historique des confrontations entre $home et $away apparaîtra ici.';
  }

  @override
  String get gameWinDistribution => 'Répartition des victoires';

  @override
  String get gameDraws => 'Nuls';

  @override
  String gameTeamGoals(String team) {
    return 'BUTS $team';
  }

  @override
  String get gameRecentEncounters => 'Confrontations récentes';

  @override
  String gameScore(int home, int away) {
    return '$home - $away';
  }

  @override
  String get gameTokenHistoryTitle => 'Historique des jetons';

  @override
  String get gameTokenHistoryTemporarilyUnavailable =>
      'L’historique des jetons est temporairement indisponible.';

  @override
  String get gameHistoryUnavailable => 'Historique indisponible';

  @override
  String get gameEarned => 'Gagné';

  @override
  String get gameSpent => 'Dépensé';

  @override
  String get gameAllUpper => 'Tous';

  @override
  String get gameEarnedUpperFilter => 'Gagnés';

  @override
  String get gameSpentUpper => 'Dépensés';

  @override
  String get gameCredit => 'Crédit';

  @override
  String get gameDebit => 'Débit';

  @override
  String get gameLedgerUpdate => 'Mise à jour du registre';

  @override
  String gameTransactionSemantics(
    String direction,
    String headline,
    String detail,
    int amount,
    int balance,
    String date,
  ) {
    return 'Transaction de $direction, $headline, $detail, $amount points, solde de $balance points, $date';
  }

  @override
  String get gameUnknownTime => 'Heure inconnue';

  @override
  String get gameClubFanZoneTitle => 'Zone supporters du club';

  @override
  String get gameClubFanZoneTemporarilyUnavailable =>
      'La zone supporters du club est temporairement indisponible.';

  @override
  String get gameFanZoneUnavailable => 'Zone supporters indisponible';

  @override
  String get gameSupporterPulse => 'Dynamique des supporters';

  @override
  String get gameSupporterPulseDescription =>
      'La dynamique réelle des supporters autour des compétitions actives, des choix de rencontres et des meilleurs clubs.';

  @override
  String get gameTopClubs => 'Meilleurs clubs';

  @override
  String gameRankHash(int rank) {
    return 'Nº $rank';
  }

  @override
  String get gameSupporterLeans => 'Tendances des supporters';

  @override
  String gameSupporterLeansEmpty(String appName) {
    return 'La répartition des choix de la communauté apparaîtra lorsque cette compétition aura des pronostics $appName actifs.';
  }

  @override
  String gamePair(String first, String second) {
    return '$first · $second';
  }

  @override
  String gameSupporterLeanPercentage(String percentage) {
    return '$percentage% des supporters penchent actuellement dans ce sens.';
  }

  @override
  String get gameLeagueHubTitle => 'Centre de la ligue';

  @override
  String get gameLeagueDataTemporarilyUnavailable =>
      'Les données de la ligue sont temporairement indisponibles.';

  @override
  String get gameLeagueUnavailable => 'Ligue indisponible';

  @override
  String get gameCompetition => 'Compétition';

  @override
  String get gameRegion => 'Région';

  @override
  String get gameLeague => 'Ligue';

  @override
  String get gameTeams => 'Équipes';

  @override
  String get gameFixtures => 'Rencontres';

  @override
  String get gameLeader => 'Leader';

  @override
  String get gameTopTable => 'Haut du tableau';

  @override
  String get gameFullStandings => 'Classement complet';

  @override
  String gameLeagueStandingRecord(int played, int won, int drawn, int lost) {
    return '${played}J · ${won}G ${drawn}N ${lost}P';
  }

  @override
  String get gameEntrySubmitted => 'Participation envoyée';

  @override
  String get gameBonusEntryLive =>
      'Votre participation bonus est maintenant active.';

  @override
  String get gameCouldNotSubmitBonus =>
      'Impossible d’envoyer la participation bonus pour le moment.';

  @override
  String get gameKickoffTbd => 'Coup d’envoi à définir';

  @override
  String get gameBonusRound => 'Manche bonus';

  @override
  String get gameSubmitting => 'Envoi…';

  @override
  String get gameEntriesClosedSentence => 'Participations fermées';

  @override
  String get gameSubmitEntry => 'Envoyer la participation';

  @override
  String get gameBonusRoundActivationPending =>
      'L’activation de la manche bonus est en attente.';

  @override
  String get gameBonusRoundTemporarilyUnavailable =>
      'La manche bonus est temporairement indisponible.';

  @override
  String get gameBonusRoundUnavailable => 'Manche bonus indisponible';

  @override
  String get gamePointsPool => 'Réserve de points';

  @override
  String get gamePickAllFeatured =>
      'Choisissez chaque rencontre en vedette avant le verrouillage de la manche.';

  @override
  String gamePicksComplete(int selected, int total) {
    return '$selected choix sur $total terminés';
  }

  @override
  String gameEntriesRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participations restantes',
      one: '1 participation restante',
    );
    return '$_temp0';
  }

  @override
  String get gameLeaders => 'Leaders';

  @override
  String get gameSocialHub => 'Espace social';

  @override
  String get gameClub => 'Club';

  @override
  String get gameSearchYourFriends => 'Rechercher vos amis';

  @override
  String get gameBrowse => 'Parcourir';

  @override
  String get gameViewAll => 'Tout voir';

  @override
  String get gameClubStandingsTemporarilyUnavailable =>
      'Le classement du club est temporairement indisponible.';

  @override
  String get gameClubStandingsUnavailable => 'Classement du club indisponible';

  @override
  String get gameClubStanding => 'Classement dans le club';

  @override
  String get gameUnranked => 'Non classé';

  @override
  String get gameEarnPointsForClubTable =>
      'Gagnez des points pour apparaître dans le classement du club.';

  @override
  String gamePointsEarnedSoFar(int count) {
    return '$count pts gagnés jusqu’ici.';
  }

  @override
  String gameNameYou(String name) {
    return '$name (Vous)';
  }

  @override
  String get gameChallengeFlowTemporarilyUnavailable =>
      'Le parcours de défi est temporairement indisponible.';

  @override
  String gameHeadToHeadMessage(String appName, String home, String away) {
    return 'Face-à-face $appName sur $home c. $away';
  }

  @override
  String get gameChallengeSent => 'Défi envoyé';

  @override
  String get gameChallengeWaiting => 'Votre défi attend une réponse.';

  @override
  String get gameCouldNotSendChallenge =>
      'Impossible d’envoyer le défi pour le moment.';

  @override
  String get gameSending => 'Envoi…';

  @override
  String get gameSendChallenge => 'Envoyer le défi';

  @override
  String get gameChallengeUnavailable => 'Défi indisponible';

  @override
  String get gameSupporter => 'Supporter';

  @override
  String get gameAddFriendsBeforeChallenge =>
      'Ajoutez des amis avant d’envoyer un défi.';

  @override
  String get gameFindFriends => 'Trouver des amis';

  @override
  String get gameFixture => 'Rencontre';

  @override
  String get gamePick => 'Choix';

  @override
  String get gameSelected => 'Sélectionné';

  @override
  String get gameChoose => 'Choisir';

  @override
  String get gameTeamNotFound => 'Équipe introuvable.';

  @override
  String get gameTeamProfileTemporarilyUnavailable =>
      'Le profil de l’équipe est temporairement indisponible.';

  @override
  String get gameSupporterActivityActiveClubOnly =>
      'L’activité des supporters est disponible uniquement pour le club actif.';

  @override
  String get gameSupporterRoutingCurrentClubOnly =>
      'Le registre des supporters et l’acheminement des contributions sont disponibles uniquement pour le club actuel de l’application.';

  @override
  String get gameContributionRouteNotPublished =>
      'Ce club n’a pas encore publié de parcours de contribution actif.';

  @override
  String get gameClubSupporterDataUnavailable =>
      'Les données des supporters du club sont temporairement indisponibles.';

  @override
  String get gameContributionsActiveClubOnly =>
      'Les contributions sont disponibles uniquement pour le club actif.';

  @override
  String get gameContributionRouteUnavailable =>
      'Parcours de contribution indisponible.';

  @override
  String get gameCouldNotOpenDialer =>
      'Impossible d’ouvrir le composeur téléphonique.';

  @override
  String get gameDialerLaunchFailed => 'Échec du lancement du composeur.';

  @override
  String get gameEnterContributionAmount =>
      'Saisissez le montant de la contribution';

  @override
  String gamePaymentRouteDescription(String recipient, String provider) {
    return 'Vous paierez $recipient via $provider.';
  }

  @override
  String gameAmountCurrency(String currency) {
    return 'Montant ($currency)';
  }

  @override
  String get gameDialNow => 'Composer maintenant';

  @override
  String get gameEnterValidAmount => 'Saisissez un montant valide.';

  @override
  String get gameTeamProfileTitle => 'Profil de l’équipe';

  @override
  String get gameTeamUnavailable => 'Équipe indisponible';

  @override
  String gameFoundedYear(int year) {
    return 'Fondé en $year';
  }

  @override
  String get gameTable => 'Classement';

  @override
  String get gameSquad => 'Effectif';

  @override
  String get gameOverview => 'Aperçu';

  @override
  String get gameMembers => 'Membres';

  @override
  String get gameContribute => 'Contribuer';

  @override
  String get gameAbout => 'À propos';

  @override
  String get gameLeaguePosition => 'Position dans la ligue';

  @override
  String get gamePlayedShort => 'J';

  @override
  String get gameWonShort => 'G';

  @override
  String get gameDrawnShort => 'N';

  @override
  String get gameLostShort => 'P';

  @override
  String get gameGoalDifferenceShort => 'Db';

  @override
  String get gameMomoContributionRoute => 'Parcours de contribution MoMo';

  @override
  String gameUseProviderForClub(String provider, String club) {
    return 'Utilisez $provider pour contribuer à $club.';
  }

  @override
  String get gameThisClub => 'ce club';

  @override
  String get gameSupporterRegistryCurrentClubOnly =>
      'Le registre des supporters est disponible uniquement pour le club actuel de l’application.';

  @override
  String get gameMembersUnavailable => 'Membres indisponibles';

  @override
  String get gameClubMembers => 'Membres du club';

  @override
  String get gameTierGold => 'Or';

  @override
  String get gameTierSilver => 'Argent';

  @override
  String get gameTierBronze => 'Bronze';

  @override
  String get gameTierImena => 'Imena';

  @override
  String get gameTopContributors => 'Meilleurs contributeurs';

  @override
  String get gameMomoContribution => 'Contribution MoMo';

  @override
  String gameUseProviderInCountry(String provider, String country) {
    return 'Utilisez $provider en $country pour contribuer à ce club.';
  }

  @override
  String get gameEnterAmount => 'Saisir le montant';

  @override
  String gameEnterAmountDescription(String provider) {
    return 'Choisissez le montant à envoyer via $provider.';
  }

  @override
  String get gameConfirmInDialer => 'Confirmer dans le composeur';

  @override
  String gameConfirmInDialerDescription(String code) {
    return 'Nous ouvrirons le composeur mobile money pour le code $code.';
  }

  @override
  String get gameReconciliation => 'Rapprochement';

  @override
  String get gameReconciliationDescription =>
      'Votre contribution est rapprochée de l’activité de votre club après confirmation du paiement.';

  @override
  String get gameOpeningDialer => 'Ouverture du composeur…';

  @override
  String get gameEnterAmountAndDial => 'Saisir le montant et composer';

  @override
  String gameAboutTeam(String team) {
    return 'À PROPOS DE $team';
  }

  @override
  String get gameThisClubUpper => 'Ce club';

  @override
  String get gameLocation => 'Lieu';

  @override
  String get gameCountry => 'Pays';

  @override
  String get gameFounded => 'Fondé';

  @override
  String get gameType => 'Type';

  @override
  String get gameAffiliatedClub => 'Club affilié';

  @override
  String get gameSelectedLeaderboardPeriod =>
      'Période du classement sélectionnée';

  @override
  String get gameSelectPeriod => 'Sélectionner la période';

  @override
  String gameRankLabel(String rank) {
    return 'Nº $rank';
  }

  @override
  String get gameRankPending => 'Classement en attente';

  @override
  String gameAccuracyWins(String accuracy, int wins) {
    String _temp0 = intl.Intl.pluralLogic(
      wins,
      locale: localeName,
      other: '$wins victoires',
      one: '1 victoire',
    );
    return '$accuracy% de précision · $_temp0';
  }

  @override
  String gameSettledCount(int count) {
    return '$count réglés';
  }

  @override
  String gameTierAlias(String tier, String alias) {
    return 'Niveau $tier · $alias';
  }

  @override
  String gamePodiumRank(int rank) {
    return 'Rang de podium $rank';
  }

  @override
  String get gamePickRound => 'Manche de choix';

  @override
  String gameActivePicks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count choix actifs',
      one: '1 choix actif',
    );
    return '$_temp0';
  }

  @override
  String gameEarnUpToPoints(int count) {
    return 'Gagnez jusqu’à $count pts';
  }

  @override
  String get gamePickRoundEmpty => 'La manche de choix est vide';

  @override
  String get gamePickRoundEmptyDescription =>
      'Ajoutez des choix depuis une rencontre et verrouillez-les ici.';

  @override
  String get gamePickRoundUpper => 'Manche de choix';

  @override
  String get gameAcca => 'Combiné';

  @override
  String gamePotentialPoints(int count) {
    return 'Points potentiels : $count pts';
  }

  @override
  String get gameLockInPicks => 'Verrouiller les choix';

  @override
  String get gameSomeSelectionsFailed =>
      'Certains choix n’ont pas pu être envoyés.';

  @override
  String get gameCouldNotSubmitPicks => 'Impossible d’envoyer vos choix.';

  @override
  String get gameConfirmPicks => 'Confirmer les choix';

  @override
  String gameLockingCombo(int count) {
    return 'Vous verrouillez $count choix en combiné.';
  }

  @override
  String gameLockingPicks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vous verrouillez $count choix.',
      one: 'Vous verrouillez 1 choix.',
    );
    return '$_temp0';
  }

  @override
  String gameOutcomePotential(String outcome, int count) {
    return '$outcome · +$count pts';
  }

  @override
  String get gameTotalPotential => 'Potentiel total';

  @override
  String get gameGoBack => 'Retour';

  @override
  String gamePredictionsLocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pronostics verrouillés',
      one: 'Pronostic verrouillé',
    );
    return '$_temp0';
  }

  @override
  String gameRoundId(String id) {
    return 'ID de la manche : $id';
  }

  @override
  String get gameShareUpper => 'Partager';

  @override
  String get gameCopyUpper => 'Copier';

  @override
  String get gameViewMyPredictions => 'Voir mes pronostics';

  @override
  String get gameKeepBrowsing => 'Continuer à parcourir';

  @override
  String get gameRemovePick => 'Retirer le choix';

  @override
  String get gameFans => 'Supporters';

  @override
  String get gameWallet => 'Portefeuille';

  @override
  String get gameMore => 'Plus';

  @override
  String get gameRoundUpper => 'Manche';

  @override
  String gameAccuracyRounds(String accuracy, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count manches',
      one: '1 manche',
    );
    return '$accuracy% · $_temp0';
  }

  @override
  String gamePointsRound(int count) {
    return 'Manche de $count points';
  }

  @override
  String get gamePointsRoundLabel => 'points par manche';

  @override
  String gamePointEntry(int count) {
    return 'Participation de $count point';
  }

  @override
  String gameFansCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count supporters',
      one: '1 supporter',
    );
    return '$_temp0';
  }

  @override
  String get gameChooseWdw => 'Choisir G/N/G';

  @override
  String get gameJoinRound => 'Rejoindre la manche';

  @override
  String gameSelectedOutcome(String outcome) {
    return '$outcome sélectionné';
  }

  @override
  String get gameChallengesTitle => 'Défis';

  @override
  String get gameChallengesTemporarilyUnavailable =>
      'Les défis sont temporairement indisponibles.';

  @override
  String get gameChallengesUnavailable => 'Défis indisponibles';

  @override
  String get gameDaily => 'Quotidiens';

  @override
  String get gameWeeklyUpper => 'Hebdomadaires';

  @override
  String get gameSeasonal => 'Saisonniers';

  @override
  String get gameCompleted => 'Terminé';

  @override
  String get gameChallengesRequireProfile =>
      'Les défis apparaissent lorsque votre profil de supporter est actif.';

  @override
  String get gameWhatIsFet => 'Qu’est-ce que FET ?';

  @override
  String get gameWhatIsFetBody =>
      'Les FET (jetons d’engagement des supporters) sont votre monnaie de supporter. Gagnez-les en participant à la vie du club : matchs, défis, pronostics et soutien à la communauté.';

  @override
  String get gameHowPredictionsWork => 'Fonctionnement des pronostics';

  @override
  String get gameHowPredictionsWorkBody =>
      'Parcourez les rencontres, choisissez un type de pronostic, puis verrouillez vos choix avant le coup d’envoi. Les bons choix rapportent des points selon leur difficulté.';

  @override
  String get gameEarnLevelRedeem => 'Gagnez, progressez et échangez';

  @override
  String get gameEarnLevelRedeemBody =>
      'Votre solde augmente avec votre engagement. Grimpez au classement, débloquez des niveaux d’adhésion et échangez des récompenses dans la boutique du club.';

  @override
  String get gameBackUpper => 'Retour';

  @override
  String get gameGetStarted => 'Commencer';

  @override
  String get gameNext => 'Suivant';

  @override
  String get gameMyChallenges => 'Mes défis';

  @override
  String get gameOpen => 'Ouverts';

  @override
  String get gameLocked => 'Verrouillés';

  @override
  String get gameSettled => 'Réglés';

  @override
  String get gameRefunded => 'Remboursés';

  @override
  String get gameLoadingChallenges => 'Chargement de vos défis';

  @override
  String get gameLoadingChallengesDescription =>
      'Vérification des pools créés ou rejoints pour ce statut.';

  @override
  String get gameRefresh => 'Actualiser';

  @override
  String get gameRefreshingChallengeHistory =>
      'Actualisation de l’historique des défis';

  @override
  String get gameRefreshingChallengeHistoryDescription =>
      'Vos pools confirmés restent visibles pendant la vérification du statut récent.';

  @override
  String get gameChallengeHistoryReadOnly =>
      'L’historique des défis est en lecture seule';

  @override
  String get gameChallengeHistoryReadOnlyDescription =>
      'Vos pools confirmés restent visibles, mais l’ouverture des détails est désactivée pour cette version.';

  @override
  String get gameShowingSavedChallengeHistory =>
      'Affichage de l’historique enregistré';

  @override
  String get gameShowingSavedChallengeHistoryDescription =>
      'Reconnectez-vous et actualisez avant d’ouvrir un pool ou de vérifier un statut récent.';

  @override
  String get gameRefreshHistory => 'Actualiser l’historique';

  @override
  String gameNoFilteredChallenges(String filter) {
    return 'Aucun défi $filter';
  }

  @override
  String get gameCreateChallenge => 'Créer un défi';

  @override
  String gameChallengeCardSemantics(String home, String away, String summary) {
    return '$home contre $away. $summary. Ouvrir les détails du défi.';
  }

  @override
  String get gameOpensChallenge => 'Ouvre ce défi';

  @override
  String get gameChallengeDetailsUnavailable =>
      'Les détails du défi sont indisponibles';

  @override
  String gameTeamsVersusMultiline(String home, String away) {
    return '$home\ncontre\n$away';
  }

  @override
  String get gameConnectionRestored => 'Connexion rétablie';

  @override
  String get gameChallengeHistoryOffline => 'Historique des défis hors ligne';

  @override
  String get gameRefreshLatestChallengeStatus =>
      'Actualisez pour vérifier le statut récent de vos défis.';

  @override
  String get gameReconnectChallengePools =>
      'Reconnectez-vous pour charger les pools créés ou rejoints.';

  @override
  String get gameChallengeHistoryUnavailable =>
      'Historique des défis indisponible';

  @override
  String get gameChallengeHistoryPermissionDenied =>
      'Votre accès actuel au club ne permet pas cet historique.';

  @override
  String get gameChallengeHistoryChanged => 'L’historique des défis a changé';

  @override
  String get gameChallengeHistoryChangedDescription =>
      'Actualisez et vérifiez le statut récent avant d’ouvrir un défi.';

  @override
  String get gameChallengeHistoryTimedOut =>
      'La vérification de l’historique a expiré';

  @override
  String get gameChallengeHistoryTimedOutDescription =>
      'Aucun statut n’a été confirmé. Actualisez avant d’ouvrir un défi.';

  @override
  String get gameChallengeHistoryTryAgain =>
      'Actualisez et réessayez lorsque l’historique est prêt.';

  @override
  String get gameOpenChallengesEmpty =>
      'Créez ou rejoignez un pool pour voir ici un défi de score exact actif.';

  @override
  String get gameLockedChallengesEmpty =>
      'Aucun défi rejoint n’attend actuellement de score final.';

  @override
  String get gameSettledChallengesEmpty =>
      'Les résultats et points des défis terminés apparaîtront ici.';

  @override
  String get gameRefundedChallengesEmpty =>
      'Les défis annulés ou remboursés apparaîtront ici.';

  @override
  String gameEarnedPoints(int count) {
    return '$count pts gagnés';
  }

  @override
  String get gameNoResultCredit => 'Aucun crédit de résultat';

  @override
  String gameReturnedPoints(int count) {
    return '$count pts restitués';
  }

  @override
  String gameMyPickScore(int home, int away) {
    return 'Mon choix $home-$away';
  }

  @override
  String get gameMoreOptions => 'Plus d’options';

  @override
  String get gameConnectToFanZone => 'Connectez-vous pour charger la Fan Zone.';

  @override
  String get gameOpeningFanZone => 'Ouverture de la Fan Zone';

  @override
  String get gameRefreshingFanZone => 'Actualisation de la Fan Zone';

  @override
  String get gameRefreshingFanZoneDescription =>
      'Vos points, manches et pronostics actuels restent visibles pendant le chargement.';

  @override
  String get gameMatchdayRounds => 'Manches du jour de match';

  @override
  String get gameNoMatchdayRounds => 'Aucune manche de jour de match';

  @override
  String get gameReviewJoinedRounds =>
      'Consultez les manches rejointes, cartes et résultats';

  @override
  String get gameVenueCheckIn => 'Enregistrement sur place';

  @override
  String get gameVenueOrder => 'Commande sur place';

  @override
  String get gameVenueOrderDescription =>
      'Commandez des boissons approuvées et suivez le retrait';

  @override
  String get gameLiveNow => 'En direct';

  @override
  String get gameThisWeek => 'Cette semaine';

  @override
  String get gamePointsBalanceTitle => 'Solde de points';

  @override
  String get gamePointsBalanceDescription =>
      'Solde, gains, récompenses et activité';

  @override
  String get gameActivity => 'Activité';

  @override
  String get gameOpenPointsActivity => 'Voir les mouvements récents de points';

  @override
  String get gameSupporterClubs => 'Clubs de supporters';

  @override
  String get gameSupporterClubsDescription =>
      'Fan-clubs, sections et groupes communautaires';

  @override
  String get gameMemberFans => 'Supporters membres';

  @override
  String get gameMemberFansDescription =>
      'Ouvrir le registre des supporters dans une feuille';

  @override
  String get gameSupportClubDescription =>
      'Projets et groupes de contribution des supporters';

  @override
  String get gameRedeemRewards => 'Utiliser les récompenses';

  @override
  String get gameRedeemRewardsDescription =>
      'Utilisez vos points pour des récompenses et offres partenaires';

  @override
  String get gameAchievements => 'Réalisations';

  @override
  String get gameAchievementsDescription => 'Badges et statut de série';

  @override
  String get gameShareCard => 'Carte à partager';

  @override
  String get gameShareCardDescription =>
      'Créez une carte de supporter à partager';

  @override
  String get gameConnectBeforeJoiningRound =>
      'Connectez-vous avant de rejoindre cette manche.';

  @override
  String get gamePoolEntryFailed =>
      'L’inscription à la cagnotte n’a pas pu être enregistrée.';

  @override
  String gameOutcomeJoined(String outcome) {
    return '$outcome rejoint.';
  }

  @override
  String gamePartnerSponsorsRound(String partner) {
    return '$partner sponsorise cette manche. Faites un choix avant sa fermeture.';
  }

  @override
  String get gameProjects => 'Projets';

  @override
  String get gameProjectsDescription =>
      'Initiatives du club et besoins des campagnes';

  @override
  String get gameGroups => 'Groupes';

  @override
  String get gameGroupsDescription =>
      'Rejoignez des groupes de contribution de supporters';

  @override
  String get gameQrSheetDescription =>
      'L’affichage et le partage du QR restent dans cette feuille.';

  @override
  String get gameFanIdQrDisplay => 'Fan ID et affichage QR';

  @override
  String get gameQr => 'QR';

  @override
  String get gameBadgesEarnedDescription =>
      'Obtenus grâce aux pronostics, présences et actions de soutien';

  @override
  String get gameStartStreak =>
      'Rejoignez votre prochaine manche pour démarrer une série';

  @override
  String gameActivePlayDays(int count) {
    return '$count jours de jeu actifs';
  }

  @override
  String gameActionUnavailable(String description) {
    return '$description. Indisponible.';
  }

  @override
  String get gameFanZoneAccessUnavailable => 'Accès à la Fan Zone indisponible';

  @override
  String get gameFanZoneAccessUnavailableDescription =>
      'Votre compte ne peut pas ouvrir la Fan Zone actuellement. Contactez l’assistance si cet accès devrait être disponible.';

  @override
  String get gameFanZoneChanged => 'La Fan Zone a changé';

  @override
  String get gameFanZoneChangedDescription =>
      'Les données ont changé pendant votre consultation. Actualisez pour charger la version actuelle.';

  @override
  String get gameFanZoneSecurityTimedOut =>
      'La vérification de sécurité a expiré';

  @override
  String get gameFanZoneSecurityTimedOutDescription =>
      'Nous n’avons pas pu confirmer l’accès actuel. Actualisez avant de continuer.';

  @override
  String get gameFanZoneTemporarilyUnavailable =>
      'La Fan Zone est temporairement indisponible.';

  @override
  String get gameSavedFanZoneContent =>
      'Contenu enregistré affiché. Reconnectez-vous et actualisez pour les rencontres et soldes actuels.';

  @override
  String get gamePickSectionLabel => 'Choix';

  @override
  String get gamePicksLabel => 'Choix';

  @override
  String get gameRewardsLabel => 'Récompenses';

  @override
  String get gameStreakLabel => 'Série';

  @override
  String get gameBadgesLabel => 'Badges';

  @override
  String get gamePointsLabel => 'Points';

  @override
  String get gameAccuracyLabel => 'Précision';

  @override
  String get gameFanZoneUnavailableTitle => 'Fan Zone indisponible';

  @override
  String get venueOrderConfirmedToast =>
      'Commande confirmée par le service du lieu. Payez uniquement sur place.';

  @override
  String get venueOrderingUnavailable => 'Commande sur place indisponible';

  @override
  String get venueFeatureDisabled =>
      'Cette fonctionnalité contrôlée est désactivée pour ce club ou cette version.';

  @override
  String get venueBackToFanZone => 'Retour à la fan zone';

  @override
  String get venueOrderAccessDenied => 'Accès à la commande refusé';

  @override
  String get venueOrderAccessDeniedBody =>
      'Ce compte ne peut pas utiliser le parcours de commande des supporters.';

  @override
  String get venueOrderAccessDeniedLoadBody =>
      'Ce compte ne peut pas charger le parcours de commande des supporters.';

  @override
  String get venueCheckInBeforeOrdering =>
      'Enregistrez-vous avant de commander';

  @override
  String get venueCheckInRequiredBody =>
      'Un enregistrement confirmé est requis pour charger le menu de boissons approuvé.';

  @override
  String get venueCheckInFirst => 'S’enregistrer d’abord';

  @override
  String get venueNoDrinksAvailable => 'Aucune boisson disponible';

  @override
  String get venueNoDrinksBody =>
      'Le lieu enregistré n’a aucune boisson active approuvée actuellement.';

  @override
  String get venueRefreshMenu => 'Actualiser le menu';

  @override
  String get venueMenuUnavailableOffline => 'Menu indisponible hors connexion';

  @override
  String get venueMenuOfflineBody =>
      'Reconnectez-vous avant de charger le menu. Aucune commande n’est mise en attente hors connexion.';

  @override
  String get venueTryAgain => 'Réessayer';

  @override
  String get venueMenuCheckTimedOut => 'La vérification du menu a expiré';

  @override
  String get venueMenuCheckTimedOutBody =>
      'L’application n’a pas pu établir un contexte sûr à temps. Effectuez une actualisation limitée.';

  @override
  String get venueMenuUnavailableBody =>
      'Le lieu enregistré et son menu approuvé n’ont pas pu être chargés en toute sécurité.';

  @override
  String get venueOrderHero => 'Commander des boissons ici';

  @override
  String get venueOrderHeroBody =>
      'Choisissez dans le menu de boissons approuvé. La file du personnel reste dans le portail du lieu.';

  @override
  String get venueApprovedDrinks => 'Boissons approuvées';

  @override
  String get venueOrderReview => 'Vérification de la commande';

  @override
  String venueOrderReviewValue(int count, String total) {
    return '$count articles, $total';
  }

  @override
  String get venueLegalAgeConfirmation => 'Confirmation de l’âge légal';

  @override
  String get venueNotSelected => 'Non sélectionné';

  @override
  String get venueAgeConfirmationRequired => 'Confirmation de l’âge requise';

  @override
  String get venueAgeConfirmationBody =>
      'Confirmez uniquement si vous respectez l’âge légal du lieu. Le personnel peut encore vérifier votre éligibilité.';

  @override
  String get venueRemoveConfirmation => 'Retirer la confirmation';

  @override
  String get venueConfirmLegalAge => 'Confirmer l’âge légal';

  @override
  String get venuePayAtVenue => 'Payer sur place';

  @override
  String get venuePaymentDisclaimer =>
      'L’application crée uniquement la commande. Elle ne prend aucun paiement et ne prétend pas qu’il a réussi.';

  @override
  String get venueCreatingOrderUpper => 'Création de la commande';

  @override
  String get venueOrderConfirmedUpper => 'Commande confirmée';

  @override
  String get venueReviewCreateOrder => 'Vérifier et créer';

  @override
  String get venueOrderProtections => 'Protections de la commande';

  @override
  String get venueDuplicateSubmission => 'Envoi en double';

  @override
  String get venueDuplicateSubmissionBody =>
      'Une clé d’idempotence par tentative';

  @override
  String get venueOfflineBehavior => 'Comportement hors connexion';

  @override
  String get venueOfflineBehaviorBody =>
      'Aucune mise en attente ni reprise automatique';

  @override
  String get venueStaffControls => 'Contrôles du personnel';

  @override
  String get venueStaffControlsBody => 'Portail du lieu uniquement';

  @override
  String venueItemsSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles sélectionnés',
      one: '1 article sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get venueShowingSavedMenu => 'Menu enregistré affiché';

  @override
  String get venueShowingSavedMenuBody =>
      'Reconnectez-vous avant de créer la commande. Rien n’est mis en attente ni rejoué hors connexion.';

  @override
  String get venueCreatingOrder => 'Création de la commande';

  @override
  String get venueCreatingOrderBody =>
      'Attendez la confirmation du serveur. Ne répétez pas cette tentative.';

  @override
  String get venueOrderCreated => 'Commande créée';

  @override
  String venueOrderCreatedSummary(String status, String total) {
    return '$status · $total. Le paiement reste externe et se fait sur place.';
  }

  @override
  String get venueChooseDrink => 'Choisissez au moins une boisson';

  @override
  String get venueChooseDrinkBody =>
      'La commande ne peut pas être créée avec une sélection vide.';

  @override
  String get venueCheckInRequired => 'Enregistrement requis';

  @override
  String get venueCheckInRejectedBody =>
      'Le lieu n’a pas accepté cet enregistrement. Enregistrez-vous de nouveau avant de réessayer.';

  @override
  String get venueAgeSubmitBody =>
      'Confirmez l’âge légal avant d’envoyer une boisson alcoolisée.';

  @override
  String get venueDrinkChanged => 'Une boisson sélectionnée a changé';

  @override
  String get venueDrinkChangedBody =>
      'Actualisez le menu approuvé avant de réessayer.';

  @override
  String get venueOrderAttemptPaused => 'Tentative de commande suspendue';

  @override
  String get venueOrderAttemptPausedBody =>
      'Une autre demande peut être active. Vérifiez la dernière commande avant de réessayer.';

  @override
  String get venueOrderConfirmationUncertain =>
      'Confirmation de commande incertaine';

  @override
  String get venueOrderConfirmationUncertainBody =>
      'Ne renvoyez pas la commande. Vérifiez la dernière commande avant de fermer.';

  @override
  String get venueOrderNotConfirmed => 'Commande non confirmée';

  @override
  String get venueOrderNotConfirmedBody =>
      'Le serveur n’a pas confirmé cette commande. Fermez l’avertissement avant de réessayer.';

  @override
  String venueLatestOrder(String status) {
    return 'Dernière commande : $status';
  }

  @override
  String venueLatestOrderSummary(String total, String payment) {
    return '$total · $payment.';
  }

  @override
  String get venueReadyToOrder => 'Prêt à commander';

  @override
  String get venueReadyToOrderBody =>
      'Choisissez des boissons approuvées, vérifiez le total, puis créez une seule fois.';

  @override
  String venueRemoveItem(String item) {
    return 'Retirer $item';
  }

  @override
  String venueAddItem(String item) {
    return 'Ajouter $item';
  }

  @override
  String venueDrinkSemantics(int count, String price) {
    return '$count sélectionnés, $price chacun';
  }

  @override
  String get venueAgeRestricted => 'Réservé à l’âge légal';

  @override
  String get venueWaitingForVenue => 'En attente du lieu';

  @override
  String get venueAccepted => 'Acceptée';

  @override
  String get venuePreparing => 'En préparation';

  @override
  String get venueReadyForPickup => 'Prête à retirer';

  @override
  String get venueServed => 'Servie';

  @override
  String get venueStatusPending => 'Statut en attente';

  @override
  String get venuePaidAtVenue => 'Payée sur place';

  @override
  String get venuePaymentWaived => 'Paiement annulé';

  @override
  String get venueRefundedExternally => 'Remboursée à l’extérieur';

  @override
  String get venuePaymentPending => 'Paiement en attente sur place';

  @override
  String get venueCheckinTitle => 'Enregistrement sur place';

  @override
  String get venueCheckinUnavailable => 'Enregistrement sur place indisponible';

  @override
  String get venueCheckinAccessDenied => 'Accès à l’enregistrement refusé';

  @override
  String get venueCheckinAccessDeniedBody =>
      'Ce compte ne peut pas utiliser le parcours d’enregistrement des supporters.';

  @override
  String get venueCheckinSafeStateBody =>
      'Le parcours n’a pas pu établir un état d’enregistrement sécurisé.';

  @override
  String get venueCheckinHero => 'Enregistrez-vous dans un lieu approuvé';

  @override
  String get venueCheckinHeroBody =>
      'Saisissez le code du lieu ou QR tournant après votre arrivée. L’enregistrement des supporters n’expose jamais les contrôles du personnel ou d’administration.';

  @override
  String get venueCheckinCodeLabel => 'Code du lieu';

  @override
  String get venueCheckinInputLabel => 'Code du lieu ou QR';

  @override
  String get venueCheckinInputHint => 'Saisissez au moins 4 caractères';

  @override
  String get venueCheckinCheckingCodeUpper => 'Vérification du code';

  @override
  String get venueCheckinActionUpper => 'S’enregistrer';

  @override
  String get venueCheckinLocationConsentSemantics =>
      'Consentement à la vérification du lieu';

  @override
  String get venueCheckinOptionalLocationReview =>
      'Vérification facultative du lieu';

  @override
  String get venueCheckinConsentMarkedBody =>
      'Le consentement est indiqué pour cette tentative. Cette version n’envoie toujours aucune coordonnée ; les campagnes exigeant la localisation restent en attente d’examen.';

  @override
  String get venueCheckinNoLocationBody =>
      'La localisation précise n’est pas collectée dans cette version. Vous pouvez indiquer votre consentement, mais les campagnes exigeant la localisation restent en attente d’examen.';

  @override
  String get venueCheckinRemoveConsentUpper => 'Retirer le consentement';

  @override
  String get venueCheckinMarkConsentUpper => 'Donner le consentement';

  @override
  String get venueCheckinPrivacyBoundary => 'Limite de confidentialité';

  @override
  String get venueCheckinPrivacyBoundaryBody =>
      'Les codes tournants bruts sont hachés avant l’envoi et ne sont pas conservés par l’application. Aucune localisation précise n’est collectée.';

  @override
  String get venueCheckinPausedOffline =>
      'Enregistrement suspendu hors connexion';

  @override
  String get venueCheckinPausedOfflineBody =>
      'Reconnectez-vous avant l’envoi. Aucun enregistrement n’est mis en attente ni rejoué.';

  @override
  String get venueCheckinCheckingCode => 'Vérification du code du lieu';

  @override
  String get venueCheckinCheckingCodeBody =>
      'Attendez le résultat du serveur. Ne répétez pas cet enregistrement.';

  @override
  String get venueCheckinPendingReview => 'Enregistrement en attente d’examen';

  @override
  String get venueCheckinConfirmed => 'Enregistrement confirmé';

  @override
  String get venueCheckinPendingReviewBody =>
      'Le code du lieu a été accepté, mais une vérification contrôlée du lieu ou de la campagne reste nécessaire.';

  @override
  String venueCheckinFetRecorded(int count) {
    return '+$count FET enregistrés pour cet enregistrement.';
  }

  @override
  String get venueCheckinConfirmedNoReward =>
      'Le lieu a accepté cet enregistrement. Aucune récompense n’était promise.';

  @override
  String get venueCheckinReady => 'Prêt pour l’enregistrement sur place';

  @override
  String get venueCheckinReadyBody =>
      'Utilisez le code actuel uniquement après votre arrivée sur place.';

  @override
  String get venueCheckinInvalidCode => 'Code non accepté';

  @override
  String get venueCheckinInvalidCodeBody =>
      'Saisissez le code du lieu ou QR actuel affiché sur place.';

  @override
  String get venueCheckinExpiredCode => 'Code du lieu expiré';

  @override
  String get venueCheckinExpiredCodeBody =>
      'Consultez l’écran du lieu pour obtenir le code tournant actuel.';

  @override
  String get venueCheckinAlreadyCheckedIn => 'Déjà enregistré';

  @override
  String get venueCheckinAlreadyCheckedInBody =>
      'Le serveur a trouvé un enregistrement existant. Aucune récompense en double n’a été créée.';

  @override
  String get venueCheckinCampaignUnavailable =>
      'Campagne d’enregistrement indisponible';

  @override
  String get venueCheckinCampaignUnavailableBody =>
      'La campagne est suspendue, inactive ou a atteint son budget contrôlé.';

  @override
  String get venueCheckinConflict => 'Conflit d’enregistrement';

  @override
  String get venueCheckinConflictBody =>
      'Une autre tentative peut déjà être active. Confirmez l’état du lieu avant de réessayer.';

  @override
  String get venueCheckinConfirmationUncertain =>
      'Confirmation d’enregistrement incertaine';

  @override
  String get venueCheckinConfirmationUncertainBody =>
      'Ne répétez pas encore le code. Vérifiez votre activité sur place, puis fermez cet avertissement.';

  @override
  String get venueCheckinUnavailableShort => 'Enregistrement indisponible';

  @override
  String get venueCheckinUnavailableBody =>
      'Le serveur n’a pas confirmé la tentative. Fermez cet avertissement avant de réessayer.';

  @override
  String get challengeConfirmTitle => 'Confirmer le défi';

  @override
  String challengeConfirmPoints(int count) {
    return 'Confirmer $count pts';
  }

  @override
  String get challengeCreateTitle => 'Créer un défi';

  @override
  String get challengeFindingFixtures => 'Recherche des prochaines rencontres';

  @override
  String get challengeFindingFixturesBody =>
      'Vérification des matchs encore ouverts aux défis de score exact.';

  @override
  String get challengeNoFixtures => 'Aucune rencontre disponible';

  @override
  String get challengeNoFixturesBody =>
      'Aucun prochain match n’est encore ouvert à un nouveau défi.';

  @override
  String get challengeRefreshFixtures => 'Actualiser les rencontres';

  @override
  String get challengeCreating => 'Création du défi';

  @override
  String get challengeCreatingBody =>
      'Votre rencontre, score et mise restent visibles pendant la confirmation.';

  @override
  String get challengeCreationUnavailable => 'Création de défi indisponible';

  @override
  String get challengeCreationDisabledBody =>
      'Vous pouvez consulter le formulaire, mais la création est désactivée pour cette version.';

  @override
  String get challengeShowingSavedFixtures =>
      'Rencontres enregistrées affichées';

  @override
  String get challengeShowingSavedFixturesBody =>
      'Reconnectez-vous et actualisez avant de modifier le score ou créer un défi.';

  @override
  String get challengeRefreshFixturesUpper => 'Actualiser les rencontres';

  @override
  String get challengeExactScore => 'Score exact';

  @override
  String challengeSelectedScore(int home, int away) {
    return 'Score exact sélectionné : $home à $away';
  }

  @override
  String get challengeVersusUpper => 'Contre';

  @override
  String get challengeEntryPoints => 'Points d’entrée';

  @override
  String get challengeEntryOptionsUnavailable =>
      'Les options d’entrée au défi ne sont pas encore disponibles.';

  @override
  String challengeStakePoints(int count) {
    return '$count pts';
  }

  @override
  String get challengeCheckingBalance =>
      'Vérification de votre solde de points.';

  @override
  String get challengeBalanceUnavailable =>
      'Votre solde est indisponible. Actualisez avant de créer ce défi.';

  @override
  String get challengeBalanceInsufficient =>
      'Votre solde actuel ne couvre pas cette entrée.';

  @override
  String get challengeCreatingUpper => 'Création du défi';

  @override
  String get challengeCreationOffline => 'Création de défi hors connexion';

  @override
  String get challengeRefreshLatestFixtures =>
      'Actualisez les dernières rencontres avant de créer un défi.';

  @override
  String get challengeReconnectFixtures =>
      'Reconnectez-vous pour charger les rencontres disponibles.';

  @override
  String get challengeAccessDeniedBody =>
      'Votre accès actuel au club ne permet pas un nouveau défi.';

  @override
  String get challengeDetailsChanged => 'Les détails du défi ont changé';

  @override
  String get challengeDetailsChangedBody =>
      'Actualisez les rencontres et vérifiez votre choix avant de réessayer.';

  @override
  String get challengeSecurityTimedOut =>
      'La vérification de sécurité a expiré';

  @override
  String get challengeSecurityTimedOutBody =>
      'Aucun défi n’a été confirmé. Actualisez avant de réessayer.';

  @override
  String get challengeTryAgainBody =>
      'Actualisez et réessayez lorsque les rencontres seront disponibles.';

  @override
  String challengePreviewSemantics(
    String homeTeam,
    String awayTeam,
    int homeScore,
    int awayScore,
    int stake,
    int balance,
  ) {
    return 'Aperçu du défi. $homeTeam contre $awayTeam. Votre choix $homeScore à $awayScore. Entrée $stake points. Solde $balance points.';
  }

  @override
  String get challengePreview => 'Aperçu du défi';

  @override
  String get challengeYourPick => 'Votre choix';

  @override
  String challengeBalancePoints(int count) {
    return 'Solde $count pts';
  }

  @override
  String get challengeLocksAtKickoff => 'Verrouillage au coup d’envoi';

  @override
  String challengeFixtureOption(String home, String away, String competition) {
    return '$home vs $away • $competition';
  }

  @override
  String challengeDecrease(String label) {
    return 'Diminuer $label';
  }

  @override
  String challengeIncrease(String label) {
    return 'Augmenter $label';
  }

  @override
  String get walletRewardsUnavailable => 'Récompenses indisponibles';

  @override
  String get walletDisabledBody =>
      'Les points et l’activité des récompenses sont désactivés pour cette version.';

  @override
  String get walletNoActivity => 'Aucune activité de points';

  @override
  String get walletNoActivityBody =>
      'Votre solde confirmé et l’activité des récompenses apparaîtront ici.';

  @override
  String get walletOffline => 'Récompenses hors connexion';

  @override
  String get walletOfflineBody =>
      'Reconnectez-vous pour charger votre solde confirmé. Rien n’est mis en attente.';

  @override
  String get walletAccessDenied => 'Accès aux récompenses refusé';

  @override
  String get walletAccessDeniedBody =>
      'Ce compte ne peut pas ouvrir le registre privé des points.';

  @override
  String get walletCheckTimedOut => 'La vérification des points a expiré';

  @override
  String get walletCheckTimedOutBody =>
      'L’application n’a pas pu confirmer votre registre privé à temps. Effectuez une actualisation limitée.';

  @override
  String get walletUnavailableBody =>
      'Votre registre de points n’a pas pu être chargé. Aucune activité privée n’a été affichée.';

  @override
  String walletBalanceValue(String points) {
    return '$points pts';
  }

  @override
  String get walletUsed => 'Utilisés';

  @override
  String walletHistoricalPoints(String points) {
    return '$points points proviennent de récompenses antérieures à l’activation de l’historique.';
  }

  @override
  String get walletEarn => 'Gagner';

  @override
  String get walletEarnBody =>
      'Gagnez des points grâce aux initiatives et promotions partenaires.';

  @override
  String get walletUseBody =>
      'Utilisez les points pour les récompenses, activités de match et défis Fan Zone.';

  @override
  String get walletRewardsBody =>
      'Utilisez les points pour les avantages de match et récompenses partenaires.';

  @override
  String get walletRewardsEmptyBody =>
      'Les récompenses disponibles apparaissent lorsque le club ou ses partenaires les publient.';

  @override
  String get walletActivityEmptyBody =>
      'L’activité apparaît après des récompenses partenaires ou actions de match.';

  @override
  String get walletShowingSaved => 'Points enregistrés affichés';

  @override
  String get walletShowingSavedBody =>
      'Reconnectez-vous pour le dernier solde et l’activité. Rien n’est mis en attente.';

  @override
  String get walletRefreshing => 'Actualisation des points';

  @override
  String get walletRefreshingBody =>
      'Le solde confirmé reste visible pendant le chargement du registre.';

  @override
  String get walletChangedElsewhere => 'Les points ont changé ailleurs';

  @override
  String get walletChangedElsewhereBody =>
      'Le solde enregistré reste visible. Actualisez pour confirmer le registre.';

  @override
  String get walletRefreshTimedOut => 'L’actualisation des points a expiré';

  @override
  String get walletRefreshTimedOutBody =>
      'Le solde enregistré reste affiché. Effectuez une actualisation limitée.';

  @override
  String get walletMayBeOutdated => 'Les points peuvent être obsolètes';

  @override
  String get walletMayBeOutdatedBody =>
      'Le dernier solde confirmé reste visible pendant l’indisponibilité du service.';

  @override
  String get walletSavedUntilRefresh =>
      'Le dernier solde confirmé reste visible jusqu’à une actualisation réussie.';

  @override
  String get feedChallengeTitle => 'Défi';

  @override
  String get feedDescription =>
      'Cagnottes de score exact pour de vraies rencontres. Créez, rejoignez une fois et obtenez le résultat officiel automatiquement.';

  @override
  String get feedCreateNew => 'Créer un nouveau défi';

  @override
  String get feedOpening => 'Ouverture des défis';

  @override
  String get feedOpeningBody =>
      'Vérification des rencontres, cagnottes et défis rejoints.';

  @override
  String get feedRefreshing => 'Actualisation des défis';

  @override
  String get feedRefreshingBody =>
      'Les rencontres, cagnottes et défis rejoints restent visibles.';

  @override
  String get feedActionsUnavailable => 'Actions de défi indisponibles';

  @override
  String get feedActionsUnavailableBody =>
      'Vous pouvez consulter les cagnottes, mais créer et rejoindre sont désactivés pour cette version.';

  @override
  String get feedShowingSaved => 'Défis enregistrés affichés';

  @override
  String get feedShowingSavedBody =>
      'Reconnectez-vous avant de créer ou rejoindre une cagnotte.';

  @override
  String get feedUpdatesPaused => 'Mises à jour des défis suspendues';

  @override
  String get feedEmpty => 'Aucun défi disponible';

  @override
  String get feedEmptyBody =>
      'De nouvelles cagnottes apparaîtront quand des rencontres admissibles seront ouvertes.';

  @override
  String get feedFeatured => 'Défis populaires / à la une';

  @override
  String get feedSeeAll => 'Tout voir';

  @override
  String get feedOpenChallenges => 'Défis ouverts';

  @override
  String get feedEndingSoon => 'Fin prochaine';

  @override
  String get feedEndingSoonAction => 'Fin prochaine';

  @override
  String get feedMyChallenges => 'Mes défis';

  @override
  String get feedSettledChallenges => 'Défis réglés';

  @override
  String get feedResults => 'Résultats';

  @override
  String get feedNoFilterMatches => 'Aucun résultat pour ce filtre';

  @override
  String get feedNoFilterMatchesBody =>
      'Essayez une autre vue ou créez une nouvelle cagnotte.';

  @override
  String get feedAll => 'Tous';

  @override
  String get feedHighPool => 'Cagnotte élevée';

  @override
  String get feedMostParticipants => 'Plus de participants';

  @override
  String get feedMyJoined => 'Mes participations';

  @override
  String get feedChallengesOffline => 'Défis indisponibles hors connexion';

  @override
  String get feedChallengesOfflineBody =>
      'Reconnectez-vous pour charger les rencontres et cagnottes actuelles.';

  @override
  String get feedAccessUnavailable => 'Accès aux défis indisponible';

  @override
  String get feedAccessUnavailableBody =>
      'Votre accès actuel ne permet pas ces cagnottes.';

  @override
  String get feedDataChanged => 'Les données des défis ont changé';

  @override
  String get feedDataChangedBody =>
      'Actualisez avant de consulter ou rejoindre les dernières cagnottes.';

  @override
  String get feedSecurityTimedOutBody =>
      'Aucune action n’a été effectuée. Actualisez avant de réessayer.';

  @override
  String get feedUnavailable => 'Fil des défis indisponible';

  @override
  String get feedUnavailableBody =>
      'Les cagnottes actuelles n’ont pas pu être chargées en toute sécurité.';

  @override
  String get detailTitle => 'Détail du défi';

  @override
  String get detailOpening => 'Ouverture du défi';

  @override
  String get detailOpeningBody =>
      'Vérification de la cagnotte, des entrées et du résultat officiel.';

  @override
  String get detailNotFound => 'Défi introuvable';

  @override
  String get detailNotFoundBody =>
      'Cette cagnotte est peut-être terminée, supprimée ou indisponible pour votre club.';

  @override
  String get detailBack => 'Retour aux défis';

  @override
  String get detailPendingBody =>
      'La cagnotte et le score choisi restent visibles pendant la confirmation.';

  @override
  String get detailActionsUnavailableBody =>
      'Vous pouvez consulter cette cagnotte, mais rejoindre et annuler sont désactivés.';

  @override
  String get detailShowingSaved => 'Défi enregistré affiché';

  @override
  String get detailShowingSavedBody =>
      'Reconnectez-vous et actualisez avant de rejoindre, modifier le score ou annuler.';

  @override
  String get detailRefreshUpper => 'Actualiser le défi';

  @override
  String get detailMyPickUpper => 'Mon choix';

  @override
  String get detailMyEntry => 'Mon entrée';

  @override
  String get detailJoinUpper => 'Rejoindre ce défi';

  @override
  String get detailPickScoreBody =>
      'Choisissez le score exact avant le verrouillage.';

  @override
  String get detailResults => 'Résultats';

  @override
  String get detailOfficialScore => 'Score officiel';

  @override
  String get detailWinners => 'Gagnants';

  @override
  String get detailLosers => 'Perdants';

  @override
  String get detailPointsPerWinner => 'Points / gagnant';

  @override
  String get detailEntries => 'Entrées';

  @override
  String get detailEntryCancelled => 'Entrée annulée';

  @override
  String get detailWaitingResult =>
      'En attente de la vérification du résultat officiel.';

  @override
  String detailScoreSemantics(String label, int value) {
    return 'Score de $label : $value';
  }

  @override
  String get detailAccessUnavailable => 'Accès au défi indisponible';

  @override
  String get detailAccessUnavailableBody =>
      'Votre compte ne peut pas consulter ou modifier ce défi.';

  @override
  String get detailDataChangedBody =>
      'Actualisez avant de consulter les entrées ou modifier ce défi.';

  @override
  String get detailSecurityTimedOutBody =>
      'Aucune action n’a été confirmée. Actualisez avant de réessayer.';

  @override
  String get detailUnavailable => 'Défi indisponible';

  @override
  String get detailUnavailableBody =>
      'Les derniers détails n’ont pas pu être confirmés. Actualisez pour réessayer.';

  @override
  String get detailJoinedSuccess => 'Défi rejoint avec succès.';

  @override
  String get detailCancelledSuccess => 'Défi annulé.';

  @override
  String get detailJoining => 'Participation au défi';

  @override
  String get detailCancelling => 'Annulation du défi';

  @override
  String get detailRefreshing => 'Actualisation du défi';

  @override
  String get detailJoiningUpper => 'Participation en cours';

  @override
  String detailJoinWithPoints(int count) {
    return 'Rejoindre avec $count pts';
  }

  @override
  String get detailCancellingUpper => 'Annulation en cours';

  @override
  String get detailCancelUpper => 'Annuler le défi';

  @override
  String get detailConnectionRestored => 'Connexion rétablie';

  @override
  String get detailOffline => 'Détails du défi hors connexion';

  @override
  String get detailRefreshBeforeAction =>
      'Actualisez pour vérifier la cagnotte avant de rejoindre ou annuler.';

  @override
  String get detailReconnectBeforeAction =>
      'Reconnectez-vous pour vérifier la cagnotte avant de rejoindre ou annuler.';

  @override
  String get detailEntryActive => 'Active';

  @override
  String get detailEntryWinner => 'Gagnant';

  @override
  String get detailEntryLoser => 'Perdant';

  @override
  String get detailEntryRefunded => 'Remboursée';

  @override
  String get detailEntryCancelledStatus => 'Annulée';

  @override
  String get gameShareOptionsClosed =>
      'Options de partage fermées. Confirmez la destination avant de publier.';

  @override
  String get gameShareActionsUnavailable => 'Actions de partage indisponibles';

  @override
  String get gameShareActionsUnavailableDescription =>
      'Vous pouvez revenir à la Fan Zone, mais le partage est désactivé dans cette version.';

  @override
  String get gameBackToFanZoneUpper => 'Retour à la fan zone';

  @override
  String get gamePredictionAccessDenied => 'Accès aux pronostics refusé';

  @override
  String get gamePredictionAccessDeniedDescription =>
      'Ce compte ne peut pas ouvrir l’historique des pronostics pour le partager.';

  @override
  String get gameMakePickFirst => 'Faites d’abord un pronostic';

  @override
  String get gameShareCardsUnlock =>
      'Les cartes à partager sont disponibles après un pronostic de jour de match.';

  @override
  String get gameBackToPicksUpper => 'Retour aux pronostics';

  @override
  String get gameShareCardsOffline => 'Cartes à partager hors connexion';

  @override
  String get gameShareCardsOfflineDescription =>
      'Reconnectez-vous pour charger votre historique de pronostics confirmé. Rien n’est mis en attente hors connexion.';

  @override
  String get gameHistoryCheckTimedOut =>
      'La vérification de l’historique a expiré';

  @override
  String get gameHistoryCheckTimedOutDescription =>
      'L’application n’a pas pu confirmer un historique de pronostics sûr à temps. Essayez une actualisation limitée.';

  @override
  String get gameTryAgainUpper => 'Réessayer';

  @override
  String get gameShareCardsUnavailable => 'Cartes à partager indisponibles';

  @override
  String get gameShareCardsUnavailableDescription =>
      'L’historique des pronostics n’a pas pu être chargé. Aucun détail d’activité privé n’a été affiché.';

  @override
  String get gameShowingSavedShareCard => 'Carte enregistrée affichée';

  @override
  String get gameShowingSavedShareCardDescription =>
      'Reconnectez-vous avant de partager ou copier. Aucune action n’est mise en attente hors connexion.';

  @override
  String get gameCopyingShareText => 'Copie du texte de partage';

  @override
  String get gameOpeningShareOptions => 'Ouverture des options de partage';

  @override
  String get gameShareAwaitPlatformConfirmation =>
      'Attendez la confirmation de la plateforme. Ne répétez pas cette action.';

  @override
  String get gameShareActionPaused => 'Action de partage suspendue';

  @override
  String get gameShareActionPausedDescription =>
      'Une autre action était déjà active. Vérifiez la vue actuelle de la plateforme avant de continuer.';

  @override
  String get gameShareConfirmationUncertain =>
      'Confirmation du partage incertaine';

  @override
  String get gameShareConfirmationUncertainDescription =>
      'Vérifiez la feuille de partage ou le presse-papiers, puis fermez cet avertissement avant de réessayer.';

  @override
  String get gameShareActionUnavailable => 'Action de partage indisponible';

  @override
  String get gameShareActionUnavailableDescription =>
      'La plateforme n’a pas terminé l’action. Fermez cet avertissement avant de réessayer.';

  @override
  String get gameUsingSavedPredictionHistory =>
      'Historique de pronostics enregistré utilisé';

  @override
  String get gameUsingSavedPredictionHistoryDescription =>
      'Actualisez cette page avant d’ouvrir une autre action de partage de la plateforme.';

  @override
  String get gameBackToPicks => 'Retour aux pronostics';

  @override
  String get gameChoosePick => 'Choisir un pronostic';

  @override
  String gameSharePredictionSemantics(
    String home,
    String away,
    String market,
    String outcome,
  ) {
    return '$home contre $away, $market, $outcome';
  }

  @override
  String gameShareMarketSelection(String market, String selection) {
    return '$market · $selection';
  }

  @override
  String get gameCurrentlySelectedShareCard =>
      'Carte à partager actuellement sélectionnée';

  @override
  String get gameSelectThisShareCard => 'Sélectionner cette carte à partager';

  @override
  String get gamePredictionPickCancelled => 'Pronostic annulé.';

  @override
  String get gamePredictionSummaryCopied =>
      'Résumé de l’activité copié dans le presse-papiers.';

  @override
  String get gamePredictionScorePending => 'en attente';

  @override
  String gamePredictionSummaryClipboard(
    String home,
    String away,
    String market,
    String outcome,
    String score,
  ) {
    return '$home contre $away · $market · $outcome · $score';
  }

  @override
  String get gamePredictionStatusWon => 'Gagné';

  @override
  String get gamePredictionStatusLost => 'Perdu';

  @override
  String get gamePredictionStatusCancelled => 'Annulé';

  @override
  String get gamePredictionStatusVoid => 'Invalidé';

  @override
  String get gamePredictionStatusPending => 'En attente';

  @override
  String get gamePredictionDateTbd => 'À confirmer';

  @override
  String gamePredictionDateTime(String date, String time) {
    return '$date • $time';
  }

  @override
  String gamePredictionWonSettlement(int count) {
    return 'Ce pronostic a été validé et $count points ont été crédités.';
  }

  @override
  String get gamePredictionLostSettlement =>
      'Ce pronostic n’a pas été validé en votre faveur.';

  @override
  String gamePredictionOfficialOutcomeMessage(String outcome) {
    return 'Résultat officiel : $outcome.';
  }

  @override
  String get gamePredictionCancelledSettlement =>
      'Ce pronostic a été annulé avant le verrouillage du match.';

  @override
  String get gamePredictionVoidSettlement =>
      'Ce pronostic a été invalidé et aucun point n’a été attribué.';

  @override
  String get gamePredictionPendingSettlement =>
      'Ce pronostic est verrouillé et sera validé à l’arrivée des résultats officiels.';

  @override
  String get gamePredictionActivityNotFound => 'Activité introuvable';

  @override
  String get gamePredictionActivityNotFoundDescription =>
      'Ce pronostic peut être terminé, supprimé ou ne plus être accessible à votre compte.';

  @override
  String get gamePredictionBackToPredictions => 'Retour aux pronostics';

  @override
  String get gamePredictionCancellingPick => 'Annulation du pronostic';

  @override
  String get gamePredictionRefreshingActivity => 'Actualisation de l’activité';

  @override
  String get gamePredictionConfirmedPickVisible =>
      'Le pronostic confirmé reste visible pendant la vérification de son statut.';

  @override
  String get gamePredictionActionsUnavailable => 'Actions indisponibles';

  @override
  String get gamePredictionCancellationDisabled =>
      'Vous pouvez consulter ce pronostic, mais son annulation est désactivée dans cette version.';

  @override
  String get gamePredictionShowingSavedActivity =>
      'Affichage de l’activité enregistrée';

  @override
  String get gamePredictionReconnectBeforeCancelling =>
      'Reconnectez-vous et actualisez avant d’annuler ce pronostic.';

  @override
  String get gamePredictionActivityDetailTitle => 'Détail de l’activité';

  @override
  String gamePredictionShortTeams(String home, String away) {
    return '$home  •  $away';
  }

  @override
  String get gamePredictionVenueTbc => 'Lieu à confirmer';

  @override
  String get gamePredictionPickType => 'Type de pronostic';

  @override
  String get gamePredictionSelection => 'Sélection';

  @override
  String get gamePredictionEarned => 'Gagné';

  @override
  String get gamePredictionPotential => 'Potentiel';

  @override
  String gamePredictionPositiveValue(int count) {
    return '+$count';
  }

  @override
  String get gamePredictionSettlement => 'Validation';

  @override
  String get gamePredictionPlaced => 'Enregistré';

  @override
  String get gamePredictionKickoff => 'Coup d’envoi';

  @override
  String get gamePredictionSettled => 'Validé';

  @override
  String get gamePredictionOfficialOutcome => 'Résultat officiel';

  @override
  String get gamePredictionCancelPick => 'Annuler le pronostic';

  @override
  String get gamePredictionCopyResult => 'Copier le résultat';

  @override
  String get gamePredictionCopySummary => 'Copier le résumé';

  @override
  String get gamePredictionShareCard => 'Partager la carte';

  @override
  String get gamePredictionBrowseFixtures => 'Parcourir les matchs';

  @override
  String get gamePredictionRefreshActivity => 'Actualiser l’activité';

  @override
  String get gamePredictionConnectionRestored => 'Connexion rétablie';

  @override
  String get gamePredictionDetailsOffline => 'Détails hors connexion';

  @override
  String get gamePredictionRefreshBeforeCancelling =>
      'Actualisez pour confirmer le pronostic avant de l’annuler.';

  @override
  String get gamePredictionReconnectToConfirm =>
      'Reconnectez-vous pour confirmer le pronostic avant de l’annuler.';

  @override
  String get gamePredictionAccessUnavailable =>
      'Accès à l’activité indisponible';

  @override
  String get gamePredictionAccessUnavailableDescription =>
      'Votre compte actuel ne peut ni consulter ni modifier cette activité.';

  @override
  String get gamePredictionDataChanged => 'Données de l’activité modifiées';

  @override
  String get gamePredictionDataChangedDescription =>
      'Actualisez avant de consulter le résultat ou d’annuler ce pronostic.';

  @override
  String get gamePredictionSecurityTimeout =>
      'Délai de vérification de sécurité dépassé';

  @override
  String get gamePredictionSecurityTimeoutDescription =>
      'Aucune annulation n’a été confirmée. Actualisez avant de réessayer.';

  @override
  String get gamePredictionUnavailable => 'Activité indisponible';

  @override
  String get gamePredictionUnavailableDescription =>
      'Les derniers détails du pronostic n’ont pas pu être confirmés. Actualisez pour réessayer.';

  @override
  String gamePredictionSelectedMetricSemantics(String label, String value) {
    return '$label $value, sélectionné';
  }

  @override
  String gamePredictionMetricSemantics(String label, String value) {
    return '$label $value';
  }

  @override
  String get gameMatchTitle => 'Match';

  @override
  String get gameBackToFanZoneTitleCase => 'Retour à la Fan Zone';

  @override
  String get gameMatchNotFound => 'Match introuvable';

  @override
  String get gameMatchNotFoundDescription =>
      'Ce match peut être terminé, supprimé ou ne plus être disponible.';

  @override
  String get gameWeekdayMon => 'Lun';

  @override
  String get gameWeekdayTue => 'Mar';

  @override
  String get gameWeekdayWed => 'Mer';

  @override
  String get gameWeekdayThu => 'Jeu';

  @override
  String get gameWeekdayFri => 'Ven';

  @override
  String get gameWeekdaySat => 'Sam';

  @override
  String get gameWeekdaySun => 'Dim';

  @override
  String get gameMonthJan => 'Jan';

  @override
  String get gameMonthFeb => 'Fév';

  @override
  String get gameMonthMar => 'Mar';

  @override
  String get gameMonthApr => 'Avr';

  @override
  String get gameMonthMay => 'Mai';

  @override
  String get gameMonthJun => 'Juin';

  @override
  String get gameMonthJul => 'Juil';

  @override
  String get gameMonthAug => 'Aoû';

  @override
  String get gameMonthSep => 'Sep';

  @override
  String get gameMonthOct => 'Oct';

  @override
  String get gameMonthNov => 'Nov';

  @override
  String get gameMonthDec => 'Déc';

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
  String get gameH2hTab => 'Face-à-face';

  @override
  String get gameLineupsTab => 'Compositions';

  @override
  String gameMatchTeamsVs(String home, String away) {
    return '$home contre $away';
  }

  @override
  String get gamePartnerPoolsTooltip => 'Pools partenaires';

  @override
  String get gameJoiningPartnerPool => 'Participation au pool partenaire';

  @override
  String get gameRefreshingMatch => 'Actualisation du match';

  @override
  String get gameConfirmedMatchVisible =>
      'Le match confirmé reste visible pendant la vérification de son état.';

  @override
  String get gameMatchActionsUnavailable => 'Actions du match indisponibles';

  @override
  String get gameMatchActionsUnavailableDescription =>
      'Vous pouvez consulter ce match, mais la participation aux pools partenaires est désactivée dans cette version.';

  @override
  String get gameShowingSavedMatch => 'Affichage du match enregistré';

  @override
  String get gameReconnectBeforePartnerPool =>
      'Reconnectez-vous et actualisez avant de rejoindre un pool partenaire.';

  @override
  String get gameVsUpper => 'VS';

  @override
  String get gamePartnerOutcomeHomeWin => 'Victoire à domicile';

  @override
  String get gamePartnerOutcomeDraw => 'Match nul';

  @override
  String get gamePartnerOutcomeAwayWin => 'Victoire à l’extérieur';

  @override
  String get gamePartnerOutcomeUnknown => 'Inconnu';

  @override
  String get gamePartnerEarnRequired => 'Gain partenaire requis';

  @override
  String get gamePromotionEarnRequired => 'Gain promotionnel requis';

  @override
  String get gameOpenToAllFans => 'Ouvert à tous les supporters';

  @override
  String get gamePoolJoinOffline =>
      'Reconnectez-vous et actualisez avant de rejoindre ce pool.';

  @override
  String get gamePoolJoinPermissionDenied =>
      'Votre compte ne peut pas rejoindre ce pool partenaire.';

  @override
  String get gamePoolJoinConflict =>
      'Ce pool a changé ou est verrouillé. Actualisez avant de réessayer.';

  @override
  String get gamePoolJoinTimeout =>
      'Aucune participation n’a été confirmée. Actualisez avant de réessayer.';

  @override
  String get gamePoolJoinUnavailable =>
      'La participation au pool n’a pas pu être confirmée.';

  @override
  String get gameRefreshMatch => 'Actualiser le match';

  @override
  String get gameMatchConnectionRestored => 'Connexion rétablie';

  @override
  String get gameMatchDetailsOffline => 'Détails du match hors connexion';

  @override
  String get gameRefreshBeforeJoiningPool =>
      'Actualisez pour confirmer le match avant de rejoindre un pool.';

  @override
  String get gameReconnectBeforeJoiningPool =>
      'Reconnectez-vous pour confirmer le match avant de rejoindre un pool.';

  @override
  String get gameMatchAccessUnavailable => 'Accès au match indisponible';

  @override
  String get gameMatchAccessUnavailableDescription =>
      'Votre compte actuel ne peut pas consulter ce match.';

  @override
  String get gameMatchDataChanged => 'Données du match modifiées';

  @override
  String get gameMatchDataChangedDescription =>
      'Actualisez avant de rejoindre un pool ou de consulter le statut actuel.';

  @override
  String get gameMatchSecurityTimeout => 'Délai de sécurité du match dépassé';

  @override
  String get gameMatchSecurityTimeoutDescription =>
      'Aucune participation au pool n’a été confirmée. Actualisez avant de réessayer.';

  @override
  String get gameMatchUnavailable => 'Match indisponible';

  @override
  String get gameMatchUnavailableDescription =>
      'Les derniers détails du match n’ont pas pu être confirmés. Actualisez pour réessayer.';

  @override
  String get gamePartnerWdwPools => 'Pools WDW partenaires';

  @override
  String get gameNoPartnerPool => 'Aucun pool partenaire pour ce match';

  @override
  String get gameNoPartnerPoolDescription =>
      'Les pronostics de football s’ouvrent uniquement lorsqu’un partenaire crée un pool WDW à participation fixe pour ce match.';

  @override
  String get gameViewFanZone => 'Voir la Fan Zone';

  @override
  String gamePartnerPoolsOnly(String home, String away) {
    return '$home contre $away utilise uniquement des pools WDW financés par des partenaires.';
  }

  @override
  String get settingsThemePreview => 'Aperçu du thème';

  @override
  String get settingsApplyTheme => 'Appliquer';
}
