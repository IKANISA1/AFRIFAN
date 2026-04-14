import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

abstract final class AppLinks {
  static const supportWhatsApp = String.fromEnvironment(
    'APP_SUPPORT_WHATSAPP',
    defaultValue: '',
  );

  static const supportEmail = String.fromEnvironment(
    'APP_SUPPORT_EMAIL',
    defaultValue: '',
  );

  static const websiteUrl = String.fromEnvironment(
    'APP_WEBSITE_URL',
    defaultValue: '',
  );

  static const privacyPolicyUrl = String.fromEnvironment(
    'APP_PRIVACY_URL',
    defaultValue: '',
  );

  static const termsUrl = String.fromEnvironment(
    'APP_TERMS_URL',
    defaultValue: '',
  );

  static bool get hasSupportWhatsApp => supportWhatsApp.trim().isNotEmpty;
  static bool get hasSupportEmail => supportEmail.trim().isNotEmpty;
  static bool get hasWebsite => websiteUri != null;
  static bool get hasPrivacyPolicy => privacyPolicyUri != null;
  static bool get hasTerms => termsUri != null;
  static bool get hasAnySupportChannel =>
      hasSupportWhatsApp || hasSupportEmail || hasWebsite;

  static Uri? get websiteUri => _parseExternalUri(websiteUrl);
  static Uri? get privacyPolicyUri => _parseExternalUri(privacyPolicyUrl);
  static Uri? get termsUri => _parseExternalUri(termsUrl);

  static Uri? _parseExternalUri(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      return null;
    }
    return uri;
  }
}

Uri buildMailToUri({required String email, String? subject, String? body}) {
  return Uri(
    scheme: 'mailto',
    path: email,
    queryParameters: <String, String>{
      if (subject != null && subject.trim().isNotEmpty) 'subject': subject,
      if (body != null && body.trim().isNotEmpty) 'body': body,
    },
  );
}

Future<bool> launchExternalUri(
  BuildContext context,
  Uri uri, {
  required String failureMessage,
}) async {
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failureMessage)));
  }
  return launched;
}

Future<bool> launchMailTo(
  BuildContext context, {
  required String email,
  String? subject,
  String? body,
  required String failureMessage,
}) async {
  return launchExternalUri(
    context,
    buildMailToUri(email: email, subject: subject, body: body),
    failureMessage: failureMessage,
  );
}

Future<bool> launchWhatsApp(
  BuildContext context, {
  String? message,
  required String failureMessage,
}) async {
  if (!AppLinks.hasSupportWhatsApp) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp support is not configured for this build.'),
        ),
      );
    }
    return false;
  }
  final encoded = Uri.encodeComponent(message ?? '');
  final uri = Uri.parse(
    'https://wa.me/${AppLinks.supportWhatsApp.replaceAll('+', '')}'
    '${message != null ? '?text=$encoded' : ''}',
  );
  return launchExternalUri(context, uri, failureMessage: failureMessage);
}

