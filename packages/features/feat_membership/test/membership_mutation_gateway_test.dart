import 'package:feat_membership/src/providers/membership_mutation_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('free activation calls the no-argument server boundary', () async {
    String? functionName;
    Map<String, dynamic>? parameters;
    final gateway = SupabaseMembershipMutationGateway.withInvoker((
      name, {
      params,
    }) async {
      functionName = name;
      parameters = params;
      return <String, dynamic>{'id': 'membership-1', 'tier': 'fan'};
    });

    final result = await gateway.activateFreeMembership();

    expect(functionName, 'activate_free_fan_membership');
    expect(parameters, isNull);
    expect(result['tier'], 'fan');
  });

  test(
    'paid physical application sends only the approved RPC fields',
    () async {
      String? functionName;
      Map<String, dynamic>? parameters;
      final gateway = SupabaseMembershipMutationGateway.withInvoker((
        name, {
        params,
      }) async {
        functionName = name;
        parameters = params;
        return <String, dynamic>{
          'id': 'application-1',
          'metadata': <String, dynamic>{'amount': 100000},
        };
      });

      await gateway.submitPhysicalApplication(
        tier: ' Bronze ',
        paymentReference: ' membership-ref-1 ',
        chapter: ' Kigali ',
      );

      expect(functionName, 'submit_membership_application');
      expect(parameters, <String, dynamic>{
        'p_tier': 'bronze',
        'p_payment_reference': 'membership-ref-1',
        'p_chapter': 'Kigali',
      });
      expect(
        parameters!.keys,
        unorderedEquals(<String>['p_tier', 'p_payment_reference', 'p_chapter']),
      );
    },
  );

  test('blank client authority fields are rejected before RPC', () async {
    var callCount = 0;
    final gateway = SupabaseMembershipMutationGateway.withInvoker((
      name, {
      params,
    }) async {
      callCount += 1;
      return <String, dynamic>{};
    });

    await expectLater(
      gateway.submitPhysicalApplication(
        tier: ' ',
        paymentReference: 'reference',
      ),
      throwsArgumentError,
    );
    expect(callCount, 0);
  });
}
