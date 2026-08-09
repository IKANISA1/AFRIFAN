import 'package:core_network/core_network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolvePushDeliveryPreference', () {
    test('retains opt-out default only when the settings row is absent', () {
      expect(resolvePushDeliveryPreference(null), isTrue);
    });

    test('honors the persisted preference exactly', () {
      expect(
        resolvePushDeliveryPreference(<String, dynamic>{'push_enabled': true}),
        isTrue,
      );
      expect(
        resolvePushDeliveryPreference(<String, dynamic>{'push_enabled': false}),
        isFalse,
      );
    });

    test('fails closed when the settings lookup failed', () {
      expect(resolvePushDeliveryPreference(null, lookupFailed: true), isFalse);
    });
  });
}
