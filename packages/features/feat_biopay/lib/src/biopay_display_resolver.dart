import 'package:core_auth/core_auth.dart';
import 'package:core_utils/core_utils.dart';

import 'models/biopay_profile.dart';

const String kBiopayUnlinkedLabel = 'Not linked';
const String kBiopayPendingSyncLabel = 'Pending sync';

String? resolveBiopayId(BiopayProfile? profile, UserProfile? user) {
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

String? resolveBiopayRouteValue(
  PaymentRecipientType routeType,
  BiopayProfile? profile,
  UserProfile? user,
) {
  final profileValue = profile?.recipientValue.trim();
  if (profile?.routeType == routeType &&
      profileValue != null &&
      profileValue.isNotEmpty) {
    return profileValue;
  }

  if (routeType == PaymentRecipientType.phoneNumber) {
    final momo = user?.momoNumber?.trim();
    if (momo != null && momo.isNotEmpty) {
      return momo;
    }
  }

  return null;
}

String initialBiopayRecipientValue(
  PaymentRecipientType routeType,
  UserProfile? user,
  AfriCountry country,
) {
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

String biopayRecipientHint(
  PaymentRecipientType routeType,
  AfriCountry country,
) {
  return switch (routeType) {
    PaymentRecipientType.phoneNumber =>
      country.mobileExampleNational ?? '07XX XXX XXX',
    PaymentRecipientType.code => country.momoCodeExample ?? 'Enter code',
  };
}

String biopayEnrollmentAlias(UserProfile? user) {
  final candidates = <String?>[user?.publicUserId, user?.displayName];
  for (final candidate in candidates) {
    final trimmed = candidate?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return 'Supporter';
}
