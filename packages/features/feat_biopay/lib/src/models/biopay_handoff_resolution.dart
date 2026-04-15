import 'package:core_utils/core_utils.dart' as jh;

import 'biopay_money.dart';

class BiopayHandoffResolution {
  const BiopayHandoffResolution({
    required this.displayName,
    required this.publicId,
    required this.routeType,
    required this.recipientValue,
    required this.countryCode,
    required this.paymentCode,
    required this.paymentMethod,
    required this.expiresAt,
    required this.channel,
    this.amount,
    this.reference,
    this.currencyCode,
    this.currencySymbol,
    this.senderName,
  });

  factory BiopayHandoffResolution.fromApiResponse(Map<String, dynamic> data) {
    return BiopayHandoffResolution(
      displayName: data['display_name']?.toString() ?? '',
      publicId: data['public_id']?.toString() ?? '',
      routeType: _parseRouteType(data['route_type']),
      recipientValue: data['recipient_value']?.toString() ?? '',
      countryCode:
          data['country_code']?.toString() ??
          jh.AfriCountryCatalog.defaultCountry.isoCode,
      paymentCode:
          data['payment_code']?.toString() ??
          data['ussd_code']?.toString() ??
          '',
      paymentMethod: data['payment_method']?.toString() ?? 'ussd_dial',
      expiresAt:
          DateTime.tryParse(data['expires_at']?.toString() ?? '') ??
          DateTime.now(),
      channel: data['channel']?.toString() ?? 'qr',
      amount: data['amount'] is num ? (data['amount'] as num).toInt() : null,
      reference: data['reference']?.toString(),
      currencyCode: data['currency_code']?.toString(),
      currencySymbol: data['currency_symbol']?.toString(),
      senderName: data['sender_name']?.toString(),
    );
  }

  final String displayName;
  final String publicId;
  final jh.PaymentRecipientType routeType;
  final String recipientValue;
  final String countryCode;
  final String paymentCode;
  final String paymentMethod;
  final DateTime expiresAt;
  final String channel;
  final int? amount;
  final String? reference;
  final String? currencyCode;
  final String? currencySymbol;
  final String? senderName;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  String get formattedAlias =>
      publicId.trim().isEmpty ? '000-000' : jh.AliasGenerator.format(publicId);

  String get routeLabel => switch (routeType) {
    jh.PaymentRecipientType.phoneNumber => 'Mobile money number',
    jh.PaymentRecipientType.code => 'Merchant code',
  };

  String get maskedRecipientValue {
    final trimmed = recipientValue.trim();
    if (trimmed.length <= 4) return trimmed;
    final prefixLength = trimmed.length >= 9 ? 3 : 2;
    final suffixLength = trimmed.length >= 9 ? 3 : 2;
    return '${trimmed.substring(0, prefixLength)}•••${trimmed.substring(trimmed.length - suffixLength)}';
  }

  Uri get launchUri {
    if (paymentMethod == 'deep_link') {
      return Uri.parse(paymentCode);
    }
    return Uri.parse('tel:${paymentCode.replaceAll('#', '%23')}');
  }

  String? get formattedAmount => amount == null
      ? null
      : formatBiopayAmount(
          amount: amount!,
          currencySymbol: currencySymbol,
          currencyCode: currencyCode,
        );

  static String? extractToken(String rawPayload) {
    final raw = rawPayload.trim();
    if (raw.isEmpty) return null;

    final uri = Uri.tryParse(raw);
    if (uri == null) return null;

    final token = uri.queryParameters['token']?.trim();
    if (token == null || token.isEmpty) return null;
    return token;
  }

  static jh.PaymentRecipientType _parseRouteType(Object? value) {
    return switch (value?.toString()) {
      'code' => jh.PaymentRecipientType.code,
      _ => jh.PaymentRecipientType.phoneNumber,
    };
  }
}
