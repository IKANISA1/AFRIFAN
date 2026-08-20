import 'package:core_feature_config/core_feature_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlatformConfigSnapshot', () {
    test('empty has no features and no content blocks', () {
      const snapshot = PlatformConfigSnapshot();
      expect(snapshot.features, isEmpty);
      expect(snapshot.contentBlocks, isEmpty);
      expect(snapshot.isEmpty, isTrue);
      expect(snapshot.isNotEmpty, isFalse);
    });

    test('static empty is const-identical to default constructor', () {
      expect(PlatformConfigSnapshot.empty.isEmpty, isTrue);
    });

    test('fromJson parses features and content blocks', () {
      final json = <String, dynamic>{
        'features': [
          {
            'feature_key': 'ticketing',
            'display_name': 'Ticketing',
            'is_enabled': true,
            'visibility_state': 'visible',
            'channel': {
              'is_enabled': true,
              'is_visible': true,
              'show_in_navigation': true,
              'show_on_home': false,
              'sort_order': 3,
            },
          },
          {
            'feature_key': 'shop',
            'display_name': 'Club Shop',
            'is_enabled': false,
            'visibility_state': 'hidden',
          },
        ],
        'content_blocks': [
          {
            'block_key': 'hero_banner',
            'block_type': 'banner',
            'title': 'Welcome',
            'placement_key': 'home_top',
            'is_active': true,
            'sort_order': 1,
          },
        ],
        'route_registry': [
          {
            'route_key': 'challenge',
            'path_pattern': '/challenge',
            'surface': 'mobile',
            'feature_key': 'challenge',
            'label': 'Challenge',
            'auth_required': true,
            'required_roles': [],
            'sort_order': 7,
          },
        ],
        'option_sets': [
          {
            'option_set_key': 'challenge_stake_fet',
            'label': 'Challenge stakes',
            'value_type': 'number',
            'values': [
              {
                'option_key': 'stake_500',
                'label': '500 FET',
                'value': 500,
                'sort_order': 1,
              },
              {
                'option_key': 'stake_1000',
                'label': '1,000 FET',
                'value': 1000,
                'sort_order': 2,
                'is_default': true,
              },
            ],
          },
        ],
        'runtime_copy': [
          {
            'copy_key': 'home.feed.degraded',
            'surface': 'mobile',
            'locale': 'en',
            'text_value': 'Live club data is temporarily unavailable.',
          },
        ],
        'config_version': '2026-04-16T12:00:00Z',
        'channel': 'mobile',
      };

      final snapshot = PlatformConfigSnapshot.fromJson(json);

      expect(snapshot.features, hasLength(2));
      expect(snapshot.contentBlocks, hasLength(1));
      expect(snapshot.routeRegistry, hasLength(1));
      expect(snapshot.optionSets, hasLength(1));
      expect(snapshot.runtimeCopy, hasLength(1));
      expect(
        snapshot.routeByPath('/challenge/friend')?.featureKey,
        'challenge',
      );
      expect(snapshot.intOptions('challenge_stake_fet'), [500, 1000]);
      expect(
        snapshot.copyValue('home.feed.degraded'),
        'Live club data is temporarily unavailable.',
      );
      expect(snapshot.isNotEmpty, isTrue);
      expect(snapshot.channel, 'mobile');
      expect(snapshot.configVersion, isNotNull);
    });

    test('featureByKey returns correct feature', () {
      final snapshot = PlatformConfigSnapshot(
        features: [
          const PlatformFeature(
            featureKey: 'contributions',
            displayName: 'Contributions',
            isEnabled: true,
            visibilityState: 'visible',
          ),
          const PlatformFeature(
            featureKey: 'live',
            displayName: 'Live Match',
            isEnabled: false,
            visibilityState: 'hidden',
          ),
        ],
      );

      expect(
        snapshot.featureByKey('contributions')?.displayName,
        'Contributions',
      );
      expect(snapshot.featureByKey('live')?.isEnabled, isFalse);
      expect(snapshot.featureByKey('nonexistent'), isNull);
    });

    test(
      'runtime copy uses exact, language, then deterministic English fallback',
      () {
        const snapshot = PlatformConfigSnapshot(
          runtimeCopy: [
            RuntimeCopyEntry(
              copyKey: 'home.feed.degraded',
              surface: 'mobile',
              locale: 'rw',
              textValue: 'Amakuru ntabonetse.',
            ),
            RuntimeCopyEntry(
              copyKey: 'home.feed.degraded',
              surface: 'mobile',
              locale: 'fr',
              textValue: 'Les informations sont indisponibles.',
            ),
            RuntimeCopyEntry(
              copyKey: 'home.feed.degraded',
              surface: 'mobile',
              locale: 'en',
              textValue: 'Club data is unavailable.',
            ),
            RuntimeCopyEntry(
              copyKey: 'home.feed.degraded',
              surface: 'mobile',
              locale: 'fr-rw',
              textValue: 'Les informations locales sont indisponibles.',
            ),
          ],
        );

        expect(
          snapshot.copyValue('home.feed.degraded', locale: 'FR_rw'),
          'Les informations locales sont indisponibles.',
        );
        expect(
          snapshot.copyValue('home.feed.degraded', locale: 'fr-BE'),
          'Les informations sont indisponibles.',
        );
        expect(
          snapshot.copyValue('home.feed.degraded', locale: 'de'),
          'Club data is unavailable.',
        );
      },
    );

    test('runtime copy never falls through to an unrelated locale', () {
      const snapshot = PlatformConfigSnapshot(
        runtimeCopy: [
          RuntimeCopyEntry(
            copyKey: 'home.feed.degraded',
            surface: 'mobile',
            locale: 'rw',
            textValue: 'Amakuru ntabonetse.',
          ),
        ],
      );

      expect(snapshot.copyValue('home.feed.degraded', locale: 'fr'), isNull);
    });

    test('toJson and fromJson are symmetric', () {
      final original = PlatformConfigSnapshot(
        features: [
          const PlatformFeature(
            featureKey: 'test',
            displayName: 'Test Feature',
            isEnabled: true,
            visibilityState: 'visible',
          ),
        ],
        contentBlocks: [
          const ContentBlock(
            blockKey: 'block1',
            blockType: 'banner',
            placementKey: 'home',
            isActive: true,
          ),
        ],
        channel: 'web',
      );

      final json = original.toJson();
      final restored = PlatformConfigSnapshot.fromJson(json);

      expect(restored.features, hasLength(1));
      expect(restored.features.first.featureKey, 'test');
      expect(restored.contentBlocks, hasLength(1));
      expect(restored.contentBlocks.first.blockKey, 'block1');
      expect(restored.optionSets, isEmpty);
      expect(restored.routeRegistry, isEmpty);
      expect(restored.channel, 'web');
    });

    test('toJsonString and fromJsonString roundtrip', () {
      const original = PlatformConfigSnapshot(
        features: [PlatformFeature(featureKey: 'x', displayName: 'X')],
      );

      final str = original.toJsonString();
      final restored = PlatformConfigSnapshot.fromJsonString(str);
      expect(restored.features.first.featureKey, 'x');
    });

    test('fromJson handles null/missing fields gracefully', () {
      final json = <String, dynamic>{};
      final snapshot = PlatformConfigSnapshot.fromJson(json);
      expect(snapshot.features, isEmpty);
      expect(snapshot.contentBlocks, isEmpty);
      expect(snapshot.configVersion, isNull);
    });

    test('fromJson ignores non-map entries in features list', () {
      final json = <String, dynamic>{
        'features': [
          'not a map',
          42,
          {'feature_key': 'valid', 'display_name': 'Valid'},
        ],
      };
      final snapshot = PlatformConfigSnapshot.fromJson(json);
      expect(snapshot.features, hasLength(1));
      expect(snapshot.features.first.featureKey, 'valid');
    });
  });

  group('PlatformFeature', () {
    test('defaults are sensible', () {
      const f = PlatformFeature(featureKey: 'test', displayName: 'Test');
      expect(f.isEnabled, isTrue);
      expect(f.visibilityState, 'visible');
      expect(f.channel, isNull);
      expect(f.rules, isNull);
    });

    test('isEffectivelyEnabled checks all conditions', () {
      // Fully enabled
      const enabled = PlatformFeature(
        featureKey: 'a',
        displayName: 'A',
        isEnabled: true,
        visibilityState: 'visible',
      );
      expect(enabled.isEffectivelyEnabled, isTrue);

      // Disabled globally
      const disabled = PlatformFeature(
        featureKey: 'b',
        displayName: 'B',
        isEnabled: false,
        visibilityState: 'visible',
      );
      expect(disabled.isEffectivelyEnabled, isFalse);

      // Hidden visibility
      const hidden = PlatformFeature(
        featureKey: 'c',
        displayName: 'C',
        isEnabled: true,
        visibilityState: 'hidden',
      );
      expect(hidden.isEffectivelyEnabled, isFalse);
    });

    test('isEffectivelyEnabled respects channel config', () {
      const channelDisabled = PlatformFeature(
        featureKey: 'd',
        displayName: 'D',
        isEnabled: true,
        visibilityState: 'visible',
        channel: FeatureChannelConfig(isEnabled: false),
      );
      expect(channelDisabled.isEffectivelyEnabled, isFalse);

      const channelInvisible = PlatformFeature(
        featureKey: 'e',
        displayName: 'E',
        isEnabled: true,
        visibilityState: 'visible',
        channel: FeatureChannelConfig(isVisible: false),
      );
      expect(channelInvisible.isEffectivelyEnabled, isFalse);
    });

    test('isEffectivelyEnabled respects schedule rules', () {
      const outsideSchedule = PlatformFeature(
        featureKey: 'f',
        displayName: 'F',
        isEnabled: true,
        visibilityState: 'visible',
        rules: FeatureRuleConfig(isWithinSchedule: false),
      );
      expect(outsideSchedule.isEffectivelyEnabled, isFalse);

      const insideSchedule = PlatformFeature(
        featureKey: 'g',
        displayName: 'G',
        isEnabled: true,
        visibilityState: 'visible',
        rules: FeatureRuleConfig(isWithinSchedule: true),
      );
      expect(insideSchedule.isEffectivelyEnabled, isTrue);
    });
  });

  group('FeatureChannelConfig', () {
    test('fromJson with full data', () {
      final json = <String, dynamic>{
        'is_enabled': true,
        'is_visible': false,
        'show_in_navigation': true,
        'show_on_home': true,
        'sort_order': 5,
        'route_key': '/tickets',
        'placement_key': 'home_grid',
      };
      final config = FeatureChannelConfig.fromJson(json);
      expect(config.isEnabled, isTrue);
      expect(config.isVisible, isFalse);
      expect(config.showInNavigation, isTrue);
      expect(config.showOnHome, isTrue);
      expect(config.sortOrder, 5);
      expect(config.routeKey, '/tickets');
      expect(config.placementKey, 'home_grid');
    });

    test('fromJson with empty map uses defaults', () {
      final config = FeatureChannelConfig.fromJson(const <String, dynamic>{});
      expect(config.isEnabled, isTrue);
      expect(config.isVisible, isTrue);
      expect(config.showInNavigation, isFalse);
      expect(config.showOnHome, isFalse);
      expect(config.sortOrder, isNull);
    });
  });

  group('FeatureRuleConfig', () {
    test('fromJson with schedule and roles', () {
      final json = <String, dynamic>{
        'auth_required': true,
        'role_restrictions': ['admin', 'moderator'],
        'is_within_schedule': false,
        'schedule_start_at': '2026-01-01T00:00:00Z',
        'schedule_end_at': '2026-12-31T23:59:59Z',
      };
      final rules = FeatureRuleConfig.fromJson(json);
      expect(rules.authRequired, isTrue);
      expect(rules.roleRestrictions, ['admin', 'moderator']);
      expect(rules.isWithinSchedule, isFalse);
      expect(rules.scheduleStartAt, isNotNull);
      expect(rules.scheduleEndAt, isNotNull);
    });
  });

  group('ContentBlock', () {
    test('fromJson with all fields', () {
      final json = <String, dynamic>{
        'block_key': 'hero',
        'block_type': 'hero_banner',
        'title': 'Match Day',
        'subtitle': 'Get your tickets',
        'content': {'image_url': 'https://example.com/img.jpg'},
        'placement_key': 'home_top',
        'feature_key': 'ticketing',
        'is_active': true,
        'sort_order': 1,
        'metadata': {'priority': 'high'},
      };
      final block = ContentBlock.fromJson(json);
      expect(block.blockKey, 'hero');
      expect(block.blockType, 'hero_banner');
      expect(block.title, 'Match Day');
      expect(block.featureKey, 'ticketing');
      expect(block.isActive, isTrue);
      expect(block.sortOrder, 1);
      expect(block.content['image_url'], 'https://example.com/img.jpg');
    });

    test('fromJson with minimal data', () {
      final block = ContentBlock.fromJson(const <String, dynamic>{});
      expect(block.blockKey, '');
      expect(block.blockType, '');
      expect(block.placementKey, '');
      expect(block.isActive, isTrue);
      expect(block.content, isEmpty);
    });
  });
}
