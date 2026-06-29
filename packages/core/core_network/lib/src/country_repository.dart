import 'package:core_utils/core_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'safe_rpc.dart';

/// Fetches countries from [countries] Supabase table and injects
/// them into [AfriCountryCatalog] as the live source of truth.
///
/// Flow:
///   1. [loadAndInject] fetches all active countries from DB
///   2. Parses each row into [AfriCountry.fromJson]
///   3. Calls [AfriCountryCatalog.withCountries] to replace hardcoded entries
///   4. Falls back to hardcoded catalog if DB fetch fails (offline-safe)
class CountryRepository {
  CountryRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  /// In-memory cache so we don't re-fetch on every screen.
  List<AfriCountry>? _cached;
  DateTime? _cachedAt;

  /// How long the in-memory cache is valid.
  static const _cacheDuration = Duration(hours: 6);

  /// Fetch countries from Supabase and inject into AfriCountryCatalog.
  ///
  /// Returns the list of loaded countries.
  /// On failure, returns the current catalog entries (hardcoded fallback).
  Future<List<AfriCountry>> loadAndInject({bool forceRefresh = false}) async {
    // Return cached if valid and not forced
    if (!forceRefresh && _isCacheValid) {
      return _cached!;
    }

    try {
      final rows = await _client
          .from('countries')
          .select()
          .eq('is_active', true)
          .order('name', ascending: true);

      if (rows.isEmpty) {
        AfriLogger.warn(
          'CountryRepository',
          'Country DB returned an empty active catalog; using hardcoded fallback.',
        );
        return AfriCountryCatalog.all;
      }

      final countries = rows
          .map<AfriCountry?>((row) {
            try {
              return AfriCountry.fromJson(_normalizeRow(row));
            } catch (e) {
              AfriLogger.warn(
                'CountryRepository',
                'Failed to parse country row: $e',
              );
              return null;
            }
          })
          .whereType<AfriCountry>()
          .where((c) => c.isoCode.isNotEmpty && c.dialCode.isNotEmpty)
          .toList(growable: false);

      if (countries.isEmpty) {
        AfriLogger.warn(
          'CountryRepository',
          'All rows failed parsing; using hardcoded fallback.',
        );
        return AfriCountryCatalog.all;
      }

      // Inject into the global catalog
      AfriCountryCatalog.withCountries(countries);

      // Cache the result
      _cached = countries;
      _cachedAt = DateTime.now();

      AfriLogger.info(
        'CountryRepository',
        'Loaded ${countries.length} countries from DB.',
      );
      return countries;
    } catch (error, stackTrace) {
      if (SafeRpc.isTransientConnectivityError(error)) {
        AfriLogger.warn(
          'CountryRepository',
          'Country catalog unavailable; using hardcoded offline fallback.',
        );
      } else {
        AfriLogger.error(
          'CountryRepository',
          'Failed to fetch countries; using hardcoded fallback.',
          error,
          stackTrace,
        );
      }
      return AfriCountryCatalog.all;
    }
  }

  /// Get a single country by ISO code, fetching from DB if not cached.
  Future<AfriCountry?> getByIsoCode(String isoCode) async {
    await loadAndInject();
    return AfriCountryCatalog.byIsoCode(isoCode);
  }

  /// Get the country for a partner's payment route.
  Future<AfriCountry> resolveForPaymentRoute(PartnerPaymentRoute route) async {
    await loadAndInject();
    return AfriCountryCatalog.byIsoCode(route.countryCode) ??
        AfriCountryCatalog.defaultCountry;
  }

  /// Get all active countries (DB-backed, with fallback).
  Future<List<AfriCountry>> getActiveCountries() async {
    return loadAndInject();
  }

  /// Invalidate the in-memory cache.
  void clearCache() {
    _cached = null;
    _cachedAt = null;
  }

  bool get _isCacheValid {
    if (_cached == null || _cachedAt == null) return false;
    return DateTime.now().difference(_cachedAt!) < _cacheDuration;
  }

  /// Normalize Supabase row from the [countries] table.
  ///
  /// Maps column names from the `countries` table to the keys that
  /// [AfriCountry.fromJson] expects.
  static Map<String, dynamic> _normalizeRow(Map<String, dynamic> row) {
    final normalized = Map<String, dynamic>.from(row);

    // Map countries-table column names → AfriCountry.fromJson keys
    normalized['iso_code'] ??= normalized['id'];
    normalized['country_name'] ??= normalized['name'];
    normalized['flag_emoji'] ??= normalized['flag'];
    normalized['dial_code'] ??= normalized['dialing_code'];
    normalized['currency_code'] ??= normalized['currency'];
    normalized['momo_number_ussd_template'] ??=
        normalized['ussd_number_format'];
    normalized['momo_code_ussd_template'] ??= normalized['ussd_code_format'];

    return normalized;
  }
}
