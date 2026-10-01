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

    test('opaque strings and booleans fail every declared value boundary', () {
      for (final event in PrivacySafeAnalyticsPolicy.taxonomy.entries) {
        for (final key in event.value) {
          for (final unsafe in <Object>[
            'opaque_private_supporter_alias',
            true,
            123,
            'whatsapp_private',
          ]) {
            expect(
              PrivacySafeAnalyticsPolicy.prepare(
                event.key,
                parameters: <String, Object>{key: unsafe},
              ),
              isNull,
              reason: '${event.key}.$key: $unsafe',
            );
          }
        }
      }
    });

    test('current product caller values remain valid coarse signals', () {
      final cases = <String, Map<String, Object>>{
        'prediction_placed': {
          'market': 'wdw',
          'outcome': 'home',
          'value_bucket': 'under_100',
        },
        'ticket_completion': {
          'ticket_type': 'general',
          'payment_channel': 'momo',
        },
        'contribution_completion': {
          'payment_channel': 'momo',
          'value_bucket': '100_999',
        },
        'support_access': {'channel': 'whatsapp'},
        'home_action_selected': {'action': 'tickets', 'layer': 'primary'},
        'search_success': {
          'category': 'commerce',
          'result_count_bucket': 'two_to_five',
        },
        'error_recovery': {
          'surface': 'profile_settings',
          'outcome': 'conflict_refresh',
        },
        'task_abandonment': {
          'task': 'ticket_checkout',
          'stage': 'checkout_review',
        },
      };
      for (final entry in cases.entries) {
        expect(
          PrivacySafeAnalyticsPolicy.prepare(
            entry.key,
            parameters: entry.value,
          ),
          isNotNull,
          reason: entry.key,
        );
      }
    });

    test(
      'opaque screens and classes fail closed; dynamic labels are constant',
      () {
        for (final unsafe in <String>[
          'opaque_private_supporter_alias',
          '/opaque_private_supporter_alias',
          '/home/private',
          'https://example.invalid/home',
          '/orders/../private',
          '/support/private',
        ]) {
          expect(PrivacySafeAnalyticsPolicy.sanitizeScreenName(unsafe), isNull);
        }
        expect(
          PrivacySafeAnalyticsPolicy.sanitizeScreenName('club-news-detail'),
          '/club/news/:item',
        );
        expect(
          PrivacySafeAnalyticsPolicy.sanitizeScreenName(
            '/club/news/opaque_private_supporter_alias?private=value',
          ),
          '/club/news/:item',
        );
        expect(
          PrivacySafeAnalyticsPolicy.sanitizeScreenName(
            '/orders/opaque_private_supporter_alias',
          ),
          '/orders/:item',
        );
        expect(
          PrivacySafeAnalyticsPolicy.sanitizeScreenClass(
            'opaque_private_supporter_alias',
          ),
          isNull,
        );
      },
    );

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
