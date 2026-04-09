import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

abstract final class AppLinks {
  static const supportWhatsApp = '+250795588248';

  static const supportEmail = String.fromEnvironment(
    'APP_SUPPORT_EMAIL',
    defaultValue: 'support@ikanisa.com',
  );

  static const websiteUrl = String.fromEnvironment(
    'APP_WEBSITE_URL',
    defaultValue: 'https://gikundiro.com',
  );

  static const privacyPolicyUrl = String.fromEnvironment(
    'APP_PRIVACY_URL',
    defaultValue: 'https://gikundiro.com/privacy',
  );

  static const termsUrl = String.fromEnvironment(
    'APP_TERMS_URL',
    defaultValue: 'https://gikundiro.com/terms',
  );
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
  final encoded = Uri.encodeComponent(message ?? '');
  final uri = Uri.parse(
    'https://wa.me/${AppLinks.supportWhatsApp.replaceAll('+', '')}'
    '${message != null ? '?text=$encoded' : ''}',
  );
  return launchExternalUri(context, uri, failureMessage: failureMessage);
}

Future<bool> openStoreListing(BuildContext context) async {
  try {
    await InAppReview.instance.openStoreListing();
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the app store listing.')),
      );
    }
    return false;
  }
}
