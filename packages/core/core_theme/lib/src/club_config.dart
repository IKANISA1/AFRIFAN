import 'dart:ui';

/// Club-specific color palette.
/// Each club provides its own primary, secondary, accent colors.
/// Platform constants (glass, shadows, surfaces) remain fixed.
class ClubColors {
  final Color primary;
  final Color secondary;
  final Color accent;
  final List<Color> gradient;

  const ClubColors({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.gradient,
  });
}

/// MOMO mobile money configuration per club.
class MomoConfig {
  final String ussdTemplate;
  final String senderName;
  final String countryCode;

  const MomoConfig({
    required this.ussdTemplate,
    required this.senderName,
    required this.countryCode,
  });
}

/// Abstract interface that every club config package must implement.
/// This is the ONLY thing that changes per club — pure data, no logic.
abstract class ClubConfig {
  /// Unique tenant ID: e.g. 'rayon_sports_rw'
  String get clubId;

  /// Display name: e.g. 'Rayon Sports FC'
  String get clubName;

  /// Short app name: e.g. 'Rayon Sports'
  String get appName;

  /// Country full name: e.g. 'Rwanda'
  String get country;

  /// ISO 3166-1 alpha-2: e.g. 'RW'
  String get countryCode;

  /// Default language ISO 639-1: e.g. 'rw'
  String get language;

  /// MOMO USSD prefix: e.g. '*182*'
  String get momoPrefix;

  /// Currency code: e.g. 'RWF'
  String get currency;

  /// Currency symbol: e.g. 'FRw'
  String get currencySymbol;

  /// Club-specific color palette
  ClubColors get colors;

  /// Path to club crest asset
  String get crestAsset;

  /// Supabase project URL
  String get supabaseUrl;

  /// Supabase anonymous key
  String get supabaseAnonKey;

  /// Supported languages list
  List<String> get supportedLanguages;

  /// Feature flags
  bool get hasBiopay;
  bool get hasFanClubs;
  bool get hasShop;
  bool get hasTicketing;
  bool get hasChat;
  bool get hasSmsLedger;

  /// MOMO config
  MomoConfig get momo;

  /// Feature flags as a map (for dynamic checks)
  Map<String, bool> get features => {
    'biopay': hasBiopay,
    'fan_clubs': hasFanClubs,
    'shop': hasShop,
    'ticketing': hasTicketing,
    'chat': hasChat,
    'sms_ledger': hasSmsLedger,
  };
}
