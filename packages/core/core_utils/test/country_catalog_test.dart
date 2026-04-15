import 'package:core_utils/core_utils.dart';
import 'package:flutter_test/flutter_test.dart';

const _angola = AfriCountry(
  isoCode: 'AO',
  dialCode: '+244',
  name: 'Angola',
  flagEmoji: '🇦🇴',
  currencyCode: 'AOA',
  currencyName: 'Kwanza',
  momoUssdTemplate: '*000#',
);

const _rwanda = AfriCountry(
  isoCode: 'RW',
  dialCode: '+250',
  name: 'Rwanda',
  flagEmoji: '🇷🇼',
  currencyCode: 'RWF',
  currencyName: 'Rwandan Franc',
  momoUssdTemplate: '*182#',
);

const _zambia = AfriCountry(
  isoCode: 'ZM',
  dialCode: '+260',
  name: 'Zambia',
  flagEmoji: '🇿🇲',
  currencyCode: 'ZMW',
  currencyName: 'Zambian Kwacha',
  momoUssdTemplate: '*303#',
);

void main() {
  tearDown(() {
    AfriCountryCatalog.setPreferredCountryCode(null);
    AfriCountryCatalog.withCountries(const <AfriCountry>[]);
  });

  group('AfriCountryCatalog default country', () {
    test('uses the preferred country code instead of list order', () {
      AfriCountryCatalog.setPreferredCountryCode('RW');
      AfriCountryCatalog.withCountries(const <AfriCountry>[
        _angola,
        _rwanda,
        _zambia,
      ]);

      expect(AfriCountryCatalog.defaultCountry.isoCode, 'RW');
    });

    test('falls back to first entry when preferred code is unavailable', () {
      AfriCountryCatalog.setPreferredCountryCode('CD');
      AfriCountryCatalog.withCountries(const <AfriCountry>[_angola, _zambia]);

      expect(AfriCountryCatalog.defaultCountry.isoCode, 'AO');
    });

    test('normalizes blank input to the preferred runtime country', () {
      AfriCountryCatalog.setPreferredCountryCode('ZM');
      AfriCountryCatalog.withCountries(const <AfriCountry>[_angola, _zambia]);

      expect(AfriCountryCatalog.normalizeCountryCode(null), 'ZM');
      expect(AfriCountryCatalog.normalizeCountryCode(''), 'ZM');
    });
  });
}
