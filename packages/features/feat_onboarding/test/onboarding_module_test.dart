import 'package:feat_onboarding/feat_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('OnboardingModule', () {
    late OnboardingModule module;

    setUp(() {
      module = OnboardingModule();
    });

    test('featureKey is onboarding', () {
      expect(module.featureKey, 'onboarding');
    });

    test('has no tab route', () {
      expect(module.tabRoute, isNull);
    });

    test('provides /splash route', () {
      final paths = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(paths, contains('/splash'));
    });

    test('provides /onboarding route', () {
      final paths = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(paths, contains('/onboarding'));
    });

    test('provides split WhatsApp auth routes', () {
      final paths = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(paths, contains('/auth/phone'));
      expect(paths, contains('/auth/otp'));
    });

    test('has exactly 4 routes', () {
      expect(module.routes.whereType<GoRoute>().length, 4);
    });

    test('isEnabled defaults to true', () {
      expect(module.isEnabled({}), isTrue);
    });

    test('isEnabled returns false when explicitly disabled', () {
      expect(module.isEnabled({'onboarding': false}), isFalse);
    });

    test('standaloneRoutes is empty', () {
      expect(module.standaloneRoutes, isEmpty);
    });
  });
}
