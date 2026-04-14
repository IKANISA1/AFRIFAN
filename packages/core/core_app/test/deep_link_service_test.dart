import 'package:core_app/core_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeepLinkParser', () {
    test('maps matching website links into internal routes', () {
      final parser = DeepLinkParser(
        websiteUri: Uri.parse('https://gikundiro.com'),
      );

      final route = parser.toInternalUri(
        Uri.parse('https://gikundiro.com/fanzone/match/123?tab=stats'),
      );

      expect(route?.toString(), '/fanzone/match/123?tab=stats');
    });

    test('ignores website links for unknown hosts', () {
      final parser = DeepLinkParser(
        websiteUri: Uri.parse('https://gikundiro.com'),
      );

      final route = parser.toInternalUri(
        Uri.parse('https://attacker.example/fanzone/match/123'),
      );

      expect(route, isNull);
    });

    test('maps custom-scheme links into internal routes', () {
      final parser = DeepLinkParser(customScheme: 'gikundiro');

      final route = parser.toInternalUri(
        Uri.parse('gikundiro://fanzone/fixtures?filter=live'),
      );

      expect(route?.toString(), '/fanzone/fixtures?filter=live');
    });

    test('ignores unrelated schemes', () {
      final parser = DeepLinkParser(customScheme: 'gikundiro');

      final route = parser.toInternalUri(
        Uri.parse('mailto:support@gikundiro.com'),
      );

      expect(route, isNull);
    });
  });
}
