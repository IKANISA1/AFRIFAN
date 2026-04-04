/// White-label country catalog for AfriClub.
///
/// Supports multi-country MoMo USSD dialing, phone validation, and
/// merchant code payments. Each club injects its supported countries
/// via ClubConfig; the catalog provides the validation + normalization.
library;

import 'country_data.dart';

/// Payment recipient route type.
enum PaymentRecipientType { phoneNumber, code }

/// A supported country with MoMo USSD templates and phone validation.
class AfriCountry {
  const AfriCountry({
    required this.isoCode,
    required this.dialCode,
    required this.name,
    required this.flagEmoji,
    required this.currencyCode,
    required this.currencyName,
    required this.momoUssdTemplate,
    this.momoCodeUssdTemplate,
    this.providerIdValue,
    this.aliases = const <String>[],
    this.providerAliases = const <String>[],
    this.mobileNationalNumberPattern,
    this.mobilePossibleLengths = const <int>[],
    this.mobileExampleNational,
    this.mobileExampleE164,
    this.momoNumberLocalPattern,
    this.momoNumberE164Pattern,
    this.momoNumberUssdRegex,
    this.momoNumberUssdExample,
    this.momoCodeKind,
    this.momoCodePattern,
    this.momoCodeMinLength,
    this.momoCodeMaxLength,
    this.momoCodeExample,
    this.momoCodeUssdRegex,
    this.momoCodeUssdExample,
    this.phoneValidationSource,
    this.momoUssdSource,
    this.validationNotes,
  });

  final String isoCode;
  final String dialCode;
  final String name;
  final String flagEmoji;
  final String currencyCode;
  final String currencyName;
  final String momoUssdTemplate;
  final String? momoCodeUssdTemplate;
  final String? providerIdValue;
  final List<String> aliases;
  final List<String> providerAliases;
  final String? mobileNationalNumberPattern;
  final List<int> mobilePossibleLengths;
  final String? mobileExampleNational;
  final String? mobileExampleE164;
  final String? momoNumberLocalPattern;
  final String? momoNumberE164Pattern;
  final String? momoNumberUssdRegex;
  final String? momoNumberUssdExample;
  final String? momoCodeKind;
  final String? momoCodePattern;
  final int? momoCodeMinLength;
  final int? momoCodeMaxLength;
  final String? momoCodeExample;
  final String? momoCodeUssdRegex;
  final String? momoCodeUssdExample;
  final String? phoneValidationSource;
  final String? momoUssdSource;
  final String? validationNotes;

  String get providerId => providerIdValue ?? 'momo_${isoCode.toLowerCase()}';
  String get displayName => '$flagEmoji $name';
  String get pickerLabel => '$flagEmoji  $name  $dialCode';
  String get routeSummary => '$currencyCode · $dialCode';
  bool get supportsMomoCode => (momoCodeUssdTemplate ?? '').trim().isNotEmpty;

  factory AfriCountry.fromJson(Map<String, dynamic> json) {
    return AfriCountry(
      isoCode: json['iso_code']?.toString() ?? '',
      dialCode: json['dial_code']?.toString() ?? '',
      name:
          json['country_name']?.toString() ??
          json['name']?.toString() ??
          json['display_name']?.toString() ??
          '',
      flagEmoji: json['flag_emoji']?.toString() ?? '',
      currencyCode: json['currency_code']?.toString() ?? '',
      currencyName: json['currency_name']?.toString() ?? '',
      providerIdValue:
          json['momo_provider_id']?.toString() ??
          json['provider_id']?.toString(),
      momoUssdTemplate:
          json['momo_number_ussd_template']?.toString() ??
          json['momo_ussd_template']?.toString() ??
          '',
      momoCodeUssdTemplate: _nullIfEmpty(json['momo_code_ussd_template']),
      aliases: _asStringList(json['country_aliases']),
      providerAliases: _asStringList(json['momo_provider_aliases']),
      mobileNationalNumberPattern: json['mobile_national_number_pattern']
          ?.toString(),
      mobilePossibleLengths: _asIntList(json['mobile_possible_lengths']),
      mobileExampleNational: json['mobile_example_national']?.toString(),
      mobileExampleE164: json['mobile_example_e164']?.toString(),
      momoNumberLocalPattern: json['momo_number_local_pattern']?.toString(),
      momoNumberE164Pattern: json['momo_number_e164_pattern']?.toString(),
      momoNumberUssdRegex: json['momo_number_ussd_regex']?.toString(),
      momoNumberUssdExample: json['momo_number_ussd_example']?.toString(),
      momoCodeKind: json['momo_code_kind']?.toString(),
      momoCodePattern: json['momo_code_pattern']?.toString(),
      momoCodeMinLength: _asIntOrNull(json['momo_code_min_length']),
      momoCodeMaxLength: _asIntOrNull(json['momo_code_max_length']),
      momoCodeExample: json['momo_code_example']?.toString(),
      momoCodeUssdRegex: json['momo_code_ussd_regex']?.toString(),
      momoCodeUssdExample: json['momo_code_ussd_example']?.toString(),
      phoneValidationSource: json['phone_validation_source']?.toString(),
      momoUssdSource: json['momo_ussd_source']?.toString(),
      validationNotes: json['validation_notes']?.toString(),
    );
  }

  // ─── USSD Builder ─────────────────────────────────────────────

  /// Build a complete USSD code for this country and recipient type.
  String buildUssdCode({
    required String recipientMomo,
    int? amount,
    PaymentRecipientType recipientType = PaymentRecipientType.phoneNumber,
  }) {
    final template = switch (recipientType) {
      PaymentRecipientType.phoneNumber => momoUssdTemplate,
      PaymentRecipientType.code => momoCodeUssdTemplate,
    };

    if (template == null || template.trim().isEmpty) {
      throw UnsupportedError(
        'No USSD template configured for $recipientType in $isoCode.',
      );
    }

    final recipient = switch (recipientType) {
      PaymentRecipientType.phoneNumber => normalizeLocalPhone(recipientMomo),
      PaymentRecipientType.code => normalizeMerchantCode(recipientMomo),
    };

    var ussdCode = template
        .replaceAll('{recipient}', recipient)
        .replaceAll('{momo}', recipient)
        .replaceAll('{phone}', recipient)
        .replaceAll('{number}', recipient)
        .replaceAll('{code}', recipient)
        .replaceAll('{merchant_code}', recipient);
    if (amount != null && amount > 0) {
      ussdCode = ussdCode.replaceAll('{amount}', amount.toString());
    } else {
      ussdCode = ussdCode
          .replaceAll('*{amount}', '')
          .replaceAll('{amount}', '');
    }

    final routeRegex = switch (recipientType) {
      PaymentRecipientType.phoneNumber => momoNumberUssdRegex,
      PaymentRecipientType.code => momoCodeUssdRegex,
    };
    if (routeRegex != null &&
        routeRegex.trim().isNotEmpty &&
        !RegExp(routeRegex).hasMatch(ussdCode)) {
      throw FormatException(
        'The USSD route for $isoCode is invalid for $recipientType.',
      );
    }

    return ussdCode;
  }

  // ─── Phone Normalization ──────────────────────────────────────

  /// Strip to local digits (no leading zeros, no country code).
  String normalizeLocalPhone(String value) {
    final e164 = buildE164Phone(value);
    var digits = e164.replaceAll(RegExp(r'[^0-9]'), '');
    final dialDigits = dialCode.replaceFirst('+', '');

    if (digits.startsWith(dialDigits)) {
      digits = digits.substring(dialDigits.length);
    }
    while (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  /// National format preserving trunk zero if country uses it.
  String normalizeNationalPhone(String value) {
    final e164 = buildE164Phone(value);
    var digits = e164.replaceAll(RegExp(r'[^0-9]'), '');
    final dialDigits = dialCode.replaceFirst('+', '');

    if (digits.startsWith(dialDigits)) {
      digits = digits.substring(dialDigits.length);
    }

    final nationalExampleDigits = mobileExampleNational?.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    if (nationalExampleDigits != null && nationalExampleDigits.isNotEmpty) {
      if (nationalExampleDigits.startsWith('0')) {
        return digits.startsWith('0') ? digits : '0$digits';
      }
      while (digits.startsWith('0')) {
        digits = digits.substring(1);
      }
      return digits;
    }

    final localPattern = momoNumberLocalPattern ?? mobileNationalNumberPattern;
    if (_matchesPattern(digits, localPattern)) return digits;

    final withLeadingZero = digits.startsWith('0') ? digits : '0$digits';
    if (_matchesPattern(withLeadingZero, localPattern)) return withLeadingZero;

    return digits;
  }

  /// Normalize a merchant/agent code.
  String normalizeMerchantCode(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      throw const FormatException('Merchant code is required.');
    }
    if (!supportsMomoCode) {
      throw UnsupportedError(
        'Merchant-code payments are not configured for $isoCode.',
      );
    }
    if (momoCodePattern != null &&
        momoCodePattern!.trim().isNotEmpty &&
        !RegExp(momoCodePattern!).hasMatch(digits)) {
      throw FormatException('Enter a valid merchant code for $name.');
    }
    if (momoCodeMinLength != null && digits.length < momoCodeMinLength!) {
      throw FormatException('Merchant code is too short for $name.');
    }
    if (momoCodeMaxLength != null && digits.length > momoCodeMaxLength!) {
      throw FormatException('Merchant code is too long for $name.');
    }
    return digits;
  }

  /// Build E.164 phone from any input format.
  String buildE164Phone(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Phone number is required.');
    }

    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    final plusCandidate = '+$digits';
    final e164Pattern = momoNumberE164Pattern;
    final localPattern = momoNumberLocalPattern ?? mobileNationalNumberPattern;
    final hasValidationMetadata =
        (e164Pattern?.trim().isNotEmpty ?? false) ||
        (localPattern?.trim().isNotEmpty ?? false) ||
        mobilePossibleLengths.isNotEmpty;

    if (!hasValidationMetadata) {
      if (trimmed.startsWith('+')) return plusCandidate;
      return '$dialCode${_fallbackLocalDigits(digits, dialCode)}';
    }

    if (_matchesPattern(plusCandidate, e164Pattern)) return plusCandidate;

    final normalizedLocalDigits = _normalizedLocalDigitsForE164(digits);
    if (normalizedLocalDigits != null) {
      return '$dialCode$normalizedLocalDigits';
    }

    final dialDigits = dialCode.replaceFirst('+', '');
    if (digits.startsWith(dialDigits)) {
      final withPlus = '+$digits';
      if (_matchesPattern(withPlus, e164Pattern)) return withPlus;

      final nationalDigits = digits.substring(dialDigits.length);
      final normalizedNational = _normalizedLocalDigitsForE164(nationalDigits);
      if (normalizedNational != null) return '$dialCode$normalizedNational';
    }

    if (mobilePossibleLengths.isNotEmpty &&
        !mobilePossibleLengths.contains(digits.length)) {
      throw FormatException('Enter a valid $name mobile number.');
    }

    throw FormatException('Enter a valid $name mobile number.');
  }

  bool isValidPhoneNumber(String value) {
    try {
      buildE164Phone(value);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool isValidMerchantCode(String value) {
    try {
      normalizeMerchantCode(value);
      return true;
    } catch (_) {
      return false;
    }
  }

  String phoneExampleHint() {
    return mobileExampleNational?.trim().isNotEmpty ?? false
        ? mobileExampleNational!.trim()
        : mobileExampleE164?.trim().isNotEmpty ?? false
        ? normalizeNationalPhone(mobileExampleE164!.trim())
        : '07XXXXXXX';
  }

  String? _normalizedLocalDigitsForE164(String digits) {
    final localPattern = momoNumberLocalPattern ?? mobileNationalNumberPattern;
    if (!_matchesPattern(digits, localPattern)) return null;

    var normalized = digits;
    if (!_e164KeepsLeadingZero() && normalized.startsWith('0')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }

  bool _e164KeepsLeadingZero() {
    final exampleDigits = mobileExampleE164?.replaceAll(RegExp(r'[^0-9]'), '');
    if (exampleDigits == null || exampleDigits.isEmpty) return false;

    final dialDigits = dialCode.replaceFirst('+', '');
    if (!exampleDigits.startsWith(dialDigits) ||
        exampleDigits.length <= dialDigits.length) {
      return false;
    }
    return exampleDigits.substring(dialDigits.length).startsWith('0');
  }
}

// ─── Catalog ──────────────────────────────────────────────────────

/// Multi-country catalog. Not hardcoded to any single country.
///
/// Use [AfriCountryCatalog.withCountries] to inject club-specific entries,
/// or load from Supabase `countries` table.
abstract final class AfriCountryCatalog {
  /// Built-in catalog entries. Extend via [withCountries].
  static List<AfriCountry> _entries = List<AfriCountry>.of(builtInCountries);

  /// Inject club-specific countries (replaces built-in).
  static void withCountries(List<AfriCountry> countries) {
    _entries = countries;
  }

  /// Append additional countries to the built-in list.
  static void addCountries(List<AfriCountry> countries) {
    _entries = [..._entries, ...countries];
  }

  /// All registered countries.
  static List<AfriCountry> get all => _entries;

  /// Default country (first in catalog).
  static AfriCountry get defaultCountry => _entries.first;

  /// Lookup by ISO code or alias.
  static AfriCountry? byIsoCode(
    String? value, {
    Iterable<AfriCountry>? source,
  }) {
    final normalized = _normalizeLookup(value);
    if (normalized.isEmpty) return null;
    for (final country in source ?? _entries) {
      if (country.isoCode.toLowerCase() == normalized) return country;
      for (final alias in country.aliases) {
        if (_normalizeLookup(alias) == normalized) return country;
      }
    }
    return null;
  }

  /// Lookup by dial code (e.g. '+250').
  static AfriCountry? byDialCode(
    String? value, {
    Iterable<AfriCountry>? source,
  }) {
    if (value == null || value.trim().isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
    for (final country in source ?? _entries) {
      if (country.dialCode == digits) return country;
    }
    return null;
  }

  /// Lookup by provider ID.
  static AfriCountry? byProviderId(
    String? value, {
    Iterable<AfriCountry>? source,
  }) {
    final normalized = _normalizeLookup(value);
    if (normalized.isEmpty) return null;
    for (final country in source ?? _entries) {
      if (_normalizeLookup(country.providerId) == normalized) return country;
      for (final alias in country.providerAliases) {
        if (_normalizeLookup(alias) == normalized) return country;
      }
    }
    return null;
  }

  /// Lookup by phone number prefix.
  static AfriCountry? fromPhoneNumber(
    String? value, {
    Iterable<AfriCountry>? source,
  }) {
    if (value == null || value.trim().isEmpty) return null;
    final phone = value.startsWith('+')
        ? value
        : '+${value.replaceAll(RegExp(r'[^0-9]'), '')}';
    for (final country in source ?? _entries) {
      if (phone.startsWith(country.dialCode)) return country;
    }
    return null;
  }

  /// Multi-strategy resolve — always returns a country.
  static AfriCountry resolve({
    String? country,
    String? phone,
    String? providerId,
    Iterable<AfriCountry>? source,
  }) {
    return byIsoCode(country, source: source) ??
        byDialCode(country, source: source) ??
        byProviderId(providerId, source: source) ??
        fromPhoneNumber(phone, source: source) ??
        defaultCountry;
  }

  static String normalizeCountryCode(String? value) {
    if (value == null || value.trim().isEmpty) return defaultCountry.isoCode;
    return byIsoCode(value)?.isoCode ??
        byDialCode(value)?.isoCode ??
        fromPhoneNumber(value)?.isoCode ??
        value.trim().toUpperCase();
  }

  static String _normalizeLookup(String? value) {
    return value
            ?.toLowerCase()
            .replaceAll('&', 'and')
            .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
            .trim() ??
        '';
  }
}

// ─── Helpers ────────────────────────────────────────────────────

String _fallbackLocalDigits(String digits, String dialCode) {
  var normalized = digits;
  final dialDigits = dialCode.replaceFirst('+', '');
  if (normalized.startsWith(dialDigits)) {
    normalized = normalized.substring(dialDigits.length);
  }
  while (normalized.startsWith('0')) {
    normalized = normalized.substring(1);
  }
  return normalized;
}

bool _matchesPattern(String value, String? pattern) {
  if (pattern == null || pattern.trim().isEmpty) return false;
  return RegExp(pattern).hasMatch(value);
}

String? _nullIfEmpty(dynamic value) {
  final s = value?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Object>()
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

List<int> _asIntList(dynamic value) {
  if (value is List) {
    return value.map(_asIntOrNull).whereType<int>().toList(growable: false);
  }
  return const <int>[];
}

int? _asIntOrNull(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
