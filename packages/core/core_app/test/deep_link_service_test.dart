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

    test(
      'maps the explicit generic TV pairing alias into the mobile route',
      () {
        final parser = DeepLinkParser(
          customScheme: 'gikundiro',
          additionalCustomSchemes: const <String>['africlub'],
        );

        final route = parser.toInternalUri(
          Uri.parse('africlub://my-tvs/pair?challenge=TV4K8M2Q'),
        );

        expect(route?.toString(), '/my-tvs/pair?challenge=TV4K8M2Q');
        expect(
          parser.toInternalUri(
            Uri.parse('unlisted://my-tvs/pair?challenge=TV4K8M2Q'),
          ),
          isNull,
        );
      },
    );

    test('ignores unrelated schemes', () {
      final parser = DeepLinkParser(customScheme: 'gikundiro');

      final route = parser.toInternalUri(
        Uri.parse('mailto:support@gikundiro.com'),
      );

      expect(route, isNull);
    });

    test('rejects encoded separator paths', () {
      final parser = DeepLinkParser(
        websiteUri: Uri.parse('https://gikundiro.com'),
        customScheme: 'gikundiro',
      );

      expect(
        parser.toInternalUri(Uri.parse('gikundiro://settings/%5Cadmin')),
        isNull,
      );
      expect(
        parser.toInternalUri(Uri.parse('gikundiro://settings%2Fprivacy')),
        isNull,
      );
    });
  });

  group('InternalRouteUriPolicy', () {
    test('accepts local canonical paths with query and fragment', () {
      final route = InternalRouteUriPolicy.validate(
        Uri.parse('/fanzone/match/123?tab=stats#summary'),
      );

      expect(route?.toString(), '/fanzone/match/123?tab=stats#summary');
    });

    test(
      'rejects external, authority, encoded separator, and control targets',
      () {
        for (final raw in <String>[
          'https://attacker.example/settings',
          '//attacker.example/settings',
          '/settings/%2Fprivacy',
          '/settings/%5Cprivacy',
          '/settings/%0Aprivacy',
          'settings/privacy',
        ]) {
          expect(
            InternalRouteUriPolicy.validate(Uri.parse(raw)),
            isNull,
            reason: raw,
          );
        }
      },
    );

    test('raw parsing rejects traversal before URI normalization', () {
      for (final raw in <String>[
        '/settings/../admin',
        '/settings/%2E%2E/admin',
        '/settings/./privacy',
        '/settings/%2e/privacy',
      ]) {
        expect(InternalRouteUriPolicy.parse(raw), isNull, reason: raw);
      }
    });
  });
}
