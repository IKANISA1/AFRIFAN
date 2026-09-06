import '../models/platform_feature_config.dart';

/// Server feature keys that can authorize policy-sensitive store surfaces.
///
/// Merely enabling the surrounding product feature is intentionally
/// insufficient. The matching feature must also carry every required boolean
/// in `rules.rollout_rules` before a production store build can expose it.
abstract final class StorePolicyFeatureKeys {
  static const String stakedCompetitions = 'predict';
  static const String rewardRedemption = 'reward_redemption';
  static const String crossUserText = 'cross_user_text';
  static const String paidDigitalMembership = 'paid_digital_membership';
}

abstract final class StorePolicyRuleKeys {
  static const String storeReleaseAuthorized = 'store_release_authorized';
  static const String stakesHaveNoRealWorldValue =
      'stakes_have_no_real_world_value';
  static const String contestRulesApproved = 'contest_rules_approved';
  static const String rewardsHaveNoRealWorldValue =
      'rewards_have_no_real_world_value';
  static const String rewardsCatalogApproved = 'rewards_catalog_approved';
  static const String termsAcceptanceEnabled = 'terms_acceptance_enabled';
  static const String contentFilteringEnabled = 'content_filtering_enabled';
  static const String reportingEnabled = 'reporting_enabled';
  static const String blockingEnabled = 'blocking_enabled';
  static const String moderationOperationsApproved =
      'moderation_operations_approved';
  static const String storeBillingAuthorized = 'store_billing_authorized';
}

/// Fail-closed policy for capabilities that carry store-review risk.
///
/// Production is the default environment on purpose: a candidate that omits
/// `ENVIRONMENT` remains protected. Development and staging builds can opt out
/// explicitly through their existing environment configuration.
class StoreReleasePolicy {
  const StoreReleasePolicy({
    required this.isEnforced,
    this.stakedCompetitionsAuthorized = false,
    this.rewardRedemptionAuthorized = false,
    this.crossUserTextAuthorized = false,
    this.paidDigitalMembershipAuthorized = false,
    this.storeBillingAvailable = false,
  });

  const StoreReleasePolicy.unenforced()
    : this(
        isEnforced: false,
        stakedCompetitionsAuthorized: true,
        rewardRedemptionAuthorized: true,
        crossUserTextAuthorized: true,
        paidDigitalMembershipAuthorized: true,
        storeBillingAvailable: true,
      );

  static const String compiledEnvironment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'production',
  );

  /// This may become true only in a binary that actually integrates and tests
  /// the applicable Apple/Google store-billing implementation.
  static const bool compiledStoreBillingAvailable = bool.fromEnvironment(
    'AFRICLUB_STORE_BILLING_AVAILABLE',
    defaultValue: false,
  );

  final bool isEnforced;
  final bool stakedCompetitionsAuthorized;
  final bool rewardRedemptionAuthorized;
  final bool crossUserTextAuthorized;
  final bool paidDigitalMembershipAuthorized;
  final bool storeBillingAvailable;

  bool get allowsStakedCompetitions =>
      !isEnforced || stakedCompetitionsAuthorized;

  bool get allowsRewardRedemption => !isEnforced || rewardRedemptionAuthorized;

  bool get allowsCrossUserText => !isEnforced || crossUserTextAuthorized;

  bool get allowsPaidDigitalMembership =>
      !isEnforced || (paidDigitalMembershipAuthorized && storeBillingAvailable);

  /// Direct external-payment launch without a server-created pending intent is
  /// development-only. A published recipient route or reconciliation label is
  /// not evidence that the app can track, reconcile, or recover the payment.
  bool get allowsUnreconciledExternalPaymentLaunch => !isEnforced;

  /// Peer-to-peer points transfer and unscoped/manual redemption remain
  /// development-only. A no-real-value reward catalog approval does not imply
  /// that a transferable balance or generic redemption rail is store-safe.
  bool get allowsPointsTransfer => !isEnforced;
  bool get allowsManualPointsRedemption => !isEnforced;

  bool get allowsEarnedPointsReadHistory => true;
  bool get allowsPhysicalGoods => true;
  bool get allowsEventTickets => true;

  factory StoreReleasePolicy.forCurrentBuild(
    PlatformConfigSnapshot snapshot, {
    bool? enforceStorePolicy,
    bool storeBillingAvailable = compiledStoreBillingAvailable,
  }) {
    final enforced =
        enforceStorePolicy ??
        compiledEnvironment.trim().toLowerCase() == 'production';
    if (!enforced) {
      return const StoreReleasePolicy.unenforced();
    }

    return StoreReleasePolicy(
      isEnforced: true,
      stakedCompetitionsAuthorized: _isAuthorized(
        snapshot,
        StorePolicyFeatureKeys.stakedCompetitions,
        const <String>[
          StorePolicyRuleKeys.storeReleaseAuthorized,
          StorePolicyRuleKeys.stakesHaveNoRealWorldValue,
          StorePolicyRuleKeys.contestRulesApproved,
        ],
      ),
      rewardRedemptionAuthorized: _isAuthorized(
        snapshot,
        StorePolicyFeatureKeys.rewardRedemption,
        const <String>[
          StorePolicyRuleKeys.storeReleaseAuthorized,
          StorePolicyRuleKeys.rewardsHaveNoRealWorldValue,
          StorePolicyRuleKeys.rewardsCatalogApproved,
        ],
      ),
      crossUserTextAuthorized: _isAuthorized(
        snapshot,
        StorePolicyFeatureKeys.crossUserText,
        const <String>[
          StorePolicyRuleKeys.storeReleaseAuthorized,
          StorePolicyRuleKeys.termsAcceptanceEnabled,
          StorePolicyRuleKeys.contentFilteringEnabled,
          StorePolicyRuleKeys.reportingEnabled,
          StorePolicyRuleKeys.blockingEnabled,
          StorePolicyRuleKeys.moderationOperationsApproved,
        ],
      ),
      paidDigitalMembershipAuthorized: _isAuthorized(
        snapshot,
        StorePolicyFeatureKeys.paidDigitalMembership,
        const <String>[
          StorePolicyRuleKeys.storeReleaseAuthorized,
          StorePolicyRuleKeys.storeBillingAuthorized,
        ],
      ),
      storeBillingAvailable: storeBillingAvailable,
    );
  }

  factory StoreReleasePolicy.fromRawSnapshot(
    Map<String, dynamic>? snapshot, {
    required bool enforceStorePolicy,
    bool storeBillingAvailable = compiledStoreBillingAvailable,
  }) {
    return StoreReleasePolicy.forCurrentBuild(
      snapshot == null
          ? const PlatformConfigSnapshot()
          : PlatformConfigSnapshot.fromJson(snapshot),
      enforceStorePolicy: enforceStorePolicy,
      storeBillingAvailable: storeBillingAvailable,
    );
  }

  /// Returns a system-controlled supporter alias whenever public editable text
  /// has not passed the complete UGC control gate.
  String publicSupporterLabel({
    String? displayName,
    String? publicUserId,
    String? userId,
  }) {
    final normalizedDisplayName = _trimToNull(displayName);
    if (allowsCrossUserText && normalizedDisplayName != null) {
      return normalizedDisplayName;
    }

    final explicitAlias = _trimToNull(
      publicUserId,
    )?.replaceFirst(RegExp(r'^#+'), '');
    final alias = explicitAlias ?? _stableSixDigitAlias(_trimToNull(userId));
    if (alias == null) {
      return 'Supporter';
    }
    return '#${_formatAlias(alias)}';
  }

  bool isRouteAllowed(String path) {
    if (!isEnforced) return true;
    final normalized = _normalizePath(path);
    if (normalized == '/predict' ||
        normalized.startsWith('/predict/') ||
        normalized == '/challenge' ||
        normalized.startsWith('/challenge/') ||
        normalized == '/fanzone/jackpot' ||
        normalized.startsWith('/fanzone/jackpot/') ||
        normalized == '/fanzone/challenges' ||
        normalized.startsWith('/fanzone/challenges/') ||
        normalized == '/fanzone/challenge' ||
        normalized.startsWith('/fanzone/challenge/') ||
        normalized == '/fanzone/friends' ||
        normalized.startsWith('/fanzone/friends/')) {
      return allowsStakedCompetitions;
    }
    if (normalized == '/fanzone/rewards' ||
        normalized.startsWith('/fanzone/rewards/') ||
        normalized == '/fanzone/offers' ||
        normalized.startsWith('/fanzone/offers/')) {
      return allowsRewardRedemption;
    }
    return true;
  }

  static bool _isAuthorized(
    PlatformConfigSnapshot snapshot,
    String featureKey,
    List<String> requiredRules,
  ) {
    final feature = snapshot.featureByKey(featureKey);
    if (feature == null || !feature.isEffectivelyEnabled) {
      return false;
    }
    final rolloutRules = feature.rules?.rolloutRules;
    if (rolloutRules == null) return false;
    return requiredRules.every((key) => rolloutRules[key] == true);
  }

  static String _normalizePath(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    final path = uri?.path.trim();
    return (path == null || path.isEmpty ? trimmed : path).toLowerCase();
  }

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _stableSixDigitAlias(String? value) {
    if (value == null) return null;
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return (100000 + (hash % 900000)).toString();
  }

  static String _formatAlias(String alias) {
    final normalized = alias.trim();
    if (RegExp(r'^\d{6}$').hasMatch(normalized)) {
      return '${normalized.substring(0, 3)}-${normalized.substring(3)}';
    }
    return normalized;
  }
}
