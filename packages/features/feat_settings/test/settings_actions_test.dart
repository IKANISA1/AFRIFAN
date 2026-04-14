import 'package:feat_settings/src/settings_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildMailToUri encodes subject and body', () {
    final uri = buildMailToUri(
      email: 'support@example.com',
      subject: 'Data export request',
      body: 'Hello support team',
    );

    expect(uri.scheme, 'mailto');
    expect(uri.path, 'support@example.com');
    expect(uri.queryParameters['subject'], 'Data export request');
    expect(uri.queryParameters['body'], 'Hello support team');
  });

  test('app links expose configured defaults', () {
    expect(
      AppLinks.supportEmail,
      anyOf(isEmpty, contains('@')),
    );
    expect(
      AppLinks.websiteUrl,
      anyOf(isEmpty, startsWith('https://')),
    );
    expect(
      AppLinks.termsUrl,
      anyOf(isEmpty, startsWith('https://')),
    );
    expect(
      AppLinks.privacyPolicyUrl,
      anyOf(isEmpty, startsWith('https://')),
    );
  });
}
