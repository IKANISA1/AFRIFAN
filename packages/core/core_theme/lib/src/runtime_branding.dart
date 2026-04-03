class RuntimeBranding {
  RuntimeBranding._();

  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'AFRICLUB',
  );
  static const String crestAsset = String.fromEnvironment(
    'CREST_ASSET',
    defaultValue: '',
  );
  static const String homeTeamName = String.fromEnvironment(
    'HOME_TEAM_NAME',
    defaultValue: '',
  );
  static const String homeVenueName = String.fromEnvironment(
    'HOME_VENUE_NAME',
    defaultValue: 'Home Stadium',
  );
  static const String rivalTeamName = String.fromEnvironment(
    'RIVAL_TEAM_NAME',
    defaultValue: 'Rivals',
  );
  static const String primaryCompetitionName = String.fromEnvironment(
    'PRIMARY_COMPETITION_NAME',
    defaultValue: 'League Match',
  );
  static const String nfcMethodChannel = String.fromEnvironment(
    'BIOPAY_NFC_CHANNEL',
    defaultValue: 'africlub/biopay_nfc_hce',
  );

  static String get displayAppName {
    final trimmed = appName.trim();
    return trimmed.isEmpty ? 'AFRICLUB' : trimmed;
  }

  static String get displayHomeTeamName {
    final trimmed = homeTeamName.trim();
    return trimmed.isEmpty ? displayAppName : trimmed;
  }

  static String get displayHomeVenueName {
    final trimmed = homeVenueName.trim();
    return trimmed.isEmpty ? 'Home Stadium' : trimmed;
  }

  static String get displayRivalTeamName {
    final trimmed = rivalTeamName.trim();
    return trimmed.isEmpty ? 'Rivals' : trimmed;
  }

  static String get displayCompetitionName {
    final trimmed = primaryCompetitionName.trim();
    return trimmed.isEmpty ? 'League Match' : trimmed;
  }

  static String get displayCrestAsset => crestAsset.trim();

  static String get appInitials {
    final parts = displayAppName
        .split(RegExp(r'\s+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'AF';
    }
    if (parts.length == 1) {
      final token = parts.first;
      return token.length >= 2
          ? token.substring(0, 2).toUpperCase()
          : token.toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
}
