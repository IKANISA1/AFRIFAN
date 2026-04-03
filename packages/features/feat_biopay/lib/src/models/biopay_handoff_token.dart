import 'package:core_utils/core_utils.dart' as jh;

import 'biopay_money.dart';

class BiopayHandoffToken {
  const BiopayHandoffToken({
    required this.token,
    required this.resolverUrl,
    required this.expiresAt,
    required this.channel,
    required this.displayName,
    required this.publicId,
    this.amount,
    this.reference,
    this.countryCode,
    this.currencyCode,
    this.currencySymbol,
    this.paymentMethod,
    this.senderName,
  });

  factory BiopayHandoffToken.fromApiResponse(Map<String, dynamic> data) {
    return BiopayHandoffToken(
      token: data['token']?.toString() ?? '',
      resolverUrl: Uri.parse(data['resolver_url']?.toString() ?? ''),
      expiresAt:
          DateTime.tryParse(data['expires_at']?.toString() ?? '') ??
          DateTime.now(),
      channel: data['channel']?.toString() ?? 'qr',
      displayName: data['display_name']?.toString() ?? '',
      publicId: data['public_id']?.toString() ?? '',
      amount: data['amount'] is num ? (data['amount'] as num).toInt() : null,
      reference: data['reference']?.toString(),
      countryCode: data['country_code']?.toString(),
      currencyCode: data['currency_code']?.toString(),
      currencySymbol: data['currency_symbol']?.toString(),
      paymentMethod: data['payment_method']?.toString(),
      senderName: data['sender_name']?.toString(),
    );
  }

  final String token;
  final Uri resolverUrl;
  final DateTime expiresAt;
  final String channel;
  final String displayName;
  final String publicId;
  final int? amount;
  final String? reference;
  final String? countryCode;
  final String? currencyCode;
  final String? currencySymbol;
  final String? paymentMethod;
  final String? senderName;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  String get formattedAlias =>
      publicId.trim().isEmpty ? '000-000' : jh.AliasGenerator.format(publicId);

  String? get formattedAmount => amount == null
      ? null
      : formatBiopayAmount(
          amount: amount!,
          currencySymbol: currencySymbol,
          currencyCode: currencyCode,
        );
}
