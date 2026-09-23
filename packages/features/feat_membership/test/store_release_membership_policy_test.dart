import 'package:feat_membership/src/official_membership_tiers.dart';
import 'package:feat_membership/src/providers/membership_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'runtime catalog preserves published prices and never invents missing offers',
    () {
      expect(
        publishedMembershipPackages([], allowsPaidDigital: false),
        isEmpty,
      );
      final rows = publishedMembershipPackages([
        {
          'id': 'published',
          'club_id': 24,
          'tier': 'gold',
          'title': 'Gold',
          'annual_price': 1250000,
          'benefit_scope': 'physical_membership',
          'benefits': ['Matchday programme'],
        },
        {
          'id': 'missing-price',
          'tier': 'gold',
          'benefit_scope': 'physical_membership',
        },
        {
          'id': 'digital',
          'tier': 'gold',
          'annual_price': 1000,
          'benefit_scope': 'digital_entitlement',
          'store_billing_required': true,
        },
      ], allowsPaidDigital: false);
      expect(rows, hasLength(2));
      expect(rows.first['annual_price'], 1250000);
      expect(rows.first['benefits'], ['Matchday programme']);
    },
  );
  test(
    'store-safe membership catalog contains only curated physical benefits',
    () {
      final packages = storeReleaseMembershipPackages();

      expect(packages, hasLength(officialMembershipTiers.length));
      expect(
        packages.every(
          (package) => package['digital_entitlements_included'] == false,
        ),
        isTrue,
      );
      expect(
        packages.every(
          (package) =>
              package['benefit_scope'] == 'physical_membership' &&
              package['store_billing_required'] == false,
        ),
        isTrue,
      );
      final allCopy = packages
          .expand(
            (package) => <String>[
              package['description'].toString(),
              ...List<String>.from(package['benefits'] as List),
            ],
          )
          .join(' ')
          .toLowerCase();
      expect(allCopy, isNot(contains('video')));
      expect(allCopy, isNot(contains('digital')));
      expect(allCopy, isNot(contains('insider')));
      expect(allCopy, isNot(contains('news')));
    },
  );

  test('unknown remote tier cannot enter the curated release catalog', () {
    expect(storeReleaseMembershipPackage('remote-premium-tier'), isNull);
  });
}
