import 'package:feat_membership/src/official_membership_tiers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
