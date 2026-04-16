import 'package:core_utils/core_utils.dart';
import 'package:core_utils/core_utils.dart' as jh;

/// Universal BioPay profile — white-label, country-agnostic.
///
/// The payment route type is generic (not MoMo-specific):
/// - `phoneNumber`: mobile money number (MoMo, M-Pesa, etc.)
/// - `code`: merchant/agent code
class BioPayProfile {
  const BioPayProfile({
    required this.id,
    required this.publicId,
    required this.userId,
    required this.displayName,
    required this.routeType,
    required this.recipientValue,
    required this.countryCode,
    required this.active,
    required this.consentVersion,
    this.consentAt,
    this.createdAt,
    this.updatedAt,
    this.revokedAt,
  });

  final String id;
  final String publicId;
  final String userId;
  final String displayName;
  final PaymentRecipientType routeType;
  final String recipientValue;
  final String countryCode;
  final bool active;
  final String consentVersion;
  final DateTime? consentAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? revokedAt;

  String get routeLabel => switch (routeType) {
    PaymentRecipientType.phoneNumber => 'Mobile money number',
    PaymentRecipientType.code => 'Merchant code',
  };

  String get publicAlias {
    final preferred = publicId.trim();
    if (preferred.isNotEmpty) return preferred;
    return displayName.trim();
  }

  String get formattedAlias =>
      publicAlias.isEmpty ? '000-000' : jh.AliasGenerator.format(publicAlias);

  String get maskedRecipientValue {
    final trimmed = recipientValue.trim();
    if (trimmed.length <= 4) return trimmed;
    final prefixLength = trimmed.length >= 9 ? 3 : 2;
    final suffixLength = trimmed.length >= 9 ? 3 : 2;
    return '${trimmed.substring(0, prefixLength)}•••${trimmed.substring(trimmed.length - suffixLength)}';
  }

  /// Resolve the country from the catalog.
  AfriCountry get country =>
      AfriCountryCatalog.byIsoCode(countryCode) ??
      AfriCountryCatalog.defaultCountry;

  factory BioPayProfile.fromJson(Map<String, dynamic> json) {
    return BioPayProfile(
      id: jh.asStringOrNull(json['id']) ?? '',
      publicId: jh.asStringOrNull(json['public_id']) ?? '',
      userId: jh.asStringOrNull(json['user_id']) ?? '',
      displayName:
          jh.asStringOrNull(json['display_name']) ??
          jh.asStringOrNull(json['public_id']) ??
          '',
      routeType: _parseRouteType(json['route_type']),
      recipientValue: jh.asStringOrNull(json['recipient_value']) ?? '',
      countryCode:
          jh.asStringOrNull(json['country_code']) ??
          AfriCountryCatalog.defaultCountry.isoCode,
      active: jh.asBool(json['active']),
      consentVersion: jh.asStringOrNull(json['consent_version']) ?? 'BioPay-v1',
      consentAt: jh.parseDateTime(json['consent_at']),
      createdAt: jh.parseDateTime(json['created_at']),
      updatedAt: jh.parseDateTime(json['updated_at']),
      revokedAt: jh.parseDateTime(json['revoked_at']),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'public_id': publicId,
      'user_id': userId,
      'display_name': displayName,
      'route_type': _serializeRouteType(routeType),
      'recipient_value': recipientValue,
      'country_code': countryCode,
      'active': active,
      'consent_version': consentVersion,
      'consent_at': consentAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'revoked_at': revokedAt?.toIso8601String(),
    };
  }

  static PaymentRecipientType _parseRouteType(Object? value) {
    return switch (value?.toString()) {
      'code' => PaymentRecipientType.code,
      _ => PaymentRecipientType.phoneNumber,
    };
  }

  static String _serializeRouteType(PaymentRecipientType value) {
    return switch (value) {
      PaymentRecipientType.phoneNumber => 'phone_number',
      PaymentRecipientType.code => 'code',
    };
  }
}
