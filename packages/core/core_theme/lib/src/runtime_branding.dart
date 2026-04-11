class RuntimeBranding {
  RuntimeBranding._();

  static const String _defaultAppName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: '',
  );
  static const String _defaultClubName = String.fromEnvironment(
    'CLUB_NAME',
    defaultValue: '',
  );
  static const String _defaultCrestAsset = String.fromEnvironment(
    'CREST_ASSET',
    defaultValue: '',
  );
  static const String _defaultHomeTeamName = String.fromEnvironment(
    'HOME_TEAM_NAME',
    defaultValue: '',
  );
  static const String _defaultCountryCode = String.fromEnvironment(
    'COUNTRY_CODE',
    defaultValue: '',
  );
  static const String _defaultCurrencyCode = String.fromEnvironment(
    'CURRENCY_CODE',
    defaultValue: '',
  );
  static const String _defaultCurrencySymbol = String.fromEnvironment(
    'CURRENCY_SYMBOL',
    defaultValue: '',
  );
  static const String _defaultHomeVenueName = String.fromEnvironment(
    'HOME_VENUE_NAME',
    defaultValue: 'Home Stadium',
  );
  static const String _defaultRivalTeamName = String.fromEnvironment(
    'RIVAL_TEAM_NAME',
    defaultValue: 'Rivals',
  );
  static const String _defaultPrimaryCompetitionName = String.fromEnvironment(
    'PRIMARY_COMPETITION_NAME',
    defaultValue: 'League Match',
  );

  static String _appName = const String.fromEnvironment(
    'APP_NAME',
    defaultValue: '',
  );
  static String _clubName = const String.fromEnvironment(
    'CLUB_NAME',
    defaultValue: '',
  );
  static String _crestAsset = const String.fromEnvironment(
    'CREST_ASSET',
    defaultValue: '',
  );
  static String _homeTeamName = const String.fromEnvironment(
    'HOME_TEAM_NAME',
    defaultValue: '',
  );
  static String _countryCode = const String.fromEnvironment(
    'COUNTRY_CODE',
    defaultValue: '',
  );
  static String _currencyCode = const String.fromEnvironment(
    'CURRENCY_CODE',
    defaultValue: '',
  );
  static String _currencySymbol = const String.fromEnvironment(
    'CURRENCY_SYMBOL',
    defaultValue: '',
  );
  static String _homeVenueName = const String.fromEnvironment(
    'HOME_VENUE_NAME',
    defaultValue: 'Home Stadium',
  );
  static String _rivalTeamName = const String.fromEnvironment(
    'RIVAL_TEAM_NAME',
    defaultValue: 'Rivals',
  );
  static String _primaryCompetitionName = const String.fromEnvironment(
    'PRIMARY_COMPETITION_NAME',
    defaultValue: 'League Match',
  );
  static const String nfcMethodChannel = String.fromEnvironment(
    'BIOPAY_NFC_CHANNEL',
    defaultValue: 'africlub/biopay_nfc_hce',
  );

  static void configure({
    required String appName,
    required String clubName,
    String? crestAsset,
    String? countryCode,
    String? currencyCode,
    String? currencySymbol,
    String? homeTeamName,
    String? homeVenueName,
    String? rivalTeamName,
    String? primaryCompetitionName,
  }) {
    _appName = appName.trim().isEmpty ? _appName : appName;
    _clubName = clubName.trim().isEmpty ? _clubName : clubName;
    if (crestAsset != null && crestAsset.trim().isNotEmpty) {
      _crestAsset = crestAsset;
    }
    if (countryCode != null && countryCode.trim().isNotEmpty) {
      _countryCode = countryCode;
    }
    if (currencyCode != null && currencyCode.trim().isNotEmpty) {
      _currencyCode = currencyCode;
    }
    if (currencySymbol != null && currencySymbol.trim().isNotEmpty) {
      _currencySymbol = currencySymbol;
    }
    if (homeTeamName != null && homeTeamName.trim().isNotEmpty) {
      _homeTeamName = homeTeamName;
    }
    if (homeVenueName != null && homeVenueName.trim().isNotEmpty) {
      _homeVenueName = homeVenueName;
    }
    if (rivalTeamName != null && rivalTeamName.trim().isNotEmpty) {
      _rivalTeamName = rivalTeamName;
    }
    if (primaryCompetitionName != null &&
        primaryCompetitionName.trim().isNotEmpty) {
      _primaryCompetitionName = primaryCompetitionName;
    }
  }

  static void resetForTest() {
    _appName = _defaultAppName;
    _clubName = _defaultClubName;
    _crestAsset = _defaultCrestAsset;
    _homeTeamName = _defaultHomeTeamName;
    _countryCode = _defaultCountryCode;
    _currencyCode = _defaultCurrencyCode;
    _currencySymbol = _defaultCurrencySymbol;
    _homeVenueName = _defaultHomeVenueName;
    _rivalTeamName = _defaultRivalTeamName;
    _primaryCompetitionName = _defaultPrimaryCompetitionName;
  }

  static String get displayAppName {
    final trimmed = _appName.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }

    return _clubName.trim();
  }

  static String get displayClubName {
    final trimmed = _clubName.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }

    return _appName.trim();
  }

  static String get displayHomeTeamName {
    final trimmed = _homeTeamName.trim();
    return trimmed.isEmpty ? displayClubName : trimmed;
  }

  static String get displayHomeVenueName {
    final trimmed = _homeVenueName.trim();
    return trimmed.isEmpty ? 'Home Stadium' : trimmed;
  }

  static String get displayRivalTeamName {
    final trimmed = _rivalTeamName.trim();
    return trimmed.isEmpty ? 'Rivals' : trimmed;
  }

  static String get displayCompetitionName {
    final trimmed = _primaryCompetitionName.trim();
    return trimmed.isEmpty ? 'League Match' : trimmed;
  }

  static String get displayCountryCode => _countryCode.trim().toUpperCase();

  static String get displayCurrencyCode {
    final trimmed = _currencyCode.trim().toUpperCase();
    return trimmed.isEmpty ? 'RWF' : trimmed;
  }

  static String get displayCurrencySymbol {
    final trimmed = _currencySymbol.trim();
    return trimmed.isEmpty ? displayCurrencyCode : trimmed;
  }

  static String get displayCrestAsset => _crestAsset.trim();

  static String get appInitials {
    final source = displayAppName.trim().isNotEmpty
        ? displayAppName
        : displayClubName;
    final parts = source
        .split(RegExp(r'\s+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return '';
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
