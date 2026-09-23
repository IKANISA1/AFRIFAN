import 'package:core_feature_config/core_feature_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── Shared test fixtures ──

  PlatformConfigSnapshot buildSnapshot({
    List<PlatformFeature> features = const [],
    List<ContentBlock> blocks = const [],
  }) {
    return PlatformConfigSnapshot(
      features: features,
      contentBlocks: blocks,
      channel: 'mobile',
    );
  }

  const ticketing = PlatformFeature(
    featureKey: 'ticketing',
    displayName: 'Ticketing',
    isEnabled: true,
    visibilityState: 'visible',
    channel: FeatureChannelConfig(
      isEnabled: true,
      isVisible: true,
      showInNavigation: true,
      showOnHome: false,
      sortOrder: 2,
      routeKey: '/tickets',
    ),
  );

  const shop = PlatformFeature(
    featureKey: 'shop',
    displayName: 'Club Shop',
    isEnabled: true,
    visibilityState: 'visible',
    channel: FeatureChannelConfig(
      isEnabled: true,
      isVisible: true,
      showInNavigation: false,
      showOnHome: true,
      sortOrder: 5,
    ),
  );

  const disabledGlobally = PlatformFeature(
    featureKey: 'membership',
    displayName: 'Membership',
    isEnabled: false,
    visibilityState: 'visible',
  );

  const hiddenFeature = PlatformFeature(
    featureKey: 'contributions',
    displayName: 'Contributed',
    isEnabled: true,
    visibilityState: 'hidden',
  );

  const maintenanceFeature = PlatformFeature(
    featureKey: 'fan_clubs',
    displayName: 'Fan Clubs',
    isEnabled: true,
    visibilityState: 'maintenance',
  );

  const channelDisabled = PlatformFeature(
    featureKey: 'live',
    displayName: 'Live',
    isEnabled: true,
    visibilityState: 'visible',
    channel: FeatureChannelConfig(
      isEnabled: false,
      isVisible: true,
      showInNavigation: true,
      showOnHome: true,
    ),
  );

  const authRequired = PlatformFeature(
    featureKey: 'admin',
    displayName: 'Admin',
    isEnabled: true,
    visibilityState: 'visible',
    rules: FeatureRuleConfig(authRequired: true),
  );

  const settingsAuthRequired = PlatformFeature(
    featureKey: 'settings',
    displayName: 'Settings',
    isEnabled: true,
    visibilityState: 'visible',
    channel: FeatureChannelConfig(
      isEnabled: true,
      isVisible: true,
      showInNavigation: true,
      routeKey: '/settings',
    ),
    rules: FeatureRuleConfig(authRequired: true),
  );

  const outsideSchedule = PlatformFeature(
    featureKey: 'predict',
    displayName: 'Predict',
    isEnabled: true,
    visibilityState: 'visible',
    rules: FeatureRuleConfig(isWithinSchedule: false),
  );

  const withDeps = PlatformFeature(
    featureKey: 'streak',
    displayName: 'Streak',
    isEnabled: true,
    visibilityState: 'visible',
    rules: FeatureRuleConfig(
      dependencyRules: {
        'requires': ['ticketing', 'shop'],
      },
    ),
  );

  const withBrokenDeps = PlatformFeature(
    featureKey: 'jackpot',
    displayName: 'Jackpot',
    isEnabled: true,
    visibilityState: 'visible',
    rules: FeatureRuleConfig(
      dependencyRules: {
        'requires': ['membership'],
      },
    ),
  );

  const predictFeature = PlatformFeature(
    featureKey: 'predict',
    displayName: 'Predict',
    isEnabled: true,
    visibilityState: 'visible',
  );

  const disabledPredictFeature = PlatformFeature(
    featureKey: 'predict',
    displayName: 'Predict',
    isEnabled: false,
    visibilityState: 'visible',
  );

  const navFeatureB = PlatformFeature(
    featureKey: 'home',
    displayName: 'Home',
    isEnabled: true,
    visibilityState: 'visible',
    channel: FeatureChannelConfig(
      isEnabled: true,
      isVisible: true,
      showInNavigation: true,
      showOnHome: false,
      sortOrder: 1,
    ),
  );

  // ── Tests ──

  group('FeatureConfigService — empty snapshot', () {
    late FeatureConfigService service;

    setUp(() {
      service = FeatureConfigService(buildSnapshot());
    });

    test('hasConfig returns false for empty snapshot', () {
      expect(service.hasConfig, isFalse);
    });

    test(
      'isFeatureEnabled returns true for unknown features (backward compat)',
      () {
        expect(service.isFeatureEnabled('anything'), isTrue);
      },
    );

    test('shouldShowInNav returns false for unknown features', () {
      expect(service.shouldShowInNav('anything'), isFalse);
    });

    test('shouldShowOnHome returns false for unknown features', () {
      expect(service.shouldShowOnHome('anything'), isFalse);
    });

    test('getNavFeatures returns empty list', () {
      expect(service.getNavFeatures(), isEmpty);
    });

    test('getHomeFeatures returns empty list', () {
      expect(service.getHomeFeatures(), isEmpty);
    });

    test('getContentBlocks returns empty list', () {
      expect(service.getContentBlocks('home_top'), isEmpty);
    });
  });

  group('FeatureConfigService — feature queries', () {
    late FeatureConfigService service;

    setUp(() {
      service = FeatureConfigService(
        buildSnapshot(
          features: [
            ticketing,
            shop,
            disabledGlobally,
            hiddenFeature,
            maintenanceFeature,
            channelDisabled,
            authRequired,
            outsideSchedule,
            withDeps,
            withBrokenDeps,
            navFeatureB,
          ],
        ),
      );
    });

    test('hasConfig returns true', () {
      expect(service.hasConfig, isTrue);
    });

    test('isFeatureEnabled — enabled feature returns true', () {
      expect(service.isFeatureEnabled('ticketing'), isTrue);
    });

    test('isFeatureEnabled — globally disabled returns false', () {
      expect(service.isFeatureEnabled('membership'), isFalse);
    });

    test('isFeatureEnabled — hidden feature returns false', () {
      expect(service.isFeatureEnabled('contributions'), isFalse);
    });

    test('isFeatureEnabled — maintenance feature returns false', () {
      expect(service.isFeatureEnabled('contributions'), isFalse);
    });

    test('isFeatureEnabled — channel disabled returns false', () {
      expect(service.isFeatureEnabled('live'), isFalse);
    });

    test('isFeatureEnabled — outside schedule returns false', () {
      expect(service.isFeatureEnabled('predict'), isFalse);
    });

    test('isFeatureEnabled — unknown feature defaults to true', () {
      expect(service.isFeatureEnabled('nonexistent_feature'), isTrue);
    });
  });

  group('FeatureConfigService — visibility queries', () {
    late FeatureConfigService service;

    setUp(() {
      service = FeatureConfigService(
        buildSnapshot(features: [ticketing, hiddenFeature, maintenanceFeature]),
      );
    });

    test('isFeatureVisible — visible feature returns true', () {
      expect(service.isFeatureVisible('ticketing'), isTrue);
    });

    test('isFeatureVisible — hidden feature returns false', () {
      expect(service.isFeatureVisible('contributions'), isFalse);
    });

    test('isFeatureVisible — maintenance feature returns true', () {
      expect(service.isFeatureVisible('fan_clubs'), isTrue);
    });

    test('isFeatureVisible — unknown feature defaults to true', () {
      expect(service.isFeatureVisible('unknown_feature'), isTrue);
    });

    test('isFeatureInMaintenance — maintenance feature returns true', () {
      expect(service.isFeatureInMaintenance('fan_clubs'), isTrue);
    });

    test('isFeatureInMaintenance — visible feature returns false', () {
      expect(service.isFeatureInMaintenance('ticketing'), isFalse);
    });

    test('isFeatureInMaintenance — unknown feature returns false', () {
      expect(service.isFeatureInMaintenance('unknown'), isFalse);
    });
  });

  group('FeatureConfigService — navigation queries', () {
    late FeatureConfigService service;

    setUp(() {
      service = FeatureConfigService(
        buildSnapshot(
          features: [
            navFeatureB,
            ticketing,
            shop,
            channelDisabled,
            disabledGlobally,
          ],
        ),
      );
    });

    test('shouldShowInNav — nav feature returns true', () {
      expect(service.shouldShowInNav('home'), isTrue);
      expect(service.shouldShowInNav('ticketing'), isTrue);
    });

    test('shouldShowInNav — non-nav feature returns false', () {
      expect(service.shouldShowInNav('shop'), isFalse);
    });

    test('shouldShowInNav — channel-disabled nav feature returns false', () {
      expect(service.shouldShowInNav('live'), isFalse);
    });

    test('shouldShowOnHome — home feature returns true', () {
      expect(service.shouldShowOnHome('shop'), isTrue);
    });

    test('shouldShowOnHome — non-home feature returns false', () {
      expect(service.shouldShowOnHome('ticketing'), isFalse);
    });
  });

  group('FeatureConfigService — aggregate queries', () {
    late FeatureConfigService service;

    setUp(() {
      service = FeatureConfigService(
        buildSnapshot(
          features: [navFeatureB, ticketing, shop, channelDisabled],
        ),
      );
    });

    test('getNavFeatures returns only enabled nav features', () {
      final nav = service.getNavFeatures();
      final keys = nav.map((f) => f.featureKey).toList();
      expect(keys, containsAll(['home', 'ticketing']));
      expect(keys, isNot(contains('shop')));
      expect(keys, isNot(contains('live')));
    });

    test('getNavFeatures is sorted by sort_order', () {
      final nav = service.getNavFeatures();
      expect(nav.first.featureKey, 'home'); // sort_order: 1
      expect(nav.last.featureKey, 'ticketing'); // sort_order: 2
    });

    test('getHomeFeatures returns only enabled home features', () {
      final home = service.getHomeFeatures();
      final keys = home.map((f) => f.featureKey).toList();
      expect(keys, contains('shop'));
      expect(keys, isNot(contains('ticketing')));
      expect(keys, isNot(contains('live')));
    });
  });

  group('FeatureConfigService — auth and schedule queries', () {
    late FeatureConfigService service;

    setUp(() {
      service = FeatureConfigService(
        buildSnapshot(features: [ticketing, authRequired, outsideSchedule]),
      );
    });

    test('isAuthRequired — returns true for auth-required feature', () {
      expect(service.isAuthRequired('admin'), isTrue);
    });

    test('isAuthRequired — returns false for non-auth feature', () {
      expect(service.isAuthRequired('ticketing'), isFalse);
    });

    test('isAuthRequired — returns false for unknown feature', () {
      expect(service.isAuthRequired('non_existent'), isFalse);
    });

    test('isInsideScheduleWindow — outside schedule returns false', () {
      expect(service.isInsideScheduleWindow('predict'), isFalse);
    });

    test('isInsideScheduleWindow — no rules returns true', () {
      expect(service.isInsideScheduleWindow('ticketing'), isTrue);
    });

    test('isInsideScheduleWindow — unknown returns true', () {
      expect(service.isInsideScheduleWindow('unknown'), isTrue);
    });
  });

  group('FeatureConfigService — contextual auth gating', () {
    late PlatformConfigSnapshot snapshot;

    setUp(() {
      snapshot = buildSnapshot(features: [settingsAuthRequired]);
    });

    test('signed-out service hides auth-required nav routes', () {
      final service = FeatureConfigService(snapshot);

      expect(service.shouldShowInNav('settings'), isFalse);
      expect(service.isRouteAvailable('/settings'), isFalse);
    });

    test('signed-in service exposes auth-required nav routes', () {
      final service = FeatureConfigService(snapshot, isAuthenticated: true);

      expect(service.shouldShowInNav('settings'), isTrue);
      expect(service.isRouteAvailable('/settings'), isTrue);
    });
  });

  group('FeatureConfigService — dependency queries', () {
    late FeatureConfigService service;

    setUp(() {
      service = FeatureConfigService(
        buildSnapshot(
          features: [
            ticketing,
            shop,
            disabledGlobally,
            withDeps,
            withBrokenDeps,
          ],
        ),
      );
    });

    test('areDependenciesSatisfied — all deps enabled returns true', () {
      // streak depends on ticketing + shop, both enabled
      expect(service.areDependenciesSatisfied('streak'), isTrue);
    });

    test('areDependenciesSatisfied — dep disabled returns false', () {
      // jackpot depends on membership, which is disabled
      expect(service.areDependenciesSatisfied('jackpot'), isFalse);
    });

    test('areDependenciesSatisfied — no deps returns true', () {
      expect(service.areDependenciesSatisfied('ticketing'), isTrue);
    });

    test('areDependenciesSatisfied — unknown feature returns true', () {
      expect(service.areDependenciesSatisfied('imaginary'), isTrue);
    });
  });

  group('FeatureConfigService — route and sort queries', () {
    late FeatureConfigService service;

    setUp(() {
      service = FeatureConfigService(
        buildSnapshot(features: [ticketing, shop, disabledGlobally]),
      );
    });

    test('getRoute returns route key', () {
      expect(service.getRoute('ticketing'), '/tickets');
    });

    test('getRoute returns null when no channel config', () {
      expect(service.getRoute('membership'), isNull);
    });

    test('getRoute returns null for unknown feature', () {
      expect(service.getRoute('unknown'), isNull);
    });

    test('getSortOrder returns sort order', () {
      expect(service.getSortOrder('ticketing'), 2);
      expect(service.getSortOrder('shop'), 5);
    });

    test('getSortOrder returns null when no channel config', () {
      expect(service.getSortOrder('membership'), isNull);
    });

    test('getFeature returns the feature', () {
      final f = service.getFeature('ticketing');
      expect(f, isNotNull);
      expect(f!.displayName, 'Ticketing');
    });

    test('getFeature returns null for unknown key', () {
      expect(service.getFeature('unknown'), isNull);
    });

    test('getFeatureKeyForPath resolves configured and fallback routes', () {
      expect(service.getFeatureKeyForPath('/tickets'), 'ticketing');
      expect(service.getFeatureKeyForPath('/tickets/checkout'), 'ticketing');
      expect(
        service.getFeatureKeyForPath('/predict?section=supporters'),
        'predict',
      );
      expect(service.getFeatureKeyForPath('/unknown'), isNull);
    });

    test('isRouteAvailable blocks disabled feature routes gracefully', () {
      expect(service.isRouteAvailable('/tickets'), isTrue);
      expect(service.isRouteAvailable('/membership'), isFalse);
      expect(service.isRouteAvailable('/membership?source=home'), isFalse);
      expect(service.isRouteAvailable('/somewhere-else'), isTrue);
    });

    test('isRouteAvailable fail-closes Predict routes', () {
      expect(service.isRouteAvailable('/predict'), isFalse);
    });

    test('Predict routes require both feature and store-policy approval', () {
      final unapprovedService = FeatureConfigService(
        buildSnapshot(features: [predictFeature]),
      );
      final enabledService = FeatureConfigService(
        buildSnapshot(features: [predictFeature]),
        storeReleasePolicy: const StoreReleasePolicy(
          isEnforced: true,
          stakedCompetitionsAuthorized: true,
        ),
      );
      final disabledService = FeatureConfigService(
        buildSnapshot(features: [disabledPredictFeature]),
        storeReleasePolicy: const StoreReleasePolicy(
          isEnforced: true,
          stakedCompetitionsAuthorized: true,
        ),
      );

      expect(unapprovedService.isRouteAvailable('/predict'), isFalse);
      expect(enabledService.isRouteAvailable('/predict'), isTrue);
      expect(disabledService.isRouteAvailable('/predict'), isFalse);
    });
  });

  group('FeatureConfigService — access semantics', () {
    late FeatureConfigService service;

    setUp(() {
      service = FeatureConfigService(
        buildSnapshot(
          features: [
            hiddenFeature,
            maintenanceFeature,
            authRequired,
            withDeps,
            ticketing,
            shop,
          ],
        ),
      );
    });

    test('hidden features stay operational but do not render', () {
      final access = service.getFeatureAccess('contributions');
      expect(access.isVisible, isFalse);
      expect(access.isOperational, isTrue);
      expect(access.isAvailable, isTrue);
      expect(service.canRenderFeature('contributions'), isFalse);
      expect(service.canUseFeature('contributions'), isTrue);
    });

    test('maintenance features stay visible but are unavailable', () {
      final access = service.getFeatureAccess('fan_clubs');
      expect(access.isVisible, isTrue);
      expect(access.isOperational, isFalse);
      expect(access.isAvailable, isFalse);
      expect(access.reason, 'maintenance');
    });

    test('auth restrictions block availability until signed in', () {
      final signedOutAccess = service.getFeatureAccess('admin');
      final signedInAccess = service.getFeatureAccess(
        'admin',
        isAuthenticated: true,
      );

      expect(signedOutAccess.isAvailable, isFalse);
      expect(signedOutAccess.reason, 'auth_required');
      expect(signedInAccess.isAvailable, isTrue);
      expect(signedInAccess.reason, 'ok');
    });

    test('dependency checks do not recurse infinitely', () {
      const cyclicA = PlatformFeature(
        featureKey: 'cyclic_a',
        displayName: 'Cyclic A',
        isEnabled: true,
        visibilityState: 'visible',
        rules: FeatureRuleConfig(
          dependencyRules: {
            'requires': ['cyclic_b'],
          },
        ),
      );

      const cyclicB = PlatformFeature(
        featureKey: 'cyclic_b',
        displayName: 'Cyclic B',
        isEnabled: true,
        visibilityState: 'visible',
        rules: FeatureRuleConfig(
          dependencyRules: {
            'requires': ['cyclic_a'],
          },
        ),
      );

      final cyclicService = FeatureConfigService(
        buildSnapshot(features: [cyclicA, cyclicB]),
      );

      expect(cyclicService.areDependenciesSatisfied('cyclic_a'), isTrue);
      expect(cyclicService.canUseFeature('cyclic_a'), isTrue);
    });
  });

  group('FeatureConfigService — content blocks', () {
    late FeatureConfigService service;

    setUp(() {
      service = FeatureConfigService(
        buildSnapshot(
          features: [ticketing, disabledGlobally],
          blocks: [
            const ContentBlock(
              blockKey: 'hero',
              blockType: 'banner',
              placementKey: 'home_top',
              isActive: true,
              sortOrder: 1,
            ),
            const ContentBlock(
              blockKey: 'promo',
              blockType: 'card',
              placementKey: 'home_top',
              featureKey: 'ticketing',
              isActive: true,
              sortOrder: 2,
            ),
            const ContentBlock(
              blockKey: 'member_promo',
              blockType: 'card',
              placementKey: 'home_top',
              featureKey: 'membership',
              isActive: true,
              sortOrder: 3,
            ),
            const ContentBlock(
              blockKey: 'inactive_block',
              blockType: 'banner',
              placementKey: 'home_top',
              isActive: false,
              sortOrder: 0,
            ),
            const ContentBlock(
              blockKey: 'sidebar_block',
              blockType: 'widget',
              placementKey: 'sidebar',
              isActive: true,
              sortOrder: 1,
            ),
          ],
        ),
      );
    });

    test('getContentBlocks filters by placementKey', () {
      final blocks = service.getContentBlocks('home_top');
      expect(blocks.every((b) => b.placementKey == 'home_top'), isTrue);
    });

    test('getContentBlocks excludes inactive blocks', () {
      final blocks = service.getContentBlocks('home_top');
      expect(blocks.any((b) => b.blockKey == 'inactive_block'), isFalse);
    });

    test('getContentBlocks excludes blocks for disabled features', () {
      final blocks = service.getContentBlocks('home_top');
      // membership is disabled → member_promo should be excluded
      expect(blocks.any((b) => b.blockKey == 'member_promo'), isFalse);
    });

    test('getContentBlocks includes blocks for enabled features', () {
      final blocks = service.getContentBlocks('home_top');
      expect(blocks.any((b) => b.blockKey == 'promo'), isTrue);
    });

    test('getContentBlocks includes unlinked blocks', () {
      final blocks = service.getContentBlocks('home_top');
      expect(blocks.any((b) => b.blockKey == 'hero'), isTrue);
    });

    test('getContentBlocks sorts by sort_order', () {
      final blocks = service.getContentBlocks('home_top');
      expect(blocks.first.blockKey, 'hero'); // sort_order: 1
      expect(blocks.last.blockKey, 'promo'); // sort_order: 2
    });

    test('getContentBlocks returns empty for unknown placement', () {
      expect(service.getContentBlocks('footer'), isEmpty);
    });

    test('sidebar placement returns only sidebar blocks', () {
      final blocks = service.getContentBlocks('sidebar');
      expect(blocks, hasLength(1));
      expect(blocks.first.blockKey, 'sidebar_block');
    });
  });
}
