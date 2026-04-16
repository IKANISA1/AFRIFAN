import 'package:core_utils/core_utils.dart';
import 'package:feat_biopay/feat_biopay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BioPayCacheService', () {
    test('stores and retrieves match results in memory only', () async {
      final service = BioPayCacheService();
      await service.clear();

      const profile = BioPayProfile(
        id: 'profile-1',
        publicId: '483912',
        userId: 'user-1',
        displayName: 'Marie Uwase',
        routeType: PaymentRecipientType.phoneNumber,
        recipientValue: '0781234567',
        countryCode: 'RW',
        active: true,
        consentVersion: 'BioPay-v1',
      );
      const result = BioPayMatchResult(
        match: true,
        score: 0.99,
        profile: profile,
      );

      await service.storeMatch('owner-1', const <double>[
        0.12,
        0.34,
        0.56,
      ], result);

      final cached = await service.findNearestMatch(
        const <double>[0.12, 0.34, 0.56],
        ownerUserId: 'owner-1',
        similarityThreshold: 0.95,
      );

      expect(cached, isNotNull);
      expect(cached?.profile?.id, 'profile-1');
      expect(cached?.profile?.displayName, 'Marie Uwase');
    });

    test('scopes entries to the owning user and clears by owner id', () async {
      final service = BioPayCacheService();
      await service.clear();

      const profileA = BioPayProfile(
        id: 'profile-a',
        publicId: '111111',
        userId: 'user-a',
        displayName: 'User A',
        routeType: PaymentRecipientType.phoneNumber,
        recipientValue: '0781000001',
        countryCode: 'RW',
        active: true,
        consentVersion: 'BioPay-v1',
      );
      const profileB = BioPayProfile(
        id: 'profile-b',
        publicId: '222222',
        userId: 'user-b',
        displayName: 'User B',
        routeType: PaymentRecipientType.phoneNumber,
        recipientValue: '0781000002',
        countryCode: 'RW',
        active: true,
        consentVersion: 'BioPay-v1',
      );

      await service.storeMatch('owner-a', const <double>[
        1,
        0,
        0,
      ], const BioPayMatchResult(match: true, score: 0.98, profile: profileA));
      await service.storeMatch('owner-b', const <double>[
        0,
        1,
        0,
      ], const BioPayMatchResult(match: true, score: 0.98, profile: profileB));

      await service.clear(ownerUserId: 'owner-a');

      final missing = await service.findNearestMatch(
        const <double>[1, 0, 0],
        ownerUserId: 'owner-a',
        similarityThreshold: 0.8,
      );
      final preserved = await service.findNearestMatch(
        const <double>[0, 1, 0],
        ownerUserId: 'owner-b',
        similarityThreshold: 0.8,
      );

      expect(missing, isNull);
      expect(preserved?.profile?.id, 'profile-b');
    });

    test(
      'purges legacy persistent cache through the configured deletion hook',
      () async {
        var deletedBoxName = '';
        final service = BioPayCacheService(
          deleteBox: (name) async {
            deletedBoxName = name;
          },
        );

        await service.purgeLegacyPersistentCache(force: true);

        expect(deletedBoxName, BioPayCacheService.boxName);
      },
    );
  });
}
