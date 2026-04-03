import 'package:core_utils/core_utils.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/biopay_match_result.dart';
import '../models/biopay_payment_intent.dart';
import '../models/biopay_profile.dart';

/// Supported payment handoff methods.
enum PaymentHandoffMethod {
  /// USSD dial via tel: URI (MoMo, M-Pesa).
  ussdDial,

  /// Deep link to external payment app (Revolut, bank app).
  deepLink,

  /// Server-issued payment intent (precomputed code).
  intentDial,
}

/// Universal payment handoff service — white-label.
///
/// Supports USSD dialing (MoMo/M-Pesa), deep links (Revolut/bank),
/// and server-issued payment intents.
class BiopayPaymentHandoffService {
  const BiopayPaymentHandoffService();

  // ─── USSD Dialing ─────────────────────────────────────────

  /// Build a USSD code for the given profile's country and route type.
  String buildUssdCode({
    required PaymentRecipientType routeType,
    required String recipientValue,
    AfriCountry? country,
  }) {
    final resolvedCountry = country ?? AfriCountryCatalog.defaultCountry;
    return resolvedCountry.buildUssdCode(
      recipientMomo: recipientValue,
      recipientType: routeType,
    );
  }

  /// Build a tel: URI for dialing a USSD code.
  Uri buildDialUri({
    required PaymentRecipientType routeType,
    required String recipientValue,
    AfriCountry? country,
  }) {
    final ussd = buildUssdCode(
      routeType: routeType,
      recipientValue: recipientValue,
      country: country,
    );
    return Uri.parse('tel:${ussd.replaceAll('#', '%23')}');
  }

  /// Build a dial URI for a specific profile.
  Uri buildProfileDialUri(BiopayProfile profile) {
    return buildDialUri(
      routeType: profile.routeType,
      recipientValue: profile.recipientValue,
      country: profile.country,
    );
  }

  // ─── Payment Execution ────────────────────────────────────

  /// Initiate payment handoff for a matched profile.
  Future<bool> payProfile(BiopayProfile profile) async {
    return _launchUri(buildProfileDialUri(profile));
  }

  /// Initiate payment handoff for a match result.
  Future<bool> payMatch(BiopayMatchResult result) async {
    final profile = result.profile;
    if (profile == null) return false;
    return payProfile(profile);
  }

  /// Execute a server-issued payment intent.
  ///
  /// Supports both USSD and deep link payment methods based
  /// on the intent's paymentMethod field.
  Future<bool> payIntent(BiopayPaymentIntent intent) async {
    if (intent.isExpired) return false;
    return _launchUri(intent.launchUri);
  }

  /// Generic payment handoff — resolve method automatically.
  Future<bool> executeHandoff({
    required PaymentHandoffMethod method,
    required Uri uri,
  }) async {
    return _launchUri(uri);
  }

  // ─── URI Launcher ─────────────────────────────────────────

  Future<bool> _launchUri(Uri uri) async {
    final canLaunch = await canLaunchUrl(uri);
    if (!canLaunch) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
