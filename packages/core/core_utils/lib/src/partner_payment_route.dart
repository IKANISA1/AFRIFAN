import 'package:core_utils/core_utils.dart';

/// Partner payment route status.
enum PartnerPaymentRouteStatus {
  draft,
  active,
  inactive;

  static PartnerPaymentRouteStatus fromValue(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'active' => PartnerPaymentRouteStatus.active,
      'inactive' => PartnerPaymentRouteStatus.inactive,
      _ => PartnerPaymentRouteStatus.draft,
    };
  }
}

/// A partner's mobile money / payment route configuration.
///
/// White-label: uses [AfriCountryCatalog] for country resolution
/// and [PaymentRecipientType] for generic payment routing.
class PartnerPaymentRoute {
  const PartnerPaymentRoute({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.partnerSlug,
    required this.countryCode,
    required this.providerId,
    required this.recipientCode,
    required this.reconciliationLabel,
    required this.status,
  });

  factory PartnerPaymentRoute.fromJson(Map<String, dynamic> json) {
    return PartnerPaymentRoute(
      id: json['id']?.toString() ?? '',
      partnerId:
          json['partner_id']?.toString() ?? json['club_id']?.toString() ?? '',
      partnerName: json['partner_name']?.toString() ?? 'Partner',
      partnerSlug: json['partner_slug']?.toString() ?? '',
      countryCode: AfriCountryCatalog.normalizeCountryCode(
        json['country']?.toString(),
      ),
      providerId: json['provider']?.toString().trim() ?? '',
      recipientCode: json['recipient_code']?.toString().trim() ?? '',
      reconciliationLabel:
          json['reconciliation_label']?.toString().trim() ?? '',
      status: PartnerPaymentRouteStatus.fromValue(json['status']?.toString()),
    );
  }

  final String id;
  final String partnerId;
  final String partnerName;
  final String partnerSlug;
  final String countryCode;
  final String providerId;
  final String recipientCode;
  final String reconciliationLabel;
  final PartnerPaymentRouteStatus status;

  bool get isActive => status == PartnerPaymentRouteStatus.active;

  AfriCountry get country =>
      AfriCountryCatalog.byIsoCode(countryCode) ??
      AfriCountryCatalog.defaultCountry;

  String get providerLabel =>
      _resolveProviderLabel(providerId: providerId, country: country);

  String get payToLabel => '$providerLabel code $recipientCode';

  /// Build a USSD code for a given amount.
  String ussdCode(int amount) {
    return country.buildUssdCode(
      recipientMomo: recipientCode,
      amount: amount,
      recipientType: PaymentRecipientType.code,
    );
  }

  /// Format an amount with the country's currency.
  String amountLabel(int amount) {
    return '${_formatNumber(amount)} ${country.currencyCode}';
  }

  static String _resolveProviderLabel({
    required String providerId,
    required AfriCountry country,
  }) {
    final normalized = providerId.trim().toLowerCase();
    return switch (normalized) {
      'mtn' => 'MTN MoMo',
      'airtel' => 'Airtel Money',
      'orange' => 'Orange Money',
      'mpesa' => 'M-Pesa',
      'tigo' => 'Tigo Pesa',
      '' => '${country.name} Mobile Money',
      _ =>
        normalized == country.providerId.toLowerCase()
            ? '${country.name} Mobile Money'
            : providerId.trim(),
    };
  }

  static String _formatNumber(int value) {
    final buffer = StringBuffer();
    final str = value.toString();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
