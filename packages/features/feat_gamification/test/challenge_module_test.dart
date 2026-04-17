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

    test('registers the challenge tab route', () {
      expect(module.tabRoute.path, '/challenge');
      expect(module.tabRoute.label, 'Fan Zone');
    });

    test('registers create, my, and detail routes', () {
      final paths = module.routes
          .whereType<GoRoute>()
          .map((route) => route.path)
          .toList(growable: false);

      expect(paths, contains('/challenge/create'));
      expect(paths, contains('/challenge/my'));
      expect(paths, contains('/challenge/:id'));
      expect(paths, hasLength(3));
    });
  });
}
