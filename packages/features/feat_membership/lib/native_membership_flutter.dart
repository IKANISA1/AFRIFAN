/// Optional Flutter dialer adapter. Existing membership routes are not changed.
library;

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'src/native_checkout/models.dart';
import 'src/native_checkout/ports.dart';

export 'native_membership.dart';

final class ExternalMembershipDialer implements MembershipDialer {
  const ExternalMembershipDialer({this.enabled = false});
  final bool enabled;
  @override
  Future<bool> open(String ussdCode) async {
    requireContract(
      enabled &&
          !kIsWeb &&
          [
            TargetPlatform.android,
            TargetPlatform.iOS,
          ].contains(defaultTargetPlatform),
      'dialer_disabled',
    );
    final match = RegExp(r'^\*[0-9*]+#$').stringMatch(ussdCode);
    requireContract(
      match == ussdCode && ussdCode.length <= 128,
      'invalid_instruction',
    );
    // Uri encodes # in the path; it must not become a fragment or query.
    // USSD support varies by platform/network; false is not payment evidence.
    return launchUrl(
      Uri(scheme: 'tel', path: ussdCode),
      mode: LaunchMode.externalApplication,
    );
  }
}
