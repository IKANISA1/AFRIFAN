import 'package:feat_biopay/feat_biopay.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  group('BiopayRepository', () {
    late MockSupabaseClient client;
    late MockFunctionsClient functionsClient;
    late MockGoTrueClient authClient;
    late BiopayRepository repository;

    setUp(() {
      client = MockSupabaseClient();
      functionsClient = MockFunctionsClient();
      authClient = MockGoTrueClient();
      repository = BiopayRepository(
        client: client,
        appCheckTokenProvider: () async => 'limited-use-token',
      );

      when(() => client.functions).thenReturn(functionsClient);
      when(() => client.auth).thenReturn(authClient);
      when(() => authClient.currentUser).thenReturn(null);
      when(
        () => functionsClient.invoke(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => FunctionResponse(
          data: <String, dynamic>{
            'success': true,
            'data': <String, dynamic>{
              'intent_id': 'intent-1',
              'nonce': 'nonce-1',
              'ussd_code': '*182*1*1*0781234567#',
              'payment_code': '*182*1*1*0781234567#',
              'payment_method': 'ussd_dial',
              'expires_at': '2026-03-30T20:00:00.000Z',
              'display_name': 'Marie',
              'public_id': '483912',
              'recipient_value': '0781234567',
              'route_type': 'phone_number',
            },
          },
          status: 200,
        ),
      );
    });

    test(
      'creates payment intents with App Check headers and the server contract payload',
      () async {
        final intent = await repository.createPaymentIntent(
          matchReceipt: 'signed-match-receipt',
        );

        final captured = verify(
          () => functionsClient.invoke(
            'biopay-create-payment-intent',
            headers: captureAny(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        ).captured;

        final capturedHeaders = captured[0] as Map<dynamic, dynamic>;
        final capturedBody = captured[1] as Map<dynamic, dynamic>;

        expect(capturedHeaders, <String, String>{
          'X-Firebase-AppCheck': 'limited-use-token',
        });
        expect(capturedBody, <String, Object?>{
          'match_receipt': 'signed-match-receipt',
        });
        expect(intent.intentId, 'intent-1');
        expect(intent.paymentCode, '*182*1*1*0781234567#');
        expect(intent.paymentMethod, 'ussd_dial');
        expect(intent.formattedAlias, '483-912');
      },
    );

    test(
      'passes requested amount to payment intent creation when provided',
      () async {
        await repository.createPaymentIntent(
          matchReceipt: 'signed-match-receipt',
          amount: 6500,
        );

        final captured = verify(
          () => functionsClient.invoke(
            'biopay-create-payment-intent',
            headers: captureAny(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        ).captured;

        final capturedBody = captured[1] as Map<dynamic, dynamic>;

        expect(capturedBody, <String, Object?>{
          'match_receipt': 'signed-match-receipt',
          'amount': 6500,
        });
      },
    );
  });
}
