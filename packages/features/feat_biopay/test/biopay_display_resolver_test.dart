import 'package:core_auth/core_auth.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_biopay/src/biopay_display_resolver.dart';
import 'package:feat_biopay/src/models/biopay_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    test('uses the linked user momo number for phone routes', () {
      const user = UserProfile(
        id: 'user-1',
        clubId: '24',
        momoNumber: '0788123456',
      );

      expect(
        resolveBiopayRouteValue(PaymentRecipientType.phoneNumber, null, user),
        '0788123456',
      );
    });

    test('does not invent merchant codes when none are configured', () {
      const user = UserProfile(id: 'user-1', clubId: '24');

      expect(
        resolveBiopayRouteValue(PaymentRecipientType.code, null, user),
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
          user,
          AfriCountryCatalog.defaultCountry,
        ),
        isEmpty,
      );
    });
  });
}
