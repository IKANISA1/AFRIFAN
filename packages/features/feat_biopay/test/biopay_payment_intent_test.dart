import 'package:feat_biopay/feat_biopay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BiopayPaymentIntent', () {
    late BiopayPaymentIntent intent;

    setUp(() {
      intent = BiopayPaymentIntent.fromApiResponse(<String, dynamic>{
        'intent_id': 'intent-abc',
        'nonce': 'nonce-123',
        'ussd_code': '*182*1*1*0781234567#',
        'payment_method': 'ussd_dial',
        'expires_at': '2099-12-31T23:59:59.000Z',
        'display_name': 'Test User',
        'public_id': '483912',
        'recipient_value': '0781234567',
        'route_type': 'phone_number',
        'amount': 5000,
        'currency_code': 'RWF',
        'currency_symbol': 'RWF',
        'country_code': 'RW',
      });
    });

    test('parses all fields from API response', () {
      expect(intent.intentId, 'intent-abc');
      expect(intent.nonce, 'nonce-123');
      expect(intent.paymentCode, '*182*1*1*0781234567#');
      expect(intent.paymentMethod, 'ussd_dial');
      expect(intent.displayName, 'Test User');
      expect(intent.publicId, '483912');
      expect(intent.recipientValue, '0781234567');
      expect(intent.amount, 5000);
      expect(intent.currencyCode, 'RWF');
      expect(intent.currencySymbol, 'RWF');
    });

    test('isExpired returns false for future dates', () {
      expect(intent.isExpired, false);
    });

    test('isExpired returns true for past dates', () {
      final expired = BiopayPaymentIntent.fromApiResponse(<String, dynamic>{
        'intent_id': 'exp-1',
        'nonce': 'n',
        'ussd_code': '*182#',
        'expires_at': '2020-01-01T00:00:00.000Z',
        'display_name': 'Expired',
      });
      expect(expired.isExpired, true);
    });

    test('dialUri encodes hash character for tel: URI', () {
      expect(intent.dialUri.toString(), 'tel:*182*1*1*0781234567%23');
    });

    test('launchUri returns dialUri for ussd_dial method', () {
      expect(intent.launchUri, intent.dialUri);
    });

    test('launchUri returns deep link URI for deep_link method', () {
      final deepLink = BiopayPaymentIntent.fromApiResponse(<String, dynamic>{
        'intent_id': 'dl-1',
        'nonce': 'n',
        'payment_code': 'https://pay.example.com/p/123',
        'payment_method': 'deep_link',
        'expires_at': '2099-12-31T23:59:59.000Z',
        'display_name': 'Deep',
      });
      expect(deepLink.launchUri.toString(), 'https://pay.example.com/p/123');
    });

    test('formattedAlias formats public ID as xxx-xxx', () {
      expect(intent.formattedAlias, '483-912');
    });

    test('formattedAlias returns 000-000 for empty publicId', () {
      final noId = BiopayPaymentIntent.fromApiResponse(<String, dynamic>{
        'intent_id': 'x',
        'nonce': 'n',
        'ussd_code': '*182#',
        'expires_at': '2099-12-31T23:59:59.000Z',
        'display_name': 'No ID',
      });
      expect(noId.formattedAlias, '000-000');
    });

    test('maskedRecipientValue masks middle digits', () {
      expect(intent.maskedRecipientValue, '078•••567');
    });

    test('maskedRecipientValue returns short values unmasked', () {
      final short = BiopayPaymentIntent.fromApiResponse(<String, dynamic>{
        'intent_id': 'x',
        'nonce': 'n',
        'ussd_code': '*182#',
        'expires_at': '2099-12-31T23:59:59.000Z',
        'display_name': 'Short',
        'recipient_value': '1234',
      });
      expect(short.maskedRecipientValue, '1234');
    });

    test('formattedAmount uses symbol when available', () {
      expect(intent.formattedAmount, 'RWF 5000');
    });

    test('formattedAmount falls back to currency code', () {
      final codeOnly = BiopayPaymentIntent.fromApiResponse(<String, dynamic>{
        'intent_id': 'x',
        'nonce': 'n',
        'ussd_code': '*182#',
        'expires_at': '2099-12-31T23:59:59.000Z',
        'display_name': 'Code',
        'amount': 3000,
        'currency_code': 'USD',
      });
      expect(codeOnly.formattedAmount, 'USD 3000');
    });

    test('formattedAmount returns null when amount is null', () {
      final noAmount = BiopayPaymentIntent.fromApiResponse(<String, dynamic>{
        'intent_id': 'x',
        'nonce': 'n',
        'ussd_code': '*182#',
        'expires_at': '2099-12-31T23:59:59.000Z',
        'display_name': 'No Amount',
      });
      expect(noAmount.formattedAmount, isNull);
    });

    test('prefers ussd_code over payment_code', () {
      final both = BiopayPaymentIntent.fromApiResponse(<String, dynamic>{
        'intent_id': 'x',
        'nonce': 'n',
        'ussd_code': '*182*1*1*999#',
        'payment_code': 'https://fallback.com',
        'expires_at': '2099-12-31T23:59:59.000Z',
        'display_name': 'Both',
      });
      expect(both.paymentCode, '*182*1*1*999#');
    });
  });

  group('biopayAmountInputLabel', () {
    test('returns Amount when no currency', () {
      expect(biopayAmountInputLabel(), 'Amount');
    });

    test('returns Amount when empty currency', () {
      expect(biopayAmountInputLabel(currencyCode: ''), 'Amount');
    });

    test('includes currency code when provided', () {
      expect(biopayAmountInputLabel(currencyCode: 'RWF'), 'Amount in RWF');
    });
  });

  group('formatBiopayAmount', () {
    test('uses symbol when available', () {
      expect(
        formatBiopayAmount(
          amount: 1000,
          currencySymbol: 'RWF',
          currencyCode: 'RWF',
        ),
        'RWF 1000',
      );
    });

    test('falls back to code when no symbol', () {
      expect(
        formatBiopayAmount(amount: 500, currencyCode: 'USD'),
        'USD 500',
      );
    });

    test('returns plain number when no symbol or code', () {
      expect(formatBiopayAmount(amount: 7500), '7500');
    });
  });
}
