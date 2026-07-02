enum FetChallengeBucket { daily, weekly, seasonal }

enum FetWalletEntryDirection { credit, debit }

class FetCatalogItem {
  const FetCatalogItem({
    required this.id,
    required this.clubId,
    required this.code,
    required this.templateScope,
    required this.category,
    required this.itemName,
    required this.fetValue,
    required this.triggerCondition,
    required this.activationTiming,
    required this.description,
    required this.badgeName,
    required this.implementationNotes,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final int? clubId;
  final String code;
  final String templateScope;
  final String category;
  final String itemName;
  final int fetValue;
  final String triggerCondition;
  final String activationTiming;
  final String description;
  final String? badgeName;
  final String? implementationNotes;
  final int sortOrder;
  final bool isActive;

  factory FetCatalogItem.fromJson(Map<String, dynamic> json) {
    return FetCatalogItem(
      id: json['id']?.toString() ?? '',
      clubId: int.tryParse(json['club_id']?.toString() ?? ''),
      code: (json['code']?.toString() ?? '').toUpperCase(),
      templateScope: json['template_scope']?.toString() ?? 'generic',
      category: json['category']?.toString() ?? 'General',
      itemName: json['item_name']?.toString() ?? 'Fan engagement reward',
      fetValue: (json['fet_value'] as num?)?.toInt() ?? 0,
      triggerCondition:
          json['trigger_condition']?.toString() ??
          'Defined by club operations.',
      activationTiming: json['activation_timing']?.toString() ?? 'Always on',
      description: json['description']?.toString() ?? '',
      badgeName: _normalizeNullableString(json['badge_name']),
      implementationNotes: _normalizeNullableString(
        json['implementation_notes'],
      ),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] != false,
    );
  }

  String get iconKey {
    final normalizedCategory = category.toLowerCase();
    if (normalizedCategory.contains('match')) return 'match';
    if (normalizedCategory.contains('identity')) return 'fan_club';
    if (normalizedCategory.contains('social')) return 'fan_club';
    if (normalizedCategory.contains('content')) return 'contributor';
    if (normalizedCategory.contains('loyalty')) return 'legend';
    if (normalizedCategory.contains('challenge')) return 'streak';
    if (normalizedCategory.contains('leaderboard')) return 'mvp';
    if (normalizedCategory.contains('season')) return 'legend';
    if (normalizedCategory.contains('club contribution')) return 'contributor';
    if (normalizedCategory.contains('partner')) return 'spender';
    if (normalizedCategory.contains('prediction')) return 'mvp';
    return 'match';
  }

  FetChallengeBucket get challengeBucket {
    final normalizedTiming = activationTiming.toLowerCase();
    final normalizedCategory = category.toLowerCase();

    if (normalizedTiming.contains('season') ||
        normalizedTiming.contains('annual') ||
        normalizedTiming.contains('birthday') ||
        normalizedTiming.contains('pre-season') ||
        normalizedCategory.contains('seasonal') ||
        normalizedCategory.contains('loyalty')) {
      return FetChallengeBucket.seasonal;
    }

    if (normalizedTiming.contains('every day') ||
        normalizedTiming.contains('daily') ||
        normalizedTiming.contains('day 0') ||
        normalizedTiming.contains('pre-match') ||
        normalizedTiming.contains('post-match') ||
        normalizedTiming.contains('match day') ||
        normalizedTiming.contains('halftime')) {
      return FetChallengeBucket.daily;
    }

    return FetChallengeBucket.weekly;
  }
}

class FetPartnerOffer {
  const FetPartnerOffer({
    required this.id,
    required this.clubId,
    required this.catalogItemId,
    required this.code,
    required this.partnerId,
    required this.partnerSlug,
    required this.partnerName,
    required this.partnerEmoji,
    required this.partnerCategory,
    required this.partnerSubtitle,
    required this.partnerBrandPrimaryColor,
    required this.partnerBrandSecondaryColor,
    required this.title,
    required this.subtitle,
    required this.fetValue,
    required this.triggerCondition,
    required this.activationTiming,
    required this.description,
    required this.badgeName,
    required this.ctaLabel,
    required this.verificationMode,
    required this.deeplinkRoute,
    required this.externalUrl,
    required this.isFeatured,
    required this.isActive,
    required this.sortOrder,
    required this.metadata,
  });

  final String id;
  final int? clubId;
  final String catalogItemId;
  final String code;
  final String partnerId;
  final String partnerSlug;
  final String partnerName;
  final String? partnerEmoji;
  final String partnerCategory;
  final String? partnerSubtitle;
  final String? partnerBrandPrimaryColor;
  final String? partnerBrandSecondaryColor;
  final String title;
  final String subtitle;
  final int fetValue;
  final String triggerCondition;
  final String activationTiming;
  final String description;
  final String? badgeName;
  final String ctaLabel;
  final String verificationMode;
  final String? deeplinkRoute;
  final String? externalUrl;
  final bool isFeatured;
  final bool isActive;
  final int sortOrder;
  final Map<String, dynamic> metadata;

  factory FetPartnerOffer.fromJson(Map<String, dynamic> json) {
    final metadataValue = json['metadata'];
    return FetPartnerOffer(
      id: json['id']?.toString() ?? '',
      clubId: int.tryParse(json['club_id']?.toString() ?? ''),
      catalogItemId: json['catalog_item_id']?.toString() ?? '',
      code: (json['code']?.toString() ?? '').toUpperCase(),
      partnerId: json['partner_id']?.toString() ?? '',
      partnerSlug: json['partner_slug']?.toString() ?? '',
      partnerName: json['partner_name']?.toString() ?? 'Partner',
      partnerEmoji: _normalizeNullableString(json['partner_emoji']),
      partnerCategory: json['partner_category']?.toString() ?? 'organization',
      partnerSubtitle: _normalizeNullableString(json['partner_subtitle']),
      partnerBrandPrimaryColor: _normalizeNullableString(
        json['partner_brand_primary_color'],
      ),
      partnerBrandSecondaryColor: _normalizeNullableString(
        json['partner_brand_secondary_color'],
      ),
      title: json['title']?.toString() ?? 'Partner offer',
      subtitle: json['subtitle']?.toString() ?? '',
      fetValue: (json['fet_value'] as num?)?.toInt() ?? 0,
      triggerCondition:
          json['trigger_condition']?.toString() ??
          'Complete the partner journey to earn points.',
      activationTiming: json['activation_timing']?.toString() ?? 'Always on',
      description: json['description']?.toString() ?? '',
      badgeName: _normalizeNullableString(json['badge_name']),
      ctaLabel: json['cta_label']?.toString() ?? 'View details',
      verificationMode:
          json['verification_mode']?.toString() ?? 'manual_review',
      deeplinkRoute: _normalizeNullableString(json['deeplink_route']),
      externalUrl: _normalizeNullableString(json['external_url']),
      isFeatured: json['is_featured'] == true,
      isActive: json['is_active'] != false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      metadata: metadataValue is Map
          ? Map<String, dynamic>.from(metadataValue)
          : const <String, dynamic>{},
    );
  }

  bool get isMatchDay {
    final normalized = activationTiming.toLowerCase();
    return normalized.contains('match day') ||
        normalized.contains('kickoff') ||
        normalized.contains('post-match') ||
        normalized.contains('derby');
  }

  bool get hasDeepLink =>
      deeplinkRoute != null && deeplinkRoute!.trim().isNotEmpty;
}

class FetLeaderboardRow {
  const FetLeaderboardRow({
    required this.rank,
    required this.userId,
    required this.supporterAlias,
    required this.displayName,
    required this.totalFet,
    required this.tier,
    required this.isCurrentUser,
  });

  final int rank;
  final String userId;
  final String supporterAlias;
  final String displayName;
  final int totalFet;
  final String tier;
  final bool isCurrentUser;

  factory FetLeaderboardRow.fromJson(Map<String, dynamic> json) {
    return FetLeaderboardRow(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      userId: json['user_id']?.toString() ?? '',
      supporterAlias: json['supporter_alias']?.toString() ?? '000000',
      displayName: json['display_name']?.toString() ?? 'Supporter',
      totalFet: (json['total_fet'] as num?)?.toInt() ?? 0,
      tier: json['tier']?.toString() ?? 'imena',
      isCurrentUser: json['is_current_user'] == true,
    );
  }
}

class FetExperienceContext {
  const FetExperienceContext({
    required this.catalog,
    required this.leaderboard,
    required this.earnedCodes,
    required this.currentFet,
    required this.weeklyFet,
    required this.fanRank,
    required this.tier,
    required this.nextTier,
  });

  final List<FetCatalogItem> catalog;
  final List<FetLeaderboardRow> leaderboard;
  final Set<String> earnedCodes;
  final int currentFet;
  final int weeklyFet;
  final int fanRank;
  final String tier;
  final String nextTier;
}

class FetWalletSummary {
  const FetWalletSummary({
    required this.userId,
    required this.clubId,
    required this.membershipId,
    required this.balance,
    required this.tier,
    required this.weeklyEarned,
    required this.monthlyEarned,
    required this.lifetimeEarned,
    required this.lifetimeSpent,
    required this.transactionCount,
    required this.historicalBalanceGap,
  });

  final String userId;
  final int? clubId;
  final String membershipId;
  final int balance;
  final String tier;
  final int weeklyEarned;
  final int monthlyEarned;
  final int lifetimeEarned;
  final int lifetimeSpent;
  final int transactionCount;
  final int historicalBalanceGap;

  factory FetWalletSummary.fromJson(Map<String, dynamic> json) {
    return FetWalletSummary(
      userId: json['user_id']?.toString() ?? '',
      clubId: int.tryParse(json['club_id']?.toString() ?? ''),
      membershipId: json['membership_id']?.toString() ?? '',
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      tier: json['tier']?.toString() ?? 'imena',
      weeklyEarned: (json['weekly_earned'] as num?)?.toInt() ?? 0,
      monthlyEarned: (json['monthly_earned'] as num?)?.toInt() ?? 0,
      lifetimeEarned: (json['lifetime_earned'] as num?)?.toInt() ?? 0,
      lifetimeSpent: (json['lifetime_spent'] as num?)?.toInt() ?? 0,
      transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
      historicalBalanceGap:
          (json['historical_balance_gap'] as num?)?.toInt() ?? 0,
    );
  }
}

class FetWalletTransaction {
  const FetWalletTransaction({
    required this.id,
    required this.entryType,
    required this.direction,
    required this.amount,
    required this.balanceAfter,
    required this.counterpartyUserId,
    required this.counterpartyDisplayName,
    required this.counterpartyPublicUserId,
    required this.note,
    required this.referenceType,
    required this.referenceId,
    required this.createdAt,
  });

  final String id;
  final String entryType;
  final FetWalletEntryDirection direction;
  final int amount;
  final int balanceAfter;
  final String? counterpartyUserId;
  final String? counterpartyDisplayName;
  final String? counterpartyPublicUserId;
  final String? note;
  final String? referenceType;
  final String? referenceId;
  final DateTime? createdAt;

  factory FetWalletTransaction.fromJson(Map<String, dynamic> json) {
    final directionText = json['direction']?.toString().toLowerCase();
    return FetWalletTransaction(
      id: json['id']?.toString() ?? '',
      entryType: json['entry_type']?.toString() ?? 'earn',
      direction: directionText == 'debit'
          ? FetWalletEntryDirection.debit
          : FetWalletEntryDirection.credit,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      balanceAfter: (json['balance_after'] as num?)?.toInt() ?? 0,
      counterpartyUserId: _normalizeNullableString(
        json['counterparty_user_id'],
      ),
      counterpartyDisplayName: _normalizeNullableString(
        json['counterparty_display_name'],
      ),
      counterpartyPublicUserId: _normalizeNullableString(
        json['counterparty_public_user_id'],
      ),
      note: _normalizeNullableString(json['note']),
      referenceType: _normalizeNullableString(json['reference_type']),
      referenceId: _normalizeNullableString(json['reference_id']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  int get signedAmount =>
      direction == FetWalletEntryDirection.debit ? -amount : amount;

  String get headline {
    switch (entryType) {
      case 'partner_promotion_earn':
        return 'Partner points earned';
      case 'partner_pool_entry':
        return 'Partner pool entry';
      case 'partner_pool_payout':
        return 'Partner pool payout';
      case 'partner_pool_refund':
        return 'Partner pool refund';
      case 'transfer_in':
        return 'Transfer received';
      case 'transfer_out':
        return 'Transfer sent';
      case 'redeem':
        return 'Points redemption';
      case 'admin_adjustment':
        return direction == FetWalletEntryDirection.credit
            ? 'Admin top-up'
            : 'Admin deduction';
      case 'opening_balance':
        return 'Opening balance';
      case 'earn':
      default:
        return 'Points earned';
    }
  }
}

class FetWalletSupporter {
  const FetWalletSupporter({
    required this.userId,
    required this.publicUserId,
    required this.displayName,
    required this.tier,
    required this.balance,
  });

  final String userId;
  final String? publicUserId;
  final String displayName;
  final String tier;
  final int balance;

  factory FetWalletSupporter.fromJson(Map<String, dynamic> json) {
    return FetWalletSupporter(
      userId: json['user_id']?.toString() ?? '',
      publicUserId: _normalizeNullableString(json['public_user_id']),
      displayName: json['display_name']?.toString() ?? 'Supporter',
      tier: json['tier']?.toString() ?? 'imena',
      balance: (json['balance'] as num?)?.toInt() ?? 0,
    );
  }
}

class FetWalletOperationResult {
  const FetWalletOperationResult({
    required this.status,
    required this.amount,
    required this.balance,
    required this.referenceId,
    required this.alreadyProcessed,
    required this.recipientUserId,
  });

  final String status;
  final int amount;
  final int balance;
  final String? referenceId;
  final bool alreadyProcessed;
  final String? recipientUserId;

  factory FetWalletOperationResult.fromJson(Map<String, dynamic> json) {
    return FetWalletOperationResult(
      status: json['status']?.toString() ?? 'unknown',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      referenceId: _normalizeNullableString(json['reference_id']),
      alreadyProcessed: json['already_processed'] == true,
      recipientUserId: _normalizeNullableString(json['recipient_user_id']),
    );
  }
}

class FetFriendProfile {
  const FetFriendProfile({
    required this.userId,
    required this.displayName,
    required this.tier,
    required this.balance,
    required this.friendshipStatus,
    this.publicUserId,
    this.friendshipId,
    this.isOnline = false,
    this.lastSeenAt,
  });

  final String userId;
  final String? publicUserId;
  final String displayName;
  final String tier;
  final int balance;
  final String? friendshipId;
  final String friendshipStatus;
  final bool isOnline;
  final DateTime? lastSeenAt;

  bool get isFriend => friendshipStatus == 'accepted';
  bool get hasPendingIncoming => friendshipStatus == 'pending_incoming';
  bool get hasPendingOutgoing => friendshipStatus == 'pending_outgoing';
  bool get canChallenge => isFriend;

  factory FetFriendProfile.fromJson(Map<String, dynamic> json) {
    return FetFriendProfile(
      userId: json['user_id']?.toString() ?? '',
      publicUserId: _normalizeNullableString(json['public_user_id']),
      displayName: json['display_name']?.toString() ?? 'Supporter',
      tier: json['tier']?.toString() ?? 'imena',
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      friendshipId: _normalizeNullableString(json['friendship_id']),
      friendshipStatus: json['friendship_status']?.toString() ?? 'none',
      isOnline: json['is_online'] == true,
      lastSeenAt: DateTime.tryParse(json['last_seen_at']?.toString() ?? ''),
    );
  }
}

class FetFriendActionResult {
  const FetFriendActionResult({
    required this.status,
    required this.message,
    this.friendshipId,
  });

  final String status;
  final String message;
  final String? friendshipId;

  bool get isSuccess =>
      status == 'accepted' ||
      status == 'pending_outgoing' ||
      status == 'declined' ||
      status == 'cancelled' ||
      status == 'blocked';

  factory FetFriendActionResult.fromJson(Map<String, dynamic> json) {
    return FetFriendActionResult(
      status: json['status']?.toString() ?? 'error',
      message: json['message']?.toString() ?? '',
      friendshipId: _normalizeNullableString(json['friendship_id']),
    );
  }
}

class FetRewardRedemption {
  const FetRewardRedemption({
    required this.id,
    required this.rewardItemId,
    required this.rewardSlug,
    required this.rewardTitle,
    required this.costFet,
    required this.status,
    this.walletReferenceId,
    this.fulfillmentChannel,
    this.fulfillmentReference,
    this.supporterNote,
    this.adminNote,
    this.consumedAt,
    this.fulfilledAt,
    this.createdAt,
  });

  final String id;
  final String rewardItemId;
  final String rewardSlug;
  final String rewardTitle;
  final int costFet;
  final String status;
  final String? walletReferenceId;
  final String? fulfillmentChannel;
  final String? fulfillmentReference;
  final String? supporterNote;
  final String? adminNote;
  final DateTime? consumedAt;
  final DateTime? fulfilledAt;
  final DateTime? createdAt;

  factory FetRewardRedemption.fromJson(Map<String, dynamic> json) {
    return FetRewardRedemption(
      id: json['id']?.toString() ?? '',
      rewardItemId: json['reward_item_id']?.toString() ?? '',
      rewardSlug: json['reward_slug']?.toString() ?? '',
      rewardTitle: json['reward_title']?.toString() ?? '',
      costFet: (json['cost_fet'] as num?)?.toInt() ?? 0,
      walletReferenceId: _normalizeNullableString(json['wallet_reference_id']),
      status: json['status']?.toString() ?? 'pending',
      fulfillmentChannel: _normalizeNullableString(json['fulfillment_channel']),
      fulfillmentReference: _normalizeNullableString(
        json['fulfillment_reference'],
      ),
      supporterNote: _normalizeNullableString(json['supporter_note']),
      adminNote: _normalizeNullableString(json['admin_note']),
      consumedAt: DateTime.tryParse(json['consumed_at']?.toString() ?? ''),
      fulfilledAt: DateTime.tryParse(json['fulfilled_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class FetRewardRedemptionResult {
  const FetRewardRedemptionResult({
    required this.status,
    required this.message,
    this.redemptionId,
    this.rewardItemId,
    this.rewardSlug,
    this.rewardTitle,
    this.balance = 0,
    this.referenceId,
    this.alreadyProcessed = false,
  });

  final String status;
  final String message;
  final String? redemptionId;
  final String? rewardItemId;
  final String? rewardSlug;
  final String? rewardTitle;
  final int balance;
  final String? referenceId;
  final bool alreadyProcessed;

  bool get isSuccess => status == 'submitted';

  factory FetRewardRedemptionResult.fromJson(Map<String, dynamic> json) {
    return FetRewardRedemptionResult(
      status: json['status']?.toString() ?? 'error',
      message: json['message']?.toString() ?? '',
      redemptionId: _normalizeNullableString(json['redemption_id']),
      rewardItemId: _normalizeNullableString(json['reward_item_id']),
      rewardSlug: _normalizeNullableString(json['reward_slug']),
      rewardTitle: _normalizeNullableString(json['reward_title']),
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      referenceId: _normalizeNullableString(json['reference_id']),
      alreadyProcessed: json['already_processed'] == true,
    );
  }
}

String? _normalizeNullableString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
