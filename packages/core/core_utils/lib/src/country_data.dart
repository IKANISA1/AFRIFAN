/// Built-in country data for the AfriClub catalog.
///
/// Hardcoded entries for countries with verified USSD templates and
/// phone validation metadata. Additional countries can be loaded at
/// runtime via [AfriCountryCatalog.withCountries] or
/// [AfriCountryCatalog.addCountries].
library;

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'country_catalog.dart';

/// Loads built-in country data from the core_utils JSON asset.
///
/// Must be called during app bootstrap, before [AfriCountryCatalog] is used.
Future<List<AfriCountry>> loadBuiltInCountries() async {
  try {
    final content = await rootBundle.loadString(
      'packages/core_utils/assets/countries.json',
    );
    final List<dynamic> jsonList = jsonDecode(content);
    return jsonList
        .map((j) => AfriCountry.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  } catch (error) {
    // Fallback if asset loading fails for any reason
    return const <AfriCountry>[];
  }
}
