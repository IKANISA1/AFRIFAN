import 'package:core_feature_config/core_feature_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StoreReleasePolicy', () {
    test('production defaults fail closed with no server capabilities', () {
      final policy = StoreReleasePolicy.forCurrentBuild(
        const PlatformConfigSnapshot(),
        enforceStorePolicy: true,
      );

      expect(policy.allowsStakedCompetitions, isFalse);
      expect(policy.allowsRewardRedemption, isFalse);
      expect(policy.allowsCrossUserText, isFalse);
      expect(policy.allowsPaidDigitalMembership, isFalse);
      expect(policy.allowsEarnedPointsReadHistory, isTrue);
      expect(policy.allowsPhysicalGoods, isTrue);
      expect(policy.allowsEventTickets, isTrue);
    });

    test('one generic server boolean cannot open a sensitive capability', () {
      final policy = StoreReleasePolicy.forCurrentBuild(
        _snapshot(<PlatformFeature>[
          _feature(
            StorePolicyFeatureKeys.stakedCompetitions,
            const <String, dynamic>{
              StorePolicyRuleKeys.storeReleaseAuthorized: true,
            },
          ),
        ]),
        enforceStorePolicy: true,
      );

      expect(policy.allowsStakedCompetitions, isFalse);
    });

    test('staked competition requires complete explicit server evidence', () {
      final policy = StoreReleasePolicy.forCurrentBuild(
        _snapshot(<PlatformFeature>[
          _feature(
            StorePolicyFeatureKeys.stakedCompetitions,
            const <String, dynamic>{
              StorePolicyRuleKeys.storeReleaseAuthorized: true,
              StorePolicyRuleKeys.stakesHaveNoRealWorldValue: true,
              StorePolicyRuleKeys.contestRulesApproved: true,
            },
          ),
        ]),
        enforceStorePolicy: true,
      );

      expect(policy.allowsStakedCompetitions, isTrue);
      expect(policy.isRouteAllowed('/challenge/create'), isTrue);
    });

    test('reward redemption requires approved no-real-value catalog', () {
      final policy = StoreReleasePolicy.forCurrentBuild(
        _snapshot(<PlatformFeature>[
          _feature(
            StorePolicyFeatureKeys.rewardRedemption,
            const <String, dynamic>{
              StorePolicyRuleKeys.storeReleaseAuthorized: true,
              StorePolicyRuleKeys.rewardsHaveNoRealWorldValue: true,
              StorePolicyRuleKeys.rewardsCatalogApproved: true,
            },
          ),
        ]),
        enforceStorePolicy: true,
      );

      expect(policy.allowsRewardRedemption, isTrue);
      expect(policy.allowsPointsTransfer, isFalse);
      expect(policy.allowsManualPointsRedemption, isFalse);
      expect(policy.isRouteAllowed('/fanzone/rewards'), isTrue);
    });

    test('paid digital benefits need server approval and compiled billing', () {
      final snapshot = _snapshot(<PlatformFeature>[
        _feature(
          StorePolicyFeatureKeys.paidDigitalMembership,
          const <String, dynamic>{
            StorePolicyRuleKeys.storeReleaseAuthorized: true,
            StorePolicyRuleKeys.storeBillingAuthorized: true,
          },
        ),
      ]);

      expect(
        StoreReleasePolicy.forCurrentBuild(
          snapshot,
          enforceStorePolicy: true,
          storeBillingAvailable: false,
        ).allowsPaidDigitalMembership,
        isFalse,
      );
      expect(
        StoreReleasePolicy.forCurrentBuild(
          snapshot,
          enforceStorePolicy: true,
          storeBillingAvailable: true,
        ).allowsPaidDigitalMembership,
        isTrue,
      );
    });

    test('public identity falls back to a stable system alias', () {
      const policy = StoreReleasePolicy(isEnforced: true);

      expect(
        policy.publicSupporterLabel(
          displayName: 'Unmoderated nickname',
          publicUserId: '882941',
          userId: 'user-1',
        ),
        '#882-941',
      );
      final derived = policy.publicSupporterLabel(
        displayName: 'Unmoderated nickname',
        userId: 'user-1',
      );
      expect(derived, matches(RegExp(r'^#\d{3}-\d{3}$')));
      expect(policy.publicSupporterLabel(userId: 'user-1'), derived);
    });

    test('complete UGC authorization may use the display name', () {
      final policy = StoreReleasePolicy.forCurrentBuild(
        _snapshot(<PlatformFeature>[
          _feature(
            StorePolicyFeatureKeys.crossUserText,
            const <String, dynamic>{
              StorePolicyRuleKeys.storeReleaseAuthorized: true,
              StorePolicyRuleKeys.termsAcceptanceEnabled: true,
              StorePolicyRuleKeys.contentFilteringEnabled: true,
              StorePolicyRuleKeys.reportingEnabled: true,
              StorePolicyRuleKeys.blockingEnabled: true,
              StorePolicyRuleKeys.moderationOperationsApproved: true,
            },
          ),
        ]),
        enforceStorePolicy: true,
      );

      expect(
        policy.publicSupporterLabel(
          displayName: 'Approved nickname',
          publicUserId: '882941',
        ),
        'Approved nickname',
      );
    });

    test('sensitive routes are blocked while physical routes remain open', () {
      const policy = StoreReleasePolicy(isEnforced: true);

      expect(policy.isRouteAllowed('/challenge/123'), isFalse);
      expect(policy.isRouteAllowed('/fanzone/jackpot'), isFalse);
      expect(policy.isRouteAllowed('/fanzone/friends/create'), isFalse);
      expect(policy.isRouteAllowed('/fanzone/rewards'), isFalse);
      expect(policy.isRouteAllowed('/tickets'), isTrue);
      expect(policy.isRouteAllowed('/shop'), isTrue);
    });
  });
}

PlatformConfigSnapshot _snapshot(List<PlatformFeature> features) {
  return PlatformConfigSnapshot(features: features);
}

PlatformFeature _feature(String key, Map<String, dynamic> rolloutRules) {
  return PlatformFeature(
    featureKey: key,
    displayName: key,
    rules: FeatureRuleConfig(rolloutRules: rolloutRules),
  );
}
