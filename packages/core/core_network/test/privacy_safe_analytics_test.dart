import 'package:core_network/core_network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrivacySafeAnalyticsPolicy', () {
    test('accepts a declared event with coded coarse parameters', () {
      final event = PrivacySafeAnalyticsPolicy.prepare(
        'search_success',
        parameters: const <String, Object>{
          'category': 'commerce',
          'result_count_bucket': 'two_to_five',
        },
      );

      expect(event, isNotNull);
      expect(event!.name, 'search_success');
      expect(event.parameters['category'], 'commerce');
    });

    test('rejects unknown events and parameters', () {
      expect(PrivacySafeAnalyticsPolicy.prepare('free_form_event'), isNull);
      expect(
        PrivacySafeAnalyticsPolicy.prepare(
          'support_access',
          parameters: const <String, Object>{
            'channel': 'whatsapp',
            'phone': '250788123456',
          },
        ),
        isNull,
      );
    });

    test('rejects contact details, identifiers, secrets, and free text', () {
      for (final unsafe in <String>[
        'person@example.com',
        '250788123456',
        '550e8400-e29b-41d4-a716-446655440000',
        'Bearer_secret',
        'hello world',
      ]) {
        expect(
          PrivacySafeAnalyticsPolicy.prepare(
            'support_access',
            parameters: <String, Object>{'channel': unsafe},
          ),
          isNull,
          reason: unsafe,
        );
      }
    });

    test('buckets precise values and result counts', () {
      expect(PrivacySafeAnalyticsPolicy.valueBucket(0), 'zero');
      expect(PrivacySafeAnalyticsPolicy.valueBucket(99), 'under_100');
      expect(PrivacySafeAnalyticsPolicy.valueBucket(500), '100_999');
      expect(PrivacySafeAnalyticsPolicy.valueBucket(250000), '100000_plus');
      expect(PrivacySafeAnalyticsPolicy.resultCountBucket(0), 'zero');
      expect(PrivacySafeAnalyticsPolicy.resultCountBucket(4), 'two_to_five');
      expect(
        PrivacySafeAnalyticsPolicy.resultCountBucket(21),
        'twenty_one_plus',
      );
    });

    test('normalizes screens without emitting identifiers or queries', () {
      expect(
        PrivacySafeAnalyticsPolicy.sanitizeScreenName(
          '/tickets/550e8400-e29b-41d4-a716-446655440000?token=secret',
        ),
        '/tickets/:item',
      );
      expect(
        PrivacySafeAnalyticsPolicy.sanitizeScreenName('/orders/123456'),
        '/orders/:item',
      );
      expect(
        PrivacySafeAnalyticsPolicy.sanitizeScreenName(
          '/support/person@example.com',
        ),
        isNull,
      );
    });

    test('taxonomy covers every required task-success signal', () {
      expect(
        PrivacySafeAnalyticsPolicy.taxonomy.keys,
        containsAll(<String>[
          'search_success',
          'ticket_completion',
          'contribution_completion',
          'predict_engagement',
          'support_access',
          'error_recovery',
          'task_abandonment',
        ]),
      );
    });

    test('allows coded Home action layers but rejects unsafe action keys', () {
      final event = PrivacySafeAnalyticsPolicy.prepare(
        'home_action_selected',
        parameters: const <String, Object>{
          'action': 'tickets',
          'layer': 'primary',
        },
      );

      expect(event, isNotNull);
      expect(event!.parameters, const <String, Object>{
        'action': 'tickets',
        'layer': 'primary',
      });
      expect(
        PrivacySafeAnalyticsPolicy.prepare(
          'home_action_selected',
          parameters: const <String, Object>{
            'action': 'supporter 250788123456',
            'layer': 'primary',
          },
        ),
        isNull,
      );
    });
  });

  test('analytics consent remains off in the default build', () async {
    await FirebaseAnalyticsService.configureConsent(enabled: true);
    expect(FirebaseAnalyticsService.consentGranted, isFalse);
  });
}
