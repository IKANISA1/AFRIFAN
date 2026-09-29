import 'package:app_registry/app_registry.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Set<String> keys(_ScopedConfig config, [Map<String, dynamic>? snapshot]) =>
      AppModuleRegistry.build(
        config,
        configSnapshot: snapshot,
      ).map((module) => module.featureKey).toSet();

  test('remote flags cannot expand a different club capability set', () {
    const configuredClub = _ScopedConfig(features: {'shop': false});
    final snapshot = <String, dynamic>{
      'club_id': 24,
      'channel': 'mobile',
      'features': [
        {'feature_key': 'shop', 'is_enabled': true},
      ],
    };
    expect(keys(configuredClub, snapshot), isNot(contains('shop')));
    expect(
      keys(const _ScopedConfig(features: {'shop': true}), snapshot),
      contains('shop'),
    );
  });

  test('explicitly mismatched or malformed snapshot scope fails closed', () {
    for (final scope in <dynamic>[25, '25', null, 24.0, true, 'invalid']) {
      expect(
        keys(const _ScopedConfig(), {
          'club_id': scope,
          'features': [
            {'feature_key': 'shop', 'is_enabled': true},
          ],
        }),
        isEmpty,
        reason: '$scope',
      );
    }
    expect(
      keys(const _ScopedConfig(), {
        'club_id': '24',
        'channel': 'mobile',
        'features': [
          {'feature_key': 'shop', 'is_enabled': true},
        ],
      }),
      contains('shop'),
    );
    for (final channel in <dynamic>['web', 'admin', null, true]) {
      expect(
        keys(const _ScopedConfig(), {'channel': channel}),
        isEmpty,
        reason: '$channel',
      );
    }
  });

  test(
    'core always-visible modules remain only in an enabled club capability',
    () {
      expect(keys(const _ScopedConfig()), containsAll(['club', 'membership']));
      expect(
        keys(
          const _ScopedConfig(features: {'club': false, 'membership': false}),
        ),
        isNot(anyOf(contains('club'), contains('membership'))),
      );
      // Specialized core modules retain their current availability contracts.
      expect(
        keys(const _ScopedConfig(), {
          'features': [
            {'feature_key': 'club', 'is_enabled': false},
            {'feature_key': 'membership', 'is_enabled': false},
          ],
        }),
        containsAll(['club', 'membership']),
      );
    },
  );

  test('malformed optional runtime flags never register their module', () {
    for (final value in <dynamic>['true', 1, null, false]) {
      expect(
        keys(const _ScopedConfig(), {
          'features': [
            {'feature_key': 'shop', 'is_enabled': value},
          ],
        }),
        isNot(contains('shop')),
        reason: '$value',
      );
    }
  });

  test('all explicitly disabled modules produce an empty registry', () {
    final features = {
      for (final module in AppModuleRegistry.allModules)
        module.featureKey: false,
    };
    expect(keys(_ScopedConfig(features: features)), isEmpty);
    expect(
      keys(_ScopedConfig(features: features), {
        'features': [
          for (final key in features.keys)
            {'feature_key': key, 'is_enabled': true},
        ],
      }),
      isEmpty,
    );
  });

  test(
    'absent scope preserves existing offline and scoped-cache bootstrap',
    () {
      expect(
        keys(const _ScopedConfig()),
        containsAll(['home', 'club', 'membership']),
      );
      expect(
        keys(const _ScopedConfig(), {}),
        containsAll(['home', 'club', 'membership']),
      );
      expect(keys(const _ScopedConfig(), {'features': []}), contains('shop'));
      expect(
        keys(const _ScopedConfig(), {
          'features': [
            {'feature_key': 'admin', 'is_enabled': true},
          ],
        }),
        isNot(contains('admin')),
      );
    },
  );
}

class _ScopedConfig implements ClubConfig {
  const _ScopedConfig({this.features = const {}});
  @override
  String get clubId => '24';
  @override
  final Map<String, bool> features;
  // Registry tests fail if registration unexpectedly starts reading other
  // product/configuration values rather than these explicit capabilities.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
