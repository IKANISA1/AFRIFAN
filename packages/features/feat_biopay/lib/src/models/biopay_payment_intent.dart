import 'package:core_utils/core_utils.dart' as jh;

import 'biopay_money.dart';

/// Server-issued, time-limited, one-time-use payment intent
/// that binds a biometric match to a specific payment action.
///
/// White-label: stores `paymentCode` (not USSD-specific) so that
/// non-USSD payment methods (deep links, bank transfers) work too.
class BiopayPaymentIntent {
  const BiopayPaymentIntent({
    required this.intentId,
    required this.nonce,
    required this.paymentCode,
    required this.expiresAt,
    required this.displayName,
    this.publicId,
    this.recipientValue,
    this.routeType,
    this.amount,
    this.paymentMethod,
    this.countryCode,
    this.currencyCode,
    this.currencySymbol,
    this.senderName,
  });

  factory BiopayPaymentIntent.fromApiResponse(Map<String, dynamic> data) {
    return BiopayPaymentIntent(
      intentId: data['intent_id']?.toString() ?? '',
      nonce: data['nonce']?.toString() ?? '',
      paymentCode:
          data['ussd_code']?.toString() ??
          data['payment_code']?.toString() ??
          '',
      expiresAt:
          DateTime.tryParse(data['expires_at']?.toString() ?? '') ??
          DateTime.now(),
      displayName: data['display_name']?.toString() ?? '',
      publicId: data['public_id']?.toString(),
      recipientValue: data['recipient_value']?.toString(),
      routeType: data['route_type']?.toString(),
      amount: data['amount'] is num ? (data['amount'] as num).toInt() : null,
      paymentMethod: data['payment_method']?.toString(),
      countryCode: data['country_code']?.toString(),
      currencyCode: data['currency_code']?.toString(),
      currencySymbol: data['currency_symbol']?.toString(),
      senderName: data['sender_name']?.toString(),
    );
  }

  final String intentId;
  final String nonce;

  /// The payment execution code. For USSD: a USSD string. For deep links: a URL.
  final String paymentCode;
  final DateTime expiresAt;
  final String displayName;
  final String? publicId;
  final String? recipientValue;
  final String? routeType;
  final int? amount;

  /// Optional: the payment method hint (e.g., 'ussd_dial', 'deep_link').
  final String? paymentMethod;
  final String? countryCode;
  final String? currencyCode;
  final String? currencySymbol;
  final String? senderName;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Build the tel: URI for dialing the payment code (USSD mode).
  Uri get dialUri => Uri.parse('tel:${paymentCode.replaceAll('#', '%23')}');

  /// Build the launch URI based on payment method.
  Uri get launchUri {
    if (paymentMethod == 'deep_link') {
      return Uri.parse(paymentCode);
    }
    return dialUri;
  }

  String get formattedAlias {
    final raw = publicId?.trim() ?? '';
    if (raw.isEmpty) return '000-000';
    return jh.AliasGenerator.format(raw);
  }

  String get maskedRecipientValue {
    final trimmed = recipientValue?.trim() ?? '';
    if (trimmed.length <= 4) return trimmed;
    final prefixLength = trimmed.length >= 9 ? 3 : 2;
    final suffixLength = trimmed.length >= 9 ? 3 : 2;
    return '${trimmed.substring(0, prefixLength)}•••${trimmed.substring(trimmed.length - suffixLength)}';
  }

  String? get formattedAmount => amount == null
      ? null
      : formatBiopayAmount(
          amount: amount!,
          currencySymbol: currencySymbol,
          currencyCode: currencyCode,
        );
}
