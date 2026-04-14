import 'package:core_auth/core_auth.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_biopay/src/biopay_display_resolver.dart';
import 'package:feat_biopay/src/models/biopay_profile.dart';
import 'package:flutter_test/flutter_test.dart';

const _testCountry = AfriCountry(
  isoCode: 'RW',
  dialCode: '+250',
  name: 'Rwanda',
  flagEmoji: 'RW',
  currencyCode: 'RWF',
  currencyName: 'Rwandan Franc',
  momoUssdTemplate: '*182*1*1*{momo}*{amount}#',
  momoCodeUssdTemplate: '*182*1*1*{code}*{amount}#',
  mobileNationalNumberPattern: r'^0\d{9}$',
  momoNumberLocalPattern: r'^0\d{9}$',
  momoNumberE164Pattern: r'^\+250\d{9}$',
  mobilePossibleLengths: <int>[10],
  mobileExampleNational: '0788123456',
  mobileExampleE164: '+250788123456',
  momoCodePattern: r'^\d{6}$',
  momoCodeMinLength: 6,
  momoCodeMaxLength: 6,
  momoCodeExample: '123456',
);

void main() {
  setUpAll(() {
    AfriCountryCatalog.withCountries(const <AfriCountry>[_testCountry]);
  });

  group('resolveBiopayId', () {
    test('prefers enrolled BioPay profile id', () {
      const profile = BiopayProfile(
        id: 'profile-1',
        publicId: '483912',
        userId: 'user-1',
        displayName: 'Rayon Fan',
        routeType: PaymentRecipientType.phoneNumber,
        recipientValue: '0788123456',
        countryCode: 'RW',
        active: true,
        consentVersion: 'v1',
      );
      const user = UserProfile(id: 'user-1', clubId: '24');

      expect(resolveBiopayId(profile, user), '483912');
    });

    test('falls back to null when there is no trustworthy id to show', () {
      const user = UserProfile(id: 'user-1', clubId: '24');

      expect(resolveBiopayId(null, user), isNull);
    });
  });

  group('resolveBiopayRouteValue', () {
    test('uses the saved BioPay profile route for the matching type', () {
      const profile = BiopayProfile(
        id: 'profile-1',
        publicId: '483912',
        userId: 'user-1',
        displayName: 'Rayon Fan',
        routeType: PaymentRecipientType.phoneNumber,
        recipientValue: '0788123456',
        countryCode: 'RW',
        active: true,
        consentVersion: 'v1',
      );
      const user = UserProfile(
        id: 'user-1',
        clubId: '24',
        momoNumber: '0788123456',
      );

      expect(
        resolveBiopayRouteValue(
          PaymentRecipientType.phoneNumber,
          profile,
          user,
        ),
        '0788123456',
      );
    });

    test('does not treat linked user momo as a saved BioPay route', () {
      const user = UserProfile(
        id: 'user-1',
        clubId: '24',
        momoNumber: '0788123456',
      );

      expect(
        resolveBiopayRouteValue(PaymentRecipientType.phoneNumber, null, user),
        isNull,
      );
    });
  });

  group('enrollment defaults', () {
    test('uses the user alias or display name and never a fake numeric id', () {
      const user = UserProfile(
        id: 'user-1',
        clubId: '24',
        displayName: 'Blue Army',
      );

      expect(biopayEnrollmentAlias(user), 'Blue Army');
      expect(biopayEnrollmentAlias(null), 'Supporter');
    });

    test('keeps merchant code enrollment empty until the user enters one', () {
      const user = UserProfile(
        id: 'user-1',
        clubId: '24',
        momoNumber: '+250788123456',
      );

      expect(
        initialBiopayRecipientValue(
          PaymentRecipientType.code,
          null,
          user,
          _testCountry,
        ),
        isEmpty,
      );
    });

    test('can reuse a saved BioPay route during Face ID enrollment', () {
      const profile = BiopayProfile(
        id: 'profile-1',
        publicId: '483912',
        userId: 'user-1',
        displayName: 'Rayon Fan',
        routeType: PaymentRecipientType.phoneNumber,
        recipientValue: '+250788123456',
        countryCode: 'RW',
        active: true,
        consentVersion: 'v1',
      );

      expect(
        initialBiopayRecipientValue(
          PaymentRecipientType.phoneNumber,
          profile,
          null,
          _testCountry,
        ),
        '0788123456',
      );
    });
  });

  group('recipient validation', () {
    test('validates and normalizes mobile money numbers', () {
      expect(
        validateBiopayRecipient(
          routeType: PaymentRecipientType.phoneNumber,
          value: '0788123456',
          country: _testCountry,
        ),
        isNull,
      );
      expect(
        normalizeBiopayRecipient(
          routeType: PaymentRecipientType.phoneNumber,
          value: '+250788123456',
          country: _testCountry,
        ),
        '0788123456',
      );
    });

    test('requires a merchant code when using code routing', () {
      expect(
        validateBiopayRecipient(
          routeType: PaymentRecipientType.code,
          value: ' ',
          country: _testCountry,
        ),
        'Enter your merchant code.',
      );
    });
  });
}
