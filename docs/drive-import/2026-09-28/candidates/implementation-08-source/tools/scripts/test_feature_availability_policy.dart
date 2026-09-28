// Dependency-free test entrypoint: dart run tools/scripts/test_feature_availability_policy.dart
import '../../packages/core/core_router/lib/src/feature_availability_policy.dart';

void main() {
  var checks = 0;
  void check(bool actual, bool expected, String label) {
    checks++;
    if (actual != expected) throw StateError('$label: expected $expected, got $actual');
  }
  bool evaluate(Map<String, dynamic>? config, {bool club = true}) =>
      isFeatureOperational(featureKey: 'shop', clubEnabled: club, snapshot: config);
  Map<String, dynamic> feature(Map<String, dynamic> fields) => {
    'features': [<String, dynamic>{'feature_key': 'shop', ...fields}],
  };
  check(evaluate(null), true, 'offline fallback');
  check(evaluate(null, club: false), false, 'club disabled offline');
  check(evaluate(feature({'is_enabled': true}), club: false), false, 'remote cannot enable club-disabled capability');
  check(evaluate({'features': []}), true, 'absent feature fallback');
  check(evaluate({}), true, 'legacy bootstrap fallback');
  check(evaluate(feature({'is_enabled': false})), false, 'global disabled');
  check(evaluate(feature({'is_enabled': 'true'})), false, 'malformed bool');
  check(evaluate(feature({'is_enabled': null})), false, 'explicit null enablement');
  check(evaluate(feature({'channel': {'is_enabled': false}})), false, 'channel disabled');
  check(evaluate(feature({'rules': {'is_within_schedule': false}})), false, 'outside schedule');
  check(evaluate(feature({'visibility_state': 'maintenance'})), false, 'maintenance');
  check(evaluate(feature({'visibility_state': 'hidden'})), true, 'hidden deep links remain registered');
  check(evaluate(feature({'visibility_state': 2})), false, 'malformed visibility');
  check(evaluate(feature({'channel': 1})), false, 'malformed channel');
  check(evaluate(feature({'rules': []})), false, 'malformed rules');
  check(evaluate({'features': null}), false, 'malformed collection');
  check(evaluate({'features': [{'feature_key': 'shop'}, {'feature_key': 'Shop'}]}), false, 'duplicate normalized keys');
  check(evaluate({'features': [{'feature_key': 42}]}), false, 'malformed identity');
  check(evaluate({'features': [{'feature_key': ' SHOP ', 'is_enabled': true}]}), true, 'key normalization');
  check(evaluate(feature({'channel': null, 'rules': null})), true, 'optional nullable objects');
  print('Feature availability policy passed: $checks checks.');
}
