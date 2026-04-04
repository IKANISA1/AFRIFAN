/// Built-in country data for the AfriClub catalog.
///
/// Hardcoded entries for countries with verified USSD templates and
/// phone validation metadata. Additional countries can be loaded at
/// runtime via [AfriCountryCatalog.withCountries] or
/// [AfriCountryCatalog.addCountries].
library;

import 'country_catalog.dart';

/// Seed entries shipped with every build.
const List<AfriCountry> builtInCountries = <AfriCountry>[
  // Rwanda — MTN MoMo
  AfriCountry(
    isoCode: 'RW',
    dialCode: '+250',
    name: 'Rwanda',
    flagEmoji: '🇷🇼',
    currencyCode: 'RWF',
    currencyName: 'Rwandan franc',
    momoUssdTemplate: r'*182*1*1*{recipient}*{amount}#',
    momoCodeUssdTemplate: r'*182*8*1*{recipient}*{amount}#',
    aliases: <String>['Rwanda'],
    providerAliases: <String>['mtn_rwanda', 'mtn', 'mtn rwanda'],
    mobileNationalNumberPattern: r'^0?7[23589]\d{7}$',
    mobilePossibleLengths: <int>[9, 10],
    mobileExampleNational: '0781234567',
    mobileExampleE164: '+250781234567',
    momoNumberLocalPattern: r'^0?7[23589]\d{7}$',
    momoNumberE164Pattern: r'^\+2507[23589]\d{7}$',
    momoCodePattern: r'^\d{4,9}$',
    momoCodeMinLength: 4,
    momoCodeMaxLength: 9,
    momoCodeExample: '123456',
  ),
  // Uganda — MTN MoMo
  AfriCountry(
    isoCode: 'UG',
    dialCode: '+256',
    name: 'Uganda',
    flagEmoji: '🇺🇬',
    currencyCode: 'UGX',
    currencyName: 'Ugandan shilling',
    momoUssdTemplate: r'*165*1*{recipient}*{amount}#',
    aliases: <String>['Uganda'],
    providerAliases: <String>['mtn_uganda'],
    mobileNationalNumberPattern: r'^0?7[0-9]\d{7}$',
    mobilePossibleLengths: <int>[9, 10],
    mobileExampleNational: '0771234567',
    mobileExampleE164: '+256771234567',
    momoNumberLocalPattern: r'^0?7[0-9]\d{7}$',
    momoNumberE164Pattern: r'^\+2567[0-9]\d{7}$',
  ),
  // Kenya — M-Pesa
  AfriCountry(
    isoCode: 'KE',
    dialCode: '+254',
    name: 'Kenya',
    flagEmoji: '🇰🇪',
    currencyCode: 'KES',
    currencyName: 'Kenyan shilling',
    momoUssdTemplate: r'*334*{recipient}*{amount}#',
    momoCodeUssdTemplate: r'*247*{recipient}*{amount}#',
    aliases: <String>['Kenya'],
    providerAliases: <String>['mpesa_ke', 'mpesa', 'safaricom'],
    mobileNationalNumberPattern: r'^0?7[0-9]\d{7}$',
    mobilePossibleLengths: <int>[9, 10],
    mobileExampleNational: '0712345678',
    mobileExampleE164: '+254712345678',
    momoNumberLocalPattern: r'^0?7[0-9]\d{7}$',
    momoNumberE164Pattern: r'^\+2547[0-9]\d{7}$',
    momoCodePattern: r'^\d{4,10}$',
    momoCodeMinLength: 4,
    momoCodeMaxLength: 10,
    momoCodeExample: '123456',
    momoCodeKind: 'till_number',
  ),
  // Tanzania — M-Pesa / TigoPesa
  AfriCountry(
    isoCode: 'TZ',
    dialCode: '+255',
    name: 'Tanzania',
    flagEmoji: '🇹🇿',
    currencyCode: 'TZS',
    currencyName: 'Tanzanian shilling',
    momoUssdTemplate: r'*150*00*{recipient}*{amount}#',
    aliases: <String>['Tanzania'],
    providerAliases: <String>['vodacom_tz', 'mpesa_tz'],
    mobileNationalNumberPattern: r'^0?[67][0-9]\d{7}$',
    mobilePossibleLengths: <int>[9, 10],
    mobileExampleNational: '0712345678',
    mobileExampleE164: '+255712345678',
  ),
  // Ghana — MTN MoMo
  AfriCountry(
    isoCode: 'GH',
    dialCode: '+233',
    name: 'Ghana',
    flagEmoji: '🇬🇭',
    currencyCode: 'GHS',
    currencyName: 'Ghanaian cedi',
    momoUssdTemplate: r'*170*1*1*{recipient}*{amount}#',
    aliases: <String>['Ghana'],
    providerAliases: <String>['mtn_ghana'],
    mobileNationalNumberPattern: r'^0?[235][0-9]\d{7}$',
    mobilePossibleLengths: <int>[9, 10],
    mobileExampleNational: '0241234567',
    mobileExampleE164: '+233241234567',
  ),
];
