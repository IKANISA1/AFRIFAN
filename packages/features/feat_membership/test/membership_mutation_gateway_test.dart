import 'package:feat_membership/src/providers/membership_mutation_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'payment preparation sends only a selected tier, never client price or approval',
    () async {
      String? function;
      Map<String, dynamic>? parameters;
      final gateway = SupabaseMembershipMutationGateway.withInvoker((
        name, {
        params,
      }) async {
        function = name;
        parameters = params;
        return {
          'id': 'order-1',
          'club_id': 24,
          'tier': 'gold',
          'ussd_code': '*182*8*1*1000*12345#',
          'amount': 1000,
          'recipient_code': '12345',
          'country': 'RW',
        };
      });
      final result = await gateway.preparePayment(tier: ' Gold ', clubId: 24);
      expect(function, 'prepare_membership_payment_for_club');
      expect(parameters, {'p_tier': 'gold', 'p_expected_club_id': 24});
      expect(result['amount'], 1000);
    },
  );
  test('zero-price responses cannot start membership payment', () async {
    final gateway = SupabaseMembershipMutationGateway.withInvoker(
      (name, {params}) async => {
        'amount': 0,
        'recipient_code': '12345',
        'country': 'RW',
      },
    );
    await expectLater(
      gateway.preparePayment(tier: 'gold', clubId: 24),
      throwsStateError,
    );
  });
  test('blank tier is rejected before a network request', () async {
    var calls = 0;
    final gateway = SupabaseMembershipMutationGateway.withInvoker((
      name, {
      params,
    }) async {
      calls++;
      return <String, dynamic>{};
    });
    await expectLater(
      gateway.preparePayment(tier: ' ', clubId: 24),
      throwsArgumentError,
    );
    expect(calls, 0);
  });
}
