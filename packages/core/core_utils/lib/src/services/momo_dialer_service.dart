import 'dart:async';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../country_catalog.dart';

/// Generic service to format and launch Mobile Money USSD flows
/// across the entire AfriClub monorepo.
class MomoDialerService {
  /// Builds the USSD code and attempts to launch the native device dialer.
  ///
  /// Returns `true` if the dialer was successfully launched, `false` otherwise.
  static Future<bool> launchMomoUssd({
    required String recipient,
    required num amount,
    AfriCountry? country,
    PaymentRecipientType recipientType = PaymentRecipientType.phoneNumber,
  }) async {
    final activeCountry = country ?? AfriCountryCatalog.defaultCountry;

    try {
      final ussdString = activeCountry.buildUssdCode(
        recipientMomo: recipient,
        amount: amount.toInt(),
        recipientType: recipientType,
      );

      // Encode # as %23 for tel: URI schema compliance
      final telUriStr = 'tel:${ussdString.replaceAll('#', '%23')}';
      final uri = Uri.parse(telUriStr);

      if (await canLaunchUrl(uri)) {
        unawaited(HapticFeedback.lightImpact());
        return await launchUrl(uri);
      }
      return false;
    } catch (e) {
      // In a production scenario we might log this to Sentry/Crashlytics.
      return false;
    }
  }
}
