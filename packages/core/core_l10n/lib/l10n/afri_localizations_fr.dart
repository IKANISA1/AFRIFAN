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
}
