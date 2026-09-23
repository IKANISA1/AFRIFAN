import 'package:url_launcher/url_launcher.dart';

/// MOMO USSD dialer — builds and launches USSD strings.
///
/// Supports MTN (*182*), Airtel (*185*), Orange (*144*) across Africa.
class MomoDialer {
  /// Build the USSD string from template.
  ///
  /// Template: '*182*8*1*{amount}*{momo}#'
  /// Replaces {amount} and {momo} with actual values.
  static String buildUssd({
    required String template,
    required int amount,
    required String momoNumber,
  }) {
    return template
        .replaceAll('{amount}', amount.toString())
        .replaceAll('{momo}', momoNumber);
  }

  /// Launch USSD via tel: URI.
  /// On Android, this opens the dialer with the USSD code.
  static Future<bool> dial({
    required String template,
    required int amount,
    required String momoNumber,
  }) async {
    final ussd = buildUssd(
      template: template,
      amount: amount,
      momoNumber: momoNumber,
    );

    // Encode # as %23 for URI
    final encoded = ussd.replaceAll('#', '%23');
    final uri = Uri.parse('tel:$encoded');

    if (await canLaunchUrl(uri)) {
      return launchUrl(uri);
    }
    return false;
  }
}
