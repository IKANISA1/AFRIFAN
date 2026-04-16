import 'package:core_auth/core_auth.dart';
import 'package:core_utils/core_utils.dart';

import 'models/biopay_profile.dart';

const String kBioPayUnlinkedLabel = 'Not linked';
const String kBioPayPendingSyncLabel = 'Pending sync';

String? resolveBioPayId(BioPayProfile? profile, UserProfile? user) {
  final candidates = <String?>[
    profile?.publicId,
    user?.publicUserId,
    user?.displayName,
  ];
  for (final candidate in candidates) {
    final trimmed = candidate?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}

String? resolveBioPayRouteValue(
  PaymentRecipientType routeType,
  BioPayProfile? profile,
  UserProfile? _,
) {
  final profileValue = profile?.recipientValue.trim();
  if (profile?.routeType == routeType &&
      profileValue != null &&
      profileValue.isNotEmpty) {
    return profileValue;
  }

  return null;
}

String initialBioPayRecipientValue(
  PaymentRecipientType routeType,
  BioPayProfile? profile,
  UserProfile? user,
  AfriCountry country,
) {
  final profileValue = resolveBioPayRouteValue(routeType, profile, user);
  if (profileValue != null) {
    return _normalizeRecipientForDisplay(routeType, profileValue, country);
  }

  if (routeType != PaymentRecipientType.phoneNumber) {
    return '';
  }

  final rawMomo = user?.momoNumber?.trim();
  if (rawMomo == null || rawMomo.isEmpty) {
    return '';
  }

  try {
    return country.normalizeNationalPhone(rawMomo);
  } catch (_) {
    return rawMomo;
  }
}

String? validateBioPayRecipient({
  required PaymentRecipientType routeType,
  required String value,
  required AfriCountry country,
}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return routeType == PaymentRecipientType.phoneNumber
        ? 'Enter your mobile money number.'
        : 'Enter your merchant code.';
  }

  try {
    normalizeBioPayRecipient(
      routeType: routeType,
      value: trimmed,
      country: country,
    );
    return null;
  } catch (error) {
    return error
        .toString()
        .replaceFirst('FormatException: ', '')
        .replaceFirst('Unsupported operation: ', '');
  }
}

String normalizeBioPayRecipient({
  required PaymentRecipientType routeType,
  required String value,
  required AfriCountry country,
}) {
  final trimmed = value.trim();
  return switch (routeType) {
    PaymentRecipientType.phoneNumber => country.normalizeNationalPhone(trimmed),
    PaymentRecipientType.code => country.normalizeMerchantCode(trimmed),
  };
}

String BioPayRecipientHint(
  PaymentRecipientType routeType,
  AfriCountry country,
) {
  return switch (routeType) {
    PaymentRecipientType.phoneNumber =>
      country.mobileExampleNational ?? '07XX XXX XXX',
    PaymentRecipientType.code => country.momoCodeExample ?? 'Enter code',
  };
}

String BioPayEnrollmentAlias(UserProfile? user) {
  final candidates = <String?>[user?.publicUserId, user?.displayName];
  for (final candidate in candidates) {
    final trimmed = candidate?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return 'Supporter';
}

String _normalizeRecipientForDisplay(
  PaymentRecipientType routeType,
  String rawValue,
  AfriCountry country,
) {
  try {
    return normalizeBioPayRecipient(
      routeType: routeType,
      value: rawValue,
      country: country,
    );
  } catch (_) {
    return rawValue.trim();
  }
}
