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
  const ClubConfig();

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

  /// Currency symbol: e.g. 'RWF'
  String get currencySymbol;

  /// Club-specific color palette
  ClubColors get colors;

  /// Supabase project URL
  String get supabaseUrl;

  /// Supabase anonymous key
  String get supabaseAnonKey;

  /// Supported languages list
  List<String> get supportedLanguages;

  /// Feature flags
  bool get hasFanClubs;
  bool get hasShop;
  bool get hasTicketing;
  bool get hasChat;
  bool get hasSmsLedger;

  /// MOMO config
  MomoConfig get momo;

  /// Environment: e.g. 'production', 'staging'
  String get environment => 'production';

  /// Feature flags as a map (for dynamic checks)
  Map<String, bool> get features => {
    'fan_clubs': hasFanClubs,
    'shop': hasShop,
    'ticketing': hasTicketing,
    'chat': hasChat,
    'sms_ledger': hasSmsLedger,
  };

  /// Minimal shared fallback used in widget tests and empty-state previews.
  static ClubConfig fallback() => const _FallbackClubConfig();

  /// Enforces required `--dart-define` / `--dart-define-from-file` values.
  static String requireDefine(String value, String name) {
    if (value.trim().isEmpty) {
      throw StateError(
        '$name must be provided via --dart-define or --dart-define-from-file.',
      );
    }
    return value;
  }
}

class _FallbackClubConfig extends ClubConfig {
  const _FallbackClubConfig();

  @override
  String get clubId => 'fallback';

  @override
  String get clubName => 'AFRICLUB';

  @override
  String get appName => 'AFRICLUB';

  @override
  String get country => 'Rwanda';

  @override
  String get countryCode => 'RW';

  @override
  String get language => 'en';

  @override
  String get momoPrefix => '*182*';

  @override
  String get currency => 'RWF';

  @override
  String get currencySymbol => 'RWF';

  @override
  ClubColors get colors => const ClubColors(
    primary: Color(0xFF0038A8),
    secondary: Color(0xFF001F5C),
    accent: Color(0xFFD4A017),
    gradient: <Color>[Color(0xFF001F5C), Color(0xFF0038A8)],
  );

  @override
  String get supabaseUrl => 'https://example.supabase.co';

  @override
  String get supabaseAnonKey => 'anon';

  @override
  List<String> get supportedLanguages => const <String>['en'];

  @override
  bool get hasFanClubs => true;

  @override
  bool get hasShop => true;

  @override
  bool get hasTicketing => true;

  @override
  bool get hasChat => true;

  @override
  bool get hasSmsLedger => true;

  @override
  MomoConfig get momo => const MomoConfig(
    ussdTemplate: '*182*8*1*{amount}*{momo}#',
    senderName: 'MTN MoMo',
    countryCode: 'RW',
  );

  @override
  String get environment => 'test';
}
