import 'package:core_utils/core_utils.dart';

/// Draft payload for enrolling a face into BioPay.
class BioPayEnrollmentDraft {
  const BioPayEnrollmentDraft({
    required this.displayName,
    required this.routeType,
    required this.recipientValue,
    required this.countryCode,
    required this.consentVersion,
  });

  final String displayName;
  final PaymentRecipientType routeType;
  final String recipientValue;
  final String countryCode;
  final String consentVersion;

  /// Build the payload for the `BioPay-enroll` edge function.
  Map<String, Object?> toPayload(
    List<double> embedding, {
    Map<String, Object?>? liveness,
  }) {
    return <String, Object?>{
      'display_name': displayName,
      'route_type': switch (routeType) {
        PaymentRecipientType.phoneNumber => 'phone_number',
        PaymentRecipientType.code => 'code',
      },
      'recipient_value': recipientValue.trim(),
      'country_code': countryCode.trim().isEmpty
          ? AfriCountryCatalog.defaultCountry.isoCode
          : countryCode.trim(),
      'consent_version': consentVersion,
      'embedding': embedding,
      ...?(liveness == null ? null : <String, Object?>{'liveness': liveness}),
    };
  }
}
