import 'package:feat_gamification/feat_gamification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('ChallengeModule', () {
    late ChallengeModule module;

    setUp(() {
      module = ChallengeModule();
    });

    test('featureKey is challenge', () {
      expect(module.featureKey, 'challenge');
    });

    test('keeps challenge off the primary bottom tabs', () {
      expect(module.tabRoute, isNull);
    });

    test('registers root, create, my, and detail routes', () {
      final paths = module.routes
          .whereType<GoRoute>()
          .map((route) => route.path)
          .toList(growable: false);

      expect(paths, contains('/challenge'));
      expect(paths, contains('/challenge/create'));
      expect(paths, contains('/challenge/my'));
      expect(paths, contains('/challenge/:id'));
      expect(paths, hasLength(4));
    });
  });
}
