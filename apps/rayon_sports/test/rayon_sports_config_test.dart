import 'package:club_rayon_sports/club_rayon_sports.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke tests for Rayon Sports FC configuration.
///
/// These verify that the club config is correctly defined and will not
/// cause runtime failures on app startup.
void main() {
  group('RayonSportsConfig', () {
    late RayonSportsConfig config;

    setUp(() {
      config = const RayonSportsConfig();
    });

    test('has valid club identity', () {
      expect(config.clubName, 'Rayon Sports FC');
      expect(config.appName, 'Gikundiro');
      expect(config.country, 'Rwanda');
      expect(config.countryCode, 'RW');
      expect(config.language, 'rw');
    });

    test('has valid currency configuration', () {
      expect(config.currency, 'RWF');
      expect(config.currencySymbol, 'FRw');
    });

    test('has valid color configuration', () {
      final colors = config.colors;
      expect(colors.primary, isNotNull);
      expect(colors.secondary, isNotNull);
      expect(colors.accent, isNotNull);
      expect(colors.gradient, isNotEmpty);
      expect(colors.gradient.length, greaterThanOrEqualTo(2));
    });

    test('has valid Supabase configuration', () {
      expect(config.supabaseUrl, startsWith('https://'));
      expect(config.supabaseUrl, contains('.supabase.co'));
      expect(config.supabaseAnonKey, isNotEmpty);
      expect(config.supabaseAnonKey.length, greaterThan(50));
    });

    test('has crest asset path defined', () {
      expect(config.crestAsset, 'assets/crest/rayon_sports_crest.png');
    });

    test('has supported languages', () {
      expect(config.supportedLanguages, isNotEmpty);
      expect(config.supportedLanguages, contains('rw'));
      expect(config.supportedLanguages, contains('en'));
    });

    test('has MoMo configuration', () {
      expect(config.momo.ussdTemplate, isNotEmpty);
      expect(config.momo.countryCode, 'RW');
    });

    test('features map is consistent with flags', () {
      final features = config.features;
      expect(features['biopay'], config.hasBiopay);
      expect(features['fan_clubs'], config.hasFanClubs);
      expect(features['shop'], config.hasShop);
      expect(features['ticketing'], config.hasTicketing);
      expect(features['chat'], config.hasChat);
      expect(features['sms_ledger'], config.hasSmsLedger);
    });

    test('all feature flags are boolean', () {
      for (final entry in config.features.entries) {
        expect(
          entry.value,
          isA<bool>(),
          reason: 'Feature "${entry.key}" should be a bool',
        );
      }
    });

    test('momoPrefix is valid USSD format', () {
      expect(config.momoPrefix, startsWith('*'));
    });
  });
}
