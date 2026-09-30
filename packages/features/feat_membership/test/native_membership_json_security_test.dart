import 'package:feat_membership/native_membership.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final text in [
    '{"clubId":25,"clubId":24}',
    r'{"clubId":25,"club\u0049d":24}',
    '{"paymentInstruction":{"amount":1,"amount":10000}}',
    r'{"\u0061":1,"a":2}',
  ]) {
    test('ambiguous raw membership JSON is rejected: $text', () {
      expect(() => decodeWire(text), throwsA(isA<NativeMembershipException>()));
    });
  }
  test('bounded parser permits separate object keys and JSON escapes', () {
    expect(decodeWire(r'[{"a":1},{"a":2,"label":"quoted \" text"}]'), [
      {'a': 1},
      {'a': 2, 'label': 'quoted " text'},
    ]);
  });
  test('deep nesting and UTF-8 overrun are denied without echoing content', () {
    for (final text in [
      '${List.filled(34, '[').join()}0${List.filled(34, ']').join()}',
      '"${List.filled(6000, '€').join()}"',
    ]) {
      try {
        decodeWire(text);
        fail('Unbounded JSON accepted');
      } on NativeMembershipException catch (error) {
        expect(error.code, 'invalid_membership_contract');
        expect(error.toString(), isNot(contains(text)));
      }
    }
  });
}
