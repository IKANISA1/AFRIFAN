import 'package:feat_live/feat_live.dart';
import 'package:feat_live/src/widgets/live_match_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Unit tests for the Live module — routes, feature toggle, and data models.
void main() {
  // ═══════════════════════════════════════════════════════════
  // LiveModule
  // ═══════════════════════════════════════════════════════════

  group('LiveModule', () {
    late LiveModule module;

    setUp(() {
      module = LiveModule();
    });

    test('featureKey is live', () {
      expect(module.featureKey, 'live');
    });

    test('registers live as a bottom-nav tab', () {
      final tab = module.tabRoute;

      expect(tab.path, '/live');
      expect(tab.label, 'LIVE');
    });

    test('registers nested news route and standalone live-match alias', () {
      final routePaths = module.routes
          .whereType<GoRoute>()
          .map((route) => route.path)
          .toList();
      final standalonePaths = module.standaloneRoutes
          .whereType<GoRoute>()
          .map((route) => route.path)
          .toList();

      expect(routePaths, orderedEquals(<String>['news/:articleId']));
      expect(standalonePaths, orderedEquals(<String>['/live-match']));
    });

    test('isEnabled returns true when live feature is in config', () {
      expect(module.isEnabled({'live': true}), isTrue);
    });

    test('isEnabled defaults to true when key is absent', () {
      // FeatureModule defaults missing keys to true
      expect(module.isEnabled({}), isTrue);
    });

    test('isEnabled returns false when explicitly disabled', () {
      expect(module.isEnabled({'live': false}), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // MatchIntelEvent (data model)
  // ═══════════════════════════════════════════════════════════

  group('MatchIntelEvent', () {
    test('stores minute, title, and body correctly', () {
      const event = MatchIntelEvent(
        minute: "45'",
        title: 'GOAL',
        body: 'Nshuti scores from a free kick.',
      );

      expect(event.minute, "45'");
      expect(event.title, 'GOAL');
      expect(event.body, 'Nshuti scores from a free kick.');
    });

    test('supports const construction', () {
      // Verify const semantics (should compile without issues)
      const events = [
        MatchIntelEvent(minute: "12'", title: 'CORNER', body: 'Left side'),
        MatchIntelEvent(minute: "23'", title: 'YELLOW CARD', body: 'Foul'),
      ];
      expect(events, hasLength(2));
    });
  });
}
