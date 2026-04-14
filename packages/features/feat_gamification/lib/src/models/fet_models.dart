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
      tier: json['tier']?.toString() ?? 'fan',
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
    required this.legacyBalanceGap,
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
  final int legacyBalanceGap;

  factory FetWalletSummary.fromJson(Map<String, dynamic> json) {
    return FetWalletSummary(
      userId: json['user_id']?.toString() ?? '',
      clubId: int.tryParse(json['club_id']?.toString() ?? ''),
      membershipId: json['membership_id']?.toString() ?? '',
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      tier: json['tier']?.toString() ?? 'fan',
      weeklyEarned: (json['weekly_earned'] as num?)?.toInt() ?? 0,
      monthlyEarned: (json['monthly_earned'] as num?)?.toInt() ?? 0,
      lifetimeEarned: (json['lifetime_earned'] as num?)?.toInt() ?? 0,
      lifetimeSpent: (json['lifetime_spent'] as num?)?.toInt() ?? 0,
      transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
      legacyBalanceGap: (json['legacy_balance_gap'] as num?)?.toInt() ?? 0,
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
      case 'transfer_in':
        return 'Transfer received';
      case 'transfer_out':
        return 'Transfer sent';
      case 'redeem':
        return 'Wallet redemption';
      case 'admin_adjustment':
        return direction == FetWalletEntryDirection.credit
            ? 'Admin top-up'
            : 'Admin deduction';
      case 'opening_balance':
        return 'Opening balance';
      case 'earn':
      default:
        return 'FET earned';
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
      tier: json['tier']?.toString() ?? 'fan',
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

String? _normalizeNullableString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
